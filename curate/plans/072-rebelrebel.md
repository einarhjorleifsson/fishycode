# 072 — rebelrebel: a mapping package on MapLibre for the marine environment, built with the pipe

**status:** partly built — written 2026-11-10 at the maintainer's request ("Let's make a plan for the ribellibre
package"), the name changed to rebelrebel and asks a-j answered the same day, then the names made singular again, ask k (the
discrete palette, Okabe-Ito) and ask l (past eight values) answered, and §3.9 (nested choosers, `choose`) added at
the maintainer's word; step 1 (the move) built the same evening at the maintainer's word ("proceed to the next step")
in `~/R/Pakkar/rebelrebel` (github.com/einarhjorleifsson/rebelrebel; both renamed from ribellibre 2026-11-10), committed as a0ae669 at the
maintainer's word ("lets commit first"), not pushed; ask m answered (`rr_text()`) · **see:** plans 046 (the viewer), 063 (the bathymetry map's depth and relief), 064 (the time panel), decisions
220, 228, 277-281 (the effort map, its tiles, bundles and time panel), TODO 185 (the depth grid), TODO 198

Drafted with AI assistance (Claude) on 2026-11-10; a person has not yet checked it. What §0 and §1 call measured, Claude
measured; the rest is proposal.

The maintainer, 2026-11-10:
- "The aim is a general mapping package based on maplibre"; "the focus is on the marine environment, fishing data is
  just one of them"; "it should be user intuitive".
- "function names and calls should be thought about very carefully. check the geom_xxx names (point, line, path,
  tile, grid, ..), they are very familiar to a lot of people. But check also tinyplot package and tmap."
- "Arguments in the functions should be consistent."
- "How colour palettes are determined and passed to functions should be intuitive. For distinct variables I like
  Brewer palette Set 1. For continuous variables viridis palettes should be base default. We have then already
  established the defaults for the background depth maps."
- "Assume that people work with parquet/duckdb as default"; "The layers are built using the R native pipe."
- "We have already laid out the technical ground work with functions in the ramb package. Those are to be moved to
  ribellibre."
- Later the same turn: "we want the maps to be fast and responsive", and "the leaflet package allows user to operate on
  a low level, the mapview package is kind of build on top of that being easier for the user to work with. We want both
  for ribellibre."

**The name.** ribellibre (Italian *ribelle*, rebel, and *libre*) was chosen on 2026-11-09. The maintainer, 2026-11-10:
"I am seriously contemplating that the package name should be rebelrebel, then the function calls become rr_. typing r
twice is quick and "r" on the keyboard is in a "nice spot"", and, shown the checks below, "Yes, switch". rebelrebel is
free on CRAN and its archive, R-universe, PyPI and npm; on GitHub nine repositories carry the name, none an R package
or a map, and einarhjorleifsson/rebelrebel is free (checked 2026-11-10). It names no maps, so the package's title says
it: maps on MapLibre for marine data. A web search for "rebel rebel" finds Bowie's song first.

## 0. Built (2026-11-10)

**Step 1, the move,** in `~/R/Pakkar/rebelrebel`, commit a0ae669 (not pushed), by its `dev/move_from_ramb.R` and the edits after it: ramb's map
viewer as of ramb 2026.11.09.4 (09182bc), under §4's names, its behaviour unchanged.
- **The code,** split by subject (`R/map.R`, `palettes.R`, `notes.R`, `bundle.R`, `tiles.R`, `quick.R`, `time.R`,
  `serve.R`); ramb's DuckDB helpers copied into `R/duckdb.R`, and its example reader into `R/example.R`
  (`rr_example()`). `rb_map_group()` is `rr_section()` until step 2 gives each layer `section`; `rb_map_pings()` and
  `rb_map_track()` are internal (`.rr_pings()`, `.rr_track()`) until `rr_point()` and `rr_path()` replace them; ramb's
  old `gap_h` is left behind.
- **The page,** `inst/engine/index.html` (engine 7), with MapLibre GL JS 5.24.0, maplibre-contour 0.1.1 and uPlot
  1.6.30 vendored in `inst/engine/vendor` (1.2 MB; BSD 3-Clause and MIT, each licence beside its file and in
  `inst/COPYRIGHTS`), served at `/vendor/` and copied into a bundle's `vendor` folder: a map draws with no network but
  the base map's.
- **Five of ramb's datasets** (`dansk`, `dansk_harbours`, `dansk_relief`, `trawlsurvey`, `trawlsurveytows`; 8.6 MB),
  their dictionary entries and their sources, as Git LFS objects from the first commit (the maintainer, 2026-11-10: "is
  that not "safer", we may "change" them later": a change to a file not in LFS stays in every clone's history), so the
  install is `remotes::install_git(git = "external")`, as ramb's, and the workflow's checkout fetches them. The survey's
  two are MFRI's, with terms not stated, as in ramb.
- **Tests:** ramb's map tests moved, 632 expectations passing (ramb's own 634, less the two for `gap_h`), and 16 new
  for the vendored libraries: 648, none failing.
- **R CMD check `--as-cran`:** no error, no warning, two notes carried from ramb: a new submission of 8.8 MB (CRAN's
  limit is 5 MB, so R-universe first, as §5 says) whose dataset pages give DOIs as links, and an example line over 100
  characters.
- **A GitHub Actions workflow** (R CMD check on macOS, Windows and Ubuntu), which runs once the repository is pushed.

**Measured:**
- **fishycode's bathymetry map runs on rebelrebel** with only the names changed (a scratch copy of
  `products/bathymetry_map/` and `products/effort_map/`, served on 127.0.0.1:8831): depth, relief, contours, names and
  ports drawn, MapLibre and maplibre-contour from `/vendor/`, no error in the console.
- **A figure from the page, the must:** the example seabed's bundle (250 tiles, 8.9 MB, written in 4.2 s), opened from
  its file by headless Chrome (chromote 0.5.1) at 300/96 device pixels to each CSS pixel, gave a PNG of 2,009 × 1,419
  pixels, 17.0 × 12.0 cm at 300 dpi, its text and lines sharp, in 1.9 s (`dev/measure_figure.R`). Left for step 4: the
  page's controls are in the shot, which the print layout hides. That bundle drew no contour lines: the gap known
  since 2026-11-09, a bundle's contour tile lost where a neighbouring tile lies outside the grid, unchanged by the move.
- **Speed, ramb against rebelrebel:** fishycode's effort map served by each (ports 8833 and 8832), four fresh views each
  at 1280 × 800 in headless Chrome, twice (`dev/measure_speed.R`), was the same within a run's noise. A view of 4 grid
  tiles was idle after 1.7-2.0 s, of 9 tiles after 2.3-2.4 s, of 6 tiles at zoom 8 after 4.0-4.1 s; the grid's last
  tile came 1.3-1.4, 1.9-2.0 and 3.5-3.6 s after the jump, while the base map's tiles (from the internet) were done in
  0.1-0.3 s and the place names' (served by R, small) in 0.04-0.12 s. The grid's tiles take 0.2-0.6 s each and arrive
  one after another, R serving one at a time: §2's budgets (a full screen under 2 s, a tile under 100 ms) are not met.
  Step 3's work.
