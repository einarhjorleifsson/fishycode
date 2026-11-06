# 287 — Production's speed rule stays: the candidate rebuilt overnight beside the store, hand-checked, and TODO 192 parked until plan 048

*2026-11-05/06. Plan 069, for TODO 192. The maintainer: "Yes, as recommended" (plan 069's asks a-f), "Yes, check and
read", "Yes, draw samples", "Yes, start with D01", "Count all, then P by hand", and "Yes, park until 048". Run,
measured and counted by Claude (AI); the hand verdicts are the maintainer's. The study, its scripts and every table:
`$FISHYDATA/archive/2026-11-05-speed-rule-rebuild-test/` (its README).*

## What was run

Plan 069's night (2026-11-05 23:47 to 02:08, detached, unattended): the sweep's other 18 years; production's own clean
step under today's ramb (2026.11.05.11) on a `cp -c` clone of the store, as a control; the candidate of decisions
282-284 in its place (`rb_flag_ping_impossible(method = "local")` on each vessel and stream's own limits, the recorded
speed, the larger side and the vote); the 16 targets below it, from a frozen clone of the code at f17930c; and the
comparison, every record of every product in one outcome against the live store. Every morning check passed: no live
file written, the control equal to the store's labels (so every difference is the rule's), every year reconciled, all
612 files written stamped with f17930c, a clean tree and ramb b7109d4.

## What it found

| | the candidate against production, 2007-2026 |
|---|---|
| pings (589 M) | flags 701,615 production keeps, keeps 680,276 production flags; keeps more in 2007-2011 (STK's event rows), flags more from 2012 (STK's AIS stream) |
| fishing hours | 9,171,625 → 9,172,304 (+0.007 %), every year within ±0.2 %; no fix changes its station or trip |
| port calls (1.62 M) | 21,600 lost, 8,142 new, 140,901 moved |
| voyages (1.43 M) | 2,487 lost, 4,231 new, 10,453 merged, 4,238 split |
| trips (2.09 M) | the AIS departure of 7,381 moved by over 6 h (5,680 earlier), the return of 13,458 (11,875 later) |
| the survey's tows | 4 of 7,601 stretches differ |

The sweep's worry, about 3,200 h of fishing-window pings in 2018, does not reach the effort: a fix's hours run to the
next fix, so a flagged ping hands its time on. What moves is the port calls, and with them the trips' spans.

**The hand check.** Of 30 cases drawn, 4/3/3 from three periods with a seed:

- **The trips, by the logbook's own date** (the maintainer chose the count over the remaining 17 trip cases; every
  moved trip has a date): the departures fall on production's day 4,741 times, on the candidate's 1,312, on both 165,
  on neither 1,163 (843 nearer production's); the returns 9,610, 923, 736 and 2,189 (1,579 nearer production's). On
  D01-D03, judged on the page, the candidate's times are real departures, of earlier trips, which it merges in by
  keeping a whack.
- **The lost port calls, the maintainer's verdicts:** in port, production right 5; undecided 3; no option picked 2,
  each with whacks named that the candidate keeps; the candidate right none.
- **The mechanism:** every whack the maintainer named is an STK report out of place, nearly all event rows at 0 kn
  placed in another harbour or far off (Þorlákshöfn, Flateyri, Ólafsfjörður, Reykjavík, off Norway). Production's
  `vmask` flags them by their angle. The candidate has no angle test: over hours of silence, its legs to and from such
  a row stay within the vessel's own limits. So a stay breaks, voyages merge, and a one-day trip takes an earlier
  trip's departure.

## What was chosen

- **Production's speed rule stays**: `curate/ais_ping_clean.R` runs `clean` at 25 kn. Nothing in the pipeline or the
  store changed.
- **TODO 192 parked until plan 048** (TODO 148) takes STK's event rows out of the track and judges them as events.
  Then plan 069's night runs again with the candidate, on a fresh clone: its scripts are in the study, ready.

## What it leaves

- **The scratch store**, `/Users/einarhj/stasi/scratch-192-candidate/` (about 47 GB of its own): kept until deleted at
  the maintainer's word; it must go before any live rebuild, or it keeps the replaced files' disk.
- **A hybrid rule**: `clean`'s first stage (the angle) before the candidate's own limits. Not built; an option if plan
  048 does not clear the candidate's losses.
- **The trip ends the candidate gets right**, 2,235 by the logbook's date: production's own wrong ends, not looked at.
- **Whacks both rules keep**, as P01's event row placed at Sandgerði.
- **The logbook's date as a witness of the AIS trip ends**: counted here once, in no check of the pipeline.
