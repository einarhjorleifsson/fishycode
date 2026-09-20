# ais_trip-setting.R
# Input:  data/trail2/ — AIS consolidated parquet, with pid harbour tags
# Output: data/ais_trips.parquet  — trip table (vid, year, trip, t1, t2, hid1, hid2)
#         data/trail_trips/       — clean pings (whacky removed) with trip column
#
# Trip key: (vid, year, trip) — trips numbered 1..n per vessel per year.
# Trips spanning a year boundary are split at Dec 31 / Jan 1.
#
# Algorithm per year:
#   1. Flag isolated whacky points (whack_fwdbwd, lazy dplyr)
#   2. Detect harbour/sea state changes → cumsum run_id (lazy dplyr, collected)
#   3. Bridge harbour runs < MIN_HARBOUR_H between two sea runs (in-memory dplyr)
#   4. Number sea runs 1..n per vessel → trips with hid1/hid2
#   5. Join trip IDs back to clean pings via time-range join; write parquet

library(duckdbfs)
library(tidyverse)
library(ramb)

# -- Parameters ----------------------------------------------------------------

KN_MAX        <- 25   # whacky-point speed threshold (knots)
MIN_HARBOUR_H <-  4   # harbour dwell < this (hours) → bridged into trip
MIN_PINGS     <- 10   # trips with fewer pings than this are dropped

# Set VIDS for testing; NULL = all vessels
# VIDS <- c(2765L, 1234L, 500L, 3001L, 2100L)
VIDS <- NULL

# -- Data ----------------------------------------------------------------------

ais   <- open_dataset(fd_staging("ais", "ping_tagged"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

# -- Main loop -----------------------------------------------------------------

trips_all <- vector("list", length(years))

for (yr in years) {
  message("Year ", yr)

  base <- ais |>
    filter(year == yr) |>
    select(vid, mmsi, time, lon, lat, speed, heading, cog, provider, pid, year)
  if (!is.null(VIDS)) base <- filter(base, vid %in% VIDS)

  # -- 1. Whack filter (lazy dplyr) -------------------------------------------
  flagged <- base |> whack_fwdbwd(kn_max = KN_MAX) |> mutate(whack = ifelse(is.na(whack), FALSE, whack))

  # -- 2. RLE run detection -------------------------------------------------------
  # Collect clean pings; apply forward pass to remove remaining clusters that
  # whack_fwdbwd missed (internally slow but geographically wrong tracks).
  # Then aggregate to one row per contiguous harbour/sea run.
  clean <- flagged |>
    filter(!whack) |>
    select(vid, mmsi, time, lon, lat, speed, heading, cog, provider, pid, year) |>
    collect() |>
    whack_forward(kn_max = KN_MAX)

  runs <- clean |>
    filter(!whack2) |>
    mutate(in_harbour = !is.na(pid)) |>
    arrange(vid, time) |>
    group_by(vid) |>
    mutate(
      new_run = is.na(lag(in_harbour)) | in_harbour != lag(in_harbour),
      run_id  = cumsum(as.integer(new_run))
    ) |>
    group_by(vid, run_id) |>
    summarise(
      in_harbour = max(in_harbour),
      pid        = max(pid),
      t1         = min(time),
      t2         = max(time),
      n_pings    = n(),
      .groups    = "drop"
    ) |>
    mutate(dur_hours = as.numeric(t2 - t1, units = "hours"))

  # -- 3. Bridge short harbour stays (in-memory dplyr) -----------------------
  runs <- runs |>
    arrange(vid, t1) |>
    group_by(vid) |>
    mutate(
      bridge = in_harbour &
               dur_hours < MIN_HARBOUR_H &
               !lag(in_harbour,  default = TRUE) &
               !lead(in_harbour, default = TRUE),
      state2       = if_else(bridge, FALSE, in_harbour),
      state_change = state2 != lag(state2, default = !first(state2)),
      run_id2      = cumsum(state_change)
    ) |>
    group_by(vid, run_id2) |>
    summarise(
      in_harbour = first(state2),
      pid        = first(pid[!is.na(pid)]),
      t1         = min(t1),
      t2         = max(t2),
      n_pings    = sum(n_pings),
      .groups    = "drop"
    ) |>
    arrange(vid, t1)

  # -- 4. Number trips; attach departure / arrival harbour codes -------------
  trips_yr <- runs |>
    group_by(vid) |>
    mutate(
      hid1 = if_else(!in_harbour, lag(pid),  NA_character_),
      hid2 = if_else(!in_harbour, lead(pid), NA_character_)
    ) |>
    filter(!in_harbour) |>
    mutate(year = yr, trip = row_number()) |>
    ungroup() |>
    select(vid, year, trip, t1, t2, hid1, hid2, n_pings) |>
    filter(n_pings >= MIN_PINGS)

  # -- 5. Join trip IDs back to clean pings; write parquet -------------------
  tmp <- tempfile(fileext = ".parquet")
  write_dataset(trips_yr, tmp)

  out_dir <- if (is.null(VIDS)) fd_curated("ais", "ping") else fd_staging("ais", "ping_test")

  # Use the in-memory clean table (both passes applied) for the ping write
  clean |>
    filter(!whack2) |>
    select(-whack2) |>
    left_join(trips_yr |> select(vid, trip, t1, t2),
              by = join_by(vid, between(time, t1, t2))) |>
    select(-t1, -t2) |>
    write_dataset(glue::glue("{out_dir}/year={yr}"), format = "parquet")

  unlink(tmp)
  trips_all[[match(yr, years)]] <- trips_yr
}

# -- Collect and write trip summary --------------------------------------------

trips <- list_rbind(trips_all)

message(glue::glue(
  "Done: {nrow(trips)} trips across {n_distinct(trips$vid)} vessels"
))

out_trips <- if (is.null(VIDS)) fd_curated("ais", "trip.parquet") else fd_staging("ais", "trip_test.parquet")
write_dataset(trips, out_trips)

# -- QA: vid == 2765 -----------------------------------------------------------

if (FALSE) {
  trips |> filter(vid == 2765) |> arrange(year, trip) |> print(n = 40)

  library(mapdeck)
  token <- "pk.eyJ1IjoiZmlzaHZpY2UiLCJhIjoiY2p0MXQ5dThpMDZqeDQ5bHM0MGx4dHI5cyJ9.Fed_z7mv_TgTWDRjiavU3A"
  mapdeck::set_token(token)

  open_dataset(fd_staging("ais", "ping_test")) |>
    filter(vid == 2765) |>
    collect() |>
    arrange(time) |>
    filter(!is.na(trip)) |>
    select(trip, lon, lat, speed) |>
    group_by(trip) |>
    ramb::rb_mapdeck(no_lines = FALSE)
}
