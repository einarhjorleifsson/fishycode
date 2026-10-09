# 013 — ramb as the function library for the WGSFD one-flow; fishycode as its first user

**status:** partly built — step A done (WGSFD doc version 2: `~/stasi/wgsfd2026/`, claude.ai rev 125), phases 0–2 done (decisions 070–072; `rb_assign_trip`'s declared tier moved to phase 4); phase 3 waits for the maintainer's go · **2026-10-09** ·
**see:** `~/stasi/wgsfd2026/one_flow_effort_pressure_catch_v2.md`, `~/R/Pakkar/ramb`, decision 070

Drafted with AI assistance (Claude) from the maintainer's direction in the session of 2026-10-08, three code
explorations and an adversarial review.

**Measured** (2026-10-08): the audit of ramb against the flow — which function does each step, tested once as a
data frame and once as a lazy DuckDB table on 3,000 `dansk` pings; ramb's git history of removed functions; the
fishycode scripts named as templates, read file by file.
**Assumed:** everything from "Function map" onward is proposal. In particular, that each fishycode step can be ported
to ramb with exact equality on real data, and that the speed-profile models fit at tier 3, are untested.


## Step A, now, for the WGSFD meeting. Approving this plan approves only this step.

Write version 2 of the one-flow document in `~/stasi/wgsfd2026/`. Version 1 is left untouched.

- **The diagram.**
  - `one_flow_cascade_v2.svg`: the diagram shown in chat (version 2), as a standalone SVG with explicit styles,
    since the chat's CSS classes are not available outside it.
  - `one_flow_cascade_v2.png`, rendered from it.
- **The document.** `one_flow_effort_pressure_catch_v2.md` is the version 1 text with the new figure, plus only the
  edits the diagram implies, in the doc's own short-bullet style:
  - two short entries before step 1:
    - vessel (`assign_vessel`): registry > own track > logbook/landing > continuity;
    - flag pings (`flag_pings`): invalid > duplicate > impossible, set aside; harbour pings stay in the trail;
  - step 1:
    - the voyage is built from harbour stays;
    - a "link and reconcile `T2`" bullet: many-to-many, covering sales notes per buyer and weekly landings over
      several trips;
  - step 2: the two-way note;
  - step 4: haul window + speed range;
  - step 6:
    - a "several trips (e.g. weekly landing)" row;
    - the sentence "catch can be coarser than the activity; each unit is shared over the fishing pings it covers";
  - "every ping is kept" becomes "every ping is accounted for; impossible pings are set aside";
  - the basis list adds `derived`;
  - the AI-use line gets a v2 entry: "diagram and matching edits drafted by Claude, 2026-10-08; human review
    pending".
- **The rendered page.** `one_flow_effort_pressure_catch_v2.html`, rendered with quarto. A clean render is enough;
  the output is not scraped.
- **What it does not touch:** the claude.ai master doc and version 1's files.
- **Then stop.** Phases 0–5 below start only on a separate go.

## Context

The WGSFD 2026 working document (`~/stasi/wgsfd2026/one_flow_effort_pressure_catch.md`, master on claude.ai rev 108)
describes one generic, per-ping flow: flag pings, then six steps (trip, logbook record, gear, fishing, effort and
pressure, catch and value). Each step takes the best source per ping, falls back when it is missing, labels the ping
with a basis, and keeps every ping.

The maintainer wants:

- **ramb** to be generic, with a function for every panel of the diagram;
- the Icelandic data (fishycode) to serve as the template for some cases;
- fishycode to call ramb wherever possible: anything of WGSFD value now in fishycode is generalised into ramb, then
  used from fishycode;
- names that are verb-ish and consistent, and that show where in the flow a function sits.

**Audit (2026-10-08).** Of the seven steps:

- ramb captures two: impossible positions (`rb_whack_clean`) and catch sharing (`dc_spread_cash_and_catch`, partly).
- It has building blocks for three: trip, gear and effort.
- It has nothing for two: the logbook record, and the decision whether a ping is fishing.
- No ramb function writes a basis.

The step logic lives in fishycode scripts and SQL. ramb's own speed-profile and trip methods were removed in 2021–2025,
mostly because of their package dependencies.

**Maintainer direction (2026-10-08):**

| Step | Direction |
|---|---|
| 0 | Impossible positions go in a separate table; harbour pings stay in the trail. |
| 1 | `T2` is to be resolved by comparing logbook, landings and AIS, and no vessel should be without a trip. The design is open. |
| 3 | Gear on the trail, but on hold, because global data have several gears per trip. |
| 4 | The data are fishy, so this needs deep thought first. |
| 5–6 | Downstream, outside fishycode; ramb still gets generic functions for them. |

## Decided by the maintainer (2026-10-08)

1. **Names.**
   - A function that belongs to a step is `rb_<verb>_<stage>[_<detail>]`, verb first. The stage word marks its
     place on the diagram's vertical line: `vessel`, `ping`, `trip`, `record`, `gear`, `fishing`, `effort`, `catch`.
   - Tools that serve every step are `rb_<verb>_<object>`.
   - All existing exports are renamed, and each old name stays as an alias that warns it will be removed (item 8).
     It replaces the bare `.Deprecated()` of `R/whackies.R:802-847`.
2. **One task, one function.** Where several functions do one task, they become one function with a `method =`
   argument.
3. **Columns.**
   - Inputs default to the grammar names (`vid`, `time`, `lon`, `lat`, `speed`, `T1`, `T2`, `t1`–`t4`), each
     overridable by an argument with tidy evaluation (`vid = vessel_id`).
   - Added columns use the doc's names (`trip_id`, `record_id`, `n_records`, `fishing`, `harbour_id`,
     `<stage>_basis`).
