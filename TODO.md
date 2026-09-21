# TODO

Open work items. One line of provenance each, and a **check** that decides when the
item is closed — so this file can be audited against the code rather than believed.

Not a diary. Why a thing is the way it is goes in `curate/decisions/`. Data defects
with a detection rule and a repair go in `curate/corrections/*.yml`. This file is
only for work that is *not done yet*.

Status: `open` · `blocked` · `in progress` · `done` (delete when done and recorded elsewhere)

---

## 1. Wire `adb` into the logbook merge — BLOCKED on gear coding
**status:** blocked · **files:** `sources/adb/convert.R`, `curate/logbook.R`

`_targets.R` declares `adb` as a dependency of the `logbook` target and the comment
above it states a three-tier rule — "afli where it exists, then fs_afladagbok
through its dump end, then adb beyond it". `curate/logbook.R` implements only two
tiers and never opens `staging/adb/`. The edge exists in the DAG; the code ignores it.

Consequence: the merged product ends **2025-12-12 with zero 2026 coverage**, while
`staging/adb/station.parquet` holds **20,530 stations for 2026**, already built.

Two obstacles, one of them real:

- **`adb` emits no `fishing_sample`.** Its `station` is a *fat* table carrying
  `gid_old, t1, t3, t4, effort, effort_unit, towtime, gear_width` — detail that in
  afli and fs_afladagbok lives in `fishing_sample`. The converter never split them.
  Mechanical to fix.
- **BLOCKER: adb's gear coding cannot be resolved against `reference/gear.parquet`.**
  Measured 2026-09-21 over 628,314 adb stations:

  | adb code | rows | valid as |
  |---|---|---|
  | 92, 99, 91, 29 | 4,232 | `gear$map` ONLY (old coding) |
  | 10 | 2,670 | `gear$gid` ONLY (new coding) |
  | 53, 51 | 6,654 | **neither** |

  The two codings overlap on the common values, so the majority is uninformative.
  The discriminating values contradict each other. Assigning `gear`/`target2` on this
  evidence would silently mislabel gear.

**check:** `curate/logbook.R` reads `staging/adb`; merged `station.parquet` has
non-zero 2026 rows; every adb `gid_old` resolves to exactly one `gid` with a written
justification for 53 and 51.

---

## 2. `FS_DATE_MAX` expired nine months ago
**status:** open · **file:** `curate/logbook.R:24`

`FS_DATE_MAX <- as.Date("2025-12-31")`. Today is 2026-09-21. Everything after that
date is dropped from the merge. Interacts with item 1: adb is what was supposed to
cover beyond it.

**check:** no hardcoded date in `logbook.R` sits in the past at build time.

---

## 3. `station_type` is prose, not a contract
**status:** open · **files:** `sources/afli/convert.R`, `sources/fs_afladagbok/convert.R`

`grammar.qmd`'s flagship contribution. Appears 5x in prose and **0x in any script**,
unchanged since this restructuring began. Step 3 of the plan, still not started.

**check:** `grep -rn station_type sources/` returns the column being written by both
adapters.

---

## 4. Harbour-polygon overlap — decide the selection rule
**status:** open · **file:** `staging/aux/ports.fgb`, `curate/ais_ping_tag.R`
**see:** `curate/decisions/004-issue-11-seventy-extra-rows.md`

Overlapping polygons make a left spatial join emit one row per matching harbour.
One ping was found inside three at once. 70 extra rows in 528 M — harmless for
aggregates, but it means `max(pid)` decides which harbour a visit is attributed to,
which is not a decision anyone made. Deduplicate after the join (smallest containing
polygon) or resolve the source geometry.

**check:** `ping_tagged` row count equals `ping_union` row count.

---

## 5. `ping_union` carries exact duplicate rows
**status:** open · **file:** `curate/ais_ping_union.R`

25 exactly-duplicated rows in 2020 alone — same vid, time, lon, lat — before any
tagging. Distinct from item 4. Not yet quantified across all years. Most likely one
fix arriving from two providers, or a provider delivering a ping twice.

**check:** `count(vid, time, lon, lat) |> filter(n > 1)` is empty across all years.

---

## 6. GEBCO: two scripts want two different rasters
**status:** open · **see:** `curate/decisions/002-missing-gebco-raster.md`

`reference/geo/h3_index.R` needs `raw/aux/gebco_2026.tif` — this blocks `area_h3` and
a clean full `tar_make()`. `products/exports/astd_iseez.R` hardcodes `gebco_2024.tif`.
Neither is present. The 709 MB original is at
`~/Downloads/older/GEBCO_07_May_2026_8472de0f82f8/gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif`
but macOS privacy blocks Claude from reading `~/Downloads`, so the copy must be run
by hand. Decide whether one raster serves both scripts.

**check:** `tar_make(names = "area_h3")` succeeds.

---

## 7. Verification scripts test shape, not substance
**status:** open · **files:** `R/check_ready.R`, `R/check_paths.R`, `R/paths.R`

Three times now a check has reported "ready" or "clean" about something that was not:
`check_paths.R` missed seven absolute paths, `check_ready.R` did not recognise
`read_excel`, and both were fooled by empty directories. The root cause of the last
one is `.fd_writable()` **creating a directory as a side effect of resolving a path**,
so `dir.exists()` cannot distinguish "never built" from "built and empty".

Today's failures were all in code that had never executed, and two would have failed
*silently* — a character/integer comparison that wrote an empty dataset, and those
empty directories.

**check:** `check_ready.R` reports not-ready for an existing but empty dataset
directory.

---

## 8. `fishydata_2024-2026` still holds 40 GB that step 1 never moved
**status:** open

Step 1 of the plan symlinked `logbooks/` into `$FISHYDATA`. It was never applied to
`fishydata_2024-2026`, which still has `data/ais/trail` (31 GB) and
`data-raw/ais/stk` (8.4 GB) as **real directories**. Its `trail` is a *third* trail,
distinct from `legacy/curated/trail` (13 GB) and `trail2` (19 GB), so it cannot be
deleted until someone establishes whether anything in it is unique.

**check:** no directory under `~/stasi/fishydata_2024-2026` exceeds 1 GB.

---

## 9. No archive date for the old repos
**status:** open

The plan calls a fixed, agreed archive date a non-optional safeguard, and names
parallel development as how the forks were born. There are currently **three** trees
and both old ones are still writable. No date is set.

**check:** `logbooks` and `fishydata_2024-2026` are read-only.

---

## 10. `curated/check/` does not exist
**status:** open

The plan calls the cross-check disagreement tables "part of the product, not a
by-product" — an analyst asking "can I trust this row?" should get a dataset to join
against. Nothing has been built. `reference/species` is also absent.

**check:** `curated/check/` contains at least one disagreement table.

---

## 11. Datasets named `year=YYYY` are not actually partitioned
**status:** open · **files:** `curate/ais_ping_clean.R`, `curate/ais_trip.R`, `curate/logbook_sensor_gps.R`
**see:** `curate/decisions/003-undeclared-dump-inputs.md`

Superseded in part — these now write real `year=YYYY/` directories. But
`ais_ping_union.R`'s claim that partitioning enables "partition pruning" should be
re-checked now the layout has changed, and the `year` data column now coexists with a
hive column of the same name.

**check:** reading each dataset yields exactly one `year` column, of a stable type.
