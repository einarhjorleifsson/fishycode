# 028 — The annual ship register (Skipaskrá) mined whole, into the `vessel` schema's tables

**status:** proposal — measured 2026-10-18 (read-only), nothing built; the output takes the `vessel` schema's table
structure, not one table (maintainer, 2026-10-18); §9 asks open (TODO 83) · **2026-10-18** · **see:** decisions 046,
047, 049 and 121; plans 008, 016, 021, 022 and 023; TODO 25 (the key redo, which rebuilds `annual_call_sign`), TODO 65
and TODO 71 (the 2023-01-15 MMSI list)

Drafted with AI assistance (Claude) on 2026-10-18, at the maintainer's request. The request was to read the annual
register PDFs whole, the minor tables too (new vessels, scrapped vessels, their fate), into tables of every variable.
Each error or discrepancy found is to be reported beside the mining. The checks may use the rest of fishydata:
- the `vessel` schema dump;
- Hreiðar's workbook (typos are to be expected);
- the landings dumps, for licence periods and change histories;
- the hand-curated mbl scrapes;
- the MMSI tables;
- the hand-curated MarineTraffic sheets, as auxiliary;
- the logbooks, the landings and AIS.

The aim is a comprehensive register input to the project, with the MMSI. The PDFs are the source over the years
they cover, and Hreiðar's workbook may help before that. The maintainer's steer on the shape: base the output on the
`vessel` schema's structure, which is likely well thought out but may have missed things, such as the history of
the call signs; and perhaps not a single table (maintainer, 2026-10-18).

The numbers below were measured by Claude (AI). A person has not yet checked them.

**Measured** (read-only, 2026-10-18):
- the 19 PDFs in `raw/external/skipaskra/reports/`, converted with `pdftotext -layout` in scratch, and the earlier
  extractions, scrapes and trial scripts beside them;
- `raw/external/hreidar/` and `raw/external/marinetraffic/`;
- `raw/oracle/vessel/` (dump of 2026-10-16) with its data dictionary;
- the vessel, licence and MMSI tables of `raw/oracle/{kvoti,ufs,fs_ufs,orri,ops_einarhj}/`, by name, size, columns
  and date span;
- `raw/mmsi/` and `raw/vessels/`;
- `curated/vessel/mmsi.parquet` and `staging/skipaskra/annual_call_sign.parquet` as they stand.

Scripts and text are in scratch only.

**Assumed:**
- the edition of year Y is the register on Y-01-01, as each title page says and decision 049 tested;
- the edition's key (*Skýringar*) says what each field holds;
- where a rough parse finds fewer entries than an edition's stated total, the parse is short, not the edition (§2.4
  tests this only in part);
- the kvoti and ufs Oracle comments say what a table holds (only their date spans were measured);
- the mbl and siglo scrapes are the state at the date in their log names, not on 1 January.

**Personal data:** every entry prints the owner's name and address. The name-prerogative list names holders, and
mbl has the operator and a phone number. None of it was extracted, and the plan does not read it (§7). This follows
decision 121 and plan 023 §7. Nothing personal enters this repository, which is public.

## 1. In short

- **19 editions, 2004-2022, 5,230 pages.** 49 pages carry no text layer, most of them title or logo pages. 2006's
  first six pages (title, summary and aggregate tables) are images. No OCR is needed for the register itself.
- **Three layouts:**
  - 2004-2017: a five-line block per vessel;
  - 2018: two-line rows with wrapped cells;
  - 2019-2022: two-line rows, each line opening with the registration number.

  The key gives 27 fields for a decked ship and 24 for an open boat. The changes field ends in 2010, and engine year
  and kW end in 2017.
- **Every edition has minor tables:**
  - the previous year's registrations;
  - its deregistrations, with date and fate (sold abroad, scrapped, sank, burned);
  - summaries and aggregates;
  - per-vessel draught and weight (2004-2006);
  - lists by registration number, district number and call sign (2004-2013).

  2006 has no per-vessel registration or deregistration list.
- **A rough parse finds 96-100 % of each edition's entries** (§2.4), except 2018's wrapped rows. The old tabulizer
  route's 2009-2017 table is within 12 entries of each stated total. The two routes can check each other.
- **The `vessel` schema has the structure to base the output on.** For each topic it keeps a current table and a
  `_hist` table with `valid_from` and `valid_to`, beside code tables. Every PDF field read has a column in it, except
  four, which are added (§4.2). Its gaps are content:
  - every history row was written on or after the 2023-12-19 system change;
  - earlier dates are back-filled: 79 % of the dates on which it starts a name are a 1 January;
  - no hull in it has ever had more than one call sign. The editions show 48 call signs passing between hulls in
    2007-2017 alone.
- **`kvoti.skipasaga` is not inside it.** 99 % of its class values are in `vessel_operational_hist`, half of them on
  the same date. Its names, districts and home ports are there as values (96-97 %), but under other dates: fewer than
  3 % fall on the same day. So the Directorate of Fisheries' dated histories are a witness of their own: kvoti for
  1992-2020, and ufs, whose change journals run from 2006.
- **Licences are dated in kvoti from 1996-09-01 to July 2020**: 61,847 licences, plus deleted and revoked ones. No
  licence table for later years was found in the dumps.
- **Two snapshots fill the gap after the 2022 edition:**
  - the mbl register, 5,803 vessels, scraped 2022-12-28 to 2023-01-09;
  - Samgöngustofa's online register, 5,677 numbers, scraped 2022-12-28.

  The MMSI comes from about a dozen tables. `mmsi.R` reads most of them, but not the 2023-01-15 list or mbl's 1,738
  MMSIs, 26 of which are not in the archive.
