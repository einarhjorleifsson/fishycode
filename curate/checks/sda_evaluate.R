# sda_evaluate.R — argosfilter's speed-distance-angle filter (Rcpp port) vs the whack filters.
#
# Input:  staging/ais/ping_tagged (read-only); ramb::rb_whack_sda() (the Rcpp port lives in ramb)
# Output: curated/check/whack_sda_vid.parquet   one row per vid x year x filter
#         (the console also prints seconds spent in each filter over the whole dataset)
#
# Filters, all run per year in batches of whole vessels (the grain of ais_ping_clean.R):
#   current   whack_fwdbwd, then whack_forward on the survivors   (ais_ping_clean.R)
#   variant   gross outliers (> 50 km + kinematic slack from the 7-ping median), then whack_forward
#   sda       argosfilter::sdafilter logic, vmax = 25 kn, default angles/distances
#   sda+fwd   sda, then whack_forward on the survivors
# Judged by pings kept and by speed spikes left among the KEPT pings (whack_fwdbwd).

source(here::here("R", "paths.R"))
source(here::here("R", "write_curated.R"))
library(dplyr)
library(duckdbfs)
library(ramb)

KN_MAX <- 25
VMAX_MS <- KN_MAX * 0.514444
BATCH_PINGS <- 5e6

ais <- open_dataset(fd_staging("ais", "ping_tagged"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

hav <- function(x1, y1, x2, y2) 6371000 * 2 * asin(pmin(1, sqrt(
  sin(pi/180 * (y2 - y1)/2)^2 + cos(pi/180 * y1) * cos(pi/180 * y2) * sin(pi/180 * (x2 - x1)/2)^2)))
gross <- function(lon, lat, time) {
  n <- length(lon)
  if (n < 7L) return(rep(FALSE, n))
  t <- as.numeric(time)
  half <- (c(t[-(1:3)], rep(t[n], 3)) - c(rep(t[1], 3), t[-((n - 2):n)])) / 2
  hav(lon, lat, runmed(lon, 7), runmed(lat, 7)) > 50000 + KN_MAX * 0.514444 * half
}

secs <- c(current = 0, variant = 0, sda = 0, `sda+fwd` = 0)
timed <- function(nm, expr) { t <- system.time(r <- expr)[["elapsed"]]; secs[nm] <<- secs[nm] + t; r }

summarise_kept <- function(keep, d, nm) {
  keep |> mutate(spike = rb_whack_fwdbwd(keep, KN_MAX)$whack) |>
    group_by(vid) |> summarise(kept = n(), spikes = sum(spike), .groups = "drop") |>
    right_join(count(d, vid, name = "n"), "vid") |>
    mutate(filter = nm, across(c(kept, spikes), \(x) coalesce(x, 0L)))
}

run_batch <- function(d) {
  d <- arrange(d, vid, time)
  cur <- timed("current", {
    f1 <- rb_whack_fwdbwd(d, KN_MAX)$whack
    s <- d[!f1, ] |> rb_whack_forward(KN_MAX); s[!s$whack2, ] })
  var <- timed("variant", {
    g <- d |> group_by(vid) |> mutate(g = gross(lon, lat, time)) |> ungroup()
    s <- d[!g$g, ] |> rb_whack_forward(KN_MAX); s[!s$whack2, ] })
  sda <- timed("sda", {
    r <- rb_whack_sda(d, KN_MAX, ang = c(15, 25), distlim = c(2500, 5000),
                   speedlim_kn = c(0, 0), vmask_min_dist = 5000)   # the package's own defaults
    r[is.na(r$whack_sda), names(d)] })
  sdf <- timed("sda+fwd", { s <- sda |> rb_whack_forward(KN_MAX); s[!s$whack2, ] })
  bind_rows(summarise_kept(cur, d, "current"), summarise_kept(var, d, "variant"),
            summarise_kept(sda, d, "sda"), summarise_kept(sdf, d, "sda+fwd"))
}

out <- list(); t0 <- Sys.time()
for (yr in years) {
  vid_n <- ais |> filter(year == yr, !is.na(vid)) |> count(vid) |> collect() |> arrange(desc(n))
  for (g in split(vid_n$vid, cumsum(as.numeric(vid_n$n)) %/% BATCH_PINGS)) {
    d <- ais |> filter(year == yr, vid %in% g) |> select(vid, time, lon, lat) |> collect()
    out[[length(out) + 1]] <- run_batch(d) |> mutate(year = yr)
  }
  message(sprintf("%s done, %.1f min elapsed", yr, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
res <- bind_rows(out)
write_curated(res, fd_curated("check", "whack_sda_vid.parquet"))

cat("\nseconds in each filter (whole dataset):\n"); print(round(secs))
res |> group_by(filter) |>
  summarise(pings = sum(n), kept = sum(kept), dropped = pings - kept, spikes = sum(spikes)) |> print()
