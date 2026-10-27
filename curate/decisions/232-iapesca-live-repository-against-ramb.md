# 232 — iapesca's live repository read against the one flow and ramb: two ramb methods follow its 2022 copy; the better half, step by step

*2026-10-27. The maintainer: "the iapesca github site is a dead alley, for a long time not maintained. the live
source is here: https://gitlab.ifremer.fr/iapesca/r-packages_iapesca … care to clone it and then mine it. and then
compare it with one flow, the ramb package". The maintainer and iapesca's author mean to discuss, in Ancona, putting
the better half of each package's work in one place. Claude (AI) cloned the repository and read it with three AI
subagents (the effort and output functions; the net, Danish-seine and observer functions; the core, the learners and
the issues of 2026-10-19), then checked the claims below that the record rests on in the code itself. No iapesca code
was run: every defect under "Read, not run" is from reading. No person has checked this record. Nothing went into
ramb.*

## What was read

| | the live repository | the copy read until now |
|---|---|---|
| where | `gitlab.ifremer.fr/iapesca/r-packages_iapesca`, cloned to `~/R/Pakkar/r-packages_iapesca_gitlab` | `github.com/JulRodrigu/r-packages_iapesca`, at `~/R/Pakkar/r-packages_iapesca` |
| version, commit | 1.3, `1882892` of 2026-10-22 | 0.1, `1b7248c` of 2022-11-16 |
| history | 282 commits from 2022-12-02; most in 2023-06 to 2023-08 and 2026-01 to 2026-10 | 5 commits, one day |
| size | 76 exported functions, about 10,000 lines of R, six example datasets | about 5,500 lines |
| licence | CC BY 4.0 | GPL |

The GitHub copy is deprecated; the package is hosted by Ifremer (its author, 2026-10-26). Version 1.3 was submitted to
CRAN in October 2026 (commit `b188dea`). Branch `iapesca_v1.3_261021` stops at `a27efb9`, two commits before main, so if
CRAN builds from it, it lacks the fixes below (an inference, not checked). Decisions 078 (2026-10-09) and 148, plan
031's trip bench and the issues of 2026-10-19 (`curate/issues/iapesca.yml`) all read the GitHub copy.

## Lineage, as the code shows it

- iapesca's `Clustering_BivariateBinary` calls `EMbC::stbc(df, info = -1)` and takes the turns and speeds out with
  copies of EMbC's internal `getTurns` and `getSpeed`. That is the maintainer's `rb_gaussian_binary_clustering` in
  WKSSFGEO (`R-dev/einar/ramb_functions2.R`, 2021-11), now `fm_gaussian_binary_clustering` in fishymodel.
- iapesca's `CalcThresholds` sets limits at ±1.96 σ around a cleaned mean, as the maintainer's `rb_gaussian` set them
  around the slowest Gaussian mode (`cs = 1.96`).
- The `Calc*` movement features came to WKSSFGEO's pkg branch from Jeppe Olsen's upload (`R-dev/ToICESGitHub`,
  2021-12-03), which the maintainer packaged; decision 078 found them to be iapesca's ancestors.
- The live `Check_sfObject`, the remedy for the first issue below, names both the maintainer and iapesca's author.

## The issues of 2026-10-19, against the live code

Its author fixed them in GitLab work item #14, commits `bb145a9` (2026-10-21) and `1882892` (2026-10-22). Two were
fixed long before: they were reported against the dead copy.

| issue | outcome |
|---|---|
| no trips with s2 off | fixed (`bb145a9`): `Check_sfObject` turns s2 on for lon/lat and restores it, though only on success |
| `min.stop` measures between trip ends | fixed in 2023 (`3edff8f`, 2023-02-01): a stop is the gap from the last fix at sea to the next |
| the buffer drops back past about 370 km | fixed (`bb145a9`) with the suggested `min(max(...))` |
| `CalcSpeed` drops rows that are not duplicates | changed, not as suggested (`1882892`): any second fix at the same second is dropped, wherever it is |
| `CleanSpuriousSpeeds` returns NA rows | fixed in 2023 (`df901f9`, 2023-07-10) |
| `Char2Time` at midnight | fixed (`1882892`); `CalcSpeed` still turns a missing time step into speed 0 |
| a faster harbour test (enhancement) | in part: sparse `st_intersects`; buffered harbours cannot be passed in |

## What ramb took from the 2022 copy, and how the live method differs

