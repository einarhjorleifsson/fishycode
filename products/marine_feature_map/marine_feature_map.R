# marine_feature_map.R — the names map on ogis: marine_feature drawn, the names edited (plan 074 step 12, ask w: the
# named-features study's 132 moved here, on curated tables in place of the study's files).
# Side: product. Internal: served on 127.0.0.1, not bundled (Landhelgisgæslan's chart names and the sea charts as base maps,
# not for navigation; wrecks known from internal lists, flagged `internal`).
#
# Input:  curated/reference/marine_feature.parquet and marine_feature_link.parquet (reference/marine_feature.R),
#         marine_name.parquet, marine_name_source.parquet and marine_name_extent.parquet (reference/names/marine_name.R),
#         chart_names.parquet (the letterings), aid.parquet and wreck.parquet (the lists' own columns), the depth model
#         products/bathymetry_map/depth.mbtiles (TODO 185); overrides/marine_name_edits.csv (the maintainer's edits)
# Output: rows appended to overrides/marine_name_edits.csv (NAME_EDITS= names another file, as a test does)
#
# The names at their place from the zoom they deserve (`z_rule`, the first whole zoom at or above it), MapLibre giving way
# where they collide (the traffic jam is the page's, step 7): the names' layer above the aids' names and those above the
# wrecks' (ask y: places first, an aid's name from zoom 10, a wreck's from 13); the long names along their lines; the aids
# and wrecks at their places, a line from an aid to the named feature it stands on; the sea charts as base maps; the depth,
# its relief and contours. The editing is the study's 75 and 132: a click on a name shows where each chart printed it, the
# name drags and turns, Earlier and Later a whole zoom, the rule's; Save appends a row (75's columns and checks), Place back
# reverts. The rule that lays the edits on is reference/names/marine_name.R's alone: at start, when the edits file is newer
# than marine_feature, the server runs it and reference/marine_feature.R again (about half a minute); edits saved while it
# runs are laid on in the page by the route `changed` (ogis reads a layer's data once, when the server starts).
# Run from the repo root: Rscript products/marine_feature_map/marine_feature_map.R, then http://127.0.0.1:8822 (PORT=).
# Needs ogis 2026.11.18.11 or later. Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages({ library(ogis); library(sf); library(dplyr); library(jsonlite) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)   # read_curated_sf()
HERE <- "products/marine_feature_map"
EF <- Sys.getenv("NAME_EDITS", "overrides/marine_name_edits.csv")
PORT <- as.integer(Sys.getenv("PORT", "8822"))
REF <- function(f) fd_curated("reference", f)
pq <- function(f) as.data.frame(nanoparquet::read_parquet(REF(f)))
`%||%` <- function(a, b) if (is.null(a)) b else a

# The edits laid on by marine_name.R, when the record is newer than the table -----------------------------------------
if (EF == "overrides/marine_name_edits.csv" && file.mtime(EF) > file.mtime(REF("marine_feature.parquet"))) {
  message("the edits are newer than marine_feature: rebuilding marine_name and marine_feature")
  for (s in c("reference/names/marine_name.R", "reference/marine_feature.R"))
    if (system2("Rscript", s, stdout = FALSE) != 0) stop("rebuilding failed: ", s)
}

# The tables ------------------------------------------------------------------------------------------------------------
t0 <- Sys.time()
mf <- read_curated_sf(REF("marine_feature.parquet"))
nm <- pq("marine_name.parquet"); aid <- pq("aid.parquet"); wr <- pq("wreck.parquet"); fl <- pq("marine_feature_link.parquet")
ex <- read_curated_sf(REF("marine_name_extent.parquet"))
chr <- function(x) ifelse(is.na(x), "", as.character(x))
GROUND <- "(grunn|banki|flak|fláki)$"
NAME_COL <- c(water = "#c0141b", isle = "#1a1a1a", land = "#4a4a4a")

# The names: the columns the editing script reads (the study's 132 names, kept) ------------------------------------------
n <- mf[mf$type == "name", ]; k <- match(n$list_id, as.character(nm$id))
aids_on <- fl |> filter(grepl("^aid:", from)) |> mutate(aid_name = mf$name[match(from, mf$id)]) |>
  group_by(to) |> summarise(aids = paste(unique(na.omit(aid_name)), collapse = "; "), .groups = "drop")