4. **Basis values:** `recorded | derived | reconstructed | synthesised | none`.
   - `derived` means computed from recorded values of the same record (`t2 + duration`).
   - Modifiers (`capped`, `placeholder`) go in their own columns.
5. **MFRI-only readers** stay in ramb, renamed `rb_read_*_mfri` and marked as MFRI-only.
6. **Lazy-first, no new Imports.** Code from other packages is recoded, not copied (rule below).

7. **`duckdbfs` is the default for reading and writing**
   - **Lazy inputs:**
     - Examples, docs and readers (`rb_read_*_mfri`) open data with `duckdbfs::open_dataset()`.
     - Test fixtures are made lazy with `duckdbfs::as_dataset()`.
     - `duckdbfs` moves from Suggests to Imports.
   - **One connection:**
     - Everything opened through `duckdbfs` shares its cached connection.
     - Tier-2 SQL takes the connection from the input (`dbplyr::remote_con`), which is that cached connection.
     - A function with several lazy inputs stops with a clear message if they are on different connections.
     - `rb_register_macros(con = duckdbfs::cached_connection())`.
   - **Writing:**
     - Anything ramb writes goes through `duckdbfs::write_dataset()`.
     - This includes the tier-4 label batches: written as temporary parquet, opened with `open_dataset()`, joined
       lazily. This replaces today's never-dropped temp tables.
     - fishycode's lesson (`R/write_parquet.R`) applies: a materialised frame that `write_dataset()` registers in the
       cached connection must be released after each batch, or a loop accumulates it (48 GB spilled in the ASTD-B
       run).
     - fishycode keeps `write_curated()` for `curated/`, because it adds the provenance stamps.
8. **Aliases warn that the old name will go.**
   - **Renamed functions:** a small internal helper `.rb_renamed(old, new)` warns once per session per name, so a loop
     over batches warns once, not thousands of times. For example: "`rb_speed()` is now `rb_calc_speed()`. The old
     name still works but will be removed in a future version."
   - **Deprecated functions that keep their old body:** the warning says what supersedes them and that the old
     function will be removed. For example: "`rb_trip()` is superseded by `rb_cut_trip_voyages()` and will be removed
     in a future version; until then it behaves as before."
   - **Tests:** each alias test checks the warning and that the result is unchanged.
   - **No `lifecycle` dependency;** this is base `warning()` with a session registry.
   - **`NEWS.md`** lists every old name with its replacement.

## Decided in this plan (change at approval if you disagree)

- **One label column for step 0.**
  - The ping flaggers share `ping_flag`: NA means a good ping; otherwise it holds the reason, e.g. `invalid`,
    `duplicate`, `vmask`, `spike`, `forward`.
  - Each flagger tests only rows not yet flagged, so
    `pings |> rb_flag_ping_invalid() |> rb_flag_ping_duplicate() |> rb_flag_ping_impossible()`
    reproduces `ais_ping_clean.R:91-103`.
  - The doc's `impossible` is `!is.na(ping_flag)`.
  - The function is named `rb_flag_ping_impossible`, the doc's word, not "whacky". The old `rb_whack_*` names stay as
    aliases.
- **`harbour_id` is the harbour polygon's id**, which is fishycode's `pid`, not the landing code `hid` (TODO 3c).
- **The gear speed range is `speed_min`/`speed_max` in ramb.** This removes the clash with the grammar's station
  bounds `s1`/`s2`. fishycode keeps `s1`/`s2` on the trail and maps them at its boundary.
- **Each step function returns one thing.**
  - `rb_cut_trip_voyages` returns the voyage table only. Pings get their voyage through `rb_assign_trip(voyages =)`.
  - `rb_assign_record` returns the pings. A separate `rb_link_record_pings` returns the table that links each ping
    to every record covering it.

## The verb table (what each verb means)

| Verb | Means | Returns |
|---|---|---|
| `flag` | label rows with a state; no row is dropped | table + label column |
| `assign` | a diagram step: a key or value from the best source, with a basis | table + value + `*_basis` |
| `share` | distribute a quantity over rows, conserving the total | table + shares |
| `find` | derive intervals or events from a track | new table |
| `cut` | split a track into segments | segment table |
| `build` | a rule or window table that a step consumes | new table |
| `link` | crosswalk two tables, ambiguity kept | link table |
| `limit` | judge a value against a rule; raw kept, value set NA when implausible | table + column |
| `number` | number runs or segments within a vector | integer vector |
| `detect` | per-row logical, for use inside `mutate()` | logical vector |
| `calc` | per-row numeric derivative | numeric vector |
| `encode` / `extract` / `convert` / `bin` | codes, metier parts, units, grids | vector |
| `interpolate` / `fill` / `predict` / `classify` / `lookup` / `cap` / `standardise` / `sum` | as in English | vector or table |
| `check` | validate a table and warn | the table, unchanged |
| `get` / `read` / `plot` / `rasterize` / `rayshade` / `register` / `keep` / `drop` / `create` / `peek` | as in English | as now |

