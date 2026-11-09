# 308 — TODO 88 closed: the whack filter's question answered by plan 062, and its two kept pings were STK event rows

*2026-11-09. TODO 88, at the maintainer's word: "Yes, check and close". Checked and written by Claude (AI); no person
has checked the queries.*

## Why

TODO 88 asked for a whack filter that catches troubled pings without the domain knowledge the maintainer had used on
vid 2350's day-shifted copy (2026-10-18). Plan 062 answered it (decisions 276, 303 and 306): copies are labelled before
any speed rule, ramb's `"local"` rule judges each leg against the vessel's own recorded speed and limits, and every
rule is scored on ramb's planted faults, in the book's ping chapter and its appendix (decision 307). Production keeps
`"clean"` at 25 knots, with each faster vessel at its own ceiling (decisions 287, 297 and 299). The item stayed open
only for what was left, with the maintainer to close it or keep it.

## What was left, and where it stands

- **The two pings the filter kept** (found 2026-10-23, TODO 25's review). Neither is in the AIS track today, before
  or after the flags (`staging/ais/ping_union`, `ping_tagged`, `ping_clean`, `ping_whacky`, searched by vessel and time
  and by position and date). Both are rows of STK's port-event table (`staging/ais/stk_event.parquet`), departures
  (`io` "U"):
  - vid 7438, 2009-07-09 12:59:57, at a rounded 64.2333° N, 22.4° W, 29.9 km from its port;
  - vid 2654, 2013-09-13 05:19, at 180° W, 8.55° N.

  Since plan 048 (decisions 288-296), STK's event rows are out of the track and judged as events, and an event's port
  comes from its code (`pid_basis` "code"), not its position. So neither reaches the speed rule any more.
- **A placeholder found on the way**: 866 of STK's 8.48 million port events, all departures (2007-2024), lie at
  longitude 180°, at latitudes from 64.5° S to 69.3° N. 49 of them, on 44 vessels in 2007-2019, sit between 8.50° and
  8.59° N, every one stamped 05:19 or midnight, vid 2654's among them. 763 of the 866 take their port from the
  event's code and 100 from the arrival before; 3 have none. Whether the event judge (`rb_flag_port_event()`) sets
  them aside was not checked, nor their cause at the source.
- **Normal Icelandic days** have no truth to score a rule against; the planted faults stand in, and the night runs
  against the live store (decisions 287, 297) compared the rules on every ping.
- **A lone feed's copies**: labelled as pairs (`ping_repeat_dt_s`), the choice of which is the copy left undecided on
  one feed with no receipt time (decision 276).

## What was chosen

TODO 88 is closed and deleted. Nothing in the pipeline or the store changed.
