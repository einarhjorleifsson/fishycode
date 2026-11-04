# 277 — The bathymetry map as a folder that opens from its index.html, with no R: ramb's `rb_map_bundle()`

*2026-11-04. The maintainer's ask, 2026-11-04: to share "this whole construct" with "the map and the data ... in a
selfcontained directory", opened "by just opening an index.html", "non-dependent on R"; "this will only be shared
in-house at MFRI". Built and tested by Claude (AI) the same day; no person has checked it. ramb 2026.11.04.2 is 05247e1
on ramb's local `main`, installed from it the same day at the maintainer's word, not pushed. The bundle was built
with it loaded from the clone before the commit.*

## What was built

- **ramb's `rb_map_bundle(map, dir, maxzoom, fit, overwrite)`.** It writes `index.html` (the page with the config and
  a bundle block) and, as scripts that hand their value to `RB_BUNDLE()`, the layers' tiles
  (`tiles/<folder>/<z>/<x>/<y>.js`, base64) and data (`data/<id>.js`). A page opened as a file may load a script where
  it may not fetch (decision 153). Layers on one MBTiles file share one folder, by `rb_map_tiles_mbtiles()`'s new
  `source`. Grid and vector layers are left out with a message: a server makes their tiles. Its overwrite removes
  only a bundle's own files, never the rest of the folder.
- **The page's bundle mode.** Tiles reach MapLibre through a `bundle://` protocol. maplibre-contour runs on the
  page's thread, its tile fetch swapped for the bundle's (`manager.getTile`, in 0.1.1). `/meta` comes from the
  bundle block. The three fits from the view are made in the browser from the layer's tiles in view (`bundleFit()`),
  by the rules in `fit`: those of `depth_fit()` and `relief_fit()`, on the tiles' pixels rather than the grid's cells.
- **fishycode's `products/bathymetry_map/bundle.R`**, writing `$FISHYDATA/exports/bathymetry_map_bundle/` and its zip,
  with `bundle_README.md` as its README.

## Chosen

- **Tiles to zoom 9:** 1,683 tiles, 243 MB, 174 MB zipped, where zoom 10 would make about 730 MB. At 65° N a zoom-9
  pixel is about 65 m, against the grid's 50 m; zoom 10 alone is 372 MB of the file's 547. Past zoom 9 the map draws
  zoom 9's tiles larger.
- **No depth by cell:** its tiles are made by a server from the depth grid (1.9 GB at its finest level).
- **The fits made in the browser**, not stored: they follow any view, as on the server.

## Found

- **CARTO's GL styles serve a page opened as a file.** In headless Chrome and Firefox their style, vector tiles and
  fonts answer 200 with no Referer, and so do Esri's ocean and satellite tiles. Decision 153 found CARTO's *raster*
  light tiles refused; the GL styles are not. All six base maps work in the bundle.
- **The address works on a file page** (`history.replaceState`) in both browsers: written by a control, read from a
  link, with the view in the hash.
- **The fits agree with the server's** on the same box (a 1200 x 900 window):

  | View (zoom) | Floor and cap, bundle (server) | Intensity, bundle (server) |
  |---|---|---|
  | Faxaflói (9) | 3.9-120 (3.8-120), the quantiles within 0.1 m | 1.00 (1.00) |
  | Ísafjarðardjúp (9) | 2.7-140 (2.7-140) | 0.48 (0.47) |
  | All of Iceland (6) | 4.2-1,500 (2.5-1,500) | 0.69 (0.78) |

  At zoom 6 a pixel is about 1.2 km, and averages away the shallow edge the server's cells keep.
- **A defect in ramb's page, found in Firefox and fixed for both modes.** A contour layer's levels changed by
  `setTiles` while its tiles were still loading kept the old levels' lines: MapLibre finishes a loading tile with the
  old address and does not ask again. On the bundle in Firefox, Faxaflói at zoom 9 drew one level of 13. The levels
  are now set once the layer's tiles are in, the latest asked winning. The view's step holds from one zoom out of the
  view's, so the far zooms' tiles kept for zooming out are not remade at a 2 m step: up to 4.9 MB and 1 s each, on
  the page's thread in a bundle.

## Tested

Opened as a file in headless Chrome and Firefox 159 on macOS, each item of the checklist's F1-F6
(`products/bathymetry_map/checklist.md`):

- it opens at -19/65, zoom 6, with no console error, its layers in order;
- the fits;
- the contours at the view's levels;
- the six base maps;
- the address written and read;
- Herðatré at zoom 8, and a click's popup.

The server's map on the new page, in both browsers, and the effort map (its cells, names and ports) are unchanged.
ramb's full tests pass under `devtools::test()` from the working tree: 2,595 expectations, none failing. They include
two new tests for `rb_map_bundle()`: its files, the tiles written once, the overwrite, its arguments, and the layers
a server draws left out.

## Not settled

- **Safari and Windows are untested**, as for decision 153 (TODO 96).
- **The bundle needs the internet** for MapLibre and maplibre-contour (jsdelivr) and the base maps. It works offline
  only with the libraries bundled too, and the base map "none".
- **The effort map in a bundle** (the maintainer's question, 2026-11-04). Its grid is summed by a server for any years
  and gears. A bundle would carry rows by cell, year, gear and preset, and sum them in the browser. Measured
  2026-11-04, at about 9 bytes a row compressed, within the depth grid's area: 80 MB to 0.02° cells, about 295 MB to
  0.01°, both presets, interpolated. Not built.
