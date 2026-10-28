# 235 — DuckDB 2.0 adopted: R's duckdb 2.0.0 from source, every file read the same, tests passing but one; the rebuild still to run

*2026-10-28. The maintainer: "Using duckdb 2.0 will thus be the future. May as well adopt to it now. It carries
potential risk, but nothing that we have is yet used by other people." Run and written by Claude (AI); every number
comes from its runs, and no person has checked them. Plan 046 §7 had left DuckDB 2.0 for later and said what taking it
up needs: its own change, step 1's tile timings before and after, and the pipeline's fingerprints. Working files, each
with the command that reruns it: `$FISHYDATA/archive/2026-10-28-duckdb2/`. Amended the same day: ramb's one failing
test fixed (ramb `ca57d64`), on the maintainer's go after checking it could run beside another session's job.*

## What was installed

- **CRAN's source, not its binary.** CRAN has held duckdb 2.0.0 as source since DuckDB 2.0.0 LTS was released
  (2026-10-21). Its macOS arm64 binary is still 1.5.6, and r-universe has a development binary (2.0.0.9000). The
  released source was compiled here: C++17, 4.5 minutes with `MAKEFLAGS=-j12`, R's header warnings only. The engine
  reports `v2.0.0`. DuckDB 2.0.1 is scheduled for 2026-11-18; the migration guide suggests waiting for a patch release
  for critical work, which nothing here is.
- **The switch.** First into a side library, `~/Library/R/duckdb-2.0.0`, where everything below was tried while 1.5.6
  stayed the default. Then copied into R's library as the default. 1.5.6 is kept at `~/Library/R/duckdb-1.5.6`;
  copying it back is the rollback. `duckdbfs` 0.1.2 and `duckplyr` 1.2.1 ask for duckdb ≥ 1.1 and ≥ 1.4.4, so neither
  needed a reinstall. ramb's `DESCRIPTION` names duckdb with no version, and it stays so: ramb runs on both.
- **Extensions** for v2.0.0 install as before: spatial and icu from the core repository, h3 from community
  (`~/.duckdb/extensions/v2.0.0/`). R's duckdb links only parquet and core_functions under both engines, so time zones
  load the `icu` extension under both (it was in `v1.5.6/` too).

## What 2.0 changes, tried on what fishycode and ramb use

`smoke.R`, run under each engine (`smoke_v156.log`, `smoke_v200.log`).

**The same under both.**
- `SET TimeZone`, TIMESTAMPTZ to TIMESTAMP, `AT TIME ZONE`, and R's POSIXct both ways.
- spatial's `ST_Point` and `ST_Transform(…, always_xy := true)`.
- h3, and `duckdbfs::load_spatial()`, `load_h3()`, `write_dataset()` partitioned.
- `write_curated()` with its six stamps and plain TIMESTAMP.
- The parquet writer's SNAPPY.
- `hash()` of an integer, a string, a double and a timestamp, to the digit.

**Changed: four things a new script must know.**
1. **Axis order in spatial.** `ST_Distance_Spheroid` (and the other `_Spheroid` functions) stops unless
   `geometry_always_xy` is set. Nothing in fishycode calls them. ramb's `ST_Transform` calls pass
   `always_xy := true`, and its map tests pass. A new script sets `SET geometry_always_xy = true`
   (longitude, latitude), which 2.1 makes the default.
2. **Division by zero.** `//` and `%` by zero now stop ("Use TRY(...)"); `/` still gives Inf. No SQL here divides
   that way by a value that can be zero. The datacall's `%/%` divides by constants, and ramb's `near.R` takes `%` of
   a cell count. Guard the divisor or wrap it in `TRY()`.
