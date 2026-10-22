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

## Amended 2026-10-22: finer hexagons, the effort named, the colours by decade, the landings with their trips

The maintainer, after using the tab:
- "lets hold on" pinning the colour scale;
- "provide higher hex-resolution at any zoom that is now in place";
- "use the effort (time steps / dt) rather than number of pings";
- "show the colour scale on a log scale";
- "we want to operate on the trip window. now it is the landing window - that is 'misleading'".

Code, checks and this section by Claude (AI-assisted). Both tabs changed. The service changed too (API version
2026-10-22.4).

- **Finer hexagons.** On both maps a hexagon is now about 6 pixels from centre to corner, half the 12 of decision 143,
  rounded to a step from 0.1 to 50 km.
  - The History cells are now 0.01° by 0.02° (about 1.1 by 0.95 km), and History hexagons go down to 2 km.
  - Measured as month × cell rows: vid 1977 has 338,026 rows (1.2 MB, 0.18 s), and vid 1416 100,609.
  - Cells of about 0.5 km would be 604,889 rows (1.8 MB) for vid 1977. They were not taken: the browser re-sums the
    hexagons at every zoom step and every choice of months.
  - At the grounds' frame the History map now draws 5 km hexagons where it drew 10 km.
- **The effort was already the time steps.** Both maps summed the trail's `hours`: each fishing fix's time step to the
  next fix in its voyage, capped (`ramb::rb_add_effort`). That is not a count of pings. The page now says so:
  - the legend reads "effort per … km hexagon, in hours";
  - a hexagon's tooltip gives its hours of fishing effort, "the time steps of its N fishing pings".
- **The colours by decade, on a log scale the legend shows.** A hexagon's colour is the decade its hours fall in:
  0.01-0.1, 0.1-1, 1-10 and so on, from the decade of the smallest hexagon to that of the largest. Viridis spreads over
  as many steps as there are decades, and the legend labels every bound (0.01 · 0.1 · 1 · 10 · 100 · 1,000 · 10,000).
  - The first draw learns the hexagons' range. They are then recoloured on its decades, which does not sum them again.
  - The steps are still each vessel's own (not pinned).
- **The landings go with their trips.** On the Activity tab, "Landings in the window" and the activity card's "landed"
  are now the landings of the logbook trips that overlap the window, through `lid_map`, whenever they landed.
  - A landing that no trip of the loaded years claims goes by its own day.
  - Each landing row names its trip's dates.
  - On the History tab, landed tonnes are counted in the month the landing's trip returned, as the logged tonnes are,
    so the two compare month by month. Where a landing links several trips, the last trip's month is used. A landing
    with no trip keeps its own month.
  - The landing triangles on the chart and the landing lane stay at the landing's day: they are the event itself.
- **Checked** in the browser pane:
  - vid 1977's History map: 5 km hexagons, decades 0.01 to 10,000 hours;
  - its Activity map over 2025: 10 km hexagons, 0.01 to 1,000 hours;
  - a window on one haul of 2025-10-02: before, "No landing in the window"; now the trip's landing of 2025-10-26,
    421.6 t;
  - `check.R` passes (91 answers, 10 refusals); the demo builds.
