# 076 — rebelrebel as a foundation: what a page built on it needs, and the faults such pages found

**status:** partly built — written 2026-11-17 at the maintainer's word (rebelrebel is not an editor; editing pages are built
ad hoc on its foundation, so that each one smoke-tests its engine; the foundation made right now rather than later), from
the names editor's smoke test and a survey of every map page in fishycode, its studies and EM4SSF; asks a-c, e and f
answered the same evening (turned names at their point, the seam as proposed, all four of §3.6's gaps, the steps in
order, articles first), ask d on 2026-11-18 (one 5 MB line for every layer, as now); step 1 built the same night (rebelrebel 2026.11.17, 4698bc2, not pushed: maps live in
Quarto and R Markdown documents and pkgdown articles, the article "Get started" in Quarto, three faults it found
mended); step 2 built (2026.11.17.1, 0b8f6d3: the guarded click, MapLibre 5.24.1); step 3 built 2026-11-18 (2026.11.18, 86d13a9: labels); steps 4 and 5 the same night (5fe2c0a: `id` and MapLibre's terms; 5b0aa95: the seam, `rr_script()` and the map's own routes); step 6 the names session's (two engine faults it found mended 2026-11-18: `rr_add_layer()`, 2026.11.18.3, 16ba1f4; `rr.fetch()`'s path and query, 2026.11.18.4, 83b4fb6), step 7 under way (2026-11-18: the base map by address, 61032f1; layer order, f95a77c); R Markdown kept (2026-11-18, it costs no code); installed in R's library on 2026-11-18 at the maintainer's word ("Install, then names map": 2026.11.18.2 from the local `main`, 5b0aa95, `R CMD INSTALL --preclean` of a built tarball; not pushed, so no `RemoteSha`), and 2026.11.18.4 (83b4fb6) the same way later that day ("Install now"; the editor on 4836 and the names map on 4849 had stopped by then) · **see:** plan 072
(rebelrebel), plan 074 step 7 (the names editor), TODO 198

Drafted with AI assistance (Claude) on 2026-11-17; a person has not yet checked it. What §1 calls measured, Claude measured
(scripts, logs and tables in `$FISHYDATA/archive/2026-11-17-rebelrebel-foundation/`); §2-§5 are proposal.

The maintainer, 2026-11-17:
- On the names editor, rebelrebel should not be an editor ("concur"); "the edits is something that gets build ad-hoc on
  top of that. That way we always will check the engine of rebelrebel ... acting our own smoke-tester of rebelrebel when
  we cook something ad hoc".
- "MapLibre judges a zoom condition in a layer's filter at whole zooms only - Why are we not just using that. We have to
  think of rebelrebel being robust, no only fancy."
- "If you want to know what we want rebel rebel to do - check also the stuff we have been playing around with in
  fishycode and em4ssf."
- "we really need good articles for the user - articles are also a good feedback mechanism, it acts as feed-back lopp: If
  you can not create easy intuative code for the user to create a map, you need to back to the the package structure."
  And: "I love building and checking things in pckdown and devtools, so use those."
- "everything has to be platform independent - linux, mac and windose".
- "I think the articles should show at lest some of the simple maps in the rendered version of the article. the
  rstudio leaflet package does, so should we."
- "we are going to feed the rebelrebel package with some good examples from our icelandic landings / logbooks and ais.
  for the time being we use the current public stuff, in part because the selection of good examples from the icleandic
  dataset requires some deep mining on its own", warts and all: the issues people have with VMS and AIS data, around
  which EM4SSF and WGSFD revolve.

## 1. What is at hand (measured 2026-11-17)

### 1.1 The names editor

