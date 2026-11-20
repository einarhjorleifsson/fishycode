# aid_accounting.R — the aid list's bookkeeping: every record of every list in one outcome, counted (plan 082; the
# named-features study's 94_aids_check.R).
# Side: preprocessing (aids). Standalone, run by hand after reference/aids/aid.R, outside the targets flow (plan 082 ask p).
#
# Input:  raw/external/vegagerdin/{Vitaskra_i_gildi.pdf,vitar_2024_1.geojson,dufl_2024_1.geojson}, raw/external/osm_seamarks/,
#         raw/external/natt_lighthouses/, raw/external/wikidata_lighthouses/ (each list counted again from raw), the study's
#         frozen charts' witnesses (out/frozen/aids/) and curated/reference/chart_names.parquet,
#         curated/reference/{aid,aid_record,aid_pair,aid_description}.parquet (reference/aids/aid.R)
# Output: curated/check/aid_accounting.parquet - one row per check: the check, its verdict ("ok" or what failed), the count
#         curated/check/aid_conflict.parquet - every record of every aid in conflict, with the conflict's reasons, for the
#         maintainer (the conflicts are listed, not resolved)
#
# Bookkeeping, not an agreement rate (decision 155): the raw records of each list are counted from the raw files again (the
# List of Lights from the PDF itself: an aid is a line with a position), and every one must appear once in the record table,
# in exactly one outcome. The script stops, after writing, unless:
#   - each list's raw records = its rows in aid_record, no key twice; the outcomes and roles from their sets, the wave buoys
#     not aids;
#   - a witness has an aid, a not_an_aid none, a copy its original's (a witness), an attached chart label the aid of the
#     witness it attached to, an unattached label an aid of its own; the records' outcomes their aid's;
#   - each aid's records, lists and counts agree with aid_record; a conflict says why, no other aid does; several witnesses
#     means two lists or more; one_list_twice where an aid holds two witnesses of one list and only there;
#   - each attribute from its best witness (no record of an earlier list in the order holds a value the basis's list did not
#     win), the position its basis record's and the best of position;
#   - every text valid UTF-8; every description points to a record of its list, every record has one; joined pairs lie in
#     one aid and are witnesses of two lists.
library(sf)
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)                     # standalone: not targets'
R <- function(...) fd_raw("external", ...)
aid <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "aid.parquet")))
rec <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "aid_record.parquet")))
pr <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "aid_pair.parquet")))
desc <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "aid_description.parquet")))
acc <- data.frame(check = character(), verdict = character(), n = integer())
ok <- function(what, cond, n = NA_integer_) { cond <- isTRUE(all(cond))
  acc[nrow(acc) + 1, ] <<- list(what, if (cond) "ok" else "FAILED", as.integer(n)); message(if (cond) "ok " else "FAILED ", what) }

# Raw counts ----------------------------------------------------------------------------------------------------------------------
txt <- system2("pdftotext", c("-layout", shQuote(R("vegagerdin", "Vitaskra_i_gildi.pdf")), "-"), stdout = TRUE)
osm <- xml2::read_xml(gzfile(tail(sort(list.files(R("osm_seamarks"), "\\.osm\\.gz$", full.names = TRUE)), 1)))
wd <- read.csv(tail(sort(list.files(R("wikidata_lighthouses"), "\\.csv$", full.names = TRUE)), 1), encoding = "UTF-8", colClasses = "character")
FROZEN <- fd_path("archive", "2026-11-11-named-features", "out", "frozen", "aids")
cn <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "chart_names.parquet")))
al <- read.csv(file.path(FROZEN, "aid_letterings.csv"), encoding = "UTF-8", colClasses = "character")
raw <- c(vitaskra = sum(grepl("(?<!\\d)(6[3-7]) (\\d{2},\\d{1,2})\\s+([12]\\d) (\\d{2},\\d{1,2})(?!\\d)", txt, perl = TRUE)),
         vegagerdin = nrow(read_sf(R("vegagerdin", "vitar_2024_1.geojson"))), wave_buoy = nrow(read_sf(R("vegagerdin", "dufl_2024_1.geojson"))),
         osm = length(xml2::xml_find_all(osm, "/osm/node|/osm/way|/osm/relation")),
         is50v = nrow(read_sf(R("natt_lighthouses", "IS_50V__mannvirki_punktar_6510.geojson"))), wikidata = length(unique(wd$item)),
         chart = sum(cn$kind %in% "light" | cn$class %in% "light" | paste(cn$chart, cn$label_id) %in% paste(al$chart, al$label_id)) +
                 nrow(read_sf(file.path(FROZEN, "light_characteristics.gpkg"), "characteristic")))
