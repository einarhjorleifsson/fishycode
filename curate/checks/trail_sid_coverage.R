# trail_sid_coverage.R — how many logbook stations find a fix in the trail? (plan 010 §3, plan 011 Phase 5)
# Side: flow, check. See plan 014.
#
# Input:  curated/logbook/station_window.parquet   (the stations: .sid, schema, vid, gear_class, windows)
#         curated/ais/trail_match/                 (every (fix, station) match, tier 1 = tow/haul/set/jig, tier 2 = day)
#         curated/ais/trail/                       (only for which vessel-years have any fix)
# Output: curated/check/trail_sid_coverage.parquet   one row per (year, schema, gear_class)
#         a figure, when STAIL_FIG names a file
#
# A station is covered when at least one fix matches it, whatever the phase (`n_any`). A station has a time
# window (`n_tw`) when the logbook gave it usable times (tow, haul, set, jig); otherwise it gets a `day` window,
# the whole station date, which matches any fix of that day and so flatters. `n_tw` is a property of the LOGBOOK
# (47 % of stations in 2008, 99 % in 2024); the share of those stations that find a fix (`n_tw_matched`) is the
# property of the TRAIL. Reading `n_tier1 / n_stations` mixes the two and mostly shows the first. A vessel with no transponder in a year can never match, so
# `n_heard` counts the stations of vessels that have at least one fix in the trail that year and `n_any_heard` /
# `n_tier1_heard` the covered ones among them. Stations without a vessel (vid <= 0) are left out. The year is
# the year the station's first window starts. Static-gear sets and hauls are separate rows in station_window
# but one station here.

library(dplyr)

con <- DBI::dbConnect(duckdb::duckdb())
q <- function(s) DBI::dbGetQuery(con, s)
swf   <- fd_curated("logbook", "station_window.parquet")
tm    <- file.path(fd_curated("ais", "trail_match"), "year=*", "month=*", "part_001.parquet")
trail <- file.path(fd_curated("ais", "trail"), "year=*", "month=*", "part_001.parquet")

DBI::dbExecute(con, glue::glue("
  CREATE TEMP TABLE st AS
  SELECT \".sid\" AS sid, schema, any_value(vid) AS vid, any_value(gear_class) AS gear_class,
         year(min(w_start)) AS year, bool_or(phase <> 'day') AS has_tw
  FROM read_parquet('{swf}') WHERE vid > 0 GROUP BY \".sid\", schema"))
DBI::dbExecute(con, glue::glue("
  CREATE TEMP TABLE mt AS
  SELECT \".sid\" AS sid, schema, bool_or(phase <> 'day') AS tier1
  FROM read_parquet('{tm}', hive_partitioning = true) GROUP BY \".sid\", schema"))
DBI::dbExecute(con, glue::glue("
  CREATE TEMP TABLE heard AS
  SELECT DISTINCT vid, year FROM read_parquet('{trail}', hive_partitioning = true)"))

out <- q("
  SELECT st.year, st.schema, coalesce(st.gear_class, 'unknown') AS gear_class,
         count(*) AS n_stations,
         count(mt.sid) AS n_any, count(*) FILTER (WHERE mt.tier1) AS n_tier1,
         count(*) FILTER (WHERE heard.vid IS NOT NULL) AS n_heard,
         count(*) FILTER (WHERE heard.vid IS NOT NULL AND mt.sid IS NOT NULL) AS n_any_heard,
         count(*) FILTER (WHERE heard.vid IS NOT NULL AND mt.tier1) AS n_tier1_heard,
         count(*) FILTER (WHERE st.has_tw) AS n_tw,
         count(*) FILTER (WHERE st.has_tw AND mt.tier1) AS n_tw_matched
  FROM st LEFT JOIN mt ON mt.sid = st.sid AND mt.schema = st.schema
          LEFT JOIN heard ON heard.vid = st.vid AND heard.year = st.year
  GROUP BY ALL ORDER BY 1, 2, 3") |> tibble::as_tibble()

out |> write_curated(fd_curated("check", "trail_sid_coverage.parquet"), inputs = c(swf))

fig <- Sys.getenv("STAIL_FIG")
if (nzchar(fig)) {
  library(ggplot2)
  d <- out |> filter(year >= 2008, year <= 2025, gear_class %in% c("static", "towed", "jigged")) |>
    group_by(year, gear_class) |>
    summarise(across(starts_with("n_"), sum), .groups = "drop") |>
    transmute(year, gear_class,
              `any match (a day window counts)` = 100 * n_any / n_stations,
              `station has recorded times (logbook)` = 100 * n_tw / n_stations,
              `matched, given recorded times (trail)` = 100 * n_tw_matched / n_tw) |>
    tidyr::pivot_longer(-c(year, gear_class), names_to = "measure", values_to = "pct")
  p <- ggplot(d, aes(year, pct, colour = measure)) +
    geom_line(aes(linetype = measure), linewidth = 0.9) + geom_point(size = 1.3) +
    scale_linetype_manual(values = c("solid", "dashed", "solid")) +
    facet_wrap(~gear_class) +
    scale_y_continuous(limits = c(0, 100)) +
    labs(x = NULL, y = "% of logbook stations", colour = NULL,
         title = "Logbook stations with at least one fix in the trail",
         subtitle = "afli and fs_afladagbok, by year of the station; the dashed line is the logbook, not the trail") +
    theme_minimal(base_size = 11) + theme(legend.position = "bottom")
  ggsave(fig, p, width = 10, height = 4.8, dpi = 150)
}
print(out |> filter(year %in% c(2008, 2012, 2016, 2020, 2024)) |> group_by(year) |>
        summarise(across(starts_with("n_"), sum), .groups = "drop") |>
        transmute(year, n_stations, pct_any = round(100 * n_any / n_stations, 1),
                  pct_recorded_times = round(100 * n_tw / n_stations, 1),
                  pct_matched_given_times = round(100 * n_tw_matched / n_tw, 1)), width = 200)
