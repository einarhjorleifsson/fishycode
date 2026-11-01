# ais_feed_clock.R — the feeds' clocks: the first test on every track, right after the union (plan 059 §2, step 3).
# Side: flow, step 0. See plan 059.
#
# Input:  staging/ais/ping_union/year=<y>; raw/oracle/stk/trail (its port event rows, and posdate against recdate)
# Output: curated/check/ais_feed_clock.parquet - one row per vessel, stream and month: the stream's dt pattern, its lag
#         against STK's AIS stream with the outcome, the copies of the reference's reports it holds, and for STK's own
#         streams the share of that month's positions stamped at receipt
#
# A stream is the provider, and STK's three by the position's grid (decision 233): its AIS stream, its VMS stream (a
# hundredth of a minute) and its own units (neither). STK's port event rows are not fixes and are left out. The work is
# ramb's step 0 (2026.11.01): rb_add_ping_stream() reads the dt pattern, rb_create_ping_lags() the lag per vessel,
# stream and month against STK's AIS stream (plan 059 ask a), rb_add_ping_own_lag() the copies, the same report heard
# by two streams, whose own lag comes before the month's (ask b). The logger's positions are reconstructed from the
# track, so its lag is no clock: its outcome is "reconstructed positions" and nothing moves it (plan 059 step 2).
# Nothing reads this table yet; the tag pass will (plan 059 §3).

library(DBI)
library(dplyr)
library(ramb)

REFERENCE <- "stk_ais"
STK <- c("stk_ais", "stk_vms", "stk_unit")
COPY_S <- 10   # a copy further apart than this escapes the cross-feed duplicate flag (curate/ais_ping_clean.R's DUP_S)

con <- duckdbfs::cached_connection()
configure_duckdb_temp()
x <- function(...) invisible(dbExecute(con, sprintf(...)))
q <- function(...) dbGetQuery(con, sprintf(...))
trail <- sprintf("read_parquet('%s/year=*/*.parquet', hive_partitioning = true)", fd_raw("oracle", "stk", "trail"))
union_dir <- fd_staging("ais", "ping_union")
years <- sort(as.integer(sub("year=", "", list.files(union_dir, pattern = "^year="))))

# STK's grid in degrees, as stk_trail() converts the radians: the VMS grid first, since it lies on the AIS grid too
stream_sql <- "
  CASE WHEN u.provider <> 'stk' THEN u.provider
       WHEN e.time IS NOT NULL THEN 'stk_event'
       WHEN abs(u.lat * 6000 - round(u.lat * 6000)) < 0.0002 AND abs(u.lon * 6000 - round(u.lon * 6000)) < 0.0002 THEN 'stk_vms'
       WHEN abs(u.lat * 600000 - round(u.lat * 600000)) < 0.02 AND abs(u.lon * 600000 - round(u.lon * 600000)) < 0.02 THEN 'stk_ais'
       ELSE 'stk_unit' END"

