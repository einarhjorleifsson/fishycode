# 079 — ogis: live layers in a bundle, the page's own DuckDB answering ogis's tile SQL (a trial)

**status:** proposal — written 2026-11-19 at the maintainer's word ("Yes, write the plan"), from his: "in one sense the
end goal of ogis is to save a construct in a format that does not need R - would be think about using something like
the post for that" (DuckDB's blog, "Local analytics without a database server", 2026-11-12); asks a-d his ·
**2026-11-19** · **see:** plans 072, 076, 077 and 078, decisions 153, 277, 278 and 328, TODO 198, TODO 204, the
rebelrebel options of 2026-11-11 (`$FISHYDATA/archive/2026-11-11-rebelrebel-whole/notes/formats_research.md` and the
PMTiles study beside it)

Drafted with AI assistance (Claude) on 2026-11-19; a person has not yet checked it. What §2 calls measured was
measured by Claude before this plan, in the studies and decisions it names.

## 1. Why

ogis saves a map with no R in two ways today: `og_serve()` needs R running, and `og_bundle()` writes a folder that
opens from its `index.html` with its tiles made in advance, one PMTiles archive a layer (decision 277). A bundle opens
offline and is light, but it shows only what was made: a layer whose filters and summaries combine (effort by gear,
year and vessel; any span of time) needs every combination made in advance, or keeps only the few its maker chose (the
depth and effort bundle sums its filters in the page over tiles made in advance, decision 278).

The post runs DuckDB in the page (DuckDB-WASM), keeps the data as Parquet and makes vector tiles on demand with DuckDB's
spatial extension (`ST_AsMVT`). ogis's server already writes its tiles as DuckDB SQL (`og_tiles_table()`, `og_cells()`),
so the same SQL could run in the browser's DuckDB: the construct saved would be the layers, their SQL and their Parquet
files, and nothing would need R.

## 2. Known, not to be measured again

- **DuckDB-WASM can make the tiles** (the formats research of 2026-11-11): `ST_AsMVT` works since duckdb-wasm 1.30.1,
  handed to MapLibre by its `addProtocol`. It is heavy: the core engine 34-36 MB and the spatial extension 23.5 MB (about
  11 MB to download, 58 MB to compile), loaded from a CDN, on one thread. That day's verdict: too heavy just to draw a
  map; the maintainer: "keep rr for now relatively simple", so DuckDB-WASM was left "not now".
- **It starts from a folder.** fishycode's vessel demo (decision 153) runs DuckDB-WASM 1.28.0, fetched from jsdelivr,
  from `file://` in Chrome and Firefox; the internet was needed for the engine.
- **The frozen bundles** (2026-11-11): from a folder a PMTiles archive is read whole (1-2 s and 300-650 MB more memory for
  90-141 MB of tiles); from a web host by range requests.
- **A bundle opens from a folder** on MapLibre 6.19.0, repackaged as classic scripts (decision 328); ogis's
  `test-file.R` opens one in headless Chrome and Firefox.

## 3. Design of the trial

- **A layer is frozen or live.** Frozen: its tiles in a PMTiles archive, as now, and the default. Live: its rows as a
  Parquet file in the bundle, and the tile SQL ogis's server runs for it, sent as a template the page fills for each tile
  and runs in DuckDB-WASM, MapLibre reading the result through `addProtocol`. A frozen and a live layer on one page.
- **The engine** from a CDN, as the vessel demo, or copied into the bundle so it opens offline (about 60 MB a bundle):
  both tried.
- **From a folder** the Parquet file is read whole (no range requests from `file://`); **from a web host** by range
  requests.
- **The check of correctness**: a live layer's tiles equal the served layer's at sampled tiles and zooms (the same SQL;
  the same features and values, the bytes where the engines agree).
- Generic: ogis's, nothing Icelandic. `og_bundle()`'s default and `og_serve()` unchanged.

## 4. What is measured

On each route (a folder; a web host on this Mac), against the same layer frozen: the bundle's size; the time to the
first drawn tile and to a view settled; the memory the page takes; a tile's time by zoom; a filter changed and redrawn;
whether it opens offline with the engine copied in. In Chrome and Firefox headless, as `test-file.R`; Safari by the
maintainer (ask c).

## 5. Steps

1. **A hand-made live bundle**, in a study under `$FISHYDATA/archive/`, not in ogis's code: ogis's page, DuckDB-WASM from
   a CDN and one live layer, `og_cells()` on ogis's `dansk` example (its pings, 6.6 MB of Parquet), opened from a folder
   and from a local web host; measured (§4) and checked (§3).
2. **The engine copied into the bundle**: opened offline; measured.
3. **A larger file from a web host** on this Mac only (ask a), its range requests measured.
4. **A report**: the measures against the frozen layer, and a recommendation: whether `og_bundle()` gains a live layer,
   for which kinds of layer and up to which sizes.
5. **Only at the maintainer's word**: the live layer in ogis (`og_bundle()`), with tests, as a choice beside the frozen.

## 6. Asks

a. **The trial's data.** ogis's `dansk` example (public) for steps 1-2; for step 3, fishycode's census pings
   (decision 329, internal: 85 MB, on this Mac's local host alone) or a public dataset of that size?
b. **Offline.** Must a live bundle open with no internet (the engine copied in, about 60 MB a bundle), or is a CDN
   enough for MFRI's use?
c. **Browsers.** Chrome and Firefox headless, Safari by the maintainer, as for plan 077?
d. **Where the trial lives.** A study under `$FISHYDATA/archive/`, ogis untouched until step 5?

## 7. Not in this plan

SQLRooms or any other app framework around the page; AI in the page; deck.gl; any change to `og_serve()`; the
simplification of shapes by zoom and the repair of invalid ones before tiling (faults of their own, TODO 204);
DuckDB-WASM for the vessel overview.
