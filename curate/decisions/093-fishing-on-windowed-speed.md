# 093 — The trail's `fishing` tests the ±10 min median speed

*2026-10-14. The maintainer's choice, made after asking whether the speed-range work beats the status quo. Built
and dry-run by Claude (AI-assisted). ramb 2026.10.14.5 (b32070a), committed and installed. The trail is not rebuilt
yet (TODO 61).*

## What was chosen, and what was not

- **Adopted: the windowed speed.** A fix in a tow, haul, jig or day window is fishing when the median of the
  vessel's fix speeds within ±10 min lies in the gear's declared `[s1, s2]`, not its own speed.
  - On all years, inside recorded windows (decision 090, Q1): towed 89.2 → 92.7 %, static 84.8 → 88.8 %,
    jigged 58.8 → 59.7 %.
  - It is one SQL window function.
  - Its cost far from the windows (−0.4 points) does not reach the trail, which tests speed only inside windows.
- **Not taken up: a vessel × gear speed range** (plan 012 §2l).
  - It gained 1-2 points of agreement with the declared tow boundaries. Agreement with the logbook is not
    accuracy (TODO 60).
  - It would add a statistics table, a fallback, an exception for Danish seine, and a loop from the flow's
    output back into its input.
  - The declared gear ranges stay.
- **The stretch pairing (decision 092) stays out of the flow.** Nothing consumes it until ground truth can say
  whether the track's boundary beats the declared one. Whether it becomes a check is open (TODO 61).

## What changed

- **ramb 2026.10.14.5:** `rb_link_record_pings()` takes `window_s`, as `rb_assign_fishing()` does since
  2026.10.14.4. Both functions share one SQL, so `trail_match` and the trail agree.
- **`R/trail_sql.R`:**
  - `trail_month_sql(window_s = 600)` reads the month's fixes with 10 min either side, from the next year's
    files at New Year;
  - it passes `window_s` to both ramb calls and cuts both tables back to the month. A fix's windowed speed so does
    not depend on the month split.
- **`curate/ais_trail.R`:** a January or December month lists the neighbouring year's ping files among its inputs.
- **Docs:** `docs/data-dict.yaml`, `docs/ais_trail.qmd` (its proof recomputes `fishing` with
  `ramb::rb_calc_speed_smooth()`) and `docs/one_flow.qmd`.

## The dry run (2023, June and January, into the scratchpad; read-only against `curated/`)

- **With `window_s = 0`**, the trail and `trail_match` equal the curated files row for row: 3,288,291 and
  656,897 rows for June, 2,391,438 and 375,393 for January. The margin and the cut change nothing else.
- **With `window_s = 600`**, every column but `fishing` is unchanged, and the trail and `trail_match` agree on
  every single-match fix. `fishing` changes as follows:

  | month | towed: to TRUE / to FALSE | static | jigged | fishing fixes before (towed) |
  |---|---|---|---|---|
  | June 2023 | 9,187 / 1,816 | 2,334 / 1,062 | 10,445 / 9,593 | 177,482 |
  | January 2023 | 9,086 / 1,633 | 4,342 / 1,497 | 266 / 97 | 212,927 |

  Jigging swaps in both directions: no speed rule serves it well (decision 090).
- **Time:** about 1 s per month for either kind, with or without the window.

Script: `$FISHYDATA/archive/2026-10-speed-range/dryrun_trail.R`.
