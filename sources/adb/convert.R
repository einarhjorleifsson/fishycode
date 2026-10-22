# Create standard summary tables
# Side: preprocessing (adb). See plan 014.
# Input: raw/oracle/adb/{trip_v,fishing_trip,fishing_station,trawl_and_seine_net_v,dredge_v,line_and_net_v,trap_v,
#        surrounding_net_v,catch}.parquet
# Output: staging/adb/{trip,station,fishing_sample,catch}.parquet

library(whack) # pak::pak("einarhjorleifsson/whack)
library(geo)
library(tidyverse)
library(duckdbfs)

# seeding ----------------------------------------------------------------------
SCHEMA <- "adb"
dictionary <- duckdbfs::open_dataset(fd_curated("reference", "dictionary.parquet")) |> collect() |>
  filter(schema == SCHEMA)

# trip -------------------------------------------------------------------------
trip <- duckdbfs::open_dataset(fd_raw("oracle", "adb", "trip_v.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  select(.tid, vid, T1, hid1, T2, hid2) |>
  mutate(schema = SCHEMA)

# base -------------------------------------------------------------------------
# The table, not Oracle's view station_v: the view reads every six-digit position as ddmm.hh where the digits are
# ddmmss (curate/corrections/adb_station_v_positions.yml). decode_logbook_position() (R/logbook_position.R) reads them
# and turns the longitude's sign as the view did. Depth is the table's fathoms, as fs_afladagbok's; curate/logbook.R
# converts both. Renamed to the view's names, which the dictionary holds.
trip_source <- duckdbfs::open_dataset(fd_raw("oracle", "adb", "fishing_trip.parquet")) |>
  select(trip_id = id, source) |> collect()

base <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "fishing_station.parquet")) |> collect() |>
  rename(station_id = fishing_station_id, trip_id = fishing_trip_id, gear_no = fishing_gear_no) |>
  left_join(trip_source, by = "trip_id", relationship = "many-to-one") |>
  mutate(hundredths = logbook_position_hundredths(trip_id, source, latitude, longitude, latitude_end, longitude_end),
         pos1 = decode_logbook_position(latitude, longitude, hundredths),
         pos2 = decode_logbook_position(latitude_end, longitude_end, hundredths),
         latitude = pos1$lat, longitude = pos1$lon, latitude_end = pos2$lat, longitude_end = pos2$lon) |>
  wk_translate(dictionary) |>
  mutate(date = as_date(coalesce(t1, t3, t4))) |>
  select(.tid, .sid, gid, date,
         t1, t3, t4,
         lon1, lat1, lon2, lat2,
         z1, z2)

# aux tables -------------------------------------------------------------------
## Each block computes effort for its gear class and selects only
##   .sid, effort, effort_unit, and any gear-specific columns (towtime,
##   gear_width).  All inner_joins are on .sid only; base carries gid and
##   times needed for the calculations.

## mobile (trawl / seine-net) --------------------------------------------------
mobile_aux <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "trawl_and_seine_net_v.parquet")) |> collect() |>
  wk_translate(dictionary) |>                  # station_id → .sid; bridle_length → sweeps
  inner_join(base |> select(.sid, gid, t3, t4), by = ".sid") |>
  mutate(
    towtime = as.numeric(difftime(t4, t3, units = "mins")),
    effort = case_when(
      gid %in% c(6, 7, 14) ~ towtime / 60,
      gid == 5              ~ 1,
      .default = NA_real_
    ),
    effort_unit = case_when(
      gid %in% c(6, 7, 14) ~ "hours towed",
      gid == 5              ~ "setting",
      .default = NA_character_
    ),
    gear_width = if_else(!is.na(sweeps), sweeps, NA_real_)
  ) |>
  select(.sid, effort, effort_unit, towtime, gear_width)

## dredge (plógur) -------------------------------------------------------------
##   dredge_v covers gid 5, 6, 7, 51, 53 that are absent from trawl_and_seine_net_v
dredge_aux <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "dredge_v.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(base |> select(.sid, t3, t4), by = ".sid") |>
  mutate(
    towtime   = as.numeric(difftime(t4, t3, units = "mins")),
    effort    = towtime / 60,
    effort_unit = "hours towed",
    gear_width  = width
  ) |>
  select(.sid, effort, effort_unit, towtime, gear_width)

## static (longline / gillnet / handline) --------------------------------------
static_aux <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "line_and_net_v.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(base |> select(.sid, gid, t3, t4), by = ".sid") |>
  mutate(
    dt = as.numeric(difftime(t4, t3, units = "hours")),
    effort = case_when(
      gid == 1                             ~ hooks,
      gid %in% c(2, 11, 25, 29, 91, 92)   ~ nets * dt / 24,
      gid == 3                             ~ dt,
      .default = NA_real_
    ),
    effort_unit = case_when(
      gid == 1                             ~ "hooks",
      gid %in% c(2, 11, 25, 29, 91, 92)   ~ "netnights",
      gid == 3                             ~ "hookhours",
      .default = NA_character_
    )
  ) |>
  select(.sid, effort, effort_unit)

