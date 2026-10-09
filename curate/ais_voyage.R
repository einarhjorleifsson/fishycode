# ais_voyage.R — L4a of the vessel-trail model: port-to-port voyages (ais_trip.R until plan 014).
# Side: flow, step 1. See plan 014.
#
# Input:  staging/ais/ping_clean   (whacky positions already removed - L2)
#         curated/ais/port_stay.parquet   (stays: elapsed time at a port, plan 011 Phase 3; key (vid, stay))
# Output: curated/ais/voyage.parquet (vid, year, voyage, T1, T2, pid1, pid2, n_pings)
#         curated/ais/ping           (clean pings carrying keys only: `voyage`, and `stay` where the ping is in one)
#
# Voyage key is (vid, year, voyage), numbered 1..n per vessel per year; a voyage
# spanning New Year is split at the boundary.
#
# T1/T2 are UPPERCASE on purpose: case encodes the level, so a trip or voyage is
# T1/T2 and an event within it is t1..t4. See curate/decisions/010-time-variable-naming.md
# before "fixing" this to lowercase.
#
# A voyage is the sea between two stays (plan 011, decision 061). Until 2026-10-01 a harbour stay was the
# span of the pings in a run of polygon-tagged pings, so one `I` ping followed by silence had span 0 and was
# bridged away, and day-trip vessels merged into year-long "voyages" (vid 2481, 2011: 185 landings, one voyage).
# Now the port is the stay, measured in elapsed time, from every provider (curate/port_stay.R).
# Plan 014 (decision 075): a ping carries keys, never the stay's or voyage's values; those are one row each in
# port_stay.parquet and voyage.parquet. `pid1`/`pid2` are port ids: an AIS table has no `hid`.
#
# Per year:
#   1. Each ping gets the stay it falls in (`stay`), NA at sea; contiguous stay/sea runs
#      via a cumsum over that
#   2. Sea runs numbered per vessel, with departure/arrival ports attached (the stays either side)
#   3. Voyage keys joined back to the pings by time range
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
# The stay minimum (2 h) is a parameter of curate/port_stay.R, not of this script.
EXCLUDE_EVENT_ONLY <- TRUE

# Set AIS_TRIP_VIDS (comma-separated) for testing: the run then writes to staging/ais/ping_test and
# voyage_test.parquet, never to curated/. NULL = all vessels.
VIDS <- if (nzchar(Sys.getenv("AIS_TRIP_VIDS"))) as.integer(strsplit(Sys.getenv("AIS_TRIP_VIDS"), ",")[[1]]) else NULL

# -- Data ----------------------------------------------------------------------

ais   <- open_dataset(fd_staging("ais", "ping_clean"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

stays <- duckdbfs::open_dataset(fd_curated("ais", "port_stay.parquet")) |> collect() |>
  filter(!EXCLUDE_EVENT_ONLY | evidence != "event_pair") |>
  transmute(vid, port_id = pid, T_in, T_out, stay_id = stay) |>
  arrange(vid, T_in)

# -- Main loop -----------------------------------------------------------------

trips_all <- vector("list", length(years))

# Target pings per in-memory batch - see the note below.
BATCH_PINGS <- 5e6

for (yr in years) {
  message("Year ", yr)

  base <- ais |>
    filter(year == yr) |>
    select(vid, mmsi, time, lon, lat, speed, speed_raw, heading, cog, provider, pos_basis, speed_basis,
           dt_sec, sid_gps, n_sid_gps, pid, year)
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

    # -- Voyages: the sea between two stays, numbered per vessel and year (ramb, plan 013 phase 2) -----
    # A ping takes the stay it falls in (the earlier of two that overlap); sea runs become voyages with
    # the ports of the stays either side; voyages under MIN_PINGS pings are dropped after numbering.
    # Only recorded positions cut voyages and count towards MIN_PINGS; the gps logger's reconstructed fixes
    # get their voyage by time below, like every other ping (plan 014).
    st_g <- stays |> filter(vid %in% g)
    v_b <- ramb::rb_cut_trip_voyages(clean |> filter(pos_basis == "recorded"), st_g, min_pings = MIN_PINGS)
    trips_yr_b <- v_b |>
      transmute(vid, year = as.integer(year), voyage = as.integer(voyage_id), T1, T2, pid1 = port_from, pid2 = port_to, n_pings = as.integer(n_pings))

    out_dir <- if (is.null(VIDS)) fd_curated("ais", "ping") else fd_staging("ais", "ping_test")

    # Use the in-memory clean table for the ping write. write_curated() opens a fresh
    # connection per call, as write_parquet_group() does - this is a materialised frame
    # inside a per-year loop, which is exactly the shape that accumulates (R/write_parquet.R).
    # A test run (VIDS) writes to staging, which write_curated() refuses.
    ping_b <- ramb::rb_assign_trip(clean, v_b, stays = st_g) |>
      transmute(!!!rlang::syms(names(clean)), stay = as.integer(stay_id), voyage = as.integer(voyage_id))
    f <- glue::glue("{out_dir}/year={yr}/part_{sprintf('%03d', i)}.parquet")
    if (is.null(VIDS)) write_curated(ping_b, f, inputs = fd_curated("ais", "port_stay.parquet"))
    else write_parquet_group(ping_b, f)
    rm(ping_b)

    trips_batches[[i]] <- trips_yr_b
    rm(clean); gc(FALSE)
    message(sprintf("  batch %d/%d: %s vessels, %s trips",
                    i, length(groups), length(g), nrow(trips_yr_b)))
  }

  trips_yr <- bind_rows(trips_batches)
  trips_all[[match(yr, years)]] <- trips_yr
}

# -- Collect and write the voyage table --------------------------------------------

trips <- list_rbind(trips_all)

message(glue::glue(
  "Done: {nrow(trips)} voyages across {n_distinct(trips$vid)} vessels"
))

out_trips <- if (is.null(VIDS)) fd_curated("ais", "voyage.parquet") else fd_staging("ais", "voyage_test.parquet")
if (is.null(VIDS)) write_curated(trips, out_trips, inputs = fd_curated("ais", "port_stay.parquet")) else
  write_parquet_group(trips, out_trips)

# -- QA: vid == 2765 -----------------------------------------------------------

if (FALSE) {
  trips |> filter(vid == 2765) |> arrange(year, voyage) |> print(n = 40)

  library(mapdeck)
  token <- "pk.eyJ1IjoiZmlzaHZpY2UiLCJhIjoiY2p0MXQ5dThpMDZqeDQ5bHM0MGx4dHI5cyJ9.Fed_z7mv_TgTWDRjiavU3A"
  mapdeck::set_token(token)

  open_dataset(fd_staging("ais", "ping_test")) |>
    filter(vid == 2765) |>
    collect() |>
    arrange(time) |>
    filter(!is.na(voyage)) |>
    select(voyage, lon, lat, speed) |>
    group_by(voyage) |>
    ramb::rb_plot_trail(no_lines = FALSE)
}
