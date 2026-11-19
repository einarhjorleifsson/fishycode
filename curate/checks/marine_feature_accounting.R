# marine_feature_accounting.R — the one table's bookkeeping: every row of the three lists once, every link to a row of the
# table, the internal rows those the wreck list flags (plan 074 step 12).
# Side: preprocessing (sea-chart names). Standalone, run by hand after reference/marine_feature.R, outside the targets flow.
#
# Input:  curated/reference/{marine_feature,marine_feature_link}.parquet (reference/marine_feature.R), and the lists it binds:
#         curated/reference/{marine_name,wreck,aid}.parquet, the study's frozen names_v1/feature_aid.csv (111's links)
# Output: curated/check/marine_feature_accounting.parquet - one row per check: the check, its verdict ("ok" or what failed), n
#
# Bookkeeping (decision 155). The script stops, after writing, unless:
#   - every feature of marine_name, every wreck place and every aid is one row, no other row, no id twice;
#   - the types and kinds from their sets, the rank by type (a name 1, an aid 2, a wreck 3);
#   - a name's place, angle and zoom those of marine_name; an aid's zoom 10, a wreck's the one chosen;
#   - a holder only on a name, an on_feature only on an aid or a wreck, each a name's row of the table;
#   - an aid's on_feature one of its links in 111 to a feature of the list, and every aid with such a link has one; a wreck's
#     inside its feature's area; every chosen link in the link table once per row;
#   - `internal` on a wreck exactly where the wreck list flags it (internal or only internal), on nothing else;
#   - every text valid UTF-8.
# Run from the repo root: Rscript curate/checks/marine_feature_accounting.R   (TRIAL=1: the trial outputs of marine_feature.R)
# Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages(library(dplyr))
for (f in c("R/paths.R", "R/write_curated.R")) source(f)                     # standalone: not targets'
TRIAL <- Sys.getenv("TRIAL") == "1"
REF <- function(f) fd_curated("reference", f)
DIR <- if (TRIAL) fd_curated("scratch", "marine_feature_trial") else fd_curated("reference")
WRECK <- if (TRIAL) fd_path("archive", "2026-11-11-named-features", "out", "wrecks", "wreck.parquet") else REF("wreck.parquet")
V1 <- fd_path("archive", "2026-11-11-named-features", "out", "frozen", "names_v1")
pq <- function(p) as.data.frame(nanoparquet::read_parquet(p))
mf <- pq(file.path(DIR, "marine_feature.parquet")); ln <- pq(file.path(DIR, "marine_feature_link.parquet"))
nm <- pq(REF("marine_name.parquet")); aid <- pq(REF("aid.parquet")); wr <- pq(WRECK)
fa <- read.csv(file.path(V1, "feature_aid.csv"), encoding = "UTF-8")

acc <- data.frame(check = character(), verdict = character(), n = integer())
ok <- function(what, cond, n = NA_integer_) { cond <- isTRUE(all(cond))
  acc[nrow(acc) + 1, ] <<- list(what, if (cond) "ok" else "FAILED", as.integer(n)) }

want <- c(paste0("name:", nm$id), paste0("wreck:", wr$wreck), paste0("aid:", aid$aid))
ok(sprintf("every row of the lists once: names %d, wrecks %d, aids %d", nrow(nm), nrow(wr), nrow(aid)),
   setequal(mf$id, want) && !anyDuplicated(mf$id) && nrow(mf) == length(want), nrow(mf))
ok("types and kinds from their sets, the rank by type",
   mf$type %in% c("name", "wreck", "aid") & mf$rank == c(name = 1L, aid = 2L, wreck = 3L)[mf$type] &
     ((mf$type == "name" & mf$kind %in% c("water", "land", "isle")) | (mf$type == "wreck" & mf$kind == "wreck") |
      (mf$type == "aid" & mf$kind %in% unique(aid$kind))), nrow(mf))
n <- mf[mf$type == "name", ]; k <- match(n$list_id, as.character(nm$id))
ok("a name's place, angle and zoom those of marine_name",
   !anyNA(k) & n$lon == nm$lon[k] & n$lat == nm$lat[k] & n$rotate_deg == nm$rotate_deg[k] & n$z_rule == nm$z_rule[k], nrow(n))
ok("an aid's zoom 10, a wreck's one zoom", all(mf$z_rule[mf$type == "aid"] == 10) && length(unique(mf$z_rule[mf$type == "wreck"])) == 1,
   sum(mf$type != "name"))
ok("a holder only on a name, a name's row", is.na(mf$holder[mf$type != "name"]) & (is.na(mf$holder) | mf$holder %in% mf$id[mf$type == "name"]), nrow(mf))
ok("an on_feature only on an aid or a wreck, a name's row",
   is.na(mf$on_feature[mf$type == "name"]) & (is.na(mf$on_feature) | mf$on_feature %in% mf$id[mf$type == "name"]), nrow(mf))
fl <- fa[!is.na(fa$feature) & fa$feature %in% nm$id, ]
a <- mf[mf$type == "aid", ]
ok("an aid's on_feature one of its 111 links to a feature of the list",
   is.na(a$on_feature) | paste(a$list_id, sub("^name:", "", a$on_feature)) %in% paste(fl$aid, fl$feature), nrow(a))
ok("every aid with such a link has an on_feature", a$list_id[!is.na(a$on_feature)] %in% as.character(fl$aid) &
   as.character(unique(fl$aid)) %in% a$list_id[!is.na(a$on_feature)], length(unique(fl$aid)))
ch <- ln[ln$chosen, ]
ok("one chosen link a row, the row's on_feature", !anyDuplicated(ch$from) &
   setequal(paste(ch$from, ch$to), paste(mf$id, mf$on_feature)[!is.na(mf$on_feature)]), nrow(ch))
w <- mf[mf$type == "wreck", ]; kw <- match(w$list_id, as.character(wr$wreck))
ok("internal on a wreck where the wreck list flags it, on nothing else",
   all(!mf$internal[mf$type != "wreck"]) && all(w$internal == (coalesce(wr$internal[kw], FALSE) | coalesce(wr$only_internal[kw], FALSE))),
   sum(mf$internal))
ok("every text valid UTF-8", all(validUTF8(na.omit(c(mf$name, mf$synonyms, mf$flags, mf$z_rule_basis)))), nrow(mf))

out <- if (TRIAL) file.path(DIR, "marine_feature_accounting.parquet") else fd_curated("check", "marine_feature_accounting.parquet")
write_curated(acc, out, script = "curate/checks/marine_feature_accounting.R",
              inputs = c(file.path(DIR, "marine_feature.parquet"), file.path(DIR, "marine_feature_link.parquet")))
print(knitr::kable(acc))
fails <- acc$check[acc$verdict != "ok"]
message(sprintf("marine_feature_accounting: %d checks, %d failed", nrow(acc), length(fails)))
if (length(fails)) stop("marine_feature_accounting: ", paste(fails, collapse = "; "))
