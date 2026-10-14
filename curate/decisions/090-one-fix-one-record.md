# 090 — One fix, at most one record: the multi-link census and the TODO 56 exploration

*2026-10-14. Measured by Claude (AI-assisted) on the maintainer's request (TODO 56, plan 013 phase 4). The invariant,
its scope and the shared-fix rule are the maintainer's (2026-10-14). Read-only: nothing in ramb, the targets or
`curated/` changed. Closes TODO 56; the builds are TODOs 57-60.*

## The invariant (maintainer)

A fix belongs to at most one logbook record, and to at most one phase of it. A fix linked to two records is
impossible, so the algorithm must never produce it.

- **Scope: assignments.** The wide trail (`.sid`, `phase`), `station_event`, and the voyage-wide pairing to come.
  `trail_match` stays what it is, a table of *candidate* matches (one row per fix and station).
- **When two events would share their bounding fix, the event nearer in time keeps it.** The other gets no fix
  (`time` NA), and its `gap_s` says the track cannot resolve it.
- A phase holding one fix (`t3+t4` of one haul) is one phase, so it does not break the rule.

## The census: it does happen

**Twin records** come first, because they run through everything: stations of one vessel with identical t1-t4.

| source | twin stations | what they are |
|---|---|---|
| fs_afladagbok | 7,650 | 7,021 pairs on different trips. About 2,000 trip pairs are one trip submitted twice (same dates, same vendor), 2022-2025 |
| afli | 16,763 | 8,465 pairs on one trip with the same gear (1969-2023); 1,153 pairs across trips |
| adb | 355 | 351 pairs (2026) |

**`trail_match`, all years.** 7,229,400 of the 161,326,205 fixes with a match (4.48 %) have two or more stations:
- **whole-day windows: 6,497,406 (89.9 %).** Several stations on one date with no usable times.
- **overlapping declarations: 452,179 (6.3 %).** In 196,477 of them `fishing` depends on which station is taken.
  The window rules leave these uncapped:
  - a static-gear haul and another station's set (306,087 fixes). A gillnet set (GNS) starts a median 2 h into
    the other station's declared haul; longline (LLS) hauls overlapped this way are declared as about 18 h long;
  - jig windows, which are never capped (86k fixes; median overlap 7 h);
  - two tows or hauls with the same declared start, which the capping never cuts (tow+tow: median overlap 85 min);
  - sets with the same start (8,696).
- **twin records: 279,269 (3.9 %).**
- **boundary ties: 546.** This is the closed-window double count of decision 076: negligible.

**`station_event`, all years** (3,593,240 events with a fix).
- After twins are collapsed, **62,694 fixes bound events of two operations (60,360) or two phases of one
  (2,334).** The commonest is `t2 | t3` (48,562): one fix between tow A's haul-back and tow B's shoot.
- 9,333 more fixes collide only because of twins.
- **Under the nearer-in-time rule, 64,954 claims lose their fix (1.8 %).** The losers lie a median 23-26 min from
  it, the winners 6-7 min.
- In 3,599 fixes the two claims are equally near. A tie-break is needed: the record built here gives the fix to
  the earlier event time.

## The four questions of TODO 56

The numbers are in plan 013 phase 4 ("Measured"). The answers below are from 2023 and June 2023; the next section
repeats the tests on all years.

