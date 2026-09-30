# station_window.R — when is the vessel busy with each logbook station?
#
# Input:  curated/logbook/fishing_sample.parquet  (.sid, .tid, schema, gear, gid, t1..t4, duration_m)
#         curated/logbook/trip.parquet            (.tid, schema, vid)
#         curated/logbook/station.parquet         (.sid, schema, date)
#         curated/reference/gear_window.parquet   (gear_class, s1, s2, set_max_min)
# Output: curated/logbook/station_window.parquet
#
# One row per (station, phase). A station is not one interval: a trawl has one
# (tow), a net or longline has two short ones (set, haul) with the soak between
# them NOT a window, a jigger has one long one (jig), and a station with no usable
# times gets the station date (day). The class and its rule come from
# reference/gear/windows.R; plan 010 §2 has the reasoning and the measurements.
#
# KEYS. `.sid` and `.tid` are unique only WITHIN a schema: afli and fs_afladagbok
# number their stations and trips independently, so 15,184 station ids and 6,565
# trip ids occur in both. Everything here joins on (id, schema); a downstream table
# that joins on `.sid` alone will attach one schema's pings to the other's station.
#
# Every row also lists the events its STATION recorded (`events`, `n_events`), so a
# longline's set start (t1), haul start (t3) and haul end (t4) stay visible beside
# whichever window was drawn from them.
#
# win_basis says where the interval came from and is never dropped:
#   recorded     both ends are logbook times
#   derived      one end is a logbook time, the other comes from duration_m
#   synthesised  an end is an assumption: the typical haul length (per gear, median
#                of recorded t4 - t3), the set length (gear_window.set_max_min), or
#                the whole station date
#   capped       a recorded end passed the vessel's next recorded event and was cut
#                back to it (the raw times are kept beside the window, unchanged)
# A day window must never be treated as evidence of where the vessel was: the join
# in plan 010 §3 lets it claim only pings that no recorded window claims.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
lb <- function(f) fd_curated("logbook", f)

dbExecute(con, sprintf("CREATE VIEW fs   AS SELECT * FROM read_parquet('%s')", lb("fishing_sample.parquet")))
dbExecute(con, sprintf("CREATE VIEW trip AS SELECT * FROM read_parquet('%s')", lb("trip.parquet")))
dbExecute(con, sprintf("CREATE VIEW st   AS SELECT * FROM read_parquet('%s')", lb("station.parquet")))
dbExecute(con, sprintf("CREATE VIEW gw   AS SELECT * FROM read_parquet('%s')",
                       fd_curated("reference", "gear_window.parquet")))

# Base: one row per usable station --------------------------------------------

