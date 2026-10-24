# app.R — the effort map's web app: the page, /meta and the vector tiles, as an httpuv app.
# Decision 220. Used by server.R (a terminal) and effort_map.R (an R session).
#
# Input:  the base grid `grid` (grid.R), the page in the folder `www`; $FISHYDATA/curated/reference/gear.parquet;
#         effort_tile() from tiles.R, sourced by the caller with this file; $FISHYDATA/curated/place_name/place_name.parquet
#         (plan 044), read once if it is there
# Output: effort_map_app(con, grid, www), an httpuv app:
#   /                                   the page; its query string sets the first view (effort_map.R)
#   /meta                               the gears (with their hours), the years, the grid's version and the app's, as JSON
#   /place_names.geojson                the gazetteer's names: a footprint per name that has one (kind footprint) and a
#                                       label at each name's median position (kind label), with its minimum zoom and
#                                       level, class, cross-check and candidate synonyms, and a label at each other
#                                       place of a name that means several (place.parquet); 404 without the gazetteer
#   /tiles/{z}/{x}/{y}.pbf?preset=fishing|fishing_flow&gid=6,7&y1=2015&y2=2020&px=1
#                                       one vector tile (tiles.R); gid, y1/y2 and px may be left out

APP_VERSION <- 4L     # what effort_map.R asks of a server on its port, and the page's APP: changed together
PX <- c(0.5, 1, 2)    # the page's cell sizes, in screen pixels per cell

effort_map_app <- function(con, grid, www) {
  meta <- local({
    g <- DBI::dbGetQuery(con, sprintf(
      "SELECT g.gid, any_value(r.\"veiðarfæri\") AS name, any_value(r.gear) AS fao, sum(g.h) AS h
       FROM read_parquet('%s') g LEFT JOIN read_parquet('%s') r ON r.gid = g.gid AND r.version = 'new'
       WHERE g.preset = 'fishing' AND g.gid IS NOT NULL GROUP BY g.gid ORDER BY h DESC",
      grid, fd_curated("reference", "gear.parquet")))
    y <- DBI::dbGetQuery(con, sprintf("SELECT min(year) AS y1, max(year) AS y2 FROM read_parquet('%s')", grid))
    list(gears = g, y1 = y$y1, y2 = y$y2, app = APP_VERSION)
  })

  # The gazetteer's names as GeoJSON, made once: its footprints and a label point per name with a position
  place_names <- local({
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
                        depth = round(d$depth_m), gear = d$gear, parent = parent, children = d$n_children,
                        r80 = round(d$r80_km, 1), spellings = d$n_spelling, min_zoom = d$min_zoom, level = d$level,
                        class = d$class, outcome = d$outcome, families = d$families, n_places = d$n_places,
                        synonyms = unname(syn_txt[d$key]))
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
  })

  parse_query <- function(q) {
    kv <- strsplit(strsplit(sub("^[?]", "", q %||% ""), "&", fixed = TRUE)[[1]], "=", fixed = TRUE)
    stats::setNames(lapply(kv, function(x) httpuv::decodeURIComponent(if (length(x) > 1) x[2] else "")),
                    vapply(kv, `[`, "", 1))
  }
  whole <- function(x, lo, hi) {
    if (is.null(x) || !grepl("^[0-9]+$", x)) return(NULL)
    v <- as.integer(x)
    if (v < lo || v > hi) NULL else v
  }
  reply <- function(status, body, type = "text/plain; charset=utf-8", headers = list())
    list(status = status, headers = c(list(`Content-Type` = type), headers), body = body)

  list(call = function(req) {
    path <- req$PATH_INFO
    if (req$REQUEST_METHOD != "GET") return(reply(405L, "GET only"))
    if (path == "/") return(reply(200L, paste(readLines(file.path(www, "index.html"), warn = FALSE, encoding = "UTF-8"),
                                              collapse = "\n"), "text/html; charset=utf-8", list(`Cache-Control` = "no-store")))
    # v, the grid's write time, goes into the tile address, so a rebuilt grid is not hidden by the browser's cache
    if (path == "/meta") return(reply(200L, as.character(jsonlite::toJSON(c(meta, v = as.numeric(file.mtime(grid))),
                                                                         auto_unbox = TRUE, digits = NA)),
                                       "application/json; charset=utf-8", list(`Cache-Control` = "no-store")))
    if (path == "/place_names.geojson")
      return(if (is.null(place_names)) reply(404L, "no gazetteer: build curated/place_name (plan 044)")
             else reply(200L, place_names, "application/geo+json; charset=utf-8", list(`Cache-Control` = "no-store")))
    m <- regmatches(path, regexec("^/tiles/([0-9]+)/([0-9]+)/([0-9]+)[.]pbf$", path))[[1]]
    if (length(m) != 4) return(reply(404L, "not found"))
    z <- whole(m[2], 0L, 16L)
    if (is.null(z)) return(reply(400L, "z is 0-16"))
    x <- whole(m[3], 0L, 2L^z - 1L); y <- whole(m[4], 0L, 2L^z - 1L)
    if (is.null(x) || is.null(y)) return(reply(400L, "x and y lie in the zoom's range"))
    a <- parse_query(req$QUERY_STRING)
    preset <- a$preset %||% "fishing"
    if (!preset %in% c("fishing", "fishing_flow")) return(reply(400L, "preset is fishing or fishing_flow"))
    gid <- if (!is.null(a$gid) && nzchar(a$gid)) {
      g <- strsplit(a$gid, ",", fixed = TRUE)[[1]]
      if (!all(grepl("^[0-9]{1,4}$", g))) return(reply(400L, "gid is whole numbers, comma separated"))
      as.integer(g)
    }
    y1 <- whole(a$y1, 1900L, 2100L); y2 <- whole(a$y2, 1900L, 2100L)
    if (xor(is.null(y1), is.null(y2))) return(reply(400L, "y1 and y2 are years, given together"))
    px <- suppressWarnings(as.numeric(a$px %||% "1"))
    if (!isTRUE(px %in% PX)) return(reply(400L, paste("px is one of", paste(PX, collapse = ", "))))
    t0 <- Sys.time()
    body <- effort_tile(con, grid, z, x, y, preset, gid, y1, y2, px)
    reply(200L, body, "application/vnd.mapbox-vector-tile",
          list(`Cache-Control` = "max-age=600",
               `X-Server-Ms` = sprintf("%.0f", 1000 * as.numeric(difftime(Sys.time(), t0, units = "secs")))))
  })
}
