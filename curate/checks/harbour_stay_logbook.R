# harbour_stay_logbook.R — do the stays agree with the logbook? (plan 011 §4 Phase 3 acceptance)
#
# Input:  curated/ais/harbour_stay.parquet   (stays from AIS only)
#         curated/logbook/trip.parquet       (logbook trips, afli + fs_afladagbok)
#         curated/landing/landings.parquet   (landings, agf + lods)
# Output: curated/check/harbour_stay_logbook.parquet   one row per vessel-year
#
# Landings and logbook trips are NOT inputs to the stays (AGENTS: cycles are broken outside the DAG);
# they are only the yardstick. Per vessel-year: stays per logbook trip and stays per landing day, in
# three versions of the stays: all evidence, ping evidence only (the general rules), and event-pair
# evidence only. Before 2017 `all` and `ping` coincide. The same metric as plan 011 §2a (Phase 0,
# "voyages per logbook trip", vessel-years with >= MIN_TRIPS trips; baseline: median 0.10-0.68 in
# 2008-2016 and 0.67-1.04 in 2017-2024 today, 1.2 with the bare gap split, 59 % within +-25 %).
# Stays at a harbour with no `einar` polygon (abroad) are missing from the numerator, and a landing
# abroad is missing from the denominators' AIS counterpart; both pull the ratio down a little.

library(dplyr)
MIN_TRIPS <- 20

con <- DBI::dbConnect(duckdb::duckdb())
f <- list(stay = fd_curated("ais", "harbour_stay.parquet"), trip = fd_curated("logbook", "trip.parquet"),
          land = fd_curated("landing", "landings.parquet"))
d <- DBI::dbGetQuery(con, glue::glue("
  WITH s AS (SELECT vid, year, count(*) AS n_stay,
                    count(*) FILTER (WHERE T_in_ping IS NOT NULL) AS n_stay_ping,
                    count(*) FILTER (WHERE T_in_ev IS NOT NULL)   AS n_stay_ev
             FROM read_parquet('{f$stay}') GROUP BY ALL),
  t AS (SELECT vid, year(T1) AS year, count(DISTINCT \".tid\") AS n_trip FROM read_parquet('{f$trip}') GROUP BY ALL),
  l AS (SELECT vid, year(date) AS year, count(DISTINCT date) AS n_landing_days FROM read_parquet('{f$land}') GROUP BY ALL)
  SELECT coalesce(t.vid, l.vid, s.vid) AS vid, coalesce(t.year, l.year, s.year) AS year,
         coalesce(n_stay, 0) AS n_stay, coalesce(n_stay_ping, 0) AS n_stay_ping, coalesce(n_stay_ev, 0) AS n_stay_ev,
         coalesce(n_trip, 0) AS n_trip, coalesce(n_landing_days, 0) AS n_landing_days
  FROM t FULL JOIN l USING (vid, year) FULL JOIN s USING (vid, year)")) |>
  as_tibble() |> filter(year >= 2008)

d |> write_curated(fd_curated("check", "harbour_stay_logbook.parquet"),
                   inputs = unlist(f))

within <- function(r) mean(abs(r - 1) <= 0.25)
print(d |> filter(n_trip >= MIN_TRIPS, year <= 2025) |>
  group_by(year) |>
  summarise(vessel_years = n(),
            stay_per_trip = median(n_stay / n_trip), within25 = within(n_stay / n_trip),
            ping_per_trip = median(n_stay_ping / n_trip), ping_within25 = within(n_stay_ping / n_trip),
            stay_per_landday = median(n_stay / pmax(n_landing_days, 1)),
            .groups = "drop"), n = Inf)
