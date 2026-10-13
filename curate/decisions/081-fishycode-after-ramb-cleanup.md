# 081 — fishycode after ramb's 2026-10-11/12 cleanup: call sites, shims, and what the review found in ramb

*2026-10-13. Review and edits by Claude (AI-assisted), on the maintainer's request to review the ramb changes and
fishycode in their light. ramb f6faf9b (the build of decision 079) → 63ec2d0 (reviewed) → e79e77b, version
2026.10.13 (fixed here, pushed, installed). The fishycode tree was
2835b83 plus the uncommitted edits the ramb sessions of 2026-10-11/12 left here (the shims, `astd_iseez.R`,
decision 080, `curate/ramb-articles/`).*

## How it was checked

- Every ramb reference in fishycode's R, qmd and Rmd files was parsed and checked against the installed ramb:
  whether the function is exported, and whether its named arguments are in the formals. Each call was also
  matched against the old formals, to catch positional shifts.
- Every ramb function fishycode reaches, directly or through helpers, was compared as code between f6faf9b and
  HEAD. Bodies were deparsed and single-statement braces stripped, so the `air format` normalisation drops out.

## What changed for fishycode

- **Code-identical to f6faf9b:** steps 1, 2 and 4 as fishycode calls them (`rb_find_trip_stays`,
  `rb_cut_trip_voyages` with `"stays"`, `rb_assign_trip`, `rb_link_trip_voyages`, `rb_flag_ping_port`,
  `rb_flag_ping_invalid`, `rb_limit_record_duration`, `rb_build_record_windows`, `rb_link_record_pings`,
  `rb_assign_record`, `rb_assign_fishing`), and also `rb_interpolate_track`, `rb_fill_gear_width` and the MFRI
  readers. A rebuild now would take no change from ramb except the emodnet speed (decision 080).
- **Renames only:** the ping filters, now internal engines behind `rb_flag_ping_impossible()` and
  `rb_flag_ping_duplicate()` (their superseded warnings removed), and the helpers of `rb_classify_mmsi()` and
  `rb_cap_outliers()`.
- **Behaviour:** the `rb_calc_speed()` default (decision 080). `rb_cap_outliers(method = "winsorize")` no longer
  turns a vector with an `NA` all-`NA`; `products/exports/buseful_2025-05-05.R` caps `effort` this way.

## Call sites fixed

- `products/ices_vms_datacall/build.R`: `rb_encode_ices_rectangle(safe = FALSE)` → `snap_to_midpoint = FALSE`.
  The old call errored with "unused argument", so the datacall build would have stopped there.
- `curate/ais_ping_clean.R`: `rb_flag_ping_duplicate(n = DUP_K)` → `n_neighbours = DUP_K`. It still ran
  through R's partial argument matching, and the values are the same, so there is nothing to rebuild.
- `rb_plot_trail(no_lines = FALSE)` → `path = TRUE`: `curate/ais_voyage.R` (inside `if (FALSE)`), and four
  times in `docs/stk_data-inspection.qmd`.
- `docs/stk_data-inspection.qmd`: `rb_whack_fwdbwd()`, which no longer exists, →
  `rb_flag_ping_impossible(method = "fwdbwd")`, with `whack = !is.na(ping_flag)`. The page was frozen, so the
  site still rendered, but any edit would have re-run it into the error. Both edited pages (and `ais_trail.qmd`) render clean, 2026-10-13.
- Names in prose: `docs/ais_trail.qmd` (`rb_whack_clean`) and `docs/one_flow.qmd` (`rb_share_catch` is built).
- `curate/ais_ping_union.R`: the speed method is named (decision 080).

**Left as they are:**

- `products/exports/astd_iseez.R`: the 2026-10-11 session replaced `ramb::rb_trip()` by a local `trip_runs()`,
  checked to be the old body verbatim. It is not a fork in AGENTS.md's sense, because `rb_trip()` no longer
  exists. Moving to `rb_cut_trip_voyages(method = "runs")` would mean rebuilding the script around a voyage
  table, and the script reads Oracle, so the result could not be compared here.
- `curate/ramb-articles/`: six unevaluated sketches, moved out of ramb on 2026-10-11 and never committed
  here. They call functions that are gone (`rb_interval_id2`, `rb_kn2ms`, `rb_read_trails`) and `YEARS =`.
  **Deleted 2026-10-13** at the maintainer's request. None belongs in ramb: two are MFRI Oracle workflows
  sourcing a credentials file, superseded by fishycode itself; the interpolation sketch is covered by
  `rb_cut_trip_voyages("jepol")`, `rb_interpolate_track()` and a decision-078 pickup; the machine-learning toy
  is upstream in WKSSFGEO, and models belong in fishymodel. All six are byte-identical in ramb's history at
  7fcebcd~1. The one pointer worth keeping, a gillnet dataset, is in plan 013.
- `docs/project-review.qmd` reviews the old `logbooks` repo; its `rb_whack_fwdbwd` row describes that repo.

## The shims were checked against the functions they replace

