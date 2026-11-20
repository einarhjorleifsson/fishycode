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
#     rock at LMÍ's position, or an edit of the maintainer's (made after version 1 was written, or reverted after it);
#     since version 2 (plan 080 §5.2) also his renames, a row joined into another (one thing from two sources), and the
#     name such a row takes by ask g's order; version 1's place is compared with the label's (`label_lon`, `label_lat`);
#   - version 2's own: every latest rename laid on, the source's spelling kept; every thing and label placed with a basis;
#     every pair of one name from two sources within 10 km once, in one outcome; a joined row gone, its records with the
#     row kept; a doubtful pair flagged on both rows, a whole and part on both.
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
# his joins, the latest row of each feature (`join`; `unjoin` undoes): the ids of the rows that go
hj <- ed[ed$action %in% c("join", "unjoin"), ]; hj <- hj[order(hj$at), ]; hj_gone <- hj$feature[!duplicated(hj$feature, fromLast = TRUE) & hj$action == "join"]
pr  <- as.data.frame(nanoparquet::read_parquet(REF("marine_name_pair.parquet")))
pr$gone <- ifelse(pr$outcome == "one thing", ifelse(pr$kept == pr$id_a, pr$id_b, pr$id_a), NA)

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
IN <- c("a lettering of a feature in the list", "shown from a zoom", "already the chart's feature (one name)", "one name with the map's",
        "brought in by the maintainer", "brought in by the region's rule (ask m)", "accepted by the maintainer", "a name of the maintainer's own")
inl <- rec$outcome %in% IN
ok("a record in the list points to a feature of the list", rec$feature[inl] %in% nm$id, sum(inl))
ok("a record left out points to none", is.na(rec$feature[!inl]), sum(!inl))

# Every feature traced and complete ------------------------------------------------------------------------------------------
ok("ids unique", !anyDuplicated(nm$id), nrow(nm))
ok("every feature has a place, a basis, an angle and a zoom",
   !is.na(nm$lon) & !is.na(nm$lat) & !is.na(nm$place_basis) & !is.na(nm$rotate_deg) & !is.na(nm$z_rule), nrow(nm))
ok("every feature's label placed, with a basis; a point kind's label at its thing unless moved by hand",
   !is.na(nm$label_lon) & !is.na(nm$label_lat) & !is.na(nm$label_basis) & !is.na(nm$point_kind) &
     (!nm$point_kind | !is.na(nm$edited_at) | (abs(nm$label_lon - nm$lon) < 1e-9 & abs(nm$label_lat - nm$lat) < 1e-9)), nrow(nm))
ok("one version in the list", length(unique(nm$version)) == 1, nrow(nm))

# Version 2: the renames, one thing from two sources ------------------------------------------------------------------------
rn <- ed[ed$action == "rename", ]; rn <- rn[order(rn$at), ]; rn <- rn[!duplicated(rn$feature, fromLast = TRUE), ]
k <- match(rn$feature, nm$id)
ok("every latest rename laid on: the name his, the source's spelling kept among the synonyms",
   !anyNA(k) & nm$name[k] == rn$new_name & !is.na(nm$renamed_at[k]) &
     vapply(seq_along(k), function(i) nm$name_source[k[i]] %in% trimws(strsplit(nm$synonyms[k[i]], ";")[[1]]), logical(1)), nrow(rn))
ok("no other row renamed", sum(!is.na(nm$renamed_at)) == nrow(rn), sum(!is.na(nm$renamed_at)))
sy <- ed[ed$action == "synonym", ]; ks <- match(sy$feature, nm$id)
ok("every synonym of the maintainer's among the feature's synonyms",
   !anyNA(ks) & vapply(seq_along(ks), function(i) !is.na(ks[i]) && sy$new_name[i] %in% trimws(strsplit(coalesce(nm$synonyms[ks[i]], ""), ";")[[1]]), logical(1)),
   nrow(sy))
pn <- ed[ed$action %in% c("pin", "unpin"), ]; pn <- pn[order(pn$at), ]; pn <- pn[!duplicated(pn$feature, fromLast = TRUE), ]
pp <- pn[pn$action == "pin", ]; kp <- match(pp$feature, nm$id)
ok("every latest pin laid on: the thing where he put it, by his hand; no other row pinned",
   !anyNA(kp) & abs(nm$lon[kp] - pp$lon) < 1e-9 & abs(nm$lat[kp] - pp$lat) < 1e-9 & nm$pinned_at[kp] == pp$at &
     sum(!is.na(nm$pinned_at)) == nrow(pp), nrow(pp))
