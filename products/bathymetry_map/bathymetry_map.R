# bathymetry_map.R — the depth grid (TODO 185) on ramb's map viewer: the seabed's relief from the 50 m grid, shaded and
# coloured in the browser, the depth by cell to click, and the gazetteer's place names over them. bathymetry_map()
# opens it in RStudio's Viewer (or a browser).
# TODO 185, plan 046.
#
# Input:  $FISHYDATA/products/bathymetry_map/depth.mbtiles (dem.R), left out if it is not there;
#         grid_0010/, grid_0040.parquet and grid_0200.parquet (grid.R); the effort map's tile bounds, cell-size option
#         and place names (products/effort_map/tiles.R, map.R and map.json; plan 044's gazetteer); ramb's map viewer
#         (rb_map_*(), and for the relief its dem layer and rb_map_tiles_mbtiles(): ramb >= 2026.11.03)
# Output: bathymetry_map(), bathymetry_map_stop(); bathymetry_map_build() and depth_tile() in .bathymetry_map, for
#         server.R; a server on 127.0.0.1:<port> in this R session, in the background
#
# Use, from the fishycode root (an RStudio project opens there):
#   source("products/bathymetry_map/bathymetry_map.R")
#   bathymetry_map()
#   bathymetry_map(center = c(-22.5, 66.2), zoom = 9, palette = "etopo1_bathy", lang = "is")
#   bathymetry_map_stop()
#
# The server answers while the console is idle: a map waits while R runs something else.

source("R/paths.R")
source("R/write_curated.R")    # read_curated_sf(), for the place names

.bathymetry_map <- new.env()
.bathymetry_map$dir <- fd_path("products", "bathymetry_map")
# the effort map's tile bounds and place names, sourced rather than copied
sys.source("products/effort_map/tiles.R", envir = .bathymetry_map)
sys.source("products/effort_map/map.R", envir = .bathymetry_map)

