# wreck_accounting.R — the wreck list's bookkeeping: every record of every list in one outcome, counted (plan 082; plan 074 step
# 12; the named-features study's 92_wrecks_check.R).
# Side: preprocessing (wrecks). Standalone, run by hand after reference/wrecks/wreck.R, outside the targets flow (plan 082 ask p).
#
# Input:  raw/external/isor/vindorka_a_hafi_Infrastructure__*.geojson, raw/external/wreck_hi/unzipped/thekkt_skipsflok.shp,
#         raw/external/emodnet_human_activities/wwshipwrecks.geojson, raw/external/osm_wrecks/, the plotter's exports in
#         raw/external/ornefni/fra_gudmundi-a-bjarna/GS_nofn-og-flok_2022-10-18/ and
#         raw/external/vernd_i_hafi/kortlagning/grunnthekjur/nofn-flok/ (each list counted again from raw);
#         curated/reference/{wreck,wreck_record,wreck_pair,wreck_description}.parquet and
#         curated/check/{wreck_depth_read,wreck_date_read}.parquet (reference/wrecks/wreck.R); where it is, the named-features
#         study's out/wrecks/hi_depth_unit.csv (its 99_hi_depth_unit.R: HI's depths against the depth model)
# Output: curated/check/wreck_accounting.parquet - one row per check: the check, its verdict ("ok" or "FAILED"), the count
#         curated/check/wreck_conflict.parquet - every record of every wreck in conflict, with the conflict's reasons, for the
#         maintainer (the conflicts are listed, not resolved)
#
# Bookkeeping, not an agreement rate (decision 155): the raw records of each list are counted from the raw files again, and
# every one must appear once in the record table, in exactly one outcome. The script stops, after writing, unless:
#   - each list's raw records = its rows in wreck_record, no key twice; one outcome each, from the set;
#   - a witness has a wreck, a not_a_wreck none, a copy its original's (a witness); the witnesses' outcomes their wreck's;
#   - each wreck's records and witnesses agree with wreck_record; several witnesses means two lists or more, one witness
#     one; a conflict says why, no other wreck does; wreck_conflict holds every record of every wreck in conflict;
#   - every text valid UTF-8; every description points to a record of its list; joined pairs lie in one wreck;
#   - ask o's flag, maybe one wreck: exactly the mutual pairs not joined, in two wrecks, within 1 km or the two records'
#     digits; the wreck table's maybe_same_as names every flagged wreck on both sides, its distance the nearest;
#   - the internal lists (HI's, the plotter's) marked internal wherever they give an attribute or a description;
#   - the plotter: one witness a TimeZero mark, every copy says how, and its 2025 export's other formats (abcd.gpx,
#     Flök.kml = ccc.kml, cc_wpt.csv) hold the same marks as its TimeZero file;
#   - depth: one outcome a record; every reading's unit, metres and quantity in its own column, its text holding its number
#     and unit; every record whose text or field holds a depth (found here by a simpler detector of this script's own) read
#     or listed; HI's Z read only with a unit (in metres, those the study's 99 finds only as fathoms left out); each wreck's
#     depths from a witness of its basis;
#   - the date sunk: ISO 8601 truncated to its precision, one outcome a record, every record with a year beside a word of
#     loss or a date field read or listed, each wreck's date from a witness of its basis, dates_differ and dates_agree at
#     the common precision.
# Run from the repo root: Rscript curate/checks/wreck_accounting.R. Written by Claude (AI), 2026-11-19.
library(sf)
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)                     # standalone: not targets'
R <- function(...) fd_raw("external", ...)
cur <- function(...) as.data.frame(nanoparquet::read_parquet(fd_curated(...)))
wk <- cur("reference", "wreck.parquet"); wk$geometry <- NULL
rec <- cur("reference", "wreck_record.parquet"); pr <- cur("reference", "wreck_pair.parquet")
desc <- cur("reference", "wreck_description.parquet")
dr <- cur("check", "wreck_depth_read.parquet"); tr <- cur("check", "wreck_date_read.parquet")
acc <- data.frame(check = character(), verdict = character(), n = integer())
ok <- function(what, cond, n = NA_integer_) { cond <- isTRUE(all(cond))
  acc[nrow(acc) + 1, ] <<- list(what, if (cond) "ok" else "FAILED", as.integer(n)); message(if (cond) "ok " else "FAILED ", what) }
