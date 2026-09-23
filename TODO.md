# TODO

Open work items. One line of provenance each, and a **check** that decides when the
item is closed — so this file can be audited against the code rather than believed.

Not a diary. Why a thing is the way it is goes in `curate/decisions/`. Data defects
with a detection rule and a repair go in `curate/corrections/*.yml`. This file is
only for work that is *not done yet*.

**An item is a stub, not an essay — 35 lines at most, enforced.** It says what is open,
points at the record that holds the evidence, and states its check. When an item wants
sections, tables and its own numbers it is a plan or a correction, and what stays here
is the pointer. This file reached 871 lines by ignoring that; the cure was mechanical —
four "Resume note" sections were 211 of them, and seven items were restating a plan or a
correction that already said it better. Session state belongs in the git log, which is
where "what happened when" is recorded.

Status: `open` · `blocked` · `parked` · `in progress` · `done` (delete when done and
recorded elsewhere)

`parked` is a deliberate stop, not an obstacle: the work could proceed and a decision
was taken that it should not. `blocked` means something outside the item is in the way.
Conflating them hides which ones a session could actually pick up.

An item that cannot move without the maintainer — a decision, an account, a
credential, anything outside this repo — also carries **`needs: maintainer`**, and says
in one line what is being asked. Without that marker a session either stalls on it or
does it twice.

---

## 1. Wire `adb` into the logbook merge — BLOCKED on units and longitude sign
**status:** blocked · **files:** `sources/adb/convert.R`, `curate/logbook.R`
**see:** `curate/corrections/adb_vs_fs_afladagbok.yml`, item 1b

`_targets.R` declares `adb` as a logbook dependency; `curate/logbook.R` never opens
`staging/adb/`, so the merged product ends **2025-12-12 with zero 2026 coverage** while
adb holds 20,530 stations for 2026, already converted.

Blocked on two defects that would silently corrupt the product — adb is in **metres**
where fs and afli are in **fathoms** (settled against GEBCO, not by comparing sources),
and adb **drops the west longitude sign** on 10.8% of shared stations. Both are measured
in the correction file, together with the gear crosswalk that is no longer a blocker.
The unit question is shared with item 1b and is the real gate.

**check:** `curate/logbook.R` reads `staging/adb`; merged `station.parquet` has non-zero
2026 rows; depth is in one declared unit throughout; no merged 2026 station has a
positive longitude.

## 1b. afli depth units drift fathoms → metres over 2010 to mid-2012
**status:** blocked · **needs: maintainer** · **file:** `sources/afli/convert.R`
**see:** `curate/corrections/afli_depth_units.yml`

**Asked of the maintainer:** agree one depth unit for the whole product and record which
was chosen. `docs/output-schema.md:88` declares `z1`/`z2` as "Start / end depth" with **no
unit**, all three adapters pass the column through verbatim, and so no adapter can be
called wrong. Until that line exists neither this repair nor item 1's is writable.
Deferred by the maintainer 2026-09-21; recorded so the next attempt starts here.

The drift itself is measured against GEBCO and is a **per-vessel** property — at the peak
window 65 of 268 vessels are unambiguously fathoms and 46 unambiguously metres. Repair
must classify `(vid, period)`, never rows.

**check:** median GEBCO-ratio per year varies by less than 5% across 1990–2026.

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
**status:** open · **see:** `curate/corrections/ping_union_duplicate_keys.yml`

Duplicate `(vid, time)` keys survive into the union. Measured and declared; the repair
rule is the open part, and the correction records one proposed rule that was **rejected**
— preferring the smaller `sec_nextpoint` would have selected the placeholder every time.

**check:** `staging/ais/ping_union` has no duplicate `(vid, time)`, or the correction
states why the surviving ones are legitimate.

## 6. GEBCO: `astd_iseez.R` still wants a raster nobody has
**status:** open · **see:** `curate/decisions/002-missing-gebco-raster.md`

**Half of this closed on 2026-09-22.** The 2026 raster is in
`raw/aux/gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif` and always was;
`reference/geo/h3_index.R` was looking for `gebco_2026.tif`, a name nobody ever
created. Repointed, banner removed, and `check_ready()` now reports every target ready.

What remains is the second consumer. `products/exports/astd_iseez.R:23` hardcodes
`raw/aux/gebco_2024.tif`, and that file is genuinely absent — `raw/aux` holds exactly one
`.tif` and it is the 2026 one. The 2026 release supersedes 2024 in coverage, so
repointing is the obvious move **unless** the depths that script extracts are meant to
be frozen at the 2024 vintage. Nothing in the script says either way, and `products/` is
outside the DAG so nothing has forced the question.

**The `area_h3` rebuild is done.** `tar_make(names = "area_h3")` ran 2026-09-22 in
7m30s; the gate passes and an anti-join against `raw/aux/h3_indices.parquet` in both
directions returns zero rows, with zero disagreements on `depth`, `bbht` or `fao`. The
sweep no longer contains a table the pipeline never made.

