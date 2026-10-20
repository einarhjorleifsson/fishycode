# allocation_audit.R — is every link the flow makes between two records borne out by the records' own times?
# Side: flow, check. See plan 014.
#
# Input:  curated/logbook/{trip,station,fishing_sample,lid_map}.parquet, curated/logbook/catch.parquet
#         curated/ais/{voyage,port_call}.parquet, curated/link/trip_voyage.parquet
#         curated/ais/trail/   (the fixes on a station, with the trip their voyage names)
#         curated/ais/catch/   (the catch on the fixes)
# Output: curated/check/allocation_audit.parquet   one row per (link, year, schema, detail, outcome):
#         amount, unit (records or kg), share of its (link, year, schema, detail), ok (TRUE consistent, FALSE not,
#         NA cannot be judged)
#
# The method (2026-10-20, after decision 154). Each link is a child record placed in a parent: a station in a trip,
# a trip on a voyage, a fix on a station, a trip on a landing, a kilogram on a fix. The child's own time is a witness
# the link did not use, so the link can be tested by whether that time lies in the parent. Every child is counted
# in exactly one outcome, the inconsistent and the unjudgeable included: a check that compares two links only where
# both exist hides the rest. trail_agreement.R reported 99.5 % agreement between a fix's station trip and its
# voyage's trip while 8.8 % of the fixes on a station never reached the comparison, their voyage naming no trip;
# that was a station placed by its trip on a voyage it was not fished in ($FISHYDATA/archive/2026-10-voyage-gear/).
#
#   station_voyage  a station with a time of day (t1-t4, not 00:00): in its trip's voyage, in another voyage, in a
#                   voyage while its trip is on none, in a port call of its vessel, or in neither (no track)
#   station_voyage_gear  a timed station in a voyage (by its time): the voyage's gear is the logbook's and the
#                   station's gear label, the logbook's but another (several gears), ambiguous, a landing's, or none
#   fix_trip        a fix on one timed station (not a day window): its voyage names the station's trip, another
#                   trip, several trips (shared), or none; or the fix is in no voyage
#   station_trip    a station's date against its trip's days, T1 to T2
#   trip_landing    a trip matched to a landing (detail: lid_map's match_type): the landing against the end of the
#                   voyage holding the trip's last timed station: on its end day (or the next) at the same port, at
#                   another, landed before that voyage ended (a port call missed), over a day after, or no voyage
#   catch           logged kilograms (duplicates left out) and landed kilograms of landings with no logbook trip,
#                   against ais_catch's (approach fishing_flow): on fixes, on a unit with no fix, on a station with no
#                   window (lost: a station's catch enters ais_catch through its window), deleted in the source (left
#                   out by design), or another difference (a haul over New Year, signed)
# Duplicate twin stations and trips (decision 094) and stations deleted in the source (`eytt_deleted`) are left out
# of the station links. A station's year is its date's, a fix's its own.

con <- DBI::dbConnect(duckdb::duckdb())
f <- function(...) sprintf("read_parquet('%s')", fd_curated(...))
x <- function(...) invisible(DBI::dbExecute(con, sprintf(...)))
tod <- function(c) sprintf("CASE WHEN %s IS NOT NULL AND CAST(%s AS TIME) <> TIME '00:00:00' THEN %s END", c, c, c)
trail <- sprintf("read_parquet('%s', hive_partitioning = true)", file.path(fd_curated("ais", "trail"), "*", "*", "*.parquet"))
acatch <- sprintf("read_parquet('%s', hive_partitioning = true)", file.path(fd_curated("ais", "catch"), "*", "*.parquet"))

