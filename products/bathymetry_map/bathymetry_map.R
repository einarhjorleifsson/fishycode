# bathymetry_map.R — the depth grid (TODO 185) on ramb's map viewer: from the 50 m grid's elevation tiles, the depth
# coloured and the relief shaded in the browser, two layers with their own controls (plan 063); the depth by cell to
# click; the gazetteer's place names over them. bathymetry_map() opens it in RStudio's Viewer (or a browser).
# TODO 185, plan 046.
#
# Input:  $FISHYDATA/products/bathymetry_map/depth.mbtiles (dem.R), left out if it is not there;
#         grid_0010/, grid_0040.parquet and grid_0200.parquet (grid.R); the effort map's tile bounds, cell-size option
#         and place names (products/effort_map/tiles.R, map.R and map.json; plan 044's gazetteer); ramb's map viewer
#         (rb_map_*(), and for the depth and relief its dem layer, rb_map_tiles_mbtiles() and their controls,
#         `colour` and `shade`, and its contour layer: ramb >= 2026.11.03.3)
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

# The depth from the elevation tiles, coloured in the page: palette, floor and cap, scale, ramp or bands (the charts'
# isobaths), a cut of the shallow end and opacity in the reader's hands (plan 063 step 2); the depths under 10-20 m are
# poorly covered (the maintainer), so a cut is offered, none by default. The floor and cap follow the view (plan 063
# point 7(a)): the 2nd and 98th percentiles of the depths in it, as the depth by cell's are fitted
depth_layer <- function(file, con, dir) {
  ramb::rb_map_layer(
    "depth", "dem", label = "lyrDepthColour", info = "infoDepthColour", visible = TRUE,
    tiles = ramb::rb_map_tiles_mbtiles(file),
    style = list(list(id = "depth-colour", type = "color-relief")),
    colour = list(palette = "deep", floor = 10, cap = 2000, fit = depth_fit(con, dir))
  )
}

# A view's floor and cap, the 2nd and 98th percentiles of grid.R's cells in its box, to two figures, and 25 quantiles
# from the one to the other, for colours in equal shares (plan 063 point 8(a)); from the finest level that holds at most
# 4 million cells there (a base cell is 0.001 by 0.0005 degrees; a cell of level 40 holds 16 of them, of 200, 400);
# NULL where the box has no sea
depth_fit <- function(con, dir) {
  probs <- seq(0.02, 0.98, length.out = 25)
  function(west, south, east, north) {
    base <- (east - west) / 0.001 * (north - south) / 0.0005
    level <- if (base <= 4e6) 10 else if (base / 16 <= 4e6) 40 else 200
    q <- DBI::dbGetQuery(con, sprintf(
      "SELECT quantile_cont(depth, [%s]) AS q FROM read_parquet('%s')
       WHERE ix >= %.0f AND ix < %.0f AND iy >= %.0f AND iy < %.0f",
      paste(probs, collapse = ", "), level_file(dir, level),
      floor(west * 1e4), ceiling(east * 1e4), floor(south * 1e4), ceiling(north * 1e4)))$q[[1]]
    if (is.null(q) || anyNA(q)) return(NULL)
    lo <- max(1, signif(q[1], 2))
    list(floor = lo, cap = min(10000, max(lo * 1.5, signif(q[length(q)], 2))), quantiles = round(q, 1))
  }
}

# Depth contours made in the browser from the same tiles (plan 063 step 3), spaced by depth as well as by zoom (its
# point 7: by zoom alone, Faxaflói's 20-100 m had none at zoom 8): from each zoom, the spacing kept under 50 m, from 50
# to 200 m, from 200 to 1,000 m and deeper. maplibre-contour takes intervals by zoom only, so it makes the lines at
# their greatest common spacing and one layer per zoom range keeps those at their depth's (a layer's filter, as a
# filter may not read the zoom). The charts' isobaths are the major lines, heavier and labelled; sea level left out
CONTOUR_BANDS <- c(0, 50, 200, 1000)
CONTOUR_SPACING <- list("5" = c(25, 50, 100, 500), "7" = c(10, 50, 100, 500), "8" = c(10, 20, 100, 200),
                        "9" = c(10, 20, 50, 200), "10" = c(5, 10, 50, 100), "11" = c(5, 10, 20, 100))
