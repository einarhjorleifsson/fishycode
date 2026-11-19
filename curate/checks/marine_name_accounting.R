# marine_name_accounting.R — the names list's bookkeeping: every record of the three sources in one outcome, every feature
# traced to its records, and every difference from the names map's version 1 explained (plan 074 step 12).
# Side: preprocessing (sea-chart names). Standalone, run by hand after reference/names/marine_name.R, outside the targets flow.
#
# Input:  raw/external/is50v/ornefni_all/README-provenance.txt (IS 50V's own counts), staging/isor/seabed_name.parquet,
#         curated/reference/chart_names.parquet, the study's frozen names_v1/names.geojson (version 1's names as shown),
#         overrides/marine_name_{edits,reading,duplicate}.csv,
#         curated/reference/{marine_name,marine_name_source,marine_name_record,marine_name_extent}.parquet
# Output: curated/check/marine_name_accounting.parquet - one row per check: the check, its verdict ("ok" or what failed), n
#         curated/check/marine_name_v1_diff.parquet    - every feature whose name, place, angle or zoom differs from version
#                                                        1, what differs, by how much, and why (unexplained: none allowed)
#
# Bookkeeping, not an agreement rate (decision 155). The script stops, after writing, unless:
#   - each source's records are counted again from outside the list (IS 50V's server counts in the dump's provenance, ÍSOR's
#     staged records, the charts' curated labels) and each appears once in marine_name_record, in one outcome;
#   - a record whose outcome says it is in the list points to a feature of the list, and no other record does;
#   - every feature has a place, a basis for it, an angle and a zoom; every chart feature a lettering, every LMÍ feature an
#     LMÍ record, every ÍSOR feature an ÍSOR record; every link to a record that exists; a holder in the list;
#     the duplicates flagged both ways; the extents' features in the list;
#   - every difference from version 1 has a reason: the reading corrected, the piece folded into its feature, a submerged
#     rock at LMÍ's position, or an edit of the maintainer's (made after version 1 was written, or reverted after it).
# Run from the repo root: Rscript curate/checks/marine_name_accounting.R. Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages(library(dplyr))
for (f in c("R/paths.R", "R/write_curated.R")) source(f)                     # standalone: not targets'
REF <- function(f) fd_curated("reference", f)
nm  <- as.data.frame(nanoparquet::read_parquet(REF("marine_name.parquet")))
src <- as.data.frame(nanoparquet::read_parquet(REF("marine_name_source.parquet")))
rec <- as.data.frame(nanoparquet::read_parquet(REF("marine_name_record.parquet")))
ex  <- as.data.frame(nanoparquet::read_parquet(REF("marine_name_extent.parquet")))
cn  <- nanoparquet::read_parquet(REF("chart_names.parquet"))
sr  <- nanoparquet::read_parquet(fd_staging("isor", "seabed_name.parquet"))
V1  <- fd_path("archive", "2026-11-11-named-features", "out", "frozen", "names_v1")
rdg <- read.csv("overrides/marine_name_reading.csv", encoding = "UTF-8")
dup <- read.csv("overrides/marine_name_duplicate.csv", encoding = "UTF-8")
ed  <- read.csv("overrides/marine_name_edits.csv", encoding = "UTF-8")

acc <- data.frame(check = character(), verdict = character(), n = integer())
ok <- function(what, cond, n = NA_integer_) { cond <- isTRUE(all(cond))
  acc[nrow(acc) + 1, ] <<- list(what, if (cond) "ok" else "FAILED", as.integer(n)) }

# Every record once, in one outcome ---------------------------------------------------------------------------------------
prov <- readLines(fd_raw("external", "is50v", "ornefni_all", "README-provenance.txt"), encoding = "UTF-8")
n_is50v <- sum(as.integer(sub(".*the server's own count ([0-9]+).*", "\\1", grep("the server's own count", prov, value = TRUE))))
by_src <- table(rec$source)
ok(sprintf("every record once: the charts' labels %d, IS 50V's names %d (the server's counts), ÍSOR's records %d",
           nrow(cn), n_is50v, nrow(sr)),
   by_src[["chart"]] == nrow(cn) && by_src[["lmi"]] == n_is50v && by_src[["isor"]] == nrow(sr) &&
     !anyDuplicated(rec[c("source", "source_id")]) && setequal(rec$source_id[rec$source == "chart"], paste(cn$chart, cn$label_id, sep = "/")) &&
     setequal(rec$source_id[rec$source == "isor"], as.character(sr$rid)), nrow(rec))
ok("one outcome each", !is.na(rec$outcome) & nzchar(rec$outcome), nrow(rec))
IN <- c("a lettering of a feature in the list", "shown from a zoom", "already the chart's feature (one name)", "one name with the map's")
inl <- rec$outcome %in% IN
ok("a record in the list points to a feature of the list", rec$feature[inl] %in% nm$id, sum(inl))
ok("a record left out points to none", is.na(rec$feature[!inl]), sum(!inl))

# Every feature traced and complete ------------------------------------------------------------------------------------------
ok("ids unique", !anyDuplicated(nm$id), nrow(nm))
ok("every feature has a place, a basis, an angle and a zoom",
   !is.na(nm$lon) & !is.na(nm$lat) & !is.na(nm$place_basis) & !is.na(nm$rotate_deg) & !is.na(nm$z_rule), nrow(nm))
