# Create standard summary tables
# Input:  data-dump/logbooks/fs_afladagbok/{ws_veidiferd,ws_veidi,ws_afli,
#           ws_dragnot_varpa,ws_plogur,ws_linanethandf,ws_gildra,ws_hringn}.parquet
# Output: data-raw/logbooks/fs_afladagbok/{trip,station,fishing_sample,catch}.parquet

# Setup -----------------------------------------------------------------------
library(whack)     # pak::pak("einarhjorleifsson/whack")
library(geo)
library(tidyverse)
library(duckdbfs)

SCHEMA <- "fs_afladagbok"
dictionary   <- duckdbfs::open_dataset(fd_curated("reference", "dictionary.parquet")) |> collect() |> filter(schema == SCHEMA)
gear_mapping <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> collect() |> filter(version == "new")
# hid is the Icelandic harbour code, hid_new this schema's own code, and pid the
# standard port key from reference/ports/ports_all.R. drop_na() is scoped so
# that a code without a pid keeps its name rather than vanishing.
harbours <-
  duckdbfs::open_dataset(fd_curated("reference", "port.parquet")) |> collect() |>
  select(hid_new = hafnarnumer_id, port, hid, pid) |>
  drop_na(hid_new, hid, port)

# Sources known to encode coordinates in DDM (degrees-decimal-minutes).
# All others default to DMS classification via row-level signal.
DDM_SOURCES <- c(
  "FRA TAKTIKAL", "FRA TAKTIKAL - GAFL AUTO",
  "Marína raun",  "Marína raun - GAFL AUTO", "Marína raun - Skrifstofa VES",
  "GAFL BÓK UPPFÆRÐ FRÁ TAKTIKAL"
)



