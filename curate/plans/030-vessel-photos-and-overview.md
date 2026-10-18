# 030 — Vessel photos from mbl into the flow, and an internal vessel overview app

**status:** proposal — measured 2026-10-18 (read-only), nothing built; asks a-g open (TODO 85)
· **2026-10-18** · **see:** plan 028 (§3.6, §7), plan 001 (§3, §4), decisions 049, 105, 130 and 132,
`sources/mbl/register.R`, `dump/vessels/faroe.R`, `products/publish.R`, `~/stasi/fishyshiny/` (outside this repo)

Drafted with AI assistance (Claude) on 2026-10-18, at the maintainer's request, relayed by the plan 028 session. The
numbers below were measured by Claude (AI). A person has not yet checked them.

**Why** (maintainer, 2026-10-18). An internal Shiny overview of one vessel at a time:
- its photo;
- the latest register entry;
- the latest landings;
- the latest logbook trips and stations;
- a mapdeck map of its latest AIS trail.

The photos must first enter the flow as an index a consumer can join on `vid`. The app's uses (checking a vessel
while reviewing the key, the register history or a trip) are named here, not measured.

**Measured** (read-only, 2026-10-18, on the build of 2026-10-17):
- every file in `raw/external/skipaskra/jpg/`: size, pixel size, EXIF (R's `magick`);
- the three scripts and eight logs that made them, in `raw/external/skipaskra/`;
- photo coverage against `staging/mbl/register_2023-01`, `staging/samgongustofa/register_2022-12-28` and
  `curated/vessel/vessel.parquet`;
- each panel's table: its schema, how recent it is, and the time to read one vessel's latest rows through DuckDB, for
  three vessels: vid 2757 (most pings in 2026-09), 3739 (median), 2652 (silent since 2024).

Scripts and output are in scratch only. Nothing was written under `$FISHYDATA`.

**Assumed:**
- the 1,000 files are a capped copy of a set about four times larger (§1.3);
- timings on a cold cache, or on another machine, are of the same order as those measured;
- mapdeck draws a vessel-month of trail without thinning.

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
  set is was not checked. The Trash is closed to Claude, and `/Volumes/einarhj` is not mounted on this host
  (HAFRO-EINARHJ-2). Ask b.
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
  - a camera date on 410 of the 538 photos. 17 are before 2000 (most likely camera clocks never set); 86 fall in
    2006-2010, 256 in 2011-2015, 49 in 2016-2020, and none later;
  - camera make and model on 405;
  - a photographer's name (`Artist`) on 82, and a `Copyright` string on 63. Some of these hold an e-mail address and
    a phone number.
- So a photo's date is known for 410 vessels at most. For the rest, the scrape (2022-12-27/28) is a bound. A photo
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

**Proposed** (nothing moved):
- `dump/vessels/mbl.R`, one script for both scrapes, since one page request gives the fields and the gallery. It
  writes `raw/external/mbl/<date>/` through `fd_raw()`, with a log per run and a manifest: vid, image place, mbl image
  id, URL, caption and credit if the page prints them, bytes, md5, time.
- Every image in a vessel's gallery is taken, not only the first.
- Thumbnails are not a dump step. The app scales images itself.
- The script's first commit holds the two 2022 scripts verbatim, so git records what made the files on disk.
- The raw copies of the scripts stay beside the 2022 files as their record, read-only, or go to the Trash as in
  decision 105 (ask f).
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

### 4.1 Where its code lives

`products/vessel_overview/app.R`. AGENTS.md's `products/` holds the consumers of the sweep. The code is public, like
the rest of the repo; it holds no data, names, image or token.
- It is not a target, and not in `R/`, which `targets` sources wholesale.
- It is not in `docs/`, since `products/publish.R` copies the rendered site to a public web page.
- The alternative is `~/stasi/fishyshiny/`, where the review apps live. It is outside git (ask d).

### 4.2 The panels, their tables, and what "latest" means

| panel | reads | latest | one vessel, measured |
|---|---|---|---|
| photo | `staging/mbl/photo.parquet` | `best`, every image on a click | (not built) |
| register, today | `curated/vessel/vessel.parquet` (7,249 rows, 0.3 MB): name, call sign, MMSI, IMO, length, kW, GT, status | one row per vid | under 0.01 s |
| register, history | `curated/vessel/skipaskra/*_hist`, `vessel_event` (3.6-36 k rows each), keyed on `registration_no`, the vid | the window holding the date shown | under 0.01 s |
| landings | `curated/landing/landings.parquet` (2.2 M) and `catch.parquet` (8.2 M), joined on (`.lid`, `schema`) | `date`, to 2026-10-14 | the last 20 and their catch: 0.01 s |
| logbook | `curated/logbook/trip.parquet` (1.85 M), `station.parquet` (7.3 M), `catch.parquet` (17 M), on (`.tid`, `schema`) and (`.sid`, `schema`); `twin` `duplicate` left out (decision 094) | `T2`, to 2026-10-16 | the last 10 trips, their stations and catch: 0.05 s |
| map | `curated/ais/trail/year=*/month=*` (585 M rows, 19 GB) | `max(time)` for the vid over all partitions, then that month | `max(time)`: 0.13 s; the month: under 0.01 s |

Measured on this laptop, with the files in the OS cache. A cold start was not measured.

- **The register's history stops on 2023-12-19.** Plan 028 step 6, the live part, is not built. Until it is, the
  panel shows `vessel.parquet` for today and the history to 2023-12-19, each labelled with its date (ask g).
- **The trail is cheap per vessel.** 233 partition files, 2007-2026, one per month. Each file is sorted by `vid`, with
  a median of 22 row groups, so a vid filter reads one or two of them.
  - A vessel-month since 2024: median 479 pings, 99 % under 16,149, max 20,637. Over all years the max is 47,738
    (vid 2800, 2013-06).
  - The months 2026-07 to 2026-10 hold 0.55-0.98 M pings, against 2.4-5.1 M in the months before, with as many
    vessels. The latest trail is the sparsest. The cause was not measured.
- **Names for codes.** Gear and port come from `curated/reference/gear` and `port`. There is no species reference
  (TODO 10), so species show as codes until it is built.
- **A vessel is chosen** by vid, name, call sign or MMSI. Names are for reading only; the app keys on `vid`.
- **The map:** the latest month's track as a path per voyage, coloured by `fishing_flow`, with time, speed and gear
  on hover; the latest trips' logbook stations as a second layer; the vessel's stays in port.

### 4.3 Persons and the photos: what the app shows

Decided here; the maintainer can overrule (ask e):
- **Never shown:** kennitala (`vessel_owners_hist.national_identity_no`, `vessel_fishery_hist.identity_no`),
  addresses, postal codes, phone numbers, web pages, and the EXIF copyright strings. The app's readers select named
  columns (an allowlist), so these columns never enter the R session. A test checks the app's column lists against
  a list of the personal columns.
- **Shown:** the owner's and operator's names as the register prints them; the photographer (`exif_artist`) as a
  credit, with "mbl.is, 200 mílur" as the source.
- **The photos are a newspaper's images, for internal use only.** They never go into the repo, `docs/`, `fishyweb`
  or a release. No screenshot showing a photo goes into a plan, decision or docs page. The app is not reachable from
  outside MFRI.
- **Nothing leaves `$FISHYDATA`** (plan 001 §3). The app reads and writes nothing there.

### 4.4 The Mapbox token

mapdeck needs a Mapbox token, and its basemap sends the token to the browser.
- The token is never in the repo (plan 001 §4: the committed one was revoked on 2026-10-16).
- `MAPBOX_TOKEN` is set in both the project's `.Renviron` and `~/.Renviron` (names checked, not values). R started in
  the repo reads the project's `.Renviron`.
- Whether that value is the token made after 2026-10-16, and whether it is restricted to the app's URL, is the
  maintainer's to say (ask c).
- If there is no token, leaflet needs none, as `~/stasi/fishyshiny/` does.

### 4.5 Where it runs

The maintainer's call (ask a):
- **On the laptop** (`shiny::runApp()`, 127.0.0.1): the case measured here.
- **On an MFRI Shiny server:** the tables the app reads (about 19 GB of trail, 0.3 GB of tables, the photos) would
  have to be on that server, and access limited to MFRI.

## 5. Steps

1. **The photo index**: `sources/mbl/photo.R`, target `mbl_photo` in `_targets.R`, built by name
   (`tar_make_isolated(names = "mbl_photo")`) on the maintainer's go.
   **Check:** §3's checks pass; the counts in §1 are reproduced from the table.
2. **The dump script**: `dump/vessels/mbl.R`, written from the two 2022 scripts, not run.
   **Check:** for five vids, the URLs and file names the script would use match the 2022 logs', checked without
   sending a request.
3. **The app**: `products/vessel_overview/app.R`, with the column allowlist and its test.
   **Check:**
   - it opens for vids 2757, 3739 and 2652, and each panel shows its latest rows with their date;
   - a vessel with no photo, no logbook trip (3739) or no trail since 2024 (2652) shows an empty panel that says so;
   - the personal-column test passes.
4. **The whole photo set**, if ask b finds it or allows a new scrape. **Check:** the index has no `missing` row, or
   each one is explained.

## 6. Asks

a. **Where does the app run:** the laptop only, or an MFRI Shiny server (which)?

b. **The whole photo set.** The scrape logged 2,120 photos (500 MB), and 1,000 files came in. Is the original `jpg/`
   on the Linux machine that ran the scrape (R 4.2.2, 2022-12-27/28), or in the `skipaskra` folder in the Trash? If
   neither, is a new scrape of mbl wanted (every image per vessel, with captions and credits if the page prints
   them), and is it acceptable to scrape the newspaper's site again for internal use?

c. **The Mapbox token:** is the project `.Renviron`'s `MAPBOX_TOKEN` the token made after 2026-10-16, and is it
   restricted to the app's URL? Or should the map use leaflet, which needs no token?

d. **Where the app's code lives:** `products/vessel_overview/` in fishycode (proposed), or `~/stasi/fishyshiny/`?

e. **Owner and operator names in the app:** shown (proposed) or not? Kennitala, addresses and phone numbers are never
   shown.

f. **The raw copies of the 2022 scrape scripts:** kept beside the files as their record (proposed), or sent to the
   Trash once `dump/vessels/mbl.R` holds them, as decision 105 did?

g. **The register panel until plan 028 step 6:** `vessel.parquet` for today and the history to 2023-12-19, each
   labelled (proposed), or wait for step 6?
