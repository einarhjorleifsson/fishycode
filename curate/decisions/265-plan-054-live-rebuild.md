# 265 — Plan 054's live rebuild: 54 targets by name, every difference from the scratch build explained, the trail's effort traced by source, and the key cascade redone by the ancestor rule, kept

*2026-10-30. Plan 054 §8 step 2 (TODO 168). The maintainer's go: "live rebuld? the whole thing, except ais_catch". On
the key cascade, after the trace: "Keep and record". Run, traced and written by Claude (AI); the numbers come from its
runs, and no person has checked them. Everything is in `$FISHYDATA/archive/2026-10-30-plan054-live-rebuild/`.*

## The run

`build.sh` ran at f76e73c with a clean tree, under DuckDB 1.5.6 and ramb 2026.10.28.3, kept awake by `caffeinate`, from
19:34 to 22:20 UTC.

- `before.R` chose the set: every outdated target, plus five whose scripts or called functions had changed where
  `targets` cannot see (`afli`, `afli_sent`, `fs_afladagbok_part`, `gear_window`, `stk`), plus everything downstream of
  them. `ais_catch` and `check_allocation_audit` were left out (decision 261). That came to 54 targets (`names.txt`).
  Before anything was invalidated, it fingerprinted their 698 output files and took the trail's counts per year and
  schema (`trail_before.csv`).
- `tar_make_isolated(names = )` built the 54 with no failure. The long steps were `ais_trail` (64 min), `ais_voyage`
  (45 min), `port_call` (11 min), `afli_part` (7 min) and `lid_map` (3 min).
- `TAR_PROJECT=once tar_make_isolated(names = "check_ais_key_landings")` then built seven targets, not one (see the key
  cascade below).
- Afterwards, only `ais_catch` and the audit are outdated in the main project.

Before `ais_trail`, 17 GiB was free. A 31 GB DuckDB spill, left in R's tempdir by a job stopped that afternoon and held
by no process, was deleted on the maintainer's word, along with five finished scratch folders. After the build, the
effort grid's own spill reached 48 GB, and for about a minute the disk had 0.3 GiB free. The grid finished and checked
its hours; nothing failed.

## Before and after

`after.R` fingerprinted the same targets' outputs again. Each of the 713 files falls in one outcome:

- **Unchanged: 195.** They include all 11 of `staging/afli`, `aflaskeyti`'s 3, and 127 trail months.
- **Changed: 502.** That is 467 trail and match files, and 35 logbook, link, landing, reference and check tables.
- **New: 15.** They are `afli_grasl`'s six staged files, `catch_detail` (agf, lods and curated), `nephrops_tails`,
  `whole_weight_factor`, `trip_landing`, `trip_disposition`, the trip-landing check and the app-profile check.
- **Gone: 1.** `staging/ais/stk/year=2006`, the stale partition of TODO 95. `stk_event` lost its one row with it.

## Against the combined scratch build

The scratch build of plan 054 §8 step 1 wrote 91 files. Live, 84 of them are identical, one of those because it is
empty on both sides (`staging/fs_afladagbok/sensor_summary`). The other 7 differ, each for a known reason:

- **The STK chain, which scratch did not rebuild: 3.** `curated/check/trip_landing`, `curated/logbook/trip_landing`
  (1,625,493 → 1,625,519 rows) and `trip_disposition`. They read the new voyages and port calls.
- **The order of a floating-point sum: 2.** `landed_logged` (`kg_landed`, `landed_over_logged`) and `catch_flag`
  (`vessel_kg_largest`). Both are identical when rounded to 3 decimals.
- **Row order: 1.** In `staging/afli_sent/fishing_sample`, 3,286 `.checks` labels swap between "end time overlaps next"
  and "start time overlaps previous" (12 also to or from "ok"). The stations tie in time, so the label depends on the
  row order. The merged `fishing_sample` is identical, since nothing downstream reads the column (TODO 174).
- **The key cascade: 1.** `curated/check/ais_key_landings` (below).

## The trail

The number of fixes is unchanged in every year from 2007 to 2026. Station fixes and fishing hours (`fishing`) changed
by source as follows. The figures are for all years, after minus before (`trail_diff.csv`):

| Source | Fixes with a station | Fishing hours | Why |
|---|---|---|---|
| `afli_grasl` (new) | +2,658,252 | +95,844 | afli's lumpfish logbook as a source of its own, 2007-2016 (decision 263) |
| `fs_afladagbok` | +639,786 | +33,845 | plan 053's feed and the tour app: 8,423 more stations and 9,821 more trips staged (decisions 253-264) |
| `adb` | +67,312 | +881 | 2025-2026 |
| `afli` | −129,532 | −114,678 | mostly the nets' 0.2 kn floor (decision 247 §7) |
| no station | — | −3,301 | fixes judged by the voyage gear |

All fishing hours went from 9,154,305 to 9,166,895 (+0.14 %).

- **The floor.** Station fixes now below a 0.2 kn floor that are not fishing sum to 30,873 hours in 2017, where afli lost
  28,986. The pairs for 2019 and 2018 are 23,158 against 21,000, and 15,122 against 12,486. The same holds in every year
  from 2007, within 0-2.6 thousand hours. This is measured on the new trail only, assuming those fixes were fishing
  before: the old trail was deleted when the new one was written, so no fix-level comparison with it is possible.