- **Proposed:**
  - source-shaped staging tables for every table in the PDFs;
  - the `vessel` schema's tables, with the same names and columns, with their past filled in: hull and use,
    identification, measurement, engines, operational category, and dated MMSI;
  - added tables for what the schema lacks: events (registrations, deregistrations with fate) and licences;
  - on every row: its source and basis, how many independent lineages agree, its status (single, agreed, resolved,
    reviewed, open), the rule that decided it, and the columns in dispute;
  - an evidence table of every value every witness gives, chosen or not;
  - a decision model (§6): ordered rules that settle a discrepancy, from parse faults and reviewed overrides through
    the register's own rules, period precedence and typo detection to dating, with what is left kept open for
    review. Each rule's error is measured;
  - a discrepancy table with a docs page.

  The PDFs answer for 2004-2022, Hreiðar's workbook before that, the two snapshots and the ufs journals for 2022-2023,
  and the `vessel` schema from 2023-12-19. No single table is built.

## 2. The PDFs

### 2.1 Editions

The PDFs were downloaded from samgongustofa.is (`R/00_get_from_web.R` in the folder). There is none before 2004 or
after 2022.

| edition | pages | pages with no text | layout |
|---|---|---|---|
| 2004 | 288 | 1 | A |
| 2005 | 284 | 1 | A |
| 2006 | 274 | 7: 1-6 (title, summary, aggregates), 14 | A |
| 2007 | 351 | 6 | A |
| 2008 | 284 | 3 | A |
| 2009 | 285 | 5 | A |
| 2010 | 322 | 6 | A |
| 2011 | 323 | 6 | A |
| 2012 | 343 | 6 | A |
| 2013 | 350 | 6 | A |
| 2014 | 228 | 1 | A |
| 2015 | 229 | 1 | A |
| 2016 | 225 | 0 | A |
| 2017 | 227 | 0 | A |
| 2018 | 252 | 0 | B |
| 2019 | 248 | 0 | C |
| 2020 | 218 | 0 | C |
| 2021 | 245 | 0 | C |
| 2022 | 254 | 0 | C |

The layouts:

- **A**: five lines per vessel under a five-line header, each field at a fixed place.
- **B**: two lines per vessel, with cells wrapped onto the lines above and below; even the IMO number is split.
- **C**: two lines per vessel, both opening with the registration number, with wrapped cells.

Decked ships and open boats are separate sections in every edition.

### 2.2 The register entry

The key's 27 fields for a decked ship:

1. registration number (*skipaskrárnúmer*, our vid)
2. name
3. district number
4. classification society
5. call sign
6. home port
7. previous name
8. owner
9. owner's address
10. where built
11. year built
12. yard
13. type of ship (use)
14. hull material
15. main engine make
16. engine year
17. kW
18. changes
19. GRT (*brúttórúmlestir*)
20. GT
21. NT
22. registered length
23. breadth
24. depth
25. length overall
26. IMO number
27. torque index (*aflvísir*)

An open boat has the same fields less the classification society, the IMO number and the torque index (24). It
carries a call sign only if it has one.

Which fields the tables actually print (measured from the column headers):

- 2004-2010: all of them.
- 2011-2017: no changes field.
- 2018-2022: no engine year, kW or changes. The 2019 key still lists kW as field 17.

The key also states rules that can be checked:

- only a ship of 15 m length overall or more gets a call sign;
- a ship over 24 m registered length has an IMO number;
- below 15 m, GT = 0.031 × L² × B and NT = 0.3 × GT;
- the torque index is hp × propeller diameter × 1, or × 0.6 without a nozzle.

### 2.3 The minor tables

| table | editions | per vessel | fields |
|---|---|---|---|
| summary and trend: counts and GT by year, by inspection body, and from 2014 by use | all; 2006 an image | no | year, count, GT |
| the previous year's registrations: first, re-registered, open boats decked | all but 2006 | yes | number, name, district number, home port, GT; the registration date in later editions |
| the previous year's deregistrations | all but 2006 | yes | number, name, fate in words, date, GT; 2013 adds the last re-registration date (checked in 2013 only) |
| decked ships by type, age, mean age and engine make | 2004-2013; 2006 images | no | aggregates |
| draught, dimensions and weight | 2004-2006 | yes | number, L, B, weight, light and loaded draught |
| lists by registration number, district number and call sign | 2004-2013 | yes | the call-sign list also shows unassigned call signs |
| name prerogative (*einkaréttur á skipsnöfnum*) | all | yes | reserved name and holder: not read (§7) |
| the key: district letters, classification societies, types of ship | all | no | code lists |

### 2.4 How far a plain text parse gets

One regular expression per layout, with no column positions, counting each vessel's first line:

