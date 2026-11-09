# stk_misdated_2026.R — STK's reports of 14 January 2026, 09:08-13:30, delivered with a time a day late: which of them
# the tag pass moves back a day.
# Side: flow, step 0 (the clocks). See plan 059 and TODO 182.
#
# Input:  raw/oracle/stk/trail (through stk_trail(), R/stk_trail.R; STK's receipt time, `recdate`)
#         curated/vessel/vessel_ais_key.parquet         (mid -> vid, by date, as the union joins it)
#         staging/ais/ping_union/year=2026              (PAME's astd pings, the witness inside the live zone)
# Output: staging/ais/stk_misdated.parquet              (vid, stream, time as delivered, lon, lat, decision, basis) —
#         a side table, read by curate/ais_ping_tag.R, which moves a `misdated` ping back a day and labels an
#         `undecided` one, both beside their delivered time.
#
# Declaration and evidence: curate/corrections/stk_misdated_2026.yml; the study
# $FISHYDATA/archive/2026-11-09-stk-outage-misdated/ (its README). In STK's outage of January 2026 the reports of 14
# January 09:08-13:30 reached STK on 15 January between 11:08:43 and 11:30:30, stamped a day late; STK holds no other
# copy of them, and its track has a hole on 14 January over those hours. The block is named by its receipt span and its
# written times. STK also received live reports in that half hour, stamped at their own time, 0-6 min before their
# receipt; a block report can land there too. So:
#   misdated, basis "block"   a report of the block written outside 0-6 min before its receipt: a day late;
#   misdated, basis "astd"    one inside that zone that astd places where the vessel was a day before;
#   undecided, basis "none"   one inside the zone astd cannot place (no witness, the same place both days, neither).
# A report inside the zone astd places at its own time is live: not in the table, not moved.

library(dplyr)
library(DBI)

RECEIPT_FROM <- "2026-01-15 11:08:43"
RECEIPT_TO <- "2026-01-15 11:30:30"
WRITTEN_FROM <- "2026-01-15 09:00:00"
LIVE_S <- 360    # a live report is written 0-6 min before its receipt (the study's 07_block_rule.R)
WIN_S <- 300     # astd's pings either side of a time, within 5 min
TOL_M <- 500     # within 500 m of astd's position

con <- duckdbfs::cached_connection()
x <- function(...) invisible(dbExecute(con, sprintf(...)))

# the block's reports, each with its vessel, as the union joins STK's mobile ids (curate/ais_ping_union.R)
key <- duckdbfs::open_dataset(fd_curated("vessel", "vessel_ais_key.parquet")) |>
  select(vid, mid, d1, d2, d2_is_open) |>
  group_by(mid) |> mutate(open = d2_is_open & d1 == max(d1, na.rm = TRUE)) |> ungroup() |>
  filter(!is.na(vid)) |>
  mutate(d2e = if_else(open, dplyr::sql("'infinity'::DATE"), d2 + 1L))
stk_trail() |>
  filter(year == 2026L, stream %in% c("centiminute", "ais")) |>
  filter(dplyr::sql(sprintf("recdate BETWEEN TIMESTAMP '%s' AND TIMESTAMP '%s' AND time >= TIMESTAMP '%s'",
                            RECEIPT_FROM, RECEIPT_TO, WRITTEN_FROM))) |>
  mutate(stream = if_else(stream == "centiminute", "stk_vms", "stk_ais"),
         gap_s = dplyr::sql("epoch(recdate) - epoch(time)")) |>
  inner_join(key, by = join_by(mid, time >= d1, time < d2e)) |>
  # one row per key the tag pass joins on: a report STK holds twice is one report here
  group_by(vid, stream, time, lon, lat) |>
  summarise(gap_s = min(gap_s), .groups = "drop") |>
  compute(name = "blk", overwrite = TRUE)

