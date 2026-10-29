# Create standard summary tables
# Side: preprocessing (afli). See plan 014.
# Input:  raw/oracle/afli/{stofn,toga,lineha,gildra,hringn,afli}.parquet
#         raw/oracle/fs_afli/{stofn,toga,lineha,gildra,hringn,afli,rafr_stofn}.parquet
#         curated/reference/{dictionary,gear,port}.parquet
# Output: staging/afli/{trip,station,fishing_sample,sensor,catch,aggregate}.parquet

# Setup -----------------------------------------------------------------------
library(whack) # pak::pak("einarhjorleifsson/whack")
library(geo)
library(tidyverse)
library(duckdbfs)

SCHEMA <- "afli"
dictionary   <- duckdbfs::open_dataset(fd_curated("reference", "dictionary.parquet")) |> collect() |> filter(schema == SCHEMA)
gear_mapping <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> collect() |> filter(version == "old")
# hid is the Icelandic harbour code; pid is the standard port key minted once
# in reference/ports/ports_all.R and shared with the landings and AIS data.
# drop_na() is scoped to (hid, port) deliberately: 21 of 112 codes are sentinels
# or country placeholders with no pid, and a bare drop_na() would now discard
# them along with their names.
harbours <-
  duckdbfs::open_dataset(fd_curated("reference", "port.parquet")) |> collect() |>
  select(hid, port, pid) |>
  drop_na(hid, port)
# fs_afli is the Directorate's copy of this schema and holds all of it (decisions 122-124). The electronic
# logbooks of 2020-2024 came in through it and were read into afli.stofn, so afli's own rafr_ tables stop on
# 2020-07-23. Two things are taken from it: the eytt flag, from its rafr_stofn, and the paper stations
# afli.stofn lacks (positive ids), with copy = "fs_afli". The electronic stations afli lacks are left out:
# they are fs_afladagbok's hauls. curate/logbook.R ranks the added stations below fs_afladagbok, since where
# afli or fs_afladagbok has the vessel-day they are the same hauls entered again (decision 123).
# eytt flag: records officially deleted in Oracle (eytt=1 in rafr_stofn).
# eytt_deleted = TRUE  → deleted in Oracle; treat with caution / exclude.
# eytt_deleted = FALSE → active in Oracle (rafr_ era, 2003–2024).
# eytt_deleted = NA    → not in rafr_ (paper).
eytt_ref <- duckdbfs::open_dataset(fd_raw("oracle", "fs_afli", "rafr_stofn.parquet")) |> collect() |>
  select(visir, eytt) |>
  mutate(eytt_deleted = eytt == 1L) |>
  select(visir, eytt_deleted)
stofn_afli <- duckdbfs::open_dataset(fd_raw("oracle", "afli", "stofn.parquet")) |> collect()
stofn_fs <-
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afli", "stofn.parquet")) |> collect() |>
  filter(visir > 0, !visir %in% stofn_afli$visir) |>
  select(-uppruni)
FS_SID <- stofn_fs$visir
# A table of each copy, afli's whole and fs_afli's for the added stations only
read_copies <- function(table) {
  bind_rows(
    duckdbfs::open_dataset(fd_raw("oracle", "afli", table)) |> collect(),
    duckdbfs::open_dataset(fd_raw("oracle", "fs_afli", table)) |> filter(visir %in% FS_SID) |> collect())
}

