# marine_name.R — the names of the sea charts, LMÍ and ÍSOR as one list: a row a named feature, with one place, one angle,
# the zoom it deserves and the basis of each (plan 074 step 12, the names; marine_feature.R binds it with the wrecks and aids).
# Side: preprocessing (sea-chart names). Standalone, run by hand outside the targets flow (plan 074 ask p).
#
# Input:  $FISHYDATA/archive/2026-11-11-named-features/out/frozen/names_v1/ - the names map's version 1, frozen 2026-11-19 by
#         the study's 133 (the maintainer: "Freeze v1 as an input"): names.geojson (every name shown, its computed place,
#         angle and zoom), extent, hierarchy, lettering_feature, letterings (the charts' features), island, island_place
#         (the islands, 110), lmi_record, lmi_feature, chart_join (LMÍ's names, 128), isor_record, isor_feature, isor_join
#         (ÍSOR's, 131), lmi_extent, isor_extent, name_lines (the extents and the long names' lines), not_shown; its
#         manifest.csv's md5s are checked first
#         staging/is50v/name.parquet (sources/is50v/name.R: IS 50V's 200,674 names), staging/isor/seabed_name.parquet
#         (sources/isor/seabed_name.R: ÍSOR's 2,825 records), curated/reference/chart_names.parquet (the charts' 8,203 labels)
#         overrides/marine_name_edits.csv (the maintainer's moves and turns in the names editor, append-only, latest counts),
#         marine_name_reading.csv (misreads corrected, ask v), marine_name_duplicate.csv (duplicates flagged, ask v),
#         marine_name_variant.csv (the charts' misprints named as meant, by the maintainer; v1 holds them already, the edits
#         made under a misprint are matched through it)
# Output: curated/reference/marine_name.parquet        - one row per named feature (25,879): its place as WKB `geometry`
#         curated/reference/marine_name_source.parquet - one row per link of a feature to a source record (a chart's
#                                                        lettering, an LMÍ record, an ÍSOR record) and its role
#         curated/reference/marine_name_record.parquet - every record of the three sources in one outcome: the charts'
#                                                        8,203 labels, IS 50V's 200,674 names, ÍSOR's 2,825 records
#         curated/reference/marine_name_extent.parquet - each feature's extent where a source gives one (LMÍ's area or line,
#                                                        ÍSOR's area) and the long names' lines, WKB `geometry`
#
# Version 1's rules are the study's (scripts 42-131, its README), not repeated here: this script takes their results as they
# are and lays on three things decided after them:
# - the submerged rocks at LMÍ's position (the maintainer, 2026-11-17: "Submerged rocks - position from LMÍ"): a chart
#   feature of the point class "rock or shoal" joined to LMÍ records of its name (128's chart_join) whose bearers are all a
#   rock's (ROCK) takes their position, the chart's anchor a witness, `lmi_moved_m` beside it and `far_from_chart` where it
#   lies more than 12 mm from the chart's place at its finest chart's scale (step 4's listing rule); joined to another
#   bearer (an island, a fishing ground) it keeps the anchor, flagged `lmi_bearer_differs` (Claude's reading of "rock");
# - the misreads corrected and the duplicates flagged (ask v), from overrides/;
# - the maintainer's edits, each feature's latest (a revert drops its edits), matched as the study's 71 matched them: by
#   number where the name agrees, else the feature of that name nearest the edit's computed place within 30 km or its box;
#   the zoom a stream of its own (a zoom edit fixes `z_rule`, a zoom back gives the rule's again), as 71 and the page keep it.
# The traffic jam is the page's: `z_rule` is the zoom a name deserves, the page draws it from there or later.
# LMÍ's source (heimild) is as LMÍ publishes it with its names. Run from the repo root: Rscript reference/names/marine_name.R
# Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)   # standalone: not targets'