ok("every pair once, in one outcome", !anyDuplicated(pr[c("id_a", "id_b")]) &
   pr$outcome %in% c("one thing", "whole and part", "doubtful", "namesakes") & pr$km <= 10, nrow(pr))
one <- pr[pr$outcome == "one thing", ]
ok("a row joined is gone, its row kept in the list, its records with it",
   !one$gone %in% nm$id & one$kept %in% nm$id & !rec$feature[!is.na(rec$feature)] %in% one$gone &
     !src$id %in% one$gone & !ex$feature %in% one$gone, nrow(one))
ok("the row kept says what was joined into it", vapply(seq_len(nrow(one)), function(i)
   as.character(one$gone[i]) %in% strsplit(nm$joined_from[match(one$kept[i], nm$id)], " ")[[1]], logical(1)), nrow(one))
fl_has <- function(id, pat) grepl(pat, nm$flags[match(id, nm$id)], fixed = TRUE)
dbt <- pr[pr$outcome == "doubtful", ]
ok("a doubtful pair flagged on both rows", fl_has(dbt$id_a, "doubtful: one name with") & fl_has(dbt$id_b, "doubtful: one name with"), nrow(dbt))
wp <- pr[pr$outcome == "whole and part", ]
ok("a whole and part flagged on both rows", fl_has(wp$id_a, "namesake") & fl_has(wp$id_b, "namesake"), nrow(wp))
sfx <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "seabed_feature.parquet")))
ok("every link to ÍSOR's features to one that exists, with its basis", is.na(nm$seabed_id) | (nm$seabed_id %in% sfx$seabed_id & !is.na(nm$seabed_link)),
   sum(!is.na(nm$seabed_id)))
hl <- ed[ed$action %in% c("link", "unlink"), ]; hl <- hl[order(hl$at), ]; hl <- hl[!duplicated(hl$feature, fromLast = TRUE), ]
kl <- match(hl$feature, nm$id)
ok("every latest link or unlink of the maintainer's laid on",
   !anyNA(kl) & ifelse(hl$action == "link", nm$seabed_id[kl] %in% hl$link_to & grepl("^by the maintainer", nm$seabed_link[kl]),
                       is.na(nm$seabed_id[kl])), nrow(hl))
ok("every chart feature has a lettering", nm$id[nm$src == "chart"] %in% src$id[src$source == "chart"], sum(nm$src == "chart"))
ok("every LMÍ feature has an LMÍ record", nm$id[nm$src == "lmi"] %in% src$id[src$source == "lmi"], sum(nm$src == "lmi"))
ok("every Trackwell name accepted by the maintainer, its candidate's record pointing to it",
   nm$id[nm$src == "trackwell"] %in% src$id[src$source == "trackwell"] &
     nm$id[nm$src == "trackwell"] %in% rec$feature[rec$source == "trackwell" & rec$outcome == "accepted by the maintainer"], sum(nm$src == "trackwell"))
ok("every ÍSOR feature has an ÍSOR record", nm$id[nm$src == "isor"] %in% src$id[src$source == "isor"], sum(nm$src == "isor"))
ok("every link to a feature of the list and to a record that exists",
   src$id %in% nm$id & paste(src$source, src$source_id) %in% paste(rec$source, rec$source_id), nrow(src))
hold <- nm$holder[!is.na(nm$holder)]
ok("a holder is a feature of the list", hold %in% nm$id, length(hold))
ok("the duplicates flagged both ways (overrides)", nm$possible_duplicate[match(dup$feature_a, nm$id)] == dup$feature_b &
   nm$possible_duplicate[match(dup$feature_b, nm$id)] == dup$feature_a & sum(!is.na(nm$possible_duplicate)) == 2 * nrow(dup), nrow(dup))
ok("the extents' features are in the list", ex$feature %in% nm$id, nrow(ex))
isor_f <- unique(ex$feature[ex$what == "extent" & ex$basis == "ÍSOR's"])
ok("no row uses an LMÍ area where it has ÍSOR's; every area set aside says why",
   !any(ex$used & ex$what == "extent" & grepl("^LMÍ's", ex$basis) & ex$feature %in% isor_f) & !anyNA(ex$set_aside[!ex$used]), nrow(ex))
ok("every text valid UTF-8", all(validUTF8(c(nm$name, nm$synonyms, nm$lmi_source, rec$name, src$role))), nrow(nm))

# Every difference from version 1, explained ----------------------------------------------------------------------------------
g <- jsonlite::fromJSON(file.path(V1, "names.geojson"), simplifyVector = TRUE)$features
v1 <- data.frame(id = as.integer(g$properties$feature), name = g$properties$name, rot = g$properties$rot, z = g$properties$z_rule,
                 edited = g$properties$edited, do.call(rbind, g$geometry$coordinates))
