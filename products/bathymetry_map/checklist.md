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
- **L2** The layers, bottom up: the depth's colour, the relief's shading, the depth by cell (off), the base map's
  labels, the place names.
- **L3** A relief tile is a WebP image, answered in a few ms (`curl` on `/tiles/relief/{z}/{x}/{y}.webp`).

## Depth (its colours by palette until plan 063 step 2)

- **D1** Colours: deep, blues, etopo1 bathy, each with its legend; `depth_by=` in the address.
- **D2** The depth's checkbox: off hides the colour and leaves the shading; on brings it back.

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

## Depth by cell

- **C1** Off by default; ticked, its cells over the relief with the grid's colour controls; a click, a popup with the
  cell's depth.

## Place names

- **N1** The names 14-19 px by level, with no halo; a click, the name's popup. A place written several ways is one
  label, its proposed name, with "the name" and "also written" in the popup ("9,049 names", 2026-11-03).
- **N2** The names' checkbox off and on; `names=0` in the address.

## Base map and language

- **B1** Each of the six base maps: the depth and relief under its labels, the names over them; the relief's settings
  kept through a change.
- **S6** IS | EN switches the relief's controls with the rest.

## From R

- **R** `bathymetry_map()` opens the map; `bathymetry_map_stop()` stops it.
