# 250 — Overlapping logbook trips classed, most overlapping only in their declared times, and every vessel that lands with no AIS given a reason

*2026-10-30. Plan 054 step 1, TODOs 102 and 24. Measured by Claude (AI) in a side session, read-only, and not checked
by a person; the scripts, results and draft override are in `$FISHYDATA/archive/2026-10-30-plan054-trips-and-vessels/`.
The choices are the maintainer's, put by Claude with AskUserQuestion the same day. Nothing is built: the treatments
ride plan 054's step 2f and rebuilds A and B.*

## TODO 102: trips that overlap another trip of the same vessel and source

**The counts differ by definition, not by build.**
- TODO 102's 21,220, 4,116 and 596 (afli, fs_afladagbok, adb) count a pair when `a.T1 < b.T2 − 1 h` and
  `b.T1 < a.T2 − 1 h`, at any trip length. This is definition A.
- Plan 054's 12,045, 3,862 and 576 require `T2 > T1`, and an overlap itself over 1 h. This is definition B.
- Each definition gives the same counts on the builds of 2026-10-16, 10-21 and 10-29.
- A's 9,175 extra afli trips are one-day trips that lie inside another trip's dates, since afli's trips are made from
  the landing's date and port, at midnight.
- adb's 624 of TODO 102 is not reproduced: those builds give 584 and 596.

Every trip in A is put in one class, the first rule that fits; its class under B is kept beside it.

| class | afli A / B | fs_afladagbok A / B | adb A / B |
|---|---|---|---|
| test entry | 3 / 0 | 187 / 159 | 0 / 0 |
| a resubmission decision 094 misses | 237 / 178 | 1,111 / 1,102 | 142 / 140 |
| several boats under one vid | 345 / 338 | 80 / 61 | 0 / 0 |
| real overlap | 1,974 / 1,549 | 17 / 17 | 6 / 6 |
| split voyage (two trips, one landing) | 91 / 77 | 1,027 / 1,014 | 207 / 202 |
| gap (one trip inside a gap between the other's stations) | 6,404 / 2,747 | 101 / 79 | 12 / 12 |
| declared span (stations in order; only the declared `T1`/`T2` overlap) | 12,164 / 7,154 | 1,593 / 1,430 | 229 / 216 |
| cannot be judged | 2 / 2 | 0 / 0 | 0 / 0 |

- **Most overlaps are in the declared times, not in the fishing.** In most gap and declared-span pairs the vessel
  landed between the two stretches.
- **TODO 138's 125 Marína re-entries** all overlap by over 1 h. 117 are resubmissions (the same departure), 4 are
  test entries, and 4 are under the placeholder vid −100.
- **vid 7373's 13 trips** are test entries themselves.
- **The placeholder vids** −100, −200 and −300 are classed as several boats under one vid.
- **Over 1 % of a source's trips**, as ask f asked to be told:
  - over all years, only fs_afladagbok's declared span under A (1.04 %);
  - by source and year under B, fs_afladagbok's resubmissions in 2023 (1.43 %), its split voyages in 2022 (1.02 %),
    and its declared spans in 2022 and 2023 (1.26 % and 1.30 %);
  - afli's declared span, in eight years.

**Chosen (the maintainer):**
- **Overlaps are counted by definition B**, an overlap of over 1 h.
- **Ask f's four treatments apply to their classes** (plan 054 §5 f):
  - a resubmission is `duplicate`, by decision 094's twin rule widened with the study's four resubmission tests,
    which take TODO 138's Marína re-entries with them;
  - a test entry is flagged and left out of the links;
  - several boats under one vid are listed for the register's review (TODOs 25, 65);
  - in a real overlap, a fix inside both trips gets no trip and a flag (decision 191 c).
- **The three classes that fit none of the four:**
  - gap and declared span: the trip's window is cut to its stations' span. That is a value `derived` beside the
    declared `T1` and `T2`, which stay as recorded;
  - split voyages keep both trips, both linked to the one landing through `trip_landing` (plan 027, rebuild B).

Left open in TODO 102: decision 094's own open ends, its 6,035 same-time stations and the 148 resubmitted
fs_afladagbok trips with a later arrival.

## TODO 24: Icelandic vessels that land fish but are never heard on AIS

The set is 105 vids today, not 107: vids 978 and 1265 left the check at the key redo of 2026-10-17, though neither has a
ping in the union. All 107 are given one reason.

| reason | vids | TODO 24's term |
|---|---:|---|
| not a hull: a landings placeholder (8007, 99xx) | 9 | no AIS expected |
| not a hull: a diver (8008, 8009) | 2 | no AIS expected |
| off the register when its records are dated (sold abroad 28, scrapped 20, …) | 69 | no AIS expected |
| no catch: only 0-kg agf landing rows, and no logbook catch | 22 | no AIS expected |
| an STK unit found, unkeyed (5886) | 1 | an STK unit found |
| an MMSI on record, never heard (2026, 2828) | 2 | an MMSI found |
| a small boat with no unit heard while fishing (6189, 6512) | 2 | no transponder |
| a match missed, or cannot be judged | 0 | |

- **7 of the 69 off-register vids hold catch:** 2127, 1174, 2186, 2362, 1786, 1805 and 7289. That points to a wrong
  vid in their records, not to a missing track.
- **Decision 161's "32" is not reproduced.** Its table names 5 of the 107; STK's mobile table names 45.
- **Small boats are usually heard.** 94-99 % of the boats of 6-15 m that still land are heard, so "a small boat"
  explains little.

**Chosen (the maintainer):**
- **8009 takes a diver class** through an override; the register lists it among divers.
- **8008 is listed for the register's review** instead. Its landings are a diver's, but afli holds 84 dredge
  ("Plógur") stations under it in 2018-2022, which need a boat.
- **`landed_but_no_ais` leaves out 8009 and the landings placeholders.**
- **The 7 off-register vids with catch** are listed as wrong vids in their records, for the register's review.

TODO 24 closes when the override is in place and the check reads it.