A method never appears in a name; it is always `method =`. A grouping never appears in a method; it is always `by =`.
A ramb test enforces the table: every export except the deprecated aliases starts `rb_<verb>_`.

## Lazy-first rule, and dependencies

Each function is written at the first tier that can express it:

1. **dplyr that dbplyr translates.** One body serves data frames and DuckDB. Examples: voyage numbering by runs, the
   declared-trip join, effort intervals (`lead()`), catch shares, the landing-link cascade, jepol trip cutting.
2. **DuckDB SQL rendered from the lazy input** (`dbplyr::remote_con` + `sql_render`, returning `tbl(con, sql(...))`).
   Examples: ASOF joins, window frames, `QUALIFY`, recursive CTEs, harbour stays, record windows, ping-to-record
   matching, track interpolation, `fwdbwd`, and the neighbour tests of `sda`.
3. **Reduce lazily, fit small, apply lazily.** For the speed-profile models: speeds (and turning angles) are binned in
   DuckDB, overall or `by =` trip; a weighted EM is fitted in R on the bins; the fitted thresholds or states are
   applied back in SQL. This covers the Gaussian mixture and binary clustering.
4. **Sequential cores only** (the forward whack scan, HMM decoding): Rcpp behind a batched lazy wrapper, the
   `rb_whack_clean` pattern (`whackies.R:757-799`). One batch of vessels is collected, labelled in C++, only the
   labels are written back, and a lazy join is returned. The temp table must be dropped when it is no longer needed;
   today it never is.

**Macro twins.** The per-row tools (`rb_calc_distance`, `rb_convert_speed`, `rb_encode_ices_rectangle`,
`rb_encode_csquare`, `rb_bin_midpoint`) get a DuckDB macro of the same name, registered by `rb_register_macros(con)`.
The same `mutate()` then runs on a lazy table. For `rb_calc_distance`, see "One distance function" below.

**Recoding.**

- An algorithm that came from another package is recoded at the lowest tier that can express it. The original
  package goes in Suggests only, for an equivalence test with `skip_if_not_installed()`. This is the pattern of
  `rb_whack_sda` against `argosfilter` (`tests/testthat/test-rb_whack_clean.R:47-48`).
- Imports reviewed:

  | Import | Action |
  |---|---|
  | `data.table` (jepol) | recode |
  | `traipse` (geodesics) | recode |
  | `geo::arcdist` and `trip::` (both undeclared) | recode |
  | `terra`, `mapdeck`, `scales`, and `sf` for plotting | Suggests |
  | `icesVocab` | Suggests |
  | `omar`, `geo` | Suggests, with `Remotes` |
  | `duckdbfs` | Suggests → Imports (the default reader and writer) |
  | `glue` | replaced by `sprintf` |

**Every step function has a test** that runs the same fixture as a data frame and as a DuckDB table and compares the
results. One known divergence to fix: `fwdbwd` gives FALSE at track ends on a data frame but NA on DuckDB.

## One distance function (maintainer's direction, 2026-10-09)

*The direction is the maintainer's: one function with a `method` argument; DuckDB spatial on lazy tables; Rcpp
where there is a loop. The default and every number below were proposed and measured by Claude (AI-assisted) in the
session of 2026-10-09. Nothing is built yet.*

ramb has two distance definitions today:
- **An ellipsoid:** Vincenty, `.rb_geodesic`, used by `rb_calc_speed`.
- **A sphere:** haversine with R = 6,371,000 m, used by `rb_calc_distance`, the speed filters' C++ and `rb_flag_ping_duplicate`.

They become one function:

`rb_calc_distance(lon1, lat1, lon2, lat2, method = c("geodesic", "andoyer", "haversine"))`

- **`"geodesic"`, the default.** Exact on WGS84.
  - **Data frame:** Karney's algorithm, from GeographicLib's C code (`geodesic.c`/`geodesic.h`, MIT) added to ramb's
    `src/` with its licence notice. It is called through Rcpp, and it is one C++ entry point that the speed filters also call. It
    replaces `.rb_geodesic` (Vincenty).
  - **Lazy:** DuckDB spatial's `ST_Distance_Spheroid`, which is the same algorithm (through PROJ). It takes points as (lat, lon);
    the macro fixes the order.
  - **Why Karney, not Vincenty (maintainer, 2026-10-09).** Vincenty fails near the antipode, which is never a real leg but
    possible for a garbage ping, and ramb's version fails without any signal. From Iceland (64° N, 22° W) to a ping at the
    antipode it is 19,441 m short; at 157.9° E, 63.95° S it is 7,059 m short. Andoyer–Lambert cannot stand in for it: it is
    6,476 m long at the antipode. NA was ruled out by the maintainer. Karney is exact everywhere, so there is no fallback
    branch. Data frames, the C++ filters and lazy tables run one algorithm and agree on every leg.
  - **A deliberate exception to the "recode" rule above.** The C code is taken in unchanged, not recoded. Recoding Karney's
    numerics by hand is where errors would enter, and a reference library kept with its licence is not the forked script the
    rule was written against.
- **`"andoyer"`:** Andoyer–Lambert, a closed form with no loop. It runs as a plain DuckDB macro, without the spatial extension.
- **`"haversine"`:** the sphere, to reproduce older outputs.

