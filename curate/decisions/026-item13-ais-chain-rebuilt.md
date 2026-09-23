# TODO item 13's AIS chain gaps are closed

*Decided and implemented 2026-09-23. Closes TODO.md item 13.*

## What item 13 tracked

Four things not yet propagated into the large derived AIS datasets, after
the harbour-geometry fix (`staging/aux/ports.fgb` 6,019 → 10,047 features)
and the logbook merge landed:

| dataset | was |
|---|---|
| `staging/ais/ping_tagged` | 527,960,388 rows vs `ping_union`'s 527,960,318 (+70), from the pre-fix harbour geometry |
| `staging/ais/ping_clean` | 9 of 20 years, from a stopped run |
| `curated/ais/*` | not built |
| `curated/logbook/trip.parquet` | missing `.tid_land`/`match_type` |

## What happened

The whole AIS chain (`stk` → `ais_ping_union` → `ais_ping_tag` → `ais_ping_clean`
→ `ais_trip` → `logbook_sensor_gps` → `trip_voyage`) was rebuilt today,
prompted by "consolidate the ais/trail data given the new logbooks." Along
the way, three real bugs surfaced and were fixed (not just measured around):

- `duckdbfs::cached_connection()`'s default `temp_directory` wasn't reliably
  creatable, breaking any target big enough to spill to disk (`stk` first).
  Fixed in `R/duckdb_temp.R` / `_targets.R`.
- `ais_ping_clean.R` had an `rm(clean)` before a `message()` that still read
  `nrow(clean)` - fixed.
- `ramb::whack_forward()` was a plain R for-loop, ~48K pings/sec - ported to
  a compiled core (`ramb` `src/whack_forward.cpp`), ~1000x on the core scan.
  Verified byte-identical to the original on `whacks1` and stress cases.

Result, measured:

- `ping_tagged` = `ping_union` = **543,152,274** rows. The +70 is gone (the
  fix that caused it was already in; this just re-ran the chain against it).
- `ping_clean` covers all **20** years.
- `curated/ais/trip.parquet`: **720,281** trips. `curated/ais/ping`:
  **540,012,308** rows.

## What supersedes the fourth row

`trip.parquet` **will not** carry `.tid_land`/`match_type` going forward -
that was never the right design. See
[025-lid_map-stops-overwriting-trip-parquet](025-lid_map-stops-overwriting-trip-parquet.md):
`lid_map.parquet` already carries those columns independently, and having
two targets both write `trip.parquet` was an active bug (perpetual mutual
invalidation between `logbook` and `lid_map`), not a pending-work gap. Item
13's original check ("`trip.parquet` carries `.tid_land`") is retired along
with the row it described, not satisfied.
