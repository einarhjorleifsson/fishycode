# sda_tune.R — tune the speed-distance-angle filter for AIS, and try combinations.
#
# Input:  staging/ais/ping_tagged (read-only); ramb::whack_sda() (the Rcpp port lives in ramb)
# Output: console table; the same table as curated/check/sda_tune.parquet
#
# Two years (2012: sparse stk, 2016: dense), per year in vessel batches.
# Judged by: pings dropped; speed spikes left among the kept (whack_fwdbwd on the survivors);
# and, as a PROXY for precision/recall (no ground truth exists), the median-of-7 reference
# used earlier: "corrupt" = more than 0.5 degrees from the 7-ping running median.
#   missed = corrupt pings still kept;  good_dropped = non-corrupt pings dropped.
# The proxy is weak inside long bursts of bad pings; use it for ranking, not as a count.

source(here::here("R", "paths.R"))
source(here::here("R", "write_curated.R"))
library(dplyr)
library(duckdbfs)
library(ramb)

KN <- 25; V <- KN * 0.514444
YEARS <- c(2012, 2016)
ais <- open_dataset(fd_staging("ais", "ping_tagged"))

hav <- function(x1, y1, x2, y2) 6371000 * 2 * asin(pmin(1, sqrt(
  sin(pi/180 * (y2 - y1)/2)^2 + cos(pi/180 * y1) * cos(pi/180 * y2) * sin(pi/180 * (x2 - x1)/2)^2)))
gross <- function(lon, lat, time) {
  n <- length(lon); if (n < 7L) return(rep(FALSE, n))
  t <- as.numeric(time)
  half <- (c(t[-(1:3)], rep(t[n], 3)) - c(rep(t[1], 3), t[-((n - 2):n)])) / 2
  hav(lon, lat, runmed(lon, 7), runmed(lat, 7)) > 50000 + KN * 0.514444 * half
}

# name = list(ang, distlim, vmask_min_dist, speedlim)
SDA <- list(
  default            = list(c(15, 25), c(2500, 5000), 5000, numeric()),
  `dist 1000/2000`   = list(c(15, 25), c(1000, 2000), 5000, numeric()),
  `dist 500/1000`    = list(c(15, 25), c(500, 1000),  5000, numeric()),
  `dist 250/500`     = list(c(15, 25), c(250, 500),   5000, numeric()),
  `500/1000, vmask0` = list(c(15, 25), c(500, 1000),  0,    numeric()),
  `wide 30/60 deg`   = list(c(30, 60), c(500, 1000),  5000, numeric()),
  `speed <=25 deg`   = list(25,        0,             0,    V),
  `speed <=45 deg`   = list(45,        0,             0,    V),
  `speed <=90 deg`   = list(90,        0,             0,    V),
  `speed any angle`  = list(180,       0,             0,    V),
  # combinations / vmask on its own (angle step switched off) / other vmax
  `vmask only`       = list(numeric(), numeric(), 0, numeric()),
  `vmask only 18kn`  = list(numeric(), numeric(), 0, numeric(), 18 * 0.514444),
  `vmask only 35kn`  = list(numeric(), numeric(), 0, numeric(), 35 * 0.514444),
  `speed <=25 18kn`  = list(25, 0, 0, 18 * 0.514444, 18 * 0.514444))

run_sda <- function(d, cfg, pre = NULL) {
  if (!is.null(pre)) d <- pre(d)
  kn <- if (length(cfg) >= 5) cfg[[5]] / 0.514444 else KN
  sl <- if (length(cfg[[4]]) == length(cfg[[1]])) cfg[[4]] / 0.514444 else rep(0, length(cfg[[1]]))
  dl <- if (length(cfg[[2]]) == length(cfg[[1]])) cfg[[2]] else rep(0, length(cfg[[1]]))
  r <- whack_sda(d, kn, ang = cfg[[1]], distlim = dl, speedlim_kn = sl, vmask_min_dist = cfg[[3]])
  r[is.na(r$whack_sda), names(d)]
}
drop_gross <- function(d) { g <- d |> group_by(vid) |> mutate(g = gross(lon, lat, time)) |> ungroup(); d[!g$g, ] }
fwd  <- function(k) { s <- whack_forward(k, KN); s[!s$whack2, ] }
cur  <- function(d) { f1 <- whack_fwdbwd(d, KN)$whack; fwd(d[!f1, ]) }
grs  <- function(d) { g <- d |> group_by(vid) |> mutate(g = gross(lon, lat, time)) |> ungroup(); fwd(d[!g$g, ]) }

score <- function(keep, d, nm) {
  keep_id <- keep$.id
  d |> mutate(kept = .id %in% keep_id) |>
    summarise(pings = n(), dropped = sum(!kept),
              missed = sum(!kept == FALSE & corrupt), good_dropped = sum(!kept & !corrupt)) |>
    mutate(spikes = sum(whack_fwdbwd(keep, KN)$whack), filter = nm)
}

out <- list()
for (yr in YEARS) {
  vn <- ais |> filter(year == yr, !is.na(vid)) |> count(vid) |> collect() |> arrange(desc(n))
  for (g in split(vn$vid, cumsum(as.numeric(vn$n)) %/% 5e6)) {
    d <- ais |> filter(year == yr, vid %in% g) |> select(vid, time, lon, lat) |> collect() |> arrange(vid, time)
    d <- d |> group_by(vid) |>
      mutate(corrupt = if (n() < 7) FALSE else (abs(lon - runmed(lon, 7)) > 0.5 | abs(lat - runmed(lat, 7)) > 0.5)) |>
      ungroup() |> mutate(.id = row_number())
    res <- list(score(cur(d), d, "current"), score(grs(d), d, "variant (gross + fwd)"))
    for (nm in names(SDA)) {
      s <- run_sda(d, SDA[[nm]])
      res[[length(res) + 1]] <- score(s, d, paste("sda:", nm))
      res[[length(res) + 1]] <- score(fwd(s), d, paste("sda + fwd:", nm))
    }
    # gross screen first, then vmask only, then the forward scan
    res[[length(res) + 1]] <- score(fwd(run_sda(d, SDA[["vmask only"]], pre = drop_gross)), d, "gross + vmask only + fwd")
    res[[length(res) + 1]] <- score(fwd(run_sda(d, SDA[["speed <=25 deg"]], pre = drop_gross)), d, "gross + sda speed<=25 + fwd")
    out[[length(out) + 1]] <- bind_rows(res) |> mutate(year = yr)
  }
  message(yr, " done")
}
tab <- bind_rows(out) |> group_by(filter) |>
  summarise(across(c(pings, dropped, missed, good_dropped, spikes), sum), .groups = "drop") |>
  mutate(dropped_pct = round(100 * dropped / pings, 2)) |> arrange(spikes)
print(tab, n = Inf, width = Inf)
write_curated(tab, fd_curated("check", "sda_tune.parquet"))
