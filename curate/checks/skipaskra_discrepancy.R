# The annual ship register checked: inside each edition, between editions, against the other witnesses, and against
# landings and logbooks (plan 028 step 4).
# Side: once (register history). See plan 014; plan 028 §5; decision 132.
#
# Input:  staging/skipaskra/{register,event,index_list,summary}.parquet                the PDFs as read (decision 130)
#         curated/vessel/skipaskra/evidence.parquet                                     every witness's values (step 3)
#         raw/oracle/kvoti/{veidileyfi,strandveidileyfi_v,grasleppusaga,dragnot_leyfi,tegund_veidileyfis}.parquet
#         curated/landing/{landings,catch}.parquet, curated/logbook/trip.parquet       the activity
# Output: curated/check/skipaskra_discrepancy.parquet - one row per finding
#         curated/check/skipaskra_agreement.parquet   - each witness against the PDFs (and the 2022-12-28 scrape), by
#                                                       edition and column: values compared, agreeing, agreeing in time
#
# A check only finds; the decision model (plan 028 §6, step 5) settles. Until it runs, every finding's `status` is
# "unsettled", and `rule` and `value_chosen` are empty.
#
# - `kind`: parse (a value outside the key's vocabulary, a reading fault or a print one, for D0 to tell), edition
#   (inside one edition), between_editions, witness, activity.
# - `value`, `source`: the value checked and where it is printed; `value_other`, `source_other`: what it is checked
#   against (a printed total, the hull's usual value, another witness's values, days of landings).
# - An edition speaks for its 1 January. The 2020 edition reprints 2019's register (decision 130), so it is left out
#   where a check reads change between editions, and its lists are read with 2021's.
# - Numbers agree when equal at the coarser of the two precisions, the finer rounded or truncated. Precision is read
#   off each value as stored, which keeps no trailing zero: some editions print GRT and NT to one decimal or none, so a
#   PDF value is not taken to have two.
# - Text is compared on its letters and digits, upper case and Unicode-composed, so a word wrapped across a cell
#   ("FÁSKRÚÐSFJÖRÐU R") or a stop ("HF.") is no disagreement. Hull materials are compared as sets ("EIK OG FURA" =
#   "FURA OG EIK"), classification societies by body (SI and SS are the maritime authority; NG, DNV GL, follows NV).
# - Not checked here: AIS (plan 028 §5.4, later), the trend tables of registrations and deregistrations across editions
#   (their year labels shift between editions; each edition's are checked against its own lists), changes the editions
#   do not show (step 5 dates changes from the ufs journals), and owners' addresses, which the sources write in
#   different grammatical cases and with or without postcode and town.
# - The `vessel` schema's back-filled engine rows (before 2023-12-19) hold the engine type ("D") where the make belongs;
#   its one-letter makes are left out of the comparison and counted.
# - The MMSI archive's default window (from 2007-06-01, to 2028-12-24) is no date: such a start opens nothing, and such
#   an end is open. vids above 9999 are no register numbers and are left out of the MMSI and activity checks.

library(dplyr)
library(tidyr)
library(nanoparquet)
library(DBI)
library(duckdb)

NEAR_DAYS   <- 183                        # a witness's change within half a year of an edition dates it; it is no other value
LICENCE_END <- as.Date("2020-07-22")      # kvoti's licence tables stop here (plan 028 ask c)
RECREATIONAL <- c("38", "39", "42")       # frístundaveiðar: licences a passenger or pleasure boat may hold
ed_date <- function(e) {                  # paste0() of an empty vector still returns one string
  out <- rep(as.Date(NA), length(e)); ok <- !is.na(e)
  if (any(ok)) out[ok] <- as.Date(paste0(e[ok], "-01-01"))
  out
}
yr <- function(d) as.integer(format(d, "%Y"))

key_txt <- function(x) gsub("[^\\p{L}\\p{N}]", "", stringi::stri_trans_nfc(toupper(x)), perl = TRUE)
key_material <- function(x) {
  p <- strsplit(gsub(",", " OG ", toupper(ifelse(is.na(x), "", x))), "\\s+OG\\s+")
  k <- vapply(p, function(w) paste(sort(key_txt(w[w != ""])), collapse = "+"), "")
  ifelse(is.na(x) | k == "", NA, k)
}
key_class <- function(x) {
  k <- key_txt(x)
  case_when(k %in% c("SI", "SS") | grepl("^SAMG|^SIGL", k) ~ "AUTHORITY",
            k %in% c("NV", "NG", "DNV", "DNVGL") ~ "DNV",
            TRUE ~ k)
}
dec_of <- function(v) ifelse(grepl("\\.", v), nchar(sub("^[^.]*\\.", "", v)), 0L)
num_agree <- function(a, da, b, db) {
  s <- 10^pmin(da, db)
  fine <- ifelse(da >= db, a, b); coarse <- ifelse(da >= db, b, a)
  abs(round(fine * s) - round(coarse * s)) < 0.5 | abs(floor(fine * s + 1e-7) - round(coarse * s)) < 0.5
}
is_fishing <- function(type) grepl("FISKI|TOGAR|NÓTAVEIÐI|HVALVEIÐI", key_txt(type))
imo_ok <- function(x) {
  x <- as.character(x); ok <- !is.na(x) & grepl("^[0-9]{7}$", x)
  d <- matrix(as.integer(unlist(strsplit(ifelse(ok, x, "0000000"), ""))), ncol = 7, byrow = TRUE)
  ok & as.vector(d[, 1:6, drop = FALSE] %*% (7:2)) %% 10 == d[, 7]
}
fnd <- function(check, kind, vid = NA, edition = NA, date = NA, table = NA, column = NA, value = NA, source = NA,
                value_other = NA, source_other = NA, detail = NA) {
  tibble(check, kind, vid = as.integer(vid), edition = as.integer(edition), date = as.Date(date),
         table = as.character(table), column = as.character(column), value = as.character(value),
         source = as.character(source), value_other = as.character(value_other),
         source_other = as.character(source_other), detail = as.character(detail))
}
ora <- function(schema, table) read_parquet(fd_raw("oracle", schema, paste0(table, ".parquet")))

reg  <- read_parquet(fd_staging("skipaskra", "register.parquet")) |>
  mutate(by = suppressWarnings(as.integer(built_year)), ey = suppressWarnings(as.integer(engine_year)),
         by = ifelse(by == 0, NA, by), ey = ifelse(ey == 0, NA, ey), src = paste0("pdf:", edition))
evt  <- read_parquet(fd_staging("skipaskra", "event.parquet")) |> filter(!is.na(vid))
il   <- read_parquet(fd_staging("skipaskra", "index_list.parquet"))
summ <- read_parquet(fd_staging("skipaskra", "summary.parquet"))
evi  <- read_parquet(fd_curated("vessel", "skipaskra", "evidence.parquet"))
pres <- reg |> distinct(vid, edition)
in_ed <- function(v, e) paste(v, e) %in% paste(pres$vid, pres$edition)
series <- reg |> filter(edition != 2020)                     # 2020 reprints 2019
F <- list()

