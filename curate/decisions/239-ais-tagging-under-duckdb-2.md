# 239 — The AIS tagging under DuckDB 2.0: the memory was ramb's port flag, not 2.0; the area layers moved to the datacall

*2026-10-28. Plan 049, executed the day it was written, its four asks answered as recommended ("Yes, as recommended").
The maintainer: "get rid of eusm and gebco in the code flow — that will be handled in the ices datacall section
downstream", "ices areas is definitively a ices data-call thing", and "i just can not believe that 2.0 is really the
problem here". Run and written by Claude (AI); every number comes from its runs, and no person has checked them.
Working files, each with the command that reruns it: `$FISHYDATA/archive/2026-10-28-duckdb2/` (`tag_form.R`,
`tag_form.sh`, `tag_form_rep.sh`, `form_hash.R`, `check_port_call.R`, their logs, `form_hash.csv`). Amended through
the night of 2026-10-28/29: the resume's stop at `port_call` and its cause, the rebuild finished, and 2.0 against
1.5.6, all run unattended on the maintainer's word.*

## What was found

**2.0 was not the problem; the query was.** `curate/ais_ping_tag.R` ran three ways on the three years that had
stopped or hung the rebuild (§ The tests): today's query (A), the same without the area join (B), and ramb's port flag
rewritten without windows (C). Each ran under DuckDB 2.0.0 and 1.5.6, at DuckDB's defaults and at decision 235's cap,
in a fresh process. Every run gave the same ports, to the row:

- **The engines are alike.** Within each form and setting, 2.0 took about the time and memory 1.5.6 took.
- **The area join costs little.** B against A: about the same memory, and up to a fifth less time.
- **The memory was the port flag's two windows.** `ramb::rb_flag_ping_port()` numbered every ping and kept one port per
  ping by a window over every column of a year. A and B took 15 GB at the cap and 20-23 GB of the machine's 24 at the
  defaults, under either engine. So a year ran near the edge on 1.5.6 too, and 2.0's estimate of a partition filter
  (decision 235) was enough to push it over.
- **Without the windows it is light.** C joins each distinct position to the port polygons once and the pings back on
  the position. It took 3-15 s and 0.9-4.0 GB where A took 29-132 s and 15-23 GB.

