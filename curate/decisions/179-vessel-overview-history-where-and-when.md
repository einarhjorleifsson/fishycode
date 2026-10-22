# 179 — The vessel overview's History tab: Where and When over the whole history, on an axis and a frame pinned for every vessel

*2026-10-22. Amends decision 143's History tab. The same session as decisions 177 and 178.*

- **Who chose.** The maintainer, 2026-10-22: "the history should have the where and when at the top - in the where you
  will have the hexagon stuff and the when you will have the full history. for the latter pin the x-axis always from
  2027-09 to the present irrespective of how long the vessel has been in that history. do the same for the hex".
  - 2027-09 is in the future. Claude read it as 2007-09, where the AIS trail and the agf landings begin, and said so.
  - "The same for the hex" is read as the same months and a fixed map frame: the fishing grounds' box of decision 143,
    the same for every vessel.
- **Who did the work.** Claude (Anthropic): the code, the measurements, the checks in the browser pane on the running
  server, and this record. A person has not yet used the tab.

## Done

**Two service endpoints** (API version 2026-10-22.3). A 19-year time-speed line would be millions of pings in the
browser, so the service sums them:
- `history_effort`: per month, the vessel's pings, its fishing pings (`fishing_flow`) and its fishing hours (the trail's
  `hours`, the effort of a fishing fix).
- `history_cells`: fishing hours and pings per month in cells of 0.025° latitude by 0.05° longitude (about 2.8 by
  2.4 km at 65°N).

  Measured, as month × cell rows:

  | vid | 1 km cells | about 2.5 km cells (chosen) | about 5 km cells |
  |---|---|---|---|
  | 1977, the busiest | 338,026 | 120,232 | 51,747 |
  | 1416 | 100,609 | 29,971 | 11,709 |

  - For vid 1977 the chosen cells are 650 KB in 0.17 s, and the whole tab loads in 0.84 s.
  - Each endpoint takes a time filter only from the demo builder, never from a request.

**The tab.** Where | When on top, in the Activity tab's two fifths and three. The tables of landings and logbook trips
stay under them.
- **When** is two bar charts on one time axis, pinned from 2007-09 to the end of this month for every vessel:
  - fishing hours per month (red, the fishing colour);
  - tonnes per month: landed as orange bars, and logged as green dots by the month the logbook trip returned.

  The two charts are separate because hours and tonnes are different units: one axis each, never two on one chart. The
  months before 2007-09 are left off the charts. The tables below keep them.
- **Where** is the fishing hours of the months chosen, in hexagons, on the fishing grounds' frame. A button resets the
  view to that frame. The hexagons are never smaller than 5 km, since the cells are about 2.5 km. Colours are viridis on
  a log scale, as on the Activity tab, with the scale's ends given per vessel.
- **Choosing months:** a drag across either chart chooses its months, and a click chooses one. The months are shaded on
  both charts, their sums are given (fishing hours, tonnes landed and logged), and the map redraws for them. "Whole
  history" clears the choice.
- **Open in Activity** loads the chosen months' years on the Activity tab with the window on those months, so a month
  that stands out in the history can be opened with its pings.
- **The demo bundle** holds one window, so there the axis is that window's months.

## Checked (in the browser pane, on the running server)

- `check.R` passes: 91 answers (the two new endpoints for three vessels) and 10 refusals.
  - The new answers took 0.14-0.20 s.
  - vid 2757 has 230 months and 13,895 cells; vid 3739 has 27 and 1,075.
- **vid 1977:** 2007-09 to 2026-10, 86,978 fishing hours, 101,853.9 t landed and 98,629.4 t logged, the map at 10 km
  hexagons.
  - A drag chose 2017-03 to 2019-07 (12,062 hours). The map and its legend redrew.
  - A click chose 2019-07 (437 hours). Open in Activity loaded 2019 with the window on July. The Activity card there gave
    436.6 fishing hours, the same month counted from the pings.
- **vid 3739**, on AIS since 2022: the axis still runs from 2007-09, with its months at the right end.
- No console error from the tab.

## Seen while checking

- A vessel that fishes off Greenland (vid 3739) has most of its hexagons outside the pinned frame. They are there when
  one zooms out. Pinning the frame is the maintainer's rule, so the page does not fit the map to such a vessel.
- The colour scale is per vessel: the same colour is not the same number of hours on two vessels. A scale pinned across
  vessels, like the axis, is the maintainer's call.
