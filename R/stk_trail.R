# stk_trail.R — the STK trail and mobile ids in their preferred form, over the dump as Oracle holds it (plan 018).
#
# Input:  raw/oracle/stk/trail/year=<y>/*.parquet, raw/oracle/stk/mobile.parquet
# Output: none; lazy tables over the cached DuckDB connection (stk_trail(), stk_mobile()), or the SELECT behind
#         each (stk_trail_sql(), stk_mobile_sql()) for a reader that writes its own SQL: `from (%s) t`
#
# The dump keeps Oracle's names and units: trailid, mobileid, posdate, poslon/poslat and heading in radians, speed in
# m/s. Every reader wants .id, mid, time, lon/lat in degrees, speed in knots, hid and io. Until plan 018 the old dump
# (dump/ais/stk.R) computed these in Oracle and wrote them as a second copy, from 2007 only. A view does it with no
# copy, and holds every year from 2003. `year` is the partition: the year of recdate, the receipt time, not of time (a
# ping with a bad time sits in its receipt year).
#
# Three columns decode what the dump holds in one field or in none (plan 048 §2.1, decisions 233 and 288; the dump
# keeps the original in raw/):
#   stream   STK's stream by the position's grid in degrees (dump/oracle/meta/stk.yml): "centiminute" (a hundredth of a
#            minute; VMS in 2006-2010) first, since that grid lies on the AIS one too, then "ais" (a ten-thousandth of
#            a minute), else "ungridded" (STK's own units). The rule the tag pass applied until plan 048, so a stream
#            is the same as before.
#   heading  true heading, degrees: the AIS stream's field before the switch to course over ground, cut on posdate at
#            2010-06-09 17:40:13 (as sharp as on recdate, decision 288); NA on the other streams and after it.
#   cog      course over ground, degrees: the AIS stream's field from the switch, and the other streams' throughout.
# A value of a full turn or more, or below 0, is a code for "not available" (511 true heading's, 360.0 course's), NA
# in both. A 0 is kept: a north course and a missing one look alike (stk.yml).
STK_HEADING_SWITCH <- "2010-06-09 17:40:13"

stk_trail_sql <- function(src = file.path(fd_raw("oracle", "stk", "trail"), "year=*", "*.parquet")) {
  sprintf("
SELECT \".id\", mid, time, lon, lat, speed, stream,
       CASE WHEN rb_code OR stream <> 'ais' OR time >= TIMESTAMP '%2$s' THEN NULL ELSE rb_hd END AS heading,
       CASE WHEN rb_code OR (stream = 'ais' AND time < TIMESTAMP '%2$s') THEN NULL ELSE rb_hd END AS cog,
       hid, io, recdate, year
FROM (SELECT *, rb_hd >= 360 OR rb_hd < 0 AS rb_code,
             CASE WHEN abs(lat * 6000 - round(lat * 6000)) < 0.0002 AND abs(lon * 6000 - round(lon * 6000)) < 0.0002 THEN 'centiminute'
                  WHEN abs(lat * 600000 - round(lat * 600000)) < 0.02 AND abs(lon * 600000 - round(lon * 600000)) < 0.02 THEN 'ais'
                  ELSE 'ungridded' END AS stream
      FROM (SELECT trailid AS \".id\", mobileid AS mid, posdate AS time,
                   poslon * 180 / pi() AS lon, poslat * 180 / pi() AS lat,
                   speed * 3600 / 1852 AS speed, heading * 180 / pi() AS rb_hd,
                   harborid AS hid, in_out_of_harbor AS io, recdate, year
            FROM read_parquet('%1$s', hive_partitioning = true)))", src, STK_HEADING_SWITCH)
}

stk_trail <- function(conn = duckdbfs::cached_connection()) dplyr::tbl(conn, dplyr::sql(stk_trail_sql()))

# The old dump's three columns of stk.mobile, under its names: mid, loid (the unit's local id) and glid (its global
# id, an MMSI where it has one).
stk_mobile_sql <- function() {
  sprintf("SELECT mobileid AS mid, localid AS loid, globalid AS glid FROM read_parquet('%s')",
          fd_raw("oracle", "stk", "mobile.parquet"))
}

stk_mobile <- function(conn = duckdbfs::cached_connection()) dplyr::tbl(conn, dplyr::sql(stk_mobile_sql()))

# A ping's stream (decision 233, plan 059), one rule for the feeds' clock check and the tag pass, over the union's own
# columns as `u`: the provider; STK's three by the union's `stream` (stk_trail()'s, under the names the feed-clock
# check keys its lags by: "stk_vms", "stk_ais", "stk_unit"); and an STK arrival kept as a fix (the union's `io`, plan
# 048 §2.2) "stk_event", as every port event row was until plan 048, so its time is not moved. Until plan 048 the
# event label came from matching a row's time and position to the trail's event rows, which put it on 6,091 fixes
# equal to an event row (decision 288).
ping_stream_sql <- function(u = "u") {
  sprintf("
  CASE WHEN %1$s.provider <> 'stk' THEN %1$s.provider
       WHEN %1$s.io IS NOT NULL THEN 'stk_event'
       WHEN %1$s.stream = 'centiminute' THEN 'stk_vms'
       WHEN %1$s.stream = 'ais' THEN 'stk_ais'
       ELSE 'stk_unit' END", u)
}