**The hang.** Its stack (decision 235's sample) is that of DuckDB issue
[#26720](https://github.com/duckdb/duckdb/issues/26720): a window function written by `COPY` under a memory limit,
with workers idle and the client waiting. That issue was reproduced on 1.5.5 and 1.5.6 as well as a 2.0 build, and
its fix was merged into the 2.0 branch on 2026-10-14 ([#27059](https://github.com/duckdb/duckdb/pull/27059)). Here
the hang did not come back in 34 runs of A and B, 22 of them the very case that hung, under either engine. It is a
rare race that needs the windows and the memory pressure, and form C has neither.

**duckdbfs was not bypassed.** The scripts connect, read and write through it, and ramb builds its SQL on that same
connection. Our only additions are a spill folder that exists (`configure_duckdb_temp()`) and, until this record,
decision 235's cap.

**DuckDB 2.0 offered nothing that would have carried the old query.** Its notes name no change to spilling, windows
or spatial joins. 2.0 estimates a filter on a hive partition column at about 1 row under every option tried:
`hive_types` as BIGINT or INTEGER, `hive_types_autocast = false`, a cast literal, `IN` and `BETWEEN`. With no filter
it estimates `ping_union` at 60,138,100 rows against 589,267,384. Reading the partition's own folder is the only cure
found.

## The tests

One run each, in a fresh process (`tag_form.sh`), with the cap (14 GB, 4 threads, no insertion order) / at DuckDB's
defaults. Seconds and peak memory (`/usr/bin/time -l`):

| year | pings | with a port | engine | A: today's | B: no area join | C: no windows |
|---|---|---|---|---|---|---|
| 2015 | 36,791,290 | 16,857,368 | 1.5.6 | 36 s 14.9 GB / 29 s 20.5 GB | 30 s 15.1 GB / 27 s 20.3 GB | 5 s 0.9 GB / 3 s 2.4 GB |
| | | | 2.0.0 | 37 s 15.0 GB / 35 s 20.5 GB | 32 s 15.3 GB / 29 s 20.7 GB | 7 s 1.3 GB / 5 s 3.0 GB |
| 2017 | 72,447,344 | 46,092,669 | 1.5.6 | 95 s 15.6 GB / 131 s 22.1 GB | 93 s 15.5 GB / 144 s 21.6 GB | 11 s 1.7 GB / 6 s 3.1 GB |
| | | | 2.0.0 | 105 s 15.9 GB / 132 s 23.1 GB | 97 s 15.7 GB / 124 s 22.8 GB | 15 s 2.1 GB / 10 s 4.0 GB |
| 2020 | 44,804,818 | 26,271,790 | 1.5.6 | 58 s 15.0 GB / 66 s 21.7 GB | 47 s 15.0 GB / 61 s 21.4 GB | 6 s 1.0 GB / 3 s 2.5 GB |
| | | | 2.0.0 | 55 s 15.1 GB / 68 s 21.8 GB | 49 s 15.1 GB / 53 s 21.8 GB | 8 s 1.4 GB / 5 s 3.1 GB |

**Repeated** (`tag_form_rep.sh`, `tag_form_summary.R` and its log):

- **Form C, three more runs of each cell.** The medians of four runs:
  - at the defaults, 3-6 s under 1.5.6 and 5-10 s under 2.0;
  - at the cap, 5-11 s and 7-14 s;
  - peaks 0.9-3.1 GB under 1.5.6 and 1.3-4.1 GB under 2.0.

  So 2.0 is 1.3-1.7 times slower than 1.5.6 on this light query, by a few seconds a year.
- **Against form A.** A over C, by the medians: 5.3-22 times the time and 5.6-15.7 times the memory.
- **The hang probe.** Form A on 2020 at the cap, the case that hung, ten more runs under each engine: 22 runs with the
  first. None hung (median 56 s under 1.5.6 and 58 s under 2.0, 15.2-15.3 GB), so the hang is rare.

**The output is the same.** Each output was hashed under 2.0 (`form_hash.R`):

- its rows;
- its pings with a port;
- an order-free hash of every row over the port flag's columns, which ties each port to its ping.

All 92 outputs of a year agree on all three, whatever the form, engine, setting or run.

## What changed

- **ramb 2026.10.28.3** (`rb_flag_ping_port()`): form C. Same arguments, same output, and a test that adds two polygons
  of one area, a shared position and a missing one.
- **`curate/ais_ping_tag.R`:** the port flag alone. Decision 235's cap is gone, and the year's folder read stays.
- **`curate/ais_ping_clean.R`:** no longer carries `h3`, `depth`, `bbht` and `fao`. No later step read them;
  `curated/ais/ping` never held them.
- **`curate/port_call.R`:** reads the years' own folders. It filtered `ping_clean` on the year and then joined, and 2.0
  estimated that filter at about 1 row in 2020 and 2026, so the event join would have been built on three years of
  pings. `check_port_call.R` finds the same rows and the same order-free hash, old against new, for 2007, 2020 and
  2026, with the new estimates near the truth. No other script of the 16 targets after `ais_ping_tag` joins after a
  filter on a hive partition: `R/trail_sql.R` and `ais_catch.R` already read the years' folders. `ais_ping_clean.R`
  and `ais_voyage.R` follow the filter with `vid %in%` a batch of vessels; 2.0 makes that a mark join built on the
  list (EXPLAIN, 5 to 1,500 vessels), whatever the pings' estimate.
- **The estimate is not always 1 row.** On `ping_clean` (several files a year) through duckdbfs, 2019's filter was
  estimated at 74,907,378 rows; on `ping_union` (one file a year) and in `port_call.R`'s glob for 2020 and 2026, at
  about 1. A folder read is exact either way.
- **The graph:** `shapes_raw` and `area_h3` are gone.
  - `shapes` writes the port polygons alone, cropped to the buffered ICES areas' box as it last built (10,062 ports,
    each geometry and attribute the same as before).
  - `depth_h3` (`reference/geo/depth_h3.R`, from a new file target `gebco_raster`) is `h3_index.R`'s GEBCO part
    unchanged. `afli_depth_units` alone reads it.
- **The datacall's own** (`products/ices_vms_datacall/`, not wired): `shapes_raw.R`, `area_layers.R` (the ICES areas,
  EUSM and GEBCO parts of the old `shapes.R`) and `area_h3.R` (the old `h3_index.R`), all by `git mv`. Plan 015's
  habitat, depth and area point there.
- **The files under `$FISHYDATA` stay:** `staging/aux/` and `aux_valid/`, and `curated/reference/area_h3.parquet`.
  `products/exports/astd_iseez.R` still reads some of them.

The geo targets that left took 22 minutes of today's build (`tar_meta()`).

## The resume: `port_call` runs away under 2.0, now and then

The resume (`resume.sh`, `build_resume_3.log`) built 21 of its 36 targets, `ais_ping_tag` included. It then stopped
at `port_call` 2018, which wrote 74.4 GiB of spill in about 75 seconds, to DuckDB's default limit of 90 % of the free
disk. DuckDB removed the spill when the query failed.

**The other targets.** `ais_ping_clean` kept and flagged the same pings as on 2026-10-23, to the ping (580,639,236
kept, 8,552,088 flagged in the same classes). It took 45 minutes against 19.6 then; that is not explained.

**Diagnosed alone** (`run_port_call.sh`, `replay_port_call.sh`, `explain_repeat.R`, their logs):

- **The year alone passes.** 2018 by itself under 2.0 ran in 29 s at 9.8 GB, with the 88,183 port calls of
  2026-10-23. The query as it was before this record took 87 s and 19.9 GB under 2.0.
- **So does the whole run.** 2007-2018 in one session, as the target runs them, passed under 2.0.
- **But not every time.** 2017-2018, the first two years that use STK's events, five times in fresh processes under
  2.0 with the spill capped at 20 GB: one run filled the cap in 2017 within 14 s, the other four ran in 31 s.
- **1.5.6 does not.** The same replay eight times under 1.5.6: all eight in 31-32 s at about 10 GB.
- **The plan is the same.** 2.0 planned the query the same way in 11 EXPLAINs across four sessions. The runaway is in
  execution: the same plan, data and query that pass in 30 s now and then grow without bound.

So this stop is DuckDB 2.0's own, unlike the tagging's: 2 of 8 runs under 2.0, none of 8 under 1.5.6.

**The operator, found the same night** (the maintainer: "Dig into 2.0 first"; `pc_stage.R`, `replay_sampled3.sh`,
`replay_sampled_logs/t1.sample.txt`, `check_ev_semi.R`):

- **The spill is real**, and fast: about 2 GB a second to the cap.
- **Its source.** A stack sample taken while it grew shows a hash aggregate fed by a Parquet scan, evicting to
  temporary files. In this query that is the events input's `SELECT DISTINCT vid, time` over three years of
  `ping_clean` (165 million groups).
- **Alone it is fine.** That DISTINCT ran in under a second even at a 1 GB limit, 15 times in 15. So did the events
  input and the pings input. It runs away only inside the whole query, beside its windows and spatial join.
- **The fix in `port_call.R`.** The pings are narrowed to the events' (vid, time) by a semi join before the DISTINCT.
  The events input is the same in rows, good flags and hash for 2017, 2018 and 2026 under both engines, and three
  times faster. The full replay then passed 15 times in 15 under 2.0, with no spill and the same port calls; it had
  run away in 5 of 21 runs before.
- **Settings are no cure.** On synthetic data (`synth/`, no MFRI data in it), the old query ran away under 2.0 in:
  - 1 of 18 runs at the defaults;
  - 5 of 10 with 4 threads;
  - 1 of 10 without insertion order.

  Under 1.5.6, none of 10.
- **To DuckDB.** That reprex, and one for the partition estimate (2.0: about 1 row; 1.5.6: the partition's
  55,000,000), are drafted in `curate/issues/duckdb.yml`, not sent.

## The night of 2026-10-28: the rebuild finished under 2.0, and 2.0 against 1.5.6

The maintainer: "Yes, resume under 2.0", then to test 2.0 against 1.5.6 for speed, memory and robustness, with smaller
machines in mind, to decide "if we should jump to duckdb 2.0 now, or wait a little bit longer". Run unattended
(`night.sh`, `build_resume_4.log`, `compare_before_after.log`, `bench_small.sh` and its log).

**The rebuild finished.** `port_call` and the 14 targets after it were built under 2.0 from 22:36 to 23:57 UTC with
no stop. The fingerprint after was compared with the one taken at 13:33, before the rebuild began: every one of
8,086 files is in one outcome, and every outcome is explained.

- **The same: 7,717.**
- **Rows or schema changed: 151.**
  - `ping_tagged` and `ping_clean` dropped their four area columns, as planned; their rows are unchanged.
  - Two years of `ping_union` and `ping_tagged` typed three all-empty columns as `"NULL"` (decision 235, change 3;
    `ais_ping_union.R` writes a bare NA).
  - Two catch files lost 3 rows, and one check gained 2.
- **Values moved, rows and schema the same: 210.** Mostly the trail's `gid_voyage` (123 files) and the catch's `kg`
  (80). These are TODO 139's ties: `voyage_gear` takes each voyage's gear by `arg_max(gid, n)`. Run four times,
  that query gave four different `gid_voyage` hashes under 1.5.6, and the same four times under 2.0, equal to the
  night's file. The 13:33 store was 1.5.6's.
- **Two `ping_clean` files** had all their columns move: their rows changed files within the year, and every year
  sums to the same hashes.
- **Rewritten, only before, only after.** The md5 of 5 GeoPackages changed: they were rewritten. The 2 files only
  before are the `.fgb` area layers, still on disk but no longer targets. The 1 only after is `depth_h3`.

Rows went from 8,842,597,453 to 8,868,758,417; the difference is `depth_h3`'s 26,160,965 cells.

**Target times against 2026-10-23 (1.5.6):**

| target | 2.0 | 1.5.6 |
|---|---|---|
| `ais_trail` | 27 min 38 s | 31 min 20 s |
| `port_call` | 5 min 27 s | 5 min 45 s |
| `ais_voyage` | 28 min 22 s | 14 min 36 s |
| `ais_ping_clean` | 45 min 25 s | 19 min 39 s |

The rest were within a second or two either way.

**The small-machine battery.** Three rounds of four tests, under each engine, at this Mac's defaults (14 threads, 19
GiB) and at 4 GB and 4 threads, each in a fresh process (`bench_small.log`). Medians, wall time and peak, 2.0 against
1.5.6:

| test | defaults: 2.0 | defaults: 1.5.6 | 4 GB, 4 threads: 2.0 | 4 GB, 4 threads: 1.5.6 |
|---|---|---|---|---|
| `port_call` 2017-2018 | 72 s, 10.1 GB | 72 s, 8.1 GB | 85 s, 4.8 GB | 85 s, 4.7 GB |
| tagging 2017, form C | 13 s, 4.2 GB | 9 s, 3.0 GB | 16 s, 2.1 GB | 12 s, 1.7 GB |
| `ais_ping_clean`'s batch reads 2017 | 36 s, 1.6 GB | 12 s, 1.7 GB | 36 s, 1.6 GB | 18 s, 1.7 GB |

Every run passed, but one of the old-query reprexes under 2.0 at the defaults.

**The batch reads: a third regression in 2.0, found the same night** (`explain_inlist.R`, `cleanbatch2.R`,
`synth/prune_reprex2.R`).

- **Two causes.** `ais_ping_clean` and `ais_voyage` read each year through `duckdbfs::open_dataset()`, a view, with
  `filter(year == yr)`. duckdbfs returns the years as doubles, so dbplyr writes `year = 2017.0`.
  - Through a view, 2.0 does not prune the other years' files on a DOUBLE literal: one batch scanned 489,361,252
    rows of `ping_tagged` where 1.5.6 scanned the year's 72,369,236. The synthetic data does the same (3 files read
    against 1); straight on `read_parquet` both engines prune.
  - The year's 15 batches took 195 s under 2.0 with the double and 34 s with an integer, against 11.4 s under
    1.5.6 with either.
