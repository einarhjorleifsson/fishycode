# Consolidate all AIS / GPS sources into a single Icelandic-vessel track dataset.
# Side: preprocessing (ais feeds). See plan 014.
#
# Inputs:
#   raw/oracle/stk/trail, through stk_trail()   — STK AIS pings (mid-keyed, all vessels; R/stk_trail.R)
#   staging/ais/stk_event.parquet               — STK's port events (sources/stk/event.R): which arrivals stay as fixes
#   staging/ais/astd/                           — ASTD commercial AIS (all flags, parquet)
#   staging/ais/astdB/                          — ASTDB commercial AIS (all flags, parquet)
#   curated/logbook/sensor_gps/                 — AIS-corrected GPS logger positions
#   raw/ais/EmodNet/is2017.csv                  — EmodNet AIS snapshot (Iceland, 2017 only)
#   curated/vessel/vessel_ais_key.parquet       — mid → vid temporal lookup (STK)
#   curated/vessel/vessel_identity.parquet      — vid → MMSI over time (the MMSI-keyed feeds)
#
# Output:
#   staging/ais/ping_union/   — Hive-partitioned parquet (by year); ~585 M rows (decision 112, plan 048). Beside the
#                               feeds' columns, STK's `stream` (stk_trail()'s, NA for the other providers, plan 048 ask
#                               f) and `io` ("I" on an STK arrival kept as a fix, else NA)
#   staging/ais/stk_receipt/  — STK's receipt of each ping of its VMS stream: vid, time, lon, lat, the unit (`mid`, STK's
#                               mobile id, and `n_mid`), the earliest receipt (`recdate`) and `n_rec`, the trail rows that
#                               hold it; by year (decision 196's side table, its receipt part: plan 060 §2)
#   staging/ais/ping_union_copies.parquet — by year and provider, the rows of the four measured feeds before and after
#                               the de-duplication of rows equal in every column (plan 060 §8)
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
  # a period of no known hull (vid NA, curate/corrections/mmsi_broadcast_unregistered.yml) is dropped only now, after the
  # windows are opened, so it cuts the neighbouring holder's window instead of being covered by it
  filter(!is.na(vid)) |>
  duckdbfs::as_dataset() |>
  mutate(t1 = dplyr::sql("t1::TIMESTAMP"), t2 = dplyr::sql("t2::TIMESTAMP"))

# The speed of a feed that has none ----------------------------------------------
# astd and emodnet carry no speed reading, so it is derived within the feed (AGENTS.md, Rules: derive within one
# stream): the chord from the MMSI's previous report to its next over the time between them, a central difference
# stamped at the ping, with the time it spans beside it (`speed_span_s`) for a consumer to judge a long interval; no
# speed is left out. Each position once, so a report delivered twice is not its own neighbour; the first and last report
# take the one side they have. The distance is on the WGS84 ellipsoid, from the local radii of curvature at the chord's
# mean latitude, as astd's own distance is: within 0.1 % of the geodesic for pings minutes apart, where the sphere
# would miss recorded speed over ground by heading, whose column and gear speed windows these share (decision 080).
# Checked against the study's variant c on 2019: equal to 1e-6 kn on 40.5 M astd pings. Plan 059 step 7 (ask
# i, the maintainer, 2026-11-01): against astd's forward difference stamped at the interval's start, the 2019 survey's
# tow ends both within 5 min 51.5 -> 54.7 %, hours fishing -0.15 % (`$FISHYDATA/archive/2026-11-01-astd-speed-stamp/`).
KN <- 1.94384449   # m/s to knots
ELLIPSOID_M <- paste0(
  "sqrt(pow(6335439.327 / pow(1 - 0.00669437999 * pow(sin(radians((lat0 + lat1) / 2)), 2), 1.5) * radians(lat1 - lat0), 2) + ",
  "pow(6378137.0 / sqrt(1 - 0.00669437999 * pow(sin(radians((lat0 + lat1) / 2)), 2)) * cos(radians((lat0 + lat1) / 2)) * ",
  "radians(((lon1 - lon0 + 540) % 360) - 180), 2))")
