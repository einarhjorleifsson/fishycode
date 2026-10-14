# link_station_event.R — the fix that bounds each recorded event time of a logbook station.
# Side: flow, step 2. See plan 013 (phase 4: reconcile declared times with the track) and decision 088.
#
# Input:  curated/ais/ping/year=*                  the fixes (vid, time)
#         curated/logbook/station_window.parquet   t1-t4 per station as the windows read them (adb's towed start
#                                                  and end already moved to t2/t3)
#         curated/logbook/fishing_sample.parquet   afli's .t3_source: a tow end computed from the towing time
# Output: curated/link/station_event.parquet       one row per (station, event time present)
#
#   the event   .sid schema vid event event_time event_basis event_flag
#   the fix     time dt_s gap_s ping_lost   (ramb::rb_link_record_events())
#
# The rule (maintainer, 2026-10-14): a start takes the next fix, an end the previous, so the fixes from the t1 fix
# to the t2 fix are the setting, from the t3 fix to the t4 fix the hauling, and a tow (towed gear records t2 and
# t3 only) is the fixes strictly between its t2 fix and its t3 fix. The nearest fix, the first rule, was the one
# before the event half the time (decision 088).
# event_basis: "recorded", or "derived" for afli's tow end (t2 plus the towing time). Both are matched alike
# (maintainer, 2026-10-14). event_flag: "suspect_clock" for a clock value far commoner than its neighbours, which
# reads as "time unknown" (decision 088): afli set starts (t1) at 23:59, fs_afladagbok tow starts (t2) at 00:00.
# The fix is still matched (maintainer). MAX_DT_S: farther than this, a fix says nothing about the event, and
# `time` and `dt_s` are NA; `gap_s` stays.
#
# One fix, one record (maintainer, decision 090; built in decision 091): a fix bounds the events of at most one
# station, and of one phase of it (setting t1-t2 or hauling t3-t4). When two would share it, the event nearer in
# time keeps it, then the earlier event time, then the lower (.sid, schema); the others have `ping_lost` TRUE and
# no fix. Twins (TODO 58) are broken the same way until the maintainer decides which keeps the link.
#
# Year by year, so DuckDB's two ASOF joins see one year of fixes and events at a time, plus a month of fixes
# either side. Each event is linked in the year of its own time. The events within a day of the year go in too,
# because the one-fix rule must see every event that wants a fix: two such events are at most 2 x MAX_DT_S apart.

library(DBI)
library(duckdb)

MAX_DT_S <- 3600
stopifnot(2 * MAX_DT_S < 86400)  # the day of margin around each year

con <- dbConnect(duckdb())
spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
dbExecute(con, sprintf("SET temp_directory = '%s'", spill))

pt  <- file.path(fd_curated("ais", "ping"), "year=*", "*.parquet")
swf <- fd_curated("logbook", "station_window.parquet")
fsf <- fd_curated("logbook", "fishing_sample.parquet")

dbExecute(con, sprintf("
  CREATE TABLE rec AS
  SELECT DISTINCT \".sid\", schema, vid, t1, t2, t3, t4 FROM read_parquet('%s') WHERE vid IS NOT NULL", swf))
dbExecute(con, sprintf("
  CREATE TABLE src AS SELECT \".sid\", schema, \".t3_source\" AS t3_source FROM read_parquet('%s')", fsf))
stopifnot(dbGetQuery(con, "SELECT count(*) - count(DISTINCT (\".sid\", schema)) AS n FROM rec")$n == 0)

