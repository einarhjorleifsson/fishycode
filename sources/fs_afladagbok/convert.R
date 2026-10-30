# Create standard summary tables
# Side: preprocessing (fs_afladagbok). See plan 014.
# Input:  raw/oracle/fs_afladagbok/{ws_veidiferd,ws_veidi,ws_afli,
#           ws_dragnot_varpa,ws_plogur,ws_linanethandf,ws_gildra,ws_hringn}.parquet;
#         raw/oracle/fs_afladagbok/{tour,fishing_spot,catch}.parquet (the tour app, plan 019 §4);
#         curated/reference/{dictionary,gear,gear_window,port}.parquet; curated/landing/landings.parquet (the tour
#         trips' class); curate/corrections/logbook_app_profile.yml (the position rows P3, P4)
# Output: staging/fs_afladagbok/{trip,station,fishing_sample,catch}.parquet, the tour app's trips, spots and catch
#         among them (source "tour")

# Setup -----------------------------------------------------------------------
library(whack)     # pak::pak("einarhjorleifsson/whack")
library(geo)
library(tidyverse)
library(duckdbfs)

SCHEMA <- "fs_afladagbok"
dictionary   <- duckdbfs::open_dataset(fd_curated("reference", "dictionary.parquet")) |> collect() |> filter(schema == SCHEMA)
gear_mapping <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> collect() |> filter(version == "new")
gear_window  <- duckdbfs::open_dataset(fd_curated("reference", "gear_window.parquet")) |> collect()
# hid is the Icelandic harbour code, hid_new this schema's own code, and pid the
# standard port key from reference/ports/ports_all.R. drop_na() is scoped so
# that a code without a pid keeps its name rather than vanishing.
harbours <-
  duckdbfs::open_dataset(fd_curated("reference", "port.parquet")) |> collect() |>
  select(hid_new = hafnarnumer_id, port, hid, pid) |>
  drop_na(hid_new, hid, port)




# Trip -------------------------------------------------------------------------
# Built first: `source` (uppruni) is a trip-level column in ws_veidiferd and
# is needed for coordinate classification in ws_veidi below.
trip <-
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_veidiferd.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  rename(.tid = id) |>
  mutate(n_crew = NA_integer_, schema = SCHEMA) |>
  select(.tid, vid, T1, hid1, T2, hid2, n_crew, source, schema)
trip <- trip |>
  rename(hid_new = hid1) |>
  left_join(harbours,
            by = join_by(hid_new == hid_new)) |>
  select(.tid, vid, T1, hid1 = hid, pid1 = pid, T2, hid2, n_crew, source, schema) |>
  rename(hid_new = hid2) |>
  left_join(harbours,
            by = join_by(hid_new == hid_new)) |>
  select(.tid, vid, T1, hid1, pid1, T2, hid2 = hid, pid2 = pid, port,
         n_crew, source, schema)
