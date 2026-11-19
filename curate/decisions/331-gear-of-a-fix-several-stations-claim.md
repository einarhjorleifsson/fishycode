# 331 — The gear of a fix that several stations claim: filled when they all have the same

*2026-11-19. Found by Claude (AI) on the maintainer's question why ogisdata's effort map has missing gid; the place of
the fix the maintainer's choice ("In the trail"), the code and its test Claude's; no person has checked it. Amends
decision 085's rule. Rebuilt the same day (below), at the maintainer's word.*

## What was found

ogisdata's `cells.parquet` (`products/effort_map/cells.R`, plan 078) has 808,592 of its 32.4 M rows with no `gid`:
281,037 of 9.1 M hours (3 %), from 2.43 M fixes, 5-9 % of the hours in 2007-2013, under 1 % in most later years.
`cells.R` takes the grid's `fishing` preset, and `grid.R` takes the gear of a fix as the trail's `gid_used`.

`R/trail_sql.R` joined `gid_used` (with `gid`, `gid_landing`, `gid_basis`) on the fix's `.sid`, and `.sid` is filled
only when one station claims the fix (decision 085). `fishing` is TRUE under several. Counted on the v0 trail and
`trail_match`: every fishing fix with no gear has `n_sid` 2-29, every one claimed by one station has its gear, and all
of them are in day windows, several date-only hauls of a vessel on one day (TODO 105), each fix's stations from one
schema. In 280,201 of the 281,037 hours (99.7 %) the stations have the same `gid_used`: the gear is known though the
station is not.

Over all 6,618,907 fixes with `n_sid` above 1, fishing or not:

| the stations agree on | fixes |
|---|---|
| `gid_used` | 6,601,079 (99.7 %) |
| `gid_used` and `gid_basis` | 6,591,713 (9,366 with one station's gear recorded, another's from the landing) |
| `gid_used`, `gear`, `gear_class` | 6,601,079 (`gear` and `gear_class` follow from it; 11,088 more agree on those two alone) |
| `gid_used`, `metier`, `target` (the last two not filled) | 6,598,074 |

## What was chosen

Two places were offered: the trail, so every reader gets the gear, or the effort grid alone. The maintainer chose
the trail.

In the wide row of `R/trail_sql.R`, a fix with no station and `n_sid` above 1 takes each gear column from the month's
`trail_match`, where every station that claims it has the same value: `gid`, `gid_landing`, `gid_used` (joined from
`curated/logbook/gear.parquet` by each match's station) and the window's `gear` and `gear_class`. `gid_basis` is filled
with `gid_used`: the stations' basis when they share one, else `reconstructed` (one station's gear recorded, another's
taken from the landing; the weaker of the two). The station's own columns (`.sid`, `.tid`, `metier`, `target`,
`target2`, `s1`, `s2`, `phase`, ...) stay NA, `trail_match` and the columns' names and types are unchanged.

`n_sid` above 1 with `gid_used` filled says the gear came from agreeing stations; no column was added for it.

## Tested

Two months built twice on the same inputs and ramb, by HEAD's `R/trail_sql.R` and the edited one (scripts in the
session's scratchpad, not kept):

