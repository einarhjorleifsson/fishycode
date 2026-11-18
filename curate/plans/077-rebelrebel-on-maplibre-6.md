# 077 — rebelrebel on MapLibre 6: the library repackaged, so a page opened from its folder still draws

**status:** proposal — written 2026-11-18 at the maintainer's word ("Yes, write the plan"), after a trial the same day
(plan 076, after step 7). **Measured** (in a copy of rebelrebel 2026.11.18.9 in a scratch folder, on macOS, headless
Chrome and headless Firefox 160): MapLibre 6.19.0 repackaged as a classic script opens from a folder (`file://`) in
both; the whole test suite passes on it; label-heavy maps are as fast as on 5.24. **Assumed, not measured:** Safari;
Chrome and Firefox on Windows and Linux (CI runs the suite on all three, but over http); that 6.x has done with the
lost index of plan 076 §1.3; that later 6.x releases keep the module's shape the repackaging relies on · **see:** plans
072, 076

Drafted with AI assistance (Claude) on 2026-11-18; a person has not yet checked it. What §2 calls measured, Claude
measured.

## 1. Why

- **5.x is frozen.** 5.24.1 (2026-11-11) is its last release, and carries only fixes to how attributions are cleaned;
  6.x is at 6.19.0 and has a release about every month. Staying means no more fixes.
- **The reason to stay holds only for the library as published.** 6.x ships only ES modules (`maplibre-gl.mjs`, and
  its worker as `maplibre-gl-worker.mjs`), which a page opened from its folder cannot load: rebelrebel's bundles open
  by a double click, with no server (plan 072). Repackaged once per release as a classic script, it loads (§2).
- **What 6 gives rebelrebel:** the lost index fixed (6.0.0, maplibre-gl-js 7765; 6.3.0, issue 8064), so the engine's
  guard can go once shown (§3.6); colour ramps interpolated in OKLab or OKLCh (6.19.0; the depth looks were designed in
  OKLCh and are now cut to 17 stops); blend modes for raster, line and fill layers (6.18.0; relief multiplied over the
  depth colours); font files of the page's own for labels (`font-faces`, 6.7.0); faster symbol layout (6.13.0) and tile
  loading (6.15.0), not seen at the size measured (§2).
- **What 6.0 broke, as it touches rebelrebel:** almost nothing in the engine's code. It uses none of `map.transform`,
  `styleimagemissing`, `MapDataEvent`, `setData()`'s return or `waitForCompletion`, nor the RTL plugin. Two changes are
  visible: transparent lines that overlap no longer add up (`line-opacity`), and tiles past their deepest zoom are drawn
  by `zoomLevelsToOverscale` 4. WebGL 2 is required (every current browser has it).

## 2. Measured: the trial (2026-11-18)

How: MapLibre 6.19.0's `dist/maplibre-gl.mjs`, `maplibre-gl-worker.mjs`, its css and licence from jsDelivr. The module
has no `import` statement, ends in one `export {...}` list of 88 names, and reads `import.meta.url` in two places (its
worker's address when served over http). A 40-line text transform wrapped it in a function, put the script's own
address for `import.meta.url` and turned the export list into `window.maplibregl`; its worker's code went into a
classic script of its own, handed to `maplibregl.setWorkerUrl()` as a blob, which 6.17.0 (#8912) made work on a page
opened from a file (a classic worker that imports the module from a `data:` address). No Node or bundler was needed
(Homebrew's Node on the maintainer's Mac is broken; esbuild was not used). The engine changed by one line: the worker's
script loaded before MapLibre.

| check | on 6.19 |
|---|---|
| a bundle of depth colours, contours (maplibre-contour), outlined areas, labels and search, opened from its folder in headless Chrome | drawn: 242 areas, 129 labels, 19 contour lines in view, the depth source loaded |
| the same in headless Firefox 160, driven over WebDriver BiDi | drawn: 271 areas, 119 labels, 32 contour lines |
| the test suite (`test_dir()`, the copy loaded) | 1,222 checks, none failed; two skipped, which need the copy installed |
| those two, the copy installed in a library of its own (knit, Rscript) | 75 checks, none failed |
| 8,918 turned labels with priorities, a bundle served over http, median of five | open 0.47 s (5.24: 0.44 s); five zoom steps 1.68 s (5.24: 1.69 s) |
| a bundle's size | 0.6 MB more (the worker in a file of its own; in 5.x it is inside `maplibre-gl.js`) |

The one console line in either browser was MapLibre's warning that the first style was set before it had loaded (the
engine's opening base map), which 5.x also meets.

## 3. Design

### 3.1 The repackaging, in R

`tools/vendor-maplibre.R` in the package (excluded from the build), run by hand at each MapLibre update: it takes a
version, downloads that version's `dist/maplibre-gl.mjs`, `dist/maplibre-gl-worker.mjs`, `dist/maplibre-gl.css` and
`LICENSE.txt`, checks each against the npm registry's integrity for that version, and writes `inst/engine/vendor/`:
`maplibre-gl.js` (the module as a classic script) and `maplibre-gl-worker.js` (the worker's code as a string). It
stops, with what it found, if the module has an `import` statement, a use of `import.meta` other than `.url`, or no
single export list at its end: then the shape has changed and the transform is rewritten (or esbuild used, which needs
Node). The version is written at the head of both files and into `vendor/README`.

### 3.2 The engine

The worker's script loaded before MapLibre; the worker always given by `setWorkerUrl()` from that script's code, served
or opened from a folder (the trial's way; the suite passed with it); comments that name 5.x brought up to date. The
guard on queries (plan 076 §3.5) stays.

### 3.3 Tests

Every browser test today opens its page over http. One is added that opens a bundle from its folder (`file://`) in
Chrome, drawing points, labels and contours, so the case that kept rebelrebel on 5.x is tested in CI on all three
systems. Firefox: `tools/firefox-check.R`, the trial's WebDriver BiDi client, run by hand at each MapLibre update (CI's
runners may lack Firefox; a test skipped there would prove nothing).

### 3.4 What to look at

The articles rebuilt and looked at, beside 5.x's: transparent lines that overlap (the tows), labels and contours past
their tiles' deepest zoom. Safari: the maintainer opens one bundle by a double click.

### 3.5 Cost

A bundle 0.6 MB larger; one script to run per MapLibre update; one line in the engine. Users see nothing else.

### 3.6 Later, each on its own

The guard dropped once plan 076 §1.3's reproduction (a filter on the zoom from MapLibre's global state, data sent
during an animated zoom) shows no failure on 6. Then, as wanted: OKLCh ramps for the depth looks, blend modes for
relief over depth, the page's own fonts.

## 4. Steps

1. `tools/vendor-maplibre.R`; 6.19.0 (or the latest 6.x then) vendored; the engine's line; `devtools::check()`, the
   articles rebuilt and looked at (§3.4); committed, with NEWS.
2. The `file://` test; `tools/firefox-check.R` run; Safari by the maintainer.
3. Installed, at the maintainer's word; the pages built on it (the names map) started again on it.

## 5. Asks

a. **The order, with the rename to ogis (`og_`).** The maintainer is considering renaming the package. Recommended: the
   rename first, while nothing else is in flight, then this plan in the new names; a rename changes no behaviour, so
   the suite before and after shows it, and MapLibre 6 is then measured against a renamed baseline.
b. **Pin, or follow.** Recommended: a pinned version, updated by running the script on purpose, not the latest at
   each build.
c. **Firefox in the suite, or by hand.** Recommended: by hand (§3.3).

## 6. Not in this plan

The rename; MapLibre 6's new features (§3.6, each its own); the guard's removal; the Python host.
