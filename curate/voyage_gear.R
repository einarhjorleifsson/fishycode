# voyage_gear.R — the gear each AIS voyage fished with, for the fixes no logbook window holds.
# Side: flow, step 3. See plan 013 item 3.
#
# Input:  curated/ais/voyage.parquet             (vid, year, voyage_id, T1, T2)
#         curated/link/trip_voyage.parquet       (.tid, schema, vid, year, voyage_id: the voyage a logbook trip is on)
#         curated/logbook/station.parquet        (.sid, .tid, schema, twin)
#         curated/logbook/fishing_sample.parquet (.sid, schema, t1..t4: the station's own times)
#         curated/logbook/trip.parquet           (.tid, schema, vid)
#         curated/logbook/gear.parquet           (.sid, schema, gid_used: logbook_gear.R)
#         curated/landing/landings.parquet       (.lid, schema, vid, date)
#         curated/landing/catch.parquet          (.lid, schema, gid, catch: agf in the new gear code, lods in the old)
#         curated/reference/gear.parquet         (old gid -> map, the new gid)
#         curated/reference/gear_window.parquet  (gid, gear_class, s1, s2)
# Output: curated/ais/voyage_gear.parquet        one row per voyage
#
# The gear's speed range lets the track decide whether a fix is fishing where no logbook window holds it:
# ramb::rb_add_fishing(method = c("window", "speed")) in R/trail_sql.R (plan 013 item 3). A voyage takes
#   logbook    the gears of the logbook stations on the voyage, when they share one speed range (the gid used most is
#              named). A station is on every voyage one of its own times of day (t1-t4, not 00:00) lies in; a station
#              with no time of day, or whose times lie in no voyage, is on its trip's voyage (trip_voyage). Taking the
#              trip's voyage for every station put 5.5 % of timed stations on a voyage other than the one they were
#              fished in, since a logbook trip often spans several voyages (2026-10-20,
#              $FISHYDATA/archive/2026-10-voyage-gear/);
#   ambiguous  its stations use gears with different speed ranges: no range, so only the windows decide;
#   landing    no logbook trip, but a landing of the vessel dated within the voyage (to the day after it ends), not
#              on a day the vessel was at sea all day; or, for a voyage with none, the landings dated within
#              LANDING_AFTER_D days of its end whose last voyage ended by the end of their day is this one, even
#              when the vessel has left again (plan 034 §7 e: a freezer trawler lands after it sails again). The gear
#              that holds most of the landed weight; landing_gap_d is the days from the voyage's end date to the
#              first of those landings, empty for a landing within the voyage;
#   none       neither.
# Duplicate twin stations (decision 094) and stations deleted in the source (`eytt_deleted`) are left out, as in
# station_window.R. A landing gid of lods is mapped to the new code first, as in
# curate/corrections/logbook_gear.R.

library(DBI)
con <- dbConnect(duckdb::duckdb())
f <- function(...) shQuote(fd_curated(...), type = "sh")
LANDING_AFTER_D <- 7L   # plan 034 §7 e: 2,476 voyages with no gear gain one (§3.4)

