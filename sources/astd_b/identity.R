# What ASTD's class-B feed says about each MMSI, counted by year.
# Side: preprocessing (astd_b). See plan 014; plan 021 step 2.
#
# Input:  staging/ais/astdB/ (dump/ais/astd_b.R; all flags, 2014-2024)
# Output: staging/astd_b/identity.parquet - one row per (mmsi, year, cc_iso3, ais_class, length, breadth), with its
#         pings, pings in the box, and the first and last ping
#
# The counterpart of sources/astd/identity.R. astdB carries no name, IMO or call sign: its claims are the flag it
# derives (`cc_iso3`), the transponder class and the dimensions. No hours: the feed has no time to the next point,
# and deriving it needs a window over 0.9 B rows that nothing here uses. The box is plan 017's, as in ASTD's table.

library(duckdbfs)
library(dplyr)

astd_b <- duckdbfs::open_dataset(fd_staging("ais", "astdB"))

claims <- astd_b |>
  # astdB stores mmsi as a DOUBLE, and DuckDB renders a double as text with its decimal point
  # (curate/corrections/astdb_mmsi_double_cast.yml): cast to an integer first, BIGINT for the out-of-range ones
  mutate(mmsi = as.character(dplyr::sql("CAST(mmsi AS BIGINT)")),
         box  = lon >= -35 & lon <= 0 & lat >= 58 & lat <= 71) |>
  group_by(mmsi, year, cc_iso3, ais_class, length, breadth) |>
  summarise(pings     = n(),
            pings_box = sum(as.integer(box), na.rm = TRUE),
            t_first   = min(date_time_utc, na.rm = TRUE),
            t_last    = max(date_time_utc, na.rm = TRUE),
            .groups = "drop") |>
  mutate(year = as.integer(year), pings = as.integer(pings), pings_box = as.integer(pings_box)) |>
  arrange(mmsi, year, desc(pings))

# staging is source-shaped and unstamped (write_curated() is for curated/ only)
claims |> duckdbfs::write_dataset(fd_staging("astd_b", "identity.parquet"))

s <- duckdbfs::open_dataset(fd_staging("astd_b", "identity.parquet")) |>
  summarise(rows = n(), mmsi = n_distinct(mmsi), pings = sum(pings)) |>
  collect()
message(sprintf("astd_b identity: %s rows, %s MMSIs, %.1f M pings",
                format(s$rows, big.mark = ","), format(s$mmsi, big.mark = ","), s$pings / 1e6))
