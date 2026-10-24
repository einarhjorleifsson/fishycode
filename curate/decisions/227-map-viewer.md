# 227 — The map viewer: the effort map in Vefsjá's shape on ramb's rb_map_*(), and a second view on the same kit

*2026-10-24. The maintainer asked for structure in the interactive pages made on the fly: vefsja.is as the template
for the user's side, the effort map first and with every present feature kept (the fast engine on parquet and DuckDB,
the palettes), GeoServer not used, place names and DuckDB 2.0 left out, and R functions as wrappers kept in ramb.
Plan 046, its seven steps done the same day, each on the maintainer's go and each asked step answered (plan 046 §6).
Built, measured and written by Claude (AI); the maintainer tried the page as it went. Not checked by a person beyond
that.*

## What was built

- **The checklist** (`products/effort_map/checklist.md`): every control and click path of the effort map, 29 at the
  start and 45 at the end, each run logged with what passed and what was found. Every later step ran it again.
- **The tile bench** (`products/effort_map/bench.R`): 279 fixed tiles at zoom 5-8 over the grounds, at the three cell
  sizes, with and without a filter, to `$FISHYDATA/products/effort_map/bench/`.
- **The page in Vefsjá's shape:**
  - a sidebar of groups that fold, each layer with its checkbox, count, ⓘ, and under it when ticked its controls and
    legend;
  - six base maps (Carto's vector styles, Esri's ocean and satellite, none), changed without losing the layers' state;
  - Icelandic and English by a switch, numbers in the language's format;
  - the whole view in the address, with a copy-link button;
  - on a phone, the sidebar as a drawer.
- **The ports** as a reference layer: all 18,009 of `curated/reference/port_geometry`, as vector tiles from DuckDB.
- **ramb 2026.10.24.1** (817fc1a, with the fix of 2026.10.24.2, 4d79a55; both pushed and installed), the kit:
  - the engine `inst/map/index.html`, with three layer kinds: `grid` (the effort layer made general), `vector` and
    `geojson`;
  - `rb_map_layer()`, `rb_map_group()`, `rb_map()`, `rb_map_serve()`, `rb_map_stop()`, `rb_map_tiles_table()`,
    `rb_map_palettes()` and `rb_map_basemaps()`;
  - a grid's parameters checked against its declared filters before any SQL;
  - tests on its own example data.
- **The effort map on the kit:** `products/effort_map/map.json` (layers, groups, texts) and `map.R` (each layer's
  tiles or data). `app.R`, `ports.R` and `www/` are retired.
- **The second view:** `products/voyage_map/voyage_map.R`, `voyage_map(vid, year, voyage)`, one voyage's track and
  fixes coloured by fishing, from ramb's functions alone. It needed no new feature of the kit, and found one fault in
  it (below).

## What was measured

- **Vefsjá** (vefsja.is, Alta), from its served scripts: one config of 116 layers in 12 groups and 6 base maps, each
  layer with its info, legend, popup template and on 6 layers a filter. Its data are images drawn by GeoServer, and its
  address keeps the position only. No licence text is in its scripts, so the ideas were taken and none of its code.
- **The tile times on the fixed set:** the worst tile is 0.60 s and 9.8 MB at one pixel, and 1.72 s and 37.8 MB at
  half a pixel. Decision 220's figures came from fewer tiles and understated these.
- **Through ramb's route,** the same 30 tiles: median 225 against 226 ms, worst 645 against 617 ms. The bytes of one
  tile vary between two fetches from the same server, by up to 0.25 %: DuckDB's parallel sums do not fix the order.
- **The rebuilt map** gave the old page's numbers on the same views: the fit, the sliders, the gear labels, and the
  place names' popup line for line.

## Faults found and fixed on the way

- The cap slider stopped at 10^5, below kW-hours' 98th percentile. The sliders now widen to the values at hand.
- Several gears showed as ids; they now show by name and FAO code.
- A refused tile was always blamed on an older server. It now shows the server's reason, or names an older server.
- A cap from the address came back rounded by the slider's step (300 as 302).
- A language switch while tiles loaded left the status line in the old language.
- A scrollbar appearing moved every button 15 px, so a second click missed.
- A page opened with the effort off never fitted its colours.
- A vector layer's tiles kept one address across server starts, so a voyage served after another was drawn from the
  browser's cache. Found by the second view; fixed in ramb 2026.10.24.2, with no caching of GeoJSON either.
- `unlocode` in the port reference is a flag (the pid is the port's UN/LOCODE), not a code; the popup says so.

## Choices

- **The engine stays MapLibre with vector tiles from DuckDB.** Vefsjá's OpenLayers and server-drawn images would put
  the colours on the server; GeoServer is not used (maintainer).
- **The kit's boundary** (maintainer, each as recommended):
  - the engine's texts are English in ramb, and fishycode's config adds the Icelandic;
  - ramb gets the server and one table helper, while the effort grid's tile SQL stays fishycode's function;
  - the place names' popup is plain fields prepared in the GeoJSON, with no names code in ramb.
- **ramb is installed from GitHub with `remotes::install_git()`.** `install_github()` takes GitHub's source archive,
  which holds the Git LFS pointers of ramb's example data, not the data.

## Not done

- **Comparison** of two selections (two periods, two gears), side by side or as a difference: later (maintainer).
- **More reference layers:** GEBCO depth, ICES areas and rectangles, EUSM habitats. Each is a config entry and, for a
  large one, `rb_map_tiles_table()`. The coastline, the EEZ and the 12 nm line are not on hand.
- **A static folder** (`rb_map_write()`), for a page that opens from a file: not built.
- **The vessel overview** on the kit (plan 030): not attempted.
- **Gear names in English:** none, since `reference/gear` has no English names.
- **DuckDB 2.0:** left for now (maintainer). CRAN has 2.0.0, and R here loads 1.5.6 (plan 046 §7).
- **Effort inside Reykjavík's port area** (fishing fixes in a harbour polygon): seen at zoom 12, not measured. It may
  belong with TODO 142's haul windows.
