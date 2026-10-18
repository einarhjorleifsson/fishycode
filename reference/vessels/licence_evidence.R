# Every statement a record makes about a hull's fishing licence, to 2020-07-22, and how far each record agreed with
# the licence register while both existed (plan 029 step 3).
# Side: once (licence history). See plan 014; plan 029 §3.5, §5.3 and §5.7; decision 133.
#
# Input:  staging/kvoti/{licence,licence_deleted,licence_lumpfish,licence_seine,licence_revocation,licence_arrears,
#                        licence_date_fix,quota_right,mackerel_allocation,mackerel_class,effort_day_notice,
#                        coastal_trip,lumpfish_logbook}.parquet
#         curated/vessel/vessel_class.parquet          the class runs (a main-project file, watched)
#         curated/landing/{landings,catch}.parquet     activity: landings by gear and species (main-project files)
# Output: curated/vessel/licence/evidence.parquet      one row per witness statement
#         curated/vessel/licence/calibration.parquet   one row per witness, licence group and year: implies, covers
#
# Nothing is chosen here: every statement is kept as its record gives it, and the rules (plan 029 §5.4, step 4) settle
# the history from it.
#
# - `group`: licence types fall into groups (GROUP below), since most witnesses name a group, not a type. A
#   revocation, an arrears entry and the class of surrendered rights (-10) speak for every licence: group "all".
# - `says`: the register's own words, `held`, `unpaid`, `stored` (lumpfish right in storage), `deleted`,
#   `surrendered` (Danish seine), `revoked`, `absent` (arrears); every other lineage `implied`, or `absent` for
#   class -10.
# - `t1`, `t2`: dates as the record gives them, both days included. A class run's exclusive end moves back a day; a
#   run opening on the 1901 placeholder starts on 1991-01-01, the day the class record opens (flag
#   `placeholder_start`). A record that holds a day or a stamp (notices, trips, the logbook, landings) is summed to
#   its first and last day per hull and year, or per hull and day for landings.
# - Only statements starting on or before 2020-07-22 are kept: the live tail after it is the main project's
#   (decision 133).
# - `lineage` (plan 029 §5.3): licence_register, class, quota, notices, lumpfish_logbook, activity.
# - The lost-century dates take their corrected value from curate/corrections/licence_lost_century.R; an
#   unresolved one is NA, flagged `lost_century_unresolved`.
# - Calibration (plan 029 §3.5): every statement is cut at year ends, 1991 to 2020-07-22. `implies` is the share of a
#   witness's pieces that a held or unpaid licence of the same group overlaps for the same hull, in years when the
#   register holds that group; `covers` is the share of the register's pieces that the witness overlaps, in years
#   when the witness speaks.

library(dplyr)

SPLIT <- as.Date("2020-07-22")
OPEN <- as.Date("1991-01-01")
st <- function(name) duckdbfs::open_dataset(fd_staging("kvoti", paste0(name, ".parquet"))) |> collect()
d8 <- function(x) as.Date(x, tz = "UTC")
yr <- function(x) as.integer(format(x, "%Y"))

GROUP <- c("1" = "catch_quota", "2" = "handline", "3" = "cod_cap", "4" = "inshore_shrimp", "6" = "scallop",
           "7" = "sea_urchin", "8" = "danish_seine", "9" = "danish_seine", "10" = "danish_seine", "11" = "lumpfish",
           "36" = "lumpfish", "14" = "line_handline", "23" = "effort_days", "32" = "hook_quota", "37" = "coastal",
           "38" = "recreational", "39" = "recreational", "42" = "recreational", "40" = "sea_cucumber",
           "26" = "mackerel", "43" = "mackerel", "44" = "mackerel", "45" = "mackerel", "53" = "mackerel",
           "16" = "foreign", "19" = "foreign", "20" = "foreign", "21" = "foreign", "22" = "foreign", "24" = "foreign",
           "27" = "foreign", "35" = "foreign")
group_of <- function(type) unname(coalesce(GROUP[type], paste0("type_", type)))

# The class each fishing system's licence goes with (stadall_utgerdarflokkar_v). The catch-quota classes are those of
# the Aflamark system that name a fishing vessel.
CLASS_MAP <- c("-12" = "coastal", "96" = "hook_quota", "98" = "cod_cap", "101" = "effort_days", "100" = "handline",
               "99" = "line_handline", "89" = "recreational", "95" = "recreational", "-11" = "recreational",
               "93" = "lumpfish", "-10" = "all",
               setNames(rep("catch_quota", 15), c(10, 11, 16, 20, 21, 30, 40, 50, 60, 61, 62, 70, 80, 90, 91)))

