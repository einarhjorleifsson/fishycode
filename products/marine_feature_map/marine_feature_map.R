# marine_feature_map.R — the names map on ogis: marine_feature drawn, the names edited (plan 074 step 12, ask w: the
# named-features study's 132 moved here, on curated tables in place of the study's files).
# Side: product. Internal: served on 127.0.0.1, not bundled (Landhelgisgæslan's chart names and the sea charts as base maps,
# not for navigation; wrecks known from internal lists, flagged `internal`).
#
# Input:  curated/reference/marine_feature.parquet and marine_feature_link.parquet (reference/marine_feature.R),
#         marine_name.parquet, marine_name_source.parquet, marine_name_record.parquet and marine_name_extent.parquet
#         (reference/names/marine_name.R), staging/is50v/name.parquet (LMÍ's feature and class of a record),
#         chart_names.parquet (the letterings), aid.parquet and wreck.parquet (the lists' own columns), the depth model
#         products/bathymetry_map/depth.mbtiles (TODO 185); overrides/marine_name_edits.csv (the maintainer's edits)
# Output: rows appended to overrides/marine_name_edits.csv (NAME_EDITS= names another file, as a test does)
#
# Version 2 (plan 080 §5.2): each name drawn at its label (`label_lon`, `label_lat`), a point kind's (a rock, a shoal, a
# skerry) with a dot at the thing and its name beside it; a name renamed on the page (Rename: a row `rename` with the new
# name and why, ask e); another name added (Add as a synonym: a row `synonym`); where the thing is set by hand (its point, a marker of its own: Save the point writes a row `pin`,
# Point back a row `unpin`; a pinned name gets a dot); the version's review layer, opening on Faxaflói and Reykjaneshryggur (ask j): the doubtful pairs
# of one name from two sources, the wholes and parts, the rows joined, the renames, version 1's duplicates, rocks far from
# the chart and known faults, each with a line to its namesake where it has one. ÍSOR's areas a layer of their own, LMÍ's
# another (hidden), a click on an area choosing its name; LMÍ's oceans (its feature haf in its large class: Íslandshaf,
# Norður-Atlantshaf) not drawn, kept in the records (decision 338). ÍSOR's craters and guyots a layer of their own (plan 080 §5.2a): with
# a name chosen, a click on one offers Link to this mound (a row `link`, the feature in `link_to`), Unlink a row `unlink`.
# ÍSOR's landforms (decision 336 ask p), off when the page opens: its troughs, moraines, channels, shelf break (as its line), streamlines.
# Trackwell's names in the open regions (reference/names/trackwell_candidate.R): its candidates a layer, a click offering Accept
# and Reject (rows `accept` and `reject`, the candidate's key in `link_to`; an accepted one a name at the next build), the rest
# (already a name, one vessel, carried in) a layer off when the page opens.
#
# The names at their place from the zoom they deserve (`z_rule`, the first whole zoom at or above it), MapLibre giving way
# where they collide (the traffic jam is the page's, step 7): the names' layer above the aids' names and those above the
# wrecks' (ask y: places first, an aid's name from zoom 10, a wreck's from 13); the long names along their lines; the aids
# and wrecks at their places, a line from an aid to the named feature it stands on; the sea charts as base maps, and the
# old land maps (Atlaskort 1:100 000, the Danish and AMS 1:50 000) from the same service; the depth,
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
pairs <- pq("marine_name_pair.parquet")
sfx <- read_curated_sf(REF("seabed_feature.parquet"))
VERSION <- unique(mf$version); stopifnot(length(VERSION) == 1)
ex <- read_curated_sf(REF("marine_name_extent.parquet"))
chr <- function(x) ifelse(is.na(x), "", as.character(x))
GROUND <- "(grunn|banki|flak|fláki)$"
NAME_COL <- c(water = "#c0141b", isle = "#1a1a1a", land = "#4a4a4a")

# The names: the columns the editing script reads (the study's 132 names, kept) ------------------------------------------
# a name at its label; the thing's place kept as thing_lon, thing_lat (a point kind's dot)
n <- st_drop_geometry(mf[mf$type == "name", ]) |> mutate(thing_lon = lon, thing_lat = lat, lon = label_lon, lat = label_lat) |>
  st_as_sf(coords = c("label_lon", "label_lat"), crs = 4326, remove = FALSE)
k <- match(n$list_id, as.character(nm$id))
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
  report = chr(nm$report[k]), report_entry = chr(nm$report_entry[k]), name_en = chr(nm$name_en[k]),
  coined = ifelse(nm$coined[k] %in% TRUE, "yes", ifelse(nm$coined[k] %in% FALSE, "no", "")),
  aids = chr(aids_on$aids[match(id, aids_on$to)]), holder_name = chr(nm$holder_name[k]),
  pk = as.integer(point_kind), name_source = chr(name_source), name_basis = chr(name_basis),
  comp_thing_lon = nm$thing_lon_computed[k], comp_thing_lat = nm$thing_lat_computed[k], pinned = chr(nm$pinned_at[k]),
  thing = sprintf("%.5f, %.5f (%s)", thing_lon, thing_lat, place_basis),
  seabed_id = chr(nm$seabed_id[k]),
  seabed = ifelse(is.na(nm$seabed_id[k]), "", paste0("ÍSOR's ", sfx$kind[match(nm$seabed_id[k], sfx$seabed_id)], " ",
                  sfx$label[match(nm$seabed_id[k], sfx$seabed_id)], " (", nm$seabed_link[k], ")")),
  face = if_else(style == "water", "italic", "plain"), turn = -coalesce(rot, 0), pr = -priority,
  up = if_else(nzchar(edited) | abs(coalesce(rot, 0)) >= 0.5 | pk == 1L, 0, sign(coalesce(dy, 0)) * (1.25 * size + 5) / size),
  ox = if_else(pk == 1L & !nzchar(edited), 0.7, 0),
  sz = size + if_else(style == "water" & grepl(GROUND, name, ignore.case = TRUE), 0.25, 0),
  hand = if_else(nzchar(edited) | nzchar(zoom_by), "by hand", "computed"))