The 2026-10-11 session gave twelve evaluation scripts in `curate/checks/` adapters (`whack_shims.R`) over
`rb_flag_ping_impossible()`, and left the scripts themselves unchanged. To check them, the calls the scripts make
were run on June 2023 of `staging/ais/ping_tagged` (3,334,950 pings, 1,522 vessels): ramb f6faf9b from a
temporary library against HEAD with the shims.

- `forward` and `fwdbwd` on a data frame: identical.
- `clean` (two settings), `sda`, and `clean` on a lazy table: identical once the 8,646 rows that share a
  (vid, time) are put in one order.
- `fwdbwd` on a lazy table (the SQL branch, which the shim calls directly) differs by one same-second pair:
  1,700 flags old, 1,698 new. The shim is not the cause. The SQL orders its window by `time` alone, so pings in
  the same second take an arbitrary order: four runs of HEAD on the same input gave 1,699, 1,700, 1,701 and
  1,699. Production does not use this branch: `rb_flag_ping_impossible()` on a lazy table orders by
  (time, lon, lat), and gave the same counts in three runs.

The shims keep the evaluation records runnable. They reach into `ramb:::.rb_whack_fwdbwd`, an internal, which
fails loudly if ramb renames it.

## Fixed in ramb (2026-10-13, at the maintainer's request)

The first four were found by reading and running the code. The maintainer then asked for them fixed, for a
look for anything else done wrong, and for older behaviour to come back where the data say so. Six commits on
63ec2d0, each with a NEWS.md bullet and a test that fails on the old code, then the version bump e79e77b
(2026.10.13), pushed 2026-10-13 (63ec2d0..e79e77b) and installed: 77 tests, 258 expectations, 0 failures;
`R CMD check` 0 errors, 0 notes, the one known toolchain warning.

1. **52ecbfa.** `NEWS.md` had carried unresolved stash-conflict markers since c0d71d0. The distance and jepol
   bullets below them had lost their heading. The speed-shift figure there, "about 0.1-0.3 % at Icelandic
   latitudes", is now 0.24-0.40 %, always downward (decision 080).
2. **efa472e.** `rb_cap_outliers(method = "miller")` tested `exists("limit")`, which also searches enclosing
   environments: with `limit <- 0.5` in the global environment it capped c(1, 2, 3) to 0.5 0.5 0.5. Each
   branch now returns, and the caps are identical to before on 20,000 random vectors.
3. **d0fba61.** The `forward`, `fwdbwd` and `sequential` filters sorted by (vid, time) only, and the
   `fwdbwd` SQL ordered its window by time only. Reshuffling June 2023 changed 22-25 `forward` flags and 1-4
   `fwdbwd` flags; the lazy SQL gave 1,698-1,701. Now lon and lat break the tie, as `sda` always did: 0
   changed flags, and the SQL gives 1,697 every run. fishycode's production chain (`clean`) gives identical
   flags on every ping with the old and the fixed ramb. The only order effect left is which of two
   byte-identical rows gets `vmask` and which `spike`.
4. **fee889a.** `rb_cut_trip_voyages(method = "jepol")` overwrote a last-ping departure with an arrival, a
   defect inherited unchanged from DTU Aqua's `define_trips()`. A voyage was then recycled across the port
   stay, or the whole call stopped ("departures and arrivals do not pair"). 791 of the 34,286 Icelandic
   vessel-years with port pings end on a departure, and 2023 stopped at vessel 1542. 2023 now runs in 0.7 min:
   106,890 voyages, none overlapping. `dansk` has no such vessel, so its pinned fixture is unchanged.
5. **0ffd416.** The named vector form of `rb_calc_distance()` fell back on the data-frame default
   `lon1 = lon` when `lon1` was left out. A global `lon <- 5` then gave 1,258,560 m instead of an error. All
   four coordinates are now required.
6. **b225b37.** `rb_calc_speed()` and `rb_calc_step_acceleration()` are geodesic by default again, as before
   2026-10-12, on the measurement against recorded speed over ground in decision 080.

**Not changed, for the maintainer:**

- The version had stayed at 2026.10.08.1 through a week of hard renames and removals, so the old and the new
  build both reported 2026.10.8.1. It is 2026.10.13 now (e79e77b, at the maintainer's request); a bump at each
  breaking change would let fishycode state a minimum version.
- `rb_summarise_track()` was renamed on 2026-10-12 to output `n_harbours` (it counts `hid`), three days
  after the "port, not harbour" rule.
- The jepol method warns once per vessel ("shorter than min_dur after splitting"): more than 50 warnings on
  one year. One summary warning would do.
- The `fwdbwd` SQL leaves a vessel's first or last ping NA, not FALSE, when its one leg is fast; the comment
  says "always FALSE". `curate/checks/ais_residual_whacks.R` relies on the NA, so this is a note, not a fix.
- In a run filtered to one file, the lazy-table tests error on an unregistered `dbWriteTable` S4 method;
  they pass in the full suite, which has loaded duckdb by then.