- **Fewer afli stations.** 9,719 static-gear set windows, drawn from placeholder set times (2003-2023), are no longer
  drawn: the placeholder is flagged, not used (decision 255). The tour app changes the type of 332 afli stations
  in 2020-21 (decision 264).
- **Not attributed:** in 2021, `fs_afladagbok` has 51,183 fewer station fixes, and fixes judged by the voyage gear lose
  3,714 fishing hours.

## v0, the effort map and the dictionary

`products/user_tables.R` and both of the effort map's grids were rerun (`products.sh`; `v0_rerun.R` and
`v0_compare.log`).
- v0's written trip, station and catch tables gained the rows above (trips 1,853,260 → 2,087,289, stations 7,301,171 →
  7,545,513). Its four other tables are the same.
- In all four grids, the hours per preset equal the trail's: `fishing` +0.14 %, `fishing_flow` −1.94 %
  (11,606,386 → 11,381,649). The largest changes are lumpfish nets (gid 3) in 2008-2012 (the lumpfish logbook) and
  in 2017 and 2019 (the floor), cod nets (gid 2) under `fishing_flow` in 2015-2017, and handline (gid 14) in 2020 (the
  tour app).
- v0's tables carry `fd.dirty` false. The grids carry no stamps.

`docs/data-dict.yaml` gained the columns and tables plan 054 added. The STK page reads `staging/ais/stk` without
`unify_schemas` (TODO 95).

## TODO 139's check

`curate/voyage_gear.R` and `curate/trip_reconciled.R` were run a second time on an APFS clone of the rebuilt store.
Both give content identical to the live files (1,430,712 and 2,087,289 rows; `ties/compare.txt`).

## The key cascade, redone and kept

`tar_make_isolated(names = )` builds the named target and its outdated ancestors. In the once project, the main
project's files that it watches had all been rewritten, and every rewrite changes a file's stamp. So it rebuilt four
watchers, `landing_vid_class_overrides`, and the frozen `vessel_ais_key_cascade` before the check. `AGENTS.md` had said
that a once target built by name is safe from this.

- **The new cascade** equals, row for row, the base run of the key-redo refresh of 2026-10-23
  (`$FISHYDATA/archive/2026-10-23-key-redo-refresh/stores/base`: 20,546 rows).
- **The cascade it replaced** was built on 2026-10-17 (decision 128, md5 5571d26…). `vessel_ais_key.parquet` was built
  from it, and no copy of it was archived. The key itself is untouched. The main project never reads the cascade, so
  the trail and everything else built tonight are unaffected.
- **The check** therefore audits a newer cascade than the one the key came from. Against the scratch build's check,
  which read the old cascade, five vids differ. 2922, 2964, 7811 and 7858 show one mid instead of two, with 61-670
  fewer pings. 2173 is no longer a vessel "with landings and no AIS identity" (1,028 → 1,027 rows).
- **In the once project**, the key and its checks are now outdated. A whole once build would redo the key, which only a
  decision may do.

The maintainer kept the new cascade. The rule is now enforced: in the once project, `tar_make_isolated()` stops before
building anything when `names` would also rebuild an ancestor it does not name. It points to
`targets::tar_make(names = , shortcut = TRUE)` or `ancestors = TRUE`. This was tested with the build call stubbed out:
the once audit's call stops, naming its four outdated ancestors, and a main-project call runs as before. `AGENTS.md`
says so.

## What closes

The build lands every coded step of plan 054. These TODOs are deleted, each recorded where its decision says:
- 24 (decision 250; the check built, with the five vids above);
- 73 (the tour app, decision 264; plan 020 built as plan 052; `protected_bycatch` moved to TODO 173);
- 81 and 112 (decision 262);
- 95 (the writer clears its output since 7204d9a, now built: the 2006 partition is gone; the STK page);
- 139 (the tie-breaks of 7204d9a; the check above);
- 141 (decision 264; the question to the Directorate is TODO 169's);
- 152 (decision 257);
- 156 (plan 050 executed: step 5 with decision 257, ask f TODO 169's);
- 162 (decision 249);
- 167 (decision 263; its factors provisional until TODO 169's answers);
- 168 (plan 054 executed).

TODO 157 stays open, on plan 051's ask e (the paper era's × 1.25) and the authors' answers. Plans 027, 036, 050 and 054
are executed. Plans 019 and 051 are partly built, with stubs in TODOs 173 and 157.

## Left

- The 2021 differences above are not attributed.
- TODO 174: afli_sent's overlap labels depend on the row order.
- Columns the dictionary lacked before plan 054 are not added: the vessel register's tables, `station_window`,
  `catch_by_species_station`, `gear_window` and others.
- The dictionary entries were written by a helper agent (Claude), and checked here only by spot reads and the
  validator: `validate-spec` gives the same 10 errors and 261 warnings as before, and 67 of the new tables' 69
  columns pass `validate-meta` (the other 2 are DATE columns that DuckDB writes untyped). Not described yet:
  `curated/check/trip_landing` and `check/logbook_app_profile`. The agent also found descriptions that plan 054
  left stale, which nobody has checked: `logbook_fishing_sample.t1_placeholder`, `link_trip_reconciled.T1_ais`
  and `T2_ais`, `reference_port_code`'s table text, and `logbook_trip.source` (no `tour`). The `ais_catch` table
  names a file that is gone (decision 261). `afli_grasl` was added to six `schema` value lists.
