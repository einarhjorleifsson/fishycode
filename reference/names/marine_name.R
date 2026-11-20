# marine_name.R — the names of the sea charts, LMÍ and ÍSOR as one list: a row a named feature, where the thing is and where
# its name is drawn, its angle, the zoom it deserves and the basis of each (plan 074 step 12, version 1; plan 080 §5.2, version
# 2; marine_feature.R binds it with the wrecks and aids).
# Side: preprocessing (sea-chart names). Standalone, run by hand outside the targets flow (plan 074 ask p).
#
# Input:  $FISHYDATA/archive/2026-11-11-named-features/out/frozen/names_v1/ - the names map's version 1, frozen 2026-11-19 by
#         the study's 133 (the maintainer: "Freeze v1 as an input"): names.geojson (every name shown, its computed place,
#         angle and zoom), extent, hierarchy, lettering_feature, letterings (the charts' features), island, island_place
#         (the islands, 110), lmi_record, lmi_feature, chart_join (LMÍ's names, 128), isor_record, isor_feature, isor_join
#         (ÍSOR's, 131), lmi_extent, isor_extent, name_lines (the extents and the long names' lines), not_shown; its
#         manifest.csv's md5s are checked first
#         curated/reference/seabed_feature.parquet (reference/seabed/seabed_feature.R: ÍSOR's craters and volcanic areas)
#         staging/is50v/name.parquet (sources/is50v/name.R: IS 50V's 200,674 names), staging/isor/seabed_name.parquet
#         (sources/isor/seabed_name.R: ÍSOR's 2,825 records), curated/reference/chart_names.parquet (the charts' 8,203 labels)
#         staging/ornefni/document_name.parquet (sources/ornefni/document_name.R): the entries of ÍSOR's four reports of 2008
#         for Orkustofnun on the names of the sea floor (GRG-ISOR-08041, 08044, 08045, 08125; decisions 222, 285)
#         overrides/marine_name_edits.csv (the maintainer's moves, turns, zooms and renames on the names page, append-only,
#         latest counts),
#         marine_name_reading.csv (misreads corrected, ask v), marine_name_duplicate.csv (duplicates flagged, ask v),
#         marine_name_variant.csv (the charts' misprints named as meant, by the maintainer; v1 holds them already, the edits
#         made under a misprint are matched through it), marine_name_include.csv (records a rule left out, brought in by the
#         maintainer, version 2)
# Output: curated/reference/marine_name.parquet        - one row per named feature: where the thing is (`lon`, `lat`, WKB
#                                                        `geometry`, `place_basis`) and where its name is drawn (`label_lon`,
#                                                        `label_lat`, `label_basis`; `rotate_deg` and `z_rule` are the label's);
#                                                        for a name of Orkustofnun's 2014 delivery to LMÍ, its entry in ÍSOR's
#                                                        reports of 2008 (`report`, `report_entry`, `name_en`, `coined`)
#         curated/reference/marine_name_source.parquet - one row per link of a feature to a source record (a chart's
#                                                        lettering, an LMÍ record, an ÍSOR record) and its role
#         curated/reference/marine_name_record.parquet - every record of the three sources in one outcome: the charts'
#                                                        8,203 labels, IS 50V's 200,674 names, ÍSOR's 2,825 records
#         curated/reference/marine_name_extent.parquet - each feature's extent where a source gives one (LMÍ's area or line,
#                                                        ÍSOR's area) and the long names' lines, WKB `geometry`
#         curated/reference/marine_name_pair.parquet   - every pair of one name from two sources within 10 km, in one
#                                                        outcome (one thing, whole and part, doubtful, namesakes)
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
# Version 2 (plan 080 §5.2, decision 333) lays on, after those:
# - the maintainer's renames (ask e): the latest `rename` row of a feature in the edits; the name used is his, the source's
#   spelling kept (`name_source`) and among the synonyms, `name_basis` saying whose the name is; his `synonym` rows each
#   add a synonym (the new name another name of the feature);
# - where the thing is apart from where its name is drawn: `label_lon`, `label_lat` are version 1's place, the maintainer's
#   moves included (his moves are of labels); `lon`, `lat` the thing's: the computed place, but a chart's areal name with an
#   extent of LMÍ's or ÍSOR's at a point inside that extent; `point_kind` a rock, shoal, skerry or stack, or an LMÍ record
#   whose bearers are all a rock's, or ÍSOR's point: a dot at the thing, its name beside it;
# - the maintainer's pins: the latest `pin` row of a feature sets where the thing is (`place_basis` his hand), over every
#   rule above, a pinned name drawn with a dot; an `unpin` gives the rule's place back. A point kind's label follows its thing
#   unless he moved the label;
# - one thing from two sources (ask f): a pair of one name (case aside) from two sources within 10 km is one thing where
#   their places meet (a place inside the other's extent, or the two within their reaches, a reach half the extent, 250 m at
#   least) and their sizes are alike (2 times at most) and of one broad kind (sea, isle, land); whole and part where one is
#   5 times the other or more and the smaller lies within the larger's extent or reach; namesakes where they lie beyond 3
#   times their reaches; doubtful otherwise, listed for the maintainer, both kept. One thing is one row: the chart's (else
#   LMÍ's) kept, the name by ask g's order (his, LMÍ's, the charts', ÍSOR's), the thing at ÍSOR's area where ÍSOR's is one of
#   the two (ask h: a volcanic feature at ÍSOR's), the label the kept row's; the other's records and extent move to it. Where
#   ÍSOR's area is one of the two it is the row's primary source (the maintainer, 2026-11-19, of Grjóthryggur: "We should
#   have that area as the primary source in "our" version. And then the name would be along the polygon axis"): `src`
#   ÍSOR's, the extent ÍSOR's, the label inside the area along its long axis on the map (Web Mercator), unless he moved it;
# - records brought in (overrides/marine_name_include.csv; the maintainer, 2026-11-19, of LMÍ's Gullhóll: "Yes, bring it
#   in"): an LMÍ record a rule left out becomes a name, its id 2,100,000,000 plus LMÍ's own, its place the centre of the
#   largest circle in its area (version 1's for LMÍ's areas), its extent the longer side of its box, its zoom and size the
#   median of LMÍ's sea names of its extent within 25 %, its record's outcome "brought in by the maintainer";
# - the link from a name to ÍSOR's crater or mound (`seabed_id`, plan 080 §5.2a; the maintainer, 2026-11-19: "if we bring
#   this in now we can make the link here between the ISOR mound position and "our" name"): ÍSOR's own names to their own
#   area or point; a name of a mound's size (3 km at most) whose thing lies within its reach of a crater or guyot (its reach
#   and the crater's 250 m) to the nearest, the thing of the sea's kinds moved there (over LMÍ's position for a rock), an
#   island's not; one beyond its reach but within 3 km flagged doubtful, for review; a name inside a seamount and linked to
#   no crater to the seamount. His `link` rows (the feature in `link_to`) link by hand and move the thing there (to an area:
#   the area its extent, LMÍ's set aside; to a trough: the thing at its deepest point), his `part of` rows (the whole's id
#   in `link_to`) make the whole the part's holder; `unlink`
#   rows undo; his pins come after and win;
# - Trackwell's candidates the maintainer accepts (plan 080 ask n; reference/names/trackwell_candidate.R): his latest `accept`
#   row of a candidate's key makes it a name, `src` trackwell, its id 2,140,000,000 and the order of his first acceptance, its
#   thing at the candidate's place (ÍSOR's feature, else the tows' centre, flagged to pin), from zoom 9; a `reject` keeps it out;
#   a name of the skippers' he ignores (`ignore`, trackwell_candidate.R) is never a candidate, its record "ignored by the
#   maintainer";
# - the maintainer's own names (`new` rows: the name, the ÍSOR features it names in `link_to`, its place their middle), ids
#   from 2,130,000,000 by the order he gave them; his `remove` rows take a name out (its record "removed by the maintainer");
#   his `area aside` rows set a name's LMÍ area aside (2026-11-19, of Kiddahóll: "the area stuff is off");
# - ÍSOR's area over LMÍ's (the maintainer, 2026-11-19: "I think the LMÍ area should be removed here. But that is probably a
#   general rule when we have ISOR area and LMÍ area. And in general LMÍ areas are in my view highly suspect, although they
#   should not be excluded as a rule"): where a row has both, LMÍ's is set aside, kept in marine_name_extent with `used`
#   FALSE and why; an LMÍ area alone stays in use.
# The traffic jam is the page's: `z_rule` is the zoom a name deserves, the page draws it from there or later.
# LMÍ's source (heimild) is as LMÍ publishes it with its names. Run from the repo root: Rscript reference/names/marine_name.R
# Written by Claude (AI), 2026-11-19; version 2 the same day.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)   # standalone: not targets'

V1 <- fd_path("archive", "2026-11-11-named-features", "out", "frozen", "names_v1")
man <- read.csv(file.path(V1, "manifest.csv"))
stopifnot("a frozen file of names_v1 changed" = identical(unname(tools::md5sum(file.path(V1, man$file))), man$md5))
rd <- function(f) read.csv(file.path(V1, f), encoding = "UTF-8")
ov <- function(f) read.csv(file.path("overrides", f), encoding = "UTF-8")
SCRIPT <- "reference/names/marine_name.R"
INPUTS <- c(if (file.exists(fd_curated("reference", "place_name_proposal.parquet"))) c(fd_curated("reference", "place_name_proposal.parquet"), fd_curated("reference", "place_name_proposal_shape.parquet")),
            file.path(V1, man$file), fd_staging("is50v", "name.parquet"), fd_staging("isor", "seabed_name.parquet"), fd_staging("ornefni", "document_name.parquet"),
            fd_curated("reference", "chart_names.parquet"),
            file.path("overrides", c("marine_name_edits.csv", "marine_name_reading.csv", "marine_name_duplicate.csv",
                                     "marine_name_variant.csv", "marine_name_include.csv")), fd_curated("reference", "seabed_feature.parquet"),
            fd_curated("reference", "place_name_region.parquet"), fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif"),
            fd_curated("reference", "marine_name_candidate.parquet"))
VERSION <- 3L   # version 2 frozen 2026-11-20 (plan 081 step 1 closed, decision 338); the edits since make version 3
`%||%` <- function(a, b) if (is.null(a)) b else a
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

# The maintainer's renames and synonyms (version 2, plan 080 ask e): laid on once every name exists, after his own names ----
vr <- ov("marine_name_variant.csv"); ed <- ov("marine_name_edits.csv")
if (!"new_name" %in% names(ed)) ed$new_name <- NA_character_
nm$name_source <- nm$name                                  # the source's spelling, a misread corrected
nm$name_basis <- unname(c(chart = "the charts' print", lmi = "LMÍ's spelling", isor = "ÍSOR's")[nm$src])
nm$renamed_at <- NA_character_
syn <- function(x, add, drop) vapply(seq_along(x), function(i) {
  z <- c(strsplit(coalesce(x[i], ""), ";\\s*")[[1]], strsplit(coalesce(add[i], ""), ";\\s*")[[1]])
  z <- unique(z[nzchar(z) & !same(z, drop[i])]); if (length(z)) paste(z, collapse = "; ") else NA_character_ }, "")
