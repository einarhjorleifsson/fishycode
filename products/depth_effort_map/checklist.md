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
  names. The effort over the depth hides it where vessels fished, by its opacity (85 % when the page opens).

## The effort and the depth together

- **E1** The effort as on the effort map: its filters (F1-F6), colours fitted to the view (L4, C1-C5) in magma, and a
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

## Runs

- **2026-11-04, built** (uncommitted, on top of 5d6022d; ramb 2026.11.04.2 installed). Claude's run in headless Chrome
  and the browser pane, not checked by a person. L1-L3, E1-E5 and R passing: E5 `ports=1` written, and a link with
  `gid=6&y1=2020&y2=2022`, `depth_lo=5&depth_hi=200&depth_auto=0`, `names_colour`, `ports=1` and `lang=is` opened
  with each (the effort's tiles asked with the gear and years, 78,944 cells at zoom 8 over Faxaflói). The bathymetry
  and effort maps run again after their builders were split for this one (`effort_map_layers()`, and
  `bathymetry_map_build()`'s `cells`, `groups`, `palette` and `about`): their layers, groups, palette and About as
  before.
