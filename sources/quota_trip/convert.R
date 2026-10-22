# convert.R — the quota system's trip records: a landing tied to the vessel's departure from and return to port.
# Side: preprocessing (quota_trip). See plan 014.
#
# Input:  raw/oracle/kvoti/ivln_tilkynning_londun.parquet  (line incentive, 2004-2020: STK and phone-line out/in ids)
#         raw/oracle/kvoti/strandveidar.parquet            (coastal fishing, 2009-2023: STK and phone out/in ids)
#         raw/oracle/kvoti/lods_londun.parquet             (the landing: vessel, day, port, gear, line-incentive flag)
#         raw/oracle/stk/tilk_stk.parquet                  (STK's port events: time, STK code, numeric port)
#         raw/oracle/simalinu/tilk_linu_sokn.parquet       (the line-incentive phone line: time, port)
#         curated/reference/stk_hid_pid.parquet, curated/reference/port.parquet
# Output: staging/quota_trip/trip.parquet  one row per record: regime, vid, date, hid, komunr, gid_landing,
#         linu_ivilnun, T1, T1_from, pid1, pid1_from, T2, T2_from, pid2, pid2_from, invalid, and the four event ids
#
# Decision 172, TODO 121. Each regime ties a landing (hofn, komunr; every record is in lods_londun) to the events that
# open and close its trip. These are trip records in their own right, not only departure witnesses: the regime, and
# the landing's gear (veidarf) with the hand-baited longline flag of the line incentive (linu_ivilnun 1 or 2), go
# with them. STK's event is taken before the phone's where both exist; an STK out-event carries no port from 2014.
# strandveidar's er_ogild (the record is invalid) is kept as `invalid`; the line incentive has no such flag.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
k <- function(x) fd_raw("oracle", "kvoti", paste0(x, ".parquet"))

dbExecute(con, sprintf("CREATE VIEW port AS SELECT hid, pid FROM read_parquet('%s')", fd_curated("reference", "port.parquet")))
dbExecute(con, sprintf("
CREATE VIEW ev AS SELECT e.trailid AS id, e.timi AS t, coalesce(h.pid, p.pid) AS pid,
  CASE WHEN h.pid IS NOT NULL THEN 'harborid' WHEN p.pid IS NOT NULL THEN 'hofn' END AS pid_from
FROM read_parquet('%s') e LEFT JOIN read_parquet('%s') h ON h.hid = e.harborid
LEFT JOIN port p ON p.hid = e.hofn AND e.hofn <> 999",
  fd_raw("oracle", "stk", "tilk_stk.parquet"), fd_curated("reference", "stk_hid_pid.parquet")))
dbExecute(con, sprintf("
CREATE VIEW ph AS SELECT l.id, l.timi AS t, p.pid, CASE WHEN p.pid IS NOT NULL THEN 'phone' END AS pid_from
FROM read_parquet('%s') l LEFT JOIN port p ON p.hid = l.hofn",
  fd_raw("oracle", "simalinu", "tilk_linu_sokn.parquet")))

q <- sprintf("
WITH r AS (
  SELECT 'line_incentive' AS regime, hofn, komunr, id_stk_ur_hofn AS stk_out, id_stk_i_hofn AS stk_in,
         id_sima_lina_ur_hofn AS phone_out, id_sima_lina_i_hofn AS phone_in, NULL::BOOLEAN AS invalid
  FROM read_parquet('%s')
  UNION ALL
  SELECT 'coastal', hofn, komunr, id_ur_hofn, id_i_hofn, id_sima_ur_hofn, id_sima_i_hofn, er_ogild = 1
  FROM read_parquet('%s'))
SELECT r.regime, l.skip_nr AS vid, CAST(l.l_dags AS DATE) AS date, r.hofn AS hid, r.komunr,
       l.veidarf AS gid_landing, l.linu_ivilnun,
       coalesce(so.t, po.t) AS T1, CASE WHEN so.t IS NOT NULL THEN 'stk' WHEN po.t IS NOT NULL THEN 'phone' END AS T1_from,
       coalesce(so.pid, po.pid) AS pid1, coalesce(so.pid_from, po.pid_from) AS pid1_from,
       coalesce(si.t, pi.t) AS T2, CASE WHEN si.t IS NOT NULL THEN 'stk' WHEN pi.t IS NOT NULL THEN 'phone' END AS T2_from,
       coalesce(si.pid, pi.pid) AS pid2, coalesce(si.pid_from, pi.pid_from) AS pid2_from,
       r.invalid, r.stk_out, r.stk_in, r.phone_out, r.phone_in
FROM r JOIN read_parquet('%s') l ON l.hofn = r.hofn AND l.komunr = r.komunr
LEFT JOIN ev so ON so.id = r.stk_out LEFT JOIN ev si ON si.id = r.stk_in
LEFT JOIN ph po ON po.id = r.phone_out LEFT JOIN ph pi ON pi.id = r.phone_in",
  k("ivln_tilkynning_londun"), k("strandveidar"), k("lods_londun"))

dbExecute(con, sprintf("COPY (%s ORDER BY vid, date, regime) TO '%s' (FORMAT parquet)", q,
                       fd_staging("quota_trip", "trip.parquet")))
dbDisconnect(con, shutdown = TRUE)