# Trip -------------------------------------------------------------------------
# Built first: `source` (uppruni) is a trip-level column in ws_veidiferd and
# is needed for coordinate classification in ws_veidi below.
trip <-
  duckdbfs::open_dataset(fd_raw("logbooks", "fs_afladagbok", "ws_veidiferd.parquet")) |> collect() |>
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
# After this block `source` has: .sid .tid gid t1 t3 t4 lon1 lat1 lon2 lat2
# z1 z2 n_lost date schema.
# Raw columns: upphaf_timi→t1, milli_timi→t3, lok_timi→t4.
# t3 (milli_timi) is absent for OTB/OTM/DRB; for SDN it always equals t1.
source <-
  duckdbfs::open_dataset(fd_raw("logbooks", "fs_afladagbok", "ws_veidi.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  rename(.sid = id) |>
  select(-c(breytt, skraningartimi, snt, veidarfaeri_efni, athugasemd_txt)) |>
  # uppruni is not in ws_veidi; join from trip to enable DDM_SOURCES classification
  left_join(trip |> select(.tid, source), by = ".tid") |>

  ## Classify coordinate format -------------------------------------------------
  # Rule 1 (row-level): last-2-digits of normalised y1 ≥ 60 is impossible in DMS
  #   → definitive DDM evidence; lifted to trip level.
  # Rule 2 (source prior): known DDM sources classified unconditionally.
  mutate(
    ny1    = nchar(as.character(abs(y1))),
    y1_det = case_when(
      ny1 == 6 ~ as.numeric(abs(y1)),
      ny1 == 5 ~ abs(y1) * 10,
      ny1 == 4 ~ abs(y1) * 100,
      ny1 == 2 & source == "STOKKUR" ~ abs(y1) * 10000,
      .default = as.numeric(abs(y1))
    ),
    ddm_signal = !is.na(y1_det) & (y1_det %% 100 >= 60)
  ) |>
  group_by(.tid) |>
  mutate(trip_ddm = any(ddm_signal, na.rm = TRUE)) |>
  ungroup() |>
  mutate(coord_fmt = case_when(
    trip_ddm | source %in% DDM_SOURCES ~ "ddm",
    .default = "dms"
  )) |>
  select(-ny1, -y1_det, -ddm_signal, -trip_ddm) |>

  ## Convert to decimal degrees -------------------------------------------------
  # Step 1: normalise all coordinates to 6-digit DDMMSS / DDMMmm integers.
  # gid 9 (Flotvarpa) has mixed decimal-degree / DMS encoding that cannot be
  # disentangled without per-source classification — skip normalisation for x.
  mutate(
    nx1 = nchar(as.character(abs(x1))), nx2 = nchar(as.character(abs(x2))),
    ny1 = nchar(as.character(abs(y1))), ny2 = nchar(as.character(abs(y2)))
  ) |>
  mutate(
    y1 = case_when(ny1 == 6 ~ y1, ny1 == 5 ~ y1 * 10, ny1 == 4 ~ y1 * 100,
                   ny1 == 2 & source == "STOKKUR" ~ y1 * 10000, .default = y1),
    x1 = case_when(nx1 == 6 ~ x1, nx1 == 5 & gid != 9 ~ x1 * 10,
                   nx1 == 4 & gid != 9 ~ x1 * 100,
                   nx1 == 2 & source == "STOKKUR" ~ x1 * 10000, .default = x1),
    y2 = case_when(ny2 == 6 ~ y2, ny2 == 5 ~ y2 * 10, ny2 == 4 ~ y2 * 100,
                   ny2 == 2 & source == "STOKKUR" ~ y2 * 10000, .default = y2),
    x2 = case_when(nx2 == 6 ~ x2, nx2 == 5 & gid != 9 ~ x2 * 10,
                   nx2 == 4 & gid != 9 ~ x2 * 100,
                   nx2 == 2 & source == "STOKKUR" ~ x2 * 10000, .default = x2)
  ) |>
  # Step 2: convert to decimal degrees.
  # validate = FALSE required: case_when() evaluates all branches before applying
  # conditions, so DMS-encoded values would trigger spurious DDM validation errors.
  # Sign is NOT corrected here; that is a separate concern handled in Step 3.
  mutate(
    lon1 = case_when(coord_fmt == "ddm" ~ wk_convert_ddm(x1, validate = FALSE),
                     .default = wk_convert_dms(x1, validate = FALSE)),
    lat1 = case_when(coord_fmt == "ddm" ~ wk_convert_ddm(y1, validate = FALSE),
                     .default = wk_convert_dms(y1, validate = FALSE)),
    lon2 = case_when(coord_fmt == "ddm" ~ wk_convert_ddm(x2, validate = FALSE),
                     .default = wk_convert_dms(x2, validate = FALSE)),
    lat2 = case_when(coord_fmt == "ddm" ~ wk_convert_ddm(y2, validate = FALSE),
                     .default = wk_convert_dms(y2, validate = FALSE))
  ) |>
  # Step 3: sign correction for longitude.
  # Negate all lons (most providers store as positive), then restore records
  # that were already correctly negative — identified as lon > 10.75 after
  # negation (flipped to positive) while still in Iceland latitudes (lat < 67.66).
  mutate(
    lon1 = -lon1,
    lon1 = case_when(lon1 > 10.75 & lat1 < 67.66 ~ -lon1, .default = lon1),
    lon2 = -lon2,
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
  select(.sid, .tid, date, gid, t1, t3, t4, z1, z2, lon1, lat1, lon2, lat2, n_lost, schema) |>
  arrange(date, .sid, t1, t3, t4)

# Helper: station keys + ICES gear labels for inner-joining aux tables
source_gear <- source |>
  select(.sid, gid) |>
  left_join(gear_mapping |> select(gid, gear), by = "gid")

# Station (spatial / temporal envelope) ---------------------------------------
# Narrow table: keys, date, positions, depth. Fishing operation detail is in
# fishing_sample; the two join on .sid.
station <-
  source |>
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
  select(.sid, .tid, date, lon1, lat1, lon2, lat2, z1, z2, coord_flag, schema)

# Aux tables ------------------------------------------------------------------
# Each block reads one gear-specific parquet, translates columns, and
# inner-joins to the relevant gear class via source_gear.

## Mobile (ws_dragnot_varpa: OTB / OTM / SDN) ----------------------------------
aux_mobile <-
  duckdbfs::open_dataset(fd_raw("logbooks", "fs_afladagbok", "ws_dragnot_varpa.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear %in% c("OTB", "OTM", "SDN")), by = ".sid")

## Dredge (ws_plogur: DRB) ----------------------------------------------------
aux_dredge <-
  duckdbfs::open_dataset(fd_raw("logbooks", "fs_afladagbok", "ws_plogur.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear == "DRB"), by = ".sid")

## Static (ws_linanethandf: LLS / GNS / GND / LHM) ----------------------------
aux_static <-
  duckdbfs::open_dataset(fd_raw("logbooks", "fs_afladagbok", "ws_linanethandf.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear %in% c("LLS", "GNS", "GND", "LHM")), by = ".sid")

## Traps (ws_gildra: FPO) -----------------------------------------------------
aux_trap <-
  duckdbfs::open_dataset(fd_raw("logbooks", "fs_afladagbok", "ws_gildra.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear == "FPO"), by = ".sid")

## Purse seine (ws_hringn: PS) -------------------------------------------------
aux_seine <-
  duckdbfs::open_dataset(fd_raw("logbooks", "fs_afladagbok", "ws_hringn.parquet")) |> collect() |>
  wk_translate(dictionary) |>
  inner_join(source_gear |> filter(gear == "PS"), by = ".sid")

# Fishing sample --------------------------------------------------------------

## Gear dimensions + effort inputs ---------------------------------------------
# One row per station; gear-specific columns NA where not applicable.
# effort_count and effort_unit are derived here alongside gear dimensions —
# they share the same source columns.
dims <-
  bind_rows(
    # OTB / OTM — bottom and midwater trawl; n_units unreliable, assume 1
    aux_mobile |>
      filter(gear %in% c("OTB", "OTM")) |>
      mutate(effort_count = 1L,
             effort_unit  = "gear-minutes") |>
      select(.sid, n_units, g_mesh, g_width, effort_count, effort_unit),
    # SDN — Danish seine (effort is per setting, not time-based)
    aux_mobile |>
      filter(gear == "SDN") |>
      mutate(effort_count = 1L, effort_unit = "setting") |>
      select(.sid, g_mesh, g_length, effort_count, effort_unit),
    # DRB — dredge / plow
    aux_dredge |>
      mutate(effort_count = coalesce(as.integer(n_units), 1L),
             effort_unit  = "gear-minutes") |>
      select(.sid, n_units, g_mesh, g_width, g_length, g_height, effort_count, effort_unit),
    # LLS — longline (gid 12 Lína, 13 Landbeitt lína, 21 Línutrekt)
    aux_static |>
      filter(gear == "LLS") |>
      mutate(effort_count = n_hooks, effort_unit = "hook-days") |>
      select(.sid, n_units = n_hooks, effort_count, effort_unit),
    # GNS / GND — gillnet
    aux_static |>
      filter(gear %in% c("GNS", "GND")) |>
      mutate(n_units      = n_nets,
             g_length     = n_nets * mean_gillnet_length,
             effort_count = n_units,
             effort_unit  = "net-days") |>
      select(.sid, n_units, g_mesh, g_height, g_length, effort_count, effort_unit),
    # LHM — handline / jig
    aux_static |>
      filter(gear == "LHM") |>
      mutate(effort_count = n_jigs, effort_unit = "jig-hours") |>
      select(.sid, n_units = n_jigs, effort_count, effort_unit),
    # FPO — traps
    aux_trap |>
      mutate(effort_count = n_units, effort_unit = "trap-hours") |>
      select(.sid, n_units, effort_count, effort_unit),
    # PS — purse seine (effort is per setting)
    aux_seine |>
      mutate(effort_count = 1L, effort_unit = "setting") |>
      select(.sid, g_mesh, g_length, g_height, effort_count, effort_unit)
  )

## Duration limits -------------------------------------------------------------
# The plausible maximum per gear is reference/gear/windows.R (gear_window.dur_max_min),
# applied by R/duration_limit.R and shared with afli. This adapter used to carry its own
# cap table, which had drifted from afli's and kept only the capped value.
gear_window <- duckdbfs::open_dataset(fd_curated("reference", "gear_window.parquet")) |> collect()

## Assemble fishing_sample -----------------------------------------------------
fishing_sample <-
  source |>
  select(.tid, .sid, gid, t1, t3, t4, date, n_lost, schema) |>
  left_join(gear_mapping |> select(gid, gid_old = map, gear, target, target2), by = "gid") |>
  # Remap raw ws_veidi timestamps to the unified t1–t4 grammar.
  # Raw columns: upphaf_timi → t1_raw, milli_timi → t3_raw, lok_timi → t4_raw.
  #
  # Mobile (OTB/OTM/DRB/SDN):
  #   upphaf_timi = deployment ends (warp fully out / gear on bottom) → t2
  #   lok_timi    = retrieval starts (warp coming in)                 → t3
  #   t1 and t4 are not recorded                                      → NA
  #   SDN exception: if milli_timi ≠ upphaf_timi (3 distinct timestamps)
  #   interpret as t1=upphaf_timi, t2=milli_timi, t3=lok_timi.
  #   In current data milli_timi == upphaf_timi for 100% of SDN rows.
  #
  # Static (LLS/GNS/GND/LHM/FPO):
  #   upphaf_timi = deployment starts → t1
  #   milli_timi  = retrieval starts  → t3
  #   lok_timi    = retrieval ends    → t4
  #   t2 (deployment ends) not recorded → NA
  mutate(
    .t1_raw   = t1,
    .t3_raw   = t3,
    .t4_raw   = t4,
    .mob_3ts  = gear %in% c("OTB", "OTM", "DRB", "SDN") &
                !is.na(.t3_raw) & .t3_raw != .t1_raw,
    t1 = case_when(
      gear %in% c("OTB", "OTM", "DRB")     ~ NA_POSIXct_,
      gear == "SDN" & !.mob_3ts             ~ NA_POSIXct_,
      gear == "SDN" &  .mob_3ts             ~ .t1_raw,
      .default                              = .t1_raw
    ),
    t2 = case_when(
      gear %in% c("OTB", "OTM", "DRB")     ~ .t1_raw,
      gear == "SDN" & !.mob_3ts             ~ .t1_raw,
      gear == "SDN" &  .mob_3ts             ~ .t3_raw,
      .default                              = NA_POSIXct_
    ),
    t3 = case_when(
      gear %in% c("OTB", "OTM", "DRB", "SDN") ~ .t4_raw,
      .default                                  = .t3_raw
    ),
    t4 = case_when(
      gear %in% c("OTB", "OTM", "DRB", "SDN") ~ NA_POSIXct_,
      .default                                  = .t4_raw
    )
  ) |>
  select(-c(.t1_raw, .t3_raw, .t4_raw, .mob_3ts)) |>
  # Duration:
  #   Mobile (OTB/OTM/DRB/SDN): t3 − t2 (= lok_timi − upphaf_timi)
  #   Static (LLS/GNS/GND/LHM/FPO): t4 − t1 (approximate; true soak =
  #     t3 − t1, but including hauling is consistent with afli treatment)
  mutate(duration_m = case_when(
    gear %in% c("OTB", "OTM", "DRB", "SDN")         ~
      as.numeric(difftime(t3, t2, units = "mins")),
    gear %in% c("LLS", "GNS", "GND", "LHM", "FPO")  ~
      as.numeric(difftime(t4, t1, units = "mins")),
    .default = NA_real_
  )) |>
  # duration_m_raw is kept; an implausible duration becomes NA (R/duration_limit.R). The
  # end time that produced it is not believed either: a mobile tow's t3 and a static
  # set's t4 are set to NA with it, so no window is drawn from an impossible span.
  apply_duration_limit(gear_window) |>
  mutate(t3 = if_else(.duration_source == "implausible" & gear %in% c("OTB", "OTM", "DRB", "SDN"), NA_POSIXct_, t3),
         t4 = if_else(.duration_source == "implausible" & gear %in% c("LLS", "GNS", "GND", "LHM", "FPO"), NA_POSIXct_, t4)) |>
  # Effort: two-component — effort = effort_count × effort_duration
  left_join(dims |> select(.sid, effort_count, effort_unit), by = ".sid") |>
  mutate(
    effort_duration = case_when(
      effort_unit == "gear-minutes" ~ duration_m,
      effort_unit == "hook-days"    ~ duration_m / (60 * 24),
      effort_unit == "net-days"     ~ duration_m / (60 * 24),
      effort_unit == "jig-hours"    ~ duration_m / 60,
      effort_unit == "trap-hours"   ~ duration_m / 60,
      effort_unit == "setting"      ~ 1,
      .default = NA_real_
    ),
    effort = effort_count * effort_duration
  ) |>
  # Gear dimensions
  left_join(dims |> select(-effort_count, -effort_unit), by = ".sid") |>
  select(.tid, .sid, gid, gid_old, gear, target, target2, t1, t2, t3, t4, date,
         duration_m, duration_m_raw, .duration_source,
         effort_count, effort_duration, effort_unit, effort,
         n_units, n_lost, g_mesh, g_width, g_length, g_height,
         schema) |>
  select(-date)

# Catch -----------------------------------------------------------------------
catch <-
  duckdbfs::open_dataset(fd_raw("logbooks", "fs_afladagbok", "ws_afli.parquet")) |> collect() |>
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
  arrange(.sid, sid)

# Export -----------------------------------------------------------------------
trip           |> duckdbfs::write_dataset(fd_staging("fs_afladagbok", "trip.parquet"))
station        |> duckdbfs::write_dataset(fd_staging("fs_afladagbok", "station.parquet"))
fishing_sample |> duckdbfs::write_dataset(fd_staging("fs_afladagbok", "fishing_sample.parquet"))

catch          |> duckdbfs::write_dataset(fd_staging("fs_afladagbok", "catch.parquet"))


# QC scratch (if FALSE) -------------------------------------------------------
if (FALSE) {

  ## Coordinate format breakdown -----------------------------------------------
  source |> count(coord_fmt)

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
