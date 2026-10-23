# Merge afli (legacy), fs_afladagbok, adb and the ERS catch reports (aflaskeyti) into unified logbook tables.
# Side: preprocessing (logbook). See plan 014.
# Input:  staging/{afli,fs_afladagbok,adb,aflaskeyti}/{trip,station,fishing_sample,catch}.parquet, and the side
#         tables named under "Load"; the dump stamps (fd.dumped, never the rows) of raw/oracle/{afli,fs_afli}/stofn,
#         adb/fishing_station and dw/dw_aflaskeyti, for the date caps
# Output: curated/logbook/{trip,station,fishing_sample,catch}.parquet
#
# Decision rule (tiered priority):
#   Tier 1 — if (vid, date) present in afli                        → use afli
#   Tier 2 — not in afli, but present in fs_afladagbok             → use fs_afladagbok
#   Tier 2b — not in either, and an afli station read from fs_afli  → use it (decision 124)
#   Tier 3 — not in afli or fs_afladagbok, present in adb from ADB_DATE_MIN on → use adb
#   Tier 4 — in none of them, present in aflaskeyti                → use aflaskeyti (plan 026): the foreign
#            vessels' hauls of 2014-2018, and the Icelandic vessels' hauls on vessel-days their logbook lacks
#
# Rationale:
#   afli > fs_afladagbok: afli mobile-gear timing is derived from the on-bottom
#   clock; when fs_afladagbok was instigated, timestamps and/or duration were
#   missing in fs_afladagbok.
#   fs_afladagbok > adb: fs_afladagbok is the dump of the e-logbook; adb is
#   derived from it and from other schemas, with errors of its own, and is
#   read only for the dates the dump no longer covers (decision 160).
#
# Date bounds applied:
#   afli          — no lower bound; upper: <= AFLI_DATE_MAX, the day after its dump
#   fs_afladagbok — lower: >= FS_DATE_MIN; upper: <= FS_DATE_MAX (static dump)
#   adb           — lower: >= ADB_DATE_MIN, the day fs_afladagbok's dump starts
#                   to thin (decision 160); upper: <= ADB_DATE_MAX, the day after
#                   its dump. From that day the tier anti-join decides which of
#                   the two holds a vessel-day, since the dump goes on to 2025-11-28.
#   aflaskeyti    — no lower bound; upper: <= ERS_DATE_MAX, the day after its dump
#
# Depth: z1/z2 are converted to metres (curate/decisions/022), z1_raw/z2_raw
# keep the original recorded value, z1_basis/z2_basis says which happened.
# Longitude: adb's dropped west sign is fixed by curate/corrections/
# adb_vs_fs_afladagbok.R (lon1_raw/lon2_raw/lon1_basis/lon2_basis), and afli's end longitude where Oracle holds the
# end latitude by curate/corrections/afli_end_longitude.R (lon2_raw/lon2_basis).
# aflaskeyti: three corrections and the trips, each a side table (plan 026): the swapped positions
# (aflaskeyti_coordinates.R: lon1_raw, lat1_raw, lon2_raw, lat2_raw, coord_flag), the Faroese summer times
# (aflaskeyti_local_time.R: t_shift_min, time_basis), the state of each weight (aflaskeyti_weight.R:
# condition_basis), and the trips cut at landings in Iceland (curate/aflaskeyti_trip.R: T1_basis, T2_basis).
# Station type: station.parquet carries station_type (operation / event) and
# station_type_basis, read per vessel, year and gear (decision 084).
# Set times: a logbook app's placeholder t1 is NA in fishing_sample.parquet, t1_placeholder TRUE (decision 157).

library(tidyverse)
library(duckdbfs)