- **Names:** R-universe's index of CRAN finds none of §3's names exported by another package but `rr_label()`, which
  ggpmisc exports (ask m: the text layer is `rr_text()`).

## 1. What is at hand (measured 2026-11-10)

### 1.1 ramb's viewer (2026.11.09.4)

- **17 exported functions**, `rb_map*()`, in `R/map.R` (5,171 lines), and the page, `inst/map/index.html` (2,226
  lines, engine 7), on MapLibre 5.24.0 and maplibre-contour 0.1.1, both loaded from jsdelivr (`index.html` lines 9-10):
  no map draws without a network.
- **Five layer kinds** in `rb_map_layer()`: grid (cells summed by DuckDB per tile, with filters, palette, stretch,
  limits and histogram in the page), vector (tiles cut by DuckDB's `ST_AsMVT()`), geojson, dem (elevation images:
  depth in colour, shading) and contour (lines made in the browser). Served on 127.0.0.1 by httpuv with fixed routes,
  or written as a folder that opens from its `index.html` (`rb_map_bundle()`). Notes, verdicts, a time panel, two
  languages, the whole view in the page's address. 18 palettes, seven of them the depth looks settled in fishycode's
  bathymetry map (quiet, seabed, deep, chart, grey, drained, haxby).
- **The door is an expert's.** `rb_map_layer()` takes 28 arguments and MapLibre's styles as nested lists. The maps
  article's points layer, coloured two ways with a legend and a popup, is 50 lines. A grid needs its tile function
  written by the user, in SQL. Only `rb_map_pings()` and `rb_map_track()` are one call, and only for pings.
- **The suite:** 3,364 tests pass, 3 skipped (2026-11-09).

### 1.2 Speed, as measured before

- A tile of the effort map's grid, zoom 6-9: median 253 ms, at most 461 ms (fixes grid; decision 228). A port tile:
  under 10 ms (plan 046).
- httpuv runs R's handlers on R's one thread, so a screen of about 16 tiles at 253 ms fills in some 4 s
  (deduced, not measured: step 1 measures it).
- A restyle (palette, limits, stretch, a variant) fetches nothing: it is MapLibre's paint and global state.
- Plan 064 §1.4: a window move on a vessel's 103,680 pings drawn in 48-65 ms.

### 1.3 Who calls the viewer

12 files in fishycode (the bathymetry, depth-and-effort, effort and voyage maps, the place-name explorer's API, and
`docs/one_flow.qmd`), 2 in EM4SSF's `me_code`, and studies under `$FISHYDATA/archive/` (not counted). Most used:
`rb_map_serve()` 17 calls, `rb_map_basemaps()` 10, `rb_map_layer()` and `rb_map_group()` 8 each.

### 1.4 Names elsewhere (read from the installed packages: ggplot2 4.0.3, tinyplot 0.8.0, tmap 4.4.1, mapgl 0.5.0, leaflet 2.2.3)

| Draws | ggplot2 | tinyplot | tmap | mapgl | leaflet |
|---|---|---|---|---|---|
| points | `geom_point` | `type_points` | `tm_dots`, `tm_symbols`, `tm_bubbles` | `add_circle_layer` | `addCircleMarkers` |
| rows joined in order | `geom_path` | `type_lines` | — | — | — |
| rows joined in order of x | `geom_line` | — | — | — | — |
| line geometries | `geom_sf` | — | `tm_lines` | `add_line_layer` | `addPolylines` |
| a line per row, start to end | `geom_segment` | `type_segments` | — | — | — |
| areas | `geom_polygon`, `geom_sf` | `type_polygon` | `tm_polygons` (`tm_fill` + `tm_borders`) | `add_fill_layer` | `addPolygons` |
| cells | `geom_tile`, `geom_raster`, `geom_bin_2d` | `type_tile`, `type_hexbin` | `tm_raster` | — | `addRasterImage` |
| contours | `geom_contour`, `geom_contour_filled` | — | `tm_iso` | — | — |
| text | `geom_text`, `geom_label` | `type_text` | `tm_text`, `tm_labels` | `add_symbol_layer` | `addLabelOnlyMarkers` |
| base map | — | — | `tm_basemap`, `tm_tiles` | `maplibre(style = )` | `addTiles`, `addProviderTiles` |

Arguments: ggplot2 maps `colour`, `fill`, `size`, `linewidth`, `alpha`, `label`, and splits a path with `group`;
tinyplot has `by`, `palette`, `col`, `fill`, `alpha`; tmap v4 has `fill`, `col`, `size`, `lwd`, each with `.scale`
and `.legend`, and `group` for the layer control; mapgl has MapLibre's property names (`circle_color`,
`circle_radius`), `popup`, `tooltip`, `min_zoom`, `max_zoom`, and helpers `interpolate()`, `match_expr()`,
`step_quantile()`; leaflet has `group` for the layer control. mapview's one call is `mapview(x, zcol = )`.

### 1.5 Palettes in base R

`palette.colors(9, "Set 1")` gives ColorBrewer's Set 1 exactly (`#E41A1C` ... `#999999`, its ninth a grey), and
`palette.pals()` has Set 2, Set 3, Dark 2, Paired, Okabe-Ito and Tableau 10. `hcl.colors(n, "viridis")` is not
viridis: its ends are `#4B0055` and `#FDE333` against viridisLite's `#440154` and `#FDE725`. So viridis comes from
viridisLite's stops (written in, as ramb does now, or viridisLite in Imports).

## 2. What rebelrebel is (proposal)

**A map package for marine data on MapLibre**: depth, relief and contours; survey stations and tows; vessel tracks;
gridded effort or model output (temperature, chlorophyll); areas (protected areas, EEZs, ICES areas); place names. The
data stay in DuckDB, the browser draws and restyles, and a map is served from R, opened from a folder with no R, or
saved as a figure.

**Three doors to one map**, each built on the one below, as mapview is built on leaflet:

