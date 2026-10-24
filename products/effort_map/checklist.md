# The effort map: every control and click path

Plan 046, step 1. This is the list each step of the plan is tested against, one item at a time, before the next step
begins. Every item that works on the page of decision 220 must still work after each step. An item a step removes on
purpose is struck out here in the same commit, with the step that removed it.

How to test:
- a click is preceded by a hover, as a person's is;
- the browser pane must be visible for anything drawn on an animation frame (the map, the histogram);
- tile times come from `bench.R`, run with no other load on the machine.

## Load

- **L1** `/` opens at lon -19, lat 65, zoom 5; the status line reads `zoom 5.0` once the map is idle.
- **L2** The gear list holds every gear in the grid, ordered by hours, each `name (FAO code)`; "all gears" first.
- **L3** The years run from the grid's first to its last year, both ends chosen.
- **L4** On the first idle, floor and cap are fitted to the cells in view (their 2nd and 98th percentiles); the colour
  bar and the histogram are drawn.
- **L5** The tile address carries `v`, the grid's write time.

## Filters (each reloads the tiles: "loading tiles…", then `zoom …`)

- **F1** Preset: `fishing` ↔ `fishing_flow`.
- **F2** Gear: one gear, then "all gears" again.
- **F3** Years: a from-year after the to-year is swapped.
- **F4** Metric: hours ↔ kW-hours per km²; the histogram is resampled and floor and cap refitted, with no tile reload;
  the sliders reach the fitted values (plan 046 step 2).
- **F5** Cells: finer, fine, coarser.
- **F6** Interpolation: on (the default, each fishing fix's hours spread along the track) ↔ off (each fix's hours in
  its own cell, the grid of `grid.R fixes`); the tiles reload, the address carries `interp=off`, and the totals are
  the same either way. Left out of the page when the fixes grid is not built.

## Colour (no tile reload)

- **C1** Palette: map, bar and histogram recoloured.
- **C2** Stretch: even on a log scale ↔ equal shares of the cells in view.
- **C3** Floor slider: its value and the bar's left label follow; the map recolours as it moves.
- **C4** Cap slider: the same, on the right.
- **C5** "Fit to view": floor and cap at the 2nd and 98th percentiles of the cells now in view.

## Map

- **M1** A click on a cell: a popup with hours and kW-hours per km² and the fixes.
- **M2** A click on a place name: its own popup, and no cell popup under it.
- **M3** Pan or zoom: the hash follows; the histogram is resampled on idle.
- **M4** A reload keeps the position.
- **M5** Names checkbox: off hides the labels and footprints, on shows them; "N names" beside it.

## Address

- **A1** `?preset=&gid=&y1=&y2=&metric=&px=&palette=&stretch=` sets the first view.
- **A2** `floor` and `cap` set the colour range and are kept, not refitted, on the first idle.
- **A3** A `gid` the list does not hold (several gears, `6,7`) is added under the gears' names and FAO codes
  ("Botnvarpa, Humarvarpa (OTB)"; plan 046 step 2).
- **A4** A value the page does not offer is left out, and the default stands.
- **A5** Every control writes its value into the address as it changes, a value at its default left out; the position
  stays in the hash, MapLibre's; a value the page does not offer is dropped from the address on load (plan 046 step 3).
- **A6** A reload, or the copied link opened afresh, gives the same view: every control, layer, opacity, base map,
  language and position.
- **A7** Floor and cap enter the address only when set by hand (a slider, "Fit to view") or given in it; a metric
  change, which refits, takes them out; a given value is kept exactly (`cap=300` stays 300).
- **A8** 🔗 copies the address and says so in the status line.

## Sidebar (plan 046 step 2)

- **S1** The effort layer's checkbox: off hides the layer, its controls and its legend; on brings them back, with the
  histogram redrawn.
- **S2** Opacity: the effort layer's opacity follows the slider, its value beside it.
- **S3** A layer's ⓘ opens its info, and a second click closes it.
- **S4** A group folds and unfolds; its layers stay as they are.
- **S5** At 375 px wide: the map fills the screen with no side scroll; ☰ opens the sidebar as a drawer, ✕ closes it;
  a control in the drawer works, and the map answers clicks after.
