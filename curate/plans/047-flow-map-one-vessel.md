# 047 — The flow on one vessel: ramb's map viewer built around the flow diagram, a vessel followed from its pings to its catch

**status:** proposal — written 2026-10-25 at the maintainer's request; none of its steps built; the viewer, the flow
document, the trail and the vessel overview measured the same day (read-only); the other viewers in §1.6 are leads
from a web search, not tried; later the same day ramb gained parts its steps can use, and step 1 one of its
measurements (§8) · **2026-10-25** · **see:** plan 046 and decision 227 (the viewer), decision 215 (the product is the
link), `docs/one_flow.qmd` and its diagram (version 3), plan 030 §7 (the vessel overview), plan 033 (the book), plan
013 (ramb's steps), TODO 145

Drafted with AI assistance (Claude) on 2026-10-25; a person has not yet checked it. What §1 calls measured, Claude
measured; the rest is proposal.

The maintainer, 2026-10-25:
- looking for inspiration for `rb_map` in other apps that show VMS or AIS data;
- "the plan for the rb_map should be centered around the diagram flow - i.e. clean the track, assign trip, ... split
  the catch";
- "the thinking is that a user can operate e.g. on a single vessel but e.g. follow the full process through on the
  app".

## 1. What is at hand (measured 2026-10-25)

### 1.1 ramb's map viewer (2026.10.25.1)

- **Has:** three kinds of layer: a grid (tiles cut by DuckDB on request, filters the server checks, the page's palette,
  stretch, floor, cap and histogram), vector tiles from a table (`rb_map_tiles_table()`), and GeoJSON. Groups that fold,
  texts in several languages, base maps, popups, legends and counts, and the whole view in the address.
- **Lacks, for this plan:**
  - no time in the page: no time filter, timeline or playback;
  - no chart linked to the map;
  - a layer's data are fixed when the server starts (only a grid's tiles take the user's values), so a choice in the
    page cannot recompute a vessel's fixes;
  - one grid per map;
  - a sidebar of layers and their controls, not a sequence of steps with text and counts.
- **Built for big tables:** tiles are cut on request. One vessel's data are small (§1.4) and are better held whole in
  the browser.

### 1.2 The flow, row by row

From `docs/one_flow.qmd` and its diagram, version 3. The ramb functions are those of ramb's reference index.

| Row | What it gives each fix | Its sources, best first | ramb |
|---|---|---|---|
| Vessel | the vessel | its own track where feeds agree; the register's dated MMSI; logbook or landing on the day; continuity of the device | `rb_link_vessel_tracks` |
| Flag pings | set aside or kept, and the port it lies in | invalid, duplicate, impossible (set aside, not dropped) | `rb_flag_ping_invalid`, `_duplicate`, `_impossible`, `_port` |
| 1. Trip | port call, voyage, trip | declared trip; voyage from the track; gaps and device power; then link and reconcile T1 and T2 from ranked witnesses | `rb_create_port_calls`, `rb_create_voyages`, `rb_add_voyages`, `rb_link_trip_voyages`, `rb_link_trip_landings`, `rb_add_trip_time`, `rb_add_logbook_trip` |
| 2. Record | the logbook record and its phase | haul with t1-t4 or positions; period × area; trip. Candidates kept, one assignment | `rb_create_record_windows`, `rb_link_record_pings`, `rb_link_record_events`, `rb_create_record_stretches`, `rb_link_record_stretches`, `rb_link_record_sets`, `rb_add_record`, `rb_create_record_pings`, `rb_limit_record_duration` |
| 3. Gear | gear, class, width | record, landing, licence, predicted from the track | `rb_extract_metier`, `rb_predict_gear_width`, `rb_fill_gear_width`, `rb_standardise_gear_meshsize` |
| 4. Fishing? | fishing, not fishing or undecided, with the reason | haul window and speed; phases; a track model; the gear's speed range. Presets, or the user's filter (decision 215) | `rb_add_fishing` |
| 5. Effort | the time the fix stands for | hours (gaps capped), kW-hours, pressure | `rb_add_effort`, `rb_cap_effort` |
| 6. Catch | its share of each unit's catch | the unit's catch split by time over the fixes the filter keeps; kg in = kg out | `rb_add_catch_units`, `rb_share_catch` |
| 7. Products | — | grids, the data call, checks of what was delivered | — |

Down the side of the diagram runs validation: each answer checked where something better is known. Every row puts every
fix in one outcome, with its basis.

### 1.3 The Icelandic outputs, by row (`curated/`, the build of 2026-10-23)

The trail's columns, grouped by the row that gives them:
- **vessel:** `vid`, `mmsi`, `provider`;
- **pings:** `pos_basis`, `speed_basis`, `interval_flag`. `curated/ais/ping` holds the kept pings, with their port call
  and voyage and no flag column; where the set-aside pings are kept is measured in step 1;
- **trip:** `port_call_id`, `voyage_id`, `.tid_voyage`, `schema_voyage`, `n_tid_voyage`, `.tid`;
- **record:** `.sid`, `schema`, `n_sid`, `phase`, `phase_frac`, `win_basis`, `events`, `nearest_event`, `sid_gps`,
  `n_sid_gps`;
- **gear:** `metier`, `gear`, `target`, `target2`, `gid`, `gid_landing`, `gid_used`, `gid_basis`, `gear_class`,
  `gid_voyage`, `gear_voyage_basis`;
- **fishing:** `s1`, `s2`, `fishing`, `fishing_flow`, `fishing_flow_basis`, `leisure`;
- **effort:** `dt_sec`, `hours`, `kw_hours`, `effort_basis`, `kw_basis`.

Beside it: `curated/ais/` `port_call.parquet`, `voyage.parquet`, `voyage_gear.parquet`, `trail_match` (the candidate
links) and `catch` (the shares, by year); the logbook's trip, station, station_window, catch and lid_map; the landings;
the reconciled trips.

### 1.4 One vessel's size (the trail, 2025)

| Gear class | Vessels | Median fixes | Most fixes | Median voyages | Median hauls |
|---|---|---|---|---|---|
| towed | 115 | 111,776 | 147,432 | 51 | 584 |
| static | 190 | 2,985 | 135,761 | 45 | 37 |
| jigged | 773 | 1,591 | 113,477 | 28 | 24 |
| other | 5 | 5,543 | 7,601 | 30 | 89 |
| none on any fix | 826 | 347 | 134,904 | 3 | 0 |

The largest vessel-year is about 150 thousand fixes. That is small enough to hold whole in the browser, as the vessel
overview does.

### 1.5 The vessel overview (plan 030 §7): one vessel, already in the browser

- **How it works:** one vessel's answers come as small parquet files (17 KB to 1.7 MB a vessel-year), held in
  DuckDB-WASM. deck.gl filters the pings to the time window on the graphics card. A uPlot speed chart carries trip bands,
  haul bars, landing triangles and the activity record's lanes, and a drag on it sets the window.
- **How fast:** a window move redraws in a median of 17 ms on the busiest vessel-year (147,432 pings).
- **Also:** the state in the address, cards and a trip table, a History tab.
- **What it is not:**
  - it shows the flow's outputs, not the flow: no order of steps, no accounting per step, no choice for the user;
  - it is fishycode's, on Iceland's columns and its own endpoints and engine (deck.gl), not ramb's (MapLibre).

### 1.6 Other viewers (a web search, 2026-10-25; leads, not tried)

- **Global Fishing Watch's map:** a time bar, and a vessel's profile with an activity timeline. Events lie along the
  track (fishing, port visits, encounters). Reports for an area, saved workspaces.
- **kepler.gl's trip layer and deck.gl's TripsLayer:** a track played over time, with a slider for how long the trail
  lasts.
- **ICES fisheriesXplorer's VMS module** (Shiny, February 2026): maps by gear; the figure and its data downloaded from
  the app.
- **EMODnet's vessel density:** monthly and yearly layers of one grid, with the unit stated.
- **The Irish iVMS Shiny app** (WKSSFGEO 2022, p. 7): pots hauled, gear length hauled and track length, by vessel,
  fleet, place and time. Not public.

### 1.7 ramb's example data, by row (from the catalogue's labels; columns not yet checked)

- **Flags, port calls, voyages:** `dansk` and `dansk_harbours` (Danish AIS, behaviour labelled), which the book's
  `flow_pings` and `flow_trip` chapters use. Also `whacks1` (impossible positions) and `wkssfgeo_cnr_*` (voyages by two
  rules).
- **Records with times:** `trawlsurvey` and `trawlsurveytows` (an Icelandic survey's tracks and tows).
- **Static gear, set and haul labelled:** `wkssfgeo2_irl_pots`, `wkssfgeo2_irl_gillnets`, `wkssfgeo2_it_pots`. Also
  `ird_mg_gillnet` and `creel`.
- **Catch:** none of the labels names logbook catch or landings, so the Catch row cannot be shown on them as they are
  (checked in step 1).

## 2. The app

### 2.1 What the user does

- **Picks a vessel and a span:** a year, a trip or a voyage. In Iceland by `vid` or name; on ramb's data, the dataset's
  vessels.
- **Steps down the diagram's rows:** Vessel, Flag pings, Trip, Record, Gear, Fishing, Effort, Catch, Products. Each
  step:
  - **says what it took for this vessel:** which sources exist, and which answered (the basis), fix by fix;
  - **accounts:** every fix in one outcome, the unjudgeable counted too (decision 155). A table of counts whose total
    is the vessel's fixes, and at Catch kg in = kg out;
  - **draws:** the fixes coloured by the step's result, the step's own objects (port calls, voyages, haul windows,
    set-aside pings), and its lane on the timeline;
  - **keeps what came before:** earlier steps stay as layers and lanes to turn on.
- **Operates where the flow leaves the choice to the user** (decision 215): the fishing filter (preset `fishing` or
  `fishing_flow`, or a speed range and time window of their own), the effort measure, and so the catch split. Every
  count and the catch map follow at once, with kg in = kg out shown.
- **In the live mode (§2.3), also a step's method and parameters:** for example the voyage rule (`cnr` or `iapesca`) or
  the impossible-speed limit, rerun for this vessel from that step down.

### 2.2 Two linked views

- **The map:** the fixes, the step's objects, a base map.
- **The timeline under it:** time across and the fix's speed as a line, as in the overview's speed chart and Global
  Fishing Watch's vessel timeline. One lane per step: port calls, voyages and trips, records' windows and phases,
  fishing, effort, catch shared.
- **How they link:** a drag on the timeline sets the time window, and the map shows that window's fixes and zooms to
  them. A click on a fix marks its time. A play button moves the window along, as kepler's trail does.
- **The address holds the state:** the vessel, the span, the step, the window and the choices, so a link opens the same
  view.

### 2.3 Two modes

- **As built** (fishycode, the Icelandic data): the step results are read from `curated/` as the build left them.
  Nothing is recomputed but the user's filter, effort and catch split, which are cheap on one vessel. This shows what
  the product says, and where each value came from.
- **Live** (ramb, any data): the vessel's standard inputs (pings, port list, trips, records, catch, landings, whatever
  exist) go through the flow's `rb_` steps in the R session, step by step. This shows how the product is made, on ramb's
  example data or a user's own vessel. A method chosen at a step reruns the flow from that step down.
- **Both** use the same page and the same list of steps. The as-built mode comes first (§4).

## 3. Design

### 3.1 What lives where

- **ramb: the engine.** Generic, with no Icelandic column in it.
  - **A track layer:** one vessel's fixes held whole in the browser, not tiled (§1.4: at most about 150 thousand fixes
    a vessel-year). They are coloured and filtered by a property and by the time window, all in the browser.
    Intervals (port calls, voyages, windows) are a second shape of the same layer.
  - **A timeline panel** linked to the map: lanes from interval tables, a line from the fixes; brush, click and play.
  - **A step panel:** an ordered list of steps, each with its text, its count table, and the layers and lanes it turns
    on. It takes the place of the layer list when the map is a flow.
  - **Data computed on request:** a layer whose data come from parameters, as a grid's tiles do now, for the user's
    choices. The server checks each value against the step's declared choices before R sees it.
  - **`rb_map_flow()`** (name to settle, §6 f): builds the step map from a vessel's standard inputs by calling the
    flow's `rb_` steps (the live mode). Shown on ramb's example data in its article.
