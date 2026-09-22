# ais_trip.R — L4a of the vessel-trail model: harbour-to-harbour voyages.
#
# Input:  staging/ais/ping_clean   (whacky positions already removed - L2)
# Output: curated/ais/trip.parquet (vid, year, trip, T1, T2, hid1, hid2, n_pings)
#         curated/ais/ping         (clean pings carrying their trip number)
#
# Trip key is (vid, year, trip), numbered 1..n per vessel per year; a voyage
# spanning New Year is split at the boundary.
#
# T1/T2 are UPPERCASE on purpose: case encodes the level, so a trip or voyage is
# T1/T2 and an event within it is t1..t4. See curate/decisions/010-time-variable-naming.md
# before "fixing" this to lowercase.
#
# Per year:
#   1. Contiguous harbour/sea runs via a cumsum over the pid tag
#   2. Harbour stays shorter than MIN_HARBOUR_H bridged into the surrounding trip
#   3. Sea runs numbered per vessel, with departure/arrival harbours attached
#   4. Trip ids joined back to the pings by time range
#
# Whacky-point removal used to happen here. It is now its own stage in
# curate/ais_ping_clean.R, so the merged ping table is clean in its own right
# rather than only inside this script.
#
# Downstream: curate/link_trip_voyage.R (L4) ties these voyages to logbook trips.

library(duckdbfs)
library(tidyverse)

# -- Parameters ----------------------------------------------------------------

MIN_HARBOUR_H <-  4   # harbour dwell < this (hours) → bridged into trip
MIN_PINGS     <- 10   # trips with fewer pings than this are dropped

# Set VIDS for testing; NULL = all vessels
# VIDS <- c(2765L, 1234L, 500L, 3001L, 2100L)
VIDS <- NULL

# -- Data ----------------------------------------------------------------------

ais   <- open_dataset(fd_staging("ais", "ping_clean"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

# -- Main loop -----------------------------------------------------------------

trips_all <- vector("list", length(years))

# Target pings per in-memory batch - see the note below.
BATCH_PINGS <- 5e6

for (yr in years) {
  message("Year ", yr)

  base <- ais |>
    filter(year == yr) |>
    select(vid, mmsi, time, lon, lat, speed, heading, cog, provider, pid, year)
  if (!is.null(VIDS)) base <- filter(base, vid %in% VIDS)

  # -- Batch the year by VESSEL ----------------------------------------------
  #
  # This loop used to collect() a whole year. On a 24 GB machine that does not
  # survive the large years: 2017 alone carries 69 M pings, nine times the size
  # of the year that already reached 6.2 GB resident.
  #
  # Every step below groups by vid - run detection, the harbour bridge, and trip
  # numbering - so a vessel's trips depend on nothing outside that vessel.
  # Batching whole vessels is therefore EXACTLY equivalent to processing the year
  # at once, not an approximation. Batching by time would NOT be: a run that
  # straddles the cut would be split into two.
  vid_n  <- base |> count(vid) |> collect() |> arrange(desc(n))
  groups <- split(vid_n$vid, cumsum(as.numeric(vid_n$n)) %/% BATCH_PINGS)

  out_dir <- if (is.null(VIDS)) fd_curated("ais", "ping") else fd_staging("ais", "ping_test")
  unlink(file.path(out_dir, paste0("year=", yr)), recursive = TRUE)

  trips_batches <- vector("list", length(groups))

  for (i in seq_along(groups)) {
    g <- groups[[i]]
    # -- 1. RLE run detection ---------------------------------------------------
    # Whacky-point removal is no longer done here - it is its own stage now, in
    # curate/ais_ping_clean.R (L2), so staging/ais/ping_clean is already clean.
    clean <- base |> filter(vid %in% g) |> collect()

    runs <- clean |>
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
        T1         = min(time),
        T2         = max(time),
        n_pings    = n(),
        .groups    = "drop"
      ) |>
      mutate(dur_hours = as.numeric(T2 - T1, units = "hours"))

    # -- 3. Bridge short harbour stays (in-memory dplyr) -----------------------
    runs <- runs |>
      arrange(vid, T1) |>
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
        T1         = min(T1),
        T2         = max(T2),
        n_pings    = sum(n_pings),
        .groups    = "drop"
      ) |>
      arrange(vid, T1)

    # -- 4. Number trips; attach departure / arrival harbour codes -------------
    trips_yr_b <- runs |>
      group_by(vid) |>
      mutate(
        hid1 = if_else(!in_harbour, lag(pid),  NA_character_),
        hid2 = if_else(!in_harbour, lead(pid), NA_character_)
      ) |>
      filter(!in_harbour) |>
      mutate(year = yr, trip = row_number()) |>
      ungroup() |>
      select(vid, year, trip, T1, T2, hid1, hid2, n_pings) |>
      filter(n_pings >= MIN_PINGS)

    # -- 5. Join trip IDs back to clean pings; write parquet -------------------
    # A write of trips_yr to a tempfile stood here and was unlinked four lines
    # later without ever being read. Removed: it was dead, and it registered a
    # frame into the cached duckdb connection on every year of the loop.

    out_dir <- if (is.null(VIDS)) fd_curated("ais", "ping") else fd_staging("ais", "ping_test")

    # Use the in-memory clean table for the ping write. write_parquet_group, not
    # write_dataset - this is a materialised frame inside a per-year loop, which
    # is exactly the shape that accumulates. See R/write_parquet.R.
    clean |>
      left_join(trips_yr_b |> select(vid, trip, T1, T2),
                by = join_by(vid, between(time, T1, T2))) |>
      select(-T1, -T2) |>
      write_parquet_group(glue::glue("{out_dir}/year={yr}/part_{sprintf('%03d', i)}.parquet"))

    trips_batches[[i]] <- trips_yr_b
    rm(clean); gc(FALSE)
    message(sprintf("  batch %d/%d: %s vessels, %s trips",
                    i, length(groups), length(g), nrow(trips_yr_b)))
  }

  trips_yr <- bind_rows(trips_batches)
  trips_all[[match(yr, years)]] <- trips_yr
}

# -- Collect and write trip summary --------------------------------------------

trips <- list_rbind(trips_all)

message(glue::glue(
  "Done: {nrow(trips)} trips across {n_distinct(trips$vid)} vessels"
))

out_trips <- if (is.null(VIDS)) fd_curated("ais", "trip.parquet") else fd_staging("ais", "trip_test.parquet")
write_parquet_group(trips, out_trips)

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