# Parameters -------------------------------------------------------------------
FS_DATE_MIN  <- as.Date("2020-01-01")
FS_DATE_MAX  <- as.Date("2025-12-31")
# Decision 160: adb only for the dates fs_afladagbok's dump no longer covers. The dump holds 99-100 % of adb's
# vessel-days up to 2025-11-19, then 95 % falling to 3 % on 11-28; what it lacks before 11-19 is strays.
ADB_DATE_MIN <- as.Date("2025-11-19")
# Decision 181: no haul is later than the copy it was read from. Each source is capped at the day after its dump began
# (fd.dumped; a dump can run past midnight), which leaves out the dates entered in the future (26 adb stations,
# 2027-2031) and lets each new year in, where the fixed 2026-12-31 that stood here would have dropped it.
dump_day_after <- function(schema, table) {
  m <- curated_provenance(fd_raw("oracle", schema, table))
  d <- as.Date(substr(m$value[m$key == "fd.dumped"], 1, 10))
  stopifnot("a logbook dump carries no fd.dumped stamp" = length(d) == 1 && !is.na(d))
  d + 1L
}
AFLI_DATE_MAX <- max(dump_day_after("afli", "stofn.parquet"), dump_day_after("fs_afli", "stofn.parquet"))
ADB_DATE_MAX  <- dump_day_after("adb", "fishing_station.parquet")
ERS_DATE_MAX  <- dump_day_after("dw", "dw_aflaskeyti.parquet")
# curate/decisions/022-depth-unit-is-metres.md: product-wide depth is metres.
# fs_afladagbok has no drift (curate/corrections/afli_depth_units.yml baseline) -
# a flat conversion is enough; afli's vessel-by-vessel drift needs its own
# correction, curate/corrections/afli_depth_units.R, run beforehand. adb is
# fathoms too: its adapter reads the table, not the view station_v that gave
# metres (curate/corrections/adb_station_v_positions.yml), and it is converted
# the same way.
FATHOM_TO_M <- 1.8288

# Load -------------------------------------------------------------------------
afli_trip           <- duckdbfs::open_dataset(fd_staging("afli", "trip.parquet")) |> collect()
afli_station        <- duckdbfs::open_dataset(fd_staging("afli", "station.parquet")) |> collect()
afli_fishing_sample <- duckdbfs::open_dataset(fd_staging("afli", "fishing_sample.parquet")) |> collect()
afli_catch          <- duckdbfs::open_dataset(fd_staging("afli", "catch.parquet")) |> collect()
afli_depth          <- duckdbfs::open_dataset(fd_staging("afli", "depth.parquet")) |> collect()
afli_end_lon        <- duckdbfs::open_dataset(fd_staging("afli", "end_longitude.parquet")) |> collect()

fs_trip           <- duckdbfs::open_dataset(fd_staging("fs_afladagbok", "trip.parquet")) |> collect()
fs_station        <- duckdbfs::open_dataset(fd_staging("fs_afladagbok", "station.parquet")) |> collect()
fs_fishing_sample <- duckdbfs::open_dataset(fd_staging("fs_afladagbok", "fishing_sample.parquet")) |> collect()
fs_catch          <- duckdbfs::open_dataset(fd_staging("fs_afladagbok", "catch.parquet")) |> collect()

adb_trip           <- duckdbfs::open_dataset(fd_staging("adb", "trip.parquet")) |> collect()
adb_station        <- duckdbfs::open_dataset(fd_staging("adb", "station.parquet")) |> collect()
adb_fishing_sample <- duckdbfs::open_dataset(fd_staging("adb", "fishing_sample.parquet")) |> collect()
adb_catch          <- duckdbfs::open_dataset(fd_staging("adb", "catch.parquet")) |> collect()
adb_lon_sign       <- duckdbfs::open_dataset(fd_staging("adb", "lon_sign.parquet")) |> collect()

# aflaskeyti's trips and station keys come from curate/aflaskeyti_trip.R, not from the adapter's runs.
ers_trip           <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "trip_landing.parquet")) |> collect()
ers_station_trip   <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "station_trip.parquet")) |> collect()
ers_station        <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "station.parquet")) |> collect()
ers_fishing_sample <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "fishing_sample.parquet")) |> collect()
ers_catch          <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "catch.parquet")) |> collect()
ers_coordinates    <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "coordinates.parquet")) |> collect()
ers_time           <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "time.parquet")) |> collect()
ers_weight         <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "weight.parquet")) |> collect()

# Depth unit ---------------------------------------------------------------
# afli: replace z1/z2 with the per-vessel-period corrected value from
# afli_depth_units.R; keep z1_raw/z2_raw/z1_basis/z2_basis (never overwrite the
# original - AGENTS.md).
afli_station <- afli_station |>
  select(-z1, -z2) |>
  left_join(afli_depth, by = ".sid")