1. **The speed window wins inside the windows.** Measured on 2023, at sea:
   - Fixes in recorded tows called fishing rise from 89.9 % (the fix's own speed) to 93.4 % at ±10 min. Static
     gear goes from 87.3 to 89.6 %.
   - Fixes ≥ 30 min from any window lose less than half a point.
   - Jig is poorly served by any speed rule (62-67 %).
2. **The voyage-wide pairing works, and exclusivity costs nothing.** June 2023, 4,237 declared tow operations:
   - The track is cut into towing-speed stretches (±10 min median). A stretch holding two declared tows is cut at
     the slowest fix between them.
   - The stretches are paired with the tows in order, exclusively.
   - 99.0 % of tows pair, with 0 breaks of the invariant.
   - Bottom trawl (OTB): start within 15/30 min for 62/77 %, end for 63/74 %. The earlier non-exclusive test had
     61/74 % and 60/71 %.
   - Danish seine (SDN) and pelagic trawl (OTM) fit badly, because one speed range does not describe their phases.
   - 30 % of towing-speed stretches hold no declared tow.
3. **`station_event` stays, made exclusive, as the declarations' anchor.** The pairing gives the track's
   boundaries. They are the two candidates that `rb_reconcile_time()` compares per event.
   - In June 2023 the exclusive rule takes the fix from 57 of 8,468 t2/t3 anchors, and the pairing still bounds
     50 of those tows.
   - The track's start is within one fix interval of the declared start for 30 % of paired tows. Which side is
     right in the other 70 % needs ground truth.
4. **No ground truth for Icelandic towed gear here.**
   - The afli GPS logger is keyed by the captain's station entry, so it is not independent of the declared times.
   - WKSSFGEO's labelled AIS marks only fishing pings for OTB.
   - The labelled Portuguese dredge and pot sets and the Irish and Italian pots (WKSSFGEO, WKSSFGEO2) suit static
     gear and `rb_link_record_sets()`.
   - The candidate is MFRI's own groundfish surveys: hired trawlers in the AIS, with tow start and end recorded by
     staff (TODO 60, maintainer).

## The same tests on all years (maintainer's request, same day)

Q1 and Q2 were rerun on every trail year (2007-2026). Q2 ran on every month, and Q3 was checked on all years. The
June 2023 answers hold where the track is dense. The wider data add four things.

- **Q1, pooled over all years** (share called fishing inside recorded windows; share called not fishing outside them):

  | gear class | in: own speed / ±10 / ±20 | ≥ 30 min out: same | < 30 min out: same |
  |---|---|---|---|
  | towed (58.5 M in) | 89.2 / 92.7 / 94.4 % | 87.2 / 86.8 / 86.2 % | 58.3 / 50.0 / 36.2 % |
  | static (30.4 M) | 84.8 / 88.8 / 90.5 % | 81.4 / 81.3 / 81.0 % | 74.1 / 73.1 / 70.9 % |
  | jigged (5.5 M) | 58.8 / 59.7 / 63.1 % | 76.5 / 76.3 / 76.0 % | 75.2 / 75.8 / 75.7 % |

  - Every year gains 1-5 points inside the towed windows and loses 0.3-0.6 far from them.
  - Next to a window the window costs twice what June 2023 showed. That does not touch the trail's `fishing`,
    which tests speed only inside windows. It is why the stretch cut needs the declared tows as its prior.
- **Q2, all years** (1,285,948 tow operations):

  | variant | paired | start within 15 / 30 min | end within 15 / 30 min | invariant breaks |
  |---|---|---|---|---|
  | own speed, no prior | 85.6 % | 39.9 / 51.0 % | 36.7 / 46.6 % | 0 |
  | ±10 min, cut at the declared tows, exclusive | 87.3 % | 46.6 / 64.7 % | 46.4 / 60.5 % | 0 |
  | the same stretches, each tow its best stretch alone | 88.3 % | 46.5 / 64.6 % | 46.2 / 60.4 % | 27,863 |

  - **Exclusivity costs nothing in agreement**, and the non-exclusive choice breaks the invariant.
  - The one cost is dredges (DRB): 83.6 % paired against 95.2 %, because one stretch holds several short declared
    tows.
  - **OTB, 2015-2025:** 98-99 % paired, start within 15/30 min for 55-60/77-80 %, end 62-68/75-80 %.
  - **Before 2012 the track is too sparse:** OTB paired 20 % in 2007, 63 % in 2008, 81 % in 2010.
  - **By source:** fs_afladagbok 96.8 % paired (start 51/74 %); afli 85.4 % (46/63 %). afli's capped tows pair
    only 50.8 %.
  - 33 % of towing-speed stretches hold no declared tow.
- **Q3, all years:** 46,399 tows (3.8 % of 1.22 M with a t2 anchor) lose a t2 or t3 anchor under the exclusive
  rule. The pairing still bounds 19,553 of them (42 %; June 2023: 50 of 57). The losses gather where the track is
  sparse, which is also where the pairing fails. The join matched some operations sharing a t2 more than once, so
  these counts are approximate.

## What is to be built (each its own TODO and its own go)

- **TODO 57, the assignments made exclusive.** In ramb:
  - `rb_link_record_events()` gets the nearer-in-time rule and a tie-break;
  - `rb_build_record_windows()` caps jig windows, caps a haul at a later set, breaks equal-start ties, and uses
    half-open windows.

  The held ramb 2026.10.14.x is reshaped before any push.
- **TODO 58, twin records.** A correction that flags them and never deletes them.
- **TODO 59, the voyage-wide pairing and the speed window in ramb.**
- **TODO 60, ground truth for towed gear.**

## Which flow sections warrant a ramb function (maintainer's request)

**Generic, so for ramb:**
- the stretch cut and the ordered, exclusive pairing (two step-2 functions, beside `rb_cut_trip_voyages` and
  `rb_link_trip_voyages`);
- a windowed speed (median over ±W) for `rb_assign_fishing()` and the stretch cut;
- a twin-record check;
- an exclusivity contract check, among plan 013's misuse checks;
- the changes to `rb_link_record_events()` and `rb_build_record_windows()` above;
- the voyage → trip side of `R/trail_sql.R` (`.tid_voyage`, `n_tid_voyage`), which belongs in `rb_assign_trip()`.

**Icelandic, so they stay in fishycode:**
- the `suspect_clock` flags and afli's derived t3;
- the speed-range table;
- the twin correction itself;
- extracting the survey tows.

The scripts, logs and per-tow results are in `$FISHYDATA/archive/2026-10-todo56/`, with a README giving the run order.
