# 102 — The catch table rebuilt: landings on their voyages, the raising factor, and four defects

*2026-10-14. Built and measured by Claude (AI-assisted); plan 013 items 2 and 5, in fishycode. `curated/ais/catch`
rebuilt with ramb 2026.10.14.14. The trail was not rebuilt.*

## What changed in `curate/ais_catch.R`

- **Landings with no logbook trip are linked to the voyages they ended** (item 5), with
  `ramb::rb_link_trip_landings()`. It tries same day and port first, then looser steps, then the vessel's next
  landing within 14 days.
  - Those voyages are the landing's unit (resolution `landing_trip`).
  - A landing it cannot link keeps the period since the vessel's previous landing (`landing`).
- **`raise_factor`** (item 2) is on the logbook's rows: the trip's landed weight of the species over its logged
  weight, through `lid_map`. The raised catch is kg × raise_factor; nothing is overwritten.
- **Each year is shared in four vessel groups** (vid modulo 4), one part file each. A vessel's units, fixes and
  landings are its own, so the groups are independent.
- **Two kilogram checks.** Kilograms out must equal kilograms in per group and approach. The groups together must
  equal the year, so no catch is tied to no event.

## rb_link_trip_landings() against lid_map (the same data, read-only)

Run on all logbook trips and landings from 2007-09, with the five date and port steps of `lid_map`:

| | trips | share |
|---|---|---|
| same landing as `lid_map` | 780,770 | 98.7 % |
| only in `lid_map` | 9,375 | 1.2 % |
| only in ramb | 1,072 | 0.1 % |
| a different landing | 60 | 0.0 % |

"Only in `lid_map`" is mostly its own date and port steps 01-05 (8,815), where ramb's rule that a pair be the sole
candidate both ways declined, or where the port codes differ (`lid_map` compares the source codes `hid`, ramb the
port `pid`). The rest is its Iceland-specific weight and expected-date steps (560), which stay in fishycode.
`lid_map` remains the preprocessing match; ramb's function serves the flow side.

## Defects found on the way

1. **A NULL-dropping filter.** `!(twin %in% "duplicate")` becomes `NOT (twin IN ('duplicate'))` in SQL, which is
   NULL for every trip with no twin value.
   - It dropped most logbook trips as units in the first build of this table (decision 101), and in decision
     100's June check.
   - So catch with no fishing fix in its own record went to the vessel's month instead of its trip.
   - Now written `is.na(twin) | twin != "duplicate"`. No other script in the repo had it.
2. **An event in two units.**
   - `rb_build_catch_units()` started a dateless event at the vessel's "previous" event by an order with ties: two
     landings in a day.
   - It also evaluated its islands twice, so a tie decided differently each time put one event in two units, and
     its catch was counted twice: 1,751 t too many in 2007.
   - The script's kilograms check stopped the build.
   - Fixed in ramb 2026.10.14.14: the previous event is the latest ending strictly earlier, so same-day landings
     share a unit; the islands are computed once.
   - The script now also stops if any event is in two units.
3. **Memory.**
   - With DuckDB's default cap the build ran out of memory in 2015, as each year left temporary tables behind.
   - With a 12 GB cap and those tables dropped, it still ran out in 2008, and 2017 failed even at 14 GB.
   - Sharing in vessel groups brings 2017 down to a 10 GB peak.
4. **Two lazy results could not be unioned** (ramb 2026.10.14.9, decision 101).

## The rebuilt table, 2008–2025

Kilograms in equal kilograms out in every year, group and approach. 6.7 GB, 2007–2026.

- Approach totals are as in decision 101; placement changed.
  - Under `fishing_flow`, landings with no logbook trip put 3,526 kt on fixes.
  - Logbook catch kept with basis `none` is 63 kt.
- Catch moved up a level (`fishing_flow`, placed on fixes; the paths of 5 kt or more):

  | from | to | kt |
  |---|---|---|
  | logbook record (tow, haul+set, set, day) | its trip | 469 |
  | logbook record | a landing's unit | 41 |
  | logbook record | the vessel's month | 67 |
  | landing, linked to its voyages | the vessel's month (the voyages have no fishing fix) | 388 |
  | landing, period since the previous | the vessel's month | 44 |

- `raise_factor`:
  - It covers 88.8 % of the logbook's kilograms. Its median is 1.00, and 90 % of values lie between 0.59 and 1.78.
  - 688,292 rows have a factor above 10. Read later the same day (decisions 103, 104): not units. For the pelagic
    species they are trips that landed what another vessel caught (transhipment); for the others, small logged
    weights. A difference between logbook and landing is information, not an error (maintainer).
