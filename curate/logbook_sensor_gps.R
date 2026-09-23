# logbook_sensor_gps.R — usable positions for the afli GPS logger.
#
# Input:  raw/logbooks/afli/sjalfvirkir_maelar.parquet
#         raw/logbooks/afli/rafr_sjalfvirkir_maelar.parquet
#         curated/ais/ping          (merged, cleaned track, tagged with trip)
#         curated/ais/trip.parquet  (voyage windows, to bound the interpolation)
#         curated/logbook/{trip,fishing_sample}.parquet   (.sid -> vid)
# Output: curated/logbook/sensor_gps
#
# What is wrong with the logger, precisely: the timestamp, speed and heading are
# sound. Only lon/lat are affected, by a DDMMmm encoding fault that displaces
# roughly 40% of fixes by 741 m. See curate/corrections/afli_coords.yml.
#
# So this keeps the logger's own time, speed and heading and supplies lon/lat by
# linear interpolation from the merged track onto the logger's clock.
#
# BOUNDED BY TRIP. Interpolation runs within a single voyage and never across
# two. Without that bound a logger fix falling in the gap between voyages gets a
# position drawn straight across the harbour stop - a line through land between
# the end of one trip and the start of the next. A logger fix that falls inside
# no voyage is left NA and flagged, rather than invented.
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
library(ramb)

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

# -- interpolate positions from the merged track, WITHIN each voyage ----------

track  <- open_dataset(fd_curated("ais", "ping"))
voyage <- open_dataset(fd_curated("ais", "trip.parquet")) |>
  select(vid, year, trip, T1, T2) |> collect()

years <- sort(unique(logger$year))
out   <- fd_curated("logbook", "sensor_gps")
unlink(out, recursive = TRUE)

for (yr in years) {
  lg <- logger |> filter(year == yr)
  if (!nrow(lg)) next

  # which voyage does each logger fix fall inside? none is a legitimate answer:
  # the vessel may have been in harbour, or had no AIS reception at the time.
  vy <- voyage |> filter(year == yr)
  lg <- lg |>
    left_join(vy |> select(vid, trip, T1, T2),
              by = join_by(vid, between(time, T1, T2))) |>
    select(-T1, -T2)

  tk <- track |>
    filter(year == yr, !is.na(trip)) |>
    select(vid, trip, time, lon, lat) |>
    collect() |>
    arrange(vid, trip, time)
  if (!nrow(tk)) next

  inside <- lg |> filter(!is.na(trip))
  outside <- lg |> filter(is.na(trip)) |>
    mutate(lon = NA_real_, lat = NA_real_, dt_sec = NA_real_, basis = "outside_voyage")

  if (nrow(inside)) {
    # rule = 1 (no extrapolation) inside rb_interpolate_track(): outside this
    # voyage's own fixes the answer is NA, not a position carried over from
    # its nearest endpoint. See curate/decisions/024-interpolate-track-in-ramb.md
    # for why this moved out of an inline group_modify() into ramb.
    inside <- inside |>
      ramb::rb_interpolate_track(tk, by = c("vid", "trip")) |>
      arrange(vid, trip, time) |>
      mutate(basis = if_else(is.na(lon), "no_track_cover", "interpolated_within_voyage"))
  }

  res <- bind_rows(inside, outside)
  # write_parquet_group, not write_dataset: res is materialised. See R/write_parquet.R.
  write_parquet_group(res, file.path(out, paste0("year=", yr), "data_0.parquet"))
  message(sprintf("  %d: %s fixes | %.1f%% positioned | %.1f%% outside a voyage",
                  yr, format(nrow(res), big.mark = ","),
                  100 * mean(!is.na(res$lon)),
                  100 * mean(res$basis == "outside_voyage")))
}
