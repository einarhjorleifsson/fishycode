# 274 — Plan 060: STK's VMS pings on one clock by their receipt; every target of the main project from raw, then two rebuilds from the tag pass, for the copies and for STK's outages; TODO 180 closed

*2026-11-02. Plan 060 (TODO 180). The maintainer's choices: asks a-h "as recommended" (2026-11-01), h added by Claude:
"Every target from raw"; on step 1's numbers, the persistent rule and no receipt lag for STK's own units: "proceed"
(2026-11-02); "Yes, push ramb"; "run the rebuild without my go - just make sure the computer does not fall asleep"; on
the copies the rebuild found: "Fix now"; the maintainer's question "How do i know that you are not just halucinatin
regards the time fix?", answered by a check from the raw data; on STK's outages it found: "Fix it, rebuild". Run,
measured and written by Claude (AI); the numbers come from its runs, and no person has checked them. Everything is in
four folders under `$FISHYDATA/archive/`: `2026-11-01-vms-clock-scan/` (the method; README "Plan 060 step 1" and "step
3"), `2026-11-02-plan060-rebuild/` (the full rebuild), `2026-11-02-plan060-fix/` (the copies, and the check by hand) and
`2026-11-02-plan060-outage/` (STK's outages).*

## What step 1 measured

STK keeps two times for each VMS report: the unit's own (`posdate`) and its receipt (`recdate`). Joined to the AIS track
in every year, 2007-2026 (the study, scripts 06-12):

- A report stamped at its receipt is on the track (median shift 0.0 min every year). Most VMS units stamp their own
  time, in every year.
- Per vessel-month, the receipt gap less the stream's baseline agrees with the track's shift within 3 min in 40 of 42
  hour-off months, 289 of 296 minute-off months and 5,042 of 5,271 on-time months. It also reads the clocks where no
  AIS track is: 78-134 vessel-months a year over 3 min in 2007-2009, which the scan could not judge.
- Moving every own-stamped ping by its unit's day level is 1-4 points worse than no lag in 2018-2026, since a slow day
  of delivery looks like a clock. The persistent rule moves a ping by its own level only where the unit's day level and
  its week level both depart from the stream's usual level by over 2 min; elsewhere the stream's usual lag (about a
  minute). Within 3 min of the track: hour-off months 1 % → 92.6 %, minute-off 12.9 → 94.5 %, on-time 91.6 → 93.2 %.
- The usual level found from the receipts alone equals the track's, so the track gives only the usual lag (60-69 s,
  2009 30 s).
- STK's own units' gaps are delivery, not clock: a receipt lag would move them off the track (2020: 91.3 → 35.8 % within
  3 min). They get none (ask d).

## What was built

- **ramb**, pushed and installed from GitHub on 2026-11-02:
  - 2026.11.02 (8bfffce): `rb_add_ping_own_lag(method = "receipt")`, the persistent rule;
    `rb_create_ping_lags(method = "track")`, a sparse stream placed on the reference's moving track (the study's scan),
    no recorded speed needed; step 0's order guarded by warnings; `rb_flag_ping_invalid(rules = "after_receipt")`,
    opt-in and not used here; a fault track for the tests.
  - 2026.11.02.1 (8d728ba): with `"copy"` and `"receipt"`, a copy of a reference ping the receipt moves takes that lag
    too, and stays a duplicate of it.
  - 2026.11.02.2 (15af6e8): `mass_share = 0.5`, a receipt hour that flushes a backlog counts in no unit's level.
