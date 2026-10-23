# trip_reconciled.R — every logbook trip's departure and return, time and port, from ranked witnesses.
# Side: flow, step 1. See plan 014.
#
# Input:  curated/logbook/trip.parquet         (.tid, schema, vid, T1, T2, hid1, pid1, hid2, pid2, twin)
#         curated/logbook/station.parquet      (.sid, .tid, schema, twin)
#         curated/logbook/fishing_sample.parquet (.sid, schema, t1..t4, eytt_deleted: the station's own times)
#         curated/ais/voyage.parquet           (vid, year, voyage_id, T1, T2, pid1, pid2)
#         curated/link/trip_voyage.parquet     (T1_ais, T2_ais, pid1_ais, pid2_ais: the AIS voyage linked to the trip)
#         curated/logbook/lid_map.parquet      (the trip's landing: date_land, hid_land, pid_land, n_trips)
#         staging/stk/voyage.parquet           (STK's recorded voyages)
#         staging/quota_trip/trip.parquet      (the quota system's trip records, keyed by landing)
#         staging/phone_call/call.parquet      (phone notifications)
#         curated/reference/port.parquet       (adb's port number -> pid)
# Output: curated/link/trip_reconciled.parquet  one row per logbook trip (twins left out): .tid, schema, vid; T1, pid1,
#         T2, pid2, each with _from, _basis, _n, _outcome (times also _day, _spread_s); each witness's own values
#         (T1_<w>, pid1_<w>, T2_<w>, pid2_<w>); the AIS witness's n_voyage_ais, ais_basis and ais_flag
#
# Decisions 173, 174, TODO 121. The maintainer's ranking (2026-10-22), the same for both ends: the AIS voyage, then the
# logbook's own, then STK, the quota system's records and the phone calls; the landing register witnesses the return
# only, last. Time and port are each taken from the best witness that holds one (ramb::rb_add_trip_time()); a value
# that is a date only (`day`: a logbook time at midnight, the landing day) gives way to a time on that day, and every
# trip falls in one outcome per field. The witnesses:
#   ais      the voyages the trip's stations lie in by their own times (t1-t4, not 00:00; voyage_gear.R's link,
#            decision 155): the first one's departure and the last one's return, where there are two or more
#            (ais_basis "stations"). Otherwise the voyage rb_link_trip_voyages() linked to the trip (trip_voyage,
#            "trip_voyage"). Until decision 193 every trip took that one voyage, so a trip that spans several had one
#            voyage's bounds (decision 191). n_voyage_ais counts the voyages. Where a voyage within the span holds
#            another trip (a station by time, or its linked voyage), the span would overlap it: the linked voyage stays
#            and ais_flag is "overlap" (TODO 102).
#   own      the logbook's times and ports. T1 from fs_afladagbok and adb only: afli's T1 is the first fishing day,
#            not a departure. T2 from afli too (its landing day). aflaskeyti's are synthesised from the landings.
#            adb's port 0 is a placeholder (decision 172), not a port.
#   stk      the latest STK voyage that contains the trip (out by T1's day, in on or after T2's day, within 60 days),
#            its out and in together
#   quota    the record of the trip's landing (lid_map, a landing no other trip claims), its departure on or before the
#            landing day
#   phone    the latest valid out-call on T1's day or up to 3 days before, no later than T2's day; the latest valid
#            in-call on T2's day or up to 3 days before, no earlier than T1
#   landing  the trip's landing (lid_map): its day and port
# A trip that no witness covers is kept, with NA values and basis "none".

library(DBI)
library(duckdb)

RANK1 <- c("ais", "own", "stk", "quota", "phone")
RANK2 <- c(RANK1, "landing")
BASIS <- c(ais = "reconstructed", own = "recorded", stk = "recorded", quota = "recorded", phone = "recorded",
           landing = "recorded")
TOLERANCE_S <- 3600

