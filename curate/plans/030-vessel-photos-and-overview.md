# 030 — Vessel photos from mbl into the flow, and an internal vessel overview app

**status:** partly built — step 1 built 2026-10-18 (`staging/mbl/photo.parquet`, decision 138); step 2's script
written, its pilot refused by a bot check on mbl's pages (decision 141); steps 3 and 4, the R
service and the page, built and checked (decisions 139, 140); asks a-h answered (decision 137; h: the R service
serves, DuckDB-WASM in the page reads); the search for the whole photo set (ask b) is the maintainer's (TODO 85)
· **2026-10-18** · **see:** plan 028 (§3.6, §7), plan 001 (§3, §4), decisions 049, 105, 130, 132 and 137-141,
`sources/mbl/register.R`, `dump/vessels/faroe.R`, `products/publish.R`; outside this repo `~/stasi/fishyshiny/` and the
maintainer's `ShinyApps/asjo/` (the map's model, §4.2)

Drafted with AI assistance (Claude) on 2026-10-18, at the maintainer's request, relayed by the plan 028 session. The
numbers below were measured by Claude (AI). A person has not yet checked them.

**Why** (maintainer, 2026-10-18). An internal overview of one vessel at a time:
- its photo;
- the latest register entry;
- the latest landings;
- the latest logbook trips and stations;
- a map of its latest AIS trail.

Asked first as a Shiny app with a mapdeck map. The maintainer then added (the same day): linked views, so that a map
and a dygraph-type time-speed plot are tied together with a time slider. "The main thing is that [it] is responsive",
and the app may be better written directly in JavaScript, without Shiny in the middle. §4 follows that.

The photos must first enter the flow as an index a consumer can join on `vid`. The app's uses (checking a vessel
while reviewing the key, the register history or a trip) are named here, not measured.

A predecessor exists: the Shiny app in `ShinyApps/skipaskra/` on the institute share (2026-03-02). It read
landings and logbooks live from Oracle, the old trail's `.rds` files and the thumbnails from `~/stasi/skipaskra/jpg/`
on the server. The maintainer does not count it as a model ("may be not my best example"), so it is not one here.

