# 220 — The effort map: fishing effort at a cell size that follows the zoom, as vector tiles, in a page and from R

*2026-10-24. The maintainer, using v0 (decision 219) as an end user: coarse cells when zoomed out and finer as one
zooms in ("even build things directly on javascript"), the hours spread along the track, a colour scale that fits the
data's distribution, tidyterra's palettes, and an R function that opens a view in RStudio. Built, measured and written
by Claude (AI); the maintainer tried each step on the page. Not checked by a person beyond that.*

## What was built

`products/effort_map/`, beside the vessel overview and on its pattern (an R service on 127.0.0.1, a page with pinned
libraries):

- **`grid.R`**, the base grid: v0's AIS trail, fishing fixes summed by 0.001° cell, gear, year and preset (`fishing`,
  `fishing_flow`), to `$FISHYDATA/products/effort_map/grid.parquet` (524 M rows, 5.1 GB, about 3 min), and a copy on
  0.005° cells (71 M rows, 1 GB). The build stops unless the hours, kW-hours and fixes per preset, gear and year are
  the trail's (731 of 731).
- **`tiles.R`**, one vector tile: DuckDB sums the grid to a cell of about one screen pixel at the zoom (0.5 or 2 on
  request), whole cells only, and writes it with `ST_AsMVT`. A cell that is a multiple of 0.005° is read from the
  copy, whose sums equal the fine grid's to 1e-14.
- **`app.R`** (the httpuv app), **`server.R`** (from a terminal), **`effort_map.R`** (from an R session: the app in the
  background, the view in RStudio's Viewer, set by its arguments: gear by id, FAO code or name, years, preset,
  metric, cells, palette, stretch, floor and cap, centre and zoom).
- **`www/index.html`**: MapLibre GL JS 4.7.1 and Carto's basemap. Filters change the tile address; the colour, its
  floor and cap, are in the browser. The page's address sets its first view.

## Choices, and what they rest on

- **Hours spread along the track** (maintainer): a fix stands for the time to its next fix, so its hours go in
  1-minute steps along the straight line to that fix, same vessel and voyage, for gaps up to 30 minutes. Longer gaps
  (7 % of the fishing hours) stay on the fix. Without it, cells finer than the distance between fixes showed dots.
- **Density, not totals:** hours and kW-hours per km², so a colour means the same at every cell size.
- **Gear is `gid_used`**, the logbook's gear corrected by the landing's (plan 014 3j). The first grid used `gid`, the
  logbook's as recorded, and showed 18 vessels' sea cucumber dredging off the east coast, 2019-2025, as bottom trawl
  (the maintainer saw it; their landings and voyage gear say dredge, towing at a median 2 knots).
- **Squares, not H3:** H3 tiles took 0.7-1.1 s against 0.07-0.27 s, measured on the same tiles; a hexagon's cells
  cannot be cut to a tile by a range test, and H3's sizes step by 7 in area.
- **Palettes by lightness:** ten palettes whose OKLab lightness changes steadily (viridisLite's and tidyterra's
  `deep`, `scotland`, `population_dens`, two bathymetric, `gn_yl`, `blues`), two terrain palettes kept to compare.
  A stretch even on a log scale, or in equal shares of the cells in view, with their histogram under the colour bar.
- **Cells:** the maintainer's choice, one pixel per cell by default. Measured, the worst tile at zoom 5-8: one pixel
  3.5-5 MB in 0.2-0.5 s, half a pixel up to 25 MB in 1.3 s, two pixels about 1 MB.

## Not done

- How the product is versioned (TODO 140): the grid is rebuilt from v0's trail by hand, after a rebuild.
- The page does not write its filters into its address, so a link shows the place, not the gear or years.
- Haul windows that hold steaming or a position jump draw lines across land and to harbour (TODO 142).
- The v0 station table still carries the logbook's gear as recorded (TODO 140).