n <- n |> mutate(
  feature = as.integer(list_id), style = kind, printed = chr(nm$name_printed[k]), rot = rotate_deg, comp_rot = nm$rotate_computed[k],
  comp_lon = nm$lon_computed[k], comp_lat = nm$lat_computed[k], z0 = z_rule, comp_z0 = nm$z_rule_computed[k], dy = label_dy,
  edited = chr(nm$edited_at[k]), zoom_by = ifelse(is.na(nm$zoom_edited_at[k]), "", paste0("the maintainer, ", nm$zoom_edited_at[k])),
  delayed_by = "", balanced = "no", letters = "",
  place = paste0(place_basis, ifelse(is.na(nm$place_basis_computed[k]) | place_basis == nm$place_basis_computed[k], "",
                                     paste0(" (computed: ", nm$place_basis_computed[k], ")"))),
  angle = chr(rotate_basis), box = ifelse(is.na(extent_km), "", paste0(round(extent_km, 2), " km (", chr(extent_basis), ")")),
  lmi = ifelse(src == "lmi", paste0("LMÍ's ", chr(nm$class[k])), ""), isor = chr(nm$isor_references[k]),
  lmi_source = chr(nm$lmi_source[k]), lmi_source_kind = chr(nm$lmi_source_kind[k]), island_flags = chr(flags),
  aids = chr(aids_on$aids[match(id, aids_on$to)]), holder_name = chr(nm$holder_name[k]),
  face = if_else(style == "water", "italic", "plain"), turn = -coalesce(rot, 0), pr = -priority,
  up = if_else(nzchar(edited) | abs(coalesce(rot, 0)) >= 0.5, 0, sign(coalesce(dy, 0)) * (1.25 * size + 5) / size),
  sz = size + if_else(style == "water" & grepl(GROUND, name, ignore.case = TRUE), 0.25, 0),
  hand = if_else(nzchar(edited) | nzchar(zoom_by), "by hand", "computed"))
INFO <- c("feature", "name", "printed", "style", "src", "z0", "z_rule", "comp_z0", "delayed_by", "rot", "comp_rot",
          "comp_lon", "comp_lat", "dy", "size", "edited", "zoom_by", "place", "angle", "box", "letters", "balanced", "lmi",
          "lmi_source", "lmi_source_kind", "isor", "aids", "island_flags", "holder_name")
ZS <- 3:18
shrink <- function(z) min(1, max(0.7, 0.7 + 0.3 * (z - 6) / 3))
is_ground <- list(">", list("-", list("get", "sz"), list("floor", list("get", "sz"))), 0.1)
TEXT_SIZE <- c(list("interpolate", list("linear"), list("zoom")), unlist(lapply(ZS, function(z)
  list(z, list("case", is_ground, list("max", 10, list("*", list("floor", list("get", "sz")), shrink(z))), list("get", "sz")))),
  recursive = FALSE))

# The long names along their lines, from the zoom a line holds the name; never an edited name's
nl <- ex[ex$what == "line", ] |> mutate(id = paste0("name:", feature)) |> filter(id %in% n$id[!nzchar(n$edited)])
nl <- nl |> mutate(name = n$name[match(id, n$id)], style = n$style[match(id, n$id)], size = n$size[match(id, n$id)],
                   face = if_else(style == "water", "italic", "plain"))

# The aids and the wrecks at their places --------------------------------------------------------------------------------
BASIS <- c(vegagerdin = "Vegagerðin's position", vitaskra = "the List of Lights", is50v = "LMÍ's IS 50V",
           osm = "OpenStreetMap (NGA's list of 2010)", wikidata = "Wikidata")
a <- mf[mf$type == "aid" & mf$area == "iceland" & mf$place_basis != "chart", ]; ka <- match(a$list_id, as.character(aid$aid))
a <- a |> mutate(characteristic = chr(aid$characteristic[ka]), basis = chr(unname(BASIS[place_basis])), outcome = aid$outcome[ka],
                 why = chr(aid$why[ka]), on = chr(mf$name[match(on_feature, mf$id)]))
