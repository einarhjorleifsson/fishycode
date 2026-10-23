# 194 — The logbook merge writes the fate of every staging station and trip (plan 024): coded and checked, not built

*2026-10-23. On the maintainer's answers to plan 024's asks the same day (plan 024 §6). Coded and checked on a scratch
`$FISHYDATA` by Claude (Anthropic): the code, the checks and every count below are Claude's, not yet checked by a
person. Nothing was built in the store. The tables are built with the next rebuild that touches the logbook (plan 037
phase 1), so the chain is rebuilt once; TODO 79 stays open until then.*

## What was chosen (the maintainer, 2026-10-23)

- (a) The merge itself writes `curated/logbook/station_fate.parquet`: one row per staging station of every source it
  reads, with the rule that dropped it. Each tier's anti-join keeps the stations it removes, so the rules exist once.
- (b) With the whole weight and `day_match`. The whole-weight rule becomes one function in `R/`, named with the
  grammar's term (plan 037 §4), which both the merge and `catch_by_species_station.R` call. That file's output must
  not change.
- (c) `trip_fate.parquet` beside it, one row per staging trip, the 78,870 with no station included.
- (d) The drops before staging, by the adapters, later: each adapter its own ledger.
- The merge checks the account before writing and stops otherwise.

## What changed

- **`R/whole_weight.R`**: `calc_whole_weight(catch, by, ...)`, the one copy of the rule. It takes `catch_whole` where
  recorded and GUTT / 0.8 where not, and is as recorded otherwise. The basis is the weakest of the rows (decision
  066). It uses only verbs that dbplyr translates, so it runs in DuckDB and in memory alike.
- **`curate/catch_by_species_station.R`** calls it through dbplyr in place of its own SQL. Its columns keep their
  names (`catch_round` is the whole weight, `round_basis` its basis).
- **`curate/logbook.R`**:
  - The fate's rows are taken before any rule: each staging station with its tier key, and each staging trip.
    Each station's catch as recorded and its whole weight are summed in DuckDB from the staged catch files.
  - Each date bound names the bound a station broke (`out_of_bounds()`). Each tier returns what it kept and what it
    dropped from one anti-join and semi-join pair (`split_held()`).
  - After the merge: `in_curated` is read from the stations written, `held_by` from the kept stations' vessel-days,
    and `day_match` set; then the trips, the invariants, the two files.
  - The sources' samples and catch are freed before the fate is put together.
- **`_targets.R`**: the `logbook` target declares the two files.
- **`docs/data-dict.yaml`**: `logbook_station_fate` and `logbook_trip_fate`, with their composite keys and their rules
  as table assertions.
- **`docs/merge.qmd`**: a section, "What the merge keeps and drops", whose four tables read the files. It says the
  tables are not built yet while the files are missing.

## The tables

**`station_fate`**, key (`.sid`, `schema`):

- `.tid`, `copy`, and the tier key (`vid`, `date`), as the merge saw them.
- `kg` and `kg_whole`, with `kg_whole_basis`.
- `in_curated`.
- `reason`: `date_before`, `date_after`, `date_missing` or `vessel_day_held`.
- `held_by`: the tier whose kept stations hold the vessel-day.
- `day_match`: `equal`, `held_more` or `dropped_more`.

**`trip_fate`**, key (`.tid`, `schema`):

- `vid`, `T1`, `T2`, `n_station`, `n_kept`, `kg`, `in_curated`.
- `reason`: its stations' reason, `mixed` when they went for different reasons, or `no_station`.

**The invariants** (the merge stops otherwise):

- one row per staging station and per staging trip;
- every station's trip is a staging trip;
- the `in_curated` rows are exactly `station.parquet`'s and `trip.parquet`'s keys;
- per schema, staging kg = kept + dropped, and kept kg = `catch.parquet`'s;
- no station or trip is dropped by a rule the merge does not name (`other`);
- no vessel-day is held by two tiers.

**Choices made in coding**, Claude's, for review:

- **`day_match` compares row against row,** duplicate twins included on both sides. Twins are judged only on the
  merged tables, so the dropped side cannot leave its own out. With the kept side's duplicates left out, adb had 799
  "dropped more" vessel-days against fs_afladagbok. 786 of them are equal once the kept side's duplicates count:
  records entered twice that both copies of the e-logbook hold.
  Row against row reproduces plan 024 §2.3's method: fs_afladagbok gives the same 37,406 / 37,104 / 193 / 109 /
  12.5 kt.
- **"Equal" means within 1 % of the larger weight.** Two days with no catch are equal.
- **The column names are `kg_whole` and `kg_whole_basis`,** the grammar's term, in place of plan 024's `kg_round`.
- **The basis words are `catch_by_species_station`'s** (`reconstructed` for GUTT / 0.8), so that its output stays
  the same. Plan 037 phase 1 settles the word: `derived`, by TODO 115's check.
- **aflaskeyti's staging trips are `trip_landing.parquet`** (812), the trips the merge reads, not the adapter's
  `trip.parquet` (794).
