# 127 — The rebuild of 2026-10-17, first half: the logbook, landings and vessel side, before the STK key redo

*2026-10-17. Split chosen by the maintainer; run and checked by Claude (AI-assisted) on the maintainer's go.
fishycode 5e37114, ramb 2026.10.15.1 (the version of decision 112). The scripts, the build log, the fingerprints, a
copy of `curated/logbook` from before and the comparison are in `$FISHYDATA/archive/2026-10-17-rebuild/`.*

## The choice

TODO 77's build is split in two. The 49 outdated targets that do not read the STK key (`vessel_ais_key`) were built
now. The 20 that read it (`stk`, `stk_event`, `port_stay`, the AIS chain from `ais_ping_union` to `ais_catch`,
`trip_voyage`, `station_event`, `voyage_gear`, `vessel_ais_link` and seven checks) wait for the key redo (TODO 25).
That way the AIS chain, about 1 h 55 min in decision 112, runs once, on the new key. The key's own checks read the
logbook and the landings as witnesses, so the logbook comes first. The maintainer asked, and chose this order over
a full build now with the chain run again after the redo.

**The AIS, for now (maintainer, the same day):** "limited to vessels in the Icelandic logbooks and landings (vid
1-9999) and then all other Icelandic vessels, including SKB". This is narrower than plan 021 §6 a, which carries
foreign fishing vessels as well, and holds until the maintainer widens it. Measured on the current tables, the union
already carries this, with one gap:

- STK, through the frozen key (2026-10-09, 19,323 rows): vids 1-3699 on 1,356 rows, 3700-4999 (foreign vessels
  landing in Iceland) on 365, 5000-9999 on 1,341. The 16,261 rows with no vid are dropped.
- ASTD and astdB, Icelandic MMSIs only (`251`, `ISL`), through `vessel_identity`: every vid 1-9999 with an MMSI, and
  SKB (207 rows, vid 100000 + n, decision 119).
- Nothing in the chain reads decision 115's crosswalk or a vid from 200000, so building them widens nothing.
- **The gap:** STK's 179 SKB mobile-ids (357,642 pings) and the STK units with no vid whose MMSI is an Icelandic
  vid's (plan 022 §3) have no vid in the frozen key. That is the redo's. Foreign vids 3700-4999 reach the AIS only
  through STK; through ASTD they need plan 021 step 6, which waits.

## What was run

- `tar_make_isolated()` takes `names` (5e37114). The set was `tar_outdated()` less everything downstream of
  `vessel_ais_key`: 49 targets, and their own outdated ancestors were the same 49.
- **Before**, ahead of any build or invalidation: fingerprints of 4,798 files, 4,644,770,720 rows (2.3 min); a copy
  of `curated/logbook`'s nine tables; counts by schema.
- **Build:** 17:02:43 to 17:17:52 UTC, 49 of 49, exit 0. No tracked file changed during it, and the `once` project
  was not touched.
- **After:** `tar_outdated()` lists the 20, all downstream of the key. The 21 curated files built carry `fd.commit`
  5e37114 and `fd.dirty` false (`check_sync()`). Fingerprints: 5,164 files.

## What changed

By fingerprint (rows, schema, order-free hashes), only three directories that existed before changed:
`curated/logbook` (9 files), `staging/afli` (5) and `curated/check` (`check_landed_logged`, 1,051 to 1,152 rows).
Every other output rebuilt is identical: adb's and fs_afladagbok's staging, the landings, the vessel tables, gear and
ports. New to the store: `staging/aflaskeyti` (9 files), decision 115's identity tables (`staging/astd`,
`staging/astd_b`, `staging/emodnet`), and the raw inputs declared by decisions 113 and 116.

`curated/logbook` against its copy from before, row by row on each table's key (`.sid` or `.tid` with `schema`):

| table | added | removed | shared rows | new columns |
|---|---|---|---|---|
| `station` | adb 5,664; aflaskeyti 3,058; afli 172 | 0 | differ in `eytt_deleted` only (165,463) | `copy`, `lat1_raw`, `lat2_raw` |
| `trip` | adb 1,448; aflaskeyti 595; afli 165 | 0 | equal | `T1_basis`, `T2_basis` |
| `fishing_sample` | as `station` | 0 | differ in `eytt_deleted` only (165,463) | `t_shift_min`, `time_basis` |
| `catch` (whole rows) | adb 15,475 (56.55 kt); aflaskeyti 6,947 (282.96 kt); afli 363 (0.15 kt) | 0 | | |
| `lid_map` | adb 1,105; aflaskeyti 521; afli 160 | 0 | one row's `n_trips` changes | |

Each schema's additions are the scratch runs': decision 124 (172 stations, 165 trips, 152.9 t), decision 125 (5,664
stations, 1,448 trips, 15,475 catch rows, 56.55 kt) and plan 026 (3,058 stations, 595 trips). fs_afladagbok is
unchanged in all four tables.

**The one changed `lid_map` row.** Landing 831318 (vessel 2640, Breiðdalsvík, 2022-06-09) was claimed by
fs_afladagbok trip 58086 (one station, 2022-06-09). It is now claimed as well by afli trip 106330026 (two of decision
124's paper stations, 2022-06-07 to 06-09). This is probably one trip held twice. The two copies sit on different
vessel-days, so the merge's vessel-day anti-join keeps both. It belongs to TODO 79's station fate. Landings claimed by
two trips: 6,772 rows before, 6,800 after.

## The checks

- **TODO 78:** 172 stations carry `copy` "fs_afli". `eytt_deleted` TRUE goes from 327 to 392: 61 from NA and 4
  from FALSE. Passes. Its "`tar_outdated()` is empty" is TODO 77's.
- **TODO 80:** no adb station between `ADB_DATE_MIN` (2020-01-01) and `DATE_MAX` is dropped on a vessel-day that
  `curated/logbook` does not hold (0). adb's change is decision 125's rows only. Passes.
- **Plan 026 §8:**
  1. 7,770 staged stations, 2,778 of them foreign, foreign catch 280.3 kt, no catch row without a station. Passes.
  2. All 7,770 positions swapped back; 2,772 of the 2,778 foreign hauls lie in the box; 316 hauls at −60 min. Passes.
  3. Every kept station is on a trip, and all 521 dated trips have a `lid_map` row. Passes. The 9 second landings
     (3.5 kt) were not measured again; they are TODO 81's.
  4. The other schemas change by decisions 124 and 125 only. Passes.

  Kept by flag: foreign 2,778 stations in 579 trips (280.3 kt, 2,772 around Iceland); Icelandic 280 in 16 trips
  (2.7 kt); no twin. Items 5 and 6 (trail and catch) wait for the second half.

**Warnings.** Five targets left one each in `tar_meta()`:
- `vessel`: countrycode reads district letters as flags.
- `fs_afladagbok`: dplyr's `case_match()` is deprecated.
- The three identity tables: NAs are dropped in SQL aggregation.
- `lid_map`: a many-to-many join.

The build of 2026-10-16 kept no warning text, so it is not known whether any of them is new. No output they touch
differs beyond what is reported above.

## Left

Until the second half, `curated/ais/trail` and `curated/ais/catch` are decision 112's: the 8,894 stations and 2,208
trips added here are on no fix, and their catch is on no fix either. Next is TODO 25's key redo. Then
`tar_make_isolated()` builds the 20 (TODO 77), plan 026 §8.5-6 is checked, and the fingerprints are compared
against this record's after set (`fingerprints_after_pre.rds`).
