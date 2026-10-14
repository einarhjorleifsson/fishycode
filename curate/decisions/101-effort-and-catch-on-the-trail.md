# 101 — Effort and catch on the trail: items 1–3 wired in and rebuilt

*2026-10-14. Built, rebuilt and measured by Claude (AI-assisted) on the maintainer's go ("go for the whole thing");
plan 013 items 1–3 in fishycode. Built with ramb 2026.10.14.9. The rebuild ran with `tar_make_isolated()` on a clean
tree (commit 75b1277).*

## What changed

- **`curate/voyage_gear.R`**, a new target. It gives each voyage the gear and speed range that the track's side of
  fishing needs.
  - From its logbook trips' stations, when they share one range (`logbook`).
  - Else from the landing's main gear by weight, with lods codes mapped to the new ones (`landing`).
  - `ambiguous` where the stations differ in range, `none` where there is neither.
  - 2008–2025: about 59 % of voyages take their gear from the logbook, 12–20 % from the landing, and fewer than 300
    are ambiguous. The rest have neither, mostly vessels that land nothing (plan 013, row 6).
- **The trail gains ten columns:**
  - the voyage's gear (`gid_voyage`, `s1_voyage`, `s2_voyage`, `gear_voyage_basis`);
  - `fishing_flow` and `fishing_flow_basis`: the window, else the voyage gear's speed range
    (`rb_assign_fishing(method = c("window", "speed"))`);
  - `hours`, `kw_hours`, `interval_flag`, `effort_basis`: on every fix, whatever the approach
    (`rb_assign_effort(by = "voyage")`, capped at 2 h, kW from `vessel.parquet`). The month is read with 2 h after
    it.
  - `fishing` and every other old column are unchanged.
- **`curate/ais_catch.R`**, a new target: `curated/ais/catch/year=Y`, the catch per (fishing fix, unit, species,
  approach) (decision 100's functions).
  - The units are station windows (timed, then day), logbook trips, and every landing as an event; of the landings,
    only those with no logbook trip carry catch.
  - The catch is shared under both `fishing` and `fishing_flow`.
  - The script stops unless kilograms out equal kilograms in, per year and approach.
- **ramb found two defects on the way, both fixed and released:**
  - integer-stored date-times registered in DuckDB as INTEGER (2026.10.14.7);
  - two lazy results could not be put in one `union_all()` (2026.10.14.9).

## Verified

- **The trail kept every fix and every old value.** Fingerprints before and after (`R/fingerprint.R`): 454 files and
  752,705,594 rows either way. No file changed its row count, and of 13,620 (file, column) pairs none changed. The
  only pairs without a hash are those of an empty file (trail_match, December 2025), empty both times. Every year's
  own check passed: the fixes written equal those in `ais/ping`.
- **The checks downstream** give what they gave: window and voyage trip agree on 99.63 % of fixes, and station
  coverage is unchanged.
- **The catch:** kilograms in equal kilograms out in every year and under both approaches. 2008–2025:

  | approach | logbook, on fixes | logbook, basis none | landing, on fixes | landing, basis none |
  |---|---|---|---|---|
  | `fishing` (window) | 20,691 kt | 167 kt | 1,054 kt | 3,456 kt |
  | `fishing_flow` | 20,794 kt | 64 kt | 3,526 kt | 984 kt |

  Under the window approach a landing with no logbook trip has no fishing fix, so most of its catch has no place.
  The track's side puts 2,472 kt more of it on fixes. Most of that is foreign vessels' landings (plan 013, rows 4
  and 9).
- **The effort:** fishing hours per period.

  | period | `fishing` | `fishing_flow` | more | of `fishing_flow`, decided by speed | kWh, `fishing_flow` |
  |---|---|---|---|---|---|
  | 2008–2012 | 2.51 M h | 3.08 M h | +23 % | 18.7 % | 3.26 TWh |
  | 2013–2020 | 4.06 M h | 5.13 M h | +26 % | 20.8 % | 4.92 TWh |
  | 2021–2025 | 1.88 M h | 2.53 M h | +34 % | 25.6 % | 2.91 TWh |

  The speed side's error is known from the windows (decision 090): towed gear calls 12 % of fixes far from any
  window fishing, static gear 23 %. The extra hours are an upper reading, and the basis says which fixes carry it.
- **Size:** the trail went from 17 to 19 GB, and the catch table is 6.1 GB (70–84 M rows a year). The data volume is
  99 % full (13 GB free).

## What is not done

- **The landings with no logbook trip are not yet linked to their voyages** (plan 013, item 5). Their unit runs from
  the vessel's previous landing; the next catch build links them with `rb_link_trip_landings()`.
- **The raising column** (plan 013, item 2) is not built.
- **Pressure** is not on the trail: there is no gear width yet (plan 015, choice d).
