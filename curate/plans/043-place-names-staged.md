# 043 — Place names of fishing grounds: the ornefni data staged, source by source

**status:** executed — the data copied into raw 2026-10-24 (decision 221), §3.4 added the same day from a preliminary
check of the Trackwell names (levels, lanes, the seabed), and the thirteen tables staged that afternoon (decision 222):
asks b, c, d, e and g taken as recommended on the maintainer's "finish the staging", h answered "proceed to curation"
(plan 044); a and f open (TODO 144) · **2026-10-24** · **see:** decision 221,
`$FISHYDATA/raw/external/ornefni/README-provenance.txt`, plan 020 §6 and
`$FISHYDATA/archive/2026-10-logbook-notes/README.md` §3.6 (the notes' ground names), `raw/oracle/orri/ornefni.parquet`,
`raw/oracle/ops_sigfus/ornefni.parquet`, `sources/hreidar/vessel_year.R` (the pattern)

Drafted with AI assistance (Claude) on 2026-10-24, at the maintainer's request: "the idea is then to at minimum stage
these datasets". The measurements and the design are Claude's, and a person has not yet checked them. The data hold
personal data: a finder's id, informants and skippers named in articles, and a person's own plotter marks. So only
counts are written here, and no row.

**Measured:** every count in §2 and §3, read from the files in `raw/external/ornefni/` and, for the Trackwell match,
`curated/logbook/station_window` as built on 2026-10-23 (decision 218), and for §3.4 the effort map's base grid
(decision 220) and GEBCO 2026. **Assumed:**
- that the sjókort lines are label lines digitised from nautical charts (nothing in the files says so);
- that the plotter marks' names that are numbers are depths or catch marks, not names;
- that the 2021 TimeZero export's names are the same marks as the 2022 GPX names that lost their letters;
- that bottom-trawl effort since 2023 shows the lanes of 2008-2022, outside the areas closed since (§3.4).

## 1. The aim

Each of the ornefni repo's datasets staged as it is, one table per dataset, under `staging/ornefni/`. Staged means
source-shaped: every row and every column, the text as given beside any cleaned form, positions in WGS 84, and each
position's basis. Not in this plan:
- a merged gazetteer in `curated/`;
- the Trackwell names on the logbook hauls (the maintainer, 2026-10-24: not for now);
- the notes' ground names (plan 020 §6).

## 2. What there is

| Source | Staged from | Rows | Names | Position | Time |
|---|---|---|---|---|---|
| Trackwell's logbook app | `trackwell_2022-11-07.csv` | 484,734 hauls, 189 vessels | 1,372 | haul start and end, recorded | 2003-2022 |
| Trackwell's picklist summary | `VeiðisvæðiSkipstjóra….xlsx` | 1,096 | 1,096 | min, max, mean of hauls | — |
| a person's plotter (TimeZero) | 4 GPX files, `Nöfn/UserObjects.json` | 519,009 waypoints, 579 objects; 1.87 M track points | 1,571, 4,412, 570 and 196 distinct by file, many of them numbers | recorded | 1984-2022 |
| sjókort (MFRI GIS, 2015) | `ornefni.shp` | 272 lines | 240 | digitised | — |
| LMÍ IS_50V (2022) | `ornefni_lmi.gpkg`, `lmi_ornefni.csv` | 5,821 polygons; 538 sea names | 4,479 | digitised | — |
| tag recaptures (fiskmerki) | `ornefni_endurheimtur.*`, `tag_ornefni*` | 20,317; 2,439 words | 4,874 texts | recapture position | — |
| fiskislóð hulls | `fiskislod_polygons.gpkg` | 566 polygons | 566 | derived (hull + 100 m) | — |
| the name dictionary | `dictonary.xlsx` | 9,285 | 876 standard names | none | — |
| a hand-drawn polygon | `ornefni_qgis-handdrawn.gpkg` | 1 | 1 | drawn | — |
| articles (Fiskifréttir) | `data-md/*.md` | 151 records | 150 | none (text only) | — |
| the Skjálfandi report (2004) | `Fiskimið.pdf` | about 271 grounds | ~271 | landmark bearings; 4 coordinates | — |
| ÍSOR's names (2008) | 3 `GRG-ISOR-*.pdf` | 124 entries (57, 37, 30), text + map | 117 marked as coined (◊) | map only | — |
| maps and photos | Vestmannaeyjar PDF, `images/` | 4 images, 1 map PDF | on the image | map only | — |

The Oracle gazetteers are already in the dump. They are `orri.ornefni` (2,509 rows) and `ops$sigfus.ornefni` (2,881),
each with a name, a description, the region and a statistical square, and a position on about 220 rows. Beside them
are `afli.skikar` (1,211) and `afli.afli_skikar` (1,470), the coarse grounds by square, and `brei_nofn` (428, in
Breiðafjörður). Not dumped: `fiskar.ornefni` (2,880, a third copy) and `fiskmerki.endurheimtur`, the source of
`fiskmerki/`.

## 3. What shapes the staging

1. **Trackwell.**
   - The per-haul file is Trackwell's own record of logbook hauls MFRI also holds: 446,790 rows (92.2 %) match a
     curated haul on vid and start minute, and the tow's duration agrees on every match.
   - The name is the one value Oracle never had.
   - The 2022-11-03 file is the same hauls without vid, time or depth: 484,289 of its 484,306 named rows are in the
     11-07 file, which adds 445. So only the 11-07 file is staged, and the 11-03 file stays in raw.
   - The picklist's default, "Ekkert valið" (254,662 hauls in the summary), is absent from the per-haul file. Those
     hauls carry no name, so the table does not say where the app was used without a name.
   - **The names are noisy, likely by "use last value"** (the maintainer, 2026-10-24: skippers probably forget to
     switch to a new name when they enter a new area). Claude's first test, read-only, not checked by a person:
     - Spread: a haul's start lies a median 13 km from that vessel's centre (median position) for the name; 34 % lie
       more than 20 km away, 10.5 % more than 50 km and 1 % more than 400 km. Large grounds account for part of it.
     - Switching: a vessel changes name within 48 h of the last haul 106,369 times. In runs of 6 hauls or more, the
       last haul before a switch lies nearer the next name's centre than its own on 15.8 %. The rate falls to the
       mid-run 7.3 % over about four hauls (11.3, 9.4, 8.7, 7.5 %). At the start of a run only the first haul is
       raised (12.6 %, then 6.6-7.0 %). So late switches outnumber early ones, by about 0.16 hauls per switch
       against 0.05.

     Staging keeps the name as given. A reassignment would be a correction in `curate/`, and is not in this plan. A
     name's centre or area drawn from these hauls must be robust to it (a median, the run's tail left out).