# A quota type that names a fishery with a licence of its own; any other allocation goes with the catch-quota licence
QUOTA_MAP <- c("36" = "mackerel", "951" = "lumpfish",
               setNames(rep("sea_cucumber", 8), 101:108), setNames(rep("sea_urchin", 4), 115:118),
               setNames(rep("scallop", 9), c(43, 61:66, 901, 902)),
               setNames(rep("inshore_shrimp", 10), c(51:58, 72, 73)))
AREA_QUOTA <- c("sea_cucumber", "sea_urchin", "scallop", "inshore_shrimp")

COLS <- c("vid", "group", "licence_type", "area", "t1", "t2", "says", "source", "record", "lineage", "licence_no",
          "status_source", "detail", "flag")
fill <- function(d, source, lineage) {
  d$source <- source; d$lineage <- lineage
  for (c in setdiff(COLS, names(d))) d[[c]] <- NA
  d |> mutate(record = as.character(record), vid = as.integer(vid)) |> select(all_of(COLS))
}
ev <- list()

# The licence register -----------------------------------------------------------------------------------------------
ev$licence <- st("licence") |>
  transmute(vid, group = group_of(licence_type), licence_type, area, t1 = d8(t1), t2 = d8(t2),
            says = if_else(unpaid, "unpaid", "held"), record = id, licence_no) |>
  fill("kvoti.veidileyfi", "licence_register")

ev$deleted <- st("licence_deleted") |>
  transmute(vid, group = group_of(licence_type), licence_type, area, t1 = d8(t1), t2 = d8(t2), says = "deleted",
            record = row, licence_no, detail = paste("deleted", format(d8(deleted)))) |>
  fill("kvoti.veidileyfi_eydd", "licence_register")

ev$lumpfish <- st("licence_lumpfish") |>
  transmute(vid, group = "lumpfish", area, t1 = d8(t1), t2 = d8(t2), says = if_else(status == "G", "stored", "held"),
            record = row, licence_no, status_source = status) |>
  fill("kvoti.grasleppusaga", "licence_register")

ev$seine <- st("licence_seine") |>
  transmute(vid, group = "danish_seine", t1 = d8(t1), t2 = d8(t2),
            says = if_else(is.na(surrendered), "held", "surrendered"), record = paste(vid, year, period),
            detail = paste("period", year, period)) |>
  fill("kvoti.dragnot_leyfi", "licence_register")

fix <- st("licence_date_fix")
with_fix <- function(d, tab) {
  f <- fix |> filter(table == tab)
  d$flag <- NA_character_
  for (col in c("t1", "t2")) {
    ff <- f |> filter(column == col)
    i <- match(d$record, ff$record)
    d[[col]][!is.na(i)] <- ff$value[i[!is.na(i)]]
    d$flag[!is.na(i)] <- ff$flag[i[!is.na(i)]]
  }
  d
}
ev$revocation <- st("licence_revocation") |>
  transmute(vid, record = row, t1, t2, detail = cause) |>
  with_fix("licence_revocation") |>
  mutate(group = "all", says = "revoked", t1 = d8(t1), t2 = d8(t2)) |>
  fill("kvoti.veidileyfi_sviptingar", "licence_register")

ev$arrears <- st("licence_arrears") |>
  transmute(vid, record = row, t1, t2, detail = kind) |>
  with_fix("licence_arrears") |>
  mutate(group = "all", says = "absent", t1 = d8(t1), t2 = d8(t2)) |>
  fill("kvoti.veidileyfi_vanskil", "licence_register")

# The class record ---------------------------------------------------------------------------------------------------
ev$class <- duckdbfs::open_dataset(fd_curated("vessel", "vessel_class.parquet")) |>
  select(vid, class_code, t1, t2) |>
  collect() |>
  mutate(group = unname(CLASS_MAP[as.character(class_code)])) |>
  filter(!is.na(group)) |>
  mutate(record = paste(vid, format(t1)), flag = if_else(t1 < OPEN, "placeholder_start", NA_character_)) |>
  transmute(vid, group, t1 = pmax(d8(t1), OPEN), t2 = d8(t2) - 1, says = if_else(group == "all", "absent", "implied"),
            record, detail = paste("class", class_code), flag) |>
  filter(t2 >= t1) |>
  fill("curated.vessel_class", "class")