- **S6** Language: IS | EN switches every text, tooltip, status and popup label, and the numbers' format (5,0 and
  9.554 in Icelandic); `?lang=is` sets it at load. Gear names are the reference's, Icelandic in both.

- **B1** Base map: each of the six (Positron, Voyager, Dark Matter, Esri Ocean, Esri satellite, none) is drawn
  under the effort and the names; the effort's colours, filters, opacity and on/off, and the names' on/off, are kept
  through a change; filters, clicks and "Fit to view" work after it.

## Ports (plan 046 step 4)

- **P1** Ports, off by default: ticked, every port of the reference as tiles, the area (and lines) from zoom 8, a dot
  on every port further out and on a port that is only a point, names from zoom 7; "N ports" beside it, and its legend
  (area, point) under it.
- **P2** A click on a port: its name, pid, port code, whether the pid is its UN/LOCODE, and source, in the page's
  language; a place name over it speaks first, and an effort cell under it stays quiet.
- **P3** `ports=1` in the address, and from `effort_map(ports = TRUE)`; kept through a base map change; ticking it off
  and on writes the address.

## The config (plan 046 step 5)

- **K1** The page's groups, layers and texts come from `map.json` (the palettes and base maps from ramb's defaults),
  read by `map.R` when the server starts and written into ramb's page by `rb_map_serve()`, and served at
  `/config.json`; a server that sends no config makes the page say to restart it. (Step 5's `www/config.json` was read
  at each request, so an edit showed on a reload; since step 6 an edit to `map.json` needs a restart.)

## Errors

- **E1** A refused tile: the status line says so, with the HTTP status and the server's reason; a server older than
  the page (its `/meta` app version) is named as such (plan 046 step 2).
- **E2** A server with no gazetteer: the names checkbox is disabled, "no gazetteer on this server".

## From R (`effort_map.R`)

- **R1** `effort_map(gear = "OTB", years = 2015:2020, palette = "deep", stretch = "equal")` opens the view with those
  values; `effort_map_stop()` ends the server.
- **R2** A server of ramb's viewer serving the effort map already on the port (from `server.R`) is used as it is; any
  other (an older effort map) stops with a message.
- **R3** A palette the page does not have, a gear nothing matches, or a floor not below the cap: an error that says so.
- **R4** `effort_map(lang = "is", base = "ocean", opacity = 60, names = FALSE)` opens the view with them; a base or
  opacity the page does not take stops with a message.

## Runs

- **2026-10-24, baseline (plan 046 step 1), at f74e4ef**, the page as of 2e8a8df (decisions 220, 224). All 29
  items pass. Claude's run in the browser pane, with the pane visible; not checked by a person. Found on the way, left
  for step 2:
  - F4: on kW-hours the cells' 98th percentile (10^5.19 at zoom 5, all gears and years) lies above the cap slider's
    top (10^5), so "Fit to view" stops short and 4 % of the cells in view (6,009 of 147,212) are above the slider;
  - A3, R1: several gears show as their ids ("gears 6,7,8"), not their names;
  - E1: the message says the server may be an older version for every refused tile, a wrong address included.
  Tile times: `$FISHYDATA/products/effort_map/bench/2026-10-24_baseline.csv` (summary in plan 046 §4, step 1).
