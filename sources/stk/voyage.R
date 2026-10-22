# voyage.R — STK's recorded voyages, port to port, with each end's port as a standard pid.
# Side: preprocessing (stk). See plan 014.
#
# Input:  raw/oracle/stk/tilk_stk_allt.parquet          (skip_nr, timi_ut, hofn_ut, timi_inn, hofn_inn, trailid_ut/_inn)
#         raw/oracle/stk/tilk_stk.parquet               (the port events behind them: trailid, harborid, hofn)
#         curated/reference/stk_hid_pid.parquet         (STK code -> pid)
#         curated/reference/port.parquet                (the landing system's port number -> pid)
# Output: staging/stk/voyage.parquet   one row per recorded voyage: vid, T1, T2, pid1, pid2, pid1_from, pid2_from,
#                                      trailid_out, trailid_in
#
# A departure witness for the logbook trips (decision 172, TODO 121). tilk_stk_allt pairs STK's out and in events
# (plan 022: every out and in trailid is a tilk_stk event). A port is the event's STK code through stk_hid_pid, else
# the voyage's numeric port through port.parquet; 999 is STK's "Hafnarheiti vantar", no port. The out-events carry
# no port from 2014, so later voyages have a time and no pid1.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
p <- function(...) fd_raw("oracle", "stk", ...)

q <- sprintf("
WITH ev AS (SELECT e.trailid, h.pid FROM read_parquet('%s') e
            JOIN read_parquet('%s') h ON h.hid = e.harborid WHERE h.pid IS NOT NULL),
port AS (SELECT hid, pid FROM read_parquet('%s'))
SELECT a.skip_nr AS vid, a.timi_ut AS T1, a.timi_inn AS T2,
       coalesce(eo.pid, po.pid) AS pid1, coalesce(ei.pid, pi.pid) AS pid2,
       CASE WHEN eo.pid IS NOT NULL THEN 'harborid' WHEN po.pid IS NOT NULL THEN 'hofn' END AS pid1_from,
       CASE WHEN ei.pid IS NOT NULL THEN 'harborid' WHEN pi.pid IS NOT NULL THEN 'hofn' END AS pid2_from,
       a.trailid_ut AS trailid_out, a.trailid_inn AS trailid_in
FROM read_parquet('%s') a
LEFT JOIN ev eo ON eo.trailid = a.trailid_ut LEFT JOIN ev ei ON ei.trailid = a.trailid_inn
LEFT JOIN port po ON po.hid = a.hofn_ut AND a.hofn_ut <> 999 LEFT JOIN port pi ON pi.hid = a.hofn_inn AND a.hofn_inn <> 999
WHERE a.skip_nr IS NOT NULL AND (a.timi_ut IS NOT NULL OR a.timi_inn IS NOT NULL)",
  p("tilk_stk.parquet"), fd_curated("reference", "stk_hid_pid.parquet"), fd_curated("reference", "port.parquet"),
  p("tilk_stk_allt.parquet"))

dbExecute(con, sprintf("COPY (%s ORDER BY vid, T1) TO '%s' (FORMAT parquet)", q, fd_staging("stk", "voyage.parquet")))
dbDisconnect(con, shutdown = TRUE)
