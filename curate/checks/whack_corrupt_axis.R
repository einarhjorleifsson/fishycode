# whack_corrupt_axis.R — how many vids behave like vid 239: pings with ONE axis corrupted.
#
# Input:  staging/ais/ping_tagged (read-only)
# Output: console tables; per-vid table saved as an .rds in tempdir() (not in $FISHYDATA).
#
# Reference that does not use the whack filters: the median of the ping and its 3
# neighbours on each side, per vid. A ping > 0.5 degrees from it on an axis is
# "corrupt" on that axis (pings are minutes apart; a vessel moves < 0.1 degree).
# Compared with whack_fwdbwd (pass 1 only - pass 2 needs an R pass per vessel).

source(here::here("R", "paths.R"))
library(dplyr)
library(duckdbfs)
library(ramb)

ais <- open_dataset(fd_staging("ais", "ping_tagged"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

by_vid_year <- function(yr) {
  x <- ais |> filter(year == yr, !is.na(vid)) |> select(vid, time, lon, lat) |>
    whack_fwdbwd(kn_max = 25)
  con <- dbplyr::remote_con(x)
  src <- dbplyr::sql_render(x)
  nb <- function(col) paste0("list_median([", paste0(
    sprintf("lag(%s,%d) OVER vt", col, 3:1), collapse = ","), ",", col, ",",
    paste0(sprintf("lead(%s,%d) OVER vt", col, 1:3), collapse = ","), "])")
  q <- sprintf("
    WITH s AS (SELECT *, %s AS rlon, %s AS rlat FROM (%s) WINDOW vt AS (PARTITION BY vid ORDER BY time)),
    c AS (SELECT vid, whack,
            abs(lon - rlon) > 0.5 AS cl, abs(lat - rlat) > 0.5 AS ca FROM s)
    SELECT vid, count(*) AS n,
      sum((cl OR ca)::INT) AS corrupt, sum((cl AND NOT ca)::INT) AS c_lon,
      sum((ca AND NOT cl)::INT) AS c_lat, sum((cl AND ca)::INT) AS c_both,
      sum(coalesce(whack, false)::INT) AS flagged,
      sum((coalesce(whack, false) AND NOT (cl OR ca))::INT) AS good_dropped,
      sum((coalesce(whack, false) AND (cl OR ca))::INT) AS caught
    FROM c GROUP BY vid", nb("lon"), nb("lat"), src)
  DBI::dbGetQuery(con, q) |> mutate(year = yr)
}

t <- system.time(res <- purrr::map(years, by_vid_year) |> bind_rows())[["elapsed"]]
cat(sprintf("whole dataset, %d years: %.0f s\n", length(years), t))
saveRDS(res, file.path(tempdir(), "whack_corrupt_axis.rds"))

v <- res |> group_by(vid) |>
  summarise(across(c(n, corrupt, c_lon, c_lat, c_both, flagged, good_dropped, caught), sum)) |>
  mutate(corrupt_pct = 100 * corrupt / n, dropped_pct = 100 * good_dropped / n)

cat("\nOverall\n")
v |> summarise(vids = n(), pings = sum(n), corrupt = sum(corrupt), c_lon = sum(c_lon),
               c_lat = sum(c_lat), c_both = sum(c_both), flagged = sum(flagged),
               caught = sum(caught), good_dropped = sum(good_dropped)) |> print(width = Inf)

cat("\nVids by corrupt share of pings\n")
v |> mutate(band = cut(corrupt_pct, c(-Inf, 0, 0.1, 1, 5, 100),
                       labels = c("0", "0-0.1%", "0.1-1%", "1-5%", ">5%"))) |>
  group_by(band) |> summarise(vids = n(), pings = sum(n), corrupt = sum(corrupt),
                              good_dropped = sum(good_dropped)) |> print()

cat("\nWorst 15 vids by good pings dropped\n")
v |> arrange(desc(good_dropped)) |> head(15) |>
  select(vid, n, corrupt_pct, c_lon, c_lat, caught, good_dropped, dropped_pct) |> print()