years <- dbGetQuery(con, "
  SELECT DISTINCT year(t) AS y FROM (UNPIVOT rec ON t1, t2, t3, t4 INTO NAME e VALUE t) ORDER BY 1")$y

dbExecute(con, "CREATE TABLE ev (\".sid\" DOUBLE, schema VARCHAR, vid INTEGER, event VARCHAR, event_time TIMESTAMP,
                                 time TIMESTAMP, dt_s DOUBLE, gap_s DOUBLE, ping_lost BOOLEAN)")
for (y in years) {
  t0 <- sprintf("TIMESTAMP '%d-01-01'", y); t1 <- sprintf("TIMESTAMP '%d-01-01'", y + 1L)
  m0 <- sprintf("%s - INTERVAL 1 DAY", t0); m1 <- sprintf("%s + INTERVAL 1 DAY", t1)
  inside <- function(v) sprintf("(%1$s >= %2$s AND %1$s < %3$s)", v, m0, m1)
  keep <- function(v) sprintf("CASE WHEN %s THEN %s END AS %s", inside(v), v, v)
  tt <- c("t1", "t2", "t3", "t4")
  # the stations with an event time in the year or the day either side, and only those event times
  r <- dplyr::tbl(con, dplyr::sql(sprintf("SELECT \".sid\", schema, vid, %s FROM rec WHERE %s",
                                          paste(keep(tt), collapse = ", "), paste(inside(tt), collapse = " OR "))))
  p <- dplyr::tbl(con, dplyr::sql(sprintf(
    "SELECT vid, time FROM read_parquet('%s', hive_partitioning = false)
     WHERE time >= %s - INTERVAL 31 DAY AND time < %s + INTERVAL 31 DAY", pt, t0, t1)))
  e <- ramb::rb_link_record_events(p, r, key = c(".sid", "schema"), max_dt_s = MAX_DT_S)
  dbExecute(con, sprintf("INSERT INTO ev BY NAME SELECT * FROM (%s) WHERE event_time >= %s AND event_time < %s",
                         dbplyr::sql_render(e), t0, t1))
}

out_sql <- "
  SELECT e.\".sid\", e.schema, e.vid, e.event, e.event_time,
         CASE WHEN e.schema = 'afli' AND e.event = 't3' AND s.t3_source = 'derived' THEN 'derived'
              ELSE 'recorded' END AS event_basis,
         CASE WHEN e.schema = 'afli' AND e.event = 't1' AND strftime(e.event_time, '%H:%M') = '23:59' THEN 'suspect_clock'
              WHEN e.schema = 'fs_afladagbok' AND e.event = 't2' AND e.event_time::TIME = TIME '00:00:00' THEN 'suspect_clock'
         END AS event_flag,
         e.time, e.dt_s, e.gap_s, e.ping_lost
  FROM ev e LEFT JOIN src s ON s.\".sid\" = e.\".sid\" AND s.schema = e.schema"

# every event time of every station is in the table once
n_in <- dbGetQuery(con, "SELECT count(*) AS n FROM (UNPIVOT rec ON t1, t2, t3, t4 INTO NAME e VALUE t)")$n
n_ev <- dbGetQuery(con, "SELECT count(*) AS n FROM ev")$n
if (n_in != n_ev) stop("station_event: ", n_ev, " rows for ", n_in, " event times")
# one fix, one station and phase
n_shared <- dbGetQuery(con, "
  SELECT count(*) AS n FROM (SELECT vid, time FROM ev WHERE time IS NOT NULL GROUP BY vid, time
    HAVING count(DISTINCT (\".sid\", schema, event IN ('t1', 't2'))) > 1)")$n
if (n_shared > 0) stop("station_event: ", n_shared, " fixes bound events of two stations or phases")

write_curated_sql(con, out_sql, fd_curated("link", "station_event.parquet"),
                  inputs = c(swf, fsf), order_by = "vid, event_time, event")

# Report ----------------------------------------------------------------------------
q <- function(s) print(dbGetQuery(con, s))
message("\nstation_event: rows, a fix within MAX_DT_S, and |dt| and the gap (median, 90 %), by schema and event")
q("SELECT schema, event, count(*) AS n, count(time) AS n_fix,
          round(median(abs(dt_s))) AS med_dt, round(quantile_cont(abs(dt_s), 0.9)) AS q90_dt,
          round(median(gap_s)) AS med_gap, round(quantile_cont(gap_s, 0.9)) AS q90_gap
   FROM ev GROUP BY ALL ORDER BY 1, 2")
message("\nevent times whose fix went to a nearer event of another station or phase, by schema and event")
q("SELECT schema, event, count(*) AS n, sum(ping_lost::INT) AS n_lost,
          round(100.0 * sum(ping_lost::INT) / count(*), 2) AS pct_lost, round(median(gap_s) FILTER (WHERE ping_lost)) AS med_gap_lost
   FROM ev GROUP BY ALL ORDER BY 1, 2")
message("\nphases with no fix inside: the start's fix comes after the end's (setting t1-t2, hauling t3-t4)")
q("SELECT a.event || '-' || b.event AS phase, count(*) AS n_both_fixed, sum((a.time > b.time)::INT) AS n_crossed
   FROM ev a JOIN ev b ON a.\".sid\" = b.\".sid\" AND a.schema = b.schema
    AND ((a.event = 't1' AND b.event = 't2') OR (a.event = 't3' AND b.event = 't4'))
   WHERE a.time IS NOT NULL AND b.time IS NOT NULL GROUP BY 1 ORDER BY 1")
dbDisconnect(con, shutdown = TRUE)