# A trip id that still maps to two vessels inside one schema cannot place its
# stations; they are left out and counted rather than guessed.
dbExecute(con, "
CREATE TABLE trip_vid AS
SELECT \".tid\" AS tid, schema, any_value(vid) AS vid
FROM trip WHERE vid IS NOT NULL
GROUP BY 1, 2 HAVING count(DISTINCT vid) = 1")

dbExecute(con, "
CREATE TABLE base AS
SELECT f.\".sid\" AS sid, f.schema, f.\".tid\" AS tid, tv.vid, f.gear,
       CAST(f.gid AS INTEGER) AS gid, g.gear_class, g.s1, g.s2, g.set_max_min,
       f.t1, f.t2, f.t3, f.t4, f.duration_m,
       date_trunc('day', st.date) AS d
FROM fs f
JOIN trip_vid tv ON tv.tid = f.\".tid\" AND tv.schema = f.schema
JOIN st          ON st.\".sid\" = f.\".sid\" AND st.schema = f.schema
JOIN gw g        ON g.gid = CAST(f.gid AS INTEGER)
WHERE NOT coalesce(f.eytt_deleted, false) AND g.gear IS NOT NULL")

# The typical haul stands in where only t4 is recorded. It is measured from the
# recorded hauls themselves and kept only where there are enough of them.
dbExecute(con, "
CREATE TABLE typ_haul AS
SELECT gear, median(epoch(t4 - t3) / 60.0) AS haul_min, count(*) AS n
FROM base WHERE gear_class = 'static' AND t3 IS NOT NULL AND t4 > t3
GROUP BY gear HAVING count(*) >= 50")

# A record whose t1, t3 and t4 are the same minute (duration 0) is a stamp, not a
# haul: it gets the typical haul ending at t4, unclamped by t1.
# Windows before capping --------------------------------------------------------

mins <- function(x) sprintf("to_minutes(CAST(round(%s) AS BIGINT))", x)

dbExecute(con, sprintf("
CREATE TABLE win0 AS
WITH b AS (SELECT base.*, th.haul_min FROM base LEFT JOIN typ_haul th USING (gear)),
tow AS (
  SELECT *, 'tow' AS phase,
    CASE WHEN t2 IS NOT NULL AND t3 > t2 THEN t2
         WHEN t2 IS NOT NULL AND duration_m > 0 THEN t2 END AS w_start,
    CASE WHEN t2 IS NOT NULL AND t3 > t2 THEN t3
         WHEN t2 IS NOT NULL AND duration_m > 0 THEN t2 + %s END AS w_end,
    CASE WHEN t2 IS NOT NULL AND t3 > t2 THEN 'recorded'
         WHEN t2 IS NOT NULL AND duration_m > 0 THEN 'derived' END AS win_basis
  FROM b WHERE gear_class = 'towed'),
haul AS (
  SELECT *, 'haul' AS phase,
    CASE WHEN t3 IS NOT NULL AND t4 > t3 THEN t3
         WHEN t4 IS NOT NULL AND t1 < t4 THEN greatest(t4 - %s, t1)
         WHEN t4 IS NOT NULL THEN t4 - %s
         ELSE t3 END AS w_start,
    CASE WHEN t3 IS NOT NULL AND t4 > t3 THEN t4
         WHEN t4 IS NOT NULL THEN t4
         ELSE t3 + %s END AS w_end,
    CASE WHEN t3 IS NOT NULL AND t4 > t3 THEN 'recorded' ELSE 'synthesised' END AS win_basis
  FROM b WHERE gear_class = 'static' AND haul_min IS NOT NULL
           AND (t4 IS NOT NULL OR t3 IS NOT NULL)),
st_set AS (
  SELECT *, 'set' AS phase, t1 AS w_start, t1 + %s AS w_end, 'synthesised' AS win_basis
  FROM b WHERE gear_class = 'static' AND t1 IS NOT NULL AND set_max_min IS NOT NULL),
jig AS (
  SELECT *, 'jig' AS phase,
    CASE WHEN t1 IS NOT NULL AND t4 > t1 THEN t1
         WHEN t4 IS NOT NULL AND duration_m > 0 THEN t4 - %s
         WHEN t1 IS NOT NULL AND duration_m > 0 THEN t1 END AS w_start,
    CASE WHEN t1 IS NOT NULL AND t4 > t1 THEN t4
         WHEN t4 IS NOT NULL AND duration_m > 0 THEN t4
         WHEN t1 IS NOT NULL AND duration_m > 0 THEN t1 + %s END AS w_end,
    CASE WHEN t1 IS NOT NULL AND t4 > t1 THEN 'recorded'
         WHEN duration_m > 0 AND (t1 IS NOT NULL OR t4 IS NOT NULL) THEN 'derived' END AS win_basis
  FROM b WHERE gear_class = 'jigged'),
named AS (
  SELECT * FROM tow  WHERE w_start IS NOT NULL UNION ALL
  SELECT * FROM haul WHERE w_start IS NOT NULL UNION ALL
  SELECT * FROM st_set                          UNION ALL
  SELECT * FROM jig  WHERE w_start IS NOT NULL),
day AS (
  SELECT b.*, 'day' AS phase, b.d AS w_start,
         b.d + INTERVAL 1 DAY - INTERVAL 1 SECOND AS w_end, 'synthesised' AS win_basis
  FROM b WHERE NOT EXISTS (SELECT 1 FROM named n WHERE n.sid = b.sid AND n.schema = b.schema))
SELECT * FROM named UNION ALL SELECT * FROM day",
  mins("duration_m"), mins("haul_min"), mins("haul_min"), mins("haul_min"),
  mins("set_max_min"), mins("duration_m"), mins("duration_m")))

dbExecute(con, "ALTER TABLE win0 ADD COLUMN rid BIGINT")
dbExecute(con, "CREATE SEQUENCE rid_seq")
dbExecute(con, "UPDATE win0 SET rid = nextval('rid_seq')")

# Capping -------------------------------------------------------------------------
# A tow or haul ends at the vessel's next tow or haul that has a RECORDED start:
# two tows cannot be towed at once and hauls cannot overlap (measured: 0.1-0.2 % of
# tows and ~2 % of static hauls do, in the logbook). A set ends at the vessel's next
# recorded event of any kind, which includes its own haul, so two sets never claim a
# ping. Events with a synthesised start are never used as bounds: an assumption must
# not cut a recorded time.
dbExecute(con, "
CREATE TABLE ev_work AS
SELECT DISTINCT vid, w_start FROM win0
WHERE phase IN ('tow', 'haul', 'jig') AND win_basis = 'recorded'")
dbExecute(con, "
CREATE TABLE ev_all AS
SELECT vid, w_start FROM ev_work
UNION
SELECT DISTINCT vid, w_start FROM win0 WHERE phase = 'set'")

dbExecute(con, "
CREATE TABLE nxt AS
SELECT r.rid, w.w_start AS next_work, a.w_start AS next_any
FROM win0 r
ASOF LEFT JOIN ev_work w ON r.vid = w.vid AND r.w_start < w.w_start
ASOF LEFT JOIN ev_all  a ON r.vid = a.vid AND r.w_start < a.w_start
WHERE r.phase <> 'day'")

dbExecute(con, "
CREATE TABLE station_window AS
SELECT r.sid AS \".sid\", r.schema, r.tid AS \".tid\", r.vid, r.gear, r.gid, r.gear_class, r.phase,
  r.w_start,
  CASE WHEN r.phase IN ('tow', 'haul') AND n.next_work < r.w_end THEN n.next_work
       WHEN r.phase = 'set' AND n.next_any < r.w_end THEN n.next_any
       ELSE r.w_end END AS w_end,
  CASE WHEN r.phase IN ('tow', 'haul') AND n.next_work < r.w_end THEN 'capped'
       ELSE r.win_basis END AS win_basis,
  CASE WHEN r.phase = 'set' AND n.next_any < r.w_end THEN 'next_event'
       WHEN r.phase = 'set' THEN 'max'
       WHEN r.phase IN ('tow', 'haul') AND n.next_work < r.w_end THEN 'next_event' END AS win_closed_by,
  r.t1, r.t2, r.t3, r.t4, r.duration_m, r.s1, r.s2,
  -- Which logbook events this STATION recorded, on every one of its rows. A longline
  -- has three (t1 set starts, t3 haul starts, t4 haul ends); most have one or two,
  -- and the window of the missing event is an estimate (win_basis says so).
  (CASE WHEN r.t1 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN r.t2 IS NOT NULL THEN 1 ELSE 0 END
   + CASE WHEN r.t3 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN r.t4 IS NOT NULL THEN 1 ELSE 0 END)::TINYINT AS n_events,
  concat_ws('+', CASE WHEN r.t1 IS NOT NULL THEN 't1' END, CASE WHEN r.t2 IS NOT NULL THEN 't2' END,
            CASE WHEN r.t3 IS NOT NULL THEN 't3' END, CASE WHEN r.t4 IS NOT NULL THEN 't4' END) AS events
FROM win0 r LEFT JOIN nxt n USING (rid)
ORDER BY r.vid, r.w_start")

# Report ----------------------------------------------------------------------------

q <- function(s) dbGetQuery(con, s)
message("\nstation_window: rows by class, phase and basis")
print(q("SELECT gear_class, phase, win_basis, count(*) n,
                round(median(epoch(w_end - w_start) / 60), 0) AS med_min
         FROM station_window GROUP BY ALL ORDER BY 1, 2, 3"))

message("\nstations left out, by reason")
print(q("
  SELECT 'no unambiguous vessel for the trip' AS reason, count(*) AS n FROM fs f
   WHERE NOT coalesce(f.eytt_deleted, false)
     AND NOT EXISTS (SELECT 1 FROM trip_vid tv WHERE tv.tid = f.\".tid\" AND tv.schema = f.schema)
  UNION ALL
  SELECT 'gear with no code (farm cage, mussel line)', count(*) FROM fs f
   JOIN gw g ON g.gid = CAST(f.gid AS INTEGER)
   WHERE NOT coalesce(f.eytt_deleted, false) AND g.gear IS NULL"))

bad <- q("SELECT count(*) n FROM station_window WHERE NOT (w_end > w_start)")$n
if (bad > 0) stop("station_window: ", bad, " windows with w_end <= w_start")
lost <- q("SELECT count(*) n FROM base b WHERE NOT EXISTS (
            SELECT 1 FROM station_window w WHERE w.\".sid\" = b.sid AND w.schema = b.schema)")$n
if (lost > 0) stop("station_window: ", lost, " stations produced no window")
dup <- q("SELECT count(*) n FROM (SELECT \".sid\", schema, phase FROM station_window
          GROUP BY ALL HAVING count(*) > 1)")$n
if (dup > 0) stop("station_window: ", dup, " (station, phase) pairs are not unique")

out <- dbGetQuery(con, "SELECT * FROM station_window")
out |> write_curated(lb("station_window.parquet"),
                     inputs = c(lb("fishing_sample.parquet"), lb("trip.parquet"),
                                lb("station.parquet"),
                                fd_curated("reference", "gear_window.parquet")))
dbDisconnect(con, shutdown = TRUE)
