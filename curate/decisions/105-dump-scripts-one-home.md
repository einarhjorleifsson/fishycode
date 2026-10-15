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
- **Types follow Oracle's declaration, not the driver.** RJDBC is the only driver on the laptop (ROracle finds no
  Oracle client). It returns `NUMBER(p, s)` as a double, but a NUMBER with scale 0 and no precision (Oracle's
  `INTEGER`) as text; the earlier dumps, made with ROracle, hold `NUMBER(p <= 9, 0)` as integers and every other
  NUMBER as a double. From `all_tab_columns`, `NUMBER(p <= 9, 0)` is cast to integer and a NUMBER that arrives as text
  to double, unless a value does not convert exactly (past 2^53), when the text is kept and named. A mock run against
  DuckDB checked both casts, an empty table, a failure, `skip`, `drop` and the stale-file note.
- **Writes go through `write_parquet_group()`**, plain `TIMESTAMP` as AGENTS.md requires; the vessel and afli dumps
  had used nanoparquet.
- **The scripts:** `dump/oracle/{adb,afli,agf,fs_afladagbok,gear,lods,logbook,species,vessels}.R` and `dump/ais/stk.R`,
  each writing where its reader looks. `dump_tables.R` became `agf.R`, and its kvoti table went to `lods.R` with
  `lods_londun`, which was on disk with no script. afli's XML table is now joined on `id` (unique: 483,738 rows) rather
  than bound side by side from two queries.
- **They run in the maintainer's terminal.** The password comes from the macOS keychain, which Claude's shell cannot
  open.

## The first run: adb, 2026-10-15

The maintainer ran `dump/oracle/adb.R` before the text cast existed. 31 of 32 objects were written; `fishing_station`
failed, as the maintainer expected (the overview now records it). `trip_v` came out column for column as in April,
but 16 files held their ids as text: `station_v.station_id`, `catch.catch_id`, `fishing_trip.fishing_trip_id` and
others, all declared NUMBER with scale 0 and no precision. That would have broken `sources/adb/convert.R`, which joins
the catch's double `fishing_station_id` to the station's id.

With the cast applied to a scratch copy, `convert.R` ran into scratch and matched `staging/adb` (built from April)
column for column: trips 270,490 then, 306,509 now; stations 628,314 then, 690,912 now; catch rows 1,893,058 then,
2,074,255 now. Every April trip and station is still there. Their times agree except on 11 trips and 70 stations,
all dated before 1990 (years 6, 202, 630, 1923: typos), where Java and R read historic calendars and local mean time
differently. The April `_overview_views.parquet` went to the Trash; the overview now lists views by `type`.

## The reruns, 2026-10-15

- **adb** (`dba939f`): 31 written, `fishing_station` failed again; no NUMBER column is text, and `catch` is typed as in
  April column for column. `convert.R`, run on it into scratch, matches `staging/adb`'s types with the counts above.
- **stk**: only `year=2026` was fetched (20,618,281 fixes, ids unique, last received 08:45). All 20 partitions now
  share one schema, `.id` and `mid` double.
- **Neither shows in `tar_outdated()`.** The `adb` and `ais_ping_union` targets do not declare their raw files, so
  a rebuild that should take up the new dumps invalidates them by hand (`tar_invalidate(c(adb, ais_ping_union))`).
  The vessel dump does show, through plan 016's file targets.

## Found on the way

- **STK `year=2026`, dumped 2026-10-15, holds `.id` and `mid` as text**; 2007-2025 hold doubles. The pipeline reads
  them right only because DuckDB takes the schema from the first file and casts the rest. `stk.R` now casts after
  collecting, and since 2026 is the current year its next run rewrites the partition. The same cause as adb's text
  ids: the old script cast with `as.integer()` inside the Oracle query. Its times are right: on 2026-03-01, 21,511 fixes
  match `staging/ais/ping_union` (built from the April dump) to the second.
- **`stk.R` refetches a year that does not reach 31 December**, instead of a first year edited by hand: every year
  2007-2025 holds a record from the last minute of 31 December.
- **`raw/ais/stk/einarhj_mobile-vid.parquet`, rewritten 2026-10-15, holds `t1`, `t2` and `datel` as text.** It is an
  input of the frozen `once` project only, and `ais_key_cascade` takes only `mid` and `vid` from it.

## Not done

The other scripts have not run against Oracle yet; the maintainer runs them through 2026-10-15. `dump/oracle/landings.R` is not a dump (it transforms, writes
`staging/` and uses arrow) and was left as it is.
