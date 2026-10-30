# logbook_app_profile.R — each e-logbook app's profile, field by field, on every build, against the reviewed rows.
# Side: preprocessing, check. See plan 053 §5.4 (step 4).
#
# Input:  raw/oracle/fs_afladagbok/{ws_veidiferd,ws_veidi}.parquet, raw/oracle/adb/{fishing_trip,fishing_station}.parquet
#         staging/{fs_afladagbok,adb}/{fishing_sample,station}.parquet (the gear; a position the merge lacks),
#         staging/adb/lon_sign.parquet, staging/afli_sent/{trip,station,fishing_sample}
#         curated/logbook/{station,trip,lid_map}.parquet (the merge's stations and twins, its trips, their landings)
#         curate/corrections/logbook_app_profile.yml (the rows)
# Output: curated/check/logbook_app_profile.parquet, one row per (area, feed, app, year, gear_class, field, class):
#         n stations (or trips), n_merge of them in the merge, app_named (a row names the app)
#
# The classes are plan 053's (the archive's scripts/02_profile.py, $FISHYDATA/archive/2026-10-29-elogbook-feed/), from
# the record alone, so the check gives the archive's counts on the store it measured: counts/p01 row for row, p03 and
# p05 on every class, r18 by app (2026-10-30, $FISHYDATA/archive/2026-10-30-plan054-step2a/test_check.R). Each
# station once: fs_afladagbok whole; adb's stations fs_afladagbok lacks; the afli route as sent. A time's class, first
# match wins: nothing; the placeholder (t1 only: t3 less 270 or 1,710 min, or 270 min and k >= 2 whole days, all +-1 min);
# a date; the departure (+-1 min); the landing (+-10 min, not a date); the station's own times (t1 = t3 or t4 +-1 min,
# t2 = t3 and t3 = t4 within 4 min); the entry time; the previous station (t1 only); the half-hour grid (t1 only);
# the afli route's adapter basis "derived"; seconds; a whole minute. Positions: the start latitude's digit form, the
# longitude's sign against the sign rule, the end. Depth: nothing, zero, recorded, the end a copy.
# Also, area "trip", class "unlanded_cluster": row I4's trips (a vessel-year whose e-logbook trips with no landing
# linked, lid_map, are 10 or more and at least half of its trips, by app and the landing's year, duplicate twins out),
# which need the landing link, made after the merge. A check, never an input: nothing reads this file back.
#
# A new app, a new version or a moved share is read off the file: app_named FALSE for an app no row names (on
# 2026-10-30 the afli route's versions but 2.6, which the value rows with "*" read, the tour app, paper, TRACKWELL
# BAEKUR and FRA GAFLI - AUTO), a class by year beside the last build's.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
dbExecute(con, "SET TimeZone = 'UTC'")
x <- function(...) invisible(dbExecute(con, sprintf(...)))
R <- function(s, t) sprintf("read_parquet('%s')", fd_raw("oracle", s, paste0(t, ".parquet")))
ST <- function(s, t) sprintf("read_parquet('%s')", fd_staging(s, paste0(t, ".parquet")))
CU <- function(t) sprintf("read_parquet('%s')", fd_curated("logbook", paste0(t, ".parquet")))

