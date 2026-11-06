# 292 — Every port call cuts the voyages: ramb 2026.11.06.3 and the rebuild from `ais_voyage` down; no voyage runs through a port, 43,831 voyages back

*2026-11-06. TODO 148, after decision 291, at the maintainer's word ("Yes both": the ramb change and the rebuild).
Built, run and counted by Claude (AI); no person has checked the code or the counts. The study, its scripts and every
table: `$FISHYDATA/archive/2026-11-06-voyage-cut/` (its README).*

## What was done

- **ramb 2026.11.06.3** (ce1e464, committed to ramb's local `main` and installed from it, not pushed):
  `rb_create_voyages(method = "dwell")` cut the track into runs by the port call each ping fell in, so a port call no
  ping fell in cut nothing (decision 291). A port call's start and end now join the pings as its own rows, counted in
  no voyage's `n_pings`, so every call cuts. A call over New Year also gives the next year's first voyage its port. It
  has a test of its own, and the whole suite passes (3,157).
- **Checked on 2012 before the build** (`check_year.R`): the installed ramb gave the store's 71,555 voyages and 5,780
  calls crossed; the new one gave 76,079 and none crossed. The 67,279 voyages that crossed no call are the same, and
  most of the 4,276 that did are now split at those calls.
- **`curate/ais_voyage.R` stops under an older ramb** (78729b5).
- **Rebuilt** at 78729b5 with DuckDB 1.5.6: `ais_voyage` invalidated by hand (`targets` does not track ramb), then the
  14 targets below it, from 18:36 to 19:33. After it only `ais_catch` and `check_allocation_audit` are outdated
  (decision 261). The effort map's grids were rerun.

## What changed

Every output file against the store of decision 291: 1,324 files, 321 changed (313 under `curated/ais`), 1,003
unchanged.

| | before plan 048 | decision 291 | now |
|---|---|---|---|
| voyages | 1,428,837 | 1,370,630 | 1,414,461 |
| port calls that cut voyages, lying inside one | | 57,389 | 0 of 1,620,310 |
| fixes with a voyage | | 291,783,733 | 291,717,635 |
| fixes with the voyage's logbook trip (`.tid_voyage`) | | 211,842,341 | 216,674,340 (+2.3 %) |
| hours fishing (`fishing`) | 9,171,625 | 9,180,025 | 9,178,966 |
| hours fishing (`fishing_flow`) | 11,361,036 | 11,369,295 | 11,361,142 |
| trips with AIS times from a voyage | 846,672 | 846,001 | 843,327 |
| trips with AIS times from stations | 16,159 | 15,521 | 16,041 |

- **The voyages** are back to 14,376 (1.0 %) under the count before plan 048. The likely cause is short voyages: without
  STK's event rows, 12,678 runs at sea no longer reach the 10 pings a voyage needs (decision 291's `voyages.R`). Port
  calls lost and new also play a part. Not traced voyage by voyage.
- **The voyage's logbook trip** is on 4,831,999 more fixes: a voyage that had joined two trips had none (`.tid_voyage`
  is kept only when there is exactly one).
- **Effort**: the fixes judged fishing are the same; their hours fell by 1,059 (−0.01 %). `fishing_flow`, which takes
  the voyage's gear outside a window, has 35,550 fewer fixes and 8,153 fewer hours (−0.07 %).
- **Trips**: 2,674 fewer take their AIS times from a voyage and 520 more from stations. Not traced trip by trip. Likely
  the same short voyages: a trip whose only voyage now falls under 10 pings has none.

## What it leaves

- **Plan 048's step 6**, the event pairs before 2017 against the logbook's own dates (TODO 148).
- **Pushing** ramb (b7109d4..ce1e464 on its local `main`) and fishycode: the maintainer's.
- **The short voyages**: whether 10 recorded pings is still the right minimum now that event rows no longer count
  towards it. That is the maintainer's question, not measured here.
