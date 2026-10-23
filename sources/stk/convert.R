# Intermediate processing of the stk data
# Side: preprocessing (stk). See plan 014.
#
# Inputs:
#   raw/oracle/stk/trail/, through stk_trail()    — STK AIS pings (mid-keyed, all vessels; R/stk_trail.R)
#   curated/vessel/vessel_ais_key.parquet          — mid → vid temporal lookup
#
# Output:
#   data-raw/ais/stk   — Hive-partitioned parquet (by year); ~566 M rows (Icelandic vessels)
#
# All heavy lifting is done lazily in DuckDB; data never fully enter R memory.
library(tictoc)
tic()
library(sf)
library(duckdb)
library(duckdbfs)
library(tidyverse)
duckdbfs::load_spatial()

# mid → vid match table; used for STK (temporal interval join) and as the
# authoritative MMSI → vid lookup for the commercial providers.
vid <- duckdbfs::open_dataset(fd_curated("vessel", "vessel_ais_key.parquet"))

# stk --------------------------------------------------------------------------
# STK is Iceland's domestic AIS receiver network. Pings are keyed by `mid`
# (a STK-internal mobile ID), so we resolve to vid via a temporal interval join:
# each mid may map to different vessels over time as transponders are reused.
stk_trail() |>
  # d2 is a DATE and a segment's last day runs to its end: half-open on d2 + 1, or every ping after 00:00 on
  # the last day of a period falls between two periods and is lost. An open stretch (d2_is_open) has no end: its d2
  # is an arbitrary open-end date, which as an end would drop every later ping (decision 183). Only a mid's last
  # stretch is open; the flag is also on two stretches that a later one follows. d2e stays in the output as it was.
  inner_join(vid |> select(vid, mmsi, mid, loid, glid, d1, d2, d2_is_open) |>
               group_by(mid) |> mutate(open = d2_is_open & d1 == max(d1, na.rm = TRUE)) |> ungroup() |>
               filter(!is.na(vid)) |>
               mutate(d2e = d2 + 1L, .end = if_else(open, dplyr::sql("'infinity'::DATE"), d2e)) |>
               select(-d2_is_open, -open),
             by = join_by(mid, time >= d1, time < .end)) |>
  select(-.end) |>
  mutate(year = year(time)) |>
  arrange(vid, time) |>
  group_by(year) |>
  duckdbfs::write_dataset(fd_staging("ais", "stk"))