INTERNAL <- c("hi", "plotter")
eqna <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)

# Raw counts -------------------------------------------------------------------------------------------------------------------
f <- sort(list.files(R("isor"), "^vindorka_a_hafi_Infrastructure__", full.names = TRUE))
osm <- xml2::read_xml(gzfile(tail(sort(list.files(R("osm_wrecks"), "\\.osm\\.gz$", full.names = TRUE)), 1)))
GS <- R("ornefni", "fra_gudmundi-a-bjarna", "GS_nofn-og-flok_2022-10-18"); NF <- R("vernd_i_hafi", "kortlagning", "grunnthekjur", "nofn-flok")
tzn <- function(txt) { g <- gregexpr('"ObjectType":(0|7),', txt)[[1]]; sum(g > 0) }      # TimeZero's marks, types 0 and 7
rdt <- function(con) paste(readLines(con, warn = FALSE, encoding = "UTF-8"), collapse = "")
raw <- c(isor = nrow(st_coordinates(read_sf(f[1]))), skfi = nrow(read_sf(f[2])), lhg = nrow(read_sf(f[3])), dive = nrow(read_sf(f[4])),
         hi = nrow(read_sf(R("wreck_hi", "unzipped", "thekkt_skipsflok.shp"))),
         ukho = nrow(read_sf(R("emodnet_human_activities", "wwshipwrecks.geojson"))),
         osm = length(xml2::xml_find_all(osm, "/osm/node|/osm/way|/osm/relation")),
         plotter = tzn(rdt(file.path(GS, "Nöfn", "UserObjects.json"))) + tzn(rdt(file.path(GS, "Nöfn og flök", "UserObjects.json"))) +
           sum(gregexpr("<wpt ", rdt(file.path(GS, "nofn og flok.gpx")), fixed = TRUE)[[1]] > 0) +
           tzn(rdt(unz(file.path(NF, "nöfn og flök.tzx"), "UserObjects.json"))))
got <- table(sub("_appended$", "", rec$list))[names(raw)]
ok(sprintf("every raw record once (%s)", paste(names(raw), raw, collapse = ", ")),
   !is.na(got) & got == raw & !anyDuplicated(rec$rid) & !anyDuplicated(paste(rec$list, rec$record_id)), sum(raw))
# Outcomes, roles and wrecks ---------------------------------------------------------------------------------------------------
ok("one outcome each, from the set", !is.na(rec$outcome) & rec$outcome %in% c("several_witnesses", "one_witness", "conflict", "copy", "not_a_wreck"), nrow(rec))
w <- rec$role == "witness"; cp <- rec$role == "copy"; nw <- rec$role == "not_a_wreck"
ok("a witness has a wreck", !is.na(rec$wreck[w]), sum(w))
ok("a not_a_wreck has none", is.na(rec$wreck[nw]) & rec$outcome[nw] == "not_a_wreck", sum(nw))
orig <- match(rec$copy_of[cp], rec$rid)
ok("a copy sits with its original, a witness", !is.na(orig) & rec$role[orig] == "witness" & rec$wreck[cp] == rec$wreck[orig] & rec$outcome[cp] == "copy", sum(cp))
ok("witness outcomes agree with their wreck's", rec$outcome[w] == wk$outcome[match(rec$wreck[w], wk$wreck)])
nrec <- table(rec$wreck[w])
ok(sprintf("%d wrecks, each with its witnesses", nrow(wk)),
   setequal(wk$wreck, as.integer(names(nrec))) & wk$n_records == as.integer(nrec[as.character(wk$wreck)]) &
   wk$witnesses == vapply(wk$wreck, function(p) paste(sort(unique(rec$list[w & rec$wreck %in% p])), collapse = ","), character(1)), nrow(wk))