# 5.1 Inside an edition ------------------------------------------------------------------------------------------------
## Entries against the edition's own trend table ------------------------------------------------------------------------
fleet <- summ |>
  filter(table %in% c("Fjöldi og stærð", "Fjöldi og stærð í brúttótonnum (BT)", "janúar hvers árs"), !is.na(value)) |>
  mutate(measure = case_when(
    label == "Þilfarsskip" ~ "n_decked", label == "Opnir bátar" ~ "n_open", label == "Heildarfjöldi" ~ "n_total",
    label %in% c("Heildarbrúttótonn", "Heildar brúttótonnatala") | (label == "BT" & occurrence == 3) ~ "gt_total",
    label %in% c("BT", "Brúttótonn", "Brúttótonn (BT)") & occurrence == 1 ~ "gt_decked",
    label %in% c("BT", "Brúttótonn", "Brúttótonn (BT)") & occurrence == 2 ~ "gt_open")) |>
  filter(!is.na(measure)) |>
  distinct(edition, table, measure, year, value)
# the edition's own column; 2019 labels its last column 2018 (plan 028 §2.6), so an edition without its year takes its last
own <- fleet |> group_by(edition) |> filter(year == edition | (!any(year == edition) & year == max(year))) |> ungroup()
parsed <- reg |>
  group_by(edition) |>
  summarise(n_decked = sum(section == "decked"), n_open = sum(section == "open"), n_total = n(),
            gt_decked = sum(gt[section == "decked"], na.rm = TRUE), gt_open = sum(gt[section == "open"], na.rm = TRUE),
            gt_total = sum(gt, na.rm = TRUE), gt_na = sum(is.na(gt)), .groups = "drop") |>
  pivot_longer(n_decked:gt_total, names_to = "measure", values_to = "parsed")
tot <- own |> inner_join(parsed, by = c("edition", "measure")) |>
  filter(ifelse(grepl("^n_", measure), parsed != value, abs(parsed - value) > 1))
F$total <- with(tot, fnd("total", "edition", NA, edition, ed_date(edition), "register", measure, round(parsed, 2),
                         paste0("pdf:", edition, " entries"), value, paste0("pdf:", edition, " table '", table, "' ", year),
                         ifelse(grepl("^gt", measure) & gt_na > 0, paste(gt_na, "entries print no GT"), NA)))
# the table's own sums
sums <- own |> select(edition, table, measure, value) |>
  pivot_wider(names_from = measure, values_from = value, values_fn = function(v) v[1]) |>
  mutate(n_off = n_decked + n_open - n_total, gt_off = gt_decked + gt_open - gt_total)
s1 <- sums |> filter(!is.na(n_off), n_off != 0)
s2 <- sums |> filter(!is.na(gt_off), abs(gt_off) > 1)
F$table_sum <- bind_rows(
  with(s1, fnd("table_sum", "edition", NA, edition, ed_date(edition), "summary", "n_total", n_decked + n_open,
               paste0("pdf:", edition, " table '", table, "' decked + open"), n_total, paste0("pdf:", edition, " table '", table, "' total"))),
  with(s2, fnd("table_sum", "edition", NA, edition, ed_date(edition), "summary", "gt_total", gt_decked + gt_open,
               paste0("pdf:", edition, " table '", table, "' decked + open"), gt_total, paste0("pdf:", edition, " table '", table, "' total"))))

## The register against its own lists (2004-2013) ----------------------------------------------------------------------
nl <- il |> filter(list == "number", !is.na(vid)) |> distinct(edition, vid, .keep_all = TRUE)
en <- reg |> filter(edition %in% nl$edition) |> select(edition, vid, name, district, call_sign)
x1 <- nl |> anti_join(en, by = c("edition", "vid"))
x2 <- en |> anti_join(nl, by = c("edition", "vid"))
# a name in another edition dates the list: the hull's name before or after
names_ed <- reg |> transmute(vid, e = edition, k = key_txt(name))
when_named <- function(v, k, e) {
  m <- tibble(i = seq_along(v), vid = v, k = k, e0 = e) |> inner_join(names_ed, by = c("vid", "k"), relationship = "many-to-many")
  before <- unique(m$i[m$e < m$e0]); after <- unique(m$i[m$e > m$e0])
  case_when(seq_along(v) %in% after & !seq_along(v) %in% before ~ "the hull's name in a later edition",
            seq_along(v) %in% before & !seq_along(v) %in% after ~ "the hull's name in an earlier edition",
            seq_along(v) %in% before ~ "the hull's name in earlier and later editions",
            TRUE ~ NA_character_)
}
x3 <- nl |> inner_join(en, by = c("edition", "vid"), suffix = c("_list", "_reg")) |>
  filter((!is.na(name_list) & key_txt(name_list) != key_txt(name_reg)) |
           (!is.na(district_list) & !is.na(district_reg) & key_txt(district_list) != key_txt(district_reg))) |>
  mutate(named = when_named(vid, key_txt(name_list), edition))
F$number_list <- bind_rows(
  with(x1, fnd("number_list", "edition", vid, edition, ed_date(edition), "register", "vid", NA, paste0("pdf:", edition),
               name, paste0("pdf:", edition, " number list"), "in the number list, no entry in the register")),
  with(x2, fnd("number_list", "edition", vid, edition, ed_date(edition), "register", "vid", name, paste0("pdf:", edition),
               NA, paste0("pdf:", edition, " number list"), "an entry in the register, not in the number list")),
  with(x3, fnd("number_list", "edition", vid, edition, ed_date(edition), "register", "name",
               paste(name_reg, district_reg), paste0("pdf:", edition), paste(name_list, district_list),
               paste0("pdf:", edition, " number list"),
               ifelse(is.na(named), "name or district differs", paste0("name or district differs; the list's name is ", named)))))
cl <- il |> filter(list == "call_sign") |> mutate(k = key_txt(call_sign))
held <- cl |> filter(!is.na(name))
rc <- reg |> filter(edition %in% cl$edition, !is.na(call_sign)) |> mutate(k = key_txt(call_sign)) |>
  select(edition, vid, k, call_sign, name)
y1 <- held |> anti_join(rc, by = c("edition", "k"))
y2 <- rc |> anti_join(held, by = c("edition", "k")) |>
  mutate(listed = ifelse(paste(edition, k) %in% paste(cl$edition, cl$k), "listed as free", "not in the call-sign list"))
y3 <- held |> inner_join(rc, by = c("edition", "k"), suffix = c("_list", "_reg")) |>
  filter(key_txt(name_list) != key_txt(name_reg))
F$callsign_list <- bind_rows(
  with(y1, fnd("callsign_list", "edition", NA, edition, ed_date(edition), "vessel_identification_hist", "call_sign",
               NA, paste0("pdf:", edition), paste(call_sign, name), paste0("pdf:", edition, " call-sign list"),
               "held in the call-sign list, on no entry")),
  with(y2, fnd("callsign_list", "edition", vid, edition, ed_date(edition), "vessel_identification_hist", "call_sign",
               call_sign, paste0("pdf:", edition), NA, paste0("pdf:", edition, " call-sign list"), listed)),
  with(y3, fnd("callsign_list", "edition", vid_reg, edition, ed_date(edition), "vessel_identification_hist", "call_sign",
               paste(call_sign_reg, name_reg), paste0("pdf:", edition), paste(call_sign_list, name_list),
               paste0("pdf:", edition, " call-sign list"), "the list names another ship")))

