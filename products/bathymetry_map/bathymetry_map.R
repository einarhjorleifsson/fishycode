# bathymetry_map.R — the depth grid (TODO 185) on ramb's map viewer: from the 50 m grid's elevation tiles, the depth
# coloured and the relief shaded in the browser, two layers with their own controls (plan 063); the depth by cell to
# click; the gazetteer's place names over them. bathymetry_map() opens it in RStudio's Viewer (or a browser).
# TODO 185, plan 046.
#
# Input:  $FISHYDATA/products/bathymetry_map/depth.mbtiles (dem.R), left out if it is not there;
#         grid_0010/, grid_0040.parquet and grid_0200.parquet (grid.R); the effort map's tile bounds, cell-size option
#         and place names (products/effort_map/tiles.R, map.R and map.json; plan 044's gazetteer), and its ports
#         ($FISHYDATA/curated/reference/port_geometry.parquet, left out if it is not there); ramb's map viewer
#         (rb_map_*(), and for the depth and relief its dem layer, rb_map_tiles_mbtiles() and their controls,
#         `colour` and `shade`, and its contour layer: ramb >= 2026.11.03.3; the place names' controls, map.json's
#         `state`: ramb >= 2026.11.04.1)
# Output: bathymetry_map(), bathymetry_map_stop(); bathymetry_map_build() and depth_tile() in .bathymetry_map, for
#         server.R; a server on 127.0.0.1:<port> in this R session, in the background
#
# Use, from the fishycode root (an RStudio project opens there):
#   source("products/bathymetry_map/bathymetry_map.R")
#   bathymetry_map()
#   bathymetry_map(center = c(-22.5, 66.2), zoom = 9, palette = "seabed", lang = "is")
#   bathymetry_map(depth_colour = list(palette = "quiet"))     # what the depth's colour controls open with
#   bathymetry_map(layers = list(<rb_map_layer>), texts = list(<its labels>))   # a study's layer beside the names
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

