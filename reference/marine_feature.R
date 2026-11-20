# marine_feature.R — one table of what the map shows: the names, the wrecks and the aids to navigation, a row each, told apart
# by `type` and `kind` (plan 074 step 12; the maintainer, 2026-11-19: "names, wrecks and lights and beacons ... all in one
# single dartaframe, seperable by filter on a variable name"; the name his, ask x).
# Side: preprocessing (sea-chart names). Standalone, run by hand after the three lists, outside the targets flow.
#
# Input:  curated/reference/marine_name.parquet and marine_name_extent.parquet (reference/names/marine_name.R),
#         curated/reference/wreck.parquet (reference/wrecks/wreck.R), curated/reference/aid.parquet (reference/aids/aid.R),
#         the named-features study's frozen names_v1/{feature_aid,aid_place_name}.csv (its 111: which named feature each aid
#         stands on, every aid in Iceland in one outcome)
# Output: curated/reference/marine_feature.parquet      - one row per name's feature, wreck's place or aid: `id`
#                                                         ("name:<id>", "wreck:<place>", "aid:<aid>"), `type`, `kind`, the
#                                                         list's own id, name, place and angle with their basis, the zoom it
#                                                         deserves, `rank` and `priority`, `holder` and `on_feature`, extent,
#                                                         `internal`, flags; WKB `geometry` (the point)
#         curated/reference/marine_feature_link.parquet - every link of a wreck or an aid to a named feature, the chosen one
#                                                         `on_feature`
#
# What one list alone has stays in its own tables, joined by the list's id (`list_id`): a light's characteristic in aid, a
# wreck's year and depth in wreck, a name's letterings and LMÍ's source in marine_name_source.
# - The ranking (ask y, the maintainer, 2026-11-19: "Places first; aids z10; wrecks fine"): `rank` 1 a name, 2 an aid, 3 a
#   wreck, the page giving way in that order; within a rank `priority` (a name's, version 1's: larger first). An aid's name
#   deserves zoom 10 (as the names editor drew them); a wreck's WRECK_Z, 13 (Claude's choice for "a fine zoom", his to
#   correct), its dot the page's at every zoom.
# - `on_feature`: an aid's named feature from 111's links, in the order lettered with the feature's name, on its island, at its
#   island's point, at its island's edge, then the nearest; a wreck's the smallest LMÍ or ÍSOR area of a name in the list that
#   holds it (Claude's rule for version 1). Every link in marine_feature_link.
# - `internal`: a wreck known only from internal lists or taking an attribute from one (the wreck list's flags), so that a copy
#   shared outside drops it by one filter; no name or aid is internal.
# - Version 2 (plan 080 §5.2): `lon`, `lat` where the thing is, `label_lon`, `label_lat` where its name is drawn (an aid's and a
#   wreck's at the thing), `point_kind` a dot at the thing (every aid and wreck); `name_source` and `name_basis` the name's
#   source spelling and whose the name used is; `version`. An aid's link (111) to a name joined into another in version 2
#   goes to the row kept (marine_name_pair's `kept`).
# Run from the repo root: Rscript reference/marine_feature.R   (TRIAL=1 reads the study's wreck prototype and writes under
# curated/scratch/marine_feature_trial/, before the wreck list is in fishycode). Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)   # standalone: not targets'
TRIAL <- Sys.getenv("TRIAL") == "1"
WRECK_Z <- 13; AID_Z <- 10
V1 <- fd_path("archive", "2026-11-11-named-features", "out", "frozen", "names_v1")
VERSION <- 3L   # version 2 frozen 2026-11-20 (decision 338)
REF <- function(f) fd_curated("reference", f)
WRECK <- if (TRIAL) fd_path("archive", "2026-11-11-named-features", "out", "wrecks", "wreck.parquet") else REF("wreck.parquet")
OUT <- if (TRIAL) fd_curated("scratch", "marine_feature_trial") else fd_curated("reference")
SCRIPT <- "reference/marine_feature.R"
INPUTS <- c(REF("marine_name.parquet"), REF("marine_name_extent.parquet"), REF("marine_name_pair.parquet"), WRECK, REF("aid.parquet"),
            file.path(V1, c("feature_aid.csv", "aid_place_name.csv")))