INFO <- c("feature", "name", "printed", "style", "src", "z0", "z_rule", "comp_z0", "delayed_by", "rot", "comp_rot",
          "comp_lon", "comp_lat", "dy", "size", "edited", "zoom_by", "place", "angle", "box", "letters", "balanced", "lmi",
          "lmi_source", "lmi_source_kind", "isor", "aids", "island_flags", "holder_name", "pk", "name_source", "name_basis", "thing",
          "thing_lon", "thing_lat", "comp_thing_lon", "comp_thing_lat", "pinned", "synonyms", "seabed_id", "seabed",
          "report", "report_entry", "name_en", "coined")
ZS <- 3:18
shrink <- function(z) min(1, max(0.7, 0.7 + 0.3 * (z - 6) / 3))
is_ground <- list(">", list("-", list("get", "sz"), list("floor", list("get", "sz"))), 0.1)
TEXT_SIZE <- c(list("interpolate", list("linear"), list("zoom")), unlist(lapply(ZS, function(z)
  list(z, list("case", is_ground, list("max", 10, list("*", list("floor", list("get", "sz")), shrink(z))), list("get", "sz")))),
  recursive = FALSE))

# A point kind's dot at the thing, from the zoom its name deserves (a text layer: og_point has no start zoom by row)
dots <- st_drop_geometry(n) |> filter(pk == 1L | nzchar(pinned)) |>
  transmute(id, feature, name, style, z0, bullet = "\u2022", lon = thing_lon, lat = thing_lat) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE)

# Version 2's review: what the maintainer is asked to look at, at the thing, with a line to its namesake ---------------------
FAULTS <- c("Eldeyjarbanki" = "a known fault (plan 074): its crest wanders", "Skeiðarárdjúp" = "a known fault (plan 074): its place",
            "Haffjarðarey" = "an island pair on one anchor (plan 074)", "Útey" = "an island pair on one anchor (plan 074)",
            "Öxney" = "an island pair on one anchor (plan 074)", "Örney" = "an island pair on one anchor (plan 074)")
has <- function(p) grepl(p, chr(n$flags), fixed = TRUE)
REASON <- c(doubtful = "doubtful: one name, two sources", part = "whole and part: one name", joined = "one thing: two sources joined",
            renamed = "renamed by you", duplicate = "a possible duplicate (version 1)", far = "at LMÍ's position, far from the chart's",
            bearer = "LMÍ's record of another bearer", fault = "a known fault")
rv <- bind_rows(
  st_drop_geometry(n)[has("doubtful: one name with"), ] |> mutate(reason = REASON[["doubtful"]]),
  st_drop_geometry(n)[has("namesake ") & has("whole and part"), ] |> mutate(reason = REASON[["part"]]),
  st_drop_geometry(n)[!is.na(nm$joined_from[k]), ] |> mutate(reason = REASON[["joined"]]),
  st_drop_geometry(n)[!is.na(nm$renamed_at[k]), ] |> mutate(reason = REASON[["renamed"]]),
  st_drop_geometry(n)[has("possible_duplicate"), ] |> mutate(reason = REASON[["duplicate"]]),
  st_drop_geometry(n)[has("far_from_chart"), ] |> mutate(reason = REASON[["far"]]),
  st_drop_geometry(n)[has("lmi_bearer_differs"), ] |> mutate(reason = REASON[["bearer"]]),
  st_drop_geometry(n)[n$name %in% names(FAULTS) & n$src == "chart", ] |> mutate(reason = REASON[["fault"]], fault = unname(FAULTS[name]))) |>
  transmute(id, name, src, reason, detail = coalesce(fault, chr(flags)), lon = thing_lon, lat = thing_lat) |>
  group_by(id) |> summarise(name = first(name), src = first(src), reason = paste(unique(reason), collapse = "; "),
                            first_reason = first(reason), detail = first(detail), lon = first(lon), lat = first(lat), .groups = "drop") |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE)
RV_COL <- setNames(c("#e41a1c", "#984ea3", "#4daf4a", "#377eb8", "#ff7f00", "#a65628", "#f781bf", "#000000"), unname(REASON))
pl <- pairs |> filter(outcome != "namesakes") |>
  transmute(outcome, names = paste0(name_a, " (", src_a, ") – ", name_b, " (", src_b, ")"), km = round(d_km, 2),
            lon = lon_a, lat = lat_a, lon_end = lon_b, lat_end = lat_b)
PAIR_COL <- c("one thing" = "#4daf4a", "whole and part" = "#984ea3", "doubtful" = "#e41a1c")
message(sprintf("review (version %d): %d places, %d lines between namesakes", VERSION, nrow(rv), nrow(pl)))

# The names' areas, ÍSOR's and LMÍ's, each a layer; a click chooses the area's name (the script)
ae <- ex[ex$what == "extent" & ex$used & st_geometry_type(ex) %in% c("POLYGON", "MULTIPOLYGON"), ] |> mutate(id = paste0("name:", feature)) |>
  filter(id %in% n$id)