## Recomputed aggregates: decked ships by inspection body, and the year's lists against the trend tables ----------------
# "Skoðunaraðili" counts every ship by the body that inspects it (Siglingastofnun's few, the inspection firms the rest),
# so only the societies compare with the register's column, and its total with all entries. "Flokkunarfélag" (2004)
# counts the classed ships.
cls <- summ |>
  filter(table %in% c("Skoðunaraðili", "Flokkunarfélag"), year == edition, !is.na(value)) |>
  mutate(code = case_when(grepl("\\(BV", label) ~ "BV", grepl("\\(NV\\)", label) ~ "NV", grepl("\\(GL\\)", label) ~ "GL",
                          grepl("\\(LR\\)", label) ~ "LR",
                          label == "Samtals" & table == "Skoðunaraðili" ~ "all entries",
                          label == "Samtals" ~ "classed")) |>
  filter(!is.na(code)) |> distinct(edition, table, code, value)
cnt <- bind_rows(reg |> filter(section == "decked") |> count(edition, code = class_society),
                 reg |> count(edition) |> mutate(code = "all entries"),
                 reg |> filter(section == "decked", !class_society %in% c("SI", "SS", NA)) |> count(edition) |> mutate(code = "classed"))
z <- cls |> left_join(cnt, by = c("edition", "code")) |> mutate(n = coalesce(n, 0L)) |> filter(n != value)
F$aggregate_class <- with(z, fnd("aggregate_class", "edition", NA, edition, ed_date(edition), "vessel_hist",
                                 "classification_society", paste(code, n), paste0("pdf:", edition, " entries"),
                                 value, paste0("pdf:", edition, " table '", table, "'")))
# The trend tables label a year's registrations by the year or by the next edition, and 2004-2005 print deregistrations
# under "Nýskráningar"; a list's count must be one of the edition's figures for the year or the year before
lists_n <- evt |>
  mutate(section = coalesce(section, ifelse(deck_code %in% "O", "open", NA))) |>
  group_by(edition, kind) |>
  summarise(n_decked = sum(section %in% "decked"), n_open = sum(section %in% "open"), n_total = n(), .groups = "drop") |>
  pivot_longer(n_decked:n_total, names_to = "measure", values_to = "n")
evtab <- summ |>
  filter(grepl("^Nýskrán|^Afskrán", table), year %in% c(edition, edition - 1), !is.na(value)) |>
  mutate(measure = case_when(label == "Þilfarsskip" ~ "n_decked", label == "Opnir bátar" ~ "n_open",
                             label == "Heildarfjöldi" ~ "n_total"),
         kind = ifelse(grepl("^Afskrán", table) | (table == "Nýskráningar" & occurrence == 2), "deregistration",
                       "registration")) |>
  filter(!is.na(measure))
ag <- lists_n |>
  inner_join(evtab |> group_by(edition, kind, measure) |>
               summarise(printed = paste(sort(unique(value)), collapse = "/"), hit = list(unique(value)), .groups = "drop"),
             by = c("edition", "kind", "measure")) |>
  filter(!mapply(function(n, h) n %in% h, n, hit)) |>
  filter(measure == "n_total" | n > 0)          # a list without its decked/open split counts all under n_total
F$aggregate_events <- with(ag, fnd("aggregate_events", "edition", NA, edition, ed_date(edition), "vessel_event",
                                   paste(kind, measure), n, paste0("pdf_event:", edition, " list rows"), printed,
                                   paste0("pdf:", edition, " trend table, the year or the year before")))

## The key's rules -----------------------------------------------------------------------------------------------------
r1 <- reg |> filter(!is.na(call_sign), !is.na(loa), loa < 15)
r2 <- reg |> filter(!is.na(imo), !imo_ok(imo))
has_imo <- reg |> group_by(edition) |> summarise(any_imo = any(!is.na(imo)))
r3 <- reg |> semi_join(has_imo |> filter(any_imo), by = "edition") |>
  filter(section == "decked", !is.na(length_reg), length_reg > 24, is.na(imo))
r4 <- reg |> filter(!is.na(length_reg), length_reg < 15, !is.na(gt), !is.na(breadth)) |>
  mutate(p = 0.031 * length_reg^2 * breadth) |> filter(abs(gt - p) > 0.01 * p + 0.01)
r5 <- reg |> filter(!is.na(length_reg), length_reg < 15, !is.na(gt), !is.na(nt)) |>
  filter(abs(nt - 0.3 * gt) > 0.003 * gt + 0.011)
r6 <- bind_rows(reg |> filter(!is.na(by), by > edition) |> mutate(column = "construction_year", v = by),
                reg |> filter(!is.na(ey), ey > edition) |> mutate(column = "year", v = ey))
F$rule <- bind_rows(
  with(r1, fnd("rule_callsign_short", "edition", vid, edition, ed_date(edition), "vessel_identification_hist",
               "call_sign", call_sign, src, loa, src, "a call sign below 15 m length overall")),
  with(r2, fnd("rule_imo_check_digit", "edition", vid, edition, ed_date(edition), "vessel_hist", "imo_no", imo, src,
               NA, NA, "the IMO number fails its check digit")),
  with(r3, fnd("rule_imo_missing", "edition", vid, edition, ed_date(edition), "vessel_hist", "imo_no", NA, src,
               length_reg, src, "no IMO number above 24 m registered length")),
  with(r4, fnd("rule_gt_formula", "edition", vid, edition, ed_date(edition), "vessel_measurement_hist",
               "brutto_weight_tons", gt, src, round(p, 2), src, "GT off 0.031 L² B below 15 m (L registered length)")),
  with(r5, fnd("rule_nt_formula", "edition", vid, edition, ed_date(edition), "vessel_measurement_hist",
               "netto_weight_tons", nt, src, round(0.3 * gt, 2), src, "NT off 0.3 GT below 15 m")),
  with(r6, fnd("rule_year_after_edition", "edition", vid, edition, ed_date(edition),
               ifelse(column == "year", "vessel_engines_hist", "vessel_hist"), column, v, src, edition, src,
               "a year after the edition")))

## Vocabulary: a value outside the key's lists ---------------------------------------------------------------------------
mat_keys <- key_txt(strsplit(sub("^.*\\(\\^\\| \\)\\(", "", sub("\\)\\$$", "", MATERIAL_RE)), "\\|")[[1]])
mat_re <- paste0("(", paste(mat_keys, collapse = "|"), ")$")
v1 <- reg |> filter(!is.na(region_acronym), !sub("[.]$", "", region_acronym) %in% DISTRICTS) |>   # "EA." is printed so
  mutate(column = "region_acronym", v = region_acronym)
v2 <- reg |> filter(!is.na(class_society), !class_society %in% c(CLASS_SET, "NG")) |> mutate(column = "classification_society", v = class_society)
v3 <- reg |> filter(!is.na(hull_material), !grepl(mat_re, key_txt(hull_material))) |> mutate(column = "hull_material", v = hull_material)
v4 <- reg |> filter(!is.na(ship_type), !grepl(sub("SKIP|", "SKIP|TOGARI|", SHIPTYPE_RE, fixed = TRUE), key_txt(ship_type))) |>
  mutate(column = "usage_category", v = ship_type)