3. **A bare NULL has its own type.** `COPY (SELECT 1 AS a, NULL AS b)` writes `b` as type `"NULL"`, where 1.5.6
   wrote INTEGER. nanoparquet still reads it as integer, and DuckDB as `"NULL"`. dbplyr's `mutate(x = NA)` is such a
   NULL. Write `NA_integer_`, `NA_character_` and the like, or `CAST(NULL AS …)`, as ramb already does. The rebuild's
   schema comparison will show any file this reaches.
4. **The single-arrow lambda is off.** `x -> x + 1` stops in the binder; `lambda x: x + 1` works under both. Nothing
   here uses the arrow (plan 046 §7, checked again).

The other changes in the [migration guide](https://duckdb.org/docs/2.0/operations_manual/migration) touch nothing
here. `~` and `!~` now match partially (no SQL here uses them), and `X'…'` literals are now BLOB. The removed
profiling and HTTP-logging settings are not set anywhere. `MERGE INTO` is not used. The storage format of `.duckdb`
database files is one-way (2.0's cannot be opened by 1.5), and none is used: no script opens one, and none is in
`$FISHYDATA` to four levels deep.

## Measured

- **Every file reads the same.** The main project's outputs were fingerprinted under each engine (`fingerprint.R`,
  `compare.R`). All 8,085 files are the same under both: 8,842,597,453 rows, the same schema type names and the same
  order-free hashes per column. So 2.0 reads every file 1.5.6 wrote. Since `hash()` holds across the engines, a
  rebuild's before and after can be fingerprinted under either.
- **fishycode's tests:** 30 tests, 175 expectations, none failing under either engine.
- **ramb's tests** (the installed 2026.10.28.1, `dfd693d`, `test_dir(load_package = "installed")`): 225 tests, 3
  skipped under both. One errors under 2.0 only: "an extension installs offline". It copies the smallest installed
  extension into an extension folder. That is h3, a community extension, and 2.0 refuses its signature
  (`allow_unsigned_extensions`) unless the `.info` file that records its origin is copied with it. A core extension
  (icu) copied alone loads under 2.0, and h3 with its `.info` loads too. 1.5.6 loaded h3 alone. ramb itself loads
  core extensions only (`spatial` and `httpfs`, six calls of `.rb_extension()`), for which its offline route and
  message are right; only the test's pick was wrong. Fixed the same day in ramb `ca57d64` (2026.10.28.2): the test
  copies the smallest core extension (`installed_from = 'core'`), and a comment in `R/connection.R` records 2.0's
  rule. Run from a scratch library: 225 tests, none failing or erroring, 3 skipped, under 2.0.0 and 1.5.6 alike; the
  offline test ran its 8 expectations under both. It ran beside another session's `vessel_bundle.R`, which loads no
  ramb and no extension. Pushed on the maintainer's go and installed from GitHub (`RemoteSha` `ca57d64`).
- **The effort map's tiles** (plan 046 step 1's bench, three interleaved runs per engine in fresh processes,
  `bench_summary.R`):
  - total 302 s under 2.0 against 297 s under 1.5.6 (1.02), and the slowest single run was 2.0's third (334 s);
  - the unfiltered tiles are unchanged (median ratios 0.94-1.05 by zoom and cell size);
  - with the bottom-trawl filter of 2015-2020 they are 1.01-1.29 times slower, 1 to 21 ms a tile at the medians.
  
  The tiles' sizes vary between runs of one engine (1,139 of 1,674 cases took three sizes in three 1.5.6 runs), so
  their sizes across engines say nothing. The vessel overview's server, started by another hand at 11:38, was up
  during the bench.

## Not done

- **The complete rebuild under 2.0** (TODO 150). The data on disk are still 1.5.6's (decision 218). It waits for a
  clean tree: the vessel overview had another session's uncommitted edits when this was written, and
  `write_curated()` would stamp every file built meanwhile as dirty.
- **The vessel overview's server**, started before the switch, still runs on the 1.5.6 library it loaded until it is
  restarted. Its page's DuckDB-WASM is another engine, pinned from jsdelivr, and is untouched.
