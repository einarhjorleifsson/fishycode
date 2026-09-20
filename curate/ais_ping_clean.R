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

out <- fd_staging("ais", "ping_clean")
unlink(out, recursive = TRUE)

kept <- dropped <- 0L

for (yr in years) {
  message("Year ", yr)

  base <- ais |>
    filter(year == yr) |>
    select(vid, mmsi, time, lon, lat, speed, heading, cog, provider, pid, h3,
           depth, bbht, fao, year)

  # pass 1, lazy
  flagged <- base |>
    whack_fwdbwd(kn_max = KN_MAX) |>
    mutate(whack = ifelse(is.na(whack), FALSE, whack))

  # pass 2, in memory on what survived
  clean <- flagged |>
    filter(!whack) |>
    collect() |>
    whack_forward(kn_max = KN_MAX)

  n_in  <- nrow(clean)
  clean <- clean |> filter(!whack2) |> select(-whack, -whack2)

  kept    <- kept + nrow(clean)
  dropped <- dropped + (n_in - nrow(clean))

  clean |> write_dataset(file.path(out, paste0("year=", yr)), format = "parquet")
}

message(sprintf("kept %s pings, dropped %s as whacky (%.2f%%)",
                format(kept, big.mark = ","), format(dropped, big.mark = ","),
                100 * dropped / (kept + dropped)))