# Palettes this map adds to ramb's: "quiet", pale cyan-grey to a mid grey-blue, low in chroma and stopping at mid
# lightness (OKLab L 0.93 to 0.59 in even steps; ramb's "deep" goes 0.99 to 0.26), so the relief's shading still reads
# through the depth's colour (the maintainer, 2026-11-09, liked the relief and contours with no colour at all; study
# $FISHYDATA/archive/2026-11-09-seabed-colour/). Hue 200 to 245 and chroma 8 to 32 in HCL; first made from L 0.96,
# whose shallow end sat 0.014 from the base map's landcover and read as land in Breiðafjörður, so its light end was
# darkened, hue and chroma kept (the maintainer: "Yes, fix quiet"; 04_looks.R). The depth opens with it since
# 2026-11-09 (the maintainer: "Yes, make default"). "seabed", the same study's look the maintainer
# liked ("seabed guess, fading with depth"), by depth alone: sand shading into mud, seen through the water, red lost
# first; its nine stops at even OKLab lightness, 0.84 to 0.40 (the study's 03_seabed_palette.R). A look, not a
# substrate: the grid's roughness and hollows proved no witness of the seabed (02_marks_vs_grid.R). Two more, each for
# a use the others lack, designed in OKLCh and measured (the study's 04_looks.R): "chart", the sea's one colour
# convention, the nautical chart's: shallow water blue, deep water near white (L 0.70 to 0.95, hue 240), so the
# shallows stand out and the relief reads in the deeps; it runs dark to light, as the page goes shallow to deep.
# "grey", a ground for other layers (effort, names, marks): L 0.94 to 0.58, chroma under 0.01, so it pulls no
# overlay's hue (by hue alone the nearest any overlay comes is 0.042 in OKLab, against 0.005 to 0.016 for the
# others). Each palette's ends are held off the base map's land (#FAFAF8 and its landcover's green): quiet's shallow
# end 0.037, chart's deep end 0.027, grey's shallow end 0.035. Two daring ones, from tidyterra 1.3.0's palettes (the
# study's 05_daring.R), each resampled to 17 stops at even steps along its path in OKLab, its whitest stops (L over
# 0.92) dropped first so the shallowest water stays off the land (0.124 and 0.165): "drained", the seabed as land, as
# if the sea were drained: gmt_globe_hypso, the land palette of the widest span (0 to 10,000 m), the deeps its green
# lowland, the banks its ochre and brown hills, the shallowest its grey rock; "haxby", marine geology's multibeam
# palette (Haxby's, as GMT and GRASS carry it), orange shallows through green and cyan to deep blue. Both lean on hue,
# so a colour-blind reader parts their neighbours less well (0.023 and 0.024 at the smallest). All belong in ramb's
# rb_map_palettes() when ramb's viewer is next opened
BATHY_PALETTES <- list(
  list(id = "quiet", label = "quiet", source = "fishycode, HCL",
       colors = c("#DFECEE", "#CBE0E3", "#B9D2D8", "#A9C4CE", "#99B7C4", "#8AA9BB", "#7D9BB0", "#708DA7", "#657E9E")),
  list(id = "seabed", label = "seabed (sand to deep water)", source = "fishycode, sand and mud through water",
       colors = c("#D8CAA2", "#B2BEA9", "#9AADA1", "#869D96", "#738C8B", "#5F7D81", "#4B6D78", "#3C5C6D", "#2E4C61")),
  list(id = "chart", label = "chart (shallow blue, deep white)", source = "fishycode, OKLCh, after the nautical chart",
       colors = c("#60A7D6", "#75B0D9", "#87B9DC", "#99C2DF", "#AACBE3", "#BAD4E7", "#CADDEB", "#D8E6F1", "#E5F0F8")),
  list(id = "grey", label = "grey (under other layers)", source = "fishycode, OKLCh",
       colors = c("#E7EAED", "#D8DBDE", "#CACDD0", "#BBBFC2", "#ADB1B5", "#9FA3A7", "#91959A", "#84888C", "#767B80")),
  list(id = "drained", label = "drained (the seabed as land)", source = "tidyterra gmt_globe_hypso, resampled",
       colors = c("#CCCCCC", "#C1ACAC", "#B68C8C", "#AC6B6B", "#9F5E45", "#9B6F05", "#A48F18", "#C7A224", "#E6B858",
                  "#F7D09A", "#E7E0AA", "#B0E28D", "#6DD474", "#35BF5B", "#37A041", "#378325", "#336600")),
  list(id = "haxby", label = "haxby (multibeam)", source = "tidyterra grass haxby, resampled",
       colors = c("#FFBA85", "#FFA44C", "#FFB955", "#F9D568", "#ECEF7F", "#C6FDA4", "#99F0AC", "#7EECD0", "#6BEBFD",
                  "#52D7FF", "#37C1FF", "#2CAAFE", "#2893FD", "#287BF6", "#2865DE", "#274FC6", "#2539AF"))
)
# The map offers a short list, seven looks to pick between (the maintainer, 2026-11-09: "the user can select between
# certain limited preset options", "5 base options", "make that actually two daring ones"): quiet (the default),
# seabed, ramb's deep, chart and grey, and the daring drained and haxby; the depth's checkbox off leaves the relief
# alone, the look the maintainer first liked. A map of its own that wants other palettes (products/depth_effort_map/)
# passes "all": ramb's twelve and these
bathymetry_palettes <- function(which = c("short", "all")) {
  all <- c(ramb::rb_map_palettes(), BATHY_PALETTES)
  if (match.arg(which) == "all") return(all)
  all[match(c("quiet", "seabed", "deep", "chart", "grey", "drained", "haxby"), vapply(all, `[[`, "", "id"))]
}