- **fishycode: `products/flow_map/`** (name to settle). The as-built mode: one `vid` and span from `curated/`, its steps
  declared over the trail's columns (§1.3), the user's filter on its fixes as in decision 215.
- **The vessel overview (plan 030) stays as it is in this plan.** Whether its proven parts (the uPlot timeline, the
  window on the graphics card) move into ramb's engine, with the overview rebuilt as a configuration over it, is ask a.

### 3.2 The steps, row by row

| Row | The step shows (map, timeline, counts) | The user's choice | Live: ramb | As built: fishycode |
|---|---|---|---|---|
| Vessel | the vessel's identity, its MMSIs and feeds with their periods; fixes by feed | — | `rb_link_vessel_tracks` | `vid`, `mmsi`, `provider`; the register |
| Flag pings | the set-aside pings apart from the kept ones, and the port pings; pings in = kept + set aside | live: the impossible-speed limit | `rb_flag_ping_*` | step 1 |
| 1. Trip | port calls, voyages, declared trips and landings, and the links between them; T1 and T2 with their witnesses | live: the voyage rule | `rb_create_port_calls` … `rb_add_trip_time` | `port_call`, `voyage`, reconciled trips, `lid_map`; `port_call_id`, `voyage_id`, `.tid` |
| 2. Record | haul windows and phases on the timeline; candidates against the one assignment; placeholder times flagged | — | `rb_create_record_windows` … `rb_add_record` | station, station_window, `trail_match`; `.sid`, `phase`, `win_basis` |
| 3. Gear | each operation's gear and its source | — | `rb_extract_metier`, `rb_fill_gear_width` | `gid_used`, `gid_basis`, `gear_class` |
| 4. Fishing? | fixes fishing, not fishing or undecided, with the reason, by preset or the user's filter | the filter: a preset, a speed range, a window | `rb_add_fishing` | `fishing`, `fishing_flow`, `fishing_flow_basis` |
| 5. Effort | each fix's time, capped gaps; hours and kW-hours of the kept fixes | hours or kW-hours | `rb_add_effort`, `rb_cap_effort` | `dt_sec`, `hours`, `kw_hours`, `effort_basis` |
| 6. Catch | each unit's kg split over its kept fixes by time; units that found no fix moved up; flagged kg and landed excess apart; kg in = kg out | follows the filter | `rb_add_catch_units`, `rb_share_catch` | `curated/ais/catch`; the logbook catch and landings |
| 7. Products | the vessel's own effort and catch grid, and its totals | the cell size | the effort map's grid for one vessel | — |
| Validation | where a better record exists (recorded tows), the step's answer against it, as counts | — | — | the allocation audit (decision 155) |

