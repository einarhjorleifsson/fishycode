# The annual ship register's history to 2023-12-19, in the `vessel` schema's tables, every value chosen from its witnesses
# by plan 028's decision model (step 5).
# Side: once (register history). See plan 014; plan 028 §4 and §6; decisions 132 and 135.
#
# Input:  curated/vessel/skipaskra/evidence.parquet          every witness's values (step 3)
#         staging/skipaskra/{register,event}.parquet         the PDFs' entries and event lists
#         staging/hreidar/vessel_year.parquet                Hreiðar's years in use and fates
#         curated/vessel/mmsi.parquet                        the MMSI archive's windows (plan 016)
#         raw/oracle/vessel/{vessel,usage_category}.parquet  vessel_id, and the usage code table
#         overrides/skipaskra_reviewed.csv                   a person's decisions (D1)
#         overrides/usage_category_printed_reviewed.csv      a person's codes for printed types no table maps
# Output: curated/vessel/skipaskra/<table>.parquet, for vessel_hist, vessel_identification_hist, vessel_measurement_hist,
#         vessel_engines_hist, vessel_operational_hist, vessel_owners_hist, vessel_fishery_hist, vessel_mmsi_hist and
#         vessel_event; registered.parquet, each hull's runs on the register; usage_category_printed.parquet, the
#         PDFs' types of ship to the schema's codes; annual_call_sign.parquet, the call sign on each 1 January;
#         decision.parquet, one row per column and stretch, with the value chosen, its witnesses and the deciding rule
#
# How a value is chosen (plan 028 §4.3 and §6.2):
# - Each witness speaks for a window: an edition for its 1 January until the next edition (2020 reprints 2019 and is no
#   witness), Hreiðar for his year, a dated source for its from-to, the 2022-12-28 scrape and mbl from their date on.
# - Every stretch of time takes the first witness in its period's order: before 2004 Hreiðar, then the fisheries'
#   histories, then the `vessel` schema's back-filled rows; 2004-2021 the PDFs, then Hreiðar, the `vessel` schema, the
#   fisheries; from 2022 the fisheries' changes after the 2022 edition, the scrape, mbl, the `vessel`
#   schema's later rows, then the 2022 edition. Neighbouring stretches merge when printed alike (numbers at their
#   coarser precision, materials as sets), each agreeing with the value the merged stretch carries.
# - D1: a row of overrides/skipaskra_reviewed.csv outranks everything. D2: a PDF value that breaks one of the register's
#   own rules gives way to another lineage's value that keeps it, or stays and goes `open`; a GT off the formula below
#   15 m is only flagged (the maintainer's check, decision 136). D3: else the period's
#   witness decides. D4: a PDF value alone in its series gives way when two other lineages agree on its neighbours'.
#   D5: a change between two annual witnesses takes its day from a dated source that gives the value before and after.
# - Lineages (decision 135): Hreiðar is inside the register's for 2004-2021; mbl is its own; observation never counts.
# - A stretch's `status`: `single` (one lineage speaks), `agreed`, `resolved` (they disagree, `rule` chose), `reviewed`
#   (D1), `open`.
# - Values are kept only while the hull is on the register (`registered.parquet`): runs of the editions it is in and of
#   Hreiðar's years in use, their ends dated by the lists, the first registration or the `vessel` schema where one falls
#   in the bracket, else annual.
# - Personal data (decision 135): owners carry `national_identity_no` and operators `identity_no`, under $FISHYDATA.

library(dplyr)
library(tidyr)
library(nanoparquet)
library(DBI)
library(duckdb)

END <- as.Date("2023-12-19")                     # the `vessel` schema's own history begins: the main project's live part
EDITIONS <- c(2004:2019, 2021:2022)              # 2020 reprints 2019 (decision 130)
# NA-safe: case_when() evaluates every branch on every row
ed_date <- function(e) as.Date(ifelse(is.na(e), NA, paste0(e, "-01-01")))
ed_next <- function(e) { i <- match(e, EDITIONS); nx <- EDITIONS[pmin(i + 1, length(EDITIONS))]
  as.Date(ifelse(is.na(i), NA, ifelse(i < length(EDITIONS), paste0(nx, "-01-01"), as.character(END)))) }
year_start <- function(d, k = 0) as.Date(ifelse(is.na(d), NA, paste0(as.integer(format(d, "%Y")) + k, "-01-01")))
yd <- function(y) as.Date(paste0(y, "-01-01"))
agree_v <- function(cmp1, num1, dec1, cmp2, num2, dec2) ifelse(!is.na(num1) & !is.na(num2), num_agree(num1, dec1, num2, dec2), cmp1 == cmp2)
STATUS_ORDER <- c("single", "agreed", "resolved", "reviewed", "open")
worst <- function(s) STATUS_ORDER[max(match(s, STATUS_ORDER))]
pad_kt <- function(x) ifelse(grepl("^[0-9]{9}$", x), paste0("0", x), x)   # a kennitala whose leading zero was lost

HIST <- tribble(
  ~table, ~column, ~type,
  "vessel_hist", "name", "text", "vessel_hist", "previous_name", "text", "vessel_hist", "usage_category", "text",
  "vessel_hist", "open", "text", "vessel_hist", "classification_society", "class",
  "vessel_hist", "construction_place", "text", "vessel_hist", "construction_country", "text",
  "vessel_hist", "construction_year", "num", "vessel_hist", "construction_station", "text",
  "vessel_hist", "hull_material", "material", "vessel_hist", "imo_no", "text", "vessel_hist", "power_indicator", "num",
  "vessel_hist", "power_kw", "num", "vessel_hist", "horse_power", "num", "vessel_hist", "changes", "text",
  "vessel_identification_hist", "region_acronym", "text", "vessel_identification_hist", "region_no", "num",
  "vessel_identification_hist", "call_sign", "text", "vessel_identification_hist", "home_port", "text",
  "vessel_measurement_hist", "length", "num", "vessel_measurement_hist", "max_length", "num",
  "vessel_measurement_hist", "width", "num", "vessel_measurement_hist", "depth", "num",
  "vessel_measurement_hist", "brutto_grt", "num", "vessel_measurement_hist", "brutto_weight_tons", "num",
  "vessel_measurement_hist", "netto_weight_tons", "num", "vessel_measurement_hist", "brutto_grt_older", "num",
  "vessel_measurement_hist", "draft", "num", "vessel_measurement_hist", "draft_light", "num",
  "vessel_measurement_hist", "weight", "num",
  "vessel_engines_hist", "manufacturer_name", "text", "vessel_engines_hist", "year", "num",
  "vessel_engines_hist", "power", "num",
  "vessel_operational_hist", "operational_category_no", "text", "vessel_operational_hist", "operational_category", "text",
  "vessel_fishery_hist", "name", "text", "vessel_fishery_hist", "address", "text", "vessel_fishery_hist", "postal_no", "num",
  "vessel_fishery_hist", "identity_no", "text")

# The witnesses, comparable -------------------------------------------------------------------------------------------
# register numbers only: no placeholder (the fisheries' -999 and up), no foreign number (3700-4999)
evi <- read_parquet(fd_curated("vessel", "skipaskra", "evidence.parquet")) |>
  filter(vid >= 1, vid <= 9999, !(vid >= 3700 & vid <= 4999))