V1 <- fd_path("archive", "2026-11-11-named-features", "out", "frozen", "names_v1")
man <- read.csv(file.path(V1, "manifest.csv"))
stopifnot("a frozen file of names_v1 changed" = identical(unname(tools::md5sum(file.path(V1, man$file))), man$md5))
rd <- function(f) read.csv(file.path(V1, f), encoding = "UTF-8")
ov <- function(f) read.csv(file.path("overrides", f), encoding = "UTF-8")
SCRIPT <- "reference/names/marine_name.R"
INPUTS <- c(file.path(V1, man$file), fd_staging("is50v", "name.parquet"), fd_staging("isor", "seabed_name.parquet"),
            fd_curated("reference", "chart_names.parquet"),
            file.path("overrides", c("marine_name_edits.csv", "marine_name_reading.csv", "marine_name_duplicate.csv",
                                     "marine_name_variant.csv")))
ROCK <- c("boði", "sker", "skerjaklasi", "rif", "drangur", "klettur", "steinn", "stapi", "flös", "flaga", "hlein", "grynning")
uuids <- function(x) strsplit(ifelse(is.na(x), "", x), "\\s+")
same <- function(a, b) !is.na(a) & !is.na(b) & tolower(a) == tolower(b)

# Version 1's names -------------------------------------------------------------------------------------------------------
g <- jsonlite::fromJSON(file.path(V1, "names.geojson"), simplifyVector = TRUE)$features
p <- g$properties
xy <- do.call(rbind, g$geometry$coordinates)
ext <- rd("extent.csv"); hie <- rd("hierarchy.csv"); cj <- rd("chart_join.csv"); lf <- rd("lmi_feature.csv")
isf <- rd("isor_feature.csv"); let <- rd("letterings.csv"); ltf <- rd("lettering_feature.csv"); ns <- rd("not_shown.csv")
ip <- rd("island_place.csv"); isl <- rd("island.csv")

place_code <- function(src, txt) case_when(
  grepl("by hand", txt) ~ "hand",
  src == "chart" & grepl("^LMÍ's position", txt) ~ "lmi_position",
  src == "chart" & grepl("^its anchor", txt) ~ "anchor",
  src == "chart" & grepl("^its box's middle", txt) ~ "box_middle",
  src == "chart" & grepl("on its line|slid along its line", txt) ~ "line",
  src == "chart" & grepl("^its finest lettering", txt) ~ "finest_lettering",
  grepl("^its area's middle", txt) ~ "area_middle",
  grepl("^its line's middle", txt) ~ "line_middle",
  grepl("hull round its islets", txt) ~ "islets_hull_middle",
  grepl("^LMÍ's point|^ÍSOR's point", txt) ~ "point",
  grepl("^a point on it", txt) ~ "point_on_it",
  grepl("record's point", txt) ~ "record_point")
angle_code <- function(txt) case_when(grepl("by hand", txt) ~ "hand", grepl("^level", txt) ~ "level",
                                      grepl("landscape line", txt) ~ "landscape_line",
                                      grepl("finest turned lettering", txt) ~ "finest_turned_lettering")
nm <- tibble(
  id = as.integer(p$feature), src = p$src, name = p$name, name_printed = na_if(p$printed, ""), kind = p$style,
  lon0 = p$comp_lon, lat0 = p$comp_lat, rotate0 = p$comp_rot, lon_v1 = xy[, 1], lat_v1 = xy[, 2], rotate_v1 = p$rot,
  place_basis_computed = place_code(p$src, p$place), place_note_v1 = p$place, angle_note_v1 = p$angle,
  rotate_basis = angle_code(p$angle), rotate_low_deg = p$rot_low, level_from_zoom = p$level_from,
  z_rule = p$comp_z0, z_rule_v1 = p$z_rule, size = p$size, priority = p$prio, label_dy = p$dy,
  lmi_source = na_if(p$lmi_source, ""), lmi_source_kind = na_if(p$lmi_source_kind, ""), island_flags = na_if(p$island_flags, ""),
  edited_v1 = na_if(p$edited, ""))
stopifnot(nrow(nm) == 25880L, !anyDuplicated(nm$id), !anyNA(nm$place_basis_computed), !anyNA(nm$rotate_basis),
          !anyNA(nm$z_rule), all(nm$z_rule == nm$z_rule_v1))   # no zoom edit in the record: the rule's zoom is the shown one
