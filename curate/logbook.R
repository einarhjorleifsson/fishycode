# Merge afli (legacy), fs_afladagbok and adb into unified logbook tables.
# Side: preprocessing (logbook). See plan 014.
# Input:  staging/{afli,fs_afladagbok,adb}/{trip,station,fishing_sample,catch}.parquet
# Output: curated/logbook/{trip,station,fishing_sample,catch}.parquet
#
# Decision rule (three-tier priority):
#   Tier 1 — if (vid, date) present in afli                        → use afli
#   Tier 2 — not in afli, but present in fs_afladagbok             → use fs_afladagbok
#   Tier 3 — not in afli or fs_afladagbok, present in adb          → use adb
#
# Rationale:
#   afli > fs_afladagbok: afli mobile-gear timing is derived from the on-bottom
#   clock; when fs_afladagbok was instigated, timestamps and/or duration were
#   missing in fs_afladagbok.
#   fs_afladagbok > adb: adb has no fishing_sample detail of its own (gid is
#   NA - see sources/adb/convert.R) and exists to extend coverage past
#   fs_afladagbok's static dump, not to compete with it.
#
# Date bounds applied:
#   afli          — no lower bound; upper: <= DATE_MAX
#   fs_afladagbok — lower: >= FS_DATE_MIN; upper: <= FS_DATE_MAX (static dump)
#   adb           — lower: >= ADB_DATE_MIN (day after FS_DATE_MAX); upper: <= DATE_MAX.
#                   Below ADB_DATE_MIN adb is redundant with fs_afladagbok and
#                   would otherwise need the same vid-date tiering to suppress it;
#                   above it, adb's own dates are corrupt in places (rows found in
#                   year 3, year 202, year 2031 - a handful each, unrelated to this
#                   merge) so DATE_MAX still applies.
#
# Depth: z1/z2 are converted to metres (curate/decisions/022), z1_raw/z2_raw
# keep the original recorded value, z1_basis/z2_basis says which happened.
# Longitude: adb's dropped west sign is fixed by curate/corrections/
# adb_vs_fs_afladagbok.R (lon1_raw/lon2_raw/lon1_basis/lon2_basis).
# Station type: station.parquet carries station_type (operation / event) and
# station_type_basis, read per vessel, year and gear (decision 084).

library(tidyverse)
library(duckdbfs)

# Parameters -------------------------------------------------------------------
FS_DATE_MIN  <- as.Date("2020-01-01")
FS_DATE_MAX  <- as.Date("2025-12-31")
ADB_DATE_MIN <- FS_DATE_MAX + 1
DATE_MAX     <- as.Date("2026-12-31")
# curate/decisions/022-depth-unit-is-metres.md: product-wide depth is metres.
# fs_afladagbok has no drift (curate/corrections/afli_depth_units.yml baseline) -
# a flat conversion is enough; afli's vessel-by-vessel drift needs its own
# correction, curate/corrections/afli_depth_units.R, run beforehand. adb is
# already metres (same decision) - no conversion, just basis columns for
# consistency across the merged table.
FATHOM_TO_M <- 1.8288

# Load -------------------------------------------------------------------------
afli_trip           <- duckdbfs::open_dataset(fd_staging("afli", "trip.parquet")) |> collect()
afli_station        <- duckdbfs::open_dataset(fd_staging("afli", "station.parquet")) |> collect()
afli_fishing_sample <- duckdbfs::open_dataset(fd_staging("afli", "fishing_sample.parquet")) |> collect()
afli_catch          <- duckdbfs::open_dataset(fd_staging("afli", "catch.parquet")) |> collect()
afli_depth          <- duckdbfs::open_dataset(fd_staging("afli", "depth.parquet")) |> collect()