| edition | stated total | rough parse | almost-tidy table |
|---|---|---|---|
| 2004 | 2,365 | 2,325 | |
| 2005 | 2,344 | 2,329 | |
| 2006 | 2,311 | 2,291 | |
| 2007 | 2,309 | 2,295 | |
| 2008 | 2,323 | 2,297 | |
| 2009 | 2,268 | 2,235 | 2,256 |
| 2010 | 2,237 | 2,199 | 2,237 |
| 2011 | 2,250 | 2,187 | 2,249 |
| 2012 | 2,266 | 2,194 | 2,266 |
| 2013 | 2,298 | 2,208 | 2,288 |
| 2014 | 2,300 | 2,276 | 2,298 |
| 2015 | 2,296 | 2,263 | 2,294 |
| 2016 | 2,284 | 2,244 | 2,285 |
| 2017 | 2,289 | 2,246 | 2,289 |
| 2018 | 2,295 | 610 | |
| 2019 | 2,278 | 2,269 | |
| 2020 | 2,267 | 2,270 | |
| 2021 | 2,242 | 2,236 | |
| 2022 | 2,240 | 2,236 | |

The stated totals come from the editions' trend tables. Two notes on those totals:

- 2008's preface warns that some of its tables count 1,125 decked ships against the register's 1,123: a dry-lease
  ship and one on the waiting list are included.
- 2022's preface says 2,244, while its trend table says 2,240.

Every registration number the rough parse finds in the 2008, 2014 and 2021 editions is in the `vessel` schema's
`vessel` table. Between 99.6 % and 100 % of them are in Hreiðar's workbook for the same year.

### 2.5 The earlier work in the folder

- `R/01_import_pdfs.R` ran tabulizer on every edition, writing `data-raw/skipaskra_tabulized_matrix_*.rds`: 208-401
  tables per edition.
- `R/02_tidy_2009_2017.R` turned those into `data/skipaskra_2009-2017_almost-tidy.rds`, 32 columns, owner and address
  among them.
- `R/02_tidy_2004_2008.R` does not run here: it needs the Oracle region list and an old `stringr` idiom, and fails on
  short pages (decision 049).
- `00_DATASET_skipaskra_frum-og-afskraningar.R` and its `_TRIAL2` read the registration and deregistration tables
  with `pdftools`. They name the problem that matters: a line break inside a cell looks like a new row.
- `2024-11-0*_consolidating-matrix.R` read the 2018-2022 matrices. That is the route `annual_call_sign.R` takes.
- The scrapes are §3.6's.

The plan reads the matrices and the almost-tidy table only as a second route, to check the first.

**A correction to the record.** `sources/skipaskra/annual_call_sign.R` says 2004-2006 are "card layout in the PDFs"
and not read. In the text layer they are the same five-line blocks as 2007-2017. The card problem is the matrices'.

### 2.6 Discrepancies already in view

These were found in passing, by reading. None is resolved.

- 2019's trend table labels its last column 2018, but the column holds 2019's numbers: 1,020 decked ships and 2,278
  in all, the total its own preface gives for 2019. 2018's figures (1,032 and 2,295) are missing from it. 2018's
  preface dates its registrations to "2016", where it means 2017.
- The decked fleet's GT on 2016-01-01 is 198,079 in the 2016 and 2018 editions, and 198,278 in 2022's.
- The open boats' GT on 2017-01-01 is 8,935 in two editions, against 7,327-7,621 in the years around it. Not checked
  further.
- The 2004 contents date the register to 1 January 2003. Its title page and preface say 2004.
- 2008 prints its list of new decked ships twice, on pages 8 and 9.
- 2004's list of new registrations has a five-digit registration number, 12587.
- 2022's preface (2,244 vessels) disagrees with its own trend table (2,240).

## 3. The other witnesses

### 3.1 The `vessel` schema (Oracle, dump of 2026-10-16)

- **Size:** 18 tables, 7,047 hulls. Of these, 2,244 are on the register, 3,490 deregistered, 1,290 foreign and 23
  other.
- **Keys:** `vessel_id` is a surrogate key, one to one with `registration_no` (the vid) over all 7,047.
- **Structure:** for each topic a current table, with `valid_from`, and a `_hist` table, with `valid_from`,
  `valid_to` and audit columns (`hist_operation`, `hist_datetime`). The topics:
  - the hull, use and status (`vessel`);
  - identification: district letters and number, call sign, home port;
  - measurement;
  - engines, one row per engine;
  - operational category, with its licence system;
  - owners, and the operator (`vessel_fishery`).

  The code tables are `usage_category` (57), `operational_category` (43) and `region` (25). `vessel_mmsi` (3,462)
  has no dates and no history.
- **How far back:**
  - every `_hist` row was written (`hist_datetime`) on 2023-12-19 or later;
  - 24,118 of `vessel_hist`'s 33,324 rows start earlier, back-filled. The commonest starting dates of the
    identification rows are 1998-01-01 (1,170 rows) and 1901-01-01 (959);
  - for the same name, its date is a median 209 days after `kvoti.skipasaga`'s.
- **Call signs:** 1,313 identification rows carry a call sign, on 1,262 hulls, and no hull has two.

So the schema is the model to fill. Its history before 2023-12-19 is a reconstruction, and it has no call-sign
history at all.

### 3.2 Hreiðar's workbook (`HREIDAR_Islensk_skip.xlsx`, sheet `Data main`)

- **Size:** 164,164 rows, one per number and year in use, 1710-2021, plus 1,214 placeholder rows dated 9999. It has
  7,664 numbers; 1,764 of them are 90000 or above, for boats without a registration number.
- **Against the editions:** it has 2,271-2,473 rows a year in 2004-2021. That is 4-149 more than the edition's own
  total, most in 2006-2008. Its "year in use" is not the same as the register on 1 January.
- **50 columns:** name, district and number, build year and place, hull material, engine type, open or decked, use,
  GRT before and after re-measurement, GT, kW, hp, lengths, home port, and the year use ended. It also has:
  - the fate, in 7 classes, on 7,415 numbers;
  - the numbers of people lost and rescued;
  - the book and page in Jón Björnsson's series, its source before the register;
  - the operator's and parent company's names and kennitala.
