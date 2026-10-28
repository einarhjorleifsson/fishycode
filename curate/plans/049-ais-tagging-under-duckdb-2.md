# 049 — The AIS tagging under DuckDB 2.0: EUSM, GEBCO and the ICES areas out of the flow, a port flag without windows, and tests before the rebuild resumes

**status:** partly built — written 2026-10-28 at the maintainer's request, after the rebuild under DuckDB 2.0 (TODO
150) hung in `ais_ping_tag` at year 2020; the four asks answered the same day, each as recommended (§5); steps 1-3 and
5 done the same day (decision 239), step 4, the rebuild, is TODO 150 · **measured** (§1), by Claude the
same day: the readers of the area columns by search, the targets' times from `tar_meta()`, the stack sample of the
hang, DuckDB's release notes and issues, duckdbfs's code; the memory and plans of decision 235 · **assumed** (§2): that
the port flag can drop its windows and give every ping the same port, and that without them and the area join the
year's query stays clear of both stops · **see:** decision 235, TODO 150, plan 015 (the datacall), decision 218,
`$FISHYDATA/archive/2026-10-28-duckdb2/`

Drafted with AI assistance (Claude) on 2026-10-28; a person has not yet checked it.

The maintainer, 2026-10-28: "get rid of eusm and gebco in the code flow — that will be handled in the ices datacall
section downstream"; "ices areas is definitively a ices data-call thing"; "run some tests on alternative way to
rebuild — focus on the biggest hurdles stumbled on using duckdb 2.0. my hunch is that we may not be using the latest
feature. another possibility is that we now have by-passed duckdbfs. … i just can not believe that 2.0 is really the
problem here."

## 1. What is measured

**Where the area columns go.** `curate/ais_ping_tag.R` puts the port (`pid`, `hid`) and, from
`curated/reference/area_h3.parquet`, the H3 cell's `h3`, GEBCO `depth`, EUSM habitat `bbht` and ICES area `fao` on
every ping. `curate/ais_ping_clean.R` carries the four into `staging/ais/ping_clean` and `ping_whacky`;
`curated/ais/ping` and `curated/ais/trail` hold none of them. No other script of the flow reads them. Outside it:

- plan 015 (the datacall) takes habitat, depth and the ICES area from `ping_tagged`, joined on (vid, time);
- `products/exports/astd_iseez.R` reads the layers (`staging/aux/eusm.fgb`, `gebco.gpkg`,
  `aux_valid/ices_areas.gpkg`);
- `curate/corrections/afli_depth_units.R` reads `area_h3`'s `depth` alone, at each logbook station's cell (fathoms
  or metres);
- `curate/place_name.R` reads the GEBCO raster itself.

`shapes.R` also writes the port polygons (`staging/aux/ports.fgb`, read by `ais_ping_tag` and `stk_hid_pid`), cropped
to the bounding box of the buffered ICES areas.

**What the area layers cost.** In today's build under 2.0 (`tar_meta()`), `shapes_raw` took 643 s, `shapes` 252 s and
`area_h3` 424 s: 22 minutes of a complete rebuild. The area join's share of `ais_ping_tag` is not measured.

**The two stops in `ais_ping_tag` under 2.0** (decision 235).

1. **Out of memory at 2015.** 2.0 estimates a filter on the partition column at about 1 row and builds the spatial
   join on the pings. It is fixed by reading the year's own folder.
2. **A hang at 2020** under decision 235's settings (14 GB, 4 threads, no insertion order), from about 17:16 UTC to
   the kill at 18:26. The stack sample (`hang_sample_ais_ping_tag_2020.txt`) has 60 worker frames idle in
   `TaskScheduler::ExecuteForever` and the client in `Executor::WaitForTask`, with a partitioned hash join in it.

