# 079 — The plan 014 rebuild: every difference reconciled

*2026-10-09. Rebuild and comparison run by Claude (AI-assisted) at fishycode 2af080e → eb6be4d, with ramb f6faf9b
(local `-O2` build, not yet pushed). Before/after fingerprints (`R/fingerprint.R`), logs and the comparison are in
`$FISHYDATA/archive/plan014/`.*

## What was run

- **Before:** 871 files, 3,886,810,978 rows; rows, schema, an order-free row hash and per-column hashes
  (2.2 min).
- **Rebuild:** `tar_invalidate(everything())`, then `tar_make_isolated()`: all 45 targets of the main project.
  It stopped twice, each time fixed, committed and resumed:
  - at `ais_ping_union`: dbplyr put the gps feed's `WITH` query bare after `UNION ALL` (14c98a7);
  - by choice in `ais_ping_clean`: the new tie test used `duplicated()` on a data frame, 23.5 s per 5 M-ping
    batch, about 45 min in all. A neighbour test on the sorted pings gives the same result in 0.5 s (eb6be4d).
- **Step times:** `ais_ping_clean` 16 min (2017–2026 only, after the stop), `port_stay` 8 min, `ais_voyage`
  29 min (was 51; TODO 48's check is 10), `ais_trail` 21 min.
- **After:** 890 files, 4,035,116,546 rows; `tar_outdated()` empty.
- **Archived:** the nine outputs superseded by renames or removals were moved by a logged script to
  `$FISHYDATA/legacy/2026-10-plan014/`. The store was pruned.

## Measured: the AIS chain reconciles exactly

| | before | after | why |
|---|---|---|---|
| `ping_union` | 543,776,104 | 575,067,773 | + 26,921,466 gps (3a), + 4,370,203 astd 2023-08/09 (3e) |
| `ais/ping` = `ping_clean` | 535,613,524 | 566,714,976 | the AIS ties `ais_ping_trail.R` removed later are now flagged in step 0; gps joins |
| `ais/trail` | 562,412,432 | 566,714,976 | + 4,303,856 astd 2023 − 1,308 stk − 4 gps, all in 2023 |
| step-0 flags | | | `tie` 122,562 (24,204 AIS ties as before, the rest gps at an AIS second); 0 duplicate `(vid, time)` in the trail |

- **The 2023 stk and gps differences** come from the two new astd months. With them in the track, step 0
  judges 1,308 stk pings differently, and 4 gps fixes now lose an exact tie to an astd ping.
- **By feed in the trail:** astdB, emodnet and the other years of stk and gps are identical.

## Measured: everything else that changed has its cause in decision 077

| Output | before → after | cause |
|---|---|---|
| stays (`port_stay`, was `harbour_stay`) | 1,551,598 → 1,565,680 | one 2 h stay, STK-only events (3b: +13,865 on the old inputs), + 2023 astd |
| voyages (`voyage`, was `ais/trip`) | 1,372,652 → 1,377,033 | the stays |
| `link/trip_voyage` | 797,663 → 797,639 | the voyages |
| STK events (`staging/ais/stk_event`) | 8,197,409 → 8,197,409 | columns only: `io_jump`, `in_clean` dropped (3b) |
| `lid_map` | 790,632 → 790,875 | 3i, as counted |
| `catch_by_species_trip` | 8,285,715 → 8,285,697 | the links |
| `station_window` | 7,496,440 → 7,493,906 | gear from the landing changes a station's class and phases (3j) |
| `trail_match` | 185,801,016 → 186,607,511 | more fixes, changed windows |
| `staging/afli/depth`, `logbook/station` | rows unchanged | the tie-break of 3d (163 stations) |
| the checks on the trail, stays and voyages | | their inputs |
| five `.gpkg` | md5 only | a GeoPackage stores its write time (decision 073); the files built from them are identical |

Identical: the logbook and landings tables, the references, the frozen fixes (key, sensor_gps, port radius), the
STK staging and every key check.

## Follows

- TODO 14 closes: 2023 has all 12 astd months in the union. 2017-07 and 2019-01 have no zip in `raw/`.
- TODO 48 stays open: 29 min, against 51 before and a check of 10.
- Still to do: the data dictionary redrafted from the new files, the docs rendered, three fishyweb pages, the
  WGSFD doc (plan 014 phase 5), and the ramb push (the maintainer's yes).

## Done after the rebuild, the same day (plan 014 phase 5 and the follow-ups)

- **ramb pushed** to GitHub (9789c0c..f6faf9b), with the maintainer's yes.
- **`docs/data-dict.yaml`** follows the renames: tables, columns and joins, a new `logbook_gear` table, and
  `sensor_gps.trip` marked as the frozen voyage number of decision 073's build. Its older spec errors are
  TODO 51.
- **Docs:** rendered page by page, 13 of 19 render. The six that fail read paths from before the restructuring
  (TODO 50), not plan 014's.
- **fishyweb:** three pages follow the names (27b35ff, local commit, not pushed). The tutorial's
  `voyage_year` was stale before plan 014. All three render.
- **WGSFD doc, version 2:** the local copy in `~/stasi/wgsfd2026/` says "port" throughout (text, code
  examples, diagram SVG and PNG, rendered HTML), and its AI-use line says so. The claude.ai master is unchanged
  until the maintainer says yes.