- **2026-10-24, plan 046 step 2** (uncommitted, on top of da3c2ba), in four parts, each tested before the next. Claude's
  runs in the browser pane, visible; not checked by a person.
  - The sidebar: L1-L5, F1-F5, C1-C5, M1-M5, A1-A4, E1, E2, R1-R3 pass again; S1-S5 new and passing. A drag in the
    test tool lasts 16 ms, so MapLibre's inertia carries the map far past it: the tool's flick, not the page's.
  - Base maps: B1 new and passing, for all six, with the effort's and the names' state kept through each change.
  - The three faults of step 1, fixed: F4 (the sliders widen to the values, from a fit or the address), A3 (gears by
    name), E1 (the server's reason, or an older server named).
  - Language: S6 new and passing. The pane's browser has no Icelandic number data and formatted "is" as English, so
    German, the same format, stands in where the browser lacks it.
  Tile times not rerun: `tiles.R` and the tile route are untouched, and `app.R` changed in a comment only.
- **2026-10-24, plan 046 step 3** (uncommitted, on top of ed1f7f0). Claude's run in the browser pane, visible; not
  checked by a person. A5-A8 and R4 new and passing; R1-R3, M2 (the names' labels on a base from the address), S5 (the
  phone header with 🔗) and E2 run again and passing. Two faults found and fixed on the way: a cap from the address came
  back rounded by the slider's 0.01 step on the log scale (300 as 302), now `step="any"`; and a language switch while
  tiles loaded left the status line in the old language. The copy test put a link on the maintainer's clipboard.
  Tile times not rerun: the tile code is untouched.
- **2026-10-24, plan 046 step 4** (uncommitted, on top of 79e2d1c). Claude's run in the browser pane, visible; not
  checked by a person. P1-P3 new and passing; M1 (an effort cell beside the ports), B1 (satellite) and S6 run again and
  passing. The app's version went from 4 to 5 with the new route: before the restart, `effort_map()` refused the
  running server as older (R2, on a real server). Found on the way: the reference's `unlocode` is a flag (the pid is
  the port's UN/LOCODE), not a code, so the popup says so; Reykjavík's port is one multipolygon (the old harbour and
  Sundahöfn) with its point in Sundahöfn; 4 OpenStreetMap areas are invalid geometries, drawn as they are.
- **2026-10-24, plan 046 step 5** (uncommitted, on top of 2963436). Claude's run in the browser pane; for part of it
  the page was hidden (the app's window not in front), so the map drew slowly and those checks waited longer. Every
  item run again and passing, K1 new: L1-L5, F1-F5, C1-C5, M1-M5, S1-S6, B1, P1-P3, A1-A8, E1, E2 (the names' missing
  text from the config), R1-R4 (`effort_map()` now reads the palettes and base maps from `config.json`). Two faults
  found and fixed on the way: with the ports row the sidebar could scroll, and a scrollbar appearing (an ⓘ opened)
  moved every button 15 px left, so a second click missed (now `scrollbar-gutter: stable`); and a page opened with the
  effort off never fitted its colours when the effort was turned on (the first fit now waits for cells). The copy test
  put a link on the maintainer's clipboard again.
- **2026-10-24, plan 046 step 6** (on top of f74fa96; ramb 2026.10.24.1, run from a scratch library, then pushed as
  817fc1a and installed from GitHub, where the page loaded again as before). The effort map rebuilt on ramb's viewer (`map.json`, `map.R`; `app.R`, `ports.R` and `www/`
  retired), run on port 8795 beside the old page on 8791. Claude's run in the browser pane; the pane was closed twice
  during it, and the page then never started (MapLibre's `load` waits for a drawn frame): those checks were run again
  with it open. Every item run again and passing on the rebuilt map, with the same numbers as the old page on the same
  views (the fit, the sliders, the gear labels, the place names' popup line for line). E1's refused tile now shows
  ramb's reason (`px is 0.5, 1, 2`); R2 refused the old page's server on 8791 as an older effort map. Tile times through
  ramb's route against the old route, the same 30 tiles at zoom 6-8: median 225 against 226 ms, worst 645 against 617
  ms; the bytes of one tile vary between two fetches from the same server (by up to 0.25 %, DuckDB's parallel sums), so
  no byte comparison is made. One fault found and fixed on the way: the ports' count text was lost in the move to
  `map.json`.
- **2026-10-24, the interpolation switch** (decision 228; uncommitted, on top of 95bf81a). Claude's run on the server
  only: the session was not open in a window, so the page could not draw. F6's server side passes: the config carries
  the filter in both languages, on by default; tiles come back both ways (16 tiles at zoom 6-9, median 253 ms off
  against 353 ms on); `interp=maybe` is refused with the server's reason; `effort_map(interpolate = FALSE)` writes
  `interp=off`. The two grids' totals are equal. The click in the page waits for the window.