fs_trip           <- duckdbfs::open_dataset(fd_staging("fs_afladagbok", "trip.parquet")) |> collect()
fs_station        <- duckdbfs::open_dataset(fd_staging("fs_afladagbok", "station.parquet")) |> collect()
fs_fishing_sample <- duckdbfs::open_dataset(fd_staging("fs_afladagbok", "fishing_sample.parquet")) |> collect()
fs_catch          <- duckdbfs::open_dataset(fd_staging("fs_afladagbok", "catch.parquet")) |> collect()

adb_trip           <- duckdbfs::open_dataset(fd_staging("adb", "trip.parquet")) |> collect()
adb_station        <- duckdbfs::open_dataset(fd_staging("adb", "station.parquet")) |> collect()
adb_fishing_sample <- duckdbfs::open_dataset(fd_staging("adb", "fishing_sample.parquet")) |> collect()
adb_catch          <- duckdbfs::open_dataset(fd_staging("adb", "catch.parquet")) |> collect()
adb_lon_sign       <- duckdbfs::open_dataset(fd_staging("adb", "lon_sign.parquet")) |> collect()

# Depth unit ---------------------------------------------------------------
# afli: replace z1/z2 with the per-vessel-period corrected value from
# afli_depth_units.R; keep z1_raw/z2_raw/z1_basis/z2_basis (never overwrite the
# original - AGENTS.md).
afli_station <- afli_station |>
  select(-z1, -z2) |>
  left_join(afli_depth, by = ".sid")

# fs_afladagbok: uniformly fathoms (no drift window), so a flat conversion with
# basis = "reconstructed"; NA stays NA, basis NA.
fs_station <- fs_station |>
  mutate(z1_raw = z1, z2_raw = z2,
         z1 = z1_raw * FATHOM_TO_M, z2 = z2_raw * FATHOM_TO_M,
         z1_basis = if_else(is.na(z1_raw), NA_character_, "reconstructed"),
         z2_basis = if_else(is.na(z2_raw), NA_character_, "reconstructed"))

# adb: already metres (decision 022) - basis columns only, no conversion.
# Longitude: replace lon1/lon2 with adb_vs_fs_afladagbok.R's sign-corrected
# value, keep lon1_raw/lon2_raw/lon1_basis/lon2_basis (never overwrite the
# original - AGENTS.md).
adb_station <- adb_station |>
  mutate(z1_raw = z1, z2_raw = z2,
         z1_basis = if_else(is.na(z1_raw), NA_character_, "recorded"),
         z2_basis = if_else(is.na(z2_raw), NA_character_, "recorded")) |>
  select(-lon1, -lon2) |>
  left_join(adb_lon_sign |> select(.sid, lon1, lon2, lon1_raw, lon2_raw, lon1_basis, lon2_basis),
            by = ".sid")

# Apply date bounds ------------------------------------------------------------
afli_station <- afli_station |> filter(date <= DATE_MAX)
fs_station   <- fs_station   |> filter(date >= FS_DATE_MIN, date <= FS_DATE_MAX)
adb_station  <- adb_station  |> filter(date >= ADB_DATE_MIN, date <= DATE_MAX)

# Subset all tables to stations/trips surviving the date filter
afli_trip           <- afli_trip           |> semi_join(afli_station |> distinct(.tid), by = ".tid")
afli_fishing_sample <- afli_fishing_sample |> semi_join(afli_station |> distinct(.sid), by = ".sid")
afli_catch          <- afli_catch          |> semi_join(afli_station |> distinct(.sid), by = ".sid")

fs_trip           <- fs_trip           |> semi_join(fs_station |> distinct(.tid), by = ".tid")
fs_fishing_sample <- fs_fishing_sample |> semi_join(fs_station |> distinct(.sid), by = ".sid")
fs_catch          <- fs_catch          |> semi_join(fs_station |> distinct(.sid), by = ".sid")

adb_trip           <- adb_trip           |> semi_join(adb_station |> distinct(.tid), by = ".tid")
adb_fishing_sample <- adb_fishing_sample |> semi_join(adb_station |> distinct(.sid), by = ".sid")
adb_catch          <- adb_catch          |> semi_join(adb_station |> distinct(.sid), by = ".sid")