# v1 overwrote a hand-moved name's computed basis with "by hand": its computed place is kept (lon0, lat0), its basis not
nm$place_basis_computed[nm$place_basis_computed == "hand"] <- NA
nm$rotate_basis[nm$rotate_basis == "hand"] <- NA

# Each feature's class, extent, holder and letterings ---------------------------------------------------------------------
fin <- let |> group_by(feature) |> summarise(finest_scale = min(scale), n_letterings = n(), .groups = "drop")
ch <- nm$src == "chart"; li <- nm$src == "lmi"; io <- nm$src == "isor"
m <- match(nm$id, ext$feature); nm$class <- ifelse(ch, coalesce(na_if(ext$point_class[m], ""), ext$sort[m]), NA)
nm$charts <- ifelse(ch, ext$charts[m], NA_integer_); nm$coarsest_chart <- ifelse(ch, ext$coarsest[m], NA)
mj <- match(nm$id, cj$feature)
nm$extent_km <- ifelse(ch, coalesce(cj$lmi_extent_km[mj], ext$extent_km[m]), NA_real_)
nm$extent_basis <- ifelse(ch, ifelse(!is.na(cj$lmi_extent_km[mj]), paste0("LMÍ's: ", cj$lmi_extent_basis[mj]), ext$extent_basis[m]), NA)
ml <- match(nm$id, lf$feature)
nm$class[li] <- lf$class[ml[li]]; nm$extent_km[li] <- lf$extent_km[ml[li]]; nm$extent_basis[li] <- lf$extent_basis[ml[li]]
nm$synonyms <- ifelse(li, na_if(lf$second_name[ml], ""), NA)
mi <- match(nm$id, isf$feature)
nm$class[io] <- isf$kind[mi[io]]; nm$extent_km[io] <- isf$extent_km[mi[io]]; nm$extent_basis[io] <- isf$extent_basis[mi[io]]
nm$synonyms[io] <- na_if(isf$synonym[mi[io]], ""); nm$isor_references <- ifelse(io, isf$references[mi], NA)
nm$z_rule_basis <- case_when(ch ~ "rule e on its extent (step 5)",
                             !is.na(nm$extent_km) ~ "rule e on its extent (step 5)",
                             li ~ "LMÍ's display scale (birtingarkvardi), its size class",
                             io ~ "a point with no extent, from 1:25 000 (Claude's choice, his to correct)")
mh <- match(nm$id, hie$feature)
nm$holder <- ifelse(ch, hie$holder[mh], NA_integer_); nm$holder_name <- ifelse(ch, na_if(hie$holder_name[mh], ""), NA)
mf <- match(nm$id, fin$feature); nm$finest_scale <- fin$finest_scale[mf]; nm$n_letterings <- coalesce(fin$n_letterings[mf], 0L)
fl <- ifelse(ch, cj$flags[mj], ifelse(li, lf$flags[ml], ifelse(io, isf$flags[mi], NA)))
nm$flags <- vapply(seq_len(nrow(nm)), function(i) { z <- c(na_if(fl[i], ""), nm$island_flags[i]); z <- z[!is.na(z) & nzchar(z)]
  if (length(z)) paste(z, collapse = "; ") else NA_character_ }, "")
nm$island_flags <- NULL

# The submerged rocks at LMÍ's position ------------------------------------------------------------------------------------
st <- read_curated_sf(fd_staging("is50v", "name.parquet"))
lmi_pos <- function(u) {   # an LMÍ record's position: its point, a line's middle, a polygon's point on its surface
  x <- st_transform(st[st$uuid %in% u, ], 3057)
  pt <- lapply(seq_len(nrow(x)), function(i) { gi <- st_geometry(x)[i]
    if (x$layer[i] == "point") st_coordinates(gi)[1, 1:2]
    else if (x$layer[i] == "line") st_coordinates(st_line_sample(st_cast(gi, "LINESTRING")[1], sample = 0.5))[1, 1:2]
    else st_coordinates(st_point_on_surface(gi))[1, 1:2] })
  colMeans(do.call(rbind, pt)) }
