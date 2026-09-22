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

**Both this and item 1 are blocked on the same undeclared thing, upstream of both.**
`docs/output-schema.md:88` declares `z1`, `z2` as `int`, "Start / end depth" — with
**no unit**, while the same file spends twenty lines declaring effort units precisely.
All three adapters carry the column through verbatim (`afli:59`, `fs:146`, `adb:160`)
and not one converts, so no adapter can be called wrong. Both correction registries
stop at the same sentence: *"agree a unit for the whole product and convert everything
once, recording which was chosen"*. Until that line exists, neither repair is writable.
Deferred by the maintainer 2026-09-21; recorded so the next attempt starts here rather
than rediscovering it.

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

## 3c. `hid` and `pid` are not the same concept
**status:** open · **raised by the maintainer 2026-09-21, while resolving item 4**
**see:** `curate/decisions/007-hid-maps-to-pid.md` — the mapping is built; typing is what remains

The landings/logbook harbour code answers **"where did this fish go?"**. A harbour
polygon answers **"where was the vessel?"**. These coincide most of the time and then
diverge exactly where it matters:

- **A landing place that is not a harbour.** Hellissandur (41) and Hnífsdalur (71) appear
  to be processing sites, not berths (decision 004). Forcing them into the harbour-polygon
  domain is what produced the bad record in the first place.
- **A code that is not a place at all.** `300 Flutningaskip` is a vessel type,
  `900 Fiskistofa skráningar` an administrative sentinel, `150 Ýmsir staðir` a catch-all.
- **A code that is a whole country.** The eight foreign codes (decision 007) resolve to a
  country, not a port.
- **A harbour that is not a landing place.** Any polygon a vessel visits without landing.

So the crosswalk cannot be `hid ↔ pid` 1:1. It needs a **type** on each code —
place / processing-site / country / sentinel — and a `pid` only where the code really
denotes a physical harbour. Building it as a plain join will silently invent harbours
that do not exist, which is the defect this project is supposed to detect.

**check:** every harbour code carries an explicit type; no code typed non-harbour
carries a `pid`.

---

## 5. `ping_union` carries duplicate position keys — measured, not repaired
**status:** open · **file:** `curate/ais_ping_union.R`
**see:** `curate/corrections/ping_union_duplicate_keys.yml` · detection in the `.R` beside it
**measured in full 2026-09-21** — was "25 rows in 2020, not yet quantified"

**21,920 duplicate keys on `(vid, time, lon, lat)`, 21,952 excess rows** in
527,960,318, across all 20 years. Three unrelated populations:

| population | groups | years | speed differs | heading differs |
|---|---|---|---|---|
| `astd` | 21,142 | **2013–2019 only, zero from 2020** | 15,821 | 0 (astd has no heading) |
| `astd+emodnet` | 405 | 2017 only — the only emodnet year | 404 | 0 |
| `stk` | 373 | all 20, flat, 1–91/yr | 323 | 304 |

**Two things this item used to say are wrong.** It called these "exact duplicate
rows". They are not: lines 98–101 bind with `union()`, which renders SQL `UNION`
— i.e. `UNION DISTINCT`, verified with `sql_render()` rather than assumed — so
rows identical in every column are already removed. Every group here differs in
at least one non-key column, and for 16,144 of them the differing column is
**`speed`**, which is what decides fishing/not-fishing downstream. And the 25
rows first seen in 2020 are the `stk` population: 2020 is the one year with zero
astd duplicates, so the year the defect was noticed is the least representative
of its bulk.

The `astd` shape — rising 315 → 5,100 over 2013–2019 then stopping dead — points
at how that era's staging was assembled, not at the feed. **Not yet checked:**
whether the duplicates already exist in `staging/ais/astd`, upstream of the
union. That is one query per year and it decides where the repair belongs.

A `DISTINCT` is not the repair. Where the two members disagree on speed, taking
the first silently makes a fishing call by row order.

**check:** `ping_union_duplicate_keys()` returns NULL.

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
**status:** open · **kaenugardr done 2026-09-21 (read-only, write refused)**

The plan calls a fixed, agreed archive date a non-optional safeguard, and names
parallel development as how the forks were born.

`kaenugardr` is now read-only, closing the window in which its scripts existed in
two editable places (decision 006). **`logbooks` and `fishydata_2024-2026` are
still writable** and no date is set for them.

**2026-09-22: a third one.** `~/stasi/fishyweb` was pulled from GitHub and is
writable, and it holds yet another copy of the ports and source-conversion scripts
(item 16). It cannot be made read-only until item 16 decides what survives it, so it
is listed here as known-open rather than silently missing from the check.

**check:** `logbooks`, `fishydata_2024-2026` and `fishyweb` are read-only.

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

---