- **The rest is slower anyway.** The remaining factor of three, at the integer, is not in DuckDB's execution: one
  batch ran in 0.095 s under 2.0 and 0.111 s under 1.5.6. It is in handing the rows to R, not measured further.

**What 2.0.0 costs and gives.**

- **Robustness: three regressions**, each worked around in our code (the third only on 2026-10-29, below):
  - the spill runaway in a hash aggregate (worse with fewer threads: 5 of 10 runs at 4 threads);
  - a filter on a partition estimated at 1 row;
  - no partition pruning through a view on a DOUBLE literal.
- **Speed.** Light queries and results handed to R are 1.3 to 3 times slower. The large trail query is 12 % faster.
- **Memory.** Peaks are up to 40 % higher at the defaults, and about the same at 4 GB.
- **Determinism.** It gave the same result on `voyage_gear`'s ties, where 1.5.6 did not. That is a defect of the
  query (TODO 139), not something to rely on.
- **The parser** takes `column` as a keyword, so a column of that name must be quoted.

## 2026-10-29: R's default back to 1.5.6 until 2.0.1

The maintainer, the morning after: "Switch R's default DuckDB back to 1.5.6 until 2.0.1, 2) set year to integer", and
"what about read_parquet vs open_dataset?". Done by Claude the same morning.