x("CREATE MACRO app_base(a) AS trim(regexp_replace(trim(a), ' - (GAFL AUTO|Skrifstofa VES)', '', 'g'))")
x("CREATE MACRO gclass(g) AS CASE WHEN g IN ('OTB','OTM','DRB') THEN 'towed' WHEN g = 'SDN' THEN 'seine'
   WHEN g = 'PS' THEN 'purse seine' WHEN g IN ('LLS','GNS','GND','FPO') THEN 'static' WHEN g = 'LHM' THEN 'jig'
   ELSE 'other' END")
x("CREATE MACRO eqm(a, b, s) AS coalesce(abs(epoch(a) - epoch(b)) <= s, FALSE)")
x("CREATE MACRO ndig(v) AS CASE WHEN v IS NULL OR v = 0 THEN 0 ELSE length(CAST(CAST(abs(v) AS BIGINT) AS VARCHAR)) END")
x("CREATE MACRO tclass(v, fld, t1, t3, t4, dep, land, ent, p3, p4, basis) AS CASE
    WHEN v IS NULL THEN 'nothing'
    WHEN fld = 't1' AND t3 IS NOT NULL AND (abs(date_diff('minute', v, t3) - 270) <= 1
         OR abs(date_diff('minute', v, t3) - 1710) <= 1) THEN 'placeholder'
    WHEN fld = 't1' AND t3 IS NOT NULL AND date_diff('minute', v, t3) >= 2879
         AND abs(((date_diff('minute', v, t3) - 270) %% 1440 + 1440 + 1) %% 1440 - 1) <= 1 THEN 'placeholder'
    WHEN v = CAST(v AS DATE) THEN 'date'
    WHEN eqm(v, dep, 60) THEN 'copy: departure'
    WHEN eqm(v, land, 600) AND land <> CAST(land AS DATE) THEN 'copy: landing'
    WHEN fld = 't1' AND (eqm(v, t3, 60) OR eqm(v, t4, 60)) THEN 'copy: own field'
    WHEN fld = 't2' AND eqm(v, t3, 240) THEN 'copy: own field'
    WHEN fld = 't3' AND eqm(v, t4, 240) THEN 'copy: own field'
    WHEN eqm(v, ent, 60) THEN 'copy: entry time'
    WHEN fld = 't1' AND (eqm(v, p4, 60) OR eqm(v, p3, 60)) THEN 'copy: previous station'
    WHEN fld = 't1' AND t3 IS NOT NULL AND t3 > v AND date_diff('minute', v, t3) %% 30 = 0
         AND second(v) = second(t3) THEN 'derived: half-hour grid'
    WHEN basis = 'derived' THEN 'derived: adapter'
    WHEN second(v) <> 0 THEN 'recorded: seconds'
    ELSE 'recorded: whole minute' END")

# The merge: membership, twins, positions ----------------------------------------------------------------------------
x("CREATE TABLE mg AS SELECT s.schema AS src, s.\".sid\" AS sid, s.twin, s.lat1, s.lon1 FROM %s s
   WHERE s.schema IN ('fs_afladagbok', 'adb', 'afli')", CU("station"))

# A station the merge does not hold takes its staged position (fs's sign rule; adb's sign from staging/adb/lon_sign)
x("CREATE TABLE sp AS
  SELECT 'fs_afladagbok' AS src, CAST(\".sid\" AS BIGINT) AS sid, lat1, lon1 FROM %s
  UNION ALL SELECT 'adb', CAST(s.\".sid\" AS BIGINT), s.lat1, coalesce(l.lon1, s.lon1) FROM %s s
  LEFT JOIN %s l ON l.\".sid\" = s.\".sid\"", ST("fs_afladagbok", "station"), ST("adb", "station"), ST("adb", "lon_sign"))

# The e-logbook, each station once, its times in the grammar's slots (R/logbook_effort.R's elogbook_times()) ---------
x("CREATE TABLE el AS
  WITH ft AS (SELECT id AS tid, skipnr AS vid, uppruni AS app_raw, upphafstimi AS departure, londunardagur AS landing
              FROM %s),
  fv AS (SELECT id AS sid, veidiferd_id AS tid, upphaf_timi AS ts, milli_timi AS tm, lok_timi AS te, upphaf_breidd AS y1,
                upphaf_lengd AS x1, lok_breidd AS y2, lok_lengd AS x2, upphaf_dypi AS z1, lok_dypi AS z2,
                skraningartimi AS entered FROM %s),
  atr AS (SELECT id AS tid, vessel_no AS vid, source AS app_raw, departure, landing FROM %s),
  av AS (SELECT fishing_station_id AS sid, fishing_trip_id AS tid, fishing_start AS ts, tow_start AS tm, fishing_end AS te,
                latitude AS y1, longitude AS x1, latitude_end AS y2, longitude_end AS x2, depth AS z1, depth_end AS z2,
                registered AS entered FROM %s)
  SELECT 'fs_afladagbok' AS src, CAST(fv.sid AS BIGINT) AS sid, CAST(ft.vid AS INTEGER) AS vid, ft.app_raw, g.gear,
         fv.ts, fv.tm, fv.te, fv.y1, fv.x1, fv.y2, fv.x2, fv.z1, fv.z2, fv.entered, ft.departure, ft.landing
  FROM fv LEFT JOIN ft USING (tid) LEFT JOIN %s g ON g.\".sid\" = fv.sid
  UNION ALL
  SELECT 'adb', CAST(av.sid AS BIGINT), CAST(atr.vid AS INTEGER), atr.app_raw, g.gear, av.ts, av.tm, av.te, av.y1, av.x1,
         av.y2, av.x2, av.z1, av.z2, av.entered, atr.departure, atr.landing
  FROM av LEFT JOIN atr ON atr.tid = CAST(av.tid AS VARCHAR) LEFT JOIN %s g ON g.\".sid\" = av.sid",
  R("fs_afladagbok", "ws_veidiferd"), R("fs_afladagbok", "ws_veidi"), R("adb", "fishing_trip"),
  R("adb", "fishing_station"), ST("fs_afladagbok", "fishing_sample"), ST("adb", "fishing_sample"))
x("CREATE TABLE pop AS
  SELECT el.*, app_base(app_raw) AS app, gclass(gear) AS gear_class,
    CASE WHEN gclass(gear) = 'towed' THEN NULL WHEN gear = 'SDN' AND tm IS NOT NULL AND tm <> ts THEN ts
         WHEN gear = 'SDN' THEN NULL ELSE ts END AS t1,
    CASE WHEN gclass(gear) = 'towed' THEN ts WHEN gear = 'SDN' AND tm IS NOT NULL AND tm <> ts THEN tm
         WHEN gear = 'SDN' THEN ts END AS t2,
    CASE WHEN gclass(gear) IN ('towed', 'seine') THEN te ELSE tm END AS t3,
    CASE WHEN gclass(gear) IN ('towed', 'seine') THEN NULL ELSE te END AS t4,
    CAST(coalesce(ts, tm, te) AS DATE) AS sdate, year(coalesce(ts, tm, te, departure)) AS year,
    mg.twin, coalesce(mg.lat1, sp.lat1) AS lat1, coalesce(mg.lon1, sp.lon1) AS lon1, mg.sid IS NOT NULL AS in_merge,
    CASE WHEN el.src = 'fs_afladagbok' THEN 'fs_afladagbok'
         WHEN CAST(coalesce(ts, tm, te) AS DATE) >= DATE '2025-11-19' THEN 'adb from 2025-11-19'
         ELSE 'adb before 2025-11-19, not in fs' END AS feed
  FROM el LEFT JOIN mg ON mg.src = el.src AND mg.sid = el.sid LEFT JOIN sp ON sp.src = el.src AND sp.sid = el.sid
  WHERE el.src = 'fs_afladagbok' OR el.sid NOT IN (SELECT sid FROM el WHERE src = 'fs_afladagbok')")
x("CREATE TABLE prev AS SELECT feed, sid, lag(t3) OVER w AS prev_t3, lag(t4) OVER w AS prev_t4
   FROM pop WHERE vid IS NOT NULL AND twin IS DISTINCT FROM 'duplicate'
   WINDOW w AS (PARTITION BY vid ORDER BY coalesce(t3, t1, t2), coalesce(t4, t3, t1, t2), sid)")

# The afli route as sent ---------------------------------------------------------------------------------------------
x("CREATE TABLE sa AS
  SELECT CAST(s.\".sid\" AS BIGINT) AS sid, t.vid, coalesce(s.app, '(none)') AS app,
    split_part(s.app_version, '.', 1) || '.' || split_part(s.app_version, '.', 2) AS app_version,
    f.gear, gclass(f.gear) AS gear_class, f.t1, f.t2, f.t3, f.t4, f.t1_basis, f.t2_basis, f.t3_basis, f.t4_basis,
    t.T1 AS departure, t.T2 AS landing, year(s.date) AS year, mg.sid IS NOT NULL AS in_merge
  FROM %s s JOIN %s f ON f.\".sid\" = s.\".sid\" AND f.\".xid\" = s.\".xid\"
  LEFT JOIN %s t ON t.\".tid\" = s.\".tid\"
  LEFT JOIN mg ON mg.src = 'afli' AND mg.sid = s.\".sid\"",
  ST("afli_sent", "station"), ST("afli_sent", "fishing_sample"), ST("afli_sent", "trip"))
x("CREATE TABLE sprev AS SELECT sid, lag(t3) OVER w AS prev_t3, lag(t4) OVER w AS prev_t4 FROM sa WHERE vid IS NOT NULL
   WINDOW w AS (PARTITION BY vid ORDER BY coalesce(t3, t1, t2), coalesce(t4, t3, t1, t2), sid)")

# Times --------------------------------------------------------------------------------------------------------------
fields <- list(t1 = "('static', 'jig', 'seine', 'other')", t2 = "('towed', 'seine')",
               t3 = "('static', 'jig', 'seine', 'other', 'towed', 'purse seine')", t4 = "('static', 'jig', 'other')")
el_q <- paste(vapply(names(fields), \(f) sprintf(
  "SELECT 'time' AS area, feed, app, year, gear_class, '%1$s' AS field,
          tclass(%1$s, '%1$s', t1, t3, t4, departure, landing, entered, prev_t3, prev_t4, NULL) AS class, in_merge
   FROM p WHERE %2$s", f, if (f == "t3") "TRUE" else sprintf("gear_class IN %s", fields[[f]])), ""), collapse = " UNION ALL ")
sa_q <- paste(vapply(names(fields), \(f) sprintf(
  "SELECT 'time', 'afli route (sent)', app || ' ' || coalesce(app_version, ''), year, gear_class, '%1$s',
          tclass(%1$s, '%1$s', t1, t3, t4, departure, landing, NULL::TIMESTAMP, prev_t3, prev_t4, %1$s_basis), in_merge
   FROM q WHERE %2$s", f, if (f == "t3") "TRUE" else sprintf("gear_class IN %s", fields[[f]])), ""), collapse = " UNION ALL ")
x("CREATE TABLE tc AS
   WITH p AS (SELECT pop.*, pv.prev_t3, pv.prev_t4 FROM pop LEFT JOIN prev pv USING (feed, sid)),
        q AS (SELECT sa.*, sp.prev_t3, sp.prev_t4 FROM sa LEFT JOIN sprev sp USING (sid))
   %s UNION ALL %s", el_q, sa_q)

# Positions and depth (the e-logbook) ------------------------------------------------------------------------------------
x("CREATE TABLE pz AS
  SELECT 'position' AS area, feed, app, year, gear_class, 'lat1' AS field,
    CASE ndig(y1) WHEN 0 THEN 'nothing' WHEN 2 THEN '2 digits: whole degrees' WHEN 4 THEN '4 digits: ddmm'
      WHEN 5 THEN '5 digits: ddmm.m' WHEN 6 THEN CASE WHEN abs(y1) %% 100 > 60 THEN '6 digits: last two 61-99 (hundredths)'
      ELSE '6 digits: ddmmss or ddmm.hh' END WHEN 7 THEN '7 digits: ddmm.mmm' ELSE ndig(y1) || ' digits' END AS class, in_merge
  FROM pop
  UNION ALL SELECT 'position', feed, app, year, gear_class, 'lon1',
    CASE WHEN x1 IS NULL OR x1 = 0 THEN 'nothing' WHEN x1 > 0 THEN 'positive (read west)'
      WHEN lat1 IS NOT NULL AND lon1 < 0 THEN 'negative, read west by the rule' ELSE 'negative (read east)' END, in_merge
  FROM pop
  UNION ALL SELECT 'position', feed, app, year, gear_class, 'pos2',
    CASE WHEN y2 IS NULL OR y2 = 0 OR x2 IS NULL OR x2 = 0 THEN 'nothing' WHEN y2 = y1 AND x2 = x1 THEN 'copy of the start'
      ELSE 'recorded' END, in_merge FROM pop
  UNION ALL SELECT 'depth', feed, app, year, gear_class, 'z1',
    CASE WHEN z1 IS NULL THEN 'nothing' WHEN z1 = 0 THEN 'zero' ELSE 'recorded' END, in_merge FROM pop
  UNION ALL SELECT 'depth', feed, app, year, gear_class, 'z2',
    CASE WHEN z2 IS NULL THEN 'nothing' WHEN z2 = 0 THEN 'zero' WHEN z2 = z1 THEN 'copy of z1' ELSE 'recorded' END, in_merge
  FROM pop")

# Row I4: the unlanded clusters --------------------------------------------------------------------------------------
x("CREATE TABLE i4 AS
  WITH t AS (SELECT t.\".tid\" AS tid, t.schema, t.vid, year(t.T2) AS year, coalesce(nullif(app_base(t.source), ''), '(no app)') AS app,
                    m.\".tid\" IS NOT NULL AS landed
             FROM %s t LEFT JOIN (SELECT DISTINCT \".tid\", schema FROM %s) m USING (\".tid\", schema)
             WHERE t.schema IN ('fs_afladagbok', 'adb') AND t.twin IS DISTINCT FROM 'duplicate' AND t.vid IS NOT NULL),
  vy AS (SELECT app, vid, year FROM t GROUP BY ALL
         HAVING count(*) FILTER (WHERE NOT landed) >= 10 AND count(*) FILTER (WHERE NOT landed) >= 0.5 * count(*))
  SELECT 'trip' AS area, t.schema AS feed, t.app, t.year, NULL AS gear_class, 'trip' AS field,
         'unlanded_cluster' AS class, TRUE AS in_merge
  FROM t JOIN vy USING (app, vid, year) WHERE NOT t.landed", CU("trip"), CU("lid_map"))

# The profile's apps -------------------------------------------------------------------------------------------------
rows <- yaml::read_yaml("curate/corrections/logbook_app_profile.yml")$rows
named <- setdiff(unique(unlist(lapply(rows, \(r) unlist(r$apps)))), "*")
out <- dbGetQuery(con, "
  SELECT area, feed, app, year, gear_class, field, class, count(*) AS n, count(*) FILTER (WHERE in_merge) AS n_merge
  FROM (SELECT * FROM tc UNION ALL SELECT * FROM pz UNION ALL SELECT * FROM i4)
  GROUP BY ALL ORDER BY area, feed, app, year, gear_class, field, class")
# a row names the app, or on the afli route its software's name and version ("... Fishing Log 2.6")
out$app_named <- out$app %in% named | vapply(out$app, \(a) any(endsWith(a, paste0(" ", named))), TRUE)

message("\napps no row names, by feed (stations)")
print(stats::aggregate(n ~ feed + app, out[!out$app_named & out$area == "time" & out$field == "t3", ], sum))
message("\nrow I4: the unlanded clusters, trips by feed and app")
print(stats::aggregate(n ~ feed + app, out[out$area == "trip", ], sum))

out |> write_curated(fd_curated("check", "logbook_app_profile.parquet"),
                     inputs = c(fd_raw("oracle", "fs_afladagbok", "ws_veidiferd.parquet"),
                                fd_raw("oracle", "fs_afladagbok", "ws_veidi.parquet"),
                                fd_raw("oracle", "adb", "fishing_trip.parquet"),
                                fd_raw("oracle", "adb", "fishing_station.parquet"),
                                fd_staging("fs_afladagbok", "fishing_sample.parquet"),
                                fd_staging("adb", "fishing_sample.parquet"), fd_staging("fs_afladagbok", "station.parquet"),
                                fd_staging("adb", "station.parquet"), fd_staging("adb", "lon_sign.parquet"),
                                fd_staging("afli_sent", "station.parquet"), fd_staging("afli_sent", "fishing_sample.parquet"),
                                fd_staging("afli_sent", "trip.parquet"), fd_curated("logbook", "station.parquet"),
                                fd_curated("logbook", "trip.parquet"), fd_curated("logbook", "lid_map.parquet"),
                                "curate/corrections/logbook_app_profile.yml"))
dbDisconnect(con, shutdown = TRUE)
