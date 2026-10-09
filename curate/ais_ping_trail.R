# ais_ping_trail.R — the cleaned AIS pings and the GPS logger fixes, as one track.
# Side: flow, step 0 (gps joins the union in plan 014 phase 3; this script then goes). See plan 014.
#
# Input:  curated/ais/ping/year=*           (cleaned AIS with voyage number; ais_trip.R)
#         curated/logbook/sensor_gps/year=* (logger fixes, lon/lat interpolated; logbook_sensor_gps.R)
# Output: curated/ais/ping_trail/year=*/part_001.parquet
#
# WHERE THIS SITS. The logger fixes are built downstream of the AIS chain on purpose
# (decision 000): their positions are interpolated from the cleaned AIS track, so
# putting them back inside ais_ping_union recreated a cycle in which the union held
# 26.9 M positions interpolated from itself. They join the track HERE, directly after
# the interpolation, and nothing upstream ever sees them. Plan 010 §5.
#
# UNIQUE ON (vid, time). Downstream analyses use the interval between consecutive
# fixes (speed = distance / duration) and a zero interval breaks them. So:
#   AIS   one row per (vid, time); on a tie stk beats the commercial feeds.
#         (101 ties in 2019, 9,806 in 2023; 0.03 %.) Done here and not in
#         ais_ping_clean so the 50 GB cleaning chain is not rerun for it.
#   gps   gps1 and gps2 are the same fixes from two raw tables (sjalfvirkir_maelar and
#         rafr_sjalfvirkir_maelar); collapsed to one row with speed = whichever has a real one
#         (a 1.000 m/s placeholder in one table yields to the other table's value; they agree only
#         17 % of the time on those rows, so "never disagree" held only for real speeds). A fix stamped to several stations keeps
#         no single station: sid_gps is NA and n_sid_gps counts them - the window join
#         recovers them.
#   tie   a gps fix at exactly an AIS ping's (vid, time) is dropped; AIS stays whole
#         and the logger's speed is kept beside it as speed_gps.
#   Fixes a few seconds apart both stay; provider tells them apart.
# ROW ORDER. Each file is sorted by vid then time, checked on the written file.
#
# THE COLUMNS MIX PROVENANCE, SO EACH SAYS WHAT IT IS.
#   pos_basis    recorded (AIS) | reconstructed (gps: interpolated onto the logger clock;
#                dt_sec is the AIS gap it was interpolated across - the trust gauge)
#   speed        knots, NA where the source value is implausible (< 0 or > SPEED_MAX), and NA for a logger
#                speed of exactly 1.000 m/s, which is a placeholder, not a speed (speed_basis "placeholder").
#   speed_raw    the same value before that test, also knots. AIS carries values up to
#                8.6 million; the logger's raw unit is m/s and is converted here.
#   speed_basis  recorded | derived | placeholder, per provider, from how the feed builds its speed
#                (curate/ais_ping_union.R): stk and gps carry the source's own measured
#                speed; astd, astdB and emodnet have none and derive it from the distance
#                to the next ping over the interval. A derived speed is a chord over the
#                interval and reads low when pings are sparse or the track bends.
# Anything that measures WHERE (distance, implied speed, whack) must not use gps rows:
# their positions come from the same AIS track.
#
# Logger rows with no position (outside any voyage) are left out - this is a position
# table - and counted in the report.

library(DBI)
library(duckdb)

SPEED_MAX <- 40          # knots; above this a value is not a vessel speed
MS_TO_KN  <- 1 / 0.514444
# The logger writes exactly 1.000 m/s where it has no speed (curate/corrections/logger_speed_placeholder.yml).
# Its raw speeds sit on a 0.1 kn grid, which 1.000 m/s is not, so the value is recognisable in every year.
LOGGER_PLACEHOLDER_MS <- 1