# The depth from the elevation tiles, coloured in the page: palette, floor and cap, scale, ramp or bands (the charts'
# isobaths), a cut of the shallow end and opacity in the reader's hands (plan 063 step 2); the depths under 10-20 m are
# poorly covered (the maintainer), so a cut is offered, none by default. The floor and cap follow the view (plan 063
# point 7(a)): the 2nd and 98th percentiles of the depths in it, as the depth by cell's are fitted. It opens with the
# quiet palette in equal shares (2026-11-09: on a log scale Faxaflói's 40-75 m took the palette's two darkest steps
# and read as one tone; in equal shares its plateau, channels and rim part). `colour` changes what the page opens with
# (a map of its own, products/depth_effort_map/)
depth_layer <- function(file, con, dir, colour = list()) {
  ramb::rb_map_layer(
    "depth", "dem", label = "lyrDepthColour", info = "infoDepthColour", visible = TRUE,
    tiles = ramb::rb_map_tiles_mbtiles(file),
    style = list(list(id = "depth-colour", type = "color-relief")),
    colour = utils::modifyList(list(palette = "quiet", scale = "equal", floor = 10, cap = 2000,
                                    fit = depth_fit(con, dir)), colour)
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
           # along a line MapLibre fits a label only where the line bends under its 45 degrees over the label's length,
           # and the 50 m grid's contours wiggle at screen scale: 1 label on some 30 lines at zoom 8 (2026-11-06, the
           # maintainer: "can you add depth indicator on contour lines"); 180 degrees and a label every 200 px placed
           # 20, with a halo to read on the depth's colours
           layout = list("symbol-placement" = "line", "text-size" = 13, "text-max-angle" = 180, "symbol-spacing" = 200,
                         "text-field" = list("concat", list("number-format", ele, structure(list(), names = character())),
                                             " m")),
           paint = list("text-color" = "#1b2a3a", "text-halo-color" = "#ffffff", "text-halo-width" = 1.5))
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
# reader's hands (plan 063 step 1); the intensity following the view (point 8(c)). `shade` changes what the page opens
# with
relief_layer <- function(file, con, dir, shade = list()) {
  ramb::rb_map_layer(
    "relief", "dem", label = "lyrRelief", info = "infoRelief", visible = TRUE,
    tiles = ramb::rb_map_tiles_mbtiles(file),
    style = list(list(id = "relief-shade", type = "hillshade")),
    shade = utils::modifyList(list(exaggeration = 0.6, shadow = "#1b2a3a", fit = relief_fit(con, dir)), shade)
  )
}

# A view's shading intensity: 2 over the 90th percentile of the seabed's slope in it, in degrees, kept between 0.3 and
# 1, so a gentle view is shaded harder. The slope from each cell's step to its east and north neighbours, on the level
# depth_fit() reads, about a cell a screen pixel. Measured 2026-11-03 (p90): the shelf edge west at zoom 8 1.1 degrees,
# Faxaflói at 9 1.5, all of Iceland at 6 1.8, the deep south at 7 2.4, Ísafjarðardjúp at 9 4.1; 20-60 ms
relief_fit <- function(con, dir) {
  function(west, south, east, north) {
    base <- (east - west) / 0.001 * (north - south) / 0.0005
    level <- if (base <= 4e6) 10 else if (base / 16 <= 4e6) 40 else 200
    dx <- level * 1e-4 * 111320 * cos((south + north) / 2 * pi / 180)
    dy <- level / 2 * 1e-4 * 110574
    p90 <- DBI::dbGetQuery(con, sprintf(
      "WITH c AS (SELECT ix, iy, depth FROM read_parquet('%s')
                  WHERE ix >= %.0f AND ix < %.0f AND iy >= %.0f AND iy < %.0f)
       SELECT quantile_cont(degrees(atan(sqrt(pow((e.depth - c.depth) / %f, 2) + pow((n.depth - c.depth) / %f, 2)))), 0.9)
              AS p90
       FROM c JOIN c e ON e.ix = c.ix + %d AND e.iy = c.iy JOIN c n ON n.ix = c.ix AND n.iy = c.iy + %d",
      level_file(dir, level), floor(west * 1e4), ceiling(east * 1e4), floor(south * 1e4), ceiling(north * 1e4),
      dx, dy, level, level / 2))$p90
    if (!length(p90) || is.na(p90) || p90 <= 0) return(NULL)
    list(exaggeration = min(1, max(0.3, 2 / p90)))
  }
}

