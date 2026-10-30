# 255 — Each app's habits flagged by the reviewed rows, and the windows that read the flags (plan 053 steps 5 and 6)

*2026-10-30. Plan 054 step 2a, plan 053 steps 5 and 6 (TODO 165). Coded by Claude (AI) in a side session and checked on
a scratch store, not by a person. The code is on main as cfc277b, and the typical-haul fix as cc5daf4. The draft, with
every table, and its traces are in `$FISHYDATA/archive/2026-10-30-plan054-step2a/`
(`draft-steps5-6-the-flags-and-the-windows.md`, `trace_files.txt`, `trace_profile_2.txt`). Nothing is built on the
live store; the change rides plan 054's rebuild A.*

## Why

The profile (`curate/corrections/logbook_app_profile.yml`) says per app what each field holds, and every row was
reviewed by the maintainer on 2026-10-29 and 30. Until now nothing read it. The merge set the one placeholder it knew
(T1) to NA, and every other habit opened windows as if it were the skipper's time.

## Chosen

- **`R/logbook_app_profile.R` reads the reviewed rows**, and the merge applies each flag and note row after the twins.
  Each row's scope (apps, feeds, period, gear class) comes from the YAML; its test is coded from the row's text. The
  rows of a field are tried in the archive's class order, and the first match wins. A flag or note row that no code
  applies stops the merge, unless it is named as applied elsewhere.
- **Every value stays as recorded.** Each field carries three columns: what the value holds (`t1_flag` ... `t4_flag`),
  the row's id (`t1_rule` ...), and the action (`t1_action` ...):
  - `flag` leaves the value out of every window, link and duration;
  - `note` keeps it.

  The trip carries `T1_*` and `T2_*` (T11), the station `pos1_*` and `pos2_*` (P5-P7), and the catch `species_*` (K2).
  `t1_placeholder` stays one release, as `t1_flag == "placeholder"`, and the section that set a placeholder `t1` to NA
  is gone.
- **The data the rules need.** Each record's entry time is staged as `record_entered` (fs and adb). The afli route's
  departure comes from the sent layer; it is a date on every trip, as decision 249 found.
- **The profile takes decision 249's rows**:
  - T2-afli, T3-afli and T20 (210 min);
  - T11-afli, split off as a row of its own;
  - T15 relabelled;
  - T14's flag on the end, so the start stays usable;
  - T12 by gear: gillnets flagged, longlines noted, traps never reviewed and left as recorded.
- **The windows read the flags** through `judged_time_sql()`, now for `t1` and `t2` too. So do `voyage_gear.R`,
  `trip_reconciled.R` and the audit; `calc_effort()` leaves a flagged time out.
  - A station with no usable time gets ramb's day window (W1).
  - **trip_time** (T4, T10): the trip's departure and return stand in, basis `derived`.
  - **pressed** (T14): the window runs from the start to the gear's 95th-percentile span, or to the vessel's next
    station, basis `synthesised`.
- **The typical-haul fix (cc5daf4).** A pressed haul enters ramb as two rows, so its made-up end stays out of ramb's
  median haul.

## Checked on a scratch store

- **The rules against their evidence.** Each row's count matches its archive class, or the difference is explained.
  - T1 exactly; T2 716 + 123 against 700 + 16 and 122 + 1; T3 exactly; T7 342 against 341; T13 2,898 against 2,893;
    T16 228 and 71 against 227 and 71.
  - T14 and T18 also take the starts equal to the departure or landing: 4,807 pressed tows and hauls against 4,810.
- **The files.**
  - `fishing_sample`: 85,812 rows differ, all of them the rules' work (77,953 placeholder `t1`s kept as recorded,
    7,859 newly flagged).
  - `trip` and `station`: only decisions 253's and 249's changes.
  - `catch` and the fates: unchanged.
- **The windows, every station in one outcome.** Of 7,300,776 stations: 7,239,092 unchanged, 38,275 moved, and 23,409
  with the same spans on another basis; none in one store only.
  - The moved are counted by rule, and 5,541 more day windows are among them: all 3,930 of STOKKUR's, whose false set
    window was their only one.
  - 2,344 moved with no flag of their own, through ramb's typical haul, which the flags changed. Gillnets went from 247
    to 251 min.
- **`voyage_gear`:** 618 voyages of 1.43 M change gear; one whose only logbook evidence was a flagged time now takes
  the landing's gear, or none.
- **`trip_reconciled`:** the departure changes on 953 trips and the return on 1,611. 666 of those had only the
  logbook's own departure, now flagged.

Not traced: `station_event`, the trail, effort and catch on the fixes, and the audit. They belong to the combined
scratch build.

## Left

- P8's 8 stations need Trackwell's copy as a frozen list.
- I4 is the check's (decision 256).
- D4 and D5 are step 8's, and P2-P4 step 7's.
- The new columns go into the data dictionary and v0 with rebuild A.
- **For the maintainer:** 1,767 pressed records start at the trip's departure and 821 at its landing. T14 takes them as
  written, and no reviewed row says whether such a start is a copy.
- Traps are outside T12 and take FPO's own 95th percentile, 347 min, which plan 053 did not measure.
