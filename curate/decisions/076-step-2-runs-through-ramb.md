# 076 — Step 2 and the window fishing method run through ramb

*2026-10-09. Plan 014 phase 2 (plan 013's phase 3), ported and checked by Claude (AI-assisted). ramb f28646d,
installed locally with `R CMD INSTALL --preclean`. It is not yet pushed to GitHub, which waits for the
maintainer's yes.*

## What moved

| ramb function | was in fishycode | fishycode now |
|---|---|---|
| `rb_limit_record_duration()` | `R/duration_limit.R` | `apply_duration_limit()` calls it and keeps `.duration_source` |
| `rb_build_record_windows()` | `curate/station_window.R` (the window SQL) | the script supplies the Icelandic base: the vessel per trip, adb's gear from the landing, and adb's `t1`/`t4` moved to `t2`/`t3` for towed gear |
| `rb_link_record_pings()`, `rb_assign_record()`, `rb_assign_fishing(method = "window")` | `R/trail_sql.R` | `trail_month_sql()` supplies the month's inputs, the voyage side and the column names (`n_sid` = `n_records`) |

`curate/ais_trail.R` now writes the month's `trail_match` first. The wide trail reads the matches back from that
file, so they are not computed twice. The gear rules are joined by the caller, not by ramb, because the adb
time swap needs the gear class first.

## Measured: exact ports

All outputs were built in scratch from today's inputs; nothing under `curated/` was written. They were compared
row by row in both directions (`EXCEPT ALL`) against the built outputs.

| Output | Rows | Differ |
|---|---|---|
| `station_window` (all) | 7,496,440 | 0; same column order |
| `apply_duration_limit()` on every fishing sample | 7,239,778 | identical (`identical()`) |
| `trail_match` 2019-06 | 1,098,145 | 0 |
| `trail` 2019-06 (186,956 gps fixes) | 4,864,265 | 0 |

ramb tests: 226 pass. The new tests compare a data frame and a lazy table for each function.

## Doubts found while porting (decision 073's rule: equality proves the port, not the logic)

- **Closed windows.** `time BETWEEN w_start AND w_end` closes both ends, so a fix exactly at a capped tow's end
  (the next tow's start) matches both stations and gets `n_sid = 2`. This is plan 013's "half-open windows" item,
  still to be counted.
- **Day windows.** In a whole-day window, `fishing` is only "speed inside the gear's range" for 24 hours,
  including steaming at trawl-like speeds. 1,585,089 of the 5,676,056 towed stations (27.9 %) have only a `day` window. This is plan
  012 / TODO 18 territory, not fixed here.

Neither is changed by the port.