# Source (stofn) --------------------------------------------------------------
# No explicit trip table in this schema; .tid derived as min(.sid) per
# (vid, T2, hid2). T1 is the minimum fishing date within the derived trip.
# Each copy makes its own trips, so an added station never changes an afli trip or its .tid.
source <-
  bind_rows(stofn_afli |> mutate(copy = "afli"),
            stofn_fs   |> mutate(copy = "fs_afli")) |>
  wk_translate(dictionary) |>
  filter(!is.na(date)) |>                        # 40 records have NA date
  # Remove ~41k monthly aggregate records (nephrops, shrimp, d-seine); these
  # are summaries at month-gear-vessel-square level, not individual hauls
  filter(
    is.na(comment) |
    (!comment %in% c("Frá OPS$SIGFUS.GAMALL_HUMAR, samantekt",
                     "Frá OPS$SIGFUS.GOMUL_RAEKJA, samantekt") &
     !str_starts(comment, "Frá afli.gomul_dragnot, samantekt"))
  ) |>
  mutate(lon1 = -geoconvert.1(x1 * 100),
         lat1 =  geoconvert.1(y1 * 100),
         lon2 = -geoconvert.1(x2 * 100),
         lat2 =  geoconvert.1(y2 * 100)) |>
  group_by(copy, vid, T2, hid2) |>
  mutate(.tid = min(.sid)) |>
  group_by(vid, .tid) |>
  mutate(T1 = min(date, na.rm = TRUE), hid1 = NA_integer_) |>
  ungroup() |>
  mutate(schema = SCHEMA) |>
  left_join(eytt_ref, by = c(".sid" = "visir")) |>
  select(.sid, .tid, vid, gid, date, lon1, lat1, lon2, lat2, sq, ssq, z1, z2,
         T1, hid1, T2, hid2, n_crew, schema, eytt_deleted, copy)

## The skipper's remark (stofn.athugas) ------------------------------------------
# A code of afli's table ATHUGASEMDIR (`rafr_stofn_aths_skipstjora`). Its twenties are the rig: 0-14 names none, 20-34
# two trawls ("Tvö troll"), 40-54 a pair trawl ("Tvílembingar", two vessels towing one trawl); the rest is the mishap,
# 0 none. 0 is "no remark", not "one trawl" (plan 050 §6, TODO 158). Kept as recorded and named: the rig is a witness
# for the count of trawls below, the mishap a flag, never a correction.
MISHAP <- c("snagged", "snagged and torn", "torn", "headline or fishing line broken", "fouled",
            "leg or bridle broken", "sweep or footrope broken", "codend holed", "released", "warp broken",
            "trawl lost", "winch broken", "engine failure", "steering failure")
remark <-
  bind_rows(stofn_afli |> select(.sid = visir, athugas), stofn_fs |> select(.sid = visir, athugas)) |>
  filter(!is.na(athugas)) |>
  transmute(.sid,
            rig = case_when(athugas %/% 20 == 1 ~ "twin", athugas %/% 20 == 2 ~ "pair"),
            mishap = MISHAP[na_if(as.integer(athugas %% 20), 0L)])

# Helper: station keys with ICES gear labels, used in aux table joins below
stofn_gear <- source |>
  select(.sid, gid) |>
  left_join(gear_mapping |> select(gid, gear), by = "gid")

# Trip ------------------------------------------------------------------------
# Derived: one row per (vid, T2, hid2) group
trip <-
  source |>
  select(.tid, vid, T1, hid1, T2, hid2, n_crew, schema) |>
  distinct(.tid, vid, T1, hid1, T2, hid2, .keep_all = TRUE) |>
  left_join(harbours |> select(hid, pid1 = pid), by = join_by(hid1 == hid)) |>
  left_join(harbours, by = join_by(hid2 == hid)) |>
  rename(pid2 = pid)
#trip |> count(hid2, port) |> knitr::kable()
# Station (spatial/temporal envelope) -----------------------------------------
station <-
  source |>
  select(.sid, .tid, date, lon1, lat1, lon2, lat2, sq, ssq, z1, z2, schema,
         eytt_deleted, copy)

# Aux tables ------------------------------------------------------------------
# Each block reads one source parquet, translates columns, and inner-joins to
# the relevant gear class. All downstream fishing_sample, sensor, and dims
# content is extracted from these four objects — no further sub-objects.

## Mobile (toga: OTB / OTM / DRB / SDN) ---------------------------------------
aux_mobile <-
  read_copies("toga.parquet") |>
  wk_translate(dictionary) |>
  inner_join(stofn_gear |> filter(gear %in% c("DRB", "OTB", "OTM", "SDN")),
             by = ".sid")

## Static (lineha: LLS / GNS / GND / LHM) -------------------------------------
aux_static <-
  read_copies("lineha.parquet") |>
  rename(.sid = visir) |>
  wk_translate(dictionary) |>
  inner_join(stofn_gear |> filter(gear %in% c("LLS", "GNS", "GND", "LHM")),
             by = ".sid")

## Trap (gildra: FPO) ----------------------------------------------------------
aux_trap <-
  read_copies("gildra.parquet") |>
  wk_translate(dictionary) |>
  inner_join(stofn_gear |> filter(gear == "FPO"), by = ".sid") |>
  mutate(duration_m = duration_h * 60)

