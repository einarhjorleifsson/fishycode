# trail_sql.R — the SQL that attaches logbook evidence to a month of fixes.
#
# Used by curate/ais_trail.R only. Plan 010 §3 (how a fix finds its station) and plan 011 Phase 5 (how it finds
# its logbook trip through the voyage). Function definitions only; nothing runs on load.
#
# The station rules are ramb's (plan 014 phase 2, an exact port of what stood here): rb_link_record_pings() makes
# the matches, rb_assign_fishing(method = "window") and rb_assign_record() put them on the fixes. This file
# supplies the month's inputs, the voyage side and fishycode's column names (`n_sid` is ramb's `n_records`).
#
# A fix matches every station window of its vessel that contains its time; windows are half-open, [w_start,
# w_end). Windows come in tiers and a lower tier only claims fixes no higher tier claims: tier 1 = tow | haul |
# set | jig (logbook times), tier 2 = day (the whole station date, used when a station has no usable time). Tier-1
# windows of a vessel never overlap (decision 091), so only day windows leave a fix with several stations, and
# trail_match is a table of candidates there. What stays ambiguous stays ambiguous:
# `n_sid` counts the stations and `.sid`/`.tid`/`phase` are filled only when exactly one station claims the fix.
# A station matched in two of its own phases counts once, haul > tow > jig > set > day.
# Keys: `.sid` and `.tid` are unique only within a schema, so the station is (.sid, schema).
# `fishing` is TRUE when a tow, haul, jig or day window holds the fix and its speed is inside that gear's [s1, s2];
# a set is never fishing. It is NA when such a window holds the fix but the fix has no speed (a logger fix with no
# speed, or the 1.000 m/s placeholder, plan 012 §2f): unknown, not FALSE. FALSE for a fix in no window.
#
# The voyage side: `trip_voyage` links a logbook trip to the AIS voyage (vid, year, voyage) it overlaps most.
# Several logbook trips may share one voyage (3-4 %), so `.tid_voyage` is filled only when exactly one trip is on
# the voyage, and `n_tid_voyage` counts them (0 = no logbook trip on this voyage or the fix is in no voyage).
#
# The station's gear codes come from curated/logbook/gear.parquet under the names they have there (TODO 34,
# question 3): `gid` the logbook's, `gid_landing` the landing's, `gid_used` the one the windows use, `gid_basis`.
# Like every station column they are filled only when one station claims the fix.
#
# `nearest_event` names the event times this fix bounds, from curated/link/station_event (TODO 54, decision 088):
# the first fix of a setting (t1) or hauling (t3), the last of a setting (t2) or hauling (t4); `t3+t4` for a haul of
# one fix. They belong to one station and one phase: when two events would share a fix, the nearer keeps it
# (decision 091). NA otherwise. The station, the time difference and the gap are in that table. The name stayed
# from the first rule, the nearest fix.

trail_month_sql <- function(con, year, month, kind = c("wide", "match"), matches = NULL) {
  kind <- match.arg(kind)
  t0 <- sprintf("TIMESTAMP '%d-%02d-01'", year, month)
  t1 <- if (month == 12) sprintf("TIMESTAMP '%d-01-01'", year + 1L) else sprintf("TIMESTAMP '%d-%02d-01'", year, month + 1L)
  # every part of the year: curated/ais/ping is written in batches (plan 014; ping_trail had one file per year)
  pfile <- shQuote(file.path(fd_curated("ais", "ping"), paste0("year=", year), "*.parquet"), type = "sh")
  swf   <- shQuote(fd_curated("logbook", "station_window.parquet"), type = "sh")
  tvf   <- shQuote(fd_curated("link", "trip_voyage.parquet"), type = "sh")
  gf    <- shQuote(fd_curated("logbook", "gear.parquet"), type = "sh")
  sef   <- shQuote(fd_curated("link", "station_event.parquet"), type = "sh")
  lazy  <- function(q) dplyr::tbl(con, dplyr::sql(q))
  rend  <- function(x) as.character(dbplyr::sql_render(x))

  p <- lazy(sprintf("SELECT * EXCLUDE (year, pid) FROM read_parquet(%s) WHERE time >= %s AND time < %s", pfile, t0, t1))
  carry <- c(".tid", "metier", "gear", "target", "target2", "gear_class", "win_basis", "events")

  if (kind == "match") {
    w <- lazy(sprintf("SELECT * FROM read_parquet(%s) WHERE w_end >= %s AND w_start < %s", swf, t0, t1))
    m <- ramb::rb_link_record_pings(p, w, key = c(".sid", "schema"), carry = carry,
                                    speed_min = "s1", speed_max = "s2")
    return(sprintf("
      SELECT vid, time, \".sid\", schema, \".tid\", metier, gear, target, target2, gear_class, phase, phase_frac,
             win_basis, events, s1, s2, w_start, w_end, fishing
      FROM (%s)", rend(m)))
  }

  # the wide row reads the month's matches back from trail_match, written just before it
  m <- lazy(sprintf("SELECT * FROM read_parquet(%s)", shQuote(matches, type = "sh")))
  r <- p |>
    ramb::rb_assign_fishing(m, method = "window", speed_min = "s1", speed_max = "s2") |>
    ramb::rb_assign_record(m, key = c(".sid", "schema"), carry = c(carry[1:6], "s1", "s2", "win_basis", "events"))
  sprintf("
    WITH v AS (
      SELECT vid, year, voyage, count(*) AS n_tid_voyage,
             CASE WHEN count(*) = 1 THEN any_value(\".tid\") END AS tid_v,
             CASE WHEN count(*) = 1 THEN any_value(schema) END AS schema_v
      FROM read_parquet(%s) WHERE year = %d GROUP BY vid, year, voyage),
    g AS (SELECT \".sid\", schema, gid, gid_landing, gid_used, gid_basis FROM read_parquet(%s)),
    e AS (SELECT vid, time, array_to_string(list_sort(list_distinct(list(event))), '+') AS nearest_event
          FROM read_parquet(%s) WHERE time >= %s AND time < %s GROUP BY vid, time),
    r AS (%s)
    SELECT r.vid, r.mmsi, r.time, r.lon, r.lat, r.speed, r.speed_raw, r.heading, r.cog, r.provider,
           r.pos_basis, r.speed_basis, r.dt_sec, r.stay, r.voyage,
           v.tid_v AS \".tid_voyage\", v.schema_v AS schema_voyage, coalesce(v.n_tid_voyage, 0) AS n_tid_voyage,
           r.n_records AS n_sid, r.\".sid\", r.schema, r.\".tid\", r.metier, r.gear, r.target, r.target2,
           g.gid, g.gid_landing, g.gid_used, g.gid_basis, r.gear_class,
           r.s1, r.s2, r.phase, r.phase_frac, r.win_basis, r.events, e.nearest_event, r.fishing, r.sid_gps, r.n_sid_gps
    FROM r LEFT JOIN v ON v.vid = r.vid AND v.voyage = r.voyage
           LEFT JOIN g ON g.\".sid\" = r.\".sid\" AND g.schema = r.schema
           LEFT JOIN e ON e.vid = r.vid AND e.time = r.time",
    tvf, year, gf, sef, t0, t1, rend(r))
}