rock <- nm$id[ch & nm$class %in% "rock or shoal" & !nm$id %in% ip$feature]
rj <- cj[cj$feature %in% rock, ]
rj$rock_bearer <- vapply(strsplit(rj$bearers, ",\\s*"), function(b) all(b %in% ROCK), logical(1))
nm$lmi_moved_m <- NA_real_; nm$place_basis <- nm$place_basis_computed
for (i in which(rj$rock_bearer)) {
  k <- match(rj$feature[i], nm$id); q <- lmi_pos(uuids(rj$uuids[i])[[1]])
  a <- st_coordinates(st_transform(st_sfc(st_point(c(nm$lon0[k], nm$lat0[k])), crs = 4326), 3057))[1, 1:2]
  nm$lmi_moved_m[k] <- sqrt(sum((q - a)^2))
  ll <- st_coordinates(st_transform(st_sfc(st_point(q), crs = 3057), 4326))[1, ]
  nm$lon0[k] <- ll[1]; nm$lat0[k] <- ll[2]; nm$place_basis[k] <- "lmi_position"
}
far <- !is.na(nm$lmi_moved_m) & nm$lmi_moved_m > 0.012 * nm$finest_scale
add_flag <- function(flags, k, f) ifelse(k, ifelse(is.na(flags), f, paste(flags, f, sep = "; ")), flags)
nm$flags <- add_flag(nm$flags, far, "far_from_chart")
nm$flags <- add_flag(nm$flags, nm$id %in% rj$feature[!rj$rock_bearer], "lmi_bearer_differs")
message(sprintf("submerged rocks: %d of %d rock-or-shoal features joined to LMÍ moved to its position (median %.0f m, %d far from the chart); %d joined to another bearer kept",
                sum(rj$rock_bearer), length(rock), median(nm$lmi_moved_m, na.rm = TRUE), sum(far), sum(!rj$rock_bearer)))

# The misreads and the duplicates (ask v) -----------------------------------------------------------------------------------
rdg <- ov("marine_name_reading.csv"); dup <- ov("marine_name_duplicate.csv")
stopifnot(all(rdg$feature %in% nm$id), all(c(dup$feature_a, dup$feature_b) %in% nm$id))
nm$reading_corrected <- NA_character_; nm$legend_entry <- FALSE
sp <- rdg[grepl("spelling", rdg$correction), ]
k <- match(sp$feature, nm$id); stopifnot(all(same(nm$name[k], sp$read_as)))
nm$name[k] <- sp$corrected; nm$reading_corrected[k] <- paste0(sp$read_as, " -> ", sp$corrected)
nm$legend_entry[match(rdg$feature[grepl("legend_entry", rdg$correction)], nm$id)] <- TRUE
nm$flags <- add_flag(nm$flags, nm$legend_entry, "legend_entry: the place is the chart's list of names, not the feature's")
piece <- rdg[grepl("^piece_of:", rdg$correction), ]; piece$into <- as.integer(sub("^piece_of:", "", piece$correction))
stopifnot(all(piece$into %in% nm$id), all(same(nm$name[match(piece$feature, nm$id)], piece$read_as)))
nm$possible_duplicate <- NA_integer_
nm$possible_duplicate[match(dup$feature_a, nm$id)] <- dup$feature_b; nm$possible_duplicate[match(dup$feature_b, nm$id)] <- dup$feature_a
nm$flags <- add_flag(nm$flags, !is.na(nm$possible_duplicate), "possible_duplicate")

# The maintainer's edits ---------------------------------------------------------------------------------------------------
vr <- ov("marine_name_variant.csv"); ed <- ov("marine_name_edits.csv")
box_km <- ext$box_km[match(nm$id, ext$feature)]
latest <- ed |> filter(action %in% c("move", "turn", "move and turn", "revert")) |>
  mutate(name = ifelse(tolower(name) %in% tolower(vr$printed), vr$name[match(tolower(name), tolower(vr$printed))], name)) |>
  arrange(at) |> group_by(feature, name) |> slice_tail(n = 1) |> ungroup()
