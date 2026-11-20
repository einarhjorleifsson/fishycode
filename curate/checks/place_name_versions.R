# place_name_versions.R — a version of the place names against the one before it, frozen: every row in one outcome (the
# same, changed, gone, new) and every change with its reason (plan 080 §4: "Measured against the version before: every row
# in one outcome, every difference explained").
# Side: preprocessing (sea-chart names). Standalone, run by hand after reference/marine_feature.R, outside the targets flow.
#
# Input:  curated/reference/marine_feature.parquet (the version now), marine_name.parquet and marine_name_pair.parquet (its
#         renames, pins, joins and the maintainer's edits since; the version before's marine_name.parquet beside it); curated/reference/place_names/v<N-1>/marine_feature.parquet (the version before, frozen by
#         reference/names/freeze_version.R)
# Output: curated/check/place_name_versions.parquet       - one row per check: the check, its verdict, n
#         curated/check/place_name_version_diff.parquet - one row per row of either version that is not the same: its id,
#                                                         outcome, what changed (version N-1 -> N) and why
#
# Compared: the name, where the name is drawn (version 1's `lon`, `lat` were the label's; since version 2 `label_lon`,
# `label_lat`), its angle and zoom, holder, on_feature, extent, kind, internal and the flags; where the thing is from
# version 2 on. Bookkeeping (decision 155): a change with no reason fails the check.
# Run from the repo root: Rscript curate/checks/place_name_versions.R. Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages(library(dplyr))
for (f in c("R/paths.R", "R/write_curated.R")) source(f)                     # standalone: not targets'
REF <- function(f) fd_curated("reference", f)
pq <- function(p) as.data.frame(nanoparquet::read_parquet(p))
now <- pq(REF("marine_feature.parquet")); nm <- pq(REF("marine_name.parquet")); pr <- pq(REF("marine_name_pair.parquet"))
N <- unique(now$version); stopifnot(length(N) == 1, N >= 2)
PREV <- fd_path("curated", "reference", "place_names", paste0("v", N - 1), "marine_feature.parquet")
stopifnot("the version before is not frozen" = file.exists(PREV))
old <- pq(PREV)
lab <- function(d) if ("label_lon" %in% names(d)) d[c("label_lon", "label_lat")] else setNames(d[c("lon", "lat")], c("label_lon", "label_lat"))
old[c("label_lon", "label_lat")] <- lab(old)

one <- pr[pr$outcome == "one thing", ]; one$gone <- paste0("name:", ifelse(one$kept == one$id_a, one$id_b, one$id_a))
one$kept_id <- paste0("name:", one$kept)
# his joins (ledger rows `join`, the latest of a row; `unjoin` undoes): the row that goes, joined into the row kept
ed <- read.csv("overrides/marine_name_edits.csv", encoding = "UTF-8"); if (!"link_to" %in% names(ed)) ed$link_to <- NA_character_
hj <- ed[ed$action %in% c("join", "unjoin"), ]; hj <- hj[order(hj$at), ]; hj <- hj[!duplicated(hj$feature, fromLast = TRUE) & hj$action == "join", ]
hj_gone <- paste0("name:", hj$feature); hj_kept <- paste0("name:", hj$link_to)
ren <- paste0("name:", nm$id[!is.na(nm$renamed_at)]); joined_into <- paste0("name:", nm$id[!is.na(nm$joined_from)])
pinned_pk <- paste0("name:", nm$id[!is.na(nm$pinned_at) & nm$point_kind])
# the maintainer's moves, turns and zooms on the page since the version before was written
pn <- pq(file.path(dirname(PREV), "marine_name.parquet")); mp <- match(nm$id, pn$id)
newer <- function(now_at, prev_at) !is.na(now_at) & (is.na(prev_at) | now_at != prev_at)
hand_label <- paste0("name:", nm$id[newer(nm$edited_at, pn$edited_at[mp])])
hand_zoom <- paste0("name:", nm$id[newer(nm$zoom_edited_at, pn$zoom_edited_at[mp])])
hand_back <- paste0("name:", nm$id[!is.na(pn$edited_at[mp]) & is.na(nm$edited_at)])   # moved by hand in the version before, placed back since
isor_axis <- paste0("name:", nm$id[nm$label_basis %in% "inside ÍSOR's area, along its axis"])
prop_axis <- paste0("name:", nm$id[grepl("^inside its accepted area|^on its accepted line", ifelse(is.na(nm$label_basis), "", nm$label_basis))])   # decision 338: an accepted name's letters
prop_zoom <- paste0("name:", nm$id[grepl("accepted area|accepted line", ifelse(is.na(nm$z_rule_basis), "", nm$z_rule_basis))])   # and its zoom, rule e on its area
crater_pk <- paste0("name:", nm$id[grepl("linked", nm$place_basis) & nm$point_kind & is.na(nm$edited_at)])
linked_area <- paste0("name:", nm$id[grepl("linked by the maintainer", nm$extent_basis)])   # an area he linked is its extent
proposed <- paste0("name:", nm$id[grepl("Claude's proposal, accepted by the maintainer", nm$extent_basis)])   # plan 081: an accepted proposal
held_on <- paste0("name:", nm$id[grepl("^its holder .* joined into ", ifelse(is.na(nm$holder_note), "", nm$holder_note))])   # a holder joined away
his_part <- paste0("name:", nm$id[grepl("^a part of it, by the maintainer", ifelse(is.na(nm$holder_note), "", nm$holder_note))])   # his `part of`
prop_part <- paste0("name:", nm$id[grepl("^a part of it, by Claude's proposal accepted", ifelse(is.na(nm$holder_note), "", nm$holder_note))])   # step 3's accepted part
# his latest verdict on a name's proposal a reject: the name back to its own source's place, area and letters (decision 341,
# Paradísarhola leaving ÍSOR's trough 11)
vd <- ed[ed$action %in% c("accept proposal", "reject proposal"), ]; vd <- vd[order(vd$at), ]; vd <- vd[!duplicated(vd$link_to, fromLast = TRUE), ]
prop_rej <- paste0("name:", sub("^deep:", "", vd$link_to[vd$action == "reject proposal" & grepl("^deep:[0-9]+$", vd$link_to)]))
REJ <- "the maintainer rejected Claude's proposal: back to its own source's (decision 341)"

