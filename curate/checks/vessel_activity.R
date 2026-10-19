# vessel_activity.R — the vessels at sea that neither land fish nor keep a logbook: what are they doing?
# Side: flow (reads AIS voyages). See plan 013 item 6.
#
# Input:  curated/ais/voyage.parquet      (vid, year, voyage, T1, T2, pid1, pid2, n_pings)
#         curated/landing/landings.parquet (vid, date)
#         curated/logbook/trip.parquet     (vid, T1)
# Output: curated/check/vessel_activity.parquet   one row per vessel-year with voyages
#
# A REPORT, not a correction (AGENTS.md: checks report; a reviewed conclusion re-enters through overrides/).
# Plan 013's paths table found that 10-36 % of the voyages in a year are of vessels that land nothing that year,
# rising since 2013, and the ports they grew from are the fish-farming fjords and the whale-watching ports
# (maintainer: aquaculture, whale watching). They are not missing logbooks. This table gives each vessel-year the
# evidence for a class, and the class it suggests, for a person to confirm:
#   lands, logbook      whether the vessel landed fish, or kept a logbook, that year
#   home_pid            the port most of its voyages leave from; port_share the share that do
#   day_trip_share      voyages under 12 h
#   suggested           fishing (lands or logbook) | aquaculture_service (no fish, home in a fish-farming fjord,
#                       day trips) | whale_watching (no fish, home in a whale-watching port, day trips) | other (no
#                       fish) ; suggested_basis "derived". The port lists are the maintainer's of 2026-10-14 and
#                       are evidence, not a register: a vessel there may be a pleasure boat or a pilot boat.
library(DBI)
con <- dbConnect(duckdb::duckdb())
f <- function(...) shQuote(fd_curated(...), type = "sh")
aqua <- c("IS-BID", "IS-TAK", "IS-PAR", "IS-TEY", "IS-SUV", "IS-FAS", "IS-ESF", "IS-RFJ")
whale <- c("IS-REY", "IS-HUA", "IS-AKU", "IS-HAU")
q <- function(x) paste0("'", x, "'", collapse = ", ")
sql <- sprintf("
  WITH v AS (SELECT vid, year, voyage_id, pid1, epoch(T2 - T1) / 3600.0 AS dur_h FROM read_parquet(%s)),
  ld AS (SELECT DISTINCT vid, year(date) AS year FROM read_parquet(%s)),
  lb AS (SELECT DISTINCT vid, year(T1) AS year FROM read_parquet(%s)),
  hp AS (SELECT vid, year, pid1 AS home_pid, count(*) AS n FROM v WHERE pid1 IS NOT NULL GROUP BY vid, year, pid1
         QUALIFY row_number() OVER (PARTITION BY vid, year ORDER BY count(*) DESC, pid1) = 1),
  s AS (SELECT vid, year, count(*) AS voyages, round(avg(CASE WHEN dur_h < 12 THEN 1.0 ELSE 0.0 END), 3) AS day_trip_share,
               round(median(dur_h), 1) AS median_voyage_h
        FROM v GROUP BY ALL)
  SELECT s.*, ld.vid IS NOT NULL AS lands, lb.vid IS NOT NULL AS logbook, hp.home_pid,
         round(hp.n / s.voyages, 3) AS port_share,
         CASE WHEN ld.vid IS NOT NULL OR lb.vid IS NOT NULL THEN 'fishing'
              WHEN hp.home_pid IN (%s) AND s.day_trip_share >= 0.5 THEN 'aquaculture_service'
              WHEN hp.home_pid IN (%s) AND s.day_trip_share >= 0.5 THEN 'whale_watching'
              ELSE 'other' END AS suggested,
         'derived' AS suggested_basis
  FROM s LEFT JOIN ld USING (vid, year) LEFT JOIN lb USING (vid, year) LEFT JOIN hp USING (vid, year)",
  f("ais", "voyage.parquet"), f("landing", "landings.parquet"), f("logbook", "trip.parquet"), q(aqua), q(whale))
write_curated_sql(con, sql, fd_curated("check", "vessel_activity.parquet"),
                  inputs = c(fd_curated("ais", "voyage.parquet"), fd_curated("landing", "landings.parquet"),
                             fd_curated("logbook", "trip.parquet")),
                  order_by = "year, vid")
dbDisconnect(con, shutdown = TRUE)