xy_of <- function(ids) { i <- match(ids, mf$id); data.frame(lon = mf$lon[i], lat = mf$lat[i]) }
la <- fl[grepl("^aid:", fl$from) & fl$from %in% a$id, ]
links <- cbind(la["from"], xy_of(la$from), setNames(xy_of(la$to), c("lon_end", "lat_end")))
AID_COL <- c(light = "#e8b400", buoy = "#d7301f", mark = "#4d4d4d", racon = "#2166ac", lit = "#9e9ac8")
w <- mf[mf$type == "wreck", ]; kw <- match(w$list_id, as.character(wr$wreck))
w <- w |> mutate(year_sunk = wr$year_sunk[kw], depth_m = wr$depth_m[kw], n_lists = wr$n_lists[kw], outcome = wr$outcome[kw],
                 why = chr(wr$why[kw]), witnesses = chr(wr$witnesses[kw]), on = chr(mf$name[match(on_feature, mf$id)]),
                 known = if_else(internal, "internal list", "public list"), label = coalesce(name, ""))

# The base maps: the sea charts (gis.natt.is's WMS map cache), each alone, and none ---------------------------------------
# A style of the page's own (route `style`): the glyphs (OpenFreeMap's Noto Sans) and two symbol layers that draw nothing, so
# that ogis finds a plain and an italic face on a base map without its own (plan 076 §1.2)
STYLE_URL <- "/x/style"   # relative: the page may be opened as localhost or 127.0.0.1
STYLE <- as.character(toJSON(list(version = 8, glyphs = "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf",
  sources = list(nm_font = list(type = "geojson", data = list(type = "FeatureCollection", features = list()))),
  layers = list(list(id = "nm_font_bg", type = "background", paint = list("background-color" = "#f4f2ee")),
                list(id = "nm_font_plain", type = "symbol", source = "nm_font", layout = list("text-font" = list("Noto Sans Regular"), "text-field" = "")),
                list(id = "nm_font_italic", type = "symbol", source = "nm_font", layout = list("text-font" = list("Noto Sans Italic"), "text-field" = "")))),
  auto_unbox = TRUE))
WMS <- paste0("https://gis.natt.is/mapcache/sjokort/web-mercador/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=TRUE",
              "&STYLES=&TILED=true&CRS=EPSG%3A3857&WIDTH=256&HEIGHT=256&BBOX={bbox-epsg-3857}&LAYERS=Sjomaelingar%3A")
CHART_ATT <- "Sjókort © Sjómælingar Íslands, Landhelgisgæslan; not for navigation"
SERIES <- c(sjokort_2milljon = "1:2 000 000", sjokort_1milljon = "1:1 000 000", sjokort_300thusund = "1:300 000",
            sjokort_K42 = "1:160 000 (K42)", sjokort_100thusund = "1:100 000", sjokort_K44 = "1:70 000 (K44)",
            sjokort_35_40_50thusund = "1:35 000-1:50 000", sjokort_15thusund = "1:15 000", sjokort_10thusund = "1:10 000")
BASES <- c(list(list(id = "plain", label = "None (the names alone)", style = STYLE_URL)),
           unname(Map(function(id, lab) list(id = id, label = paste("Sea chart", lab), tiles = paste0(WMS, id), maxzoom = 17,
                                              attribution = CHART_ATT, labels = STYLE_URL, label_layers = "^nm_font_", background = "#f4f2ee"),
                      names(SERIES), SERIES)))

# The sea floor: the depth model, its relief and contours, as the study's 75 and 132 draw them -----------------------------
dem_tiles <- og_tiles_mbtiles(fd_path("products", "bathymetry_map", "depth.mbtiles"))
depth <- og_layer("depth", "dem", label = "Depth", info = "The Olex depth model (and GEBCO beyond), coloured in the page.",
  tiles = dem_tiles, style = list(list(id = "depth-colour", type = "color-relief")),
  colour = list(palette = "grey", opacity = 75, scale = "log", floor = 10, cap = 2000))
relief <- og_layer("relief", "dem", label = "Relief", visible = FALSE, info = "The same tiles, shaded in the page.",
  tiles = dem_tiles, style = list(list(id = "relief-shade", type = "hillshade")), shade = list(exaggeration = 0.4, shadow = "#1b2a3a"))
BANDS <- c(0, 50, 200, 1000)
SPACING <- list("5" = c(25, 50, 100, 500), "7" = c(10, 50, 100, 500), "8" = c(10, 20, 100, 200),
                "9" = c(10, 20, 50, 200), "10" = c(5, 10, 50, 100), "11" = c(5, 10, 20, 100))
