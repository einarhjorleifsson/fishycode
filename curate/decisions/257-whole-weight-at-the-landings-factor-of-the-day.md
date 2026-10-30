# 257 — Whole weight at the landings' factor of the day: one factor table dated by the regulations, the logbook's ×1.25 kept beside it, the Nephrops tails at 3.25, and the landings keeping their state

*2026-10-30. Plan 054 step 2c, plan 051 steps 3-6, plan 050 step 5 (TODOs 152, 157). Coded by Claude (AI) in a side
session and checked on a scratch store, not by a person. The regulations were read as web pages, and one was checked
by hand. The code is on branch `claude/plan-054-whole-weight-75363a` as 51c81e1 (the tails and whole weight) and
84a2eb6 (the landings scripts in lazy DuckDB, 13 min to 80 s, outputs identical). It goes to main once the shared tree
is clean. The draft with every table, the regulation readings, the step 6 counts and the traces are in
`$FISHYDATA/archive/2026-10-30-plan054-whole-weight/`. Nothing is built on the live store.*

## Chosen (plan 051 asks a, d and e, answered 2026-10-30)

- **One factor table**, `curated/reference/whole_weight_factor.parquet`, built from a reviewed declaration,
  `reference/species/whole_weight_factor.yml`. It holds four scopes:
  - `landings`: the landing system's factor per species, state, area and period. A set period where it holds over
    time; a year mean, with its range, for products processed at sea; every other species, state and area the data
    hold, listed.
  - `logbook`: the rows `calc_whole_weight()` reads. The logbooks' own 1.25 is the fallback for a gutted species
    without a landings factor.
  - `lumpfish logbook`: provisional (TODO 167).
  - `held`: kept and not applied.
- **The periods are dated by each fishing year's regulation on the total allowable catch.** A year read that prints
  the same factor gets basis `recorded`, with the regulation as witness. A year not read keeps the landings' table,
  basis `derived`. A regulation that prints another factor stops the build. 2000/01 to 2025/26 were read, and no factor
  changes in them. 1996/97 to 1999/2000 are not online as web pages, so the change of 1997-09-01 rests on the landings'
  tables.
- **`calc_whole_weight()` reads the table:**
  - GUTT takes the species' gutted factor of the day, 1.1905 for cod, haddock and saithe since 1997-09-01;
  - lumpfish logged gutted is roe, and takes the roe factor;
  - a state named by a correction takes that state's factor (the tails, 3.25);
  - UNGU, RELE and afli's stateless weight are taken as they are.

  The basis is `reconstructed`. The logbook's own whole weight is kept beside it (`catch_round_logbook`). Without the
  table the function returns the old rule, so the merge's fate is unchanged.
- **The Nephrops tails** (plan 050 step 5) keep its detection and guard. Its 3.3 gives way to the table's 3.25, which
  both landings systems and every regulation read use.
- **The landings keep their state and the weight as landed**, in a new `curated/landing/catch_detail.parquet`.
  `catch.parquet` is summed from it as before and is unchanged to the last bit.

## Checked on a scratch store

- **`catch_by_species_station`:**
  - the same 16,991,905 rows;
  - `catch_recorded` unchanged on every row, and `catch_round_logbook` equal to the old `catch_round`;
  - the whole weight moves on about 637,000 e-logbook rows and the 2,047 tail rows, from 51,214.8 to 51,142.7 kt
    (−0.14 %).
- **Logged over landed**, from 2015, before and after:

  | species | before | after |
  |---|---:|---:|
  | cod | 1.038 | 1.027 |
  | haddock | 1.043 | 1.025 |
  | saithe | 1.071 | 1.056 |
  | Greenland halibut | 1.113 | 1.059 |
  | plaice | 1.125 | 1.074 |

  Saithe in 2025-2026 stays at 1.20-1.43 either way: a fault other than the factor.
- **`landings.parquet` and `catch.parquet`** are unchanged by row hash. `catch_detail` has 8,419,860 rows and sums to
  `catch.parquet` on every row.
- **Speed.** The landings scripts went from 13.5 min to 80 s with the same outputs (84a2eb6), against about 3 min for
  the same targets live.

## Not done, and why

- **afli's stored weight stays as stored**, round(GUTT × 1.25) + UNGU. Its state is in the sent layer and not carried
  into the merge; that is plan 037 phase 1 (TODO 115).
- **The area.** The logbook reads Iceland's waters' factor everywhere, so a haul off Norway or in the Barents Sea is up
  to 1 % heavy.
- **Ask e is the maintainer's.** Under the 0.84 cut, afli's weights without a sent message fall 25-30 % of their
  judged kilograms, against 10-11 % in the control known to be converted. So part of the paper era looks unconverted,
  but the test cannot say which trips. Nothing is changed on it.

## Left

- The live build, by name, in rebuild A. `whole_weight_factor` and `logbook_nephrops_tails` are new targets.
- v0's catch and `docs/data-dict.yaml` follow it.