# afli: the end longitude the logbook sent, where Oracle holds the end latitude in its place
# (curate/corrections/afli_end_longitude.R); lon2_raw/lon2_basis keep what happened.
afli_station <- afli_station |>
  select(-lon2) |>
  left_join(afli_end_lon, by = ".sid", relationship = "one-to-one")

# fs_afladagbok and adb: uniformly fathoms (no drift window), so a flat conversion with
# basis = "reconstructed"; NA stays NA, basis NA.
fathoms_to_metres <- function(station) {
  station |>
    mutate(z1_raw = z1, z2_raw = z2,
           z1 = z1_raw * FATHOM_TO_M, z2 = z2_raw * FATHOM_TO_M,
           z1_basis = if_else(is.na(z1_raw), NA_character_, "reconstructed"),
           z2_basis = if_else(is.na(z2_raw), NA_character_, "reconstructed"))
}
fs_station <- fs_station |> fathoms_to_metres()

# adb: longitude: replace lon1/lon2 with adb_vs_fs_afladagbok.R's sign-corrected
# value, keep lon1_raw/lon2_raw/lon1_basis/lon2_basis (never overwrite the
# original - AGENTS.md).
adb_station <- adb_station |>
  fathoms_to_metres() |>
  select(-lon1, -lon2) |>
  left_join(adb_lon_sign |> select(.sid, lon1, lon2, lon1_raw, lon2_raw, lon1_basis, lon2_basis),
            by = ".sid")

# aflaskeyti: positions swapped back, times in UTC, each weight's state, and the trips (plan 026). No depth.
ers_station <- ers_station |>
  select(-lon1, -lat1, -lon2, -lat2, -.tid) |>
  left_join(ers_coordinates, by = ".sid", relationship = "one-to-one") |>
  left_join(ers_station_trip, by = ".sid", relationship = "one-to-one")
ers_fishing_sample <- ers_fishing_sample |>
  select(-t1, -t2, -t3, -t4, -.tid) |>
  left_join(ers_time, by = ".sid", relationship = "one-to-one") |>
  left_join(ers_station_trip, by = ".sid", relationship = "one-to-one")
ers_catch <- ers_catch |>
  select(-condition, -catch_whole) |>
  left_join(ers_weight, by = c(".sid", "sid"), relationship = "one-to-one")
stopifnot(!anyNA(ers_station$.tid), !anyNA(ers_station$lat1), all(ers_station$.tid %in% ers_trip$.tid))

# Apply date bounds ------------------------------------------------------------
afli_station <- afli_station |> filter(date <= AFLI_DATE_MAX)
fs_station   <- fs_station   |> filter(date >= FS_DATE_MIN, date <= FS_DATE_MAX)
adb_station  <- adb_station  |> filter(date >= ADB_DATE_MIN, date <= ADB_DATE_MAX)
ers_station  <- ers_station  |> filter(date <= ERS_DATE_MAX)

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

# Tier 1: afli — full coverage, less the stations read from fs_afli -------------
afli_fs_station <- afli_station |> filter(copy == "fs_afli")
afli_station    <- afli_station |> filter(copy == "afli")
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

# Tier 2b: the paper stations only fs_afli holds -------------------------------
# Where afli or fs_afladagbok has the vessel-day, they are the same hauls entered again (decision 123): of the
# 17 such stations, 14 carry the same kg as a station already there, and one has no catch.
afli_fs_kept <- afli_fs_station |>
  left_join(afli_trip |> select(.tid, vid), by = ".tid") |>
  anti_join(bind_rows(afli_vid_date, fs_only_vid_date), by = c("vid", "date"))
afli_fs_vid_date <- afli_fs_kept |> distinct(vid, date)
afli_station <- bind_rows(afli_station, afli_fs_kept |> select(-vid))

afli_trip           <- afli_trip           |> semi_join(afli_station |> distinct(.tid), by = ".tid")
afli_fishing_sample <- afli_fishing_sample |> semi_join(afli_station |> distinct(.sid), by = ".sid")
afli_catch          <- afli_catch          |> semi_join(afli_station |> distinct(.sid), by = ".sid")