## 12. Provenance stamping — built, adopted by 1 of 19 curated writers
**status:** open · **`write_curated()` built 2026-09-21** (`R/write_curated.R`)

Found while planning 3d: `AGENTS.md` asserted `write_curated()`, `check_sync()`,
`manifest.yml` and `KV_METADATA` as existing machinery. All four had **zero
references** in the repo. This session had already copied that claim into
`curate/decisions/006` as a reason before checking it — the exact failure the
file's own header names.

**Now built and tested.** `write_curated()` writes
`COPY … (FORMAT parquet, KV_METADATA {…})` stamping `fd.repo`, `fd.commit`,
`fd.dirty`, `fd.script`, `fd.built`, `fd.rows`, `fd.schema_hash` and
`fd.inputs`. `sf` is accepted — geometry as WKB, CRS in `fd.crs`, round trip
verified feature-for-feature on 157 harbours. `curated_provenance()` reads the
stamps; `check_sync()` reports drift against HEAD.

**Adopted by one writer**, `reference/ports/harbour_codes.R`. The remaining ~18
still use `duckdbfs::write_dataset()` or `nanoparquet::write_parquet()`.

**The blocker for the rest is real, not laziness.** `write_curated()` takes a
materialised data frame. The `write_dataset()` callers pass **lazy duckdb
relations**, some writing partitioned `year=YYYY/` directories — `logbook.R`,
`link_lid_map.R`, `ais_*`, `h3_index.R`. Materialising those to stamp them
would reintroduce exactly the accumulation `R/write_parquet.R` exists to avoid
(48 GB spilled across ~130 month groups). They need a variant that stamps a
`COPY (SELECT …)` straight from the relation, and a partitioned dataset needs
its metadata at the directory level, which parquet KV cannot express.

`manifest.yml` remains unbuilt and is not started.

**check:** `grep -rn "duckdbfs::write_dataset\|nanoparquet::write_parquet" `
over scripts writing to `fd_curated()` returns nothing.

---

## 13. Code is fixed, data is not yet rebuilt
**status:** open · **added 2026-09-21 at end of session**

Several fixes landed in code and in the reference tables but have **not been
propagated into the large derived datasets**. Nothing here is wrong; it is
work not yet run, and it is listed so nobody reads the current files as final.

| dataset | state |
|---|---|
| `staging/ais/ping_tagged` | **still 527,960,388 rows vs `ping_union`'s 527,960,318** — the +70. The harbour geometry that caused it is fixed, but `ais_ping_tag.R` has not re-run. |
| `curated/logbook/trip.parquet` | missing `.tid_land` and `match_type` — `curate/logbook.R` rewrote it and `link_lid_map.R` has not re-run since. |
| `staging/ais/ping_clean` | still 9 of 20 years, from the stopped run. |
| `curated/ais/*` | not built. |

**`staging/aux/ports.fgb` went from 6,019 to 10,047 features**, because the
hardcoded source filter is gone and the deduplicated global set is used instead.
More harbours are now detectable, which is the intended improvement, but it
changes which pings are in harbour and therefore **trip segmentation** in
`ais_trip.R`. Any trail rebuilt before 2026-09-21 is not comparable with one
rebuilt after.

**check:** `ping_tagged` row count equals `ping_union` row count; `trip.parquet`
carries `.tid_land`.

---

## 14. Two months of astd are in `raw/` and were never loaded
**status:** open · **added 2026-09-21** · **file:** `dump/ais/astd.R`
**see:** `curate/corrections/astd_missing_months.yml`

`staging/ais/astd/year=2023` has **10 monthly partitions**; `raw/ais/astd` has 12
zips for 2023. 2017 (no 07) and 2019 (no 01) are genuine source gaps — the zips
do not exist. 2023-08 and 2023-09 are not: 1.17 GB of raw delivery, 10.1 GB of
CSV, present and never converted.

**Cause established** by running the script, after three wrong guesses from
reading code. The two zips use **DEFLATE64** (PKWARE method 9, `zipinfo`:
`deflated (enhanced-64k)`) where every other month uses standard deflate. R's
`unz()`/`unzip()` are zlib, which implements only method 8, so R cannot read a
row of them — `unz()` fails instantly with "error reading from the connection".
Hence `sniff_zip()` returns NULL at `:60`, the month never enters
`cols_by_month`, and `:341` fails the same way. Wrong guesses, recorded because
they will be made again: the `_manual` filename defeating the glob (no — `:206`
documents the suffix); the member exceeding 4 GB (no — 202312 at 4.46 GB works,
202309 at 4.50 GB fails); a transient temp-space failure (no — deterministic).

