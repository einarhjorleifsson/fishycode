# whack_recipe_evaluate.R — ramb::rb_whack_clean() vs the current filter, whole AIS ping table.
#
# Input:  staging/ais/ping_tagged (read-only)
# Output: curated/check/whack_recipe_vid.parquet   one row per vid x year x filter
#         console: summary tables
#
#   current  whack_fwdbwd, then whack_forward on the survivors   (ais_ping_clean.R today)
#   recipe   ramb::rb_whack_clean(): vmask, leg-speed spike, whack_forward. LABELS, never drops.
#
# Judged by pings flagged, by speed spikes left among the UNFLAGGED pings (whack_fwdbwd on
# them), and by track length: the summed leg distance of the vessel's track raw, and with
# each filter's flagged pings left out. A whacky ping adds a detour to the raw length, so the
# raw-minus-clean length is the track it would have invented.
# Same grain as ais_ping_clean.R: per year, batches of whole vessels.
#
# Timing and the DuckDB path are in whack_recipe_timing.R.

source(here::here("R", "paths.R"))
source(here::here("R", "write_curated.R"))
library(dplyr)
library(duckdbfs)
library(ramb)

KN <- 25
ais <- open_dataset(fd_staging("ais", "ping_tagged"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()
secs <- c(current = 0, recipe_df = 0)
timed <- function(nm, expr) { t <- system.time(r <- expr)[["elapsed"]]; secs[nm] <<- secs[nm] + t; r }

hav <- function(x1, y1, x2, y2) 6371000 * 2 * asin(pmin(1, sqrt(
  sin(pi/180 * (y2 - y1)/2)^2 + cos(pi/180 * y1) * cos(pi/180 * y2) * sin(pi/180 * (x2 - x1)/2)^2)))
# summed leg distance (km) of each vessel's track through the pings in `d` (sorted by vid, time)
path_km <- function(d) d |> group_by(vid) |>
  summarise(km = sum(hav(lon[-n()], lat[-n()], lon[-1], lat[-1]), na.rm = TRUE) / 1000, .groups = "drop")

tally <- function(d, flag, nm) {
  keep <- d[!flag, ]
  keep |> mutate(spike = rb_whack_fwdbwd(keep, KN)$whack) |>
    group_by(vid) |> summarise(kept = n(), spikes = sum(spike), .groups = "drop") |>
    left_join(path_km(keep) |> rename(path_km = km), "vid") |>
    right_join(count(d, vid, name = "n") |> left_join(path_km(d) |> rename(raw_km = km), "vid"), "vid") |>
    mutate(filter = nm, across(c(kept, spikes), \(x) coalesce(x, 0L)))
}

out <- list(); t0 <- Sys.time()
for (yr in years) {
  vn <- ais |> filter(year == yr, !is.na(vid)) |> count(vid) |> collect() |> arrange(desc(n))
  for (g in split(vn$vid, cumsum(as.numeric(vn$n)) %/% 5e6)) {
    d <- ais |> filter(year == yr, vid %in% g) |> select(vid, time, lon, lat) |> collect() |> arrange(vid, time, lon, lat)
    cur <- timed("current", { f1 <- rb_whack_fwdbwd(d, KN)$whack; f <- f1; f[!f1] <- rb_whack_forward(d[!f1, ], KN)$whack2; f })
    rec <- timed("recipe_df", rb_whack_clean(d, KN))
    stopifnot(nrow(rec) == nrow(d), all(rec$vid == d$vid), all(rec$time == d$time), all(rec$lon == d$lon))
    out[[length(out) + 1]] <- bind_rows(tally(d, cur, "current"), tally(d, rec$whack, "recipe")) |> mutate(year = yr)
  }
  message(sprintf("%s done (data frames), %.1f min", yr, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
res <- bind_rows(out)
write_curated(res, fd_curated("check", "whack_recipe_vid.parquet"))

cat("\nseconds in each filter (inside the scoring loop):\n"); print(round(secs))
res |> group_by(filter) |> summarise(pings = sum(n), flagged = pings - sum(kept), spikes = sum(spikes),
                                    raw_km = sum(raw_km), clean_km = sum(path_km)) |> print(width = Inf)
v <- res |> group_by(vid, filter) |> summarise(flagged = sum(n - kept), .groups = "drop") |> tidyr::pivot_wider(names_from = filter, values_from = flagged)
cat("\nvids: recipe flags fewer / more / same:", sum(v$recipe < v$current), sum(v$recipe > v$current), sum(v$recipe == v$current), "\n")
