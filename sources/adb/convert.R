# Create standard summary tables
# Side: preprocessing (adb). See plan 014.
# Input: raw/oracle/adb/{fishing_trip,fishing_station,trawl_and_seine_net,dredge,line_and_net,trap,catch,
#        fishing_gear}.parquet; curated/reference/{gear,gear_window}.parquet
# Output: staging/adb/{trip,station,fishing_sample,catch}.parquet

library(whack) # pak::pak("einarhjorleifsson/whack)
library(geo)
library(tidyverse)
library(duckdbfs)

# seeding ----------------------------------------------------------------------
SCHEMA <- "adb"
dictionary <- duckdbfs::open_dataset(fd_curated("reference", "dictionary.parquet")) |> collect() |>
  filter(schema == SCHEMA)

# Every Oracle object read here is a table, never a view (AGENTS.md, Rules; decision 170). Each is renamed to its
# former view's names, which the dictionary holds, and the view's unit factors are done in R.

# trip -------------------------------------------------------------------------
# trip_v's trip_id is the table's VARCHAR id, not its fishing_trip_id. Only the columns used: the table holds persons'
# data (vessel_gsm, company_ssn).
trip <- duckdbfs::open_dataset(fd_raw("oracle", "adb", "fishing_trip.parquet")) |>
  select(trip_id = id, vessel_no, departure, departure_port_no, landing, landing_port_no) |> collect() |>
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
## Each block reads one gear table's count and dimensions, as fs_afladagbok's adapter reads the same fields
## (equal on every station both hold: two_fg = tvo_veidarf, two_dredges = ws_plogur's tvo_veidarf, hooks, nets and
## pole_and_lines = fj_kroka, fj_dreginna_neta and fj_faera, number_of_traps = fj_gildra; plan 050 §6). The effort
## is the grammar's, made in the fishing sample below. adb's own units ("hours towed", "netnights", "hookhours"),
## made here until plan 050 step 2, are gone with it.

## mobile (trawl / seine-net) --------------------------------------------------
##   The bridle is in fathoms, converted as trawl_and_seine_net_v did. two_fg counts the trawls.
mobile_aux <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "trawl_and_seine_net.parquet")) |>
  select(station_id = fishing_station_id, bridle, two_fg) |> collect() |>
  mutate(bridle_length = bridle * 1.8288) |>
  wk_translate(dictionary) |>                  # station_id → .sid; bridle_length → sweeps
  select(.sid, n_gear = two_fg, gear_width = sweeps)

## dredge (plógur) -------------------------------------------------------------
##   The width is in feet (fs_afladagbok's ws_plogur says "fet"); dredge_v took a foot as 0.3042 m.
dredge_aux <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "dredge.parquet")) |>
  select(station_id = fishing_station_id, width, two_dredges) |> collect() |>
  mutate(width = width * 0.3048) |>
  wk_translate(dictionary) |>
  select(.sid, n_gear = two_dredges, gear_width = width)

## static (longline / gillnet / handline) --------------------------------------
static_aux <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "line_and_net.parquet")) |>
  select(station_id = fishing_station_id, hooks, nets, pole_and_lines) |> collect() |>
  wk_translate(dictionary) |>
  select(.sid, n_hooks = hooks, n_nets = nets, n_jigs = pole_and_lines)

## traps -----------------------------------------------------------------------
trap_aux <-
  duckdbfs::open_dataset(fd_raw("oracle", "adb", "trap.parquet")) |>
  select(station_id = fishing_station_id, number_of_traps) |> collect() |>
  wk_translate(dictionary) |>
  select(.sid, n_traps = number_of_traps)

# station table ----------------------------------------------------------------
station <-
  base |>
  left_join(
    bind_rows(mobile_aux, dredge_aux, static_aux, trap_aux),
    by = ".sid", relationship = "one-to-one"
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
# adb writes the old gear code, the GEAR schema's fishing_gear_no; it is kept
# verbatim as gid_old (the converter's own effort keyed on it until plan 050
# step 2). adb's conversion from the
# FS number is undone here, where it enters (plan 050 step 4): adb's own table
# fishing_gear maps the code back to the FS number, the new gid, as afli and
# fs_afladagbok carry it (53 dredge -> 15, 51 crab trap -> 16, the rest as
# reference/gear.parquet's old code). Back through it, every station adb shares
# with fs_afladagbok from 2025 on has fs's code; the 5,256 wrong and 432 coded 99
# are 2019-2024, which the merge takes from fs_afladagbok (decision 160). Code
# 99, gear not recorded, has no row there and keeps no gear. The landing's gear
# still wins where it names one (curate/corrections/logbook_gear.R).
# A code is listed once per gear type, with the same FS number.
gear_code <- duckdbfs::open_dataset(fd_raw("oracle", "adb", "fishing_gear.parquet")) |>
  distinct(gid_old = as.integer(fishing_gear_no), gid = as.integer(id)) |> collect()
stopifnot(!anyDuplicated(gear_code$gid_old))
gear_mapping <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> collect() |>
  filter(version == "new") |> select(gid, gear, target, target2)

station_narrow <-
  station |>
  select(.sid, .tid, date, lon1, lat1, lon2, lat2, z1, z2, schema)

gear_window <- duckdbfs::open_dataset(fd_curated("reference", "gear_window.parquet")) |> collect()

# adb's times are fs_afladagbok's, field for field, and are read as that adapter reads them (R/logbook_effort.R):
# fishing_start, tow_start and fishing_end are t1, t3 and t4 here, as the dictionary names them. Until plan 050
# step 2 they were kept as read, and a towed gear's start and end sat in t1 and t4 with no duration;
# curate/station_window.R moved them. The count is read per gear, as afli's and fs's are.
fishing_sample <-
  station |>
  mutate(gid_old = as.integer(gid), .keep = "unused") |>
  left_join(gear_code, by = "gid_old", relationship = "many-to-one") |>
  left_join(gear_mapping, by = "gid", relationship = "many-to-one") |>
  mutate(gid = as.numeric(gid)) |>
  elogbook_times(gear_window) |>
  mutate(effort_count = recorded_count(case_when(gear %in% c("OTB", "OTM", "DRB") ~ n_gear,
                                                 gear == "LLS"                    ~ n_hooks,
                                                 gear %in% c("GNS", "GND")        ~ n_nets,
                                                 gear == "LHM"                    ~ n_jigs,
                                                 gear == "FPO"                    ~ n_traps)),
         effort_count_basis = if_else(is.na(effort_count), NA_character_, "recorded")) |>
  add_effort_count() |>
  transmute(
    .tid, .sid,
    gid_old,                        # adb's own coding, kept verbatim
    gid, gear, target, target2,
    t1, t2, t3, t4,
    duration_m, duration_m_raw, .duration_source,
    effort_count, effort_count_basis, effort_count_unit,
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