**This is not a silent failure — and that is the point.** The script prints
`Sniffing 155 files` then `Canonical schema across 153 months`, its column-set
table jumps 202307 → 202310, and it ends with `Failed: 2` naming `202308` and
`202309` explicitly. It has said so on every run, and it leaves the tree clean
(verified: no empty partition dirs, no truncated parquet). Decision 003 recorded
that run as "clean: 2,769,131,193 rows … 25.5 min" — a row total taken from a
run whose own summary reported two failures. **Not item 7's pattern after all**:
the check was there and was not read.

**Fixed in code 2026-09-21, one path verified, one not.** `dump/ais/astd.R` now
falls back to the Info-ZIP `unzip` CLI, which does implement method 9 — both
members verified to decompress to exactly their declared byte counts
(5,277,681,911 and 4,835,251,763). The **sniff** path is tested: both months now
return 28 columns, a control month unaffected at 27. The **conversion** path at
`:341` is written but has **not been executed** — that needs the real 10 GB
extraction. `bsdtar` is not a usable fallback (stops after 224 bytes); 7z is not
installed here.

Still to handle when the conversion runs: these files carry an **extra leading
`ship_id` column** (28 against 27) from the hand-written SELECT, plus quoted
headers and a millisecond timestamp. A plain re-run was tried before the fix:
153 skipped, 0 written, 2 failed, nothing left behind.

**This must precede the item 13 rebuild.** Rebuilding now bakes a two-month hole
in 2023 into the product, where it is invisible and reads as a real decline.

**check:** every `year=YYYY` under `staging/ais/astd` has one partition per zip
in `raw/ais/astd` for that year.

---


---

## 15. The three-repo publication boundary
**status:** open · **see:** `curate/plans/001-three-repo-publication-boundary.md`

`fishycode` public on GitHub, `fishydata` never public, `fishyweb` an open web page.
The design, the evidence and the open questions are in the plan; this stub exists so
the work is visible here. Two things in it are time-sensitive: there is still **no git
remote**, so history is free to rewrite until the first push, and a Mapbox `pk.` token
is committed in three files. The boundary that actually needs a rule is
`fishydata` → `fishyweb`, which is a data-disclosure question and binds item 16.

---

## 16. `~/stasi/fishyweb` — decide what survives it
**status:** open · **files:** none in this repo yet · **see:** item 15, `curate/decisions/005-harbour-geometry-is-a-frozen-input.md`

Pulled 2026-09-22 from `github.com/einarhjorleifsson/fishyweb` (branch `master`, 10 MB,
last commit **2026-04-08** "reconstucted webpage"). An earlier incarnation of this
project, already renamed on GitHub — it ships `fishyweb.Rproj`, and its `.gitignore`
still carries a line excluding the old `fishydata.Rproj`. It mixes two things that the
current split keeps apart: code that generates data, and web material.

**The data half is mostly a previous generation of code that now lives elsewhere.**
Mapped by script name and topic, not by reading the code:

| fishyweb `scripts/` | now at |
|---|---|
| `00_DATASET_ports-{emodnet,kvoti,osm,vmstools,iceland-and-faroe}.R` | `~/stasi/kaenugardr/`, same filenames |
| rest of 00/01-series (gear, vessels, mmsi, gfw, optiger, eflalo-dictionary, lookups, shapes) | `reference/` in this repo |
| 05/11/12/41/43-series (astd, astdB, stk, norway, landings, logbooks, trail) | `sources/` and `curate/` |
| `80_DATASET_SMB_demo.R`, `91_datacall_*.R`, `ices-datacall/2025/` | **no counterpart** |

**Nothing in it runs here.** Every script uses relative `data/` and `data-raw/`, which
were symlinks into `/u3/geo/fishydata/` on the Hafró server — documented in its
`LESTUMIG`, gitignored, absent on this Mac. 17 of its 22 `ramb/` posts also read data,
several by absolute server path (`/u3/haf/gisland/...`, `/home/haf/einarhj/...`) or
Hafró FTP. So neither half can be executed or rendered locally without repathing.

**What is actually unique to it, and is the reason not to just archive it:**

- `ramb/` — **22 written posts**, 2025-01 to 2026-03. Prose, not code. This repo
  produces no reading surface at all, so these have no home in the current structure.
  They are the `fishyweb` slot of item 15, already populated.
- `AGENTS.md` (21 KB) — documents the RAW SOURCES, not the code: ASTD schema evolution
  across four distinct periods, the STK Oracle column mapping and its query-time unit
  conversions, the MMSI four-case merge logic. Source documentation does not go stale
  the way the code around it does. Worth diffing against what `sources/astd` and
  `sources/stk` say now.
- `ices-datacall/2025/ICES_VMS_QC-main/` — vendored ICES VMS QC harness, 160 KB.

**Already broken in it:** `_quarto.yml` lists `qmd/fishtrawl-footprint.qmd` in the
navbar; that file does not exist (only `slides/fishtrawl-footprint.qmd` does). The
other five navbar targets resolve.