area_of <- function(lon, lat) ifelse(lon >= -8 & lon <= -6 & lat >= 61.3 & lat <= 62.5, "faroes",   # as reference/aids/aid.R
  ifelse(lat > 67.5 & lon < -20, "greenland", ifelse(lon >= -25.5 & lon <= -12.5 & lat >= 62.9 & lat <= 67.6, "iceland", "other")))
pq <- function(p) as.data.frame(nanoparquet::read_parquet(p))

nm <- pq(REF("marine_name.parquet")); aid <- pq(REF("aid.parquet")); wr <- pq(WRECK)
fa <- read.csv(file.path(V1, "feature_aid.csv"), encoding = "UTF-8"); ap <- read.csv(file.path(V1, "aid_place_name.csv"), encoding = "UTF-8")
stopifnot(all(fa$aid %in% aid$aid), all(ap$aid %in% aid$aid), !anyDuplicated(wr$wreck), !anyDuplicated(aid$aid))
stopifnot("marine_name is not this script's version" = all(nm$version == VERSION))
pairs <- pq(REF("marine_name_pair.parquet")); jn <- pairs[pairs$outcome == "one thing", ]
jn$gone <- ifelse(jn$kept == jn$id_a, jn$id_b, jn$id_a)
fa$feature_v1 <- fa$feature
fa$feature <- ifelse(fa$feature %in% jn$gone, jn$kept[match(fa$feature, jn$gone)], fa$feature)
nid <- function(x) ifelse(is.na(x), NA_character_, paste0("name:", x))

# The names -----------------------------------------------------------------------------------------------------------
names_rows <- nm |> mutate(list_id = as.character(id)) |> transmute(
  id = nid(id), type = "name", kind, class, list = "marine_name", list_id, src, name, name_source, name_basis, synonyms, point_kind,
  lon, lat, place_basis, label_lon, label_lat, label_basis, rotate_deg, rotate_basis, z_rule, z_rule_basis, rank = 1L, priority,
  holder = nid(holder), on_feature = NA_character_, extent_km, extent_basis, size, label_dy, area = "iceland", internal = FALSE, flags,
  seabed_id, seabed_link)

# The aids: on the named feature 111 links them to -----------------------------------------------------------------------
LINK_ORDER <- c("lettered", "on_island,lettered", "on_island", "island_point", "island_edge")
al <- fa |> filter(!is.na(feature), feature %in% nm$id) |>
  transmute(from = paste0("aid:", aid), to = nid(feature), link, dist_m, order = match(link, LINK_ORDER)) |>
  mutate(order = coalesce(order, length(LINK_ORDER) + 1L))
stopifnot(all(fa$link %in% LINK_ORDER))
aid_on <- al |> arrange(from, order, dist_m) |> group_by(from) |> slice_head(n = 1) |> ungroup()
aid_rows <- aid |> transmute(
  id = paste0("aid:", aid), type = "aid", kind, class = NA_character_, list = "aid", list_id = as.character(aid), src = "aid", name,
  name_source = name, name_basis = "the aid list's", synonyms = NA_character_, point_kind = TRUE, lon, lat, place_basis = position_basis,
  label_lon = lon, label_lat = lat, label_basis = "at the aid", rotate_deg = 0, rotate_basis = "level",
  z_rule = AID_Z, z_rule_basis = "an aid's name from zoom 10 (ask y)", rank = 2L, priority = 0, holder = NA_character_,
  on_feature = aid_on$to[match(paste0("aid:", aid), aid_on$from)], extent_km = NA_real_, extent_basis = NA_character_,
  size = NA_real_, label_dy = NA_real_, area, internal = FALSE,
  flags = trimws(paste(ifelse(outcome == "conflict", paste0("conflict: ", why), ""),
                       ifelse(aid %in% ap$aid, paste0("place name: ", ap$place_name[match(aid, ap$aid)]), "")))) |>
  mutate(flags = na_if(flags, ""))