ok("several_witnesses means two lists or more, one_witness one", (wk$outcome != "several_witnesses" | wk$n_lists >= 2) & (wk$outcome != "one_witness" | wk$n_lists == 1))
ok("a conflict says why, no other wreck does", (wk$outcome == "conflict") == nzchar(dplyr::coalesce(wk$why, "")), sum(wk$outcome == "conflict"))
cf <- rec[rec$wreck %in% wk$wreck[wk$outcome == "conflict"], ]
cf$why <- wk$why[match(cf$wreck, wk$wreck)]; cf <- cf[order(cf$wreck, cf$list), ]
ok("wreck_conflict holds every record of every wreck in conflict", setequal(cf$rid, rec$rid[!is.na(rec$wreck) & rec$wreck %in% wk$wreck[wk$outcome == "conflict"]]), nrow(cf))
# Text, descriptions, pairs ----------------------------------------------------------------------------------------------------
chr_ok <- function(df) all(vapply(df, function(v) !is.character(v) || all(is.na(v) | validUTF8(v)), logical(1)))
ok("all text valid UTF-8", chr_ok(wk) & chr_ok(rec) & chr_ok(pr) & chr_ok(desc) & chr_ok(dr) & chr_ok(tr))
ok("every description points to a record of its list", desc$rid %in% rec$rid & desc$list == rec$list[match(desc$rid, rec$rid)], nrow(desc))
ok("joined pairs lie in one wreck", with(pr[pr$joined, ], wreck_i == wreck_j), sum(pr$joined))
# Ask o's flag, recomputed: mutual nearest, not joined, two wrecks, within MAYBE_M (1 km) or the two records' digits -----------
MAYBE_M <- 1000
lim <- pmax(MAYBE_M, dplyr::coalesce(rec$res_m[match(pr$rid_i, rec$rid)], 0) + dplyr::coalesce(rec$res_m[match(pr$rid_j, rec$rid)], 0))
ok(sprintf("maybe one wreck: exactly the mutual pairs not joined, in two wrecks, within %g m or their digits", MAYBE_M),
   pr$maybe_same == (pr$mutual & !pr$joined & pr$wreck_i != pr$wreck_j & pr$dist_m <= lim) & abs(pr$maybe_lim_m - lim) < 0.05, sum(pr$maybe_same))
fl <- pr[pr$maybe_same, ]
oth <- lapply(wk$wreck, function(p) sort(unique(c(fl$wreck_j[fl$wreck_i == p], fl$wreck_i[fl$wreck_j == p]))))
ok("the wreck table's maybe_same_as names every flagged wreck on both sides, its distance the nearest",
   mapply(function(a, o) identical(if (is.na(a)) integer() else sort(as.integer(strsplit(a, ",")[[1]])), as.integer(o)), wk$maybe_same_as, oth) &
   is.na(wk$maybe_same_m) == (lengths(oth) == 0) &
   mapply(function(m, p) is.na(m) || m == min(fl$dist_m[fl$wreck_i == p | fl$wreck_j == p]), wk$maybe_same_m, wk$wreck), sum(lengths(oth) > 0))
# Internal ---------------------------------------------------------------------------------------------------------------------
ok("the internal lists' descriptions marked internal (HI, the plotter)", desc$internal == (desc$list %in% INTERNAL), sum(desc$internal))
ok("a wreck internal where any attribute comes from an internal list, internal alone where all its witnesses are",
   wk$internal == (wk$position_basis %in% INTERNAL | wk$name_basis %in% INTERNAL | wk$date_basis %in% INTERNAL | wk$depth_basis %in% INTERNAL |
                   wk$least_depth_basis %in% INTERNAL) &
   wk$only_internal == vapply(strsplit(wk$witnesses, ","), function(x) all(x %in% INTERNAL), logical(1)), sum(wk$internal))
