# 142 — The register's live part from 2023-12-19, through the same model, in the main project (plan 028 step 6)

*2026-10-18. Coded, checked and built by Claude (AI-assisted), on the maintainer's go ("Start plan 028 step 6: the live
part from 2023-12-19 in the main project, through the same model"). Built in the main project by name, at 916ae1e. Amended the same day: the dump's date, and the register rebuilt
by decision 144, whose numbers supersede the tables below.*

## What was built

**`reference/vessels/vessel_register.R`**, the main-project target `vessel_register`, writes the register's tables for
every year to `curated/vessel/register/`. Each holds the frozen history's rows to 2023-12-19 (decision 136) and the live
rows after them, marked by `part`:

| table | rows | of them live | open at the dump |
|---|---|---|---|
| `vessel_hist` | 33,323 | 4,157 | 2,244 |
| `vessel_identification_hist` | 25,711 | 2,744 | 2,244 |
| `vessel_measurement_hist` | 17,806 | 2,409 | 2,244 |
| `vessel_engines_hist` | 15,820 | 2,427 | 2,215 |
| `vessel_operational_hist` | 42,608 | 6,275 | 1,823 |
| `vessel_fishery_hist` | 23,757 | 3,241 | 2,244 |
| `vessel_owners_hist` | 31,084 | 3,995 | 2,527 |
| `vessel_mmsi_hist` | 3,678 | | 2,889 |
| `vessel_event` | 20,841 | 121 | |
| `registered` | 8,462 | 2,305 | 2,244 |
| `decision` | 364,198 | 87,262 | 69,986 |
| `annual_call_sign`, 2004-2026 | 8,926 | | |

Two more outputs:
- `curated/check/vessel_register_open.parquet` holds the step's check, value by value.
- The main project reads the history through `frozen_input()` (target `register_history`), and the raw `vessel` schema
  and ufs through the file target `register_live_raw`.

## How the live part applies the model

- **D3.** From 2023-12-19 the `vessel` schema answers (plan 028 §4.3). It is one register source and dated, so D3 takes
  its versions. Its history tables hold every version, the current one with no `valid_to` and equal to the current
  table's row. They run to the dump of 2026-10-16, whose last entry in every history table is 2026-06-16 (first written
  here as the dump of 2026-06-16).
- **D1** applies as in the history.
- **D2's rules act on the schema's values** as in the history:
  - an IMO number failing its check digit gives way to ufs's that keeps it, or goes open: 9 fail, none has an
    alternative;
  - a call sign below 15 m length overall goes open (78);
  - a GT off the formula is flagged (213).
- **D4 and D5** have no annual series to act on.
- **Status** counts the fisheries' lineage (ufs, its current saga and the call-sign journal) and the radio's (the MMSI
  archive's call signs). Of the 87,262 live stretches:

  | status | stretches | share |
  |---|---|---|
  | single | 72,132 | 82.7 % |
  | agreed | 12,688 | 14.5 % |
  | resolved | 2,375 | 2.7 %, all D3 |
  | open | 67 | 0.1 %, D2 |

- **On the register** means the schema's status "Á aðalskipaskrá", the main register.
  - There are 2,305 live runs on 2,300 hulls; 2,245 continue one of the history's runs, and 2,244 are open at the dump.
  - 60 runs start after 2023-12-19 and 61 end, each a dated event.
- **One engine at a time.** Choosing engines column by column mixed two engines on hulls with two main engines: the
  make from one, the year from the other. Now an engine is chosen first, all its columns from it:
  - the main one (usage code A);
  - of two, the one that began last, then the stronger, then the lower id.
- **The split at 2023-12-19.** The history's open rows end at 2023-12-19 and the live rows start there.
  - The boundary is `continued` where the live row gives the same values on the columns both carry, else
    `system_start`.
  - A live row records the columns that change in `changed_at_start`.
  - The engines change most (the PDFs stopped printing them after 2017), then the operators' kennitala (Hreiðar's
    against the schema's) and `open` and the previous name, which the schema's system leaves empty for many hulls.

## Shared code

The live part reads the `vessel` schema and ufs with the evidence's own mappings. Those moved to `R/skipaskra_sources.R`
(`sk_vessel_schema()`, `sk_ufs()`, `sk_longer()`). The lineage count (`sk_lineages()`), the column list (`SK_HIST`) and
the agreement helpers moved to `R/skipaskra_compare.R`. The evidence, the history and the live part use them alike.
- Rerun in a scratch store after the move, the evidence and the history reproduce their built files exactly: 7,316,877
  rows, and 13 of 13 files.
- So their `once` targets were not rebuilt. `targets` sees no edit to their scripts' text, and the outputs would not
  change.

## Checked

- **Plan 028 step 6's check.** The rows with an open `valid_to` equal the `vessel` schema's current tables, for every
  registered hull and column by column: 79,855 of 79,855 values over 36 columns of six tables.
  - A zero counts as no value on both sides, as in the evidence.
  - Before the engine fix 23 differed, all on hulls with two main engines.
- **No overlap.** No table's rows overlap for a hull; the script stops otherwise.
- **The build.**
  - `vessel_register` and its two inputs were built in the main project by name, exit 0. Its 12 files are identical
    to the scratch run's, stamped 916ae1e, not dirty.
  - The main project has nothing outdated.

## Not done

- **Step 7**, repointing `vessel_sign`, `vessel_class`, `vessel_year` and `registry.R` to `curated/vessel/register/`,
  one at a time with fingerprints.
- **The STK key** still reads `staging/skipaskra/annual_call_sign.parquet`. The switch to the register's view belongs
  to its redo (TODO 25).
- **Asks d and e** of plan 028.
