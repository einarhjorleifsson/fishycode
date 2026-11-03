# 063 — the bathymetry map's relief in the reader's hands: colours, depth range and bands, opacity, contours and shading

**status:** partly built — steps 1-3 built 2026-11-03 (ramb 2026.11.03.1's `shade`, 2026.11.03.2's `colour`,
2026.11.03.3's contour layer; the bathymetry map's depth and relief as two layers, each with its live controls, and
contours finer with the zoom; its `checklist.md` passed after each, with the effort map's MapLibre items, M1 after
step 2 only). Step 3's contours show at every zoom, their depth labels only from zoom 11 (checklist K2: below it
MapLibre places no label along `maplibre-contour`'s lines, cause not found). Point 7(b), contours by depth as well
as by zoom, and point 8's first part, the depth's colours following the view, in equal shares if chosen, built the same day. Step 2's two asks were left to the page: the cut
offered at 10, 20 and 50 m, none by default, drawn clear or grey; the bands at the charts' isobaths (10, 20, 50, 100,
200, 500, 1,000, 2,000 m); written 2026-11-03 at the
maintainer's request, the day the relief was built (TODO 185, ramb 8aa21b4, fishycode 71bc39d). **see:** TODO 185, plan 046 (the viewer), `products/bathymetry_map/`, ramb `R/map.R` and
`inst/map/index.html`

Drafted with AI assistance (Claude) on 2026-11-03. What is **measured** was run or read that day, as said in each
place; what is **assumed** is marked so. Steps 1-3 are built; the rest is not.

## What the maintainer asked (2026-11-03)

- play with the relief's colour palettes, to find what works best across different areas: a choice of palette, a
  choice of the depth the colours span, and an opacity control;
- depths shallower than 10-20 m are badly covered in the depth model: possibly cut them, or put the depth in
  categories;
- contours, finer as the zoom deepens; each depth plane then a different alpha of one colour;
- there are different ways to shade: look at rayshader, for code ideas, not to use the package (the maintainer, the
  same day);
- depth and the relief's exposition are two different things; the relief (shading, angles, intensity, alpha, ...)
  should be updated live in the page, as the depth by cell already is (the maintainer, the same day);
- what is best should not be judged by contours, nor by two areas, alone: moving from one area to another, what is
  used should update itself, as a choice of the reader's, following the view or not (the maintainer, the same day).

## Measured

- **The tiles hold elevations, not colours** (`dem.R`, Terrarium to 0.1 m). Every colour choice below is made in the
  browser from the same tiles; none needs a rebuild. Only a shading computed outside the browser would add tiles.