v5 <- reg |> filter(!is.na(call_sign), !grepl(CALLSIGN_RE, call_sign)) |> mutate(column = "call_sign", v = call_sign)
F$vocabulary <- with(bind_rows(v1, v2, v3, v4, v5),
                     fnd("vocabulary", "parse", vid, edition, ed_date(edition),
                         ifelse(column %in% c("region_acronym", "call_sign"), "vessel_identification_hist", "vessel_hist"),
                         column, v, src, NA, NA, "not in the key's list"))

## Uniqueness in an edition ----------------------------------------------------------------------------------------------
u1 <- reg |> filter(!is.na(call_sign)) |> group_by(edition, call_sign) |> filter(n_distinct(vid) > 1) |>
  mutate(others = paste(sort(unique(vid)), collapse = ", ")) |> ungroup()
u2 <- reg |> filter(!is.na(region_acronym), !is.na(region_no)) |> group_by(edition, region_acronym, region_no) |>
  filter(n_distinct(vid) > 1) |> mutate(others = paste(sort(unique(vid)), collapse = ", ")) |> ungroup()
F$unique <- bind_rows(
  with(u1, fnd("unique_call_sign", "edition", vid, edition, ed_date(edition), "vessel_identification_hist", "call_sign",
               call_sign, src, others, src, "one call sign on several hulls in one edition")),
  with(u2, fnd("unique_district", "edition", vid, edition, ed_date(edition), "vessel_identification_hist", "region_no",
               paste0(region_acronym, region_no), src, others, src, "one district number on several hulls in one edition")))

# 5.2 Between editions -------------------------------------------------------------------------------------------------
## Identical editions ---------------------------------------------------------------------------------------------------
fields <- c("name", "district", "class_society", "call_sign", "home_port", "previous_name", "owner", "address",
            "built_place", "built_year", "yard", "ship_type", "hull_material", "engine_make", "engine_year", "engine_kw",
            "imo", "grt", "gt", "nt", "length_reg", "breadth", "depth", "loa")
sig <- reg |> select(edition, vid) |> mutate(sig = do.call(paste, c(lapply(fields, function(f) as.character(reg[[f]])), sep = "|")))
eds <- sort(unique(reg$edition))
idn <- bind_rows(lapply(seq_along(eds)[-1], function(i) {
  a <- sig |> filter(edition == eds[i - 1]); b <- sig |> filter(edition == eds[i])
  tibble(edition = eds[i], prev = eds[i - 1], n = nrow(b), same = sum(paste(b$vid, b$sig) %in% paste(a$vid, a$sig)))
})) |> mutate(share = same / n)
F$identical <- with(idn |> filter(share >= 0.95),
                    fnd("identical_editions", "between_editions", NA, edition, ed_date(edition), "register", "entry",
                        sprintf("%d of %d entries", same, n), paste0("pdf:", edition), sprintf("%.1f %%", 100 * share),
                        paste0("pdf:", prev), "entries printed exactly as in the edition before"))

## Fixed fields: build year, place, yard, IMO and hull material are the same in every edition ----------------------------
ff <- series |>
  transmute(edition, vid, src, construction_year = as.character(by), construction_place = built_place,
            construction_station = yard, imo_no = imo, hull_material) |>
  pivot_longer(construction_year:hull_material, names_to = "column", values_to = "value", values_drop_na = TRUE) |>
  mutate(k = ifelse(column == "hull_material", key_material(value), key_txt(value))) |>
  filter(!is.na(k), k != "")
mode_k <- ff |> group_by(vid, column, k) |> summarise(n = n(), last = max(edition), v = value[which.max(edition)], .groups = "drop") |>
  group_by(vid, column) |> mutate(N = sum(n)) |> arrange(desc(n), desc(last)) |>
  summarise(mk = k[1], mv = v[1], mn = n[1], N = N[1], n_values = n(), .groups = "drop") |> filter(n_values > 1)
dev <- ff |> inner_join(mode_k, by = c("vid", "column")) |> filter(k != mk) |>
  group_by(vid, column, k) |> mutate(kn = n()) |> ungroup()
F$fixed <- with(dev, fnd("fixed_field", "between_editions", vid, edition, ed_date(edition), "vessel_hist", column, value,
                         src, mv, paste0("pdf: ", mn, " of ", N, " editions"),
                         paste0("printed so in ", kn, " of ", N, " editions")))

## A dimension or tonnage that changes has a note (to 2010) or a dated change ----------------------------------------------
mcols <- c(length_reg = "length", breadth = "width", depth = "depth", loa = "max_length", grt = "brutto_grt",
           gt = "brutto_weight_tons", nt = "netto_weight_tons")
ch <- series |>
  select(edition, vid, changes, all_of(names(mcols))) |>
  pivot_longer(all_of(names(mcols)), names_to = "pcol", values_to = "v") |>
  filter(!is.na(v), v != 0) |>
  mutate(column = unname(mcols[pcol]), d = dec_of(as.character(v))) |>
  arrange(vid, column, edition) |>
  group_by(vid, column) |>
  mutate(e0 = lag(edition), v0 = lag(v), d0 = lag(d), changes0 = lag(changes)) |>
  ungroup() |>
  filter(!is.na(v0), !num_agree(v, d, v0, d0)) |>
  mutate(noted = edition <= 2010 & coalesce(key_txt(changes), "") != coalesce(key_txt(changes0), ""))
dated_src <- c("kvoti.skipasaga", "ufs.skipasaga", "vessel:vessel_measurement_hist")
dated <- evi |> filter(source %in% dated_src, table == "vessel_measurement_hist", !is.na(t1), !is.na(value_num)) |>
  select(vid, column, t1, wv = value_num, wval = value)
chd <- ch |> filter(!noted) |>
  inner_join(dated, by = c("vid", "column"), relationship = "many-to-many") |>
  filter(t1 > ed_date(e0), t1 <= ed_date(edition) + 90, num_agree(v, d, wv, dec_of(wval))) |>
  distinct(vid, column, edition)
unexpl <- ch |> filter(!noted) |> anti_join(chd, by = c("vid", "column", "edition"))
message(nrow(ch), " changes of a dimension or tonnage between editions: ", sum(ch$noted), " with a changes note, ",
        nrow(chd), " dated in another source, ", nrow(unexpl), " unexplained")
F$change <- with(unexpl, fnd("change_unexplained", "between_editions", vid, edition, ed_date(edition),
                             "vessel_measurement_hist", column, v, paste0("pdf:", edition), v0, paste0("pdf:", e0),
                             ifelse(edition <= 2010, "no changes note and no dated change",
                                    "no dated change (no changes field after 2010)")))

