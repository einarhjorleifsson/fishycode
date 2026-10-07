# whack_recipe_timing.R — how long ramb::whack_clean() takes, on a data frame and on DuckDB.
#
# Input:  staging/ais/ping_tagged (read-only)
# Output: curated/check/whack_recipe_timing.parquet   one row per year x path
#
# Times ONLY the filter, per year:
#   df      collect() of vid, time, lon, lat for the year is timed apart ("read_sec"); whack_clean() on
#           the collected frame ("filter_sec"), in batches of whole vessels as ais_ping_clean.R does.
#   duckdb  whack_clean() on the lazy table, down to a one-row count ("filter_sec" includes reading).
# The flag counts of the two paths must agree (they are compared here).

source(here::here("R", "paths.R"))
source(here::here("R", "write_curated.R"))
library(dplyr)
library(duckdbfs)
library(ramb)

ais <- open_dataset(fd_staging("ais", "ping_tagged"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()
rows <- list()
for (yr in years) {
  vn <- ais |> filter(year == yr, !is.na(vid)) |> count(vid) |> collect() |> arrange(desc(n))
  read <- filt <- flagged <- 0
  for (g in split(vn$vid, cumsum(as.numeric(vn$n)) %/% 5e6)) {
    read <- read + system.time(
      d <- ais |> filter(year == yr, vid %in% g) |> select(vid, time, lon, lat) |> collect())[["elapsed"]]
    filt <- filt + system.time(r <- whack_clean(d))[["elapsed"]]
    flagged <- flagged + sum(r$whack)
  }
  rows[[length(rows) + 1]] <- tibble(year = yr, path = "df", pings = sum(vn$n), read_sec = read, filter_sec = filt, flagged = flagged)
  message(yr, " df done")
}
for (yr in years) {
  t <- system.time(n <- ais |> filter(year == yr, !is.na(vid)) |> select(vid, time, lon, lat) |> whack_clean() |>
                     summarise(flagged = sum(as.integer(whack), na.rm = TRUE), pings = n()) |> collect())[["elapsed"]]
  rows[[length(rows) + 1]] <- tibble(year = yr, path = "duckdb", pings = n$pings, read_sec = NA_real_, filter_sec = t, flagged = n$flagged)
  message(yr, " duckdb done")
}
res <- bind_rows(rows)
write_curated(res, fd_curated("check", "whack_recipe_timing.parquet"))
res |> group_by(path) |> summarise(pings = sum(pings), read_sec = sum(read_sec), filter_sec = sum(filter_sec), flagged = sum(flagged)) |>
  mutate(minutes = round(filter_sec / 60, 1), M_pings_per_sec = round(pings / filter_sec / 1e6, 2)) |> print(width = Inf)
cat("flag counts agree between the paths in every year:",
    all((res |> filter(path == "df") |> arrange(year))$flagged == (res |> filter(path == "duckdb") |> arrange(year))$flagged), "\n")
