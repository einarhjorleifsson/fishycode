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
- **F4** Metric: hours ↔ kW-hours per km²; the histogram is resampled and floor and cap refitted, with no tile reload.
- **F5** Cells: finer, fine, coarser.

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
- **A3** A `gid` the list does not hold (several gears, `6,7`) is added as "gears 6,7".
- **A4** A value the page does not offer is left out, and the default stands.

## Errors

- **E1** A refused tile: the status line says so, with the HTTP status.
- **E2** A server with no gazetteer: the names checkbox is disabled, "no gazetteer on this server".

## From R (`effort_map.R`)

- **R1** `effort_map(gear = "OTB", years = 2015:2020, palette = "deep", stretch = "equal")` opens the view with those
  values; `effort_map_stop()` ends the server.
- **R2** A server of the same version already on the port (from `server.R`) is used as it is; an older one stops with
  a message.
- **R3** A palette the page does not have, a gear nothing matches, or a floor not below the cap: an error that says so.

## Runs

- **2026-10-24, baseline (plan 046 step 1), at f74e4ef**, the page as of 2e8a8df (decisions 220, 224). All 29
  items pass. Claude's run in the browser pane, with the pane visible; not checked by a person. Found on the way, left
  for step 2:
  - F4: on kW-hours the cells' 98th percentile (10^5.19 at zoom 5, all gears and years) lies above the cap slider's
    top (10^5), so "Fit to view" stops short and 4 % of the cells in view (6,009 of 147,212) are above the slider;
  - A3, R1: several gears show as their ids ("gears 6,7,8"), not their names;
  - E1: the message says the server may be an older version for every refused tile, a wrong address included.
  Tile times: `$FISHYDATA/products/effort_map/bench/2026-10-24_baseline.csv` (summary in plan 046 §4, step 1).