add_central_speed <- function(x) {
  s <- x |>
    filter(!is.na(lon), !is.na(lat)) |>
    distinct(mmsi, time, lon, lat) |>
    group_by(mmsi) |>
    dbplyr::window_order(time, lon, lat) |>
    mutate(t0 = coalesce(lag(time), time), lon0 = coalesce(lag(lon), lon), lat0 = coalesce(lag(lat), lat),
           t1 = coalesce(lead(time), time), lon1 = coalesce(lead(lon), lon), lat1 = coalesce(lead(lat), lat)) |>
    ungroup() |>
    mutate(speed_span_s = dplyr::sql("epoch(t1 - t0)"),
           speed = dplyr::sql(sprintf("CASE WHEN epoch(t1 - t0) > 0 THEN %s / epoch(t1 - t0) * %.8f END", ELLIPSOID_M, KN))) |>
    select(mmsi, time, lon, lat, speed, speed_span_s)
  left_join(x, s, by = c("mmsi", "time", "lon", "lat"))
}

# stk --------------------------------------------------------------------------
# STK is Iceland's domestic AIS receiver network. Pings are keyed by `mid`
# (a STK-internal mobile ID), so we resolve to vid via a temporal interval join:
# each mid may map to different vessels over time as transponders are reused.
# The raw trail is hive-partitioned by `year`. That is the year of the ping's time for all but ~33 k of ~290 M
# rows (bad timestamps: 1984, 1997, 2106 ... sit in a later partition), so a year is its own partition PLUS the
# rows of every other partition whose time falls in it: reading only year == YR would silently lose those.
stk_raw <- stk_trail()
stk_src <- function(YR) {
  union_all(stk_raw |> filter(year == YR),
            stk_raw |> filter(year != YR, year(time) == YR)) |>
    # half-open on d2 + 1: d2 is a date, and a period's last day runs to its end; a mid's last stretch, if open
    # (d2_is_open), has no end (see sources/stk/convert.R)
    inner_join(vid |> select(vid, mmsi, mid, d1, d2, d2_is_open) |>
                 group_by(mid) |> mutate(open = d2_is_open & d1 == max(d1, na.rm = TRUE)) |> ungroup() |>
                 filter(!is.na(vid)) |>
                 mutate(d2e = if_else(open, dplyr::sql("'infinity'::DATE"), d2 + 1L)),
               by = join_by(mid, time >= d1, time < d2e)) |>
    # the unit and its receipt go to stk_receipt, never into the union (decision 196)
    select(vid, mmsi, time, lon, lat, speed, heading, cog, stream, mid, recdate, io)
}
# STK's port events are events, not fixes (decision 196, plan 048 §2.2): every event row leaves the union but an
# arrival inside its own port at no marker (a position 10 or more vessels' events share): that position is the
# vessel's, in port, and stays a fix. The events themselves go to the flow from staging/ais/stk_event.parquet, where
# curate/port_call.R judges them with ramb::rb_flag_port_event(). Decision 288: 4,549,650 of the 8,460,441 event rows
# leave; a row equal to a fix of the dump is the fix and stays (its own `io` is NA).
stk_kept_arrivals <- duckdbfs::open_dataset(fd_staging("ais", "stk_event.parquet")) |>
  filter(io == "I", io_pos == "own", !marker) |>
  distinct(vid, time) |>
  mutate(kept = TRUE)
stk_fixes <- function(YR) {
  stk_src(YR) |>
    left_join(stk_kept_arrivals, by = c("vid", "time")) |>
    filter(is.na(io) | (io == "I" & !is.na(kept))) |>
    select(-kept)
}
# STK's VMS stream, by the position's grid (a hundredth of a minute: R/stk_trail.R's rule), its event rows left out
STK_VMS_GRID <- dplyr::sql("abs(lat * 6000 - round(lat * 6000)) < 0.0002 AND abs(lon * 6000 - round(lon * 6000)) < 0.0002")

