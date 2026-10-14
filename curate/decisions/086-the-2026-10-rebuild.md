# 086 — The 2026-10 rebuild: every difference traced

*2026-10-14. Rebuild and comparison run by Claude (AI-assisted), on the maintainer's go of 2026-10-13. fishycode
b1e21c9..36c480b, ramb 2026.10.13.3. Fingerprints (`R/fingerprint.R`), the build log, the scripts and the
comparison are in `$FISHYDATA/archive/2026-10-rebuild/`. Folded in before the rebuild, by the maintainer's choice:
decisions 082 (pids pinned), 083 (afli keeps its recorded times), 084 (`station_type`) and 085 (gear codes on the
trail).*

## What was run

- **Before:** 845 files, 3,449,630,359 rows (1.6 min), with `tar_outdated()` at 0.
- **Rebuild:** `tar_invalidate(everything())`, then `tar_make_isolated()`: all 46 targets of the main project in
  one pass, from 22:10 to 23:59 UTC on 2026-10-13, with no stops. The `once` project was not touched.
- **After:** 846 files (+ `overrides/port_pid_pinned.csv`), 3,453,806,694 rows, and `tar_outdated()` at 0.
- **Step times:** `ais_ping_clean` 21.2 min, `ais_trail` 18.2, `ais_voyage` 13.8 (29 at decision 079; TODO 48's
  check is 10), `shapes_raw` 10.5, `ais_ping_tag` 9.9, `area_h3` 6.9, `port_stay` 5.6.

## Identical

These match file by file and column by column:
- stays, voyages, `trip_voyage` and `lid_map`;
- the landings and both catch-by-species tables;
- the logbook trip, catch and gear tables;
- the vessel key, `vessel_identity` and `sensor_gps`;
- every reference table, including `port_geometry`, `port` and `stk_hid_pid`;
- `staging/aux/ports.fgb`, the STK staging and events, and the adb and fs_afladagbok staging.

The pins therefore changed no pid. The `.gpkg` files differ in md5 only, because a GeoPackage stores its write time
(decision 073).

## Changed, as expected

| output | before → after | cause |
|---|---|---|
| `staging/afli/fishing_sample`, `curated/logbook/fishing_sample` | t2, t3 only | decision 083: t3 on 217,816 static stations, t2 on 1,087,355 tows, both on 188,165 overlapping tows |
| `station_window` | 7,493,906 → 7,494,007 rows | the restored times |
| `trail_match` | 186,607,511 → 190,783,745 | the windows |
| `ais/trail` | same 566,714,976 fixes; station columns; 4 new columns | the windows; decision 085 |
| `curated/logbook/station` | 2 new columns | decision 084 |
| `check/trail_agreement`, `check/trail_sid_coverage` | counts | the trail |
| `ping_union`, `ping_tagged` | `speed`, `speed_raw` in one file (2017) | decision 081: emodnet's speed, Vincenty → Karney |

What the restored times did to the windows (decision 083):
- The 188,152 overlapping tows that reach `station_window` were all whole-day windows. Now 94,690 are recorded
  tows, 93,447 are tows capped at the next tow's start, 13 are day windows and 2 are hauls.
- afli's static gear has 202,226 recorded hauls [t3, t4].
- In `trail_match`: 95,553,680 matches are to recorded windows, 92,756,144 to synthesised ones, 2,143,225 to derived
  and 330,696 to capped.

Checked on the rebuilt files:
- `station_type` is on every station: 5,879,425 operation (`derived`), 517,713 operation (`synthesised`, LLS),
  842,619 event, 21 `none`.
- The trail's gear codes are filled on exactly the 157,856,535 fixes with one station, and `gid_used` equals
  the window's gid on every one.

## Findings: not on the expected list

**A. `speed`, `speed_raw` and `heading` differ in about 90 of the 124 `ping_clean` files** (and so in
`curated/ais/ping` and the trail).
- `ping_clean` does not compute these columns: on June 2023 they equal `ping_tagged` on every ping, apart from
  9 pairs.
- Those are two pings with the same vessel, second, feed and position but different speed or heading. Across all
  years `ping_tagged` holds 6,412 such keys, and 6,173 of them differ, mostly in 2015–2016.
- The tie order `(vid, time, pos_basis, provider, lon, lat)` cannot separate them, so which reading is kept is
  arbitrary from build to build. The ping set is identical: the vid, time, lon and lat hashes match.
- Not fixed here, so that code and data stay in step. It is TODO 55.

**B. Depth (`z1`, `z2` and their basis) changed in `staging/afli/depth` and so in `curated/logbook/station`:
270 stations.** Two independent causes, separated by rerunning `afli_depth_units.R` without writing:
- **B1, the session's time zone (149 stations, 145 of them dated 2012-06-30).** The drift window's bounds were
  `as.POSIXct("2010-01-01")` and `as.POSIXct("2012-06-30")`, without a zone.
  - The build of 2026-10-09 ran at +03:00 (its log is stamped +03:00), so the window ended at 21:00 UTC on
    29 June 2012 and left out the stations of 30 June. Tonight's ran at UTC.
  - Proof: the old times with the session at +03:00 reproduce the pre-rebuild file exactly (row hash and every
    depth column).
  - The bounds are UTC in the code now. That script, run at +03:00, reproduces tonight's file exactly, so the
    data stay as built.
  - No other pipeline script has a time literal without a zone (searched; `ais_key_cascade.R` uses `ymd_hms()`,
    which defaults to UTC).
- **B2, the restored times (121 stations, 9 vessels' switch dates, 2010-06 to 2012-05).** The stations of one day
  are ordered by their first recorded time, `coalesce(t1, t2, t3, t4)` (TODO 47), and the per-vessel changepoint
  scan reads them in that order. Decision 083 gave many stations a time they lacked, so the order, and with it a
  few switch dates, moved by days.

Nothing else differs.

## Follows

- **TODO 48:** 13.8 min against a check of 10; it stays open.
- **TODO 55:** finding A.
- `AGENTS.md` now says the data are built with ramb 2026.10.13.3.
- **TODO 52 closed** (maintainer, 2026-10-14):
  - `$FISHYDATA/legacy/2026-10-plan014` (16 GB, the nine outputs plan 014 superseded) was moved to the macOS
    Trash; it is gone when the Trash is emptied.
  - The claude.ai one-flow master is retired: a notice under its byline points to `docs/one_flow.qmd`.
  - fishyweb's local commits wait for its first remote, under TODO 15.
