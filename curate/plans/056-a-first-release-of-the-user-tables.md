# 056 — The user tables as a data repository: frozen releases on an MFRI server, the first for a colleague, with their README, metadata and the historical aggregates

**status:** proposal — written 2026-10-31 at the maintainer's request, restructured the same day around a conventional
data repository; measured read-only the same day; nothing built; asks a-h (§9) answered the same day, each as
recommended after a check of the data; the share's path still to be named (TODO 175) · **2026-10-31** ·
**see:** decision 219 (v0), decisions 240, 257, 261 and 266, plans 039, 041 and 055, TODOs 15, 123, 136, 140, 171 and
172, `products/user_tables.R`, `docs/data-dict.yaml`, `$FISHYDATA/archive/2026-10-30-records-and-statistics/`,
`$FISHYDATA/archive/2026-10-30-nephrops-shrimp-factors/`

Drafted with AI assistance (Claude) on 2026-10-31. These are the maintainer's: the aim, the first user and the
server; the target chain; the README as a `.qmd` with the approach and its differences from afli; the metadata YAML;
the names without `_part`; the logger in the logbook; the versioning as a question to think through; fishycode's and
ramb's commits in the release; and the form, a conventional repository rather than an R package. The design and
the numbers are Claude's. No person has checked the numbers.

**Measured** (by Claude, read-only, 2026-10-31): v0's tables as rerun after decision 265's rebuild, their rows,
columns and sizes; their Nephrops and shrimp rows by source and decade; the e-logbook's tow times; `sensor_gps` read
through v0; the historical tables' rows and columns; and the data behind each ask's recommendation (§9). The scripts
are in the session's scratchpad, not kept, and the numbers are measured again when a release is built.
**Assumed:**
- that the colleague reads parquet from R or Python, and has read access to a central MFRI server;
- that the server holds a plain directory tree, readable over the network share;
- that the historical tables' units are those decision 266 and plan 041 read (tow time in hours in `ops$sigfus`; ICES
  in tonnes);
- that the register's `skip_nr`, vor's `skip` and `ops$sigfus`'s `skipnr` are vids (as plan 055 assumes).

## 0. Where this stands

- **v0** (decision 219) is the maintainer's own view: `products/user_tables.R` writes the logbook tables into
  `$FISHYDATA/products/v0/` and links the rest into `curated/`. It is live, not frozen, run by hand after a rebuild,
  and `_targets.R` (l. 26) keeps `products/` out of the build. `sensor_gps` was linked into its logbook folder on
  2026-10-31.
- **The ask** (the maintainer, 2026-10-31): a preliminary release for an MFRI colleague who works on Nephrops and
  shrimp, as a test case of the product. It goes on a central MFRI server they can read. They want the historical
  aggregated data too. The product joins the target chain, carries a metadata YAML for its tables and a README, and
  its parquet files drop the `_part` in their names.
- **The form** (the maintainer, 2026-10-31): "a conventional repo now, not an R-package per se". An R package with the
  parquet files in `inst/` was weighed first: `renv` would have pinned the data with the code. It was set aside for
  now. A directory of parquet files needs no installation, can be read from any language, and keeps one copy on the
  server. A package may come later as a reader over the repository.
- **TODO 140** asked first for how a data product is versioned ("very important", 2026-10-24). §2 answers that for
  the repository; the design of the user tables after v0 stays with TODO 140 and plan 055's analyst view.

## 1. The repository

### 1.1 Its layout

A plain directory tree. Its history is its releases and their index, not a version-control system; the code that
makes it is in fishycode.

```
<root>/                          the repository, a folder on an MFRI share (ask a)
  README.html                    what the repository is, how to read a release and how to cite one
  RELEASES.md                    the index: one row per release
  LATEST                         a text file: the newest release's id
  releases/
    2026.11.03.1/                a release, never rewritten
      README.html, README.qmd    this release: its approach, tables, joins and what to watch (§4.2)
      CHANGES.md                 what changed since the release before, and why (§2.4)
      manifest.yml               ids, checksums and provenance (§2.3)
      meta.yml                   every table and column (§4.1)
      logbook/                   trip, station, catch, landed_not_logged, environment, gear, rigging, sensor_summary;
                                 sensor_gps/year=…/
      aggregate/                 the historical aggregates: logged_monthly, nephrops_fleet, ices (§5)
      landing/                   landing, catch
      vessel/                    vessel, vessel_year
      reference/                 species, gear, port
```

