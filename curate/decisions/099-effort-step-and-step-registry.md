# 099 — Effort per ping, and the step registry's skeleton

*2026-10-14. Built and measured by Claude (AI-assisted) on the maintainer's go; plan 013, items 0 and 1. ramb
2026.10.14.6. Nothing in fishycode calls it yet, and no data were rebuilt.*

## What was built (ramb)

- **`rb_assign_effort()`**, step 5.
  - Every ping gets the time it stands for (`hours`): the interval to the vessel's next ping, or since its
    previous one.
  - Intervals over `max_interval_s` (2 h) are capped or dropped, and those under `min_interval_s` dropped. `by`
    keeps an interval inside a voyage.
  - `kw_hours` takes the engine power from a vessel table or from the pings.
  - `pressure` is the swept area (km²) where a towed gear's width is given.
  - `interval_flag` marks capped, dropped and edge pings. `effort_basis` is `derived`, or `none` where there are
    no hours.
  - It is computed for every ping, fishing or not: the approaches to "is it fishing?" stand side by side as
    columns (plan 013, rethink 1), and a summary picks one by filtering on its column.
  - Without engine power or width, those columns are `NA`, so the output has the same columns at every data
    resolution. Static-gear pressure (quantity × soak) is not built (plan 013, item 8).
- **The step registry's skeleton** (`R/registry.R`, internal; plan 013, "robustness to misuse").
  - One row per step function: its stage, its kind (step, builder or tool), its main input, the columns it needs
    and adds, and the step before it. There are 26 rows, so every export named `rb_<verb>_<stage>` has one.
  - `.rb_check_input()` checks a step's input against its row: the needed columns under the user's names, their
    types (a lazy table by its schema only), and, on request, that the step has not already run (its own columns
    are not there yet).
  - It stops with a message that names the missing column and, where a step adds it, that step.
  - Only `rb_assign_effort()` calls it so far. The other functions are retrofitted one by one (plan 013, item 0).

ramb's tests: 96 pass (two new files, `test-effort.R` and `test-registry.R`, with three message snapshots); a data
frame and a lazy table give the same effort.

## Checked on the Icelandic data (June 2023, read-only)

`rb_assign_effort(by = "voyage")` on the month's trail (3.29 M fixes) with engine power from
`curated/vessel/vessel.parquet` ran in 0.4 s, lazily.

- **Its hours equal an independent SQL sum** of the same capped intervals: 521,717 h either way (the difference is
  6 × 10⁻⁸ h).
- **Its fishing hours sit inside the recorded windows at the rates decision 090 measured for fixes.** These are
  the hours of fixes the trail calls fishing, over the hours of the month's recorded windows (sets left out):

  | gear class | fishing hours | window hours | ratio | decision 090, in-window share called fishing |
  |---|---|---|---|---|
  | towed | 13,563 | 16,233 | 0.84 | 93 % |
  | static | 5,815 | 7,071 | 0.82 | 90 % |
  | jigging | 32,860 | 53,535 | 0.61 | 63 % |

  The towed and static ratios are lower than decision 090's shares because windows with no fix (records whose
  vessel has no AIS that day) count in the denominator, and the month's edges cut intervals.
- Every fishing hour has an engine power. 1.5 % of the fixes had a capped interval and 0.4 % were at a group's edge.

## What is not done

- fishycode does not call it. The trail has no interval on its AIS fixes (`dt_sec` is filled only for the logger
  fixes, plan 013's paths table), so wiring effort in means the trail rebuild that items 1–3 share.
- Gear width (plan 015, choice d) is not an input yet, so `pressure` is empty for the Icelandic data.
- The other step functions do not check against the registry yet.