- **A vessel-day with no vessel is never held.** This is `na_matches = "never"` for `held_by`; the tiers' own
  anti-joins keep dplyr's default. The 21 afli stations with no `vid` are all kept.

## Checked on a scratch store

The setup: `raw/` and the four sources' `staging/` were linked from the store, and `curated/` started empty. The merge
and `catch_by_species_station.R` were run through `R_ENVIRON_USER`. Afterwards no file under the store was newer than
the start, so nothing in the store was written.

- **The four logbook tables are identical to the store's** (built at 003b194): `trip` 1,854,063, `station` 7,310,942,
  `fishing_sample` 7,310,942, `catch` 17,026,059. None is in either `EXCEPT ALL`, columns and types are the same, and
  the rows are in the same file order. The same holds for **`catch_by_species_station`** (16,991,905 rows, the same
  `fd.schema_hash`).
- **The invariants held:** 8,013,418 station rows and 2,175,609 trip rows. `validate-data` passes on both files:
  their keys, enum values and table assertions, with 0 failed rows. `validate-spec` passes on the whole dictionary,
  with no error and the same 266 todo warnings as before.
- **Time and memory:**

  | run | time | resident | peak footprint |
  |---|---|---|---|
  | HEAD's merge | 1.6 min | 11.9 GB | 17.9 GB |
  | this one | 3.0 min | 11.4 GB | 18.4 GB |

  Before the sources were freed, it peaked at 22.4 GB of the machine's 24.
- **`tar_outdated()`**, read-only against the store's `_targets` (its `meta` unchanged): on HEAD's tree it lists none.
  With these changes it lists **20**: `logbook` and its chain through `ais_catch` and the checks (`lid_map`,
  `logbook_gear`, `catch_by_species_station`, `catch_by_species_trip`, `station_window`, `trip_voyage`,
  `trip_reconciled`, `station_event`, `voyage_gear`, `ais_trail`, `ais_catch` and eight checks). The `logbook`
  command now names two files the store lacks. **They are left outdated, on the maintainer's word.** Any
  `tar_make_isolated(names = )` that reaches a target downstream of `logbook` would build the chain before that
  rebuild. Build such a target with the logbook chain, or not at all.
- `docs/merge.qmd` renders both with the files (from the scratch store) and without them (HEAD's scratch merge),
  from a copy outside the repo, so the book's freeze holds no scratch numbers.

The scripts, logs and outputs are in the session's scratchpad. They are not kept.

## Plan 024 §2, recounted on today's inputs

These counts are from the scratch `station_fate` and `trip_fate`. Their inputs are the store's staging as built on
2026-10-22. Plan 024's were from 2026-10-16, before decision 127 (aflaskeyti, fs_afli's paper stations) and decision
160 (adb from 2025-11-19). Stations are given with kt of catch as recorded in brackets.

### By source and reason

| source | staging | kept | vessel-day held | before the lower bound | after the upper bound |
|---|---|---|---|---|---|
| afli, copy afli | 6,844,567 (45,984.7) | all | 0 | no bound | 0 |
| afli, copy fs_afli | 189 (0.2) | 172 (0.2) | 17 (0.0): afli 11, fs_afladagbok 6 | no bound | 0 |
| fs_afladagbok | 469,881 (5,419.9) | 374,681 (3,926.6) | 95,009 (1,492.9), all afli | 165 (0.4): day held by afli 66, by none 99 | 26 (0.0) |
| adb | 691,011 (7,417.8) | 88,464 (836.7) | 2,206 (26.7), all fs_afladagbok | 600,315 (6,554.3): afli 229,443, fs_afladagbok 370,170, fs_afli 171, none 531 | 26 (0.0) |
| aflaskeyti | 7,770 (517.1) | 3,058 (283.0) | 4,712 (234.1), all afli | no bound | 0 |

- **No station has a missing date.** In all, 702,476 stations are dropped (8,308.5 kt of 59,339.7 kt staged).
- **The kg account to the kilogram** (staging = kept + dropped):
  - afli 45,984,899,996 = 45,984,890,342 + 9,654;
  - fs_afladagbok 5,419,941,634 = 3,926,592,021 + 1,493,349,613;
  - adb 7,417,808,187 = 836,735,338 + 6,581,072,849;
  - aflaskeyti 517,070,613 = 282,957,397 + 234,113,216.

  Each kept figure equals `catch.parquet`'s.
- **The dates after the upper bound** are the same 26 stations in fs_afladagbok and adb, in 2027-2031.
- **adb's 2,206 held stations** lie from 2025-11-19 to 12-12, on 854 vessel-days fs_afladagbok's dump still holds.
- **aflaskeyti's 4,712** are the Icelandic vessels' hauls on vessel-days their own logbook holds (plan 026).

### Trips

