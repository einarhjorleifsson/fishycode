# The bathymetry map: every control and click path

Plan 063. Each step of the plan is tested against this list, one item at a time, before the next step begins, with
the effort map's MapLibre items (`products/effort_map/checklist.md`: L1, L4, F1, C1, S2, M1, M2, M5, B1, P1, P2), since
the two share ramb's page. An item a step changes on purpose is changed here in the same commit, with the step.

How to test: as the effort map's list says (a hover before a click; the browser pane visible for anything drawn on an
animation frame). A hidden pane draws no frame, so MapLibre's `load` waits and the page sits at "loading tiles…" until
it is shown (2026-11-03: over a minute hidden, 3 s once shown): time a tile from the shell, not the pane.

## Load

- **L1** `/` opens at lon -19, lat 65, zoom 6; the status line reads `zoom 6.0` once the map is idle; no error in the
  console.
- **L2** The layers, bottom up: the depth's colour, the relief's shading, the depth by cell (off), the contours, the
  base map's labels, the place names.
- **L3** A relief tile is a WebP image, answered in a few ms (`curl` on `/tiles/relief/{z}/{x}/{y}.webp`).

## Depth (plan 063 step 2)

- **D1** Colours: any of the viewer's palettes recolours the depth at once; the legend's bar follows.
- **D2** The depth's checkbox: off hides the colour and leaves the shading; on brings it back.
- **D3** Floor and cap: the colours span between them as the sliders move, their depths beside them and at the bar's
  ends; a floor set above the cap is read the other way round.
- **D4** Scale: log or linear respaces the colours between floor and cap; "equal shares" places them at the view's
  quantiles, each colour an equal share of the depths in view (Faxaflói at zoom 9: its 25-52 m half of the bay spread
  over the palette's middle); following the view the quantiles follow it, not following they stay as last fitted; a
  link with `depth_scale=equal` and a floor and cap fetches the view's quantiles and keeps the floor and cap.
- **D5** Colours as bands: one flat colour per band at the charts' isobaths (10, 20, 50, 100, 200, 500, 1,000,
  2,000 m), the legend a swatch per band with its depths; a ramp again brings the bar back.
- **D6** Shallower than 10, 20 or 50 m: those depths drawn clear, or grey with "drawn grey"; none shows every depth.
- **D7** Opacity: the depth's colour alone fades, the shading stays; its value in % beside it.
- **D8** Each depth control in the address (`depth_pal`, `depth_lo`, `depth_hi`, `depth_scale`, `depth_mode`,
  `depth_cut`, `depth_cutas`, `depth_cop`, `depth_auto`), only when away from its default; a link opens with them; a
  value outside a control's range or options is left out.
- **D9** "Fit to view": the floor and cap at the 2nd and 98th percentiles of the depths in view (all of Iceland at
  zoom 6 about 10-1,700 m; Faxaflói at zoom 9 about 3-83 m); over land, "no depths in view to fit to".
- **D10** "Follow the view", on when the map opens: the floor and cap fitted when the map is drawn and each time it
  settles after a move, silently where the view has no depth; setting the floor or cap by hand unticks it and keeps
  them through moves; ticking it again fits at once. While it follows, the address leaves out `depth_lo` and
  `depth_hi`; a link that names them opens with it unticked (`depth_auto=0`).

## Contours (plan 063 step 3)

- **K1** On when the map opens: lines from zoom 5, made in the browser by `maplibre-contour`, spaced by depth and zoom
  (plan 063 point 7; `CONTOUR_SPACING` in `bathymetry_map.R`): under 50 m every 25 m at zoom 5-6, 10 m at 7-9, 5 m from
  10; deeper, coarser. Faxaflói (20-100 m) has lines at zoom 8 (every 10 m to 50, then 20 m); every chart isobath at
  least as deep as the zoom's shallowest spacing is drawn (the 50 m line at zoom 8); no line along the coast.
- **K2** The charts' isobaths (10, 20, 50, 100, 200, 500, 1,000 m and every 500 m deeper) heavier; from zoom 11
  labelled along the line with its depth ("50 m"), 13 px with no halo;
  the legend under the layer. Below zoom 11 MapLibre places no label along these lines, filtered or not, at any
  `text-max-angle`, overlap allowed or not (2026-11-03; cause not found; point placement puts one label at a line's
  start; the plugin's `overzoom` gave 0-2): the lines themselves show at every zoom.
- **K3** The contours' checkbox: off hides the lines and their labels; on brings them back; `contours=0` in the address.
- **K4** "Levels from the view", on when the map opens: about a dozen lines at round depths near the view's quantiles,
  made at a step of 1, 2 or 5 times a power of ten that makes some 40 of its range, refitted each time the map
  settles (Faxaflói at zoom 9: 4, 18, 26, 30 ... 72, 84 m on a 2 m step; all of Iceland at zoom 6: 60 ... 1,660 m on
  20 m); unticked, K1's spacing by depth and zoom, and `contours_auto=0` in the address; ticked again, the view's
  levels.

## Relief (plan 063 step 1)

- **R1** Method: each of MapLibre's five applies at once; "several lights" lights from three directions, 45° apart.
- **R2** Light from: the shading turns as the slider moves; its value in degrees beside it.
- **R3** Light height: the same, 0-90°.
- **R4** Intensity: 0 flattens the shading, 1 is the strongest.
- **R5** Opacity: 0 removes the shading, 100 is full; its value in % beside it.
- **R6** Shadow and light colours: each applies as it is picked.
- **R7** The relief's checkbox: off hides the shading and leaves the colour; on brings it back, as it was set.
- **R8** Each relief control in the address (`relief_method`, `relief_dir`, `relief_alt`, `relief_ex`, `relief_op`,
  `relief_shadow`, `relief_light`), only when away from its default; a link opens with them; a value outside a
  control's range or options is left out.
- **R9** "Intensity from the view", on when the map opens (plan 063 point 8(c)): the intensity 2 over the 90th
  percentile of the seabed's slope in view, between 0.3 and 1, each time the map settles (Faxaflói at zoom 9 1.00,
  Ísafjarðardjúp at zoom 9 0.50), kept as it was over land; setting it by hand unticks it and keeps the value through
  moves (`relief_ex=0.8&relief_auto=0` in the address); ticking it again refits at once, and the address leaves out
  `relief_ex`.