ISOBATHS <- c(10, 20, 50, 100, 200, 500, 1000, 1500, 2000, 2500, 3000)
contours <- local({
  ele <- list("get", "ele"); gcd <- function(a, b) if (b == 0) a else gcd(b, a %% b)
  major <- list("in", ele, list("literal", as.list(ISOBATHS)))
  kept <- function(s) c(list("any"), lapply(seq_along(s), function(i) c(list("all", list(if (i == 1) ">" else ">=", ele, BANDS[i])),
    if (i < length(BANDS)) list(list("<", ele, BANDS[i + 1])), list(list("==", list("%", ele, s[i]), 0)))),
    list(list("all", major, list(">=", ele, s[1]))))
  zooms <- as.numeric(names(SPACING))
  style <- unlist(lapply(seq_along(zooms), function(k) {
    mz <- if (k < length(zooms)) zooms[k + 1] else 24; f <- kept(SPACING[[k]])
    list(list(id = sprintf("contours-line-%d", zooms[k]), type = "line", "source-layer" = "contours", minzoom = zooms[k], maxzoom = mz,
              filter = f, paint = list("line-color" = "rgba(27,42,58,0.55)", "line-width" = list("case", major, 1.2, 0.5))),
         list(id = sprintf("contours-label-%d", zooms[k]), type = "symbol", "source-layer" = "contours", minzoom = zooms[k], maxzoom = mz,
              filter = list("all", f, major),
              layout = list("symbol-placement" = "line", "text-size" = 12, "text-max-angle" = 180, "symbol-spacing" = 200,
                            "text-field" = list("concat", list("number-format", ele, structure(list(), names = character())), " m")),
              paint = list("text-color" = "#1b2a3a", "text-halo-color" = "#ffffff", "text-halo-width" = 1.5)))
  }), recursive = FALSE)
  og_layer("contours", "contour", label = "Contours", info = "Depth contours made in the page from the same tiles.",
           tiles = dem_tiles, contours = list(multiplier = -1, thresholds = lapply(SPACING, function(s) Reduce(gcd, s))), style = style)
})

# The map: the wrecks first, the aids, the names last, so the names are placed first where labels collide -----------------
m <- og_map(title = "Marine features (plan 074)", view = list(center = c(-19, 64.9), zoom = 6), basemaps = BASES) |>
  og_add_layer(list(depth, relief, contours), section = "Sea floor") |>
  og_point(w, colour = known, palette = c("public list" = "#5e3c99", "internal list" = "#b2abd2"), size = c(3, 8), hover = label,
           popup = c(label, year_sunk, depth_m, n_lists, witnesses, outcome, why, on, known, flags), visible = FALSE,
           id = "wrecks", name = "Wrecks", section = "Wrecks", choose = known) |>
  og_text(w[nzchar(w$label), ], label = label, minzoom = 13, size = 11, offset = c(0, -0.8), colour = "#5e3c99",
          visible = FALSE, id = "wreck_names", name = "Their names", section = "Wrecks") |>
  og_point(a, colour = kind, palette = AID_COL, size = c(4, 11), hover = name, popup = c(name, characteristic, kind, basis, outcome, why, on),
           visible = FALSE, id = "aids", name = "Lights, buoys and beacons", section = "Aids") |>
  og_text(a[!is.na(a$name), ], label = name, minzoom = 10, size = 11, offset = c(0, -0.8), colour = "#6b5500",
          visible = FALSE, id = "aid_names", name = "Their names", section = "Aids") |>
  og_segment(links, lon = "lon", lat = "lat", lon_end = lon_end, lat_end = lat_end, colour = "#8a6d00", linewidth = 1,
             popup = FALSE, legend = FALSE, visible = FALSE, id = "aid_links", name = "Lines to the features' names",
             section = "Aids", "line-dasharray" = list(3, 2)) |>
  og_text(nl, label = name, minzoom = z_line, size = size, fontface = face, colour = style, palette = NAME_COL, whole = TRUE,
          id = "name_lines", name = "Long names along their lines", section = "Names",
          info = "The long names along their lines, from the zoom a line holds the name.") |>
  og_text(n, label = name, minzoom = z0, angle = turn, priority = pr, size = sz, fontface = face, offset = c(0, up),
          colour = style, palette = NAME_COL, choose = c(src, style, hand), popup = all_of(INFO), whole = TRUE,
          id = "names", name = "Names", section = "Names",
          info = "Each name at its place, from the first whole zoom at or above the zoom it deserves; a name gives way where two collide.",
          "text-size" = TEXT_SIZE, "text-letter-spacing" = list("case", list("==", list("get", "style"), "water"), 0.15, 0),
          "text-padding" = 2, "text-max-width" = 40) |>
  og_script(file.path(HERE, "marine_feature_map.js"), css = file.path(HERE, "marine_feature_map.css"))
