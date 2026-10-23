# 205 — The rebuild of 2026-10-23: the logbook chain, with the fate tables, every landing in the link, and the reconciled trip across voyages

*2026-10-23. 20 targets of the main project, by name with `tar_make_isolated()`, at f7c82eb with ramb 2026.10.22.2,
from a clean tree, on the maintainer's go in a status review run by Claude (AI). Fingerprints before and after
(`R/fingerprint.R`) and the scripts, log and numbers in `$FISHYDATA/archive/2026-10-23-rebuild/`. Measured by Claude,
not yet checked by a person.*

## What was built

`logbook` and the 19 targets after it: `catch_by_species_station`, `lid_map`, `catch_by_species_trip`,
`logbook_gear`, `station_window`, `station_event`, `trip_voyage`, `trip_reconciled`, `voyage_gear`, `ais_trail`,
`ais_catch` and eight checks, 15:26 to 16:26 (the trail 31 min, `ais_catch` 20 min).
`tar_outdated()` was empty after. It carries three decisions coded and checked on scratch stores the same day:
- **194:** the merge writes `curated/logbook/station_fate.parquet` (8,013,418 rows, one per staging station of every
  source) and `trip_fate.parquet` (2,175,609, one per staging trip), its invariants checked before writing;
- **203:** `lid_map` reads every landing, not those from 2007-09-01;
- **193:** `trip_reconciled`'s AIS witness spans every voyage its stations lie in.
And decision 190's leisure bound in `R/trail_sql.R` (no output changes today).

## What moved (fingerprints, 567 files before)

- **Catch on the fixes:** the landing path in 2007 fell from 1,208.6 to 209.9 kt (−998.7 kt): January to August 2007's
  landings now find their trips, and the double count of decision 191 is gone. 2008 and 2009 moved by +0.02 and +0.06
  kt; the logbook's catch on the fixes did not move. `ais_catch` holds 1,047.9 M rows (1,054.2 M before).
- **`lid_map`:** 1,533,984 matches (826,109 before): 1992-2006 newly (about 677 k), 2007 31,726 more (43,206), and 2008,
  2011 and 2012 one to six fewer.
- **`trip_reconciled`:** its new columns (a schema change), and 168 more departures (1,030,037).
- **`catch_by_species_trip`** 8,669,601 rows (+275,760, the trips newly matched), `logbook/gear` and `station_window`
  in content (the landing's gear on the newly matched trips), the checks `allocation_audit` (1,895 rows),
  `landed_logged` (1,697), `trail_agreement`, `trail_sid_coverage`.
- **The trail:** 8 of 233 monthly files. 2007-06 to 2007-09 for the newly matched trips (their gear, windows and
  fishing; `trail_match` 492 rows fewer in 2007-06 to 08); 2008-05, 2009-08, 2022-11 and 2023-07 in the voyage gear's
  columns only, `voyage_gear`'s ties chosen differently from run to run (decision 199's tie-break is not built yet).
- Unchanged: the logbook's trip, station, catch and fishing-sample tables, `catch_by_species_station`, `station_event`,
  `trip_voyage` and four checks, row for row.

## Closed and left

TODO 79 is closed: the fate tables exist with their invariants, built and recounted. Plan 024 is executed. Plan 038's
step 1 is half done (the catch units of §7.1 are next) and its step 1b is done; step 2's readers of the reconciled
trip are next. The `once` project and the AIS chain above the trail were not touched.