got <- table(rec$list)[names(raw)]
ok(sprintf("every raw record once (%s)", paste(names(raw), raw, collapse = ", ")),
   !is.na(got) & got == raw & !anyDuplicated(rec$rid) & !anyDuplicated(paste(rec$list, rec$record_id)), sum(raw))
# Outcomes and roles --------------------------------------------------------------------------------------------------------------
ok("one outcome each, from the set", !is.na(rec$outcome) & rec$outcome %in% c("several_witnesses", "one_witness", "conflict", "copy", "not_an_aid"), nrow(rec))
ok("roles from the set, an outcome that fits the role", rec$role %in% c("witness", "label", "copy", "not_an_aid") &
   (rec$role == "not_an_aid") == (rec$outcome == "not_an_aid") & (rec$role == "copy") == (rec$outcome == "copy"))
ok("the wave buoys are not aids", rec$outcome[rec$list == "wave_buoy"] == "not_an_aid", sum(rec$list == "wave_buoy"))
w <- rec$role == "witness"; cp <- rec$role == "copy"; nw <- rec$role == "not_an_aid"; lb <- rec$role == "label"; ev <- w | lb
ok("a witness has an aid", !is.na(rec$aid[w]), sum(w))
ok("a not_an_aid has none", is.na(rec$aid[nw]), sum(nw))
orig <- match(rec$copy_of[cp], rec$rid)
ok("a copy sits with its original, a witness", !is.na(orig) & rec$role[orig] == "witness" & rec$aid[cp] == rec$aid[orig], sum(cp))
att <- lb & !is.na(rec$attach_rid); a0 <- match(rec$attach_rid[att], rec$rid)
ok("an attached chart label sits with the witness it attached to", !is.na(a0) & rec$role[a0] == "witness" & rec$aid[att] == rec$aid[a0] &
   rec$attach_by[att] %in% c("name", "characteristic"), sum(att))
lone <- lb & is.na(rec$attach_rid)
ok("an unattached chart label is an aid of its own", !is.na(rec$aid[lone]) & !rec$aid[lone] %in% rec$aid[!lone & !nw] & !anyDuplicated(rec$aid[lone]), sum(lone))
ok("the records' outcomes are their aid's", rec$outcome[ev] == aid$outcome[match(rec$aid[ev], aid$aid)])
# Aids ------------------------------------------------------------------------------------------------------------------------------
nrec <- table(rec$aid[ev]); lists_of <- function(p, keep) sort(unique(rec$list[keep & rec$aid %in% p]))
ok("each aid with its records", setequal(aid$aid, as.integer(names(nrec))) & aid$n_records == as.integer(nrec[as.character(aid$aid)]), nrow(aid))
ok("the witnesses and the counts of lists agree", aid$witnesses == vapply(aid$aid, function(p) paste(lists_of(p, ev), collapse = ","), character(1)) &
   aid$n_lists == vapply(aid$aid, function(p) length(lists_of(p, ev)), integer(1)) & aid$n_position_lists == vapply(aid$aid, function(p) length(lists_of(p, w)), integer(1)))
ok("a conflict says why, no other aid does", (aid$outcome == "conflict") == nzchar(ifelse(is.na(aid$why), "", aid$why)), sum(aid$outcome == "conflict"))
ok("several_witnesses means two lists or more, one_witness one", (aid$outcome != "several_witnesses" | aid$n_lists >= 2) & (aid$outcome != "one_witness" | aid$n_lists == 1))
ok("one_list_twice where an aid holds two witnesses of one list, and only there",
   grepl("one_list_twice", ifelse(is.na(aid$why), "", aid$why)) == vapply(aid$aid, function(p) anyDuplicated(rec$list[w & rec$aid %in% p]) > 0, logical(1)))
