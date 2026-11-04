# 278 — The depth and effort map as a folder that opens from its index.html: the effort summed in the browser

*2026-11-04. The maintainer's ask, 2026-11-04: "bundle this", the depth and effort map, "as a zipped export"; chosen
from three forms put to them, "Full filters, 0.01°". Built and tested by Claude (AI) the same day; no person has
checked it. ramb 2026.11.04.3 is e27a478 on ramb's local `main`, installed from it the same day at the maintainer's
word, not pushed; the bundle was built again with the installed package.*

## What was built

- **ramb's `rb_map_bundle(grids = )`.** A grid layer's rows are summed by cell at the cell sizes asked for. Each level
  comes from the finest level that divides it, in DuckDB. The rows are written in blocks of 128 x 128 cells
  (`grids/<id>/<level>/<bx>_<by>.js`), each zlib-compressed in base64: its sums as float32, the cell in the block as
  uint16, and each filter's column as codes into its values. The bundle block lists the blocks that exist, so the page
  never asks for a missing file.
- **The page's grid tiles.** A `bundle-grid://` protocol answers each tile MapLibre asks for. It takes the cell size
  that makes a cell one to two screen pixels (the `px` filter times that), reads the blocks under the tile, keeps the
  rows the tile's filters pass, sums them by cell, and encodes a vector tile with the fields the server's has (a sum,
  or a sum per km² of the cell). So the colours, histogram, popup and address work as served. The blocks read are
  kept, 256 MB at most.
- **Vector layers from `rb_map_tiles_table()`** go in too: its tiles say which hold a feature (`tiles_at`), and only
  those are written, to the bundle's zoom 9. Here, the ports.
- **fishycode's `products/depth_effort_map/bundle.R`**, from `grid_005.parquet`, writing
  `$FISHYDATA/exports/depth_effort_map_bundle/` and its zip.

## Chosen

- **Cells of 0.01, 0.02, 0.04, 0.1, 0.2 and 0.5 degrees**, by gear, year and fishing definition, everywhere the grid has
  effort. The finest is the maintainer's choice. The server goes to 0.001 degrees from zoom 9, the bundle stops at
  0.01.
- **A cell of one to two screen pixels**, where the server makes one of up to one. The opening view (zoom 6) then
  reads 0.02-degree cells, 21 blocks, and is drawn in about 6 s rather than reading the 0.01-degree level.
- **The opening colours** (served and bundled): the depth in gn_yl, in equal shares, at 52 %, the relief "combined",
  black place names (the maintainer's, from a view they liked: "the colours scale, not the location"), and the effort
  in blues at 60 % (Claude's at the maintainer's word, of six palettes at 60 and 85 % and blues at 45 %, compared in screenshots at
  two views: the one whose hue stays apart from the depth's greens and lets the relief show through).
- **The interpolated effort only.** The interpolation switch is left out: its grid of fixes would nearly double the
  effort's share.

## Measured

- **The folder:** 636 MB, 457 MB zipped. The effort is 351 MB (216 MB at 0.01 degrees, 603 blocks). The depth's tiles
  are 221 MB to zoom 9, the ports' 19,782 tiles 103 MB on disk, the names 15 MB. Built in 2.5 minutes from 71 M rows.
- **The bundle's tiles equal the server's.** Five tiles were made both ways at the same cell size (the bundle's `px` half
  the server's) and decoded cell by cell. Every server cell has its twin; hours and kW-hours per km² agree to 1.1e-7
  (float32); the fixes are equal. The cases: zoom 6 all fishing; zoom 6 flow, gear 6, 2020-2022; zoom 5, 2015-2019;
  zoom 4 flow, gears 6 and 15; zoom 6 gear 15 in 2024. The bundle has up to 122 cells more, beyond a tile's east edge,
  in the margin MapLibre does not draw.
- **Speed**, headless on this Mac: the opening view ready in 3-6 s, a view at zoom 6-10 in 1-2 s, one tile in
  0.1-0.5 s; about 215 MB of blocks held after a few views.
- **Opened as a file in Chrome and Firefox 159**, with no error in the map or the console:
  - a link with the gear, years and fishing definition;
  - each of the effort's controls, and hours or kW-hours;
  - a cell's popup;
  - the address;
  - the depth's controls and fits, as decision 277 found them.
- **ramb's tests** pass from its working tree: 2,620 expectations, none failing. They include a test of a grid's
  blocks read back as the page reads them, and of a table's vector tiles written only where they hold a feature.

## Found

- **Four port polygons from OpenStreetMap are invalid** (Abidjan CI-POR, Karatsu JP-U64, Kamień Pomorski PL-POT,
  Berezniki RU-S7M; a free hole). DuckDB's `ST_AsMVTGeom` then fails the whole tile that holds one: 25 tiles to zoom 9,
  none over Iceland. The served maps refuse the same tiles. `rb_map_bundle()` now leaves out a tile its function cannot
  make, with a message, where it stopped. Not fixed in the port reference.
- **A test harness's limit, not the page's:** the DevTools protocol did not return an 8 MB string from
  `Runtime.evaluate` (1 MB in 1.2 s). The tile comparison reads its tiles back in 900 kB pieces.

## Not settled

- **Safari and Windows are untested** (TODO 96).
- **Memory on a small machine:** the blocks held are capped at 256 MB, on top of the map's own.
- **The port polygons**, above.