ok("every chart feature has a lettering", nm$id[nm$src == "chart"] %in% src$id[src$source == "chart"], sum(nm$src == "chart"))
ok("every LMÍ feature has an LMÍ record", nm$id[nm$src == "lmi"] %in% src$id[src$source == "lmi"], sum(nm$src == "lmi"))
ok("every ÍSOR feature has an ÍSOR record", nm$id[nm$src == "isor"] %in% src$id[src$source == "isor"], sum(nm$src == "isor"))
ok("every link to a feature of the list and to a record that exists",
   src$id %in% nm$id & paste(src$source, src$source_id) %in% paste(rec$source, rec$source_id), nrow(src))
hold <- nm$holder[!is.na(nm$holder)]
ok("a holder is a feature of the list", hold %in% nm$id, length(hold))
ok("the duplicates flagged both ways (overrides)", nm$possible_duplicate[match(dup$feature_a, nm$id)] == dup$feature_b &
   nm$possible_duplicate[match(dup$feature_b, nm$id)] == dup$feature_a & sum(!is.na(nm$possible_duplicate)) == 2 * nrow(dup), nrow(dup))
ok("the extents' features are in the list", ex$feature %in% nm$id, nrow(ex))
ok("every text valid UTF-8", all(validUTF8(c(nm$name, nm$synonyms, nm$lmi_source, rec$name, src$role))), nrow(nm))

# Every difference from version 1, explained ----------------------------------------------------------------------------------
g <- jsonlite::fromJSON(file.path(V1, "names.geojson"), simplifyVector = TRUE)$features
v1 <- data.frame(id = as.integer(g$properties$feature), name = g$properties$name, rot = g$properties$rot, z = g$properties$z_rule,
                 edited = g$properties$edited, do.call(rbind, g$geometry$coordinates))
names(v1)[6:7] <- c("lon", "lat")
m <- match(v1$id, nm$id)
d_m <- function(a, b, c, e) sqrt(((a - c) * 111320 * cos(b * pi / 180))^2 + ((b - e) * 110570)^2)
diff <- data.frame(id = v1$id, name_v1 = v1$name, name = nm$name[m], moved_m = round(d_m(v1$lon, v1$lat, nm$lon[m], nm$lat[m]), 1),
                   rotate_v1 = v1$rot, rotate = nm$rotate_deg[m], z_v1 = v1$z, z = nm$z_rule[m], edited_v1 = v1$edited,
                   edited_at = nm$edited_at[m], zoom_edited_at = nm$zoom_edited_at[m], place_basis = nm$place_basis[m])
diff$what <- trimws(paste(ifelse(is.na(m), "gone", ""), ifelse(!is.na(m) & diff$name != diff$name_v1, "name", ""),
                          # v1's coordinates and its computed place were rounded apart by up to 1.1 m (5 decimals): 2 m is no move
                          ifelse(!is.na(m) & diff$moved_m > 2, "place", ""), ifelse(!is.na(m) & abs(diff$rotate - diff$rotate_v1) > 0.01, "angle", ""),
                          ifelse(!is.na(m) & abs(diff$z - diff$z_v1) > 1e-9, "zoom", "")))
diff <- diff[nzchar(diff$what), ]
late <- ed$at > max(v1$edited[nzchar(v1$edited)])                              # edits written after version 1's map
diff$why <- case_when(
  diff$what == "gone" & diff$id %in% rdg$feature[grepl("^piece_of", rdg$correction)] ~ "a piece read cut short, folded into its feature (overrides)",
  diff$what == "name" & diff$id %in% rdg$feature ~ "the reading corrected (overrides)",
  diff$what == "zoom" & !is.na(diff$zoom_edited_at) ~ "the maintainer's zoom edit",
  !is.na(diff$edited_at) & diff$edited_at != coalesce(na_if(diff$edited_v1, ""), "") ~ "the maintainer's edit made after version 1 was written",
  is.na(diff$edited_at) & nzchar(diff$edited_v1) & diff$id %in% ed$feature[late & ed$action == "revert"] ~ "the maintainer's revert made after version 1 was written",
  diff$place_basis == "lmi_position" & diff$what == "place" ~ "a submerged rock at LMÍ's position (2026-11-17)",
  # v1 drew a long name along its line (79) and slid it there where it fits sooner (81): the page's, the traffic jam; the
  # table keeps the computed place and carries the line in marine_name_extent
  is.na(diff$edited_at) & (diff$id %in% ex$feature[ex$what == "line"] | grepl("on its line|slid along its line", nm$place_note_v1[match(diff$id, nm$id)])) ~
    "a long name drawn along its line in version 1 (the page's): the computed place kept, its line in marine_name_extent",
  TRUE ~ NA_character_)
ok("every difference from version 1 explained", !is.na(diff$why), nrow(diff))
ok("version 1's names all here but the folded piece", sum(diff$what == "gone") == sum(grepl("^piece_of", rdg$correction)) &&
   nrow(nm) == nrow(v1) - sum(grepl("^piece_of", rdg$correction)), nrow(v1))

INPUTS <- c(REF("marine_name.parquet"), REF("marine_name_source.parquet"), REF("marine_name_record.parquet"),
            REF("marine_name_extent.parquet"), file.path(V1, "names.geojson"))
write_curated(acc, fd_curated("check", "marine_name_accounting.parquet"), script = "curate/checks/marine_name_accounting.R", inputs = INPUTS)
write_curated(diff, fd_curated("check", "marine_name_v1_diff.parquet"), script = "curate/checks/marine_name_accounting.R", inputs = INPUTS)
print(knitr::kable(acc))
print(knitr::kable(count(diff, what, why), caption = "differences from version 1"))
fails <- acc$check[acc$verdict != "ok"]
message(sprintf("marine_name_accounting: %d checks, %d failed; %d features differ from version 1", nrow(acc), length(fails), nrow(diff)))
if (length(fails)) stop("marine_name_accounting: ", paste(fails, collapse = "; "))
