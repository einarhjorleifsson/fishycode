# 046 — Map viewers: the effort map in a Vefsjá-like shell on the same tile engine, then R functions in ramb

**status:** proposal — written 2026-10-24 at the maintainer's request; the effort map, Vefsjá's served scripts and the
installed DuckDB measured the same day (read-only); nothing built · **2026-10-24** · **see:** decision 220, plan 030
§7, decision 153, TODO 140, TODO 142

Drafted with AI assistance (Claude) on 2026-10-24; a person has not yet checked it. What §1 calls measured, Claude
measured. The tools named in §1.4 are leads, not yet tried.

The maintainer, 2026-10-24:
- the interactive pages ("leaflets") have been made on the fly, and need more structure;
- the template to follow is [vefsja.is](https://www.vefsja.is): "the user selection part is simple and adaptive", and
  its scripts are open, to be mined for ideas;
- the first product is an improved effort map, keeping every present feature: the fast engine on parquet and DuckDB,
  the palettes, and the rest. The place names are left out of this round;
- GeoServer is not to be used;
- in time, R functions that build such a viewer, "just wrappers around the javascripts", kept at first in ramb;
- DuckDB 2.0 is left for now.

## 1. What is at hand (measured 2026-10-24)

### 1.1 The effort map (decision 220): what must survive

`products/effort_map/`: `grid.R` (the base grid, 524 M rows at 0.001°, a 0.005° copy), `tiles.R` (one vector tile:
DuckDB sums the grid to about one screen pixel per cell and writes `ST_AsMVT`), `app.R` (httpuv: `/`, `/meta`,
`/place_names.geojson`, `/tiles/{z}/{x}/{y}.pbf`), `server.R` (a terminal), `effort_map.R` (an R session: the app in
the background, the view in RStudio's Viewer), `www/index.html` (315 lines, MapLibre GL JS 4.7.1, Carto's basemap).
The page's controls, each a line of step 1's checklist (§3):
- preset (`fishing`, `fishing_flow`), gear (by `gid`, listed by hours), years from–to, metric (hours or kW-hours per
  km²), cells (0.5, 1 or 2 pixels);
- colour: twelve palettes (ten of steady OKLab lightness), a stretch (even on a log scale, or equal shares of the cells
  in view), floor and cap sliders, "Fit to view" (2nd and 98th percentiles), a colour bar over a histogram of the cells
  in view, refit on the first idle;
- a click on a cell gives its hours and kW-hours per km² and its fixes; a refused tile is said in the status line;
- the first view from the address (written by `effort_map()`); the position in the hash; the grid's write time in the
  tile address, so a rebuilt grid is not hidden by the cache;
- the place-name layer (plan 044), a checkbox.

Measured in decision 220, the worst tile at zoom 5-8: 0.2-0.5 s and 3.5-5 MB at one pixel, 1.3 s and up to 25 MB at
half a pixel, about 1 MB at two. Not done there: the filters are not in the address, so a link shows the place only.

### 1.2 The other pages made on the fly

Two live pages and one export carry a map library: the vessel overview (`products/vessel_overview/www/`, deck.gl,
uPlot and DuckDB-WASM, 136 kB of `app.js`; plan 030), the effort map, and `products/exports/buseful_2025-05-05.R`.
The vessel demo (decision 153) is the overview opened from a file. Each page has its own panel, its own state in the
address, its own way of serving data; none shares code with another.

### 1.3 Vefsjá (vefsja.is, Alta), from its served scripts

- **Engine:** OpenLayers 10.3.1, ol-mapbox-style 12.1.1 and geotiff from CDNs; w3.css; its own `vefsja.min.js`
  (37 kB). No licence text in its scripts. The ideas are taken here, not the code (§2).
- **Everything is one config file**, `valayers.js` (96 kB):
  - `setupParams`: the first view and zoom limits, logo, the first base map, where a feature's info goes (sidebar or
    popup), legends shown, an about text;
  - 116 layers (`VA_Layer`), each with a title, an `info` text (source, date, link), a legend, a popup `template` with
    `{field}` slots, z-order, opacity, zoom limits, a `tag`, and on 6 layers `selectOptions`: a dropdown that sets the
    layer's filter (`cql_filter`, e.g. the year of a historic map);
  - 12 groups (`VA_LayerGroup`: title, contents, expanded) under one `VA_LayerSet` with six base maps.