- **fishycode** (475dc92, 5f522e0):
  - `curate/ais_ping_union.R`: the de-duplication explicit and counted (`staging/ais/ping_union_copies.parquet`); STK's
    receipt and unit of each VMS ping in `staging/ais/stk_receipt` (decision 196's side table, its receipt part).
  - `curate/checks/ais_feed_clock.R`: STK's VMS stream measured by the track method, and its usual lag by year
    (`curated/check/ais_feed_clock_usual.parquet`).
  - `curate/ais_ping_tag.R`: the receipt method for STK's VMS stream; `lag_basis` `receipt`.
  - `curate/checks/ais_vms_track.R`, target `check_ais_vms_track`: the VMS pings against the AIS track by vessel-week,
    on the delivered and the harmonized times, on STK's AIS stream and, since 5f522e0, on PAME's astd (`astd_outcome`).

## The runs

**The full rebuild** (`2026-11-02-plan060-rebuild/`). 171 targets, every target of the main project less `ais_catch` and
`check_allocation_audit` (decision 261), 1,300 output files (7.5 billion rows) fingerprinted. `build.sh` ran
07:10:34-09:35:56 at 475dc92, ramb 2026.11.02, DuckDB 1.5.6, under `caffeinate`, with no stop (2 h 25 min). The `once`
project was not touched. Every changed file outside the AIS chain explained (`scripts/changed_columns.R`).

**The copies** (`2026-11-02-plan060-fix/`). The full rebuild put 733 astd and emodnet pings with `lag_basis` `copy` in
the trail (decision 271: none). Each copies an STK VMS report: the copy took its original's delivered time, the receipt
rule then moved the original (732) or its stream's measured lag did (1), and the duplicate flag no longer paired them.
ramb 2026.11.02.1; 19 targets from `ais_ping_tag` down, 10:57:36-12:30:04 (1 h 32 min). The trail's copies 733 → 1;
732 to duplicate; 14 neighbouring pings changed the clean's stage; the trail 580,681,053 → 580,680,326 fixes; every
changed file explained.

**Found on the store: STK's outages.** The VMS track check put 2026 at 0 → 14 off-track vessel-weeks. Checked by hand
from STK's raw dump and PAME's astd at the maintainer's question (`2026-11-02-plan060-fix/notes/verify_by_hand.R`):

- On 2026-01-13..15 and 2026-10-11..13 every unit's receipt gap, VMS and AIS alike, is 6 h to 2 days: STK took the
  reports in late and all at once (also 2026-05-11..12). Some came in dated a day late, VMS and STK's AIS together, some
  received before their own time. On 2026-05-21 a slowdown of 15-60 min.
- The rule leaves gaps over 3 h out of a level, so the gaps left, the end of the backlog and the misdated reports, were
  all an on-time unit's level had. For vid 2173, 24 reports of 14-15 January steaming north: astd heard the vessel at
  each place within 5 min of the report's own time (23 of 24); the rule moved all 24 by 85 min, and the clean took them
  out as impossible jumps. In 2026: 1,900 VMS pings moved by over 20 min in the outage weeks, 1,473 left in the trail so
  moved, 427 taken out.
- STK's AIS stream came through the outage with the VMS reports, so there the check's "on track" compared two of STK's
  streams agreeing on a wrong time. astd is the witness outside STK.
- The study had left "mass-delivery days" out of the levels (`2026-11-01-vms-clock-scan/scripts/09_receipt_variants.R`);
  ramb's version of the rule had dropped them.

My first account of it, a delivery delay shared by the units, was wrong in kind: the check from the raw data showed
outages, and the moved pings of vid 2173 taken out of the trail rather than misplaced in it.

**STK's outages** (`2026-11-02-plan060-outage/`). ramb 2026.11.02.2: a receipt hour in which half or more of the stream's
pings came in over 3 h late (64 hours in 2007-2026, 19 of them in 2026) counts in no level. Every year 2007-2026 before
the release (`notes/mass_guard.R`): with the guard off the rule equals the store on all 4,030,711 receipt pings; on, it
changes 11,575 (10,868 in 2026; 707 in 2007-2022, none of them moved over 20 min), moves 1,911 → 75 of 2026's by over
20 min, and the changed vessel-weeks off the track by over 3 min go from 8 to 0 of 49 on astd's track and 14 to 0 of 75
on STK's AIS stream. 19 targets from `ais_ping_tag` down, 15:16:18-16:50:20 at 5f522e0 (1 h 34 min, no stop). 74 files
changed, 684 unchanged: the years whose lags the guard changed (2007-2009, 2016, 2022, 2026), the port calls, voyages,
trips' times and the checks downstream; 809 rows of 2025's clean moved between two of its files, the year's rows and
their summed hash the same. Only 2026's trail changed: 23,562,481 → 23,562,684 fixes, fishing hours −3.7 h and
`fishing_flow` +1.0 h. The clean keeps 323 more of STK's VMS pings in 2026 (vmask 954 → 616) and 116 fewer of astd's
(33 more duplicates of a VMS report, 74 more vmask). The effort grids pass (`products.sh`).

**Stamps** (added 2026-11-02 by another Claude session; the maintainer: "Record them"). Of the 608 files this run
wrote, 51 carry `fd.dirty = true` at 5f522e0: `ais/trail` partitions built by `curate/ais_trail.R` from 16:29:24 to
16:37:10. In those minutes another session rendered the whole book in `docs/` (16:29:08 to about 16:37), and the
render's intermediate files made the tree dirty. The pipeline reads none of them, so these files are what a clean tree
gives. The other 557, from 15:29 to 16:50, are clean. Their stamps say dirty until the next build from a clean tree, as
decision 218 left its own.

## STK's VMS stream in the store

In the trail, 4,021,863 pings:

| `lag_basis` | pings | moved | by over 3 min |
|---|---|---|---|
| `receipt` | 4,004,056 | 2,989,299 | 491,282 |
| `measured` (its vessel-month's lag, the clock check) | 4,499 | 4,499 | 6 |
| `none` | 6,821 | 0 | 0 |
| `unmeasured` | 6,487 | 0 | |

A ping off `receipt` is one whose unit has no level, its gaps around all over 3 h late or in a flushed backlog: 15,246
of the 17,807 in 2026's outages. 75 of 2026's are moved by over 20 min (69 in the trail), against 1,911 before the guard.

`check_ais_vms_track`, vessel-weeks off the track by over 3 min:

| track | judged | delivered times | harmonized times |
|---|---|---|---|
| STK's AIS stream, 2007-2026 | 4,084 | 399 | 30 |
| astd, 2013-2026 | 8,403 | 76 | 35 |

2026: 0 of 277 on STK's AIS stream and 0 of 223 on astd's track. The 30 are in 2007-2024, 6 of them in 2017.

## Before and after

Plan 059's store (decision 271) against the store now: the trail 580,659,851 → 580,680,529 fixes (+20,678), hours
fishing +0.020 % and `fishing_flow` −0.002 %, every year within ±0.2 % (2007 +0.18 %, the most). The clean keeps 23,635
more of STK's pings (vmask −12,547, forward −11,012), STK's VMS stream in the trail 4,000,957 → 4,021,863, and 2,929
fewer of astd's (4,147 more duplicates: copies on STK's time). STK's VMS stream was `unmeasured` 3,542,795, `none`
452,093 and `measured` 6,069 (1,986 by over 3 min). Every changed file is explained in the three folders' after-checks
and `scripts/changed_columns.R`.

## What closes

TODO 180, deleted. `curate/corrections/stk_vms_clock.yml` repaired. Plan 060 executed.

## Left

- The copy of a VMS ping moved by its stream's measured lag (1 in the trail): `rb_add_ping_time()` sets that lag and
  cannot see copies.
- STK's reports dated a day late in its outages, VMS and STK's AIS together: 6 of vid 2173's on 15 January at places
  astd heard the vessel a day before; 307 VMS reports of 2026 received over 10 min before their own time in a flushed
  hour, none before 2026. No rule here sees them where both of STK's streams agree. TODO 182.
- 2026-05-21's slowdown of 15-60 min, under 3 h and so no flush: its moves are in vessel-weeks neither track judges.
- The 30 and 35 vessel-weeks still off the track, listed by the check, not moved otherwise (plan 060 §4).
- Two run-to-run ties found by the full rebuild (`scripts/determinism.sh`): the afli_sent adapter's `fishing_sample`
  pairs its values differently between two runs on the same inputs (3,006 rows); the clock check orders the merged
  track by time and position, where up to 11,570 pairs a year from two providers tie. TODO 139's kind.
