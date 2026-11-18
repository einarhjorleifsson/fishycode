# 328 — ogis on MapLibre 6.19: the library repackaged, so a bundle opened from its folder draws; plan 077 executed

*2026-11-18. Plan 077, at the maintainer's word ("start the MapLibre 6 plan", "Yes, push", "Yes, install"); its asks
b and c taken as recommended. Built, checked and measured by Claude (AI); Safari checked by the maintainer ("Safari
draws the maps fine"). The trial before it is recorded in plan 076, after step 7.*

## What was decided and why

MapLibre 5.x is frozen (5.24.1, 2026-11-11, its last). The reason recorded for staying on it (plan 076 §1.3: 6.x loads
only as ES modules, which a bundle opened from its folder cannot) held only for the library as published: MapLibre's
module has no imports, one export list and two uses of `import.meta.url`, and 6.17 made its worker run from a blob on
a page opened from a file. So ogis vendors 6.19.0 repackaged as classic scripts, pinned, updated by running a script on
purpose.

## What was built (ogis 2026.11.18.11, a9e450e; tests 70c62d8)

- `tools/vendor-maplibre.R`: the npm tarball, checked against the registry's SHA-512, made into `maplibre-gl.js` (the
  module wrapped, `import.meta.url` the script's own address, the export list the global `maplibregl`) and
  `maplibre-gl-worker.js` (the worker's code as a string, handed to `setWorkerUrl()` as a blob); it stops if a module's
  shape changes. `inst/COPYRIGHTS` says what was changed in MapLibre's code (BSD 3-Clause).
- The engine loads the worker's script before MapLibre; nothing else changed. The guard on queries for MapLibre 5's
  lost index stays until a reproduction shows 6 has done with it (plan 077 §3.6).
- `test-file.R`: a bundle opened from its folder (`file://`) draws outlines, labels and contours (the first test not
  over http); `tools/firefox-check.R`, the same in Firefox, by hand at each update.
- Two test fixes found by CI (70c62d8): a label test waits for MapLibre's `idle` event, not a fixed 0.3 s after
  `map.loaded()` (it failed on Ubuntu); Chrome's temporary folder is inside R's own during a test run (`--as-cran`
  noted the one left in the system's).

## Measured

| check | result |
|---|---|
| R CMD check | 0/0/0 locally (macOS, `--as-cran`); CI on Ubuntu, Windows and macOS passing (70c62d8) |
| a bundle opened from its folder | drawn in headless Chrome (the test, on all three systems in CI), headless Firefox 160 (271 areas, 119 labels, 32 contour lines), Safari (the maintainer) |
| beside 5.24.1, the same views | crossing transparent lines, a label at zoom 16 from tiles to 14, contours past their elevation tiles' zoom: alike |
| speed, 8,918 turned labels | open 0.47 s (5.24: 0.44 s), five zoom steps 1.68 s (1.69 s) |
| the published site | its maps load MapLibre 6.19.0 as repackaged; a live map drew 3,969 positions in view within a second |
| installed (R's library) | the knit, Rscript and `file://` tests pass against it, 79 checks |

A bundle carries 0.6 MB more (the worker in a file of its own).

## Open

MapLibre 6's new features, each its own if wanted (plan 077 §3.6): the guard's removal after a reproduction, OKLCh
ramps for the depth looks, blend modes for relief, the page's own fonts.