ISOBATHS <- c(10, 20, 50, 100, 200, 500, 1000, 1500, 2000, 2500, 3000)
contour_layer <- function(file, con, dir) {
  ele <- list("get", "ele")
  gcd <- function(a, b) if (b == 0) a else gcd(b, a %% b)
  major <- list("in", ele, list("literal", as.list(ISOBATHS)))
  # a line at its depth's spacing: over the band's top (sea level itself left out), under its bottom; and every isobath
  # as deep as the shallowest spacing (50 m sits in a band spaced 20 m at zoom 8)
  kept <- function(s) c(list("any"), lapply(seq_along(s), function(i) {
    c(list("all", list(if (i == 1) ">" else ">=", ele, CONTOUR_BANDS[i])),
      if (i < length(CONTOUR_BANDS)) list(list("<", ele, CONTOUR_BANDS[i + 1])),
      list(list("==", list("%", ele, s[i]), 0)))
  }), list(list("all", major, list(">=", ele, s[1]))))
  zooms <- as.numeric(names(CONTOUR_SPACING))
  style <- unlist(lapply(seq_along(zooms), function(k) {
    z <- c(minzoom = zooms[k], maxzoom = if (k < length(zooms)) zooms[k + 1] else 24)
    f <- kept(CONTOUR_SPACING[[k]])
    list(
      list(id = sprintf("contours-line-%d", zooms[k]), type = "line", "source-layer" = "contours",
           minzoom = z[["minzoom"]], maxzoom = z[["maxzoom"]], filter = f,
           paint = list("line-color" = "rgba(27,42,58,0.55)", "line-width" = list("case", major, 1.2, 0.5))),
      list(id = sprintf("contours-label-%d", zooms[k]), type = "symbol", "source-layer" = "contours",
           minzoom = z[["minzoom"]], maxzoom = z[["maxzoom"]], filter = list("all", f, major),
           layout = list("symbol-placement" = "line", "text-size" = 13,
                         "text-field" = list("concat", list("number-format", ele, structure(list(), names = character())),
                                             " m")),
           paint = list("text-color" = "#1b2a3a"))
    )
  }), recursive = FALSE)
  ramb::rb_map_layer(
    "contours", "contour", label = "lyrContours", info = "infoContours", visible = TRUE,
    tiles = ramb::rb_map_tiles_mbtiles(file),
    # following the view (plan 063 point 8(b)): levels from the view's quantiles, the same fit as the colours'; the
    # spacing above when the reader unticks it
    contours = list(multiplier = -1, thresholds = lapply(CONTOUR_SPACING, function(s) Reduce(gcd, s)),
                    fit = depth_fit(con, dir)),
    style = style,
    legend = list(list(swatch = list(fill = "rgba(27,42,58,0.55)"), label = "contourMinor"),
                  list(swatch = list(fill = "#1b2a3a"), label = "contourMajor"))
  )
}

# The relief from the same tiles, shaded in the page, its method, light, intensity, opacity and colours in the
# reader's hands (plan 063 step 1)
relief_layer <- function(file) {
  ramb::rb_map_layer(
    "relief", "dem", label = "lyrRelief", info = "infoRelief", visible = TRUE,
    tiles = ramb::rb_map_tiles_mbtiles(file),
    style = list(list(id = "relief-shade", type = "hillshade")),
    shade = list(exaggeration = 0.6, shadow = "#1b2a3a")
  )
}