**Why exact by default.** Measured against Karney's geodesic (geodist) on:
- 3,293,579 Icelandic legs (June 2023);
- a grid of 18 bearings and legs of 10 m to 100 km at 45° S to 75° N;
- WKSSFGEO's Adriatic (43–44° N), Portuguese (37° N) and `dansk` (55–57° N) tracks.

| Method | Worst error | Time per million legs, data frame / DuckDB |
|---|---|---|
| exact (Vincenty in R today; `ST_Distance_Spheroid`) | under 3e-6 m on real legs / 2e-9 m | 0.5–0.9 s / 0.12 s |
| Andoyer–Lambert | 1.4e-6 of the distance (14 mm per 10 km up to 50°, 8 mm at 65° N); R and macro equal to 2e-9 m | 0.30 s / 0.06 s |
| haversine | −0.44 % to +0.56 % by latitude and direction; at 35° N +0.23 % north–south, −0.22 % east–west | 0.08 s / 0.02 s |

- **The sphere's error is a bias, not noise.** At low latitudes it also changes sign with direction, so no regional radius
  fixes it. Any summed distance (track km, effort, swept area) would carry it. On real legs: 18 m in the Adriatic,
  340 m on a 104 km Danish leg.
- **Two exact implementations agree** (to 2e-9 m), so the data-frame and lazy results pass this plan's equality test
  with no tolerance. Andoyer on one side and spatial on the other would differ by up to 14 mm per 10 km.

**Lazy mechanics** (tested with DuckDB 1.5.6 and dbplyr):

- **The switch is a macro, not a test.** Inside `mutate()` on a lazy table, dbplyr never runs the R function; it passes
  the call to SQL by name. So the switch is a macro named `rb_calc_distance`, registered by `rb_register_macros(con)`,
  not an `inherits(x, "tbl_lazy")` test. Step functions that take a table keep that test and write the same call into
  their SQL.
- **The method is always the fifth argument, never named.** dbplyr cannot pass a named argument: `method = "haversine"`
  renders as `'haversine' AS "method"`, a parser error. An overloaded macro does work: 4 arguments take the default, and a
  fifth, positional argument is the method.
- **The defaults cannot drift.** A macro cannot call itself, so the 4-argument form calls a shared helper macro. R writes
  the macro SQL from the same constants as the R code.
- **Registration checks itself.** `rb_register_macros()` loads spatial and checks one known distance (1° of latitude at
  64° N). NaN or a wrong value stops it: with (lon, lat) the spatial function returned NaN without an error. If spatial
  cannot load, it stops. It never falls back to another method silently.
- **The speed filters are the exception.** They pull batches into R even on lazy tables (tier 4), so their distance is the
  C++ one, and it must be the same exact function.

**Before switching the filters and the duplicate rule** (`DUP_M` = 128.6 m) to the default, count the change, as
decision 069 counted the time-step floor. At 64° N distances grow by about 0.33 %, about 0.08 kn at 25 kn.

**Assumed, not measured:**
- that GeographicLib's C code, called through Rcpp, is at least as fast as the R Vincenty (0.5–0.9 s per million legs). geodist,
  which uses Karney's algorithm, took 1.6 s per million legs including its R overhead;
- that DuckDB spatial keeps the (lat, lon) order in later versions (the registration check guards this).

## What the diagram may be missing (from fishydata)

1. **Vessel identity.** Pings arrive as an MMSI or a mobile id. Mapping them to a vessel that changes over time is a
   stage of its own (`vessel`); it took plans 003, 008 and 009 in fishycode.
2. **Several feeds.** Merging feeds needs a feed priority and the flagging of cross-feed copies (decision 069).
3. **Harbour stays, not harbour pings.** Trips from the track need stays measured in elapsed time, a minimum stay by
   harbour class and year, and a departure radius per harbour. That is a builder the diagram hides.
4. **Sources checked against each other before the cascade.** `T2` reconciliation; logbook ↔ landing ↔ voyage links
   (products in themselves); corrections that keep the original value; human overrides as inputs (how cycles are
   broken).
5. **Two-way flow.** Records also get positions and times from the track: logger fixes on the AIS track, haul
   positions from pings.
6. **Ambiguity is kept.** Several records can cover one ping, and one voyage can carry several logbook trips (3–4 %),
   so counts and links are needed alongside "finest first".
7. **A fourth basis value**, `derived`: the doc uses it in step 4.
8. **Not every ping is kept; every ping is accounted for.**
   - Impossible positions are set aside in their own table (whacky pings, `ping_whacky`); every other ping stays in
     the trail. Pings in = pings out across the two tables.
   - The ramb flaggers only label. The caller does the split.
9. **Catch can be coarser than the activity.**
   - Fishing may be resolved per ping and per haul (`t1`–`t4`) while catch arrives per day × rectangle, or as a
     weekly landing that covers several daily trips.
   - Step 6's units therefore go above the trip ("several trips", e.g. a weekly landing; as a last resort vessel ×
     period). Each unit's catch is shared over the fishing pings it covers, by effort.
   - Trips and landings link many-to-many: several sales notes per trip (one per buyer), one weekly landing over
     several trips.
   - Sales notes are already in the landing panel; no new box.

## Function map: panel → ramb function → template

