# trip_reconciled.R — every logbook trip's departure and return, time and port, from ranked witnesses.
# Side: flow, step 1. See plan 014.
#
# Input:  curated/logbook/trip.parquet         (.tid, schema, vid, T1, T2, hid1, pid1, hid2, pid2, twin)
#         curated/link/trip_voyage.parquet     (T1_ais, T2_ais, pid1_ais, pid2_ais: the AIS voyage linked to the trip)
#         curated/logbook/lid_map.parquet      (the trip's landing: date_land, hid_land, pid_land, n_trips)
#         staging/stk/voyage.parquet           (STK's recorded voyages)
#         staging/quota_trip/trip.parquet      (the quota system's trip records, keyed by landing)
#         staging/phone_call/call.parquet      (phone notifications)
#         curated/reference/port.parquet       (adb's port number -> pid)
# Output: curated/link/trip_reconciled.parquet  one row per logbook trip (twins left out): .tid, schema, vid; T1, pid1,
#         T2, pid2, each with _from, _basis, _n, _outcome (times also _day, _spread_s); each witness's own values
#         (T1_<w>, pid1_<w>, T2_<w>, pid2_<w>)
#
# Decisions 173, 174, TODO 121. The maintainer's ranking (2026-10-22), the same for both ends: the AIS voyage, then the
# logbook's own, then STK, the quota system's records and the phone calls; the landing register witnesses the return
# only, last. Time and port are each taken from the best witness that holds one (ramb::rb_add_trip_time()); a value
# that is a date only (`day`: a logbook time at midnight, the landing day) gives way to a time on that day, and every
# trip falls in one outcome per field. The witnesses:
#   ais      the voyage rb_link_trip_voyages() linked to the trip (trip_voyage)
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
            port = fd_curated("reference", "port.parquet"))
dbExecute(con, sprintf("CREATE TEMP TABLE trip AS SELECT \".tid\", schema, vid, T1, T2, hid1, pid1, hid2, pid2
                        FROM read_parquet('%s') WHERE twin IS DISTINCT FROM 'duplicate'", inputs[["trip"]]))
dbExecute(con, sprintf("CREATE TEMP TABLE port AS SELECT hid, pid FROM read_parquet('%s')", inputs[["port"]]))

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
SELECT \".tid\", schema, 'T1' AS end_, 'ais' AS witness, T1_ais AS time, pid1_ais AS place, false AS day FROM read_parquet('%s')
UNION ALL SELECT \".tid\", schema, 'T2', 'ais', T2_ais, pid2_ais, false FROM read_parquet('%s')
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
  inputs[["stk"]], inputs[["lid"]], inputs[["quota"]], inputs[["phone"]], inputs[["voyage"]], inputs[["voyage"]],
  midnight("t.T1"), midnight("t.T2")))

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
       w.* EXCLUDE (\".tid\", schema)
FROM trip t JOIN (%s) d1 USING (\".tid\", schema) JOIN (%s) d2 USING (\".tid\", schema)
LEFT JOIN (SELECT \".tid\", schema,\n       %s,\n       %s\n FROM witness GROUP BY ALL) w USING (\".tid\", schema)",
  end_sql("T1", RANK1, "pid1"), end_sql("T2", RANK2, "pid2"), wide("T1", "pid1", RANK1), wide("T2", "pid2", RANK2))

write_curated_sql(con, q, fd_curated("link", "trip_reconciled.parquet"), inputs = unname(inputs),
                  order_by = "schema, vid, T1")
dbDisconnect(con, shutdown = TRUE)