**check:** `astd_iseez.R` either reads the 2026 raster or says in the script why it must
not.

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

## 10. `reference/species` is an empty directory
**status:** open
**see:** `curate/decisions/019-the-check-layer-exists.md`

This item used to read "`curated/check/` does not exist". That half is **closed** —
it holds three tables and the contract a check owes its reader is written down in
decision 019. The claim had gone stale before anyone noticed, which is why it is
recorded rather than quietly edited.

What is left is the species reference. `reference/species/` is an empty directory and
`curated/reference/` has no species table, so nothing in the sweep resolves a species
code to a name. Every other reference domain — gear, ports, geo, vessels — has one.

**check:** `curated/reference/species.parquet` exists and the catch tables' species
codes all resolve against it.

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
**status:** open · **see:** `curate/corrections/astd_missing_months.yml`

Two months of ASTD sit in `raw/` and never reach the union, so the AIS track has holes
nobody sees. Measured and declared in the correction, which holds the month list and what
was checked.

**check:** every month present in `raw/ais/astd` appears in `staging/ais/ping_union`.

## 19. The dropped afli stations — PARKED
**status:** parked · **see:** `curate/corrections/afli_rafr_stofn_stations_dropped.yml`,
`curate/plans/005-recover-the-dropped-afli-stations.md`

**Parked by the maintainer 2026-09-23. Nothing is queued and the product is unchanged.**
23,570 live electronic submissions are absent from `stofn` and therefore from everything
this repo builds. That is measured twice and is not in doubt. What to do about it is.

The position moved three times in one session — hold for an upstream answer, lift the
hold on AIS corroboration, then a claimed two-thirds reversal on supersession that was a
conditioning error caught by one further check. The measurements underneath were sound
every time; the readings of them were not. That is why it is parked rather than pushed.

**What is published and stays:** `curate/checks/afli_rafr_stofn_loss.R` and
`afli_rafr_stofn_corroboration.R` into `curated/check/`, and
`docs/afli-dropped-stations.qmd`, which names the 53 vessels whose per-vessel figures
are wrong. Parking the repair is not a finding that the data is fine.

**Before resuming**, read the yml's `parked` and `the_supersession_hypothesis_failed`
sections. The second is the most recent thing learned and the most expensive to
rediscover.

**check:** none — a parked item has no completion test. It closes when the maintainer
reopens it or decides the rows stay out for good.

---

## 18. Fishing windows from behaviour, not from the logbook
**status:** open · **see:** `curate/plans/004-behavioural-fishing-windows.md`

Infer each station's fishing window from the logger's own speed and heading, instead of
from logbook times that 7,336 stations a year do not record at all. Five cheap
measurements decide whether it is worth building; none has been done.

**check:** plan 004's five measurements are recorded in its header.

## 17. Full review of the STK vessel match
**status:** open · **needs: maintainer** · **see:** `curate/plans/003-stk-vessel-identity.md`

**Asked of the maintainer:** plan 003 steps 6–9 — close `d2` behind `d2_is_open`, the
reliability tier column, the ASTD identity table, and the dead `n >= 10` filter at
`ais_key.R:305`.

Reviewed 2026-09-22; the design, the re-measured baseline and the four superseded
numbers are all in the plan. Two corrections came out of it and are declared:
`ais_key_callsign_reuse.yml` and `stk_trail_time_outliers.yml`. The latter must land
before `d2` is closed from evidence.

**check:** plan 003 steps 6–9 are marked done in its own header.

## 15. The three-repo publication boundary
**status:** open · **needs: maintainer** · **see:** `curate/plans/001-three-repo-publication-boundary.md`

**Asked of the maintainer, in the plan's own words:** restrict or relocate the Mapbox
token (§4), decide when the GitHub remote goes up and whether history is rewritten
first (§4), set the aggregation rule for what may leave `fishydata` for an open
`fishyweb` (§3), and say where `fishydata` lives and whether it is backed up (§5). The
disclosure rule blocks item 16. Everything else in the plan I can act on unblocked.

**check:** the four questions in plan 001 §§3–5 are answered in the plan, and the
Mapbox token no longer appears in the working tree.

`fishycode` public on GitHub, `fishydata` never public, `fishyweb` an open web page.
The design, the evidence and the open questions are in the plan; this stub exists so
the work is visible here. Two things in it are time-sensitive: there is still **no git
remote**, so history is free to rewrite until the first push, and a Mapbox `pk.` token
is committed in three files. The boundary that actually needs a rule is
`fishydata` → `fishyweb`, which is a data-disclosure question and binds item 16.


---

## 16. `~/stasi/fishyweb` — port the last mile
**status:** blocked · **see:** `curate/plans/002-the-last-mile.md`, item 15

`fishyweb` is alive, not an archive (maintainer, 2026-09-22) — the third repo of plan
001, keeping its 22 `ramb/` posts. The question is what to *port*, and the design is in
plan 002. Blocked on item 15's disclosure rule, which decides what may leave
`fishydata` at all.

**check:** plan 002's port list is built and item 15's disclosure rule exists.