lay_names <- function(nm) {
  rn <- ed |> filter(action == "rename") |> arrange(at) |> group_by(feature) |> slice_tail(n = 1) |> ungroup()
  k <- match(rn$feature, nm$id)
  if (anyNA(k) || any(!nzchar(coalesce(rn$new_name, ""))))
    stop("renames that find no feature, or name none: ", paste(rn$name[is.na(k) | !nzchar(coalesce(rn$new_name, ""))], collapse = ", "))
  was <- ed |> filter(action == "rename") |> group_by(feature) |> summarise(names = list(c(name, new_name)), .groups = "drop")
  ok_from <- vapply(seq_along(k), function(r) any(same(was$names[[match(rn$feature[r], was$feature)]], nm$name_source[k[r]])), logical(1))
  if (!all(ok_from)) stop("renames whose name is not the feature's: ", paste(rn$name[!ok_from], collapse = ", "))
  nm$name[k] <- rn$new_name; nm$renamed_at[k] <- rn$at
  nm$name_basis[k] <- paste0("the maintainer's hand, ", rn$at)
  nm$synonyms[k] <- syn(nm$synonyms[k], nm$name_source[k], rn$new_name)
  sy <- ed |> filter(action == "synonym") |> arrange(at)
  k <- match(sy$feature, nm$id)
  okn <- !is.na(k) & vapply(seq_along(k), function(r) !is.na(k[r]) && any(same(c(nm$name[k[r]], nm$name_source[k[r]]), sy$name[r])), logical(1))
  if (!all(okn) || any(!nzchar(coalesce(sy$new_name, "")))) stop("synonyms that find no feature or name none: ", paste(sy$name[!okn], collapse = ", "))
  for (r in seq_along(k)) nm$synonyms[k[r]] <- syn(nm$synonyms[k[r]], sy$new_name[r], nm$name[k[r]])
  message(sprintf("renames: %d features named by the maintainer; synonyms: %d added by him", length(unique(rn$feature)), nrow(sy)))
  nm
}

# The maintainer's edits ---------------------------------------------------------------------------------------------------
box_km <- ext$box_km[match(nm$id, ext$feature)]
# every edit matched to its feature first, then each feature's latest: an edit saved under the study's number of a feature
# and a later one under today's are one stream (found 2026-11-19: a place back under 1806 did not supersede a move under 1792)
latest <- ed |> filter(action %in% c("move", "turn", "move and turn", "revert")) |>
  mutate(name = ifelse(tolower(name) %in% tolower(vr$printed), vr$name[match(tolower(name), tolower(vr$printed))], name)) |>
  arrange(at)
rn_to <- with(ed[ed$action == "rename", ], split(new_name, feature))   # a move saved under the name he gave it
names_as <- function(i) c(nm$name[i], nm$name_printed[i], sub(" -> .*", "", nm$reading_corrected[i]), nm$name_source[i],
                          rn_to[[as.character(nm$id[i])]])
edit_row <- function(r) { i <- match(latest$feature[r], nm$id)
  if (!is.na(i) && any(same(names_as(i), latest$name[r]))) return(i)
  j <- which(same(nm$name, latest$name[r]) | same(nm$name_printed, latest$name[r])); if (!length(j) || is.na(latest$comp_lon[r])) return(NA_integer_)
  dk <- sqrt(((nm$lon0[j] - latest$comp_lon[r]) * 111.32 * cos(latest$comp_lat[r] * pi / 180))^2 + ((nm$lat0[j] - latest$comp_lat[r]) * 110.57)^2)
  if (min(dk) <= max(30, coalesce(box_km[j][which.min(dk)], 0))) j[which.min(dk)] else NA_integer_ }
latest$row <- vapply(seq_len(nrow(latest)), edit_row, 0L)
# an edit of a row the build makes later (a copy brought in, a Trackwell name accepted, his own name: ids from 2,100,000,000)
# waits until that row exists (found 2026-11-19: his move of Sæmundarrenna's label stopped the build)
LATE_FROM <- 2100000000
later <- function(e) is.na(e$row) & !is.na(e$feature) & e$feature >= LATE_FROM
late_mv <- latest[later(latest), ]; latest <- latest[!later(latest), ]
if (anyNA(latest$row)) stop("edits that found no feature: ", paste(latest$name[is.na(latest$row)], collapse = ", "))
latest <- latest |> group_by(row) |> slice_tail(n = 1) |> ungroup()
mv <- latest[latest$action != "revert", ]
nm$lon <- nm$lon0; nm$lat <- nm$lat0; nm$rotate_deg <- nm$rotate0; nm$edited_at <- NA_character_
nm$lon[mv$row] <- mv$lon; nm$lat[mv$row] <- mv$lat; nm$rotate_deg[mv$row] <- mv$rot; nm$edited_at[mv$row] <- mv$at
nm$place_basis[mv$row] <- "hand"; nm$rotate_basis[mv$row] <- "hand"
# a name moved by hand in version 1 and placed back since: version 1 kept no computed basis for it
back <- is.na(nm$edited_at) & is.na(nm$place_basis)
nm$place_basis[back] <- "computed (version 1 kept no basis for a name moved by hand)"
nm$rotate_basis[is.na(nm$edited_at) & is.na(nm$rotate_basis)] <- "computed (version 1 kept no basis for a name turned by hand)"
stopifnot(!anyNA(nm$place_basis[is.na(nm$edited_at)]))
message(sprintf("edits: %d rows, %d features' latest, %d moved or turned by hand, %d reverted", nrow(ed), nrow(latest), nrow(mv),
                sum(latest$action == "revert")))
# the zoom, a stream of its own (the page's Earlier, Later and the rule's): a feature's latest zoom edit fixes the zoom it
# deserves, a zoom back gives the rule's again
zl <- ed |> filter(action %in% c("zoom", "zoom back")) |>
  mutate(name = ifelse(tolower(name) %in% tolower(vr$printed), vr$name[match(tolower(name), tolower(vr$printed))], name)) |>
  arrange(at)
