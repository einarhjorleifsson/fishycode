# Consolidate all AIS / GPS sources into a single Icelandic-vessel track dataset.
#
# Inputs:
#   data-dump/ais/stk/trail/                  — STK AIS pings (mid-keyed, all vessels)
#   data-raw/ais/astd/                        — ASTD commercial AIS (all flags, parquet)
#   data-raw/ais/astdB/                       — ASTDB commercial AIS (all flags, parquet)
#   data-raw/logbooks/afli/sensor_GPS.parquet — AIS-corrected GPS logger positions
#   data-dump/ais/EmodNet/is2017.csv          — EmodNet AIS snapshot (Iceland, 2017 only)
#   data/vessels/stk_vessel_match.parquet     — mid → vid temporal lookup
#
# Output:
#   data/trail/   — Hive-partitioned parquet (by year); ~566 M rows (Icelandic vessels)
#
# All heavy lifting is done lazily in DuckDB; data never fully enter R memory.
library(tictoc)
tic()
library(sf)
library(duckdb)
library(duckdbfs)
library(tidyverse)
duckdbfs::load_spatial()

# mid → vid match table, for the STK temporal interval join.
vid <- duckdbfs::open_dataset(fd_curated("vessel", "vessel_ais_key.parquet"))

# vid → identity over time, for the commercial providers, which are keyed by MMSI.
# This used to be `vid |> select(mmsi, vid) |> distinct()` off the key above - no
# time dimension at all. The registry reissues 21 MMSIs from one hull to the next,
# and the key carries exactly one vid per MMSI (ais_key.R picks it with
# arrange(mmsi, desc(mmsi_t2)) |> slice(1)), so every ASTD and ASTDB ping on a
# reissued MMSI landed on the LATER hull for all time. In each of the 21 cases it
# is the earlier holder whose whole era was misattributed: OLAFUR's 2007-08 pings
# became HOFFELL's, which is also why OLAFUR shows up in
# curated/check/ais_key_landings.parquet as a vessel that lands fish and has no
# AIS track. Joining on (mmsi, time) instead of mmsi is the fix.
idy <-
  duckdbfs::open_dataset(fd_curated("vessel", "vessel_identity.parquet")) |>
  filter(!is.na(mmsi)) |>
  select(mmsi, vid, t1, t2)

# stk --------------------------------------------------------------------------
# STK is Iceland's domestic AIS receiver network. Pings are keyed by `mid`
# (a STK-internal mobile ID), so we resolve to vid via a temporal interval join:
# each mid may map to different vessels over time as transponders are reused.
stk <- duckdbfs::open_dataset(fd_raw("ais", "stk", "trail")) |>
  inner_join(vid |> select(vid, mmsi, mid, d1, d2) |> filter(!is.na(vid)),
             by = join_by(mid, between(time, d1, d2))) |>
  select(vid, mmsi, time, lon, lat, speed, heading)

# astd -------------------------------------------------------------------------
# ASTD is a global commercial AIS feed. The raw data cover all flags, so we
# filter to 9-digit MMSIs starting with "251" (Iceland's MID) before joining
# to vid. Speed is not directly available; we derive it from distance/time
# between consecutive pings and convert m/s → knots.
astd  <- open_dataset(fd_staging("ais", "astd")) |>
  mutate(mmsi = as.character(mmsi),
         nc = nchar(mmsi)) |>
  filter(nc == 9 & str_sub(mmsi, 1, 3) == "251") |>
  inner_join(idy, by = join_by(mmsi, between(date_time_utc, t1, t2))) |>
  mutate(speed = dist_nextpoint / sec_nextpoint * 1.94384449) |>
  select(vid, mmsi, time = date_time_utc,
         lon = longitude, lat = latitude,
         speed,
         imo = imonumber) |>
  # IMO numbers ≤ 0 are placeholder/null values in this feed
  mutate(imo = ifelse(imo <= 0, NA, imo))

# astdB ------------------------------------------------------------------------
# ASTDB is a second commercial AIS feed. Filtered to Iceland (cc_iso3 == "ISL")
# before joining; this provider includes COG in addition to true heading.
astdB <- open_dataset(fd_staging("ais", "astdB")) |>
  filter(cc_iso3 == "ISL") |>
  mutate(mmsi = as.character(mmsi)) |>
  inner_join(idy, by = join_by(mmsi, between(date_time_utc, t1, t2))) |>
  select(vid, mmsi, time = date_time_utc,
         lon, lat,
         speed,
         heading = true_heading, cog)

