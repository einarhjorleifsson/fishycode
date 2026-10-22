# 177 — The vessel overview draws hauls and trips from the flow's windows; a wider map with its choices on it, a narrower chart margin, and a trip's records open on a click

*2026-10-22. Amends decisions 143 and 156 (the overview's page). Closes TODO 104.*

- **Who chose.**
  - TODO 104 (2026-10-20): draw hauls from `station_window`, not from the logbook's t1-t4, and count a haul's pings by
    the `.sid` each fix carries.
  - The maintainer, 2026-10-22, on Overview's layout:
    - "The When has a very wide margin, particularily on the left side. Make margin smaller so there more space for
      viewing the data";
    - "Part of the saved space can be use to widen the area the where takes relative to when";
    - "The user choice what to show in the Where could be put into the 'leaflet'".
  - The maintainer, the same day, on the trip table: "when one clicks on a trip one would get a 'dropdown' that shows
    each event (logbook records). then if the user selects a single event within a trip the graphs would update
    accordingly, similar as what happens when one now clicks the trip".
- **Who did the work.** Claude (Anthropic), in one session: the code, the checks in the browser pane on the running
  server, and this record. A person has not yet used the changed page.

## Done

**Hauls from the flow's windows (TODO 104).**
- **The service** has a new endpoint, `windows`: `curated/logbook/station_window.parquet` for the vessel's trips, with
  `.sid`, `schema`, `.tid`, `phase`, `w_start`, `w_end` and `win_basis` (API version 2026-10-22.1). A server started
  earlier shows the page's banner until it is restarted.
- **On the chart, a haul is drawn by its windows.**
  - setting in grey; towing, hauling or jigging in green;
  - a haul known by its date alone is drawn as its day, in pale green. Before, it was a hairline at midnight.
  - The chosen trip's windows are drawn in red, and the chosen haul's in black.
  - Quality control's lanes show the set, the attended phases (tow, haul, jig) and the day, from the same windows. The
    logbook's own t1-t4 stay in the haul table, as recorded.
- **A haul's pings are those carrying its `.sid`** on the trail (one fix, one record: decision 090). Its fishing pings
  leave out its set window, as decision 143's check judged static gear on its hauling.
  - The page's own gear lists (STATIC, MOBILE) are gone. The windows already apply each gear's rule.
- **A trip spans its T1-T2 and its hauls' attended windows**, so a trip known by its dates alone (T1 = T2 = midnight)
  covers its days.
  - That span is used for the trip's band on the chart, its pings, the presets and its frame on the map.
  - The table shows T1 and T2 as recorded.
  - A set window is left out of the span, since a net may be set on an earlier trip.
- **Quality control's trip table** has a new column, "on its hauls": the trip's pings that carry the `.sid` of one of
  its hauls.
  - "fishing pings outside hauls" is now "fishing pings on no haul of the trip", counted by `.sid`.
  - The haul table shows each haul's windows with their basis, its pings and its fishing pings.
- **The trip table opens on the page that holds the window's trips**, not on the newest.

**Overview's layout.**
- **The chart's left margin** is 24 px in Overview, down from 118, with no axis title: the legend gives the unit and
  the cap. The right margin is 18 px, down from 28. Quality control keeps the wide margin, which holds the lanes' names.
- **Where | When** is two fifths and three fifths, up from a third for Where. It is still one setting in `index.html`.
  - The map's shape is unchanged (1.35), so the map is taller.
  - Overview's chart is now as tall as the map beside it (291 px against 230 at 1,440 px), so the two panels end
    together. It is never less than 230 px. In Quality control and on one column it stays at 230.
- **The map's choices are on the map**: a bar along its top with "window: points | line only", "outside it: nothing |
  fishing hours | track" and Fit. The hexagons' legend is at the map's foot.
  - The map's frame leaves room for the bar.
  - The bar above the panels keeps the window's presets.

**The trip table.**
- A click on a row selects it (the window, map and chart) and opens its records, closing any other open row. A click
  on the chosen row, while it is open, closes it. The caret opens or closes a row without choosing it. The double-click
  is gone.
- A click on a record (a haul) frames that haul alone:
  - the window is the haul's windows with 30 min either side, and a date-only haul's window is its day;
  - the map glides to it;
  - the haul is drawn in black.

  The address carries it as `haul=<.sid>|<schema>`, beside `trip=`, so a link can name one haul.

**The demo builder** (`products/exports/vessel_demo.R`, decision 153) adds the `windows` answer, and `check.R` asks
the new endpoint.

## Checked

- `check.R` passes: 85 answers and 10 refusals, each answer with exactly its allowlisted columns.
- **TODO 104's case**, vid 1416's trip 103167526 (afli, 2009-08-09 to 08-13, four date-only GNS hauls):
  - Quality control shows 73 pings, 73 on its hauls and 45 fishing, and "agree".
  - Each haul is its day, with 18, 24, 23 and 8 pings, of which 10, 20, 12 and 3 are fishing. That matches the
    trail's own count by `.sid`.
  - TODO 104 counted 74 pings in the trip on the build of 2026-10-20. The current build (2026-10-21) holds 73 in T1-T2,
    all on the hauls. Why the count changed was not looked into.
- **Date-only trips**, vid 1684 (GNS), June 2018:
  - before the trip span, every trip showed "no pings in the trip";
  - after it, each trip has its day's pings (126-205), all on its haul, and shows "agree".
  - Other trips keep real warnings: vid 1416's trips of December 2009 have 4 and 27 pings, and hauls with no fishing
    ping.
- **Clicks, in the browser pane:**
  - a click on a trip opened its records and closed the row open before it;
  - a second click closed it;
  - a click on a haul set the window to that haul's day, drew it black, and put `haul=` in the address;
  - a link with `trip=` and `haul=` opened both, in both modes.
- **Redraw on the heaviest vessel-year**, vid 1977's 2025 (147,432 pings), in Overview with the hexagons on: 20 window
  moves at a median of 17 ms, one frame at 60 Hz. The first two moves took 321 and 925 ms while the map's tiles loaded.
  Decision 143 measured 7-17 ms, so this is the same.
- **The demo** builds with the new page and opens over HTTP from a scratch store, with no console error. The demo
  already in `exports/` (2026-10-20) was not rebuilt.
- No console error on vids 1416, 1684 and 1977.

## Not done

- The demo in `exports/` still carries the page of 2026-10-20. Rebuilding it is TODO 96's.
- The proposals put to the maintainer the same day are not built:
  - expandable panels;
  - brushing on the map;
  - QC flags for the known defect patterns;
  - the reconciled trip times;
  - lods' `hid_origin`.