# Source (ws_veidi) -----------------------------------------------------------
# Translate columns, join trip-level `source` for coordinate classification,
# then convert raw integer coordinates to decimal degrees.
# After this block `source` has: .sid .tid gid t1 t3 t4 lon1 lat1 lon2 lat2 pos1_form pos2_form
# z1 z2 n_lost date record_entered schema. record_entered is the record's entry time (skraningartimi), which the app
# profile reads (curate/corrections/logbook_app_profile.yml, rows T12 and T16).
# t1, t3, t4 here are the dictionary's names for upphaf_timi, milli_timi, lok_timi, not yet
# the grammar's: fishing_sample below remaps them by gear class, mobile gear taking
# upphaf_timi as t2 and lok_timi as t3. milli_timi is empty for OTB/OTM/DRB and equals
# upphaf_timi for SDN.
source <-
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_veidi.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  rename(.sid = id, record_entered = skraningartimi) |>
  select(-c(breytt, snt, veidarfaeri_efni, athugasemd_txt)) |>
  # uppruni is not in ws_veidi; join from trip for the app, whose profile rows the position decoder reads
  left_join(trip |> select(.tid, source, .vid = vid), by = ".tid") |>

  ## Decode the positions ------------------------------------------------------
  # One decoder for the e-logbook's integers, adb's too (decode_logbook_position(), R/logbook_position.R): the digit
  # count gives the form; the app profile's rows say where an app writes its own (curate/corrections/
  # logbook_app_profile.yml: P3, Taktikal's hundredths and exchanged pairs; P3-value, a trip with 61-99; P4, the short
  # latitudes of 2022-23). A shorter longitude beside a six-digit latitude is read value by value, the record deciding
  # where both readings are valid (logbook_short_longitudes(); the maintainer, 2026-10-30). Until plan 053 step 7 this
  # adapter normalised every value to six digits itself, so it read every short longitude right-padded (wrong east of
  # 10° W), named STOKKUR for its whole degrees, left gid 9's longitudes unscaled, and read seven- and eight-digit
  # values as none.
  # The form read is kept, pos1_form and pos2_form. The sign is turned by the decoder (a positive longitude is west).
  mutate(.app = app_base_name(source), .date = as_date(coalesce(t1, t3, t4))) |>
  (\(d) {
    r <- logbook_position_rules(d$.app, SCHEMA, d$.date, app_profile())
    h <- logbook_position_hundredths(d$.tid, r$hundredths, d$y1, d$x1, d$y2, d$x2)
    s <- logbook_short_longitudes(d$.tid, d$.vid, d$.date, d$y1, d$x1, d$y2, d$x2, h,
                                  midwater = d$gid %in% gear_mapping$gid[gear_mapping$gear %in% "OTM"])
    p1 <- decode_logbook_position(d$y1, d$x1, h, r$short_latitude, r$exchanged, s$lon1, s$why1)
    p2 <- decode_logbook_position(d$y2, d$x2, h, r$short_latitude, r$exchanged, s$lon2, s$why2)
    mutate(d, lat1 = p1$lat, lon1 = p1$lon, lat2 = p2$lat, lon2 = p2$lon, pos1_form = p1$form, pos2_form = p2$form)
  })() |>
  # Step 3: sign correction for longitude. The decoder negated every longitude (most providers store west as
  # positive); restore records that were already correctly negative — identified as lon > 10.75 after negation
  # (flipped to positive) while still in Iceland latitudes (lat < 67.66).
  mutate(
    lon1 = case_when(lon1 > 10.75 & lat1 < 67.66 ~ -lon1, .default = lon1),
    lon2 = case_when(lon2 > 10.75 & lat2 < 67.66 ~ -lon2, .default = lon2)
  ) |>
  # Step 4: range filter — set implausible values to NA
  mutate(
    lon1 = ifelse(between(lon1, -178, 178), lon1, NA_real_),
    lon2 = ifelse(between(lon2, -178, 178), lon2, NA_real_),
    lat1 = ifelse(between(lat1,    0,  85), lat1, NA_real_),
    lat2 = ifelse(between(lat2,    0,  85), lat2, NA_real_)
  ) |>
  mutate(
    date   = as_date(coalesce(t1, t3, t4)),
    schema = SCHEMA
  ) |>
  select(.sid, .tid, date, gid, t1, t3, t4, z1, z2, lon1, lat1, lon2, lat2, pos1_form, pos2_form, n_lost, record_entered,
         schema) |>
  arrange(date, .sid, t1, t3, t4)

# Tour app ---------------------------------------------------------------------
# The web logbook AFLADAGBOKWWW's own tables, tour, fishing_spot and catch (2020-01 to 2022-03; plan 019 §2 item 1,
# §4). From 2021-04-06 the Directorate imported each tour into ws_* as source STOKKUR (the tour's er_lesid set), with
# the latitude rounded to a whole degree, one time and no hours (plan 019 §2 item 2); none before that day. The tour
# app is the record of every trip it holds (decision 210): its ids are negated, so they never meet ws_*'s in this
# schema, and its STOKKUR copies, the same vessel, departure and landing to the second, leave ws_*'s tables. They go
# after the decoding above, so no other station is read differently. tour's sng and sbg name the system user.
tour_raw  <- duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "tour.parquet")) |>
  select(id, ship_id, start_date, landing_date, landing_port_id, er_lesid) |> collect()