# The quota record ---------------------------------------------------------------------------------------------------
ev$quota <- st("quota_right") |>
  filter(right %in% c("F", "H", "R")) |>
  mutate(group = case_when(right == "F" ~ "cod_cap",
                           right == "H" ~ "recreational",
                           .default = coalesce(unname(QUOTA_MAP[as.character(quota_type)]), "catch_quota")),
         area = if_else(group %in% AREA_QUOTA, paste0("quota:", quota_type), NA_character_),
         t1 = d8(t1), t2 = d8(t2)) |>
  group_by(vid, group, area, t1, t2) |>
  summarise(record = as.character(min(id)), detail = paste(right[1], paste(sort(unique(quota_type)), collapse = ",")),
            .groups = "drop") |>
  mutate(says = "implied") |>
  fill("kvoti.afla_heimild", "quota")

ev$mackerel_allocation <- st("mackerel_allocation") |>
  filter(right == "R") |>
  transmute(vid, group = "mackerel", t1 = d8(t1), t2 = d8(t2), says = "implied", record = id,
            detail = paste("pot", pot)) |>
  fill("kvoti.uthl_makrill", "quota")

ev$mackerel_class <- st("mackerel_class") |>
  mutate(y = 2000L + as.integer(substr(fishing_year, 1, 2))) |>
  transmute(vid, group = "mackerel", t1 = as.Date(sprintf("%d-09-01", y)), t2 = as.Date(sprintf("%d-08-31", y + 1L)),
            says = "implied", record = paste(vid, fishing_year), detail = paste("class", class)) |>
  fill("kvoti.makrill_flokkur", "quota")

# Notices, trips and the lumpfish logbook ----------------------------------------------------------------------------
ev$effort_days <- st("effort_day_notice") |>
  filter(valid) |>
  mutate(day = d8(time), y = yr(day)) |>
  group_by(vid, y) |>
  summarise(t1 = min(day), t2 = max(day), n = n(), .groups = "drop") |>
  transmute(vid, group = "effort_days", t1, t2, says = "implied", record = paste(vid, y), detail = paste(n, "notices"),
            flag = if_else(y < 1991, "before_1991", NA_character_)) |>
  fill("kvoti.tilkynning_sokn", "notices")

ev$coastal_trip <- st("coastal_trip") |>
  filter(!coalesce(invalid, FALSE)) |>
  mutate(d1 = d8(t_departure), d2 = d8(coalesce(t_arrival, t_departure)), y = yr(d1)) |>
  group_by(vid, y) |>
  summarise(t1 = min(d1), t2 = max(d2), n = n(), .groups = "drop") |>
  transmute(vid, group = "coastal", t1, t2, says = "implied", record = paste(vid, y), detail = paste(n, "trips")) |>
  fill("kvoti.strandveidar", "notices")

ev$lumpfish_logbook <- st("lumpfish_logbook") |>
  transmute(vid, group = "lumpfish", t1 = coalesce(first_set, as.Date(sprintf("%d-01-01", year))),
            t2 = coalesce(last_set, as.Date(sprintf("%d-12-31", year))), says = "implied", record = paste(vid, year),
            detail = paste(coalesce(n_sets, 0L), "sets"), flag = if_else(is.na(first_set), "year_only", NA_character_)) |>
  fill("fs_afli.grasl_stofn", "lumpfish_logbook")

# Activity -----------------------------------------------------------------------------------------------------------
# A gear or species that needs a licence of its own, by the landing's own code: agf carries the new gear codes, lods
# the old (curated/reference/gear.parquet).
landing <- duckdbfs::open_dataset(fd_curated("landing", "landings.parquet")) |> select(.lid, schema, vid, date)
catch <- duckdbfs::open_dataset(fd_curated("landing", "catch.parquet")) |> select(.lid, schema, gid, sid)
ev$activity <- inner_join(landing, catch, by = c(".lid", "schema")) |>
  mutate(group = case_when((schema == "agf" & gid %in% c(3, 4)) | (schema == "lods" & gid %in% c(25, 29)) ~ "lumpfish",
                           (schema == "agf" & gid == 11) | (schema == "lods" & gid %in% c(5, 26, 35)) ~ "danish_seine",
                           sid == 199 ~ "sea_cucumber",
                           sid == 191 ~ "sea_urchin",
                           sid == 43 ~ "scallop")) |>
  filter(!is.na(group), !is.na(vid)) |>
  distinct(vid, date, group, schema, gid) |>
  collect() |>
  mutate(day = d8(date)) |>
  group_by(vid, day, group) |>
  summarise(detail = paste(sort(unique(paste0(schema, ":", gid))), collapse = ","), .groups = "drop") |>
  transmute(vid, group, t1 = day, t2 = day, says = "implied", record = paste(vid, format(day)), detail) |>
  fill("curated.landing", "activity")