### 3.3 Not taken

- **The vessel overview's code is not copied into ramb** (never a second copy). What moves, moves (ask a).
- **No logbook position is drawn with the track** (decision 156).
- **Vessel data stay on 127.0.0.1.** A public demo only on ramb's example data (ask g).

## 4. Steps

1. **Measure (read-only).**
   - For three vessels (a trawler, a longliner, a small jigging boat): each row's outputs in `curated/` and their counts,
     and where the set-aside pings are kept.
   - The time to open one vessel-year in the browser and move the window: MapLibre's GeoJSON source (points and a time
     filter) against deck.gl (as in the overview).
   - Which of ramb's examples can run which rows live, and what the Catch row lacks.

   **check:** §1 filled with the numbers; a table of rows × examples.
2. **A prototype on the viewer as it is.** In fishycode, scratch first, then `products/`: one vessel-year as built, the
   rows as groups, each step's layers made in R, its counts in its info text; no timeline.
   **check:** the maintainer steps through one vessel; what is missing is written into steps 3-4.
3. **ramb: the track layer and the timeline panel, linked.** With tests, on ramb's example data.
   **check:** a window move under 50 ms on 150 thousand fixes (the overview's 17 ms is the mark); every click path in a
   checklist, as in plan 046.
4. **ramb: the step panel and data computed on request,** each choice checked by the server.
   **check:** tests; a refused choice says why.
5. **fishycode: the flow map as built, every row.** The user's filter at Fishing is carried through Effort and Catch,
   with kg in = kg out at every setting.
   **check:** each step's counts sum to the vessel's fixes, and the numbers equal a query of `curated/` for the same
   vessel (three vessels).
6. **ramb: `rb_map_flow()`, the live mode,** on ramb's examples, with the rows each can show; and the article "The flow
   on one vessel".
   **check:** the article renders; each live step equals its `rb_` function run by hand.
7. **The record:** a decision, the checklist, ramb's NEWS, and the `products/` row of AGENTS.md.
   **check:** `check_bookkeeping()`.

## 5. Checks

The checks are bookkeeping (decision 155):
- **each step:** its outcomes sum to the vessel's fixes, the unjudgeable included;
- **catch:** kg in = kg out under every filter;
- **as built** equals `curated/`;
- **live** equals the functions run by hand;
- **speed:** the marks set in step 3.

## 6. Asks

a. **The vessel overview:** keep it beside the flow map, or move its timeline and window into ramb's engine and rebuild
   the overview on it, with the flow map a second view of the same engine?
b. **The default span:** a vessel-year, a trip or a voyage?
c. **"Operate":** only the user's filter (decision 215), or also the methods and parameters of the other steps (live)?
d. **Which mode first:** as built (Iceland) or live (ramb's examples)?
e. **Example data for the whole flow:** ramb has none with catch or landings. A made-up vessel, the survey for the rows
   it can show, or another public dataset?
f. **Names:** the app's (flow map?) and ramb's function (`rb_map_flow()`?).
g. **A public demo:** on ramb's examples, opening from a file like the vessel demo (decision 153)?

## 7. Not in this plan

Taken from the other viewers (§1.6), for a later round of the viewer:
- totals for an area drawn or clicked, with a download;
- two periods compared, by a swipe or a difference;
- raster overlays as layers (bathymetry, closed areas);
- a time slider on the effort map's grid.

Also left out: more than one vessel at a time, and logbook positions (decision 156).

## 8. Since written (later on 2026-10-25)

*Built in ramb by Claude (AI) at the maintainer's request, each piece checked in a browser and by R CMD check, and
recorded in ramb's NEWS (2026.10.25.2 to .4). None of the plan's steps is done; these are parts they can use.*

- **The quick look as layers that compose** (ramb 2026.10.25.4). `rb_map_pings()` draws pings as points coloured by a
  column. `rb_map_track()` joins them into each vessel's line, broken at silences of over `gap_h` hours, and with a
  column cut into runs of its value, each run joined to the next. A second `rb_map_track()` adds a second track by
  another column, each a layer turned on and off in the page. A map is served when printed at a console:
  `pings |> rb_map_track(fishing_flow) |> rb_map_track(provider) |> rb_map_pings(c(fishing_flow, provider, speed))`.
- **A choice in the page** (`rb_map_layer(variants =)`): styles to choose between under a layer, kept in the address,
  with nothing fetched again. The pings' "Colour by" uses it.
- **For step 1, measured:** vid 1977's 2025 (147,432 fixes, the largest vessel-year, §1.4) as vector tiles from
  DuckDB. The map is built in about 1 s and its first-view tile, 6.4 MB, comes in 0.12 s. With the line cut at every
  ping (147,395 runs) it takes 0.6 s and 3.4 MB. So a vessel-year can be drawn from tiles without being held in the
  browser. A timeline linked to the map (§2.2) still needs the fixes in the browser, with the overview's 17 ms window
  move as the mark (§1.5).
- **For step 2:** the as-built prototype can be these functions over the trail's columns, one vessel and year, a track
  or pings layer per row. Tried on vid 1977: the Fishing row's `fishing_flow` as a coloured track and as a colour of
  the pings, beside `provider` and `speed`. Untried: the other rows' columns, such as `voyage_id`, `phase` and
  `fishing_flow_basis`. What the functions lack for the plan: the order of steps, the accounting per step, and the
  timeline.
- **Ask f, in part:** the layer functions' names, `rb_map_pings()` and `rb_map_track()`, are the maintainer's
  (2026-10-25). The app's own name is still open.