d_m <- function(a, b, c, e) sqrt(((a - c) * 111320 * cos(b * pi / 180))^2 + ((b - e) * 110570)^2)
ne <- function(a, b) (is.na(a) != is.na(b)) | (!is.na(a) & !is.na(b) & a != b)
m <- match(old$id, now$id)
cmp <- data.frame(id = old$id, in_now = !is.na(m))
k <- m[cmp$in_now]; o <- old[cmp$in_now, ]; n <- now[k, ]
what <- data.frame(
  name = ne(o$name, n$name), label = d_m(o$label_lon, o$label_lat, n$label_lon, n$label_lat) > 2,
  angle = abs(o$rotate_deg - n$rotate_deg) > 0.01, zoom = abs(o$z_rule - n$z_rule) > 1e-9, holder = ne(o$holder, n$holder),
  on_feature = ne(o$on_feature, n$on_feature), extent = ne(round(o$extent_km, 6), round(n$extent_km, 6)), kind = ne(o$kind, n$kind),
  internal = ne(o$internal, n$internal), flags = ne(o$flags, n$flags))
why_of <- function(col, id) {
  switch(col,
    name = case_when(id %in% ren ~ "the maintainer's rename", id %in% joined_into ~ "one thing from two sources: the name by ask g's order"),
    label = case_when(id %in% prop_axis ~ "Claude's proposal accepted: the letters inside its area or on its line, along it (decision 338)",
                      id %in% prop_rej ~ REJ,
                      id %in% hand_label ~ "the maintainer's move on the page", id %in% pinned_pk ~ "the maintainer's pin: a point kind's label follows its thing",
                      id %in% isor_axis ~ "ÍSOR's area the primary source: the label inside it along its axis", id %in% hand_back ~ "the maintainer's place back on the page",
                      id %in% crater_pk ~ "linked to ÍSOR's crater: a point kind's label follows its thing"),
    angle = case_when(id %in% prop_axis ~ "Claude's proposal accepted: the letters along its area's long axis or its line (decision 338)",
                      id %in% prop_rej ~ REJ,
                      id %in% hand_label ~ "the maintainer's turn on the page", id %in% isor_axis ~ "ÍSOR's area the primary source: the label along its axis",
                      id %in% hand_back ~ "the maintainer's place back on the page"),
    zoom = case_when(id %in% hand_zoom ~ "the maintainer's zoom on the page",
                     id %in% prop_zoom ~ "Claude's proposal accepted: rule e on its area's or line's length along its axis (decision 338)",
                     id %in% prop_rej ~ REJ),
    holder = case_when(id %in% held_on ~ "its holder joined into the row kept (one thing from two sources, or the maintainer's join; decision 338)",
                       id %in% his_part ~ "the maintainer's part of: its whole his",
                       id %in% prop_part ~ "Claude's proposal accepted: its bank its whole (plan 081 step 3)"),
    on_feature = case_when(old$on_feature[match(id, old$id)] %in% one$gone ~ "the feature it lay on joined into another (one thing from two sources)",
                           old$on_feature[match(id, old$id)] %in% hj_gone & now$on_feature[match(id, now$id)] %in% hj_kept ~
                             "the feature it lay on joined by the maintainer into another (his join)",
                           now$on_feature[match(id, now$id)] %in% paste0("name:", nm$id[nm$brought_in]) ~ "it lies in the area of a name brought in (version 2)",
                           old$on_feature[match(id, old$id)] %in% linked_area | now$on_feature[match(id, now$id)] %in% linked_area ~
                             "the area it lay or lies in is now ÍSOR's, linked by the maintainer",
                           old$on_feature[match(id, old$id)] %in% proposed | now$on_feature[match(id, now$id)] %in% proposed ~
                             "the area it lay or lies in is now Claude's proposal's, accepted by the maintainer"),
    extent = case_when(id %in% joined_into ~ "one thing from two sources: its extent from the row joined into it",
                       id %in% linked_area ~ "linked by the maintainer to ÍSOR's area: its extent ÍSOR's, LMÍ's set aside",
                       id %in% proposed ~ "Claude's proposal, accepted by the maintainer: its extent the proposal's (plan 081)",
                       id %in% prop_rej ~ REJ),
    flags = ifelse(grepl("version 2[),]", now$flags[match(id, now$id)]), "a flag of version 2's (one thing, whole and part, doubtful)",
            ifelse(grepl("in ÍSOR's report of 2008", now$flags[match(id, now$id)]), "spelt otherwise in ÍSOR's reports of 2008 (decision 338)", NA)),
    NA_character_)
}
rows <- list()
for (col in names(what)) { j <- which(what[[col]]); if (!length(j)) next
  ids <- o$id[j]
  rows[[col]] <- data.frame(id = ids, outcome = "changed", what = col,
                            before = as.character(if (col == "label") sprintf("%.6f %.6f", o$label_lon[j], o$label_lat[j]) else o[[switch(col, angle = "rotate_deg", zoom = "z_rule", extent = "extent_km", col)]][j]),
                            after = as.character(if (col == "label") sprintf("%.6f %.6f", n$label_lon[j], n$label_lat[j]) else n[[switch(col, angle = "rotate_deg", zoom = "z_rule", extent = "extent_km", col)]][j]),
                            why = why_of(col, ids)) }