names_as <- function(i) c(nm$name[i], nm$name_printed[i], sub(" -> .*", "", nm$reading_corrected[i]))
edit_row <- function(r) { i <- match(latest$feature[r], nm$id)
  if (!is.na(i) && any(same(names_as(i), latest$name[r]))) return(i)
  j <- which(same(nm$name, latest$name[r]) | same(nm$name_printed, latest$name[r])); if (!length(j) || is.na(latest$comp_lon[r])) return(NA_integer_)
  dk <- sqrt(((nm$lon0[j] - latest$comp_lon[r]) * 111.32 * cos(latest$comp_lat[r] * pi / 180))^2 + ((nm$lat0[j] - latest$comp_lat[r]) * 110.57)^2)
  if (min(dk) <= max(30, coalesce(box_km[j][which.min(dk)], 0))) j[which.min(dk)] else NA_integer_ }
latest$row <- vapply(seq_len(nrow(latest)), edit_row, 0L)
if (anyNA(latest$row)) stop("edits that found no feature: ", paste(latest$name[is.na(latest$row)], collapse = ", "))
mv <- latest[latest$action != "revert", ]
nm$lon <- nm$lon0; nm$lat <- nm$lat0; nm$rotate_deg <- nm$rotate0; nm$edited_at <- NA_character_
nm$lon[mv$row] <- mv$lon; nm$lat[mv$row] <- mv$lat; nm$rotate_deg[mv$row] <- mv$rot; nm$edited_at[mv$row] <- mv$at
nm$place_basis[mv$row] <- "hand"; nm$rotate_basis[mv$row] <- "hand"
stopifnot(!anyNA(nm$place_basis[is.na(nm$edited_at)]))
message(sprintf("edits: %d rows, %d features' latest, %d moved or turned by hand, %d reverted", nrow(ed), nrow(latest), nrow(mv),
                sum(latest$action == "revert")))
# the zoom, a stream of its own (the page's Earlier, Later and the rule's): a feature's latest zoom edit fixes the zoom it
# deserves, a zoom back gives the rule's again
zl <- ed |> filter(action %in% c("zoom", "zoom back")) |>
  mutate(name = ifelse(tolower(name) %in% tolower(vr$printed), vr$name[match(tolower(name), tolower(vr$printed))], name)) |>
  arrange(at) |> group_by(feature, name) |> slice_tail(n = 1) |> ungroup()
nm$z_rule_computed <- nm$z_rule; nm$zoom_edited_at <- NA_character_
if (nrow(zl)) {
  latest <- zl; zl$row <- vapply(seq_len(nrow(zl)), edit_row, 0L)
  if (anyNA(zl$row)) stop("zoom edits that found no feature: ", paste(zl$name[is.na(zl$row)], collapse = ", "))
  zz <- zl[zl$action == "zoom", ]
  nm$z_rule[zz$row] <- zz$z0; nm$zoom_edited_at[zz$row] <- zz$at
  nm$z_rule_basis[zz$row] <- paste0("the maintainer's hand, ", zz$at)
}
message(sprintf("zoom edits: %d features' latest, %d fixed by hand", nrow(zl), sum(!is.na(nm$zoom_edited_at))))

# The holders: v1's hierarchy (68) was made while the lights were still names, so a light may hold names; the next holder up
# that is in the list then holds them (hierarchy.csv lists every holder, nearest first)
gone <- piece$feature; keep <- setdiff(nm$id, gone)
hl <- lapply(strsplit(ifelse(is.na(hie$holders), "", as.character(hie$holders)), "\\s+"), function(z) suppressWarnings(as.integer(z)))
first_in <- vapply(hl, function(z) { z <- z[!is.na(z) & z %in% keep]; if (length(z)) z[1] else NA_integer_ }, 0L)
nm$holder_v1 <- nm$holder; nm$holder <- ifelse(ch, first_in[mh], NA_integer_)
nm$holder_name <- nm$name[match(nm$holder, nm$id)]
nm$holder_note <- ifelse(!is.na(nm$holder_v1) & !nm$holder_v1 %in% keep,
                         "the next holder up: version 1's nearest holder is not in the list (a light, now an aid)", NA)