| schema | staging | kept (split) | vessel_day_held | date_before | date_after | mixed | no_station |
|---|---|---|---|---|---|---|---|
| afli | 1,661,071 | 1,661,056 (0) | 15 | 0 | 0 | 0 | 0 |
| fs_afladagbok | 207,189 | 154,534 (8) | 20,640 | 114 | 26 | 2 | 31,873 |
| adb | 306,537 | 37,878 (2) | 549 | 221,043 | 26 | 44 | 46,997 |
| aflaskeyti | 812 | 595 (1) | 217 | 0 | 0 | 0 | 0 |

- **Trips that went whole:** fs_afladagbok's 20,782 are plan 024's count. adb's are now 221,662 (222,743 under the
  old bound).
- **Trips with no station:** 78,870, the same as plan 024's. They run from 2020 to 2026 (adb 2026: 4,943), with 3
  strays before.
- **The 46 `mixed` trips** lost stations both to a date bound and to a tier.
- **A split trip** keeps some of its stations: 21 fs_afladagbok, 6 adb, 4 aflaskeyti and 2 adb date-bound stations
  went from 11 kept trips.

### By year, where the dropped vessel-day is held

| year | fs_afladagbok, held by afli | adb, date bound, day held by afli | adb, date bound, day held by fs_afladagbok | adb, date bound, day not held |
|---|---|---|---|---|
| before 2019 | 9 (0.0), date bound | 61 (0.0) | 0 | 108 (0.1) |
| 2019 | 57 (0.3), date bound | 1,198 (3.0) | 0 | 0 |
| 2020 | 643 (3.1) | 102,176 (931.1) | 14 (0.0) | 360 (0.0) |
| 2021 | 55,461 (770.6) | 86,182 (1,019.8) | 22,001 (19.8) | 32 (0.0) |
| 2022 | 37,093 (711.1) | 38,012 (719.0) | 65,340 (666.4) | 24 (0.0) |
| 2023 | 1,801 (8.0) | 1,803 (8.0) | 94,910 (1,349.6) | 0 |
| 2024 | 11 (0.0) | 11 (0.0) | 97,232 (934.5) | 1 (0.0) |
| 2025 | 0 | 0 | 90,673 (902.6), and 2,206 (26.7) held by the tier from 11-19 | 6 (0.0) |

- **The three date-bound adb columns hold 600,144 stations;** 171 more (0.2 kt), in 2020 and 2022, are held by
  fs_afli's paper stations.
- **December 2025 (plan 024 §3) is in the product.** From 2025-11-19 no adb station is dropped on a vessel-day
  nothing holds, but for the 26 dated 2027-2031.
- **The 423 adb stations of 2019 to 2025-11-18 that no source holds** are the 423 that decision 160 removed. With them,
  682 dropped stations (0.4 kt) are on no vessel-day of the product. The other 259 are adb's 108 before 2019 and 26
  after the bound, and fs_afladagbok's 99 before and 26 after.

### On held vessel-days: the dropped whole weight against the kept

| dropped | vessel-days | equal within 1 % | kept more | dropped more | dropped excess (whole weight) |
|---|---|---|---|---|---|
| fs_afladagbok, tier, held by afli (2020-2024) | 37,406 | 37,104 (99.2 %) | 193 | 109 | 12.5 kt (2021: 10.0, 2022: 2.4) |
| adb, date bound, held by afli | 103,451 | 101,262 (97.9 %) | 1,996 | 193 | 14.3 kt (2021: 10.1, 2022: 4.2) |
| adb, date bound, held by fs_afladagbok | 193,927 | 193,186 (99.6 %) | 731 | 10 | 0.0 kt |
| adb, date bound, held by fs_afli | 171 | 171 | 0 | 0 | 0 |
| adb, tier, held by fs_afladagbok (2025-11-19 on) | 854 | 851 (99.6 %) | 0 | 3 | 0.0 kt |
| aflaskeyti, tier, held by afli (2014-2018) | 1,510 | 1,082 (71.7 %) | 345 | 83 | 6.4 kt (2018: 5.4) |
| fs_afli's paper stations, tier | 16 | 14 | 1 | 1 | 0.0 kt |

- **Without the whole weight** only 43.8 % of fs_afladagbok's held vessel-days agree with afli's, against plan 024's
  44 %. So `kg_whole` is the scale the question needs.
- **adb against afli:** plan 024 counted adb's date-bound days together, 203 dropped more and 14.4 kt. It is again 203
  days (193 + 10) and 14.3 kt.
- **aflaskeyti, not traced:** on the 345 days where the kept afli logbook holds more, it holds a median 1.06 times
  the reported whole weight (4 days near 1.25). On the 83 days where it holds less, it holds 0.80 times, as if a
  weight `aflaskeyti_weight.R` reads as gutted (/ 0.8) had been whole.

## Not done here

- **The build:** with plan 037 phase 1, the next rebuild that touches the logbook. Until then TODO 79 is open and
  `docs/merge.qmd`'s section says the tables are not built.
- **The adapters' own ledgers** (ask d): afli's 23,570 stations (decision 098) and fs_afli's 1,898 electronic
  stations (decisions 123-124).
- **Plan 038 §7.1's `catch_unit`**, the other instrument of plan 038 §8 step 1.