local(envir = .bathymetry_map, {

# The cell's longitude side in ten-thousandths of a degree, its latitude side half that: about `px` screen pixels
# wide (a tile is 512), never below the base's 10. It is read from the coarsest level whose cells it holds whole
DEPTH_K <- c(10, 20, 40, 80, 200, 400, 800, 2000)
LEVELS <- c(10, 40, 200)
level_file <- function(dir, l) {
  if (l == 10) file.path(dir, "grid_0010", "*.parquet") else file.path(dir, sprintf("grid_%04d.parquet", l))
}

# One vector tile, layer `cells`: per cell its mean depth, in metres below sea level
depth_tile <- function(con, dir, z, x, y, px = 1) {
  target <- 360 / 2^z / 512 * px * 1e4
  k <- max(DEPTH_K[DEPTH_K <= max(target, 10)])
  ky <- k / 2
  file <- level_file(dir, max(LEVELS[k %% LEVELS == 0]))
  b <- tile_bounds(z, x, y)
  ix0 <- floor(b[["lon0"]] * 1e4 / k) * k - k; ix1 <- ceiling(b[["lon1"]] * 1e4 / k) * k + k
  iy0 <- floor(b[["lat0"]] * 1e4 / ky) * ky - ky; iy1 <- ceiling(b[["lat1"]] * 1e4 / ky) * ky + ky
  sql <- sprintf("
    WITH c AS (
      SELECT floor(ix / %1$d) AS cx, floor(iy / %10$d) AS cy, sum(depth * n) / sum(n) AS depth
      FROM read_parquet('%2$s') WHERE ix >= %3$d AND ix < %4$d AND iy >= %5$d AND iy < %6$d GROUP BY ALL),
    g AS (
      SELECT depth, cx * %1$d / 1e4 AS lon0, (cx + 1) * %1$d / 1e4 AS lon1,
                    cy * %10$d / 1e4 AS lat0, (cy + 1) * %10$d / 1e4 AS lat1 FROM c),
    m AS (
      SELECT depth,
             ST_MakeEnvelope(radians(lon0) * 6378137, ln(tan(pi() / 4 + radians(lat0) / 2)) * 6378137,
                             radians(lon1) * 6378137, ln(tan(pi() / 4 + radians(lat1) / 2)) * 6378137) AS env
      FROM g)
    SELECT ST_AsMVT({'geometry': ST_AsMVTGeom(env, ST_Extent(ST_TileEnvelope(%7$d, %8$d, %9$d)), 4096, 64, true),
                     'depth': CAST(depth AS FLOAT)}, 'cells', 4096) AS tile
    FROM m", k, file, ix0, ix1, iy0, iy1, z, x, y, ky)
  r <- DBI::dbGetQuery(con, sql)$tile[[1]]
  if (is.null(r)) raw(0) else r
}

# The relief's colours: a palette of the viewer's over depths spaced for the shelf, shallow to deep as the grid's;
# sea level (land and no value) clear
RELIEF_DEPTHS <- c(5, 10, 20, 30, 50, 75, 100, 150, 200, 300, 500, 750, 1000, 1500, 2000, 3000)
relief_colour <- function(colors) {
  col <- grDevices::colorRampPalette(colors)(length(RELIEF_DEPTHS))
  stops <- unlist(lapply(rev(seq_along(RELIEF_DEPTHS)), function(i) list(-RELIEF_DEPTHS[i], col[i])), recursive = FALSE)
  c(list("interpolate", list("linear"), list("elevation")), stops, list(-0.05, col[1], 0, "rgba(0,0,0,0)"))
}
relief_legend <- function(colors) {
  col <- grDevices::colorRampPalette(colors)(length(RELIEF_DEPTHS))
  i <- match(c(10, 50, 100, 200, 500, 1000, 2000), RELIEF_DEPTHS)
  lapply(i, function(k) list(swatch = list(fill = col[k]), label = sprintf("%s m", format(RELIEF_DEPTHS[k], big.mark = ","))))
}

# The seabed's relief from the elevation tiles, coloured and shaded in the page; the colours chosen there
relief_layer <- function(file) {
  palettes <- Filter(function(p) p$id %in% c("deep", "blues", "etopo1_bathy"), ramb::rb_map_palettes())
  ramb::rb_map_layer(
    "relief", "dem", label = "lyrRelief", info = "infoRelief", visible = TRUE,
    tiles = ramb::rb_map_tiles_mbtiles(file),
    style = list(
      list(id = "relief-colour", type = "color-relief",
           paint = list("color-relief-color" = relief_colour(palettes[[1]]$colors))),
      list(id = "relief-shade", type = "hillshade",
           paint = list("hillshade-exaggeration" = 0.6, "hillshade-shadow-color" = "#1b2a3a"))
    ),
    variants = list(label = "reliefColours", options = lapply(palettes, function(p) list(
      value = p$id, label = p$label, legend = relief_legend(p$colors),
      paint = list("relief-colour" = list("color-relief-color" = relief_colour(p$colors)))
    )))
  )
}

# The map: the relief and the depth by cell, the place names as the effort map draws them, with its texts
bathymetry_map_build <- function(con, dir, center = c(-19, 65), zoom = 6, lang = "en",
                                 json = file.path("products", "effort_map", "map.json")) {
  spec <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  pick <- function(x, id) Filter(function(l) identical(l$id, id), x)[[1]]
  nm <- pick(spec$layers, "names")
  px <- pick(pick(spec$layers, "effort")$filters, "px")
  # cells of 2 pixels: at 1, a tile at zoom 6-9 is 13-14 MB (2026-11-03); the base's cells still show from zoom 10
  px$default <- "2"
  names_layer <- do.call(ramb::rb_map_layer, c(list(id = "names"), nm[setdiff(names(nm), "id")],
                                               list(data = place_names_geojson)))
  depth <- ramb::rb_map_layer(
    "depth", "grid", label = "lyrDepth", info = "infoDepth", visible = FALSE, source_layer = "cells",
    minzoom = 2, maxzoom = 14, opacity = 100,
    tiles = function(z, x, y, p) depth_tile(con, dir, z, x, y, px = as.numeric(if (is.null(p$px)) px$default else p$px)),
    meta = function() list(v = max(as.numeric(file.mtime(Sys.glob(vapply(LEVELS, level_file, "", dir = dir)))))),
    filters = list(px, list(id = "metric", type = "metric", label = "metric")),
    metrics = list(list(field = "depth", label = "depthM")),
    popup = list(fields = list(list(field = "depth", label = "depthM", format = "value")))
  )
  texts <- c(spec$texts[setdiff(names(spec$texts), c("title", unlist(spec$about)))], list(
    title = list(en = "Depth: Olex 50 m with GEBCO", is = "Dýpi: Olex 50 m með GEBCO"),
    gDepth = list(en = "Depth", is = "Dýpi"),
    lyrRelief = list(en = "Seabed relief", is = "Lögun hafsbotns"),
    reliefColours = list(en = "Colours", is = "Litir"),
    infoRelief = list(
      en = paste("Olex's 50 m depth grid with GEBCO, as elevation tiles (Terrarium, lossless WebP, to 0.1 m, zoom 0-10),",
                 "shaded and coloured in the browser; land and cells with no value are clear. TODO 185."),
      is = paste("50 m dýptargrunnur Olex með GEBCO sem hæðarflísar (Terrarium, WebP án taps, 0,1 m, aðdráttur 0-10),",
                 "skyggður og litaður í vafranum; land og reitir án gildis eru gegnsæir. TODO 185.")
    ),
    lyrDepth = list(en = "Depth by cell", is = "Dýpi eftir reitum"),
    depthM = list(en = "Depth (m)", is = "Dýpi (m)"),
    infoDepth = list(
      en = paste("Olex's 50 m depth grid with GEBCO filling the gaps, shared by Julian Burgos (MFRI), averaged into",
                 "cells of 0.001 by 0.0005 degrees (about 47 by 56 m at 65 N), coarser at far zooms; metres below sea",
                 "level. A first view (TODO 185)."),
      is = paste("50 m dýptargrunnur Olex, GEBCO í eyðum, frá Julian Burgos (Hafrannsóknastofnun), meðaltal í reitum",
                 "0,001 x 0,0005 gráður (um 47 x 56 m á 65° N), grófari fjær; metrar undir sjávarmáli. Fyrsta sýn",
                 "(TODO 185).")
    )
  ))
  dem <- file.path(dir, "depth.mbtiles")
  ramb::rb_map(
    ramb::rb_map_group("depth", "gDepth", c(if (file.exists(dem)) list(relief_layer(dem)), list(depth))),
    ramb::rb_map_group("ref", "gRef", list(names_layer)),
    title = "title", view = list(center = center, zoom = zoom), texts = texts,
    languages = unlist(spec$languages), language = lang, locales = lapply(spec$locales, unlist), palette = "deep"
  )
}

})

bathymetry_map <- function(center = c(-19, 65), zoom = 6, palette = "deep", base = "light", lang = c("en", "is"),
                           port = 8798, viewer = TRUE) {
  lang <- match.arg(lang)
  palettes <- vapply(ramb::rb_map_palettes(), `[[`, "", "id")
  bases <- vapply(ramb::rb_map_basemaps(), `[[`, "", "id")
  if (!palette %in% palettes) stop("palette is one of ", paste(palettes, collapse = ", "), call. = FALSE)
  if (!base %in% bases) stop("base is one of ", paste(bases, collapse = ", "), call. = FALSE)
  bathymetry_map_stop()
  e <- .bathymetry_map
  e$con <- DBI::dbConnect(duckdb::duckdb())
  invisible(DBI::dbExecute(e$con, "LOAD spatial"))
  m <- e$bathymetry_map_build(e$con, e$dir, center = center, zoom = zoom, lang = lang)
  q <- list(palette = palette, base = if (base != "light") base)
  url <- ramb::rb_map_serve(m, port = port, open = viewer, query = Filter(Negate(is.null), q))
  e$port <- port
  invisible(url)
}

bathymetry_map_stop <- function() {
  e <- .bathymetry_map
  if (!is.null(e$port)) ramb::rb_map_stop(e$port)
  if (!is.null(e$con)) DBI::dbDisconnect(e$con, shutdown = TRUE)
  e$con <- e$port <- NULL
  invisible()
}