tour_spot <- duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "fishing_spot.parquet")) |>
  select(id, tour_id, date_time, equipment_id, latitude, longitude, snt, longline_hooks_count, longline_mainline_count,
         net_count, handline_mainline_count, line_hours_in_sea, net_nights_in_sea) |> collect()

stokkur_copy <- trip |>
  filter(source %in% "STOKKUR") |>
  inner_join(tour_raw |> transmute(tour_id = id, vid = as.integer(ship_id), T1 = start_date, T2 = landing_date),
             by = c("vid", "T1", "T2"), relationship = "one-to-one")
stopifnot("the STOKKUR copies are not the tours the app marks imported (er_lesid)" =
            setequal(stokkur_copy$tour_id, tour_raw$id[!is.na(tour_raw$er_lesid)]))
trip   <- trip   |> filter(!.tid %in% stokkur_copy$.tid)
source <- source |> filter(!.tid %in% stokkur_copy$.tid)

## Trip ------------------------------------------------------------------------
# The landing port is the landing system's place number, hid, translated as the landings translate it (decision 252);
# the departure port is not recorded. tour_class says how each tour reaches the logbook (decision 210, as decision 189
# classes afli's never-loaded records): "imported", the trip the Directorate imported and the tour replaces; of the
# trips never imported, "landed" where the vessel landed the day before, the day or the day after (curated/landing), and
# "unlanded" where it did not. Every class is admitted: the merge's own rules leave out a spot on a vessel-day another
# source holds (vessel_day_held) or out of the dump's dates.
landed <- duckdbfs::open_dataset(fd_curated("landing", "landings.parquet")) |>
  filter(vid %in% !!unique(as.integer(tour_raw$ship_id)),
         date >= !!(min(as_date(tour_raw$landing_date)) - 1), date <= !!(max(as_date(tour_raw$landing_date)) + 1)) |>
  distinct(vid, date) |> collect()
landed <- paste(landed$vid, landed$date)
tour_trip <- tour_raw |>
  transmute(.tid = -id, vid = as.integer(ship_id), T1 = start_date, hid1 = NA_integer_, pid1 = NA_character_,
            T2 = landing_date, hid2 = as.integer(landing_port_id), n_crew = NA_integer_, source = "tour", schema = SCHEMA,
            .day = as_date(T2),
            tour_class = case_when(!is.na(er_lesid) ~ "imported",
                                   paste(vid, .day - 1) %in% landed | paste(vid, .day) %in% landed |
                                     paste(vid, .day + 1) %in% landed ~ "landed",
                                   .default = "unlanded")) |>
  left_join(duckdbfs::open_dataset(fd_curated("reference", "port.parquet")) |> select(hid, pid2 = pid, port) |> collect(),
            by = join_by(hid2 == hid), relationship = "many-to-one") |>
  select(.tid, vid, T1, hid1, pid1, T2, hid2, pid2, port, n_crew, source, schema, tour_class)

## Station ---------------------------------------------------------------------
# The spot's decimal position as recorded, west negative (the profile's row P1); no end position and no depth (empty in
# these data). record_entered is the row's insert time, a minute after the spot time at the median.
tour_station <- tour_spot |>
  transmute(.sid = -id, .tid = -tour_id, date = as_date(date_time), gid = as.integer(equipment_id),
            lon1 = longitude, lat1 = latitude, lon2 = NA_real_, lat2 = NA_real_,
            pos1_form = "decimal degrees", pos2_form = NA_character_, record_entered = snt, schema = SCHEMA)