1. **One call** (mapview's level): `rr_view(x)` looks at the data and draws it. Points, lines, areas, cells or an
   elevation grid are told apart by the data, with the defaults of §3.5; `rr_view(pings, speed)` colours by speed.
   It returns a map, so the pipe goes on: `rr_view(pings, speed) |> rr_relief(relief)`.
2. **Layer by layer** (leaflet's level): `rr_map() |> rr_relief(relief) |> rr_point(pings, colour = speed)`. Each
   layer function draws one kind of mark with the vocabulary of §3.4.
3. **MapLibre's own terms** (the expert's): `rr_layer()`, ramb's `rb_map_layer()`, MapLibre's styles as lists. Every
   function above writes through it, so nothing the engine can do is out of reach.

**Fast and responsive** is a requirement with budgets, measured on the heaviest case at each step (§5):

| What | Budget |
|---|---|
| First map drawn, served, on the heaviest case | under 1 s to the first tiles, under 2 s to a full screen |
| A tile, p95 | under 100 ms (the effort grid is 253 ms median now) |
| A control in the page (palette, limits, stretch, a variant, a layer on or off) | the next frame, no fetch |
| A pan or zoom on a filled screen | no frame over 50 ms |
| A bundle | opens from its file in under 2 s |

The ways to meet them, each measured before chosen: a tile cache per map (memory, then disk); sums kept by zoom so a
coarse tile reads few rows (the effort map's base grid does this); static layers cut once into a parquet store of
tiles (`z`, `x`, `y`, `bytes`) that the server or a bundle reads; more than one R worker, each with its own DuckDB
connection to the same parquet; points left to a zoom where a tile is light, with the same rows as cells further out.

**Not:** Shiny; a translator to ggplot2; a tmap mode (tmap hands finished features to a renderer, which would drop
DuckDB's tiles and the page's controls; rebelrebel borrows tmap's scales and print layout instead); a GIS. A map sends
only the columns its call names (aesthetics, popup, hover, choose), so nothing else leaves DuckDB: a guard for
confidential data, which must not leave MFRI without an agreed basis.

**How it differs**, one line each:
- **leaflet:** an htmlwidget with the data whole in the page, slow past about 100 thousand features; raster tiles.
- **mapview:** leaflet's one call; the same limits.
- **mapgl** (Kyle Walker): MapLibre and Mapbox in R, layer by layer, MapLibre's property names, data whole in the page
  or from a tile URL; no DuckDB tiles, no controls in the page beyond MapLibre's own.
- **tmap:** one grammar, static or interactive with one switch (`tmap_mode()`); styling done in R.
- **marmap:** depth data from NOAA and analysis (transects, least-cost paths), static plots. Borrow the cursor's depth,
  a transect's profile, area by depth.
- **ggOceanMaps** (IMR): static polar maps in ggplot2. Borrow a globe view for high latitudes.

## 3. The names and the calls (proposal; the names answered in §6)

### 3.1 One prefix: `rr_`

Every exported function starts `rr_`, as tmap's start `tm_` and ramb's `rb_`, so a tab after `rr_` lists the
package, and the prefix is the name's. Not `rl_`, the prefix first drafted for ribellibre: rOpenSci's rredlist, the
IUCN Red List's client, exports 86 `rl_` functions (`rl_species()`, `rl_faos()` for FAO's fishing areas, ...), none
the same as a name here but mixed with them in a tab's list where marine and biodiversity users load both. Of the 15
CRAN packages whose names start with rr checked on 2026-11-10, none exports an `rr_` function; CRAN's package `rr`
(randomized response) exports `rrreg()` and the like. Not `geom_`: ggplot2 exports the same names, and the package loaded last would mask the other's. Not `add_`:
mapgl's verb, and leaflet's in camel case. Not `layer_`: ggvis, the pipe's ggplot2, used it, but ggplot2 exports
`layer_data()`, `layer_scales()` and `layer_grob()`. Whether any other package on CRAN exports `rr_` names is unchecked
(step 0).

### 3.2 Layer functions are nouns, singular, ggplot2's where ggplot2 has one

ramb's rule is verbs for functions. A layer function is a mark, named as the grammar of graphics names marks: the
pipe reads "and a point layer". What is done to a whole map is a verb: `rr_serve()` and `rr_stop()`, `rr_save()`,
`rr_bundle()`. Singular, as ggplot2 (`geom_point`), not plural as tmap, tinyplot and ggvis (`tm_dots`, `type_points`,
`layer_points`): the maintainer, 2026-11-10, "I think we should go singular" (ask b).

| Function | Draws | Its analogue | ramb today |
|---|---|---|---|
| `rr_point()` | a circle per row: a ping, a station, a catch as a bubble | `geom_point` | vector + circle style; `rb_map_pings()` |
| `rr_path()` | rows joined in order of `time`, one line per `group`: tracks, drifters, tagged fish | `geom_path` | `rb_map_track()` |
| `rr_line()` | rows that are lines: tows, transects, cables, a coastline | `geom_sf` (lines) | vector + line style |
| `rr_segment()` | a line per row from `lon`, `lat` to `lon_end`, `lat_end`: a tow from shooting to hauling | `geom_segment` | — |
| `rr_polygon()` | areas, `fill` inside and `colour` outline | `geom_polygon` | vector or geojson + fill style |
| `rr_grid()` | cells: rows that are cells, or rows summed into cells at a size that follows the zoom | `geom_tile`, `geom_bin_2d` | grid kind, tile function by hand |
| `rr_relief()` | an elevation grid's depth (or height) in colour, and its shading | — | dem kind |
| `rr_contour()` | lines of equal depth from the same grid, labelled | `geom_contour` | contour kind |
| `rr_text()` | text at points: place names, station ids, with a halo | `geom_text`, `geom_label` | symbol style by hand |

Why these words:
- **`path` and `line` as ggplot2 means them.** `geom_path` joins rows in their order and `geom_line` in order of x; on
  a map, order of longitude means nothing. So `rr_path()` joins rows in time and `rr_line()` draws what already is a
  line. A lazy DuckDB table has no row order, so `rr_path()` needs `time` (any column that orders: a time, a distance
  along a transect, a sequence number).
- **`grid`, not `tile`.** In web maps a tile is the z/x/y square a map is cut into (vector tiles, tmap's `tm_tiles()`);
  a layer called "tile" would be read as that. Fisheries and ocean data say grid: c-squares, ICES rectangles, H3, a
  model's grid.
- **`relief`, not `depth` or `dem`.** Cartography's word for drawing the ground's shape, in colour (hypsometric and
  bathymetric tints) and in shade, which are MapLibre's `color-relief` and `hillshade`. It serves seabed and land:
  `of = "depth"` by default, `"elevation"` on land.
- **`rr_text()`**, as ggplot2's `geom_text` and tmap's `tm_text`, with a halo on by default, since map text needs one
  (what `geom_label`'s box does on a plot); its text is the `label` argument: `rr_text(places, label = name)`. Not
  `rr_label()`, which ggpmisc exports (ask m).
- **Later, not in this plan:** a heat map (`geom_density_2d`'s place; MapLibre's heatmap layer), arrows for currents
  and wind (`geom_spoke`), 3D terrain, a globe for high latitudes.

### 3.3 The map, the pipe and the other functions

```r
rr_map(pings) |>                              # pings: a parquet file, a lazy table, a data frame or sf
  rr_relief(rr_example("relief")) |>
  rr_contour(rr_example("relief")) |>
  rr_path(group = vessel_id, time = time) |>
  rr_point(colour = c(behaviour, speed), popup = c(vessel_id, time, speed), minzoom = 10)
```

- `rr_map(data = NULL, ...)` starts a map. Its data is each layer's unless the layer has its own, as `ggplot(data)`.
- **A layer's first argument is the map.** Given a table instead, it starts a map with it, so `pings |> rr_point()`
  works (`rb_map_pings()` does this now).
- **Printing a map shows it**: in an R session it is served and opened in the viewer, as leaflet's; in Quarto or
  R Markdown it is written into the page, its tiles cut to a `maxzoom`, with a guard on size.
- `rr_serve()` and `rr_stop()`; `rr_bundle(map, dir)`; `rr_save(map, file)` (§3.7).
- `rr_layer()`: the expert's door (§2).
- `rr_time()`: the time panel under the map, for any rows with a time and an id: vessels, drifters, tagged fish.
- `rr_tiles_table()`, `rr_tiles_dem()`, `rr_tiles_mbtiles()`: the tile makers, for `rr_layer()`.
- `rr_palettes()`, `rr_basemaps()`: what there is.
- `rr_notes()`, `rr_notes_add()`, `rr_verdicts()`: what readers wrote on a served map.
- `rr_example()`: the example data (§4).

### 3.4 One vocabulary, one order

Every layer function takes its arguments in this order, and a test holds them to it:

1. `map`, then `data`;
2. **where:** `lon`, `lat` (found by name when not given: lon/lat, longitude/latitude, x/y, or a geometry column, said
   once in a message), and the mark's own: `group` and `time` (`rr_path()`, `rr_polygon()`), `lon_end` and `lat_end`
   (`rr_segment()`), `elevation` and `of` (`rr_relief()`, `rr_contour()`), `cell` and `fun` (`rr_grid()`);
3. **how it looks:** `colour`, `fill`, `size`, `linewidth`, `opacity`, `label`;
4. **its colours:** `palette`, `limits`, `breaks`, `stretch`, `legend`;
5. **what the reader can do:** `popup`, `hover`, `choose`;
6. **the sidebar:** `name`, `info`, `section`, `visible`;
7. **its zooms:** `minzoom`, `maxzoom`;
8. `...`, passed to `rr_layer()`: MapLibre's paint and layout for the expert.

The words:
- **`colour`** (`color` accepted) is a point's, a line's, a text's colour and an area's outline; **`fill`** an area's
  or a cell's inside. ggplot2's meanings.
- **`size`** a point's diameter in pixels; **`linewidth`** a line's width in pixels (ggplot2's name since 3.4.0);
  **`opacity`** 0-1, the layer's (MapLibre's and leaflet's word; ggplot2's `alpha` is a mapped aesthetic, which this
  is not).
- **`label`** is the text `rr_text()` writes, as ggplot2's. So a layer's name in the sidebar is **`name`** (ramb's
  `label` now), its id taken from it unless `id` is given.
- **A bare name is a column, a string is a value:** `colour = speed` colours by speed, `colour = "#c0392b"` paints
  every point. dplyr's rule, which tidyverse users know; ggplot2 needs `aes()` for it and tmap guesses. A string that
  is a column's name and not a colour stops with a message to write it bare.
- **Several columns are a choice in the page:** `colour = c(behaviour, speed)` offers both under "Colour by", the first
  shown (ramb's `variants`); `fill = c(hours, kwh)` on a grid is its metric control.
- **`popup = c(vessel_id, time, speed)`** (tidyselect; the first as its title, `TRUE` for every column, as a table:
  §3.11);
  **`hover = vessel_id`** a label beside the pointer.
- **`choose = c(gear, year)`**: which rows the reader shows, a list or a range per column (§3.9). Filtering before
  the map is dplyr's, in the pipe before it.
- **`group` splits rows into lines and areas**, as ggplot2's (`geom_path(aes(group = id))`), and takes one column or
  several: `rr_path(pings, group = c(vid, tid), time = time)` draws a line per trip of each vessel (the maintainer,
  2026-11-10: "ggplot has an argument in the aes - "group". like in geom_path"; "group should be able to take more than
  one variable, aka group = c(vid, tid))"). Not tinyplot's `by`, which colours groups too.
- **`section`** is the sidebar's box a layer sits in ("Seabed", "Data"), which leaflet and tmap call a group. Sections
  appear in the order first named; `rr_map(sections = )` gives their titles and which
  open.
- **`minzoom` and `maxzoom`** are MapLibre's words, as now. The map's own opening view is `center` and `zoom`, by
  default the data's extent.

### 3.5 Colours

- **One `palette` per layer**, for the column in `colour` or `fill`. Its kind comes from the column: character,
  factor or logical is discrete; a number, date or time is continuous; an elevation grid takes the depth looks.
- **Defaults:**
  - discrete, by the number of values and whether they have an order (asks k and l):
    - unordered, up to eight: **Okabe-Ito**, black last: `#E69F00`, `#56B4E9`, `#009E73`, `#F0E442`, `#0072B2`,
      `#D55E00`, `#CC79A7`, `#000000`. Its yellow is faint on a light base map (contrast 1.27:1 on Carto Positron's
      land), so a point's thin outline is part of its default look (measured in step 2);
    - unordered, nine to twelve: **Paired**;
    - unordered, more than twelve: **Glasbey's** 32 colours, there to tell neighbours apart (tracks of many vessels),
      the value itself shown on hover;
    - ordered (an ordered factor, or a DuckDB ENUM), at any number: **viridis**, in the values' order.
  - A message says once which palette was taken and why.
  - continuous: **viridis**, and the page offers the viridis family (viridis, magma, plasma, inferno, cividis).
  - depth: the settled looks: the seven depth palettes, quiet first; limits fitted to the view at its 2nd and 98th
    percentiles, in equal shares; shading at 0.6 with a blue-grey shadow; contour levels following the view.
- **The defaults are only defaults.** Any call overrides them with `palette`, whatever the column (`palette = "viridis"`
  on unordered values takes them in sorted order). A palette with fewer colours than values colours the most frequent
  and puts the rest in grey, "other".
- **What `palette` takes:** a name (`"Set 1"`, `"Paired"`, `"viridis"`, `"magma"`, a depth look, any of base R's
  `palette.pals()` and `hcl.pals()`; matched without regard to case, spaces, `-` or `_`, so `"set1"` is Set 1); a
  vector of colours; colours named by value for a discrete column (`c(Fishing = "#c0392b", Steaming = "#8a959e")`); or
  a function of n (`viridisLite::mako`).
- **For numbers:** `limits = c(10, 2000)` (ggplot2's word; the page's two-handled slider), `fit = TRUE` (limits follow
  the view), `stretch` (`"linear"`, `"log"` or `"equal"`, equal shares of the values in view: the page's word, since
  "scale" on a map is the map's scale), `breaks` (bands).
- **The legend is made from the palette and the column**, its title the layer's `name`; `legend = FALSE` hides it.
  ramb asks for swatches by hand now.

### 3.6 Data in

- `data` takes **a parquet file, folder or glob** (opened by DuckDB, nothing read into R), **a lazy DuckDB table**, a
  **data frame**, tibble or data.table (copied into DuckDB), or an **sf object** (geometry as WKB). One table given
  four ways gives the same tiles, byte for byte: a test.
- Small data may go to the page whole (GeoJSON) and large as tiles, the same map either way; the size it switches at
  is measured (step 2).
- Points: below the zoom where a points tile meets the budget, the same rows are drawn as cells, unless
  `minzoom` says otherwise (step 2 measures the zoom by row count and extent).

### 3.7 A map as a figure

`rr_save(map, "fig.png", width = 17, height = 12, units = "cm", dpi = 300, view = )` (ggsave's name and arguments).
The page is drawn by a headless Chrome (chromote, in Suggests) at the pixel ratio the dpi needs, in a print layout:
title, legend, scale bar, north arrow, attribution, optionally a graticule (tmap's layout elements: `tm_title`,
`tm_legend`, `tm_scalebar`, `tm_compass`, `tm_credits`, `tm_graticules`). `view` takes the page's address, so what the
reader set (layers, palette, limits, the view) is the figure. PNG, and PDF or TIFF around it: MapLibre draws with WebGL,
so there is no vector output. It is the maintainer's must, so step 1 tests it first.

### 3.8 One engine, room for Python

The page, the config's schema (JSON Schema) and the routes live in the repository's `engine/`, which the R package
ships. Tests validate every config against the schema. A Python host (DuckDB and parquet there too) could ship the same
engine. Nothing for Python is built in this plan.

### 3.9 Choosing what to show: `choose`

The maintainer, 2026-11-10: "if we have vessel id and then trip id, could we use group_by to indicate that the first
"select" panel holds vid and then within the vid we would then get the second select panel holding the tid of the
selected vid". Then: "this group_by may be a bit too much to ask, but a "by =" argument is the function call is
possibly more "proper"", and, offered `choose` or `by`, "choose is more intuative". Told that gear and year would be
`filters`: "i could foresee the user wanting to use gear as a "choose" or for that matter "year". also "gear" as a
colour, etc. - So clarify".

**A column can play several parts at once**, each named by its argument:

| Part | Argument | What the reader gets |
|---|---|---|
| how it looks | `colour`, `fill`, `size` | gear in colour, with its legend; several columns, a choice of colouring |
| which rows show | `choose` | a list for text, a factor or a logical; a range for a number, a date or a time |
| what it tells | `popup`, `hover` | its value on a click, or beside the pointer |

So `rr_point(hauls, colour = gear, choose = c(gear, year), popup = c(gear, catch))` draws a point per haul in gear's
colours, with a list of gears and a range of years, and both on a click. The legend's entries also turn their values
on and off, as in most interactive charts.

**One word for showing some rows: `choose`.** `filters` leaves the vocabulary; ramb's grid filters become a grid's
`choose`.

```r
rr_map(pings, choose = c(vid, tid)) |>
  rr_path(group = c(vid, tid), time = time) |>
  rr_point(colour = speed)
```

- **The lists are linked: each offers only the values the others leave** (as a shop's filters). So nesting needs no
  declaring: with `choose = c(vid, tid)`, once a vessel is chosen the trips' list holds only its trips; with
  `choose = c(gear, year)`, once a gear is chosen the years' range spans only the years it fished, and the other way
  round. The order in `choose` is the lists' order on the page. "all" heads each list, and ‹ and › step through it.
- **A number, a date or a time is a range** on a two-handled slider, as `limits`; a list of its values instead (years
  one at a time) is an option settled in step 2.
- **The map's, or a layer's.** On `rr_map()` a choice drives every layer that has the column, and the time panel (the
  chosen vessel, its span the chosen trip). On a layer (`rr_grid(effort, choose = c(gear, year))`) it drives that layer
  alone, its controls under its name in the sidebar. Layers without the column (depth, areas) stay as they are.
- **Where the rows are kept:** a grid's cells are summed again by the server for the choice; other layers keep the
  chosen rows in the page, or in the server where a tile holds too many (measured in step 2).
- **The view** fits the chosen rows' extent (by itself or on a click: settled in step 2). **The address holds the
  choice** (`?vid=1234&tid=5678`), so the view of one trip can be sent.
- **A value's text** is the value, or another column's, such as a vessel's name beside its vid (the argument's name
  settled in step 2).
- **How the lists reach the page:** DuckDB counts the combinations of the chosen columns once, each with its extent.
  Few go whole to the page; many are answered by the server for the other lists' choices. A bundle writes them whole,
  with a guard on size.
- **An argument, not the data's groups.** A grouping travels unseen with the data (one made for an earlier
  `summarise()` would make lists nobody asked for) and is lost through parquet; dplyr itself has moved to grouping in
  the call (`.by`). So rebelrebel reads no `group_by()`. Not `by` (tinyplot's colours groups) nor `group` (which splits
  lines, as ggplot2's): `choose` says that the reader picks, and is ramb's word now (`rb_map(choose = )`).
- **Now in ramb (measured):** `rb_map_pings()` and `rb_map_track()` make one list per group column (their `choose`
  defaults to the data's groups), each with every value of its column, not linked (`inst/map/index.html` lines
  884-899), with an extent for each combination; a grid's `filters` are separate controls, a list or a range each. The
  time panel nests already: a vessel, then its spans (`rb_map_time(span = )`). Linked lists are new (step 2).

### 3.10 Depth: the user's own model, else one online

The maintainer, 2026-11-10, on Olex's 50 m grid, which cannot ship in a public package: "you mentioned earlier in the
session that there were other depth models out there. should we check those first "as default" before we proceed?",
then: "remember this package is not only for Iceland. We have e.g. Italian example dataset. The way the package
should work is that the user can supply his own depth model. Default would be to get something online though. There
the speed of access is just as important as the resolution. The speed is also then partly dependent on the format that
the server provides relative to what maplibre "likes"".

- **The user's own model** works now: a grid in any table DuckDB reads (`rr_tiles_dem()`, as `dansk_relief`), or an
  MBTiles file of elevation images (`rr_tiles_mbtiles()`, as fishycode's Olex grid). `rr_relief(x)` takes either.
- **The default is online,** with no download and no key: `rr_relief()` with no data draws it.
- **What MapLibre likes:** elevation values as Terrarium or Terrain-RGB images in web-mercator tiles, fetched by the
  browser straight from a fast host, with no R in the path; or a PMTiles archive or a Cloud-Optimized GeoTIFF read in
  the browser by a protocol plugin. A source that gives only pictures (WMS, WMTS) cannot be coloured, shaded or
  contoured in the page; one that gives values only on request (WCS) needs R to cut and encode every tile, R's one
  thread again (§0: 0.2-0.6 s a tile).
- **Measured first (step 1a),** in several regions, not Iceland's alone: Iceland's shelf (Olex as the reference there),
  Danish waters (`dansk`), the Adriatic (ramb's Italian pots, `wkssfgeo2_it_pots`), and the Irish or Portuguese
  Atlantic shelf. For each candidate source: its format and how the page reads it; the time to fill a screen at zooms
  6, 9 and 11 in headless Chrome; its resolution and its depths against the best reference in each region (Olex in
  Iceland; elsewhere the finest open grid); its licence, its attribution and its terms of use. One table, and a look
  at each region's ground at zoom 9.
- **Measured the same evening** (Claude; study `$FISHYDATA/archive/2026-11-10-depth-sources/`, internal for its Olex
  tiles; Norway's and the inventory by a research agent). The maintainer's notes on the way: a model kept for the
  package must be weighed ("you have to think about data file size"; "NE Atlantic would suffice"); "the NOAA bathy -
  any chance they have a fast modern service?"; "the Norwegians may be also providing something modern".

  | Source | What MapLibre gets | A screen, or a tile | At sea |
  |---|---|---|---|
  | AWS Terrain Tiles | Terrarium PNG, 256 px, no key | 0.8-11.7 s a screen (S3, no CDN) | ETOPO1, about 1.8 km: a blur; 4.8 m off Olex at the median |
  | Mapterhorn | Terrarium WebP, 512 px, no key, Cloudflare | 0.17-0.71 s a screen | none (land only) |
  | EMODnet DTM | values by WCS only | 1.0-2.2 s a tile | 115 m, real detail; 0.7 m off Olex |
  | GEBCO 2026 | a COG in EPSG:4326 | 1.6-4.8 s a tile (gdalwarp) | 450 m, near EMODnet in Europe; whole metres, terraced in the shallow Adriatic |
  | NOAA (marmap's ImageServer) | float values on request | 1.2-5.2 s a tile, 0.3-1 MB | ETOPO 2022 with regional models |
  | Kartverket (Norway) | values by WCS only, UTM33 | about 0.6 s per 256 px | 50, 25, 5 m, patchy offshore; CC BY |

  **So no source is both fast and detailed at sea.** The fast one has no sea floor (Mapterhorn). The open one with a
  sea floor is a blur (AWS). The detailed ones give values only on request, at 1-5 s a tile. A default that is both
  has to be built once: EMODnet where it reaches (European seas, Iceland's included), GEBCO beyond, encoded as Olex's
  tiles are (Terrarium to 0.1 m, lossless WebP, 512 px), and hosted outside the package on a static host with a CDN,
  read by the page directly (an XYZ folder, or one PMTiles file through the 20 KB pmtiles reader).
- **Its weight:** an all-sea tile is about 100 KB (40-200 KB measured). For the NE Atlantic (25-82° N, 45° W-40° E),
  sea tiles only: about 0.4-0.5 GB to zoom 8, GEBCO's own resolution; 1.8 GB to zoom 9; 7 GB to zoom 10, EMODnet's.
  None of it goes in the package, which carries only the address; CRAN's whole package is 5 MB.
- **Chosen, then scrapped** (ask n, "AWS for now", then "scrap this trial"; ask o): the no-setup default was to be AWS's tiles, coarse at sea but working everywhere; a user's own model
  draws as now. Left to measure: a PMTiles file's speed from the chosen host (the only one tried, Mapterhorn's 355 GB
  planet, drew nothing in 10 minutes), and whether a coarser step than 0.1 m in deep water shrinks the tiles without
  the terraces dem.R saw on gentle slopes.

### 3.11 What a click shows: the row as a table

The maintainer, 2026-11-10, on the map of the survey's tows: "when we click on the tow-station we should get a
formatted "table" with all the variables in the dataset. aka what we have in mapview. so put this in as part of the
plan." (Not to be built yet.) mapview's click shows every column of the feature as a two-column table (leafpop's
`popupTable()`); ramb's popup now shows a title and the fields named one by one.

- **By default a click shows the row:** every column, a line each, name and value, the title the first column or the
  one `popup` names; `rr_view()` and every layer function alike. `popup = c(id, time, speed)` keeps those, in that
  order; `popup = FALSE` none.
- **Formatted:** numbers in the page's language (decimal mark, thousands, digits to the column's precision), dates and
  times as ISO with their zone (UTC), logicals as yes/no, missing values as a dash, long text wrapped, the geometry left
  out. A column's description and unit, where the data have a dictionary (as rebelrebel's examples do), become its
  label and a tooltip: `speed (knots)`. Values that are codes show their labels where a lookup is given (ramb's
  `values` of a popup field, kept).
- **Fetched on the click, not carried in the tiles:** the tile carries the feature's key alone; a click asks the
  server for that row (`/row/<layer>/<key>`), which DuckDB reads from the layer's table. So the tiles stay small and
  fast however many columns the table has, the row is whole however long its text, and §2's guard holds (only the
  key leaves DuckDB until a reader clicks, and the server answers only the layer's own columns). A bundle, which has
  no server, writes the rows beside its tiles, by tile, with a guard on size.
- **The same for a grid's cell** (its sums by the filters in force) and for a time panel's ping.
- **Built in step 2,** with the layer functions; checked by a click on a tow of `trawlsurveytows` and on a ping of
  `dansk`, served and bundled, and by the size of a bundle of `dansk` with and without its rows.

### 3.12 Media in a row: links, pictures, underwater video

The maintainer, 2026-11-10: "Be prepared / plan that we may have a link to a underwater video." A station, a tow or
a transect may have a picture or a video of the seabed: a camera on the gear, a drop camera, a towed sledge, an ROV.

- **A column that holds links is shown as one** in the row's table (§3.11): a web address, or a file under a folder the
  map names. Which columns are media is said once, `media = c(video, photo)`, or found by the values (an address
  ending .mp4, .webm, .jpg, .png, or a YouTube or Vimeo address), said in a message.
- **A picture shows in the table,** small, and large on a click.
- **A video opens in a panel beside the map,** not in the popup, which is too small to watch in: a player with its
  own controls (MP4 with H.264, or WebM, which every browser plays; a YouTube or Vimeo address in their own player,
  their terms and their cookies with it). The feature it belongs to stays marked on the map.
- **A video along a track is linked to it in time:** given the video's start time (a column, or `media_start`), playing
  it moves a mark along the track and the time panel's window follows (§3.3's `rr_time()`, which already links time
  and map), and a click on the track or the panel seeks the video to that moment. So a towed camera's film is read
  with its position, depth and speed beside it.
- **Served files:** the server answers a media file only if a row of the layer names it, from under the folder the map
  names (an allowlist, as for the rows), with byte ranges, so a long video seeks without being sent whole.
- **In a bundle,** web addresses stay links; local files are copied only when asked and under a size guard, else
  left as links to where they lie, with a note in the bundle. Footage may be internal: confidential or personal
  material must not leave MFRI without an agreed basis, so nothing is copied by default.
- **When:** links and pictures in the row's table with step 2 (§3.11); the video panel and its link to a track's time
  with step 4, after `rr_time()` has settled into the layer functions. Checked on a planted example: a short open
  clip with a start time, along a few of `dansk`'s pings.

## 4. What moves, what stays

| ramb now | rebelrebel | Notes |
|---|---|---|
| `rb_map()`, `rb_map_layer()` | `rr_map()`, `rr_layer()` | `label` becomes `name` |
| `rb_map_group()` | `section =` on each layer, `rr_map(sections = )` | |
| `rb_map(choose = )`, a grid's `filters` | `choose`, the map's or a layer's | §3.9 |
| `rb_map_serve()`, `rb_map_stop()`, `rb_map_bundle()` | `rr_serve()`, `rr_stop()`, `rr_bundle()` | |
| `rb_map_tiles_table()`, `_dem()`, `_mbtiles()` | `rr_tiles_table()`, `_dem()`, `_mbtiles()` | |
| `rb_map_palettes()`, `rb_map_basemaps()` | `rr_palettes()`, `rr_basemaps()` | palettes gain `type` |
| `rb_map_notes()`, `rb_map_notes_add()`, `rb_map_verdicts()` | `rr_notes()`, `rr_notes_add()`, `rr_verdicts()` | |
| `rb_map_time()` | `rr_time()` | ask h |
| `rb_map_pings()`, `rb_map_track()` | `rr_point()` and `rr_path()`; `rr_view()` for the quick look | their arguments carried, below |
| `inst/map/index.html` | `engine/` | MapLibre and maplibre-contour vendored, so a bundle draws offline (at sea) |
| `dansk_relief` | rebelrebel's examples, then vortur | ask i |
| the maps article | rebelrebel's articles | |

- **Every map function leaves ramb** (the maintainer, 2026-11-10: "my thinking is that these where also going to be
  part of rebelrebel", of `rb_map_pings()` and `rb_map_track()`). Pings are any track's (vessels, drifters, tagged
  animals), so rebelrebel has no functions of their own: what the two do becomes arguments of `rr_point()` and
  `rr_path()`, and `rr_view()` draws a table of pings as a track and its points.
  - `rb_map_track()`: a line per vessel (`by`) is `group`; broken at a silence longer than `max_gap_s` seconds, the
    same name; coloured by a column whose runs of one value cut the line (`col`) is `colour`, cutting the line where
    the value changes; the map's lists from the data's groups (`choose`) are `rr_map(choose = )`. Its `by` defaults to
    the map's, else `vid` where the data have it; `group`'s default is settled in step 2.
  - `rb_map_pings()`: colour by a column or a choice of columns (`col`) is `colour`; `discrete` is the column's type
    (§3.5), overridden by `palette`; the radius in metres with a largest size in pixels (`radius`, `radius_max`) is
    `size`, its unit settled in step 2; `popup`, `time`, `title` and `port` are rebelrebel's own.
- **ramb keeps every `rb_map_*()` one release as an alias** that warns once and calls rebelrebel (`by` passed on as
  `group`), then has no map functions; ramb takes rebelrebel in Suggests for that release. rebelrebel does not depend
  on ramb.
- **DuckDB's helpers** (`.rb_con_for()`, `.rb_scope()`, `.rb_hold()`, `.rb_name()`): rebelrebel gets its own copy, a
  hundred-odd lines; ramb's flow keeps its own.
- **rebelrebel's dependencies:** Imports DBI, duckdb, jsonlite, httpuv, rlang; Suggests sf, dbplyr, png, chromote,
  knitr, testthat, viridisLite (unless its stops are written in). Fewer than ramb's.
- **fishycode's maps and EM4SSF's viewer** move to rebelrebel after its first release, one at a time, each through its
  click paths (`products/effort_map/checklist.md` and the like), while the aliases still run them.

## 5. Steps

Each step is committed in rebelrebel on its own, checked against the speed budgets of §2 where it touches speed, and
reported before the next.

0. **The names.** §3 put to the maintainer (§6): every ask answered 2026-11-10, §3 amended. Left: the `rr_` prefix
   checked against CRAN's exports.
1. **The move, behaviour unchanged.** The engine and the `rb_map*()` functions under §4's names, MapLibre vendored,
   tests moved and passing, R CMD check on GitHub Actions. Two measurements first: `rr_save()`'s figure (a 300 dpi PNG
   of the bathymetry bundle by chromote, looked at by the maintainer), and the served map's speed (a full screen of the
   effort grid: time to fill, tiles in flight, R's one thread). Check: the suite passes; fishycode's bathymetry map
   runs on rebelrebel with only the names changed (scratch library).
1a. **The depth default, measured** (§3.10; the maintainer, 2026-11-10: "Yes, depth first"): the online sources, their
   formats, speed and resolution, in four regions; the default chosen from the table, and a decision record.
1b. **EMODnet's base layer the default** (ask o), its own commit after step 1's; built the same evening (rebelrebel
   2026.11.10.1, commit 216a39a, not pushed: 672 tests pass, the page checked in a browser), with a darkened EMODnet
   added at the maintainer's word ("oooh, i like the dark map", of Carto's Dark Matter, whose sea is flat): first in `rr_basemaps()`
   (`tiles.emodnet-bathymetry.eu/2020/baselayer/web_mercator/{z}/{x}/{y}.png`, attribution to the EMODnet Bathymetry
   Consortium, CC BY), Esri's Ocean kept. And the list holds only base maps that show the sea floor (the maintainer,
   2026-11-10: "The Base map should only include those that show something of substance at sea"): EMODnet's base layer,
   EMODnet's atlas v12 (the same, lighter) and Esri's Ocean (worldwide, where EMODnet ends); Carto's three (a flat sea)
   and Esri's satellite (dark water) leave it, and GMRT stays out for its speed (2.7-18 s a screen). "None" stays, the
   one choice that is not a map, for a figure on white. The page now opens on the first base map's `style` (a vector style), so it
   learns to open on a picture base map, and place names from a labels-only layer go over it. Check: the four regions
   of §3.10 open on it; a test that the first base map may be a picture.
2. **The layer functions** on `rr_layer()`, and `choose` with its linked lists (§3.9): `rr_point()`,
   `rr_path()`, `rr_line()`, `rr_segment()`, `rr_polygon()`,
   `rr_text()`, with §3.4's vocabulary, §3.5's colours and legends, the row as a table on a click (§3.11), hover
   and `choose`. Measured: a tile's time
   by rows and zoom on `dansk` (395,558 pings) and on one year of fishycode's trail (scratch), to set the points' zoom
   and the GeoJSON switch. Check: the maps article's points layer, 50 lines now, in about five; a test holds every
   layer function to §3.4's order.
3. **Cells and the seabed:** `rr_grid()` (rows that are cells, or rows summed at the zoom's size; `fun` sum, mean or
   count; `choose`), `rr_relief()` and `rr_contour()` with the settled defaults. The speed work of §2 that step 1's
   measurements call for. Check: fishycode's effort grid through `rr_grid()`, its cell sums equal to `grid.R`'s, its
   tiles inside the budget.
4. **The one call, media and the outputs:** `rr_view()`; the video panel and its link to a track's time (§3.12); printing in an R session and in Quarto; `rr_save()` with the print
   layout. Check: `rr_view()` on each example table draws the right mark; a Quarto article renders with maps in it;
   one figure at a journal's page width looked at by the maintainer.
5. **ramb's side:** every `rb_map_*()` an alias for one release, then removed; the maps article, and the maps in
   ramb's other articles, replaced by pointers to rebelrebel; NEWS; then fishycode's maps and EM4SSF's viewer, one at a time.
6. **The articles:** a first map in five lines from a parquet file; the three doors; colours; the seabed; cells;
   figures; and the names side by side with ggplot2, tmap, leaflet and mapview. R-universe first; CRAN once the
   examples fit its size limit.

A decision record closes the plan.

## 6. Asks (answered by the maintainer, 2026-11-10)

a. **The name and the prefix:** rebelrebel and `rr_` ("Yes, switch"), over ribellibre and `rl_`.
b. **Singular or plural:** singular, `rr_point()`, as ggplot2 (as recommended): answered plural first, then "I think
   we should go singular. rr_points -> rr_point, ..." the same day.
c. **The elevation grid's layer:** `rr_relief()` (as recommended), not `rr_depth()` or `rr_seabed()`.
d. **Path and line:** two functions, `rr_path()` for rows joined in time and `rr_line()` for line geometries (as
   recommended).
e. **The one call:** `rr_view()` (as recommended), not `rr_look()` or `rr_quick()`.
f. **A colour's two ends:** `limits`, in R and in the page (as recommended); the page's floor and cap are renamed when
   its controls are next changed (step 3), not in step 1's move.
g. **Set 1's yellow:** left out (recommended was to keep it): seven colours and grey (§3.5).
h. **The time panel:** moves to rebelrebel as `rr_time()` (as recommended).
i. **Example data before vortur:** in rebelrebel (as recommended): the relief clip, the survey's stations and tows, a
   few vessels' pings from ramb's open sets; moved to vortur later.
j. **The repository:** public from its first commit (as recommended).

Asked after b while the names were plural: the cells layer `rr_grid()` (as recommended, not `rr_cells()`), and the
text layer `rr_labels()` (as recommended, not `rr_text()`), now singular, `rr_label()`. Then `rr_text()` (ask m).

k. **The discrete default, again:** Okabe-Ito with its yellow, "Okabe-Ito with yellow it is" (recommended was without
   it), black last; it replaces ask g's Set 1. The maintainer, 2026-11-10: "as said I like brewer Set1, but is has limits.
   Paired is another option, accomodates more variables. Are you aware of better one of similar nature?" Measured that
   day (Claude; colorspace 2.1.4's simulations, farver 2.1.2's CIEDE2000): the smallest difference between any two of a
   palette's first seven colours, for normal vision and as the red-green colour-blind see them at full severity (some
   red-green deficiency: about 1 man in 12 of northern European descent):

   | First seven of | normal | deuteranope | protanope |
   |---|---|---|---|
   | Set 1, no yellow (ask g) | 15 | 4 | 3 |
   | **Okabe-Ito, no yellow** | 22 | 13 | 12 |
   | Paul Tol's muted | 23 | 14 | 12 |
   | Tableau 10 | 22 | 1 | 6 |
   | Paired | 21 | 5 | 5 |
   | Dark 2 | 17 | 3 | 2 |
   | Glasbey | 28 | 2 | 5 |

   For more values no palette keeps its colours apart: at twelve the smallest difference is 14 for Paired and 10-13 for
   Kelly's and Glasbey's, and Paired's pairs merge for the colour-blind (3 and 1). Paired's light half is also faint on a
   light map. Recommended: **Okabe-Ito without its yellow, black last** (`#E69F00`, `#56B4E9`, `#009E73`, `#0072B2`,
   `#D55E00`, `#CC79A7`, `#000000`) and its grey, `#999999`, for "other": as far apart as any for normal vision, three
   times Set 1's for the colour-blind, made for them (Okabe and Ito 2008), and base R's default (`palette.colors()`).
   Its weakest contrast on Carto Positron's land is 2.2:1 (Set 1's 2.3:1); black last, because it vanishes on the dark
   base map (1.1:1). Past seven values, the seven most frequent take the colours and the rest are grey, and the
   choosers (§3.9) show one value at a time; Paired and Glasbey's 32 by name (`palette = "glasbey"`) where many
   neighbours are only to be told apart, as many vessels' tracks, with no legend to read.
l. **Past eight values** (the maintainer, 2026-11-10: "if variables more than 8, should we not be clever and go for e.g.
   paired, and if more than that one of the viridis scales"; and "we are talking about the default here. but the user
   should be able to override with his own call"). Measured that day, the smallest difference between any two colours:
   Paired 17 at nine and ten values, 14 at eleven and twelve (3 for the red-green colour-blind); viridis 7 at 13, 4 at
   20, 3 at 30, where neighbours cannot be matched to the legend; Glasbey 13 at 20 and 10 at 30. Taken: Paired for nine
   to twelve, Glasbey past twelve, viridis for ordered values at any number (§3.5), each overridden by `palette`.
m. **`rr_label()` is ggpmisc's too:** answered 2026-11-10, "rr_label -> rr_text" (as recommended). ggpmisc, a common
   extension of ggplot2, exports `rr_label()` (an R² label), with `rr_ci_label()` and `adj_rr_label()`; loaded together,
   the package loaded last would mask the other's. The text layer is `rr_text()`, as ggplot2's `geom_text`.

n. **The depth default:** answered 2026-11-10, "AWS for now" (option 3; recommended was 1), then, after a preview of
   Iceland on AWS's values beside Esri's Ocean base map, "scrap this trial" (ask o). From §3.10's measurements: (1) build the NE Atlantic tileset (EMODnet, GEBCO beyond)
   to zoom 9, about 1.8 GB, and choose its host (recommended); (2) GEBCO alone to zoom 8, about 0.5 GB, smaller and
   coarser; (3) no build, AWS's coarse tiles as the default and users' own models for detail. Asked with it: where the
   file is hosted (a CDN-backed static host: Cloudflare R2, Source Cooperative, or MFRI's own), which only the
   maintainer can open.
o. **A picture base map for the sea:** answered 2026-11-10, "Yes, EMODnet default" (as recommended). The maintainer, 2026-11-10: Esri's Ocean base map "is both faster and
   provides "no worse" map than ETOPO1", then "scrap this trial. But then question becomes is the "Ocean (ESRI)" the
   best thing out there?". Measured (study `$FISHYDATA/archive/2026-11-10-depth-sources/`, `basemaps_z9.png`): Esri
   Ocean fills a screen in 0.6-0.85 s but is nearly flat at sea at zoom 9; EMODnet's base layer (2020) draws the sea
   floor in every region tried, in 0.8-2.6 s (once 13 s), CC BY, European seas; EMODnet's atlas v12 alike, lighter;
   GMRT slow (2.7-18 s); GEBCO's WMS failing that evening. A picture carries no values: no depth looks, no contours,
   no depth under the cursor; a user's own model, or AWS's values, go on top. Recommended: EMODnet's base layer in
   `rr_basemaps()` and the default for marine maps, Esri Ocean kept as the fast one, and the AWS default dropped.

## 7. Not in this plan

The Python host; an offline base map (a coastline from data, for use at sea); heat maps, arrows, 3D terrain and a
globe; vortur, the data package, which has its own plan to come.
