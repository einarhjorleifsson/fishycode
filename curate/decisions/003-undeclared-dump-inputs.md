# 003 — The graph has undeclared inputs in `dump/`, and empty directories hid it

*Recorded 2026-09-20, while running the four-layer trail rebuild for the first time.*

## What happened

The first attempt at the L1→L4 rebuild failed in under a second, at the root target:

```
!! FAILED: subscript out of bounds
---------- L1_union FAILED in 0.0 min ----------
```

`curate/ais_ping_union.R` reads `staging/ais/astd` and `staging/ais/astdB`. Both
directories existed and both were empty. The scripts that fill them —
`dump/ais/astd.R` (155 ZIPs, 118 GB) and `dump/ais/astd_b.R` (one 17.9 GB ZIP) — live in
`dump/`, which sits outside the `targets` graph by design. `grep astd _targets.R` returns
nothing.

So the DAG's root target depends on two steps the DAG does not know about, and neither had
ever been run in this repo.

## Two defects this exposed

**1. `.fd_writable()` makes "never built" indistinguishable from "built and empty".**
`fd_staging("ais", "astd")` creates the directory as a side effect of resolving the path.
Every AIS stage was therefore a 0-byte directory that `dir.exists()` reported as `TRUE`.
`R/check_ready.R` was fooled by this, as was I: an earlier check in this same session
reported `ping dir exists: TRUE` for a directory that had never been written to.

This is the third time a verification script in this repo has reported "ready" or "clean"
about something that was not (see the `check_paths.R` and `check_ready.R` widenings). The
pattern is consistent: the checks test for the *shape* of a thing rather than its
*substance*.

**2. `duckdbfs::open_dataset()` on an empty directory raises `subscript out of bounds`.**
No path, no hint. It is the same error as a genuinely absent directory, which is why the
first diagnosis was wrong.

## The boundary question

`dump/` is outside the graph because extraction needs Oracle credentials or server access,
and cannot be reproduced on a laptop. That reasoning does not extend to the ASTD decode:
it is a deterministic local conversion of files that already sit under `$FISHYDATA/raw/`,
reproducible by anyone holding the raw delivery. By the plan's own definition it is
*decoding*, which is adapter work, not extraction.

**Provisional position, not yet acted on:** the ASTD decode belongs in the graph, as a
staging target, for the same reason every other decode does — because the thing that broke
here is precisely that nothing tracked it. Deferred rather than done, because the rebuild
in flight needs finishing first and this is a structural change, not a fix.

## What was done now

Nothing structural. The rebuild driver simply runs the two decode steps ahead of the chain:

```
dump/ais/astd.R -> dump/ais/astd_b.R -> L1 union -> tag -> L2 clean -> voyages -> L3 logger -> L4 link
```

## Suggested follow-ups

- Make `fd_*` path helpers stop creating directories on read, or have `check_ready.R` test
  for non-empty rather than existent. The current behaviour actively manufactures the
  false positive.
- Declare the ASTD decode in `_targets.R`, or state in `AGENTS.md` that `staging/ais/astd`
  and `staging/ais/astdB` are hand-run prerequisites. Either is defensible; the present
  state, where it is neither, is not.

---

## Addendum, 2026-09-21 — what first execution actually found

`dump/ais/astd.R` ran clean: **2,769,131,193 rows**, 2013–2026, 124 GB, in 25.5 min.

`dump/ais/astd_b.R` failed in 30 seconds, and had **three** independent faults. It had
never run anywhere — there is no `astdB` output in `fishydata_2024-2026` either, and the
same broken lines sit in that repo's `scripts/00_DATASET_ais_astdB_zip-to-parquet.R`.

1. `filter_out(file, str_detect("date_utc=2019-02-12"))` split `str_detect`'s two
   arguments across the call. `dplyr::filter_out()` (new in dplyr 1.2.1) then received a
   character vector as a condition: ``​`..1` must be a logical vector``.
2. `year`/`month` were extracted with `str_extract` as **character** (`"01"`) and compared
   against integer `m` in `filter(year == y, month == m)`. `"01" == 1` is `FALSE`, so every
   group would have been empty even after fault 1 was fixed. Two bugs stacked such that
   fixing only the visible one yields a script that runs to completion and writes nothing.
3. `col_types` named a column `cod`, which does not exist. The feed has `cog`, and `speed`,
   which `col_types` omitted entirely. Both are required by `ais_ping_union.R`.

Fault 2 is the instructive one: it would have produced a **silent** empty output, which is
exactly the state that caused this whole investigation.

## `write_dataset()` path semantics — measured, not assumed

`duckdbfs::write_dataset(d, path)` without `partitioning` writes a **single file at that
path**, never a directory, and ignores the extension. So the idiom used in
`ais_ping_clean.R`, `ais_trip.R` and `logbook_sensor_gps.R`:

```r
write_dataset(file.path(out, paste0("year=", yr)), format = "parquet")
```

creates a *file named* `year=2013`, not a hive directory. Measured consequences:

| Layout | Reads back? | `year` column? |
|---|---|---|
| file named `year=2014` | yes | **no** — no partition column is derived |
| directory `year=2014/data_0.parquet` | yes | yes |

**This is not currently a bug**, because in all three scripts `year` is also a genuine data
column, so it survives the round trip. But two things follow:

- The comment in `ais_ping_union.R` — *"Partition by year so downstream queries can apply
  partition pruning"* — is true of `ping_union` (which passes `partitioning = "year"`) and
  **false** of the three datasets written with the bare-path idiom. They are not partitioned.
- `astd_b.R` could not use that idiom, because its frame has no `year` column. It writes
  explicit directories with a trailing filename instead.

Left alone rather than "fixed": converting the other three to real partitioning means
dropping `year` from the data first, or the hive column collides with the data column. That
is a change with real risk, and it buys pruning, not correctness. Worth doing deliberately,
not in passing.

## Also confirmed

An in-memory R `POSIXct` written through `duckdbfs::write_dataset` lands as **`TIMESTAMP`**,
not `TIMESTAMPTZ`. The arrow/nanoparquet prohibition does not extend to materialised frames
going through duckdbfs.