- **How reliable:** its Info sheet says names, home ports, use and operator were checked for 1998-2015. It is keyed on
  `NR`. Before 2007 its `Skskr.nr.` column disagrees with `NR` (decision 046).

### 3.3 The Directorate of Fisheries' tables in kvoti (to July 2020)

| table | rows | span | holds |
|---|---|---|---|
| `skipasaga` | 65,576 on 5,363 numbers | 1992-2023 | a dated (from-to) history of name, district, class (*útgerðarflokkur*), home port, GRT, length, GT, registered dimensions and deck |
| `skipaskra_breytingar` | 10,773 | 2002-06 to 2020-07 | register changes |
| `skip_flokkabreytingar` | 284 | — | class changes |
| `skipaskra_siglo` | 5,718 | to 2020-07 | the maritime register as copied, with kW, torque index, propeller diameter and certificate dates (seaworthiness issued and valid to, hull, engine and equipment inspections) |
| `skip_extra` | 2,452 | — | build data, first and re-registration, draught and weight |
| `skip_timabil` | 262,787 | 1991-2029 | vessel × fishing year |
| `ureldingar` | 568 | 1993-1998 | catch history moved from scrapped vessels |

341 of `skipasaga`'s numbers (544 rows) are not in the `vessel` schema. Most are below 1000 (including negatives) or
above 4000. What they are was not checked.

### 3.4 Licences

- `kvoti.veidileyfi`: 61,847 rows, every fishing licence issued from 1996-09-01 by its own comment, to 2020-07-22.
  Each has a type (54 codes in `tegund_veidileyfis`), an area, and valid-from and valid-to dates.
- `veidileyfi_eydd`: 3,661 deleted licences, kept from 1999-10-28.
- `veidileyfi_sviptingar`: 4,404 revocations.
- `strandveidileyfi_v`: 7,904 coastal-fishing licences, 2009-2020.
- `dragnot_leyfi`: 1,471 Danish seine licences, 1996-2005.
- `grasleppusaga`: 3,472 lumpfish licences, 1996-2021.

No licence table was found in `ufs`, `fs_ufs` or any other dumped schema, by name or by comment.
`vessel_operational_hist` carries the category and its licence system, back-filled.

### 3.5 ufs, and the older copies

- **ufs** (the Directorate of Fisheries, after 2020):
  - `skip`: 5,317 rows (IMO and call sign);
  - `skipasaga`: 56,986 rows;
  - two journals, written from 2006-01-27 to 2025-04-23: `skipasaga_jn` (129,689 rows) and `skip_jn` (12,506
    rows). They hold every change with its time, and `skip_jn` carries the call sign. How many call-sign changes it
    holds was not counted.

  `fs_ufs.skip` (5,443 rows) is like `ufs.skip`.
- **`orri.skipaskra` and `orri.skipskra`, and `ops_einarhj.vessels` (7,181 rows):** current snapshots, older copies of
  the same.

### 3.6 Snapshots of the online registers (in `raw/external/skipaskra/`)

- **mbl, `data-raw/mbl/`:**
  - Morgunblaðið's *200 mílur* register, one file per vessel, 5,803 vessels;
  - scraped 2022-12-28 to 2023-01-09, by the log names (`R/mbl-scrape_info.R`);
  - curated by hand by the newspaper, not by the authority;
  - fields: name, home port, type, operational class, processing licence, lengths, GRT, GT, NT, build year and yard,
    engine and hp, previous name for 1,570 vessels, changes for 1,263, MMSI for 1,738, call sign for 405, IMO for 58;
  - also the operator and a phone number (not read, §7);
  - two files carry a scraped catch table by mistake.
- **Samgöngustofa's online register, `data-raw/2022-12-28_siglo.rds`:** 5,677 numbers on 2022-12-28: 2,244
  registered, 3,364 not, and 69 numbers allocated. Fields: name, type, district letters, length, GRT, GT, build year,
  home port and status. Owners are among them, and not read.
- **`data/vessels.rda` and `data/history.rda`:**
  - `vessels.rda`: 7,111 vessels, an undated merge of older sources, MMSI among them;
  - `history.rda`: 24,056 rows, a dated name and class history of 5,100 vids to 2021-12 (decision 049).
- **`jpg/`:** 1,000 vessel photos from mbl. Not data.

The two scrapes are the only witnesses to the state around 2023-01-01, between the 2022 edition and the 2023-12-19
system change.

### 3.7 The MMSI tables

| table | rows | date | read by `mmsi.R` |
|---|---|---|---|
| `raw/mmsi/*.xlsx`, the Fjarskiptastofa lists | not counted | 2024-08-21, 2024-11-07, 2025-04-10, 2026-03-09 (twice) | yes |
| `ops_einarhj.vessel_mmsi_20190627`, `_20201215`, `_20220405` | 3,286; 3,470; 3,391 | in the name | yes |
| `ops_einarhj.mmsi_icelandic_registry` | 3,759 | undated | yes |
| `ops_einarhj.mmsi_icelandic_registry_20230115` | 3,687 | 2023-01-15 | **no** (TODO 71) |
| `ops_einarhj.vessel_mmsi` | 3,687 | undated, probably the 2023 list | no |
| `vessel.vessel_mmsi` | 3,462 | the register's last change | yes |
| `raw/vessels/mmsi_iceland_archieves.parquet` | 3,999 | the old archive | for its hand-set windows only |
| `raw/mmsi/mmsi_iceland_2025-MM-DD.parquet` and `_2026-03-25.parquet` | 4,078 (2026) | earlier archive builds | no |
| `ops_einarhj.pame_vid_mmsi` | 533 | — | no |
| mbl (§3.6) | 1,738 | 2022-12/2023-01 | **no**: 1,704 pairs agree with the archive, and 26 MMSIs are not in it |
| `data/vessels.rda` | MMSI for 2,461 | undated | no |
| MarineTraffic sheets (§3.8) | 36 and 14 Icelandic MMSIs | 2019-08 to 2024-06 | no |

