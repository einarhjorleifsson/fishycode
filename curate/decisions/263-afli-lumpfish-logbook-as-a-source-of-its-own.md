# 263 — afli's lumpfish logbook as a logbook source of its own: the merge's fifth tier, the vessel-day as its unit, the roe at its salting stage's factor

*2026-10-30. Plan 054 step 2d (TODO 167), plan 051 ask c option B, plan 054 ask d (built now, the lumpfish rows
provisional). Parked in the cut of the same day, then kept by the maintainer once it was done ("Yes, keep 2d"). Coded
by Claude (AI) in side sessions and checked on scratch stores, not by a person. Merged into main as 102bf8d. The draft,
scripts and traces are in `$FISHYDATA/archive/2026-10-30-plan054-link-lumpfish/`. Nothing is built on the live
store.*

## Chosen

- **`sources/afli_grasl/convert.R`** (preprocessing) stages `grasl_sokn` × `grasl_stofn`:
  - one station per row: a vessel's day in a square, with no time and no position but the square;
  - its trip is the vessel-day, the unit its catch sits on, coarser than a fix;
  - the roe as logged under 951, with its salting stage (HV 2020-33) as the condition;
  - the nets as `effort_count`, the nights as the duration, the depth kept raw (its unit is unknown).

  The barrels stay per vessel-year and are never raised to. 15 vessel-years are flagged `barrels_implausible` and 27
  `barrels_no_roe`.
- **The whole weight** is the roe ÷ the stage's factor × 100/29.4, basis `reconstructed`. The factors are provisional
  until HV 2020-33's authors answer (TODO 169).
- **The merge's fifth tier** keeps the vessel-days no other source holds. Its stations are `event`s, kept out of the
  vessel's station-type pattern.

## Checked on scratch stores

- **Every `grasl_sokn` row in one outcome:** 239,254 rows, 239,003 staged (32.0 kt of roe). Kept are 31.7 kt of roe,
  118.9 kt whole. 282 t sit on vessel-days afli holds.
- **The other sources are unchanged:** in every merge file and in `catch_by_species_station`, every row of the other
  sources is unchanged and in the same place.
- **The logbook's whole weight** goes from 51,142.7 to 51,261.6 kt. The lumpfish of the 1980s-2000s is now in the
  logbook, where the main logbook's 951 held none before the 2010s.

## Left

- **The held vessel-days.** 2,090 of the 2,097 vessel-days afli holds are another fishery of the same vessel that day,
  so their 281 t of roe drops out under the merge's rule that one source holds a vessel-day. Keeping it would break
  that rule and `lid_map`'s match by vessel-day, so the rule stands.
- **Provisional factors:** they follow the authors' answers.
- **The rest:** `docs/data-dict.yaml`, and the live build in the rebuild.