## Leaving and returning against the lists --------------------------------------------------------------------------------
pe <- sort(unique(series$edition))
lists_for <- function(e1) if (e1 == 2006) integer(0) else if (e1 == 2021) c(2020L, 2021L) else e1   # 2006 prints no lists
lr <- bind_rows(lapply(seq_along(pe)[-1], function(i) {
  e0 <- pe[i - 1]; e1 <- pe[i]; L <- lists_for(e1)
  if (!length(L)) return(NULL)
  p0 <- series$vid[series$edition == e0]; p1 <- series$vid[series$edition == e1]
  ev <- evt |> filter(edition %in% L)
  dr <- unique(ev$vid[ev$kind == "deregistration"]); rg <- unique(ev$vid[ev$kind == "registration"])
  first <- unique(ev$vid[ev$kind == "registration" & ev$subkind %in% "first"])
  seen <- unique(series$vid[series$edition <= e0])
  lab <- paste(L, collapse = "+")
  bind_rows(
    fnd("left_unlisted", "between_editions", setdiff(setdiff(p0, p1), dr), e1, ed_date(e1), "vessel_event", "event",
        NA, paste0("pdf:", e1), paste0("in edition ", e0), paste0("pdf_event:", lab), "left the register, in no deregistration list"),
    fnd("arrived_unlisted", "between_editions", setdiff(setdiff(p1, p0), rg), e1, ed_date(e1), "vessel_event", "event",
        NA, paste0("pdf:", e1), paste0("not in edition ", e0), paste0("pdf_event:", lab), "came onto the register, in no registration list"),
    fnd("deregistered_still_printed", "between_editions", setdiff(intersect(dr, p1), rg), e1, ed_date(e1), "vessel_event",
        "event", "deregistration", paste0("pdf_event:", lab), paste0("printed in edition ", e1), paste0("pdf:", e1),
        "listed as deregistered and printed in the next edition, with no re-registration listed"),
    fnd("registered_not_printed", "between_editions", setdiff(setdiff(rg, p1), dr), e1, ed_date(e1), "vessel_event",
        "event", "registration", paste0("pdf_event:", lab), paste0("not in edition ", e1), paste0("pdf:", e1),
        "listed as registered and missing from the next edition"),
    fnd("first_registration_seen_before", "between_editions", intersect(first, seen), e1, ed_date(e1), "vessel_event",
        "event", "registration:first", paste0("pdf_event:", lab), paste0("in an edition up to ", e0), "pdf",
        "a first registration of a hull printed in an earlier edition"))
}))
F$leave_return <- lr

## The fleet trend tables across editions ---------------------------------------------------------------------------------
tr <- fleet |> group_by(measure, year, value) |> summarise(eds = list(sort(unique(edition))), n = length(unique(edition)), .groups = "drop") |>
  group_by(measure, year) |> filter(n() > 1) |> arrange(desc(n)) |>
  mutate(mv = value[1], mn = n[1]) |> slice(-1) |> ungroup() |> unnest(eds)
F$trend <- with(tr, fnd("trend", "between_editions", NA, eds, ed_date(year), "summary", measure, value,
                        paste0("pdf:", eds, " trend table, ", year), mv, paste0("pdf: ", mn, " editions"),
                        paste0("the edition's figure for ", year, " differs from the most editions'")))

# 5.3 Against the witnesses ----------------------------------------------------------------------------------------------
CMP <- tribble(
  ~table, ~column, ~type,
  "vessel_hist", "name", "text", "vessel_hist", "previous_name", "text", "vessel_hist", "usage_category", "text",
  "vessel_hist", "open", "text", "vessel_hist", "classification_society", "class",
  "vessel_hist", "construction_place", "text", "vessel_hist", "construction_year", "num",
  "vessel_hist", "construction_station", "text", "vessel_hist", "hull_material", "material",
  "vessel_hist", "imo_no", "text", "vessel_hist", "power_indicator", "num",
  "vessel_identification_hist", "district", "text", "vessel_identification_hist", "region_acronym", "text",
  "vessel_identification_hist", "region_no", "num", "vessel_identification_hist", "call_sign", "text",
  "vessel_identification_hist", "home_port", "text",
  "vessel_measurement_hist", "length", "num", "vessel_measurement_hist", "max_length", "num",
  "vessel_measurement_hist", "width", "num", "vessel_measurement_hist", "depth", "num",
  "vessel_measurement_hist", "brutto_grt", "num", "vessel_measurement_hist", "brutto_weight_tons", "num",
  "vessel_measurement_hist", "netto_weight_tons", "num",
  "vessel_engines_hist", "manufacturer_name", "text", "vessel_engines_hist", "year", "num",
  "vessel_engines_hist", "power", "num",
  "vessel_owners_hist", "name", "text")
n_type <- sum(evi$source == "vessel:vessel_engines_hist" & evi$column == "manufacturer_name" & nchar(key_txt(evi$value)) == 1)
message(n_type, " engine makes of one letter in the `vessel` schema (an engine type) left out of the comparison")
ev2 <- evi |>
  inner_join(CMP, by = c("table", "column")) |>
  filter(!(source == "mbl" & column == "usage_category"),           # mbl types by fishery, not by the register's key
         !(column == "district" & !grepl("[0-9]", value)),             # letters alone are compared as region_acronym
         !(source == "vessel:vessel_engines_hist" & column == "manufacturer_name" & nchar(key_txt(value)) == 1)) |>
  mutate(v = case_when(source == "mbl" & table == "vessel_hist" & column == "name" ~
                         sub("\\s+\\p{Lu}{1,2}[- ]?\\d{1,3}$", "", value, perl = TRUE),
                       source == "mbl" & column == "manufacturer_name" ~ sub("\\.\\s*\\d{1,2}-\\d{4}$", "", value),
                       TRUE ~ value),
         num = ifelse(type == "num" & !is.na(value_num) & value_num != 0, value_num, NA_real_),
         is_pdf = grepl("^pdf:", source),
         dec = ifelse(type == "num", as.integer(dec_of(value)), NA_integer_),
         cmp = case_when(type == "num" ~ ifelse(is.na(num), NA, as.character(num)),
                         type == "material" ~ key_material(v),
                         type == "class" ~ key_class(v),
                         TRUE ~ key_txt(v))) |>
  filter(!is.na(cmp), cmp != "")
# kvoti.skip_extra writes two societies in one code ("SINV")
two <- ev2$source == "kvoti.skip_extra" & ev2$column == "classification_society" & nchar(ev2$cmp) == 4
ev2 <- bind_rows(ev2[!two, ], ev2[two, ] |> separate_longer_position(v, width = 2) |> mutate(cmp = key_class(v)))
# ufs.skip_jn dates each call sign and IMO from the change that set it to the next change
jn <- ev2 |> filter(kind == "change") |> arrange(vid, table, column, t1) |> group_by(vid, table, column) |>
  mutate(t2 = lead(t1) - 1) |> ungroup()
NOT_WITNESS <- "^pdf|^ufs[.]skipasaga_jn$|^kvoti[.]skip_extra$"      # the journal's old versions date changes (step 5)
anc <- ev2 |> filter(is_pdf | source == "samgongustofa:2022-12-28") |>
  transmute(aid = row_number(), vid, tab = table, col = column, value, source, edition, d = t1, num, dec, cmp)
wit <- bind_rows(ev2 |> filter(kind != "change"), jn) |>
  filter(!grepl(NOT_WITNESS, source), kind != "undated") |>
  transmute(vid, tab = table, col = column, value, source, t1, t2, num, dec, cmp)

