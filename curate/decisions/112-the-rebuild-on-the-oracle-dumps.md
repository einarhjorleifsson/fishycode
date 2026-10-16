# 112 — The rebuild on the Oracle dumps (plan 018 phase 4, with plan 016's)

*2026-10-16. Rebuild and comparison run by Claude (AI-assisted) on the maintainer's go ("can you rebuild in the
background?"). fishycode c166aef, ramb 2026.10.15.1. Fingerprints (`R/fingerprint.R`), the build log, the scripts and
the comparison are in `$FISHYDATA/archive/2026-10-oracle-rebuild/`. Plan 018 phase 4, with plan 016's vessel tables,
which had been in code since 2026-10-14 without a build.*

## What was run

- **Prepared** (decision 111): the ten targets whose scripts moved to `raw/oracle/` and whose raw inputs are not
  declared were invalidated; `tar_outdated()` then listed 50. `staging/ais/stk` was not cleared (the maintainer).
- **Before:** fingerprints of 866 files, 3,704,323,352 rows (2.2 min). They were taken after the invalidation, which
  drops the ten targets from the store's paths, so their outputs have no before-fingerprint (Claude's mistake of
  order). Their state before is the scratch comparison of decision 111, and they are checked against it below.
- **Rebuild:** `tar_make_isolated()`, all 50 targets in one pass, 20:19 to 22:26 UTC, no stops, exit 0.
  The `once` project was not touched. No tracked file changed during the build.
- **After:** 976 files, 4,640,134,796 rows; `tar_outdated()` at 0; the 707 curated files built today all carry
  `fd.commit` c166aef and `fd.dirty` false (`check_sync()`).
- **Step times:** `ais_trail` 31.6 min, `ais_ping_clean` 20.8, `ais_catch` 20.0, `ais_voyage` 15.2 (TODO 48's check is
  10), `ais_ping_tag` 11.5, `port_stay` 5.7, `ais_ping_union` 2.8, `stk` 2.6.

## The ten invalidated targets and the vessel tables

Every file they wrote equals the scratch run B of decision 111 (edited code on `raw/oracle/`), row for row and value
for value (`EXCEPT ALL` both ways): the adb, afli and fs_afladagbok staging tables, the agf and lods landings, `gear`,
`port`, `port_code`, `stk_hid_pid`, `mmsi`, `vessel`, `vessel_class`, `vessel_sign` and `vessel_year`.
`staging/ais/stk` has B's rows in every year (2026: 9,548,521), and the two partitions no build writes any more,
`year=1970` and `year=2006` (3 rows, TODO 69). So what decision 111 found between B and the old staging is what this
rebuild changed there.

## Identical

Rebuilt and identical: `gear_window`, afli's depth units and the survey tow-time check. Not rebuilt, and identical as
they should be: `sensor_gps` and `vessel_ais_key` (the `once` project), `port_geometry`, `port_radius`, `area_h3`,
`dictionary`, the ports and the aux layers.

## Changed, and why

- **Every table of the AIS chain hashes differently.** The trail's positions, speed and heading now differ from the
  old copy in the last digits (≤ 1e-12, decision 111), so no row of `ping_clean`, `ping_tagged`, `ping`, the trail
  and what follows hashes the same. Row counts are what can be traced.
- **Pings, +17,676,293** (566.7 M to 584.4 M in `ping_clean` and `curated/ais/ping`):
  - **2026, +16,805,647.** The last build (2026-10-13) had neither the ASTD months of 2026-02 on, loaded 2026-10-15
    (decision 107), nor the STK trail to 2026-10-16. 2026 now holds 14.3 M ASTD and 9.1 M STK fixes.
  - **2013-2025, +870,664** (most in 2014-2020: +286,391 in 2017). STK's rows are unchanged in those years (decision
    111), as are ASTD, ASTDB, EMODnet, `sensor_gps` and `vessel_ais_key`. The one changed input is
    `vessel_identity` (plan 016: +240 rows), which gives the MMSI-keyed feeds their vid. Traced by elimination; no
    copy of the old `vessel_identity` was kept to name the vessels.
  - **2007-2010,** within ±38 a year; not traced.
- **Voyages +49,748, stays +56,948, `trip_voyage` +31,198, `station_event` +128,638, `trail_match` +3.79 M,
  `ais/catch` +24.8 M rows** follow the pings and the logbook.
- **Landings +32,913, landing catch +101,336:** the landings recorded since the copies the last build read (agf
  +32,914 landings, lods +32,909, decision 111), merged by `curate/landing.R`.
- **Logbook: trips +31,835, stations +62,693, catch +181,521:** adb's records since the copy the last build read
  (+36,047 trips, +62,697 stations, +181,530 catch rows in staging); afli's and fs_afladagbok's staging did not change.
  `curate/logbook.R` takes 36,797 of adb's 306,537 trips, those fs_afladagbok does not hold.
- **Vessels** (plan 016): `vessel.parquet` +206 vids and the columns `status`, `foreign`, `register`;
  `vessel_identity` +240 rows; `zombie_no` is now an integer. `mmsi`, `vessel_class`, `vessel_sign` and `vessel_year`
  are built for the first time.
- **Types:** `hid` in `landing/landings`, `hid1`/`hid2` in `logbook/trip` and `hid_land` in `lid_map` are now
  integers: the dump holds Oracle's whole numbers as integers, the old copies held doubles.
- **The checks** (`landed_logged`, `port_stay_logbook`, `trail_agreement`, `trail_sid_coverage`,
  `vessel_activity`, `voyage_sharing`) change with their inputs.

## Left

- TODO 69: the stale partitions in `staging/ais/stk`, and the same risk in every partitioned output.
- TODO 63's check (plan 016 §8) can now be run on the built vessel tables.
- `ais_catch` against the ICES data call's sharing on the same trail (vmstools 0.77 `splitAmongPings()`, which the
  data call has used since its 2.1.0): compared by reading the code only.
