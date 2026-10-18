# 134 — The licence register staged, its lost century corrected, and every witness calibrated (plan 029 steps 1-3)

*2026-10-18. Coded and checked in a scratch store by Claude (AI-assisted), at the maintainer's go ("yes proceed").
Nothing was written to the real store, and nothing is wired into `_targets_once.R`.*

## Coded

All three carry `# Side: once (licence history)` (decision 133):

- **`sources/kvoti/licence.R`** (step 1) stages 20 tables in `staging/kvoti/`:
  - the licence register: licences, deleted licences, lumpfish rights and their 2021 state, lumpfish nets, Danish
    seine with its period dates, revocations, exemptions, arrears, and the code lists;
  - the quota record's rights (1,422,730 rows; its catch, `heimild` X, is left out), quota types, right codes;
  - mackerel allocations and the mackerel class;
  - effort-day notices, coastal trips, the lumpfish logbook with each hull-year's first and last set.

  Columns are renamed and nothing else changes. Kennitala is kept: the lumpfish right's owner and the net
  application's operator, by the maintainer's general rule of the same day (below). Staff user names are dropped.
- **`curate/corrections/licence_lost_century.{yml,R}`** (step 2) writes `staging/kvoti/licence_date_fix.parquet`.
  Of 16 dates with a year below 1000, 13 take 2000 + the year within a year of their entry stamp. Three are left for
  review: 0010-06-23, 0201-09-02 and 0219-03-26, all revocation ends.
- **`reference/vessels/licence_evidence.R`** (step 3) writes two files:
  - `curated/vessel/licence/evidence.parquet`: 447,019 statements on 5,218 hulls, from 14 records in six lineages;
  - `curated/vessel/licence/calibration.parquet`: each witness's `implies` and `covers` by group and year,
    1991 to 2020-07-22.

  The class runs come from `curated/vessel/vessel_class.parquet`, read as a main-project file, so the runs are not
  computed a second time.

## Checked (scratch store, raw linked read-only)

- Every staged table's rows equal the counts of plan 029 §2-3, from 61,847 licences to 231,015 coastal trips.
- Every Danish seine licence finds its period.
- Timestamps are written as plain TIMESTAMP.
- The evidence file carries its eight provenance stamps.
- `find -newer` on the real store's `staging/` and `curated/` after each run lists nothing.
- The step takes 9 seconds.

## Found

The calibration (plan 029 §3.5) corrects two of the plan's hand counts:

- **The class implies the catch-quota licence for 99.5 % of hulls**, counted over the classes that name a fishing
  vessel (10-91). The plan's "300 licences against 2,773 hulls" counted the whole Aflamark system, its null,
  inactive and temporary classes included.
- **The mackerel allocation implies the licence for 54 % of hulls** in the last five years. The 90-98 % the plan
  gave was the other direction: licence holders with an allocation (`covers`).

Above the proposed 95 % bar (ask b): every class mapped to a licence except 93, the coastal trips, the cod-cap and
recreational allocations, the lumpfish logbook, and, in the landings, Danish seine, lumpfish nets, sea cucumber and
sea urchin. Below it:
- the effort-day notices (0.70);
- class 93 (0.31);
- the scallop (0.91), mackerel (0.54), catch-quota (0.49) and inshore-shrimp (0.20) allocations.

## Kennitala: the maintainer's general rule

Stated while step 1 was written (2026-10-18): kennitala may be carried up to and including `curated/`, under
`$FISHYDATA` only, never in the repo, docs or anything published. It is recorded in AGENTS.md's rules. Plan 029 §5.1
follows it.

## Not done

- **The wiring and the build** (step 6). The plan 028 session edits `_targets_once.R` too, so the wiring waits for
  a word with it.
- **Step 4**, the rules and the history, which waits on asks b, f and g.
- **Step 5**, the checks and the docs page.