# Tier 1: afli — full coverage -------------------------------------------------
afli_vid_date <- afli_station |>
  left_join(afli_trip |> select(.tid, vid), by = ".tid") |>
  distinct(vid, date)

# Tier 2: fs_afladagbok — vessel-days not covered by afli ----------------------
fs_only_station_vid <- fs_station |>
  left_join(fs_trip |> select(.tid, vid), by = ".tid") |>
  anti_join(afli_vid_date, by = c("vid", "date"))

fs_only_vid_date <- fs_only_station_vid |> distinct(vid, date)
fs_only_station  <- fs_only_station_vid |> select(-vid)

fs_sids_kept <- fs_only_station |> distinct(.sid)
fs_tids_kept <- fs_only_station |> distinct(.tid)

fs_only_trip           <- fs_trip           |> semi_join(fs_tids_kept, by = ".tid")
fs_only_fishing_sample <- fs_fishing_sample |> semi_join(fs_sids_kept, by = ".sid")
fs_only_catch          <- fs_catch          |> semi_join(fs_sids_kept, by = ".sid")

# Tier 3: adb — vessel-days not covered by afli or fs_afladagbok --------------
# ADB_DATE_MIN already keeps this to the tail fs_afladagbok never reached, but
# the anti-join is kept anyway: it is what actually enforces the stated
# priority (afli > fs_afladagbok > adb) rather than a date cutoff standing in
# for it, and it costs nothing since fs's own vid-dates in this window are rare.
tier12_vid_date <- bind_rows(afli_vid_date, fs_only_vid_date)

adb_only_station <- adb_station |>
  left_join(adb_trip |> select(.tid, vid), by = ".tid") |>
  anti_join(tier12_vid_date, by = c("vid", "date")) |>
  select(-vid)

adb_sids_kept <- adb_only_station |> distinct(.sid)
adb_tids_kept <- adb_only_station |> distinct(.tid)

adb_only_trip           <- adb_trip           |> semi_join(adb_tids_kept, by = ".tid")
adb_only_fishing_sample <- adb_fishing_sample |> semi_join(adb_sids_kept, by = ".sid")
adb_only_catch          <- adb_catch          |> semi_join(adb_sids_kept, by = ".sid")

# Merge ------------------------------------------------------------------------
merged_trip <- bind_rows(
  afli_trip    |> mutate(.tid = as.character(.tid)),
  fs_only_trip |> mutate(.tid = as.character(.tid)),
  adb_only_trip |> mutate(.tid = as.character(.tid))
)

merged_station <- bind_rows(
  afli_station     |> mutate(.tid = as.character(.tid)),
  fs_only_station  |> mutate(.tid = as.character(.tid)),
  adb_only_station |> mutate(.tid = as.character(.tid))
)

merged_fishing_sample <- bind_rows(
  afli_fishing_sample     |> mutate(.tid = as.character(.tid)),
  fs_only_fishing_sample  |> mutate(.tid = as.character(.tid)),
  adb_only_fishing_sample |> mutate(.tid = as.character(.tid))
)

merged_catch <- bind_rows(afli_catch, fs_only_catch, adb_only_catch)

# Station type -----------------------------------------------------------------
# What a station row covers (`station_type` in docs/grammar.qmd, decision 084): `operation`, one setting, tow
# or haul, or `event`, one record for the day. No logbook says which, and it varies by vessel and over time,
# so it is read per vessel, year and gear from the vessel's own pattern: the share of its fishing days with
# more than one record. Vessel-years pile up at 0 and near 1; below ST_MULTI_MIN is one record a day.
# Longlines are `operation` whatever the share (maintainer, 2026-10-09): one set a day is what a longliner
# does, so a single record a day says nothing. Here, on the merged tables, because the tiers mix schemas
# within a vessel-year; deleted records are left out of the pattern.
ST_MULTI_MIN <- 0.1
station_gear <- merged_fishing_sample |> distinct(.sid, schema, gear)
stopifnot(!anyDuplicated(station_gear[c(".sid", "schema")]))
st_base <- merged_station |>
  select(.sid, .tid, schema, date, eytt_deleted) |>
  left_join(merged_trip |> select(.tid, schema, vid), by = c(".tid", "schema"), relationship = "many-to-one") |>
  left_join(station_gear, by = c(".sid", "schema"), relationship = "one-to-one") |>
  mutate(yr = year(date))
