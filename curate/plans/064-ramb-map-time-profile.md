# 064 — ramb's map viewer gets a time profile: the vessel overview's space and time views, generic, for any pings

**status:** proposal — written 2026-11-04 at the maintainer's request; none of its steps built. Measured by Claude the
same day, read-only: ramb's viewer (2026.11.04.3), the vessel overview's page, and the per-vessel sizes of ramb's
example data and of one partner's case study. Assumed, to be measured in step 1: the browser's times (§3.2) · **see:**
plan 047 (whose step 3 this is), plan 046 and decisions 227, 277, 278 (the viewer and its bundles), plan 030 §7 and
decision 153 (the vessel overview and its demo), TODO 145, TODO 187

Drafted with AI assistance (Claude) on 2026-11-04; a person has not yet checked it. What §1 calls measured, Claude
measured; the rest is proposal.

The maintainer, 2026-11-04:
- ramb has functions that make interactive maps on the fly from parquet files, and fishycode has the vessel overview
  for the Icelandic data;
- "Is it possible to have function calls in ramb that would emulate the space and time profiles so it can be used to
  view the CS1 data." CS1 is the Italian case study of the EM4SSF project's code hackathon: one-minute GPS pings of
  small-scale vessels, CNR-IRBIM's, held with the project's code outside this repository (`~/stasi/em4ssf/me_code`
  reads them where they are).

**Yes.** ramb's viewer draws pings in space. It has no time: no chart, no window, nothing linked to the map. The
overview has both and is Iceland's. This plan builds the time side in ramb, for any pings. It is plan 047's step 3,
taken ahead of that plan's first two steps, because a dataset that is not Iceland's needs it now.

## 1. What is at hand (measured 2026-11-04)

### 1.1 ramb's viewer (2026.11.04.3)

- **The page:** `inst/map/index.html`, 1,346 lines, on MapLibre 5.24.0 (and maplibre-contour 0.1.1 for a contour
  layer), from jsdelivr. Groups of layers in a sidebar, base maps, texts in several languages, and the whole view in the
  page's address.
- **Layers:** a grid (tiles cut by DuckDB on request), vector tiles from a table (`rb_map_tiles_table()`), GeoJSON,
  elevation images and contours.
- **For pings:** `rb_map_pings()` (points coloured by a column, several to choose between) and `rb_map_track()` (each
  vessel's line, broken at silences and at changes of a column's value). They pipe:
  `pings |> rb_map_track(fishing) |> rb_map_pings(c(speed, fishing))`. Grouped pings (`group_by(trip)`) give the page a
  chooser per group column.
- **Served or bundled:** `rb_map_serve()` on 127.0.0.1, or `rb_map_bundle()`, a folder that opens from its
  `index.html` with no R and no server (decisions 277, 278).
- **No time in the page.** No chart, no time window, no hover shared with a chart. The page has no mention of uPlot, a
  timeline or a brush.

### 1.2 The vessel overview's two views (plan 030 §7, `products/vessel_overview/`)

- **Space:** deck.gl 8.9.35. One vessel's pings as points and a line coloured by speed, a hexagon layer of hours, and
  the track. They are filtered to the time window on the graphics card.
- **Time:** uPlot 1.6.30. Speed over time (capped at 15 kn), with bands for the logbook's windows (setting, towing,
  hauling) and a bar of trips along the top. Under it are lanes: trips, port calls, hauls, landings. A drag sets the
  window, the map follows, and a hover on one view marks the same time on the other.
- **Data:** one vessel's tables as parquet from its R service, held in DuckDB-WASM. Plan 047 §1.5 measured a window
  move at a median of 17 ms on the busiest vessel-year (147,432 pings).
- **Iceland's:** its columns, endpoints and engine are fishycode's. Its code is not copied into ramb (plan 047 §3.3).

### 1.3 The sizes the browser must hold, one vessel at a time

| Data | Vessels | Pings | Per vessel: median | largest |
|---|---|---|---|---|
| ramb's `dansk` | 14 | 395,558 | — | 103,680 |
| Iceland's trail, a vessel-year (2025, plan 047 §1.4) | 1,909 | — | 347 to 111,776 by gear class | 147,432 |
| the partner's case study, 15 months at 1 minute | 10 | 1,020,999 | 50,860 | 453,993 |

A vessel's whole series is three times plan 047's mark (150 thousand) in the case study. So the page needs a span
(a month, a trip, the whole) as well as a window within it.

## 2. What the user gets

```r
pings |>                                   # vid, time, lon, lat and any other columns; a data frame or lazy table
  rb_map_track(trip_id) |>                 # as now
  rb_map_pings(c(speed, ping_flag)) |>     # as now
  rb_map_time(speed, lanes = list(voyages = voyages, port_calls = port_calls))   # new: name to settle (ask a)
```

- **A time panel under the map:** the chosen vessel's columns over time (speed by default, one or more), with marks
  where a column says so (a flag, a fill), and lanes for intervals: voyages, port calls, trips, records' windows, or
  runs of a ping column's value.
- **A vessel and a span:** a chooser of vessels (from `by`, as the track's), and a span (the whole, a month, a trip
  or voyage). Only the span's pings are held in the browser.
- **Linked:**
  - a drag on the time axis sets the window, and the map shows that window's pings and track and fits to them;
  - a hover on the chart marks the ping on the map, and a click on a ping on the map marks its time on the chart;
  - the other layers keep the time window where they carry the time.