cm <- sk_comparable(evi, HIST)
cm <- bind_rows(cm |> filter(kind != "change"), sk_journal_intervals(cm))
reg <- read_parquet(fd_staging("skipaskra", "register.parquet"))

# Candidates for the series, each with its window [a, b) ----------------------------------------------------------------
# the journals date changes; an undated source, a one-day snapshot (kvoti's register copy of 2020-07-22) and an
# observation are witnesses only
SERIES_OUT <- "^ufs[.]skipasaga_jn$|^kvoti[.]skip_extra$|^kvoti[.]skipaskra_siglo$|^marinetraffic$|^ops_einarhj|^pdf_event"
cand <- cm |>
  filter(!grepl(SERIES_OUT, source), !(grepl("^pdf", source) & edition %in% 2020)) |>
  mutate(fam = case_when(grepl("^pdf", source) ~ "pdf", source == "hreidar" ~ "hreidar",
                         source %in% c("kvoti.skipasaga", "ufs.skipasaga", "ufs.skip_jn") ~ "fisheries",
                         grepl("^samgongustofa", source) ~ "samgongustofa", source == "mbl" ~ "mbl",
                         TRUE ~ "copy"),
         a = case_when(fam == "pdf" ~ ed_date(edition), fam == "hreidar" ~ year_start(t1),
                       TRUE ~ coalesce(t1, as.Date("1900-01-01"))),
         b = case_when(fam == "pdf" ~ ed_next(edition), fam == "hreidar" ~ year_start(t1, 1),
                       fam %in% c("samgongustofa", "mbl") ~ END,
                       TRUE ~ pmin(coalesce(t2 + 1, END), END)),
         basis = "recorded", rule = NA_character_, value_printed = NA_character_, flag = NA_character_) |>
  filter(a < b, a < END)
# A blank in a field the edition prints means none, and blocks the fallback: FJÖLVI (2196) prints no call sign in
# 2006-2011, and kvoti's register copy would give it TFKC from 1993. A field is printed when 1 % of the edition's
# entries of the section (decked or open) carry it.
pdf_cm <- cm |> filter(grepl("^pdf:", source), edition != 2020)
pdf_rec <- evi |> filter(grepl("^pdf:", source), edition != 2020) |> distinct(vid, edition, page, record)
open_rec <- evi |> filter(grepl("^pdf:", source), table == "vessel_hist", column == "open") |> distinct(record, open = value)
n_sec <- pdf_rec |> left_join(open_rec, by = "record") |> count(edition, open, name = "N")
printed <- pdf_cm |> left_join(open_rec, by = "record") |> distinct(record, edition, open, table, column) |>
  count(edition, open, table, column) |> left_join(n_sec, by = c("edition", "open")) |> filter(n >= 0.01 * N)
blank <- pdf_rec |> left_join(open_rec, by = "record") |>
  inner_join(printed |> select(edition, open, table, column), by = c("edition", "open"), relationship = "many-to-many") |>
  # a printed zero ("0,00") is a placeholder, not none: others may fill it (6996's GT in 2018, the maintainer's check)
  anti_join(evi |> filter(grepl("^pdf:", source)) |> distinct(record, table, column), by = c("record", "table", "column"))
cand <- bind_rows(cand, blank |> left_join(HIST, by = c("table", "column")) |>
                    transmute(vid, table, column, type, value = NA_character_, cmp = "<none>", num = NA_real_, dec = NA_integer_,
                                           source = paste0("pdf:", edition), lineage = "register", fam = "pdf", kind = "snapshot",
                                           edition, page, record, t1 = ed_date(edition), t2 = ed_date(edition),
                                           a = ed_date(edition), b = ed_next(edition), basis = "recorded", rule = NA_character_,
                                           value_printed = NA_character_, flag = "blank"))
message("blanks: ", nrow(blank), " fields an edition prints and an entry leaves empty, read as none")

## D2: the register's own rules ------------------------------------------------------------------------------------------
# another lineage's value, as it stands: the ufs journal's superseded versions are no witness (28 of D2's first 33
# replacements came only from them)
other <- cm |> filter(!lineage %in% c("register", "hreidar", "observation"), source != "ufs.skipasaga_jn")
br <- bind_rows(
  reg |> filter(!is.na(imo), !imo_ok(imo)) |> transmute(vid, edition, table = "vessel_hist", column = "imo_no", why = "imo_check_digit"),
  reg |> filter(!is.na(length_reg), length_reg < 15, !is.na(gt), !is.na(breadth)) |>
    mutate(p = 0.031 * length_reg^2 * breadth) |> filter(abs(gt - p) > 0.01 * p + 0.01) |>
    transmute(vid, edition, table = "vessel_measurement_hist", column = "brutto_weight_tons", why = "gt_formula", L = length_reg, B = breadth),
  reg |> mutate(by = suppressWarnings(as.integer(built_year))) |> filter(!is.na(by), by > edition) |>
    transmute(vid, edition, table = "vessel_hist", column = "construction_year", why = "year_after_edition"),
  reg |> mutate(ey = suppressWarnings(as.integer(engine_year))) |> filter(!is.na(ey), ey > edition) |>
    transmute(vid, edition, table = "vessel_engines_hist", column = "year", why = "year_after_edition"),
  reg |> filter(!is.na(call_sign), !is.na(loa), loa < 15) |>
    transmute(vid, edition, table = "vessel_identification_hist", column = "call_sign", why = "call_sign_short")) |>
  filter(edition != 2020) |> mutate(d = ed_date(edition))
keeps <- function(why, cmpv, L, B, edition) case_when(
  why == "imo_check_digit" ~ imo_ok(cmpv),
  why == "gt_formula" ~ { g <- suppressWarnings(as.numeric(cmpv)); p <- 0.031 * L^2 * B; !is.na(g) & abs(g - p) <= 0.01 * p + 0.01 },
  why == "year_after_edition" ~ suppressWarnings(as.integer(cmpv)) <= edition,
  TRUE ~ FALSE)
alt <- br |> inner_join(other |> select(vid, table, column, t1, t2, oval = value, ocmp = cmp, osrc = source, onum = num, odec = dec),
                        by = c("vid", "table", "column"), relationship = "many-to-many") |>
  filter(is.na(t1) | t1 <= d, is.na(t2) | t2 >= d, why != "gt_formula", keeps(why, ocmp, L, B, edition)) |>
  group_by(vid, edition, table, column) |> slice(1) |> ungroup()
d2 <- br |> left_join(alt |> select(vid, edition, table, column, oval, ocmp, osrc, onum, odec), by = c("vid", "edition", "table", "column")) |>
  mutate(src = paste0("pdf:", edition))
i2 <- match(paste(cand$vid, cand$table, cand$column, cand$source), paste(d2$vid, d2$table, d2$column, d2$src))
hit <- !is.na(i2) & !is.na(d2$oval[i2])
cand$value_printed[hit] <- cand$value[hit]
cand$value[hit] <- d2$oval[i2[hit]]; cand$cmp[hit] <- d2$ocmp[i2[hit]]; cand$num[hit] <- d2$onum[i2[hit]]; cand$dec[hit] <- d2$odec[i2[hit]]
cand$rule[hit] <- "D2"; cand$record[hit] <- paste0(cand$record[hit], " <- ", d2$osrc[i2[hit]])
# the GT formula is a flag only: the maintainer found the PDF right on all 32 of D2's formula replacements (decision 136)
cand$rule[!is.na(i2) & !hit & d2$why[i2] != "gt_formula"] <- "D2_open"
cand$flag[!is.na(i2)] <- d2$why[i2[!is.na(i2)]]
message("D2: ", nrow(br), " PDF values break a rule; ", sum(!is.na(d2$oval)), " give way to another lineage's value that keeps it")