`curated/vessel/mmsi.parquet` (4,228 holder periods, plan 016) is `mmsi.R`'s product. Its windows come from list
dates and notes, with a few hand-set (TODO 82).

### 3.8 The MarineTraffic sheets (`raw/external/marinetraffic/`)

- `STK_MARINETRAFFIC_MATCTH.xlsx` (1,230 rows, recorded 2019-08-15 to 2024-06-10) and `CS_MARINE_TRAFFIC_MATCH4.xlsx`
  (823): STK mobile-ids matched by hand to a name, call sign, IMO, MMSI and class from MarineTraffic (plan 008 §3).
- They are mostly foreign vessels: 11 and 6 TF call signs, 36 and 14 Icelandic MMSIs, and their vids lie in
  3339-4981.
- So they are auxiliary here: a dated witness for those few MMSIs, IMOs and call signs. Their mobile-id key is not
  used, since the STK key is built with this register (§5.4).

### 3.9 Activity and feeds

- `staging/astd/identity.parquet`: MMSI × year, with the feed's IMO, name and flag.
- `curated/landing` and `curated/logbook`: vessel and day.

## 4. The product: the `vessel` schema's tables, with their past

### 4.1 Structure

The output follows the `vessel` schema table for table and column for column, so that anyone who knows the schema
can read it. It goes in `curated/vessel/skipaskra/`. It is a set of tables, not one table:

- **The `_hist` tables**: `vessel_hist`, `vessel_identification_hist`, `vessel_measurement_hist`,
  `vessel_engines_hist` and `vessel_operational_hist`.
  - They keep the schema's columns and its `valid_from` and `valid_to`.
  - The audit columns (`hist_operation`, `hist_datetime` and the rest) are replaced by provenance (below).
  - The current twins are not stored again: they are the rows with an open `valid_to`.
- **`vessel_mmsi_hist`**: the schema's `vessel_mmsi` columns, with `valid_from` and `valid_to` added from the MMSI
  evidence.
- **The code tables**: `usage_category`, `operational_category` and `region`, as in the schema. The PDFs' own types of
  ship, as printed, get a crosswalk table, `usage_category_printed`, to `usage_category_no`.
  `reference/vessels/vessel_year.R` already maps Hreiðar's names this way.
- **Tables the schema lacks:**
  - `vessel_event`: registration, re-registration and deregistration, each with its date, and for a deregistration
    the fate in words and a fate class;
  - `vessel_licence_hist`: one row per licence, with type, area and validity, from §3.4.
- **The key** is `registration_no`, the vid, which is one to one with `vessel_id`. `vessel_id` is kept as a column for
  joining back to Oracle.
- **Not built:** `vessel_owners_hist` and `vessel_fishery_hist`, which hold persons (§7).

**Provenance and dispute indicators on every row** (maintainer, 2026-10-18: where the data came from, and whether the
cross-checks disagree):
- `source`: the witness whose value the row carries, for example `pdf:2008`, `hreidar`, `mbl:2023-01`,
  `siglo:2022-12-28`, `vessel`, `kvoti.skipasaga` or `ufs.skipasaga_jn`;
- `basis`: recorded, derived, reconstructed or none (AGENTS.md);
- `window`: `dated` where a source gives the day; `annual` where only the editions bracket it. A value printed in
  editions Y1..Y2 holds for certain from Y1-01-01 to Y2-01-01, and its ends lie in the year before and the year after
  (decision 049);
- `n_lineages` and `n_agree`: how many independent lineages (§6.1) speak to the row's values, and how many agree;
- `status`, one of:
  - `single`: one lineage only;
  - `agreed`: every lineage that speaks agrees;
  - `resolved`: they disagreed, and a rule of the decision model chose;
  - `reviewed`: a person chose, through an override;
  - `open`: no rule applies, and the row waits for review;
- `rule`: the decision-model rule that chose the value (§6.2), when `status` is `resolved`;
- `disputed`: the columns in dispute, comma-separated, empty when none;
- for a PDF value, its `edition` and `page`, with the printed string kept beside the parsed value.

**The evidence table:** `skipaskra_evidence.parquet` sits beside the `_hist` tables. It is long, with one row per vid,
table, column, window and witness, giving the value as given, its source, edition and page. Every value any witness
gives is in it, chosen or not, so a row's `disputed` columns can always be traced back to who said what.

### 4.2 The crosswalk: each PDF field to its column