message(sprintf("holders: %d features held, %d by the next holder up (v1's a light)", sum(!is.na(nm$holder)), sum(!is.na(nm$holder_note))))

# The feature list --------------------------------------------------------------------------------------------------------
out <- nm |> filter(!id %in% gone) |>
  transmute(id, src, name, name_printed, synonyms, kind, class, lon, lat, place_basis, place_basis_computed, lon_computed = lon0,
            lat_computed = lat0, lmi_moved_m, rotate_deg, rotate_basis, rotate_computed = rotate0, rotate_low_deg, level_from_zoom,
            z_rule, z_rule_basis, z_rule_computed, zoom_edited_at,
            extent_km, extent_basis, holder, holder_name, holder_note, size, priority, label_dy, n_letterings, charts, coarsest_chart, finest_scale,
            lmi_source, lmi_source_kind, isor_references, flags, possible_duplicate, reading_corrected, legend_entry, edited_at,
            place_note_v1, angle_note_v1)
out_sf <- st_as_sf(out, coords = c("lon", "lat"), crs = 4326, remove = FALSE)

# The links to the source records ------------------------------------------------------------------------------------------
# letterings.csv (71) holds each lettering with the feature it is shown as: a far piece of a long name (70) or a fjord's piece
# in another's water (76) is shown as its host, so 67's feature (lettering_feature.csv) may differ
ltf$key <- paste(ltf$chart, ltf$label_id, sep = "/"); let$key <- paste(let$chart, let$label_id, sep = "/")
stopifnot(setequal(ltf$key, let$key))
ltf$shown <- let$feature[match(ltf$key, let$key)]
ltf$into <- ltf$shown; k <- ltf$shown %in% piece$feature; ltf$into[k] <- piece$into[match(ltf$shown[k], piece$feature)]
src_chart <- ltf |> filter(into %in% out$id) |>
  transmute(id = into, source = "chart", source_id = key,
            role = case_when(shown %in% piece$feature ~ "lettering, a piece read cut short (overrides/marine_name_reading.csv)",
                             shown != feature ~ "lettering of a piece joined into it (the study's 70 or 76)",
                             TRUE ~ paste0("lettering: ", joined)))
lmi_link <- function(ids, us, role) tibble(id = rep(ids, lengths(us)), source = "lmi", source_id = unlist(us), role = role)
src_lmi <- bind_rows(
  lmi_link(lf$feature[lf$feature %in% out$id], uuids(lf$uuids[lf$feature %in% out$id]), "record"),
  lmi_link(cj$feature[cj$feature %in% out$id], uuids(cj$uuids[cj$feature %in% out$id]), "record joined to the chart's feature (one name)"),
  lmi_link(isl$feature[!is.na(isl$feature) & isl$feature %in% out$id], uuids(isl$uuid[!is.na(isl$feature) & isl$feature %in% out$id]),
           "island record (110)")) |> filter(nzchar(source_id)) |> distinct(id, source, source_id, .keep_all = TRUE)
ir <- rd("isor_record.csv"); ij <- rd("isor_join.csv")
src_isor <- bind_rows(
  ir |> filter(!is.na(isor_feature), isor_feature %in% out$id) |> transmute(id = as.integer(isor_feature), source = "isor", source_id = as.character(rid), role = "record"),
  # 131 counts a point and a line of one name as one witness (isor_join gives its first kind and the records' count)
  ir |> filter(outcome == "one name with the map's") |> mutate(grp = ifelse(kind == "area", "area", "point or line")) |>
    inner_join(ij |> transmute(id = feature, isor_name, grp = ifelse(isor_kind == "area", "area", "point or line")),
               by = c(name = "isor_name", "grp"), relationship = "many-to-many") |>
    filter(id %in% out$id) |> transmute(id, source = "isor", source_id = as.character(rid), role = "witness (one name with the map's)"))
src <- bind_rows(src_chart, src_lmi, src_isor) |> arrange(id, source, source_id)
stopifnot(all(out$id %in% src$id))

