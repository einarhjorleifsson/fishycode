# trip_departure.R — every logbook trip's departure, time and port, from ranked witnesses.
# Side: flow, step 1. See plan 014.
#
# Input:  curated/logbook/trip.parquet         (.tid, schema, vid, T1, T2, hid1, pid1, twin)
#         curated/link/trip_voyage.parquet     (T1_ais, pid1_ais: the AIS voyage linked to the trip)
#         curated/logbook/lid_map.parquet      (the trip's landing: date_land, hid_land, n_trips)
#         staging/stk/voyage.parquet           (STK's recorded voyages)
#         staging/quota_trip/trip.parquet      (the quota system's trip records, keyed by landing)
#         staging/phone_call/call.parquet      (phone notifications)
#         curated/reference/port.parquet       (adb's port number -> pid)
# Output: curated/link/trip_departure.parquet  one row per logbook trip (twins left out): .tid, schema, vid, T1 and
#         pid1 with _from, _basis, _n, _outcome (T1_spread_s too), and each witness's own T1_<w>, pid1_<w>
#
# Decision 173, TODO 121. The maintainer's ranking (2026-10-22): the AIS voyage first, then the logbook's own, then
# STK; then the quota system's records and the phone calls. Time and port are each taken from the best witness that
# holds one (ramb::rb_add_trip_time()); every trip falls in one outcome per field. The witnesses:
#   ais    the voyage rb_link_trip_voyages() linked to the trip (trip_voyage)
#   own    the logbook's T1 and port, fs_afladagbok and adb only: afli's T1 is the first fishing day and
#          aflaskeyti's is synthesised, neither a departure. adb's port 0 is a placeholder (decision 172), not a port.
#   stk    the latest STK voyage that contains the trip: out by T1's day, in on or after T2's day, within 60 days
#   quota  the record of the trip's landing (lid_map, a landing no other trip claims), its departure on or before
#          the landing day
#   phone  the latest valid out-call on T1's day or up to 3 days before, no later than T2's day
# A trip that no witness covers is kept, with T1 and pid1 NA and basis "none".

library(DBI)
library(duckdb)

RANK  <- c("ais", "own", "stk", "quota", "phone")
BASIS <- c(ais = "reconstructed", own = "recorded", stk = "recorded", quota = "recorded", phone = "recorded")
TOLERANCE_S <- 3600

con <- dbConnect(duckdb())
inputs <- c(trip = fd_curated("logbook", "trip.parquet"), voyage = fd_curated("link", "trip_voyage.parquet"),
            lid = fd_curated("logbook", "lid_map.parquet"), stk = fd_staging("stk", "voyage.parquet"),
            quota = fd_staging("quota_trip", "trip.parquet"), phone = fd_staging("phone_call", "call.parquet"),
            port = fd_curated("reference", "port.parquet"))
dbExecute(con, sprintf("CREATE TEMP TABLE trip AS SELECT \".tid\", schema, vid, T1, T2, hid1, pid1
                        FROM read_parquet('%s') WHERE twin IS DISTINCT FROM 'duplicate'", inputs[["trip"]]))

# The witnesses ------------------------------------------------------------------
dbExecute(con, sprintf("
CREATE TEMP TABLE witness AS
SELECT \".tid\", schema, 'ais' AS witness, T1_ais AS time, pid1_ais AS place FROM read_parquet('%s')
UNION ALL
SELECT t.\".tid\", t.schema, 'own', t.T1, CASE WHEN t.schema = 'adb' THEN p.pid ELSE t.pid1 END
FROM trip t LEFT JOIN read_parquet('%s') p ON p.hid = t.hid1 AND t.hid1 <> 0
WHERE t.schema IN ('fs_afladagbok', 'adb')
UNION ALL
SELECT * FROM (
  SELECT t.\".tid\", t.schema, 'stk', s.T1, s.pid1 FROM trip t
  JOIN read_parquet('%s') s ON s.vid = t.vid AND CAST(s.T1 AS DATE) <= CAST(t.T1 AS DATE)
   AND CAST(s.T2 AS DATE) >= CAST(t.T2 AS DATE) AND s.T1 >= t.T1 - INTERVAL 60 DAY
  QUALIFY row_number() OVER (PARTITION BY t.\".tid\", t.schema ORDER BY s.T1 DESC) = 1)
UNION ALL
SELECT * FROM (
  SELECT m.\".tid\", m.schema, 'quota', q.T1, q.pid1 FROM read_parquet('%s') m
  JOIN trip t ON t.\".tid\" = m.\".tid\" AND t.schema = m.schema
  JOIN read_parquet('%s') q ON q.vid = t.vid AND q.date = m.date_land AND q.hid = m.hid_land
  WHERE m.n_trips = 1 AND q.invalid IS NOT TRUE AND q.T1 IS NOT NULL
    AND q.T1 < CAST(m.date_land AS TIMESTAMP) + INTERVAL 1 DAY AND q.T1 >= t.T1 - INTERVAL 60 DAY
  QUALIFY row_number() OVER (PARTITION BY m.\".tid\", m.schema ORDER BY q.T1) = 1)
UNION ALL
SELECT * FROM (
  SELECT t.\".tid\", t.schema, 'phone', c.time, c.pid FROM trip t
  JOIN read_parquet('%s') c ON c.vid = t.vid AND c.io = 'out' AND c.valid IS NOT FALSE
   AND CAST(c.time AS DATE) BETWEEN CAST(t.T1 AS DATE) - 3 AND CAST(t.T1 AS DATE)
   AND c.time < CAST(CAST(t.T2 AS DATE) AS TIMESTAMP) + INTERVAL 1 DAY
  QUALIFY row_number() OVER (PARTITION BY t.\".tid\", t.schema ORDER BY c.time DESC) = 1)",
  inputs[["voyage"]], inputs[["port"]], inputs[["stk"]], inputs[["lid"]], inputs[["quota"]], inputs[["phone"]]))

# The cascade --------------------------------------------------------------------
dep <- ramb::rb_add_trip_time(
  dplyr::tbl(con, dplyr::sql("SELECT \".tid\", schema, vid FROM trip")),
  dplyr::tbl(con, "witness"),
  keys = c(".tid", "schema"), rank = RANK, basis = BASIS, tolerance = TOLERANCE_S
)
wide <- paste(sprintf("max(time) FILTER (WHERE witness = '%1$s') AS T1_%1$s, max(place) FILTER (WHERE witness = '%1$s') AS pid1_%1$s",
                      RANK), collapse = ",\n       ")
q <- sprintf("SELECT d.*, w.* EXCLUDE (\".tid\", schema) FROM (%s) d
LEFT JOIN (SELECT \".tid\", schema,\n       %s\n FROM witness GROUP BY ALL) w USING (\".tid\", schema)",
  as.character(dbplyr::sql_render(dep)), wide)

write_curated_sql(con, q, fd_curated("link", "trip_departure.parquet"), inputs = unname(inputs),
                  order_by = "schema, vid, T1")
dbDisconnect(con, shutdown = TRUE)