- **The user's side:**
  - a left sidebar of groups that fold, a checkbox per layer and per group;
  - an ⓘ per layer for its info;
  - a ticked layer shows its source line and legend under its name, in the tree;
  - one base-map choice with one opacity slider;
  - feature info in the sidebar;
  - measure a line or an area, locate me, scale and zoom;
  - a guide and an about box;
  - on a phone (375 px), the sidebar folds behind a menu button and the map fills the screen.
- **Its data are images.** Its layers are WMS from GeoServer, ArcGIS exports and XYZ tiles, drawn on the server, so a
  colour cannot change in the browser. The address keeps only the position (`lat`, `lng`, `z`) and a preset (`s`); a
  ticked layer is not in it.

### 1.4 Leads, not tried

- `mapgl` 0.5.0 (installed): MapLibre from R, as htmlwidgets. Its layer control is a flat list of toggles.
- MapLibre's Martin tile server has a DuckDB backend (Google Summer of Code 2026).
- `freestiler` (CRAN) writes vector tiles from R: a lead for pre-built tiles, if a page is ever to run with no server.

## 2. What is taken from Vefsjá, and what is not

**Taken (the ideas):**
- one declarative config: setup, base maps, groups of layers;
- per layer a title, an info text (source, date, the decision behind it), a legend shown under it when ticked, a popup
  template, opacity and zoom limits, and its own controls (Vefsjá's `selectOptions` grown into the effort map's
  filters);
- groups that fold, and one base-map choice with an opacity slider;
- the sidebar that folds behind a menu button on a phone;
- an about box; measure, locate and scale.

**Not taken:**
- OpenLayers and server-drawn images: the engine stays MapLibre with vector tiles from DuckDB, so colours, stretch and
  histogram stay in the browser (maintainer: keep the fast feature base);
- GeoServer (maintainer, 2026-10-24), and w3.css;
- Vefsjá's code itself.

**Done better than Vefsjá:** the whole state goes in the address (every control, the ticked layers, the position), so
a copied link gives the same view. This closes decision 220's "not done".

## 3. Design

### 3.1 Three parts

1. **The page engine:**
   - one JavaScript file and one stylesheet, with MapLibre pinned (4.7.1 now; a move to 5.x is a step of its own);
   - it reads a config (setup, base maps, groups, layers) and builds the sidebar from it;
   - layer kinds:
     - `tiles`: vector tiles from the service, whose declared controls write their values into the tile address;
     - `geojson`;
     - `raster`: XYZ;
   - a continuous layer gets the effort map's colour block (palettes, stretch, floor and cap, histogram), moved in
     unchanged. A layer of classes gets swatches.
2. **The service:**
   - R, httpuv and DuckDB, as now;
   - generic routes: `/config.json`, `/meta/{layer}`, `/tiles/{layer}/{z}/{x}/{y}.pbf?…` and `/geojson/{layer}`;
   - a `tiles` layer is a function of `z`, `x`, `y` and its declared parameters. Each parameter has a type and its
     allowed values, checked before any SQL: the vessel overview's allowlist (plan 030), per layer;
   - `effort_tile()` becomes the first such layer, its SQL unchanged.