names(v1)[6:7] <- c("lon", "lat")
m <- match(v1$id, nm$id)
d_m <- function(a, b, c, e) sqrt(((a - c) * 111320 * cos(b * pi / 180))^2 + ((b - e) * 110570)^2)
# version 1's place is where its name was drawn: the label's since version 2
diff <- data.frame(id = v1$id, name_v1 = v1$name, name = nm$name[m], moved_m = round(d_m(v1$lon, v1$lat, nm$label_lon[m], nm$label_lat[m]), 1),
                   rotate_v1 = v1$rot, rotate = nm$rotate_deg[m], z_v1 = v1$z, z = nm$z_rule[m], edited_v1 = v1$edited,
                   edited_at = nm$edited_at[m], zoom_edited_at = nm$zoom_edited_at[m], place_basis = nm$label_basis[m],
                   renamed_at = nm$renamed_at[m], joined_from = nm$joined_from[m])
diff$what <- trimws(paste(ifelse(is.na(m), "gone", ""), ifelse(!is.na(m) & diff$name != diff$name_v1, "name", ""),
                          # v1's coordinates and its computed place were rounded apart by up to 1.1 m (5 decimals): 2 m is no move
                          ifelse(!is.na(m) & diff$moved_m > 2, "place", ""), ifelse(!is.na(m) & abs(diff$rotate - diff$rotate_v1) > 0.01, "angle", ""),
                          ifelse(!is.na(m) & abs(diff$z - diff$z_v1) > 1e-9, "zoom", "")))
diff <- diff[nzchar(diff$what), ]
late <- ed$at > max(v1$edited[nzchar(v1$edited)])                              # edits written after version 1's map
diff$why <- case_when(
  diff$what == "gone" & diff$id %in% rdg$feature[grepl("^piece_of", rdg$correction)] ~ "a piece read cut short, folded into its feature (overrides)",
  diff$what == "gone" & diff$id %in% one$gone ~ "joined into another row: one thing from two sources (version 2)",
  diff$what == "gone" & diff$id %in% hj_gone ~ "joined by the maintainer into another row, its synonym",
  diff$what == "name" & !is.na(diff$renamed_at) ~ "the maintainer's rename (version 2)",
  diff$what == "name" & !is.na(diff$joined_from) ~ "one thing from two sources: the name by ask g's order (version 2)",
  grepl("place", diff$what) & grepl("linked", nm$place_basis[match(diff$id, nm$id)]) & nm$point_kind[match(diff$id, nm$id)] &
    is.na(nm$edited_at[match(diff$id, nm$id)]) ~ "linked to ÍSOR's crater: a point kind's label follows its thing (version 2)",
  grepl("place", diff$what) & !is.na(nm$pinned_at[match(diff$id, nm$id)]) & nm$point_kind[match(diff$id, nm$id)] ~
    "the maintainer's pin: a point kind's label follows its thing (version 2)",
  grepl("place|angle|zoom", diff$what) & !grepl("name|gone", diff$what) &
    (grepl("^inside its accepted area", coalesce(nm$label_basis[match(diff$id, nm$id)], "")) |
     grepl("accepted area", coalesce(nm$z_rule_basis[match(diff$id, nm$id)], ""))) ~
    "Claude's proposal accepted: the letters inside its area along its long axis, the zoom by rule e on it (decision 338)",
  diff$what == "name" & diff$id %in% rdg$feature ~ "the reading corrected (overrides)",
  diff$what == "zoom" & !is.na(diff$zoom_edited_at) ~ "the maintainer's zoom edit",
  !is.na(diff$edited_at) & diff$edited_at != coalesce(na_if(diff$edited_v1, ""), "") ~ "the maintainer's edit made after version 1 was written",
  is.na(diff$edited_at) & nzchar(diff$edited_v1) & diff$id %in% ed$feature[late & ed$action == "revert"] ~ "the maintainer's revert made after version 1 was written",
  diff$place_basis == "lmi_position" & diff$what == "place" ~ "a submerged rock at LMÍ's position (2026-11-17)",
  # an edit saved under the study's number of a feature and a later one under another were two streams in version 1, which
  # kept the earlier move; since version 2 each feature's latest edit counts
  is.na(diff$edited_at) & nzchar(coalesce(diff$edited_v1, "")) & vapply(seq_len(nrow(diff)), function(i)
    any(ed$action == "revert" & ed$name == diff$name_v1[i] & ed$at > coalesce(diff$edited_v1[i], "")), logical(1)) ~
    "the maintainer's place back, which version 1 missed (an earlier move under another number of the feature)",
  # v1 drew a long name along its line (79) and slid it there where it fits sooner (81): the page's, the traffic jam; the
  # table keeps the computed place and carries the line in marine_name_extent
  is.na(diff$edited_at) & (diff$id %in% ex$feature[ex$what == "line"] | grepl("on its line|slid along its line", nm$place_note_v1[match(diff$id, nm$id)])) ~
    "a long name drawn along its line in version 1 (the page's): the computed place kept, its line in marine_name_extent",
  TRUE ~ NA_character_)