| PDF field | table | column |
|---|---|---|
| registration number | every table | `registration_no` |
| name, previous name | `vessel_hist` | `name`, `previous_name` |
| type of ship | `vessel_hist` | `usage_category` (as printed), `usage_category_no` (by the crosswalk) |
| decked or open (the section) | `vessel_hist` | `open` |
| classification society | `vessel_hist` | `classification_society` |
| where built, year built, yard | `vessel_hist` | `construction_place` (and `construction_country` where printed), `construction_year`, `construction_station` |
| hull material | `vessel_hist` | `hull_material` |
| IMO number | `vessel_hist` | `imo_no` |
| torque index | `vessel_hist` | `power_indicator` |
| changes (to 2010) | `vessel_hist` | **`changes`, added** |
| district letters and number | `vessel_identification_hist` | `region_acronym`, `region_no` |
| call sign | `vessel_identification_hist` | `call_sign` |
| home port | `vessel_identification_hist` | `home_port`, and `home_port_no` where it maps |
| GRT, GT, NT | `vessel_measurement_hist` | `brutto_grt`, `brutto_weight_tons`, `netto_weight_tons` |
| registered length, length overall, breadth, depth | `vessel_measurement_hist` | `length`, `max_length`, `width`, `depth` |
| loaded draught (2004-2006) | `vessel_measurement_hist` | `draft` |
| light draught, weight (2004-2006) | `vessel_measurement_hist` | **`draft_light`, `weight`, added** |
| engine make, engine year, kW (to 2017) | `vessel_engines_hist` | `manufacturer_name`, `year`, `power`; and `vessel_hist.power_kw` |
| registrations list | `vessel_event` | `event`, `date`, GT |
| deregistrations list | `vessel_event` | `event`, `date`, `fate`, `fate_class`, GT |
| owner, owner's address, name prerogative | — | not read |

So four PDF fields are added as columns: the changes, light draught, weight, and the deregistration fate. Hreiðar's
`BRL gömul` maps to the schema's `brutto_grt_older`.

The schema keeps kW in two places: one row per engine in `vessel_engines_hist`, and `power_kw` on the hull. The PDF
prints one engine line, sometimes with "two main engines" under changes. Which of the two it is will be settled in
step 1, on the printed cases.

### 4.3 Which source answers, by period

This is the maintainer's rule, with the snapshots added:

| period | answers | after it, in order |
|---|---|---|
| to 2004-01-01 | Hreiðar's workbook | the kvoti and ufs histories (from 1992) |
| 2004-01-01 to 2022-01-01 | the PDFs | none: a dated source may place a change inside a year the editions bracket, but never changes its value |
| 2022-01-01 to 2023-12-19 | the dated sources: the ufs journals, `skipasaga` to 2023-12-07 | the siglo scrape (2022-12-28), mbl (2023-01), the `vessel` schema's back-filled rows |
| from 2023-12-19 | the `vessel` schema's own history | |
| MMSI, any time | `mmsi.parquet`'s windows | the lists it does not read (§3.7), MarineTraffic |

Where witnesses disagree, this precedence is the decision model's default rule (§6.2, D3). The model's other rules
can overrule it, and every other value stays in the evidence table and goes to the discrepancy table (§5).

### 4.4 What exists now

- `staging/skipaskra/annual_call_sign.parquet` becomes a view of `vessel_identification_hist`, so the key redo reads
  the same values.
- `vessel_sign`, `vessel_class`, `vessel_year` and `registry.R`'s `yh1`/`yh2` today read parts of this from Hreiðar
  and Oracle. Each is repointed in its own step, measured before and after.
- `mmsi.R` stays the MMSI archive. `vessel_mmsi_hist` takes its windows, and the lists it does not read go in as
  evidence or checks (ask d).
- The trail and the catch flow are not touched, except through those tables.

## 5. The checks: a discrepancy table

The checks write `curated/check/skipaskra_discrepancy.parquet`, one row per finding, with:
- `vid`, and the edition or the date;
- the variable;
- the values with their sources;
- the check;
- `kind`: `parse`, `edition`, `between_editions`, `witness` or `activity`;
- the outcome: `status`, `rule` and the value chosen (§6).

A page, `docs/skipaskra.qmd`, says what each check found and how each finding was settled, where an analyst reads it.
A check only finds. The decision model (§6) settles, and the printed value is always kept beside the chosen one.

### 5.1 Inside an edition

- **Totals:** the entries parsed equal the edition's stated totals of decked ships and open boats, or the missing
  numbers are listed.
- **The register against its own lists** (2004-2013): every number in both, with the same name, district number and
  call sign.
- **Recomputed aggregates:** the summaries and aggregates recomputed from the entries (counts and GT by type, age and
  engine make) agree with the printed ones.
- **The key's rules** (§2.2):
  - a call sign only at 15 m length overall or more;
  - the IMO check digit, and an IMO only above 24 m;
  - the GT and NT formulas below 15 m;
  - build year and engine year no later than the edition;
  - district letters, types of ship, hull materials and classification societies from the key's lists.
- **Uniqueness:** no call sign or district number on two hulls in one edition.

### 5.2 Between editions

- **Fixed fields:** a hull's build year, place, yard, IMO and hull material are the same in every edition.
- **Changes:** a dimension or tonnage that changes has a changes note (to 2010) or a known re-measurement.
- **Leaving and returning:** a hull that leaves and returns is in the deregistration list of the year it left and in
  the registration list of the year it came back. No deregistered hull is in a later edition, and no registered hull
  is missing from the next one.
- **Trend tables:** the trend tables agree across editions (2019's mislabel and 2016's GT, §2.6).

### 5.3 Against the witnesses

- **Hreiðar,** by number and year: name, district, home port, GT, kW, lengths and use; its fate against the
  deregistration text; its years against the editions.