- **In the address:** the vessel, the span and the window, so a link opens the same view.
- **Bundled too:** `rb_map_bundle()` writes each vessel's series beside the tiles, so the page opens from a file.
- **Time as stored.** Times are shown as the data hold them, labelled UTC unless the caller names the clock
  (`time_label`). A dataset whose zone is not known is not converted.

## 3. Design

### 3.1 What lives where

- **ramb: the engine.** Generic, with no Icelandic column in it:
  - a function that adds the time panel to a map (§2), taking the pings, the columns to plot and mark, and interval
    tables for lanes, whose names follow ramb's own: `vid`, `time`, `start` and `end`, or a table from
    `rb_create_port_calls()`, `rb_create_voyages()` or `rb_create_record_windows()`;
  - the page's time panel and its links to the map;
  - the server's endpoint for one vessel's span, and the bundle's files for it.
- **me_code: the case study's viewer.** A script that reads the case study where it lies and builds its tables:
  - the pings as the hackathon reads them;
  - the flags of `analyses/speed_filter/`;
  - the trips the project's code made;
  - ramb's port calls from the mooring-site polygons.

  It then calls ramb. Private, like the data.
- **fishycode:** nothing in this plan. The vessel overview stays as it is (plan 047 ask a). The as-built flow map
  (plan 047 steps 2 and 5) can use the engine later.

### 3.2 How the page holds the time

- **One vessel's span, held whole.** The page asks for one vessel's span: from the server (an endpoint per layer,
  `vid` and span checked against the data before R sees them), or from a bundle's file for that vessel. It keeps:
  - the times and positions;
  - the columns plotted and marked;
  - the lanes' intervals.
- **The chart: uPlot,** pinned and loaded from jsdelivr as MapLibre is. It is the overview's engine, MIT licensed and
  small, and draws a few hundred thousand points. Written afresh for ramb's page, not copied from the overview.
- **The map, for the chosen vessel:** a GeoJSON source made in the browser from the held span. Each window move is
  either filtered by a MapLibre expression on the time or set as new data, whichever step 1 finds faster. The other
  vessels stay on the tiles as now.
- **Marks to meet** (assumed, measured in step 1):
  - a window move under 50 ms on 150 thousand pings (plan 047's mark; the overview's is 17 ms);
  - the case study's largest vessel (454 thousand) usable by its span;
  - one vessel's span arriving in under a second on 127.0.0.1.
- **Ramb's two rules** hold for the new function: the same construct out as in, and the caller's session left as it
  was. Its tables are copied into temporary tables on ramb's connection, as the tile functions' are.

### 3.3 Not taken

- **No copy of the overview's code** (`app.js`), and no deck.gl: ramb's page is MapLibre.
- **No time zone guessed.** The page converts nothing.
- **No logbook position drawn with the track** (decision 156).
- **Not a flow app.** Plan 047's step panel, accounting per step and live recomputation stay in plan 047.

## 4. Steps

Each step changes the page one piece at a time. Every click path is tested in a browser before the next, against a
checklist kept beside the code, as plan 046's `checklist.md`.

1. **Measure (read-only and scratch).**
   - On `dansk` and the case study: one vessel's span as JSON columns against a binary form (size and time on
     127.0.0.1), uPlot's draw at 100 and 450 thousand points, and the map's window move both ways (§3.2).

   **check:** §1 and §3.2 filled with the numbers; the faster route chosen.
2. **ramb: the time panel, one series, the window linked to the map.** The vessel chooser, the span, the chart of one
   column, a drag that sets the window on the map; on `dansk`.

   **check:**
   - tests (the function's arguments, the endpoint's refusals, the etiquette test);
   - the click paths;
   - the marks of step 1 met.
3. **ramb: marks, lanes and hover both ways.** Marks from a ping column, lanes from interval tables and from runs of a
   column, hover from chart to map and click from map to chart, the state in the address.

   **check:** tests; the click paths; the lanes equal the tables they came from (each interval drawn once).
4. **ramb: the bundle carries the time.** One file per vessel's series beside the tiles.

   **check:** the bundle opens from a file and shows what the served map shows, vessel by vessel (counts of pings and
   intervals equal).
5. **me_code: the case study's viewer (§3.1).** Its two speed-filter examples looked at in the viewer.

   **check:** the maintainer steps through the two examples of `analyses/speed_filter/`; what is missing goes back
   into steps 2-4.
6. **The record:** ramb's NEWS and an example script (`inst/examples/map/`, on `dansk`); a decision here; plan 047's
   step 3 marked done by this plan.

   **check:** `check_bookkeeping()`; R CMD check of ramb.

## 5. Checks

- **Bookkeeping:** every ping of a vessel's span is either in the window or outside it, and the chart and the map show
  the same pings in the window (counts equal). Every interval of a lane is drawn once.
- **Speed:** the marks of §3.2.
- **Bundle equals served,** vessel by vessel.

## 6. Asks

a. **Names:** `rb_map_time()` for the function (ramb's `rb_map_*()` family: map is the verb, time the object)? And
   `time_label` for the clock's label?
b. **Layout:** the chart under the map, as in the overview, or beside it on a wide screen?
c. **The span's default:** the whole series, the latest month, or the first trip?
d. **The vessel overview** (plan 047 ask a): stays as it is, or rebuilt later on this engine?
e. **The case study's viewer as a bundle** for the project's partners: the data are CNR-IRBIM's, so only with their
   agreement, and only inside the project.
f. **A play button** (plan 047 §2.2): now, or with plan 047?

## 7. Not in this plan

- More than one vessel on the chart at once.
- Plan 047's step panel, accounting per step and live recomputation.
- The overview's other panels (cards, trip table, history).