## traps -----------------------------------------------------------------------
trap_aux <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "trap_v.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(base |> select(.sid, t3, t4), by = ".sid") |>
  mutate(
    dt          = as.numeric(difftime(t4, t3, units = "hours")),
    effort      = number_of_traps * dt,
    effort_unit = "traphours"
  ) |>
  select(.sid, effort, effort_unit)

## seine / surrounding net -----------------------------------------------------
seine_aux <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "surrounding_net_v.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(base |> select(.sid), by = ".sid") |>
  mutate(effort = 1, effort_unit = "setting") |>
  select(.sid, effort, effort_unit)

# station table ----------------------------------------------------------------
station <-
  base |>
  left_join(
    bind_rows(mobile_aux, dredge_aux, static_aux, trap_aux, seine_aux),
    by = ".sid"
  ) |>
  mutate(schema = SCHEMA) |>
  arrange(date, .sid, t1, t3, t4)

# catch ------------------------------------------------------------------------
catch <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "catch.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  # `quantity` is fs_afladagbok's `magn` (equal on all 1.07 M shared rows where weight is NULL): the weight in
  # the state `condition` names. `weight` is fs's `afli`, the whole-fish weight, NULL for ~98 % of rows from
  # 2023 - summing it with na.rm gave catch 0 for most trips (decision 066). Same layout as the fs adapter.
  rename(.sid = fishing_station_id,
         sid = species_no,
         catch_whole = weight,
         catch = quantity) |>
  select(.sid, sid, condition, catch_whole, catch) |>
  group_by(.sid, sid, condition) |>
  summarise(catch_whole = if (all(is.na(catch_whole))) NA_real_ else sum(catch_whole, na.rm = TRUE),
            catch = sum(catch, na.rm = TRUE),
            .groups = "drop") |>
  # ensure that catch record not an orphan
  inner_join(station |> select(.sid, schema)) |>
  arrange(.sid, sid)

# split station into station + fishing_sample ----------------------------------
#
# This converter used to emit ONE fat station table carrying gid, t1/t3/t4,
# effort, towtime and gear_width. afli and fs_afladagbok split that detail into
# a narrow station (keys, date, position, depth) plus a fishing_sample holding
# the fishing operation, joined on .sid. That mismatch is why adb could never be
# merged: curate/logbook.R binds FOUR tables and adb supplied three.
#
# gid is left NA here and adb's code is kept verbatim as gid_old. That code is
# the old gear code, the GEAR schema's fishing_gear_no, which the converter's
# own effort logic keys on (gid %in% c(6,7,14), and dredge_v "covers gid
# 5,6,7,51,53"). adb's own table fishing_gear maps it to the FS number, the new
# gid: 53 dredge -> 15, 51 crab trap -> 16, and the rest as reference/gear.parquet's
# old code does. curate/corrections/logbook_gear.R reads it through that table
# (plan 034, 2026-10-20), and the landing's gear still wins where it names one.
# Decision 066 found the code did not resolve against the reference as it read
# it then (6,654 rows of 53/51 in neither), so until plan 034 an adb station's
# gear came only from its landing.

station_narrow <-
  station |>
  select(.sid, .tid, date, lon1, lat1, lon2, lat2, z1, z2, schema)

fishing_sample <-
  station |>
  transmute(
    .tid, .sid,
    gid_old = as.integer(gid),      # adb's own coding, kept verbatim
    gid     = NA_real_,             # filled downstream from landings
    gear    = NA_character_,
    target  = NA_character_,
    target2 = NA_character_,
    t1,
    t2 = as.POSIXct(NA),            # adb records no deployment-end time
    t3, t4,
    duration_m = as.numeric(towtime),   # towtime is already minutes
    effort_count    = NA_integer_,
    effort_duration = NA_real_,
    effort_unit,
    effort = as.numeric(effort),
    n_units = NA_integer_,
    n_lost  = NA_integer_,
    g_mesh   = NA_real_,
    g_width  = as.numeric(gear_width),
    g_length = NA_real_,
    g_height = NA_real_,
    schema)

# save -------------------------------------------------------------------------
trip           |> duckdbfs::write_dataset(fd_staging("adb", "trip.parquet"))
station_narrow |> duckdbfs::write_dataset(fd_staging("adb", "station.parquet"))
fishing_sample |> duckdbfs::write_dataset(fd_staging("adb", "fishing_sample.parquet"))
catch          |> duckdbfs::write_dataset(fd_staging("adb", "catch.parquet"))