- **MapLibre 5.24.0** (the page's since ramb 2026.11.03; its style specification read 2026-11-03):
  - `color-relief`: `color-relief-color` is an expression over `["elevation"]` (so any ramp, range, cut or bands:
    `interpolate` for a ramp, `step` for bands, `rgba(…, 0)` for a clear depth), `color-relief-opacity`, `resampling`;
  - `hillshade`: `hillshade-method` one of `standard`, `basic`, `combined`, `igor`, `multidirectional`; illumination
    direction and altitude as arrays (several lights), shadow and highlight colours as arrays (one per light), an
    accent colour, exaggeration, `resampling`; the illumination anchored to the map or the viewport.
- **Contours in the browser:** `maplibre-contour` 0.1.1 (npm, released 2026-09-17, BSD-3-Clause) makes contour lines
  as vector tiles in a worker from a raster-dem source, with intervals set per zoom.
- **Depth shares** of the 286.6 million cells of `grid.R`'s base grid (0.001 by 0.0005 degrees, 2026-11-03): under
  10 m 0.4 %, under 20 m 0.7 %, under 50 m 2.2 %, under 200 m 14.8 %, under 500 m 29.5 %. A cut at 20 m clears under
  1 % of the sea.
- **rayshader** 0.41.2 exports `ambient_shade`, `cloud_shade`, `constant_shade`, `height_shade`, `lamb_shade`,
  `ray_shade`, `sphere_shade` and `texture_shade`. It is a source of methods, read from CRAN's source tarball and
  recoded where worth it (ramb's rule, decision 234), never a dependency. (Installed here 2026-11-03, it does not load:
  CRAN's macOS `rgl` needs XQuartz's OpenGL, which this Mac lacks; reading its code needs neither.)

- **rayshader's code** (0.41.2, read from CRAN's source tarball by a Claude agent, 2026-11-03; GPL-3, so its ideas are
  recoded from their papers, never from its code; file references are to the package's source):
  - `lamb_shade` (`R/lamb_shade.R`) and `height_shade` (`R/height_shade.R`) are MapLibre's hillshade and colour
    relief: nothing to add.
  - `sphere_shade` (`R/sphere_shade.R`, `R/create_texture.R`): a colour looked up in a lit sphere's texture by each
    cell's normal, slope and aspect; 3 by 3 cells, so it could run per tile in the browser, but its colours compete with
    the depth's.
  - `ray_shade` (`src/rayshade.cpp`): shadows cast toward the sun, stepping cell by cell; a buffer on the sun's side of
    about relief / (cell size x tan altitude) cells (20 cells for 1,000 m of relief at 45 degrees on 50 m). It depends
    on the light, as the hillshade does.
  - `ambient_shade` (`R/ambient_shade.R`): ambient occlusion from 24 azimuths of `ray_shade`, a buffer of its search
    radius (30 cells, 1.5 km at 50 m); about 3,600 samples a cell, hours over the grid. Shows troughs, scours and
    pockmarks with no light direction.
  - `texture_shade` (`R/texture_shade.R`): Leland Brown's texture shading, the spectrum times |k|^detail by an FFT of
    the whole raster; reach global. Its code fills a missing value with the mean (a false step at the coast), holds
    the raster in interpreted R and cannot run at our size; recoded from Brown's paper it would be done in overlapping
    blocks, land at 0 m, one normalisation for every tile. Shows the hierarchy of canyons and ridges on low relief,
    with no light.
  - Its layers are combined by multiplying a shade (`R/add_shadow.R`, black with alpha), as a raster layer of
    MapLibre's can.
- **Step 1, seen in the browser** (2026-11-03): with a low light (20 degrees) at full intensity, regular east-west
  stripes show in the deeper water north-west of the Westfjords (66.8 N, 25.5 W): likely in the source grid, its
  survey lines or their interpolation; not checked.

- **Faxaflói, seen in the browser after step 3** (2026-11-03, at the maintainer's word that Ísafjarðardjúp's steep,
  deep relief flatters every setting): a broad bay of 20-100 m.
  - The default colours (log, 10 to 2,000 m) put the bay in a thin slice of the ramp, one pale green; a cap of 200 m
    brings out its banks and troughs, but would flatten the deep: the range wants to follow the view.
  - Contours by zoom alone miss it: at zoom 8 (100 m) the bay has none, at zoom 10 (20 m) only the 20, 40 and 60 m
    lines.
  - The shading shows little of its low relief, even at full intensity with several lights, while the source's
    east-west stripes show plainly.

## Assumed

- That the shallow depths are poorly covered (the maintainer's knowledge: Olex soundings sparse near shore, GEBCO
  interpolated there). Not measured: the grid carries no flag of which source a cell came from.
- That `maplibre-contour` works with MapLibre 5.24 and with Terrarium WebP tiles from ramb's server: measured at step
  3, it does (512 px tiles too); its line labels show only from zoom 11.
- What rayshader's shadings do, from its documentation, not run: `sphere_shade` (colour from slope and aspect through a
  texture), `lamb_shade` (Lambertian), `ray_shade` (shadows cast by the terrain), `ambient_shade` (ambient occlusion),
  `texture_shade` (Leland Brown's texture shading), `height_shade` (colour by height). The first two MapLibre's
  methods already approach; cast shadows, ambient occlusion and texture shading depend on a cell's surroundings beyond
  one tile's border, so they would be computed outside the browser and served as a second image layer of shade.

## Proposal

**Two layers from the same elevation tiles, each with its own controls, updated live** (no tile is fetched again:
every control sets a paint property or rebuilds a colour expression in the page, as the depth by cell's colour
controls do now):

- **Depth**: the colour a depth gets (`color-relief`).
- **Relief**: how the seabed's shape is exposed, its shading (`hillshade`, and later shade computed outside the
  browser).

The controls are generic, for any dem layer (WGSFD-wide bathymetry or terrain), so they go into ramb's page; fishycode's
map sets the defaults. Every control is in the page's address. The two layers share their tiles: the second asks for
the same addresses, which the browser has cached.