## D4: the isolated deviation -------------------------------------------------------------------------------------------
ps <- cand |> filter(fam == "pdf", is.na(rule)) |> select(vid, table, column, edition, cmp, num, dec) |>
  arrange(vid, table, column, edition) |> group_by(vid, table, column) |>
  mutate(cp = lag(cmp), np = lag(num), dp = lag(dec), cn = lead(cmp), nn = lead(num), dn = lead(dec)) |> ungroup() |>
  filter(!is.na(cp), !is.na(cn), agree_v(cp, np, dp, cn, nn, dn), !agree_v(cmp, num, dec, cp, np, dp)) |>
  mutate(d = ed_date(edition))
d4w <- ps |> inner_join(other |> select(vid, table, column, t1, t2, ocmp = cmp, onum = num, odec = dec, olin = lineage, oval = value),
                        by = c("vid", "table", "column"), relationship = "many-to-many") |>
  filter(is.na(t1) | t1 <= d, is.na(t2) | t2 >= d) |>
  mutate(with_nb = agree_v(ocmp, onum, odec, cp, np, dp), with_pdf = agree_v(ocmp, onum, odec, cmp, num, dec)) |>
  group_by(vid, table, column, edition) |>
  summarise(n_nb = n_distinct(olin[with_nb]), n_pdf = n_distinct(olin[with_pdf]), oval = oval[with_nb][1],
            ocmp = ocmp[with_nb][1], onum = onum[with_nb][1], odec = odec[with_nb][1], .groups = "drop") |>
  filter(n_nb >= 2, n_pdf == 0)
i4 <- match(paste(cand$vid, cand$table, cand$column, cand$source), paste(d4w$vid, d4w$table, d4w$column, paste0("pdf:", d4w$edition)))
h4 <- !is.na(i4)
cand$value_printed[h4] <- cand$value[h4]
cand$value[h4] <- d4w$oval[i4[h4]]; cand$cmp[h4] <- d4w$ocmp[i4[h4]]; cand$num[h4] <- d4w$onum[i4[h4]]; cand$dec[h4] <- d4w$odec[i4[h4]]
cand$rule[h4] <- "D4"; cand$basis[h4] <- "reconstructed"
message("D4: ", nrow(ps), " PDF values stand alone in their series; ", nrow(d4w), " give way to two other lineages")

## D1: a person's decision --------------------------------------------------------------------------------------------
rv <- utils::read.csv("overrides/skipaskra_reviewed.csv", colClasses = "character")
if (nrow(rv)) {
  cand <- bind_rows(cand, rv |> transmute(vid = as.integer(vid), table, column, value, cmp = key_txt(value),
                                         num = suppressWarnings(as.numeric(value)), dec = as.integer(dec_of(value)),
                                         source = paste0("review:", reviewer), lineage = "review", fam = "review",
                                         a = as.Date(valid_from), b = as.Date(ifelse(valid_to == "", as.character(END), valid_to)),
                                         basis = "recorded", rule = "D1", record = paste("review", date, reason)))
}
cand <- cand |> mutate(cid = row_number())