| Stage | ramb function | Template, origin, status |
|---|---|---|
| vessel | `rb_assign_vessel(pings, key)`: the time-bounded join | `reference/vessels/ais_key.R`; the key builder stays in fishycode |
| ping | `rb_flag_ping_invalid(rules)` | `ais_ping_clean.R:94`: `lon == lat`, (0,0), out of range |
| ping | `rb_flag_ping_duplicate(feed, priority)` (no default priority) | `rb_whack_duplicates` (vector core becomes internal) |
| ping | `rb_flag_ping_impossible(method = "clean" \| "sda" \| "forward" \| "fwdbwd" \| "sequential" \| "distance")` | `rb_whack_clean`, the other labelling filters, and the removed `rb_whacky_points` |
| ping | `rb_flag_ping_harbour(pings, harbours)` → `harbour_id` | `curate/ais_ping_tag.R` (port last: it re-runs the filter on 543 M pings) |
| trip | `rb_find_trip_stays(pings, harbours, min_stay, radius_in, radius_out, events = NULL)` | `curate/harbour_stay.R`; STK event pairs become the optional `events` |
| trip | `rb_cut_trip_voyages(pings, stays, method = "stays" \| "runs" \| "jepol", min_pings, split_at_year)` | `curate/ais_trip.R` (keep its choices: per-year cut, numbering before the `MIN_PINGS` filter); `rb_trip`, `rb_trip_jepol`, removed `define_trips_pol` |
| trip | `rb_link_trip_voyages(trips, voyages)` | `curate/link_trip_voyage.R` |
| trip | `rb_link_trip_landings(trips, landings, method = "cascade" \| "nearest_date")`: a many-to-many link table (sales notes per buyer; weekly landings over several trips) | `curate/link_lid_map.R`; removed `match_nearest_date`. **Phase 4** |
| trip | `rb_assign_trip(pings, trips, landings, voyages)` → `trip_id`, `trip_basis` | the declared tier from `rb_add_tripid` (rewritten: it fails silently on DuckDB); the `T2` tier is phase 4 |
| record | `rb_limit_record_duration(records, rules)` | `R/duration_limit.R` |
| record | `rb_build_record_windows(records, rules)` | `curate/station_window.R`; the adb `t1`/`t4` swap stays in fishycode |
| record | `rb_assign_record(pings, windows)` → `record_id`, `phase`, `n_records`, `record_basis` | `R/trail_sql.R` |
| record | `rb_link_record_pings(pings, windows)` | `trail_match` in `R/trail_sql.R` |
| gear | `rb_assign_gear(...)`, `rb_predict_gear_width(method = "benthis")`, `rb_fill_gear_width(rules)` | `curate/corrections/adb_gear.R`, `rb_benthis_width`, `rb_gearwidth_proxy`. **On hold** |
| fishing | `rb_assign_fishing(method = "window" \| "speed" \| "gmm" \| "embc" \| "hmm", by = NULL)` | `"window"` = `R/trail_sql.R`, ported as it is in phase 3; the rest in **phase 4** (the removed `R/models.R` is the specification, rewritten) |
| fishing | `rb_build_fishing_speeds(method = "declared" \| "recorded_windows" \| "gmm", by = NULL)` | `reference/gear/windows.R`, plan 012, removed `rb_gaussian` |
| effort | `rb_assign_effort(pings, vessels, widths)` | `products/ices_vms_datacall/build.R` (stale); ramb only |
| catch | `rb_share_catch(pings, catch, landings, method = "effort" \| "equal")`: units at any resolution, including units above the trip (several trips; vessel × period); uncovered catch moves up a level | `dc_spread_cash_and_catch`, removed `dc_split_among_pings`; ramb only |

## Current exports: one-to-one renames (phase 1a; behaviour unchanged)

| New | Old (kept as an alias) |
|---|---|
| `rb_calc_speed`, `rb_calc_distance`, `rb_calc_step_time`, `rb_calc_step_acceleration`, `rb_calc_track_time` | `rb_speed`, `rb_distance`, `rb_st`, `rb_sa`, `rb_track_time` |
| `rb_convert_speed(x, from, to)` | `rb_ms2kn`, `rb_kn2ms` |
| `rb_number_runs` | `rb_event` |
| `rb_encode_ices_rectangle`, `rb_bin_midpoint` | `rb_d2ir`, `rb_midpoint` |
| `rb_detect_in_polygons`, `rb_keep_in_polygons`, `rb_drop_in_polygons` | `rb_points_in_polygons`, `rb_st_keep` (the `spatial.R` body), `rb_st_drop` |
| `rb_extract_metier` (`part =`) | `rb_gear_from_metier`, `rb_target_from_metier`, `rb_met5_from6` |
| `rb_get_gear_vocabulary` (`list =`) | `rb_get_ices_*` |
| `rb_predict_gear_width`, `rb_fill_gear_width`, `rb_standardise_gear_meshsize` | `rb_benthis_width`, `rb_gearwidth_proxy`, `rb_std_meshsize` |
| `rb_classify_mmsi`, `rb_lookup_mmsi_country` | `rb_mmsi_category`, `rb_mmsi_flag` |
| `rb_cap_outliers` (`method =`) | `rb_cap_iqr`, `rb_cap_miller`, `rb_cap_winsorize` |
| `rb_detect_crosses_year`, `rb_check_trip_crosses_year`, `rb_create_timestamp` | `rb_check_crosses_year`, `dc_check_eflalo_crosses_year`, `dc_create_timestamp` |
| `rb_plot_trail`, `rb_plot_trip`, `rb_rasterize_xyz`, `rb_rayshade_raster`, … | `rb_mapdeck`, `rb_md_trip`, every `mb_*` (each listed in NEWS.md, including the misspelt `mb_rashade_xyz_dynamic`) |
| `rb_read_logbook_mfri`, `rb_read_trail_mfri`, `rb_read_harbours_mfri`, `rb_read_survey_*_mfri` | `rb_logbook`, `rb_trail`, `read_is_*` |
| `rb_interpolate_track`, `rb_interpolate`, `rb_sum_across`, `rb_pad_harbour`, `rb_peek` | kept as they are; their verbs are in the table |

