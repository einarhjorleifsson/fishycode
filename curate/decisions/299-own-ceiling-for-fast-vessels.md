# 299 — Production's speed rule judges each vessel faster than 25 kn at its own ceiling

*2026-11-08. Decision 297's leftover, at the maintainer's word: "Speed rule for fast vessels" (the test on 2024) and,
on its result, "Build it". Coded, run, measured and counted by Claude (AI); no person has checked the code or the
counts. The study, its scripts and every table: `$FISHYDATA/archive/2026-11-08-fast-vessel-ceiling/` (its README).*

## Why

Decision 297 kept production's speed rule, `clean` at 25 kn, and left its wrong flags on fast vessels. Night 2 counted
97,716 pings on vessels over 25 kn that production flags and plan 069's candidate keeps. A test on 2024 gave each such
vessel its own ceiling in place of 25 kn:

- 7,570 pings came back, on 115 of 133 vessels, mostly steaming at 25-30 kn;
- 54 pings were newly flagged.

## What was built

`curate/ais_ping_clean.R` (faace97, fixed in b50eaea):

- **Each vessel's ceiling is measured over the year**, per stream, by ramb's `rb_create_ping_limits()`, in the clean
  step itself. It uses:
  - the recorded speeds;
  - the lags whose basis is `copy`, `receipt` or `measured`;
  - steps of up to 300 s.

  The result is written to `staging/ais/ping_limits/year=<y>/limits.parquet`.
- **A vessel whose ceiling is over 25 kn is judged at that ceiling.** Its ceiling is the largest of its streams', and
  it is the vessel's `kn_max` in `clean`. Every other vessel stays at 25 kn, and so does the duplicate rule.
- **The count:** 32 to 126 vessels a year are over 25 kn (2007: 44; 2024: 126).
- **A new `METHOD` re-cleans every year.** `_targets.R`'s `ais_ping_clean` produces the new folder.

## What was run

- **A night's test, 2026-11-08 09:44-11:21,** detached:
  - on a `cp -c` clone of the store as decision 298 left it;
  - with code b50eaea and ramb 2026.11.07.1.
- **The steps:**
  - the new clean step;
  - the 16 targets below it;
  - the comparison with the live store, every record in one outcome;
  - every AIS trip end moved by over 6 h, put against the logbook trip's own date.
- **The first start stopped on 2007.** `bind_rows()` read a named list as columns; fixed in b50eaea.
- **The checks:**
  - all 612 files written were stamped b50eaea, with a clean tree;
  - no live file was written during the night.
- **A mislabelled line.** `compare.R`'s summary line for the pings was written for plan 069's candidate, whose stage
  names differ. Here it counts pings that both stores flag as "production only". The counts below are from the
  study's `scripts/02_recount.R`.

## What it found

| pings, 2007-2026 | |
|---|---|
| production flags, the own ceiling keeps | 95,761 (forward 72,240; vmask 23,437; spike 84) |
| the own ceiling flags, production keeps | 695 (forward 692) |
| both flag, at another stage | 2,100 |
| that differ, on vessels at 25 kn or less | 0 |

In 2024, 7,541 came back and 51 were newly flagged. The morning's test gave 7,570 and 54: its ceilings were measured
before plan 048 and gave 133 vessels instead of 126.

**Downstream**, each row of each side in one outcome:

- **Port calls**, of 1.67 million:
  - before: 823 changed, 31 lost, 6 split;
  - after: 829 changed, 551 new, 3 merged.
- **Voyages**, of 1.60 million:
  - before: 9,716 changed, 3 lost, 472 split;
  - after: 10,661 changed, 10 new, 22 merged.
- **Links:**
  - `trip_voyage`: 3,182 changed;
  - `trip_reconciled`: 1,015 changed;
  - `station_event`: 239 changed;
  - `trip_disposition`: 68 changed;
  - `trip_landing`: none changed.
- **The trail:**
  - 95,760 fixes added and 694 lost;
  - total hours +13,718 (+0.022 %). Each fix's interval is capped at 2 h, so a ping given back inside a long gap
    splits a capped interval;
  - fishing hours −55 (−0.0006 %);
  - `fishing_flow` −62 hours.
- **The trip ends moved by over 6 h:** 29 departures and 26 returns. The logbook puts none of them on production's day:

  | where the logbook puts it | ends |
  |---|---|
  | the own ceiling's day | 41 |
  | both rules' day | 11 |
  | neither day, the own ceiling nearer | 3 |

**Not checked by hand:**

- the 551 new port calls and the changed voyages;
- the 695 newly flagged pings;
- 2024's 1,246 pings given back whose recorded speed is under 15 kn.

## What was chosen

- **The rule is in the code** (faace97, b50eaea).
- **The live store is not rebuilt yet.** The rebuild, from `ais_ping_clean` down, waits for the maintainer's word.
- **Until then, the live store applies 25 kn to every vessel.** `tar_outdated()` does not show the change, because
  targets cannot see a script edit.