ae$name <- n$name[match(ae$id, n$id)]
isor_ar <- ae[grepl("^ÍSOR's", ae$basis), c("feature", "name", "basis")]   # its own, or one he linked (a trough)
lmi_ar <- ae[!grepl("^ÍSOR's", ae$basis), c("feature", "name", "basis")]
# LMÍ's oceans off the map, kept in the records: each covers the whole map and a click anywhere would choose it (the
# maintainer, 2026-11-20: "these very broad LMÍ areas, like Norður-Atlantshaf, Íslandshaf - get rid of them"; "Removal from a
# map is different than a removal from the records"); an ocean is LMÍ's feature haf in its large class (its races, haf too,
# are of the small class)
is0 <- as.data.frame(nanoparquet::read_parquet(fd_staging("is50v", "name.parquet")))[, c("uuid", "feature", "class")]
rc0 <- as.data.frame(nanoparquet::read_parquet(REF("marine_name_record.parquet")))
ocean <- unique(rc0$feature[rc0$source == "lmi" & rc0$source_id %in% is0$uuid[is0$feature == "haf" & grepl("Stórt$", is0$class)] & !is.na(rc0$feature)])
lmi_ar <- lmi_ar[!lmi_ar$feature %in% ocean, ]
message(sprintf("LMÍ's oceans off the map: %s", paste(nm$name[match(ocean, nm$id)], collapse = ", ")))

# ÍSOR's craters and guyots, and its seamounts (plan 080 §5.2a)
# a reference's study: the 2018 ISOR report, the 2023 mapping (EGU23-15536; every guyot is the 2023 mapping's), older work
study_of <- function(r) case_when(grepl("^Hjartarson", r) ~ "the 2018 ISOR report", grepl("^Erlendsson", r) ~ "the 2023 mapping (EGU23-15536)",
                                  is.na(r) | r == "" ~ "none given", TRUE ~ "older work")
craters <- sfx[sfx$kind %in% c("crater", "point"), ] |> mutate(depth_m = top_depth_m, study = study_of(references))
guyots <- sfx[sfx$kind == "guyot", ] |> mutate(depth_m = top_depth_m, study = study_of(references))
seamounts <- sfx[sfx$kind == "seamount", c("seabed_id", "label", "kind", "top_depth_m", "place_basis")]   # no lon, lat: ogis would draw points
CRATER_COL <- c(crater = "#b2182b", point = "#67001f")
LF_COLS <- c("seabed_id", "label", "kind", "top_depth_m", "place_basis")   # no lon, lat: ogis would draw points
twc <- if (file.exists(REF("marine_name_candidate.parquet"))) read_curated_sf(REF("marine_name_candidate.parquet")) else NULL
if (!is.null(twc)) twc <- twc |> mutate(verdict = chr(verdict), seabed_id = chr(seabed_id))
TW_CAND <- c("a candidate on a feature", "a candidate, no feature")
TW_COL <- c("a candidate on a feature" = "#d95f02", "a candidate, no feature" = "#fdb863", "already a name" = "#1b9e77",
            "one vessel" = "#bdbdbd", "carried in" = "#7570b3", "ignored by the maintainer" = "#252525")
troughs <- sfx[sfx$kind == "trough", LF_COLS]
moraines <- sfx[sfx$kind == "moraine", LF_COLS]

