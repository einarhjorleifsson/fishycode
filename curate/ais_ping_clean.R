# ais_ping_clean.R — L2 of the vessel-trail model: remove whacky positions.
#
# Input:  staging/ais/ping_tagged   (merged pings + pid harbour tag + H3)
# Output: staging/ais/ping_clean    (same columns, whacky positions dropped,
#                                    plus whack/whack2 flags for audit)
#
# A whacky point is an implausible POSITION - a speed outlier, mostly from stk.
# Not to be confused with the "wacky coordinates" of the afli GPS loggers, which
# are a DDMMmm encoding fault; different defect, different source, different fix.
# See curate/corrections/afli_coords.yml.
#
# This was previously fused inside ais_trip.R, which meant the merged ping table
# still contained whacky points and only the trip-building step ever saw a clean
# track. Anyone reading staging/ais/ping_tagged got the uncleaned data with no
# indication. Lifting it out gives the cleaning its own stage and its own output,
# as the four-layer model intends.
#
# Two filters, because one is not enough:
#   whack_fwdbwd    flags an isolated spike - both the implied speed into and out
#                   of the point exceed the threshold. Runs lazily in DuckDB.
#   whack_forward   second pass, in memory, comparing against the last RETAINED
#                   ping rather than the immediate predecessor, which catches
#                   consecutive clusters that are internally slow but
#                   geographically wrong. whack_fwdbwd cannot see those.
#
# Both live in ramb.

library(duckdbfs)
library(tidyverse)
library(ramb)

KN_MAX <- 25        # speed threshold, knots

ais   <- open_dataset(fd_staging("ais", "ping_tagged"))
years <- ais |> distinct(year) |> collect() |> pull(year) |> sort()

out   <- fd_staging("ais", "ping_clean")
marks <- fd_staging("ais", "ping_clean_marks")   # completion markers, outside
dir.create(marks, recursive = TRUE, showWarnings = FALSE)  # the dataset itself

# Target pings per in-memory batch. Pass 2 runs in R on a collected frame, so
# this, not the size of a year, is what sets peak memory.
BATCH_PINGS <- 5e6

# Three counters, not two. `dropped` used to be incremented only inside the batch
# loop, as n_in - nrow(clean), where n_in is the count AFTER pass 1 has already
# filtered - so every pass-1 rejection went unrecorded and the closing message
# understated the drop rate by a quarter. Measured 2026-09-23 on a completed run:
# 831,621 pass-1 drops against 2,306,257 reported, a true rate of 0.58% where 0.43%
# was printed.
kept <- dropped1 <- dropped2 <- 0

for (yr in years) {

  ydir <- file.path(out, paste0("year=", yr))
  if (file.exists(file.path(marks, as.character(yr)))) {
    message("Year ", yr, " already done, skipping"); next
  }
  message("Year ", yr)
  unlink(ydir, recursive = TRUE)   # any partial output from a failed attempt

  base <- ais |>
    filter(year == yr) |>
    select(vid, mmsi, time, lon, lat, speed, heading, cog, provider, pid, h3,
           depth, bbht, fao, year)

  # pass 1, lazy in DuckDB - memory is not a concern here
  flagged <- base |>
    whack_fwdbwd(kn_max = KN_MAX) |>
    mutate(whack = ifelse(is.na(whack), FALSE, whack))

  # -- batch the year by VESSEL, not by time --------------------------------
  #
  # Pass 2 used to collect() an entire year. On this machine (24 GB) that
  # reached 6.2 GB resident on a 7.6 M-ping year, and the years still to come
  # go up to 69 M pings - roughly nine times larger. It would not have finished.
  #
  # ramb::whack_forward() groups by vid internally and scans each vessel
  # independently:
  #     mutate(group_by(arrange(ungroup(x), vid, time), vid), whack2 = .fwd(...))
  # so a vessel's result depends on nothing outside that vessel. Splitting the
  # year into batches of whole vessels is therefore EXACTLY equivalent to doing
  # the year at once - it is not an approximation, and no boundary effect is
  # introduced. Splitting by time would not be equivalent, because the scan
  # carries "last retained ping" across the cut.
  # Materialise pass 1 ONCE. `flagged` is a lazy DuckDB pipeline, so every
  # collect() against it re-runs the whole whack_fwdbwd window function. Left as
  # a lazy source it would execute once for the vessel count plus once per
  # batch - 15 times over for a year like 2017, which has ~14 batches.
  # write_dataset is the right tool here precisely because this IS lazy: nothing
  # is materialised into the cached connection, so it does not accumulate.
  pass1 <- fd_staging("ais", "ping_clean_pass1.parquet")
  unlink(pass1)
  flagged |> filter(!whack) |> select(-whack) |>
    duckdbfs::write_dataset(pass1, format = "parquet")
  p1 <- open_dataset(pass1)

  vid_n <- p1 |> count(vid) |> collect() |> arrange(desc(n))

  # Pass-1 accounting. sum(vid_n$n) is the surviving row count and costs nothing -
  # it is already collected. Only the year's input needs asking for.
  n_year   <- base |> summarise(n = n()) |> pull(n)
  dropped1 <- dropped1 + (n_year - sum(as.numeric(vid_n$n)))

  batch <- cumsum(as.numeric(vid_n$n)) %/% BATCH_PINGS
  groups <- split(vid_n$vid, batch)

  for (i in seq_along(groups)) {
    g <- groups[[i]]
    clean <- p1 |>
      filter(vid %in% g) |>
      collect() |>
      whack_forward(kn_max = KN_MAX)

    n_in  <- nrow(clean)
    # `whack` was already dropped when pass 1 was materialised above
    clean <- clean |> filter(!whack2) |> select(-whack2)
    n_batch_kept <- nrow(clean)

    kept     <- kept + n_batch_kept
    dropped2 <- dropped2 + (n_in - n_batch_kept)

    # One part file per batch. Several parquet files in one hive directory is
    # normal and reads back as a single partition.
    write_parquet_group(clean, file.path(ydir, sprintf("part_%03d.parquet", i)))
    rm(clean); gc(FALSE)
    # n_in is the count going IN to pass 2, not what survived it. It was labelled
    # "kept", which made every batch line overstate the result.
    message(sprintf("  batch %d/%d: %s vessels, %s pings in, %s kept",
                    i, length(groups), length(g),
                    format(n_in, big.mark = ","), format(n_batch_kept, big.mark = ",")))
  }

  unlink(pass1)
  file.create(file.path(marks, as.character(yr)))
}

total_in <- kept + dropped1 + dropped2
message(sprintf(
  "kept %s pings; dropped %s whacky (%.2f%%) = %s in pass 1 (whack_fwdbwd) + %s in pass 2 (whack_forward)",
  format(kept, big.mark = ","), format(dropped1 + dropped2, big.mark = ","),
  100 * (dropped1 + dropped2) / total_in,
  format(dropped1, big.mark = ","), format(dropped2, big.mark = ",")))