**Not verified:** whether `reference/` and `kaenugardr` are genuinely equivalent to the
00/01-series they appear to replace, or merely cover the same topics. The table above
was built from filenames and directory listings. Before deleting anything, read the
pairs.

**check:** each row of the table above is either confirmed superseded by reading both
sides, or has an explicit decision to keep/port/drop; the `ramb` posts have a named
destination (ported, archived, or dropped) rather than sitting unreferenced; the
`AGENTS.md` source notes are either folded into `sources/*/` or recorded as still
authoritative there; `fishyweb` is then either archived with a date (see item 9) or has
a stated ongoing role.

---

## Resume note — 2026-09-21, session paused, break over 24 hours

**Start here: one command, then one check.** The `dump/ais/astd.R` DEFLATE64 fix
(item 14) is committed and the sniff half is verified; the conversion half has
never executed. Run it, at the machine, not backgrounded:

```
Rscript -e 'source("R/paths.R"); source("dump/ais/astd.R")'
```

Expect `R cannot read … — retrying via the unzip CLI` on `202308_manual` and
`202309_manual`, then the end-of-run summary to say `Written: 2, Failed: 0`.
Then the item 14 check: `ls staging/ais/astd/year=2023` must show 12 partitions.
If the `COPY` fails, the likely cause is the extra leading `ship_id` column
(28 against 27) — the canonical SELECT at `:288` names columns explicitly, so it
should be ignored, but that is reasoning, not a result.

**State on disk, unchanged by today:** `staging/ais/astd` is 123 GB, 2023 still
at ten partitions, no empty directories and no truncated parquet. Nothing was
written today. Everything in items 5, 13 and the older resume note below still
holds.

**Open, in the order that respects the dependencies:**

1. **Item 14's conversion run** — above. It blocks item 13, because a rebuild
   would bake the two-month hole into the product.
2. **Item 5's unanswered question** — whether the astd duplicates already exist
   in `staging/ais/astd`, upstream of the union. One query per year. It decides
   whether the repair belongs in the union or the decode, and it should be asked
   *after* the two months land, since they fall inside the affected era.
3. **Items 1/1b** — set aside deliberately today. Both are blocked on one line
   that does not exist: a declared unit for `z1`/`z2`. See item 1b.

**Worth knowing before trusting any measurement here:** three claims about
item 14's cause were asserted from reading code and file listings today, and all
three were wrong. Running the script settled it in one pass. Where this file
states a cause, check whether it says *measured* or *inferred*.

---

## Resume note — 2026-09-21, run stopped deliberately

The L1→L4 trail rebuild was **stopped part-way on purpose**, not by failure. Reason:
several open items above change the trail output, so completing the run would only
mean discarding it. The Hellnar/Hellissandur/Hnífsdalur shared polygon (decision 004) was
named the most consequential of them — **that has since been measured and withdrawn**:
the two undetectable harbours are named by 21 trips in the whole AIS era, so they cannot
alter trip segmentation meaningfully. The adb/afli unit items remain.

**State on disk, all of it reusable:**

| stage | state |
|---|---|
| `staging/ais/astd` | complete — 2,769,131,193 rows, 2013–2026, verified against legacy |
| `staging/ais/astdB` | complete — 901,123,092 rows, 2014–2024, verified against legacy |
| `staging/ais/ping_union` | complete — 527,960,318 pings, 2007–2026 |
| `staging/ais/ping_tagged` | complete — 527,960,388 (the +70 is item 4) |
| `staging/ais/ping_clean` | **partial — 9 of 20 years (2007–2015)** |
| `curated/ais/*` | not built — smoke-test partials (2007–2008 only) were deleted to avoid them reading as finished |
| `curated/logbook/sensor_gps` | not built — same |
| `curated/link/trip_voyage.parquet` | complete (803,549 rows) but built on **legacy** AIS voyages, not the rebuild |

**Resuming L2 costs nothing already done.** `ais_ping_clean.R` skips any year with a
marker in `staging/ais/ping_clean_marks/`. To force a full rebuild after fixing the
harbour geometry, delete that directory — the harbour tag is applied upstream in
`ais_ping_tag.R`, so an `ports.fgb` fix requires re-running from the tag step, not
just from L2.

**Before resuming, decide:** items 1/1b (adb units and longitude sign, afli depth units)
— these change outputs. **Item 14 must be done first**, not merely decided: two months
of 2023 astd are missing from staging and a rebuild would make the hole permanent. **Item 4 is no longer a blocker**: measured at 21 AIS-era trips,
it cannot move trip segmentation meaningfully (decision 004, addendum 2). Item 6 (GEBCO)
still blocks a clean full `tar_make()`.

**One command to restart, once those are settled:**
```
Rscript <scratchpad>/run_trail.R    # L2 → L3a → L3b → L4, resumable
```
