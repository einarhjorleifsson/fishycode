# What EMODnet's 2017 Iceland extract says about each MMSI.
# Side: preprocessing (emodnet). See plan 014; plan 021 step 2.
#
# Input:  raw/ais/EmodNet/is2017.csv (19.6 M rows, 1,375 MMSIs)
# Output: staging/emodnet/identity.parquet - one row per (mmsi, year, imo, cs, name, flag, ship_type), with its pings
#         and the first and last ping
#
# The counterpart of sources/astd/identity.R for the third MMSI feed, so that every MMSI the union reads has its claims
# staged (plan 021 §7). The extract pads its text fields with blanks, and writes NA for a missing IMO.

library(duckdbfs)
library(dplyr)

con <- duckdbfs::cached_connection()
emn <- dplyr::tbl(con, dplyr::sql(sprintf(
  "SELECT * FROM read_csv(%s, all_varchar = true)", DBI::dbQuoteString(con, fd_raw("ais", "EmodNet", "is2017.csv")))))

claims <- emn |>
  mutate(time = dplyr::sql("CAST(utime AS TIMESTAMP)"),
         across(c(mmsi, imo, callsign, shipname, flagisocode2, aisshiptype), ~ na_if(trimws(.x), "")),
         imo = if_else(imo == "NA" | imo == "0", NA_character_, imo)) |>
  group_by(mmsi, year = as.integer(year(time)), imo, cs = callsign, name = shipname, flag = flagisocode2,
           ship_type = aisshiptype) |>
  summarise(pings = n(), t_first = min(time, na.rm = TRUE), t_last = max(time, na.rm = TRUE), .groups = "drop") |>
  mutate(pings = as.integer(pings)) |>
  arrange(mmsi, year, desc(pings))

# staging is source-shaped and unstamped (write_curated() is for curated/ only)
claims |> duckdbfs::write_dataset(fd_staging("emodnet", "identity.parquet"))

s <- duckdbfs::open_dataset(fd_staging("emodnet", "identity.parquet")) |>
  summarise(rows = n(), mmsi = n_distinct(mmsi), pings = sum(pings)) |>
  collect()
message(sprintf("emodnet identity: %s rows, %s MMSIs, %.1f M pings",
                format(s$rows, big.mark = ","), format(s$mmsi, big.mark = ","), s$pings / 1e6))