## Depth by cell

- **C1** Off by default; ticked, its cells over the relief with the grid's colour controls; a click, a popup with the
  cell's depth.

## Place names

- **N1** The names 14-19 px by level, with no halo; a click, the name's popup. A place written several ways is one
  label, its proposed name, with "the name" and "also written" in the popup ("9,049 names", 2026-11-03). A name
  crowded at its point is moved beside it, to the first free place of nine, and a click on the label where it is
  drawn opens it (2026-11-04): Herðatré off Kópanes shows at zoom 8 (before, only from 11); the Westfjords at zoom 8
  31 labels before, 39 now; kept through each base map.
- **N2** The names' checkbox off and on; `names=0` in the address.
- **N3** "the names' areas" unticked when the page opens, no footprint drawn and none answering a click (a click on
  the sea inside one opens nothing); ticked, the footprints and `names_areas=1` in the address, kept through a reload,
  each base map and the names off and on. The effort map opens with them ticked (its M6). Since ramb 2026.11.04.1.
- **N4** "colour": dark blue (the default), black, white, red, yellow, each drawn at once; `names_colour=%23ffffff` in
  the address for any but the default, kept through a reload, each base map and the names off and on.
- **N5** "names appear": a zoom later (−1), at their zoom (0, the default), one or two zooms earlier (+1, +2): at zoom
  8 over Faxaflói the farthest-out name drawn is the gazetteer's zoom 7, 8, 9, 10 (12, 27, 71, 79 labels at a
  411 × 830 pane, names moved beside their point; 14, 30, 70, 77 at a wider pane before they were), the
  footprints a zoom before their names; `names_early=2` in the address, and at zoom 7, 9 and 10 the farthest-out name
  is the zoom plus 2. A value the list does not hold (`names_early=5`, `names_colour=red`, `names_areas=yes`) is
  dropped from the address and the default taken. All three in Icelandic with the rest.

## Base map and language

- **B1** Each of the six base maps: the depth, relief and contours under its labels, the names over them; the depth's
  and the relief's settings kept through a change.
- **S6** IS | EN switches the relief's controls with the rest.

## From R

- **R** `bathymetry_map()` opens the map; `bathymetry_map_stop()` stops it.

## The bundle, opened as a file (`bundle.R`, ramb's `rb_map_bundle()`, since 2026-11-04)

How to test: open `exports/bathymetry_map_bundle/index.html` as a file (`file://`) in Chrome and in Firefox; headless,
driven over the DevTools protocol and WebDriver BiDi by the scripts in
`$FISHYDATA/archive/2026-11-04-map-bundles/`. The browser pane shows a file outside the project only as a static
snapshot.

- **F1** `bundle.R` writes the folder: 1,683 tiles to zoom 9, about 243 MB, zipped about 174 MB, with README.md and
  VERSION; "Left out of the bundle ...: cells".
- **F2** It opens at lon -19, lat 65, zoom 6 with `zoom 6.0` in the status line and no console error; the layers as
  L2 without the depth by cell; the six base maps (CARTO's three and Esri's two serve a file page) with the depth,
  contours and names over each (B1).
- **F3** The three fits from the view (D9-D10, K4, R9) are made in the browser from the tiles in view, near the
  server's on the same box: Faxaflói at zoom 9 floor and cap 3.9-120 (the server's 3.8-120), the quantiles within
  0.1 m, intensity 1.00 (1.00); Ísafjarðardjúp at 9 2.7-140 (2.7-140), 0.48 (0.47); all of Iceland at 6 4.2-1,500
  (2.5-1,500), 0.69 (0.78), a zoom-6 pixel averaging the shallow edge (2026-11-04, a 1200 x 900 window).
- **F4** The contours at the view's levels in Chrome and Firefox (Faxaflói at zoom 9: 13 levels, 4-122 m, within
  2.5 s), and past zoom 9 from zoom 9's tiles.
- **F5** The address on a file page: a control's change written (`names_colour=%23ffffff`), and a link read
  (`names_colour`, `names_early`, `lang=is`, `depth_lo`, `depth_hi`, `depth_auto=0`, `base=ocean` and the view).
- **F6** The names: N1-N5 as on the server; Herðatré at zoom 8; a click opens a name's popup.
