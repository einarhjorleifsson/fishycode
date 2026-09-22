# link_trip_voyage.R — L4 of the vessel-trail model: join logbook trips to the
# harbour-to-harbour voyages derived from AIS.
#
# Input:  curated/logbook/trip.parquet      (.tid, vid, T1, T2, schema)
#         curated/ais/trip.parquet          (vid, year, trip, T1, T2, hid1, hid2)
# Output: curated/link/trip_voyage.parquet
#
# Both inputs carry T1/T2 because both are trip-level - case encodes the level, not
# the source (curate/decisions/010-time-variable-naming.md). Where the two meet in
# one row the AIS side takes the _ais suffix: T1_ais, T2_ais.
#
# This is the deliverable the trail data exists for: a trip identity that ties
# vessel movement to the logbook record. AIS voyages carried no logbook key at
# all before this.
#
# Nothing existing is mutated. The link is its own table and the improved times
# arrive as NEW columns (T1_ais, T2_ais), so curated/logbook/trip.parquet is
# untouched and analysts opt in by joining.
#
# Matching is by temporal overlap on vid, taking the voyage that overlaps the
# logbook trip by the most seconds. Overlap is used rather than containment
# because neither window is reliable: see the T2 repair below, and AIS voyages
# begin and end at harbour crossings that need not align with the logbook's idea
# of departure and landing.
#
# Known limits, recorded in curate/decisions/000-restructuring.md:
#   - AIS coverage is partial. Only 3,144 of 31,852 STK mobile ids ever matched a
#     vessel, and small boats may carry no transponder, so a missing link is
#     usually missing data rather than a failed match.
#   - 35 vids have overlapping mid periods (known issue 9) and will produce
#     ambiguous candidates; n_candidates records this.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())

lb  <- fd_curated("logbook", "trip.parquet")
# the AIS chain has not been rebuilt yet; fall back to the legacy build so the
# linkage can be established now and simply pick up the new table when it exists
ais <- fd_curated("ais", "trip.parquet")
if (!file.exists(ais)) {
  ais <- file.path(fishydata_root(), "legacy", "curated", "ais_trips.parquet")
  message("curated/ais/trip.parquet absent - linking against the legacy AIS trips")
}

q <- sprintf("
WITH lb AS (
  SELECT \".tid\" AS tid, vid, schema, T1, T2,
    -- Known issue 10: afli stores ~80%% of trips with T1 = T2 (date-midnight) and
    -- fs_afladagbok stores T2 as midnight of the ARRIVAL date, which for same-day
    -- trips puts T2 before T1. Either way the window is unusable for an overlap
    -- test until it is pushed to end-of-day.
    greatest(T2, date_trunc('day', T1) + INTERVAL 1 DAY - INTERVAL 1 SECOND) AS T2_fix
  FROM read_parquet('%s')
  WHERE vid IS NOT NULL AND T1 IS NOT NULL
),
v AS (
  SELECT vid, year, trip, T1, T2, hid1, hid2, n_pings FROM read_parquet('%s')
),
ov AS (
  SELECT lb.tid, lb.vid, lb.schema, lb.T1, lb.T2, lb.T2_fix,
         v.year, v.trip, v.T1 AS T1_ais, v.T2 AS T2_ais, v.hid1, v.hid2, v.n_pings,
         date_diff('second', greatest(lb.T1, v.T1), least(lb.T2_fix, v.T2)) AS overlap_s,
         date_diff('second', lb.T1, lb.T2_fix) AS lb_span_s
  FROM lb JOIN v
    ON lb.vid = v.vid AND v.T1 <= lb.T2_fix AND v.T2 >= lb.T1
),
ranked AS (
  SELECT *, row_number() OVER (PARTITION BY tid ORDER BY overlap_s DESC, n_pings DESC) rn,
            count(*)     OVER (PARTITION BY tid) n_candidates
  FROM ov WHERE overlap_s > 0
)
SELECT
  tid AS \".tid\", vid, schema,
  year AS voyage_year, trip AS voyage, T1_ais, T2_ais,
  hid1 AS hid1_ais, hid2 AS hid2_ais, n_pings,
  overlap_s, lb_span_s,
  round(overlap_s::DOUBLE / nullif(lb_span_s, 0), 4) AS overlap_frac,
  n_candidates,
  'ais_overlap' AS basis
FROM ranked WHERE rn = 1", lb, ais)

out <- fd_curated("link", "trip_voyage.parquet")
dbExecute(con, sprintf("COPY (%s) TO '%s' (FORMAT parquet)", q, out))

# -- report -------------------------------------------------------------------

n_lb <- dbGetQuery(con, sprintf(
  "SELECT schema, count(*) n FROM read_parquet('%s') WHERE vid IS NOT NULL GROUP BY 1", lb))
n_lk <- dbGetQuery(con, sprintf(
  "SELECT schema, count(*) linked, round(100.0*avg(CASE WHEN n_candidates > 1 THEN 1 ELSE 0 END),1) pct_ambiguous,
          round(median(overlap_frac),3) median_overlap_frac
   FROM read_parquet('%s') GROUP BY 1", out))
res <- merge(n_lb, n_lk, by = "schema", all.x = TRUE)
res$pct_linked <- round(100 * res$linked / res$n, 1)
print(res)

dbDisconnect(con, shutdown = TRUE)
