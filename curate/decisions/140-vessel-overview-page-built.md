# 140 — The vessel overview's page: a map, a time-speed plot and a slider on one time window (plan 030 step 4)

*2026-10-18. On the maintainer's go ("go on to step 4"); code, checks and this record by Claude (AI-assisted). A
person has not yet used the page. Nothing is written under `$FISHYDATA`.*

## Built

`products/vessel_overview/www/`: `index.html` (the layout) and `app.js` (the logic), served by the R service of
decision 139, which puts the Mapbox token into the page as it serves it. Start it from the repository root with
`Rscript products/vessel_overview/server.R` and open `http://127.0.0.1:8790/#vid=1977`.

- **Libraries**, pinned to exact versions and loaded from jsdelivr: DuckDB-WASM 1.28.0, deck.gl 8.9.35, uPlot
  1.6.30. They are not copied into the repo: DuckDB-WASM's engine is tens of MB uncompressed. A server with no
  internet access would need local copies.
- **Data:** each panel's rows come from the service once, as parquet, and DuckDB-WASM holds them as tables (ask h).
  The landings and trip summaries are SQL in the page.
- **The map** (deck.gl) follows the maintainer's asjo app (plan 030 §4.2):
  - pings coloured by speed (capped at 12 knots), with radii clamped to 2-6 px;
  - each voyage a thin path, highlighted on hover;
  - the last position a larger point, with the vessel, time, speed, heading and position in its tooltip;
  - the latest trips' logbook stations as lines, the chosen trip's in red.

  The basemap is Mapbox's light style as raster tiles with the `.Renviron` token (ask c). No second map library is
  needed.
- **One time window, three views:**
  - a drag on the time-speed plot (uPlot), the two-handle slider, the Play button, Last month and Whole year all set
    the window;
  - the map filters its pings to the window on the GPU, and the plot zooms to it;
  - hovering on the plot marks the ping on the map, and hovering on a ping moves the plot's cursor;
  - clicking a logbook trip loads its year if needed, sets the window to the trip and fits the map to it.
- **Panels:** the photo with its credit ("internal use only"); the register today; the register history to
  2023-12-19, labelled as such (ask g); the latest 20 landings by landing (port, gear, tonnes, species codes); the
  latest 10 logbook trips.
- **The address** holds the vessel (`#vid=1977&year=2025`), so a view can be linked and the back button works.

## Checked (in the desktop app's browser pane)

- **Opened** for vids 2652, 1977 (2025, and 2026 through a trip), 2757 (through the search) and 3739. Every panel
  fills, or says it is empty: 3739 has no photo, logbook trip or register history. No console error.
- **Responsive:** 40 window moves on vid 1977's 2025 (147,432 pings), each timed from the move to the map's next
  frame. Each took 7-10 ms (median 8), against the step's 50 ms. A first run had one move at 3.4 s while the page was
  still loading its map tiles; the pane also holds back frames when it is not looked at.
- **The token:** the served page carries it, and no file in the repo does.
- **Not checked:** the hover link between plot and map (it shows in a screenshot, but nothing measured it), Play, and
  the time to load a vessel (the pane's timings are unreliable).

Two bugs were found and fixed on the way:
- fitting the map to a vessel in port all month failed (a box of zero size);
- a trip in another year than the one loaded clamped the window to the year's last minute.

## Seen while checking (not looked into)

- Vid 2652 left the register on 2024-07-17 ("sold"), but its pings go on to 2024-12-30, in a foreign port by then.
- Vid 2757, as in decision 139, lies in port in its last month.

The page is meant to make such things visible. Which of them are key errors is for the key's review (TODO 25).
