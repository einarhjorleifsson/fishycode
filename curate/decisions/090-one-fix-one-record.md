# 090 — One fix, at most one record: the multi-link census and the TODO 56 exploration

*2026-10-14. Measured by Claude (AI-assisted) on the maintainer's request (TODO 56, plan 013 phase 4). The invariant,
its scope and the shared-fix rule are the maintainer's (2026-10-14). Read-only: nothing in ramb, the targets or
`$FISHYDATA` changed. Closes TODO 56; the builds are TODOs 57-60.*

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

The numbers are in plan 013 phase 4 ("Measured").

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

The scripts that produced these numbers were run in the session scratchpad, not kept in the repo.