gone <- old$id[!cmp$in_now]
rows$gone <- data.frame(id = gone, outcome = rep("gone", length(gone)), what = rep("row", length(gone)), before = old$name[match(gone, old$id)],
                        after = as.character(ifelse(gone %in% hj_gone, hj_kept[match(gone, hj_gone)], one$kept_id[match(gone, one$gone)])),
                        why = as.character(ifelse(gone %in% hj_gone, "joined by the maintainer into the row kept, its synonym",
                                     ifelse(gone %in% one$gone, "joined into the row kept: one thing from two sources", NA))))
new <- setdiff(now$id, old$id)
rows$new <- data.frame(id = new, outcome = rep("new", length(new)), what = rep("row", length(new)),
                       before = rep(NA_character_, length(new)), after = now$name[match(new, now$id)],
                       why = case_when(new %in% paste0("name:", nm$id[nm$brought_in]) ~ "brought in (a record version 1 left out: by the maintainer, or an open region's rule)",
                                       new %in% paste0("name:", nm$id[nm$src == "maintainer"]) ~ "a name of the maintainer's own",
                                       new %in% paste0("name:", nm$id[nm$src == "trackwell"]) ~ "Trackwell's candidate, accepted by the maintainer"))
diff <- bind_rows(rows)

acc <- data.frame(check = character(), verdict = character(), n = integer())
ok <- function(what, cond, n = NA_integer_) { cond <- isTRUE(all(cond))
  acc[nrow(acc) + 1, ] <<- list(what, if (cond) "ok" else "FAILED", as.integer(n)) }
same <- sum(cmp$in_now) - length(unique(diff$id[diff$outcome == "changed"]))
ok(sprintf("every row of version %d in one outcome: the same %d, changed %d, gone %d; new in version %d: %d", N - 1, same,
           length(unique(diff$id[diff$outcome == "changed"])), length(gone), N, length(new)),
   same + length(unique(diff$id[diff$outcome == "changed"])) + length(gone) == nrow(old), nrow(old))
ok("every change, every row gone and every row new with its reason", !is.na(diff$why), nrow(diff))
ok(sprintf("where the thing is given on every row of version %d", N), !is.na(now$lon) & !is.na(now$lat) & !is.na(now$place_basis), nrow(now))

INPUTS <- c(REF("marine_feature.parquet"), REF("marine_name.parquet"), REF("marine_name_pair.parquet"), PREV)
S <- "curate/checks/place_name_versions.R"
write_curated(acc, fd_curated("check", "place_name_versions.parquet"), inputs = INPUTS, script = S)
write_curated(diff, fd_curated("check", "place_name_version_diff.parquet"), inputs = INPUTS, script = S)
print(knitr::kable(acc))
print(knitr::kable(count(diff, outcome, what, why), caption = sprintf("version %d against version %d", N, N - 1)))
fails <- acc$check[acc$verdict != "ok"]
message(sprintf("place_name_versions: %d checks, %d failed", nrow(acc), length(fails)))
if (length(fails)) stop("place_name_versions: ", paste(fails, collapse = "; "))