Notes on this table:

- `rb_convert_speed`, `rb_extract_metier`, `rb_get_gear_vocabulary` and `rb_cap_outliers` merge pure functions with
  identical outputs; the `from`/`to`, `part`, `list` or `method` value reproduces each old function.
- `rb_encode_csquare` is new (the datacall uses `vmstools::CSquare`).
- `whack_clean`, `whack_sda`, `whack_forward`, `whack_fwdbwd` and `whack_sequential_fast` are re-pointed at the new
  functions.

**Not renamed. These are deprecated and keep their old bodies.** Each one's behaviour differs from the new function
that supersedes it:

| Deprecated function | Why it is not an alias of the new function |
|---|---|
| `rb_whack_*` table filters | output layouts `whack`, `whack2`, `whack_sda`, `whack_stage` |
| `rb_whacky_speed_mendo`, `rb_whacky_speed_trip` | they drop rows; `_trip` also has a bug (`whackies.R:596-600`) |
| `rb_trip`, `rb_trip_jepol` | they work on vectors |
| `rb_add_tripid` | |
| `rb_cap_effort` | it does three things: fills with the median, caps at 12/24/15 h, overwrites `t2` |
| `rb_grade` | it differs from `rb_midpoint` |
| `rb_st_remove` | it differs from `rb_st_drop` on MULTIPOLYGON |
| `rb_rms_tbl` | `calc` returns a vector, and this returns a table |
| `dc_spread_cash_and_catch` | |

Each one's alias test runs it against its own snapshot from before the change.

## Removed functions that come back as methods (rewritten, not copied)

| Removed (commit) | Becomes |
|---|---|
| `rb_whacky_points` (6e9d444) | `rb_flag_ping_impossible(method = "distance")` |
| `define_trips_pol` (e147cfd) | the `"jepol"` method, one version only |
| `rb_add_trips`, `rb_add_trips_vt` (3e45175) | the declared tier of `rb_assign_trip`; column arguments cover EFLALO/TACSAT names |
| `match_nearest_date` (008120f) | `rb_link_trip_landings(method = "nearest_date")` |
| `rb_gaussian`, `rb_gaussian_binary_clustering`, `rb_hidden_markov_step`, `rb_hidden_markov_step_and_turn` (f9d4039) | the `"gmm"`, `"embc"` and `"hmm"` methods (with `by =`), and `rb_build_fishing_speeds(method = "gmm")` |
| `dc_split_among_pings` (4cad4f6) | its `level` argument informs `rb_share_catch`'s move-up order |
| `stk_bearing`, `stk_angle` (2021) | `rb_calc_bearing`, `rb_calc_turn_angle`, needed by the HMM step-and-turn method |

The four functions in `models.R` used `%>%`, hard-coded `id`/`x`/`y` (UTM)/`behaviour` and needed `plotmm`. They are
the specification, rewritten under the lazy-first rule.

## Phases

**Checkpoints, even in auto mode.** Phases 0 and 1 run straight through. Work stops for the maintainer:

- after phase 1, before phase 2 (the first change to step logic);
- before any full rebuild;
- before any push of ramb to GitHub;
- before any change to the claude.ai doc.

Each phase ends with three things:

- ramb tests passing;
- fishycode `check_bookkeeping()` passing;
- a decision record, numbered from 071 (070 closes TODO 12) and indexed, plus a commit in each repo.

0. **Record.**
   - **Diagram.** The proposed update to the WGSFD doc's one-flow figure (version 2, shown 2026-10-08) goes into the
     claude.ai doc once you agree its content:
     - vessel and flag-pings rows;
     - voyages from harbour stays;
     - the many-to-many link-and-reconcile band;
     - the two-way note;
     - window + speed;
     - catch units above the trip, with the "coarser than the activity" band;
     - the bottom bar saying "accounted for", with five basis values.

     The doc's text changes with it: "Every ping is kept" becomes "accounted for". The AI-use line is extended to
     cover the change.
     - Saved locally as `~/stasi/wgsfd2026/one_flow_cascade_v2.svg` and `.png`, beside the untouched
       `one_flow_cascade.png`.
     - The figure in the claude.ai master doc is replaced only on an explicit yes. The doc keeps revision 108 in its
       history.
   - Close TODO 12: verify the stamps and record it in decision 070.
   - TODO 37 stays parked on its branch; its full rebuild joins phases 2–3.
   - Write fishycode `curate/plans/013-ramb-one-flow.md`: its header contract (status; measured vs assumed), a row
     in `plans/README.md`, and a TODO stub with a status and a check.
   - Widen the basis triple in `AGENTS.md` and `docs/grammar.qmd`, and note the `s1`/`s2` clash.
   - Add TODO items for the fishycode fixes listed below.
   - In ramb: write `NEWS.md` (the old → new map) and a "Naming" section in `R/ramb-package.R`.
