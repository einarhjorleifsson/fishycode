# 133 — The licence history builds in `once` to 2020-07-22, its live tail in the main project (plan 029 ask c)

*2026-10-18. The maintainer's choice; the split and its reasons written by Claude (AI-assisted). Nothing was built or
wired.*

## Decided

Asked where plan 029's licence history fits the `once` concept, the maintainer approved Claude's proposal: "yes
proceed".

- **The history to 2020-07-22 is a one-time fix**, built in the `once` project, reviewed, and frozen. It holds:
  - the staging of kvoti's licence tables, their corrections, and the evidence of every lineage;
  - each witness's calibration: its agreement with the licences while both existed (plan 029 §3.5);
  - the rules and the reviewed overrides.

  It writes `curated/vessel/licence/{evidence,calibration,history}.parquet`, and is redone only by a decision record.
- **The live tail from 2020-07-23 is the main project's**, on the preprocessing side. It runs the class and quota
  witnesses through the same rules with the frozen calibration, reads the frozen history with `frozen_input()`, and
  writes `curated/vessel/licence.parquet`.

## Why

- **Why `once` fits the history:**
  - Its sources are closed: kvoti's licence tables stop on 2020-07-22 and will not change.
  - The rules leave rows open until a person settles them, and frozen-after-review is what `once` is for.
  - Its first users build in `once`: the register's history (plan 028, decision 132) reads licences as witnesses,
    and so would the STK key, to settle which hull a mobile id belongs to.
- **Why the tail does not fit:**
  - Its witnesses (`vessel.vessel_operational_hist`, `kvoti.afla_heimild`) change with every dump. Frozen, they would
    need a decision for each new dump.
  - There is no cycle to break: the history reads no AIS, and activity only flags.
- **Why the split falls at 2020-07-22.** It is the last day of the licence tables, so the calibration can be measured
  only up to it. The register's split at 2023-12-19 is the same pattern: the day its live source begins.
- **A licence system after 2020 that can be dumped** (plan 029 ask a) goes into the live tail, not a `once` redo.

## Not done

- Nothing is coded or wired. `_targets_once.R` and AGENTS.md (which lists the fixes `once` holds) change when the
  targets are wired, plan 029 step 6.
