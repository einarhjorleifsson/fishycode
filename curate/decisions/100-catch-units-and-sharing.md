# 100 — Catch shared per catch unit, at any resolution

*2026-10-14. Built and measured by Claude (AI-assisted) on the maintainer's go; plan 013, item 2. ramb
2026.10.14.7. Nothing in fishycode calls it yet, and no data were rebuilt.*

## What was built (ramb)

- **`rb_build_catch_units()`**, a step-6 builder.
  - The events that carry catch are given as one table: record windows, trips, and landings over a trip, a week
    or a month. Each event has a `level`, 1 the finest.
  - Events of one vessel and one level whose intervals overlap, or that share a key (a record's set and haul),
    become one unit. The track cannot tell them apart.
  - A timed haul is its own unit. A day's records without times are one unit (maintainer, plan 013 item 2).
  - A landing with only a date reaches back to the vessel's previous landing (`start_filled`).
  - `match_by` keeps units apart by, for example, an ICES rectangle.
- **`rb_share_catch()`**, rewritten to the grammar (breaking; the ICES EFLALO sharing stays as
  `method = "eflalo"`).
  - Each unit's catch is shared over its fishing pings by `hours`, species by species.
  - A coarser unit's catch goes to its pings that no finer unit took, or to all of them if none is left.
  - Catch whose unit has no fishing ping moves up to the next level that overlaps it in time, then to the vessel's
    fishing pings that month. What still finds none is kept with no time and `catch_basis = "none"`.
  - So kilograms out equal kilograms in.
  - The fishing column is an argument and is named in `approach`, so each approach to fishing gets its own
    sharing (plan 013, approaches side by side).
- **The landings-only acceptance test** (plan 013) is in ramb's tests and passes. Landings per trip, per week, per
  month and since the previous landing each put every kilogram on a fishing ping inside that landing's own period.
  Its fishing column is a plain speed rule in the test until item 3 builds `rb_assign_fishing()`'s speed method.
- **A ramb defect found by that test and fixed.** A data frame whose date-times are stored as integers (as `seq()`
  makes them) was registered in DuckDB as INTEGER, and every ramb function given one failed. They now register as
  times.

ramb's tests: 102 pass.

## Checked on the Icelandic data (June 2023, read-only)

The station windows of June 2023 (duplicate twins left out) were the events. A record with any timed window was
level 1, a record with only a day window level 2, and the logbook trips level 3 (ending a day after `T2`). The
station catch was shared over the trail's fishing fixes, with effort from `rb_assign_effort(by = "voyage")`.

- **35,580,072 kg in, the same out.**
- 12,440 events made 12,321 units; 350 units hold more than one event.
- Where the catch was shared:

  | shared in | share of the catch |
  |---|---|
  | its own unit: tow / jig / haul+set / haul / day | 67.4 / 18.5 / 11.6 / 0.3 / 0.1 % |
  | moved up to the trip | 0.01 % |
  | moved up to the vessel's month | 1.6 % |
  | no fishing fix that month (`none`) | 0.4 % |

- 2.5 s for the month, lazily.

## What is not done

- **Why so little moves to the trip and so much to the month is not measured.** One reading is that those
  records' trips have no fishing fix either, so the month is the first unit with any. That has not been checked.
- **Landings are not yet events here.** That needs the landing ↔ voyage link (plan 013, item 5) and the units in one
  unit of weight, tonnes against kilograms.
- **The raising factor column** (plan 013, item 2) is not built.
- **fishycode does not call the new functions.** That waits for the trail rebuild of items 1–3.