## Seine / ring net (hringn: PS) -----------------------------------------------
aux_seine <-
  read_copies("hringn.parquet") |>
  wk_translate(dictionary) |>
  inner_join(stofn_gear |> filter(gear == "PS"), by = ".sid")

# Fishing sample --------------------------------------------------------------

## Timing ----------------------------------------------------------------------
# Event timestamps and soak/tow duration from each aux table.
# Grammar (t1–t4):
#   Mobile (OTB/OTM/DRB/SDN): t2 = gear-on-bottom (derived from ibotni/hhmm);
#     t3 = tow end (t2 + duration_m); t1 and t4 not recorded in toga.
#   Static (LLS/GNS/GND): t1 = deployment start (logn_hefst); t3 = retrieval
#     start (drattur_hefst); t4 = retrieval end (drattur_lykur); t2 not recorded.
#   Jig/handline (LHM): timestamps in lineha in ~3% of rows only; duration from
#     klst (hours) or naetur (days) in the remainder.
timing <-
  bind_rows(
    aux_mobile |> select(.sid, hhmm, duration_m),
    aux_static |>
      mutate(duration_m = case_when(!is.na(duration_d) ~ duration_d * 24 * 60,
                                    !is.na(duration_h) ~ duration_h * 60)) |>
      select(.sid, t1, t3, t4, duration_m),
    aux_trap   |> select(.sid, duration_m),
    aux_seine  |> select(.sid, hhmm)
  ) |>
  filter(!if_all(-.sid, is.na))

## Gear dimensions + the count ------------------------------------------------
# One row per station; columns vary by gear class (NA elsewhere). effort_count is the grammar's one count
# (R/logbook_effort.R): hooks, nets, jigs, traps, and the trawls or dredges of a towed gear. n_units keeps the gear
# table's own value in staging. Its basis is "recorded", or "derived" where it is made from the record's other
# values: a longline's sets × hooks per set, and a towed gear's tvo_veidarf, a flag, 0 one gear and 1 two (plan
# 050 §6: per vessel, afli's share flagged follows fs_afladagbok's share counted 2 or more), with the skipper's remark
# as a second witness: two where either says two (the maintainer, 2026-10-29, TODO 158; the remark says two trawls on
# 19,783 bottom-trawl tows with no flag and on 5,484 flagged 0).
twin_count <- function(flag, rig) case_when(rig %in% "twin" | flag %in% 1 ~ 2, flag %in% 0 ~ 1)
dims <-
  bind_rows(
    # OTB / OTM / DRB — trawl, dredge / plow
    aux_mobile |>
      filter(gear %in% c("OTB", "OTM")) |>
      left_join(remark |> select(.sid, rig), by = ".sid") |>
      mutate(effort_count = twin_count(n_units, rig), effort_count_basis = "derived") |>
      select(.sid, n_units, effort_count, effort_count_basis, bottom_type, catch_nperkg),
    aux_mobile |>
      filter(gear == "DRB") |>
      left_join(remark |> select(.sid, rig), by = ".sid") |>
      mutate(effort_count = twin_count(n_units, rig), effort_count_basis = "derived") |>
      select(.sid, n_units, effort_count, effort_count_basis,
             g_mesh = mesh, g_width = width_plow, g_height = height_plow, g_length = length_plow,
             bottom_type, catch_nperkg),
    # SDN — Danish seine (effort is per setting, not time-based)
    aux_mobile |>
      filter(gear == "SDN") |>
      select(.sid, g_mesh = mesh, length_togle, length_virle, mesh_vod, length_headline, length_fotreipi),
    # LLS — longline
    aux_static |>
      filter(gear == "LLS") |>
      mutate(n_total = case_when(!is.na(n_hooks)                          ~ n_hooks,
                                 !is.na(n_hooks_per_set) & !is.na(n_sets) ~ n_hooks_per_set * n_sets),
             effort_count = recorded_count(n_total),
             effort_count_basis = if_else(is.na(n_hooks), "derived", "recorded")) |>
      filter(!if_all(c(n_hooks, n_hooks_per_set, n_sets), is.na)) |>
      select(.sid, n_total, n_per_unit = n_hooks_per_set, n_units = n_sets,
             effort_count, effort_count_basis),
    # GNS / GND — gillnet
    aux_static |>
      filter(gear %in% c("GNS", "GND")) |>
      mutate(n_units      = n_nets,
             length       = n_nets * mean_gillnet_length,
             effort_count = recorded_count(n_units),
             effort_count_basis = "recorded") |>
      select(.sid, n_units, g_mesh = mesh, g_height, g_length = length, n_lost,
             effort_count, effort_count_basis),
    # LHM — handline / jig
    aux_static |>
      filter(gear == "LHM") |>
      mutate(effort_count = recorded_count(n_jigs), effort_count_basis = "recorded") |>
      select(.sid, n_units = n_jigs, n_per_unit = n_hooks,
             effort_count, effort_count_basis),
    # FPO — traps
    aux_trap |>
      mutate(effort_count = recorded_count(n_units), effort_count_basis = "recorded") |>
      select(.sid, n_units, effort_count, effort_count_basis),
    # PS — purse seine / ring net (effort is per set)
    aux_seine |>
      select(.sid, g_mesh = mesh, g_length, g_height)
  ) |>
  mutate(effort_count_basis = if_else(is.na(effort_count), NA_character_, effort_count_basis))


