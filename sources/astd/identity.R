# What ASTD says about each MMSI: its static claims, counted by year.
# Side: preprocessing (astd). See plan 014; plan 021 step 2.
#
# Input:  staging/ais/astd/ (dump/ais/astd.R; all flags, 2013-01 to 2026-06)
# Output: staging/astd/identity.parquet - one row per (mmsi, year, imo, name, flagcode, flagname, astd_cat,
#         sizegroup_gt), with its pings, hours, pings and hours in the box, and the first and last ping
#
# Source-shaped: the claims as the feed makes them, every combination kept, nothing chosen. Which IMO an MMSI carries
# in a year, and whether that IMO names a hull, is the crosswalk's call (curate/vessel_ais_link.R). The feed sends the
# static fields with every ping, so a change within a year shows as two rows, with the first and last ping of each.
#
# - `imo` is NA where the feed has 0 (its placeholder); an IMO is not checked here (no check digit, no register).
# - `mmsi` is the feed's integer as text: ASTD stores MMSI as INTEGER, so a leading zero (a coast station, a group
#   call) was lost before staging. The crosswalk reads such an MMSI as invalid, which it is for a vessel.
# - hours are `sec_nextpoint` capped at 1 h, as in plan 021 §2. The feed's duplicated pings (one copy with
#   sec_nextpoint = 1, curate/corrections/ping_union_duplicate_keys.yml) are counted: they add a ping and a second.
# - the box is plan 017's, 35 °W-0°, 58-71 °N, Icelandic and Faroese waters: it ranks the MMSIs a person reviews
#   first, and plan 021 §2.2 reports it.

library(duckdbfs)
library(dplyr)

astd <- duckdbfs::open_dataset(fd_staging("ais", "astd"))

claims <- astd |>
  mutate(mmsi = as.character(mmsi),
         imo  = if_else(imonumber > 0L, as.character(imonumber), NA_character_),
         h    = pmin(sec_nextpoint, 3600) / 3600,
         box  = longitude >= -35 & longitude <= 0 & latitude >= 58 & latitude <= 71) |>
  group_by(mmsi, year, imo, name = vesselname, flagcode, flagname, astd_cat, sizegroup_gt) |>
  summarise(pings     = n(),
            hours     = sum(h, na.rm = TRUE),
            pings_box = sum(as.integer(box), na.rm = TRUE),
            hours_box = sum(if_else(box, h, 0), na.rm = TRUE),
            t_first   = min(date_time_utc, na.rm = TRUE),
            t_last    = max(date_time_utc, na.rm = TRUE),
            .groups = "drop") |>
  mutate(year = as.integer(year), pings = as.integer(pings), pings_box = as.integer(pings_box)) |>
  arrange(mmsi, year, desc(pings))

# staging is source-shaped and unstamped (write_curated() is for curated/ only)
claims |> duckdbfs::write_dataset(fd_staging("astd", "identity.parquet"))

s <- duckdbfs::open_dataset(fd_staging("astd", "identity.parquet")) |>
  summarise(rows = n(), mmsi = n_distinct(mmsi), pings = sum(pings), hours = sum(hours)) |>
  collect()
message(sprintf("astd identity: %s rows, %s MMSIs, %.1f M pings, %.1f M hours",
                format(s$rows, big.mark = ","), format(s$mmsi, big.mark = ","), s$pings / 1e6, s$hours / 1e6))