con <- dbConnect(duckdb())
spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
dbExecute(con, sprintf("SET temp_directory = '%s'", spill))
duckdb_register(con, "anc", anc)
duckdb_register(con, "wit", wit)
agree_sql <- "
  CASE WHEN a.num IS NOT NULL AND w.num IS NOT NULL THEN
    abs(round((CASE WHEN a.dec >= w.dec THEN a.num ELSE w.num END) * pow(10, least(a.dec, w.dec))) -
        round((CASE WHEN a.dec >= w.dec THEN w.num ELSE a.num END) * pow(10, least(a.dec, w.dec)))) < 0.5 OR
    abs(floor((CASE WHEN a.dec >= w.dec THEN a.num ELSE w.num END) * pow(10, least(a.dec, w.dec)) + 1e-7) -
        round((CASE WHEN a.dec >= w.dec THEN w.num ELSE a.num END) * pow(10, least(a.dec, w.dec)))) < 0.5
  ELSE a.cmp = w.cmp END"
cmpd <- dbGetQuery(con, sprintf("
  SELECT a.aid, w.source AS wsource, bool_or(%s) AS agree,
         string_agg(DISTINCT w.value, '; ' ORDER BY w.value) AS wvalue,
         min(w.t1) AS wt1, max(coalesce(w.t2, DATE '2099-12-31')) AS wt2
  FROM anc a JOIN wit w ON a.vid = w.vid AND a.tab = w.tab AND a.col = w.col AND a.source <> w.source
   AND (w.t1 IS NULL OR w.t1 <= a.d) AND (w.t2 IS NULL OR w.t2 >= a.d)
  GROUP BY a.aid, w.source", agree_sql))
duckdb_register(con, "dis", cmpd |> filter(!agree) |> select(aid, wsource))
near <- dbGetQuery(con, sprintf("
  SELECT a.aid, w.source AS wsource
  FROM (SELECT anc.*, dis.wsource FROM anc JOIN dis USING (aid)) a
  JOIN wit w ON a.vid = w.vid AND a.tab = w.tab AND a.col = w.col AND w.source = a.wsource
   AND (w.t1 IS NULL OR w.t1 <= a.d + %d) AND (w.t2 IS NULL OR w.t2 >= a.d - %d)
  GROUP BY a.aid, w.source HAVING bool_or(%s)", NEAR_DAYS, NEAR_DAYS, agree_sql))
dbDisconnect(con, shutdown = TRUE)
unlink(spill, recursive = TRUE)

cmpd <- cmpd |> left_join(near |> mutate(near = TRUE), by = c("aid", "wsource")) |>
  mutate(near = coalesce(near, FALSE)) |> inner_join(anc, by = "aid")
agreement <- cmpd |>
  mutate(anchor = sub(":.*$", "", source)) |>
  group_by(anchor, edition, witness = wsource, table = tab, column = col) |>
  summarise(n = n(), n_agree = sum(agree), n_agree_in_time = sum(!agree & near), .groups = "drop")
w1 <- cmpd |> filter(!agree)
# a witness's text value that the PDFs print for the hull in another edition: an old or a new value, not another one
pdf_txt <- ev2 |> filter(is_pdf, type == "text") |> distinct(vid, tab = table, col = column, e = edition, k = cmp)
wk <- w1 |> filter(!is.na(edition)) |> select(aid, wsource, vid, tab, col, edition, wvalue) |>
  separate_longer_delim(wvalue, "; ") |> mutate(k = key_txt(wvalue)) |>
  inner_join(pdf_txt, by = c("vid", "tab", "col", "k"), relationship = "many-to-many") |>
  group_by(aid, wsource) |> summarise(before = any(e < edition), after = any(e > edition), .groups = "drop")
w1 <- w1 |> left_join(wk, by = c("aid", "wsource"))
F$witness <- with(w1, fnd("witness_value", "witness", vid, edition, d, tab, col, value, source, wvalue, wsource,
                          ifelse(near, paste0("the witness agrees within ", NEAR_DAYS, " days: a matter of dating"),
                          ifelse(before %in% TRUE & !after %in% TRUE, "the witness gives the value of an earlier edition",
                          ifelse(after %in% TRUE & !before %in% TRUE, "the witness gives the value of a later edition",
                                 paste0("the witness's window ", wt1, " to ", ifelse(wt2 >= as.Date("2099-01-01"), "open", as.character(wt2))))))))

## An undated witness: kvoti.skip_extra against every edition ------------------------------------------------------------
# only fields that do not change: an undated owner, name or home port may belong to any time
FIXED <- c("construction_year", "construction_place", "construction_station", "hull_material", "length", "width", "depth",
           "max_length", "brutto_grt", "brutto_weight_tons", "netto_weight_tons")
ux <- ev2 |> filter(source == "kvoti.skip_extra", kind == "undated", column %in% FIXED) |> select(vid, table, column, value, num, dec, cmp)
pv <- ev2 |> filter(is_pdf) |> select(vid, table, column, pval = value, pnum = num, pdec = dec, pcmp = cmp)
uj <- ux |> inner_join(pv, by = c("vid", "table", "column"), relationship = "many-to-many") |>
  mutate(agree = ifelse(!is.na(num) & !is.na(pnum), num_agree(num, dec, pnum, pdec), cmp == pcmp)) |>
  group_by(vid, table, column, value) |>
  summarise(agree = any(agree), pvals = paste(head(unique(pval), 5), collapse = "; "), .groups = "drop")
message("kvoti.skip_extra: ", sum(uj$agree), " of ", nrow(uj), " values agree with some edition")
F$undated <- with(uj |> filter(!agree), fnd("witness_undated", "witness", vid, NA, NA, table, column, value,
                                             "kvoti.skip_extra", pvals, "pdf", "matches no edition's value"))

## One call sign on two hulls at once, in any witness --------------------------------------------------------------------
cs <- bind_rows(evi |> filter(column == "call_sign", kind != "change"), jn |> filter(column == "call_sign") |> select(-any_of(c("v", "num", "dec", "cmp", "type", "is_pdf")))) |>
  filter(!grepl("^pdf", source)) |>
  transmute(vid, source, k = key_txt(value), value, a = coalesce(t1, as.Date("1900-01-01")), b = coalesce(t2, as.Date("2099-12-31")))
cs2 <- cs |> inner_join(cs, by = c("source", "k"), suffix = c("", "_o"), relationship = "many-to-many") |>
  filter(vid < vid_o, a <= b_o, a_o <= b) |>
  group_by(source, value, vid, vid_o) |> summarise(from = max(min(a), min(a_o)), .groups = "drop")
last_pr <- function(v) { l <- tapply(pres$edition, pres$vid, max)[as.character(v)]; ifelse(is.na(l), "in no edition", paste("last printed", l)) }
F$callsign_two <- with(cs2, fnd("call_sign_two_hulls", "witness", vid, NA, from, "vessel_identification_hist", "call_sign",
                                value, source, vid_o, source,
                                paste0("the same witness gives it to vid ", vid_o, " too; vid ", vid, " ", last_pr(vid),
                                       ", vid ", vid_o, " ", last_pr(vid_o))))

## MMSI -------------------------------------------------------------------------------------------------------------------
last_ed <- pres |> group_by(vid) |> summarise(ed_first = min(edition), last = max(edition))
mm <- evi |> filter(source == "mmsi", column == "mmsi_no", vid <= 9999) |> select(vid, mmsi = value, t1, t2) |>
  mutate(t1 = if_else(t1 == as.Date("2007-06-01"), as.Date(NA), t1),            # the archive's default window
         t2 = if_else(t2 >= as.Date("2028-12-24"), as.Date(NA), t2)) |>
  left_join(last_ed, by = "vid")
m1 <- mm |> filter(!is.na(t1), t1 >= as.Date("2004-01-01"), t1 <= as.Date("2022-12-31"),
                   !in_ed(vid, yr(t1)), !in_ed(vid, yr(t1) + 1))
m2 <- mm |> filter(!is.na(last), last < 2022, coalesce(t2, as.Date("2023-12-19")) > ed_date(last + 2))
mb <- evi |> filter(source == "mbl", column == "mmsi_no") |> select(vid, mmsi = value) |>
  anti_join(mm, by = c("vid", "mmsi"))
l23 <- evi |> filter(source == "ops_einarhj.mmsi_icelandic_registry_20230115", column == "mmsi_no", vid <= 9999) |>
  select(vid, mmsi = value, d = t1)
m3 <- l23 |> left_join(mm |> select(vid, mmsi, t1, t2) |> mutate(mmsi_t1_ = TRUE), by = c("vid", "mmsi"), relationship = "many-to-many") |>
  group_by(vid, mmsi, d) |>
  summarise(covered = any(!is.na(mmsi_t1_) & coalesce(t1, as.Date("1900-01-01")) <= d & (is.na(t2) | t2 >= d)),
            known = any(!is.na(mmsi_t1_)), ends = suppressWarnings(max(t2, na.rm = TRUE)), .groups = "drop") |>
  filter(!covered)
F$mmsi <- bind_rows(
  with(m1, fnd("mmsi_unregistered", "witness", vid, NA, t1, "vessel_mmsi_hist", "mmsi_no", mmsi, "mmsi",
               ifelse(is.na(ed_first), "in no edition", paste0("editions ", ed_first, "-", last)), "pdf",
               "an MMSI window that opens in a year the hull is in neither bracketing edition")),
  with(m2, fnd("mmsi_after_register", "witness", vid, NA, t2, "vessel_mmsi_hist",
               "mmsi_no", mmsi, "mmsi", paste0("last edition ", last), "pdf",
               paste0("the MMSI window runs more than a year past the hull's last edition, to ",
                      ifelse(is.na(t2), "now (open)", as.character(t2))))),
  with(mb, fnd("mmsi_mbl_not_in_archive", "witness", vid, NA, as.Date("2022-12-28"), "vessel_mmsi_hist", "mmsi_no",
               mmsi, "mbl", NA, "mmsi", "mbl's MMSI is not among the archive's for the hull")),
  with(m3, fnd("mmsi_list_2023", "witness", vid, NA, d, "vessel_mmsi_hist", "mmsi_no", mmsi,
               "ops_einarhj.mmsi_icelandic_registry_20230115", NA, "mmsi",
               ifelse(known, paste0("the archive has this pair, to ", ends), "the archive never has this pair"))))

## Licences against the register ------------------------------------------------------------------------------------------
lt <- ora("kvoti", "tegund_veidileyfis") |> transmute(type = as.character(kodi), licence = leyfi)
lic <- bind_rows(
  ora("kvoti", "veidileyfi") |> transmute(vid = skip_nr, type = as.character(tegund_leyfis), t1 = as.Date(i_gildi), t2 = as.Date(ur_gildi), lsrc = "kvoti.veidileyfi"),
  ora("kvoti", "strandveidileyfi_v") |> transmute(vid = skip_nr, type = as.character(tegund_leyfis), t1 = as.Date(i_gildi), t2 = as.Date(ur_gildi), lsrc = "kvoti.strandveidileyfi_v"),
  ora("kvoti", "grasleppusaga") |> transmute(vid = skip_nr, type = "11", t1 = as.Date(i_gildi), t2 = as.Date(ur_gildi), lsrc = "kvoti.grasleppusaga")) |>
  filter(!is.na(vid), !is.na(t1)) |> mutate(t2 = coalesce(t2, as.Date("2099-12-31"))) |> left_join(lt, by = "type")
ent <- reg |> filter(edition <= yr(LICENCE_END)) |> transmute(vid, edition, d = ed_date(edition), ship_type, src)
l1 <- ent |> filter(!is.na(ship_type), !is_fishing(ship_type), key_txt(ship_type) != "ÓTILGREINT") |>
  inner_join(lic |> filter(!type %in% RECREATIONAL), by = join_by(vid, d >= t1, d <= t2)) |>
  group_by(vid, edition, d, ship_type, src) |>
  summarise(lic = paste(sort(unique(coalesce(licence, type))), collapse = "; "), lsrc = paste(sort(unique(lsrc)), collapse = "; "), .groups = "drop")
gone <- evt |> filter(kind == "deregistration", !is.na(date)) |> left_join(last_ed, by = "vid") |>
  filter(is.na(last) | last < edition) |> group_by(vid) |> summarise(dd = max(date))
l2 <- lic |> inner_join(gone, by = "vid") |> filter(t1 > dd)
F$licence <- bind_rows(
  with(l1, fnd("licence_non_fishing", "witness", vid, edition, d, "vessel_licence_hist", "licence_name", ship_type, src,
               lic, lsrc, "a fishing licence on a ship whose type is not a fishing one")),
  with(l2, fnd("licence_after_deregistration", "witness", vid, NA, t1, "vessel_licence_hist", "licence_name",
               coalesce(licence, type), lsrc, as.character(dd), "pdf_event",
               "a licence issued after the hull's last deregistration")))

# 5.4 Against activity ---------------------------------------------------------------------------------------------------
land <- read_parquet(fd_curated("landing", "landings.parquet")) |>
  transmute(.lid, schema, vid, date = as.Date(date)) |>
  filter(!is.na(vid), vid <= 9999, !(vid >= 3700 & vid <= 4999), date >= as.Date("2004-01-01"), date <= as.Date("2021-12-31"))
trip <- read_parquet(fd_curated("logbook", "trip.parquet"), col_select = c("vid", "T1", "twin")) |>
  filter(is.na(twin) | twin != "duplicate") |>
  transmute(vid, date = as.Date(T1)) |>
  filter(!is.na(vid), vid <= 9999, !(vid >= 3700 & vid <= 4999), date >= as.Date("2004-01-01"), date <= as.Date("2021-12-31"))
act <- bind_rows(land |> distinct(vid, date) |> mutate(asrc = "landings"), trip |> distinct(vid, date) |> mutate(asrc = "logbook")) |>
  mutate(y = yr(date))
agg <- function(d, ...) d |> group_by(vid, y, asrc, ...) |>
  summarise(n = n(), first = min(date), last = max(date), .groups = "drop")
a1 <- act |> filter(!in_ed(vid, y), !in_ed(vid, y + 1)) |> agg() |> left_join(last_ed |> rename(ed_last = last), by = "vid")
dereg <- evt |> filter(kind == "deregistration", !is.na(date)) |> distinct(vid, edition, dd = date)
rereg <- evt |> filter(kind == "registration", !is.na(date)) |> distinct(vid, rd = date)
a2 <- act |> inner_join(dereg, by = "vid", relationship = "many-to-many") |>
  filter(date > dd, y == yr(dd), !in_ed(vid, edition))
back <- a2 |> inner_join(rereg, by = join_by(vid, dd < rd, date >= rd)) |> distinct(vid, date, asrc, dd)   # registered again
a2 <- a2 |> anti_join(back, by = c("vid", "date", "asrc", "dd")) |> agg(dd)
regs <- evt |> filter(kind == "registration", !is.na(date)) |> distinct(vid, edition, rd = date, subkind)
a3 <- act |> inner_join(regs, by = "vid", relationship = "many-to-many") |>
  filter(date < rd, y == yr(rd), !in_ed(vid, edition - 1)) |> agg(rd, subkind)
F$activity <- bind_rows(
  with(a1, fnd("activity_unregistered", "activity", vid, NA, first, "vessel_event", "registered", paste(n, "days"), asrc,
               ifelse(is.na(ed_first), "in no edition", paste0("editions ", ed_first, "-", ed_last)), "pdf",
               paste0(y, ": ", first, " to ", last, ", in neither edition ", y, " nor ", y + 1))),
  with(a2, fnd("activity_after_deregistration", "activity", vid, NA, first, "vessel_event", "deregistration",
               paste(n, "days"), asrc, as.character(dd), "pdf_event", paste0(first, " to ", last, ", after the deregistration"))),
  with(a3, fnd("activity_before_registration", "activity", vid, NA, first, "vessel_event", paste0("registration:", subkind),
               paste(n, "days"), asrc, as.character(rd), "pdf_event", paste0(first, " to ", last, ", before the registration"))))

## Landings without a licence, and gear without its licence (to 2020-07-22) ---------------------------------------------
ld <- land |> filter(date <= LICENCE_END) |> distinct(vid, date)
lok <- ld |> inner_join(lic, by = join_by(vid, date >= t1, date <= t2)) |> distinct(vid, date)
type_y <- reg |> distinct(vid, y = edition, .keep_all = TRUE) |> select(vid, y, ship_type)
a4 <- ld |> anti_join(lok, by = c("vid", "date")) |> mutate(y = yr(date), asrc = "landings") |> agg() |>
  left_join(type_y, by = c("vid", "y"))
seine_ok <- bind_rows(lic |> filter(type %in% c("8", "9", "10")) |> select(vid, t1, t2),
                      ora("kvoti", "dragnot_leyfi") |> transmute(vid = skip_nr, t1 = as.Date(paste0(ar, "-01-01")), t2 = as.Date(paste0(ar, "-12-31"))))
lump_ok <- lic |> filter(type == "11") |> select(vid, t1, t2)
cg <- read_parquet(fd_curated("landing", "catch.parquet"), col_select = c(".lid", "schema", "gid")) |> distinct()
lg <- land |> filter(date <= LICENCE_END) |> inner_join(cg, by = c(".lid", "schema")) |>
  mutate(gear = case_when((schema == "agf" & gid == 11) | (schema == "lods" & gid %in% c(5, 26, 35)) ~ "dragnót",
                          (schema == "agf" & gid == 3) | (schema == "lods" & gid == 25) ~ "grásleppunet")) |>
  filter(!is.na(gear)) |> distinct(vid, date, gear)
g_ok <- bind_rows(lg |> filter(gear == "dragnót") |> inner_join(seine_ok, by = join_by(vid, date >= t1, date <= t2)),
                  lg |> filter(gear == "grásleppunet") |> inner_join(lump_ok, by = join_by(vid, date >= t1, date <= t2))) |>
  distinct(vid, date, gear)
a5 <- lg |> anti_join(g_ok, by = c("vid", "date", "gear")) |> mutate(y = yr(date), asrc = "landings") |> agg(gear)
F$licence_use <- bind_rows(
  with(a4, fnd("landing_without_licence", "activity", vid, NA, first, "vessel_licence_hist", "licence_name",
               paste(n, "days"), asrc, ship_type, paste0("pdf:", y),
               paste0(first, " to ", last, ", no licence in kvoti valid on the day"))),
  with(a5, fnd("gear_without_licence", "activity", vid, NA, first, "vessel_licence_hist", "licence_name",
               paste(n, "days"), asrc, gear, "kvoti", paste0(first, " to ", last, ", landed from ", gear,
                                                             " with no licence for it valid on the day"))))

# Count, write ------------------------------------------------------------------------------------------------------------
disc <- bind_rows(F) |>
  mutate(status = "unsettled", rule = NA_character_, value_chosen = NA_character_) |>
  arrange(kind, check, vid, edition, date)
CHECKS <- c("total", "table_sum", "number_list", "callsign_list", "aggregate_class", "aggregate_events",
            "rule_callsign_short", "rule_imo_check_digit", "rule_imo_missing", "rule_gt_formula", "rule_nt_formula",
            "rule_year_after_edition", "vocabulary", "unique_call_sign", "unique_district", "identical_editions",
            "fixed_field", "change_unexplained", "left_unlisted", "arrived_unlisted", "deregistered_still_printed",
            "registered_not_printed", "first_registration_seen_before", "trend", "witness_value", "witness_undated",
            "call_sign_two_hulls", "mmsi_unregistered", "mmsi_after_register", "mmsi_mbl_not_in_archive",
            "mmsi_list_2023", "licence_non_fishing", "licence_after_deregistration", "activity_unregistered",
            "activity_after_deregistration", "activity_before_registration", "landing_without_licence",
            "gear_without_licence")
stopifnot(all(disc$check %in% CHECKS), !anyNA(disc$kind))
print(tibble(check = CHECKS) |> left_join(count(disc, kind, check), by = "check") |> mutate(n = coalesce(n, 0L)) |>
        knitr::kable(caption = "skipaskra_discrepancy: findings per check"))
print(agreement |> filter(anchor == "pdf") |> group_by(witness, table, column) |>
        summarise(n = sum(n), agree = round(100 * sum(n_agree) / sum(n), 1),
                  in_time = round(100 * sum(n_agree_in_time) / sum(n), 1), .groups = "drop") |>
        knitr::kable(caption = "the PDFs against each witness: % agreeing, and % agreeing within half a year"))

inputs <- c(file.path(fd_staging("skipaskra"), c("register.parquet", "event.parquet", "index_list.parquet", "summary.parquet")),
            fd_curated("vessel", "skipaskra", "evidence.parquet"),
            fd_raw("oracle", "kvoti", paste0(c("veidileyfi", "strandveidileyfi_v", "grasleppusaga", "dragnot_leyfi",
                                               "tegund_veidileyfis"), ".parquet")),
            file.path(fd_curated("landing"), c("landings.parquet", "catch.parquet")), fd_curated("logbook", "trip.parquet"))
write_curated(disc, fd_curated("check", "skipaskra_discrepancy.parquet"), inputs = inputs)
write_curated(agreement, fd_curated("check", "skipaskra_agreement.parquet"), inputs = inputs)
