# ais_trail.R — the pings with their trip and fishing activity attached.
#
# Input:  curated/ais/ping_trail/year=*   (AIS + gps logger, unique on vid, time)
#         curated/logbook/station_window.parquet
# Output: a lazy table (nothing is read until collect()/compute())
#
#   ais_trail(2019)                      one row per fix, station columns attached
#   ais_trail(2017:2019, vids = 1277)    a few vessels
#   ais_trail(2019, long = TRUE)         one row per (fix, station): the matches
#
# This is the join the old trail paid for once and stored. Phase 0 of plan 010 timed it
# at 6 s for a whole year, so it is done on the way out instead of kept in a 44 GB file.
#
# HOW A FIX FINDS ITS STATION (plan 010 §3)
#   A fix matches every station window of its vessel that contains its time. Windows
#   come in tiers and a lower tier only claims fixes no higher tier claims:
#     tier 1  tow | haul | set | jig   windows drawn from logbook times (win_basis
#             recorded, derived, capped, or an estimated end on a recorded start)
#     tier 2  day                      the whole station date, used when a station has
#                                      no usable time
#   So a day window never competes with a recorded one for the same fix. What remains
#   ambiguous STAYS ambiguous: n_sid counts the stations, and sid/tid/phase are filled
#   only when exactly one station claims the fix. There is no "primary" station.
#   A station matched in two of its own phases (set and haul can overlap when the haul
#   start is an estimate) counts once, with haul > tow > jig > set > day.
#
# KEYS. .sid and .tid are unique only within a schema, so the station is (sid, schema).
#
# fishing: TRUE when at least one matching window is a tow, haul, jig or day window and
# the fix's speed is inside that gear's [s1, s2]. A set is never "fishing": the vessel is
# running out the gear, faster than the gear's fishing speed. fishing is FALSE, not NA,
# for a fix with no match; look at win_basis before trusting it on a day window.
#
# The speed is the cleaned one, in knots (NA where the source value was implausible).

ais_trail <- function(years, vids = NULL, long = FALSE, sorted = TRUE) {
  years <- sort(as.integer(years))
  files <- file.path(fd_curated("ais", "ping_trail"), paste0("year=", years), "part_001.parquet")
  files <- files[file.exists(files)]
  if (!length(files)) stop("no ping_trail files for years: ", paste(years, collapse = ", "), call. = FALSE)
  swf <- fd_curated("logbook", "station_window.parquet")
  flist <- paste(shQuote(files, type = "sh"), collapse = ", ")
  vfilter <- if (!is.null(vids)) sprintf("AND vid IN (%s)", paste(as.integer(vids), collapse = ",")) else ""
  t0 <- sprintf("TIMESTAMP '%d-01-01'", min(years))
  t1 <- sprintf("TIMESTAMP '%d-01-01'", max(years) + 1L)

  pings <- sprintf("read_parquet([%s])", flist)
  # `p` is scanned twice (once to find matches, once to attach them) and must not be
  # materialised: a busy year is 50 M rows and that is what ran this out of memory.
  matches <- sprintf("
    WITH w AS (SELECT *, CASE phase WHEN 'haul' THEN 1 WHEN 'tow' THEN 2 WHEN 'jig' THEN 3
                                    WHEN 'set' THEN 4 ELSE 5 END AS prank
               FROM read_parquet(%s)
               WHERE w_end >= %s AND w_start < %s %s),
    m0 AS (
      SELECT p.vid, p.time, p.speed, w.\".sid\" AS sid, w.schema, w.\".tid\" AS tid, w.gear,
             w.gear_class, w.phase, w.win_basis, w.events, w.s1, w.s2, w.w_start, w.w_end,
             w.prank, (w.phase <> 'day') AS tier1
      FROM (SELECT vid, time, speed FROM %s WHERE true %s) p
      JOIN w ON p.vid = w.vid AND p.time BETWEEN w.w_start AND w.w_end),
    m1 AS (  -- a day window claims only fixes no tier-1 window claims
      SELECT * FROM m0 WHERE tier1
      UNION ALL
      SELECT * FROM m0 WHERE NOT tier1
        AND NOT EXISTS (SELECT 1 FROM m0 t WHERE t.tier1 AND t.vid = m0.vid AND t.time = m0.time)),
    m AS (   -- one row per (fix, station): its best phase
      SELECT * EXCLUDE (rk) FROM (
        SELECT *, row_number() OVER (PARTITION BY vid, time, sid, schema ORDER BY prank) AS rk
        FROM m1) WHERE rk = 1)",
    shQuote(swf, type = "sh"), t0, t1, vfilter, pings, vfilter)

  sql <- if (long) sprintf("
    %s
    SELECT p.*, m.sid, m.schema, m.tid, m.gear, m.gear_class, m.phase, m.win_basis, m.events,
           CASE WHEN m.phase <> 'day' THEN epoch(p.time - m.w_start) / nullif(epoch(m.w_end - m.w_start), 0) END AS phase_frac,
           m.s1, m.s2, (m.phase <> 'set' AND p.speed BETWEEN m.s1 AND m.s2) AS fishing
    FROM m JOIN (SELECT * FROM %s WHERE true %s) p USING (vid, time)", matches, pings, vfilter)
  else sprintf("
    %s,
    a AS (
      SELECT vid, time, count(*) AS n_sid,
             any_value(sid) AS sid, any_value(schema) AS schema, any_value(tid) AS tid,
             any_value(gear) AS gear, any_value(gear_class) AS gear_class,
             any_value(phase) AS phase, any_value(win_basis) AS win_basis,
             any_value(events) AS events,
             any_value(CASE WHEN phase <> 'day' THEN epoch(time - w_start) / nullif(epoch(w_end - w_start), 0) END) AS phase_frac,
             -- fishing: any tow/haul/jig/day window whose own speed range holds the speed
             bool_or(phase <> 'set' AND speed BETWEEN s1 AND s2) AS fishing
      FROM m GROUP BY vid, time)
    SELECT p.*,
           coalesce(a.n_sid, 0) AS n_sid,
           CASE WHEN a.n_sid = 1 THEN a.sid END AS sid,
           CASE WHEN a.n_sid = 1 THEN a.schema END AS schema,
           CASE WHEN a.n_sid = 1 THEN a.tid END AS tid,
           CASE WHEN a.n_sid = 1 THEN a.gear END AS gear,
           CASE WHEN a.n_sid = 1 THEN a.gear_class END AS gear_class,
           CASE WHEN a.n_sid = 1 THEN a.phase END AS phase,
           CASE WHEN a.n_sid = 1 THEN a.phase_frac END AS phase_frac,
           CASE WHEN a.n_sid = 1 THEN a.win_basis END AS win_basis,
           CASE WHEN a.n_sid = 1 THEN a.events END AS events,
           coalesce(a.fishing, false) AS fishing
    FROM (SELECT * FROM %s WHERE true %s) p LEFT JOIN a USING (vid, time)
    %s", matches, pings, vfilter, if (sorted) "ORDER BY p.vid, p.time" else "")

  con <- duckdbfs::cached_connection()
  # A year of fixes sorts past memory and DuckDB spills to disk; its default spill
  # directory is under the R session's tempdir and is not always there.
  spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
  DBI::dbExecute(con, sprintf("SET temp_directory = '%s'", spill))
  dplyr::tbl(con, dplyr::sql(sql))
}
