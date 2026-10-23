# 214 — A logbook record is typed by what its times and position cover: the e-logbook stations that hold a trip or a day are resolved to it, their window the AIS voyage

*2026-10-23. The maintainer's go ("go"), on Claude's recommendation, for TODO 137. The framing is the maintainer's:
some apps mix up what is a trip and what is a station. The study and its re-check are Claude's (AI), read-only, not
checked by a person: `$FISHYDATA/archive/2026-10-trip-time-stations/` (README, scripts 00-10, `recheck/` with its
README and scripts 01-05). Nothing is built. **Amended 2026-10-23:** catch the landing contradicts stays on the fixes,
marked, not kept off them (the maintainer: "keep flagged catch on the fixes but marked").*

## Chosen

- **A record is typed by what its times and position cover,** not by the table it sits in. A station whose times are
  the trip's departure and return, its landing, or only a date covers a trip or a day, not an operation. In the
  grammar's terms each field group carries its own resolution (`docs/grammar.qmd`, "What each field group covers"):
  the time group the trip or the day, the place group a point or a cell, the gear group the gear, the catch the trip.
  The row's resolution is that combination (here trip × gear, or day × gear). The maintainer (2026-10-23): an event
  can be any construct, "even a single ping", each fishing operation, day × rectangle × gear, day × gear, and so on;
  so the grammar's `event`, fixed at trip × gear × day × rectangle, is too narrow to name these, and what kind of
  event a record is, is its resolution. How that is written is TODO 127's.
- **Its window is the AIS voyage,** under both approaches to fishing (`fishing` and `fishing_flow`): the fixes of the
  voyage that ends at its landing, fishing by the gear's speed, as `fishing_flow` already does where there is no
  window. Its catch unit is the trip, checked against the trip's landing as now.
- **No haul window is made from a departure, landing or midnight stamp.** Such a time is set aside (NA) and flagged,
  the value kept in its own column, as decision 206 does with Trackwell's departure copies.
- **Catch the landing contradicts is flagged, not corrected,** and stays on the fixes, marked, so an analyst can leave
  it out: decision 210's implausible-catch flag, which this makes urgent (below); plan 038 §8, step 1c.
- **The tour app's spot time is the end of fishing** (decision 210's build): t4 = the spot time, t1 = t4 - its hours at
  sea, basis `synthesised`; not plan 019 §4's t1 = the spot time.
- **Left open:** whether the slow time a trip-long window adds is fishing. Documented, not corrected.

## The cases

| Records | What they cover | Count |
|---|---|---|
| Marína and Taktikal, handline (fs 2022-25, adb from 2025-11-19) | the trip: one station, departure to return | 23,359 windows |
| Marína and Taktikal, nets and lines | the trip: the set at the departure, the haul ending at the return | 1,519 stations |
| STOKKUR (fs 2020-22) | the trip: one time, at the landing; the position a 1-degree cell (decision 211) | 23,136 read |
| the old TRACKWELL route (fs, read 2022) | a day: midnight only | 1,856 read |
| the tour app (decision 210, replacing STOKKUR) | the trip: each spot timed at the landing | 31,785 spots |

## Why: three witnesses agree

- **The AIS track.** The handline window is the voyage: of Marína's 18,089 windows, 10,616 meet it within 30 min at
  both ends and 4,572 more cover 90 % of it or more (Taktikal: 2,712 and 1,652 of 5,508); of the haul-timed control's
  72,333, 3,826 and 3,718. The tour app's spots: where a spot lies on the track (22,657 of 31,785), the vessel was there before the spot time on 14,229
  and within 10 min of it on 5,834; with hours at sea, the time there falls in the hours before the spot time on
  81.1 %, after it on 15.6 %.
- **The landings** (matched by vessel and day in `curated/landing`, not through `lid_map`; every trip in one outcome).
  The handline station holds the trip's whole catch: within 10 % of the vessel's landing that day on 9,601 of 13,615
  Marína trips and 4,051 of 5,955 Taktikal, as on the haul-timed apps' (37,509 of 53,362). STOKKUR's time is the
  landing day: a landing that day on 15,166 of 17,961 handline and 2,848 of 3,524 net and line trips. The tour's
  landing date: a landing that day on 29,433 of 35,792 tours.
- **The digits** (decision 211): STOKKUR's position is the nearest whole degree, a cell, not a point.

## What it changes, measured

- **STOKKUR's 3,930 net and line stations** have only a set window at the landing and get no fishing fix (0 of 23,787
  fixes in their windows). They log 31.9 kt: 23.1 kt on 6 entry errors (11,000 t logged on a day that landed 9 t; a
  trip of three 3,704 t stations with no landing within a day) and 8.8 kt on the other 3,563. Of the 8.8 kt, under
  `fishing` 6.7 kt is placed on no fix and 1.6 kt on the vessel's month; under `fishing_flow` 7.2 kt lands on the
  trip's fixes. With the voyage as window it should land on its own trip under both (to be measured in the scratch
  build). Of the entry errors, 11.3 kt sits on
  fixes today. (The catch script's units and sharing, re-run on STOKKUR's 752 vessels, reproduce the stored catch to
  the kilogram in 2020-22.)
- **Marína's and Taktikal's handline windows** are the voyage already; a trip-long window marks fishing on 95.6 % of
  the voyage's handline-speed hours, a haul window on 86.7 %. Matched by vessel and month (76 vessel-months), the
  trip-timed trips have more fishing hours per trip in 33 and fewer in 43 (340 h against 359 h, summed). The study's
  "9 % more" compared trips of different months and is withdrawn.
- Not re-checked, the study's: the nets and lines' set at the departure (1,519) and the old route's 225 static
  stations (1.2 kt with no fix).

## Left (TODO 137)

Built as a step of the logbook batch, a scratch build first: each group's resolution on these records in the merge
(time: the trip or the day; place: a point or a 1-degree cell); the stamped times set aside and flagged; the voyage as window for them in the flow,
under both approaches; decision 210's implausible-catch flag against the landing, before any catch moves; the tour
app read as above. Then the windows, fishing fixes and catch traced before and after.
