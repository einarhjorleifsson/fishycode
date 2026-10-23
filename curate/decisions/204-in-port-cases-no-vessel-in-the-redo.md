# 204 — The cross-check's in-port cases go into the next key redo as "no vessel"

*2026-10-23. The maintainer's verdict ("move the 39 in-port cases into this redo as no vessel"), on a fix-level
cross-check of the STK key against the MMSI feeds and its follow-up: two read-only studies by Claude (AI), not checked
by a person, in `$FISHYDATA/archive/2026-10-stk-key-crosscheck/` (README §6, `frozen_feed/README.md`). The rows below
were drafted by Claude from them. Nothing was built and the key is unchanged: the verdict acts at the redo (TODO 25),
with decision 195's "no vessel" form.*

## Found

- **The class.** 45 of the cross-check's 213 cases, on 25 units: the key's vid has its ASTD, astdB or EMODnet fixes at
  one point inside a port while its STK unit is elsewhere, mostly far off and moving.
- **The witnesses.** The vid's logbook (station dates and trip spans; no logbook position read) and landings put the
  vessel in port on every disagree day in **39 cases** (16,419 STK fixes, 19 units), at sea in none, so no case is a
  stale transponder. **6 are undecided**: vids 1574, 13, 2190 and 500 have no logbook after 2015-2016, 7878 and 2489
  none ever. In 36 of the 39, a landing at the feed's port or a logbook departure on the day the feed leaves its point
  agrees.
- **The trail.** On those days `curated/ais/trail` keeps the port track in 35 of the 39 cases, which is the right one.
  Vid 1056 in 2014-12 keeps 923 fixes of its unit lying 32 km away while the vessel was in port.

## Chosen

- **No vessel on the in-port days.** The unit's fixes on them get no vid.
- **37 of the 39 cases.** Mid 143852's two cases are left out. A reviewed row of 2026-10-23 already gives those days
  to vid 1511, the unit's earlier vid, whose own logbook fits them; "no vessel" would contradict it.
- **Days, not case spans.** There is one row per run of consecutive disagree days (the days the logbook judged): **50
  rows on 18 units, 126 days, 15,911 STK fixes**, in `no_vessel_2026-10-23.csv` in the study's folder
  (`scripts/xc_08_no_vessel.R`). The rows use the reviewed table's columns, with no vid. None overlaps a reviewed row.
  Days without a witness between two runs keep the key's vid.
- **Not in `overrides/` yet.** Today's `ais_key_segments.R` reads an empty vid as "keep the segment's vid"
  (`coalesce(ovid, vid)`), so a row now would cut the segment and change nothing else. The rows enter
  `overrides/ais_key_segments_reviewed.csv` with the form, as decision 195's three no-vessel mids do.

## Left

- **Mid 101548** (10 cases, 13 rows, 2017-2020). The unit is on vid 2929's track on its sea days, and 290-1,270 km
  away on its port days. That looks more like two units, or two hulls, under one mid than like a change of hands. The
  rows give its port days no vessel; what reported under the mid then is plan 022's question (the STK side).
- **Mid 101084** (3 cases, 2022-08-14 to 10-17). Neither vid 2212 (in port) nor the earlier 2903 (no record in 2022)
  fits; the hull that carried the unit is not identified.
- **The 6 undecided cases** wait for another witness: the register, or the overview.