## Fishing sample --------------------------------------------------------------
# The spot time is the end of fishing (decision 214): t4. The hours (jigs, lines) or nights (nets) in the sea are a
# duration as recorded, as afli's are, judged by the gear's limit (R/duration_limit.R; 0 is none); where one stands,
# t1 = t4 less it, .t1_source "synthesised". t4 is recorded apart from the duration, so a doubted duration doubts t1
# alone. The count: the jigs, the nets, and a longline's hooks, which the app takes as the hooks of each line on most
# spots (fewer than 100 hooks a line, where a line holds about 400: hooks x lines, "derived") and as the total on the
# rest (2026-10-30: 1,659 and 653 of 2,312 line spots, the ratio between 60 and 200 on 33).
tour_sample <- tour_spot |>
  transmute(.tid = -tour_id, .sid = -id, gid = as.integer(equipment_id), t4 = date_time,
            duration_m = coalesce(net_nights_in_sea * 24 * 60, line_hours_in_sea * 60),
            jigs = handline_mainline_count, nets = net_count, hooks = longline_hooks_count,
            lines = longline_mainline_count) |>
  left_join(gear_mapping |> select(gid, gid_old = map, gear, target, target2), by = "gid") |>
  flag_duration_limit(gear_window) |>
  mutate(t1 = if_else(.duration_source == "data", t4 - duration_m * 60, LOGBOOK_NA_TIME),
         .t1_source = if_else(is.na(t1), NA_character_, "synthesised"),
         t2 = LOGBOOK_NA_TIME, t3 = LOGBOOK_NA_TIME,
         per_line = gear %in% "LLS" & hooks < 100 * lines,
         n_units = case_when(gear == "LHM" ~ jigs, gear %in% c("GNS", "GND") ~ nets, gear == "LLS" ~ lines),
         effort_count = case_when(gear == "LHM"            ~ recorded_count(jigs),
                                  gear %in% c("GNS", "GND") ~ recorded_count(nets),
                                  per_line                  ~ recorded_count(hooks * lines),
                                  gear == "LLS"             ~ recorded_count(hooks)),
         effort_count_basis = case_when(is.na(effort_count) ~ NA_character_, per_line ~ "derived",
                                        .default = "recorded"),
         schema = SCHEMA) |>
  add_effort_count() |>
  select(.tid, .sid, gid, gid_old, gear, target, target2, t1, t2, t3, t4, .t1_source,
         duration_m, duration_m_raw, .duration_source, effort_count, effort_count_basis, effort_count_unit,
         n_units, schema)

## Catch -----------------------------------------------------------------------
# estimated_weight in kg, whole numbers throughout. The condition from the flags, as ws_afli's codes are read below:
# released RELE, else gutted GUTT, else UNGU. undersized_kg is the part of the row's weight flagged undersized. Rows of
# one species and condition at one spot are summed, as ws_afli's are; implausible weights stay as recorded, for
# curated/logbook/catch_flag to flag (decision 210 item 3).
tour_catch <- duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "catch.parquet")) |>
  select(fishing_spot_id, species_id, estimated_weight, undersized, gutted, released) |> collect() |>
  transmute(.sid = -fishing_spot_id, sid = as.integer(species_id),
            condition = case_when(released == 1 ~ "RELE", gutted == 1 ~ "GUTT", .default = "UNGU"),
            kg = estimated_weight, undersized = undersized == 1) |>
  summarise(catch = as.integer(sum(kg)), undersized_kg = sum(kg[undersized]), .by = c(.sid, sid, condition)) |>
  mutate(catch_whole = NA_real_, schema = SCHEMA) |>
  semi_join(tour_sample, by = ".sid") |>
  select(.sid, sid, catch_whole, catch, condition, undersized_kg, schema) |>
  arrange(.sid, sid)

# Helper: station keys + ICES gear labels for inner-joining aux tables
source_gear <- source |>
  select(.sid, gid) |>
  bind_rows(tour_station |> select(.sid, gid)) |>
  left_join(gear_mapping |> select(gid, gear), by = "gid")

# Station (spatial / temporal envelope) ---------------------------------------
# Narrow table: keys, date, positions, depth. Fishing operation detail is in
# fishing_sample; the two join on .sid. The tour app's spots follow ws_veidi's stations.
station <-
  bind_rows(source, tour_station) |>
  left_join(source_gear |> select(.sid, gear), by = ".sid") |>
  mutate(
    # QC flag for suspect coordinates. Does not filter — use downstream as needed.
    #   meridian : lon suspiciously near 0 (digit-encoding error; true pos likely 1–9°W)
    #   west     : lon west of -35°W for non-OTM, or -40°W for OTM (digit error)
    #   south    : lat south of 62°N for non-OTM gear (OTM pelagic south of Iceland is expected)
    coord_flag = case_when(
      between(lon1, -1, 1)                                    ~ "meridian",
      lon1 < -40                                              ~ "west",
      lon1 < -35 & gear != "OTM"                             ~ "west",
      lat1 < 62  & gear != "OTM"                             ~ "south",
      .default = NA_character_
    )
  ) |>
  select(.sid, .tid, date, lon1, lat1, lon2, lat2, pos1_form, pos2_form, z1, z2, coord_flag, record_entered, schema)