message("map built (", round(difftime(Sys.time(), t0, units = "secs"), 1), " s)")

# The page's routes ------------------------------------------------------------------------------------------------------
cn <- as.data.frame(nanoparquet::read_parquet(REF("chart_names.parquet")))
src <- pq("marine_name_source.parquet") |> filter(source == "chart")
let <- src |> mutate(key = source_id) |>
  left_join(cn |> transmute(key = paste(chart, label_id, sep = "/"), chart, name, runs_deg, lon, lat), by = "key") |>
  mutate(chart_label = unname(SERIES[chart]), scale = as.numeric(gsub("[^0-9]", "", sub(" .*", "", unname(SERIES[chart]))))) |>
  transmute(feature = id, chart, chart_label, scale, name, runs_deg, lon, lat)
let_by <- split(let, let$feature)
ext_by <- local({ e <- ex[ex$what == "extent", ]; split(e, e$feature) })
extent_fc <- function(id) { e <- ext_by[[as.character(id)]]; if (is.null(e)) return('{"type":"FeatureCollection","features":[]}')
  tf <- tempfile(fileext = ".geojson"); on.exit(unlink(tf)); st_write(e["basis"], tf, quiet = TRUE, driver = "GeoJSON")
  paste(readLines(tf, warn = FALSE, encoding = "UTF-8"), collapse = "") }
# the rows the search and a search's choice read: every name, aid and wreck; a name with the row it is in the names layer
idx <- st_drop_geometry(n)[, INFO]; idx$lon <- n$lon; idx$lat <- n$lat; idx$og_row <- seq_len(nrow(idx)); idx$type <- "name"
idx0 <- idx                                    # as the names layer was sent
others <- bind_rows(st_drop_geometry(a) |> transmute(feature = NA_integer_, id, name, style = kind, src = "aid", type = "aid", lon, lat, z0 = 10),
                    st_drop_geometry(w) |> filter(nzchar(label)) |> transmute(feature = NA_integer_, id, name = label, style = "wreck", src = "wreck", type = "wreck", lon, lat, z0 = 13))