- **The `vessel` schema:**
  - the 2022 edition and the two snapshots against the current tables, for hulls still registered;
  - its back-filled history against the editions, column by column. This measures directly what it missed, call
    signs first.
- **`skipasaga`, `skipaskra_breytingar` and the ufs journals:** a dated change inside a year the editions bracket, and
  changes the editions do not show.
- **`skipaskra_siglo` (2020):** kW, torque index, and seaworthiness certificates. Flag a hull that has had no valid
  certificate for years.
- **The two snapshots:** mbl and siglo against each other and against the 2022 edition; mbl's previous names and
  changes against the editions.
- **MMSI:** each list's holder against the register on the list's date (a deregistered or foreign hull holding an
  Icelandic MMSI). mbl's 26 MMSIs that are not in the archive. The 2023-01-15 list against the windows it would
  refine.
- **Licences against use:** a pleasure or passenger boat with a fishing licence, a fishing vessel without one, or a
  licence on a deregistered hull.

### 5.4 Against activity

- **Landings and logbook:**
  - a vid fishing before its first registration;
  - fishing after a deregistration date (sold abroad, scrapped, sank);
  - fishing while registered as a pleasure craft, without a licence;
  - a gear without its licence: Danish seine without `dragnot_leyfi`, lumpfish nets without `grasleppusaga`.
- **AIS**, only through what the feed broadcasts itself: ASTD's IMO and name against the register, and an Icelandic
  MMSI still heard after its hull was sold abroad. The STK key is no witness here. It was built with this register's
  call signs (decision 049), so its agreement would be circular. The same holds for the MarineTraffic sheets' mobile-id
  key.

## 6. The decision model: how a discrepancy is settled

The maintainer asked for a model of how discrepancies are fixed (2026-10-18). This section proposes one: an ordered set
of rules, each named, applied to every disputed value, with the deciding rule written on the row. The rules and their
order are a proposal (ask f).

### 6.1 Witnesses are counted by lineage, not by copy

Many sources are copies of one database, so agreement between copies proves only the copy. The model counts
**lineages**:

| lineage | its sources |
|---|---|
| the maritime register (Siglingastofnun, then Samgöngustofa) | the PDFs, `kvoti.skipaskra_siglo`, the siglo scrape, the `vessel` schema's hull, identification and measurement tables |
| the Directorate of Fisheries | `kvoti.skipasaga`, `skipaskra_breytingar`, ufs and its journals, `vessel_operational_hist`, the licence tables |
| Hreiðar's workbook | his compilation from Jón Björnsson's books and the register. For the register years it is partly a copy of the first lineage, so where its notes say it took a value from the register, it is not counted apart |
| mbl | the newspaper's register, curated by hand. Where it copied from, unknown |
| the radio authority | the Fjarskiptastofa MMSI lists and their Oracle snapshots, for the MMSI and call sign only |
| observation | AIS broadcasts, MarineTraffic, landings and logbook activity. These date and flag events, and never set a register value (D6) |

### 6.2 The rules, in order

The first rule that applies decides. Each writes its id into `rule`.

- **D0 Parse.** A value that fails a parse check is a reading fault, not a register fault: a split IMO, a cell from
  the next line, a five-digit number. It is re-read by the second route (the matrices, the almost-tidy table) or from
  the page, and fixed in the adapter's parser, not in the data. Only what survives D0 is a discrepancy.
- **D1 Review.** A person's decision in `overrides/skipaskra_reviewed.csv` (vid, table, column, window, value,
  reviewer, date, reason) outranks every rule below. This is AGENTS.md's cycle rule: a reviewed decision re-enters as
  an input.
- **D2 The register's own rules.** A value that breaks a rule the register itself states (§2.2) is set aside when
  another lineage gives a value that keeps the rule: an IMO with a failed check digit, a GT off the formula below
  15 m, a build year after the edition, a call sign on a boat under 15 m. Otherwise it stays, flagged `open`.
- **D3 Period precedence.** The source for the period gives the value (§4.3).
- **D4 Isolated deviation (a typo).** D4 overrules D3 when all three hold:
  - the period's source differs from every other lineage that speaks;
  - at least two other lineages agree with each other;
  - the value stands alone in its own series: in one edition only, with the same other value in the editions before
    and after.

  The consensus value is then taken, with `basis` reconstructed. An example is a build year printed once out of
  fifteen editions.
- **D5 Dating.** A change that falls between two editions takes its day from a dated source of any lineage: a
  registration or deregistration date, the ufs journals, `skipasaga`. That source must give the same values before and
  after the change. Otherwise the window stays `annual`. D5 sets dates, never values.
- **D6 Events against activity.** Activity never changes a register value. It does three things:
  - it can bound an event: the last landing before a deregistration, or AIS heard abroad after a sale;
  - it flags an impossibility: fishing before registration, after deregistration, or as a pleasure craft without a
    licence, which goes `open`;
  - a deregistration listed while the hull is still printed the next year, with no re-registration listed, goes
    `open` too.
- **D7 Open.** Anything left goes `open`, is listed on the docs page, and waits for D1.

A systematic defect, one cause behind many values (2019's mislabelled column, a whole edition's unit), is not settled
value by value. It becomes a declared correction in `curate/corrections/` and is applied before the rules.

### 6.3 How the model is judged

- The page counts the values each rule decided, by table and period.
- Each rule's error is measured where the truth can be had. For D2 and D4, a person checks a sample of 50 decisions
  against the page images and the other lineages. The share found wrong is the rule's error, and it is printed on the
  page. This answers the project's third aim, each path's error known, for the register.