| | 2008-03 | 2022-06 |
|---|---|---|
| fixes (curated, HEAD's, edited) | 473,838 | 2,769,390 |
| HEAD's run against the curated file, rows differing | 0 | 0 |
| edited against HEAD's, rows differing outside the six gear columns | 0 | 0 |
| rows changed, every one NA → value on a fix with no station and `n_sid` above 1 | 56,869 | 62,190 |
| matches per fix equal to `n_sid` (fixes with `n_sid` above 1) | 56,869 of 56,869 | 62,477 of 62,477 |
| fishing hours with no `gid_used`, HEAD's → edited | 4,034 → 0 | 3,056 → 11 |

## Who reads it

Of the trail's readers, only `products/effort_map/grid.R` reads its gear columns where `n_sid` is above 1. The checks
that read the trail's gear (`gear_speed_range.R`, `gear_speed_by_vessel.R`, `vessel_shifted_range.R`,
`vessel_speed_range_stability.R`) keep `n_sid == 1`, and the vessel overview, the catch and the exports join the gear
from `gear.parquet` by station. The user tables link the trail (v0's `ais/trail`), so they carry it once it is
rebuilt. Amended with it: `docs/ais_trail.qmd`'s column table and `curate/ais_trail.R`'s header.

## The rebuild

2026-11-19, at the maintainer's word ("Rebuild first", then "Keep, go on"), under the heavy-job lock: the five targets'
files fingerprinted, `ais_trail` invalidated, and `ais_trail`, `trip_landing`, `check_trail_agreement`,
`check_survey_tow_times` and `check_trail_sid_coverage` built by name at 82ab83c with ramb 2026.11.18.1 and DuckDB
1.5.6, 13:22-13:59 UTC; then both effort grids and `cells.R` by 14:07. Left outdated on purpose, as by decision 326:
`ais_catch`, `check_allocation_audit` (decision 261) and the place-name sessions' 17 targets. The study, its scripts
and logs: `$FISHYDATA/archive/2026-11-19-decision331-rebuild/` (its README).

- **What changed.** In the trail (577,200,075 fixes, every year's equal to its pings) the six gear columns alone, in 205
  of its 233 files; `trail_match`, the trip-landing links and the three trail checks are equal. Two files differ in
  their kilograms alone, rows equal (`check/trip_landing.parquet`, `logbook/trip_disposition.parquet`): DuckDB's sum
  of a DOUBLE is not the same from run to run (two runs of the same sum differ in 21 of 2,199,637 landings, by at most
  2.9e-11 kg), and `curate/trip_landing.R` reads the trail's `fishing` per voyage alone.
- **The effect.** 6,601,079 of the 6,618,907 fixes several stations claim have `gid_used` now, the count above. The
  fishing hours with no gear are 968 (8,091 fixes), each on a fix whose stations have two or more gears; in
  `cells.parquet` 968 of 9,102,210 hours, 281,037 before. The "about 840" written here before the rebuild was the hours
  whose *fishing* stations have two gears (835); the rule takes every station that claims the fix, and that count was
  968.
- **ramb.** 2026.11.18.1 (ea05430, installed from ramb's tree, `@none`); the trail before was built under 2026.11.09.4.
  The functions the five reach (`R/record.R`, `effort.R`, `stretch.R` in ramb) are the same in both: 2026.11.18 and
  .18.1 changed the trip and voyage steps and added `rb_flag_ping_clock_jump()`, which nothing here calls.
- **The stamps.** An Örnefni session worked in the tree during the build: four commits (acb16a4, ca4c6b8, fc6f29b,
  e0262e4: `TODO.md` and plan 074's text) and plan 074 step 12's uncommitted work (`R/curated_list.R`, new scripts and
  overrides). 48 of the trail's files, 48 of `trail_match`'s, the six small files and `cells.parquet` carry `fd.dirty`
  true (135 of the trail's did after decision 326's build), and `fd.commit` is 82ab83c or one of the four. Every script
  and function the build ran is 82ab83c's: the commits changed no code, and none of the build's scripts calls
  `R/curated_list.R`'s `cl_*` functions. Kept as written.
- **ogisdata** 2026.11.19.2 carries the new `cells.parquet` and is installed on this Mac; its ten tests pass on the
  installed package. Its README said `devtools::test()`, under which two of them always fail (they compare the
  installed package's paths with the session's); it now says to install and test the installed package. Committed in
  ogisdata 0f484c3 by the place-name session, as part of 2026.11.19.3, which adds the place names and carries these
  cells unchanged. The copy to the share is TODO 205's.

Not rebuilt: `exports/depth_effort_map_bundle/` (decision 278), made from the grids before, so without this gear.