fold <- function(s) tolower(iconv(s, "UTF-8", "ASCII//TRANSLIT"))
COLS <- c("feature", "name", "lon", "lat", "rot", "angle_deg", "z0", "comp_z0", "action", "at", "by", "comp_lon", "comp_lat")
PLACE <- c("move", "turn", "move and turn", "revert"); ZOOM <- c("zoom", "zoom back")
arg <- function(req, k) req$query[[k]] %||% (if (is.list(req$body)) req$body[[k]])
routes <- list(
  style = function(req) STYLE,
  letterings = function(req) { x <- let_by[[as.character(arg(req, "feature") %||% "")]]; if (is.null(x)) x <- let[0, ]
    x[, c("chart", "chart_label", "scale", "name", "runs_deg", "lon", "lat")] },
  extent = function(req) extent_fc(sub("^c", "", as.character(arg(req, "id") %||% ""))),
  feature = function(req) { i <- match(as.integer(arg(req, "feature") %||% NA), idx$feature); if (is.na(i)) NULL else as.list(idx[i, ]) },
  # the whole name first, then a name it begins, then any; each kind nearest the map's centre; names, aids and wrecks alike
  search = function(req) {
    q <- fold(trimws(arg(req, "q") %||% "")); if (nchar(q) < 2) return(list(n = 0, hits = list()))
    all <- bind_rows(idx[, c("feature", "name", "style", "src", "type", "z0", "z_rule", "lon", "lat")], others)
    f <- fold(all$name); j <- which(grepl(q, f, fixed = TRUE)); if (!length(j)) return(list(n = 0, hits = list()))
    lon <- as.numeric(arg(req, "lon") %||% -19); lat <- as.numeric(arg(req, "lat") %||% 65)
    dx <- (all$lon[j] - lon) * 111.32 * cos(lat * pi / 180); dy <- (all$lat[j] - lat) * 110.57
    rank <- ifelse(f[j] == q, 0, ifelse(startsWith(f[j], q), 1, 2)); km <- sqrt(dx^2 + dy^2)
    o <- order(rank, km)[seq_len(min(40, length(j)))]
    h <- all[j[o], c("feature", "name", "style", "src", "type", "z0", "z_rule", "lon", "lat")]
    h$km <- km[o]; h$dir <- c("N", "NE", "E", "SE", "S", "SW", "W", "NW")[round(((atan2(dx[o], dy[o]) * 180 / pi) + 360) %% 360 / 45) %% 8 + 1]
    list(n = length(j), hits = h) },
  edits = function(req) { if (!file.exists(EF)) return(data.frame()); read.csv(EF, encoding = "UTF-8") },
  # the names edited since the server started (ogis reads a layer's data once; the script lays these on)
  changed = function(req) {
    k <- which(idx$lon != idx0$lon | idx$lat != idx0$lat | idx$rot != idx0$rot | idx$z0 != idx0$z0 | idx$edited != idx0$edited |
                 idx$zoom_by != idx0$zoom_by)
    idx[k, c("og_row", "feature", "lon", "lat", "rot", "z0", "edited", "zoom_by", "dy", "size")] },
  # an edit, in 75's columns and by 75's checks: a row appended, never rewritten
  edit = function(req) {
    if (req$method != "POST") stop("POST an edit")
    x <- req$body; place <- x$action %in% PLACE && x$action != "revert"
    ok <- is.numeric(x$feature) && x$action %in% c(PLACE, ZOOM) &&
      (!place || (is.numeric(x$lon) && is.numeric(x$lat) && is.numeric(x$rot) && abs(x$rot) <= 90 && x$lon > -45 && x$lon < 0 && x$lat > 55 && x$lat < 72)) &&
      (x$action != "zoom" || (is.numeric(x$z0) && x$z0 >= 3 && x$z0 <= 18 && x$z0 == round(x$z0)))
    if (!isTRUE(ok)) stop("not an edit this page makes")
    row <- data.frame(feature = as.integer(x$feature), name = as.character(x$name %||% ""), lon = if (place) round(x$lon, 6) else NA,
                      lat = if (place) round(x$lat, 6) else NA, rot = if (place) round(x$rot, 1) else NA,
                      angle_deg = if (place) round((x$rot + 90) %% 180, 1) else NA,
                      z0 = if (x$action == "zoom") x$z0 else NA, comp_z0 = if (x$action %in% ZOOM && is.numeric(x$comp_z0)) x$comp_z0 else NA,
                      action = x$action, at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), by = "the maintainer",
                      comp_lon = if (is.numeric(x$comp_lon)) x$comp_lon else NA, comp_lat = if (is.numeric(x$comp_lat)) x$comp_lat else NA)
    write.table(row[, COLS], EF, sep = ",", row.names = FALSE, col.names = !file.exists(EF), append = file.exists(EF),
                fileEncoding = "UTF-8", qmethod = "double")
    i <- match(row$feature, idx$feature)
    if (!is.na(i)) {
      if (place) { idx$lon[i] <<- row$lon; idx$lat[i] <<- row$lat; idx$rot[i] <<- row$rot; idx$edited[i] <<- row$at }
      if (x$action == "revert") { idx$lon[i] <<- idx$comp_lon[i]; idx$lat[i] <<- idx$comp_lat[i]; idx$rot[i] <<- idx$comp_rot[i]; idx$edited[i] <<- "" }
      if (x$action %in% ZOOM) { idx$z_rule[i] <<- if (x$action == "zoom") row$z0 else idx$comp_z0[i]; idx$z0[i] <<- idx$z_rule[i]
        idx$zoom_by[i] <<- if (x$action == "zoom") paste0("the maintainer, ", row$at) else "" } }
    list(ok = TRUE, at = row$at) })
message("The marine features map: http://127.0.0.1:", PORT, " (edits to ", EF, ")")
og_serve(m, port = PORT, open = FALSE, routes = routes, wait = !interactive())