**Measured** (read-only, 2026-10-18, on the build of 2026-10-17):
- every file in `raw/external/skipaskra/jpg/`: size, pixel size, EXIF (R's `magick`);
- the three scripts and eight logs that made them, in `raw/external/skipaskra/`;
- photo coverage against `staging/mbl/register_2023-01`, `staging/samgongustofa/register_2022-12-28` and
  `curated/vessel/vessel.parquet`;
- each panel's table: its schema, how recent it is, and the time to read one vessel's latest rows through DuckDB, for
  three vessels: vid 2757 (most pings in 2026-09), 3739 (median), 2652 (silent since 2024);
- the size of one vessel's year of trail, the payload a browser would hold.

Scripts and output are in scratch only. Nothing was written under `$FISHYDATA`.

**Assumed:**
- the 1,000 files are a capped copy of a set about four times larger (§1.3);
- timings on a cold cache, or on another machine, are of the same order as those measured;
- a browser draws and filters a vessel-year (up to about 150,000 pings) on the GPU without lag. This is deck.gl's
  stated range, not tested here.

## 1. The photos as they are

### 1.1 The files

`raw/external/skipaskra/jpg/` holds 1,000 files, 129 MB. They were copied in on 2026-10-14 with the rest of
`~/stasi/skipaskra`, which then went to the Trash (decision 049); the files' times are 2026-09-30.

| kind | files | MB | pixel size | file size |
|---|---|---|---|---|
| photo, `NNNN-0001.jpg` | 538 | 130.0 | median 1024 × 683, height 90-1822 | median 196 KB, max 1.5 MB |
| thumbnail, `NNNN-0001-thumb.jpg` | 462 | 2.7 | 120 px high | median 6 KB |

- All JPEG. The name is the vid in four digits, then the image's place in the page's gallery, then `-thumb`.
- Every file is image 0001. The scraper took only the first image of each page's gallery (`j <- 1`). How many more
  images mbl holds per vessel was not logged.
- 887 vids: 425 with the photo only, 349 with the thumbnail only, 113 with both.

### 1.2 How they were made

- `R/mbl-scrape_jpg.R` reads `https://www.mbl.is/200milur/skipaskra/skip/<vid>` and takes the first image id in the
  page's gallery (`.carousel-item`). It downloads `https://static.mbl.is/generic/sax/skipamyndir/<id>.jpg` to
  `jpg/<vid>-0001.jpg`. mbl's image id is not in the file name. It is kept only in the logs.
- `R/create_thumbs.R` scales every file in `jpg/` to 120 px high (`imager`) and writes it beside the original as
  `-thumb`. The thumbnails have no EXIF.
- The logs show eight runs on a Linux machine with R 4.2.2:

  | log | vids | end |
  |---|---|---|
  | `nohup_2022-12-27.log` | 1-9999 | halted at 1722 (a failed download) |
  | `nohup2.log` | 1761-9999 | halted at 2088 |
  | `mbl-scrape_2022-12-28_153000`, `_160000`, `_163000` | 2089-3000 | complete |
  | `mbl-scrape_2022-12-28_170000`, `_173000`, `_180000` | 5000-5999, 6000-6999, 7000-9999 | complete |

  No log covers vids 1723-1760 or 3001-4999. The info scrape (`mbl-scrape_info_2023-01-09_*.log`) is a separate run
  (plan 028 §3.6).
- The logs record 2,121 downloads of 2,120 vids, 500 MB (median 200 KB). Each vid has its own mbl image id.

### 1.3 The copy is a quarter of the scrape

- 878 of the 887 vids on disk are in the logs. 1,242 logged vids have no file.
- About 42 % of the logged vids in every thousand have a file. 538 of 2,120 photos (25 %) are on disk, and 462 of
  the 2,120 thumbnails (22 %). That fits 1,000 files taken from about 4,240 in no name order.
- Assumed: a copy capped at 1,000 files, made before or during the move into `~/stasi/skipaskra`. Where the whole
  set is was not found:
  - the Trash is closed to Claude;
  - the institute share (`/Volumes/einarhj`) has no `stasi/skipaskra/`;
  - the predecessor app reads `~/stasi/skipaskra/jpg/` on the Shiny server, whose home is `/home/haf/einarhj`. Not
    known: whether that home is the share (with the folder gone since) or another disk.

  Ask b.
- 529 of the 531 logged photos on disk have the logged byte count, so they are the downloads. The other two are
  defects:
  - `0078-0001.jpg` is 120 × 90 px, 34.7 KB, against 330,685 bytes logged. It is thumbnail-sized under a photo's
    name.
  - `1722-0001.jpg` holds 1,540,522 of 1,782,641 bytes. It is the download that halted the first run, truncated,
    though it still decodes.
- 9 vids have a file but no log line (8 in 1735-1760, and 3003): a run whose log was not kept.

### 1.4 Metadata: none from mbl, some in the files

- The scraper kept nothing from the page but the image id: no caption, no photographer, no date. The info scrape
  (`data-raw/mbl/vid-*.csv`, 27 fields) has no photo field.
- The EXIF in the photos themselves:
  - a camera date on 410 of the 538 photos. 17 of them are 2000-01-01, a camera's default (a clock never set). The
    other 393 run from 2003 to 2016-09-04: 2 before 2006, 86 in 2006-2010, 256 in 2011-2015 and 49 in 2016.
    (Corrected 2026-10-18 by step 1's build, decision 138: the first draft read the 17 as "before 2000".)
  - camera make and model on 405;
  - a photographer's name (`Artist`) on 82, and a `Copyright` string on 63. Some of these hold an e-mail address and
    a phone number.
- So a photo's date is known for 393 vessels at most. For the rest, the scrape (2022-12-27/28) is a bound. A photo
  can show a vessel before a refit or under an earlier name.

### 1.5 Coverage against the registers

- mbl's own register (`staging/mbl/register_2023-01`, 5,803 vids) holds 886 of the 887 photo vids. Vid 1031 has a
  photo but no info file.
- Samgöngustofa's register on 2022-12-28:

  | status | vids | photo downloaded | photo on disk |
  |---|---|---|---|
  | registered (`Skráð`) | 2,244 | 1,700 | 709 |
  | not registered (`Óskráð`) | 3,364 | 406 | 174 |
  | number allocated (`Úthlutað`) | 69 | 0 | 0 |

- `curated/vessel/vessel.parquet`: 885 of its 7,249 vids have a photo on disk.
- By mbl's type: 226 of 1,579 fishing vessels (`Fiskiskip`), 17 of 138 stern trawlers, 152 of 410 hand-line boats,
  57 of 511 pleasure craft.

## 2. Where the scrape code belongs

The scrape scripts live in `raw/external/skipaskra/R/`, beside the data: the photo scrape, the info scrape, the
thumbnail script and the Samgöngustofa scrape. Decision 105 left the scripts under `raw/external/`, because none of
them was a copy of a script in `dump/`. AGENTS.md says `dump/` is the only home of a dump script. The precedent is
`dump/vessels/faroe.R`, a vessel register scraped page by page, moved out of `reference/` on 2026-09-22.

**Written** (step 2, 2026-10-18; not run):
- `dump/vessels/mbl.R`, one script for both scrapes, since one page request gives the fields and the gallery. It
  writes `raw/external/mbl/<run date>/` through `fd_raw()`: each page as it is (`html/`), every image in its gallery
  (`jpg/`), and two manifests. `pages.csv` holds vid, URL, status and time. `images.csv` holds vid, place in the
  gallery, mbl image id, URL, file, bytes, md5, time, and the item's alt text, title and caption as printed.
- The page is kept whole. The 2022 run kept a CSV of the first four tables with the first comma turned into a point,
  which the adapter has to undo. Parsing is the adapter's job, so `sources/mbl/register.R` would read a new run's
  pages.
- Thumbnails are not a dump step. The app scales images itself.
- A halted run resumes: a vid whose page is saved is skipped. `DRY_RUN = TRUE`, the default, sends no request.
- The raw copies of the 2022 scripts stay beside the files they made, as their record (decision 137, ask f). No
  verbatim copy goes into git: it would be a second copy of that record.
- `dump/vessels/samgongustofa.R` for the Samgöngustofa scrape belongs with it. It is named here, not planned.
- The script is not run without the maintainer's go. It is the newspaper's site (ask b).

## 3. Proposed: the photo index

`sources/mbl/photo.R`, `# Side: preprocessing`. It feeds nothing in the flow, so it builds in the main project, as
target `mbl_photo`.

- **Input:** `raw/external/skipaskra/jpg/` as it is, and the eight logs. The images are not copied or moved: raw is
  never rewritten, and the index points at the files. If the whole set is found (ask b), it lands in the same
  directory after a checksum check, and the index grows.
- **Output:** `staging/mbl/photo.parquet`, with one row per file **and one per logged download with no file**, so
  the gap is visible to a consumer, not only in this plan.
- **Columns:**
  - keys and kind: `vid`, `image_no`, `kind` (`photo`, `thumbnail`, `missing`);
  - the file: `path` (relative to `$FISHYDATA`), `bytes`, `md5`, `width`, `height`;
  - from the logs: `mbl_image_id`, `url`, `log`, `logged_bytes`;
  - `defect`: `truncated` (fewer bytes than logged), `undersized` (a photo 120 px high or less), `no_log`;
  - from the EXIF, as printed: `exif_date`, `exif_camera`, `exif_artist`, `exif_copyright`. They are kept under the
    maintainer's rule for what a public source prints (plan 028 §7) and never shown or published (§4.3);
  - `scraped`: "2022-12-27/2022-12-28";
  - `use`: "internal only (mbl.is)" on every row, so a reader of the table sees the restriction;
  - `best`: one row per vid for a consumer that wants one image. A photo is preferred to a thumbnail, and a row with
    a defect comes last.
- **Not curated.** There is one source and nothing to merge. A curated photo table waits for a second source, and
  none is known.
- **Checks:**
  - rows equal files plus missing downloads;
  - every file decodes;
  - every logged download has a row, on disk or missing;
  - each defect is counted and printed: 1 truncated, 1 undersized, 9 without a log, on today's files.

## 4. Proposed: the vessel overview app

### 4.1 Its shape: the browser does the work, the server only reads

"The main thing is that [it] is responsive" (maintainer). So every interaction runs in the browser, on data the
browser already holds: dragging on the time-speed plot, the time slider, hovering, playing the track. The server is
asked once per vessel, and again only for an earlier year. It is never asked during an interaction. A Shiny input
goes to the server and back on every change, and this shape avoids that.

**The front end** is one page in plain JavaScript (ES modules, no build step). Its libraries are pinned to exact
versions and loaded from jsdelivr (step 4, decision 140): DuckDB-WASM's engine is too large for git. A server with no
internet access would need local copies:
- **The map:** deck.gl, the engine mapdeck wraps, with Mapbox raster tiles as the basemap (§4.6). Pings are drawn as points and
  voyages as paths. The time window filters on the GPU (deck.gl's `DataFilterExtension`), so moving the slider
  redraws without sending data again.
- **The time-speed plot:** uPlot, which works like dygraphs and draws a canvas of 10^5-10^6 points with drag-to-zoom.
  dygraphs itself would do, if the maintainer prefers it. Both are MIT-licensed.
- **The tables** (register, landings, logbook) are plain HTML, and the photo is an image.
- **The data** arrive as parquet, one response per panel, read by DuckDB-WASM in the page (ask h): columns, with no
  JSON to parse.

**The server** is a thin R service in fishycode (`httpuv`, or `plumber`) with fixed endpoints. The browser sends no
SQL, only the vessel and the year:
- the vessel list for the search: vid, name, call sign, MMSI;
- one vessel's register, landings, logbook, photos, and one year of trail.

It runs DuckDB on `curated/` in place, through `R/paths.R`, so the 19 GB trail is not copied. The column allowlist of
§4.5 lives in its queries.

**An alternative to measure: DuckDB in the browser** (DuckDB-WASM, raised by the maintainer, 2026-10-18). The
page would read the parquet files itself over HTTP, and the R service would shrink to a static file server.
- *Personal data.* The first draft rejected it because the browser would reach every column. That is narrower than it
  read. Of the tables the app reads, only two hold kennitala: `vessel_owners_hist` and `vessel_fishery_hist` (from
  the schemas measured for §4.4). The trail, landings, logbook and `vessel.parquet` hold no person's column. So the
  server would serve those directories as they are, and a small extract of the two register tables without the
  kennitala columns. The allowlist becomes a list of directories and one extract.
- *Speed.* DuckDB-WASM reads only the row groups it needs when the server answers HTTP range requests, and the
  trail's files are sorted by vid (§4.4). Without range requests it fetches whole files: a vessel-year would be 12
  monthly files of 18-160 MB.
- *Measured in a prototype on the laptop* (2026-10-18, scratch only; DuckDB-WASM 1.28.0, deck.gl 8.9.35). The page
  read vid 1977's 2025 (147,432 pings, the busiest) and vid 7637's (1,558, the median) both ways. A small R server
  on 127.0.0.1 served the 12 monthly trail files with range requests and logged every byte. Two page loads; times
  are the range over both:

  | | DuckDB-WASM reading the files | the R service (one parquet response) |
  |---|---|---|
  | busiest vessel-year, first read | 0.49-0.99 s; 147 requests, **119 MB** | 0.16-0.31 s; 1.7 MB (42 ms in R) |
  | the same again | 0.08-0.30 s, 0 bytes (DuckDB-WASM keeps what it read) | as first |
  | median vessel-year | 0.15-0.42 s; 48 requests, **31.6 MB** | 0.02-0.03 s; 17 KB |
  | one-time download | DuckDB-WASM 3.6 MB compressed; ready in 2.2 s, 0.2 s from the browser's cache | none |

  - httpuv's own static file server does not answer range requests: it sends the whole file (92 MB for one month).
    So DuckDB-WASM would still need an R handler that serves byte ranges, as the prototype's did.
  - DuckDB-WASM reads whole column chunks of every row group that may hold the vid (about 120,000 rows each), and
    each file's footer: 2.6 MB a file for a vessel with 130 pings a month. On the laptop that is fast. Over a
    network, 31.6 MB for the median vessel and 119 MB for the busiest would take seconds.
  - Drawing is the same in both designs. With 147,432 pings, moving the time filter redrew in a median of 8-25 ms.
    The embedded browser pane holds back frames while it is not looked at, so the first-draw times it gave (0.6 s
    and 23 s) are not measurements.
- *Chosen (ask h, decision 137 amended): both, each where it is strong.* The R service chooses and serves the rows
  (fixed endpoints, the column allowlist, 17 KB to 1.7 MB a vessel-year), and DuckDB-WASM in the page reads that
  response. The prototype's service column did exactly this (`registerFileBuffer`). The page can then run its own SQL on
  the vessel's rows (by voyage, gear or month) with no further request.


**An alternative not proposed: Shiny.** It stays only as a wrapper, if the app must run on the institute's Shiny
Server (ask a). The same page would then be one custom component, with Shiny only delivering the data, as the R
service does. The front end is the same either way.

### 4.2 The linked views

The maintainer's "crosstab" is read here as linked views. All the views share one state: the vessel, the time window,
the time under the cursor, and the selected voyage or trip. Each view reads that state and writes it:
- a drag on the time-speed plot, or the slider, sets the window. The map shows the window's pings and fades the rest;
- hovering on the plot puts a marker on the map at that ping, and hovering on the map puts a cursor line on the plot;
- the slider has a play button that moves the window along the track;
- a click on a landing, trip or station in the tables sets the window to its span (a trip's `T1`-`T2`, a station's
  window) and lights its stations on the map;
- both views colour alike, by `fishing_flow`, gear or phase.

Later, if wanted: a box drawn on the map lights its pings on the plot.

**The map's layers follow the maintainer's `asjo` app** (`ShinyApps/asjo/` on the share, 2026-07). It shows the
vessels at sea now, by gear, with mapdeck, and is given as the model for the map's set-up (maintainer, 2026-10-18).
Here it is applied to one vessel:
- the basemap is drawn once, centred on Iceland. The data layers are then replaced by a fixed layer id, without
  moving the view (`mapdeck_update()`, `update_view = FALSE`);
- the track is a thin path layer (1-5 px), with a highlight on hover and a tooltip. `asjo` draws one line per vessel;
  here there is one per voyage;
- the pings are a scatterplot coloured by speed (capped, palette `inferno`, with a legend). Their radius is set in
  metres and clamped to 2-6 px, and each has a tooltip table;
- the last position is a larger point (clamped to 4-20 px), with vessel, time, speed, heading and position in its
  tooltip.

mapdeck is an R wrapper of deck.gl, and these settings are deck.gl's own (`PathLayer`, `ScatterplotLayer`,
`radiusMinPixels`, `radiusMaxPixels`, `autoHighlight`, layer ids), so the page uses the same set-up directly. The page
adds two things: the time window, which filters every layer, and the link to the plot.

Inside Shiny, the same map would be `asjo`'s pattern: each change sends the layer's data again through
`mapdeck_update()`. For a median vessel-year (1,558 pings in 2025) that is small. For the busiest (147,432) it is
megabytes on every slider move. That is the measured case for keeping the data in the browser.

### 4.3 Where its code lives

`products/vessel_overview/`: `server.R` for the R service and `www/` for the page, its script and the pinned
libraries. AGENTS.md's `products/` holds the consumers of the sweep.
- The code is public, like the rest of the repo. It holds no data, name, image or token.
- It is the repo's first JavaScript. AGENTS.md's coding conventions are R conventions, so the page needs a short
  convention of its own: modules, no build step, pinned libraries.
- It is not a target, and not in `R/`, which `targets` sources wholesale.
- It is not in `docs/`, since `products/publish.R` copies the rendered site to a public web page.
- The alternative is `~/stasi/fishyshiny/`, where the review apps live. It is outside git (ask d).

### 4.4 The panels, their tables, and what "latest" means

| panel | reads | latest | one vessel, measured |
|---|---|---|---|
| photo | `staging/mbl/photo.parquet` | `best`, every image on a click | (not built) |
| register, today | `curated/vessel/vessel.parquet` (7,249 rows, 0.3 MB): name, call sign, MMSI, IMO, length, kW, GT, status | one row per vid | under 0.01 s |
| register, history | `curated/vessel/skipaskra/*_hist`, `vessel_event` (3.6-36 k rows each), keyed on `registration_no`, the vid | the window holding the date shown | under 0.01 s |
| landings | `curated/landing/landings.parquet` (2.2 M) and `catch.parquet` (8.2 M), joined on (`.lid`, `schema`) | `date`, to 2026-10-14 | the last 20 and their catch: 0.01 s |
| logbook | `curated/logbook/trip.parquet` (1.85 M), `station.parquet` (7.3 M), `catch.parquet` (17 M), on (`.tid`, `schema`) and (`.sid`, `schema`); `twin` `duplicate` left out (decision 094) | `T2`, to 2026-10-16 | the last 10 trips, their stations and catch: 0.05 s |
| map and time-speed plot | `curated/ais/trail/year=*/month=*` (585 M rows, 19 GB) | the year of the vid's `max(time)`, with the window on its last month | `max(time)`: 0.13 s; the busiest year: 0.07 s |

Measured on this machine, with the files in the OS cache. A cold start was not measured.

- **The register's history stops on 2023-12-19.** Plan 028 step 6, the live part, is not built. Until it is, the
  panel shows `vessel.parquet` for today and the history to 2023-12-19, each labelled with its date (ask g).
- **The trail is cheap per vessel.** 233 partition files, 2007-2026, one per month. Each file is sorted by `vid`, with
  a median of 22 row groups, so a vid filter reads one or two of them.
- **A year of one vessel fits in the browser.**
  - Pings per vessel-year: in 2025 a median of 1,558, 99 % under 131,415, and at most 147,432 (vid 1977). 2024 is
    alike (median 2,120, max 134,208). The most in any year is 342,826 (vid 2800, 2014).
  - The busiest year of 2025 reads in 0.07 s. Its time, position, speed, fishing flag, voyage and stay are 4.3 MB as
    plain columns, and 1.7 MB as zstd-compressed parquet.
  - A vessel-month since 2024: median 479 pings, max 20,637.
  - The months 2026-07 to 2026-10 hold 0.55-0.98 M pings, against 2.4-5.1 M in the months before, with as many
    vessels. The latest trail is the sparsest. The cause was not measured.
- **Names for codes.** Gear and port come from `curated/reference/gear` and `port`. There is no species reference
  (TODO 10), so species show as codes until it is built.
- **A vessel is chosen** by vid, name, call sign or MMSI. Names are for reading only; the app keys on `vid`.
- **Beyond `asjo`'s layers (§4.2):** the latest trips' logbook stations, and the vessel's stays in port.

### 4.5 Persons and the photos: what the app shows

Decided here; the maintainer can overrule (ask e):
- **Never shown:** kennitala (`vessel_owners_hist.national_identity_no`, `vessel_fishery_hist.identity_no`),
  addresses, postal codes, phone numbers, web pages, and the EXIF copyright strings. The service's queries select
  named columns (an allowlist), so these columns never leave the server. A test checks the service's column lists
  against a list of the personal columns.
- **Shown:** the owner's and operator's names as the register prints them; the photographer (`exif_artist`) as a
  credit, with "mbl.is, 200 mílur" as the source.
- **The photos are a newspaper's images, for internal use only.** The service sends them from `$FISHYDATA`. They
  never go into the repo, `docs/`, `fishyweb` or a release. No screenshot showing a photo goes into a plan, decision
  or docs page. The app is not reachable from outside MFRI.
- **Nothing leaves `$FISHYDATA`** (plan 001 §3). The app reads and writes nothing there.

### 4.6 The basemap and the Mapbox token

deck.gl draws the data, and the basemap under it: Mapbox's light style as raster tiles, through deck.gl's tile layer.
- A Mapbox style needs a token, and the browser receives it. It is a public `pk.` token, built for that.
- The token is never in the repo (plan 001 §4: the committed one was revoked on 2026-10-16). The service reads
  `MAPBOX_TOKEN` from the environment and hands it to the page when it loads.
- `MAPBOX_TOKEN` is set in both the project's `.Renviron` and `~/.Renviron`. R started in the repo reads the
  project's `.Renviron`. Both hold the same `pk.` token, and it is not the one in fishycode's history, revoked on
  2026-10-16 (compared without printing either).
- Whether that value is the token made after 2026-10-16, and whether it is restricted to the app's URL, is the
  maintainer's to say. A basemap that needs no token is the alternative (ask c).

### 4.7 Where it runs

The maintainer's call (ask a):
- **On the laptop:** the R service on 127.0.0.1, with the browser on the same machine. This is the case measured here.
- **On an institute server:** the R service there, with the curated tables it reads (about 19 GB of trail, 0.3 GB of
  tables, the photos), and access limited to MFRI.
- **On the institute's Shiny Server**, which is in use (`ShinyApps/` on the share): it hosts Shiny apps only, so there
  the page runs inside the Shiny wrapper of §4.1.

## 5. Steps

1. **The photo index**: `sources/mbl/photo.R`, target `mbl_photo` in `_targets.R`, built by name
   (`tar_make_isolated(names = "mbl_photo")`) on the maintainer's go.
   **Check:** §3's checks pass; the counts in §1 are reproduced from the table.
2. **The dump script**: `dump/vessels/mbl.R`, written 2026-10-18, not run.
   **Checked offline:** it parses; a dry run sends no request and writes nothing; with the network stubbed and a
   synthetic page shaped like the 2022 selectors, the loop writes the page, both images and both manifests, records a
   failed page with its HTTP status, and a second run tries only the failed page.
   **Piloted 2026-10-18** on vids 78, 1977, 2184, 2757 and 9810 (decision 141): every page answered HTTP 403 with a
   Cloudflare bot check, so no page was read. The check is not passed. The script now records the status and stops
   after 10 such failures in a row. A new scrape of the register is closed while the check stands.
3. **The R service**: `products/vessel_overview/` (`api.R`, `server.R`, `check.R`), built 2026-10-18 (decision 139).
   **Checked** (`check.R`): no allowlisted column is personal; 43 answers for vids 2757, 3739 and 2652, each with
   exactly its allowlisted columns, all under 0.4 s; a photo served byte for byte; eight requests refused.
4. **The page**: `products/vessel_overview/www/`, the linked views of §4.2, built 2026-10-18 (decision 140).
   **Checked:** it opens for vids 2652, 1977, 2757 and 3739, and each panel shows its latest rows or says it is
   empty; 40 window moves on vid 1977's 2025 (147,432 pings) redrew in 7-10 ms each, against 50 ms. Not checked: the
   hover link, Play, and the time to load a vessel.
5. **The whole photo set.** The image host still serves the 2022 images by id, with no bot check (decision 141):
   the 1,589 missing photos (about 370 MB) can most likely be fetched by their logged URLs into
   `raw/external/skipaskra/jpg/`, under their 2022 names, each byte count checked against the log. Only with the
   maintainer's go (ask b). **Check:** the index has no `missing` row, or each one is explained.

## 6. Asks

**Answered 2026-10-18 (decision 137), each with the proposed option:**
- a: the laptop first;
- b: the maintainer looks for the whole set, and the index is built now with the rest `missing`. Reopened after the
  pilot (decision 141): the missing photos can be fetched by their logged URLs, on a go;
- c: the `.Renviron` token;
- d: `products/vessel_overview/`;
- e: names shown, never kennitala, address or phone;
- f: the raw scripts kept as the record;
- g: today and the history to 2023-12-19, labelled.

The asks as they were put:

a. **Where does the app run:** the laptop only, an institute server running the R service, or the institute's Shiny
   Server, which would need the Shiny wrapper (§4.7)?

b. **The whole photo set.** The scrape logged 2,120 photos (500 MB), and 1,000 files came in. Is the original `jpg/`
   on the Linux machine that ran the scrape (R 4.2.2, 2022-12-27/28), or in the `skipaskra` folder in the Trash? If
   neither, is a new scrape of mbl wanted (every image per vessel, with captions and credits if the page prints
   them), and is it acceptable to scrape the newspaper's site again for internal use?
   **Revised 2026-10-18 after the pilot (decision 141):** a new scrape is closed (a bot check). Fetch the 1,589
   missing photos by their logged URLs from the image host, which has no check (about 1,600 requests, 370 MB), or ask
   Morgunblaðið first, or keep the 1,000? Open.

c. **The basemap:** the `.Renviron` token is not the revoked one. Is it the token made after 2026-10-16, for this use,
   and should it be restricted to the app's URL? Or should the basemap be one that needs no token?

d. **Where the app's code lives:** `products/vessel_overview/` in fishycode, the repo's first JavaScript (proposed),
   or `~/stasi/fishyshiny/`?

e. **Owner and operator names in the app:** shown (proposed) or not? Kennitala, addresses and phone numbers are never
   shown.

f. **The raw copies of the 2022 scrape scripts:** kept beside the files as their record (proposed), or sent to the
   Trash once `dump/vessels/mbl.R` holds them, as decision 105 did?

g. **The register panel until plan 028 step 6:** `vessel.parquet` for today and the history to 2023-12-19, each
   labelled (proposed), or wait for step 6?

h. **The R service, DuckDB in the browser, or both** (§4.1, measured 2026-10-18)? Recommended: both, the R service
   serving the vessel's rows and DuckDB-WASM in the page reading them. **Answered 2026-10-18: both** (decision 137,
   amended).
