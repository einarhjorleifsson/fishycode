# map.R — the effort map as a map of ramb's viewer (rb_map(), plan 046 step 6): map.json's layers, groups and texts,
# each layer given its tiles or data here.
# Decision 220, plan 046.
#
# Input:  products/effort_map/map.json; the base grid (grid.R) and effort_tile() from tiles.R, sourced by the caller;
#         grid_fixes.parquet beside it, the same with each fix in its own cell (`grid.R fixes`), for the interpolation
#         switch, which is left out without it; $FISHYDATA/curated/reference/gear.parquet;
#         $FISHYDATA/curated/reference/port_geometry.parquet (the ports);
#         $FISHYDATA/curated/place_name/place_name.parquet, place.parquet and synonym.parquet (plan 044), if they are
#         there; read_curated_sf() (R/write_curated.R)
# Output: effort_map_build(con, grid), an rb_map for rb_map_serve(): the effort as a grid layer (its filters checked
#         by ramb before effort_tile() sees them), the ports as tiles of their table, the place names as GeoJSON

# run from the fishycode root, as server.R and effort_map.R are
effort_map_build <- function(con, grid, json = file.path("products", "effort_map", "map.json")) {
  spec <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  # the interpolation switch needs the grid of fixes alone
  if (!file.exists(fixes_grid(grid))) {
    spec$layers <- lapply(spec$layers, function(l) {
      if (identical(l$id, "effort")) l$filters <- Filter(function(f) !identical(f$id, "interp"), l$filters)
      l
    })
  }
  extra <- list(
    effort = list(tiles = effort_tiles(con, grid), meta = function() effort_meta(con, grid)),
    ports = list(tiles = ports_tiles(con)),
    names = list(data = place_names_geojson)
  )
  layers <- lapply(spec$layers, function(l) {
    args <- c(l[setdiff(names(l), "id")], extra[[l$id]])
    do.call(ramb::rb_map_layer, c(list(id = l$id), args))
  })
  names(layers) <- vapply(spec$layers, `[[`, "", "id")
  groups <- lapply(spec$groups, function(g) ramb::rb_map_group(g$id, g$title, unname(layers[unlist(g$layers)]), g$open))
  do.call(ramb::rb_map, c(groups, list(
    title = spec$title, view = list(center = unlist(spec$view$center), zoom = spec$view$zoom), texts = spec$texts,
    languages = unlist(spec$languages), language = spec$language, locales = lapply(spec$locales, unlist),
    about = unlist(spec$about)
  )))
}

# The grid with each fix's hours in its own cell, beside the interpolated one
fixes_grid <- function(grid) sub("[.]parquet$", "_fixes.parquet", grid)

# The effort: ramb has checked the filters' values against map.json and effort_meta() before they arrive here.
# Interpolation off reads the grid of fixes alone.
effort_tiles <- function(con, grid) {
  function(z, x, y, p) {
    effort_tile(con, if (identical(p$interp, "off")) fixes_grid(grid) else grid, z, x, y,
                preset = if (is.null(p$preset)) "fishing" else p$preset,
                gid = if (!is.null(p$gid)) as.integer(strsplit(p$gid, ",", fixed = TRUE)[[1]]),
                y1 = if (!is.null(p$y1)) as.integer(p$y1), y2 = if (!is.null(p$y2)) as.integer(p$y2),
                px = if (is.null(p$px)) 1 else as.numeric(p$px))
  }
}

# The gear filter's options (every gear in the grid, by its hours under `fishing`), the years, and the grid's write
# time as its version, so a rebuilt grid is not hidden by the browser's cache
effort_meta <- function(con, grid) {
  g <- DBI::dbGetQuery(con, sprintf(
    "SELECT g.gid AS value, any_value(r.\"veiðarfæri\") AS name, any_value(r.gear) AS code,
            sum(g.h) FILTER (WHERE g.preset = 'fishing') AS h
     FROM read_parquet('%s') g LEFT JOIN read_parquet('%s') r ON r.gid = g.gid AND r.version = 'new'
     WHERE g.gid IS NOT NULL GROUP BY g.gid ORDER BY h DESC NULLS LAST",
    grid, fd_curated("reference", "gear.parquet")))
  y <- DBI::dbGetQuery(con, sprintf("SELECT min(year) AS y1, max(year) AS y2 FROM read_parquet('%s')", grid))
  list(options = list(gid = g[c("value", "name", "code")]), ranges = list(years = c(y$y1, y$y2)),
       v = max(as.numeric(file.mtime(c(grid, fixes_grid(grid)))), na.rm = TRUE))
}