con <- dbConnect(duckdb())
inputs <- c(trip = fd_curated("logbook", "trip.parquet"), voyage = fd_curated("link", "trip_voyage.parquet"),
            lid = fd_curated("logbook", "lid_map.parquet"), stk = fd_staging("stk", "voyage.parquet"),
            quota = fd_staging("quota_trip", "trip.parquet"), phone = fd_staging("phone_call", "call.parquet"),
            port = fd_curated("reference", "port.parquet"), station = fd_curated("logbook", "station.parquet"),
            sample = fd_curated("logbook", "fishing_sample.parquet"), ais = fd_curated("ais", "voyage.parquet"))
dbExecute(con, sprintf("CREATE TEMP TABLE trip AS SELECT \".tid\", schema, vid, T1, T2, hid1, pid1, hid2, pid2
                        FROM read_parquet('%s') WHERE twin IS DISTINCT FROM 'duplicate'", inputs[["trip"]]))
dbExecute(con, sprintf("CREATE TEMP TABLE port AS SELECT hid, pid FROM read_parquet('%s')", inputs[["port"]]))

# The AIS witness: the voyages the trip's stations lie in, by their own times ----------
# As voyage_gear.R, one step at a time: duplicate twin stations and stations deleted in the source left out; a
# vessel's voyages do not overlap, so a time is in the last voyage to start by it, if that has not ended.
dbExecute(con, sprintf("CREATE TEMP TABLE v AS SELECT vid, year, voyage_id, T1, T2, pid1, pid2 FROM read_parquet('%s')",
                       inputs[["ais"]]))
dbExecute(con, sprintf("CREATE TEMP TABLE st AS SELECT s.\".tid\", s.schema, t.vid, fs.t1, fs.t2, fs.t3, fs.t4
  FROM read_parquet('%s') s JOIN read_parquet('%s') fs ON fs.\".sid\" = s.\".sid\" AND fs.schema = s.schema
  JOIN trip t ON t.\".tid\" = s.\".tid\" AND t.schema = s.schema
  WHERE s.twin IS DISTINCT FROM 'duplicate' AND NOT coalesce(fs.eytt_deleted, false) AND t.vid IS NOT NULL",
  inputs[["station"]], inputs[["sample"]]))
dbExecute(con, "CREATE TEMP TABLE sv AS
  WITH ev AS (SELECT * FROM (SELECT \".tid\", schema, vid, unnest([t1, t2, t3, t4]) AS ts FROM st)
              WHERE ts IS NOT NULL AND CAST(ts AS TIME) <> TIME '00:00:00')
  SELECT DISTINCT ev.\".tid\", ev.schema, v.vid, v.year, v.voyage_id, v.T1, v.T2, v.pid1, v.pid2
  FROM ev ASOF JOIN v ON ev.vid = v.vid AND ev.ts >= v.T1 WHERE ev.ts <= v.T2")
dbExecute(con, "CREATE TEMP TABLE span AS SELECT \".tid\", schema, any_value(vid) AS vid, count(*) AS n,
  min(T1) AS T1, arg_min(pid1, T1) AS pid1, max(T2) AS T2, arg_max(pid2, T2) AS pid2 FROM sv GROUP BY ALL")
# A voyage within the span that holds another trip: one of its stations by time, or the voyage it is linked to (a
# trip whose stations carry dates only is seen through its link alone). Mostly a static gear set on the earlier
# trip's voyage, or afli's hauls of a landing day put on the next trip (decision 193); which trip the voyage is is
# not judged here.
dbExecute(con, sprintf("CREATE TEMP TABLE overlap AS
  WITH other AS (SELECT \".tid\", schema, vid, T1 FROM sv
                 UNION ALL SELECT \".tid\", schema, vid, T1_ais FROM read_parquet('%s'))
  SELECT DISTINCT s.\".tid\", s.schema FROM span s
  JOIN other o ON o.vid = s.vid AND o.T1 BETWEEN s.T1 AND s.T2 AND (o.\".tid\" <> s.\".tid\" OR o.schema <> s.schema)
  WHERE s.n >= 2", inputs[["voyage"]]))
dbExecute(con, sprintf("CREATE TEMP TABLE ais AS
  SELECT t.\".tid\", t.schema, coalesce(s.n, 0) AS n_voyage_ais,
         CASE WHEN s.n >= 2 AND o.\".tid\" IS NULL THEN 'stations' WHEN tv.\".tid\" IS NOT NULL THEN 'trip_voyage' END AS ais_basis,
         CASE WHEN o.\".tid\" IS NOT NULL THEN 'overlap' END AS ais_flag,
         CASE WHEN s.n >= 2 AND o.\".tid\" IS NULL THEN s.T1 ELSE tv.T1_ais END AS T1,
         CASE WHEN s.n >= 2 AND o.\".tid\" IS NULL THEN s.pid1 ELSE tv.pid1_ais END AS pid1,
         CASE WHEN s.n >= 2 AND o.\".tid\" IS NULL THEN s.T2 ELSE tv.T2_ais END AS T2,
         CASE WHEN s.n >= 2 AND o.\".tid\" IS NULL THEN s.pid2 ELSE tv.pid2_ais END AS pid2
  FROM trip t LEFT JOIN span s USING (\".tid\", schema) LEFT JOIN overlap o USING (\".tid\", schema)
  LEFT JOIN read_parquet('%s') tv USING (\".tid\", schema)", inputs[["voyage"]]))

# The witnesses, one row per trip, end and witness --------------------------------
midnight <- function(x) sprintf("(%1$s = date_trunc('day', %1$s))", x)
dbExecute(con, sprintf("
CREATE TEMP TABLE witness AS
WITH stk AS (
  SELECT t.\".tid\", t.schema, s.T1, s.pid1, s.T2, s.pid2 FROM trip t
  JOIN read_parquet('%s') s ON s.vid = t.vid AND CAST(s.T1 AS DATE) <= CAST(t.T1 AS DATE)
   AND CAST(s.T2 AS DATE) >= CAST(t.T2 AS DATE) AND s.T1 >= t.T1 - INTERVAL 60 DAY
  QUALIFY row_number() OVER (PARTITION BY t.\".tid\", t.schema ORDER BY s.T1 DESC) = 1),
lid AS (
  SELECT m.\".tid\", m.schema, t.vid, t.T1, m.date_land, m.hid_land, m.pid_land, m.n_trips FROM read_parquet('%s') m
  JOIN trip t ON t.\".tid\" = m.\".tid\" AND t.schema = m.schema),
quota AS (
  SELECT l.\".tid\", l.schema, q.T1, q.pid1, q.T2, q.pid2 FROM lid l
  JOIN read_parquet('%s') q ON q.vid = l.vid AND q.date = l.date_land AND q.hid = l.hid_land
  WHERE l.n_trips = 1 AND q.invalid IS NOT TRUE AND q.T1 IS NOT NULL
    AND q.T1 < CAST(l.date_land AS TIMESTAMP) + INTERVAL 1 DAY AND q.T1 >= l.T1 - INTERVAL 60 DAY
  QUALIFY row_number() OVER (PARTITION BY l.\".tid\", l.schema ORDER BY q.T1) = 1),
call AS (SELECT * FROM read_parquet('%s') WHERE valid IS NOT FALSE)
SELECT \".tid\", schema, 'T1' AS end_, 'ais' AS witness, T1 AS time, pid1 AS place, false AS day FROM ais
WHERE ais_basis IS NOT NULL
UNION ALL SELECT \".tid\", schema, 'T2', 'ais', T2, pid2, false FROM ais WHERE ais_basis IS NOT NULL
UNION ALL
SELECT t.\".tid\", t.schema, 'T1', 'own', t.T1, CASE WHEN t.schema = 'adb' THEN p.pid ELSE t.pid1 END, %s
FROM trip t LEFT JOIN port p ON p.hid = t.hid1 AND t.hid1 <> 0 WHERE t.schema IN ('fs_afladagbok', 'adb')
UNION ALL
SELECT t.\".tid\", t.schema, 'T2', 'own', t.T2, CASE WHEN t.schema = 'adb' THEN p.pid ELSE t.pid2 END, %s
FROM trip t LEFT JOIN port p ON p.hid = t.hid2 AND t.hid2 <> 0 WHERE t.schema IN ('fs_afladagbok', 'adb', 'afli')
UNION ALL SELECT \".tid\", schema, 'T1', 'stk', T1, pid1, false FROM stk
UNION ALL SELECT \".tid\", schema, 'T2', 'stk', T2, pid2, false FROM stk
UNION ALL SELECT \".tid\", schema, 'T1', 'quota', T1, pid1, false FROM quota
UNION ALL SELECT \".tid\", schema, 'T2', 'quota', T2, pid2, false FROM quota
UNION ALL
SELECT * FROM (
  SELECT t.\".tid\", t.schema, 'T1', 'phone', c.time, c.pid, false FROM trip t
  JOIN call c ON c.vid = t.vid AND c.io = 'out' AND CAST(c.time AS DATE) BETWEEN CAST(t.T1 AS DATE) - 3 AND CAST(t.T1 AS DATE)
   AND c.time < CAST(CAST(t.T2 AS DATE) AS TIMESTAMP) + INTERVAL 1 DAY
  QUALIFY row_number() OVER (PARTITION BY t.\".tid\", t.schema ORDER BY c.time DESC) = 1)
UNION ALL
SELECT * FROM (
  SELECT t.\".tid\", t.schema, 'T2', 'phone', c.time, c.pid, false FROM trip t
  JOIN call c ON c.vid = t.vid AND c.io = 'in' AND CAST(c.time AS DATE) BETWEEN CAST(t.T2 AS DATE) - 3 AND CAST(t.T2 AS DATE)
   AND c.time >= date_trunc('day', t.T1)
  QUALIFY row_number() OVER (PARTITION BY t.\".tid\", t.schema ORDER BY c.time DESC) = 1)
UNION ALL
SELECT \".tid\", schema, 'T2', 'landing', CAST(date_land AS TIMESTAMP), pid_land, true FROM lid",
  inputs[["stk"]], inputs[["lid"]], inputs[["quota"]], inputs[["phone"]], midnight("t.T1"), midnight("t.T2")))

# The cascade, one end at a time -----------------------------------------------------
end_sql <- function(e, rank, pname) {
  w <- dplyr::tbl(con, dplyr::sql(sprintf("SELECT \".tid\", schema, witness, time, place, day FROM witness WHERE end_ = '%s'", e)))
  r <- ramb::rb_add_trip_time(dplyr::tbl(con, dplyr::sql("SELECT \".tid\", schema FROM trip")), w,
                              keys = c(".tid", "schema"), rank = rank, basis = BASIS[rank], tolerance = TOLERANCE_S,
                              name = e, place_name = pname)
  as.character(dbplyr::sql_render(r))
}
wide <- function(e, p, rank) paste(sprintf("max(time) FILTER (WHERE end_ = '%1$s' AND witness = '%3$s') AS %1$s_%3$s,
       max(place) FILTER (WHERE end_ = '%1$s' AND witness = '%3$s') AS %2$s_%3$s", e, p, rank), collapse = ",\n       ")
q <- sprintf("SELECT t.\".tid\", t.schema, t.vid, d1.* EXCLUDE (\".tid\", schema), d2.* EXCLUDE (\".tid\", schema),
       w.* EXCLUDE (\".tid\", schema), a.n_voyage_ais, a.ais_basis, a.ais_flag
FROM trip t JOIN (%s) d1 USING (\".tid\", schema) JOIN (%s) d2 USING (\".tid\", schema)
LEFT JOIN (SELECT \".tid\", schema,\n       %s,\n       %s\n FROM witness GROUP BY ALL) w USING (\".tid\", schema)
JOIN ais a USING (\".tid\", schema)",
  end_sql("T1", RANK1, "pid1"), end_sql("T2", RANK2, "pid2"), wide("T1", "pid1", RANK1), wide("T2", "pid2", RANK2))

write_curated_sql(con, q, fd_curated("link", "trip_reconciled.parquet"), inputs = unname(inputs),
                  order_by = "schema, vid, T1")
dbDisconnect(con, shutdown = TRUE)
