# 093 — The trail's `fishing` tests the ±10 min median speed

*2026-10-14. The maintainer's choice, made after asking whether the speed-range work beats the status quo. Built
and dry-run by Claude (AI-assisted). ramb 2026.10.14.5 (b32070a), committed, installed and pushed. The trail was
rebuilt the same day on the maintainer's go (below). Closes TODO 61.*

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
  whether the track's boundary beats the declared one. Whether it serves as a check meanwhile is open (TODO 60).

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

## The rebuild (maintainer's go, 2026-10-14)

`ais_trail` was invalidated by hand and rebuilt with `tar_make_isolated()` at fishycode 694b17d, with ramb
2026.10.14.5. It took 24 min, and the two trail checks followed it. The logs, fingerprints and scripts are in
`$FISHYDATA/archive/2026-10-todo61/`.

- **Fingerprints** (847 files): only `fishing` changed, in 226 of the 227 month files of the trail and of
  `trail_match`. Every other column and file is identical, and so are the row counts (566,714,976 fixes,
  186,003,233 matches). `tar_outdated()` is empty afterwards.
- **`fishing`**: 106,345,578 fixes before, 110,432,906 after (+3.8 %).

  | gear class | fixes in a window | fishing before | after | change |
  |---|---|---|---|---|
  | towed | 62,991,773 | 52,827,801 | 54,929,757 | +4.0 % |
  | static | 54,141,628 | 34,049,061 | 35,537,795 | +4.4 % |
  | jigged | 37,294,252 | 16,984,276 | 17,485,158 | +2.9 % |

  Towed fixes in any window (day windows included) called fishing, by year: 2015-2019 86-87 → 89.5-90.4 %;
  2023-2025 about 89.5 → 93 %; 2007-2012 80-83 → 82-85 %; 2021 71.7 → 74.1 %. This is a wider measure than decision
  090's Q1 (single-station recorded windows only), so the two are not compared.
- **The trail and `trail_match` agree on `fishing` wherever the gear has a speed range.** They differ on 567
  single-match fixes, all in day windows of gear class `other`, which has no range (8 vessels, mostly 2007-2011).
  There `rb_assign_fishing()` gives FALSE and `rb_link_record_pings()` NA, as each documents. The difference
  does not depend on speed and predates this change.
- `docs/ais_trail.qmd` renders: its proof recomputes `fishing` from the windows and the ±10 min speed, fix by fix.