con <- dbConnect(duckdb())
# A busy year (50 M rows) sorts past memory and spills; DuckDB does not create its own
# spill directory when the session's tempdir has been cleaned, so give it one.
spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
dbExecute(con, sprintf("SET temp_directory = '%s'", spill))
ais_dir <- fd_curated("ais", "ping")
gps_dir <- fd_curated("logbook", "sensor_gps")
out_dir <- fd_curated("ais", "ping_trail")

years <- sort(as.integer(sub("year=", "", list.files(ais_dir, pattern = "^year="))))
gps_years <- as.integer(sub("year=", "", list.files(gps_dir, pattern = "^year=")))
# Testing hook: define PING_TRAIL_YEARS in the session before source()ing to build a few years.
if (exists("PING_TRAIL_YEARS")) years <- intersect(years, PING_TRAIL_YEARS)
rep <- list()

for (yr in years) {
  a <- file.path(ais_dir, paste0("year=", yr), "*.parquet")
  g <- file.path(gps_dir, paste0("year=", yr), "*.parquet")
  has_gps <- yr %in% gps_years

  gps_ctes <- if (has_gps) sprintf("
  , g0 AS (
    SELECT vid, time, \".sid\" AS sid, lon, lat, dt_sec, trip, heading,
           speed * %f AS speed_kn_raw,
           CASE WHEN abs(speed - %f) < 1e-6 THEN NULL ELSE speed * %f END AS speed_kn
    FROM read_parquet('%s') WHERE lon IS NOT NULL AND lat IS NOT NULL AND vid IS NOT NULL),
  g1 AS (
    SELECT vid, time, sid, any_value(lon) AS lon, any_value(lat) AS lat,
           any_value(dt_sec) AS dt_sec, any_value(trip) AS trip,
           any_value(heading) FILTER (WHERE heading IS NOT NULL) AS heading,
           any_value(speed_kn) FILTER (WHERE speed_kn IS NOT NULL) AS speed_kn,
           any_value(speed_kn_raw) FILTER (WHERE speed_kn IS NOT NULL) AS speed_kn_ok,
           any_value(speed_kn_raw) FILTER (WHERE speed_kn_raw IS NOT NULL) AS speed_kn_raw
    FROM g0 GROUP BY vid, time, sid),
  g2 AS (
    SELECT vid, time, any_value(lon) AS lon, any_value(lat) AS lat, any_value(dt_sec) AS dt_sec,
           any_value(trip) AS trip, any_value(heading) AS heading,
           any_value(speed_kn) FILTER (WHERE speed_kn IS NOT NULL) AS speed_kn,
           -- the raw value that goes with the speed kept; when every table says placeholder, that value itself
           coalesce(any_value(speed_kn_ok) FILTER (WHERE speed_kn_ok IS NOT NULL),
                    any_value(speed_kn_raw) FILTER (WHERE speed_kn_raw IS NOT NULL)) AS speed_kn_raw,
           count(DISTINCT sid) AS n_sid_gps,
           CASE WHEN count(DISTINCT sid) = 1 THEN min(sid) END AS sid_gps
    FROM g1 GROUP BY vid, time)", MS_TO_KN, LOGGER_PLACEHOLDER_MS, MS_TO_KN, g) else "
  , g2 AS (SELECT NULL::INTEGER vid, NULL::TIMESTAMP \"time\", NULL::DOUBLE lon, NULL::DOUBLE lat,
                  NULL::DOUBLE dt_sec, NULL::INTEGER trip, NULL::DOUBLE heading, NULL::DOUBLE speed_kn,
                  NULL::DOUBLE speed_kn_raw,
                  NULL::BIGINT n_sid_gps, NULL::DOUBLE sid_gps WHERE false)"

  sql <- sprintf("
  WITH ais0 AS (SELECT * FROM read_parquet('%s') WHERE vid IS NOT NULL),
  ais1 AS (
    SELECT * EXCLUDE (rk) FROM (
      SELECT *, row_number() OVER (PARTITION BY vid, time
               ORDER BY CASE provider WHEN 'stk' THEN 1 ELSE 2 END, provider, lon, lat) AS rk
      FROM ais0) WHERE rk = 1)
  %s
  SELECT a.vid, a.mmsi, a.time, a.lon, a.lat,
         CASE WHEN a.speed BETWEEN 0 AND %f THEN a.speed END AS speed,
         a.speed AS speed_raw, a.heading, a.cog, a.provider, a.pid, a.stay_pid, a.year, a.trip,
         'recorded' AS pos_basis,
         CASE WHEN a.provider = 'stk' THEN 'recorded' ELSE 'derived' END AS speed_basis,
         g.speed_kn AS speed_gps, CAST(NULL AS DOUBLE) AS dt_sec,
         CAST(NULL AS DOUBLE) AS sid_gps, CAST(NULL AS BIGINT) AS n_sid_gps
  FROM ais1 a LEFT JOIN g2 g ON g.vid = a.vid AND g.time = a.time
  UNION ALL
  SELECT g.vid, CAST(NULL AS VARCHAR), g.time, g.lon, g.lat,
         CASE WHEN g.speed_kn BETWEEN 0 AND %f THEN g.speed_kn END, g.speed_kn_raw,
         g.heading, CAST(NULL AS DOUBLE), 'gps', CAST(NULL AS VARCHAR), CAST(NULL AS VARCHAR), %d, g.trip,
         'reconstructed',
         CASE WHEN g.speed_kn IS NULL AND g.speed_kn_raw IS NOT NULL THEN 'placeholder' ELSE 'recorded' END,
         CAST(NULL AS DOUBLE), g.dt_sec, g.sid_gps, g.n_sid_gps
  FROM g2 g WHERE NOT EXISTS (SELECT 1 FROM ais1 a WHERE a.vid = g.vid AND a.time = g.time)
  ORDER BY vid, time", a, gps_ctes, SPEED_MAX, SPEED_MAX, yr)

  # column types must agree between the two halves of the UNION
  n <- write_curated_sql(con, sql, file.path(out_dir, paste0("year=", yr), "part_001.parquet"),
                         inputs = c(list.files(dirname(a), full.names = TRUE),
                                    if (has_gps) list.files(dirname(g), full.names = TRUE)),
                         order_by = "vid, time")
  r <- dbGetQuery(con, sprintf("
    SELECT count(*) n, sum((provider = 'gps')::int) n_gps,
           sum((speed_gps IS NOT NULL)::int) n_ties, sum((speed IS NULL AND speed_raw IS NOT NULL)::int) speed_dropped,
           sum((speed_basis = 'placeholder')::int) n_placeholder,
           count(*) - count(DISTINCT (vid, time)) dups
    FROM read_parquet('%s')", file.path(out_dir, paste0("year=", yr), "part_001.parquet")))
  message(sprintf("%d: %s rows (%s gps, %s gps speeds on AIS ties), %s speeds set NA (of which %s logger placeholders), %s duplicate (vid,time)",
                  yr, format(r$n, big.mark = ","), format(r$n_gps, big.mark = ","),
                  format(r$n_ties, big.mark = ","), format(r$speed_dropped, big.mark = ","),
                  format(r$n_placeholder, big.mark = ","), r$dups))
  if (r$dups > 0) stop("ais_ping_trail: (vid, time) not unique in ", yr)
  # time must be ordered within a vid in the FILE, not just in the query that made it
  unsorted <- dbGetQuery(con, sprintf("
    SELECT count(*) n FROM (
      SELECT vid, time, lag(vid) OVER w AS pv, lag(time) OVER w AS pt
      FROM read_parquet('%s', file_row_number = true)
      WINDOW w AS (ORDER BY file_row_number)) WHERE pv > vid OR (pv = vid AND pt >= time)",
    file.path(out_dir, paste0("year=", yr), "part_001.parquet")))$n
  if (unsorted > 0) stop("ais_ping_trail: ", unsorted, " rows out of (vid, time) order in ", yr)
  rep[[as.character(yr)]] <- r
}
dbDisconnect(con, shutdown = TRUE)
