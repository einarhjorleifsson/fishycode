# 218 — The complete rebuild of 2026-10-23: every target of the main project from raw at 916b901

*2026-10-24. The maintainer: "i want this session to end with a complete rebuild", then "Every target from raw". Run,
checked and written by Claude (AI), not checked by a person. The `once` project was not touched.*

## Run

- **Before:** every output path `tar_meta()` recorded was fingerprinted: 7,860 files, 8,838,247,673 rows, by rows,
  schema and order-free hashes of each column (`R/fingerprint.R`).
- **The build:** `tar_invalidate(everything())`, then `tar_make_isolated()` under `caffeinate`, at 916b901 with ramb
  2026.10.22.2 (0c3020b). All 121 targets of the pipeline were built, from 22:24 to 01:06 UTC (2 h 42 min), with no
  failure. `tar_outdated()` is empty since.
- The before meta also held six targets the pipeline no longer has (`port_stay`, `check_port_stay_logbook`,
  `annual_call_sign`, `vessel_sign_raw`, `vessel_class_raw`, `vessel_hist_raw`). Their files are still on disk and were
  not rebuilt.
- **The one target that reaches outside:** `lookups` reads two Wikipedia pages, the ISO 3166 country codes and the
  ITU prefixes, as its header says. Nothing is sent.
- **The log and every check:** `$FISHYDATA/archive/2026-10-23-complete-rebuild/`.

## Every file in one outcome

7,754 files are the same. 88 have the same rows and schema with values moved. 6 changed rows or schema. 5 GeoPackages
changed their md5. 7 files are only in the before set: raw files that only the six stale meta entries named, all
still on disk. Each change has one of these causes:

1. **Code committed after a target's last build**, which `targets` cannot see:
   - Decision 190's crosswalk, built for the first time: `vessel_ais_link` from 655,183 to 655,202 rows with
     `imo_flag`, its review from 3,030 to 2,611 rows with `imo_other`, and the routes check from 532 to 530. The
     crosswalk and review match decision 190's scratch result. `allocate_vids()` as a dry run gives 379,912 hulls
     (200001-579912, 0 inherited), as decision 190 requires before the allocation. Nothing was allocated.
   - Decision 213's edit of `sources/afli_sent/convert.R` after `afli_sent` was built: `fishing_sample`'s `.checks`.
2. **Decision 217:** `catch_flag` from 87,838 to 88,113 rows with three new columns, and `kg_flagged` in the catch.
3. **The web:** the maritime identification digits' `country`, as Wikipedia gave it that night.
4. **The order of floating-point sums:** ASTD identity's `hours` and `hours_box` (two scratch runs differ from each
   other by 1.5e-13 relative), the allocation audit, `landed_logged`, and the catch's `kg`.
5. **A GeoPackage stores its write time** (decision 073): `eusm`, `gebco`, `ices_areas` and the two port files.
6. **Two steps whose result depends on the run** (TODO 139). Their inputs and code are identical before and after.
   Three scratch runs of `trip_reconciled` since agree with each other and with the build, so a tie usually, but not
   always, falls the same way.
   - **`trip_reconciled`:** T2 and its `_from`, `_outcome`, `_spread_s` and `T2_stk` moved. The STK witness takes one
     voyage per trip by `row_number() … ORDER BY s.T1 DESC`. On 36 of the 730,505 trips with an STK witness, two
     latest-starting STK voyages disagree on the return, and 32 of those trips take their T2 from STK.
   - **`voyage_gear`:** `arg_max(gid, n)` picks the voyage's gear. On 506 of the 825,075 voyages with a logbook vote,
     two gears or more share the largest count, and on 208 of them the tied gears differ in gear class. The landings
     vote ties on 8 of 185,515 voyages. `gear_class`, `s1` and `s2` are each their own `arg_max`, so on a tie they can
     come from different gears.
   - **Downstream:** the trail's 2008-03, 2008-05 and 2019-07 (the voyage's gear columns, and `fishing_flow` in two),
     and two catch files: 2008 part 1 gained 6 rows and 2019 part 3 lost 10.

## The flags on the rebuilt store

Decisions 216 and 217 together flag 316.0 kt: 293.7 by rule 1, 11.9 by the species' largest landing and 10.4 by the
vessel's. Every flagged kilogram is in one outcome. 187,184.4 t are on the catch, equal to the flag in every year of
the station's window under both approaches, and `kg_flagged` lies within [0, `kg`] on every row with `kg` of 0 or
more. 69.3 t are on five (station, species) rows with no window. 128,753.6 t are logged before 2007, where no unit
exists.

## Provenance

795 curated files carry stamps:

- **733 rebuilt at 916b901.**
  - 25 are clean, built up to 22:53:58.
  - 708 are stamped `fd.dirty` true, all built from 23:38 on. At 23:07 an untracked folder,
    `docs/figures/gagnakvorn/`, appeared in the repo: another session's figure in progress (the data grinder
    cartoon, left uncommitted on purpose). Nothing the pipeline reads is in it, so these files are what a clean tree
    gives. Their stamps say dirty until the next build from a clean tree.
- **62 not rebuilt:**
  - the `once` project's frozen outputs: the STK key and its checks, the GPS logger positions, the port radius and the
    register's history;
  - nine check tables that study scripts wrote outside the pipeline (`whack_*`, `sda_tune`, `afli_rafr_stofn_*`,
    `ais_key_foreign_candidates`, `vessel_identity_foreign_conflicts`).

## Left

- TODO 139: a tie-break in the two steps, so that a rebuild reproduces the store.
- TODO 65: the first allocation, `allocate_vids(dry_run = FALSE)`, then the crosswalk and its check rebuilt on the
  ledger (decision 190's commands, from its dry run on).