# The plotter ------------------------------------------------------------------------------------------------------------------
pl <- rec[rec$list == "plotter", ]; tzw <- pl[pl$role == "witness" & grepl("^tz20", pl$record_id), ]
ok("the plotter: one witness a TimeZero mark (its guid), its other states copies", !anyDuplicated(sub("^tz20[0-9]{2}:", "", tzw$record_id)), nrow(tzw))
ok("the plotter: every copy says how", !is.na(pl$copy_how[pl$role == "copy"]), sum(pl$role == "copy"))
t25 <- pl[startsWith(pl$record_id, "tz2025:"), ]
near1 <- function(lon, lat) vapply(seq_along(lon), function(i) min(sqrt(((t25$lon - lon[i]) * cos(lat[i] * pi / 180))^2 + (t25$lat - lat[i])^2) * 111320), 0)
k <- xml2::read_xml(file.path(NF, "Flök.kml")); xml2::xml_ns_strip(k)
kc <- xml2::xml_text(xml2::xml_find_all(k, "//Placemark/Point/coordinates")); kc <- do.call(rbind, lapply(strsplit(kc, ","), function(z) as.numeric(z[1:2])))
g <- xml2::read_xml(file.path(NF, "abcd.gpx")); xml2::xml_ns_strip(g); gw <- xml2::xml_find_all(g, "//wpt")
gn <- xml2::xml_text(xml2::xml_find_first(gw, "name")); glon <- as.numeric(xml2::xml_attr(gw, "lon")); glat <- as.numeric(xml2::xml_attr(gw, "lat"))
# cc_wpt.csv: rows end in CRLF, a comment's own line breaks are bare CR; its first two lines are a header
cl <- strsplit(rawToChar(readBin(file.path(NF, "cc_wpt.csv"), "raw", file.size(file.path(NF, "cc_wpt.csv")))), "\r\n", fixed = TRUE)[[1]]
cl <- cl[-(1:2)]; cl <- cl[nzchar(cl)]; cw <- data.frame(V4 = vapply(strsplit(cl, ","), `[`, "", 4), V5 = vapply(strsplit(cl, ","), `[`, "", 5))
dm <- function(s) vapply(strsplit(s, "-"), function(z) (as.numeric(z[1]) + as.numeric(z[2]) / 60) * ifelse(z[3] %in% c("S", "W"), -1, 1), 0)
same_name <- vapply(seq_along(gn), function(i) { j <- which.min(abs(t25$lon - glon[i]) + abs(t25$lat - glat[i]))
  identical(trimws(gn[i]), t25$name_given[j]) || (is.na(gn[i]) && is.na(t25$name_given[j])) }, TRUE)
ok(sprintf("the plotter's 2025 export: abcd.gpx (%d), Flök.kml (%d points; = ccc.kml) and cc_wpt.csv (%d) hold its %d TimeZero marks, within 1 m, the GPX's names equal",
           length(gw), nrow(kc), nrow(cw), nrow(t25)),
   length(unique(tools::md5sum(file.path(NF, c("Flök.kml", "ccc.kml"))))) == 1 &
   length(gw) == nrow(t25) & nrow(kc) == nrow(t25) & nrow(cw) == nrow(t25) &
   all(near1(glon, glat) < 1) & all(near1(kc[, 1], kc[, 2]) < 1) & all(near1(dm(cw$V5), dm(cw$V4)) < 1) & all(same_name), nrow(t25))
# Depth ------------------------------------------------------------------------------------------------------------------------
wr <- rec$role != "not_a_wreck"
ok("depth: one outcome a record, from the set; not_a_wreck exactly the records that are not wrecks",
   rec$depth_outcome %in% c("read", "ambiguous", "not_a_depth", "none", "not_a_wreck") & (rec$depth_outcome == "not_a_wreck") == !wr)