# NOTE: the afli GPS logger is deliberately NOT merged here.
# Its timestamps, speeds and headings are sound, but its lon/lat are not - they
# carry a DDMMmm encoding fault. The approximation that supplies usable
# positions derives them FROM this merged track, so folding its output back in
# would be circular: the union would contain positions interpolated from itself.
# It now happens downstream instead, in curate/logbook_sensor_gps.R, writing
# curated/logbook/sensor_gps. That is also the honest model - the logger is
# logbook sensor data, not an AIS feed.

# emodnet ----------------------------------------------------------------------
# EmodNet snapshot: Iceland-only extract for 2017. Speed is recomputed from
# consecutive pings because the feed does not carry it directly.
# Note: an additional 2019 file exists (AdditionalMMSI20190327.csv) but was
# excluded due to parsing issues.
emn <-
  read_csv(fd_raw("ais", "EmodNet", "is2017.csv")) |>
  select(mmsi, time = utime, lon, lat, heading = trueheading, cog) |>
  mutate(mmsi = as.character(mmsi)) |>
  left_join(vid |> filter(!is.na(mmsi), !is.na(vid)) |> select(mmsi, vid) |> distinct(mmsi, .keep_all = TRUE) |>
              collect()) |>
  arrange(vid, time) |>
  group_by(vid) |>
  mutate(speed = ramb::rb_speed(lat, lon, time)) |>
  ungroup() |>
  select(vid, mmsi, time, lon, lat, speed, everything()) |>
  duckdbfs::as_dataset() |>
  # POSIXct registered via as_dataset() lands as TIMESTAMPTZ in DuckDB; cast to
  # plain TIMESTAMP so the union with other sources stays type-consistent.
  mutate(time = dplyr::sql("time::TIMESTAMP"))

# bind -------------------------------------------------------------------------
# Union the four MEASURED position sources; `provider` traces each ping back to
# its origin, which matters for coverage gap analysis.
d <-
  union(stk   |> mutate(provider = "stk"),
        astd  |> mutate(provider = "astd")) |>
  union(astdB |> mutate(provider = "astdB")) |>
  union(emn   |> mutate(provider = "emodnet"))

# ## add harbour -----------------------------------------------------------------
# # Tag each ping with a port ID where the position falls inside a port polygon.
# # Left join preserves pings at sea (pid = NA).
# print("adding harbour")
# d <-
#   d |>
#   mutate(geom = ST_POINT(lon, lat)) |>
#   duckdbfs::spatial_join(ports, by = "st_intersects", join = "left") |>
#   select(-geom_1)

# write out --------------------------------------------------------------------
# Partition by year so downstream queries can apply partition pruning.
# The loop materialises one year at a time to keep peak memory manageable.
years <- 2007:2026
for(y in 1:length(years)) {
  YR <- years[y]
  print(YR)
  d |>
    mutate(year = year(time)) |>
    filter(year == YR) |>
    arrange(vid, time) |>
    # duckdbfs::write_dataset keeps TIMESTAMP as-is; arrow::write_dataset
    # materialises through R POSIXct and re-writes as TIMESTAMPTZ.
    duckdbfs::write_dataset(fd_staging("ais", "ping_union"), partitioning = "year", format = "parquet")
}

toc()


#
# # issue / sanity test ----------------------------------------------------------
# #  one should have marked all the points in harbour in the above script
# #  here is a sanity test
# # this take too much time
# # d |>
# #   filter(is.na(pid)) |>
# #   select(-pid) |>
# #   duckdbfs::spatial_join(ports, by = "st_intersects", join = "left") |>
# #   select(-geom_1) |>
# #   # I did not expect this
# #   filter(!is.na(pid))
#
# # read from just created data
# ais2 <-
#   open_dataset(fd_staging("ais", "ping_union")) |>
#   # filter out all points in ports
#   filter(is.na(pid)) |>
#   select(-pid)
# ais2 |>
#   duckdbfs::spatial_join(ports, by = "st_intersects", join = "left") |>
#   select(-geom_1) |>
#   # I did not expect this
#   filter(!is.na(pid))