The same tree is kept locally as `$FISHYDATA/products/published/`, the folder decision 219 set aside for versioned
releases. The server holds a copy of it (§1.3).

### 1.2 How it is read

Nothing is installed. A table is a parquet file at a path that names its release, so an analysis names its data in
its own code:

```r
catch <- duckdbfs::open_dataset(file.path(root, "releases", "2026.11.03.1", "logbook", "catch.parquet"))
```

Python, DuckDB's command line, or anything else that reads parquet does the same. The repository's README gives
these lines, and the two that cite a subset (§2.3).

### 1.3 Where it lives

- **The maintainer copies the local tree to the server**, since Claude cannot reach MFRI's shares. Each copy is
  checked file by file against the manifest's md5s.
- **On a share, with no links** (ask a). The repository is a folder on an MFRI share the colleague can open. A
  macOS client generally cannot make hard links over SMB, and its symbolic links do not show on Windows. So:
  - `LATEST` is a text file;
  - each release is a full copy, about 1.8 GB.

  Unchanged files hard-linked between releases (`rsync --link-dest`) wait for a Linux host with a shell. That matters
  once AIS joins: 26 GB, of which 127 trail months were unchanged in decision 265's rebuild.
- **Every release is kept** for now, at about 1.8 GB each. The rule is revisited when AIS joins.
- **Not a backup.** The repository is not the store's backup (TODO 15).

### 1.4 In fishycode

| file | what it holds |
|---|---|
| `products/repository/README.qmd` | the repository's front page |
| `products/repository/release.qmd` | each release's README (§4.2) |
| `products/repository/meta.yml` | what the releases add to `docs/data-dict.yaml`'s text (§4.1) |
| `products/repository/releases.md` | the index, copied to the server as `RELEASES.md` |
| `R/release.R` | `publish_release()` and `compare_release()` (§2.4, §6) |
| `products/user_tables.R` | the candidate (§6) |

## 2. Versioning

The maintainer, 2026-10-31: "think carefully now about how we would deal with data versioning".

**Ideas borrowed, not followed to the letter.**

| source | what is taken from it |
|---|---|
| Zenodo | version and concept identifiers, frozen files, a tombstone |
| W3C DCAT 3 | a link to the previous version |
| Official statistics' revision policies (Eurostat's guidelines, Statistics Iceland) | revisions classed by cause |
| NASA's data collections | forward processing against reprocessing; never mix versions |
| GBIF's IPT | saying when results may change |
| RDA's dynamic data citation | citing a subset as a release and a query |

### 2.1 What a version must answer

An analyst, or someone checking their work years later, asks five things:
1. **Which data did this analysis use?** An id to write in a script and a report.
2. **Can I have it again?** The same bytes, years later.
3. **What changed since the last one, and why?** Per table, in rows and kilograms, each change tied to its cause.
4. **Will my code still run?** Whether a table or column was renamed, dropped, or changed its meaning or unit.
5. **How current is it?** To which date each source holds records, and which years are still provisional.

### 2.2 A release is kept, not rebuilt

Rebuilding a past release from the record does not give its bytes back, and the store has shown why:
- **The same code differs:**
  - the order of a floating-point sum: `landed_logged` and `catch_flag` agree only to 3 decimals (decision 265);
  - labels that follow row order (TODO 174);
  - the engine: DuckDB 2.0.0 against 1.5.6 (decision 239);
  - ramb, which `targets` cannot see.
- **The inputs are not kept:** a schema's dump replaces the last one once `compare_dumps()` passes, and the sources
  edit old records (adb nightly, agf).

So the files are the version, and the provenance explains them. Keeping them is cheap: a release without AIS is about
1.8 GB (§3).

### 2.3 The scheme

- **The release id is `YYYY.MM.DD.n`**, ramb's form: the date it was published, `n` from 1. The data change in every
  release, so a semantic version of the whole would say nothing; the date says when (ask b).