- **The engine.** R's library holds CRAN's 1.5.6 binary again, copied from `~/Library/R/duckdb-1.5.6`. The build of
  2.0.0 from source is kept at `~/Library/R/duckdb-2.0.0`, the same `duckdb.so` as was in R's library. The store is
  kept as built under 2.0.0. 1.5.6 reads all of it (`fingerprint_after_v156`, `compare_after_v200_v156.log`): 8,084
  files and 8,868,758,417 rows. 8,080 files are the same under both engines. The other 4 are `ping_union` and
  `ping_tagged` in the two years whose `dt_sec`, `sid_gps` and `n_sid_gps` are all empty. 2.0 wrote those columns as
  type `"NULL"` (decision 235, change 3), and 1.5.6 reads them as INTEGER, the type every other year has.
- **Years as integers** in `curate/ais_ping_clean.R` and `curate/ais_voyage.R`, as `curate/ais_ping_tag.R` already
  had them. The filter keeps the same rows. Otherwise the year is used only in paths, messages and `match()`, and
  `ais_ping_clean`'s completion markers do not hash it, so nothing is to be rebuilt. `curate/logbook_sensor_gps.R`
  also filters the pings through a view on a double year. It is a frozen one-time fix, so it is left as it is.
- **`read_parquet()` or `open_dataset()`: neither is the cause.** duckdbfs's `open_dataset()` makes a view over
  `read_parquet()`, and a view costs nothing in itself.
  - The 1-row estimate comes with `read_parquet()` too. So a query that joins reads the year's folder, whichever
    function reads it.
  - The lost pruning comes only through the view and only with a DOUBLE year. So an integer year is the fix, and
    `open_dataset()` stays (duckdbfs for parquet I/O, `AGENTS.md`).
  - `read_parquet()` stays where a script writes its SQL by hand (`curate/port_call.R`).
