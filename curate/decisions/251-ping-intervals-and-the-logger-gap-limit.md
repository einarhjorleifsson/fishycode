# 251 — The ping interval of each stream, the records shorter than four intervals, and the afli logger's gap limit: 60 minutes

*2026-10-30. Plan 054 step 1, TODOs 151 and 98. Measured by Claude (AI) in a side session, read-only, and not checked by
a person; the scripts and counts are in `$FISHYDATA/archive/2026-10-30-plan054-ais-intervals-and-gap/`. The gap limit is
the maintainer's: 60 minutes ("ok, 60 minutes then"), chosen once the measurement had been explained. Nothing is built.
The limit is built with the next AIS batch.*

## TODO 151 (1): the ping interval of each stream

The median interval at sea, in minutes, on Icelandic vessels, counting intervals up to 6 h:

| stream | 2007-12 | 2013-14 | 2015-16 | 2017-20 | 2021-25 | 2026 |
|---|---|---|---|---|---|---|
| merged (the flow's track) | 10.2-10.5 | 1.0 | 3.2-4.0 | 2.5-3.4 | 4.8-6.0 | 3.7 |
| stk | 10.2-10.5 | 1.0 | 10.0 | 10.2-10.3 | 10.3-10.5 | 10.2 |
| stk VMS (centiminute) | 60 | 60 | 60 / 10 | 40-60 | 60 | 60 |
| stk own units (no grid) | 10.5-11.5, then 105 in 2012 | 60-97 | 60 | 60 | 60-89 | 62 |
| astd | – | 74 / 6.1 | 6.0 | 3.3-4.3 | 6.1-6.2 | 3.1 |
| astdB | – | 6.0 | 9-36 | 7-26 | 18-42 | – |
| emodnet | – | – | – | 8.1 (2017 only) | – | – |
| logger | 10 | 10 | 10 | 10 | – | – |

- **In port** the merged track's median is 3-11 min to 2012, 43 min in 2013, and 3-6 min from 2014.
- **Intervals over 15 min** are 3-9 % of the merged track's at sea to 2012, and 1-2 % from 2013.
- **STK's AIS runs at 1 min in 2013-2014**, against 10 min in every other year (20 M pings a year). No record explains
  it.
- **The logger records every 10 min**, as STK does. It adds fixes at other moments, not a faster rate.

## TODO 151 (2): records shorter than four ping intervals

This is the guide's rule, decision 237: an interval no longer than a quarter of the event. All 7,310,942 stations are in
one outcome:

| outcome | records |
|---|---:|
| duplicate | 9,771 |
| deleted | 352 |
| no window | 43 |
| date only | 2,308,505 |
| synthesised window | 12,718 |
| length 0 or less | 5,587 |
| before 2007 | 3,279,494 |
| no ping within 24 h | 36,259 |
| a track on one side only | 272 |
| **shorter than four intervals** | **161,953** |
| **four intervals or more** | **1,495,988** |

- **9.8 %** of the 1,657,941 that can be judged are shorter than four intervals; 8.0 % if the logger's fixes count as
  pings.
- **By gear:** DRB 24.2 %, FPO 16.2 %, GNS 15.4 %, SDN 13.9 %, GND 10.2 %, LHM 9.5 %, OTB 8.8 %, OTM 8.8 %, LLS 3.7 %.
- **By year:** 49.6 % in 2007, falling to 3-5 % in 2015-2020. It is about 7 % in 2021-2025, raised by the e-logbook's
  jigging, dredge and Danish seine records.

Decision 237's four wishes are not decided here; they stay in TODO 151.

## TODO 98: the logger's gap limit

Decision 196 keeps the GPS logger in the track and gives its fixes positions from the cleaned AIS track. A fix is placed
on the straight line between the AIS fixes before and after it, in proportion to time. The gap limit is the longest
AIS silence across which that line is trusted. A fix across a longer silence keeps its time, speed and heading, and
gets no position (basis `none`).

Each logger fix was re-interpolated on today's cleaned track, as `rb_interpolate_track()` does. The test is the
logger's own reading, which is off by at most about 1.2 km where it is sound. It is used only in counts, and joined to
nothing.

| | 15 min | 30 min | 60 min |
|---|---:|---:|---:|
| positioned | 18,996,346 | 19,511,755 | 21,405,599 |
| no position (a silence over the limit) | 3,183,013 | 2,667,604 | 773,760 |
| over 5 km from the logger's reading | 77,603 | 79,617 | 98,165 |

These are the 22,179,359 fixes with a decimal reading and a ping on each side. Another 4,920,869 are in whole degrees and
left out, as today (decision 154); 9,608 have no ping on one side.

Over 5 km from the reading, by the length of the silence:

| silence | share |
|---|---:|
| under 30 min | 0.34-0.45 % (the reading's own error) |
| 30-60 min | 0.98 % |
| 1-3 h | 2.4 % |
| 3-6 h | 34 % |

From 2014 the 30-60 min class is at that floor; in 2008-2011 it is 1.7-5.6 %.

- **TODO 98's check cannot choose the limit.** A re-interpolated fix lies between the very pings `gps_scope.R` measures
  it against, so it scores 0 km at any limit. TODO 98's last check is met by construction once decision 196's step is
  built, and so is TODO 99's for the logger.
- **Today's 861 off-track fixes:**
  - At 30 and 60 min all of them get a position; vid 2173's then sit 0.6-1.0 km from the reading.
  - 337 stay over 5 km off at any limit, all vid 2411 on 2020-07-23. That day the logger is 277 km from the track at
    9-min brackets. It is the last day of decimal readings: a mismatch of vessel, clock or key, which no limit fixes.

**Chosen (the maintainer): 60 minutes.** It keeps 96.5 % of the fixes with a reading, against 87.9 % at 30 min. The
1.89 M fixes it adds lie mostly across the hourly offshore track, where the logger's speed places fishing between pings.
Their error is near the floor, and it climbs steeply beyond 60 min.

## Open, for the build

- `rb_interpolate_track()` needs a gap argument (ramb).
- Whether a bracket may cross from one voyage to the next. At 60 min, 84,449 positioned fixes have a bracket that is not
  on one voyage.
- vid 2411's 2020-07-23 is listed for a look at the key.