ok("every difference from version 1 explained", !is.na(diff$why), nrow(diff))
inc <- if (file.exists("overrides/marine_name_include.csv")) read.csv("overrides/marine_name_include.csv", encoding = "UTF-8") else data.frame(source_id = character())
ok("every record brought in by the maintainer a feature of the list, its record pointing to it",
   all(rec$feature[match(paste("lmi", inc$source_id), paste(rec$source, rec$source_id))] %in% nm$id[nm$brought_in]), nrow(inc))
rmv <- ed[ed$action %in% c("remove", "restore"), ]; rmv <- rmv[order(rmv$at), ]; rmv <- rmv[!duplicated(rmv$feature, fromLast = TRUE) & rmv$action == "remove", ]
ok("every latest removal laid on: the name out, its record \"removed by the maintainer\"", !rmv$feature %in% nm$id &
   sum(rec$outcome == "removed by the maintainer") >= nrow(rmv), nrow(rmv))
nw <- ed[ed$action == "new", ]
ok("every name of the maintainer's own in the list, with its record", sum(nm$src == "maintainer") == nrow(nw) &
   nm$id[nm$src == "maintainer"] %in% rec$feature[rec$outcome == "a name of the maintainer's own"], nrow(nw))
bi <- rec$outcome %in% c("brought in by the maintainer", "brought in by the region's rule (ask m)")
ok("every feature brought in has its record, and every record brought in its feature",
   setequal(rec$feature[bi], nm$id[nm$brought_in]) & sum(bi) == sum(nm$brought_in), sum(nm$brought_in))
rg <- read_curated_sf(fd_curated("reference", "place_name_region.parquet")); rg <- rg[rg$open, ]
ok("every copy brought in by a region's rule placed, with a basis", !is.na(nm$place_basis[nm$brought_in]) & !is.na(nm$lon[nm$brought_in]),
   sum(nm$brought_in))
osr <- grepl("V201404005", ifelse(is.na(nm$lmi_source), "", nm$lmi_source))   # Orkustofnun's 2014 delivery to LMÍ (decision 338)
ok(sprintf("every row of Orkustofnun's 2014 delivery to LMÍ in one outcome: its entry in ÍSOR's reports of 2008 (%d, %d coined), or none (%d); no other row takes one",
           sum(osr & !is.na(nm$report)), sum(osr & nm$coined %in% TRUE), sum(osr & is.na(nm$report))),
   !any(!is.na(nm$report) & !osr) && all(is.na(nm$report) == is.na(nm$coined)) && all(is.na(nm$report) == is.na(nm$report_entry)), sum(osr))
ok("version 1's names all here but the folded piece and the rows joined in version 2 (by rule or by him), with those brought in",
   sum(diff$what == "gone") == sum(grepl("^piece_of", rdg$correction)) + nrow(one) + length(hj_gone) &&
   nrow(nm) == nrow(v1) - sum(grepl("^piece_of", rdg$correction)) - nrow(one) - length(hj_gone) + sum(nm$brought_in) + sum(nm$src %in% c("trackwell", "maintainer")), nrow(v1))

INPUTS <- c(REF("marine_name.parquet"), REF("marine_name_source.parquet"), REF("marine_name_record.parquet"),
            REF("marine_name_extent.parquet"), REF("marine_name_pair.parquet"), file.path(V1, "names.geojson"))
write_curated(acc, fd_curated("check", "marine_name_accounting.parquet"), script = "curate/checks/marine_name_accounting.R", inputs = INPUTS)
write_curated(diff, fd_curated("check", "marine_name_v1_diff.parquet"), script = "curate/checks/marine_name_accounting.R", inputs = INPUTS)
print(knitr::kable(acc))
print(knitr::kable(count(diff, what, why), caption = "differences from version 1"))
fails <- acc$check[acc$verdict != "ok"]
message(sprintf("marine_name_accounting: %d checks, %d failed; %d features differ from version 1", nrow(acc), length(fails), nrow(diff)))
if (length(fails)) stop("marine_name_accounting: ", paste(fails, collapse = "; "))