- **The trip finder**, `rb_create_voyages(method = "iapesca")` (2026-10-19, matched voyage for voyage against the
  2022 code). The live `Detect_FishingTrips` measures a stop as the gap between fixes at sea (since 2023), clamps the
  buffer, grows it by a fifth of the distance to its cap with no limit on the passes, and names a trip by its last
  fix's date. ramb's method is the 2022 rule, the `min.stop` and buffer faults included.
- **The set finder**, `rb_link_record_sets()` (2026-10-16). Both buffer the haul's line from 330 m to 550 m in 10 m
  steps. The 2022 method looked back over the same trip and up to two trips before, at any time; it summed three
  scores (lateness, floored at 0.25; the pass's fixes, capped at 4; its setting labels, capped at 4). ramb multiplies
  the first two and has no labels. The live method looks back 1 to 240 hours over up to 11 trips, scores the pass's
  length along the line (capped at the net's length) instead of its fixes, caps nothing, and adds a consolidation pass
  on the soak times.
- **Not taken.** iapesca's speed filter was benchmarked against ramb on the 2022 code (55-60 times slower, decision
  078); its method has not changed since 2023, apart from the NA fix.

## The better half, step by step

Claude's reading, for the discussion in Ancona; "better" means more complete for that step, not better code
throughout.

| step | iapesca 1.3 | ramb (and fishymodel) | the better half |
|---|---|---|---|
| Vessel | assumes one vessel id | `rb_link_vessel_tracks` | ramb |
| Flag pings | removes rows (`CleanSpuriousSpeeds`, 25 kn) | labels them; four flags | ramb |
| Resampling | `Resample_Traj`: `trajr` in time, on an oblique Mercator | `rb_interpolate_track`, linear | equal; neither has course-and-speed interpolation |
| 1. Trip | harbours, or **a coastline downloaded through geodata when there is no port list**, or a speed limit | five methods, port calls, ranked witnesses for a trip's ends, many-to-many links, any size (DuckDB) | ramb, but iapesca's coastline mode is the piece ramb lacks for trips without a port list |
| 2. Record | no logbook records; **nets built from labelled hauling fixes** (`Create_Nets`, `Consolidate_Nets`); sets found from hauls (the live method above); **Danish seine operations** (`Detect_DanishSeineOperations`, DTU's, 2026-08); **observer operations put on fixes** (`match_Obs2Pos`, 2025-10) | record windows at any resolution, events, stretches, the set finder of 2022 | ramb for records; iapesca for gear geometry, Danish seine and observer data |
| 3. Gear | carried through nets; the gear checked against ICES's `GearType` list (`Positions2CIBBRiNA`) | widths (BENTHIS), métier, ICES's code lists | ramb |
| 4. Fishing | **movement features** (`CalcFeatures`: proximity index, jerk, bearing rate, straightness, sinuosity, lagged copies), random forests tuned by out-of-bag error per row, EMbC, k-means, one-class SVM | the window-then-speed cascade; Gaussian mixture, EMbC and HMM in fishymodel | iapesca for features and learners; ramb for record-led rules. Neither validates by trip |
| 5. Effort | **static gear**: net length × soak per net (`LengthXSkt`), nets hauled and set, soak quantiles; days at sea `floor(h / 24) + 1`; fishing days; no kW; the interval to the previous ping, uncapped, in input order | hours capped, kW-hours, swept area, on every fix | ramb for time and towed gear; iapesca for static gear |
| 6. Catch | none: no catch or value goes on a fix | units at any resolution, split under any filter, kg in = kg out, flags | ramb |
| 7. Products | C-squares (vmstools' code), ICES rectangles, rasters, regridding to a plane, plots; TACSAT and EFLALO from positions and from SACROIS, Ifremer's cross-validated logbook data; CIBBRiNA's activity template | any cell size, ICES rectangles (with the I skipped), the map viewer | iapesca for c-square codes and the format writers; ramb for rectangles and viewing |
| Basis, scale | no basis; one vessel or trip in memory, in parallel | a basis on every value; lazy tables | ramb |

Two differences of design sit under the table. iapesca removes what it rejects and works on sf objects held in
memory; ramb labels and works on lazy tables. And iapesca's dependencies are all on CRAN, while ramb's DuckDB spatial
extension is downloaded at first use, which a colleague behind an institutional VPN could not do (2026-10-26).

## Read, not run (for its author)

As read on main at `1882892`. *Amended the same day, at the maintainer's go:* the seven that looked like bugs were run
against iapesca 1.3, installed from the clone into a scratch library. Six reproduce and are drafted, unsent, as
`batch_2026_10_27` in `curate/issues/iapesca.yml`: the ICES rectangles, `CleanMemory`'s `unlink`, `Process_TripPositions`,
`Calc_VesselFE`'s fishing days, `Sacrois2Eflalo` (a species coded NA loses its kilograms; a fleet register missing the
vessel's 2022 row drops 6 of the example's 8 trips and 78 % of its kilograms; the example itself adds up) and the Danish
seine (with 2 h in harbour at each end of a trip, every fix at sea becomes "fishing" and each trip's rows go from about
1,100 to 1,800, one per slow cluster). `CalcThresholds` is dropped: it is internal and every caller passes `GaussianQt`.
The other four below are design points, kept for discussion. *Amended again the same day:* the maintainer's two rules
for any function, that it returns the class and row order it was given, and that it leaves the caller's session as it
found it (no `setwd()` without an `on.exit()` back), were tested on iapesca and drafted as two more issues. Four functions
re-sort the rows by time, two return a data.table from a data.frame, and `Clustering_BivariateBinary` fails on rows not in
time order. `Calc_NetsThresholds` resets the caller's random seed, and s2 stays switched on after an error. The same test
on five ramb functions: the two ping flags keep class and order; `rb_add_effort` returns a tibble from a data.frame,
re-sorted, and `rb_create_voyages` a tibble; none changed the session; ramb's DuckDB keeps its extensions in
`~/.duckdb`, shared across sessions. *Amended a third time the same day:* before sending, at the maintainer's request,
every issue was checked again from scratch (the `checked` field of `batch_2026_10_27`): a fresh clone, every reprex rerun
as written, every cited line re-read, each suggested fix tried on a patched copy, and an independent AI reader asked to
refute each one. That corrected six of them: a wrong cause in the Danish seine, an unsafe fix for `CleanMemory`, the
wrong side of a join in `Sacrois2Eflalo`, a false sentence about R CMD check, `Positions2Tacsat` and `assign_lsTabs`
dropped as documented behaviour, and two cases added (`Sacrois2Eflalo` loses a whole vessel missing from FPC when
there are several; `CleanMemory` is called by two other functions). `CalcTurningAngle` became an issue of its own:
nine drafts. Each points, where it can, to what ramb does at its pushed commit `9a67e0d`. The same day iapesca 1.3 was
installed in R from GitLab at `1882892`, replacing the stale 0.1.

- `ICES_rectangle` does not skip the letter I (30-40° E gives `I`, where ICES has `J`), does not pad rows 1-9 to two
  digits, and gives the A column 6-9 where ICES has 0-3.
- `BackgroundMapWithCountries` and the exported `CleanMemory` run `unlink(list.files(tempdir()), recursive = TRUE)`:
  `list.files()` returns bare names, so it deletes those names in the working directory, not in the temporary one.
- `CalcThresholds` warns that `GaussianQt` "will be set to 1.96" but never sets it, so the limits stay NA.
- `Process_TripPositions` refers to an undefined `trip.path.w.heading` on one branch (line 167), hidden from R CMD check
  by `globalVariables()`.
- `Calc_VesselFE`'s fishing days count the dates of every segment, fishing or not, and its gear join drops trips with
  no nets.
- `Spatialize_FE` gives a ping the time since the previous one in input order, with no cap and no sort.
- `Sacrois2Eflalo` joins inner throughout and drops species coded NA, so kilograms can be lost without a message.
- `Detect_DanishSeineOperations`: a slow cluster in harbour makes the whole trip "fishing", and its DBSCAN radius is
  0.001 in degrees.
- `Retrieve_SettingOperations` is not one to one: a setting pass can serve several nets, and one net with no
  candidate widens the buffer for all.
- `match_Obs2Pos` leaves unmatched fixes NA, so "not observed" is not told apart from "observed, not fishing".
- Headings are `atan2(dy, dx)`, counter-clockwise from grid east, averaged and differenced linearly.

## What this changes

- `curate/issues/iapesca.yml` records the new home and the outcome of each issue.
- `docs/one_flow.qmd`, "What exists, and where": the iapesca entries now read the live package; three wish-list rows
  name what it has (static-gear effort, days at sea and fishing days, observer operations on fixes).
- Not done, for the maintainer: whether ramb's trip method and set finder follow iapesca 1.3, and ramb's reference to
  the GitHub copy (`R/trip.R`); whether and how the six drafted issues are sent to iapesca's author.