`$FISHYDATA/archive/2026-11-11-named-features/scripts/75_name_editor.{R,html}` (163 and 632 lines; internal) is a page and a
server of its own. From rebelrebel it takes `rr_tiles_mbtiles()`, the vendor folder by `system.file()` and
`rebelrebel:::.rr_terrarium_png()`; its depth colours copy rebelrebel's palettes by value, its contours repeat the
engine's maplibre-contour set-up, and its server answers eleven routes of its own (the names, LMÍ's names, the aids, an
area by key, the letterings by key, depth tiles, an edit by POST, the edits). Four of the smoke test's nine faults were
viewer plumbing (the study's README, "The names editor smoke-tested"): the names rebuilt at every request (12-17 s, the
tiles and contours queued behind them); MapLibre's index lost after the names were sent again (§1.3); a click's fetch
landing on a later selection; a search with no ranking and no count. The other five were the editor's own.

### 1.2 Every other map page

Read on 2026-11-17 (Claude, two read-only surveys): fishycode's seven products, some 30 map scripts in 15 studies, and
EM4SSF's three viewers and five R Markdown maps.
- **Built on:** four products and about half the studies' scripts still on ramb's `rb_map_*()` (through
  `bathymetry_map_build()`), one product, the newer studies and one EM4SSF viewer on rebelrebel; four pages written by
  hand (MapLibre 4.7 or 5.24, deck.gl, Leaflet) with their own httpuv servers; EM4SSF's R Markdown maps in leaflet.
