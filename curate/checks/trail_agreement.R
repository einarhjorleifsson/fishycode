# trail_agreement.R — do the station and the voyage name the same logbook trip? (plan 011 Phase 5)
#
# Input:  curated/ais/trail/   (.tid from the station window, .tid_voyage from the AIS voyage's link)
# Output: curated/check/trail_agreement.parquet   one row per year
#
# The two columns come from independent evidence: `.tid` from the time window of a logbook station,
# `.tid_voyage` from the overlap of the AIS voyage with the logbook trip. Where a fix has both they should
# be the same trip (same `.tid` and same schema). Disagreement flags a bad link, a bad station window, or a
# vessel with two logbook records at once. Also the share of fixes by `n_tid_voyage` (0 = no logbook trip on the
# voyage or the fix is in no voyage; 1 = one; 2+ = trips share the voyage, `.tid_voyage` is NA).

library(dplyr)

con <- DBI::dbConnect(duckdb::duckdb())
trail <- file.path(fd_curated("ais", "trail"), "year=*", "month=*", "part_001.parquet")

out <- DBI::dbGetQuery(con, glue::glue("
  SELECT year, count(*) AS n_fixes,
         count(*) FILTER (WHERE n_tid_voyage = 0) AS n_voyage0,
         count(*) FILTER (WHERE n_tid_voyage = 1) AS n_voyage1,
         count(*) FILTER (WHERE n_tid_voyage > 1) AS n_voyage_shared,
         count(*) FILTER (WHERE \".tid\" IS NOT NULL) AS n_station_tid,
         count(*) FILTER (WHERE \".tid\" IS NOT NULL AND \".tid_voyage\" IS NOT NULL) AS n_both,
         count(*) FILTER (WHERE \".tid\" IS NOT NULL AND \".tid_voyage\" IS NOT NULL
                          AND \".tid\" = \".tid_voyage\" AND schema = schema_voyage) AS n_agree
  FROM read_parquet('{trail}', hive_partitioning = true) GROUP BY year ORDER BY year")) |> tibble::as_tibble()

out |> write_curated(fd_curated("check", "trail_agreement.parquet"), inputs = character())
print(out |> filter(year %in% c(2008, 2012, 2016, 2020, 2024)) |>
        transmute(year, n_fixes, pct_voyage0 = round(100 * n_voyage0 / n_fixes, 1), pct_voyage1 = round(100 * n_voyage1 / n_fixes, 1),
                  pct_shared = round(100 * n_voyage_shared / n_fixes, 1), n_both, pct_agree = round(100 * n_agree / n_both, 1)), width = 200)
cat("all years: both set", sum(out$n_both), " agree", round(100 * sum(out$n_agree) / sum(out$n_both), 2), "%\n")