## Duration limits -------------------------------------------------------------
# Not here any more: the plausible maximum per gear is reference/gear/windows.R
# (gear_window.dur_max_min) and the rule is R/duration_limit.R, shared with
# fs_afladagbok. This adapter used to cap a long duration at a hand-set value and keep
# only the capped one; see curate/plans/010-ping-activity-link.md §12.
gear_window <- duckdbfs::open_dataset(fd_curated("reference", "gear_window.parquet")) |> collect()

## Assemble fishing_sample -----------------------------------------------------
fishing_sample <-
  source |>
  select(.tid, .sid, gid, date, schema, eytt_deleted) |>
  # Old → new gear code mapping done once here
  rename(gid_old = gid) |>
  left_join(gear_mapping |> select(gid_old = gid, gid = map, gear, target, target2),
            by = "gid_old") |>
  left_join(timing, by = ".sid") |>
  # The Nephrops tow times before 2000 were blanked here as "recorded in hours not minutes" until plan 050
  # (2026-10-29). They are minutes: median 270-300, 95 % at or below 360, in every five years from 1965 (132,740 tows
  # to 1999), as after 2000. The gear's limit below takes the 10 above 720 minutes.
  # A duration above the gear's limit is flagged and kept (R/duration_limit.R; plan 050 ask h). The tow end made
  # from it below is left out where the times are read.
  flag_duration_limit(gear_window) |>
  # The count (R/logbook_effort.R). The effort is made from the times, the recorded duration and the count by
  # calc_effort(), not stored.
  left_join(dims |> select(.sid, effort_count, effort_count_basis), by = ".sid") |>
  add_effort_count()


## Timestamps ------------------------------------------------------------------
# Mobile (OTB/OTM/DRB/SDN): t1 and t4 are not recorded (NA).
#   t2 = gear-on-bottom; derived from ibotni (hhmm field in toga).
#   t3 = tow end; derived from t2 + duration_m (togtimi).
# Static (LLS/GNS/GND/LHM/FPO): t1/t3/t4 come from lineha; t2 not recorded.
# Jig/LHM: timestamps in lineha in ~3% of rows only; duration from klst/naetur.
fishing_sample <- fishing_sample |>
  mutate(t2 = NA_POSIXct_) |>
  mutate(.t2_source = if_else(!is.na(hhmm), "data", "derived"),
         .t3_source = if_else(!is.na(t3),   "data", "derived"),
         # A tow time of 0 or less (35 tows) is kept and flagged implausible, as any value out of range is (plan 050
         # ask h); it was NA here until then.
         # 00:00-00:59 is a time like any other: hour 0 holds 185,943 tow starts, between hour 23's 158,605 and
         # hour 1's 160,769. A `>= 100` here dropped them all until 2026-10-14 (decision 087).
         hhmm = if_else(!is.na(hhmm) & hhmm >= 0, hhmm, NA_real_),
         hh   = as.integer(hhmm %/% 100),
         hh   = if_else(hh < 24, hh, NA_integer_),
         mm   = as.integer(hhmm %% 100),
         mm   = if_else(mm < 60 & !is.na(hh), mm, NA_integer_),
         t2   = case_when(!is.na(t2)              ~ t2,
                          !is.na(hh) & !is.na(mm) ~ as_datetime(date) + hours(hh) + minutes(mm)),
         t3   = case_when(!is.na(t3)                        ~ t3,
                          !is.na(t2) & !is.na(duration_m)   ~ t2 + minutes(as.integer(duration_m)))) |>
  select(-c(hhmm, hh, mm))


