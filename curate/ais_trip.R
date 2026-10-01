# ais_trip.R — L4a of the vessel-trail model: harbour-to-harbour voyages.
#
# Input:  staging/ais/ping_clean   (whacky positions already removed - L2)
#         curated/ais/harbour_stay.parquet   (stays: elapsed time at a harbour, plan 011 Phase 3)
# Output: curated/ais/trip.parquet (vid, year, trip, T1, T2, hid1, hid2, n_pings)
#         curated/ais/ping         (clean pings carrying their trip number, and `stay_pid`)
#
# Trip key is (vid, year, trip), numbered 1..n per vessel per year; a voyage
# spanning New Year is split at the boundary.
#
# T1/T2 are UPPERCASE on purpose: case encodes the level, so a trip or voyage is
# T1/T2 and an event within it is t1..t4. See curate/decisions/010-time-variable-naming.md
# before "fixing" this to lowercase.
#
# A voyage is the sea between two stays (plan 011, decision 061). Until 2026-10-01 a harbour stay was the
# span of the pings in a run of polygon-tagged pings, so one `I` ping followed by silence had span 0 and was
# bridged away, and day-trip vessels merged into year-long "voyages" (vid 2481, 2011: 185 landings, one voyage).
# Now the harbour is the stay, measured in elapsed time, from every provider (curate/harbour_stay.R).
#
# Per year:
#   1. Each ping gets the harbour of the stay it falls in (`stay_pid`), NA at sea; contiguous stay/sea runs
#      via a cumsum over that
#   2. Sea runs numbered per vessel, with departure/arrival harbours attached (the stays either side)
#   3. Trip ids joined back to the pings by time range
# `pid`, the polygon tag from ping_tagged, is kept as it was; a ping inside a polygon but not in a stay (a
# visit shorter than the stay minimum, a pass-through) is part of the voyage, as the old bridging made it.
# Event-only stays (evidence is only `event_pair`) are left out: 21 % of them have a landing against 79 %
# where ping and event evidence agree (decision 060).
#
# Whacky-point removal used to happen here. It is now its own stage in
# curate/ais_ping_clean.R, so the merged ping table is clean in its own right
# rather than only inside this script.
#
# Downstream: curate/link_trip_voyage.R (L4) ties these voyages to logbook trips.

library(duckdbfs)
library(tidyverse)

# -- Parameters ----------------------------------------------------------------

MIN_PINGS     <- 10   # trips with fewer pings than this are dropped
# The stay minimum (4 h) is a parameter of curate/harbour_stay.R, not of this script.
EXCLUDE_EVENT_ONLY <- TRUE

# Set AIS_TRIP_VIDS (comma-separated) for testing: the run then writes to staging/ais/ping_test and
# trip_test.parquet, never to curated/. NULL = all vessels.
VIDS <- if (nzchar(Sys.getenv("AIS_TRIP_VIDS"))) as.integer(strsplit(Sys.getenv("AIS_TRIP_VIDS"), ",")[[1]]) else NULL

# -- Data ----------------------------------------------------------------------

ais   <- open_dataset(fd_staging("ais", "ping_clean"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

stays <- duckdbfs::open_dataset(fd_curated("ais", "harbour_stay.parquet")) |> collect() |>
  filter(!EXCLUDE_EVENT_ONLY | evidence != "event_pair") |>
  transmute(vid, stay_pid = pid, S_in = T_in, S_out = T_out) |>
  arrange(vid, S_in)

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
  # Every step below groups by vid - stay lookup, run detection and trip
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
    # Whacky-point removal is no longer done here - it is its own stage now, in
    # curate/ais_ping_clean.R (L2), so staging/ais/ping_clean is already clean.
    clean <- base |> filter(vid %in% g) |> collect()

    # -- 1. Harbour of each ping = the stay it falls in --------------------------
    # a ping inside two overlapping stays (two harbours) takes the earlier one
    st_g  <- stays |> filter(vid %in% g)
    clean <- clean |>
      left_join(st_g, by = join_by(vid, between(time, S_in, S_out)), multiple = "first") |>
      select(-S_in, -S_out)

    runs <- clean |>
      mutate(in_harbour = !is.na(stay_pid)) |>
      arrange(vid, time) |>
      group_by(vid) |>
      mutate(
        new_run = is.na(lag(in_harbour)) | in_harbour != lag(in_harbour) |
                  (in_harbour & stay_pid != lag(stay_pid)),
        run_id  = cumsum(as.integer(new_run))
      ) |>
      group_by(vid, run_id) |>
      summarise(
        in_harbour = max(in_harbour),
        pid        = first(stay_pid[!is.na(stay_pid)]),
        T1         = min(time),
        T2         = max(time),
        n_pings    = n(),
        .groups    = "drop"
      ) |>
      arrange(vid, T1)

    # -- 2. Number trips; attach departure / arrival harbour codes -------------
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

    # -- 3. Join trip IDs back to clean pings; write parquet -------------------
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
