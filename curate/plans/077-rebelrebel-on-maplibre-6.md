# 077 — rebelrebel on MapLibre 6: the library repackaged, so a page opened from its folder still draws

**status:** executed — 2026-11-18 (decision 328), Safari checked by the maintainer the same day ("Safari draws the maps fine"); steps 1 and 2 built 2026-11-18 at the maintainer's word ("start the MapLibre 6 plan"; asks b and c as recommended): ogis 2026.11.18.11, a9e450e; pushed with two test fixes (70c62d8) once CI's failure on Linux and Windows for 905b520 was read (a flaky label test, and Chrome's temporary folder that --as-cran noted), CI then passing on Ubuntu, Windows and macOS and the site live on MapLibre 6; step 3 done the same day (ogis 2026.11.18.11 installed in R's library at the maintainer's word, "Yes, install": its knit, script and `file://` tests pass against it); Safari drew the maps (the maintainer). Written 2026-11-18 at the maintainer's word ("Yes, write the plan"), after a trial the same day
(plan 076, after step 7). **Measured** (in a copy of rebelrebel 2026.11.18.9 in a scratch folder, on macOS, headless
Chrome and headless Firefox 160): MapLibre 6.19.0 repackaged as a classic script opens from a folder (`file://`) in
both; the whole test suite passes on it; label-heavy maps are as fast as on 5.24. Ask a answered the same day ("Rename first"): rebelrebel was renamed ogis, `rr_` `og_` (ogis 2026.11.18.10, e8b4780); this plan is built in the new names. **Assumed, not measured:** Safari;
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

**The guard: done 2026-11-18 (decision 328, amended):** the reproduction failed 9 times in 200 on 5.24.1 and never in 200
on 6.19.0, and the guard went in ogis 2026.11.18.12 (f2a6509).
**OKLCh ramps: tried and reverted; blend modes for relief: not possible in 6.19** (decision 328, amended). Fonts open.

The guard dropped once plan 076 §1.3's reproduction (a filter on the zoom from MapLibre's global state, data sent
during an animated zoom) shows no failure on 6. Then, as wanted: OKLCh ramps for the depth looks, blend modes for
relief over depth, the page's own fonts.

## 4. Steps

1. `tools/vendor-maplibre.R`; 6.19.0 (or the latest 6.x then) vendored; the engine's line; `devtools::check()`, the
   articles rebuilt and looked at (§3.4); committed, with NEWS.
2. The `file://` test; `tools/firefox-check.R` run; Safari by the maintainer.
3. Installed, at the maintainer's word; the pages built on it (the names map) started again on it.

### 4.1 Built (2026-11-18)

Steps 1 and 2 in ogis 2026.11.18.11 (a9e450e). `tools/vendor-maplibre.R` takes the npm tarball checked against the
registry's SHA-512 (a `file()` connection hashed to another digest; the raw bytes match the registry and `shasum`) and
writes the two classic scripts; its output equals the trial's but for a comment line (`substring()`'s default end at
character 1,000,000 first cut the export list off: it now stops if the list names nothing). The engine loads the
worker's script first; `inst/COPYRIGHTS` says what was changed in MapLibre's code. `test-file.R` opens a bundle from
its folder in Chrome (4 checks); `tools/firefox-check.R` drew it in Firefox 160 (271 areas, 119 labels, 32 contour
lines). Beside 5.24.1 at the same views, crossing transparent lines, a label at zoom 16 from tiles to 14 and contours
past their elevation tiles' zoom look the same. R CMD check 0/0/0 on macOS. Not pushed: CI failed on Ubuntu and
Windows for the rename's push (905b520, macOS passing), its log readable only signed in; the cause is read before
this goes up. Read (pasted by the maintainer): one failure on Ubuntu, `test-text.R` asking which labels were drawn a
fixed 0.3 s after `map.loaded()`, before MapLibre had placed and faded in "Delta" (from zoom 10, as tiles); and a note,
a `com.google.Chrome.*` folder left in the system's temporary folder. Mended in 70c62d8: the test waits for MapLibre's
`idle` event, and during a test run Chrome's temporary folder is inside R's own. Pushed 905b520..70c62d8 at the
maintainer's word ("Yes, push"): R CMD check passed on Ubuntu, Windows and macOS (the `file://` test with them), pkgdown
published the site, whose maps load MapLibre 6.19.0 as repackaged (a live map drew 3,969 positions in view within a
second, in headless Chrome). Step 3: installed in R's library from a built tarball (`R CMD INSTALL --preclean`), 79
checks of the tests that need the installed package passing against it. Safari: the maintainer, "Safari draws the maps
fine".

## 5. Asks

a. **The order, with the rename to ogis (`og_`).** The maintainer is considering renaming the package. Recommended: the
   rename first, while nothing else is in flight, then this plan in the new names; a rename changes no behaviour, so
   the suite before and after shows it, and MapLibre 6 is then measured against a renamed baseline. **Answered 2026-11-18,
   "Rename first"; done the same day: ogis 2026.11.18.10 (e8b4780), checked 0/0/0, its site's 13 article maps drawn.**
b. **Pin, or follow.** Recommended: a pinned version, updated by running the script on purpose, not the latest at
   each build. **Taken as recommended, 2026-11-18: 6.19.0 pinned.**
c. **Firefox in the suite, or by hand.** Recommended: by hand (§3.3). **Taken as recommended, 2026-11-18.**

## 6. Not in this plan

The rename; MapLibre 6's new features (§3.6, each its own); the guard's removal; the Python host.