## Overlap QC ------------------------------------------------------------------
# Label each operation against its neighbours on the same vessel in `.checks`
# (on t2/t3, so it effectively tests mobile gear: static gear has no t2 and is
# labelled "start time missing"). The label is a flag, and since plan 050 ask h (2026-10-29) only a flag: an
# impossible interval (start after or equal to end, from a tow time of 0 or less) kept its times blanked until then,
# and its end is now left out where the times are read (R/duration_limit.R). Until 2026-10-13 every label but
# "ok" blanked t2 and t3 (decision 083), which on the 2026-10-09 build dropped
#   217,816 recorded static-gear haul starts (t3; the haul is t3 to t4),
#   1,087,355 recorded tow starts with no duration (t2), and
#   188,165 tows that overlap a neighbour (t2/t3), each turned into a whole-day
#   window although station_window cuts a window back at the vessel's next
#   recorded start (win_basis "capped").
fishing_sample <- fishing_sample |>
  inner_join(trip |> select(.tid, vid) |> distinct(), by = ".tid") |>
  arrange(vid, date, t2) |>
  osfd::fd_flag_time_overlaps(t2, t3, by = vid) |>
  select(-vid)


## Join gear dimensions --------------------------------------------------------
fishing_sample <- fishing_sample |>
  left_join(dims |> select(-effort_count, -effort_count_basis), by = ".sid") |>
  left_join(remark, by = ".sid", relationship = "many-to-one")


## Back-entry flag -------------------------------------------------------------
# TRUE for records with pre-1980 dates AND .sid > 2,500,000.
# Rationale: genuine contemporaneous early records (1969–1979) have .sid ≤ 2.34M;
# all pre-1980 records above that threshold form identified retrospective
# back-entry batches. See afli-backentry.qmd for full derivation.
fishing_sample <- fishing_sample |>
  mutate(back_entry = !is.na(date) & year(date) < 1980 & .sid > 2500000)

fishing_sample <- fishing_sample |>
  select(-date)
# Sensor -----------------------------------------------------------------------
sensor <-
  bind_rows(
    aux_mobile |>
      select(.sid, gid, gear,
             flag_hoflinum, flag_nemi, sensor_type,
             temp1_surface, temp2_surface, temp1_bottom, temp2_bottom,
             temp1_headline, temp2_headline, z1_headline, z2_headline),
    aux_static |>
      select(.sid, gid, gear, temp1_air, temp1_surface, temp1_bottom, seastate),
    aux_seine  |>
      select(.sid, gid, gear, seastate)
  ) |>
  filter(!if_all(-c(.sid, gid, gear), is.na))

# Catch -----------------------------------------------------------------------
catch <-
  read_copies("afli.parquet") |>
  wk_translate(dictionary, "messy", "clean") |>
  select(.sid, sid, catch) |>
  group_by(.sid, sid) |>
  summarise(catch = sum(catch, na.rm = TRUE), .groups = "drop") |>
  inner_join(fishing_sample |> select(.sid, schema), by = ".sid") |>
  arrange(.sid, sid)

