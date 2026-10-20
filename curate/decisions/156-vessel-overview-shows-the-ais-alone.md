# 156 — The vessel overview's map shows the AIS voyages alone, and a link can name a trip

*2026-10-20. Amends decision 143 (the overview's two modes). The haul layer and `trip=` were committed with plan 034
(c7fa8c7), the map's voyages only at 576ab9d.*

- **Who chose.** The maintainer, in one session while checking the data in the overview: "you are adding the logbook
  lon-lat position the the ais feed - that should absolutely never happen"; "change the app such that the where does not
  show point are in harbour, i.e. only voyages"; and links into the page for each case of a data problem, with a trip in
  the address ("want them both").
- **Who did the work.** Claude (Anthropic): the code, the checks in the browser on the running server, and this record.

## Done

- **No logbook position is drawn.** The `stations` layer drew each haul as a line from its start to its end position over
  the track. Wrong end positions then looked like whacks: vid 2158 in 2008-2010, where the end longitude is the
  latitude copied over (TODO 106). The layer is removed. A haul meets the pings by time only, on the chart. Hauls with no
  start position now stay on the time axis; the page dropped them before.
- **The map shows voyages only.** A ping with no `voyage_id` (time in port above all) is filtered out of the points, a
  segment is drawn only within one voyage, and the map fits on the window's voyage pings, the harbour only when there
  are none. The chart keeps every ping, and the marker for the last position heard stays. The note under the controls
  says so.
- **The address carries the selected trip** (`trip=<.tid>|<schema>`, URL-encoded). A link with it selects the trip, sets
  the window to it and lists its hauls; clicking another trip updates the address. The years in the link must cover it.

## Checked

- vid 2158, 2008-2010, Quality control: no haul line on the map, 590 hauls on the chart as before, no console error.
- vid 2173's trip of 20 June 2026 by `trip=`: the trip selected, its 84 hauls listed, the window on the trip.
- vid 1417, 1-15 July 2012: its trips out into Skjálfandi drawn, the harbour cluster at Húsavík gone, no console error.

## Not done

- The page still reads a haul's t1-t4 itself rather than the flow's windows, so a date-only haul shows as a hairline
  with false warnings (TODO 104). The demo bundle was built before these changes (TODO 96).