# The wrecks: in the smallest named area that holds them --------------------------------------------------------------
ex <- read_curated_sf(REF("marine_name_extent.parquet"))
ar <- ex[ex$what == "extent" & ex$used & st_geometry_type(ex) %in% c("POLYGON", "MULTIPOLYGON"), ] |> st_transform(3057) |> st_make_valid()
ar$area_km2 <- as.numeric(st_area(ar)) / 1e6
wp <- st_transform(st_as_sf(wr, coords = c("lon", "lat"), crs = 4326, remove = FALSE), 3057)
hit <- st_intersects(wp, ar)
wl <- bind_rows(lapply(seq_along(hit), function(i) if (length(hit[[i]]))
  tibble(from = paste0("wreck:", wr$wreck[i]), to = nid(ar$feature[hit[[i]]]), link = "within_extent", dist_m = 0,
         area_km2 = ar$area_km2[hit[[i]]])))
wreck_on <- wl |> arrange(from, area_km2) |> group_by(from) |> slice_head(n = 1) |> ungroup()
wreck_rows <- wr |> transmute(
  id = paste0("wreck:", wreck), type = "wreck", kind = "wreck", class = NA_character_, list = "wreck", list_id = as.character(wreck),
  src = "wreck", name, name_source = name, name_basis = "the wreck list's", synonyms = NA_character_, point_kind = TRUE, lon, lat,
  place_basis = position_basis, label_lon = lon, label_lat = lat, label_basis = "at the wreck", rotate_deg = 0, rotate_basis = "level",
  z_rule = WRECK_Z, z_rule_basis = "a wreck's name from a fine zoom, 13 (ask y; Claude's choice of the zoom)", rank = 3L,
  priority = 0, holder = NA_character_, on_feature = wreck_on$to[match(paste0("wreck:", wreck), wreck_on$from)],
  extent_km = NA_real_, extent_basis = NA_character_, size = NA_real_, label_dy = NA_real_, area = area_of(lon, lat),
  internal = coalesce(internal, FALSE) | coalesce(only_internal, FALSE),
  flags = trimws(paste(ifelse(outcome == "conflict", paste0("conflict: ", why), ""),
                       ifelse(!is.na(maybe_same_as) & nzchar(maybe_same_as), paste0("maybe the same wreck as ", maybe_same_as), "")))) |>
  mutate(flags = na_if(flags, ""))

# One table ------------------------------------------------------------------------------------------------------------
mf <- bind_rows(names_rows, aid_rows, wreck_rows) |> mutate(version = VERSION)
# one chosen row a wreck or aid (an aid may link to one feature twice: on its island and at the island's point)
links <- bind_rows(al |> arrange(from, order, dist_m) |> group_by(from) |> mutate(chosen = row_number() == 1L) |> ungroup(),
                   wl |> arrange(from, area_km2) |> group_by(from) |> mutate(chosen = row_number() == 1L) |> ungroup()) |>
  select(from, to, link, dist_m, chosen)
stopifnot(!anyDuplicated(mf$id), !anyNA(mf$lon), !anyNA(mf$lat), !anyNA(mf$z_rule), !anyNA(mf$place_basis),
          !anyNA(mf$label_lon), !anyNA(mf$label_lat), !anyNA(mf$label_basis), !anyNA(mf$point_kind),
          all(na.omit(c(mf$holder, mf$on_feature)) %in% mf$id), all(links$to %in% mf$id), all(links$from %in% mf$id))
mf_sf <- st_as_sf(mf, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
STAMP <- c("fd.version" = as.character(VERSION))
write_curated(mf_sf, file.path(OUT, "marine_feature.parquet"), inputs = INPUTS, script = SCRIPT, stamps = STAMP)
write_curated(links, file.path(OUT, "marine_feature_link.parquet"), inputs = INPUTS, script = SCRIPT, stamps = STAMP)
print(knitr::kable(count(mf, type, kind), caption = paste0("marine_feature", if (TRIAL) " (TRIAL: the study's wrecks)")))
message(sprintf("on_feature: %d of %d aids, %d of %d wrecks; internal: %d wrecks; links: %d", sum(!is.na(aid_rows$on_feature)),
                nrow(aid_rows), sum(!is.na(wreck_rows$on_feature)), nrow(wreck_rows), sum(mf$internal), nrow(links)))