# astd -------------------------------------------------------------------------
# ASTD is a global commercial AIS feed. The raw data cover all flags, so we
# filter to 9-digit MMSIs starting with "251" (Iceland's MID) before joining
# to vid. Speed is not in the feed as a reading; it is derived within the feed (add_central_speed() above).
# astd and astdB are hive-partitioned by `year` (astd also by `month`), and the partition IS the year of date_time_utc
# (0 mismatches), so a year reads its own partition and the month either side, where the first and last ping of the
# year find their neighbours. The duplicate-ping window below groups on identical timestamps, so it never reaches
# across a month: pruning first does not change it.
astd_src <- function(YR) open_dataset(fd_staging("ais", "astd")) |>
  filter(year == YR | (year == YR - 1L & month == "12") | (year == YR + 1L & month == "01")) |>
  mutate(mmsi = as.character(mmsi),
         nc = nchar(mmsi)) |>
  filter(nc == 9 & str_sub(mmsi, 1, 3) == "251") |>
  # Drop the placeholder half of a duplicated ping. The feed delivers some pings
  # twice: one copy with a real next-point and one with dist_nextpoint = 0 and
  # sec_nextpoint = 1 exactly. Every emission column scales with that duration, so
  # the pair appears to differ in sixteen columns for one reason.
  #
  # It mattered while speed was DERIVED here as dist/sec (to plan 059 step 8): the placeholder's
  # speed was 0 knots - a fabricated stationary reading, and stationary is what
  # decides fishing versus not fishing downstream. The speed now comes from the positions, but the
  # placeholder is still the feed's fault, and the drop stays.
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
  select(mmsi, time = date_time_utc, lon = longitude, lat = latitude, imo = imonumber) |>
  add_central_speed() |>
  filter(year(time) == YR) |>
  inner_join(idy, by = join_by(mmsi, between(time, t1, t2))) |>
  select(vid, mmsi, time, lon, lat, speed, speed_span_s, imo) |>
  # IMO numbers ≤ 0 are placeholder/null values in this feed
  mutate(imo = ifelse(imo <= 0, NA, imo))

# astdB ------------------------------------------------------------------------
# ASTDB is a second commercial AIS feed. Filtered to Iceland (cc_iso3 == "ISL")
# before joining; this provider includes COG in addition to true heading (its codes, 511 and 360 or more, NA below).
astdB_src <- function(YR) open_dataset(fd_staging("ais", "astdB")) |>
  filter(year == YR) |>
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
# EmodNet snapshot: Iceland-only extract for 2017. Speed is derived within the feed, as astd's
# (add_central_speed() above): by MMSI, the stream's identity. It was ramb::rb_calc_speed() by vid until
# plan 059 step 8, a backward difference, which put every MMSI with no known hull into one track (vid NA);
# its arguments were once swapped (curate/corrections/emodnet_speed_args_swapped.yml).
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
  duckdbfs::as_dataset() |>
  # POSIXct registered via as_dataset() lands as TIMESTAMPTZ in DuckDB; cast to
  # plain TIMESTAMP so the union with other sources stays type-consistent.
  mutate(time = dplyr::sql("time::TIMESTAMP")) |>
  add_central_speed() |>
  select(vid, mmsi, time, lon, lat, speed, speed_span_s, everything()) |>
  # once, not in every year's union
  compute()

