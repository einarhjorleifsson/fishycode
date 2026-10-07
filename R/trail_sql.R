# trail_sql.R — the SQL that attaches logbook evidence to a month of fixes.
#
# Used by curate/ais_trail.R only. Plan 010 §3 (how a fix finds its station) and plan 011 Phase 5 (how it finds
# its logbook trip through the voyage). Function definitions only; nothing runs on load.
#
# A fix matches every station window of its vessel that contains its time. Windows come in tiers and a lower
# tier only claims fixes no higher tier claims: tier 1 = tow | haul | set | jig (logbook times), tier 2 = day
# (the whole station date, used when a station has no usable time). What stays ambiguous stays ambiguous:
# `n_sid` counts the stations and `.sid`/`.tid`/`phase` are filled only when exactly one station claims the fix.
# A station matched in two of its own phases counts once, haul > tow > jig > set > day.
# Keys: `.sid` and `.tid` are unique only within a schema, so the station is (.sid, schema).
# `fishing` is TRUE when a tow, haul, jig or day window holds the fix and its speed is inside that gear's [s1, s2];
# a set is never fishing. It is NA when such a window holds the fix but the fix has no speed (a logger fix with no
# speed, or the 1.000 m/s placeholder, plan 012 §2f): unknown, not FALSE. FALSE for a fix in no window.
#
# The voyage side: `trip_voyage` links a logbook trip to the AIS voyage (vid, year, trip) it overlaps most.
# Several logbook trips may share one voyage (3-4 %), so `.tid_voyage` is filled only when exactly one trip is on
# the voyage, and `n_tid_voyage` counts them (0 = no logbook trip on this voyage or the fix is in no voyage).