# Tier 3: adb — vessel-days not covered by afli or fs_afladagbok --------------
# fs_afladagbok and adb are copies of one e-logbook (the same station ids), so from ADB_DATE_MIN until the dump ends
# this keeps only the vessel-days the dump never received, and after it almost all of adb.
tier12_vid_date <- bind_rows(afli_vid_date, fs_only_vid_date, afli_fs_vid_date)

adb_only_station <- adb_station |>
  left_join(adb_trip |> select(.tid, vid), by = ".tid") |>
  anti_join(tier12_vid_date, by = c("vid", "date")) |>
  select(-vid)

adb_sids_kept <- adb_only_station |> distinct(.sid)
adb_tids_kept <- adb_only_station |> distinct(.tid)

adb_only_trip           <- adb_trip           |> semi_join(adb_tids_kept, by = ".tid")
adb_only_fishing_sample <- adb_fishing_sample |> semi_join(adb_sids_kept, by = ".sid")
adb_only_catch          <- adb_catch          |> semi_join(adb_sids_kept, by = ".sid")

# Tier 4: aflaskeyti — vessel-days not covered by tiers 1-3 ---------------------
# The ERS catch reports of 2014-2018 (plan 026). No foreign vessel-day is held above; of the Icelandic vessels'
# hauls, those on vessel-days their logbook holds are the same hauls again (4,716 of 5,050 within a minute), and
# the rest fill days nothing else holds (plan 026 §7).
tier123_vid_date <- bind_rows(
  tier12_vid_date,
  adb_only_station |> left_join(adb_trip |> select(.tid, vid), by = ".tid") |> distinct(vid, date))

ers_only_station <- ers_station |>
  left_join(ers_trip |> select(.tid, vid), by = ".tid") |>
  anti_join(tier123_vid_date, by = c("vid", "date")) |>
  select(-vid)

ers_sids_kept <- ers_only_station |> distinct(.sid)
ers_tids_kept <- ers_only_station |> distinct(.tid)

ers_only_trip           <- ers_trip           |> semi_join(ers_tids_kept, by = ".tid")
ers_only_fishing_sample <- ers_fishing_sample |> semi_join(ers_sids_kept, by = ".sid")
ers_only_catch          <- ers_catch          |> semi_join(ers_sids_kept, by = ".sid")

# Merge ------------------------------------------------------------------------
merged_trip <- bind_rows(
  afli_trip    |> mutate(.tid = as.character(.tid)),
  fs_only_trip |> mutate(.tid = as.character(.tid)),
  adb_only_trip |> mutate(.tid = as.character(.tid)),
  ers_only_trip
)

merged_station <- bind_rows(
  afli_station     |> mutate(.tid = as.character(.tid)),
  fs_only_station  |> mutate(.tid = as.character(.tid)),
  adb_only_station |> mutate(.tid = as.character(.tid)),
  ers_only_station
)

merged_fishing_sample <- bind_rows(
  afli_fishing_sample     |> mutate(.tid = as.character(.tid)),
  fs_only_fishing_sample  |> mutate(.tid = as.character(.tid)),
  adb_only_fishing_sample |> mutate(.tid = as.character(.tid)),
  ers_only_fishing_sample
)

merged_catch <- bind_rows(afli_catch, fs_only_catch, adb_only_catch, ers_only_catch)

