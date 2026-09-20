# logbook_sensor_gps.R — usable positions for the afli GPS logger.
#
# Input:  raw/logbooks/afli/sjalfvirkir_maelar.parquet
#         raw/logbooks/afli/rafr_sjalfvirkir_maelar.parquet
#         staging/ais/ping_clean            (the merged, cleaned vessel track)
#         curated/logbook/{trip,station,fishing_sample}.parquet   (visir -> vid)
# Output: curated/logbook/sensor_gps
#
# What is wrong with the logger, precisely: the timestamp, speed and heading are
# sound. Only lon/lat are affected, by a DDMMmm encoding fault that displaces
# roughly 40% of fixes by 741 m. See curate/corrections/afli_coords.yml.
#
# So this keeps the logger's own time, speed and heading and supplies lon/lat by
# linear interpolation from the merged track onto the logger's clock.
#
# WHY THIS SITS HERE AND NOT IN THE MERGE
# It used to run before curate/ais_ping_union.R, whose output it then joined as
# provider = "wacky". That was circular - the union ended up containing 26.9 M
# positions interpolated from itself - and it is why this step had to be kept
# outside the targets graph. Deriving the positions downstream of the merge
# instead removes the cycle entirely and states the model honestly: the logger is
# logbook sensor data, not an AIS feed.
#
# The alternative derivation, which recovers lon/lat from the logger's own
# reading without using AIS at all, is curate/corrections/afli_coords.R. It is
# measured but not adopted; both outputs are kept so the two can be compared.
#
# dt_sec is the gap between the two track fixes bracketing each logger
# timestamp - the interpolation interval, and the honest measure of how much to
# trust the position. Large dt_sec means a long unobserved stretch.

library(duckdbfs)
library(tidyverse)

# -- station -> vessel ---------------------------------------------------------

sid_vid <-
  open_dataset(fd_curated("logbook", "fishing_sample.parquet")) |>
  select(.sid, .tid) |>
  left_join(open_dataset(fd_curated("logbook", "trip.parquet")) |>
              filter(schema == "afli") |> select(.tid, vid), by = ".tid") |>
  filter(!is.na(vid)) |>
  select(.sid, vid) |>
  collect()

# -- logger fixes: time, speed and heading are kept; lon/lat are not ----------

logger <- bind_rows(
  open_dataset(fd_raw("logbooks", "afli", "sjalfvirkir_maelar.parquet")) |>
    select(visir, timi, breidd, lengd, skip_hradi, skip_stefna,
           botndypi, hofudlinudypi, botnhiti, hofudlinuhiti) |>
    collect() |> mutate(sensor_src = "gps1"),
  open_dataset(fd_raw("logbooks", "afli", "rafr_sjalfvirkir_maelar.parquet")) |>
    select(visir, timi, breidd, lengd, skip_hradi, skip_stefna,
           botndypi, hofudlinudypi, botnhiti, hofudlinuhiti) |>
    collect() |> mutate(sensor_src = "gps2")) |>
  filter(!is.na(timi)) |>
  rename(.sid = visir, time = timi, w_lat = breidd, w_lon = lengd,
         speed = skip_hradi, heading = skip_stefna) |>
  inner_join(sid_vid, by = ".sid") |>
  mutate(year = year(time))

# -- interpolate positions from the merged track, per vessel-year -------------

track <- open_dataset(fd_staging("ais", "ping_clean"))
years  <- sort(unique(logger$year))
out    <- fd_curated("logbook", "sensor_gps")
unlink(out, recursive = TRUE)

for (yr in years) {
  lg <- logger |> filter(year == yr)
  if (!nrow(lg)) next
  vids <- unique(lg$vid)

  tk <- track |>
    filter(year == yr, vid %in% vids) |>
    select(vid, time, lon, lat) |>
    collect() |>
    arrange(vid, time)
  if (!nrow(tk)) next

  res <- lg |>
    arrange(vid, time) |>
    group_by(vid) |>
    group_modify(function(g, key) {
      a <- tk[tk$vid == key$vid, ]
      if (nrow(a) < 2) return(mutate(g, lon = NA_real_, lat = NA_real_, dt_sec = NA_real_))
      tn <- as.numeric(g$time); an <- as.numeric(a$time)
      # rule = 1: no extrapolation. A logger fix outside the track's window gets
      # NA rather than a position invented from the nearest endpoint.
      g$lon <- approx(an, a$lon, tn, rule = 1, ties = mean)$y
      g$lat <- approx(an, a$lat, tn, rule = 1, ties = mean)$y
      before <- approx(an, an, tn, method = "constant", f = 0, rule = 1)$y
      after  <- approx(an, an, tn, method = "constant", f = 1, rule = 1)$y
      g$dt_sec <- after - before
      g
    }) |>
    ungroup() |>
    mutate(basis = if_else(is.na(lon), "no_track_cover", "interpolated_from_track"))

  res |> write_dataset(file.path(out, paste0("year=", yr)), format = "parquet")
  message(sprintf("  %d: %s fixes, %.1f%% positioned",
                  yr, format(nrow(res), big.mark = ","),
                  100 * mean(!is.na(res$lon))))
}