2. **The plotter marks.**
   - The three large GPX exports lost the Icelandic letters: "?" stands in their place in 867 names, and no name
     holds ð, á or þ. The small 2022-10-18 GPX has 44 names with "?" and 14 with the letters.
   - Unescaped `@`, `&` and `;` make some files invalid XML. The repo once replaced them with X; staging should
     escape them instead, so the text survives.
   - The 2021 TimeZero export keeps the letters (172 names), but only for its 446 named objects, and its geometry is
     base64 binary.
   - Waypoint times run 1984-2033 and track times 1989-2040: the plotter's clock, kept as given and flagged.
3. **Hand-made files.** `dictonary.xlsx`, `ornefni_endurheimtur.xlsx`, `tag_ornefni.xlsx`, trial2's `fiskislod`, the
   hand-drawn polygon and `data-md/` are a person's reading of the other sources. Each is staged as a table of its
   own, keyed to the rows it reads (`.rid`, the recapture id, the word), never merged into its source.
4. **What a Trackwell name covers.** The maintainer, 2026-10-24: a name can be a broad area that holds finer names, and
   many trawl names belong to the commonest tow path, which the effort map shows where effort is densest. Claude's
   preliminary check (read-only, not checked by a person; `$FISHYDATA/archive/2026-10-ornefni/`, scripts 01-04):
   - **Mostly trawl.** Through the match to the logbook, the hauls are 76.5 % bottom trawl (OTB, gear 6), 5.7 %
     other trawls, 4.8 % Danish seine and 3.9 % pelagic trawl; 7.8 % have no match.
   - **Names nest.** Of the 520 bottom-trawl names with 20 tows or more, 110 (21 %) lie inside a broader name, with
     70 % of their tows in its densest cells and under half its spread; 10 of them are two levels deep.
     Reykjafjarðaráll holds Tungan and Kolkugrunn, Grímseyjarsvæðið holds Grovensbanki and Austara- and Vestaragrunn,
     and Skerjadýpi holds Litli banki. A fine name is mostly one vessel's (a median of 1). In 53 of the 110 pairs,
     every vessel that uses the fine name also uses the broad one, so a skipper often names at two scales.
   - **Spelling variants.** One place is spelled several ways, by different vessels or the same one: Litli banki 7
     ways, Grovensbanki 5, Tungan 4 (Tungann, Túngan, "Tungan Reykjafj.áll"). "FROM SHIP" is a placeholder (6,408
     hauls).
   - **Lanes.** Effort since 2023, after the file ends, so the named tows are not in it, peaks under the named tows.
     Across 420 names with 30 tows or more, the median falls from 1 on the tow line to 0.64 at 3 km to the side and
     0.45 at 6 km.
     - 131 names hold over twice the effort on the line as 3 km away, and 45 over four times.
     - 35 names keep one tow axis, and those are narrow (3.1 km across) and sit on the sharpest ridges.
     - Most names are areas: a median 6.2 km across, with mixed tow directions.
     - Effort since 2023 is bounded by areas closed since, so a lane closed since shows none: 6 names have no effort
       on the line.
   - **One area seen** (`figures/reykjafjardarall.png`): Reykjafjarðaráll is a trough crossed in every direction.
     Tungan, Tungann and Kolkugrunn are one narrow lane along its tongue, on the densest effort. Sporðagrunn is a lane
     along an edge, Skagagrunn an area crossed in all directions.

   - **The seabed** (GEBCO 2026, `raw/aux/`, 15″; the maintainer, 2026-10-24: it may help delineate a name's area):
     - GEBCO serves at tow scale: Trackwell's own start depth (metres) is a median 0.993 of GEBCO's, and within 20 %
       on 79 % of 353,316 tows.
     - A name's tows span a median 59 m of depth (interquartile range), so names roughly follow depth bands.
     - By the terrain word in the name (bottom trawl, names with 30 tows or more), measured against the mean seabed
       within about 10 km:
       - bank names (-grunn, -banki, -flak; 79) lie higher on 96 %;
       - ridges (-hryggur; 21) on 86 %, and horns (18) on 94 %;
       - edges (kantur, brún; 37) are the steepest (1.14° against 0.7° for all tows) and span the most depth
         (96 m);
       - deeps (-dýpi, -áll, -dalur; 71) lie deeper (264 m against banks' 197 m) but not lower than their
         surroundings, at 10 km or at 30 km: trawlers likely tow a trough's flanks, not its floor;
       - hills (hóll, klakkur, boði; 16) show nothing at GEBCO's 460 m cells, so small features need finer
         bathymetry.

   What follows for the step after staging (not part of this plan):
   - **Levels.** A gazetteer with area names and the lane or patch names within them. Each child knows its parent,
     found by footprint containment, and the levels stay apart rather than merged into one polygon per name.
   - **Footprints from the effort map.** A name's footprint is drawn from the densest effort under its tows, rather
     than from the tows' hull. That makes it robust to late switches, whose tows fall on a neighbour's ridge.
   - **The seabed as a third layer.** An area name's footprint follows the feature its word names: a bank's rise, an
     edge's slope, a depth band. Lane names follow the effort, and the tows place both. GEBCO serves for banks,
     ridges and edges; deeps need the trough's own outline, and hills need finer bathymetry.
   - **Variants grouped** under one key (case, hyphens, spaces, doubled letters, accents), each spelling kept.
   - **Gear.** The names are bottom-trawl names first; the other gears' names are checked apart. The gear comes from
     the logbook match, which only the gazetteer step makes. The names still go on no logbook haul.
5. **Documents.** Two PDFs have a text layer that can be read by script:
   - the Skjálfandi table: number, name, description or bearings, coordinates where given, informant;
   - ÍSOR's entries: name, description, English name, and ◊ for a name the author coined.

   The maps (ÍSOR's three, Vestmannaeyjar, the wall-map photo, Blik 1969) hold their names on the image. Turning
   those into positions is digitising by hand, not staging.

## 4. The design (proposal)

One adapter folder, `sources/ornefni/`, with one script per staged table. Each script follows the
`sources/hreidar/vessel_year.R` pattern:
- a head stating its side, input and output;
- source-shaped, under English names, the original text kept (`name_raw` beside a trimmed `name`);
- checked row counts against the README;
- written with `write_parquet()` to `fd_staging("ornefni", …)`.

Positions are `lon`/`lat` for points. Lines and polygons are WKB with `fd.crs` (the `write_curated()` convention).
Every table carries `source` and two position columns:
- `position_basis`, in AGENTS.md's vocabulary: `recorded` (as the source gives it, a chart's line included),
  `derived` (a mean of hauls, a hull) or `none`;
- `position_kind`: `point`, `line`, `polygon`, `track` (a tow's two ends), `drawn` (by hand) or `text` (described
  only, the description kept in `position_text`, such as landmark bearings).

| Script → table | From | Notes |
|---|---|---|
| `trackwell_haul.R` → `trackwell_haul.parquet` | 11-07 CSV | vid, t1, t2, both ends, z in metres; no link to the logbook |
| `trackwell_area.R` → `trackwell_area.parquet` | the xlsx | "Ekkert valið" kept and flagged |
| `plotter_mark.R` → `plotter_mark.parquet` | 4 GPX + `UserObjects.json` | one row per mark per file; `text_lost` where "?" replaced a letter; `name_is_number` |
| `plotter_track.R` → `plotter_track.parquet` | 3 GPX | only if ask b says so |
| `chart_name.R` → `chart_name.parquet` | sjókort lines | |
| `lmi_name.R` → `lmi_name.parquet` | the 2022 polygons, the 538 attribute rows | |
| `recapture_place.R` → `recapture_place.parquet` | `ornefni_endurheimtur.csv` | the finder's text, position, `finnandi_id`, keyed on `.rid` and `id` |
| `recapture_reading.R` → `recapture_reading.parquet` | `ornefni_endurheimtur.xlsx`, trial2's xlsx | the hand columns (`ornefni`, `ornefni2`, `nafnberi`, `comment`, `fiskislod`) keyed on `.rid` and `id`, not merged into the source |
| `name_dictionary.R` → `name_dictionary.parquet`, `tag_word.parquet` | `dictonary.xlsx`, `tag_ornefni.xlsx` | the hand mappings as given |
| `fiskislod.R` → `fiskislod.parquet` | the 566 hulls | basis `derived`, kind `polygon` |
| `drawn_area.R` → `drawn_area.parquet` | the hand-drawn polygon | basis `recorded`, kind `drawn` |
| `article_record.R` → `article_record.parquet` | `data-md/` | one row per file, a column per section, the text as written |
| `document_name.R` → `document_name.parquet` | the Skjálfandi and ÍSOR text | one row per entry; the page kept |

Each staged table counts every source row in one outcome: staged, or dropped with the reason (only the README's
listed exclusions). The plotter marks also count names by `text_lost` and `name_is_number`.

## 5. Steps

1. Done (decision 221): the data in raw with checksums and its provenance README. The PDFs moved. Open: the one-home
   question for the rest of the originals (ask a).
2. The tabular sources: Trackwell (both tables), sjókort, LMÍ, the recapture set, the dictionaries, the fiskislóð
   hulls, the drawn polygon, the articles.
3. The plotter marks, after ask c.
4. The documents' text, Skjálfandi and ÍSOR.
5. A decision record, the targets wired in, `check_bookkeeping()`; TODO 143 closed.

## 6. Asks

As taken on 2026-10-24 (decision 222): b staged; c flagged, the TimeZero geometry decoded; d not digitised; e
preprocessing; g `staging/ornefni/`; h proceed (plan 044). Open: a and f (TODO 144).


- **a.** The originals in `~/stasi/ornefni`: move them under the one-home rule (Trash and symlinks), or leave the repo
  as it is? `data-md/` and the hand-edited xlsx are working files. Should their home be the ornefni repo's git
  (committed there), with raw holding dated snapshots, so nothing under `$FISHYDATA` is edited by hand?
- **b.** The plotter's tracks (1.87 M points, 1989-2022): stage them, or leave them in raw?
- **c.** The lost letters: ask the provider for TimeZero exports (`.tzx`) of the 2022 parts? Or stage the GPX names
  as they are, flagged, and repair them later from the 2021 export and other name lists?
- **d.** The maps (ÍSOR's three, Vestmannaeyjar, the wall-map photo, Blik 1969): digitise later, or keep them as
  documents only?
- **e.** The side: `preprocessing` in the main project, or `once`, built once and frozen? The sources are fixed
  deliveries, but staging is cheap.
- **f.** Dump `fiskar.ornefni` and `fiskmerki.endurheimtur` (the recapture text at its source) as single tables?
  Their schemas are 211 and 53 objects (103 M and 20 M rows).
- **g.** The name of the staging folder, `staging/ornefni/`, and of the source in the record: "ornefni" or "place
  names"?
- **h.** After staging: a plan of its own for the gazetteer (§3.4: levels, variants, footprints from the effort map
  and the seabed), or not yet?
