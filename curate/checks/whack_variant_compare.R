# whack_variant_compare.R — the current two-pass whack filter vs "gross outliers + forward scan",
# on the whole AIS ping table.
#
# Input:  staging/ais/ping_tagged (read-only)
# Output: curated/check/whack_variants_vid.parquet   one row per vid x year
#
# current  whack_fwdbwd (pass 1) then whack_forward on the survivors - what
#          curate/ais_ping_clean.R does.
# variant  drop pings > GROSS_M (+ kinematic allowance) from the median of their 7-ping window, then
#          whack_forward. No pass 1. See notes/whacky-demo.qmd in fishyweb for why.
#
# Same grain as ais_ping_clean.R: per year, batches of whole vessels (whack_forward
# scans each vessel independently, so batching by vessel is exact).
# Judged by pings kept and by speed spikes left among the KEPT pings (whack_fwdbwd
# on the survivors) - neither uses the median as reference.

source(here::here("R", "paths.R"))
source(here::here("R", "write_curated.R"))
library(dplyr)
library(duckdbfs)
library(ramb)

KN_MAX <- 25
GROSS_M <- 50000
BATCH_PINGS <- 5e6

ais <- open_dataset(fd_staging("ais", "ping_tagged"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

hav <- function(x1, y1, x2, y2) 6371000 * 2 * asin(pmin(1, sqrt(
  sin(pi/180 * (y2 - y1)/2)^2 + cos(pi/180 * y1) * cos(pi/180 * y2) * sin(pi/180 * (x2 - x1)/2)^2)))

# Gross = farther from the window median than GROSS_M PLUS what a vessel at KN_MAX could
# travel in the window's half time-span. The first version used a flat 50 km and
# dropped legitimate pings on sparse tracks (hours between pings): 858 of 2,862 vids
# lost pings against the current filter. Time-aware, a sparse track gets its slack.
# runmed() needs k <= n; a vid with fewer than 7 pings has no gross outliers by this rule.
gross <- function(lon, lat, time) {
  n <- length(lon)
  if (n < 7L) return(rep(FALSE, n))
  t <- as.numeric(time)
  half <- (c(t[-(1:3)], rep(t[n], 3)) - c(rep(t[1], 3), t[-((n - 2):n)])) / 2
  hav(lon, lat, runmed(lon, 7), runmed(lat, 7)) > GROSS_M + KN_MAX * 0.514444 * half
}

run_batch <- function(d) {
  d <- arrange(d, vid, time)
  # current
  f1  <- rb_whack_fwdbwd(d, KN_MAX)$whack
  s1  <- d[!f1, ] |> rb_whack_forward(KN_MAX)
  cur_keep <- s1[!s1$whack2, ]
  # variant
  g   <- d |> group_by(vid) |> mutate(g = gross(lon, lat, time)) |> ungroup()
  s2  <- d[!g$g, ] |> rb_whack_forward(KN_MAX)
  new_keep <- s2[!s2$whack2, ]
  per <- function(keep, nm) keep |>
    mutate(resid = rb_whack_fwdbwd(keep, KN_MAX)$whack) |>
    group_by(vid) |> summarise(kept = n(), spikes = sum(resid), .groups = "drop") |>
    rename_with(\(x) paste0(nm, "_", x), -vid)
  d |> count(vid, name = "n") |>
    left_join(per(cur_keep, "cur"), "vid") |> left_join(per(new_keep, "new"), "vid") |>
    mutate(across(-vid, \(x) coalesce(x, 0L)))
}

out <- list()
t0 <- Sys.time()
for (yr in years) {
  vid_n <- ais |> filter(year == yr, !is.na(vid)) |> count(vid) |> collect() |> arrange(desc(n))
  groups <- split(vid_n$vid, cumsum(as.numeric(vid_n$n)) %/% BATCH_PINGS)
  for (g in groups) {
    d <- ais |> filter(year == yr, vid %in% g) |> select(vid, time, lon, lat) |> collect()
    out[[length(out) + 1]] <- run_batch(d) |> mutate(year = yr)
  }
  message(sprintf("%s done, %.1f min elapsed", yr, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
res <- bind_rows(out)
minutes <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
write_curated(res, fd_curated("check", "whack_variants_vid.parquet"))

cat(sprintf("\nwhole dataset: %.1f min\n", minutes))
res |> group_by(year) |>
  summarise(n = sum(n), cur_kept = sum(cur_kept), new_kept = sum(new_kept),
            gain = new_kept - cur_kept, cur_spikes = sum(cur_spikes), new_spikes = sum(new_spikes)) |>
  print(n = Inf)
res |> summarise(across(c(n, cur_kept, new_kept, cur_spikes, new_spikes), sum)) |> print(width = Inf)