# Recording or receipt: STK's position time against its receipt time, by stream and month (plan 059 §1 item 2)
stk_time <- q("
  SELECT year(posdate) AS year, month(posdate) AS month,
         CASE WHEN abs(poslat * 343774.677078 - round(poslat * 343774.677078)) < 0.0002 AND
                   abs(poslon * 343774.677078 - round(poslon * 343774.677078)) < 0.0002 THEN 'stk_vms'
              WHEN abs(poslat * 34377467.7078 - round(poslat * 34377467.7078)) < 0.02 AND
                   abs(poslon * 34377467.7078 - round(poslon * 34377467.7078)) < 0.02 THEN 'stk_ais'
              ELSE 'stk_unit' END AS stream,
         avg((recdate = posdate)::INT) AS stk_share_at_receipt,
         approx_quantile(epoch(recdate - posdate), 0.5) AS stk_receipt_gap_median_s
  FROM %s
  WHERE in_out_of_harbor IS NULL AND recdate IS NOT NULL AND poslat IS NOT NULL AND poslon IS NOT NULL
    AND year(posdate) BETWEEN %d AND %d
  GROUP BY ALL", trail, min(years), max(years))

units <- vector("list", length(years))
for (i in seq_along(years)) {
  yr <- years[i]
  x("CREATE OR REPLACE TEMP TABLE ev AS
     SELECT DISTINCT posdate AS time, poslon * 180 / pi() AS lon, poslat * 180 / pi() AS lat FROM %s
     WHERE in_out_of_harbor IS NOT NULL AND posdate >= TIMESTAMP '%d-01-01' AND posdate < TIMESTAMP '%d-01-01'",
    trail, yr, yr + 1L)
  # the year's own folder (AGENTS.md, DuckDB 2.0); the merged track's interval before each ping for the dt pattern
  x("CREATE OR REPLACE TEMP TABLE p AS
     SELECT *, epoch(time - lag(time) OVER (PARTITION BY vid ORDER BY time, lon, lat)) AS merged_dt_s FROM (
       SELECT u.vid, u.time, u.lon, u.lat, u.speed, %s AS stream, month(u.time) AS month
       FROM read_parquet('%s/year=%d/*.parquet') u LEFT JOIN ev e ON u.time = e.time AND u.lon = e.lon AND u.lat = e.lat
       WHERE u.vid IS NOT NULL AND u.lon IS NOT NULL AND u.lat IS NOT NULL)
     WHERE stream <> 'stk_event'", stream_sql, union_dir, yr)
  p <- tbl(con, "p")

  pattern <- rb_add_ping_stream(p, stream = stream) |>
    group_by(vid, stream, month) |>
    summarise(pings = n(), cadence_s = max(stream_cadence_s, na.rm = TRUE),
              share_off_grid = mean(as.integer(stream_off_grid), na.rm = TRUE),
              share_crossed = mean(as.integer(stream_crossed), na.rm = TRUE),
              share_merged_under_60s = mean(as.integer(merged_dt_s < 60), na.rm = TRUE), .groups = "drop") |>
    collect()
  lags <- rb_create_ping_lags(p, reference = REFERENCE, stream = stream) |>
    collect() |>
    mutate(month = as.integer(format(period, "%m"))) |>
    select(vid, stream, month, pairs, lag_s, lag_q10_s, lag_q90_s, along_m, across_m, dist_zero_m, dist_lag_m, outcome)
  copies <- rb_add_ping_own_lag(p, reference = STK, method = "copy", stream = stream) |>
    filter(!is.na(lag_own_s)) |>
    group_by(vid, stream, month) |>
    summarise(copies = n(), copies_beyond_dup_s = sum(as.integer(abs(lag_own_s) > !!COPY_S), na.rm = TRUE),
              copy_lag_median_s = median(lag_own_s, na.rm = TRUE), .groups = "drop") |>
    collect()

  # the logger's positions are interpolated from the track, so they lie on STK's fixes without being copies, and their
  # lag measures the interpolation, not a clock: both left empty
  u <- pattern |>
    left_join(lags, by = c("vid", "stream", "month")) |>
    left_join(copies, by = c("vid", "stream", "month")) |>
    mutate(year = yr,
           copies = coalesce(as.integer(copies), 0L), copies_beyond_dup_s = coalesce(as.integer(copies_beyond_dup_s), 0L),
           outcome = if_else(stream == "gps", "reconstructed positions", outcome),
           across(c(pairs, lag_s, lag_q10_s, lag_q90_s, along_m, across_m, dist_zero_m, dist_lag_m, copies,
                    copies_beyond_dup_s, copy_lag_median_s), \(v) if_else(stream == "gps", NA, v)))
  stopifnot(!anyNA(u$outcome), sum(u$pings) == q("SELECT count(*) n FROM p")$n)   # every ping in one unit, every unit an outcome
  units[[i]] <- u
  message(yr, ": ", format(sum(u$pings), big.mark = ","), " pings, ", nrow(u), " units; offset ",
          sum(u$outcome == "offset"), ", copies beyond ", COPY_S, " s ", sum(u$copies_beyond_dup_s, na.rm = TRUE))
}

d <- bind_rows(units) |>
  left_join(stk_time, by = c("year", "month", "stream")) |>
  mutate(vid = as.integer(vid), month = as.integer(month)) |>
  relocate(year, month, vid, stream, pings) |>
  arrange(year, month, vid, stream)
write_curated(d, fd_curated("check", "ais_feed_clock.parquet"), script = "curate/checks/ais_feed_clock.R")
