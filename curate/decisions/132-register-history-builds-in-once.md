# 132 — The register's history builds in the `once` project, its live part in the main one (plan 028 ask a)

*2026-10-18. The maintainer's choice; the wiring, the checks and the build by Claude (AI-assisted). The graph was
first checked read-only; the build followed the same day on the maintainer's go ("Yes, run the once register build
now ..., compare the outputs with the scratch copies").*

## Decided

Asked where plan 028's register should build (ask a), the maintainer chose the plan's proposal: "Build the register
history to 2023-12-19 in the once project, as plan 028 proposes, and the live part in the main project."

- **The history to 2023-12-19 is a one-time fix** (plan 028 steps 1-5).
  - It covers the PDFs and the other witnesses read, the evidence table, the checks, and, with step 5, the decision
    model and the `_hist` tables.
  - It is built in the `once` project from frozen raw files, reviewed, and frozen, like the STK key that reads the
    register's call signs.
  - It is redone only by a decision record.
- **The live part, from 2023-12-19, is the main project's** (step 6). It will run the `vessel` schema's own history
  and the MMSI windows through the same model, and read the frozen history through `frozen_input()`.
- **The `once` project now holds four fixes, not three.** Decision 075 and AGENTS.md are amended to say so.

## Wired

- **`_targets_once.R`** gains 17 targets.
  - Nine build: the three PDF readers (`skipaskra_register`, `skipaskra_event`, `skipaskra_lists`), the four readers of
    step 2 (`hreidar_vessel_year`, `mbl_register`, `samgongustofa_register`, `marinetraffic_icelandic`),
    `skipaskra_evidence` and `check_skipaskra_discrepancy`.
  - Six are their raw inputs, as files: the 19 PDFs and mbl's 5,803 files listed by `input_files()` outside the
    commands, Hreiðar's workbook, the 2022-12-28 scrape, the two MarineTraffic sheets, and the Oracle tables read.
  - Two watch main-project files the history reads, as the key's targets do: `curated/vessel/mmsi.parquet` and
    `curated/landing/catch.parquet`. `main_landing` and `main_logbook` already watched the rest.
- **The nine scripts** now carry `# Side: once (register history)`.
- **Build it by its last target, never with the whole project:**

  ```r
  Sys.setenv(TAR_PROJECT = "once"); source("R/tar_make_isolated.R")
  tar_make_isolated(names = "check_skipaskra_discrepancy")
  ```

  Twelve of the key's, the logger's and the radius's targets are outdated already, because the main project's AIS
  rebuild (decision 129) changed the files they watch. A whole build would redo the STK key without a decision.

## Checked, read-only

- `tar_validate()` passes for both projects.
- The `once` project has 40 targets (was 23).
  - `tar_outdated()` lists 29: the same 12 as before the wiring, and the 17 new ones.
  - No existing target changed state.
  - `tar_outdated(names = "check_skipaskra_discrepancy")` lists exactly the 17, none of the key, the logger or the
    radius.
- The main project has nothing outdated.

## Built

`tar_make_isolated(names = "check_skipaskra_discrepancy")` in the `once` project, at b929d16 with a clean tree:
- all 17 targets were built, exit 0, in 11 minutes, most of it the PDF readers (lists 5 min, register 2 min);
- `tar_outdated()` lists the same 12 as before, and the 26 files of the key, logger and radius are byte-identical;
- no target outside the register changed in `tar_meta()`.

Every output equals its scratch copy from decisions 130 and 131:
- 13 of 14 files are identical, value for value;
- `skipaskra_discrepancy.parquet` holds the same 61,300 rows in another order: rows that tie on its sort keys come out
  of DuckDB in no fixed order, so a rebuild changes the file's hash but not its content.

The curated files are stamped b929d16, not dirty. Nothing in the register calls ramb, so AGENTS.md's ramb versions are
untouched.

## Not done

- **Step 5** still needs ask f (the decision model).
- **A question raised the same day:** whether Hreiðar's own numbers belong in the history. These are 90000 and above:
  1,764 boats without a register number, 30,913 rows, nearly all before 1992. The evidence table leaves them out, since
  they have no vid. Carrying them means giving each a vid through the vid ledger (`allocate_vids()`, decision 115).
  Plan 028 §9 ask g.