- **A schema version, `MAJOR.MINOR`, beside it**, in the manifest, the README and `meta.yml`. It answers question 4:
  - MAJOR goes up when a table or column a user reads is renamed or removed, or changes its meaning or unit;
  - MINOR goes up when one is added;
  - a release that only brings new data keeps its schema version;
  - a MAJOR change carries a note in `CHANGES.md` on what it breaks and how to move.
- **One id for the whole release.** Its tables come from one build and join each other by key; a version per table
  would invite mixing a station of one build with the catch of another. The manifest's md5s say which files did not
  change.
- **Immutable.** A published release is never rewritten. A defect found later goes into the next release, and the
  index marks the old one with the defect; it is not deleted, since someone may have used it. A release is withdrawn
  only if it holds what it must not, such as a person's data. Its folder is then deleted and its row in the index
  stays, saying why.
- **`LATEST`** names the newest release, for a look. An analysis names its id.
- **A subset is cited as the release and the query**: "release 2026.11.03.1, `logbook/catch`, species 40, 1986-2020".
  The README gives a line of R that writes both into a result.
- **v0 is not a release.** It is the live candidate (§6), never cited.

**The code behind a release** (the maintainer, 2026-10-31: "we need to know in the release what the git-version of
the fishycode and ramb was at the time of the build"). It is known at two moments:
- **When each file was built.** `write_curated()` stamps `fd.commit`, fishycode's commit, and nothing of ramb. It
  gains two stamps:
  - `fd.ramb`: ramb's version and commit, read from `packageDescription("ramb")`. `remotes::install_git()` records
    the commit as `RemoteSha`: today 2026.10.28.3 at 5a01d76;
  - `fd.duckdb`: the engine's version.

  A file built before these stamps carries `fd.commit` alone. The first release follows a rebuild of what it reads
  (step 3), so its files are stamped. The exception is `sensor_gps`, a frozen `once` fix, whose manifest entry names
  the record that froze it (decision 075).
- **When the release is published:** fishycode's commit, from a clean tree, which made the release folder; ramb's
  version and commit in that session; and DuckDB's and R's versions.

The manifest lists both moments. Per file, it gives the commits the file was built with. For the release, it gives
the distinct fishycode and ramb commits its files came from, so a release built across several partial rebuilds says
so.

**`manifest.yml`** (the third mechanism of `AGENTS.md` § Provenance, unbuilt since decision 000) holds:
- the id, the schema version, when it was published, and the id of the release before;
- the code behind it, as above;
- for every file: its rows, md5 and schema hash, and the `fd.*` stamps of the curated file it came from;
- for every source: the dump it was read from (raw's `fd.dumped`), the span of its records, and the years marked
  provisional (the landings' last two, decision 192). This answers question 5.

### 2.4 What changed, and why: `CHANGES.md`

`compare_release(old, new)` makes it from the two releases' files, on the fingerprints of `R/fingerprint.R`, as
decision 265 compared its builds. It answers question 3.
- **Per table**: the rows added, removed and changed, by key; for a catch table, the kilograms by year and species;
  the columns added or removed.
- **Each change classed by its cause**, as statistics offices class their revisions:
  - **new data**: records a source added or edited since the last dump; the provisional years move here;
  - **method**: a decision changed how the build reads or links, named with its number and title;
  - **correction**: an error in an earlier release, named and marked in the index against the release it affected.
- **It opens with what may change a result**: the tables whose kilograms or counts moved for a reason other than new
  data. A user who reruns an analysis on the new release reads that first.

Two kinds of release follow, as NASA's data collections are made:
- most add new data under the same method, so a series can be extended;
- a release that rebuilds the history under a new method says so at the top, and the README tells the user not to
  join it with an older one.

### 2.5 Keys across releases

A changelog by key, and a user who compares two releases, need keys that keep their meaning:
- **From the source, stable:** `vid` (the ledger, decision 115: a vid once given never moves), the logbook's
  `.sid`, and a landing's `.lid`.
- **Made by the build:** for example afli's `.tid` (the lowest `.sid` of a trip), `voyage_id` and `port_call_id`. One
  may move when the build changes how it groups.

`meta.yml` marks each key as one or the other, and `CHANGES.md` counts the build-made keys that moved.

## 3. What the first release holds

Every count is v0's of 2026-10-30 and 2026-10-31. Sizes follow the links.

| folder | table | rows | from |
|---|---|---:|---|
| `logbook/` | `trip` | 2,087,289 | written (decision 219) |
| | `station` | 7,545,513 | written |
| | `catch` | 17,184,668 | written; whole weight `catch_round` (decision 257), the Nephrops tails `reconstructed`; `flag` (§3.1) |
| | `landed_not_logged` | 34,057 | `curated/logbook/catch_flag`'s trip-level flag, on 18,462 trips (§3.1) |
| | `environment` | 4,338,522 | written |
| | `gear` (was `gear_part`) | 15,678,761 | `curated/logbook/gear_part` (plan 052) |
| | `rigging` (was `rigging_part`) | 13,626,197 | `curated/logbook/rigging_part` |
| | `sensor_summary` | 17,569,309 | `curated/logbook/sensor_summary` |
| | `sensor_gps/` | 49,324,452 | `curated/logbook/sensor_gps`: the afli GPS logger, 2007-2024, by year; a frozen `once` fix (decision 075) |
| `aggregate/` | §5 | | new |
| `landing/` | `landing`, `catch` | | `curated/landing/` |
| `vessel/` | `vessel`, `vessel_year` | | `curated/vessel/` |
| `reference/` | `species`, `gear`, `port` | | `curated/reference/` |

- **Size:** about 1.8 GB without `aggregate/`: the logbook 614 MB, the logger 1.1 GB, the landings 106 MB. The AIS
  tables (26 GB) are left out of the first release (ask c).
- **The logger** is in, at the maintainer's word (2026-10-31). Plan 052's `vessel_sensor`, its readings long and with
  no positions (TODO 163), would take its place in a later release.
- **Names** (ask d). `_part` is dropped in the release only. In `curated/logbook/`, `gear.parquet` is each station's
  gear as the pipeline uses it (`gid_used`), so the parts keep their names there. A user then meets two tables called
  `gear`, in `logbook/` (the gear's measured parts) and `reference/` (the code list); the README names both.
- **No person's data.** No column of v0's logbook, landing or vessel tables, nor of the aggregate tables in §5, holds
  a kennitala or a person's name (column names read 2026-10-31). The build stops on a column from a list of persons'
  columns, so a later join cannot carry one in. The logbooks are confidential still: the README says the release is
  for use inside MFRI.

### 3.1 Three changes before the first release

- **The inshore shrimp hauls placed** (TODO 172): 228,259 afli hauls (113.9 kt, mostly the inshore shrimp of
  1972-2003) have no position or square in `curated/logbook/station`. `ops$sigfus.fj_reitir` gives 216,425 of them a
  square and sub-square, basis `derived`. That needs the logbook chain rebuilt by name (step 3).
- **The tow time on the e-logbook's towed stations** (ask e, answered). `duration_m` is empty on every adb and
  fs_afladagbok station: their tow time is in the times (`.duration_source` `times`), and decision 240 stores no effort.
  A user's catch per tow hour then drops the e-logbooks, which hold Nephrops and shrimp since 2020 (170 of 171 Nephrops
  stations and 4,661 of 4,678 shrimp stations empty). `t2` and `t3` are both filled on 99 % of their towed stations
  (bottom and midwater trawl, Danish seine, dredge). Plan 055 §6 puts the tow time in the column a user reads.
  - **The fill**, in the release only: `duration_m` takes the span `t2` → `t3` (`duration_m_raw`) where
    `.duration_source` is `times`, on the mobile gears (269,011 stations). `.duration_source` says so on each row.
  - **Implausible and missing stay empty:** 109 implausible, 1,492 missing.
  - **The same quantity as afli's:** afli's recorded tow time is that interval on 765,100 of its 765,154 bottom-trawl
    stations from 2008. Shrimp tows' medians run on across the change of source: afli 592 minutes in 2022, the
    e-logbook 599 that year and 622-624 in 2024-2025.
  - **`curated/` is unchanged:** it stores a duration only where the record gives one (decision 240).
- **Flagged catch visible** (ask g, answered): `curated/logbook/catch_flag` (decisions 216, 217 and 246: a flag,
  never a correction) is not in v0. Its four kinds are carried two ways:
  - **On logged catch rows, three kinds,** exactly one per (station, species): `landing_contradicts` 87,856,
    `largest_landing_exceeded` 278 and `repeated_digits` 2. They become a `flag` column on `logbook/catch`, empty
    where none, so a user can leave the flagged rows out.
  - **On no catch row, `landed_not_logged`** (34,057 rows on 18,462 trips): a trip's landing holds catch its
    logbook does not, with no station or species. It becomes `logbook/landed_not_logged`, keyed by trip, with its
    witness and the trip's landed kilograms.

## 4. The metadata and the READMEs

### 4.1 `meta.yml`, in the data-dict format

- One file per release, in the format of `docs/data-dict.yaml` (`$version: 0.1.0`, decision 029): each table with
  its description, grain and keys; each column with its description, type, unit, examples or range, and the
  vocabulary of a code or a basis.
- **Composed, not copied.** A release column that is a curated column takes the curated column's text from
  `docs/data-dict.yaml`. `products/repository/meta.yml` holds only what the releases add: their tables' descriptions,
  the renamed tables, and the columns the user tables make (`T1_from`, `gid_used`, the tow time, `flag`, the aggregate
  tables' columns). One text per column, so the two cannot drift. The build stops on a release column that has no
  description.
- **Checked** by the data-dict CLI: `validate-spec` clean, and `validate-data` on the release's own files.
- **Lineage and coverage** (plan 055 §4), per table and period, go into the aggregate tables' entries now, and into
  the others when plan 055's ask f is answered.

### 4.2 The READMEs

Both are `.qmd` (the maintainer, 2026-10-31: better than a `.md`), rendered to HTML by `publish_release()` with the
`.qmd` beside them. Their numbers are read from the manifests when they render, so none is typed by hand and none can
go stale. They include:
- the release id;
- the schema version;
- rows and spans;
- the provisional years.

**The repository's** (`products/repository/README.qmd`): what the repository is; the list of releases, from the
index; how to read a table; how to cite a release and a subset; that it is for use inside MFRI, and was made with AI
assistance.

**A release's** (`products/repository/release.qmd`):

1. What this is: a preliminary release and its version; who made it and how (AI use stated); for use inside MFRI.
2. **The approach, in brief, and why it differs from afli** (the maintainer, 2026-10-31). A user who knows afli will
   find other numbers here, and each difference has a reason:
   - **One logbook from every source**: afli, its sent layer, fs_afladagbok, adb, aflaskeyti, afli's lumpfish logbook
     (decision 263) and the tour app (decision 264), merged with afli first for a vessel and a day (decision 243).
   - **Each record once**: a station or trip entered twice is left out (decision 094).
   - **Flagged, not corrected**: an extreme value stays as recorded, with its flag (decisions 216, 217 and 240). A
     value judged by the AIS track is flagged too, such as afli's east longitudes (decisions 242 and 249).
   - **The gear the landing confirms** in `gid_used`, with the logbook's own beside it (plan 014 3j).
   - **Whole weight at the landings' factor of the day**, with the logbook's ×1.25 beside it and the Nephrops tails
     at 3.25 (decision 257).
   - **A trip's departure and return from ranked witnesses**, the AIS track first, not the logbook's dates alone
     (decisions 173 and 174).
   - **No stored effort**: the times and the count are the record, and the effort is the analyst's choice (decision
     240).
   - **The monthly summaries apart** (§5): afli holds them as stations, and so repeats its Nephrops of 1986-1999.

   Then one paragraph on the e-logbook and the landings since 2020, as another story told elsewhere:
   - fs_afladagbok is the dump of record, no longer fed;
   - adb, MFRI's nightly copy, is read only from 2025-11-19 (decisions 160 and 171);
   - the landings are agf's alone from 2020-07-22 (plan 039).

   Each item says what a user sees differ, in a sentence, and names its decision. It is checked against that decision
   when written.
3. The tables, one line each, with their keys and grain.
4. How to read them: a few lines of R (DuckDB) and Python.
5. **The joins:** a logbook record by `(.sid, schema)` or `(.tid, schema)`, never by the id alone; a landing by
   `(.lid, schema)`; a trip's landing on the trip (`.lid`, `schema_land`); a vessel by `vid`.
6. **What to watch** (plan 055's analyst view, its first text):
   - one quantity per table: logged catch, landed catch and the historical statistics are never summed together;
   - `catch` as recorded against `catch_round`, whole weight, with its basis;
   - `gid_used`, the gear the pipeline uses, against `gid` and `gid_landing` as each source records it;
   - duplicates are already out (decision 094);
   - flagged values stay in, with their flag, to be left out on purpose;
   - the tow time on the e-logbooks, and effort as the analyst's choice (decision 240);
   - the landings hold foreign vessels' landings in Iceland (`vessel.foreign`), until plan 055's ask d says whose
     total is meant;
   - the aggregate tables overlap the logbook in places (§5), and must not be added to it;
   - the afli GPS logger (`sensor_gps`):
     - its positions are interpolated from the AIS track of 2026-10-09;
     - `w_lon`/`w_lat` are the logger's own, and faulty (`afli_coords.yml`);
     - from mid-2020 the logger writes whole degrees and whole m/s (`logger_whole_degrees.yml`);
     - it is afli's alone, so its `.sid` carries no schema;
     - join it to the AIS fixes by `vid` and time, in the analysis.
7. Known gaps, each with its record:
   - the monthly summaries outside the logbook (TODO 136);
   - overlapping trips (TODO 102);
   - the handline trips of 2020-09 to 2021-03 that the tour app does not fill (declared, decision 264);
   - 22,588 stations (0.3 %) whose vid is not in the vessel table: 19,960 of the lumpfish logbook's of 1980-2015,
     1,537 of afli's, 1,019 with a negative e-logbook vid, and 72 other e-logbook stations;
   - the e-logbook's 77 Nephrops stations of 2021-2024, which tow a median 24-90 minutes against afli's 313-360 in
     2017-2021: found 2026-10-31, not explained.
8. How to report a problem, and where the next release's changes are listed.

## 5. The historical aggregates

The maintainer's question: they belong neither to the landings nor to the logbooks? In part. By plan 055's rules (one
quantity per table; resolutions can cross):

| source | quantity | resolution | span | rows | family |
|---|---|---|---|---:|---|
| `ops$sigfus.gamall_humar`, with a vessel | logged | vessel × month × square (× sub-square) | 1970s-1999 | 20,949 in all | logbook, coarse |
| `ops$sigfus.gamall_humar`, no vessel (the fleet) | **unknown** (allocated at the year, key unknown) | month × square | 1960-1972 | about 800 of the above | statistic |
| `ops$sigfus.gomul_raekja` | logged | vessel × month × shrimp area | 1953-1986 | 10,531 | logbook, coarse |
| `ops$sigfus.gomul_dragnot` | logged | the table's own boat code × month × square, with sets | 1960-1970 | 2,792 (937 never loaded into afli) | logbook, coarse |
| fiskifelagid `vigtarskra66_81` | landed | vessel × month × station × gear × product | 1966-1981 | 1,426,249 | landings, period 0 |
| vor `afli_einstakra_skipa` | landed | vessel × month (1984: vessel × year) | 1982 to 1992-08 taken; compiled from LODS and agf after | 2,027,479 in all | landings, period 0 |
| fiskifelagid `landed_catch_pre94` | landed | month × port × gear | 1982-1993 | 519,999 | landings, crossing vor |
| `ops$einarhj.ices_landed_catch` | statistic | year × country × area | Iceland 1903-2019 | 416,353 (Iceland 4,876) | statistic (compiled from the landings from 1966) |

So:
- the summaries with a vessel are logbook records at a coarse unit;
- the old weighings are landings at a coarse unit;
- the fleet's Nephrops and ICES are statistics.

They have stayed out of the user tables because the plans that would place them are parked or unbuilt: plan 041 for
the summaries, plan 039's period 0 for the landings.

**In the first release** (ask f, answered): the logged summaries, the fleet's Nephrops and ICES, each one table in
`aggregate/`, in the release's names and units, kept apart from `logbook/`, with its quantity, lineage and coverage
in `meta.yml`. The folder is `aggregate/` rather than `historical/`, since ICES runs to 2019.
- **In the vessel table:**
  - `gamall_humar`: all but its 804 fleet rows and 2 others;
  - `gomul_raekja`: all but 35 rows with no vessel and 8 not found;
  - `gomul_dragnot`: none, since its numbers are the table's own boat codes.
- `logged_monthly`: the three summary tables from `ops$sigfus`, the source afli loaded them from, so the seine's 937
  rows are in.
  - Every row but the fleet's Nephrops; the seine's boat codes as recorded, beside an empty `vid`.
  - The tow time in hours, as the source holds it.
  - A column `repeats_hauls` flags the cells whose kilograms afli's hauls already hold. That is plan 041 §3.3's rule
    as a flag, not a drop: 2,501 cells and 22.5 kt in afli's rows, mostly the Nephrops of 1986-1999.
- `nephrops_fleet`: the fleet's Nephrops of 1960-72, quantity unknown (plan 055 ask g).
- `ices`: Iceland's rows of the statistic, Nephrops (1959-2019) and shrimp (1936-2019) among them. The README says
  it is a witness, compiled from the landings from 1966, never a check on them. It includes the 2018 Nephrops total,
  86 times the landings, flagged.

**The landed tables wait for plan 039's period 0:** the 1966-81 weighing register, vor to 1992-08 and
`landed_catch_pre94`. fiskifelagid's study is parked (TODO 123). Only 1,239 of the register's 2,352 vessel numbers are
in the vessel table, against 2,441 of `landed_catch_pre94`'s 2,456. So the register's numbers need a reading before a
user joins them to a vessel.

When plan 041 is built, the summaries move into `logbook/` in the next release: a MAJOR schema change (§2.3). The
README says which overlaps a user must not add: the summaries flagged `repeats_hauls`, against `logbook/catch`; and
`ices`, against everything.

**In the target chain:**
- `sources/ops_sigfus/convert.R` stages the summaries and `fj_reitir` (preprocessing);
- `sources/ops_einarhj/convert.R` stages Iceland's rows of `ices_landed_catch` (preprocessing);
- `curate/aggregate.R` writes `curated/aggregate/`, `repeats_hauls` included: it reads the summaries and afli's
  hauls, two sources, so it is in `curate/`;
- `products/user_tables.R` takes `curated/aggregate/` like any other curated table.

## 6. Building and publishing

- **One writer:** `products/user_tables.R` stays the only script that shapes the user tables. Its output, v0, becomes
  the **candidate**: what the next release would hold.
- **`user_tables`** in `_targets.R`: the script as a target, on the flow side (it links the AIS tables), downstream
  of every curated table it reads. Every build then refreshes the candidate (ask h). That ends two things: the hand
  rerun (decision 219), and the drift between v0's written and linked halves. `_targets.R` l. 26 changes with it.
- **`user_tables_check`**:
  - rows against their curated sources, each row in one outcome (taken, or out as a duplicate);
  - kilograms in = kilograms out per table;
  - every column described in `meta.yml`;
  - no persons' column;
  - `validate-spec` and `validate-data` clean.
- **`publish_release(id)`** (`R/release.R`), by hand: a build never publishes, as a frozen fix is built by name in the
  `once` project. It copies the candidate into `$FISHYDATA/products/published/releases/<id>/` with every link
  followed. It then writes the manifest and `CHANGES.md`, renders the two READMEs, updates the index, and checks it
  all. It refuses unless:
  - every curated file the release reads is stamped `fd.dirty` false (v0 as rerun on 2026-10-31 is stamped dirty,
    since the tree held this plan's uncommitted edits: exactly what the gate is for);
  - every such file carries `fd.ramb` with a commit, but for a frozen `once` fix (§2.3);
  - fishycode's tree is clean when it publishes, and the installed ramb has a commit (`RemoteSha`). A ramb installed
    from a working tree, as `devtools::install()` does, has none;
  - `tar_outdated()` lists nothing the release reads, with `ais_catch` and the audit excepted (decision 261);
  - `user_tables_check` has passed;
  - the id is new.
- **Releases are made on demand** while there is one user. A fixed rhythm, such as before the advice season, comes
  when there are more (ask b).
- `tests/test_release.R`, with no data:
  - links are followed;
  - the manifest's md5s are right;
  - a persons' column stops the build;
  - a published release is never written twice.

## 7. Steps

1. The asks answered, in this plan.
2. **Code**, nothing built:
   - `R/write_curated.R`: the stamps `fd.ramb` and `fd.duckdb`, and `curated_provenance()` printing them;
   - `user_tables.R`: the names, the tow time, the `flag` column and `landed_not_logged`, the persons' check,
     `aggregate/`;
   - the two adapters and `curate/aggregate.R`;
   - `R/release.R`;
   - `products/repository/`;
   - the targets and their side headers;
   - the tests.
3. **TODO 172's placing** coded, and the logbook chain, the adapters and `curated/aggregate/` built in a scratch
   store and compared with the live store's (every station not placed unchanged). On the maintainer's go, built by
   name, with fingerprints before and after: every curated target the release reads, so that each of its files
   carries the new stamps. The AIS targets downstream of the logbook are left outdated, since the release does not
   read them.
4. **The candidate** built by targets, and `user_tables_check` read: every outcome, every kilogram.
5. **Published:** `publish_release()` writes the local tree; the maintainer copies it to the share, and the copy is
   checked against the manifest.
6. **Recorded:** a decision on how the repository is versioned and published (TODO 140's first half), and
   `AGENTS.md`'s layout row for `products/`. The colleague's feedback goes into TODO 140 as the next release's list.

## 8. What it does not do

- It makes no R package: the repository is read as files (§0). A reader package over it may come later.
- It follows no outside standard to the letter (§2).
- It does not design the user tables after v0 (TODO 140) or write plan 055's analyst view into the grammar (TODO 171).
- It does not put the monthly summaries into the logbook (plan 041, parked): they wait in `aggregate/`.
- It does not build the landings' period 0 (plan 039), so the landed tables of 1966-1993 are not in the release.
- It does not release the AIS tables, the catch on the fixes (decision 261) or the effort map.
- It sends nothing outside MFRI.

## 9. Asks, answered

Answered by the maintainer on 2026-10-31, each as recommended, after Claude checked the data behind each
recommendation (read-only, the numbers in the sections named).

a. **The server:** a folder on an MFRI share the colleague can open, with no links. `LATEST` is a text file and each
   release a full copy (§1.3). The share's path is still to be named, before step 5.

b. **The versioning:** the id `YYYY.MM.DD.n` with a schema version `MAJOR.MINOR` beside it; releases on demand;
   `CHANGES.md` classing each change as new data, method or correction (§2). The check: in one week v0's trips rose
   12.6 % (1,853,260 to 2,087,289), its stations 3.3 % and its catch rows 1.1 %. Nearly all of that came from new
   sources read (decisions 253-264), not from new records, so the cause of a change says more than a number.

c. **The contents:** logbook (with `sensor_gps`), aggregate, landing, vessel and reference; no AIS (§3). The check:
   - every trip's landing is found;
   - every species and gear in the logbook is in the reference tables;
   - every catch row has its station;
   - the one gap is the 22,588 stations whose vid is not in the vessel table, listed in the README (§4.2).

d. **The names:** `gear` and `rigging` in the release; `curated/` keeps `gear_part` and `rigging_part`, since its
   `gear.parquet` is each station's gear (`gid`, `gid_used`, `metier`, `gear_code`) (§3).

e. **The tow time:** filled in the release from the times, on the e-logbook's mobile gears; `curated/` unchanged
   (§3.1).

f. **The aggregate tables:** the logged summaries, the fleet's Nephrops and ICES, in `aggregate/`; the landed tables
   wait for plan 039 (§5).

g. **The flags:** a `flag` column on `logbook/catch` for the three kinds that sit on catch rows, and
   `logbook/landed_not_logged` for the fourth (§3.1).

h. **The candidate:** `products/user_tables.R` as a target, rebuilt on every build (it ran in 14 seconds on
   2026-10-31); publishing by hand, behind the gate (§6).