# The records, one step at a time (one query over all of them can make DuckDB plan a join on schema alone)
x("CREATE TEMP TABLE t AS SELECT \".tid\" AS tid, schema, any_value(vid) AS vid, any_value(T1) AS T1, any_value(T2) AS T2
   FROM %s WHERE twin IS DISTINCT FROM 'duplicate' GROUP BY 1, 2 HAVING count(DISTINCT vid) <= 1", f("logbook", "trip.parquet"))
x("CREATE TEMP TABLE s AS SELECT st.\".sid\" AS sid, st.\".tid\" AS tid, st.schema, st.date, coalesce(%s, %s, %s, %s) AS ts
   FROM %s st JOIN %s fs ON fs.\".sid\" = st.\".sid\" AND fs.schema = st.schema
   WHERE st.twin IS DISTINCT FROM 'duplicate' AND NOT coalesce(fs.eytt_deleted, false)",
  tod("fs.t1"), tod("fs.t2"), tod("fs.t3"), tod("fs.t4"), f("logbook", "station.parquet"), f("logbook", "fishing_sample.parquet"))
x("CREATE TEMP TABLE sv AS SELECT s.*, t.vid FROM s JOIN t USING (tid, schema) WHERE t.vid IS NOT NULL")
x("CREATE TEMP TABLE v AS SELECT vid, year, voyage_id, T1, T2, pid2 FROM %s", f("ais", "voyage.parquet"))
x("CREATE TEMP TABLE pc AS SELECT vid, T_in, T_out FROM %s", f("ais", "port_call.parquet"))
x("CREATE TEMP TABLE tv AS SELECT \".tid\" AS tid, schema, year, voyage_id FROM %s", f("link", "trip_voyage.parquet"))
# a vessel's voyages, and its port calls, do not overlap: the last to start by a time, if it has not ended
x("CREATE TEMP TABLE sv_v AS SELECT sv.sid, sv.schema, v.year AS vy, v.voyage_id AS vv FROM sv ASOF JOIN v ON sv.vid = v.vid AND sv.ts >= v.T1
   WHERE sv.ts IS NOT NULL AND sv.ts <= v.T2")
x("CREATE TEMP TABLE sv_p AS SELECT sv.sid, sv.schema FROM sv ASOF JOIN pc ON sv.vid = pc.vid AND sv.ts >= pc.T_in
   WHERE sv.ts IS NOT NULL AND sv.ts <= pc.T_out")

out <- list()
# station_voyage ---------------------------------------------------------------
out$station_voyage <- DBI::dbGetQuery(con, "
  SELECT 'station_voyage' AS link, year(sv.date) AS year, sv.schema, NULL AS detail,
         CASE WHEN sv.ts IS NULL THEN 'no time of day'
              WHEN a.vv IS NOT NULL AND tv.tid IS NULL THEN 'in a voyage, its trip on none'
              WHEN a.vv IS NOT NULL AND a.vy = tv.year AND a.vv = tv.voyage_id THEN 'in its trip''s voyage'
              WHEN a.vv IS NOT NULL THEN 'in another voyage'
              WHEN p.sid IS NOT NULL THEN 'in a port call'
              ELSE 'in no voyage or port call' END AS outcome, count(*) AS amount
  FROM sv LEFT JOIN sv_v a USING (sid, schema) LEFT JOIN sv_p p USING (sid, schema)
  LEFT JOIN tv USING (tid, schema) GROUP BY ALL")

# fix_trip ---------------------------------------------------------------------
out$fix_trip <- DBI::dbGetQuery(con, sprintf("
  SELECT 'fix_trip' AS link, year, schema, NULL AS detail,
         CASE WHEN voyage_id IS NULL THEN 'fix in no voyage' WHEN n_tid_voyage = 0 THEN 'voyage names no trip'
              WHEN n_tid_voyage > 1 THEN 'voyage shared by trips'
              WHEN \".tid\" = \".tid_voyage\" AND schema = schema_voyage THEN 'voyage names the same trip'
              ELSE 'voyage names another trip' END AS outcome, count(*) AS amount
  FROM %s WHERE n_sid = 1 AND phase <> 'day' GROUP BY ALL", trail))

# station_voyage_gear ----------------------------------------------------------
# a timed station in a voyage (by its time): does the voyage take its gear from the logbook, and the same gear label?
x("CREATE TEMP TABLE gr AS SELECT DISTINCT ON (gid) CAST(gid AS INTEGER) AS gid, gear || '_' || coalesce(target2, '') AS metier
   FROM %s WHERE version = 'new' AND gear IS NOT NULL ORDER BY gid", f("reference", "gear.parquet"))
out$station_voyage_gear <- DBI::dbGetQuery(con, sprintf("
  SELECT 'station_voyage_gear' AS link, year(sv.date) AS year, sv.schema, NULL AS detail,
         CASE WHEN vg.gear_voyage_basis = 'logbook' AND gv.metier = g.metier THEN 'voyage gear is the logbook''s, the same'
              WHEN vg.gear_voyage_basis = 'logbook' THEN 'voyage gear is the logbook''s, another'
              WHEN vg.gear_voyage_basis = 'ambiguous' THEN 'voyage gear ambiguous'
              WHEN vg.gear_voyage_basis = 'landing' THEN 'voyage gear from a landing'
              ELSE 'voyage has no gear' END AS outcome, count(*) AS amount
  FROM sv JOIN sv_v a USING (sid, schema)
  JOIN %s g ON g.\".sid\" = sv.sid AND g.schema = sv.schema
  JOIN %s vg ON vg.vid = sv.vid AND vg.year = a.vy AND vg.voyage_id = a.vv
  LEFT JOIN gr gv ON gv.gid = vg.gid_voyage
  WHERE g.gid_used IS NOT NULL GROUP BY ALL", f("logbook", "gear.parquet"), f("ais", "voyage_gear.parquet")))

# station_trip -----------------------------------------------------------------
out$station_trip <- DBI::dbGetQuery(con, "
  SELECT 'station_trip' AS link, year(s.date) AS year, s.schema, NULL AS detail,
         CASE WHEN t.T1 IS NULL OR t.T2 IS NULL OR s.date IS NULL THEN 'trip or station undated'
              WHEN s.date < CAST(t.T1 AS DATE) - 1 OR s.date > CAST(t.T2 AS DATE) + 1 THEN 'over a day outside its trip'
              WHEN s.date < CAST(t.T1 AS DATE) OR s.date > CAST(t.T2 AS DATE) THEN 'a day outside its trip'
              ELSE 'inside its trip' END AS outcome, count(*) AS amount
  FROM s JOIN t USING (tid, schema) GROUP BY ALL")

# trip_landing -----------------------------------------------------------------
x("CREATE TEMP TABLE lastst AS SELECT tid, schema, vid, max(ts) AS ts FROM sv GROUP BY ALL")
x("CREATE TEMP TABLE lv AS SELECT l.tid, l.schema, l.ts, v.T2 AS vT2, v.pid2 FROM lastst l ASOF LEFT JOIN v ON l.vid = v.vid AND l.ts >= v.T1")
out$trip_landing <- DBI::dbGetQuery(con, sprintf("
  SELECT 'trip_landing' AS link, year(m.date_land) AS year, m.schema, m.match_type AS detail,
         CASE WHEN lv.ts IS NULL THEN 'no timed station'
              WHEN lv.vT2 IS NULL OR lv.ts > lv.vT2 THEN 'last station in no voyage'
              WHEN m.date_land < CAST(lv.vT2 AS DATE) THEN 'landed before the voyage ended'
              WHEN m.date_land > CAST(lv.vT2 AS DATE) + 1 THEN 'landed over a day after the voyage ended'
              WHEN m.pid_land IS NULL OR lv.pid2 IS NULL THEN 'voyage end day, a port unknown'
              WHEN m.pid_land = lv.pid2 THEN 'voyage end day, same port' ELSE 'voyage end day, another port' END AS outcome,
         count(*) AS amount
  FROM %s m LEFT JOIN lv ON lv.tid = m.\".tid\" AND lv.schema = m.schema GROUP BY ALL", f("logbook", "lid_map.parquet")))

# catch ------------------------------------------------------------------------
# A station's catch enters ais_catch through its window; a station deleted in the source has none by design.
given <- DBI::dbGetQuery(con, sprintf("
  WITH sw AS (SELECT DISTINCT \".sid\" AS sid, schema FROM %s)
  SELECT 'logbook' AS schema, year(st.date) AS year,
         sum(CAST(c.catch AS DOUBLE)) FILTER (WHERE coalesce(fs.eytt_deleted, false)) AS deleted,
         sum(CAST(c.catch AS DOUBLE)) FILTER (WHERE NOT coalesce(fs.eytt_deleted, false) AND sw.sid IS NULL) AS no_window,
         sum(CAST(c.catch AS DOUBLE)) FILTER (WHERE NOT coalesce(fs.eytt_deleted, false) AND sw.sid IS NOT NULL) AS kg
  FROM %s c JOIN %s st ON st.\".sid\" = c.\".sid\" AND st.schema = c.schema
  JOIN %s fs ON fs.\".sid\" = c.\".sid\" AND fs.schema = c.schema
  LEFT JOIN sw ON sw.sid = c.\".sid\" AND sw.schema = c.schema
  WHERE st.twin IS DISTINCT FROM 'duplicate' GROUP BY ALL
  UNION ALL
  SELECT 'landing', year(l.date), 0, 0, sum(c.catch) FROM %s l JOIN %s c ON c.\".lid\" = l.\".lid\" AND c.schema = l.schema
  WHERE NOT EXISTS (SELECT 1 FROM %s m WHERE m.\".lid\" = l.\".lid\" AND m.schema_land = l.schema) GROUP BY ALL",
  f("logbook", "station_window.parquet"), f("logbook", "catch.parquet"), f("logbook", "station.parquet"),
  f("logbook", "fishing_sample.parquet"), f("landing", "landings.parquet"), f("landing", "catch.parquet"),
  f("logbook", "lid_map.parquet")))
placed <- DBI::dbGetQuery(con, sprintf("
  SELECT source AS schema, year, sum(kg) FILTER (WHERE catch_basis IS DISTINCT FROM 'none') AS on_fixes,
         sum(kg) FILTER (WHERE catch_basis = 'none') AS no_fix
  FROM %s WHERE approach = 'fishing_flow' GROUP BY ALL", acatch))
k <- merge(given, placed, by = c("schema", "year"), all = TRUE)
k[is.na(k)] <- 0
k <- k[k$year >= min(placed$year), ]
# a station's year is its date's, a fix's its own: a haul over New Year moves kilograms between years, so the
# difference is kept signed (in by-year rows, not in the totals)
out$catch <- rbind(
  data.frame(link = "catch", year = k$year, schema = k$schema, detail = NA, outcome = "on fixes", amount = k$on_fixes),
  data.frame(link = "catch", year = k$year, schema = k$schema, detail = NA, outcome = "on a unit with no fix", amount = k$no_fix),
  data.frame(link = "catch", year = k$year, schema = k$schema, detail = NA, outcome = "a station with no window", amount = k$no_window),
  data.frame(link = "catch", year = k$year, schema = k$schema, detail = NA, outcome = "deleted in the source", amount = k$deleted),
  data.frame(link = "catch", year = k$year, schema = k$schema, detail = NA, outcome = "other difference",
             amount = k$kg - k$on_fixes - k$no_fix))
out$catch <- out$catch[out$catch$amount != 0, ]

# assemble ---------------------------------------------------------------------
ok_out <- c("in its trip's voyage", "voyage names the same trip", "inside its trip", "voyage end day, same port", "on fixes",
            "on a unit with no fix", "voyage gear is the logbook's, the same")
na_out <- c("no time of day", "deleted in the source", "voyage gear ambiguous", "in no voyage or port call", "trip or station undated", "no timed station",
            "voyage end day, a port unknown", "voyage shared by trips")
res <- do.call(rbind, lapply(out, function(d) { d$detail <- as.character(d$detail); d })) |>
  dplyr::mutate(year = as.integer(year), amount = as.numeric(amount),
                unit = ifelse(link == "catch", "kg", "records"),
                ok = dplyr::case_when(outcome %in% ok_out ~ TRUE, outcome %in% na_out ~ NA, .default = FALSE)) |>
  dplyr::mutate(share = amount / sum(amount), .by = c(link, year, schema, detail)) |>
  dplyr::arrange(link, year, schema, detail, dplyr::desc(amount))
print(res |> dplyr::summarise(amount = sum(amount), .by = c(link, outcome, ok)) |>
        dplyr::mutate(share = round(amount / sum(amount), 4), .by = link) |> as.data.frame(), right = FALSE)
res |> write_curated(fd_curated("check", "allocation_audit.parquet"),
                     inputs = c(fd_curated("logbook", "trip.parquet"), fd_curated("logbook", "station.parquet"),
                                fd_curated("logbook", "fishing_sample.parquet"), fd_curated("logbook", "lid_map.parquet"),
                                fd_curated("logbook", "catch.parquet"), fd_curated("logbook", "station_window.parquet"),
                                fd_curated("landing", "landings.parquet"),
                                fd_curated("landing", "catch.parquet"), fd_curated("ais", "voyage.parquet"),
                                fd_curated("ais", "port_call.parquet"), fd_curated("link", "trip_voyage.parquet"),
                                fd_curated("ais", "voyage_gear.parquet"), fd_curated("logbook", "gear.parquet"),
                                fd_curated("reference", "gear.parquet")))
DBI::dbDisconnect(con, shutdown = TRUE)