- A rule whose measured error is high is demoted to `open` (D7) until it is fixed.

## 7. Personal data

- **Not read:**
  - the owner and the owner's address, on every entry;
  - the holders in the name-prerogative list;
  - mbl's operator and phone number;
  - the owners in the siglo scrape;
  - Hreiðar's operator and parent-company names and kennitala;
  - the `vessel` schema's `vessel_owners*` and `vessel_fishery*`;
  - kvoti's owner, operator, phone and kennitala columns;
  - the owner, operator and buyer ids in ufs;
  - the owner and place columns of the MMSI lists (`eigandi`, `stadur`).
- **How it is kept out:** the parser skips the owner lines by their position, and a test asserts that no staging
  column holds them.
- **Hreiðar's counts of people lost and rescued, and its notes on the fate,** are left out unless the maintainer wants
  them (ask b).
- **Where the data stay:** everything stays under `$FISHYDATA`. The repository carries code and counts only.

## 8. Steps

1. **The PDF adapters** in `sources/skipaskra/`: `register.R` and one script each for registrations,
   deregistrations, summaries, draught and the lists.
   - `register.R` needs three parsers. Layout A by column position, taken from each page's header. Layouts B and C
     with rows re-joined from word positions (`pdftotext -bbox-layout`).
   - Each script writes `staging/skipaskra/<table>.parquet`, with `edition`, `page`, the printed strings and the
     parsed values.

   **Check:**
   - every edition's entries equal its stated totals, or the gap is listed by number;
   - the matrices and the almost-tidy table agree with the parse field by field where they cover, and every
     disagreement is inspected;
   - 50 entries per layout are compared by eye with the page, recorded in the decision record.
2. **Adapters for the other sources outside Oracle**, each with no personal column:
   - Hreiðar's workbook: `sources/hreidar/vessel_year.R` writes `staging/hreidar/vessel_year.parquet`, keyed on `NR`;
   - the mbl and siglo scrapes;
   - the MarineTraffic sheets' Icelandic rows.

   **Check:** rows and numbers equal the sources'. `registry.R` and `vessel_year.R` stay unchanged until step 7.
3. **The evidence table**: every witness's values up to 2023-12-19, mapped to §4.2's columns, in one long table.
   **Check:** every staged value is in it once, and none of its rows has an empty source.
4. **The checks of §5**: the discrepancy table. **Check:** every check runs and its findings are counted.
5. **The decision model and the history**: §6's rules applied to the evidence, writing the `_hist` and added tables of
   §4 up to 2023-12-19 with their indicators, and `annual_call_sign` as a view of `vessel_identification_hist`.
   **Check:**
   - each `_hist` table's windows tile each hull's registered life without overlap;
   - every column of §4.2 is filled where its source prints it;
   - every disputed value has a `status`, and a `rule` when `resolved`;
   - the docs page counts each rule's decisions;
   - D2's and D4's samples of 50 are checked by a person, and their error rates printed;
   - `annual_call_sign` equals today's for 2007-2017, and the fixed parse of 88823e5 for 2018-2022, with every
     difference listed.
6. **The live part**: the `vessel` schema from 2023-12-19, and the MMSI windows, through the same model. **Check:**
   the rows with an open `valid_to` equal the `vessel` schema's current tables for every registered hull, column by
   column.
7. **Repoint the readers**: `vessel_sign`, `vessel_class`, `vessel_year` and `registry.R`, one at a time, with
   fingerprints before and after (`R/fingerprint.R`).

Steps 1-4 need no answer from the maintainer. Step 5 needs asks a and f.

## 9. Asks

a. **Where it builds.** Proposed: the history to 2023-12-19 in the `once` project, reviewed and frozen like the STK
   key that reads it, and the live part in the main project. The history is built from frozen raw files. This needs
   a decision record, since decision 075 limits `once` to its fixes, though `skipaskra` is a `once` target already.
   The alternative is to build all of it in the main project.
b. **Hreiðar's counts of people lost and rescued, and its notes on the fate.** Proposed: left out. The fate class and
   year are kept.
c. **Licences after July 2020.** Which schema holds them (the Directorate of Fisheries' current system), to dump?
   Until then `vessel_operational_hist` is the only source after 2020.
d. **The MMSI lists `mmsi.R` does not read.** Proposed: the 2023-01-15 list goes into `mmsi.R` (TODO 71); mbl's MMSIs
   and MarineTraffic's are checks, not sources, since neither is the authority's list.
e. **Editions outside 2004-2022.** Does Samgöngustofa publish 2023 and later? Is there a reason to scan the printed
   registers before 2004, rather than lean on Hreiðar?
f. **The decision model (§6).**
   - Are the lineages of §6.1 right? In particular, should Hreiðar count apart from the register in 2004-2021, and
     where does mbl copy from?
   - Is the rule order right? Should D4, the typo rule, overrule the PDF at all, or only flag?

   Proposed: as written, with D4 on, its error measured and printed.

## 10. Not in this plan

- A single wide table. A vid × year view can be derived from the tables later, if an analyst asks for one.
- Foreign vessels and SKB pleasure craft, which are not in the register (plans 016 and 021).
- 2006's image pages, which hold aggregates only. They are transcribed only if a check needs them.
- The fix to `annual_call_sign` itself: TODO 25 rebuilds it from 88823e5, and this plan replaces the table later.
