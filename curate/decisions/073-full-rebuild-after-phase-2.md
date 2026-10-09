# 073 — The full rebuild after plan 013 phase 2: every difference has a cause; three defects found

*2026-10-09. Rebuild and comparison run by Claude (AI-assisted) at fishycode 09a18fc (clean tree) with ramb 9789c0c
(installed from GitHub, checked to be an `-O2` build). Follows decision 072; TODO 37 was merged for it (3df46d8).*

## What was run

- **Before:** fingerprints of all 872 files the 60 targets record (3,886,669,709 rows): per file the rows, the schema,
  a hash of every row (geometry excluded) and one hash per column; an md5 for non-parquet files.
- **Rebuild, first try:** plain `tar_make()` in one R session (TODO 37's check). 17 targets completed; at the 18th
  (`landing`) the session's memory footprint had grown to 111 GB on this 24 GB machine and it thrashed, though
  `landing`'s inputs had the usual row counts. It was stopped.
- **Rebuild:** `tar_make_isolated()`, one session per target: the other 41 targets, 08:56–11:12, none failed, none
  outdated afterwards.
- **After:** the same fingerprints (3,886,810,978 rows), compared file by file and column by column.

## Measured

50 outputs are identical. Every other difference has a cause:

| Cause | Outputs |
|---|---|
| **Vessel key** (TODO 40 fix, decision 072): 19,319 → 19,323 rows; segments 3,116 → 3,120; twins 30 → 33; discrepancies 405 → 402 | `vid`/`mmsi` of STK pings in `staging/ais/stk` and the union, tag and clean (2015–2017, 2020–2026); `ping_clean` and `curated/ais/ping` −119 pings; stays 1,551,604 → 1,551,598; voyages 1,372,656 → 1,372,652; trail −125 fixes; `trail_match` +965; `stk_event`; the key checks; the statistics in `harbour_class` and `harbour_radius` (their `class` and `r_out` columns are unchanged) |
| **Planned** | `ping_tagged` without `geom` (18 → 14.6 GB); `link/trip_voyage` 797,391 → 797,663 (270 from the `(.tid, schema)` fix of decision 072, 2 from the key) |
| **Type** | `year` DOUBLE → INTEGER in `ais/trip` and `link/trip_voyage`, from the `ais_trip.R` port. Decision 072's check compared values, so it missed the type. |
| **ramb recode** | 2017 speeds in the union: only EMODnet's are computed (`ais_ping_union.R:165`, `rb_calc_speed`), now with Vincenty instead of `traipse` (within 6e-10 on test tracks). Consistent; not measured row by row. |
| **Non-determinism** | `staging/afli/depth` and `curated/logbook/station` `z1`/`z2`: `afli_depth_units.R` sorts on `(vid, date)` only, and the tie order moves the fathoms → metres switch date of 12–15 of 809 vessels (5 shuffles). `check/ais_key_split_candidates` positions: DuckDB's parallel `sum()` of doubles differs in its last bits from run to run (4 runs, 4 results). |
| **File format** | the five `.gpkg` files: a GeoPackage stores its write time (`gpkg_contents.last_change`); the tables built from them (`area_h3`, `port`, `port_geometry`, `harbour`) are identical. |

**Limits.** The old files were overwritten, and the scratch copies of earlier tests were lost when the machine
restarted that morning, so the key's changed mids are not listed row by row and the speed change is not sized.

## What follows

- TODO 37: the global-environment cleanup is not enough for a one-session build; the item is rewritten.
- New TODO items: the depth tie flicker (47), the key audit's undeclared dependency on `ping_union` (46), and
  `ais_trip.R` taking 51 min against 9.4 (48).
- The maintainer's direction of the same day (TODO 45) changes the shape of the graph before phase 3.