**The hang has a known family.** DuckDB issue [#26720](https://github.com/duckdb/duckdb/issues/26720): a window
function written by `CREATE TABLE AS` or `COPY` under a memory limit sometimes hangs forever, with the same two stack
frames. It was reproduced on 1.5.5, 1.5.6 and a 2.0 development build, and was not seen with a 12 GB limit or with
`ORDER BY` in place of the window. Its fix (#26778, "do not miss an unblock between TryNextTask and BlockSource") was
merged on 2026-10-14 in [#27059](https://github.com/duckdb/duckdb/pull/27059), which is labelled v2.0.0. 2.0.0 still
hung here with the same signature. Whether ours is #26720 or a sibling (a spilled join, the new asynchronous writes)
is not known. Either way it is not 2.0's alone, and the memory pressure that brings it is ours.

**What makes the query heavy is ours.** `ramb::rb_flag_ping_port()` numbers every row (`row_number() OVER ()`). It
joins the ports with `ST_Intersects`, then keeps one port per ping with a second window, partitioned by that number,
over every column of a year (36.8 million rows in 2015). The windows alone took 15.4 GB under 2.0 against 7.5 GB under
1.5.6. The whole query, with the area join, peaked at 20.3 GB of the machine's 24 under 1.5.6 at its default limit.
A ping's port depends on its position alone, so neither window is needed for the answer.

**duckdbfs is not bypassed.** The scripts connect, read and write through it:

- `cached_connection()`;
- `open_dataset()`, a view over `read_parquet(…, hive_partitioning = true)`;
- `write_dataset()`, `COPY … (PARTITION_BY …)`.

ramb builds its SQL on that same connection. On top come our own settings: `configure_duckdb_temp()` (duckdbfs's
default temporary folder, `tempfile()`, is never created) and decision 235's cap. duckdbfs 0.1.2 is CRAN's newest.

**What 2.0 brings.** The release notes and the migration guide name no change to spilling, windows or spatial joins.
What is new and near this query:

- asynchronous I/O for reading and writing parquet, with no setting in the notes to turn it off;
- the window-hang fix;
- `UNION ALL` branches run in parallel when `preserve_insertion_order` is false;
- more statistics from parquet.

So no 2.0 feature is left unused here that would carry this query. The remedy is in the query.

## 2. What is assumed

- Form C below gives every ping the port today's function gives it: the smallest polygon holding the position, then
  the lowest `port_id`; none for a missing position.
- Without the windows and the area join, a year's query stays well below the machine's memory under both engines,
  and so away from both stops.
- Four other scripts filter on the partition column (`ais_ping_clean.R`, `ais_voyage.R`, `port_call.R`,
  `R/trail_sql.R`), so 2.0's estimate may flip a join there too. Of the 16 targets after `ais_ping_tag`, none has
  run under 2.0 yet.

## 3. The steps

1. **EUSM, GEBCO and the ICES areas out of the flow.**
   - **`ais_ping_tag`:** the area join goes, and `ping_tagged` is the union plus `pid` and `hid`.
   - **`ais_ping_clean`:** its select drops `h3`, `depth`, `bbht` and `fao`.
   - **The graph:** `shapes_raw` and `area_h3` leave `_targets.R` and `R/check_ready.R`.
   - **`shapes`:** it keeps the ports alone, cropped to the raw ICES layer's box widened by 500 m. Check:
     `ports.fgb` holds the same ports and geometries as today's.
   - **The moved scripts:** `shapes_raw.R`, the ICES and EUSM parts of `shapes.R`, and `h3_index.R`'s EUSM and ICES
     parts go by `git mv` to the datacall (ask b). They are not wired, and a header says so. There plan 015 tags
     only its fishing fixes, about 106 million against 589 million pings, and plan 015's rows on habitat, depth and
     area point there.
   - **GEBCO for the depth correction (ask a):** recommended, a depth-only cell table for that correction alone.
     Check: the correction's output is the same.
   - **Nothing is deleted from `$FISHYDATA`.** `astd_iseez.R` still finds its layers.
2. **Tests on the hard years**, to a scratch folder, each run in a fresh process under `/usr/bin/time -l`, the
   scripts beside their logs in the archive folder:
   - **The grid.** Three years: 2020 (it hung), 2017 (the largest) and 2015 (the first stop). Two engines: 2.0.0 and
     1.5.6. Two settings: duckdbfs as it is, with no cap and every thread, and decision 235's cap.
   - **Three forms of the query:**
     - A: today's, the port flag with the area join;
     - B: the port flag alone, as after step 1;
     - C: the port flag without windows. The positions are taken distinct and joined to the ports by
       `ST_Intersects`. `arg_min()` picks the smallest polygon for each position, and the result is joined back on
       (lon, lat).
   - **What each run reports:** wall time and peak memory. A run with no progress for 10 minutes counts as a hang:
     sampled, killed, its spill removed.
   - **The check:** the output is the same across forms, in rows and in every shared column's order-free hash.
   - **The timings:** three repeats per engine of the form chosen.
   - **The 16 targets after `ais_ping_tag`, by `EXPLAIN` only and under 2.0:** the heavy queries of `port_call`,
     `ais_voyage`, `R/trail_sql.R`, `ais_catch` and `station_event`, each on one year, to find any join that the
     1-row estimate turns. The same `EXPLAIN` checks whether `hive_types` changes the estimate. A turned join is fixed
     as in decision 235 before the rebuild resumes.
3. **Form C into ramb**, if it is the same and lighter (ask c): `rb_flag_ping_port()` keeps its arguments and its
   output. It gets a test with two nested polygons, a version and news. ramb's tests run under both engines, then it
   is pushed and installed from GitHub.
4. **The rebuild resumed** (ask d): `ais_ping_tag` and the 16 targets after it, by `resume.sh` with the tree clean,
   then the fingerprint after and the comparison. `ping_tagged` and `ping_clean` lose four columns, and the comparison
   explains that. A target that stops is diagnosed alone before the next resume.
5. **The record:**
   - a decision with step 2's numbers and the move;
   - decision 235 amended with the hang;
   - TODO 150 and plan 015 updated;
   - `AGENTS.md`'s DuckDB 2.0 line, if a rule comes out of step 2.

## 4. What it changes

- **Time:** 22 minutes of geo targets leave a complete rebuild. The area join's share of `ais_ping_tag` is measured
  in step 2.
- **Data:** `staging/ais/ping_tagged` and `ping_clean` lose `h3`, `depth`, `bbht` and `fao`. No later step reads
  them.
- **Plan 048:** it also rebuilds the AIS chain from the union down. This plan goes first, since TODO 150 waits on it,
  and plan 048's rebuild then starts from a chain that runs under 2.0.

## 5. Asks

Answered by the maintainer on 2026-10-28, each as recommended: "Yes, as recommended".

- **a. GEBCO for `afli_depth_units`.** Recommended: a depth-only cell table, `h3_index.R`'s GEBCO part unchanged,
  renamed to `reference/geo/depth_h3.R` and writing `curated/reference/depth_h3.parquet`, read by the correction
  alone. Two alternatives:
  - read the raster at each station, which changes the values the correction tests;
  - move the correction's depth test out as well.
- **b. Where the area scripts go.** Recommended: `products/ices_vms_datacall/`, unwired, for plan 015. Alternative:
  they stay in `reference/geo/`, unwired.
- **c. ramb's port flag rewritten** as form C, if step 2 shows it is the same and lighter. Recommended: yes.
- **d. After step 2.** Recommended: resume the rebuild under 2.0 if form C passes every year under both settings.
  Otherwise, finish the 17 targets under 1.5.6 and take 2.0 up again at 2.0.1 (2026-11-18).