# The map: the depth and the relief, the depth by cell, the place names as the effort map draws them, with its texts
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
    "cells", "grid", label = "lyrDepth", info = "infoDepth", visible = FALSE, source_layer = "cells",
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
    gRelief = list(en = "Relief", is = "Lögun hafsbotns"),
    lyrDepthColour = list(en = "Depth (50 m)", is = "Dýpi (50 m)"),
    lyrRelief = list(en = "Shading", is = "Skygging"),
    infoDepthColour = list(
      en = paste("Olex's 50 m depth grid with GEBCO, as elevation tiles (Terrarium, lossless WebP, to 0.1 m, zoom 0-10),",
                 "coloured in the browser; land and cells with no value are clear. TODO 185."),
      is = paste("50 m dýptargrunnur Olex með GEBCO sem hæðarflísar (Terrarium, WebP án taps, 0,1 m, aðdráttur 0-10),",
                 "litaður í vafranum; land og reitir án gildis eru gegnsæir. TODO 185.")
    ),
    infoRelief = list(
      en = paste("The same tiles, shaded in the browser: the method, the light, the intensity, the opacity and the",
                 "colours apply as they move. Plan 063."),
      is = paste("Sömu flísar, skyggðar í vafranum: aðferð, ljós, styrkur, ógegnsæi og litir breytast um leið.",
                 "Áætlun 063.")
    ),
    shMethod = list(en = "Shading", is = "Aðferð"), shStandard = list(en = "standard", is = "venjuleg"),
    shBasic = list(en = "basic", is = "einföld"), shCombined = list(en = "combined", is = "blönduð"),
    shIgor = list(en = "igor (soft)", is = "igor (mjúk)"), shMulti = list(en = "several lights", is = "mörg ljós"),
    shDirection = list(en = "Light from", is = "Ljós úr átt"), shAltitude = list(en = "Light height", is = "Hæð ljóss"),
    shIntensity = list(en = "Intensity", is = "Styrkur"), shShadow = list(en = "Shadow", is = "Skuggi"),
    shHighlight = list(en = "Light", is = "Birta"),
    cScale = list(en = "Scale", is = "Kvarði"), cLog = list(en = "log", is = "lógaritmískur"),
    cLinear = list(en = "linear", is = "línulegur"), cMode = list(en = "Colours as", is = "Litir sem"),
    cRamp = list(en = "a ramp", is = "samfelldur kvarði"), cBands = list(en = "bands", is = "bil"),
    cCut = list(en = "Shallower than", is = "Grynnra en"), cNone = list(en = "none", is = "ekkert"),
    cCutAs = list(en = "drawn", is = "sýnt"), cClear = list(en = "clear", is = "gegnsætt"),
    cGrey = list(en = "grey", is = "grátt"),
    cFitTip = list(en = "Floor and cap at the 2nd and 98th percentiles of the depths in view",
                   is = "Lágmark og hámark við 2. og 98. hundraðshluta dýpis í sýn"),
    cFitNone = list(en = "no depths in view to fit to", is = "ekkert dýpi í sýn að laga að"),
    cAuto = list(en = "follow the view", is = "fylgja sýn"),
    kAuto = list(en = "levels from the view", is = "dýpi lína eftir sýn"),
    kAutoTip = list(en = "About a dozen lines at round depths near the view's quantiles, so they fall where the area is; unticked, the fixed spacing by depth and zoom",
                    is = "Um tólf línur á sléttu dýpi nærri hundraðshlutum sýnar, þar sem flatarmálið er; án hennar föst bil eftir dýpi og aðdrætti"), cEqual = list(en = "equal shares", is = "jafnir hlutar"),
    cAutoTip = list(en = "Fit the floor and cap to the view each time it settles; setting either by hand stops it",
                    is = "Laga lágmark og hámark að sýn í hvert sinn sem kortið stöðvast; handstilling stöðvar það"),
    lyrContours = list(en = "Contours", is = "Dýptarlínur"),
    contourMinor = list(en = "contour", is = "dýptarlína"),
    contourMajor = list(en = "a chart isobath, with its depth", is = "jafndýpislína korta, með dýpi"),
    infoContours = list(
      en = paste("Depth contours made in the browser from the same elevation tiles (maplibre-contour), spaced by depth",
                 "and zoom: denser in shallow water and as you zoom in (under 50 m every 25 m at zoom 5, every 5 m from",
                 "10; deeper than 1,000 m every 500 m to every 100 m). The charts' isobaths heavier, labelled from",
                 "zoom 11. Plan 063."),
      is = paste("Dýptarlínur reiknaðar í vafranum úr sömu hæðarflísum (maplibre-contour), eftir dýpi og aðdrætti:",
                 "þéttari á grunnu vatni og við aðdrátt (grynnra en 50 m á 25 m í aðdrætti 5, á 5 m frá 10; dýpra en",
                 "1.000 m á 500 m til 100 m). Jafndýpislínur korta feitari, merktar frá aðdrætti 11. Áætlun 063.")
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
  has_dem <- file.exists(dem)
  groups <- c(
    list(ramb::rb_map_group("depth", "gDepth", c(if (has_dem) list(depth_layer(dem, con, dir), contour_layer(dem, con, dir)),
                                                  list(depth)))),
    if (has_dem) list(ramb::rb_map_group("relief", "gRelief", list(relief_layer(dem)))),
    list(ramb::rb_map_group("ref", "gRef", list(names_layer)))
  )
  do.call(ramb::rb_map, c(groups, list(
    title = "title", view = list(center = center, zoom = zoom), texts = texts,
    languages = unlist(spec$languages), language = lang, locales = lapply(spec$locales, unlist), palette = "deep"
  )))
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