# gps: the afli logger (plan 014) -----------------------------------------------
# A frozen input (curated/logbook/sensor_gps, decision 075): the logger's own time, speed and heading, with
# lon/lat interpolated once from the AIS track. Its positions are RECONSTRUCTED (pos_basis), so nothing in the
# flow that measures where a vessel is - the duplicate and impossible tests, the stays, the voyage cut - reads
# them; a gps fix gets its voyage by time afterwards. The rules are the ones curate/ais_ping_trail.R applied
# until plan 014: gps1 and gps2 (two raw tables of the same fixes) collapse to one row per (vid, time), with
# a real speed preferred over the 1.000 m/s placeholder (curate/corrections/logger_speed_placeholder.yml); a
# fix stamped to several stations keeps no single station (sid_gps NA, n_sid_gps counts them). Where the two
# tables disagree, gps1's value is taken, and between stations the lowest .sid's: any_value() chose
# arbitrarily, which moved 165 speeds of 2019 between runs (plan 014). A fix whose own reading is in whole degrees is
# left out: from mid-2020 the loggers write position to the degree and speed to the m/s (maintainer, 2026-10-20;
# curate/corrections/logger_whole_degrees.yml).
MS_TO_KN <- 1 / 0.514444
LOGGER_PLACEHOLDER_MS <- 1
gps_src <- function(YR) {
  g <- file.path(fd_curated("logbook", "sensor_gps"), paste0("year=", YR))
  if (!dir.exists(g)) return(NULL)
  # wrapped in SELECT * FROM (...): dbplyr inlines a WITH query bare inside UNION ALL, which DuckDB rejects
  dplyr::tbl(duckdbfs::cached_connection(), dplyr::sql(sprintf("
  SELECT * FROM (WITH g0 AS (
    SELECT vid, time, \".sid\" AS sid, sensor_src, lon, lat, dt_sec, heading,
           speed * %f AS speed_kn_raw,
           CASE WHEN abs(speed - %f) < 1e-6 THEN NULL ELSE speed * %f END AS speed_kn
    FROM read_parquet('%s/*.parquet') WHERE lon IS NOT NULL AND lat IS NOT NULL AND vid IS NOT NULL
      -- a reading in whole degrees comes from the loggers that, from mid-2020, cut position to whole degrees and speed
      -- to whole m/s: left out of the track (curate/corrections/logger_whole_degrees.yml)
      AND NOT coalesce(w_lat = round(w_lat) AND w_lon = round(w_lon), false)),
  g1 AS (
    SELECT vid, time, sid, arg_min(lon, sensor_src) AS lon, arg_min(lat, sensor_src) AS lat, arg_min(dt_sec, sensor_src) AS dt_sec,
           arg_min(heading, sensor_src) FILTER (WHERE heading IS NOT NULL) AS heading,
           arg_min(speed_kn, sensor_src) FILTER (WHERE speed_kn IS NOT NULL) AS speed_kn,
           arg_min(speed_kn_raw, sensor_src) FILTER (WHERE speed_kn IS NOT NULL) AS speed_kn_ok,
           arg_min(speed_kn_raw, sensor_src) FILTER (WHERE speed_kn_raw IS NOT NULL) AS speed_kn_raw
    FROM g0 GROUP BY vid, time, sid),
  g2 AS (
    SELECT vid, time, arg_min(lon, sid) AS lon, arg_min(lat, sid) AS lat, arg_min(dt_sec, sid) AS dt_sec,
           arg_min(heading, sid) AS heading,
           arg_min(speed_kn, sid) FILTER (WHERE speed_kn IS NOT NULL) AS speed_kn,
           coalesce(arg_min(speed_kn_ok, sid) FILTER (WHERE speed_kn_ok IS NOT NULL),
                    arg_min(speed_kn_raw, sid) FILTER (WHERE speed_kn_raw IS NOT NULL)) AS speed_kn_raw,
           count(DISTINCT sid) AS n_sid_gps,
           CASE WHEN count(DISTINCT sid) = 1 THEN min(sid) END AS sid_gps
    FROM g1 GROUP BY vid, time)
  SELECT vid, NULL::VARCHAR AS mmsi, time, lon, lat, speed_kn AS speed, NULL::DOUBLE AS speed_span_s,
         CAST(heading AS DOUBLE) AS heading,
         'gps' AS provider, NULL::INTEGER AS imo, NULL::DOUBLE AS cog, NULL::VARCHAR AS stream, NULL::VARCHAR AS io,
         speed_kn_raw AS speed_raw,
         'reconstructed' AS pos_basis,
         CASE WHEN speed_kn IS NULL AND speed_kn_raw IS NOT NULL THEN 'placeholder' ELSE 'recorded' END AS speed_basis,
         dt_sec, sid_gps, n_sid_gps
  FROM g2)", MS_TO_KN, LOGGER_PLACEHOLDER_MS, MS_TO_KN, g)))
}

# bind -------------------------------------------------------------------------
# Union the four MEASURED position sources; `provider` traces each ping back to
# its origin, which matters for coverage gap analysis. Then the gps feed. Every ping says
# where its position and its speed came from (pos_basis, speed_basis): stk, astdB and gps carry
# the source's own measured speed (astdB's is the feed's field, beside its cog and heading; plan
# 059 step 4); astd and emodnet derive it within the feed, from the previous report to the next, with
# the seconds it spans in `speed_span_s` (plan 059 step 7; NA for a recorded speed). `speed` is NA where a value is
# no vessel speed (outside 0-40 kn) or the logger placeholder; `speed_raw` keeps the value as given.
SPEED_MAX <- 40
ais_all <- function(YR) {
  union_all(stk_fixes(YR) |> select(-mid, -recdate) |> mutate(provider = "stk"),
            astd_src(YR) |> mutate(provider = "astd")) |>
    union_all(astdB_src(YR) |> mutate(provider = "astdB")) |>
    union_all(emn |> mutate(provider = "emodnet"))
}
d_for <- function(YR) {
  # a row equal in every column to another is one ping: a report delivered twice (5,827 astd copies in 2013-2019,
  # decision 271). Until plan 060 SQL UNION did this silently; now it is explicit and counted (ping_union_copies).
  ais <- ais_all(YR) |>
    distinct() |>
    mutate(speed_raw = speed, pos_basis = "recorded",
           speed_basis = if_else(provider %in% c("stk", "astdB"), "recorded", "derived"),
           dt_sec = NA_real_, sid_gps = NA_real_, n_sid_gps = NA_integer_)
  g <- gps_src(YR)
  d <- if (is.null(g)) ais else union_all(ais, g)
  # a heading or course of a full turn or more, or below 0, is a code for "not available", NA for every provider (plan
  # 048 ask c): astdB's 511 and 360, EMODnet's -1 and 360 or more, STK's (already NA in stk_trail()), the logger's 360
  # and more. The sources keep them.
  d |> mutate(speed = if_else(speed >= 0 & speed <= SPEED_MAX, speed, NA_real_),
              heading = if_else(heading >= 0 & heading < 360, heading, NA_real_),
              cog = if_else(cog >= 0 & cog < 360, cog, NA_real_))
}

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
# From 2007 to the newest year a feed holds (decision 181): a ping whose time is later (2106 ...) is left out, and a
# new year comes in with its first partition, where the fixed 2007:2026 that stood here would have dropped it.
partition_years <- function(dir) as.integer(sub("year=", "", list.files(dir, pattern = "^year=")))
years <- 2007:max(partition_years(fd_raw("oracle", "stk", "trail")), partition_years(fd_staging("ais", "astd")),
                  partition_years(fd_staging("ais", "astdB")), partition_years(fd_curated("logbook", "sensor_gps")))
unlink(fd_staging("ais", "stk_receipt"), recursive = TRUE)
copies <- vector("list", length(years))
for(y in 1:length(years)) {
  YR <- years[y]
  print(YR)
  n_in <- ais_all(YR) |> filter(year(time) == YR) |> count(provider, name = "rows_in") |> collect()
  d_for(YR) |>
    mutate(year = year(time)) |>
    filter(year == YR) |>
    arrange(vid, time) |>
    # duckdbfs::write_dataset keeps TIMESTAMP as-is; arrow::write_dataset
    # materialises through R POSIXct and re-writes as TIMESTAMPTZ.
    duckdbfs::write_dataset(fd_staging("ais", "ping_union"), partitioning = "year", format = "parquet")
  n_out <- open_dataset(file.path(fd_staging("ais", "ping_union"), paste0("year=", YR))) |>
    filter(provider != "gps") |> count(provider, name = "rows_out") |> collect()
  copies[[y]] <- full_join(n_in, n_out, by = "provider") |>
    mutate(year = YR, across(c(rows_in, rows_out), \(v) coalesce(as.numeric(v), 0)), copies = rows_in - rows_out)
  message(YR, ": copies dropped ", paste(sprintf("%s %s", copies[[y]]$provider, format(copies[[y]]$copies, big.mark = ",")),
                                          collapse = ", "))
  # STK's receipt of each ping of its VMS stream (plan 060 §2): the unit and the earliest receipt
  stk_src(YR) |>
    filter(year(time) == YR, is.na(io), !is.na(lon), !is.na(lat), STK_VMS_GRID) |>
    group_by(vid, time, lon, lat) |>
    summarise(mid = min(mid), n_mid = n_distinct(mid), recdate = min(recdate), n_rec = n(), .groups = "drop") |>
    mutate(year = YR) |>
    duckdbfs::write_dataset(fd_staging("ais", "stk_receipt"), partitioning = "year", format = "parquet")
}
copies <- bind_rows(copies) |> select(year, provider, rows_in, rows_out, copies) |> arrange(year, provider)
stopifnot("no row gained by the de-duplication" = all(copies$copies >= 0))
write_parquet_group(copies, fd_staging("ais", "ping_union_copies.parquet"))

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