# Aggregate records (monthly summaries, not individual hauls) -----------------
# Excluded from station/fishing_sample but preserved as a flat catch table:
# one row per (period × gear × vessel × sq × species).
# date is mid-month (15th); no coordinates available; duration_m is total
# aggregated tow time for the period (not a single-haul value).
agg_stofn <-
  duckdbfs::open_dataset(fd_raw("oracle", "afli", "stofn.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  filter(!is.na(date)) |>
  filter(
    comment %in% c("Frá OPS$SIGFUS.GAMALL_HUMAR, samantekt",
                   "Frá OPS$SIGFUS.GOMUL_RAEKJA, samantekt") |
    str_starts(comment, "Frá afli.gomul_dragnot, samantekt")
  ) |>
  mutate(
    agg_type = case_when(
      comment == "Frá OPS$SIGFUS.GAMALL_HUMAR, samantekt"      ~ "nephrops",
      comment == "Frá OPS$SIGFUS.GOMUL_RAEKJA, samantekt"      ~ "shrimp",
      str_starts(comment, "Frá afli.gomul_dragnot, samantekt") ~ "dseine"
    )
  ) |>
  select(.sid, vid, gid, date, sq, ssq, agg_type)

agg_catch <-
  duckdbfs::open_dataset(fd_raw("oracle", "afli", "afli.parquet")) |> collect() |>
  wk_translate(dictionary, "messy", "clean") |>
  select(.sid, sid, catch) |>
  inner_join(agg_stofn, by = ".sid") |>
  left_join(
    duckdbfs::open_dataset(fd_raw("oracle", "afli", "toga.parquet")) |> collect() |>
      wk_translate(dictionary) |>
      select(.sid, duration_m),
    by = ".sid"
  ) |>
  select(.sid, vid, gid, date, sq, ssq, agg_type, sid, catch, duration_m) |>
  arrange(.sid, sid)


# Export -----------------------------------------------------------------------
trip           |> duckdbfs::write_dataset(fd_staging("afli", "trip.parquet"))
station        |> duckdbfs::write_dataset(fd_staging("afli", "station.parquet"))
fishing_sample |> duckdbfs::write_dataset(fd_staging("afli", "fishing_sample.parquet"))
sensor         |> duckdbfs::write_dataset(fd_staging("afli", "sensor.parquet"))
catch          |> duckdbfs::write_dataset(fd_staging("afli", "catch.parquet"))
agg_catch      |> duckdbfs::write_dataset(fd_staging("afli", "aggregate.parquet"))


# QC scratch (if FALSE) -------------------------------------------------------
if (FALSE) {

  ## Duration distributions by gear type ---------------------------------------
  fishing_sample |>
    ggplot(aes(duration_m / 60, fill = target2)) +
    geom_histogram() +
    facet_wrap(~ gear, scales = "free") +
    scale_fill_brewer(palette = "Set1")

  ## t2/t3 source breakdown ----------------------------------------------------
  fishing_sample |> count(.t2_source, .t3_source)

  fishing_sample |>
    ggplot(aes(duration_m / 60, fill = .t1_source)) +
    geom_histogram() +
    facet_wrap(~ gear, scales = "free") +
    scale_fill_brewer(palette = "Set1")

  ## E-book vs paper logbook over time ----------------------------------------
  fishing_sample |>
    mutate(.ebook = if_else(.sid < 0, "yes", "no"),
           year   = year(date)) |>
    count(year, .ebook, gear) |>
    filter(year >= 1973) |>
    ggplot(aes(year, n, colour = .ebook)) +
    geom_point() +
    facet_wrap(~ gear, scales = "free_y")

  ## Overlap check breakdown ---------------------------------------------------
  fishing_sample |>
    count(.t1_source, .checks) |>
    group_by(.t1_source) |>
    mutate(p = n / sum(n)) |>
    ungroup()

  ## Cross-check against landings ----------------------------------------------
  lods_londun <-
    duckdbfs::open_dataset(fd_raw("oracle", "kvoti", "lods_londun.parquet")) |> collect() |>
    select(.lid = komunr, vid = skip_nr, D2 = l_dags, hid2 = hofn,
           comment = aths, stada) |>
    mutate(D2 = as_date(D2))
  lods_londun_distinct <-
    lods_londun |>
    filter(vid != 9999) |>
    arrange(vid, D2, hid2, .lid) |>
    distinct(vid, D2, hid2, .keep_all = TRUE)
  trip |>
    mutate(D2 = as_date(T2)) |>
    filter(between(D2, ymd("1992-09-01"), ymd("2020-12-31"))) |>
    inner_join(fishing_sample |> select(.tid, gid) |> distinct(.tid, .keep_all = TRUE)) |>
    left_join(lods_londun_distinct) |>
    mutate(has.lid = !is.na(.lid),
           D2 = floor_date(D2, "month")) |>
    count(D2, has.lid) |>
    ggplot(aes(D2, n, fill = has.lid)) +
    geom_col(position = "fill")

}
