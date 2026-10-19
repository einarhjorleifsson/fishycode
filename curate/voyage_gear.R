# voyage_gear.R — the gear each AIS voyage fished with, for the fixes no logbook window holds.
# Side: flow, step 3. See plan 013 item 3.
#
# Input:  curated/ais/voyage.parquet             (vid, year, voyage, T1, T2)
#         curated/link/trip_voyage.parquet       (.tid, schema, vid, year, voyage: the voyage a logbook trip is on)
#         curated/logbook/station.parquet        (.sid, .tid, schema, twin)
#         curated/logbook/gear.parquet           (.sid, schema, gid_used: logbook_gear.R)
#         curated/landing/landings.parquet       (.lid, schema, vid, date)
#         curated/landing/catch.parquet          (.lid, schema, gid, catch: agf in the new gear code, lods in the old)
#         curated/reference/gear.parquet         (old gid -> map, the new gid)
#         curated/reference/gear_window.parquet  (gid, gear_class, s1, s2)
# Output: curated/ais/voyage_gear.parquet        one row per voyage
#
# The gear's speed range lets the track decide whether a fix is fishing where no logbook window holds it:
# ramb::rb_add_fishing(method = c("window", "speed")) in R/trail_sql.R (plan 013 item 3). A voyage takes
#   logbook    the gears of its logbook trips' stations, when they share one speed range (the gid used most is named);
#   ambiguous  its stations use gears with different speed ranges: no range, so only the windows decide;
#   landing    no logbook trip, but a landing of the vessel dated within the voyage (to the day after it ends):
#              the gear that holds most of the landed weight;
#   none       neither.
# Duplicate twin stations are left out (decision 094). A landing gid of lods is mapped to the new code first, as in
# curate/corrections/logbook_gear.R.

library(DBI)
con <- dbConnect(duckdb::duckdb())
f <- function(...) shQuote(fd_curated(...), type = "sh")

dbExecute(con, sprintf("CREATE TEMP TABLE old_new AS
  SELECT CAST(gid AS INTEGER) AS gid_old, CAST(any_value(map) AS INTEGER) AS gid_new
  FROM read_parquet(%s) WHERE version = 'old' AND map IS NOT NULL GROUP BY gid", f("reference", "gear.parquet")))

sql <- sprintf("
  WITH v AS (SELECT vid, year, voyage, T1, T2 FROM read_parquet(%s)),
  w AS (SELECT CAST(gid AS INTEGER) AS gid, gear_class, s1, s2 FROM read_parquet(%s)),
  lbs AS (SELECT tv.vid, tv.year, tv.voyage, CAST(g.gid_used AS INTEGER) AS gid
          FROM read_parquet(%s) tv
          JOIN read_parquet(%s) s ON s.\".tid\" = tv.\".tid\" AND s.schema = tv.schema
          JOIN read_parquet(%s) g ON g.\".sid\" = s.\".sid\" AND g.schema = s.schema
          WHERE s.twin IS DISTINCT FROM 'duplicate' AND g.gid_used IS NOT NULL),
  lbg AS (SELECT l.vid, l.year, l.voyage, l.gid, count(*) AS n, any_value(w.gear_class) AS gear_class,
                 any_value(w.s1) AS s1, any_value(w.s2) AS s2,
                 coalesce(CAST(any_value(w.s1) AS VARCHAR), 'NA') || '|' || coalesce(CAST(any_value(w.s2) AS VARCHAR), 'NA') AS rng
          FROM lbs l LEFT JOIN w ON w.gid = l.gid GROUP BY l.vid, l.year, l.voyage, l.gid),
  lbv AS (SELECT vid, year, voyage, arg_max(gid, n) AS gid, arg_max(gear_class, n) AS gear_class,
                 arg_max(s1, n) AS s1, arg_max(s2, n) AS s2, count(DISTINCT rng) AS n_rng
          FROM lbg GROUP BY vid, year, voyage),
  lw AS (SELECT l.vid, l.date, CASE WHEN c.schema = 'lods' THEN o.gid_new ELSE CAST(c.gid AS INTEGER) END AS gid,
                sum(c.catch) AS kg
         FROM read_parquet(%s) l JOIN read_parquet(%s) c ON c.\".lid\" = l.\".lid\" AND c.schema = l.schema
         LEFT JOIN old_new o ON o.gid_old = CAST(c.gid AS INTEGER)
         GROUP BY ALL),
  lvg AS (SELECT v.vid, v.year, v.voyage, lw.gid, sum(lw.kg) AS kg
          FROM v JOIN lw ON lw.vid = v.vid AND lw.date BETWEEN CAST(v.T1 AS DATE) AND CAST(v.T2 AS DATE) + 1
          WHERE lw.gid IS NOT NULL GROUP BY ALL),
  lvm AS (SELECT vid, year, voyage, arg_max(gid, kg) AS gid FROM lvg GROUP BY vid, year, voyage)
  SELECT v.vid, v.year, v.voyage,
         CASE WHEN lbv.vid IS NOT NULL THEN lbv.gid ELSE lvm.gid END AS gid_voyage,
         CASE WHEN lbv.vid IS NOT NULL AND lbv.n_rng = 1 THEN lbv.gear_class
              WHEN lbv.vid IS NULL THEN wl.gear_class END AS gear_class_voyage,
         CASE WHEN lbv.vid IS NOT NULL AND lbv.n_rng = 1 THEN lbv.s1 WHEN lbv.vid IS NULL THEN wl.s1 END AS s1_voyage,
         CASE WHEN lbv.vid IS NOT NULL AND lbv.n_rng = 1 THEN lbv.s2 WHEN lbv.vid IS NULL THEN wl.s2 END AS s2_voyage,
         CASE WHEN lbv.vid IS NOT NULL AND lbv.n_rng = 1 THEN 'logbook'
              WHEN lbv.vid IS NOT NULL THEN 'ambiguous'
              WHEN lvm.vid IS NOT NULL THEN 'landing' ELSE 'none' END AS gear_voyage_basis
  FROM v LEFT JOIN lbv USING (vid, year, voyage) LEFT JOIN lvm USING (vid, year, voyage)
         LEFT JOIN w wl ON wl.gid = lvm.gid",
  f("ais", "voyage.parquet"), f("reference", "gear_window.parquet"), f("link", "trip_voyage.parquet"),
  f("logbook", "station.parquet"), f("logbook", "gear.parquet"),
  f("landing", "landings.parquet"), f("landing", "catch.parquet"))

write_curated_sql(con, sql, fd_curated("ais", "voyage_gear.parquet"),
                  inputs = c(fd_curated("ais", "voyage.parquet"), fd_curated("link", "trip_voyage.parquet"),
                             fd_curated("logbook", "station.parquet"), fd_curated("logbook", "gear.parquet"),
                             fd_curated("landing", "landings.parquet"), fd_curated("landing", "catch.parquet"),
                             fd_curated("reference", "gear.parquet"), fd_curated("reference", "gear_window.parquet")),
                  order_by = "vid, year, voyage")
dbDisconnect(con, shutdown = TRUE)