# astd's position at a report's own time and a day before: interpolated between its pings either side within WIN_S
x("CREATE OR REPLACE TEMP TABLE a AS SELECT vid, time, lon, lat FROM read_parquet('%s/year=2026/*.parquet')
   WHERE provider = 'astd' AND vid IN (SELECT DISTINCT vid FROM blk)", fd_staging("ais", "ping_union"))
x("CREATE OR REPLACE TEMP TABLE z AS SELECT row_number() OVER () AS rid, * FROM blk WHERE gap_s BETWEEN 0 AND %d", LIVE_S)
witness <- function(shift, nm) {
  x("CREATE OR REPLACE TEMP TABLE q AS SELECT rid, vid, time - INTERVAL %d SECOND AS tq FROM z", shift)
  x("CREATE OR REPLACE TEMP TABLE b AS SELECT q.rid, q.tq, a.time AS tb, a.lon AS lonb, a.lat AS latb
     FROM q ASOF LEFT JOIN a ON q.vid = a.vid AND a.time <= q.tq")
  x("CREATE OR REPLACE TEMP TABLE f AS SELECT q.rid, a.time AS tf, a.lon AS lonf, a.lat AS latf
     FROM q ASOF LEFT JOIN a ON q.vid = a.vid AND a.time >= q.tq")
  x("CREATE OR REPLACE TEMP TABLE %1$s AS SELECT rid,
       CASE WHEN sb <= %2$d AND sf <= %2$d AND sb + sf > 0 THEN lonb + (lonf - lonb) * sb / (sb + sf)
            WHEN sb <= %2$d THEN lonb WHEN sf <= %2$d THEN lonf END AS wlon,
       CASE WHEN sb <= %2$d AND sf <= %2$d AND sb + sf > 0 THEN latb + (latf - latb) * sb / (sb + sf)
            WHEN sb <= %2$d THEN latb WHEN sf <= %2$d THEN latf END AS wlat
     FROM (SELECT b.*, f.tf, f.lonf, f.latf, date_diff('second', b.tb, b.tq) AS sb, date_diff('second', b.tq, f.tf) AS sf
           FROM b JOIN f USING (rid))", nm, WIN_S)
}
witness(0, "w0")
witness(86400, "w1")
hav <- "6371008.8 * 2 * asin(sqrt(pow(sin(radians(%2$s - z.lat) / 2), 2) + cos(radians(z.lat)) * cos(radians(%2$s)) *
        pow(sin(radians(%1$s - z.lon) / 2), 2)))"
x("CREATE OR REPLACE TEMP TABLE zd AS SELECT z.*, %s AS d0, %s AS d1 FROM z JOIN w0 USING (rid) JOIN w1 USING (rid)",
  sprintf(hav, "w0.wlon", "w0.wlat"), sprintf(hav, "w1.wlon", "w1.wlat"))

out <- fd_staging("ais", "stk_misdated.parquet")
x("COPY (
     SELECT vid, stream, time, lon, lat, 'misdated' AS decision, 'block' AS basis FROM blk
     WHERE NOT (gap_s BETWEEN 0 AND %1$d)
     UNION ALL
     SELECT vid, stream, time, lon, lat,
            CASE WHEN d1 <= %2$d AND (d0 IS NULL OR d0 > %2$d) THEN 'misdated' ELSE 'undecided' END,
            CASE WHEN d1 <= %2$d AND (d0 IS NULL OR d0 > %2$d) THEN 'astd' ELSE 'none' END
     FROM zd WHERE NOT (coalesce(d0 <= %2$d, false) AND coalesce(d1 > %2$d, true))   -- a live report is not written
     ORDER BY vid, stream, time, lon, lat
   ) TO '%3$s' (FORMAT parquet)", LIVE_S, TOL_M, out)

res <- dbGetQuery(con, sprintf("SELECT stream, decision, basis, count(*) n, count(DISTINCT vid) vessels
                                FROM read_parquet('%s') GROUP BY ALL ORDER BY stream, decision, basis", out))
print(res)
n_blk <- dbGetQuery(con, "SELECT count(*) n FROM blk")$n
n_live <- dbGetQuery(con, sprintf("SELECT count(*) n FROM zd WHERE coalesce(d0 <= %1$d, false) AND coalesce(d1 > %1$d, true)",
                                  TOL_M))$n
# every report of the block in one outcome: in the table, or live; and the table one row per key
stopifnot("every report of the block in one outcome" = sum(res$n) + n_live == n_blk,
          "one row per key" = dbGetQuery(con, sprintf("SELECT count(*) - count(DISTINCT (vid, time, lon, lat)) d
                                                      FROM read_parquet('%s')", out))$d == 0)
message("the block: ", n_blk, " reports with a vessel; ", n_live, " live, not moved")