nm$z_rule_computed <- nm$z_rule; nm$zoom_edited_at <- NA_character_
late_zl <- zl[0, ]
if (nrow(zl)) {
  latest <- zl; zl$row <- vapply(seq_len(nrow(zl)), edit_row, 0L)
  late_zl <- zl[later(zl), ]; zl <- zl[!later(zl), ]
  if (anyNA(zl$row)) stop("zoom edits that found no feature: ", paste(zl$name[is.na(zl$row)], collapse = ", "))
  zl <- zl |> group_by(row) |> slice_tail(n = 1) |> ungroup()
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

# Where the thing is, and where its name is drawn (version 2, plan 080 §5.2) -----------------------------------------------
# The label is version 1's place, the maintainer's moves included: he moved names, not things (104 of his 105 moves are of
# the charts' sea names, one of an island's). The thing is the computed place; a chart's areal name with an extent of
# LMÍ's at a point inside that extent.
lxs <- st_read(file.path(V1, "lmi_extent.geojson"), quiet = TRUE); ixs <- st_read(file.path(V1, "isor_extent.geojson"), quiet = TRUE)
lxs$feature <- as.integer(sub("^c", "", lxs$id)); ixs$feature <- as.integer(ixs$id)
xt <- rbind(lxs["feature"], ixs["feature"]) |> st_transform(3057) |> st_make_valid() |> group_by(feature) |> summarise(.groups = "drop")
bear <- strsplit(coalesce(lf$bearers[match(nm$id, lf$feature)], ""), ",\\s*")
nm$point_kind <- (ch & nm$class %in% c("rock or shoal", "skerry or stack")) |
  (li & vapply(bear, function(b) length(b) > 0 && all(nzchar(b)) && all(b %in% ROCK), logical(1))) | (io & nm$class %in% "point")
nm$label_lon <- nm$lon; nm$label_lat <- nm$lat; nm$label_basis <- nm$place_basis
nm$lon <- nm$lon0; nm$lat <- nm$lat0
nm$place_basis <- ifelse(!is.na(nm$edited_at) & is.na(nm$place_basis_computed) & !nm$place_basis %in% "lmi_position",
                         "computed (version 1 kept no basis for a name moved by hand)", nm$place_basis)
nm$place_basis[!is.na(nm$edited_at) & !is.na(nm$place_basis_computed)] <- nm$place_basis_computed[!is.na(nm$edited_at) & !is.na(nm$place_basis_computed)]
inner_point <- function(ids) { g <- st_point_on_surface(xt[match(ids, xt$feature), ]) |> st_transform(4326); st_coordinates(g)[, 1:2, drop = FALSE] }
has_x <- ch & !nm$point_kind & nm$id %in% lxs$feature[grepl("^c", lxs$id)]
if (any(has_x)) { q <- suppressWarnings(inner_point(nm$id[has_x]))
  nm$lon[has_x] <- q[, 1]; nm$lat[has_x] <- q[, 2]; nm$place_basis[has_x] <- "a point inside its extent (LMÍ's)" }
message(sprintf("thing and label: %d point kinds (a dot at the thing); %d chart names placed inside LMÍ's extent; %d labels moved by hand",
                sum(nm$point_kind), sum(has_x), sum(!is.na(nm$edited_at))))

# Records brought in: by the maintainer (overrides/marine_name_include.csv), and LMÍ's copies inside an open region (plan 080
# ask m, decision 336: the name taken, never the place) ------------------------------------------------------------------------
INCLUDED_FROM <- 2100000000L
inc <- if (file.exists(file.path("overrides", "marine_name_include.csv"))) ov("marine_name_include.csv") else data.frame(source = character(), source_id = character(), name = character(), why = character())
if (!all(inc$source == "lmi")) stop("only LMÍ's records are brought in so far")
inc$how <- rep("maintainer", nrow(inc))
regs <- read_curated_sf(fd_curated("reference", "place_name_region.parquet")); regs <- regs[regs$open, ]
lr0 <- rd("lmi_record.csv")
copies <- st[st$uuid %in% lr0$uuid[lr0$outcome == "a copy left out"], ]
in_region <- rep(NA_character_, nrow(copies))
if (nrow(regs) && nrow(copies)) { h <- st_intersects(suppressWarnings(st_point_on_surface(copies)), regs)
  in_region <- vapply(h, function(z) if (length(z)) regs$region[z[1]] else NA_character_, "") }
rc <- copies[!is.na(in_region), ]; rc_region <- in_region[!is.na(in_region)]
inc$region <- rc_region[match(inc$source_id, rc$uuid)]
add <- !rc$uuid %in% inc$source_id
inc <- bind_rows(inc, data.frame(source = rep("lmi", sum(add)), source_id = rc$uuid[add], name = rc$name[add],
  why = sprintf("LMÍ's copy (%s) inside the open region %s: the name taken, never the place (plan 080 ask m)", rc$source_ref[add], rc_region[add]),
  how = rep("region", sum(add)), region = rc_region[add]))
nm$brought_in <- FALSE
bx <- NULL; unplaced <- character()
if (nrow(inc)) {
  s <- st[match(inc$source_id, st$uuid), ]
  if (anyNA(s$uuid) || !all(same(s$name, inc$name))) stop("records to bring in that are not LMÍ's of that name: ", paste(inc$name, collapse = ", "))
  a <- st_transform(s, 3057)
  area <- lapply(seq_len(nrow(a)), function(i) { g <- st_geometry(a)[i]; if (s$layer[i] == "polygon") g else st_buffer(g, 1000) })
  sfeat <- read_curated_sf(fd_curated("reference", "seabed_feature.parquet"))
  pts <- st_transform(sfeat[sfeat$kind %in% c("crater", "guyot", "point"), ], 3057)
  smt <- sfeat[sfeat$kind == "seamount", ]; smt_top <- st_transform(st_as_sf(st_drop_geometry(smt), coords = c("lon", "lat"), crs = 4326), 3057)
  dem <- terra::rast(fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif"))
  # where a copy's thing goes: the shallowest of ÍSOR's craters and guyots in its area, else the shallowest seamount top in
  # it, else the depth model's shallowest cell in it; outside an open region (brought in by hand) its area's middle
  place <- lapply(seq_len(nrow(a)), function(i) {
    if (is.na(inc$region[i])) { g <- st_geometry(a)[i]
      p <- if (s$layer[i] == "polygon") st_centroid(st_inscribed_circle(g, dTolerance = 25, nQuadSegs = 8)[1])
           else if (s$layer[i] == "line") st_line_sample(st_cast(g, "LINESTRING")[1], sample = 0.5) else g
      return(list(xy = st_coordinates(st_transform(p, 4326))[1, 1:2], basis = "area_middle", seabed = NA_character_)) }
    A <- area[[i]]
    k <- which(lengths(st_intersects(pts, A)) > 0)
    if (length(k)) { j <- k[order(pts$top_depth_m[k], na.last = TRUE)[1]]   # a depth off the grid last
      return(list(xy = c(pts$lon[j], pts$lat[j]), seabed = pts$seabed_id[j],
                  basis = sprintf("ÍSOR's %s %s, the shallowest in LMÍ's area (rule m, version 2)", pts$kind[j], pts$label[j]))) }
    k <- which(lengths(st_intersects(smt_top, A)) > 0)
    if (length(k)) { j <- k[order(smt_top$top_depth_m[k], na.last = TRUE)[1]]
      return(list(xy = c(smt$lon[j], smt$lat[j]), seabed = smt$seabed_id[j],
                  basis = sprintf("ÍSOR's seamount %s, its top the shallowest in LMÍ's area (rule m, version 2)", smt$label[j]))) }
    e <- terra::extract(dem, terra::vect(st_transform(st_sf(geometry = A), terra::crs(dem))), cells = TRUE, xy = TRUE)
    e <- e[!is.na(e[[2]]), ]
    if (nrow(e)) { j <- which.max(e[[2]]); q <- st_coordinates(st_transform(st_sfc(st_point(c(e$x[j], e$y[j])), crs = terra::crs(dem)), 4326))[1, 1:2]
      return(list(xy = q, seabed = NA_character_, basis = sprintf("the depth model's shallowest point in LMÍ's area, %.0f m (rule m, version 2)", -e[[2]][j]))) }
    NULL })
  ok_place <- !vapply(place, is.null, logical(1))
  unplaced <- inc$source_id[!ok_place]
  inc_p <- inc[ok_place, ]; s <- s[ok_place, ]; a <- a[ok_place, ]; place <- place[ok_place]
  ctr <- do.call(rbind, lapply(place, `[[`, "xy"))
  ext_km <- vapply(seq_len(nrow(a)), function(i) { b <- st_bbox(a[i, ]); max(b[["xmax"]] - b[["xmin"]], b[["ymax"]] - b[["ymin"]]) / 1000 }, 0)
  like <- function(e, v) { w <- which(li & nm$class %in% "water" & !is.na(nm$extent_km)); d <- abs(log(nm$extent_km[w] / e))
    k <- w[d < log(1.25)]; if (length(k) < 5) k <- w[order(d)[1:10]]   # else its ten nearest in extent
    median(v[k]) }
  rows <- nm[rep(which(li)[1], nrow(inc_p)), ]
  rows[] <- lapply(rows, function(col) { col[] <- NA; col })
  basis <- vapply(place, `[[`, "", "basis"); seab <- vapply(place, function(z) z$seabed %||% NA_character_, "")
  rows <- rows |> mutate(
    id = INCLUDED_FROM + as.integer(s$id), src = "lmi", name = s$name, name_source = s$name, name_basis = "LMÍ's spelling",
    kind = "water", class = "water", point_kind = FALSE, brought_in = TRUE,
    lon0 = ctr[, 1], lat0 = ctr[, 2], lon = ctr[, 1], lat = ctr[, 2], label_lon = ctr[, 1], label_lat = ctr[, 2],
    place_basis = basis, place_basis_computed = basis, label_basis = basis,
    rotate0 = 0, rotate_deg = 0, rotate_basis = "level", extent_km = round(ext_km, 3), extent_basis = "its area, LMÍ's",
    z_rule = round(vapply(ext_km, function(e) like(e, nm$z_rule), 0), 2), z_rule_v1 = NA_real_,
    z_rule_basis = "the median zoom of LMÍ's sea names of its extent within 25 %, else its ten nearest in extent (brought in, version 2)",
    size = vapply(ext_km, function(e) like(e, nm$size), 0), priority = -round(ext_km, 3), label_dy = 0, n_letterings = 0L,
    legend_entry = FALSE, lmi_source = s$source_ref,
    lmi_source_kind = ifelse(inc_p$how == "maintainer", "brought in by the maintainer (a copy left out by version 1)",
                             "brought in by the region's rule (a copy left out by version 1, plan 080 ask m)"),
    seabed_id = seab, seabed_link = ifelse(is.na(seab), NA_character_, "the shallowest in the copy's area (rule m)"),
    flags = paste0(ifelse(inc_p$how == "maintainer", "brought in by the maintainer: ", "brought in by the region's rule, for review: "),
                   inc_p$why, " (version 2)"))
  rows$z_rule_computed <- rows$z_rule
  stopifnot(!any(rows$id %in% nm$id), !anyNA(rows$z_rule), !anyNA(rows$size))
  nm <- bind_rows(nm, rows)
  bx <- st_transform(s, 4326) |> transmute(feature = INCLUDED_FROM + as.integer(id), what = "extent", basis = "LMÍ's", z_line = NA_real_)
  st_geometry(bx) <- "geometry"
  inc <- inc_p
}
message(sprintf("brought in: %d records a rule left out (%d by the maintainer, %d by an open region's rule); %d copies in an open region with no place",
                nrow(inc), sum(inc$how == "maintainer"), sum(inc$how == "region"), length(unplaced)))

# Trackwell's candidates the maintainer accepts (version 2, plan 080 ask n) ---------------------------------------------------
ACCEPTED_FROM <- 2140000000L   # under R's integer limit (2,147,483,647)
CAND <- fd_curated("reference", "marine_name_candidate.parquet")
twc <- if (file.exists(CAND)) as.data.frame(nanoparquet::read_parquet(CAND)) else NULL
if (!"link_to" %in% names(ed)) ed$link_to <- NA_character_
vd <- ed |> filter(action %in% c("accept", "reject")) |> arrange(at)
first_acc <- vd |> filter(action == "accept") |> group_by(link_to) |> slice_head(n = 1) |> ungroup()
latest_vd <- vd |> group_by(link_to) |> slice_tail(n = 1) |> ungroup()
acc <- latest_vd |> filter(action == "accept")
if (nrow(acc)) {
  if (is.null(twc) || !all(acc$link_to %in% twc$key)) stop("accepted candidates not in marine_name_candidate: ", paste(setdiff(acc$link_to, twc$key), collapse = ", "))
  acc <- acc |> mutate(order = match(link_to, first_acc$link_to)) |> arrange(order)
  cc <- twc[match(acc$link_to, twc$key), ]
  rows <- nm[rep(which(li)[1], nrow(cc)), ]
  rows[] <- lapply(rows, function(col) { col[] <- NA; col })
  rows <- rows |> mutate(
    id = ACCEPTED_FROM + acc$order, src = "trackwell", name = cc$name, name_source = cc$name, name_basis = "Trackwell's commonest spelling",
    synonyms = ifelse(grepl(";", cc$spellings), cc$spellings, NA_character_), kind = "water", class = "water",
    point_kind = !is.na(cc$seabed_id), brought_in = FALSE,
    lon0 = cc$lon, lat0 = cc$lat, lon = cc$lon, lat = cc$lat, label_lon = cc$lon, label_lat = cc$lat,
    place_basis = cc$place_basis, place_basis_computed = cc$place_basis, label_basis = cc$place_basis,
    rotate0 = 0, rotate_deg = 0, rotate_basis = "level", extent_km = NA_real_, extent_basis = NA_character_,
    z_rule = 9, z_rule_v1 = NA_real_, z_rule_basis = "a Trackwell name accepted: from zoom 9 (Claude's choice, his to correct)",
    size = 12, priority = 0, label_dy = 0, n_letterings = 0L, legend_entry = FALSE,
    seabed_id = cc$seabed_id, seabed_link = ifelse(is.na(cc$seabed_id), NA_character_, "Trackwell's candidate on it, accepted"),
    flags = sprintf("accepted by the maintainer %s: Trackwell's name, %d tows by %d vessels here%s (version 2)", acc$at, cc$tows, cc$vessels,
                    ifelse(is.na(cc$seabed_id), ", no feature near: pin it", "")))
  rows$z_rule_computed <- rows$z_rule
  stopifnot(!any(rows$id %in% nm$id))
  nm <- bind_rows(nm, rows)
}
nm$accepted_key <- NA_character_; if (nrow(acc)) nm$accepted_key[match(ACCEPTED_FROM + acc$order, nm$id)] <- acc$link_to
message(sprintf("Trackwell's candidates: %d accepted, %d rejected", nrow(acc), sum(latest_vd$action == "reject")))

# The maintainer's own names, and his removals (version 2) --------------------------------------------------------------------
OWN_FROM <- 2130000000L
nw <- ed |> filter(action == "new") |> arrange(at)
sfo <- st_drop_geometry(read_curated_sf(fd_curated("reference", "seabed_feature.parquet")))
like2 <- function(e, v) { w <- which(li & nm$class %in% "water" & !is.na(nm$extent_km)); d <- abs(log(nm$extent_km[w] / e))
  k <- w[d < log(1.25)]; if (length(k) < 5) k <- w[order(d)[1:10]]; median(v[k]) }
own_hull <- NULL
if (nrow(nw)) {
  mem <- strsplit(nw$link_to, ";")
  if (!all(unlist(mem) %in% sfo$seabed_id)) stop("his own names that name no ÍSOR feature: ", paste(nw$name, collapse = ", "))
  # its extent: one line (a moraine: the maintainer, 2026-11-20, "moraine 155 is what captains call "Brjálaði Hryggurinn"")
  # the line itself, its length the size; else the hull of the features' own shapes, widened by 500 m
  sfg <- read_curated_sf(fd_curated("reference", "seabed_feature.parquet"))
  one_line <- vapply(mem, function(m) length(m) == 1 && as.character(st_geometry_type(sfg[match(m, sfg$seabed_id), ])) %in% c("LINESTRING", "MULTILINESTRING"), logical(1))
  hulls <- lapply(seq_along(mem), function(i) { g <- st_union(st_transform(sfg[match(mem[[i]], sfg$seabed_id), ], 3057))
    if (one_line[i]) g else st_buffer(st_convex_hull(g), 500) })
  ext <- vapply(seq_along(hulls), function(i) if (one_line[i]) as.numeric(st_length(hulls[[i]])) / 1000 else {
    b <- st_bbox(hulls[[i]]); max(b[["xmax"]] - b[["xmin"]], b[["ymax"]] - b[["ymin"]]) / 1000 }, 0)
  rows <- nm[rep(which(li)[1], nrow(nw)), ]
  rows[] <- lapply(rows, function(col) { col[] <- NA; col })
  rows <- rows |> mutate(
    id = OWN_FROM + seq_len(nrow(nw)), src = "maintainer", name = nw$name, name_source = nw$name, name_basis = "the maintainer's own name",
    kind = "water", class = "water", point_kind = FALSE, brought_in = FALSE,
    lon0 = nw$lon, lat0 = nw$lat, lon = nw$lon, lat = nw$lat, label_lon = nw$lon, label_lat = nw$lat,
    place_basis = "the middle of the ÍSOR features it names (the maintainer's name)", place_basis_computed = place_basis, label_basis = place_basis,
    rotate0 = 0, rotate_deg = 0, rotate_basis = "level", extent_km = round(ext, 3),
    extent_basis = ifelse(one_line, "the ÍSOR line it names: its length", "the hull of the ÍSOR features it names"),
    z_rule = round(vapply(ext, function(e) like2(e, nm$z_rule), 0), 2), z_rule_v1 = NA_real_,
    z_rule_basis = "the median zoom of LMÍ's sea names of its extent within 25 %, else its ten nearest in extent (his own name)",
    size = vapply(ext, function(e) like2(e, nm$size), 0), priority = -round(ext, 3), label_dy = 0, n_letterings = 0L, legend_entry = FALSE,
    flags = sprintf("a name of the maintainer's own, %s: %s (version 2)", nw$at, nw$why))
  rows$z_rule_computed <- rows$z_rule; rows$seabed_members <- nw$link_to; rows$own_key <- paste0("new:", nw$at, ":", nw$name)
  stopifnot(!any(rows$id %in% nm$id))
  nm <- bind_rows(nm, rows)
  own_hull <- st_sf(feature = rows$id, what = "extent",
                    basis = ifelse(one_line, "the maintainer's: the ÍSOR line it names", "the maintainer's: the hull of the ÍSOR features it names"),
                    z_line = NA_real_, geometry = st_transform(do.call(c, hulls), 4326))
}
nm <- lay_names(nm)

# The maintainer's moves, turns and zooms of the rows made since: the label moved, the thing where the rule or his pin puts it
if (nrow(late_mv)) {
  latest <- late_mv; late_mv$row <- vapply(seq_len(nrow(late_mv)), edit_row, 0L)
  if (anyNA(late_mv$row)) stop("edits that found no feature: ", paste(late_mv$name[is.na(late_mv$row)], collapse = ", "))
  late_mv <- late_mv |> group_by(row) |> slice_tail(n = 1) |> ungroup() |> filter(action != "revert")   # a revert: the row as made
  nm$label_lon[late_mv$row] <- late_mv$lon; nm$label_lat[late_mv$row] <- late_mv$lat; nm$rotate_deg[late_mv$row] <- late_mv$rot
  nm$edited_at[late_mv$row] <- late_mv$at; nm$label_basis[late_mv$row] <- "hand"; nm$rotate_basis[late_mv$row] <- "hand"
}
if (nrow(late_zl)) {
  latest <- late_zl; late_zl$row <- vapply(seq_len(nrow(late_zl)), edit_row, 0L)
  if (anyNA(late_zl$row)) stop("zoom edits that found no feature: ", paste(late_zl$name[is.na(late_zl$row)], collapse = ", "))
  late_zl <- late_zl |> group_by(row) |> slice_tail(n = 1) |> ungroup() |> filter(action == "zoom")
  nm$z_rule[late_zl$row] <- late_zl$z0; nm$zoom_edited_at[late_zl$row] <- late_zl$at
  nm$z_rule_basis[late_zl$row] <- paste0("the maintainer's hand, ", late_zl$at)
}
message(sprintf("edits of rows made since version 1: %d labels moved or turned, %d zooms", nrow(late_mv), nrow(late_zl)))
# his wholes and parts: a `part of` row (the whole's id in `link_to`) makes the whole the part's holder, `not part of` undoes
po <- ed |> filter(action %in% c("part of", "not part of")) |> arrange(at) |> group_by(feature) |> slice_tail(n = 1) |> ungroup() |>
  filter(action == "part of")
if (nrow(po)) {
  k <- match(po$feature, nm$id); w <- match(suppressWarnings(as.integer(po$link_to)), nm$id)
  okn <- !is.na(k) & !is.na(w) & vapply(seq_along(k), function(r) !is.na(k[r]) && any(same(names_as(k[r]), po$name[r])), logical(1))
  if (!all(okn)) stop("parts that find no name or no whole: ", paste(po$name[!okn], collapse = ", "))
  nm$holder[k] <- nm$id[w]; nm$holder_name[k] <- nm$name[w]; nm$holder_note[k] <- paste0("a part of it, by the maintainer, ", po$at)
}
message(sprintf("wholes and parts by the maintainer: %d", nrow(po)))
rmv <- ed |> filter(action %in% c("remove", "restore")) |> arrange(at) |> group_by(feature) |> slice_tail(n = 1) |> ungroup() |> filter(action == "remove")
if (!all(rmv$feature %in% nm$id)) stop("removals that find no name: ", paste(rmv$name[!rmv$feature %in% nm$id], collapse = ", "))
removed_ids <- rmv$feature
nm <- nm[!nm$id %in% removed_ids, ]
message(sprintf("his own names: %d; removed by him: %d", nrow(nw), length(removed_ids)))

# One thing from two sources (version 2, plan 080 ask f) ---------------------------------------------------------------------
broad <- function(cl) case_when(cl %in% c("island", "skerry or stack", "light") ~ "isle", cl %in% c("land", "landform") ~ "land",
                                TRUE ~ "sea")
nm$sz_km <- coalesce(nm$extent_km, 0.5); nm$reach_km <- pmax(nm$sz_km / 2, 0.25)
cand <- nm |> filter(!id %in% piece$feature) |> mutate(key = tolower(name), kb = broad(class)) |>
  select(id, src, key, name, lon, lat, sz_km, reach_km, kb)
pr <- inner_join(cand, cand, by = "key", suffix = c("_a", "_b"), relationship = "many-to-many") |> filter(src_a < src_b)
pr$km <- sqrt(((pr$lon_a - pr$lon_b) * 111.32 * cos(pr$lat_a * pi / 180))^2 + ((pr$lat_a - pr$lat_b) * 110.57)^2)
pr <- pr[pr$km <= 10, ]
pt3057 <- function(lon, lat) st_transform(st_sfc(lapply(seq_along(lon), function(i) st_point(c(lon[i], lat[i]))), crs = 4326), 3057)
to_extent <- function(ids, lon, lat) { o <- rep(NA_real_, length(ids)); g <- pt3057(lon, lat)
  for (i in seq_along(ids)) { j <- match(ids[i], xt$feature); if (!is.na(j)) o[i] <- as.numeric(st_distance(g[i], xt[j, ]))[1] / 1000 }; o }
pr$a_in_b_km <- to_extent(pr$id_b, pr$lon_a, pr$lat_a); pr$b_in_a_km <- to_extent(pr$id_a, pr$lon_b, pr$lat_b)
pr$d_km <- pmin(pr$km, pr$a_in_b_km, pr$b_in_a_km, na.rm = TRUE)
pr$ratio <- pmax(pr$sz_km_a, pr$sz_km_b) / pmin(pr$sz_km_a, pr$sz_km_b)
small_a <- pr$sz_km_a <= pr$sz_km_b
small_within <- ifelse(small_a, coalesce(pr$a_in_b_km == 0, FALSE) | pr$km <= pr$reach_km_b,
                                coalesce(pr$b_in_a_km == 0, FALSE) | pr$km <= pr$reach_km_a)
reach2 <- pr$reach_km_a + pr$reach_km_b
pr$outcome <- case_when(pr$d_km <= reach2 & pr$ratio <= 2 & pr$kb_a == pr$kb_b ~ "one thing",
                        pr$ratio >= 5 & small_within ~ "whole and part",
                        pr$d_km > 3 * reach2 ~ "namesakes",
                        TRUE ~ "doubtful")
# a row one thing with two others of one source: none joined, both doubtful
SRC_RANK <- c(chart = 1, lmi = 2, isor = 3)
pr$keep <- ifelse(SRC_RANK[pr$src_a] <= SRC_RANK[pr$src_b], pr$id_a, pr$id_b)
pr$drop <- ifelse(pr$keep == pr$id_a, pr$id_b, pr$id_a)
one <- pr$outcome == "one thing"
twice <- pr$drop[one][duplicated(pr$drop[one])]
pr$outcome[one & pr$drop %in% twice] <- "doubtful"; pr$why <- ifelse(one & pr$drop %in% twice, "one thing with two rows of another source", NA_character_)
one <- pr$outcome == "one thing"
# a chain (ÍSOR's one with LMÍ's, LMÍ's with the chart's) ends at the row kept last
into <- setNames(pr$keep[one], pr$drop[one])
root <- function(x) { while (as.character(x) %in% names(into)) x <- into[[as.character(x)]]; x }
pr$into <- ifelse(one, vapply(pr$drop, root, 0L), NA_integer_)
joined <- tibble(gone = pr$drop[one], survivor = pr$into[one], pair = which(one))
stopifnot(!anyDuplicated(joined$gone), !any(joined$survivor %in% joined$gone))
# his joins (a `join` row: the row that goes in `feature`, the row kept in `link_to`; `unjoin` undoes): one thing by his word,
# the kept row's name used, the other's its synonym, its records with the kept row (the maintainer, 2026-11-20, of Faxadjúp
# and Jökuldjúp: "One deep, a synonym")
hj <- ed |> filter(action %in% c("join", "unjoin")) |> arrange(at) |> group_by(feature) |> slice_tail(n = 1) |> ungroup() |> filter(action == "join")
hj$feature <- as.integer(hj$feature); hj$link_to <- suppressWarnings(as.integer(hj$link_to))
if (!all(hj$feature %in% nm$id) || !all(hj$link_to %in% nm$id)) stop("joins that find no name: ", paste(hj$name[!(hj$feature %in% nm$id & hj$link_to %in% nm$id)], collapse = ", "))
joined <- bind_rows(joined |> filter(!gone %in% hj$feature), tibble(gone = hj$feature, survivor = hj$link_to, pair = rep(NA_integer_, nrow(hj))))
stopifnot(!anyDuplicated(joined$gone), !any(joined$survivor %in% joined$gone))
his_join <- hj$link_to; his_join_gone <- hj$feature
NAME_RANK <- c(lmi = 1, chart = 2, isor = 3)
# An area's long axis as the map shows it (Web Mercator): the principal direction of points spread evenly inside it; the
# label at its centre (or a point inside when the centre falls outside), turned clockwise as MapLibre turns text, -90 to 90
# (by axis_of() below since version 3: st_sample(type = "regular") offsets its grid at random, so the angle moved by a
# few tenths of a degree from build to build, decision 338)
along_axis <- function(f) axis_of(xt[xt$feature == f, ])[c("lon", "lat", "rotate")]
# the same for any area, its points the centres of a regular grid of about 600 cells inside it (no random offset: the same
# letters every build)
axis_of <- function(g) {
  a <- st_union(st_transform(st_make_valid(st_geometry(g)), 3857))
  s <- st_make_grid(a, cellsize = sqrt(as.numeric(st_area(a)) / 600), what = "centers"); s <- st_coordinates(s[lengths(st_intersects(s, a)) > 0])
  e <- eigen(cov(s[, 1:2]))$vectors[, 1]; deg <- ((atan2(e[2], e[1]) * 180 / pi + 90) %% 180) - 90
  ctr <- suppressWarnings(st_centroid(a)); if (!st_intersects(ctr, a, sparse = FALSE)[1, 1]) ctr <- suppressWarnings(st_point_on_surface(a))
  ll <- st_coordinates(st_transform(ctr, 4326))[1, ]
  c(lon = unname(ll[1]), lat = unname(ll[2]), rotate = round(-deg, 1), len_m = diff(range(s[, 1:2] %*% e)))   # its length along the axis, Mercator metres
}
# rule e (the named-features study's 71_place_map.R, his "e it is, keep it as the zoom rule"): a name shows from the zoom where
# its label, about 7.5 px a letter at 13 px, is half its feature's length (OVERSHOOT 2), whole zooms 4-16; the size 16 px for a
# feature of 20 km or more, 14 for 5 km or more, else 13. The length in Mercator metres (the map's own)
rule_e <- function(len_m, lat, n) { true_km <- len_m * cos(lat * pi / 180) / 1000; size <- ifelse(true_km >= 20, 16, ifelse(true_km >= 5, 14, 13))
  c(z = round(min(max(log2(156543.03 * max(4, n) * 7.5 * size / 13 / max(len_m, 50)) - log2(2), 4), 16), 2), size = size) }
nm$joined_from <- NA_character_
for (s_id in unique(joined$survivor)) {
  i <- match(s_id, nm$id); g <- match(joined$gone[joined$survivor == s_id], nm$id); all_i <- c(i, g)
  hand <- all_i[!is.na(nm$renamed_at[all_i])]
  w <- if (length(hand)) hand[1] else if (s_id %in% his_join) i else all_i[order(NAME_RANK[nm$src[all_i]])][1]
  nm$name[i] <- nm$name[w]; nm$name_basis[i] <- nm$name_basis[w]
  nm$synonyms[i] <- syn(nm$synonyms[i], paste(c(nm$name_source[all_i], na.omit(nm$synonyms[g])), collapse = "; "), nm$name[i])
  gi <- g[nm$src[g] == "isor"]; gl <- g[nm$src[g] == "lmi"]
  if (length(gi)) {                                          # ÍSOR's area the primary source
    nm$lon[i] <- nm$lon[gi[1]]; nm$lat[i] <- nm$lat[gi[1]]; nm$place_basis[i] <- "ÍSOR's area (one thing with ÍSOR's, version 2)"
    nm$src[i] <- "isor"; nm$extent_km[i] <- nm$extent_km[gi[1]]; nm$extent_basis[i] <- nm$extent_basis[gi[1]]
    if (is.na(nm$edited_at[i])) { ax <- along_axis(nm$id[gi[1]])
      nm$label_lon[i] <- ax[["lon"]]; nm$label_lat[i] <- ax[["lat"]]; nm$label_basis[i] <- "inside ÍSOR's area, along its axis"
      nm$rotate_deg[i] <- ax[["rotate"]]; nm$rotate_basis[i] <- "ÍSOR's area's long axis" }
  }
  else if (length(gl) && broad(nm$class[i]) == "isle") { nm$lon[i] <- nm$lon[gl[1]]; nm$lat[i] <- nm$lat[gl[1]]; nm$place_basis[i] <- "LMÍ's position (one thing with LMÍ's, version 2)" }
  if (is.na(nm$extent_km[i])) { e <- g[!is.na(nm$extent_km[g])]; if (length(e)) { nm$extent_km[i] <- nm$extent_km[e[1]]; nm$extent_basis[i] <- nm$extent_basis[e[1]] } }
  nm$point_kind[i] <- nm$point_kind[i] && all(nm$point_kind[g])
  nm$joined_from[i] <- paste(nm$id[g], collapse = " ")
  if (s_id %in% his_join) nm$flags[i] <- add_flag(nm$flags[i], TRUE, paste0("joined by the maintainer: ", paste(hj$name[hj$link_to == s_id], collapse = ", "), " its synonym"))
  nm$flags[i] <- add_flag(nm$flags[i], TRUE, paste0("one thing with ", paste(sprintf("%s %s (%d)", c(lmi = "LMÍ's", isor = "ÍSOR's", chart = "the charts'", maintainer = "his", trackwell = "Trackwell's")[nm$src[g]],
                                                                                     nm$name_source[g], nm$id[g]), collapse = ", "), " (version 2)"))
}
wp <- pr[pr$outcome == "whole and part", ]
part <- ifelse(wp$sz_km_a <= wp$sz_km_b, wp$id_a, wp$id_b); whole <- ifelse(part == wp$id_a, wp$id_b, wp$id_a)
whole <- vapply(whole, function(x) if (x %in% joined$gone) joined$survivor[match(x, joined$gone)] else x, 0L)
part <- vapply(part, function(x) if (x %in% joined$gone) joined$survivor[match(x, joined$gone)] else x, 0L)
for (r in seq_along(part)) {
  i <- match(part[r], nm$id); j <- match(whole[r], nm$id)
  nm$flags[i] <- add_flag(nm$flags[i], TRUE, sprintf("lies in its namesake %d, %s's (whole and part, version 2)", whole[r], nm$src[j]))
  nm$flags[j] <- add_flag(nm$flags[j], TRUE, sprintf("holds its namesake %d, %s's (whole and part, version 2)", part[r], nm$src[i]))
}
dp <- pr[pr$outcome == "doubtful", ]
for (r in seq_len(nrow(dp))) for (ab in list(c(dp$id_a[r], dp$id_b[r], dp$src_b[r]), c(dp$id_b[r], dp$id_a[r], dp$src_a[r]))) {
  i <- match(as.integer(ab[1]), nm$id)
  nm$flags[i] <- add_flag(nm$flags[i], TRUE, sprintf("doubtful: one name with %s's %s, %.1f km (version 2, for review)", ab[3], ab[2], dp$d_km[r]))
}
gone <- c(gone, joined$gone)
# a name held by a row that is joined away is held by the row kept (the maintainer's join of Öxarfjarðardjúp into
# Axarfjarðardjúp left six coastal names held by the row gone, decision 338)
hg <- which(nm$holder %in% joined$gone & !nm$id %in% gone)
if (length(hg)) { sv <- joined$survivor[match(nm$holder[hg], joined$gone)]
  nm$holder_note[hg] <- ifelse(is.na(nm$holder_note[hg]), sprintf("its holder %s joined into %s", nm$holder_name[hg], nm$name[match(sv, nm$id)]), nm$holder_note[hg])
  nm$holder[hg] <- sv; nm$holder_name[hg] <- nm$name[match(sv, nm$id)] }
message(sprintf("holders joined away: %d names now held by the row kept", length(hg)))
# The link from a name to ÍSOR's crater or mound (version 2, plan 080 §5.2a) -------------------------------------------------
sfx <- read_curated_sf(fd_curated("reference", "seabed_feature.parquet"))
if (!"link_to" %in% names(ed)) ed$link_to <- NA_character_
for (cc in c("seabed_id", "seabed_link")) if (!cc %in% names(nm)) nm[[cc]] <- NA_character_   # a copy brought in keeps its own
if (!"seabed_km" %in% names(nm)) nm$seabed_km <- NA_real_
nm$lon_unlinked <- nm$lon; nm$lat_unlinked <- nm$lat; nm$place_basis_unlinked <- nm$place_basis
live <- !nm$id %in% gone
move_to <- function(i, f, basis) {                         # the thing to a seabed feature; a point kind's label follows
  j <- match(f, sfx$seabed_id); nm$lon[i] <<- sfx$lon[j]; nm$lat[i] <<- sfx$lat[j]; nm$place_basis[i] <<- basis
  follow <- i[nm$point_kind[i] & is.na(nm$edited_at[i])]; nm$label_lon[follow] <<- nm$lon[follow]; nm$label_lat[follow] <<- nm$lat[follow] }
# ÍSOR's own names: their own area or point, by the staged record
ir0 <- rd("isor_record.csv"); ir0$isor_feature <- suppressWarnings(as.integer(ir0$isor_feature))
ir0$isor_feature <- ifelse(ir0$isor_feature %in% joined$gone, joined$survivor[match(ir0$isor_feature, joined$gone)], ir0$isor_feature)
own <- ir0[!is.na(ir0$isor_feature) & ir0$outcome == "shown from a zoom", ]
own$seabed_id <- sfx$seabed_id[match(own$rid, sfx$rid)]
own <- own[!is.na(own$seabed_id) & !duplicated(own$isor_feature), ]
k <- match(own$isor_feature, nm$id); nm$seabed_id[k] <- own$seabed_id; nm$seabed_link[k] <- "ÍSOR's own"; nm$seabed_km[k] <- 0
# a name of a mound's size within its reach of a crater or guyot
cr <- sfx[sfx$kind %in% c("crater", "guyot", "point"), ]; c3 <- st_transform(cr, 3057)
idx <- which(live & is.na(nm$seabed_id))
p3 <- st_transform(st_as_sf(nm[idx, c("lon", "lat")], coords = c("lon", "lat"), crs = 4326), 3057)
nn <- st_nearest_feature(p3, c3); d <- as.numeric(st_distance(p3, c3[nn, ], by_element = TRUE)) / 1000
mound <- nm$sz_km[idx] <= 3
lk <- mound & d <= nm$reach_km[idx] + 0.25
dbt <- mound & !lk & d <= 3
i <- idx[lk]; nm$seabed_id[i] <- cr$seabed_id[nn[lk]]; nm$seabed_link[i] <- "within its reach of ÍSOR's crater"; nm$seabed_km[i] <- round(d[lk], 3)
sea_kind <- i[broad(nm$class[i]) == "sea"]
for (r in sea_kind) move_to(r, nm$seabed_id[r], sprintf("ÍSOR's %s %s (linked, version 2)", cr$kind[match(nm$seabed_id[r], cr$seabed_id)],
                                                         cr$label[match(nm$seabed_id[r], cr$seabed_id)]))
nm$flags[idx[dbt]] <- add_flag(nm$flags[idx[dbt]], rep(TRUE, sum(dbt)), sprintf("doubtful: ÍSOR's %s %s %.1f km off, beyond its reach (version 2, for review)",
                                                                 cr$kind[nn[dbt]], cr$label[nn[dbt]], d[dbt]))
# a name inside a seamount, linked to no crater
sm <- sfx[sfx$kind == "seamount", ]
idx <- which(live & is.na(nm$seabed_id))
p4 <- st_as_sf(nm[idx, c("lon", "lat")], coords = c("lon", "lat"), crs = 4326)
hit <- st_intersects(p4, st_make_valid(sm))
ins <- lengths(hit) > 0
nm$seabed_id[idx[ins]] <- sm$seabed_id[vapply(hit[ins], `[`, 0L, 1)]; nm$seabed_link[idx[ins]] <- "inside ÍSOR's seamount"; nm$seabed_km[idx[ins]] <- 0
# Claude's proposals he accepts (plan 081, decision 337; reference/names/place_name_proposal.R): his latest verdict on a
# proposal's key; an accepted one puts the name's thing at the proposal's place, its extent the proposal's (LMÍ's set aside
# below), its seabed link the proposal's element; a proposal with no trough is accepted as it stands. Applied before his own
# links and pins, which win. A trough no name of ours takes comes in by the `new` row the page writes with his Accept.
pv <- ed |> filter(action %in% c("accept proposal", "reject proposal")) |> arrange(at) |> group_by(link_to) |> slice_tail(n = 1) |> ungroup()
pa <- pv |> filter(action == "accept proposal"); accepted_prop <- data.frame(feature = integer(), key = character())
if (nrow(pa)) {
  PRF <- fd_curated("reference", "place_name_proposal.parquet")
  if (!file.exists(PRF)) stop("accepted proposals but no proposal table: run reference/names/place_name_proposal.R")
  prp <- st_drop_geometry(read_curated_sf(PRF))
  if (!all(pa$link_to %in% prp$key)) stop("accepted proposals that are not proposals now: ", paste(setdiff(pa$link_to, prp$key), collapse = ", "))
  q <- prp[match(pa$link_to, prp$key), ]
  # a fjord (LMÍ's feature fjörður) keeps its own place and area, its area joined with its part of the trough, the fjord's
  # floor (decision 338)
  fjord_ids <- unique(as.integer(c(cj$feature[grepl("fjörður", coalesce(cj$bearers, ""))], lf$feature[grepl("fjörður", coalesce(lf$bearers, ""))])))
  for (r in which(!is.na(q$name_id) & q$trough != "none")) { i <- match(q$name_id[r], nm$id)
    if (is.na(i)) stop("an accepted proposal for a name not in the list: ", q$name[r])
    if (!nm$id[i] %in% fjord_ids) { nm$lon[i] <- q$lon[r]; nm$lat[i] <- q$lat[r]
      nm$place_basis[i] <- paste0("Claude's proposal, accepted by the maintainer ", pa$at[r], ": ", q$place_basis[r]) }
    nm$seabed_id[i] <- q$element[r]; nm$seabed_link[i] <- paste0("Claude's proposal, accepted by the maintainer, ", pa$at[r]); nm$seabed_km[i] <- NA_real_
    nm$extent_km[i] <- q$extent_km[r]; nm$extent_basis[i] <- paste0(q$extent_basis[r], " (Claude's proposal, accepted by the maintainer)")
    accepted_prop <- rbind(accepted_prop, data.frame(feature = nm$id[i], key = q$key[r])) }
  fjord_acc <- accepted_prop[accepted_prop$feature %in% fjord_ids, ]
  if (nrow(fjord_acc)) {
    lx0 <- st_read(file.path(V1, "lmi_extent.geojson"), quiet = TRUE); lx0$feature <- as.integer(sub("^c", "", lx0$id))
    s1 <- read_curated_sf(fd_curated("reference", "place_name_proposal_shape.parquet")); s1 <- s1[s1$what == "extent", ]
    fjord_area <- list()
    for (r in seq_len(nrow(fjord_acc))) { i <- match(fjord_acc$feature[r], nm$id); a <- lx0[lx0$feature == fjord_acc$feature[r], ]
      if (!nrow(a)) next
      u <- st_union(c(st_geometry(st_make_valid(st_transform(a, 4326))), st_geometry(st_transform(s1[s1$key == fjord_acc$key[r], ], 4326))))
      bb <- st_bbox(st_transform(u, 3057)); nm$extent_km[i] <- round(max(bb$xmax - bb$xmin, bb$ymax - bb$ymin) / 1000, 3)
      nm$extent_basis[i] <- paste0("its own area as a fjord (LMÍ's), joined with ", nm$extent_basis[i])
      fjord_area[[as.character(nm$id[i])]] <- u }
  }
  # the letters of an accepted name: inside its accepted area (a fjord's joined with its own), along the area's long axis,
  # every accepted name's, version 1's hand placements and his earlier moves included; a move or turn of his after
  # LETTERS_RESET wins (decision 338; the maintainer, 2026-11-20, of the trough names' letters left at version 1's places:
  # "Yes, where no hand", then "I think we may as well process all the letter positions the same way. Do do them all.")
  LETTERS_RESET <- "2026-11-20T13:37:50Z"
  s2 <- read_curated_sf(fd_curated("reference", "place_name_proposal_shape.parquet")); s2 <- s2[s2$what == "extent", ]
  fa <- if (exists("fjord_area")) fjord_area else list()
  # and its zoom: rule e on the accepted area's length along its long axis, its size with it; his zoom edit wins (decision 338;
  # the maintainer, 2026-11-20: "Yes, rule e on the area")
  for (r in seq_len(nrow(accepted_prop))) { i <- match(accepted_prop$feature[r], nm$id)
    g <- if (!is.null(fa[[as.character(nm$id[i])]])) fa[[as.character(nm$id[i])]] else st_geometry(s2[s2$key == accepted_prop$key[r], ])
    if (!length(g)) next
    ax <- axis_of(g); ze <- rule_e(ax[["len_m"]], ax[["lat"]], nchar(nm$name[i]))
    nm$z_rule_computed[i] <- ze[["z"]]; nm$z_rule_basis[i] <- "rule e on its accepted area's length along its long axis (decision 338)"
    if (is.na(nm$zoom_edited_at[i])) { nm$z_rule[i] <- ze[["z"]]; nm$size[i] <- ze[["size"]] }
    if (!is.na(nm$edited_at[i]) && nm$edited_at[i] > LETTERS_RESET) next
    nm$label_lon[i] <- ax[["lon"]]; nm$label_lat[i] <- ax[["lat"]]; nm$label_basis[i] <- "inside its accepted area, along its long axis"
    nm$rotate_deg[i] <- ax[["rotate"]]; nm$rotate_basis[i] <- "its accepted area's long axis" }
}
message(sprintf("Claude's proposals: %d accepted (%d placed on a trough), %d rejected", nrow(pa), nrow(accepted_prop), sum(pv$action == "reject proposal")))
# his links and unlinks: the latest of a feature
linked_area <- data.frame(feature = integer(), seabed_id = character()); linked_line <- linked_area
deepest_in <- function(g) {   # the deepest 200 m cell within the outline's largest inscribed circle (plan 081 step 1's rule):
  # deep, central, away from a trough's mouth on the slope
  dm4 <- terra::aggregate(terra::rast(fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif")), 4)
  g3 <- st_union(st_transform(st_geometry(g), 3057)); a <- st_intersection(st_inscribed_circle(g3, dTolerance = 50)[1], g3)
  v <- terra::vect(st_transform(a, terra::crs(dm4))); z <- terra::mask(terra::crop(dm4, v, snap = "out"), v, touches = FALSE); c <- which.min(terra::values(z))
  p <- st_coordinates(st_transform(st_sfc(st_point(terra::xyFromCell(z, c)[1, ]), crs = terra::crs(dm4)), 4326))
  c(p[1], p[2], -terra::values(z)[c]) }
hl <- ed |> filter(action %in% c("link", "unlink")) |> arrange(at) |> group_by(feature) |> slice_tail(n = 1) |> ungroup()
if (nrow(hl)) {
  k <- match(hl$feature, nm$id)
  if (anyNA(k) || any(hl$action == "link" & !hl$link_to %in% sfx$seabed_id)) stop("links that find no name or no seabed feature")
  for (r in seq_len(nrow(hl))) { i <- k[r]
    if (hl$action[r] == "link") {
      nm$seabed_id[i] <- hl$link_to[r]; nm$seabed_link[i] <- paste0("by the maintainer, ", hl$at[r]); nm$seabed_km[i] <- NA_real_
      j <- match(hl$link_to[r], sfx$seabed_id)
      move_to(i, hl$link_to[r], sprintf("ÍSOR's %s, linked by the maintainer",
                                        if (startsWith(sfx$label[j], sfx$kind[j])) sfx$label[j] else paste(sfx$kind[j], sfx$label[j])))
      # an area linked by hand is the name's extent (LMÍ's set aside below); a trough's thing is its deepest point (the
      # maintainer, 2026-11-19, of Skerjadjúp on ÍSOR's trough 6: "Yes, do it")
      if (as.character(st_geometry_type(sfx[j, ])) %in% c("POLYGON", "MULTIPOLYGON")) {
        linked_area <- rbind(linked_area, data.frame(feature = nm$id[i], seabed_id = hl$link_to[r]))
        bb <- st_bbox(st_transform(sfx[j, ], 3057)); nm$extent_km[i] <- round(max(bb$xmax - bb$xmin, bb$ymax - bb$ymin) / 1000, 3)
        nm$extent_basis[i] <- sprintf("ÍSOR's %s (%s), linked by the maintainer: the longer side of its box", sfx$kind[j], hl$link_to[r])
        if (sfx$kind[j] == "trough") { q <- deepest_in(sfx[j, ])
          nm$lon[i] <- q[1]; nm$lat[i] <- q[2]
          nm$place_basis[i] <- sprintf("the deepest point within the largest circle inside ÍSOR's trough (%s), %.0f m on the depth model's 200 m cells, linked by the maintainer", hl$link_to[r], q[3]) }
      }
      # a line linked by hand (a moraine: the maintainer, 2026-11-20, "moraine 229 is "Táin" as in "Selvogsbankatáin"") is
      # the name's line, its length the extent; LMÍ's area and the depth model's line set aside below
      if (as.character(st_geometry_type(sfx[j, ])) %in% c("LINESTRING", "MULTILINESTRING")) {
        linked_line <- rbind(linked_line, data.frame(feature = nm$id[i], seabed_id = hl$link_to[r]))
        nm$extent_km[i] <- round(as.numeric(st_length(st_transform(sfx[j, ], 3057))) / 1000, 3)
        nm$extent_basis[i] <- sprintf("ÍSOR's %s (%s), linked by the maintainer: its length", sfx$kind[j], hl$link_to[r])
      }
    } else {
      nm$seabed_id[i] <- NA_character_; nm$seabed_link[i] <- paste0("unlinked by the maintainer, ", hl$at[r]); nm$seabed_km[i] <- NA_real_
      nm$lon[i] <- nm$lon_unlinked[i]; nm$lat[i] <- nm$lat_unlinked[i]; nm$place_basis[i] <- nm$place_basis_unlinked[i]
    } }
}
message(sprintf("links to ÍSOR's features: %s; doubtful %d; by hand %d",
                paste(sprintf("%s %d", names(table(nm$seabed_link[live])), table(nm$seabed_link[live])), collapse = ", "), sum(dbt), nrow(hl)))

# The maintainer's pins: where the thing is, by his hand (version 2) ------------------------------------------------------
nm$thing_lon_computed <- nm$lon; nm$thing_lat_computed <- nm$lat; nm$pinned_at <- NA_character_
pn <- ed |> filter(action %in% c("pin", "unpin")) |> arrange(at) |> group_by(feature) |> slice_tail(n = 1) |> ungroup()
if (nrow(pn)) {
  k <- match(pn$feature, nm$id)
  if (anyNA(k) || any(k %in% match(gone, nm$id))) stop("pins that find no feature of the list: ", paste(pn$name[is.na(k) | k %in% match(gone, nm$id)], collapse = ", "))
  okn <- vapply(seq_along(k), function(r) any(same(names_as(k[r]), pn$name[r])), logical(1))
  if (!all(okn)) stop("pins whose name is not the feature's: ", paste(pn$name[!okn], collapse = ", "))
  p1 <- pn$action == "pin"; i <- k[p1]
  nm$lon[i] <- pn$lon[p1]; nm$lat[i] <- pn$lat[p1]; nm$pinned_at[i] <- pn$at[p1]
  nm$place_basis[i] <- paste0("the maintainer's hand, ", pn$at[p1])
  follow <- i[nm$point_kind[i] & is.na(nm$edited_at[i])]          # a point kind's label beside its thing, unless moved by hand
  nm$label_lon[follow] <- nm$lon[follow]; nm$label_lat[follow] <- nm$lat[follow]
}
message(sprintf("pins: %d features placed by the maintainer's hand", sum(!is.na(nm$pinned_at))))
pairs <- pr |> transmute(id_a, src_a, name_a, lon_a, lat_a, id_b, src_b, name_b, lon_b, lat_b, km = round(km, 3), d_km = round(d_km, 3), size_a_km = sz_km_a,
                         size_b_km = sz_km_b, ratio = round(ratio, 2), kind_a = kb_a, kind_b = kb_b, outcome, why,
                         kept = ifelse(outcome == "one thing", into, NA_integer_), version = VERSION)
message(sprintf("one name, two sources, within 10 km: %d pairs: %s", nrow(pr), paste(sprintf("%s %d", names(table(pr$outcome)), table(pr$outcome)), collapse = ", ")))

# ÍSOR's reports of 2008 on the names of the sea floor, for Orkustofnun ------------------------------------------------------
# Orkustofnun's 2014 delivery to LMÍ (source V201404005) gave the reports' names their only geometry; the reports give each
# its description, its English name and whether it was coined (◊), and hold no coordinates. A row whose LMÍ source is that
# delivery takes the report entries of its name (its synonyms' too); a name no entry spells alike takes the one entry a
# single letter apart, flagged (LMÍ's Niflingur is the report's Niflungur). The maintainer, 2026-11-20: "Yes, attach them".
low <- function(x) gsub("[^a-zþæöðáéíóúý]", "", tolower(x))
dn <- as.data.frame(nanoparquet::read_parquet(fd_staging("ornefni", "document_name.parquet")))
dn <- dn[grepl("^GRG-ISOR-", dn$document), ]; dn$k <- low(dn$name)
dn$ref <- sprintf("%s p. %d (%s)", sub("\\.pdf$", "", dn$document), dn$page, sub(" \\(mynd [0-9]+\\)$", "", dn$section))
os <- which(grepl("V201404005", coalesce(nm$lmi_source, "")) & !nm$id %in% gone)
nm$report <- NA_character_; nm$report_entry <- NA_character_; nm$name_en <- NA_character_; nm$coined <- NA
rep_hit <- integer(); rep_near <- character()
for (i in os) { ks <- low(c(nm$name[i], if (!is.na(nm$synonyms[i])) trimws(strsplit(nm$synonyms[i], "[;,]")[[1]])))
  e <- dn[dn$k %in% ks, ]
  if (!nrow(e)) { d1 <- adist(low(nm$name[i]), dn$k)[1, ]; if (sum(d1 == 1) == 1) { e <- dn[d1 == 1, ]; rep_near <- c(rep_near, sprintf("%s (the report: %s)", nm$name[i], e$name)) } }
  if (!nrow(e)) next
  rep_hit <- c(rep_hit, i)
  nm$report[i] <- paste(e$ref, collapse = "; "); nm$report_entry[i] <- paste(e$description, collapse = " | ")
  nm$name_en[i] <- paste(unique(na.omit(e$name_en)), collapse = "; "); nm$coined[i] <- any(e$coined %in% TRUE)
  if (!nzchar(nm$name_en[i])) nm$name_en[i] <- NA_character_
  if (low(nm$name[i]) != e$k[1] && !low(nm$name[i]) %in% e$k) nm$flags[i] <- trimws(paste(na.omit(c(nm$flags[i], sprintf("spelt %s in ÍSOR's report of 2008", e$name[1]))), collapse = "; ")) }
message(sprintf("ÍSOR's reports of 2008: %d of the %d rows of Orkustofnun's 2014 delivery take an entry (%d coined; a letter apart: %s); %d rows none: %s",
  length(rep_hit), length(os), sum(nm$coined[rep_hit] %in% TRUE), if (length(rep_near)) paste(rep_near, collapse = ", ") else "none",
  length(setdiff(os, rep_hit)), paste(sort(nm$name[setdiff(os, rep_hit)]), collapse = ", ")))

# The feature list --------------------------------------------------------------------------------------------------------
out <- nm |> filter(!id %in% gone) |>
  transmute(id, src, name, name_source, name_basis, renamed_at, name_printed, synonyms, kind, class, point_kind,
            lon, lat, place_basis, pinned_at, thing_lon_computed, thing_lat_computed, label_lon, label_lat, label_basis,
            place_basis_computed, lon_computed = lon0,
            lat_computed = lat0, lmi_moved_m, rotate_deg, rotate_basis, rotate_computed = rotate0, rotate_low_deg, level_from_zoom,
            z_rule, z_rule_basis, z_rule_computed, zoom_edited_at,
            extent_km, extent_basis, holder, holder_name, holder_note, size, priority, label_dy, n_letterings, charts, coarsest_chart, finest_scale,
            lmi_source, lmi_source_kind, isor_references, report, report_entry, name_en, coined, flags, possible_duplicate, reading_corrected, legend_entry, edited_at,
            place_note_v1, angle_note_v1, joined_from, brought_in, seabed_id, seabed_link, seabed_km, seabed_members, version = VERSION)
out_sf <- st_as_sf(out, coords = c("lon", "lat"), crs = 4326, remove = FALSE)

# The links to the source records ------------------------------------------------------------------------------------------
# letterings.csv (71) holds each lettering with the feature it is shown as: a far piece of a long name (70) or a fjord's piece
# in another's water (76) is shown as its host, so 67's feature (lettering_feature.csv) may differ
ltf$key <- paste(ltf$chart, ltf$label_id, sep = "/"); let$key <- paste(let$chart, let$label_id, sep = "/")
stopifnot(setequal(ltf$key, let$key))
ltf$shown <- let$feature[match(ltf$key, let$key)]
ltf$into <- ltf$shown; k <- ltf$shown %in% piece$feature; ltf$into[k] <- piece$into[match(ltf$shown[k], piece$feature)]
# a chart row joined into another (by the rule for two sources, or by his `join`): its letterings with the row kept
jj <- ltf$into %in% joined$gone; ltf$joined_row <- ifelse(jj, ltf$into, NA_integer_); ltf$into[jj] <- joined$survivor[match(ltf$into[jj], joined$gone)]
src_chart <- ltf |> filter(into %in% out$id) |>
  transmute(id = into, source = "chart", source_id = key,
            role = case_when(shown %in% piece$feature ~ "lettering, a piece read cut short (overrides/marine_name_reading.csv)",
                             !is.na(joined_row) ~ paste0("lettering of ", name, ", a row joined into it", ifelse(joined_row %in% his_join_gone, " by the maintainer", " (one thing from two sources)")),
                             shown != feature ~ "lettering of a piece joined into it (the study's 70 or 76)",
                             TRUE ~ paste0("lettering: ", joined)))
rk <- function(f) { f <- as.integer(f); ifelse(f %in% joined$gone, joined$survivor[match(f, joined$gone)], f) }   # a joined row's to its kept row
JOINED <- " (joined in version 2: one thing from two sources)"
lf_joined <- as.integer(lf$feature) %in% joined$gone
lf$feature <- rk(lf$feature); cj$feature <- rk(cj$feature); isl$feature <- rk(isl$feature)
lmi_link <- function(ids, us, role) tibble(id = rep(ids, lengths(us)), source = "lmi", source_id = unlist(us),
                                           role = if (length(role) > 1) rep(role, lengths(us)) else role)
src_lmi <- bind_rows(
  lmi_link(lf$feature[lf$feature %in% out$id], uuids(lf$uuids[lf$feature %in% out$id]),
           ifelse(lf_joined[lf$feature %in% out$id], paste0("record", JOINED), "record")),
  lmi_link(cj$feature[cj$feature %in% out$id], uuids(cj$uuids[cj$feature %in% out$id]), "record joined to the chart's feature (one name)"),
  lmi_link(isl$feature[!is.na(isl$feature) & isl$feature %in% out$id], uuids(isl$uuid[!is.na(isl$feature) & isl$feature %in% out$id]),
           "island record (110)"),
  if (nrow(inc)) lmi_link(INCLUDED_FROM + as.integer(st$id[match(inc$source_id, st$uuid)]), as.list(inc$source_id),
                          ifelse(inc$how == "maintainer", "record brought in by the maintainer (version 2)", "record brought in by the region's rule (version 2)"))) |> filter(nzchar(source_id)) |> distinct(id, source, source_id, .keep_all = TRUE)
ir <- rd("isor_record.csv"); ij <- rd("isor_join.csv")
ir_joined <- !is.na(ir$isor_feature) & as.integer(ir$isor_feature) %in% joined$gone
ir$isor_feature <- rk(ir$isor_feature); ij$feature <- rk(ij$feature)
src_isor <- bind_rows(
  ir |> mutate(j = ir_joined) |> filter(!is.na(isor_feature), isor_feature %in% out$id) |>
    transmute(id = as.integer(isor_feature), source = "isor", source_id = as.character(rid), role = ifelse(j, paste0("record", JOINED), "record")),
  # 131 counts a point and a line of one name as one witness (isor_join gives its first kind and the records' count)
  ir |> filter(outcome == "one name with the map's") |> mutate(grp = ifelse(kind == "area", "area", "point or line")) |>
    inner_join(ij |> transmute(id = feature, isor_name, grp = ifelse(isor_kind == "area", "area", "point or line")),
               by = c(name = "isor_name", "grp"), relationship = "many-to-many") |>
    filter(id %in% out$id) |> transmute(id, source = "isor", source_id = as.character(rid), role = "witness (one name with the map's)"))
src_tw <- nm |> filter(!is.na(accepted_key), !id %in% gone) |> transmute(id, source = "trackwell", source_id = accepted_key,
                                                                        role = "Trackwell's candidate, accepted by the maintainer (version 2)")
src_own <- nm |> filter(src == "maintainer") |> transmute(id, source = "maintainer", source_id = own_key, role = "the maintainer's own name (version 2)")
src <- bind_rows(src_chart, src_lmi, src_isor, src_tw, src_own) |> filter(id %in% out$id) |> arrange(id, source, source_id)
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
                            f = rk(coalesce(suppressWarnings(as.integer(lmi_feature)), suppressWarnings(as.integer(chart_feature))))), by = "source_id") |>
  transmute(source, source_id, name, feature = ifelse(f %in% out$id, f, NA_integer_),
            outcome = coalesce(v1_outcome, "inland, beyond the shore's 1 km band (the study's 115)"), detail)
rec_isor <- tibble(source = "isor", source_id = as.character(sr$rid), name = sr$name) |>
  left_join(ir |> transmute(source_id = as.character(rid), outcome), by = "source_id") |>
  left_join(src_isor |> group_by(source_id) |> summarise(feature = first(id), .groups = "drop"), by = "source_id") |>
  transmute(source, source_id, name, feature, outcome, detail = NA_character_)
if (nrow(inc)) {                                           # the records brought in: their outcome and feature
  k <- match(inc$source_id, lmi_out$source_id)
  lmi_out$outcome[k] <- ifelse(inc$how == "maintainer", "brought in by the maintainer", "brought in by the region's rule (ask m)")
  lmi_out$feature[k] <- INCLUDED_FROM + as.integer(st$id[match(inc$source_id, st$uuid)])
  lmi_out$detail[k] <- inc$why
}
if (length(removed_ids)) { k <- which(lmi_out$feature %in% removed_ids)
  lmi_out$outcome[k] <- "removed by the maintainer"; lmi_out$detail[k] <- rmv$why[match(lmi_out$feature[k], rmv$feature)]; lmi_out$feature[k] <- NA_integer_ }
if (length(unplaced)) { k <- match(unplaced, lmi_out$source_id)
  lmi_out$outcome[k] <- "a copy in an open region, no place found (for review)"; lmi_out$feature[k] <- NA_integer_ }
rec_tw <- if (is.null(twc)) NULL else {
  lv <- latest_vd$action[match(twc$key, latest_vd$link_to)]
  tibble(source = "trackwell", source_id = twc$key, name = twc$name,
         feature = nm$id[match(twc$key, nm$accepted_key)],
         outcome = case_when(lv %in% "accept" ~ "accepted by the maintainer", lv %in% "reject" ~ "rejected by the maintainer",
                             twc$outcome == "ignored by the maintainer" ~ "ignored by the maintainer",
                             TRUE ~ paste0("a Trackwell name: ", twc$outcome)),
         detail = sprintf("%d tows by %d vessels in %s; %s", twc$tows, twc$vessels, twc$region, twc$place_basis)) }
rec_own <- nm |> filter(src == "maintainer") |> transmute(source = "maintainer", source_id = own_key, name, feature = id,
                                                            outcome = "a name of the maintainer's own", detail = flags)
rec <- bind_rows(rec_chart, lmi_out, rec_isor, rec_tw, rec_own)
stopifnot(nrow(rec_chart) == 8203L, nrow(lmi_out) == 200674L, nrow(rec_isor) == 2825L, !anyNA(rec$outcome),
          !any(rec$outcome == "no feature in version 1"), !anyDuplicated(rec[c("source", "source_id")]))

# The extents and the long names' lines ------------------------------------------------------------------------------------
lx <- st_read(file.path(V1, "lmi_extent.geojson"), quiet = TRUE)
lx$feature <- rk(sub("^c", "", lx$id)); lx$what <- "extent"; lx$basis <- ifelse(grepl("^c", lx$id), "LMÍ's, joined to the chart's feature", "LMÍ's")
ix <- st_read(file.path(V1, "isor_extent.geojson"), quiet = TRUE); ix$feature <- rk(ix$id); ix$what <- "extent"; ix$basis <- "ÍSOR's"
lx$z_line <- NA_real_; ix$z_line <- NA_real_
nl <- st_read(file.path(V1, "name_lines.geojson"), quiet = TRUE); nl$feature <- as.integer(nl$feature); nl$what <- "line"
nl$basis <- "the long feature's line on the depth model (the study's 70, 72, 79)"
la <- if (nrow(linked_area)) { g <- sfx[match(linked_area$seabed_id, sfx$seabed_id), ]
  st_sf(feature = linked_area$feature, what = "extent", basis = paste0("ÍSOR's ", g$kind, " (", linked_area$seabed_id, "), linked by the maintainer"),
        z_line = NA_real_, geometry = st_geometry(st_transform(g, st_crs(lx)))) } else NULL
ll <- if (nrow(linked_line)) { g <- sfx[match(linked_line$seabed_id, sfx$seabed_id), ]
  st_sf(feature = linked_line$feature, what = "extent", basis = paste0("ÍSOR's ", g$kind, " (", linked_line$seabed_id, "), linked by the maintainer"),
        z_line = NA_real_, geometry = st_geometry(st_transform(g, st_crs(lx)))) } else NULL
la <- rbind(la, ll)
# an accepted proposal's extent, unless he linked the name by hand since (his link wins)
pe <- if (nrow(accepted_prop)) { s0 <- read_curated_sf(fd_curated("reference", "place_name_proposal_shape.parquet"))
  s0 <- s0[s0$what == "extent" & s0$key %in% accepted_prop$key, ]; s0$feature <- accepted_prop$feature[match(s0$key, accepted_prop$key)]
  s0 <- s0[!s0$feature %in% c(linked_area$feature, linked_line$feature), ]
  if (nrow(s0)) st_sf(feature = s0$feature, what = "extent", basis = paste0(s0$basis, ", accepted by the maintainer"), z_line = NA_real_,
                      geometry = st_geometry(st_transform(s0, st_crs(lx)))) } else NULL
if (!is.null(pe) && exists("fjord_area") && length(fjord_area)) for (f in names(fjord_area)) { j <- which(pe$feature == as.integer(f))   # a fjord's own area joined
  if (length(j)) { st_geometry(pe)[j] <- st_transform(fjord_area[[f]], st_crs(lx)); pe$basis[j] <- paste0(pe$basis[j], ", joined with its own area as a fjord (LMÍ's)") } }
la <- rbind(la, pe)
# a name of his own made from an accepted trough proposal: the proposal's extent (the trough), not the hull of its members
if (!is.null(own_hull) && !is.null(pe)) own_hull <- own_hull[!own_hull$feature %in% pe$feature, ]
ex <- rbind(lx[c("feature", "what", "basis", "z_line")], ix[c("feature", "what", "basis", "z_line")], nl[c("feature", "what", "basis", "z_line")],
            if (!is.null(bx)) st_transform(bx, st_crs(lx))[c("feature", "what", "basis", "z_line")],
            if (!is.null(own_hull)) st_transform(own_hull, st_crs(lx))[c("feature", "what", "basis", "z_line")],
            la) |>
  filter(feature %in% out$id) |> st_transform(4326)
# ÍSOR's area over LMÍ's: a row with both uses ÍSOR's (its own, or an area or line he linked, a line's extent the line
# itself), LMÍ's set aside, kept (version 2)
with_isor <- unique(ex$feature[ex$what == "extent" & grepl("^ÍSOR's", ex$basis)])
aside <- ex$what == "extent" & grepl("^LMÍ's", ex$basis) & ex$feature %in% with_isor
ex$used <- !aside
ex$set_aside <- ifelse(aside, ifelse(ex$feature %in% linked_line$feature, "ÍSOR's line, linked by the maintainer, over LMÍ's area",
                                     "ÍSOR's area over LMÍ's (the maintainer, 2026-11-19)"), NA_character_)
asd <- ed |> filter(action == "area aside") |> arrange(at) |> group_by(feature) |> slice_tail(n = 1) |> ungroup()
k <- ex$what == "extent" & grepl("^LMÍ's", ex$basis) & ex$feature %in% asd$feature
ex$used[k] <- FALSE; ex$set_aside[k] <- paste0("set aside by the maintainer, ", asd$at[match(ex$feature[k], asd$feature)])
message(sprintf("extents: %d in use, %d of LMÍ's set aside where ÍSOR's area is the row's", sum(ex$used), sum(aside)))

# Write --------------------------------------------------------------------------------------------------------------------
OUT <- fd_curated("reference")
STAMP <- c("fd.version" = as.character(VERSION))
write_curated(out_sf, file.path(OUT, "marine_name.parquet"), inputs = INPUTS, script = SCRIPT, stamps = STAMP)
write_curated(src, file.path(OUT, "marine_name_source.parquet"), inputs = INPUTS, script = SCRIPT, stamps = STAMP)
write_curated(rec, file.path(OUT, "marine_name_record.parquet"), inputs = INPUTS, script = SCRIPT, stamps = STAMP)
write_curated(ex, file.path(OUT, "marine_name_extent.parquet"), inputs = INPUTS, script = SCRIPT, stamps = STAMP)
write_curated(pairs, file.path(OUT, "marine_name_pair.parquet"), inputs = INPUTS, script = SCRIPT, stamps = STAMP)
print(knitr::kable(count(out, src, kind), caption = "marine_name: features by source and kind"))
print(knitr::kable(count(rec, source, outcome), caption = "marine_name_record: every record in one outcome"))
print(knitr::kable(count(pairs, src_a, src_b, outcome), caption = "marine_name_pair: one name from two sources within 10 km"))