- **The user tables and the effort map rebuilt on the store of 2026-10-28**, under 1.5.6 (the maintainer: "Yes,
  rerun both"). These were `products/user_tables.R` (6 s), the effort map's `grid.R` (244 s) and `grid.R fixes` (64 s).
  Both grid runs peaked at 23 GB of this Mac's 24. Each was summarised before and after (`v0_rerun.R`,
  `v0_rerun_compare.log`):
  - v0's `station` and `catch` are the same. `trip` has the same rows, with only `T2` moved. This is TODO 139's STK
    tie, inherited from `trip_reconciled`'s `T2` and `T2_stk`, which moved in the rebuild: 36 trips have two
    latest-starting STK voyages that disagree on the return, counted again today.
  - Each of the four grids holds the same hours under `fishing`, in every gear and year. Under `fishing_flow`, 66
    of each grid's 731 preset-gear-years changed. 194 of 11,606,380 hours moved between gears, and no year's total
    moved by more than 1.1 hours. This is TODO 139's `voyage_gear` tie: `fishing_flow` takes the voyage's gear and
    its speed range outside a haul's window. `grid.R`'s own check holds: the grid's hours, kW-hours and fixes are the
    trail's.

## Not done

- **2.0.1 against 1.5.6** (due 2026-11-18): `bench_small.sh` and the reprexes again, then which engine builds
  (TODO 150).
- **A cast of `ais_ping_union.R`'s bare NAs** (decision 235, change 3).
- **The three DuckDB drafts** (`curate/issues/duckdb.yml`): whether and how to send them is the maintainer's call.