1. **Pure renames.**
   - **1a.** Snapshot every current export's output on its fixture, apply the one-to-one table, and add the naming
     test and the alias tests.
     - Drop the duplicate definitions, keeping `spatial.R`'s `rb_st_keep` and `mb_rasterize_xyz.R:34`.
     - DESCRIPTION: `R (>= 4.1)`, Roxygen markdown, the Import review, `rb_register_macros`.
     - `_pkgdown.yml` reference grouped by stage, plus a Deprecated group.
     - Update README.Rmd, the articles and TODO.md to the new names.
   - **1b.** fishycode callers move to the new names. Outputs are unchanged, so nothing is rebuilt.
     - `curate/ais_ping_clean.R`, `ais_ping_union.R`, `ais_trip.R:197`, `R/entity_class.R`, `reference/vessels/mmsi.R`
     - `sources/norway/logbooks.R:62`, `products/exports/astd_iseez.R:201`, `buseful_2025-05-05.R:146`,
       `products/ices_vms_datacall/build.R:247`
     - the checks, and `docs/stk_data-inspection.qmd`
     - A grep then confirms that no deprecated name is called.
   - Outside users (`~/stasi/test`, fishyweb notes) keep working through the aliases.
2. **Steps 0–1 in ramb**, ported with exact equality first:
   - Functions: `rb_flag_ping_invalid`, `rb_flag_ping_duplicate`, `rb_flag_ping_impossible`, `rb_find_trip_stays`,
     `rb_cut_trip_voyages` (`"stays"`, then `"runs"`/`"jepol"` recoded), `rb_link_trip_voyages`, and
     `rb_assign_trip` (declared, voyage and none tiers).
   - Fixtures: a `dansk` subset with `dansk_harbours`, plus synthetic tracks.
   - fishycode's `ais_ping_clean.R`, `harbour_stay.R`, `ais_trip.R` and `link_trip_voyage.R` call them.
   - Equivalence is checked on vessel subsets without touching `curated/` (the existing `AIS_TRIP_VIDS` hook writes
     to staging).
   - `rb_flag_ping_harbour` and the `ais_ping_tag.R` port come last.
3. **Step 2 + fishing `"window"` in ramb**, exact port:
   - Functions: `rb_limit_record_duration`, `rb_build_record_windows`, `rb_assign_record`, `rb_link_record_pings`, and
     `rb_assign_fishing(method = "window")`. The last three must run lazily on a month of the trail.
   - fishycode's `R/duration_limit.R`, `station_window.R`, `R/trail_sql.R` and `ais_trail.R` call them.
   - Subset equivalence first. Then **one full rebuild for phases 2–3 together, with TODO 37 merged**, verified with
     per-partition fingerprints (rows plus a hash of key columns) against snapshots from before the change.
   - Only after that, as separate counted commits:
     - half-open windows, which end the boundary double count;
     - the `ais_ping_tag` overlap de-duplication.
4. **Design, then build.** Each piece continues an existing plan or TODO item rather than opening a new one:
   - `T2` reconciliation, with `rb_link_trip_landings` (the `link_lid_map` fixes) as its first piece: TODO 27b and
     plan 011.
     The maintainer, 2026-10-09: neither declared date is the arrival. The logbook's `T2` is often the expected arrival,
     written before the trip ends; the landing's date is when the catch was declared or sold. Only the track measures
     when the vessel enters port, so reconciliation links the declarations to the arrival rather than choosing one of
     them as it, and keeps all three with their basis.
     The bootstrap this creates (maintainer, same day): preprocessing matches logbook and landings on the declared
     dates only (no AIS, plan 014), and the accurate departure and arrival exist only in the flow. So step 1 builds the
     reconciled trip table as a flow output: `T1`/`T2` from the track's stays, the logbook trip and the landings linked
     to it, each with its basis; it may also link landings the declared-date match missed. It is never written back
     into the preprocessing link (`lid_map`). If a reconciled result must change an input, it re-enters as a reviewed,
     frozen input by decision, as the vessel key does (decision 075).
   - Gear with several gears per trip: TODO 34.
   - Fishing beyond window + speed: plans 004 and 012, TODO 18.
     - `"gmm"` and `"embc"` at tier 3, tested against `mixtools` and `EMbC`.
     - `"hmm"`: fitted at tier 3, decoded at tier 4, tested against `moveHMM`.
5. **Steps 5–6, ramb only:** `rb_assign_effort` and `rb_share_catch`.

   **Before building steps 1, 3, 4 or 5, read decision 078:** outside code mined for them (iapesca, WKSSFGEO,
   WKSSFGEO2), and ramb's `crs_m = 3575` port-buffer default, measured wrong away from the north.

**fishycode fixes found while exploring** (TODO items in phase 0, fixed in the phase that ports the code):

- `logbook_sensor_gps.R:45-52, 68` joins ids without `schema`.
- `catch_by_species_trip.R:40, 55` groups ids without `schema`.
- `ais_ping_tag.R` can duplicate a ping where polygons overlap.
- `link_lid_map.R:198, 210` applies `isTRUE()` to a column, and the map is not one-to-one.
- `products/ices_vms_datacall/build.R` is stale and writes into the repo.

