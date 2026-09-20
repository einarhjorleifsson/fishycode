# Intermediate processing of the stk data
#
# Inputs:
#   data-dump/ais/stk/trail/                  — STK AIS pings (mid-keyed, all vessels)
#   data/vessels/stk_vessel_match.parquet     — mid → vid temporal lookup
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
vid <- duckdbfs::open_dataset("data/vessels/stk_vessel_match.parquet")

# stk --------------------------------------------------------------------------
# STK is Iceland's domestic AIS receiver network. Pings are keyed by `mid`
# (a STK-internal mobile ID), so we resolve to vid via a temporal interval join:
# each mid may map to different vessels over time as transponders are reused.
duckdbfs::open_dataset("data-dump/ais/stk/trail") |>
  inner_join(vid |> select(vid, mmsi, mid, loid, glid, d1, d2) |> filter(!is.na(vid)),
             by = join_by(mid, between(time, d1, d2))) |>
  mutate(year = year(time)) |>
  arrange(vid, time) |>
  group_by(year) |>
  duckdbfs::write_dataset("data-raw/ais/stk")
