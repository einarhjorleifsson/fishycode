# 331 — The gear of a fix that several stations claim: filled when they all have the same

*2026-11-19. Found by Claude (AI) on the maintainer's question why ogisdata's effort map has missing gid; the place of
the fix the maintainer's choice ("In the trail"), the code and its test Claude's; no person has checked it. Amends
decision 085's rule. The trail is not yet rebuilt with it (TODO 206).*

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

## Not done

The rebuild (TODO 206): `targets` cannot see an edit in `R/`, so `ais_trail` is invalidated by hand after the
fingerprints, then the grids, `cells.R` and ogisdata. In `cells.parquet` the hours with no `gid` should fall from
281,037 to about 840, the fixes whose stations have two gears.