ok("depth: every reading a wreck record's, one seabed and one least reading a record at most",
   dr$rid %in% rec$rid[wr] & !anyDuplicated(dr[, c("rid", "quantity")]) & dr$quantity %in% c("seabed", "least"), nrow(dr))
rd <- dr[dr$outcome == "read", ]
fac <- ifelse(rd$unit == "fm", 1.8288, 1); hi_ <- pmax(rd$low, rd$high, na.rm = TRUE)
ok("depth: every reading's unit m or fm, its metres its deeper number times the unit (a fathom 1.8288 m)",
   rd$unit %in% c("m", "fm") & !is.na(rd$metres) & abs(rd$metres - round(hi_ * fac, 1)) < 1e-6 & !is.na(rd$pattern), nrow(rd))
ok("depth: a reading's text holds its number as written",
   mapply(function(t, n) all(vapply(strsplit(n, "-", fixed = TRUE)[[1]], function(z) grepl(z, t, fixed = TRUE), TRUE)), rd$text, rd$number))
ok("depth: a text reading's unit is in its text (m, metra/metrar/metrum or fm, faðmar)",
   with(rd[!grepl("^(ukho|osm|hi) ", rd$pattern), ], ifelse(unit == "fm", grepl("(?i)fm|fa[ðd?]m", text, perl = TRUE), grepl("(?i)[0-9]\\s?(m|metr)", text, perl = TRUE))))
one <- function(q, col) { x <- rd[rd$quantity == q, ]; x[[col]][match(rec$rid, x$rid)] }
ok("depth: one quantity a column, the record's seabed depth and least depth its readings, with the unit",
   eqna(rec$depth_m, one("seabed", "metres")) & eqna(rec$least_depth_m, one("least", "metres")) & eqna(rec$depth_unit, one("seabed", "unit")) &
   eqna(rec$depth_pattern, one("seabed", "pattern")))
oc <- vapply(rec$rid, function(r) { o <- dr$outcome[dr$rid == r]; if (!length(o)) "none" else intersect(c("read", "ambiguous", "not_a_depth"), o)[1] }, "")
ok("depth: a record's outcome follows its readings (read, else ambiguous, else not_a_depth, else none)", rec$depth_outcome[wr] == oc[wr])
ok("depth: every reading not read says why", !is.na(dr$why[dr$outcome != "read"]) & nzchar(dr$why[dr$outcome != "read"]), sum(dr$outcome != "read"))
# the texts that hold a depth, found here with a detector of this check's own, over the texts as given (LHG's as read back)
given <- function(l, f) { d <- desc[desc$list %in% l & desc$field %in% f, ]; d <- d[!duplicated(d$rid), ]; setNames(d$text, d$rid) }
lhg_l <- c("lhg", "lhg_appended")
lhg_t <- c(given(lhg_l, "comment"), given(lhg_l, "comment_read")); lhg_t <- lhg_t[!duplicated(names(lhg_t), fromLast = TRUE)]
txt <- c(lhg_t, given("dive", "popup"), given("skfi", "popup"), given("plotter", c("Comment", "cmt")))
txt <- tapply(txt, names(txt), paste, collapse = " ")
txt <- c(txt, setNames(rec$name_given[rec$list %in% c(lhg_l, "plotter")], rec$rid[rec$list %in% c(lhg_l, "plotter")]))
txt <- tapply(txt, names(txt), function(v) paste(v[!is.na(v)], collapse = " | "))
DET <- "(?i)(?<![0-9.,])[0-9]+(?:[.,][0-9]+)?\\s?(m|metr\\p{L}*|fm|fa[ðd?]m\\p{L}*)(?![\\p{L}?])|d[ýy?]p[it][^0-9]{0,12}[0-9]"
has_t <- as.integer(names(txt)[grepl(DET, gsub(" ", " ", txt), perl = TRUE)])
has_f <- unique(desc$rid[(desc$list == "hi" & desc$field == "Z" & !desc$text %in% "0") | (desc$list == "ukho" & desc$field %in% c("water_dept", "depth") & !desc$text %in% "n/a") |
                         (desc$list == "osm" & desc$field %in% c("depth", "wreck:depth", "seamark:wreck:depth"))])