trail_month_sql <- function(year, month, kind = c("wide", "match")) {
  kind <- match.arg(kind)
  t0 <- sprintf("TIMESTAMP '%d-%02d-01'", year, month)
  t1 <- if (month == 12) sprintf("TIMESTAMP '%d-01-01'", year + 1L) else sprintf("TIMESTAMP '%d-%02d-01'", year, month + 1L)
  pfile <- shQuote(file.path(fd_curated("ais", "ping_trail"), paste0("year=", year), "part_001.parquet"), type = "sh")
  swf   <- shQuote(fd_curated("logbook", "station_window.parquet"), type = "sh")
  tvf   <- shQuote(fd_curated("link", "trip_voyage.parquet"), type = "sh")

  p <- sprintf("(SELECT * EXCLUDE (year, pid) FROM read_parquet(%s) WHERE time >= %s AND time < %s)", pfile, t0, t1)

  matches <- sprintf("
    WITH w AS (SELECT *, CASE phase WHEN 'haul' THEN 1 WHEN 'tow' THEN 2 WHEN 'jig' THEN 3
                                    WHEN 'set' THEN 4 ELSE 5 END AS prank
               FROM read_parquet(%s) WHERE w_end >= %s AND w_start < %s),
    m0 AS (
      SELECT p.vid, p.time, p.speed, w.\".sid\" AS sid, w.schema, w.\".tid\" AS tid, w.gear, w.target, w.target2,
             w.gear_class, w.phase, w.win_basis, w.events, w.s1, w.s2, w.w_start, w.w_end,
             w.prank, (w.phase <> 'day') AS tier1
      FROM (SELECT vid, time, speed FROM %s) p
      JOIN w ON p.vid = w.vid AND p.time BETWEEN w.w_start AND w.w_end),
    m1 AS (SELECT * FROM m0 WHERE tier1
           UNION ALL
           SELECT * FROM m0 WHERE NOT tier1
             AND NOT EXISTS (SELECT 1 FROM m0 t WHERE t.tier1 AND t.vid = m0.vid AND t.time = m0.time)),
    m AS (SELECT * EXCLUDE (rk) FROM (
            SELECT *, row_number() OVER (PARTITION BY vid, time, sid, schema ORDER BY prank) AS rk FROM m1) WHERE rk = 1)",
    swf, t0, t1, p)

  if (kind == "match") return(sprintf("
    %s
    SELECT m.vid, m.time, m.sid AS \".sid\", m.schema, m.tid AS \".tid\", m.gear, m.target, m.target2, m.gear_class, m.phase,
           CASE WHEN m.phase <> 'day' THEN epoch(m.time - m.w_start) / nullif(epoch(m.w_end - m.w_start), 0) END AS phase_frac,
           m.win_basis, m.events, m.s1, m.s2, m.w_start, m.w_end,
           (m.phase <> 'set' AND m.speed BETWEEN m.s1 AND m.s2) AS fishing
    FROM m ORDER BY m.vid, m.time, m.sid", matches))

  sprintf("
    %s,
    a AS (
      SELECT vid, time, count(*) AS n_sid,
             any_value(sid) AS sid, any_value(schema) AS schema, any_value(tid) AS tid,
             any_value(gear) AS gear, any_value(target) AS target, any_value(target2) AS target2,
             any_value(gear_class) AS gear_class,
             any_value(s1) AS s1, any_value(s2) AS s2,
             any_value(phase) AS phase, any_value(win_basis) AS win_basis, any_value(events) AS events,
             any_value(CASE WHEN phase <> 'day' THEN epoch(time - w_start) / nullif(epoch(w_end - w_start), 0) END) AS phase_frac,
             -- per claiming window: FALSE for a set or a gear with no speed range, NA when there is no speed
             CASE WHEN bool_or(CASE WHEN phase = 'set' OR s1 IS NULL THEN FALSE WHEN speed IS NULL THEN NULL
                                    ELSE speed BETWEEN s1 AND s2 END) THEN TRUE
                  WHEN count(*) FILTER (WHERE NOT (phase = 'set' OR s1 IS NULL) AND speed IS NULL) > 0 THEN NULL
                  ELSE FALSE END AS fishing
      FROM m GROUP BY vid, time),
    v AS (
      SELECT vid, year, trip, count(*) AS n_tid_voyage,
             CASE WHEN count(*) = 1 THEN any_value(\".tid\") END AS tid_v,
             CASE WHEN count(*) = 1 THEN any_value(schema) END AS schema_v
      FROM read_parquet(%s) WHERE year = %d GROUP BY vid, year, trip)
    SELECT p.vid, p.mmsi, p.time, p.lon, p.lat, p.speed, p.speed_raw, p.heading, p.cog, p.provider,
           p.pos_basis, p.speed_basis, p.speed_gps, p.dt_sec, p.stay_pid, p.trip,
           v.tid_v AS \".tid_voyage\", v.schema_v AS schema_voyage, coalesce(v.n_tid_voyage, 0) AS n_tid_voyage,
           coalesce(a.n_sid, 0) AS n_sid,
           CASE WHEN a.n_sid = 1 THEN a.sid END AS \".sid\",
           CASE WHEN a.n_sid = 1 THEN a.schema END AS schema,
           CASE WHEN a.n_sid = 1 THEN a.tid END AS \".tid\",
           CASE WHEN a.n_sid = 1 THEN a.gear END AS gear,
           CASE WHEN a.n_sid = 1 THEN a.target END AS target,
           CASE WHEN a.n_sid = 1 THEN a.target2 END AS target2,
           CASE WHEN a.n_sid = 1 THEN a.gear_class END AS gear_class,
           CASE WHEN a.n_sid = 1 THEN a.s1 END AS s1,
           CASE WHEN a.n_sid = 1 THEN a.s2 END AS s2,
           CASE WHEN a.n_sid = 1 THEN a.phase END AS phase,
           CASE WHEN a.n_sid = 1 THEN a.phase_frac END AS phase_frac,
           CASE WHEN a.n_sid = 1 THEN a.win_basis END AS win_basis,
           CASE WHEN a.n_sid = 1 THEN a.events END AS events,
           CASE WHEN a.n_sid IS NULL THEN FALSE ELSE a.fishing END AS fishing,
           p.sid_gps, p.n_sid_gps
    FROM %s p
    LEFT JOIN a USING (vid, time)
    LEFT JOIN v ON v.vid = p.vid AND v.trip = p.trip",
    matches, tvf, year, p)
}
