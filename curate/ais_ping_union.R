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
# became HOFFELL's.
#
# The windows are used to place the BOUNDARY between successive holders, not to
# bound the feed. A plain between-join on t1..t2 was tried on 2026-09-22 and lost
# 95.5 M astd rows, because a hull's registry window closes whenever yh2 is stale -
# and yh2 is stale for at least 21 vessels that are demonstrably still fishing
# (curate/corrections/vessel_registry_stale_lifetime.yml). Dropping a ping because
# the registry forgot to update a year is not a defensible thing to do.
#
# So: an MMSI held by exactly one hull matches at any time, and an MMSI held by
# several is split at the handover dates, with the first period open at the start
# and the last open at the end. Coverage is preserved; only the ambiguous cases are
# cut, which is the whole and only job.
OPEN_T1 <- as.POSIXct("1970-01-01", tz = "UTC")
OPEN_T2 <- as.POSIXct("2099-12-31", tz = "UTC")
idy <-
  duckdbfs::open_dataset(fd_curated("vessel", "vessel_identity.parquet")) |>
  filter(!is.na(mmsi)) |>
  select(mmsi, vid, t1 = mmsi_t1, t2 = mmsi_t2) |>
  collect() |>
  group_by(mmsi) |>
  arrange(t1, .by_group = TRUE) |>
  mutate(t1 = if_else(row_number() == 1L,  OPEN_T1, as.POSIXct(t1)),
         t2 = if_else(row_number() == n(), OPEN_T2, as.POSIXct(t2))) |>
  ungroup() |>
  duckdbfs::as_dataset() |>
  mutate(t1 = dplyr::sql("t1::TIMESTAMP"), t2 = dplyr::sql("t2::TIMESTAMP"))

# stk --------------------------------------------------------------------------
# STK is Iceland's domestic AIS receiver network. Pings are keyed by `mid`
# (a STK-internal mobile ID), so we resolve to vid via a temporal interval join:
# each mid may map to different vessels over time as transponders are reused.
stk <- duckdbfs::open_dataset(fd_raw("ais", "stk", "trail")) |>
  # half-open on d2 + 1: d2 is a date, and a period's last day runs to its end (see sources/stk/convert.R)
  inner_join(vid |> select(vid, mmsi, mid, d1, d2) |> filter(!is.na(vid)) |> mutate(d2e = d2 + 1L),
             by = join_by(mid, time >= d1, time < d2e)) |>
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
  # Drop the placeholder half of a duplicated ping. The feed delivers some pings
  # twice: one copy with a real next-point and one with dist_nextpoint = 0 and
  # sec_nextpoint = 1 exactly. Every emission column scales with that duration, so
  # the pair appears to differ in sixteen columns for one reason.
  #
  # It matters because speed here is DERIVED as dist/sec, so the placeholder's
  # speed is 0 knots - a fabricated stationary reading, and stationary is what
  # decides fishing versus not fishing downstream.
  #
  # Measured over 2019 (curate/corrections/ping_union_duplicate_keys.yml): 5,536 of
  # 5,613 duplicate groups have exactly one such member. The 69 with none and the 8
  # with two are deliberately left alone - .n_real == 0 keeps both - because there
  # is nothing in the data to choose between them.
  group_by(mmsi, date_time_utc, longitude, latitude) |>
  mutate(.degen  = as.integer(dist_nextpoint == 0 & sec_nextpoint == 1),
         .n_real = sum(1L - .degen)) |>
  ungroup() |>
  filter(.degen == 0 | .n_real == 0) |>
  select(-c(.degen, .n_real)) |>
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
  # as.integer() FIRST. astdB stores mmsi as a DOUBLE, and DuckDB renders a double
  # as VARCHAR with its decimal point: as.character(251525240) is "251525240.0",
  # eleven characters, which matches no nine-character MMSI anywhere. That silently
  # discarded 11,119,034 of the 11,147,504 Icelandic astdB rows - the entire feed's
  # contribution to the union was 0 (curate/corrections/astdb_mmsi_double_cast.yml).
  mutate(mmsi = as.character(as.integer(mmsi))) |>
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
  # Time-aware, for the same reason as astd and astdB above: an MMSI reissued from
  # one hull to the next resolves to whichever held it at the time, not to whichever
  # distinct() happened to keep. This cast is in R, not DuckDB, so it is safe -
  # R renders a whole double without a decimal point.
  left_join(idy |> collect(), by = join_by(mmsi, between(time, t1, t2))) |>
  select(-c(t1, t2)) |>
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
