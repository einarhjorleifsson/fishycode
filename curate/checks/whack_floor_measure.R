# whack_floor_measure.R — what the time-step floor min_dt_s does to ramb::rb_whack_clean().
#
# Input:  staging/ais/ping_tagged, June 2016 and June 2023: pings with a vid and lon != lat
#         (as curate/ais_ping_clean.R takes the "invalid" placeholders out first). Read-only.
#         Needs ramb >= 2026.10.08 (rb_whack_clean() with min_dt_s).
# Output: tempdir()/floor_dt.csv          time steps by feed pair (same feed / two feeds mixed)
#         tempdir()/floor_runs.csv        one row per month x floor: flags by stage, kept legs that
#                                         are plainly wrong, kept legs the floor hides
#         tempdir()/floor_given_back.csv  pings flagged at 1 s but kept at the floor
#
# Result 2026-10-08 (chose the default min_dt_s = 10): floors of 1-10 s keep no leg > 200 m at
# > 25 kn (2016: 0, 2023: the same 2 at every floor); 20 s keeps 410 + 165, 30 s 1,560 + 565,
# 60 s 5,237 + 1,644. Steps under 10 s are ~1.3 % of legs; same-second steps are almost all
# between two feeds (2016: 8,517 of 8,864).

source(here::here("R", "paths.R"))
source(here::here("curate/checks", "whack_shims.R"))  # adapters for ramb functions removed 2026-10-11
suppressMessages({library(dplyr); library(duckdbfs); library(ramb)})
ais <- open_dataset(fd_staging("ais", "ping_tagged"))
FLOORS <- c(1, 5, 10, 20, 30, 60)
MS_MAX <- 25 * 0.514444

hav <- function(lon1, lat1, lon2, lat2) {
  r <- pi / 180
  a <- sin((lat2 - lat1) * r / 2)^2 + cos(lat1 * r) * cos(lat2 * r) * sin((lon2 - lon1) * r / 2)^2
  2 * 6371000 * asin(sqrt(pmin(1, a)))
}
# legs between consecutive rows of the same vessel (x sorted by vid, time)
legs <- function(x) {
  n <- nrow(x); same <- x$vid[-1] == x$vid[-n]
  tibble(dt = as.numeric(x$time[-1]) - as.numeric(x$time[-n]),
         dist = hav(x$lon[-n], x$lat[-n], x$lon[-1], x$lat[-1]),
         p1 = x$provider[-n], p2 = x$provider[-1])[same, ]
}

dt_tab <- list(); runs <- list(); back <- list()
for (yr in c(2016, 2023)) {
  d <- ais |> filter(year == yr, month(time) == 6L, !is.na(vid)) |>
    select(vid, time, lon, lat, provider) |> collect()
  d <- d[d$lon != d$lat, ] |> arrange(vid, time, lon, lat)

  # How short are the time steps, and between which feeds? ---------------------------
  l <- legs(d)
  dt_tab[[as.character(yr)]] <- l |>
    mutate(pair = ifelse(p1 == p2, paste0("same: ", p1), "mixed feeds"),
           step = cut(dt, c(-Inf, 0, 4, 9, 29, 59, 299, Inf),
                      labels = c("0 s", "1-4 s", "5-9 s", "10-29 s", "30-59 s", "1-5 min", "> 5 min"))) |>
    count(pair, step) |> mutate(year = yr)

  # The filter at each floor ----------------------------------------------------------
  lab <- list()
  for (f in FLOORS) {
    x <- rb_whack_clean(d, min_dt_s = f)
    lab[[as.character(f)]] <- x
    k <- legs(x[!x$whack, ])
    wrong <- k$dist > 200 & k$dist / pmax(k$dt, 1) > MS_MAX
    runs[[paste(yr, f)]] <- tibble(
      year = yr, min_dt_s = f, pings = nrow(x), flagged = sum(x$whack),
      vmask = sum(x$whack_stage %in% "vmask"), spike = sum(x$whack_stage %in% "spike"),
      forward = sum(x$whack_stage %in% "forward"),
      # kept legs that are plainly wrong whatever the floor (raw step, 1 s minimum)
      kept_wrong_1km = sum(k$dist > 1000 & k$dist / pmax(k$dt, 1) > MS_MAX),
      kept_wrong_200m = sum(wrong), wrong_200m_mixed = sum(wrong & k$p1 != k$p2),
      # kept legs the floor hides: shorter than the floor, > 200 m, > 25 kn on the raw step
      kept_hidden_200m = sum(wrong & k$dt < f), hidden_mixed = sum(wrong & k$dt < f & k$p1 != k$p2))
  }

  # What a floor gives back: flagged at 1 s, kept at f, described by the step from the ping
  # before it that the floor-f run keeps
  x1 <- lab[["1"]]
  for (f in FLOORS[-1]) {
    xf <- lab[[as.character(f)]]
    stopifnot(identical(x1$time, xf$time), identical(x1$lon, xf$lon))
    kept <- !xf$whack
    gb <- which(x1$whack & kept)
    prev <- cummax(ifelse(kept, seq_along(kept), 0L))
    j <- prev[pmax(gb - 1L, 1L)]
    ok <- j > 0 & xf$vid[pmax(j, 1L)] == xf$vid[gb]
    dd <- hav(xf$lon[j[ok]], xf$lat[j[ok]], xf$lon[gb[ok]], xf$lat[gb[ok]])
    tt <- pmax(as.numeric(xf$time[gb[ok]]) - as.numeric(xf$time[j[ok]]), 1)
    back[[paste(yr, f)]] <- tibble(year = yr, min_dt_s = f, given_back = length(gb),
                                   mixed_feed = sum(xf$provider[j[ok]] != xf$provider[gb[ok]]),
                                   m_median = median(dd), s_median = median(tt),
                                   under_50m = sum(dd < 50), wrong_200m = sum(dd > 200 & dd / tt > MS_MAX))
  }
  rm(d, l, lab, x, x1, xf); gc()
}
out <- tempdir()
write.csv(bind_rows(dt_tab), file.path(out, "floor_dt.csv"), row.names = FALSE)
write.csv(bind_rows(runs), file.path(out, "floor_runs.csv"), row.names = FALSE)
write.csv(bind_rows(back), file.path(out, "floor_given_back.csv"), row.names = FALSE)
print(bind_rows(runs), width = 200); print(bind_rows(back), width = 200)
message("written to ", out)
