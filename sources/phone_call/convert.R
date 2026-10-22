# convert.R — vessels' phone notifications of leaving and entering port, from three systems.
# Side: preprocessing (phone_call). See plan 014.
#
# Input:  raw/oracle/stk/tilk_vss.parquet              (the Coast Guard's phone notifications, 1998-2013)
#         raw/oracle/simalinu/tilk_linu_sokn.parquet   (the line-incentive phone line, 2004-2014)
#         raw/oracle/kvoti/tilkynning_sokn.parquet     (days-at-sea boats' phone notifications, 1996-2001)
#         curated/reference/port.parquet
# Output: staging/phone_call/call.parquet  one row per call: system, id, vid, time, io ("out", "in" or NA), hid, pid,
#         valid
#
# Decision 172, TODO 121: a departure witness where no track or STK voyage covers a trip. adgerd 1 is a call out of
# port and 2 into it in all three; stk.tilk_vss also holds 143 thousand rows with adgerd 0, kept with io NA. `valid`
# is the system's own flag (gild 1) where it has one; the Coast Guard's calls have none. simalinu.tilk_vss is a copy
# of stk.tilk_vss rows (id_tilk_vss_sjor) and is not read.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())

q <- sprintf("
WITH c AS (
  SELECT 'coast_guard' AS system, id, TRY_CAST(skip_nr AS INTEGER) AS vid, posdate AS time, adgerd, hofn, NULL::BOOLEAN AS valid
  FROM read_parquet('%s')
  UNION ALL SELECT 'line_phone', id, skip_nr, timi, adgerd, hofn, gild = 1 FROM read_parquet('%s')
  UNION ALL SELECT 'days_at_sea', NULL, skip_nr, timi, adgerd, hofn, gild = 1 FROM read_parquet('%s'))
SELECT c.system, c.id, c.vid, c.time, CASE c.adgerd WHEN 1 THEN 'out' WHEN 2 THEN 'in' END AS io, c.hofn AS hid, p.pid,
       c.valid
FROM c LEFT JOIN read_parquet('%s') p ON p.hid = c.hofn
WHERE c.vid IS NOT NULL AND c.time IS NOT NULL",
  fd_raw("oracle", "stk", "tilk_vss.parquet"), fd_raw("oracle", "simalinu", "tilk_linu_sokn.parquet"),
  fd_raw("oracle", "kvoti", "tilkynning_sokn.parquet"), fd_curated("reference", "port.parquet"))

dbExecute(con, sprintf("COPY (%s ORDER BY vid, time) TO '%s' (FORMAT parquet)", q, fd_staging("phone_call", "call.parquet")))
dbDisconnect(con, shutdown = TRUE)