need <- intersect(c(has_t, has_f), rec$rid[wr])
ok(sprintf("depth: every wreck record whose text or field holds a depth is in wreck_depth_read (%d records; %d read, %d ambiguous, %d not a depth)",
           length(need), sum(rec$depth_outcome[match(need, rec$rid)] == "read"), sum(rec$depth_outcome[match(need, rec$rid)] == "ambiguous"),
           sum(rec$depth_outcome[match(need, rec$rid)] == "not_a_depth")), need %in% dr$rid, length(need))
hz <- dr[dr$pattern %in% "hi Z", ]
hu <- fd_path("archive", "2026-11-11-named-features", "out", "wrecks", "hi_depth_unit.csv")
fm99 <- if (file.exists(hu)) { u <- read.csv(hu, encoding = "UTF-8"); u$record_id[u$list == "hi" & u$outcome_500 == "fathoms"] } else NULL
ok(sprintf("depth: HI's Z read only with a unit (all its readings ambiguous, or read in m but those the study's 99 finds only as fathoms: %s)",
           if (is.null(fm99)) "its table not found" else paste(fm99, collapse = ", ")),
   all(hz$outcome == "ambiguous") || (all(hz$unit[hz$outcome == "read"] == "m") &&
     (is.null(fm99) || setequal(as.character(hz$record_id[hz$outcome != "read"]), as.character(fm99)))), nrow(hz))
wb <- function(val, basis, col) mapply(function(p, v, b) if (b == "none") is.na(v) else any(rec[[col]][rec$wreck %in% p & rec$role == "witness" & rec$list == b] %in% v),
                                     wk$wreck, val, basis)
ok("depth: each wreck's seabed and least depth those of a witness of its basis, the unit with the seabed's",
   wb(wk$depth_m, wk$depth_basis, "depth_m") & wb(wk$least_depth_m, wk$least_depth_basis, "least_depth_m") &
   (is.na(wk$depth_m) == is.na(wk$depth_unit)), sum(!is.na(wk$depth_m)))