# Claude's proposals (plan 081, decision 337): each name's best proposal, its evidence and its shapes; the review mode -----
# reads them (reference/names/place_name_proposal.R; step 1, the deeps; step 2, the moraines). Absent the table, no proposal layers
pp <- if (file.exists(REF("place_name_proposal.parquet"))) read_curated_sf(REF("place_name_proposal.parquet")) else NULL
if (!is.null(pp)) {
  pev <- pq("place_name_proposal_evidence.parquet"); psh <- read_curated_sf(REF("place_name_proposal_shape.parquet"))
  pp <- pp |> mutate(name = coalesce(name, "(unnamed)"), verdict = chr(verdict), flags = chr(flags),
                     status = case_when(grepl("^accepted", verdict) ~ "accepted", grepl("^rejected", verdict) ~ "rejected",
                                        class == "deep" & trough == "none" ~ "no trough yet (step 5)",
                                        class == "moraine" & moraine == "none" ~ "no moraine (a later step)", nzchar(flags) ~ "flagged", TRUE ~ "proposed"),
                     witnesses = ifelse(n_agree > 0, paste0(n_agree, ": ", agree), "none"))
  PROP_COL <- c(proposed = "#1a9850", flagged = "#f46d43", "no trough yet (step 5)" = "#9e9e9e", "no moraine (a later step)" = "#c7c7c7",
                accepted = "#2166ac", rejected = "#7b3294")
  pext <- psh[psh$what == "extent", ] |> mutate(name = pp$name[match(key, pp$key)], status = pp$status[match(key, pp$key)])
  is_line <- as.character(st_geometry_type(pext)) %in% c("LINESTRING", "MULTILINESTRING")
  pmor <- pext[is_line, ]; pext <- pext[!is_line, ]                                      # step 2's extents are ÍSOR's moraines, lines
  pthw <- psh[psh$what == "thalweg", ] |> mutate(name = pp$name[match(key, pp$key)])
  # the review's queue: the latest step first; in it the flagged first, then the proposed, then those awaiting an element;
  # each by trough or moraine, then name
  queue <- st_drop_geometry(pp) |> mutate(o = match(status, c("flagged", "proposed", "no trough yet (step 5)", "no moraine (a later step)", "accepted", "rejected")),
                                         tn = suppressWarnings(coalesce(as.integer(trough), as.integer(moraine)))) |>
    arrange(desc(step), o, tn, name) |> transmute(key, name, status, lon, lat)
}
prop_layers <- function(m) if (is.null(pp)) m else m |>
  og_polygon(pext, colour = "#1a1a1a", fill = status, palette = PROP_COL, opacity = 0.10, linewidth = 1.2, hover = name,
             popup = c(name, status, basis, key), visible = FALSE, id = "prop_extents", name = "Proposed extents",
             section = "Claude's proposals", info = "Each deep's proposed extent: an ÍSOR trough, or its part where several deeps share it; a click opens the proposal.") |>
  og_line(pmor, colour = status, palette = PROP_COL, linewidth = 3, hover = name, popup = c(name, status, basis, key), visible = FALSE, legend = FALSE,
          id = "prop_moraines", name = "Proposed moraines", section = "Claude's proposals",
          info = "Step 2: each ridge, edge, toe or tip name's proposed moraine, one of ÍSOR's; a click opens the proposal.") |>
  og_line(pthw, colour = "#542788", linewidth = 1.4, hover = name, popup = c(name, basis), visible = FALSE, legend = FALSE,
          id = "prop_thalwegs", name = "The deeps' thalwegs (untried)", section = "Claude's proposals",
          info = "The deepest route from a deep toward the fjord or bay it is named for (plan 081 §4.1; for step 3's banks).") |>
  og_point(pp, colour = status, palette = PROP_COL, size = c(6, 12), hover = name, choose = status,
           popup = c(name, status, witnesses, against, flags, place_basis, key), id = "proposals", name = "Proposals (step 1 the deeps, step 2 the moraines)",
           section = "Claude's proposals",
           info = "Claude's best proposal for each name: where its thing is, by its witnesses (the charts, LMÍ, the skippers, the texts, his word). A click opens it with its evidence, Accept and Reject.")
lf_areas <- sfx[sfx$kind %in% c("channel", "meltwater channel"), LF_COLS]
lf_lines <- sfx[sfx$kind %in% c("canal", "glacial streamline", "gravity streamline"), LF_COLS]
LF_AREA_COL <- c(channel = "#35978f", "meltwater channel" = "#80cdc1")
# ÍSOR's shelf break is one polygon, the whole shelf inside it (288,856 km²): drawn as an area it lay under every click on the
# shelf and took it from the channels and troughs (the maintainer, 2026-11-20). Drawn as its line, the polygon's outer ring
shelf_break <- sfx[sfx$kind == "shelf break", LF_COLS]
st_geometry(shelf_break) <- st_sfc(lapply(st_geometry(shelf_break), function(g) {
  rings <- if (inherits(g, "MULTIPOLYGON")) lapply(g, `[[`, 1) else list(g[[1]]); st_multilinestring(rings) }), crs = st_crs(shelf_break))
LF_LINE_COL <- c(canal = "#8c510a", "glacial streamline" = "#bf812d", "gravity streamline" = "#01665e")

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
# The old land maps on the same service, a background for the coast's names (the maintainer, 2026-11-19: "the link to a
# server of those may be a helpful map background"): images only, never read for names (decision 336)
OLD_WMS <- paste0("https://gis.natt.is/mapcache/web-mercator/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng",
                  "&TRANSPARENT=TRUE&STYLES=&CRS=EPSG%3A3857&WIDTH=256&HEIGHT=256&BBOX={bbox-epsg-3857}&LAYERS=")
OLD <- list(c("LMI_raster%3Aatlas", "Atlaskort 1:100 000 (1900-1940, revised to 1989)", "Atlaskort © Landmælingar Íslands (Náttúrufræðistofnun)"),
            c("LMI_raster%3AAtlas_50", "Herforingjaráðskort Dana 1:50 000", "Herforingjaráðskort © Landmælingar Íslands (Náttúrufræðistofnun)"),
            c("AMS", "AMS 1:50 000", "AMS © Landmælingar Íslands (Náttúrufræðistofnun)"))