3. **The R side:**
   - a layer and a group made from R, and the config written from them;
   - the service started in the background, the view opened in RStudio's Viewer or a browser, as `effort_map()` does
     now;
   - later, a static folder for layers that need no service (decision 153's pattern).

### 3.2 What lives where

- **ramb, at first (maintainer):** the engine, the service's skeleton, the R constructors and the palettes. These are
  generic, with nothing Icelandic, and ramb's tests run them on its example data, with no `$FISHYDATA`.
- **fishycode** (`products/effort_map/`): the grid, the tile SQL on it, the gear names, the layer list and the paths.
  If the viewer grows past what a flow library should carry, or gains users outside ramb's, it moves to a package of
  its own (ask d).

### 3.3 Names

Placeholders until the review of names (TODO 127): `rb_map_layer()`, `rb_map_group()`, `rb_map()` (open a view),
`rb_map_serve()`, `rb_map_write()` (a static folder). A viewer is not a flow step, so whether it takes the `rb_` prefix
at all is part of ask d.

## 4. Steps

One at a time. After each step, every click path is tested before the next (the overview's lesson, plan 030), with the
pane visible where an animation frame matters.

1. **The baseline:**
   - §1.1's controls written out as a checklist of click paths;
   - decision 220's tile timings remeasured on a fixed set of tiles (zoom 5-8, cells 0.5, 1 and 2).
   Every later step is checked against both.
2. **The shell, effort map only:**
   - the sidebar in Vefsjá's shape: Effort (filters, colour, legend), Base map (choice, opacity), About;
   - the effort map's code moved in;
   - `tiles.R` and the tile route untouched.
3. **The address:**
   - every control in the query string, and the position in the hash;
   - `effort_map()` writes the same address;
   - a reload or a copied link gives the same view.
4. **Reference layers** (ask b), one per step:
   - each with its info and legend, as GeoJSON or as tiles from DuckDB;
   - EUSM's 3.2 M polygons can only go as tiles.
5. **The config split out:**
   - the page reads its layers from `/config.json`;
   - the effort map's layer list leaves `index.html`;
   - the page is unchanged against step 1's list.
6. **Into ramb:**
   - the engine, the service's skeleton and the R constructors move to ramb;
   - fishycode's effort map is rebuilt on them, its own code down to the layer definitions and the tile SQL;
   - ramb's tests draw its example pings as a `tiles` layer without `$FISHYDATA`.
7. **A second consumer** (ask c): one more view on the kit with no edit to the engine. This is the test that the kit
   is generic.

## 5. Checks

The plan is done when:
- every click path of step 1's list works after the last step, and was tested after each one;
- the tile timings on the same tiles and machine are no worse than step 1's;
- a copied link reproduces the full state;
- the page is usable at 375 px wide, with the sidebar behind a menu button;
- `effort_map()`'s arguments are unchanged, or each change is recorded;
- ramb passes R CMD check with tests that need no data;
- a second view runs on the engine unedited.

## 6. Asks

- **a. Language of the page:** Icelandic as Vefsjá, English, or both by a switch? Recommended: both, with the labels
  in the config.
- **b. Which reference layers first?** On hand:
  - ports (`curated/reference/port_geometry.parquet`);
  - GEBCO depth (`staging/aux/gebco.fgb`);
  - ICES areas (`staging/aux/ices_areas_500m-buffer.fgb`);
  - EUSM habitats (`staging/aux/eusm.fgb`);
  - ICES rectangles (ramb).
  The regulation areas of `uv` (decision 201) are not yet a layer. The coastline, the EEZ and the 12 nm line are not
  on hand.
- **c. The second consumer** (step 7): one vessel-voyage's fixes from the trail; the effort by year as a layer to
  compare; or the vessel overview's map, the hardest.
- **d. Names, and the home:** the function names (with TODO 127), whether a viewer takes the `rb_` prefix, and when
  it would leave ramb for a package of its own.
- **e. Comparison:** two selections side by side, or their difference (two periods, two gears)? Vefsjá has neither.
  Version 1, or later?

## 7. Not in this plan

- **The place names** (plan 045): the gazetteer's checkbox is carried over as it is, as one layer, and nothing more is
  done to it here.
- **The vessel overview's move** onto the kit (plan 030): it is larger, with its time plots and DuckDB-WASM, and comes
  after step 7 if at all.
- **Publishing:** the effort map is built from vessel-level data and stays on 127.0.0.1. A public version is a
  decision of its own under MFRI's data policy and plan 001.
- **DuckDB 2.0** (left for now, maintainer 2026-10-24). Measured the same day:
  - CRAN holds duckdb 2.0.0 (released 2026-10-21, a long-term support release); R here loads 1.5.6;
  - duckdbfs 0.1.2 asks only `duckdb (>= 1.1)`, so reinstalling it does not upgrade DuckDB;
  - the spatial extension is published for v2.0.0 on this Mac, and h3 as a community extension;
  - no SQL in fishycode or ramb uses the single-arrow lambda that 2.0 turns off.
  When it is taken up: its own change, step 1's tile timings before and after, and the pipeline's fingerprints.
- **The haul windows that draw lines across land** (TODO 142) and the product's versioning (TODO 140): data, not the
  viewer.