# Twin records -----------------------------------------------------------------
# One operation entered as two or more stations (curate/corrections/logbook_twin.yml, decision 094). A twin
# group is the stations of one vessel, in one schema, with identical t1-t4, at least one of them a time of day:
# all at 00:00 is a date, several untimed stations of one day, not a twin. In a group, stations with identical
# catch (every species, condition and weight; no catch counts as a catch) are one record entered more than once:
# the first (not deleted, then lowest .sid) is `kept`, the others `duplicate`, with `twin_of` the kept .sid. A
# member whose catch matches no other member's is `same_time`, a record of its own whose times equal another's.
# The landings decided the rule (maintainer, 2026-10-14): a trip's logbook catch is about twice its landing with
# every copy counted and equal to it with one, while dropping a same-time record does not bring a trip nearer.
# A trip all of whose stations are duplicates of one other trip's is that trip submitted again: trip `twin`
# "duplicate" and `twin_of` the other trip's .tid, which is "kept". Nothing is dropped here; every table that
# sums catch or effort, and every link, leaves the duplicates out.
is_tod <- function(t) !is.na(t) & as.numeric(t) %% 86400 != 0
tw <- merged_fishing_sample |>
  select(.sid, .tid, schema, eytt_deleted, t1, t2, t3, t4) |>
  left_join(merged_trip |> select(.tid, schema, vid), by = c(".tid", "schema"), relationship = "many-to-one") |>
  filter(!is.na(vid), is_tod(t1) | is_tod(t2) | is_tod(t3) | is_tod(t4)) |>
  filter(n() > 1, .by = c(vid, schema, t1, t2, t3, t4))
tw_sig <- merged_catch |>
  semi_join(tw, by = c(".sid", "schema")) |>
  arrange(sid, condition, catch) |>
  summarise(sig = paste(sid, condition, catch, sep = ":", collapse = ","), .by = c(.sid, schema))
tw <- tw |>
  left_join(tw_sig, by = c(".sid", "schema"), relationship = "one-to-one") |>
  mutate(sig = coalesce(sig, "")) |>
  arrange(coalesce(eytt_deleted, FALSE), .sid) |>
  mutate(n_same = n(), kept_sid = first(.sid), kept_tid = first(.tid), .by = c(vid, schema, t1, t2, t3, t4, sig)) |>
  mutate(twin    = case_when(n_same == 1 ~ "same_time", .sid == kept_sid ~ "kept", .default = "duplicate"),
         twin_of = if_else(twin == "duplicate", kept_sid, NA_real_))
tw_trip <- tw |>
  filter(twin == "duplicate") |>
  summarise(n_dup = n(), n_kept_tid = n_distinct(kept_tid), kept_tid = first(kept_tid), .by = c(.tid, schema)) |>
  inner_join(merged_station |> count(.tid, schema, name = "n_st"), by = c(".tid", "schema")) |>
  filter(n_dup == n_st) |>
  mutate(twin = "duplicate", twin_of = if_else(n_kept_tid == 1, kept_tid, NA_character_))
tw_trip <- bind_rows(
  tw_trip |> select(.tid, schema, twin, twin_of),
  tw_trip |> filter(!is.na(twin_of)) |> distinct(.tid = twin_of, schema) |> mutate(twin = "kept"))
stopifnot(!anyDuplicated(tw_trip[c(".tid", "schema")]))
merged_station <- merged_station |>
  left_join(tw |> select(.sid, schema, twin, twin_of), by = c(".sid", "schema"), relationship = "one-to-one")
merged_trip <- merged_trip |>
  left_join(tw_trip, by = c(".tid", "schema"), relationship = "one-to-one")

# Station type -----------------------------------------------------------------
# What a station row covers (`station_type` in docs/grammar.qmd, decision 084): `operation`, one setting, tow
# or haul, or `event`, one record for the day. No logbook says which, and it varies by vessel and over time,
# so it is read per vessel, year and gear from the vessel's own pattern: the share of its fishing days with
# more than one record. Vessel-years pile up at 0 and near 1; below ST_MULTI_MIN is one record a day.
# Longlines are `operation` whatever the share (maintainer, 2026-10-09): one set a day is what a longliner
# does, so a single record a day says nothing. Here, on the merged tables, because the tiers mix schemas
# within a vessel-year; deleted records and duplicate twins are left out of the pattern.
ST_MULTI_MIN <- 0.1
station_gear <- merged_fishing_sample |> distinct(.sid, schema, gear)
stopifnot(!anyDuplicated(station_gear[c(".sid", "schema")]))
st_base <- merged_station |>
  select(.sid, .tid, schema, date, eytt_deleted, twin) |>
  left_join(merged_trip |> select(.tid, schema, vid), by = c(".tid", "schema"), relationship = "many-to-one") |>
  left_join(station_gear, by = c(".sid", "schema"), relationship = "one-to-one") |>
  mutate(yr = year(date))