# The date sunk ----------------------------------------------------------------------------------------------------------------
dfm <- c(year = "^[0-9]{4}$", month = "^[0-9]{4}-[0-9]{2}$", day = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
dd <- rec[!is.na(rec$date_sunk), ]
ok(sprintf("date: every date sunk ISO 8601 truncated to its precision, a valid date, its year year_sunk (%s)",
           paste(names(table(dd$date_precision)), table(dd$date_precision), collapse = ", ")),
   c(mapply(function(d, p) grepl(dfm[[p]], d), dd$date_sunk, dd$date_precision) &
     !is.na(as.Date(ifelse(dd$date_precision == "day", dd$date_sunk, ifelse(dd$date_precision == "month", paste0(dd$date_sunk, "-01"), paste0(dd$date_sunk, "-01-01"))), optional = TRUE)) &
     dd$year_sunk == as.integer(substr(dd$date_sunk, 1, 4)),
     is.na(rec$year_sunk) == is.na(rec$date_sunk)), nrow(dd))
ok("date: one outcome a record, from the set; a record's date its reading in wreck_date_read",
   rec$date_outcome %in% c("read", "ambiguous", "no_loss_date", "none", "not_a_wreck") & (rec$date_outcome == "not_a_wreck") == !wr &
   eqna(rec$date_sunk, tr$date[tr$outcome == "read"][match(rec$rid, tr$rid[tr$outcome == "read"])]) & !anyDuplicated(tr$rid) &
   (rec$date_outcome == "read") == rec$rid %in% tr$rid[tr$outcome == "read"], nrow(tr))
ok("date: every reading not read says why", !is.na(tr$why[tr$outcome != "read"]), sum(tr$outcome != "read"))
# the records whose text holds a year beside a word of loss, or a date field, found here
LOSS <- "(?i)(s[öo?]kk?t?|f[óo?]rst|stranda[ðd?]i)(?![\\p{L}?])"
ct <- c(lhg_t, given("plotter", c("Comment", "cmt")))
yl <- as.integer(names(ct)[grepl(LOSS, ct, perl = TRUE) & grepl("(?<![0-9])(1[6-9][0-9]{2}|20[0-2][0-9])(?![0-9])", ct, perl = TRUE)])
df_ <- unique(desc$rid[(desc$list == "hi" & desc$field == "LOSS_DATE" & grepl("[0-9]", desc$text)) | (desc$list == "ukho" & desc$field == "date_sunk" & desc$text != "n/a") |
                      (desc$list == "osm" & desc$field == "wreck:date_sunk")])
need <- intersect(c(yl, df_), rec$rid[wr])
ok(sprintf("date: every wreck record with a year beside a word of loss, or a date field, is in wreck_date_read (%d; %d read, %d ambiguous)",
           length(need), sum(rec$date_outcome[match(need, rec$rid)] == "read"), sum(rec$date_outcome[match(need, rec$rid)] == "ambiguous")), need %in% tr$rid, length(need))
ok("date: each wreck's date that of a witness of its basis, with its precision",
   wb(wk$date_sunk, wk$date_basis, "date_sunk") & eqna(wk$year_sunk, as.integer(substr(wk$date_sunk, 1, 4))) &
   mapply(function(d, p) is.na(d) || grepl(dfm[[p]], d), wk$date_sunk, wk$date_precision), sum(!is.na(wk$date_sunk)))
cmp <- function(a, b) { n <- pmin(nchar(a), nchar(b)); ifelse(is.na(a) | is.na(b), NA, substr(a, 1, n) == substr(b, 1, n)) }
ddf <- vapply(wk$wreck, function(p) { d <- rec$date_sunk[rec$wreck %in% p & rec$role == "witness"]; d <- d[!is.na(d)]
  length(d) > 1 && any(outer(d, d, cmp) %in% FALSE) }, TRUE)
ok("date: dates_differ exactly where two witnesses of a wreck differ at their common precision",
   ddf == grepl("dates_differ", dplyr::coalesce(wk$why, "")), sum(ddf))
ok("date: the pairs' dates_agree at the common precision", eqna(pr$dates_agree, cmp(pr$date_i, pr$date_j)), sum(!is.na(pr$dates_agree)))

# Write: the checks, and the conflicts for the maintainer ----------------------------------------------------------------------
IN <- c(fd_curated("reference", "wreck.parquet"), fd_curated("reference", "wreck_record.parquet"), fd_curated("reference", "wreck_pair.parquet"),
        fd_curated("reference", "wreck_description.parquet"), fd_curated("check", "wreck_depth_read.parquet"), fd_curated("check", "wreck_date_read.parquet"))
write_curated(acc, fd_curated("check", "wreck_accounting.parquet"), script = "curate/checks/wreck_accounting.R", inputs = IN)
write_curated(cf, fd_curated("check", "wreck_conflict.parquet"), script = "curate/checks/wreck_accounting.R", inputs = IN)
fails <- acc$check[acc$verdict != "ok"]
message(sprintf("wreck_accounting: %d checks, %d failed; %d wrecks in conflict, %d records", nrow(acc), length(fails), length(unique(cf$wreck)), nrow(cf)))
if (length(fails)) stop("wreck_accounting: ", paste(fails, collapse = "; "))