BASES <- c(list(list(id = "plain", label = "None (the names alone)", style = STYLE_URL)),
           unname(Map(function(id, lab) list(id = id, label = paste("Sea chart", lab), tiles = paste0(WMS, id), maxzoom = 17,
                                              attribution = CHART_ATT, labels = STYLE_URL, label_layers = "^nm_font_", background = "#f4f2ee"),
                      names(SERIES), SERIES)),
           lapply(OLD, function(o) list(id = sub(".*%3A", "", o[1]), label = o[2], tiles = paste0(OLD_WMS, o[1]), maxzoom = 17,
                                        attribution = o[3], labels = STYLE_URL, label_layers = "^nm_font_", background = "#f4f2ee")))

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
m <- og_map(title = sprintf("Marine features, version %d (plan 080)", VERSION), view = list(center = c(-23.4, 63.75), zoom = 6.8),
            basemaps = BASES) |>
  og_add_layer(list(depth, relief, contours), section = "Sea floor") |>
  og_polygon(lmi_ar, colour = "#08519c", fill = "#08519c", opacity = 0.06, linewidth = 0.6, legend = FALSE, hover = name,
             popup = c(name, basis, feature), visible = FALSE, id = "lmi_areas", name = "LMÍ's areas", section = "Areas",
             info = "LMÍ's areas of the names (IS 50V); a click chooses the name.") |>
  og_polygon(isor_ar, colour = "#b2182b", fill = "#b2182b", opacity = 0.10, linewidth = 1.2, legend = FALSE, hover = name,
             popup = c(name, basis, feature), id = "isor_areas", name = "ÍSOR's areas", section = "Areas",
             info = "ÍSOR's areas of the names (the seabed map); a click chooses the name.") |>
  og_polygon(seamounts, colour = "#762a83", fill = "#762a83", opacity = 0.06, linewidth = 0.6, legend = FALSE, hover = label,
             popup = c(label, kind, top_depth_m, place_basis, seabed_id), visible = FALSE, id = "isor_seamounts",
             name = "ÍSOR's seamounts", section = "Areas", info = "ÍSOR's seamounts, a top each on the depth model.") |>
  og_polygon(troughs, colour = "#08306b", fill = "#08306b", opacity = 0.08, linewidth = 1, legend = FALSE, hover = label,
             popup = c(label, kind, top_depth_m, seabed_id), visible = FALSE, id = "isor_troughs", name = "ÍSOR's troughs",
             section = "Landforms", info = "ÍSOR's troughs (unnamed by ÍSOR; numbered here).") |>
  og_line(moraines, colour = "#7f2704", linewidth = 1.5, legend = FALSE, hover = label, popup = c(label, kind, top_depth_m, seabed_id),
          visible = FALSE, id = "isor_moraines", name = "ÍSOR's moraines", section = "Landforms", info = "ÍSOR's terminal moraines.") |>
  og_polygon(lf_areas, colour = "#01665e", fill = kind, palette = LF_AREA_COL, opacity = 0.12, linewidth = 0.8, hover = label,
             popup = c(label, kind, top_depth_m, seabed_id), visible = FALSE, id = "isor_channels", name = "ÍSOR's channels",
             section = "Landforms", info = "ÍSOR's turbidity and meltwater channels.") |>
  og_line(shelf_break, colour = "#543005", linewidth = 1.2, legend = FALSE, hover = label, popup = c(label, kind, seabed_id),
          visible = FALSE, id = "isor_shelf_break", name = "ÍSOR's shelf break", section = "Landforms",
          info = "ÍSOR's shelf break, drawn as its line (ÍSOR's polygon is the whole shelf inside it).") |>
  og_line(lf_lines, colour = kind, palette = LF_LINE_COL, linewidth = 1, hover = label, popup = c(label, kind, top_depth_m, seabed_id),
          visible = FALSE, id = "isor_streamlines", name = "ÍSOR's streamlines and canals", section = "Landforms",
          info = "ÍSOR's glacial and gravity streamlines and its canals along the shelf edge.") |>
  prop_layers() |>
  og_point(twc[!twc$outcome %in% TW_CAND, ], colour = outcome, palette = TW_COL, size = c(3, 7), hover = name, visible = FALSE,
           popup = c(name, spellings, tows, vessels, share, outcome, place_basis, key), id = "tw_others",
           name = "Trackwell's other names", section = "Trackwell", choose = outcome,
           info = "Trackwell's names in the open regions that are not candidates: already a name of ours, used by one vessel, or carried in from elsewhere.") |>
  og_point(twc[twc$outcome %in% TW_CAND, ], colour = outcome, palette = TW_COL, size = c(6, 11), hover = name,
           popup = c(name, spellings, tows, vessels, share, outcome, place_basis, verdict, key), id = "tw_candidates",
           name = "Trackwell's candidates", section = "Trackwell",
           info = "Trackwell's names that pass the rule in the open regions; a click offers Accept or Reject. An accepted one is a name at the next build.") |>
  og_point(guyots, colour = "#2166ac", size = c(5, 10), hover = label, minzoom = 7, legend = FALSE,
           popup = c(label, kind, depth_m, study, seabed_id), id = "isor_guyots", name = "ÍSOR's guyots", section = "Areas",
           info = "ÍSOR's guyots, flat-topped seamounts, every one the 2023 mapping's (EGU23-15536) and labelled by its ridge. With a name chosen, a click on one offers Link to this mound.") |>
  og_point(craters, colour = kind, palette = CRATER_COL, size = c(4, 9), hover = label, minzoom = 7, choose = study,
           popup = c(label, kind, depth_m, height, study, seabed_id), id = "isor_craters", name = "ÍSOR's craters", section = "Areas",
           info = "ÍSOR's craters (its labels, placeholders until named), by the study that mapped them. With a name chosen, a click on one offers Link to this mound.") |>
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
  og_segment(pl, lon = "lon", lat = "lat", lon_end = lon_end, lat_end = lat_end, colour = outcome, palette = PAIR_COL, linewidth = 2,
             popup = c(names, outcome, km), id = "review_pairs", name = "One name, two sources", section = "To review",
             info = "A line between two rows of one name from two sources (version 2's rule): joined into one, a whole and its part, or doubtful.") |>
  og_point(rv, colour = first_reason, palette = RV_COL, size = c(7, 12), hover = name, popup = c(name, reason, detail, src),
           id = "review", name = sprintf("Version %d's review", VERSION), section = "To review", choose = first_reason,
           info = "What version 2 asks you to look at, at the thing; Faxaflói and Reykjaneshryggur first (plan 080 ask j).") |>
  og_text(dots, label = bullet, minzoom = z0, size = 18, colour = "#1a1a1a", overlap = TRUE, id = "name_dots",
          name = "Dots at the points named", section = "Names",
          info = "A rock, a shoal or a skerry: a dot at the thing, its name beside it (version 2).") |>
  og_text(nl, label = name, minzoom = z_line, size = size, fontface = face, colour = style, palette = NAME_COL, whole = TRUE,
          id = "name_lines", name = "Long names along their lines", section = "Names",
          info = "The long names along their lines, from the zoom a line holds the name.") |>
  og_text(n, label = name, minzoom = z0, angle = turn, priority = pr, size = sz, fontface = face, offset = c(ox, up),
          colour = style, palette = NAME_COL, choose = c(src, style, hand), popup = all_of(INFO), whole = TRUE,
          id = "names", name = "Names", section = "Names",
          info = "Each name at its place, from the first whole zoom at or above the zoom it deserves; a name gives way where two collide.",
          "text-size" = TEXT_SIZE, "text-letter-spacing" = list("case", list("==", list("get", "style"), "water"), 0.15, 0),
          # a point kind's name beside its dot: its offset to the right (ogis's key of an offset, og_off "x|y", GAP)
          "text-anchor" = list("case", list("==", list("slice", list("to-string", list("get", "og_off")), 0, 5), "0.700"), "left", "center"),
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
ext_by <- local({ e <- ex[ex$what == "extent" & ex$used, ]; split(e, e$feature) })
extent_fc <- function(id) { e <- ext_by[[as.character(id)]]; if (is.null(e)) return('{"type":"FeatureCollection","features":[]}')
  tf <- tempfile(fileext = ".geojson"); on.exit(unlink(tf)); st_write(e["basis"], tf, quiet = TRUE, driver = "GeoJSON")
  paste(readLines(tf, warn = FALSE, encoding = "UTF-8"), collapse = "") }
# the rows the search and a search's choice read: every name, aid and wreck; a name with the row it is in the names layer
idx <- st_drop_geometry(n)[, INFO]; idx$lon <- n$lon; idx$lat <- n$lat; idx$og_row <- seq_len(nrow(idx)); idx$type <- "name"
idx0 <- idx                                    # as the names layer was sent
others <- bind_rows(st_drop_geometry(a) |> transmute(feature = NA_integer_, id, name, style = kind, src = "aid", type = "aid", lon, lat, z0 = 10),
                    st_drop_geometry(w) |> filter(nzchar(label)) |> transmute(feature = NA_integer_, id, name = label, style = "wreck", src = "wreck", type = "wreck", lon, lat, z0 = 13))
fold <- function(s) tolower(iconv(s, "UTF-8", "ASCII//TRANSLIT"))
COLS <- c("feature", "name", "lon", "lat", "rot", "angle_deg", "z0", "comp_z0", "action", "at", "by", "comp_lon", "comp_lat",
          "new_name", "why", "link_to")
PLACE <- c("move", "turn", "move and turn", "revert"); ZOOM <- c("zoom", "zoom back"); RENAME <- "rename"; SYNONYM <- "synonym"; PIN <- c("pin", "unpin"); LINK <- c("link", "unlink")
VERDICT <- c("accept", "reject")
append_row <- function(row) { for (c in setdiff(COLS, names(row))) row[[c]] <- NA
  write.table(row[, COLS], EF, sep = ",", row.names = FALSE, col.names = !file.exists(EF), append = file.exists(EF),
              fileEncoding = "UTF-8", qmethod = "double") }
in_sea <- function(lon, lat) is.numeric(lon) && is.numeric(lat) && lon > -45 && lon < 0 && lat > 55 && lat < 72
good_name <- function(x) is.character(x) && length(x) == 1 && !is.na(x) && nchar(trimws(x)) %in% 1:80 && !grepl("[\r\n\t\"]", x)
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
  # Claude's proposals: one by its key or its name's id, with its evidence and its place in the queue; its shapes; the queue
  proposal = function(req) { if (is.null(pp)) return(NULL)
    key <- as.character(arg(req, "key") %||% ""); i <- if (nzchar(key)) match(key, pp$key) else match(as.numeric(arg(req, "name_id") %||% NA), pp$name_id)
    if (is.na(i)) return(NULL)
    p <- st_drop_geometry(pp[i, ]); e <- pev[pev$key == p$key, intersect(c("trough", "part", "moraine", "group", "member", "outcome", "value", "detail"), names(pev))]
    list(p = as.list(p), ev = e, q = match(p$key, queue$key), n = nrow(queue)) },
  proposal_shape = function(req) { if (is.null(pp)) return('{"type":"FeatureCollection","features":[]}')
    s <- psh[psh$key == as.character(arg(req, "key") %||% ""), c("what", "basis")]
    if (!nrow(s)) return('{"type":"FeatureCollection","features":[]}')
    tf <- tempfile(fileext = ".geojson"); on.exit(unlink(tf)); st_write(s, tf, quiet = TRUE, driver = "GeoJSON")
    paste(readLines(tf, warn = FALSE, encoding = "UTF-8"), collapse = "") },
  proposal_queue = function(req) if (is.null(pp)) data.frame() else queue,
  # the names edited since the server started (ogis reads a layer's data once; the script lays these on)
  changed = function(req) {
    k <- which(idx$lon != idx0$lon | idx$lat != idx0$lat | idx$rot != idx0$rot | idx$z0 != idx0$z0 | idx$edited != idx0$edited |
                 idx$zoom_by != idx0$zoom_by | idx$name != idx0$name | idx$thing_lon != idx0$thing_lon | idx$thing_lat != idx0$thing_lat)
    x <- idx[k, c("og_row", "feature", "name", "lon", "lat", "rot", "z0", "edited", "zoom_by", "dy", "size", "pk", "thing_lon", "thing_lat", "pinned")]
    x$dots_row <- match(x$feature, dots$feature); x },
  # an edit, in 75's columns and by 75's checks: a row appended, never rewritten
  edit = function(req) {
    if (req$method != "POST") stop("POST an edit")
    x <- req$body; place <- x$action %in% PLACE && x$action != "revert"
    if (isTRUE(x$action %in% c("accept proposal", "reject proposal"))) {   # Claude's proposal accepted or rejected (plan 081)
      j <- if (is.null(pp)) NA else match(as.character(x$link_to %||% ""), pp$key)
      if (is.na(j) || !(is.null(x$why) || (is.character(x$why) && nchar(x$why) <= 300 && !grepl("[\r\n]", x$why)))) stop("not a proposal this page knows")
      row <- data.frame(feature = as.integer(pp$name_id[j]), name = pp$name[j], action = x$action, at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                        by = "the maintainer", link_to = pp$key[j], why = trimws(as.character(x$why %||% "")))
      append_row(row)
      # a trough no name of ours takes: his Accept also writes the name as his own over the trough (a row `new`), once
      if (x$action == "accept proposal" && is.na(pp$name_id[j]) && pp$name[j] != "(unnamed)") {
        ed0 <- if (file.exists(EF)) read.csv(EF, encoding = "UTF-8") else data.frame(action = character(), link_to = character())
        if (!any(ed0$action == "new" & ed0$link_to %in% pp$element[j] & ed0$name %in% pp$name[j]))
          append_row(data.frame(feature = NA_integer_, name = pp$name[j], lon = round(pp$lon[j], 6), lat = round(pp$lat[j], 6), action = "new", at = row$at,
                                by = "the maintainer", link_to = pp$element[j],
                                why = sprintf("the skippers' name of ÍSOR's %s, Claude's proposal accepted (%s)",
                                              if (pp$class[j] == "moraine") paste("moraine", pp$moraine[j]) else paste("trough", pp$trough[j]), pp$key[j]))) }
      pp$verdict[j] <<- paste0(sub(" proposal", "ed", x$action), " by the maintainer, ", row$at); pp$status[j] <<- sub(" proposal", "ed", x$action)
      queue$status[match(pp$key[j], queue$key)] <<- pp$status[j]
      return(list(ok = TRUE, at = row$at, verdict = pp$verdict[j]))
    }
    if (isTRUE(x$action %in% VERDICT)) {                    # a Trackwell candidate accepted or rejected
      j <- match(as.character(x$link_to %||% ""), twc$key)
      if (is.null(twc) || is.na(j)) stop("not a candidate this page knows")
      row <- data.frame(feature = NA_integer_, name = twc$name[j], action = x$action, at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                        by = "the maintainer", link_to = twc$key[j], why = as.character(x$why %||% ""))
      append_row(row)
      return(list(ok = TRUE, at = row$at, verdict = paste0(x$action, "ed")))
    }
    if (isTRUE(x$action %in% LINK)) {                       # a name to ÍSOR's crater or mound; the thing moves there (link)
      i <- match(as.integer(x$feature %||% NA), idx$feature); lk <- x$action == "link"
      j <- if (lk) match(as.character(x$link_to %||% ""), sfx$seabed_id) else NA
      if (is.na(i) || (lk && is.na(j))) stop("not a link this page makes")
      row <- data.frame(feature = idx$feature[i], name = idx$name[i], lon = if (lk) sfx$lon[j] else NA, lat = if (lk) sfx$lat[j] else NA,
                        action = x$action, at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), by = "the maintainer",
                        link_to = if (lk) sfx$seabed_id[j] else NA)
      append_row(row)
      if (lk) { idx$thing_lon[i] <<- sfx$lon[j]; idx$thing_lat[i] <<- sfx$lat[j]; idx$seabed_id[i] <<- sfx$seabed_id[j]
        idx$seabed[i] <<- paste0("ÍSOR's ", sfx$kind[j], " ", sfx$label[j], " (by the maintainer, ", row$at, ")") }
      else { idx$seabed_id[i] <<- ""; idx$seabed[i] <<- paste0("unlinked by the maintainer, ", row$at, "; the thing back at the next build") }
      follow <- lk && idx$pk[i] == 1L && !nzchar(idx$edited[i])
      if (follow) { idx$lon[i] <<- idx$thing_lon[i]; idx$lat[i] <<- idx$thing_lat[i] }
      return(list(ok = TRUE, at = row$at, lon = idx$thing_lon[i], lat = idx$thing_lat[i], follow = follow, seabed = idx$seabed[i],
                  dots_row = match(idx$feature[i], dots$feature)))
    }
    if (isTRUE(x$action %in% PIN)) {                        # where the thing is, by hand; a point kind's label follows it
      i <- match(as.integer(x$feature %||% NA), idx$feature)
      if (is.na(i) || (x$action == "pin" && !in_sea(x$lon, x$lat))) stop("not a pin this page makes")
      pin <- x$action == "pin"
      row <- data.frame(feature = idx$feature[i], name = idx$name[i], lon = if (pin) round(x$lon, 6) else NA, lat = if (pin) round(x$lat, 6) else NA,
                        rot = NA, angle_deg = NA, z0 = NA, comp_z0 = NA, action = x$action, at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                        by = "the maintainer", comp_lon = idx$comp_thing_lon[i], comp_lat = idx$comp_thing_lat[i], new_name = NA, why = NA)
      append_row(row)
      idx$thing_lon[i] <<- if (pin) row$lon else idx$comp_thing_lon[i]; idx$thing_lat[i] <<- if (pin) row$lat else idx$comp_thing_lat[i]
      idx$pinned[i] <<- if (pin) row$at else ""
      follow <- idx$pk[i] == 1L && !nzchar(idx$edited[i])
      if (follow) { idx$lon[i] <<- idx$thing_lon[i]; idx$lat[i] <<- idx$thing_lat[i] }
      return(list(ok = TRUE, at = row$at, lon = idx$thing_lon[i], lat = idx$thing_lat[i], follow = follow,
                  dots_row = match(idx$feature[i], dots$feature)))
    }
    if (identical(x$action, SYNONYM)) {                     # another name of the feature, the name used unchanged
      i <- match(as.integer(x$feature %||% NA), idx$feature)
      have <- trimws(strsplit(chr(idx$synonyms[i]), ";")[[1]])
      if (is.na(i) || !good_name(x$new_name) || trimws(x$new_name) %in% c(idx$name[i], have) ||
          !(is.null(x$why) || (is.character(x$why) && nchar(x$why) <= 300 && !grepl("[\r\n]", x$why))))
        stop("not a synonym this page adds: 1-80 letters, not the name or a synonym it has")
      row <- data.frame(feature = idx$feature[i], name = idx$name[i], lon = NA, lat = NA, rot = NA, angle_deg = NA, z0 = NA, comp_z0 = NA,
                        action = SYNONYM, at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), by = "the maintainer",
                        comp_lon = NA, comp_lat = NA, new_name = trimws(x$new_name), why = trimws(x$why %||% ""))
      append_row(row)
      idx$synonyms[i] <<- paste(c(have[nzchar(have)], row$new_name), collapse = "; ")
      return(list(ok = TRUE, at = row$at, synonyms = idx$synonyms[i]))
    }
    if (identical(x$action, RENAME)) {
      i <- match(as.integer(x$feature %||% NA), idx$feature)
      if (is.na(i) || !good_name(x$new_name) || trimws(x$new_name) == idx$name[i] ||
          !(is.null(x$why) || (is.character(x$why) && nchar(x$why) <= 300 && !grepl("[\r\n]", x$why))))
        stop("not a rename this page makes: a new name of 1-80 letters, other than the name now")
      row <- data.frame(feature = idx$feature[i], name = idx$name[i], lon = NA, lat = NA, rot = NA, angle_deg = NA, z0 = NA, comp_z0 = NA,
                        action = RENAME, at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), by = "the maintainer",
                        comp_lon = NA, comp_lat = NA, new_name = trimws(x$new_name), why = trimws(x$why %||% ""))
      append_row(row)
      idx$name[i] <<- row$new_name
      return(list(ok = TRUE, at = row$at, name = row$new_name))
    }
    ok <- is.numeric(x$feature) && x$action %in% c(PLACE, ZOOM) &&
      (!place || (is.numeric(x$lon) && is.numeric(x$lat) && is.numeric(x$rot) && abs(x$rot) <= 90 && x$lon > -45 && x$lon < 0 && x$lat > 55 && x$lat < 72)) &&
      (x$action != "zoom" || (is.numeric(x$z0) && x$z0 >= 3 && x$z0 <= 18 && x$z0 == round(x$z0)))
    if (!isTRUE(ok)) stop("not an edit this page makes")
    row <- data.frame(feature = as.integer(x$feature), name = as.character(x$name %||% ""), lon = if (place) round(x$lon, 6) else NA,
                      lat = if (place) round(x$lat, 6) else NA, rot = if (place) round(x$rot, 1) else NA,
                      angle_deg = if (place) round((x$rot + 90) %% 180, 1) else NA,
                      z0 = if (x$action == "zoom") x$z0 else NA, comp_z0 = if (x$action %in% ZOOM && is.numeric(x$comp_z0)) x$comp_z0 else NA,
                      action = x$action, at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), by = "the maintainer",
                      comp_lon = if (is.numeric(x$comp_lon)) x$comp_lon else NA, comp_lat = if (is.numeric(x$comp_lat)) x$comp_lat else NA,
                      new_name = NA, why = NA)
    append_row(row)
    i <- match(row$feature, idx$feature)
    if (!is.na(i)) {
      if (place) { idx$lon[i] <<- row$lon; idx$lat[i] <<- row$lat; idx$rot[i] <<- row$rot; idx$edited[i] <<- row$at }
      if (x$action == "revert") { idx$lon[i] <<- idx$comp_lon[i]; idx$lat[i] <<- idx$comp_lat[i]; idx$rot[i] <<- idx$comp_rot[i]; idx$edited[i] <<- "" }
      if (x$action %in% ZOOM) { idx$z_rule[i] <<- if (x$action == "zoom") row$z0 else idx$comp_z0[i]; idx$z0[i] <<- idx$z_rule[i]
        idx$zoom_by[i] <<- if (x$action == "zoom") paste0("the maintainer, ", row$at) else "" } }
    list(ok = TRUE, at = row$at) })
message("The marine features map: http://127.0.0.1:", PORT, " (edits to ", EF, ")")
og_serve(m, port = PORT, open = FALSE, routes = routes, wait = !interactive())