# The map: the depth and the relief, the depth by cell, the place names as the effort map draws them, with its texts;
# `extra` layers join the names in the reference group, `extra_texts` their labels (TODO 186: the chart names read)
# or over this map's own. For a map that adds a grid of its own (products/depth_effort_map/): `cells = FALSE` leaves
# out the depth by cell, as ramb draws one grid a map; `groups` go between the relief and the reference layers;
# `palette` is the grid's when the page opens; `about` names the texts of an About section. What the page opens with:
# `depth_colour` over the depth's colour controls, `relief_shade` over the relief's, `names_state` the place names'
# controls by id; `palettes` the list offered, the short one by default; `ports` the harbours beside the place names;
# `names_popup` merged into the place names' popup (a study's review: ramb's `verdict`, served with
# rb_map_serve(verdicts = ))
bathymetry_map_build <- function(con, dir, center = c(-19, 65), zoom = 6, lang = "en",
                                 json = file.path("products", "effort_map", "map.json"), extra = list(),
                                 extra_texts = list(), cells = TRUE, groups = list(), palette = "deep",
                                 about = NULL, depth_colour = list(), relief_shade = list(), names_state = list(),
                                 palettes = bathymetry_palettes(), ports = TRUE, names_popup = list()) {
  spec <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  pick <- function(x, id) Filter(function(l) identical(l$id, id), x)[[1]]
  nm <- pick(spec$layers, "names")
  # the names' areas off when the page opens: over the depth they read as a grid (the maintainer, 2026-11-04)
  nm$state <- lapply(nm$state, function(s) `[[<-`(s, "default", if (identical(s$id, "areas")) FALSE else s$default))
  nm$state <- lapply(nm$state, function(s) if (is.null(names_state[[s$id]])) s else `[[<-`(s, "default", names_state[[s$id]]))
  nm$popup <- utils::modifyList(nm$popup, names_popup)
  px <- pick(pick(spec$layers, "effort")$filters, "px")
  # cells of 2 pixels: at 1, a tile at zoom 6-9 is 13-14 MB (2026-11-03); the base's cells still show from zoom 10
  px$default <- "2"
  names_layer <- do.call(ramb::rb_map_layer, c(list(id = "names"), nm[setdiff(names(nm), "id")],
                                               list(data = place_names_geojson)))
  # the harbours: the effort map's ports layer as its map.json has it, off when the page opens (the maintainer,
  # 2026-11-09: "if we should put the harbours as an additional reference layer"); left out where the ports' table is
  # not there, as in the kit. fd_path(), since fd_curated() would make the folder
  ports_file <- fd_path("curated", "reference", "port_geometry.parquet")
  ports_layer <- if (ports && file.exists(ports_file)) {
    po <- pick(spec$layers, "ports")
    list(do.call(ramb::rb_map_layer, c(list(id = "ports"), po[setdiff(names(po), "id")],
                                       list(tiles = ports_tiles(con, ports_file)))))
  }
  depth <- ramb::rb_map_layer(
    "cells", "grid", label = "lyrDepth", info = "infoDepth", visible = FALSE, source_layer = "cells",
    minzoom = 2, maxzoom = 14, opacity = 100,
    tiles = function(z, x, y, p) depth_tile(con, dir, z, x, y, px = as.numeric(if (is.null(p$px)) px$default else p$px)),
    meta = function() list(v = max(as.numeric(file.mtime(Sys.glob(vapply(LEVELS, level_file, "", dir = dir)))))),
    filters = list(px, list(id = "metric", type = "metric", label = "metric")),
    metrics = list(list(field = "depth", label = "depthM")),
    popup = list(fields = list(list(field = "depth", label = "depthM", format = "value")))
  )
  texts <- c(spec$texts[setdiff(names(spec$texts), c("title", setdiff(unlist(spec$about), about)))], list(
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
    sAuto = list(en = "intensity from the view", is = "styrkur eftir sýn"),
    sAutoTip = list(en = "The intensity fitted to the view's relief each time the map settles: stronger where the seabed is gentle; setting it by hand stops it",
                    is = "Styrkur lagaður að landslagi sýnar í hvert sinn sem kortið stöðvast: meiri þar sem botninn er aflíðandi; handstilling stöðvar það"),
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
  texts <- utils::modifyList(texts, extra_texts)
  dem <- file.path(dir, "depth.mbtiles")
  has_dem <- file.exists(dem)
  all <- c(
    list(ramb::rb_map_group("depth", "gDepth", c(if (has_dem) list(depth_layer(dem, con, dir, depth_colour),
                                                                   contour_layer(dem, con, dir)),
                                                  if (cells) list(depth)))),
    if (has_dem) list(ramb::rb_map_group("relief", "gRelief", list(relief_layer(dem, con, dir, relief_shade)))),
    groups,
    list(ramb::rb_map_group("ref", "gRef", c(list(names_layer), ports_layer, extra)))
  )
  do.call(ramb::rb_map, c(all, list(
    title = "title", view = list(center = center, zoom = zoom), texts = texts,
    languages = unlist(spec$languages), language = lang, locales = lapply(spec$locales, unlist), palette = palette,
    palettes = palettes, about = about
  )))
}

})

bathymetry_map <- function(center = c(-19, 65), zoom = 6, palette = "deep", base = "light", lang = c("en", "is"),
                           port = 8798, viewer = TRUE, layers = list(), texts = list(), depth_colour = list()) {
  lang <- match.arg(lang)
  palettes <- vapply(.bathymetry_map$bathymetry_palettes(), `[[`, "", "id")
  bases <- vapply(ramb::rb_map_basemaps(), `[[`, "", "id")
  if (!palette %in% palettes) stop("palette is one of ", paste(palettes, collapse = ", "), call. = FALSE)
  if (!base %in% bases) stop("base is one of ", paste(bases, collapse = ", "), call. = FALSE)
  bathymetry_map_stop()
  e <- .bathymetry_map
  e$con <- DBI::dbConnect(duckdb::duckdb())
  invisible(DBI::dbExecute(e$con, "LOAD spatial"))
  m <- e$bathymetry_map_build(e$con, e$dir, center = center, zoom = zoom, lang = lang, extra = layers,
                              extra_texts = texts, depth_colour = depth_colour)
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
