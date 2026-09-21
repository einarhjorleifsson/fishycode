# TODO

Open work items. One line of provenance each, and a **check** that decides when the
item is closed — so this file can be audited against the code rather than believed.

Not a diary. Why a thing is the way it is goes in `curate/decisions/`. Data defects
with a detection rule and a repair go in `curate/corrections/*.yml`. This file is
only for work that is *not done yet*.

Status: `open` · `blocked` · `in progress` · `done` (delete when done and recorded elsewhere)

---

## 1. Wire `adb` into the logbook merge — BLOCKED on units and longitude sign
**status:** blocked · **files:** `sources/adb/convert.R`, `curate/logbook.R`, `curate/link_lid_map.R`
**see:** `curate/corrections/adb_vs_fs_afladagbok.yml`

`_targets.R` declares `adb` as a dependency of `logbook` and states a three-tier rule
— "afli where it exists, then fs_afladagbok through its dump end, then adb beyond it".
`curate/logbook.R` implements two tiers and never opens `staging/adb/`. The merged
product therefore ends **2025-12-12 with zero 2026 coverage**, while adb holds
**20,530 stations for 2026**, already built.

**Done:** `sources/adb/convert.R` now splits its fat station table into a narrow
`station` plus a `fishing_sample`, so adb supplies the four tables the merge binds.

**Blocked on two defects that would silently corrupt the product** — found by
cross-checking adb against fs_afladagbok, which is possible with no matching
heuristic at all because adb is fs's live view and they share 467,635 `.sid`:

- **Depth units.** adb is in METRES, fs and afli are in FATHOMS. `z_adb / z_fs` is
  1.8288 at every percentile — 100.00% of 443,718 rows. Which is canonical was settled
  against GEBCO, not by comparing the sources to each other: indexing each source's
  stations to H3 res 8 and dividing the cell's GEBCO depth by the recorded `z1` gives
  **1.891 for afli, 1.891 for fs, 1.025 for adb**. Merging as-is makes 2026 depths
  metres inside a column that is fathoms for 1950–2025. Nothing errors.
- **Longitude sign.** 50,269 shared stations (10.8%) differ by >10 km; 91.8% of those
  have a positive longitude in adb against 1.5% in fs. Iceland is at ~21°W — adb is
  dropping the west sign (known issue 13). ~8% of the outliers are unexplained.

**Gear is no longer a blocker.** The same cross-check resolves it: adb's code IS fs's
`gid_old`, so the unified `gid` can be *derived* from the 467,635 shared stations
rather than guessed. Two ambiguous cases (adb 53 → fs 15; adb 6 → fs 14/gid 8) need
an explicit confidence. The converter leaves `gid` NA for now; downstream it can come
either from this crosswalk or from the landings gear code, which resolves cleanly —
all 25 of its distinct values match `gear$gid`, versus 13 matching `map`.

**Ordering is not circular:** `link_lid_map.R` reads the MERGED trip table, so adb
trips reach landings automatically once merged. `R/match_nearest_date.R` is already
migrated and is the archive's mechanism for attaching landings gear as an ADDED
column (`gid_agf`, `gid_lods`) rather than overwriting — consistent with this
project's "a correction adds columns" rule.

**check:** `curate/logbook.R` reads `staging/adb`; merged `station.parquet` has
non-zero 2026 rows; depth is in one declared unit throughout; no merged 2026 station
has a positive longitude.

---

## 1b. afli depth units drift fathoms → metres over 2010 to mid-2012
**status:** open · **file:** `sources/afli/convert.R`
**see:** `curate/corrections/afli_depth_units.yml`