# Best witnesses --------------------------------------------------------------------------------------------------------------------
ORDER <- list(characteristic = c("vitaskra", "vegagerdin", "osm", "wikidata", "chart"), intl = c("vitaskra", "vegagerdin", "osm", "is50v", "wikidata"),
              height_m = c("vitaskra", "vegagerdin", "osm", "is50v", "wikidata"), name = c("vitaskra", "vegagerdin", "is50v", "osm", "wikidata", "chart"))
COL <- c(characteristic = "char_given", intl = "intl", height_m = "height_m", name = "name")
BASIS <- c(characteristic = "characteristic_basis", intl = "intl_basis", height_m = "height_basis", name = "name_basis")
for (a in names(ORDER)) ok(sprintf("the %s from its best witness", a), vapply(seq_len(nrow(aid)), function(k) {
  ix <- which(ev & rec$aid == aid$aid[k] & !is.na(rec[[COL[[a]]]]) & rec$list %in% ORDER[[a]]); b <- aid[[BASIS[[a]]]][k]
  if (!length(ix)) return(b == "none" & is.na(aid[[a]][k])); b == ORDER[[a]][min(match(rec$list[ix], ORDER[[a]]))] }, logical(1)))
rank <- function(l, p) ifelse(l == "vegagerdin", 1, ifelse(l == "vitaskra" & p == "1/100 minute", 2, ifelse(l == "is50v", 3, ifelse(l == "vitaskra", 4,
        ifelse(l == "osm", 5, ifelse(l == "wikidata", 6, 7))))))
ok("the position is its basis record's, the best of position", vapply(seq_len(nrow(aid)), function(k) { ix <- which(ev & rec$aid == aid$aid[k])
  b <- ix[rec$list[ix] == aid$position_basis[k]]
  any(abs(rec$lon[b] - aid$lon[k]) < 1e-9 & abs(rec$lat[b] - aid$lat[k]) < 1e-9) &&
    rank(aid$position_basis[k], aid$position_precision[k]) == min(rank(rec$list[ix], rec$precision[ix])) }, logical(1)))
# Text, descriptions, pairs ---------------------------------------------------------------------------------------------------------
chr_ok <- function(df) all(vapply(df, function(v) !is.character(v) || all(is.na(v) | validUTF8(v)), logical(1)))
ok("all text valid UTF-8", chr_ok(aid) & chr_ok(rec) & chr_ok(pr) & chr_ok(desc))
ok("every description points to a record of its list", desc$rid %in% rec$rid & desc$list == rec$list[match(desc$rid, rec$rid)], nrow(desc))
ok("every record has a description", rec$rid %in% desc$rid)
ok("joined pairs lie in one aid, witnesses of two lists", with(pr[pr$joined, ], aid_i == aid_j & list_i != list_j &
   rec$role[match(rid_i, rec$rid)] == "witness" & rec$role[match(rid_j, rec$rid)] == "witness"), sum(pr$joined))

# The conflicts, for the maintainer ---------------------------------------------------------------------------------------------------
cf <- rec[!is.na(rec$aid) & rec$aid %in% aid$aid[aid$outcome == "conflict"], ]
cf$why <- aid$why[match(cf$aid, aid$aid)]; cf <- cf[order(cf$aid, cf$list), ]
write_curated(acc, fd_curated("check", "aid_accounting.parquet"), script = "curate/checks/aid_accounting.R",
              inputs = c(fd_curated("reference", "aid.parquet"), fd_curated("reference", "aid_record.parquet")))
write_curated(cf, fd_curated("check", "aid_conflict.parquet"), script = "curate/checks/aid_accounting.R",
              inputs = c(fd_curated("reference", "aid.parquet"), fd_curated("reference", "aid_record.parquet")))
fails <- acc$check[acc$verdict != "ok"]
message(sprintf("aid_accounting: %d checks, %d failed; %d aids in conflict, %d records", nrow(acc), length(fails), length(unique(cf$aid)), nrow(cf)))
if (length(fails)) stop("aid_accounting: ", paste(fails, collapse = "; "))
