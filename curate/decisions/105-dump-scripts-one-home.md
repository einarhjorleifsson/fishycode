# 105 — The dump scripts have one home, `dump/`, and one Oracle dumper

*2026-10-15. Written by Claude (AI-assisted) on the maintainer's go. Does plan 016 §4 step 6's second bullet.*

## What was wrong

The Oracle dumps had two homes. The repo's `dump/` held one copy of each script; `$FISHYDATA/raw/` held another,
`DUMP_*.R` beside the data. The raw copies were the ones run, and git did not track them, so the two drifted:

| raw copy (run) | repo | difference |
|---|---|---|
| `vessels/DUMP_vessels.R` | `oracle/vessels.R` | `rjdbc = TRUE`; relative output path |
| `ais/DUMP_stk.R` | `ais/stk.R` | `rjdbc = TRUE`; first year 2025, edited by hand; `~/stasi/...` paths |
| `logbooks/DUMP_afli.R` | `oracle/afli.R` | `rjdbc = TRUE`; neither wrote where the pipeline reads (`data-raw/data-dump/afli`, `fd_staging("data-dump", ...)`) |
| `logbooks/DUMP_oracle.R` | `oracle/dump_tables.R` | `rjdbc = TRUE`; both wrote `tmp_agf/` |
| `gear/DUMP_gear.R`, `species/DUMP_species.R` | `oracle/gear.R`, `species.R` | both wrote old relative or `staging/` paths |

The same table-and-view loop sat in six of these files. `raw/logbooks/adb`, `fs_afladagbok` and `logbook` had no
script at all. The adb dump of 2026-04 lacks `fishing_station` (595,677 rows in Oracle) with no record of why: the
loop caught only the error of building the query, and kept no list of what it wrote.

## What was chosen

- **`dump/` is the only home** (maintainer). The six raw copies were moved to the macOS Trash. `raw/ais/DUMP_stk_step2.R`,
  `raw/aux/DATASET_*.R` and the scripts under `raw/external/` are not copies of anything here and were left.
- **One dumper, `R/dump_oracle.R`.** `dump_oracle_schema()` writes every table and view of a schema;
  `dump_oracle_table()` writes one. A failing table is recorded with Oracle's message and the loop goes on.
  `_overview_tables.parquet` gains the rows written, the status, the error, the time, the script, the commit and the
  driver; `_overview_fields.parquet` holds each column's declared type. A file an earlier dump wrote and this one did
  not is named at the end and left in place.
- **Types follow Oracle's declaration, not the driver.** RJDBC, the only driver on the laptop (ROracle finds no
  Oracle client), returns NUMBER columns as doubles (every one in the vessel dump of 2026-10-14); the earlier dumps
  hold some as integers (adb's `species_no`, afli's `skipnr`). `NUMBER(p <= 9, 0)` is cast to integer from
  `all_tab_columns`; whether that reproduces the earlier types column for column is checked on the first run. A mock run against
  DuckDB checked the cast, an empty table, a failure, `skip`, `drop` and the stale-file note.
- **Writes go through `write_parquet_group()`**, plain `TIMESTAMP` as AGENTS.md requires; the vessel and afli dumps
  had used nanoparquet.
- **The scripts:** `dump/oracle/{adb,afli,agf,fs_afladagbok,gear,lods,logbook,species,vessels}.R` and `dump/ais/stk.R`,
  each writing where its reader looks. `dump_tables.R` became `agf.R`, and its kvoti table went to `lods.R` with
  `lods_londun`, which was on disk with no script. afli's XML table is now joined on `id` (unique: 483,738 rows) rather
  than bound side by side from two queries.
- **They run in the maintainer's terminal.** The password comes from the macOS keychain, which Claude's shell cannot
  open.

## Found on the way

- **STK `year=2026`, dumped 2026-10-15, holds `.id` and `mid` as text**; 2007-2025 hold doubles. The pipeline reads
  them right only because DuckDB takes the schema from the first file and casts the rest. `stk.R` now casts after
  collecting, and since 2026 is the current year its next run rewrites the partition.
- **`stk.R` refetches a year that does not reach 31 December**, instead of a first year edited by hand: every year
  2007-2025 holds a record from the last minute of 31 December.
- **`raw/ais/stk/einarhj_mobile-vid.parquet`, rewritten 2026-10-15, holds `t1`, `t2` and `datel` as text.** It is an
  input of the frozen `once` project only (`ais_key_cascade`), so it matters only if that project is redone.

## Not done

The new scripts have not run against Oracle. `dump/oracle/landings.R` is not a dump (it transforms, writes
`staging/` and uses arrow) and was left as it is.