# Every source record in one outcome ---------------------------------------------------------------------------------------
cn <- nanoparquet::read_parquet(fd_curated("reference", "chart_names.parquet"))
lr <- rd("lmi_record.csv"); sr <- nanoparquet::read_parquet(fd_staging("isor", "seabed_name.parquet"))
rec_chart <- tibble(source = "chart", source_id = paste(cn$chart, cn$label_id, sep = "/"), name = cn$name) |>
  left_join(src_chart |> select(source_id, id, role), by = "source_id") |>
  left_join(ltf |> transmute(source_id = key, v1_feature = feature), by = "source_id") |>
  left_join(ns |> select(v1_feature = feature, ns_outcome = outcome, witness_of), by = "v1_feature") |>
  transmute(source, source_id, name, feature = id,
            outcome = case_when(!is.na(id) ~ "a lettering of a feature in the list", !is.na(ns_outcome) ~ ns_outcome,
                                TRUE ~ "no feature in version 1"),
            detail = coalesce(role, ifelse(!is.na(witness_of), paste0("witness of ", witness_of), NA)))
lmi_out <- tibble(source = "lmi", source_id = st$uuid, name = st$name) |>
  left_join(lr |> transmute(source_id = uuid, v1_outcome = outcome, detail = na_if(detail, ""),
                            f = coalesce(suppressWarnings(as.integer(lmi_feature)), suppressWarnings(as.integer(chart_feature)))), by = "source_id") |>
  transmute(source, source_id, name, feature = ifelse(f %in% out$id, f, NA_integer_),
            outcome = coalesce(v1_outcome, "inland, beyond the shore's 1 km band (the study's 115)"), detail)
rec_isor <- tibble(source = "isor", source_id = as.character(sr$rid), name = sr$name) |>
  left_join(ir |> transmute(source_id = as.character(rid), outcome), by = "source_id") |>
  left_join(src_isor |> group_by(source_id) |> summarise(feature = first(id), .groups = "drop"), by = "source_id") |>
  transmute(source, source_id, name, feature, outcome, detail = NA_character_)
rec <- bind_rows(rec_chart, lmi_out, rec_isor)
stopifnot(nrow(rec_chart) == 8203L, nrow(lmi_out) == 200674L, nrow(rec_isor) == 2825L, !anyNA(rec$outcome),
          !any(rec$outcome == "no feature in version 1"), !anyDuplicated(rec[c("source", "source_id")]))

# The extents and the long names' lines ------------------------------------------------------------------------------------
lx <- st_read(file.path(V1, "lmi_extent.geojson"), quiet = TRUE)
lx$feature <- as.integer(sub("^c", "", lx$id)); lx$what <- "extent"; lx$basis <- ifelse(grepl("^c", lx$id), "LMÍ's, joined to the chart's feature", "LMÍ's")
ix <- st_read(file.path(V1, "isor_extent.geojson"), quiet = TRUE); ix$feature <- as.integer(ix$id); ix$what <- "extent"; ix$basis <- "ÍSOR's"
lx$z_line <- NA_real_; ix$z_line <- NA_real_
nl <- st_read(file.path(V1, "name_lines.geojson"), quiet = TRUE); nl$feature <- as.integer(nl$feature); nl$what <- "line"
nl$basis <- "the long feature's line on the depth model (the study's 70, 72, 79)"
ex <- rbind(lx[c("feature", "what", "basis", "z_line")], ix[c("feature", "what", "basis", "z_line")], nl[c("feature", "what", "basis", "z_line")]) |>
  filter(feature %in% out$id) |> st_transform(4326)

# Write --------------------------------------------------------------------------------------------------------------------
OUT <- fd_curated("reference")
write_curated(out_sf, file.path(OUT, "marine_name.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(src, file.path(OUT, "marine_name_source.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(rec, file.path(OUT, "marine_name_record.parquet"), inputs = INPUTS, script = SCRIPT)
write_curated(ex, file.path(OUT, "marine_name_extent.parquet"), inputs = INPUTS, script = SCRIPT)
print(knitr::kable(count(out, src, kind), caption = "marine_name: features by source and kind"))
print(knitr::kable(count(rec, source, outcome), caption = "marine_name_record: every record in one outcome"))
