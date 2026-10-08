# whack_median_prototype.R — prototype of a median-anchored whack filter, vs the current two passes.
#
# Input:  staging/ais/ping_tagged (read-only)
# Output: console table only.
#
# Idea: a ping is whacky if it is farther from the MEDIAN position of its 7-ping window
# than a vessel at kn_max could travel in the window's half time-span (plus a 100 m
# floor for position jitter). Unlike whack_fwdbwd it needs no "both sides agree", so
# interleaved streams do not wipe each other out; unlike whack_forward it has no anchor
# that a bad first ping can poison. Judged without the median as reference: pings kept,
# and implied speeds > kn_max left between consecutive KEPT pings.

source(here::here("R", "paths.R"))
library(dplyr)
library(duckdbfs)
library(ramb)

hav <- function(x1, y1, x2, y2) 6371000 * 2 * asin(pmin(1, sqrt(
  sin(pi/180 * (y2 - y1)/2)^2 + cos(pi/180 * y1) * cos(pi/180 * y2) * sin(pi/180 * (x2 - x1)/2)^2)))

whack_median <- function(d, kn_max = 25, k = 7, floor_m = 100) {
  d <- arrange(d, time); n <- nrow(d); h <- k %/% 2
  t <- as.numeric(d$time)
  half <- (c(t[-(1:h)], rep(t[n], h)) - c(rep(t[1], h), t[-((n - h + 1):n)])) / 2
  hav(d$lon, d$lat, runmed(d$lon, k), runmed(d$lat, k)) > kn_max * 0.514444 * half + floor_m
}

residual <- function(d) sum(rb_whack_fwdbwd(d, 25)$whack)

ev <- function(v) {
  d <- ais |> filter(vid == v) |> select(vid, time, lon, lat) |> collect() |> arrange(time)
  f1 <- rb_whack_fwdbwd(d, 25)$whack
  cur <- f1; cur[!f1] <- rb_whack_forward(d[!f1, ], 25)$whack2
  p2  <- rb_whack_forward(d, 25)$whack2
  med <- whack_median(d)
  one <- function(nm, f) tibble(vid = v, variant = nm, n = nrow(d), kept = sum(!f),
                                residual_spikes = residual(d[!f, ]))
  mf <- med; mf[!med] <- rb_whack_forward(d[!med, ], 25)$whack2   # median first, then forward scan
  # gross outliers only (> 50 km from the window median), so the scan's anchor cannot be poisoned
  g <- hav(d$lon, d$lat, runmed(d$lon, 7), runmed(d$lat, 7)) > 50000
  gf <- g; gf[!g] <- rb_whack_forward(d[!g, ], 25)$whack2
  bind_rows(one("current (pass 1 + 2)", cur), one("pass 2 only", p2), one("median", med),
            one("median + pass 2", mf), one("gross outliers + pass 2", gf))
}

ais <- open_dataset(fd_staging("ais", "ping_tagged"))
print(bind_rows(lapply(c(239, 2350, 2628, 2765, 2438, 1524, 5466), ev)), n = Inf)