# The period's order: one witness per elementary stretch ---------------------------------------------------------------
con <- dbConnect(duckdb())
spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
invisible(dbExecute(con, sprintf("SET temp_directory = '%s'", spill)))
duckdb_register(con, "cand", cand |> transmute(cid, vid, tab = table, col = column, fam, a, b))
invisible(dbExecute(con, "
  CREATE TABLE el AS
  WITH bnd AS (
    SELECT DISTINCT vid, tab, col, d FROM (
      SELECT vid, tab, col, a AS d FROM cand UNION ALL SELECT vid, tab, col, b FROM cand
      UNION ALL SELECT vid, tab, col, DATE '2004-01-01' FROM cand UNION ALL SELECT vid, tab, col, DATE '2022-01-01' FROM cand))
  SELECT * FROM (SELECT vid, tab, col, d AS s, lead(d) OVER (PARTITION BY vid, tab, col ORDER BY d) AS e FROM bnd) WHERE e IS NOT NULL"))
pick <- dbGetQuery(con, "
  SELECT vid, tab, col, s, e, cid FROM (
    SELECT el.vid, el.tab, el.col, el.s, el.e, c.cid,
      CASE WHEN c.fam = 'review' THEN 0
           WHEN el.s < DATE '2004-01-01' THEN CASE c.fam WHEN 'hreidar' THEN 1 WHEN 'fisheries' THEN 2 WHEN 'copy' THEN 3 ELSE 9 END
           WHEN el.s < DATE '2022-01-01' THEN CASE c.fam WHEN 'pdf' THEN 1 WHEN 'hreidar' THEN 2 WHEN 'copy' THEN 3 WHEN 'fisheries' THEN 4 ELSE 9 END
           ELSE CASE WHEN c.fam = 'fisheries' AND c.a >= DATE '2022-01-01' THEN 1 WHEN c.fam = 'samgongustofa' THEN 2
                     WHEN c.fam = 'mbl' THEN 3 WHEN c.fam = 'copy' AND c.a >= DATE '2022-01-01' THEN 4 WHEN c.fam = 'pdf' THEN 5
                     WHEN c.fam = 'copy' THEN 6 WHEN c.fam = 'fisheries' THEN 7 WHEN c.fam = 'hreidar' THEN 8 ELSE 9 END END AS tier,
      row_number() OVER (PARTITION BY el.vid, el.tab, el.col, el.s ORDER BY tier, c.a DESC, c.cid) AS rk
    FROM el JOIN cand c ON c.vid = el.vid AND c.tab = el.tab AND c.col = el.col AND c.a <= el.s AND el.s < c.b) WHERE rk = 1")

## Merge neighbours that agree -----------------------------------------------------------------------------------------
pk <- pick |> rename(table = tab, column = col) |>
  left_join(cand |> select(cid, value, cmp, num, dec, source, lineage, fam, record, edition, page, basis, rule, flag, value_printed, ca = a), by = "cid") |>
  arrange(vid, table, column, s) |>
  # text and codes merge only when printed alike (SI and SS are one body, but the rename is the register's); numbers merge
  # at their coarser precision, materials as sets
  left_join(HIST, by = c("table", "column")) |>
  mutate(mkey = if_else(type %in% c("text", "class"), coalesce(key_txt(value), "<none>"), cmp)) |>
  group_by(vid, table, column) |>
  mutate(new = is.na(lag(e)) | lag(e) != s | !agree_v(mkey, num, dec, lag(mkey), lag(num), lag(dec)) |
           coalesce(rule != lag(rule), xor(is.na(rule), is.na(lag(rule)))),
         seg = cumsum(new)) |> ungroup()
# a value printed coarser can bridge two that differ (142.18 and 142.19 through 142.2): every stretch must agree with its
# group's representative, the value the group will carry, or stands as a group of its own (split before and after it)
for (pass in 1:50) {
  o <- order(pk$vid, pk$table, pk$column, pk$seg, -(pk$fam == "pdf"), -coalesce(pk$dec, 0L), -as.numeric(pk$s))
  g <- paste(pk$vid[o], pk$table[o], pk$column[o], pk$seg[o])
  ri <- o[match(g, g)]                                           # each stretch's representative, in the order o
  bad <- logical(nrow(pk))
  bad[o] <- !agree_v(pk$mkey[o], pk$num[o], pk$dec[o], pk$mkey[ri], pk$num[ri], pk$dec[ri])
  bad[is.na(bad)] <- FALSE
  if (!any(bad)) break
  pk <- pk |> mutate(bad = bad) |> group_by(vid, table, column) |>
    mutate(new = new | bad | coalesce(lag(bad), FALSE), seg = cumsum(new)) |> ungroup() |> select(-bad)
  if (pass == 50) stop("stretches still disagree with their representative after 50 passes")
}
srcs <- function(source, edition, s) {
  fam <- sub(":.*$", "", source); y <- as.integer(format(s, "%Y"))
  r <- tapply(seq_along(source), fam, function(i) {
    if (fam[i[1]] == "pdf") paste0("pdf:", min(edition[i]), if (max(edition[i]) > min(edition[i])) paste0("-", max(edition[i])))
    else if (fam[i[1]] == "hreidar") paste0("hreidar:", min(y[i]), if (max(y[i]) > min(y[i])) paste0("-", max(y[i])))
    else paste(unique(source[i]), collapse = ";") })
  paste(r[order(sapply(names(r), function(f) min(s[fam == f])))], collapse = "; ")
}
seg <- pk |> group_by(vid, table, column, seg) |>
  arrange(desc(fam == "pdf"), desc(coalesce(dec, 0L)), desc(s), .by_group = TRUE) |>
  summarise(valid_from = min(s), valid_to = max(e), value = value[1], cmp = cmp[1], num = num[1], dec = dec[1],
            value_printed = value_printed[1], source = srcs(source, edition, s), first_fam = fam[which.min(s)],
            last_fam = fam[which.max(s)], last_start = max(s),
            editions = paste(sort(unique(na.omit(edition))), collapse = ","), page = page[1],
            basis = if (any(basis == "reconstructed")) "reconstructed" else "recorded",
            rule = paste(sort(unique(na.omit(rule))), collapse = ","), flag = paste(sort(unique(na.omit(flag))), collapse = ","),
            .groups = "drop") |>
  arrange(vid, table, column, valid_from)

## D5: dating a change between annual witnesses --------------------------------------------------------------------------
chg <- seg |> group_by(vid, table, column) |>
  mutate(pfam = lag(last_fam), plast = lag(last_start), pcmp = lag(cmp), pnum = lag(num), pdec = lag(dec), pto = lag(valid_to)) |>
  ungroup() |> filter(!is.na(pfam), pto == valid_from, pfam %in% c("pdf", "hreidar"), first_fam %in% c("pdf", "hreidar")) |>
  select(vid, table, column, valid_from, plast, pcmp, pnum, pdec, cmp, num, dec)
DATED <- c("ufs.skip_jn", "ufs.skipasaga_jn", "ufs.skipasaga", "kvoti.skipasaga", "vessel:vessel_hist", "vessel:vessel_identification_hist",
           "vessel:vessel_measurement_hist", "vessel:vessel_engines_hist", "vessel:vessel_operational_hist", "vessel:vessel_fishery_hist")
dw <- cm |> filter(source %in% DATED, !is.na(t1)) |> select(vid, table, column, source, t1, t2, wcmp = cmp, wnum = num, wdec = dec)
d5 <- chg |> inner_join(dw, by = c("vid", "table", "column"), relationship = "many-to-many") |>
  filter(t1 > plast, t1 <= valid_from, agree_v(wcmp, wnum, wdec, cmp, num, dec)) |>
  select(vid, table, column, valid_from, source, d = t1)
dated <- d5 |> inner_join(dw |> rename(src2 = source), by = c("vid", "table", "column"), relationship = "many-to-many") |>
  filter(src2 == source, t1 <= d - 1, is.na(t2) | t2 >= d - 1) |>
  inner_join(chg |> select(vid, table, column, valid_from, pcmp, pnum, pdec), by = c("vid", "table", "column", "valid_from")) |>
  filter(agree_v(wcmp, wnum, wdec, pcmp, pnum, pdec)) |>
  mutate(rank = match(source, DATED)) |> arrange(rank, d) |>
  group_by(vid, table, column, valid_from) |> slice(1) |> ungroup() |> select(vid, table, column, valid_from, d, dated_by = source)
message("D5: ", nrow(chg), " changes between annual witnesses; ", nrow(dated), " dated by a source that gives both sides")
seg <- seg |> left_join(dated, by = c("vid", "table", "column", "valid_from")) |>
  group_by(vid, table, column) |> mutate(nd = lead(d)) |> ungroup() |>
  mutate(window_from = case_when(!is.na(d) ~ "dated", first_fam %in% c("pdf", "hreidar") ~ "annual", TRUE ~ "dated"),
         valid_from = coalesce(d, valid_from), valid_to = coalesce(nd, valid_to)) |>
  select(-d, -nd) |> mutate(sid = row_number())

## Status: the lineages that speak at each anchor -------------------------------------------------------------------------
anc <- pk |> mutate(d = if_else(fam == "pdf", ca, s)) |>
  select(vid, table, column, seg, d, lineage) |> distinct(vid, table, column, seg, d, .keep_all = TRUE) |>
  inner_join(seg |> select(vid, table, column, seg, sid, cmp, num, dec), by = c("vid", "table", "column", "seg"))
WIT_OUT <- "^ufs[.]skipasaga_jn$|^kvoti[.]skip_extra$|^marinetraffic$|^pdf_event"
wit <- cm |> filter(!grepl(WIT_OUT, source), !(grepl("^pdf", source) & edition %in% 2020), lineage != "observation") |>
  transmute(vid, tab = table, col = column, lineage, a = t1, b = t2, value, cmp, num, dec)
duckdb_register(con, "anc", anc |> transmute(sid, vid, tab = table, col = column, d, clin = lineage, cmp, num, dec))
duckdb_register(con, "wit", wit)
agree_sql <- "
  CASE WHEN a.num IS NOT NULL AND w.num IS NOT NULL THEN
    abs(round((CASE WHEN a.dec >= w.dec THEN a.num ELSE w.num END) * pow(10, least(a.dec, w.dec))) -
        round((CASE WHEN a.dec >= w.dec THEN w.num ELSE a.num END) * pow(10, least(a.dec, w.dec)))) < 0.5 OR
    abs(floor((CASE WHEN a.dec >= w.dec THEN a.num ELSE w.num END) * pow(10, least(a.dec, w.dec)) + 1e-7) -
        round((CASE WHEN a.dec >= w.dec THEN w.num ELSE a.num END) * pow(10, least(a.dec, w.dec)))) < 0.5
  ELSE a.cmp = w.cmp END"
st <- dbGetQuery(con, sprintf("
  WITH j AS (
    SELECT a.sid, a.d, CASE WHEN a.clin = 'hreidar' AND a.d >= DATE '2004-01-01' AND a.d < DATE '2022-01-01' THEN 'register' ELSE a.clin END AS clin,
           CASE WHEN w.lineage = 'hreidar' AND a.d >= DATE '2004-01-01' AND a.d < DATE '2022-01-01' THEN 'register' ELSE w.lineage END AS lin,
           (%s) AS ag, w.value
    FROM anc a JOIN wit w ON a.vid = w.vid AND a.tab = w.tab AND a.col = w.col
     AND (w.a IS NULL OR w.a <= a.d) AND (w.b IS NULL OR w.b >= a.d)),
  per AS (
    SELECT sid, d, any_value(clin) AS clin, list_distinct(list(lin)) AS lins, list_distinct(list(lin) FILTER (WHERE ag)) AS agl,
           string_agg(DISTINCT value, '; ' ORDER BY value) FILTER (WHERE NOT ag) AS alt
    FROM j GROUP BY sid, d)
  SELECT sid, d, len(list_distinct(list_append(lins, clin))) AS n_lin, len(list_distinct(list_append(agl, clin))) AS n_agr, alt FROM per",
  agree_sql))
dbDisconnect(con, shutdown = TRUE)
unlink(spill, recursive = TRUE)
st <- anc |> select(sid, d) |> left_join(st, by = c("sid", "d")) |>
  mutate(n_lin = coalesce(n_lin, 1L), n_agr = coalesce(n_agr, 1L),
         a_status = case_when(n_lin <= 1 ~ "single", n_agr == n_lin ~ "agreed", TRUE ~ "disputed"))
ss <- st |> group_by(sid) |>
  summarise(n_lineages = max(n_lin), n_agree = min(n_agr[n_lin == max(n_lin)]),
            any_disp = any(a_status == "disputed"), any_agreed = any(a_status == "agreed"),
            alternatives = paste(head(sort(unique(unlist(strsplit(na.omit(alt), "; ")))), 5), collapse = "; "), .groups = "drop")
seg <- seg |> left_join(ss, by = "sid") |>
  mutate(status = case_when(grepl("D1", rule) ~ "reviewed",
                            grepl("D2_open", rule) ~ "open",
                            grepl("D2|D4", rule) | any_disp ~ "resolved",
                            any_agreed ~ "agreed",
                            TRUE ~ "single"),
         rule = case_when(status == "resolved" & !grepl("D2|D4", rule) ~ "D3", status == "open" ~ "D2", TRUE ~ na_if(rule, "")),
         alternatives = na_if(alternatives, ""), flag = na_if(flag, ""))

# Registered life -------------------------------------------------------------------------------------------------------
evt <- read_parquet(fd_staging("skipaskra", "event.parquet")) |> filter(!is.na(vid))
hr <- read_parquet(fd_staging("hreidar", "vessel_year.parquet"), col_select = c("nr", "year", "year_placeholder", "year_out", "fate", "fate_note")) |>
  filter(nr >= 1, nr <= 9999, !(nr >= 3700 & nr <= 4999), !is.na(year))
fate_class <- function(f) {
  f <- toupper(f)
  case_when(is.na(f) ~ NA_character_, f == "IN USE" ~ "in_use", f == "UNKNOWN" ~ "unknown",
            grepl("BROTAJÁRN|NIÐURRIF|RIFI|ÓNÝT|FARGA|EYÐILAG|RUINED|SCRAP", f) ~ "scrapped",
            grepl("SÖKK|STRAND|FÓRST|TÝND|BRANN|SANK|STRANDED|LOST|WRECK", f) ~ "lost",
            grepl("SELT|SELDUR|SELD |ERLEND|ÚR LANDI|SOLD ABROAD", f) ~ "sold_abroad",
            grepl("AFMÁÐ|UNREGISTERED", f) ~ "deleted",
            grepl("ÚR REKSTRI|OUT OF USE", f) ~ "out_of_service",
            TRUE ~ "other")
}
on_ed <- reg |> filter(edition != 2020) |> distinct(vid, y = edition)
on_hr <- hr |> filter(!year_placeholder, year < 2004) |> distinct(vid = nr, y = year)
sgs_status <- evi |> filter(source == "samgongustofa:2022-12-28", column == "status") |> distinct(vid, value)
vstat <- evi |> filter(source == "vessel:vessel_hist", column == "status", !is.na(t1)) |> select(vid, value, t1, t2)
on23 <- bind_rows(sgs_status |> filter(value == "Skráð") |> select(vid),
                  vstat |> filter(value == "Á aðalskipaskrá", is.na(t2) | t2 >= as.Date("2023-06-01")) |> select(vid)) |>
  distinct(vid) |> mutate(y = 2023L)
dereg <- evt |> filter(kind == "deregistration") |> transmute(vid, edition, d = date, src = paste0("pdf_event:", edition))
regev <- evt |> filter(kind == "registration") |> transmute(vid, edition, d = date, src = paste0("pdf_event:", edition))
# a hull in 2019 is on in 2020 if it is in 2021 too, or left in 2020 (2021's list)
on20 <- on_ed |> filter(y == 2019) |> select(vid) |>
  filter(vid %in% on_ed$vid[on_ed$y == 2021] | vid %in% dereg$vid[dereg$edition == 2021]) |> mutate(y = 2020L)
on <- bind_rows(on_hr, on_ed, on20, on23) |> distinct(vid, y) |> arrange(vid, y)
runs <- on |> group_by(vid) |> mutate(r = cumsum(c(1, diff(y) != 1))) |>
  group_by(vid, r) |> summarise(y1 = min(y), y2 = max(y), .groups = "drop")
first_reg <- bind_rows(
  evi |> filter(source == "kvoti.skip_extra", column == "event", value == "registration:first") |> transmute(vid, d = t1, src = "kvoti.skip_extra"),
  evi |> filter(column == "initial_registration") |> transmute(vid, d = as.Date(value), src = "vessel:vessel_hist"),
  regev |> filter(!is.na(d)) |> select(vid, d, src)) |>
  filter(d > as.Date("1900-01-01"))                                   # 1900-01-01 is the `vessel` schema's placeholder
ends <- bind_rows(dereg |> filter(!is.na(d)) |> select(vid, d, src),
                  vstat |> filter(value %in% c("Afmáð", "Erlent")) |> transmute(vid, d = t1, src = "vessel:vessel_hist"))
pick_day <- function(r, ev) {
  r |> left_join(ev, by = "vid", relationship = "many-to-many") |>
    mutate(ok = !is.na(d) & d > lo & d <= hi) |> group_by(vid, r) |>
    summarise(src = if (any(ok)) src[ok][which.min(d[ok])] else NA_character_, d = if (any(ok)) min(d[ok]) else as.Date(NA), .groups = "drop")
}
# a run that starts at an edition was registered in the year before (the edition's list); at one of Hreiðar's years, in it
sd <- pick_day(runs |> mutate(lo = if_else(y1 >= 2004, yd(y1 - 1), yd(y1) - 1), hi = if_else(y1 >= 2004, yd(y1), yd(y1 + 1) - 1)), first_reg)
# printed in an edition, the hull was on the register that 1 January: it left after it (GUÐRÚN, 243, left on 2009-01-01)
en <- pick_day(runs |> mutate(lo = if_else(y2 >= 2004, yd(y2), yd(y2) - 1), hi = yd(y2 + 1) - 1), ends)
registered <- runs |>
  left_join(sd |> rename(d_from = d, src_from = src), by = c("vid", "r")) |>
  left_join(en |> rename(d_to = d, src_to = src), by = c("vid", "r")) |>
  mutate(valid_from = coalesce(d_from, yd(y1)), window_from = if_else(is.na(d_from), "annual", "dated"),
         valid_to = case_when(y2 >= 2023 ~ END, !is.na(d_to) ~ d_to, TRUE ~ yd(y2 + 1)),
         window_to = case_when(y2 >= 2023 ~ "open", !is.na(d_to) ~ "dated", TRUE ~ "annual"),
         valid_to = pmax(valid_to, valid_from + 1)) |>
  arrange(vid, valid_from) |>
  group_by(vid) |> mutate(valid_to = pmin(valid_to, coalesce(lead(valid_from), END))) |> ungroup() |>
  transmute(vid, run = r, valid_from, valid_to, window_from, window_to, dated_from = src_from, dated_to = src_to,
            first_year = as.integer(y1), last_year = as.integer(y2))
message("registered life: ", nrow(registered), " runs on ", n_distinct(registered$vid), " hulls")

vessel_event <- bind_rows(
  evt |> transmute(vid, event = ifelse(is.na(subkind), kind, paste(kind, subkind, sep = ":")), date,
                   window = if_else(is.na(date), "annual", "dated"), year = edition - 1L, fate, fate_class = fate_class(fate),
                   brutto_weight_tons = gt, section, remark, source = paste0("pdf_event:", edition), page, basis = "recorded"),
  first_reg |> filter(!grepl("^pdf_event", src)) |>
    transmute(vid, event = "registration:first", date = d, window = "dated", year = as.integer(format(d, "%Y")), source = src, basis = "recorded"),
  hr |> filter(!is.na(year_out), !is.na(fate), fate != "In use") |> group_by(vid = nr) |> slice_max(year, n = 1, with_ties = FALSE) |> ungroup() |>
    transmute(vid, event = "out_of_use", date = as.Date(NA), window = "annual", year = as.integer(year_out), fate,
              fate_class = fate_class(fate), remark = fate_note, source = "hreidar", basis = "recorded"),
  registered |> transmute(vid, event = "on_register", date = valid_from, window = window_from, year = as.integer(format(valid_from, "%Y")),
                          source = coalesce(dated_from, "derived: the editions and Hreiðar's years"), basis = "derived"),
  registered |> filter(window_to != "open") |>
    transmute(vid, event = "off_register", date = valid_to, window = window_to, year = as.integer(format(valid_to, "%Y")),
              source = coalesce(dated_to, "derived: the editions and Hreiðar's years"), basis = "derived")) |>
  distinct() |> arrange(vid, coalesce(date, as.Date(paste0(year, "-07-01"))), event)

# Columns clipped to the registered life ---------------------------------------------------------------------------------
clip <- seg |>
  inner_join(registered |> select(vid, run, p_from = valid_from, p_to = valid_to, pw_from = window_from, pw_to = window_to),
             by = "vid", relationship = "many-to-many") |>
  filter(valid_from < p_to, valid_to > p_from) |>
  mutate(window_from = if_else(valid_from <= p_from, pw_from, window_from),
         valid_from = pmax(valid_from, p_from), valid_to = pmin(valid_to, p_to)) |>
  arrange(vid, table, column, valid_from) |>
  group_by(vid, table, column) |>
  mutate(window_to = if_else(!is.na(lead(valid_from)) & lead(valid_from) == valid_to, lead(window_from), if_else(valid_to == p_to, pw_to, "annual"))) |>
  ungroup()
decision <- clip |>
  transmute(vid, table, column, valid_from, valid_to, window_from, window_to, value, value_printed, source, basis, status, rule,
            flag, n_lineages, n_agree, alternatives, editions, page, run)

## Rows of a table: every change of any of its columns opens a row ----------------------------------------------------
vkey <- read_parquet(fd_raw("oracle", "vessel", "vessel.parquet")) |> transmute(vid = as.integer(registration_no), vessel_id = as.integer(vessel_id))
assemble <- function(tab) {
  cs <- decision |> filter(table == tab)
  b <- bind_rows(cs |> select(vid, run, d = valid_from), cs |> select(vid, run, d = valid_to)) |> distinct() |>
    arrange(vid, run, d) |> group_by(vid, run) |> mutate(e = lead(d)) |> ungroup() |> filter(!is.na(e))
  w <- b |> inner_join(cs, by = c("vid", "run"), relationship = "many-to-many") |> filter(valid_from <= d, d < valid_to)
  meta <- w |> group_by(vid, run, d, e) |>
    summarise(window_from = if (any(valid_from == d & window_from == "annual")) "annual" else if (any(valid_from == d)) "dated" else "within",
              window_to = if (any(valid_to == e & window_to == "open")) "open" else if (any(valid_to == e & window_to == "annual")) "annual" else "dated",
              source = names(sort(table(sub("[:;].*$", "", source)), decreasing = TRUE))[1],
              basis = if (any(basis == "reconstructed")) "reconstructed" else "recorded",
              status = worst(status), rule = paste(sort(unique(na.omit(rule))), collapse = ","),
              disputed = paste(sort(unique(column[status %in% c("resolved", "open", "reviewed")])), collapse = ","),
              n_lineages = max(n_lineages), n_agree = min(n_agree),
              edition_first = suppressWarnings(min(as.integer(unlist(strsplit(editions, ","))), na.rm = TRUE)),
              edition_last = suppressWarnings(max(as.integer(unlist(strsplit(editions, ","))), na.rm = TRUE)), .groups = "drop") |>
    mutate(rule = na_if(rule, ""), disputed = na_if(disputed, ""),
           edition_first = ifelse(is.finite(edition_first), edition_first, NA_integer_),
           edition_last = ifelse(is.finite(edition_last), edition_last, NA_integer_))
  vals <- w |> select(vid, run, d, column, value) |> pivot_wider(names_from = column, values_from = value)
  meta |> left_join(vals, by = c("vid", "run", "d")) |> left_join(vkey, by = "vid") |>
    rename(registration_no = vid, valid_from = d, valid_to = e) |>
    relocate(vessel_id, registration_no, valid_from, valid_to) |> select(-run) |>
    arrange(registration_no, valid_from)
}
TABLES <- c("vessel_hist", "vessel_identification_hist", "vessel_measurement_hist", "vessel_engines_hist",
            "vessel_operational_hist", "vessel_fishery_hist")
out <- setNames(lapply(TABLES, assemble), TABLES)

## The types of ship as printed, to the schema's codes ----------------------------------------------------------------
uc <- read_parquet(fd_raw("oracle", "vessel", "usage_category.parquet")) |>
  transmute(usage_category_no = as.integer(usage_category_no), key = key_txt(name))
pairs <- evi |> filter(source == "vessel:vessel_hist", column %in% c("usage_category", "usage_category_no")) |>
  select(record, column, value) |> pivot_wider(names_from = column, values_from = value, values_fn = function(v) v[1]) |>
  filter(!is.na(usage_category), !is.na(usage_category_no)) |> count(key = key_txt(usage_category), no = as.integer(usage_category_no)) |>
  group_by(key) |> slice_max(n, n = 1, with_ties = FALSE) |> ungroup()
# third: the code the `vessel` schema gives the same hull on the edition's 1 January, where half or more agree
# (SKEMMTISKIP, the pleasure ship, is in neither the code table nor the schema's own texts)
same <- reg |> filter(edition != 2020, !is.na(ship_type)) |> transmute(vid, d = ed_date(edition), key = key_txt(ship_type)) |>
  inner_join(evi |> filter(source == "vessel:vessel_hist", column == "usage_category_no") |>
               transmute(vid, t1, t2, no = as.integer(value)), by = "vid", relationship = "many-to-many") |>
  filter(t1 <= d, is.na(t2) | t2 >= d) |> count(key, no) |> group_by(key) |> mutate(share = n / sum(n)) |>
  slice_max(n, n = 1, with_ties = FALSE) |> ungroup() |> filter(share >= 0.5)
# first: the maintainer's reading of types no table maps (overrides/usage_category_printed_reviewed.csv)
rvu <- utils::read.csv("overrides/usage_category_printed_reviewed.csv", colClasses = "character", encoding = "UTF-8") |>
  transmute(key = key_txt(printed), no_review = as.integer(usage_category_no), review = paste0("reviewed (", reviewer, ", ", date, ")"))
usage_category_printed <- reg |> filter(!is.na(ship_type)) |> count(printed = ship_type, name = "entries") |>
  mutate(key = key_txt(printed)) |>
  left_join(rvu, by = "key") |>
  left_join(uc |> rename(no_code = usage_category_no), by = "key") |>
  left_join(pairs |> select(key, no_pair = no), by = "key") |>
  left_join(same |> select(key, no_same = no, share), by = "key") |>
  mutate(usage_category_no = coalesce(no_review, no_code, no_pair, no_same),
         basis = case_when(!is.na(no_review) ~ review, !is.na(no_code) ~ "the code table's name", !is.na(no_pair) ~ "the `vessel` schema's own pairs",
                           !is.na(no_same) ~ paste0("the `vessel` schema's code for the same hulls (", round(100 * share), " %)"),
                           TRUE ~ "none")) |>
  select(printed, entries, usage_category_no, basis) |> arrange(desc(entries))
ukey <- usage_category_printed |> transmute(key = key_txt(printed), uno = usage_category_no) |> distinct(key, .keep_all = TRUE)
out$vessel_hist <- out$vessel_hist |>
  mutate(usage_category_no = ukey$uno[match(key_txt(usage_category), ukey$key)]) |>
  relocate(usage_category_no, .after = usage_category)
message("types of ship: ", sum(usage_category_printed$entries[usage_category_printed$basis != "none"]), " of ",
        sum(usage_category_printed$entries), " printed types map to a code")

## Owners: a set at a time, from the PDFs (2004-2021), else the `vessel` schema's and the scrape's ---------------------
kt <- bind_rows(evi |> filter(table == "vessel_owners_hist", column %in% c("name", "national_identity_no"),
                              source %in% c("vessel:vessel_owners_hist", "kvoti.skipaskra_siglo", "samgongustofa:2022-12-28")) |>
                  select(vid, record, source, column, value) |>
                  pivot_wider(names_from = column, values_from = value, values_fn = function(v) v[1])) |>
  filter(!is.na(name), !is.na(national_identity_no)) |>
  transmute(vid, key = key_txt(name), kt = pad_kt(national_identity_no), kt_source = source) |>
  distinct(vid, key, kt, .keep_all = TRUE) |> group_by(vid, key) |> slice(1) |> ungroup()
own_pdf <- reg |> filter(edition != 2020, !is.na(owner)) |>
  transmute(vid, edition, name = owner, address, postal_no = postcode, town, key = key_txt(owner), akey = key_txt(address)) |>
  arrange(vid, edition) |> group_by(vid) |>
  mutate(g = cumsum(is.na(lag(key)) | key != lag(key) | coalesce(akey != lag(akey), TRUE) |
                      lag(edition) != c(NA, EDITIONS)[match(edition, EDITIONS)])) |>      # an edition missed opens a new row
  group_by(vid, g) |>
  summarise(valid_from = ed_date(min(edition)), valid_to = ed_next(max(edition)), name = last(name), address = last(address),
            postal_no = last(postal_no), town = last(town), key = last(key),
            source = paste0("pdf:", min(edition), if (max(edition) > min(edition)) paste0("-", max(edition))),
            edition_first = min(edition), edition_last = max(edition), .groups = "drop") |>
  mutate(window_from = "annual", percentage = NA_real_)
own_v <- evi |> filter(source == "vessel:vessel_owners_hist", table == "vessel_owners_hist") |>
  select(vid, record, column, value, t1, t2) |>
  pivot_wider(names_from = column, values_from = value, values_fn = function(v) v[1]) |>
  transmute(vid, valid_from = coalesce(t1, as.Date("1900-01-01")), valid_to = pmin(coalesce(t2 + 1, END), END), name, address,
            postal_no, percentage = suppressWarnings(as.numeric(percentage)), key = key_txt(name), source = "vessel:vessel_owners_hist",
            window_from = "dated", kt0 = pad_kt(national_identity_no))
own_s <- evi |> filter(source == "samgongustofa:2022-12-28", table == "vessel_owners_hist") |>
  select(vid, record, column, value) |> pivot_wider(names_from = column, values_from = value, values_fn = function(v) v[1]) |>
  transmute(vid, valid_from = as.Date("2022-12-28"), valid_to = END, name, percentage = suppressWarnings(as.numeric(percentage)),
            key = key_txt(name), source = "samgongustofa:2022-12-28", window_from = "annual", kt0 = pad_kt(national_identity_no))
# before 2004 and from 2022: the `vessel` schema's owners; from 2022-12-28 the scrape where the schema has no change since
cut_v <- function(d, lo, hi) d |> filter(valid_from < hi, valid_to > lo) |> mutate(valid_from = pmax(valid_from, lo), valid_to = pmin(valid_to, hi))
v_late <- own_v |> filter(valid_from >= as.Date("2022-01-01"))
k22 <- own_pdf |> filter(edition_last == 2022) |> select(vid, key)
s_use <- own_s |> filter(!vid %in% v_late$vid) |> group_by(vid) |>
  filter(!setequal(key, k22$key[k22$vid == vid[1]])) |> ungroup()           # the scrape takes over only where it differs
first_late <- bind_rows(v_late, s_use) |> group_by(vid) |> summarise(f = min(valid_from))
pdf22 <- own_pdf |> filter(edition_last == 2022) |> left_join(first_late, by = "vid") |>
  mutate(valid_to = coalesce(pmin(valid_to, f), valid_to)) |> select(-f)
vessel_owners_hist <- bind_rows(
  cut_v(own_v, as.Date("1900-01-01"), as.Date("2004-01-01")),
  own_pdf |> filter(edition_last < 2022), pdf22,
  v_late, s_use) |>
  filter(valid_from < valid_to) |>
  left_join(kt, by = c("vid", "key")) |>
  mutate(national_identity_no = coalesce(kt0, kt),
         national_identity_no_source = case_when(!is.na(kt0) ~ source, !is.na(kt) ~ paste0("by name: ", kt_source)),
         basis = if_else(is.na(kt0) & !is.na(kt), "recorded; kennitala matched by name", "recorded")) |>
  select(-kt, -kt0, -kt_source, -g, -key)
# while on the register only
vessel_owners_hist <- vessel_owners_hist |>
  inner_join(registered |> select(vid, p_from = valid_from, p_to = valid_to), by = "vid", relationship = "many-to-many") |>
  filter(valid_from < p_to, valid_to > p_from) |>
  mutate(valid_from = pmax(valid_from, p_from), valid_to = pmin(valid_to, p_to)) |> select(-p_from, -p_to) |>
  left_join(vkey, by = "vid") |> rename(registration_no = vid) |> relocate(vessel_id, registration_no) |>
  arrange(registration_no, valid_from)

## MMSI: the archive's windows (plan 028 §4.3), its defaults no dates ----------------------------------------------------
vessel_mmsi_hist <- read_parquet(fd_curated("vessel", "mmsi.parquet")) |>
  filter(!is.na(vid), vid >= 1, vid <= 9999, !(vid >= 3700 & vid <= 4999)) |>
  transmute(registration_no = as.integer(vid), mmsi_no = mmsi, call_sign = cs,
            valid_from = mmsi_t1, valid_to = if_else(!is.na(mmsi_t2) & mmsi_t2 < END, mmsi_t2, END),
            window_from = if_else(mmsi_t1 == as.Date("2007-06-01"), "archive_start", "dated"),
            window_to = case_when(is.na(mmsi_t2) | mmsi_t2 >= as.Date("2028-12-24") ~ "open", mmsi_t2 >= END ~ "open", TRUE ~ "dated"),
            source = "mmsi", window_basis, basis = "recorded", note) |>
  filter(is.na(valid_from) | valid_from < END) |>
  left_join(vkey |> rename(registration_no = vid), by = "registration_no") |> relocate(vessel_id) |> arrange(registration_no, valid_from)

## annual_call_sign as a view of the history (plan 028 §4.4): the call sign on each 1 January. The STK key still reads
## staging/skipaskra/annual_call_sign.parquet; the switch belongs to the key's redo (TODO 25)
annual_call_sign <- tidyr::crossing(year = 2004:2023, out$vessel_identification_hist |> filter(!is.na(call_sign)) |>
                                      select(registration_no, valid_from, valid_to, call_sign)) |>
  filter(valid_from <= yd(year), yd(year) < valid_to) |>
  transmute(year = as.integer(year), vid = registration_no, cs = call_sign, form = "history") |> arrange(year, vid)

# Checks ----------------------------------------------------------------------------------------------------------------
## each table's rows tile the hull's runs without overlap -----------------------------------------------------------------
for (tab in TABLES) {
  o <- out[[tab]] |> arrange(registration_no, valid_from) |> group_by(registration_no) |>
    summarise(overlap = sum(valid_from < lag(valid_to), na.rm = TRUE), .groups = "drop")
  stopifnot(sum(o$overlap) == 0, all(out[[tab]]$valid_from < out[[tab]]$valid_to))
}
stopifnot(!anyNA(decision$status), all(!is.na(decision$rule[decision$status %in% c("resolved", "open", "reviewed")])))
cov <- sapply(TABLES, function(tab) {
  r <- out[[tab]] |> group_by(registration_no) |> summarise(days = sum(as.numeric(valid_to - valid_from)))
  p <- registered |> filter(vid %in% r$registration_no) |> group_by(vid) |> summarise(days = sum(as.numeric(valid_to - valid_from)))
  round(100 * sum(r$days) / sum(p$days), 1)
})
message("rows cover the registered life of the hulls they describe (%): ", paste(names(cov), cov, collapse = "; "))
## each PDF value against the history on its edition's 1 January ----------------------------------------------------------
pv <- cm |> filter(grepl("^pdf:", source), edition != 2020) |> select(vid, table, column, edition, cmp, num, dec) |> mutate(d = ed_date(edition))
hv <- decision |> select(vid, table, column, valid_from, valid_to, hval = value, status, rule) |>
  inner_join(cm |> distinct(table, column, value, hcmp = cmp, hnum = num, hdec = dec), by = c("table", "column", "hval" = "value"), relationship = "many-to-many")
pc <- pv |> left_join(hv, by = c("vid", "table", "column"), relationship = "many-to-many") |>
  mutate(cover = !is.na(valid_from) & valid_from <= d & d < valid_to) |>
  group_by(vid, table, column, edition) |>
  summarise(held = any(cover), same = any(cover & agree_v(cmp, num, dec, hcmp, hnum, hdec)),
            rule = paste(unique(na.omit(rule[cover])), collapse = ","), .groups = "drop")
message("PDF values on the history: ", sum(pc$same), " of ", nrow(pc), " the same on their 1 January; ",
        sum(!pc$held), " outside the registered life; ", sum(pc$held & !pc$same), " other (", paste(names(table(pc$rule[pc$held & !pc$same])), table(pc$rule[pc$held & !pc$same]), collapse = ", "), ")")
## the call sign of each 1 January against annual_call_sign (2007-2022) ----------------------------------------------------
acs <- read_parquet(fd_staging("skipaskra", "annual_call_sign.parquet"))
cs_h <- out$vessel_identification_hist |> filter(!is.na(call_sign)) |> select(registration_no, valid_from, valid_to, call_sign)
yrs <- intersect(unique(acs$year), 2007:2022)
cmpcs <- tidyr::crossing(year = yrs, cs_h) |> filter(valid_from <= yd(year), yd(year) < valid_to) |>
  transmute(year, vid = registration_no, cs_hist = call_sign) |>
  full_join(acs |> filter(year %in% yrs) |> transmute(year, vid, cs_acs = cs, form), by = c("year", "vid"))
message("call signs by 1 January, ", min(yrs), "-", max(yrs), ": ", sum(key_txt(cmpcs$cs_hist) == key_txt(cmpcs$cs_acs), na.rm = TRUE),
        " equal to annual_call_sign, ", sum(is.na(cmpcs$cs_acs)), " only here, ", sum(is.na(cmpcs$cs_hist)), " only there, ",
        sum(!is.na(cmpcs$cs_hist) & !is.na(cmpcs$cs_acs) & key_txt(cmpcs$cs_hist) != key_txt(cmpcs$cs_acs)), " different")
print(decision |> count(table, status, rule) |> pivot_wider(names_from = status, values_from = n, values_fill = 0) |>
        knitr::kable(caption = "decision: column stretches by table, status and rule"))

# Write -----------------------------------------------------------------------------------------------------------------
inputs <- c(fd_curated("vessel", "skipaskra", "evidence.parquet"), fd_curated("vessel", "mmsi.parquet"),
            file.path(fd_staging("skipaskra"), c("register.parquet", "event.parquet", "annual_call_sign.parquet")),
            fd_staging("hreidar", "vessel_year.parquet"),
            fd_raw("oracle", "vessel", c("vessel.parquet", "usage_category.parquet")), "overrides/skipaskra_reviewed.csv",
            "overrides/usage_category_printed_reviewed.csv")
w <- function(d, name) write_curated(d, fd_curated("vessel", "skipaskra", paste0(name, ".parquet")), inputs = inputs)
for (tab in TABLES) w(out[[tab]], tab)
w(vessel_owners_hist, "vessel_owners_hist")
w(vessel_mmsi_hist, "vessel_mmsi_hist")
w(vessel_event |> left_join(vkey, by = "vid") |> rename(registration_no = vid) |> relocate(vessel_id), "vessel_event")
w(registered |> rename(registration_no = vid), "registered")
w(usage_category_printed, "usage_category_printed")
w(annual_call_sign, "annual_call_sign")
w(decision |> rename(registration_no = vid), "decision")
