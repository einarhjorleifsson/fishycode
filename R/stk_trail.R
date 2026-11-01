# stk_trail.R — the STK trail and mobile ids in their preferred form, over the dump as Oracle holds it (plan 018).
#
# Input:  raw/oracle/stk/trail/year=<y>/*.parquet, raw/oracle/stk/mobile.parquet
# Output: none; lazy tables over the cached DuckDB connection (stk_trail(), stk_mobile()), or the SELECT behind
#         each (stk_trail_sql(), stk_mobile_sql()) for a reader that writes its own SQL: `from (%s) t`
#
# The dump keeps Oracle's names and units: trailid, mobileid, posdate, poslon/poslat and heading in radians, speed in
# m/s. Every reader wants .id, mid, time, lon/lat and heading in degrees, speed in knots, hid and io. Until plan 018
# the old dump (dump/ais/stk.R) computed these in Oracle and wrote them as a second copy, from 2007 only. A view
# does it with no copy, and holds every year from 2003. `year` is the partition: the year of recdate, the receipt
# time, not of time (a ping with a bad time sits in its receipt year).

stk_trail_sql <- function() {
  sprintf(paste("SELECT trailid AS \".id\", mobileid AS mid, posdate AS time,",
                "poslon * 180 / pi() AS lon, poslat * 180 / pi() AS lat,",
                "speed * 3600 / 1852 AS speed, heading * 180 / pi() AS heading,",
                "harborid AS hid, in_out_of_harbor AS io, recdate, year",
                "FROM read_parquet('%s', hive_partitioning = true)"),
          file.path(fd_raw("oracle", "stk", "trail"), "year=*", "*.parquet"))
}

stk_trail <- function(conn = duckdbfs::cached_connection()) dplyr::tbl(conn, dplyr::sql(stk_trail_sql()))

# The old dump's three columns of stk.mobile, under its names: mid, loid (the unit's local id) and glid (its global
# id, an MMSI where it has one).
stk_mobile_sql <- function() {
  sprintf("SELECT mobileid AS mid, localid AS loid, globalid AS glid FROM read_parquet('%s')",
          fd_raw("oracle", "stk", "mobile.parquet"))
}

stk_mobile <- function(conn = duckdbfs::cached_connection()) dplyr::tbl(conn, dplyr::sql(stk_mobile_sql()))

# A ping's stream (decision 233, plan 059), one rule for the feeds' clock check and the tag pass: the provider, and
# STK's three by the position's grid in degrees, as stk_trail() converts the radians: its VMS stream (a hundredth of a
# minute) first, since that grid lies on the AIS one (1e-4 minute) too, then its AIS stream, else its own units. A row
# of STK's port events is no fix: "stk_event". The CASE over the union's columns as `u`, with the year's event rows
# (stk_event_rows_sql()) left-joined as `e` on time, lon and lat.
ping_stream_sql <- function(u = "u", e = "e") {
  sprintf("
  CASE WHEN %1$s.provider <> 'stk' THEN %1$s.provider
       WHEN %2$s.time IS NOT NULL THEN 'stk_event'
       WHEN abs(%1$s.lat * 6000 - round(%1$s.lat * 6000)) < 0.0002 AND abs(%1$s.lon * 6000 - round(%1$s.lon * 6000)) < 0.0002 THEN 'stk_vms'
       WHEN abs(%1$s.lat * 600000 - round(%1$s.lat * 600000)) < 0.02 AND abs(%1$s.lon * 600000 - round(%1$s.lon * 600000)) < 0.02 THEN 'stk_ais'
       ELSE 'stk_unit' END", u, e)
}

# STK's port event rows of one year, as the union holds a ping (time, lon and lat in degrees)
stk_event_rows_sql <- function(yr) {
  sprintf(paste("SELECT DISTINCT posdate AS time, poslon * 180 / pi() AS lon, poslat * 180 / pi() AS lat",
                "FROM read_parquet('%s', hive_partitioning = true)",
                "WHERE in_out_of_harbor IS NOT NULL AND posdate >= TIMESTAMP '%d-01-01' AND posdate < TIMESTAMP '%d-01-01'"),
          file.path(fd_raw("oracle", "stk", "trail"), "year=*", "*.parquet"), as.integer(yr), as.integer(yr) + 1L)
}