1. **Relief.** The method (MapLibre's five); the light's direction (0-359) and altitude (0-90), several lights for
   `multidirectional`; intensity (exaggeration); the shadow's and highlight's colours; its own opacity.
2. **Depth.** A palette (all of ramb's); a depth range, floor and cap, on a log or a linear scale, as the depth by
   cell's; the ramp continuous or in **bands** (a set of depth classes, each one flat colour); a **shallow cut** (none,
   10, 20 or 50 m: shallower is clear, or grey as "poorly covered"); its own opacity.
3. **Contours** from `maplibre-contour`, pinned in the page as MapLibre is: intervals finer with the zoom (for
   example 500 m to zoom 6, 200 m at 7, 100 m at 8, 50 m at 9, 20 m at 10, 10 m from 11), index lines heavier and
   labelled, on or off.
4. **Depth planes in one colour**: a palette option that draws the bands in one hue, each plane a different alpha.
5. **Relief computed outside the browser**, from rayshader's reading: texture shading (Brown's method, from his paper)
   and ambient occlusion (true horizon angles by azimuth), neither needing a light; tried on two areas at 50 m and
   compared by eye with MapLibre's five methods on the same views; shade tiles (black with alpha, multiplied) for the
   whole sea only if one is clearly better, its cost in time and disk measured on the two areas first. Such a shade
   would be a layer of the Relief group, with its own opacity. Cast shadows and the sphere's colours last, if at all.
6. **What works across areas**: a few named views as address links (a steep fjord, Ísafjarðardjúp; a broad shallow
   bay, Faxaflói; the shelf edge; a ridge; the deep), on which the maintainer compares settings; the chosen defaults
   written into `bathymetry_map.R`.
7. **From Faxaflói** (proposed 2026-11-03): (a) "Fit to view" for the depth's colours, as the depth by cell has: the
   floor and cap from the depths in view, which the server reads from `grid.R`'s cells for the view's box; (b)
   contour intervals by depth as well as by zoom: the lines made at a fine interval and kept by the style's filter
   (every 10 m above 50 m, every 25 m to 200 m, coarser below, by zoom), since `maplibre-contour` takes intervals by
   zoom only; (c) step 5's texture shading first, as the shading meant for low relief.
8. **The map adapts to the view**, the reader choosing to follow it or not (the maintainer, 2026-11-03). Built: the
   depth's colours (ramb 2026.11.03.4's `colour$fit` and `auto`): "follow the view", on by default, fits the floor and
   cap to the 2nd and 98th percentiles of the depths in view each time the map settles (`depth_fit()`, 15-49 ms on the
   50 m grid); a floor or cap set by hand stops it, and a link that names them opens with it off. To follow: (a) the
   depth's colours in equal shares of the view, as the depth by cell's "equal" stretch, from the view's quantiles (in
   Faxaflói, fitted to 3.4-83 m, most of the bay's area lies in the ramp's dark end); (b) contour levels from the
   view's depths, nice values near its quantiles, so the lines fall where the area is; (c) the shading's strength
   from the view's relief; each a choice of following or not, as the colours'. (a) built the same day (ramb
   2026.11.03.5): the fit gives 25 quantiles of the depths in view, and the scale "equal shares" places the palette at
   them.

## Steps

One at a time, each tested before the next (the effort map's way, plan 046): the bathymetry map gets its own
`checklist.md` of click paths at step 1, and every step runs it, with the effort map's MapLibre items, since the page
is shared.

1. The relief layer apart from the depth, with its live controls (1 above), in the address; tests in ramb; the
   checklist written.
2. The depth layer's live controls (2).
3. Contours (3).
4. Depth planes in one colour (4).
5. Relief computed outside the browser (5): the trial on two areas, Ísafjarðardjúp and Faxaflói, in
   `$FISHYDATA/archive/`, read-only on the grid.
6. Named views and defaults (6).
7. Faxaflói's three (7): contours by depth (built 2026-11-03: the lines made at each zoom's common spacing, one layer
   per zoom range keeping those at their depth's, the charts' isobaths always; Faxaflói has lines at zoom 8), then
   "Fit to view" for the depth's colours (built the same day, and following the view, 8) (5 takes (c)).
8. The map following the view (8): the colours and their equal shares built 2026-11-03; then contour levels and the
   shading's strength.

## Asks (the maintainer)

- a. The shallow cut: 10 or 20 m by default, and is a cut depth clear, or grey as "poorly covered"?
- b. The bands: a standard set of depth classes (the charts', ICES's, or MFRI's own), or set in the page?
- c. Contour intervals by zoom: the example in 3, or others?
- d. Which areas to compare on (step 6), and for the rayshader study (step 5)?
- e. Whether shading tiles computed outside the browser may cost another few hundred MB (to be measured at step 5).