# Aux tables ------------------------------------------------------------------
# Each block reads one gear-specific parquet, translates columns, and
# inner-joins to the relevant gear class via source_gear.

## Mobile (ws_dragnot_varpa: OTB / OTM / SDN) ----------------------------------
aux_mobile <-
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_dragnot_varpa.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear %in% c("OTB", "OTM", "SDN")), by = ".sid")

## Dredge (ws_plogur: DRB) ----------------------------------------------------
aux_dredge <-
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_plogur.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear == "DRB"), by = ".sid")

## Static (ws_linanethandf: LLS / GNS / GND / LHM) ----------------------------
aux_static <-
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_linanethandf.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear %in% c("LLS", "GNS", "GND", "LHM")), by = ".sid")

## Traps (ws_gildra: FPO) -----------------------------------------------------
aux_trap <-
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_gildra.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear == "FPO"), by = ".sid")

## Purse seine (ws_hringn: PS) -------------------------------------------------
aux_seine <-
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_hringn.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear == "PS"), by = ".sid")

# Fishing sample --------------------------------------------------------------

## Gear dimensions + the count ------------------------------------------------
# One row per station; gear-specific columns NA where not applicable. effort_count is the grammar's one count
# (R/logbook_effort.R): hooks, nets, jigs, traps, and the trawls (tvo_veidarf, 1-3) or dredges of a towed gear,
# each as recorded. n_units keeps the gear table's own count in staging.
dims <-
  bind_rows(
    # OTB / OTM — bottom and midwater trawl; tvo_veidarf counts the trawls (1, 2 or 3; NA on every OTM)
    aux_mobile |>
      filter(gear %in% c("OTB", "OTM")) |>
      mutate(effort_count = recorded_count(n_units)) |>
      select(.sid, n_units, g_mesh, g_width, effort_count),
    # SDN — Danish seine (effort is per setting, not time-based)
    aux_mobile |>
      filter(gear == "SDN") |>
      select(.sid, g_mesh, g_length),
    # DRB — dredge / plow; tvo_veidarf counts the dredges
    aux_dredge |>
      mutate(effort_count = recorded_count(n_units)) |>
      select(.sid, n_units, g_mesh, g_width, g_length, g_height, effort_count),
    # LLS — longline (gid 12 Lína, 13 Landbeitt lína, 21 Línutrekt)
    aux_static |>
      filter(gear == "LLS") |>
      mutate(effort_count = recorded_count(n_hooks)) |>
      select(.sid, n_units = n_hooks, effort_count),
    # GNS / GND — gillnet
    aux_static |>
      filter(gear %in% c("GNS", "GND")) |>
      mutate(n_units      = n_nets,
             g_length     = n_nets * mean_gillnet_length,
             effort_count = recorded_count(n_units)) |>
      select(.sid, n_units, g_mesh, g_height, g_length, effort_count),
    # LHM — handline / jig
    aux_static |>
      filter(gear == "LHM") |>
      mutate(effort_count = recorded_count(n_jigs)) |>
      select(.sid, n_units = n_jigs, effort_count),
    # FPO — traps
    aux_trap |>
      mutate(effort_count = recorded_count(n_units)) |>
      select(.sid, n_units, effort_count),
    # PS — purse seine (effort is per setting)
    aux_seine |>
      select(.sid, g_mesh, g_length, g_height)
  ) |>
  mutate(effort_count_basis = if_else(is.na(effort_count), NA_character_, "recorded"))

## Duration limits -------------------------------------------------------------
# The plausible maximum per gear is reference/gear/windows.R (gear_window.dur_max_min, read in Setup),
# applied by R/duration_limit.R and shared with afli. This adapter used to carry its own
# cap table, which had drifted from afli's and kept only the capped value.