st_pattern <- st_base |>
  filter(!coalesce(eytt_deleted, FALSE), !coalesce(twin == "duplicate", FALSE), !is.na(vid), !is.na(date)) |>
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

# Placeholder set times --------------------------------------------------------
# Trackwell's logbook app fills the set time with the haul start less 270 min (or 1,710 min), cut to the minute
# (curate/corrections/logbook_set_placeholder.yml, decision 157). Such a t1 is not the skipper's: it becomes NA and
# t1_placeholder says why; the value as recorded stays in staging/. After the twins, which compare t1 as recorded.
# The soak and effort made from it before curate/ (fs_afladagbok's static duration_m is t4 - t1) are left as they
# are: t1_placeholder marks them too.
to_minute <- function(t) t - as.numeric(t) %% 60
is_offset <- function(t1, t3, m) !is.na(t1) & !is.na(t3) &
  (t1 == to_minute(t3 - m * 60) | t3 == to_minute(t1 + m * 60))
merged_fishing_sample <- merged_fishing_sample |>
  mutate(t1_placeholder = schema %in% c("afli", "fs_afladagbok", "adb") &
           (is_offset(t1, t3, 270) | is_offset(t1, t3, 1710)),
         t1 = if_else(t1_placeholder, NA_POSIXct_, t1))

# Summary ----------------------------------------------------------------------
cat(sprintf("afli stations (filtered):   %d\n", nrow(afli_station)))
cat(sprintf("  of them read from fs_afli: %d of %d\n", nrow(afli_fs_kept), nrow(afli_fs_station)))
cat(sprintf("fs-only stations:           %d\n", nrow(fs_only_station)))
cat(sprintf("adb-only stations:          %d\n", nrow(adb_only_station)))
cat(sprintf("aflaskeyti-only stations:   %d of %d\n", nrow(ers_only_station), nrow(ers_station)))
cat(sprintf("merged stations:            %d\n", nrow(merged_station)))
cat(sprintf("afli trips (filtered):      %d\n", nrow(afli_trip)))
cat(sprintf("fs-only trips:              %d\n", nrow(fs_only_trip)))
cat(sprintf("adb-only trips:             %d\n", nrow(adb_only_trip)))
cat(sprintf("aflaskeyti-only trips:      %d\n", nrow(ers_only_trip)))
cat(sprintf("merged trips:               %d\n", nrow(merged_trip)))
cat(sprintf("merged catch:               %d\n", nrow(merged_catch)))

cat("\nStation type by gear (stations):\n")
merged_station |>
  left_join(station_gear, by = c(".sid", "schema")) |>
  count(gear, station_type, station_type_basis) |>
  pivot_wider(names_from = c(station_type, station_type_basis), values_from = n, values_fill = 0L) |>
  print(n = 30)

cat("\nTwin records (curate/corrections/logbook_twin.yml), stations and trips:\n")
merged_station |> filter(!is.na(twin)) |> count(schema, twin) |>
  pivot_wider(names_from = twin, values_from = n, values_fill = 0L) |> print()
merged_trip |> filter(!is.na(twin)) |> count(schema, twin, has_twin_of = !is.na(twin_of)) |> print()

cat("\nPlaceholder set times (curate/corrections/logbook_set_placeholder.yml), t1 set to NA:\n")
merged_fishing_sample |> filter(t1_placeholder) |> count(schema, gear) |> print()

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
  fd_staging("afli", "depth.parquet"), fd_staging("afli", "end_longitude.parquet"), fd_staging("adb", "lon_sign.parquet"),
  unlist(lapply(c("station", "fishing_sample", "catch", "trip_landing", "station_trip", "coordinates", "time",
                  "weight"), \(t) fd_staging("aflaskeyti", paste0(t, ".parquet")))))
merged_trip           |> write_curated(fd_curated("logbook", "trip.parquet"),           inputs = logbook_inputs)
merged_station        |> write_curated(fd_curated("logbook", "station.parquet"),        inputs = logbook_inputs)
merged_fishing_sample |> write_curated(fd_curated("logbook", "fishing_sample.parquet"), inputs = logbook_inputs)
merged_catch          |> write_curated(fd_curated("logbook", "catch.parquet"),          inputs = logbook_inputs)
