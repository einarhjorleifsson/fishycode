# ais_vms_track.R — STK's VMS pings against their vessel's AIS track, after the tag pass has put them on one clock
# (plan 060 §3).
# Side: flow, step 0. See plans 059 and 060.
#
# Input:  staging/ais/ping_tagged/year=<y>, the streams stk_vms and stk_ais: `time` harmonized, `time_delivered`, the
#         lag's basis
# Output: curated/check/ais_vms_track.parquet - one row per vessel and week of STK's VMS stream: its pings, those placed
#         on the AIS track (`pairs`), the lag to the track on the delivered times and on the harmonized ones (ramb's
#         track method: positive, the VMS time later than the AIS stream's for the same position), the pings whose
#         time was judged by their receipt and those it moved by more than 3 min, and the week's outcome:
#           on track       10 or more pings placed, the harmonized lag within 3 min
#           off track      10 or more placed, the harmonized lag beyond 3 min: listed, not moved (plan 060 §4)
#           not judged     fewer than 10 placed (no AIS track moving near the pings), or no AIS stream that week
#
# The study behind it is $FISHYDATA/archive/2026-11-01-vms-clock-scan/ (scripts 01 and 12); plan 060 step 1 found the
# receipt lag within 3 min of the track for 93 % of the judged pings, and 0.2-2.7 points below no lag in 2018-2026.

library(DBI)
library(dplyr)
library(ramb)

con <- duckdbfs::cached_connection()
configure_duckdb_temp()
x <- function(...) invisible(dbExecute(con, sprintf(...)))
tagged <- fd_staging("ais", "ping_tagged")
years <- sort(as.integer(sub("year=", "", list.files(tagged, pattern = "^year="))))
OFF_S <- 180
MIN_PAIRS <- 10

weeks <- vector("list", length(years))
for (i in seq_along(years)) {
  yr <- years[i]
  # the year's own folder (decision 235): VMS and AIS pings with a vid and a position
  x("CREATE OR REPLACE TEMP TABLE v AS
     SELECT vid, time, time_delivered, lon, lat, stream, lag_basis FROM read_parquet('%s/year=%d/*.parquet')
     WHERE stream IN ('stk_vms', 'stk_ais') AND vid IS NOT NULL AND lon IS NOT NULL AND lat IS NOT NULL AND time IS NOT NULL",
    tagged, yr)
  track <- function(tcol) {
    tbl(con, "v") |>
      transmute(vid, time = !!rlang::sym(tcol), lon, lat, stream) |>
      rb_create_ping_lags(reference = "stk_ais", method = "track", period = "week", min_pairs = MIN_PAIRS) |>
      filter(stream == "stk_vms") |>
      collect()
  }
  # the weeks by the harmonized time; the delivered times' lag joined to them by their own week
  after <- track("time")
  before <- track("time_delivered") |> select(vid, period, pairs_delivered = pairs, lag_delivered_s = lag_s)
  moved <- tbl(con, "v") |>
    filter(stream == "stk_vms") |>
    mutate(period = sql("CAST(date_trunc('week', time) AS DATE)")) |>
    group_by(vid, period) |>
    summarise(pings_receipt = sum(as.integer(lag_basis == "receipt"), na.rm = TRUE),
              pings_moved_3m = sum(as.integer(lag_basis == "receipt" & abs(epoch(time - time_delivered)) > 180), na.rm = TRUE),
              .groups = "drop") |>
    collect()
  w <- after |>
    select(vid, period, pings, pairs, lag_s, lag_q10_s, lag_q90_s, dist_zero_m, dist_lag_m, track_outcome = outcome) |>
    left_join(before, by = c("vid", "period")) |>
    left_join(moved, by = c("vid", "period")) |>
    mutate(year = yr,
           outcome = case_when(pairs < MIN_PAIRS | track_outcome %in% c("no reference", "one stream", "not measurable") ~ "not judged",
                               abs(lag_s) <= OFF_S ~ "on track",
                               TRUE ~ "off track"))
  stopifnot("every VMS ping in one week" = sum(w$pings) ==
              (tbl(con, "v") |> filter(stream == "stk_vms") |> count() |> pull(n)))
  weeks[[i]] <- w
  message(yr, ": ", nrow(w), " vessel-weeks; ", paste(names(table(w$outcome)), table(w$outcome), collapse = ", "))
}

d <- bind_rows(weeks) |>
  mutate(vid = as.integer(vid), across(c(pings, pairs, pairs_delivered, pings_receipt, pings_moved_3m), as.integer)) |>
  relocate(year, period, vid, pings, pairs, outcome) |>
  arrange(year, period, vid)
write_curated(d, fd_curated("check", "ais_vms_track.parquet"), script = "curate/checks/ais_vms_track.R")