evidence <- bind_rows(ev) |>
  filter(!is.na(vid), !is.na(t1), t1 <= SPLIT) |>
  arrange(vid, group, t1, lineage, source)

# Calibration --------------------------------------------------------------------------------------------------------
pieces <- function(d) {
  d |>
    mutate(c1 = pmax(t1, OPEN), c2 = pmin(coalesce(t2, SPLIT), SPLIT)) |>
    filter(c1 <= c2) |>
    mutate(y1 = yr(c1), y2 = yr(c2)) |>
    tidyr::uncount(y2 - y1 + 1L, .id = "k") |>
    mutate(year = y1 + k - 1L,
           p1 = pmax(c1, as.Date(sprintf("%d-01-01", year))), p2 = pmin(c2, as.Date(sprintf("%d-12-31", year)))) |>
    distinct(source, lineage, vid, group, year, p1, p2)
}
reg <- evidence |> filter(lineage == "licence_register", says %in% c("held", "unpaid"), group != "all") |> pieces() |>
  distinct(vid, group, year, p1, p2)
wit <- evidence |> filter(lineage != "licence_register", says == "implied") |> pieces()

implied <- wit |>
  inner_join(reg |> rename(q1 = p1, q2 = p2), by = join_by(vid, group, year, overlaps(p1, p2, q1, q2))) |>
  distinct(source, lineage, vid, group, year, p1, p2)
spoken <- wit |> distinct(source, lineage, group, year)
covered <- reg |>
  inner_join(spoken, by = c("group", "year"), relationship = "many-to-many") |>
  inner_join(wit |> select(source, vid, group, year, q1 = p1, q2 = p2),
             by = join_by(source, vid, group, year, overlaps(p1, p2, q1, q2))) |>
  distinct(source, lineage, vid, group, year, p1, p2)

n_by <- function(d, name) count(d, source, lineage, group, year, name = name)
calibration <- spoken |>
  left_join(n_by(wit, "n_witness"), by = c("source", "lineage", "group", "year")) |>
  left_join(n_by(implied, "n_implied"), by = c("source", "lineage", "group", "year")) |>
  left_join(count(reg, group, year, name = "n_licence"), by = c("group", "year")) |>
  left_join(n_by(covered, "n_covered"), by = c("source", "lineage", "group", "year")) |>
  mutate(across(c(n_implied, n_licence, n_covered), ~ coalesce(.x, 0L)),
         implies = if_else(n_licence > 0, n_implied / n_witness, NA_real_),
         covers = if_else(n_licence > 0, n_covered / n_licence, NA_real_)) |>
  arrange(group, source, year)

# Report and write ---------------------------------------------------------------------------------------------------
print(evidence |> count(lineage, source, says) |> knitr::kable(caption = "evidence: statements per record"))
# the last five years in which the register held the group: the overlap's end weighs most (plan 029 §3.5)
print(calibration |>
        filter(n_licence > 0) |>
        group_by(group, source) |>
        mutate(last5 = year > max(year) - 5) |>
        summarise(overlap = paste0(min(year), "-", max(year)),
                  implies_all = round(sum(n_implied) / sum(n_witness), 3),
                  implies_last5 = round(sum(n_implied[last5]) / sum(n_witness[last5]), 3),
                  covers_last5 = round(sum(n_covered[last5]) / sum(n_licence[last5]), 3),
                  .groups = "drop") |>
        knitr::kable(caption = "calibration: agreement with the licence register, the whole overlap and its last five years"))
print(calibration |> group_by(group, source) |> filter(all(n_licence == 0)) |>
        summarise(years = paste0(min(year), "-", max(year)), .groups = "drop") |>
        knitr::kable(caption = "witnesses with no overlap: uncalibrated"))

inputs <- c(file.path(fd_staging("kvoti"), paste0(c("licence", "licence_deleted", "licence_lumpfish", "licence_seine",
                                          "licence_revocation", "licence_arrears", "licence_date_fix", "quota_right",
                                          "mackerel_allocation", "mackerel_class", "effort_day_notice", "coastal_trip",
                                          "lumpfish_logbook"), ".parquet")),
            fd_curated("vessel", "vessel_class.parquet"),
            fd_curated("landing", "landings.parquet"), fd_curated("landing", "catch.parquet"))
write_curated(evidence, fd_curated("vessel", "licence", "evidence.parquet"), inputs = inputs)
write_curated(calibration, fd_curated("vessel", "licence", "calibration.parquet"), inputs = inputs)