Anything that goes back into the WGSFD document states its AI use (MFRI policy).

## Verification

- **ramb:** `devtools::test()` passes. It covers:
  - the naming test;
  - alias tests against the pre-change snapshots;
  - one data-frame-vs-DuckDB equivalence test per step function;
  - recoding tests against the original packages, guarded by `skip_if_not_installed()`.

  `R CMD check` shows no new notes. Install with `R CMD INSTALL --preclean .`
- **fishycode, phases 1b–3:**
  - `targets` cannot see script edits, so ported targets are `tar_invalidate()`d by hand.
  - Equivalence is shown first on vessel subsets written to staging.
  - The full rebuild uses `tar_make_isolated()`, or `tar_make()` once TODO 37 is merged.
  - Rebuilt outputs are compared by per-partition fingerprints against snapshots taken before the change.
  - Every difference is counted and explained in the phase's decision record.
  - `check_bookkeeping()` passes.
- **Pushing** ramb to GitHub happens only with your yes; fishycode has no remote.

## TODO items folded into the phases

Open `TODO.md` items that this revamp closes or touches, so they are done together rather than twice:

| Phase | TODO items |
|---|---|
| 0 | 12 (closed, decision 070) |
| 1 | 7 and 30 (closed, decision 071) |
| 2 | 40 (the key loop: W1 reads key-dependent pings), 42 (`ais_ping_tag` overlap duplicates), 38 (whack loose ends), 3c and 36 (harbour code types, `pid` stability), 33 (harbour class), 22 (foreign vessels never reach trips) |
| 2–3 rebuild | 37 (`produces()` cleanup, on branch `todo-37-produces-cleanup`), 14 (two astd months, needs the union rebuilt anyway) |
| 3 | 3 (`station_type` = the record's `resolution`), 41 (`.sid`/`.tid` joins without `schema`), 29 (afli overlap check blanks `t2`/`t3`) |
| 4 | 43 (`link_lid_map` bugs), 27b (datacall onto the trail), 25 and 39 (key review), 34 and 18 (speed ranges, behavioural windows), 17 and 23 (vessel identity) |
| not part of it | 8, 9, 10, 15, 16, 19, 21, 24 |

## Logic questions found while porting (phase 2)

An exact match with the old output proves the port faithful, not the logic right. These were found by reading
the ported code. Each is to be settled by a measurement, and fixed only as a separate, counted commit:

| Step | Doubt | What would test it |
|---|---|---|
| 0 duplicate | A lower feed's copy is flagged before the impossible stage, so an STK anchor that is itself impossible still removes a sound astd copy. | Count duplicates whose STK anchor is later flagged impossible. |
| 0 invalid | `lon == lat` is safe only where the fleet never fishes at lon ≈ lat (59–76 °E at these latitudes); it is no generic rule. | It stays a fishycode rule (`rules = "lon_eq_lat"`); ramb's default adds `out_of_range`. Count what `out_of_range` adds. |
| 0 harbour | The harbour polygons are one static set (`staging/aux/ports.fgb`) applied to 2007–2026, though harbours were built out over those years. A ping by a new quay counts as at sea in the years before its polygon was drawn, and the other way round. | Date each polygon change; count pings that change tag if the polygon of the ping's year is used. |
| 1 stays | The nearest harbour is chosen by `ST_Distance` in degrees (EPSG:4326). At 65 °N a degree of longitude is about 0.42 of a degree of latitude, so east–west distances are understated. | Re-choose in metres (EPSG:3575) and count the pings whose harbour changes. |
| 1 stays | Event pairs count only from 2017 (`EVENT_FROM`), so stays are defined differently before and after. | Count event-only stays by year; check whether pre-2017 events are usable. |
| 1 voyages | Voyages are cut at New Year, so a trip at sea over 31 December becomes two voyages and links to two logbook trips. | Count voyages that end at 23:59:59 31 Dec or start at 00:00 1 Jan with no stay between. |
| 1 voyages | Voyages under 10 pings are dropped after numbering. Their pings get `trip = NA` though they are at sea, which goes against "no vessel without a trip". | Count the pings and vessel-days on dropped voyages, by year. |
| 1 voyages (`jepol`) | The ICES rule splits a voyage over `max_dur_h` one ping before its longest gap (`which.max(INTV[2:.N])` indexes the rows from the first), and its 3-minute test reads the gap before that ping, not the longest one. Kept so the recode matches `rb_trip_jepol()`. | Fix in ramb as its own commit; count on `dansk` the voyages whose cut moves. Not used by fishycode. |
| 1 voyages (`jepol`) | The ICES rule's voyage ends at the first ping back in harbour, so that harbour ping belongs to the voyage; `"stays"` and `"runs"` end at the last ping at sea. The methods differ in more than how they find harbour. | Document the choice per method; decide whether `jepol` keeps the ICES convention. |
| key | W1 now reads the merged pings before cleaning, so whacky other-feed positions count as evidence. | Compare W1 hits with the whacky-flagged pings removed. |
| key | The segment build keeps the first row of a tie in several places; which row wins was decided by the input files' row order (now fixed by sorting on all columns). A principled tie-break (e.g. stronger evidence, then earlier date) is not chosen. | List the ties the sort decides, and compare with an evidence-ranked choice. |