st_pattern <- st_base |>
  filter(!coalesce(eytt_deleted, FALSE), !is.na(vid), !is.na(date)) |>
  count(vid, yr, gear, date, name = "n") |>
  summarise(multi_share = mean(n > 1), .by = c(vid, yr, gear))
station_type <- st_base |>
  left_join(st_pattern, by = c("vid", "yr", "gear"), relationship = "many-to-one") |>
  mutate(station_type       = case_when(multi_share >= ST_MULTI_MIN ~ "operation",
                                        gear == "LLS" & !is.na(multi_share) ~ "operation",
                                        !is.na(multi_share) ~ "event"),
         station_type_basis = case_when(multi_share >= ST_MULTI_MIN ~ "derived",
                                        gear == "LLS" & !is.na(multi_share) ~ "synthesised",
                                        !is.na(multi_share) ~ "derived",
                                        .default = "none")) |>
  select(.sid, schema, station_type, station_type_basis)
merged_station <- merged_station |>
  left_join(station_type, by = c(".sid", "schema"), relationship = "one-to-one")

# Summary ----------------------------------------------------------------------
cat(sprintf("afli stations (filtered):   %d\n", nrow(afli_station)))
cat(sprintf("fs-only stations:           %d\n", nrow(fs_only_station)))
cat(sprintf("adb-only stations:          %d\n", nrow(adb_only_station)))
cat(sprintf("merged stations:            %d\n", nrow(merged_station)))
cat(sprintf("afli trips (filtered):      %d\n", nrow(afli_trip)))
cat(sprintf("fs-only trips:              %d\n", nrow(fs_only_trip)))
cat(sprintf("adb-only trips:             %d\n", nrow(adb_only_trip)))
cat(sprintf("merged trips:               %d\n", nrow(merged_trip)))
cat(sprintf("merged catch:               %d\n", nrow(merged_catch)))

cat("\nStation type by gear (stations):\n")
merged_station |>
  left_join(station_gear, by = c(".sid", "schema")) |>
  count(gear, station_type, station_type_basis) |>
  pivot_wider(names_from = c(station_type, station_type_basis), values_from = n, values_fill = 0L) |>
  print(n = 30)

cat("\nYear-by-year station source (2018+):\n")
merged_station |>
  mutate(yr = lubridate::year(date)) |>
  count(schema, yr) |>
  pivot_wider(names_from = schema, values_from = n, values_fill = 0L) |>
  arrange(yr) |>
  filter(yr >= 2018) |>
  print()

# Export -----------------------------------------------------------------------
logbook_inputs <- c(
  unlist(lapply(c("afli", "fs_afladagbok", "adb"), \(s)
    c(fd_staging(s, "trip.parquet"), fd_staging(s, "station.parquet"),
      fd_staging(s, "fishing_sample.parquet"), fd_staging(s, "catch.parquet")))),
  fd_staging("afli", "depth.parquet"), fd_staging("adb", "lon_sign.parquet"))
merged_trip           |> write_curated(fd_curated("logbook", "trip.parquet"),           inputs = logbook_inputs)
merged_station        |> write_curated(fd_curated("logbook", "station.parquet"),        inputs = logbook_inputs)
merged_fishing_sample |> write_curated(fd_curated("logbook", "fishing_sample.parquet"), inputs = logbook_inputs)
merged_catch          |> write_curated(fd_curated("logbook", "catch.parquet"),          inputs = logbook_inputs)
