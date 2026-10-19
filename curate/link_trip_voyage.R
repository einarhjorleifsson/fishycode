# link_trip_voyage.R — L4 of the vessel-trail model: join logbook trips to the
# Side: flow, step 1. See plan 014.
# harbour-to-harbour voyages derived from AIS.
#
# Input:  curated/logbook/trip.parquet      (.tid, vid, T1, T2, schema, twin)
#         curated/ais/voyage.parquet        (vid, year, voyage_id, T1, T2, pid1, pid2)
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
#
# A resubmitted trip (trip `twin` "duplicate", curate/corrections/logbook_twin.yml) is not linked: it is its kept
# trip again, and on the voyage it made the trail's trip (`.tid_voyage`) ambiguous.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())

lb  <- fd_curated("logbook", "trip.parquet")
ais <- fd_curated("ais", "voyage.parquet")

# The link itself is ramb::rb_link_trip_voyages() (plan 013 phase 2): the voyage that overlaps the logbook
# trip by the most seconds, ties by more pings, n_candidates kept. Known issue 10: afli stores ~80% of trips
# with T1 = T2 (date-midnight) and fs_afladagbok stores T2 as midnight of the ARRIVAL date, which for same-day
# trips puts T2 before T1; t2_fix = "end_of_t1_day" pushes the window to at least the end of the first day.
trips <- dplyr::tbl(con, dplyr::sql(sprintf(
  "SELECT \".tid\", vid, schema, T1, T2 FROM read_parquet('%s') WHERE twin IS DISTINCT FROM 'duplicate'", lb)))
voy <- dplyr::tbl(con, dplyr::sql(sprintf(
  "SELECT vid, year, voyage_id, T1, T2, pid1 AS port_from, pid2 AS port_to, n_pings FROM read_parquet('%s')", ais)))
link <- ramb::rb_link_trip_voyages(trips, voy, keys = c(".tid", "schema"), t2_fix = "end_of_t1_day") |>
  dplyr::transmute(.tid, vid, schema, year, voyage_id, T1_ais = T1_voyage, T2_ais = T2_voyage,
                   pid1_ais = port_from, pid2_ais = port_to, n_pings, overlap_s, lb_span_s = trip_span_s,
                   overlap_frac, n_candidates, basis)
q <- as.character(dbplyr::sql_render(link))

out <- fd_curated("link", "trip_voyage.parquet")
write_curated_sql(con, q, out, inputs = c(lb, ais))

# -- report -------------------------------------------------------------------

n_lb <- dbGetQuery(con, sprintf(
  "SELECT schema, count(*) n FROM read_parquet('%s') WHERE vid IS NOT NULL AND twin IS DISTINCT FROM 'duplicate'
   GROUP BY 1", lb))
n_lk <- dbGetQuery(con, sprintf(
  "SELECT schema, count(*) linked, round(100.0*avg(CASE WHEN n_candidates > 1 THEN 1 ELSE 0 END),1) pct_ambiguous,
          round(median(overlap_frac),3) median_overlap_frac
   FROM read_parquet('%s') GROUP BY 1", out))
res <- merge(n_lb, n_lk, by = "schema", all.x = TRUE)
res$pct_linked <- round(100 * res$linked / res$n, 1)
print(res)

dbDisconnect(con, shutdown = TRUE)
