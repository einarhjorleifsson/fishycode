# The depth and effort map: every control and click path

The bathymetry map with the effort map's effort and ports as more layers (the maintainer, 2026-11-04). Its items
are the two maps' own, run on this page: `products/bathymetry_map/checklist.md` (D, K, R, N, B) and
`products/effort_map/checklist.md` (F, C, M, P, A). Only what the combination adds or changes is listed here. A change
to either map is tested here too.

How to test: as the two maps' lists say (a hover before a click; the browser pane visible for anything drawn on an
animation frame), or driven headless over the DevTools protocol.

## Load

- **L1** `/` opens at lon -19, lat 65, zoom 6, "Depth and fishing effort" ("Dýpi og veiðisókn"); the status line reads
  `zoom 6.0` once the map is idle; no error in the console.
- **L2** The groups, top down: Depth (the depth's colour, the contours), Relief, Effort, Reference layers (place names,
  ports), Base map, About. No "depth by cell": ramb draws one grid a map, here the effort.
- **L3** Drawn bottom up: the depth's colour, the relief's shading, the effort, the contours, the ports, the place
  names. The effort over the depth tints it where vessels fished, by its opacity (60 % when the page opens).
- **L4** What the page opens with, an address with none of them (the maintainer's choice of colours, 2026-11-04): the
  depth in gn_yl, in equal shares of the depths in view, at 52 %; the relief shaded "combined"; the place names in
  black; the effort in blues at 60 % (Claude's, of six palettes at 60 and 85 % and blues at 45 %, the one that stays
  apart from the depth's hues and lets it show). The bathymetry map and the effort map keep their own.

## The effort and the depth together

- **E1** The effort as on the effort map: its filters (F1-F6), colours fitted to the view (its L4, C1-C5) in blues, and a
  click on a cell, its hours, kW-hours and fixes (M1). At zoom 8 over Faxaflói, 374,220 cells drawn.
- **E2** The depth's controls as on the bathymetry map (D1-D10, K1-K4, R1-R9): its colours follow the view, beside the
  effort's own (Faxaflói at zoom 8 1.9-180 m).
- **E3** A click on a place name opens the name's popup, not the cell's under it (M2).
- **E4** Each of the six base maps keeps every layer in the same order, the effort and the depth drawn (B1).
- **E5** The address carries both maps' settings (the effort's filters, `ports=1`, the depth's and the names'), and a
  link opens with them.

## From R

- **R** `depth_effort_map()` opens the map (`lang`, `base`, `center`, `zoom`), on port 8797; `depth_effort_map_stop()`
  stops it and frees the port; a base map not in the list is refused. `server.R` serves it from a terminal.

## The bundle, opened as a file (`bundle.R`, ramb's `rb_map_bundle(grids = )`, since 2026-11-04)

How to test: open `exports/depth_effort_map_bundle/index.html` as a file in Chrome and in Firefox, headless over the
DevTools protocol and WebDriver BiDi (the browser pane shows a file outside the project only as a snapshot); as the
bathymetry map's F1-F6 for the depth (decision 277).

- **G1** `bundle.R` writes the folder (about 636 MB, 457 MB zipped): the depth's tiles to zoom 9, the ports' tiles that
  hold a port, the names, and the effort's blocks at 0.01-0.5 degrees; "interp" left out with a message, and the
  ports tiles its function could not make named (four invalid port polygons, decision 278).
- **G2** It opens at zoom 6 within 3-6 s with no error in the map or the console; a view at zoom 6-10 within 1-2 s.
- **G3** The effort's tiles equal the server's at the same cell size (the bundle's `px` half the server's): every
  server cell matched, h_km2 and kwh_km2 within 1.1e-7, n equal (`compare_node.mjs` and `mvt_compare.py` of
  2026-11-04, five tiles at zoom 4-6 with gears, years and both fishing definitions).
- **G4** Each effort control redraws the cells (gear, years, fishing definition, hours or kW-hours) and is kept in
  the address; a link with `gid`, `y1`, `y2` and `preset` opens with them; a cell's popup gives its hours, kW-hours
  and fixes.
- **G5** The ports, the names and the depth as on the server, in the bundle (the bathymetry map's F2-F6).

## Runs

- **2026-11-04, built** (uncommitted, on top of 5d6022d; ramb 2026.11.04.2 installed). Claude's run in headless Chrome
  and the browser pane, not checked by a person. L1-L3, E1-E5 and R passing: E5 `ports=1` written, and a link with
  `gid=6&y1=2020&y2=2022`, `depth_lo=5&depth_hi=200&depth_auto=0`, `names_colour`, `ports=1` and `lang=is` opened
  with each (the effort's tiles asked with the gear and years, 78,944 cells at zoom 8 over Faxaflói). The bathymetry
  and effort maps run again after their builders were split for this one (`effort_map_layers()`, and
  `bathymetry_map_build()`'s `cells`, `groups`, `palette` and `about`): their layers, groups, palette and About as
  before.
- **2026-11-04, the bundle** (uncommitted, on top of 1877ead; ramb 2026.11.04.3 by `load_all()` from its working
  tree). Claude's run in headless Chrome and Firefox 159, not checked by a person. G1-G5 passing (decision 278).
- **2026-11-04, the opening colours** (uncommitted, on top of 1877ead). Claude's run in headless Chrome and Firefox, not
  checked by a person. L4 new and passing, served and in the rebuilt bundle; the bathymetry map's opening values as
  before (deep, log, 100 %, standard shading, dark blue names).
