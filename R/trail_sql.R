# trail_sql.R — the SQL that attaches logbook evidence to a month of fixes.
#
# Used by curate/ais_trail.R only. Plan 010 §3 (how a fix finds its station) and plan 011 Phase 5 (how it finds
# its logbook trip through the voyage). Function definitions only; nothing runs on load.
#
# The station rules are ramb's (plan 014 phase 2, an exact port of what stood here): rb_link_record_pings() makes
# the matches, rb_assign_fishing(method = "window") and rb_assign_record() put them on the fixes. This file
# supplies the month's inputs, the voyage side and fishycode's column names (`n_sid` is ramb's `n_records`).
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

trail_month_sql <- function(con, year, month, kind = c("wide", "match"), matches = NULL) {
  kind <- match.arg(kind)
  t0 <- sprintf("TIMESTAMP '%d-%02d-01'", year, month)
  t1 <- if (month == 12) sprintf("TIMESTAMP '%d-01-01'", year + 1L) else sprintf("TIMESTAMP '%d-%02d-01'", year, month + 1L)
  pfile <- shQuote(file.path(fd_curated("ais", "ping_trail"), paste0("year=", year), "part_001.parquet"), type = "sh")
  swf   <- shQuote(fd_curated("logbook", "station_window.parquet"), type = "sh")
  tvf   <- shQuote(fd_curated("link", "trip_voyage.parquet"), type = "sh")
  lazy  <- function(q) dplyr::tbl(con, dplyr::sql(q))
  rend  <- function(x) as.character(dbplyr::sql_render(x))

  p <- lazy(sprintf("SELECT * EXCLUDE (year, pid) FROM read_parquet(%s) WHERE time >= %s AND time < %s", pfile, t0, t1))
  carry <- c(".tid", "gear", "target", "target2", "gear_class", "win_basis", "events")

  if (kind == "match") {
    w <- lazy(sprintf("SELECT * FROM read_parquet(%s) WHERE w_end >= %s AND w_start < %s", swf, t0, t1))
    m <- ramb::rb_link_record_pings(p, w, key = c(".sid", "schema"), carry = carry,
                                    speed_min = "s1", speed_max = "s2")
    return(sprintf("
      SELECT vid, time, \".sid\", schema, \".tid\", gear, target, target2, gear_class, phase, phase_frac,
             win_basis, events, s1, s2, w_start, w_end, fishing
      FROM (%s)", rend(m)))
  }

  # the wide row reads the month's matches back from trail_match, written just before it
  m <- lazy(sprintf("SELECT * FROM read_parquet(%s)", shQuote(matches, type = "sh")))
  r <- p |>
    ramb::rb_assign_fishing(m, method = "window", speed_min = "s1", speed_max = "s2") |>
    ramb::rb_assign_record(m, key = c(".sid", "schema"), carry = c(carry[1:5], "s1", "s2", "win_basis", "events"))
  sprintf("
    WITH v AS (
      SELECT vid, year, trip, count(*) AS n_tid_voyage,
             CASE WHEN count(*) = 1 THEN any_value(\".tid\") END AS tid_v,
             CASE WHEN count(*) = 1 THEN any_value(schema) END AS schema_v
      FROM read_parquet(%s) WHERE year = %d GROUP BY vid, year, trip),
    r AS (%s)
    SELECT r.vid, r.mmsi, r.time, r.lon, r.lat, r.speed, r.speed_raw, r.heading, r.cog, r.provider,
           r.pos_basis, r.speed_basis, r.speed_gps, r.dt_sec, r.stay_pid, r.trip,
           v.tid_v AS \".tid_voyage\", v.schema_v AS schema_voyage, coalesce(v.n_tid_voyage, 0) AS n_tid_voyage,
           r.n_records AS n_sid, r.\".sid\", r.schema, r.\".tid\", r.gear, r.target, r.target2, r.gear_class,
           r.s1, r.s2, r.phase, r.phase_frac, r.win_basis, r.events, r.fishing, r.sid_gps, r.n_sid_gps
    FROM r LEFT JOIN v ON v.vid = r.vid AND v.trip = r.trip",
    tvf, year, rend(r))
}