# The ports: every port of the reference, its area or line, and a point on each for the far zooms
ports_tiles <- function(con, file = fd_curated("reference", "port_geometry.parquet")) {
  if (!file.exists(file)) return(structure(function(z, x, y) raw(0), count = 0L))
  ramb::rb_map_tiles_table(dplyr::tbl(con, dplyr::sql(sprintf("SELECT * FROM read_parquet('%s')", file))),
                           geometry = "geom", properties = c("pid", "port", "hid", "unlocode", "source"),
                           layer = "ports", points = "port_points")
}

# The gazetteer's names as GeoJSON, or NULL without it: its footprints and a label at each name's median position
# (kind label), with its minimum zoom and level, class, cross-check and candidate synonyms, and a label at each other
# place of a name that means several. `children` is empty for none and `n_places` for one, so the popup leaves them out
place_names_geojson <- function() {
  f <- fd_curated("place_name", "place_name.parquet")
  if (!file.exists(f)) return(NULL)
  p <- read_curated_sf(f)
  d <- sf::st_drop_geometry(p)
  parent <- d$name[match(d$parent_key, d$key)]
  src <- grep("^n_(trackwell|plotter|lmi|sjokort|fiskmerki|article|skjalfandi|isor|qgis|oracle|channel|uv)$", names(d), value = TRUE)
  used <- apply(d[src], 1, function(r) paste(sprintf("%s %s", sub("^n_", "", src[r > 0]), r[r > 0]), collapse = ", "))
  syn <- fd_curated("place_name", "synonym.parquet")
  syn_txt <- if (file.exists(syn)) {
    y <- nanoparquet::read_parquet(syn)
    y <- rbind(data.frame(key = y$key_a, other = y$name_b, relation = y$relation),
               data.frame(key = y$key_b, other = y$name_a, relation = y$relation))
    y <- y[!is.na(y$other), ]
    vapply(split(sprintf("%s (%s)", y$other, gsub("_", " ", y$relation)), y$key), function(v) paste(head(v, 6), collapse = "; "), "")
  } else character()
  props <- data.frame(key = d$key, name = d$name, n = d$n_positioned, sources = used, terrain = d$terrain,
                      depth = round(d$depth_m), gear = d$gear, parent = parent,
                      children = ifelse(d$n_children > 0, d$n_children, NA),
                      r80 = round(d$r80_km, 1), spellings = d$n_spelling, min_zoom = d$min_zoom, level = d$level,
                      class = d$class, outcome = d$outcome, families = d$families,
                      n_places = ifelse(d$n_places > 1, d$n_places, NA), synonyms = unname(syn_txt[d$key]))
  foot <- sf::st_sf(props, kind = "footprint", geometry = sf::st_geometry(p))[!sf::st_is_empty(p), ]
  lx <- if ("label_lon" %in% names(d)) d$label_lon else d$lon      # a square-placed name is written on the sea
  ly <- if ("label_lat" %in% names(d)) d$label_lat else d$lat
  has <- !is.na(lx)
  lab <- sf::st_sf(props[has, ], kind = "label",
                   geometry = sf::st_sfc(lapply(which(has), function(i) sf::st_point(c(lx[i], ly[i]))), crs = 4326))
  # a name's other places (two bays called Hlöðuvík) get a label each, at the place's median
  pl_file <- fd_curated("place_name", "place.parquet")
  other <- if (file.exists(pl_file)) {
    pl <- nanoparquet::read_parquet(pl_file); pl <- pl[!pl$main, ]
    i <- match(pl$key, props$key)
    sf::st_sf(props[i, ], kind = "label", geometry = sf::st_sfc(lapply(seq_len(nrow(pl)), function(k) sf::st_point(c(pl$lon[k], pl$lat[k]))),
                                                                crs = 4326))
  }
  lab$place <- 1L
  if (!is.null(other)) other$place <- pl$place
  tmp <- tempfile(fileext = ".geojson")
  sf::st_write(rbind(foot |> transform(place = NA_integer_), lab, other), tmp, driver = "GeoJSON", quiet = TRUE,
               layer_options = "COORDINATE_PRECISION=5")
  paste(readLines(tmp, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}