Checked against GEBCO bathymetry (no other source shares afli's keys). Stable at a
ratio of 1.84–1.90 — fathoms — from 1990 to 2023, matching fs_afladagbok's 1.891
exactly. But a window from 2010-01 to 2012-06 has a growing share of records in
metres: 5% → **63% at 2011-12** → back to 1.4% after an abrupt cliff at 2012-07.

Not shallow water (the shallow share is flat at 30–36% throughout, and the anomaly
survives restricting to z1 ≥ 50). It is a **per-vessel** property: at the peak
window, 65 of 268 vessels are unambiguously fathoms and 46 unambiguously metres,
with the mass between them being vessels that switched mid-window.

Repair must classify `(vid, period)`, never individual rows — GEBCO is a cell mean,
so row-level classification would mislabel genuine fathom records on steep ground.

**check:** median GEBCO-ratio per year varies by less than 5% across 1990–2026.

---

## 2. `FS_DATE_MAX` expired nine months ago
**status:** open · **file:** `curate/logbook.R:24`

`FS_DATE_MAX <- as.Date("2025-12-31")`. fs_afladagbok's real data ends 2025-12-12, so
this is not currently clipping real fs rows — it is the handover point to adb, and it
only becomes correct once item 1 lands.

A second, less obvious ceiling matters more: `link_lid_map.R:40` filters landings to
`date <= ymd("2025-12-12")`. That literal is exactly the merged logbook's current max
date, i.e. it was derived from the output at the time and then frozen. Landings
actually run to **2026-04-14** and adb to **2026-04-08**, so this line would block
2026 from matching landings even after adb is merged.

**check:** no hardcoded date in `logbook.R` sits in the past at build time.

---

## 3. `station_type` is prose, not a contract
**status:** open · **files:** `sources/afli/convert.R`, `sources/fs_afladagbok/convert.R`

`grammar.qmd`'s flagship contribution. Appears 5x in prose and **0x in any script**,
unchanged since this restructuring began. Step 3 of the plan, still not started.

**check:** `grep -rn station_type sources/` returns the column being written by both
adapters.

---

## 3b. Make `kaenugardr` the single harbour source — feasibility assessed, HIGH
**status:** open · **do not change kaenugardr yet** (maintainer working on source overlap)
**files:** `reference/geo/shapes.R:63-70`, `reference/ports/harbour_codes.R`

**It is already the source.** `$FISHYDATA/raw/ports/ports_all.gpkg` and
`ports_iceland_faroe.gpkg` are **byte-identical** (md5) to kaenugardr's outputs. Two
artifacts feed two roles:

| kaenugardr artifact | → | pipeline role |
|---|---|---|
| `ports_all.gpkg` (23,164 features) | `shapes.R` → `staging/aux/ports.fgb` (6,019) | AIS harbour tagging |
| `ports_iceland_faroe.gpkg` (159) | `harbour_codes.R` → `curated/reference/port.parquet` (143) | logbook harbour codes |

So the question is not adoption but **consolidation and sync**. There is no import
step and no version stamp — the files were copied by hand.

**Icelandic status: good.** 159 ports, **156 with a unique geometry**. Exactly ONE
duplicated geometry, covering 3 ports — and it accounts for the *entire* issue-11
defect (see item 4). Coverage of what the logbooks actually use: **99.8% of the
1,889,945 real harbour references in trips**. 42 harbour ids are uncovered, but the
most-used of those are country placeholders (`167 Færeyjar`, `163 Noregur`,
`166 Grænland`) and sentinels (`-1`, `0`), not missing harbours.

**Pan-European status: the overlap you describe is real, and quantified.**
979 distinct geometries are shared by 1,993 features — **8.6% of 23,164**. Iceland
alone carries 131 `einar` entries plus 144 from six other sources. Geometry types are
mixed (`POINT`, `LINESTRING`, `MULTILINESTRING`, `POLYGON`, `MULTIPOLYGON`), which a
spatial join handles inconsistently.

**Why feasibility is high: the resolution rule already exists, twice, in two forms.**
- kaenugardr has a `priority` column: einar 1, gisco 2, jeppe 3, maksims 4,
  emodnet 5, osm 6, vmstools 7, gfw 8, marta 9 — never applied.
- `shapes.R` hardcodes a crude equivalent: keep `einar` + `gfw`, drop `gfw` where the
  pid starts `IS` or `FO`, crop to the ICES bbox.

Consolidating means applying `priority` in kaenugardr (highest-priority feature wins
per spatial cluster) and deleting the hardcoded filter, so the rule lives in one place.

**check:** `shapes.R` contains no source-name filter; `ports.fgb` has no two features
sharing a geometry; `port.parquet` and `ports.fgb` derive from one kaenugardr release
carrying a recorded version.

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