## Assemble fishing_sample -----------------------------------------------------
fishing_sample <-
  source |>
  select(.tid, .sid, gid, t1, t3, t4, date, n_lost, schema) |>
  left_join(gear_mapping |> select(gid, gid_old = map, gear, target, target2), by = "gid") |>
  # Raw ws_veidi times to the grammar's t1-t4, the duration and its limit (R/logbook_effort.R): upphaf_timi,
  # milli_timi and lok_timi are t1, t3 and t4 here, as the dictionary names them.
  elogbook_times(gear_window) |>
  # The count (R/logbook_effort.R). The effort is made from the times and the count by calc_effort(), not stored.
  left_join(dims |> select(.sid, effort_count, effort_count_basis), by = ".sid") |>
  add_effort_count() |>
  # Gear dimensions
  left_join(dims |> select(-effort_count, -effort_count_basis), by = ".sid") |>
  select(.tid, .sid, gid, gid_old, gear, target, target2, t1, t2, t3, t4, date,
         duration_m, duration_m_raw, .duration_source,
         effort_count, effort_count_basis, effort_count_unit,
         n_units, n_lost, g_mesh, g_width, g_length, g_height,
         schema) |>
  select(-date) |>
  bind_rows(tour_sample)

# Catch -----------------------------------------------------------------------
catch <-
  duckdbfs::open_dataset(fd_raw("oracle", "fs_afladagbok", "ws_afli.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  # After the dictionary `catch` is the raw `afli` (whole-fish weight, NULL for ~98 % of rows from 2023) and
  # `magn` is the weight in the state `astand` names. `catch` stays what it was, magn; the whole weight
  # is kept beside it as `catch_whole`, NA (not 0) when no row recorded it. curate/catch_by_species_station.R
  # fills the gap. Condition codes are adb's (GUTT = S, UNGU = O, RELE = L, confirmed on 1.39 M shared rows).
  select(.sid, sid, catch_whole = catch, catch = magn, condition = astand) |>
  mutate(condition = case_match(condition, "S" ~ "GUTT", "O" ~ "UNGU", "L" ~ "RELE", .default = NA_character_)) |>
  group_by(.sid, sid, condition) |>
  summarise(catch_whole = if (all(is.na(catch_whole))) NA_real_ else sum(catch_whole, na.rm = TRUE),
            catch = sum(catch, na.rm = TRUE), .groups = "drop") |>
  inner_join(fishing_sample |> select(.sid, schema), by = ".sid") |>
  arrange(.sid, sid) |>
  bind_rows(tour_catch)

trip <- bind_rows(trip, tour_trip)

# Export -----------------------------------------------------------------------
trip           |> duckdbfs::write_dataset(fd_staging("fs_afladagbok", "trip.parquet"))
station        |> duckdbfs::write_dataset(fd_staging("fs_afladagbok", "station.parquet"))
fishing_sample |> duckdbfs::write_dataset(fd_staging("fs_afladagbok", "fishing_sample.parquet"))

catch          |> duckdbfs::write_dataset(fd_staging("fs_afladagbok", "catch.parquet"))


# QC scratch (if FALSE) -------------------------------------------------------
if (FALSE) {

  ## Position forms --------------------------------------------------------------
  source |> count(pos1_form)

  ## Duration distributions by gear --------------------------------------------
  fishing_sample |>
    filter(!is.na(duration_m)) |>
    ggplot(aes(duration_m / 60)) +
    geom_histogram() +
    facet_wrap(~gear, scales = "free")

  ## Effort summary ------------------------------------------------------------
  fishing_sample |>
    count(gear, effort_unit, .duration_source)

  ## t-ordering QC (t1 ≤ t3 ≤ t4) ---------------------------------------------
  fishing_sample |>
    filter(!is.na(t1), !is.na(t4)) |>
    summarise(t1_before_t4 = mean(t1 <= t4, na.rm = TRUE),
              t3_before_t4 = mean(t3 <= t4, na.rm = TRUE))

  ## Station coverage over time ------------------------------------------------
  station |>
    mutate(year = year(date)) |>
    count(year) |>
    filter(year >= 2018) |>
    print(n = 20)

}