- **What they did by hand, again and again** (the pieces a foundation would hold once):
  - *Reaching into the built map:* the map's lists edited (`m$config`, `mp$layers$<id>$config`) in over twenty
    scripts, often in two copies ("the page reads this copy"); `rebelrebel:::.rr_map_verdict_spec()` in four; EM4SSF's
    hand check guessing the layer ids rebelrebel makes (`"pings_2"`). What they set: a style (a halo, a ring of fixed
    size, an outline only, one colour), which base map opens, the order of layers and groups, the seabed's starting look.
  - *Labels:* italic for water, an angle, a priority and a start zoom by filter, written by hand in five pages; contour
    labels along lines in three.
  - *Maps merged:* one built map's groups, layers, texts and palettes added to another's in five scripts.
  - *Servers:* a second httpuv server for local raster tiles (three), a JSON service of the page's own (three), a loop
    to keep an `Rscript` serving (the names editor, EM4SSF's harbours), `NO_SERVE=1` to build without serving (eight).
  - *Pages written by hand:* a search box, the URL hash, keys, a selection drawn by sending data again.
- **Faults noted in their comments, still open in rebelrebel:** `rr_map(data)` drops `basemaps` and `view`; a base map
  given as a tile address cannot open the page; a base map without glyphs leaves names unwritten; GeoJSON layers
  without a count drawn in their order of arrival (an 8 MB coast over the names); `rr_segment()` calling `ST_MakeLine`
  without the spatial extension loaded; a tiled layer refused when its colour column is also in its popup.

### 1.3 MapLibre's lost index: its own fault, and the editor's fractional starts trigger it

The error the editor met, "Out of bounds. Index requested n=0", is MapLibre's: a tile reloaded while an earlier reload
of it is still being parsed loses its raw data, and `queryRenderedFeatures()` then throws on that tile until it is
loaded again. MapLibre fixed it in 6.0.0 (maplibre-gl-js pull 7765, June 2026) and a second path in 6.3.0 (issue 8064,
August 2026); 5.24.1 (2026-11-11, the last of 5.x) carries only fixes to how attributions are cleaned. rebelrebel stays
on 5.x, since 6.x loads only as ES modules, which a bundle opened from its folder cannot (plan 072, 2026-11-11).

Reproduced in headless Chrome on a bare page of MapLibre 5.24.0 (4,000 points drawn as circles and as turned text):
- **Data sent again, six ways** (once, twice at once, five times at once, with a jump, while tiles load, the editor's
  pattern), 30 times each, on 5.24.0 and 5.24.1: no failure in 360.
- **A filter reading the map's zoom from MapLibre's global state** (the editor's way to show a name from a fractional
  zoom, the state set at each 0.02 of a zoom), the data sent during an animated zoom: the text layer's query failed in
  13 of 100 trials (4 of 40 in a first run), the circles' never; an animated zoom alone, no failure in 100. **The same
  with a plain filter on `["zoom"]`** (whole zooms): no failure in 100, with the data sent during the zoom or not.
- Sending the data once more cured every failure (17 of 17).

So the trigger is a filter that changes as the map zooms: every step reloads the layer's tiles, and data sent meanwhile
collide with them. Whole zooms take the trigger away; a guard in the engine (§3.5) is the backstop for any page that
reloads tiles quickly.

### 1.4 Start zooms at whole zooms

Of the 25,880 names on the names map, 22,987 (88.8 %) start at a fraction of a zoom (script 81's start, which places no
two names on one another). Drawn from the first whole zoom at or above it, as MapLibre's filter on `["zoom"]` does, a
name shows 0.48 of a zoom later on average (median 0.48; 10,456 more than half a zoom later). No overlap is added: the
names drawn at a whole zoom are those 81 placed apart there, and zooming in only spreads them. Four names are never drawn
(no room), as now.

### 1.5 Turned names

908 names (3.5 %) are turned (an angle of half a degree or more). MapLibre gives a turned name at a point one collision
box, upright, round the whole turned text, so it hides neighbours its letters do not touch; the editor draws each
turned name on a short line of its own for each whole zoom (MapLibre then checks it letter by letter), cut to zoom 4 so
that a line never crosses a tile's edge. Measured in headless Chrome at whole zooms on the names, in the editor's style
(8 places round Iceland at zooms 6, 8, 10 and 12, 1280 × 800; names counted by key, each once):

| Turned names drawn | names drawn | turned names drawn | hidden by MapLibre's collision |
|---|---|---|---|
| with overlaps allowed (all due) | 842 | 191 | none |
| at their point, one upright box | 752 | 163 | 90 (10.7 %) |
| on lines of their own, cut to zoom 16 | 771 | 183 | 71 (8.4 %) |
| on lines of their own, cut to zoom 4 (the editor's) | 769 | 183 | 73 (8.7 %) |

- The gain of the lines is at zooms 8 and 10 (219 against 209 of 242 at zoom 8, 307 against 301 of 355 at zoom 10);
  at zoom 12 every name is drawn either way. No name was drawn twice.
- **Even on lines, MapLibre hides 8 % of the names script 81 placed apart:** its text boxes (padding, spacing) are
  larger than 81's reckoning. That is the names study's to settle (81's measure of a name), not rebelrebel's.
- **The editor's cut at zoom 4 misplaces turned names when zoomed in** (15 turned names, each at the view's centre): the
  lines' ends snap to the zoom-4 tile's grid, so at zooms 12, 14 and 16 a name is drawn 4, 17 and 69 pixels from its
  place on average (up to 100) and turned up to 4°, 14° and 20° off; at zoom 16 only 5 of the 15 are drawn. Cut to zoom
  16 (a source buffer of 512 pixels keeps every line whole in its tile), each is within 0.02 pixels and 0.2° at every
  zoom. A fault of the live editor, reported to the names study.
- The lines' length comes from an estimate of a name's width (characters times a width per size, plus 15 %); a name
  longer than its line is not drawn, so the estimate is a thing that can break with another font.

### 1.6 What rebelrebel has now, for these asks

- `rr_text()` writes a column at points: a colour (by a column too), one size, a white halo; no angle, priority, start
  zoom by row, offset or font face; text on lines is not placed along them.
- A layer sent whole is read once, when the map is built or served: the editor's first fault cannot arise for a
  rebelrebel layer. A click's row is fetched into the clicked popup's own box, so a late answer lands in a closed box,
  never on the next feature: the editor's seventh fault is already guarded for rebelrebel's popup.
- The server's routes are fixed (the page, its config, tiles, whole data, a row, a fit, the time panel, and opt-in
  notes and verdicts); a page cannot add its own. Nothing runs a page's own script.
- `rr_layer(state = )` puts a reader's control in MapLibre's global state, changed by a click, never as the map zooms.
- Plan 072 §3.4 promised `id` on every layer function and `...` passed to `rr_layer()` (MapLibre's paint and layout);
  neither is built (`...` takes only `color`).
- No article in rebelrebel yet (its site has the reference only; the maps article is ramb's), and a map printed in an
  article has nowhere to go (no `knit_print()`). R CMD check runs on macOS, Windows and Ubuntu on GitHub Actions.
- The names' label layer (name, start, angle, priority, size, kind, offset and key) is 5.2 MB of GeoJSON: just over
  the 5 MB line, so it would go as tiles by default.

## 2. The line between rebelrebel and a page built on it (proposal)

- **rebelrebel views.** What any viewer of any data may want is rebelrebel's: labels with angles and start zooms, a
  layer's id, MapLibre's paint and layout on any layer, the order of layers and base maps, a guarded click, a server
  that keeps serving from `Rscript`, a page's own routes and script.
- **A page edits.** Its panel, its edits, its ledger and its routes are the page's, in its study or project.
- **The rule:** a page uses rebelrebel's documented surface only: its exported R functions, and in the browser the
  `rr` object (§3.3). `:::`, edits of a built map's lists, rebelrebel's DOM and its vendor folder are faults of that
  surface: mended in rebelrebel with a test and a line in an article, never worked round in the page.

## 3. What rebelrebel would provide (proposal)

Each item lands with tests (`devtools::test()`), a clean `devtools::check()`, and an article or a section of one, built
by `pkgdown::build_site()`; an article whose code is long or awkward sends the item back to its design. Nothing in R
calls a shell or a fixed path, files are written as UTF-8 on every platform, and a change is done when GitHub Actions
pass on macOS, Windows and Ubuntu (at the next push the maintainer asks for).

### 3.1 Labels: `rr_text()`

```r
rr_map() |>
  rr_text(names, label = name, minzoom = z0, angle = rot, priority = size_km,
          size = px, fontface = face, offset = c(0, dy))
```

- **`minzoom` a number or a column:** each row drawn from the first whole zoom at or above its value (a filter on
  `["zoom"]`, as MapLibre judges it). Fractional starts through the global state are not built (§1.3, §1.4; ask b).
- **`angle`**, degrees, counter-clockwise as ggplot2's `geom_text(angle = )`; a number or a column. How a turned label
  meets its neighbours: ask c. **`overlap`**, `FALSE` by default (MapLibre's `text-allow-overlap`).
- **`priority`**, a number or a column: higher placed first where labels meet (MapLibre's `symbol-sort-key`,
  reversed). Within a tile only, as MapLibre places; said in the help.
- **`size`** by a column (pixels), **`fontface`** (`"plain"`, `"italic"`, `"bold"`, `"bold.italic"`, ggplot2's word) as
  a value or a column, **`offset`** in text heights (`c(x, y)`, numbers or columns; tmap's `xmod`/`ymod`).
- **Lines:** text on a line is written along it (MapLibre's `line-center`), as the editor's long names.
- Whole or as tiles by the one 5 MB line every layer has (ask d: no line of its own for text); a page that sends a
  text layer new data (`rr.setData()`) gives `whole = TRUE`.

### 3.2 Ids and MapLibre's own terms on every layer function (plan 072 §3.4, unbuilt)

`id = "names"` on every layer function (else made from `name`, as now), and `...` passed to the layer's style as
MapLibre's paint and layout (`"circle-stroke-width" = 2`, `"text-halo-width" = 0`). With them the twenty scripts that
edit `m$config` and the four `:::` calls have a documented way.

### 3.3 The seam: a page's own script

```r
rr_map() |> rr_text(names, label = name, id = "names") |> rr_script("editor.js", css = "editor.css")
```

The script is put into the page (and a bundle) and called once the layers are drawn, given one object, `rr`:

| `rr.` | gives |
|---|---|
| `map` | MapLibre's map |
| `layer(id)` | a layer's MapLibre style ids and source |
| `on("click", id, fn)` | a click on the layer's features: `fn({feature, lngLat, row})`, `row()` the clicked row, answered as `null` when a newer click came |
| `setData(id, geojson)` | a whole layer's data sent again, at most once a frame, with the guard of §3.5 |
| `filter(id, key, expr)` | an expression of the page's, ANDed with the engine's own (`choose`); `null` removes it |
| `panel(title)` | a box in the sidebar, the page's to fill |
| `route(name)` | the address of the page's own route (§3.4); `null` in a bundle |

Seven things, documented in one article; the page needs nothing else of rebelrebel's.

**A page with no R** (the maintainer, 2026-11-17: "it would be really nice if the product created in rebelrebel could be
saved as an "entity" so that the construct can be run by another user withour any R. We have already done some such
constructs in fishycode"): that entity is `rr_bundle()`, a folder that opens with a double click on any system (moved
from ramb; fishycode's bathymetry and depth-effort maps, decisions 277 and 278). A page's script goes into its bundle
too; only its routes need R, so `rr.route()` is `null` there, and a page that takes a reader's input in a bundle keeps it
in the browser and hands it over as a file (a small `rr.save(name, text)` beside the seven, proposed with step 5).

### 3.4 The server: a page's routes, and serving from `Rscript`

- `rr_serve(map, routes = list(edit = function(req) ...))`: each answered under `/x/<name>` (so no route of the page's
  can take one of the engine's), given the method, the rest of the path, the query and the body (JSON read); a list or
  data frame returned is sent as JSON, `NULL` as not found, an error as its message. Writes (POST) are answered only for a
  page opened from this computer, as notes and verdicts are.
- `rr_serve(wait = !interactive())`: from `Rscript` the server keeps serving until stopped, as `shiny::runApp()`
  does; no loop by hand.

### 3.5 The engine's guards

- **One click and one hover:** the engine queries its clickable layers itself, top first, each in a guard; a layer
  whose index is lost is sent its data again (a whole layer) or its tiles are refreshed, and the click is tried once
  more when the map is idle. Tested in the browser by a forced failure; the reproduction of §1.3 kept in the study.
- **Data sent again at most once a frame** (`rr.setData()`), so a page cannot set off reloads in quick succession.
- **MapLibre 5.24.1** in place of 5.24.0 (attributions cleaned; same interface).

### 3.6 Smaller gaps the survey found (each its own ask, e)

- A base map given as a tile address (a WMS's too) may open the page; `rr_map(data)` keeps `basemaps` and `view`.
- Layer order by a call (`rr_map(order = )`), not by the order sections are first named.
- A point's ring and an area's outline alone, as arguments (`stroke`, `fill = NA`).
- A search over a layer's text column (`search = name`): whole matches first, then beginnings, then any, nearest the
  view first, counted.
- The seabed as layer functions (`rr_relief()`, `rr_contour()`, plan 072 step 3) with a starting look, so no map is
  merged into another by hand.

### 3.7 Maps in articles

The maintainer, 2026-11-17: "I think the articles should show at lest some of the simple maps in the rendered version
of the article. the rstudio leaflet package does, so should we." `knit_print()` for a map: in R Markdown and Quarto a
map printed in a chunk is written as a bundle beside the article and shown live in an iframe, so `pkgdown::build_site()`
builds articles whose maps pan, zoom and answer clicks, as leaflet's do (plan 072 §3.14). leaflet writes its data into
the page itself; a bundle keeps it in files beside it, so a site's size grows with its maps' data: the articles' maps
use small open data, one copy of MapLibre for the whole site, and a guard on a bundle's size (measured in step 1).
First, since every other item's article needs it.

## 4. Steps

Each committed in rebelrebel's local `main` on its own, with its tests and article; pushed only at the maintainer's word.

1. **Maps in articles** (§3.7) and a first article, a map in five lines from an example file, the map live in the
   rendered page. Check: `pkgdown::build_site()` builds it locally, the map pans and answers a click in the built site
   (headless Chrome), and the site's size with and without it. **Built 2026-11-17** (rebelrebel 2026.11.17, 4698bc2):
   `knit_print()` writes each printed map as a bundle and an htmltools dependency, shown in an iframe whose small
   locator script finds the dependency's folder (pkgdown's `articles/<name>_files/libs/`, Quarto's `<doc>_files/libs/`,
   R Markdown's `<doc>_files/`), MapLibre one copy a document (1.3 MB); a self-contained page says where the map went.
   The maintainer, the same night: the articles are Quarto ("we are using quarto for the documents"); "Get started"
   (`vignettes/articles/rebelrebel.qmd`) has three maps of the survey's pings and tows, 2.9-3.1 MB each, the article
   10 MB, the site 17 MB. In headless Chrome every point drawn (8,918), each map fitted to its frame. The article found
   three faults, mended: a map from data opened at a zoom from its extent's width alone (3 for Iceland in any frame),
   now the extent fitted to the frame (4.6-4.8 in the article); `rr_map()` with no data stopped, now a map whose layers
   bring their own; duckdb's notice of its extension folder printed into documents. Browser tests (chromote; skipped
   on CRAN and without Chrome) render an R Markdown and a Quarto document; R CMD check 0 errors, 0 warnings, 1 note (an
   example line, as before); the pkgdown workflow sets Quarto up. Whether R Markdown is kept at all (the
   maintainer: "Question is if we should entertain the .Rmd construct at all"; it costs no code, the same
   `knit_print()` serving both, and one test): answered 2026-11-18, kept ("If it cost no code, keep rather than
   drop"): maps keep working in R Markdown, its test stays, the articles are Quarto.
2. **The engine's guards and MapLibre 5.24.1** (§3.5). Check: a browser test with a forced lost index; the names
   editor's click path, on a copy, no failure in 100 tries of §1.3's pattern. **Built 2026-11-17** (rebelrebel
   2026.11.17.1, 0b8f6d3): every query of the page through one guard, `query()`; one click dispatcher and one pointer
   check a frame in place of the layers' own MapLibre handlers (which queried unguarded); a whole layer healed by its own
   data sent again (`setData(source.serialize().data)`), which cured 6 of 6 in the reproduction where MapLibre's
   `refreshTiles()` cured none; a tiled layer by its tiles fetched again (not reproduced on tiles, so untested). MapLibre
   5.24.1, checked against npm's integrity hash. Browser tests: a forced lost index and a real click (the popup opens,
   the data sent once, no error on the page), and a served map's note pin, hover label and pointer. R CMD check 0 errors,
   0 warnings, 0 notes. The names editor's own click path is not rebuilt here: its fractional starts go with step 6.
   Learnt on the way: Quarto renders an article's R in a process of its own, which loads the *installed* rebelrebel,
   so a local `pkgdown::build_site()` needs the package installed first (GitHub Actions installs it); and the site's
   deploy keeps old files (`clean: false`), so map folders of earlier builds stay on the published site (a follow-up).
3. **Labels** (§3.1) with an article on labels from the package's current public examples (the harbours' and the
   survey stations' ids), and, for names with angles and start zooms, which those lack, a small public set (Natural
   Earth's marine areas, public domain; checked before use). Check: the article's map, and the names' 25,880 drawn by
   `rr_text()` with the counts of §1.5 met. **Built 2026-11-18** (rebelrebel 2026.11.18, 86d13a9): `minzoom` (a column: a filter on
   `["zoom"]`), `angle`, `priority`, `size`, `fontface` (each face in the base style's own fonts, read in the page: Carto's
   are Montserrat Medium, Regular Italic, SemiBold and SemiBold Italic) and `offset` (a column's values matched by a key
   the rows carry), each a value or a column; `overlap`; text on lines along them. In the browser, whole and as tiles and
   past the tiles' deepest zoom, a row due at 5.4 shows from 6 and at 15.5 from 16. The names' 25,880 through
   `rr_text()`: built in 0.2 s, and MapLibre hid 10.3 % of those due at the 32 views (rebelrebel's frame), against 10.7 %
   with the editor's style (study, result 5). The article "Labels" uses the package's examples (the harbours' ids
   inside them, the tows' along them, the survey positions turned to their heading, by start zoom and priority), so no
   Natural Earth set was needed; it found that `rr_map(view = )` and `basemaps` were dropped for a layer function's map
   (a §3.6 fault, mended here).
4. **Ids and MapLibre's terms** (§3.2). Check: EM4SSF's hand check and three of the studies' scripts rewritten
   without `m$config` (on copies). **Built 2026-11-18** (rebelrebel 2026.11.18.1, 5fe2c0a): `id` on every layer function (checked,
   free in the map), and MapLibre's paint and layout by their names in `...`, each put on the layer's styles of its kind
   as paint or layout as MapLibre has it (a ring of fixed size, an outline alone, a text without halo); "Get started"
   rings the positions over 12 knots that way. Not done: the rewrites on copies. EM4SSF's hand check is built on ramb's
   `rb_map_*()`, whose move onto rebelrebel is plan 072's step 5; its styling (a cyan ring of fixed size over chosen
   points, a grey track, ids not guessed) is held by a test on the package's examples instead.
5. **The seam** (§3.3, §3.4) with an article, "A page of your own": a script and a route that keep a list of the
   features a reader marks, on the same open data. Check: the article's code short and plain. **Built 2026-11-18** (rebelrebel 2026.11.18.2, 5b0aa95), with two
   changes to §3.3-§3.4 as proposed: (a) `rr.route(name)` became `rr.fetch(name, init)`, beside `rr.served` and
   `rr.save()`, since a page's writes must carry the guard the notes' do (a header and the page's origin), which a bare
   address would leave to each script; (b) `rr_serve(wait = )` is `FALSE` by default, not `!interactive()`: on by
   default it hung the package's own test of a real server, as it would any script, test or document that serves a map
   and goes on, so a script run by `Rscript` gives `wait = TRUE`. Tests: the routes as httpuv calls them; in the browser,
   a script's click reading its row and posting to its route, its filter and new data holding, the same map in a bundle
   running the script with no server; a child `Rscript` serving with `wait = TRUE`. The article's map keeps a list of
   marked positions, handed to the reader as a file in the bundle. The whole suite 1,028 tests; R CMD check 0/0/0; the
   site, three articles, 25 MB, every map drawn.
6. **The smoke test:** the names map rebuilt on rebelrebel in its study (the names session's prototype, on hold),
   its editing ad hoc on the seam; every engine fault it finds mended in rebelrebel with a test. **Faults found and
   mended, 2026-11-18** (rebelrebel's local `main`, not pushed; R CMD check 0/0/0, the whole suite 1,077 tests, the
   two that need the installed version run against a scratch install): (1) a piped map took no `rr_layer()` (the
   names map's sea floor: a dem and a contour layer from an MBTiles file), and a map of `rr_section()`s takes no
   layer function; approved by the maintainer ("Add rr_layer to the pipe"): `rr_add_layer(map, layer, section)`,
   2026.11.18.3 (16ba1f4), its test with the page, a section in "Get started" (the Danish depths under the harbours).
   (2) `rr.fetch()` encoded the whole name, so a route's `path` and `query`, which `rr_serve()` documents, could not
   be reached (404): the name, then a path and a query as written, 2026.11.18.4 (83b4fb6), with two smaller ones
   reported with it: `popup = <a variable of names>` quiet (tidyselect warned), and a line in `rr_basemaps()`'s
   help (a style on the map's own routes given by a relative address: localhost and 127.0.0.1 are two origins).
   Reported, not built (the names session records them for the maintainer): a per-row end zoom in `rr_text()`, a
   documented key on each feature for a script, a base map of several tile sources by zoom band.
7. **The smaller gaps** of §3.6 that the maintainer takes, one at a time. Begun 2026-11-18 at the maintainer's word
   ("Yes, start step 7"), the base map first: (1) *a base map by address opens the page* (2026.11.18.5, 61032f1):
   found mended already, by 96de711 on 2026-11-12 (`setBase()` wrote `glyphs: undefined`, which MapLibre refused, so
   a page opening on a picture by address never loaded a style; reproduced on d21a368), minutes after the names
   study's scripts were written round it; now tested offline in the page (a `{z}/{x}/{y}` and a WMS address, the
   switch between them, the address), `rr_basemaps()`'s help on how such an address is written, and "Get started"
   opening on GEBCO's WMS. Its other half, `rr_map(data)` keeping `basemaps` and `view`, was mended in step 3.
   (2) *layer order by a call* (2026.11.18.6, f95a77c): `rr_map(order = )`, ids from the lowest drawn up, the
   sidebar keeping its own order; a piped map now draws in the order added whatever the boxes (it drew by box,
   against its docs); and the page keeps the map's order whatever order its data arrive in (§1.2's "8 MB coast over
   the names", met again by item 1's test). Found on the way, not built: a route of `rr_serve()` answers JSON or
   text, never a picture (a raw vector is sent as JSON), so a page's own raster tiles still need a server of their
   own; the help said otherwise and now does not.

## 5. Asks

a. **The line** (§2): answered in the maintainer's words of 2026-11-17 (an engine fault found by a page is fixed in
   rebelrebel with a test, never worked round in the page); §2 writes it out.
b. **Start zooms at whole zooms only** (§3.1): answered by the maintainer, 2026-11-17 ("Why are we not just using
   that"), and measured in §1.3 and §1.4; fractional starts through the global state not built (the editor's Héraðsflói
   names, due at 7.47-7.77, show from 8).
c. **Turned names** (§1.5): answered 2026-11-17, "At its point" (as recommended). Asked: (1) at their point with
   MapLibre's one upright box, recommended as the robust way: nothing
   estimated, nothing new to break, 90 of 842 names hidden against 71; (2) on lines of their own cut to zoom 16, letters
   checked one by one: 19 more names in the 32 views (20 more of the 191 turned), exact in place and angle, at the price
   of the width estimate and the lines' making (some 60 lines); (3) overlaps allowed where a start zoom is given (the
   data's placement trusted): every name due drawn, words over words where 81's reckoning and MapLibre's differ.
   `overlap = TRUE` (MapLibre's `text-allow-overlap`) is offered whichever is chosen.
d. **A text layer whole up to 10 MB** (the 5 MB line kept for other layers): answered 2026-11-18, "Keep one line":
   one 5 MB line for every layer, as now, nothing built. Recommended at first, so the names' 5.2 MB stay in one
   source; then measured on the names (the study's finding 5): 615 drawn as tiles, 616 whole, at the same 32 views,
   the bundle 40 MB against 7 MB (true of any large layer, not of text). A line of its own for text added a rule with
   nothing to show for it on screen, measured on one text layer only, so the recommendation turned to one line; the
   names map gives `whole = TRUE`, which `rr.setData()` needs anyway.
e. **The seam as §3.3 and §3.4, and which of §3.6 now:** answered 2026-11-17, the seam "As proposed", and of §3.6 all
   four asked: the base map faults (a base map by address opens the page, `rr_map(data)` keeps its settings), layer
   order by a call, rings and outlines, and search over a layer (recommended were the base map faults alone, the rest
   later). The seabed's layer functions stay plan 072's step 3.
f. **The order of §4:** answered 2026-11-17, "Yes, in that order" (as recommended): articles first, each step committed
   to rebelrebel's local `main` with its tests, `devtools::check()` and `pkgdown`, not pushed. Step 6 is the names
   session's (its prototype, on hold until steps 1-5 land); §3.6's four come in step 7.

## 6. Not in this plan

Editing of any kind in rebelrebel; MapLibre 6 (ES modules); fractional start zooms; the Python host; the steps of plan
072 not named here; the Icelandic examples (landings, logbooks and AIS, warts and all), which need their own mining
first: until then the articles use the current public examples. The maintainer, 2026-11-17: "we are actually going to
feed the icelandic dataset into ramb and rebelrebel is going to use those datasets" (so not vortur, as plan 072's
seeds had it). rebelrebel's code depends on neither ramb nor fishycode (plan 072 §3.1b); its articles would read ramb's
datasets with ramb in `Suggests`, to be settled when the set exists.