dbExecute(con, sprintf("CREATE TEMP TABLE old_new AS
  SELECT CAST(gid AS INTEGER) AS gid_old, CAST(any_value(map) AS INTEGER) AS gid_new
  FROM read_parquet(%s) WHERE version = 'old' AND map IS NOT NULL GROUP BY gid", f("reference", "gear.parquet")))

# Each station's voyages, as temp tables one step at a time: as one query DuckDB's plan spilled over 100 GB.
dbExecute(con, sprintf("CREATE TEMP TABLE v AS SELECT vid, year, voyage_id, T1, T2 FROM read_parquet(%s)", f("ais", "voyage.parquet")))
dbExecute(con, sprintf("CREATE TEMP TABLE tvid AS SELECT \".tid\" AS tid, schema, any_value(vid) AS vid FROM read_parquet(%s)
  WHERE vid IS NOT NULL GROUP BY 1, 2 HAVING count(DISTINCT vid) = 1", f("logbook", "trip.parquet")))
dbExecute(con, sprintf("CREATE TEMP TABLE st AS
  SELECT s.\".sid\" AS sid, s.schema, s.\".tid\" AS tid, tvid.vid, CAST(g.gid_used AS INTEGER) AS gid, fs.t1, fs.t2, fs.t3, fs.t4
  FROM read_parquet(%s) s
  JOIN read_parquet(%s) g ON g.\".sid\" = s.\".sid\" AND g.schema = s.schema
  JOIN read_parquet(%s) fs ON fs.\".sid\" = s.\".sid\" AND fs.schema = s.schema
  JOIN tvid ON tvid.tid = s.\".tid\" AND tvid.schema = s.schema
  WHERE s.twin IS DISTINCT FROM 'duplicate' AND NOT coalesce(fs.eytt_deleted, false) AND g.gid_used IS NOT NULL",
  f("logbook", "station.parquet"), f("logbook", "gear.parquet"), f("logbook", "fishing_sample.parquet")))
# a vessel's voyages do not overlap: an event is in the last voyage to start by its time, if that has not ended
dbExecute(con, "CREATE TEMP TABLE evt AS
  WITH ev AS (SELECT * FROM (SELECT sid, schema, vid, unnest([t1, t2, t3, t4]) AS ts FROM st)
              WHERE ts IS NOT NULL AND CAST(ts AS TIME) <> TIME '00:00:00')
  SELECT DISTINCT ev.sid, ev.schema, v.vid, v.year, v.voyage_id FROM ev ASOF JOIN v ON ev.vid = v.vid AND ev.ts >= v.T1
  WHERE ev.ts <= v.T2")
dbExecute(con, sprintf("CREATE TEMP TABLE lbs AS
  SELECT e.vid, e.year, e.voyage_id, st.gid FROM evt e JOIN st USING (sid, schema)
  UNION ALL
  SELECT tv.vid, tv.year, tv.voyage_id, st.gid FROM st
  JOIN read_parquet(%s) tv ON tv.\".tid\" = st.tid AND tv.schema = st.schema
  ANTI JOIN evt e ON e.sid = st.sid AND e.schema = st.schema", f("link", "trip_voyage.parquet")))

sql <- sprintf("
  WITH w AS (SELECT CAST(gid AS INTEGER) AS gid, gear_class, s1, s2 FROM read_parquet(%s)),
  lbg AS (SELECT l.vid, l.year, l.voyage_id, l.gid, count(*) AS n, any_value(w.gear_class) AS gear_class,
                 any_value(w.s1) AS s1, any_value(w.s2) AS s2,
                 coalesce(CAST(any_value(w.s1) AS VARCHAR), 'NA') || '|' || coalesce(CAST(any_value(w.s2) AS VARCHAR), 'NA') AS rng
          FROM lbs l LEFT JOIN w ON w.gid = l.gid GROUP BY l.vid, l.year, l.voyage_id, l.gid),
  lbv AS (SELECT vid, year, voyage_id, arg_max(gid, n) AS gid, arg_max(gear_class, n) AS gear_class,
                 arg_max(s1, n) AS s1, arg_max(s2, n) AS s2, count(DISTINCT rng) AS n_rng
          FROM lbg GROUP BY vid, year, voyage_id),
  lw AS (SELECT l.vid, l.date, CASE WHEN c.schema = 'lods' THEN o.gid_new ELSE CAST(c.gid AS INTEGER) END AS gid,
                sum(c.catch) AS kg
         FROM read_parquet(%s) l JOIN read_parquet(%s) c ON c.\".lid\" = l.\".lid\" AND c.schema = l.schema
         LEFT JOIN old_new o ON o.gid_old = CAST(c.gid AS INTEGER)
         GROUP BY ALL),
  lvw AS (SELECT v.vid, v.year, v.voyage_id, lw.gid, sum(lw.kg) AS kg
          FROM v JOIN lw ON lw.vid = v.vid AND lw.date BETWEEN CAST(v.T1 AS DATE) AND CAST(v.T2 AS DATE) + 1
           AND NOT (lw.date > CAST(v.T1 AS DATE) AND lw.date < CAST(v.T2 AS DATE))
          WHERE lw.gid IS NOT NULL GROUP BY ALL),
  ld AS (SELECT DISTINCT vid, date FROM lw WHERE gid IS NOT NULL),
  lp AS (SELECT ld.vid, ld.date, v.year, v.voyage_id, date_diff('day', CAST(v.T2 AS DATE), ld.date) AS gap
         FROM ld ASOF JOIN v ON ld.vid = v.vid AND CAST(ld.date AS TIMESTAMP) + INTERVAL 1 DAY > v.T2),
  lva AS (SELECT lp.vid, lp.year, lp.voyage_id, lw.gid, sum(lw.kg) AS kg, min(lp.gap) AS gap
          FROM lp JOIN lw ON lw.vid = lp.vid AND lw.date = lp.date
          WHERE lp.gap <= %d AND lw.gid IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM lvw WHERE lvw.vid = lp.vid AND lvw.year = lp.year AND lvw.voyage_id = lp.voyage_id)
          GROUP BY ALL),
  lvg AS (SELECT vid, year, voyage_id, gid, kg, CAST(NULL AS BIGINT) AS gap FROM lvw
          UNION ALL SELECT vid, year, voyage_id, gid, kg, gap FROM lva),
  lvm AS (SELECT vid, year, voyage_id, arg_max(gid, kg) AS gid, min(gap) AS gap FROM lvg GROUP BY vid, year, voyage_id)
  SELECT v.vid, v.year, v.voyage_id,
         CASE WHEN lbv.vid IS NOT NULL THEN lbv.gid ELSE lvm.gid END AS gid_voyage,
         CASE WHEN lbv.vid IS NOT NULL AND lbv.n_rng = 1 THEN lbv.gear_class
              WHEN lbv.vid IS NULL THEN wl.gear_class END AS gear_class_voyage,
         CASE WHEN lbv.vid IS NOT NULL AND lbv.n_rng = 1 THEN lbv.s1 WHEN lbv.vid IS NULL THEN wl.s1 END AS s1_voyage,
         CASE WHEN lbv.vid IS NOT NULL AND lbv.n_rng = 1 THEN lbv.s2 WHEN lbv.vid IS NULL THEN wl.s2 END AS s2_voyage,
         CASE WHEN lbv.vid IS NOT NULL AND lbv.n_rng = 1 THEN 'logbook'
              WHEN lbv.vid IS NOT NULL THEN 'ambiguous'
              WHEN lvm.vid IS NOT NULL THEN 'landing' ELSE 'none' END AS gear_voyage_basis,
         CASE WHEN lbv.vid IS NULL THEN lvm.gap END AS landing_gap_d
  FROM v LEFT JOIN lbv USING (vid, year, voyage_id) LEFT JOIN lvm USING (vid, year, voyage_id)
         LEFT JOIN w wl ON wl.gid = lvm.gid",
  f("reference", "gear_window.parquet"), f("landing", "landings.parquet"), f("landing", "catch.parquet"), LANDING_AFTER_D)

write_curated_sql(con, sql, fd_curated("ais", "voyage_gear.parquet"),
                  inputs = c(fd_curated("ais", "voyage.parquet"), fd_curated("link", "trip_voyage.parquet"),
                             fd_curated("logbook", "station.parquet"), fd_curated("logbook", "gear.parquet"),
                             fd_curated("logbook", "fishing_sample.parquet"), fd_curated("logbook", "trip.parquet"),
                             fd_curated("landing", "landings.parquet"), fd_curated("landing", "catch.parquet"),
                             fd_curated("reference", "gear.parquet"), fd_curated("reference", "gear_window.parquet")),
                  order_by = "vid, year, voyage_id")
dbDisconnect(con, shutdown = TRUE)
