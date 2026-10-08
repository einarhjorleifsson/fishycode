# 071 — ramb's functions are named verb first; fishycode calls the new names (plan 013, phase 1)

*2026-10-08. Plan 013 phases 0–1. Code by Claude (AI-assisted): ramb 0ede1c2 and 5c181c3 (version 2026.10.08.1),
fishycode in the commit that adds this record. Closes TODO items 7 and 30.*

## What was done

- **ramb (phase 1a).**
  - 35 functions renamed to `rb_<verb>_<stage|object>`.
  - Four groups that did one task merged behind an argument: `rb_convert_speed(from, to)`,
    `rb_extract_metier(part)`, `rb_get_gear_vocabulary(list)`, `rb_cap_outliers(method)`.
  - Bodies unchanged; the merged ones became internal.
  - The 48 old names are aliases (`R/renamed.R`). Each warns once per session that it will be removed, then calls
    the new function.
  - The functions that later phases replace keep their names for now; the naming test lists them.
  - Also in this step:
    - duplicate definitions removed;
    - R ≥ 4.1;
    - Roxygen markdown;
    - undeclared Suggests declared;
    - `NEWS.md` maps every old name to its new one;
    - `_pkgdown.yml` groups the reference by flow stage.
- **fishycode (phase 1b).** Eleven files call the new names: the pipeline, checks, products and two docs pages.
  `rb_whack_*` and `rb_trip` stay as they are until phase 2.
- **TODO 30.**
  - `docs/qc_fs_afladagbok_2025.qmd` reads the duration limits from `curated/reference/gear_window.parquet`
    (decision 057) instead of its own copy of the cap table.
  - Its prose now says what the pipeline does: above the limit, NA plus "implausible", raw value kept.
  - Its inputs moved from pre-restructuring paths to `fd_raw()` / `fd_curated()`. It renders again.
- **TODO 7.**
  - `R/check_ready.R` resolves input paths with `fd_path()`, which creates nothing. `fd_staging()` and
    `fd_curated()` create the directory when resolving it, which made every missing directory look present.
  - An existing but empty directory now counts as missing.
- **`docs/grammar.qmd`** also read a pre-restructuring path and did not render. Fixed in phase 0.

## Measured

- **ramb.**
  - Every new name reproduces, on the same inputs, the output saved with the ramb of before the renames
    (`tests/testthat/fixtures/pre_rename.rds`, 26 functions).
  - Every alias returns the same and warns once.
  - Test suite: 38 blocks, 0 failures.
  - `R CMD check`: 0 errors. The warnings and notes that remain predate the change: `gisland` undeclared in
    `mb_base_raster`, three globals in `.whack_clean_lazy`, and a clang header warning.
- **Real data.** Phase 1b's only pipeline change that reaches `curated/` goes through `rb_classify_mmsi()` (via
  `R/entity_class.R`). `reference/vessels/ais_key_cascade.R` was re-run with the new names against `$FISHYDATA`,
  in a scratch overlay that writes nothing into `curated/`:
  - 19,163 rows, identical to the built `vessel_ais_key_cascade.parquet`;
  - no old-name warnings.
- **`check_ready()`** on a scratch store with an empty `staging/ais/ping_union`: the directory is reported missing,
  and no directory is created as a side effect.

## Not done in phase 1, by choice

Moving `terra`, `mapdeck`, `scales` and `icesVocab` to Suggests needs a check inside each function. Recoding
`data.table` (jepol) and `traipse` changes code, not names. Both move to phase 2, where every change is compared
on real data.
