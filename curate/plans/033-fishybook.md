# 033 — fishybook: one Quarto book that consolidates the ICES groups' thinking, with ramb as its code

**status:** partly built — step 1 done for the seven reports from 2019 (decision 150): the reading map
`docs/ices_reports.yml`, the diagram tested and amended as version 3, §4 revised; asks a-f answered 2026-10-19 (§12):
`docs/` converted in place keeping its name, one edition at `~einarhj/fishybook` with the Icelandic part in it (no data
files, vessel data static), the title *From pings to effort and catch*; step 2 done (decision 151): `docs/` renders as a
book from the pages that exist; the 2013-2018 reports and steps 3-9 open · **2026-10-19** · **see:** TODO 94; plan 001 (the three-repo boundary: what `fishyweb` was to
be) and plan 002 (its port list), TODO 15 and 16; TODO 91 (ramb's pkgdown index); TODO 93 and decision 148 (the
workshops' data); `docs/one_flow.qmd`, `docs/wkssfgeo.qmd`

*Written by Claude (AI-assisted) from a discussion with the maintainer, 2026-10-19. §2 and the Quarto tests in §6
were measured that day, and the WGSFD reports were fetched that day at the maintainer's request; the rest is
proposal.*

## 1. The question

The maintainer, 2026-10-19, in order:

- There are several doc spaces: `fishycode/docs`, ramb's articles (`vignettes/articles`), `fishyweb`, and more.
  `fishyweb` is a mess. Turn it into a Quarto **book**, because a book needs no pre-planning.
- The book deals with most things. Only what it takes to run ramb stays in ramb.
- The main text is generic: we have this problem, how should we approach it, how should we code it. ramb's functions
  come in strongly. It covers why parquet and DuckDB, and works on example data. Technical matters (testing methods,
  approaches, robustness tests) go in appendices.
- It covers WKSSFGEO, WKSSFGEO2 and WGSFD year by year. It is the bootstrap guide to what ramb still lacks, and it
  details what ramb can do for you.
- It draws heavily on the `.md` documents in fishycode and ramb, and the decisions are a source of text too.
- **Answered:** the Icelandic data manual goes in the book too, as its own part.
- Use the WKSSFGEO and WGSFD reports profusely: **the readers are the members of those groups.** By using the
  various ICES text sources, the thinking is consolidated into one place, a book.

## 2. What exists (measured 2026-10-19)

**Doc spaces.**

| Space | State |
|---|---|
| `fishycode/docs` | Quarto website, 28 pages (23 `.qmd`, 5 `.md`), about 9,600 lines of real text. Still titled "Logbooks" (index: "Icelandic Fishing Logbooks"), `site-url` `heima.hafro.is/~einarhj/logbooks` (the old `logbooks` repo's), GitHub link to `logbooks`; its render list names `AGENTS_data_sources.md` and `AGENTS_output_schema.md`, which do not exist; `datacall-strategy`, `on_ais`, `qc_fs_afladagbok_2025` and `stk_data-inspection` are in no menu. Rendered output and `_freeze` are untracked. |
| `~/stasi/fishyweb` | Quarto website, 35 pages, **26 of them "To be filled in" outlines** (scaffolded 8240c6a). Real content in five: `data-sources/data-dictionary.qmd` (798 lines), `notes/whacky-positions.qmd` (330, untracked), `blog/posts/trawl-footprint` (293), `tutorials/ais_trip_tutorial.qmd` (154), `blog/posts/species-445` (123). No remote; 27b35ff unpushed (TODO 15). |
| ramb pkgdown | 7 articles, 1,086 lines (`flow`, `trips`, `sets`, `vessels`, `gear`, `catch`, `tools`), reference grouped by flow step, 21 example sets in `inst/extdata` (WKSSFGEO, WKSSFGEO2, Danish, CNR-IRBIM, Irish, Portuguese, survey tows). `vignettes/articles` is in `.Rbuildignore`, so R CMD check runs none of them. ramb is public on GitHub (HTTP 200, 2026-10-19), which answers that part of plan 001 §5. |
| The maintainer's published site | `heima.hafro.is/~einarhj/fishydata`, built from `~/stasi/fishyweb_2026-09-24` (f48c5c4; the live menus match, checked 2026-10-19): "Fishydata – the process", the fishtrawl footprint (page and slides), the data call QC report, "ICES VMS datacall: present → dplyr (→ duckdb)", and "Some rambling", 22 posts of 2025-01 to 2026-03 in `ramb/` (17 read data, plan 002). The maintainer's own work and a source of ideas. `fishydata_2024-2026` has the same menus. |
| Superseded | `logbooks` and `logbooks_tanked`, both claiming `/~einarhj/logbooks`. |

**The record links into `docs/` about 130 times** (`grammar.qmd` 35, `one_flow.qmd` 28, `merge.qmd` 13,
`ais_trail.qmd` 12, `ports.md` 9, …). Cited by nothing: `on_disk.qmd`, `ramb-list.qmd`, `notes_mid-to-vid.md`,
`notes_duckdbfs-vs-duckspatial.md`, `source-schemas.md`. `project-review.qmd` (762 lines, a review of the
predecessor `logbooks` repo) is cited 3 times. `docs/licence.qmd` is cited twice and does not exist (plan 029's page,
unwritten).

**The book's seed already exists.** `one_flow.qmd` (418 lines) has the grammar in brief, the flow step by step, "How
far down each kind of data gets" (six rows of data, from pings alone to hauls with times) and "What exists, and where":
a step table (8 rows) and the workshops' wish list (19 wishes, 9 of them "nowhere"). That is the guide to what ramb
lacks. Status is stated twice: the table is dated 2026-10-19, the colours of `figures/one_flow_status.svg` (hand-drawn,
no script writes it) 2026-10-09. `wkssfgeo.qmd` (292) summarises both workshop reports page by page; `grammar.qmd`
(459) is the vocabulary.

**The ICES texts** (in `$FISHYDATA/raw/external/ices/`, each with DOI, size and sha256 in `README-provenance.txt`):

| Text | Pages | Licence |
|---|---|---|
| WKSSFGEO, ICES Scientific Reports 4:10 (2022) | 66 | CC BY 4.0 |
| WKSSFGEO2, ICES Scientific Reports 5:49 (2023) | 110 | CC BY 4.0 |
| WGSFD 2013, 2014 (second interim), 2015, 2016 (interim), 2017 (interim), 2018, 2019 | 34, 106, 152, 246, 44, 81, 150 | reproduction only with permission: from ICES's General Secretary (2013-2017), or the copyright holder (2018-2019) |
| WGSFD 2022 (outputs of the 2021 meeting), WGSFDGOV 2023 (of 2022), WGSFD 2025a (of 2024), 2025b | 157, 15, 99, 45 | CC BY 4.0 (one WGSFDGOV figure © Crown Copyright / Marine Scotland) |

These are all the WGSFD reports in the ICES library (figshare, searched 2026-10-19). The group reported in multi-year
cycles, so no report is missing for 2020 or 2023 (maintainer). 1,305 pages in all.

**The WGSFD 2026 meeting folder**, `~/stasi/wgsfd2026_meeting-document` (a copy of the group's SharePoint): 109
files. Terms of reference 8; background 53, among them the EU request on methods to calculate fishing effort
(eu.2026.11), the WKSTGEM 2026 report, the WKGEOGRID resolution and a static-gear special request; working
documents 19 (subgroups Data quality, High resolution, Workflow); presentations 16; the report 1 (a recommendation
text); data 7. It is the group's working space, not published, and it sits outside `$FISHYDATA`.

**Text from the record:** 150 decisions (13,498 lines), 33 plans (11,630), `AGENTS.md`; in ramb, `AGENTS.md` (181)
and `distance-2026-10-12.qmd` (202).

## 3. What the book is for, and who reads it

**Purpose: consolidate.** The groups' thinking on effort and catch from tracks and records is spread over about
1,300 pages of reports across 13 years, two workshops, a meeting folder and several code repositories. The book brings
it into one place, ordered by the problem rather than by meeting, and ramb is that thinking as code.

**First reader: a member of WGSFD or WKSSFGEO.** They submit to the ICES VMS and logbook data call or work on
small-scale fisheries. They know their own data and the data call, and they use R to varying depths. Consequences:

- **Begin from the groups' own text.** Each chapter opens with what the reports say about its problem, by report and
  page: G1 and G2 for the two workshops, `WGSFD 2015` and so on. A member starts on familiar ground.
- **The groups' vocabulary is the book's** (VMS, AIS, logbook, landings, fishing trip, métier, c-square, fishing
  hours, kW-hours, swept area). This project's terms (`vid`, STK, port call, `basis`) are introduced once, in the
  grammar chapter, and mapped onto them. Plain terms, with codes in brackets.
- **By intent:** other groups' tools are described by what they set out to do, not by their defects.
- **Polite, and with some humour** (maintainer, 2026-10-19). Every workflow described here was written by colleagues
  who did the work, so it is described kindly. The book may smile: at the data, at the oddities of sea-going records,
  at itself. It never smiles at someone's expense.

**Second reader: an analyst using the Icelandic data**, for whom Part IV is the manual.

**The reports are template text** (maintainer, 2026-10-19). The reading map is the index: it finds every place the
groups treated a topic. The reports' own text, read at the cited pages, is the material each chapter is drafted from,
in the book's voice. The licence decides how close a draft may stay. A CC BY 4.0 report may be **adapted**, with
attribution ("adapted from ICES 2025, pp. 26-29, CC BY 4.0"). A report that may be reproduced only with permission
(WGSFD 2013-2019) is paraphrased and cited.

**Using the texts.** Quotes are short, marked and attributed. A figure is
reused only where its licence allows: the CC BY 4.0 reports with attribution, and never a third-party figure inside
them on that licence alone. The 2013-2019 WGSFD reports are paraphrased and cited, with no figure without ICES's
permission. The 2026 meeting folder informs the text, and the book cites it only once the group's report is published
(ask e).

## 4. The book's parts

**The maintainer's starting points** (2026-10-19). The first was open to review by the mining: "I will stand corrected
if your review is that the diagram is wrong", wrong as the centre of the book, and the diagram may be amended "if your
reading of the reports etc. says so". **Tested** (decision 150): it holds as the centre and is amended as version 3.

- **The flow diagram is the essence of the book.** It is the one presented at WGSFD 2026, now version 3
  (`docs/figures/one_flow_cascade_v3.svg`; versions 1 and 2 kept), with its text in `docs/one_flow.qmd`. Part II
  follows its rows, and each chapter's sections follow that row's boxes, the sources best first. The diagram and its
  text are the maintainer's own work, so they are used as they stand, before the group's 2026 report (ask e).
- **The official ICES data call flow runs through the book, not at its front** (the maintainer, correcting a first
  draft that opened with it). The flow is ICES's own workflow, `ices-eg/ICES-VMS-and-Logbook-Data-Call` (cloned at
  a844911): its blocks 0-3, its guidelines and its formats. It is not the centrepiece. It appears in each chapter where
  its way of handling that row is worth comparing (§5, item 4), politely and with some humour (§3).

**Revised from the recent reports** (decision 150). The six reports of 2013-2018 may revise it again when they are
read. Where a chapter below names its sources in the reports, the reading map (`docs/ices_reports.yml`) gives the
pages.

**Sources still to find** (maintainer, 2026-10-19: "there is plenty there, we just need to find it"; noted, not mined
yet). Mostly for Products (15), and in part for Validation (12):

- **the maintainer's own products** on the published site, `heima.hafro.is/~einarhj/fishydata` (the fishtrawl
  footprint, the data call QC report, the posts);
- **ICES's products from the data call**, on ICES's web pages;
- **WGSFD outputs that enter ICES advice**;
- **the publications** that came out of the WGSFD and WKSSFGEO collaborations. Much of the classification and
  validation work was published.

A chapter is listed in `_quarto.yml` only once its text exists (§8). The outline below is the only place a chapter
that is not yet written is named. "Seed" is the text it starts from; "sources" are what it distils.

**Part I — The problem, the flow and the tools**

1. *The problem*: effort and catch, fix by fix, from whatever data a country holds. Seed: `AGENTS.md` ("What this
   project is"), `one_flow.qmd`'s opening. Sources: WGSFD terms of reference; the EU request on methods to calculate
   fishing effort (2026).
2. *One flow*: the diagram, every ping accounted for. Seed: `one_flow.qmd` (its generic sections; the file keeps its
   path), version 3 of the diagram and its section "Version 3: what the groups' reports added", ramb's `flow` article.
3. *A grammar of sea-going data*. Seed: `grammar.qmd`. Sources: the reading map's vocabulary, so that the groups'
   terms and this project's are mapped.
4. *What ramb can do for you*: organised by the data the reader has, the rows of "How far down each kind of data
   gets", each cell naming the ramb functions that give it, and each row a runnable example on a bundled set that
   has that level of data. A row with no public set is a gap in ramb's example data. To write.
5. *Workflow and code: large tracks on a laptop* (parquet, DuckDB, lazy tables, one workflow). "Workflow and code" is the
   theme the reports return to most (four of seven). Seeds:
   - the published site's "ICES VMS datacall: present → dplyr (→ duckdb)" (`qmd/dataflow_dplyr_thenduckdb.qmd`), a
     friendly place for the data call to appear;
   - `notes_duckdbfs-vs-duckspatial.md`;
   - ramb's `flow` article (a data frame and a lazy table give the same result).

   Sources: decisions 073, 111, 144; the reading map's code trail (362 rows).

**Part II — The flow, row by row** (the rows of version 3; ramb's reference already groups this way)

6. *Vessels: linking feeds*. Seed: ramb's `vessels` article. Sources: decision 146.
7. *Pings: label, never drop, and the ping rate*: the flags, then the rate that sets how far down a track can go,
   interpolation and downsampling, devices and gaps. Seeds: fishyweb's `notes/whacky-positions.qmd` (its vessel
   tracks go to Part IV or become aggregates) and ramb's `tools` article. Sources: decision 067, TODO 88; the reports'
   polling and resolution rows.
8. *Trips: port calls, voyages, and trips from gaps*. Seed: ramb's `trips` article. Sources: plan 031, decisions
   058-065, 147, 149; trips from gaps and device power (WGSFD 2025a, WKSSFGEO, WKSSFGEO2).
9. *Records: windows, sets and hauls*. Seed: ramb's `sets` article. Sources: decisions 088, 091, 094.
10. *Gear: the sources, one vocabulary, several gears*. Seed: ramb's `gear` article. Sources: the reports' FAO,
    BENTHIS, DATSU and métier rows, and their multi-gear trips.
11. *Fishing*. Sources: decisions 093, 101; the reports' classification work. To write.
12. *Validation: how each answer is checked*. This is the band across the rows: labelled tracks, observers,
    electronic monitoring, gear sensors, and the metrics that come from them. Its tests in detail are appendix B.
    Sources: WKSSFGEO, WKSSFGEO2, WGSFD 2025a and 2025b. To write.
13. *Effort*: hours, kW-hours, pressure, static gear (soak, hauls) and fishing days. Sources: decision 099; the
    reports' effort rows. To write.
14. *Catch*. Seed: ramb's `catch` article. Sources: decisions 100, 102.
15. *Products: grids, the data call's delivery, and its checks*. Seed: `one_flow.qmd`'s "7. Products". Sources: the
    reports' c-squares, delivery and QC rows; `products/ices_vms_datacall/`; the material below. To write.

**Part III — The groups**

16. *WKSSFGEO (2021) and WKSSFGEO2 (2023)*. Seed: `wkssfgeo.qmd`; the reading map.
17. *WGSFD, 2013-2025*: what each report set out to do, and what it asked of methods. To write, from the reading map
    (the recent reports now, the old ones when read).
18. *WGSFD 2026*. Seed: `one_flow.qmd`'s "The diagram as presented at WGSFD 2026". Sources: the meeting folder.

Later meetings are appended, one chapter each.

**Part IV — The Icelandic data** (published with the rest, under ask c's rule; §6)

- *Sources*: `afli-tables`, `source-schemas`, `grammar_logbooks`, `skipaskra`, `stk_data-inspection`, `on_ais`,
  `ports`.
- *Building the data*: `pipeline`, `merge`, `afli-backentry`, `landings-match`, `landings_match2`, `ais_trail`,
  `output-schema`, `one_flow.qmd`'s "How fishycode runs this flow", fishyweb's data dictionary.
- *Defects and corrections*: `wacky-tracks_recovery`, `afli-dropped-stations`, `qc_fs_afladagbok_2025`,
  `convert-bugs`, fishyweb's species 445.
- *How the data are used* (maintainer, 2026-10-19: "demonstrate also how I use the data, but summarise only for the
  public"): the maintainer's analyses, each summarised in a few paragraphs with rendered figures and no data. Sources:
  the 22 posts of the published site (lumpfish, seaweed and kelp harvesting, trawl share of catch, jigger and trawl
  overlap, the effect of an area closure, a day at sea, door spread, trip overlap, spreading cash and fish, the
  post "Bækats datacall", and more), the fishtrawl footprint, species 445, `datacall-strategy`. Posts that are generic
  methods (gridding, DuckDB and H3, points in polygons, door spread, trip overlap, spreading catch) seed Part I and II
  chapters instead.

Each keeps its file path in `docs/`, so the record's links keep working. The parts are made in `_quarto.yml`, not by
moving files. `ports.md`, a standalone render until then, renders inside the book (step 2, decision 151).

**Appendices**

- A. *What ramb lacks*: the gap file in full (§9), with the wish lists.
- B. *Tests and robustness*: plan 031's bench (§3.9-3.10), the set finder (decision 146), the whack filter's
  evaluation, ramb's `distance-2026-10-12.qmd`. Public data, or aggregate scores only. This is where `AGENTS.md`'s
  third "done" criterion (each path's error, measured) becomes visible.
- C. *Pitfalls*: `TIMESTAMP WITH TIME ZONE`, nanoparquet's `col_select` (decision 144), dbplyr's negated `%in%`,
  DuckDB's spill after a killed job, one R session per target (decision 073).
- D. *The groups' reports by topic*: which report treats which step, with pages. A reading map of 13 years, built in
  step 6, and the source of the gap file's `asked` column.
- E. *The example data*: sources and licences, from ramb's `inst/extdata/data-dict.yaml`.

**Removed** (ask d): `on_disk.qmd` (macOS disk notes), `ramb-list.qmd` (a listing for a `ramb/` folder that
`docs/` lacks), `notes_mid-to-vid.md` (the mid → vid plan before plan 009), and `project-review.qmd` (the review of
the `logbooks` repo). Git keeps them, so the links in decisions 022, 069 and 081 still resolve at their commit.
fishyweb's 26 outlines are dropped.

## 5. Each chapter's shape

The planning worth doing is per chapter, not per book. A Part I-III chapter runs:

1. what the groups say (reports, pages);
2. the problem, in general terms;
3. what the data offer, along the information spectrum;
4. how others approach it, by intent, the ICES data call's workflow among them where it treats that row. Seed:
   `one_flow.qmd`'s "The ICES data call, seen through this flow" and its two figures, distributed over the chapters
   rather than kept as one;
5. the ramb code, on example data, runnable;
6. how well it works (→ appendix B);
7. what ramb does not do yet (from the gap file);
8. sources: the reports, decisions and plans it distils, linked (fishycode and ramb are public).

Every chapter carries the AI-use callout the docs pages already use, and a review line (who reviewed it and when),
so machine and human text stay distinguishable. Part IV chapters keep the manual's shape: the source, its defects,
what the build does, the columns and their basis.

## 6. One edition, and what may be published with it

**Answered (ask c, maintainer 2026-10-19):** all of Part IV may be public "as long as no data goes with it". What that
means:

- **Rendered figures and tables** from the data may be published.
- **Data files** may not: no parquet, CSV, RDS, GeoPackage or other extract is published with the book, or linked
  from it.
- **An interactive widget counts as data**, since it writes its points into the page (asked and answered the same
  day). Vessel-level data are shown as static figures. mapdeck, leaflet, plotly or DT are used only over aggregates or
  ramb's public example data. Only `stk_data-inspection.qmd` had such a map (mapdeck), static since step 2. The maintainer, the same
  day: an interactive part "could always center the topic around the public data already in the ramb package". So the
  interactive figure of a topic is drawn on ramb's example sets, and the Icelandic data show the same thing static.
- **Personal data never**, as `AGENTS.md` already rules for `docs/`: no kennitala, and none of the owners, addresses
  or phones a public source prints.

**Simulated data where `fishydata` is needed** (maintainer, 2026-10-19). When a concept needs data that only
`fishydata` holds, the book uses simulated data that convey the same concept. That may be as little as garbled vessel
ids and shifted date-times, or a track built from scratch, as in ramb's `whack_clean` review scenarios. Simulated data
are not data in ask c's sense, so they may be interactive. Positions may stay real: Claude raised that a track might be
recognised by its port and grounds, and the maintainer judged that "nobody will manage to link this lon-lat stuff to a
vessel; besides the AIS data is kind of already public". **Where simulated data live** (ramb's
example data, the book, or fishycode) is a decision of its own, taken downstream.

**The groups' anonymity rules are theirs, not the book's.** WGSFD's vessel anonymity rules (ICES 2019, cited in
WGSFDGOV 2023 p. 4) govern what ICES publishes as advice. fishycode, ramb and the book are not bound by them
(maintainer, 2026-10-19), as plan 001 §3 already says of the three-vessel rule. The book describes them as the groups'
practice for ICES products, and follows its own rule above.

So there is **one edition**: `docs/_quarto.yml` with all four parts, rendered on this machine from `$FISHYDATA`, and
only the rendered `_book/` is published. The internal edition first proposed, and the "locally only" answer to its half
of ask b, fall away.

*Kept for the record, not used:* Quarto 1.8.26 can build two editions from one source (measured in a scratch book). A
profile's `book: chapters:` are appended after the base chapters and before the appendices. `project: output-dir`
gives each edition its own folder. A cross-reference into a part missing from an edition renders as `WARN: …
Unable to resolve crossref`.

## 7. Where it lives: `fishycode/docs`, converted in place

**Answered (ask a):** `docs/` becomes the book (`project: type: book`), and **keeps its name**. A rename to `book/`
was weighed and refused: `docs/` is named 200 times in 69 files (32 decision records, 21 plans, 6 corrections,
`AGENTS.md`, `R/paths.R`), and renaming would mean rewriting them or leaving them dangling, for a label only. Why
here:

- Part IV must change in the same commit as the code that makes its columns.
- The ~130 links into `docs/` keep working.
- `check_bookkeeping()` can enforce the book's rules.
- fishycode is already public, so the source is no more exposed than `docs/` is today. `_book/` is added to
  `.gitignore` beside `_freeze/` and `_site/` (step 2).

`fishyweb` gives its five real pages to the book (step 4). Its unpushed commit and untracked note are settled, and it
is archived read-only, as `kaenugardr` was (decision 006). The open web page of plan 001 becomes the book. Plan 002 and
TODO 16 are closed or redirected in that commit.

*Not chosen:* `fishyweb` renamed `fishybook`, as its own repo (the maintainer's first framing). It would have been a
cleaner unit to publish, but Part IV would have left the code it documents.

## 8. Rules

- **No chapter before its text.** fishyweb's mess is a scaffold: menus first, then 26 outlines to fill them. A
  chapter enters `_quarto.yml` when it is written, and nowhere else (§10, check 2).
- **Record → book, one way.** A finding made while writing goes to a decision or TODO first, then into the chapter.
  The book never holds a fact the record does not.
- **Working notes are not sources.** Claude's memory files and side sessions' notes folders are scratch. Text worth
  a chapter reaches a decision first.
- **ramb's articles move; they are not copied.** Each is deleted from ramb, in a ramb commit, once its chapter is in
  the book. ramb keeps its README, the reference, one "Get started" article that runs the flow on one bundled set,
  and a link to the book. TODO 91 (the pkgdown index) folds in.
- **The groups' words first**, and project terms mapped in the grammar chapter (§3).
- **Pinned to ramb.** The book runs whatever ramb is installed, and `freeze: auto` does not re-run a chapter when
  ramb changes. After 2026-10-19's renames (decision 147), a frozen chapter would show the old names. So the preface
  prints `packageVersion("ramb")`, every chapter is re-rendered at a ramb release, and check 4 holds the names.

## 9. The gap file

`docs/ramb_gaps.yml`, one row per need:

| field | holds |
|---|---|
| `need` | what is asked, in the groups' words |
| `step` | vessel, ping, trip, record, gear, fishing, effort, catch, tools |
| `asked` | where: `G1 p. 19`, `G2 p. 20-21`, `WGSFD 2015 p. …`, `WGSFD 2026` |
| `status` | `ramb`, `fishymodel`, `fishycode`, `elsewhere`, `nowhere` |
| `ramb` | the functions that meet it |
| `elsewhere` | who else has it (vmstools, iapesca, CNR-IRBIM, GFW, …) |
| `record` | the decision or plan |

It is seeded from `one_flow.qmd`'s step table and wish list, and the `asked` column grows in step 6. From it come:

- appendix A;
- the "not yet in ramb" box at the end of each Part II chapter;
- the list by step in chapter 3;
- the two tables in `one_flow.qmd`.

The status diagram is hand-drawn. Whether its colours can also come from this file, or the diagram goes, is decided
in step 3.

## 10. Checks

`check_book()` in `R/`, called by `check_bookkeeping()`. It is pure base R and needs no `$FISHYDATA`:

1. every chapter listed in `_quarto.yml` exists, and every `.qmd`/`.md` in `docs/` is
   listed or on a short, named exclude list;
2. no listed chapter contains "To be filled in";
3. every chapter carries the AI-use callout and a review line;
4. every `rb_` name in a chapter's code or backticks is exported by the installed ramb (read from its `NAMESPACE`
   via `find.package()`; skipped with a note if ramb is absent);
5. every function in the gap file's `ramb` column exists in ramb, and a `nowhere` row whose named function now exists
   is flagged;
6. no chapter that reads `$FISHYDATA` loads an interactive widget library (mapdeck, leaflet, plotly, DT, reactable,
   ggiraph, mapview) unless it is on a short, named list of chapters that show only aggregates (ask c);
7. when `_book/` exists, it holds no data file (parquet, CSV, RDS, GeoPackage, FlatGeobuf, GeoJSON, Excel) (ask c).

## 11. Steps

**The reports come first** (maintainer, 2026-10-19). The WGSFD reports, on top of the WKSSFGEO reports already read,
should decide the book's main chapters. The outline in §4 was drawn from what fishycode and ramb hold, so it is
provisional until they are mined (§11.1). Step 2 only regroups existing pages and writes no text, so it may run
alongside step 1.

1. **Mine the ICES reports** (§11.1). The result is a reading map, a decision record of what was found, and §4
   revised from it, in one commit. *Done for the seven reports from 2019 (decision 150); the six of 2013-2018 later.*
2. **Convert `docs/` to a book in place, with no new text.** `type: book`, the four parts from existing pages; the
   title *From pings to effort and catch*, subtitle *Spatial fisheries data with ramb* (ask f); `site-url`
   `heima.hafro.is/~einarhj/fishybook` (ask b); the GitHub link to fishycode; drop the two phantom render entries;
   `_book/` in `.gitignore`. Remove the four leftover pages (ask d), and make `stk_data-inspection.qmd`'s mapdeck map
   static (ask c). The book renders. *Done (decision 151): three parts, since the flow's rows have no chapter yet;
   `ports.md` inside the book.*
3. **`check_book()`** (§10), wired into `check_bookkeeping()`.
4. **The gap file** (§9), seeded from `one_flow.qmd` and from the reading map's asks; `one_flow.qmd`'s two tables are
   then generated from it; the status diagram decided.
5. **fishyweb's five pages in**: the data dictionary, species 445 and trawl footprint to Part IV; whacky positions to
   chapter 7 (generic, public data) and Part IV (the tracks); the AIS trip tutorial checked against ramb 2026.10.19.2's
   names, then into chapter 8 or dropped. Settle 27b35ff and the untracked note; archive fishyweb; close or redirect
   plan 002 and TODO 16.
6. **ramb's seven articles into Part II**, one at a time, each deleted from ramb when its chapter lands; ramb's "Get
   started"; `distance-2026-10-12.qmd` to appendix B.
7. **The 2026 meeting folder** moved under `$FISHYDATA/raw/external/ices/` with its provenance, after a checksum check
   (ask e), and mined the same way. It is cited only once the group's 2026 report is published, and that report is
   mined when it is.
8. **New chapters, one at a time**, in the shape of §5 and in the order the revised outline gives. Each is its own
   commit and enters the book only when written.
9. **Publish** at `heima.hafro.is/~einarhj/fishybook` (ask b). The old 2026-09-01 grammar page at
   `/~einarhj/logbooks` gets a pointer to it.

### 11.1 Mining the ICES reports

**What is read.**

- The 11 WGSFD reports (2013-2025, 1,129 pages), in full.
- The two WKSSFGEO reports (176 pages), a second time. The first reading (decision 148, `docs/wkssfgeo.qmd`) asked
  what plan 031 and the flow's wish list needed. This one asks what the book needs.

**What each reading returns.** One fixed structure per report, so the reports can be compared and the map can be
merged:

- *the report*: its terms of reference and what it set out to do; the state of the ICES VMS and logbook data call
  that year (what was requested, at what resolution); its main outputs;
- *one row per topic it treats*:
  - `report`, `pages` (printed page numbers);
  - `topic`: a flow step, or anything else the report treats;
  - `kind`: method, definition, finding, recommendation or ask, data-call change, or product;
  - a summary of one or two sentences, in the reader's own paraphrase;
  - the group's terms for it;
- *the vocabulary*: the terms the group uses, and what each means there, for the grammar chapter's mapping (§3).
- *the code trail* (maintainer, 2026-10-19: "leave a summary trail … with respect to coding implementation aspects"):
  one row for each piece of code the report describes, uses or asks for. A row gives:
  - what it is: package, script, function, algorithm or workflow (vmstools, sfdSAR, icesVMS, the data call
    scripts, hackathon code, …);
  - its language, and where it lives as printed (repository or URL);
  - what it does, paraphrased;
  - the data formats it reads and writes (EFLALO, TACSAT, …);
  - computing or storage limits the report mentions;
  - pages.

  Claude then adds, outside the subagent, what ramb has for it (a function, a gap, or not ramb's business). The trail
  is `code:` in `docs/ices_reports.yml`, rendered as an appendix ("The groups' code, report by report"). Its gaps feed
  the gap file.

Which topics beyond the flow's steps the reports treat is the point of the reading. Their titles and the group's remit
suggest the following, but **this is not measured until they are read**:

- gridding and aggregation (c-squares);
- fishing intensity and footprint;
- pressure and impact on the seabed (swept-area ratio, sfdSAR);
- the quality of national submissions;
- governance and disclosure (WGSFDGOV);
- small-scale fisheries, AIS and high-resolution data.

**How.**

- **One subagent per report**, or per pair of short ones: about eight in all. Each reads the text of its PDF with page
  markers, so every row cites printed pages.
- **A pilot first:** WGSFD 2025b (45 pages, the latest). Its rows are checked against the PDF (pages cited, nothing
  invented) and the structure is fixed before the rest are read.
- **Copyright:** summaries are paraphrases, never copied passages, and a quoted term is only a term. The 2013-2019
  reports may be reproduced only with permission, so the map holds no text of theirs beyond terms.
- **Cost:** see the pilot below. The first guess here, a million tokens, was too low.

**The pilot** (WGSFD 2025b, 2026-10-19, measured):

- **Rows.** 108 topic rows and 50 vocabulary entries. Every row's pages agree with the markers.
- **Checker.** Run by Claude, outside the subagent (`check_rows.py`: pages, terms on the cited pages, 8-word copies).
  It flagged 4 rows: two citation lists, one layout-split term, and one copied run, which was reworded.
- **Hand check.** Eight rows were read against their pages; all faithful, and one detail was fixed.
- **The diagram test, first reading.** 52 rows are substantive (method, definition, finding), and 36 of them (69 %)
  land on a diagram row. Seabed pressure was placed under effort. Off the diagram are governance, coverage,
  computing, workflow and high-resolution data. No row lands on *trip*.
- **Cost.** 210k subagent tokens for 45 pages: the text is about 32k tokens, so the multi-turn reading costs about
  6.5 times the text. At that rate the other 1,260 pages would cost about 5.9M tokens.

**Changes for the run, from the pilot:**

- `kind` gains `decision` and `context`, which the pilot had to file as plan and product.
- A `box` field names the diagram's box for rows on a diagram row, from its labels (for example "haul with t1–t4",
  "period × area", "speed range of the gear", "several trips / weekly landing").
- The code trail is added.
- The pilot's 20 themes are given as the starting list.
- **Compact text** (the maintainer asked whether converting the PDFs to Markdown would cut the cost; measured
  2026-10-19). Markdown would not: it adds structure, not fewer words. The converters (pymupdf4llm, docling, marker)
  are not installed, and pandoc cannot read PDF. What does cut it is compacting the page-marked text
  (`compact_text.py`): the layout's padding collapsed (−30 %), and contents lines, numeric table bodies (captions
  stay), reference lists and participant lists dropped (a further −10 %). The 13 reports go from 2.99M to 1.79M
  characters (60 %), about 450k tokens, with every page marker kept, so the rows still cite pages and the checker
  still checks them against the full text.
- **Lean reading.** Each part is read in one read (at most 2,000 lines) and written in one write. Each subagent does
  no checking of its own, since the checker and a hand sample of each report do it. Summaries are one sentence, and
  vocabulary is limited to terms not already in the map. The pilot's output was 0.6 of its input, and output tokens
  are the dearest.
- **Parts.** 21 in all: WGSFD 2015 in three; 2016, 2018, 2019, 2022, 2025a, WKSSFGEO and WKSSFGEO2 in two; the rest
  whole. They are merged per report.
- **Estimate:** about 1.4-1.6M tokens, against about 5.9M at the pilot's depth.
- **Calibration** (WGSFD 2025b read again on the compact text with the lean prompt, 2026-10-19, measured):
  - **Rows.** 106 topic rows, 46 code rows and 25 vocabulary entries.
  - **Coverage.** It matches 106 of the pilot's 108 rows (98 %, by overlapping pages and a shared term). The one
    finding missed is a numeric table whose body the compact text drops.
  - **Diagram test.** 71 % of the substantive rows land on a diagram row, against 69 % in the pilot.
  - **Code trail.** 47 of 48 code rows name something found on their pages.
  - **Copying.** Four summaries copied an 8-word run. Two were lists of names; the other two were reworded.
  - **Boxes.** Many rows on a diagram row fit none of its boxes ("other"): 7 on ping, 4 on record, 4 on fishing,
    3 on effort. This is a first sign of what the diagram may lack.
  - **Cost.** 157k tokens in 8 minutes, against 210k in 13 for the pilot. That is only a quarter less, not the
    two-thirds estimated above. The output stayed at 0.8 of the input, since the code trail added what the shorter
    summaries saved, and each turn after the write re-sends text and output.
  - **What it means.** At 1.8 tokens a compact character, the six recent reports still to read would take about
    1.7M tokens and the six old ones about 1.4M. The estimate above (1.4-1.6M for all 13) was too low by half.
  - **The lean reading is the map for 2025b**, since it carries the new fields; the pilot is kept for comparison.
- **The run of the recent reports** (2026-10-19, measured). The maintainer noted the weekly usage had "hardly moved",
  so the stop rule was dropped and the reading kept at paragraph level, with 10 readers in parallel.
  - **Rows.** Seven reports (the six new ones and 2025b): 983 topic rows and 362 code rows. The checker flags 20 topic
    rows (2 %, mostly lists of names) and 3 code rows.
  - **Cost.** 1.36M tokens for the six new ones (1.49 per compact character), and 1.88M for all the mining so far.
  - **Granularity.** On WKSSFGEO 2022, a section-level reading gave 48 rows and 71 code rows for 155k tokens. The
    paragraph-level reading gave 147 and 87 for 199k: three times the rows for 28 % more.
  - **Diagram test.** 68 % of the 537 substantive rows land on a diagram row. Four themes outside it pass the
    criterion:
    - workflow and code (4 reports);
    - data quality of submissions (3);
    - c-squares and gridding (3);
    - the data call (3).

    Seabed pressure does not: the readers put swept area under effort.
  - **Where rows fit no box ("other").**
    - ping: ping rate and resolution, interpolation and downsampling, device types (VMS, iVMS, AIS A/B, green
      boxes), gaps and jamming;
    - fishing: validation (observers, electronic monitoring, expert-labelled tracks, gear sensors, metrics,
      misclassification modelled);
    - effort: fishing days and their definitions, static-gear effort (soak time, hauls), effort statistics compared
      across sources (FDI, GFW, the data call);
    - gear: code vocabularies (FAO, Benthis, DATSU, métier levels) and several gears in one trip;
    - trip: trips cut at gaps or by device power.
- **Verdict** (proposed by Claude, made on the maintainer's go; decision 150). The diagram holds as the centre: two-thirds of
  the groups' substantive work lands on its rows, and steadily so across reports. It is amended, not replaced:
  1. a closing row, "from fixes to products": gridding (c-squares), the data call's delivery, and quality control of
     submissions;
  2. a validation band across the rows, strongest on fishing: what checks each box's answer (labelled data,
     observers, electronic monitoring, sensors). It is also where `AGENTS.md`'s third "done" criterion shows;
  3. on the ping row, the ping rate made explicit, with interpolation and downsampling, since resolution decides which
     boxes below can be reached;
  4. on the effort row, fishing days and static-gear effort (soak, hauls) as boxes;
  5. on the gear row, code vocabularies and several gears in one trip;
  6. on the trip row, trips from gaps and device power.

  "Workflow and code" is the book's own Part I and ramb itself, not a diagram row.
- **The recent reports first** (maintainer, 2026-10-19: read "just the more recent reports to cut cost down", and the
  very old ones later). From 2019, where the ICES Scientific Reports series begins, there are 7 reports: WGSFD 2019,
  2022, 2025a and 2025b, WGSFDGOV 2023, WKSSFGEO and WKSSFGEO2. They come to about 1.0M compact characters, 56 % of
  the text: about 1.7M tokens for the six not yet read, at the calibration's rate. WGSFD 2013-2018 (6 reports, 0.79M characters) are read later, as a second
  run. The diagram test's threshold counts the reports read so far: three or more.
- **WGSFD 2025b is read again** with the lean prompt, which gives it the new fields. Comparing that reading with the
  pilot measures what the lean reading loses before the rest are read.

The page-marking script and the checker live in the session's scratch folder until the run is done; they move to
`curate/` or `dump/` with the reading map, which is decided then.

**The test of the diagram.** The mining decides whether the diagram holds as the book's centre, needs amending, or
should share the centre. It is measured on the merged rows:

- the share of topic rows that land on a diagram row (`step` not `none`), by report and by year;
- the themes of the rows that land on none, and how many reports treat each.

A theme outside the rows that recurs as method or definition in three or more of the reports read earns a place: a new
row or box in the diagram, or a main part of the book.

*Hypothesis (Claude, before reading; not a finding):* the reports spend much of their pages after the last row. That
covers c-squares and gridding, swept-area ratio and seabed impact, deliveries to OSPAR, HELCOM and the EU, the quality
of national submissions, and data governance. If that holds, the amendment is a closing row, "from fixes to products",
rather than a new centre. That fits `AGENTS.md`: the fixes are the product, and a map is one view of it.

The decision record states the verdict with these numbers, and the diagram (`one_flow_cascade_v2.svg`, with
`one_flow.qmd`) is amended in the same commit if it says so.

**Laid over the diagram.** A row's `step` is a row of the diagram. Once the pilot is checked, a `box` field may name
the source within the row (logbook, landings, track, …), so each chapter can say which boxes the groups worked on and
which they did not. The data call repository's guidelines and formats (about 600 lines) are read directly, for the
chapters where the data call appears, not by a subagent.

**The page-marked texts are kept** as the source the chapters are drafted from, beside the PDFs in
`$FISHYDATA/raw/external/ices/` (regenerable with `mark_pages.sh`, but kept so that a chapter's pages can be read without
redoing the extraction).

**Where the results go.** Record → book, one way (§8):

- **`docs/ices_reports.yml`**, the reading map. It holds the report-level fields and the topic rows above. It is the
  source of appendix D, of the gap file's `asked` column, and of each chapter's "what the groups say" (§5). Its
  header states that it was read by AI subagents, spot-checked against the PDFs, and not reviewed line by line.
- **A decision record**, numbered when it is written: what the reports treat, how often and when, and what that
  changes in the book.
- **§4 of this plan revised** from it, in the same commit. The parts and chapters follow what the groups have
  actually worked on, not only what ramb and fishycode hold.

## 12. Asks, answered by the maintainer on 2026-10-19

- a. **Where the book lives:** `fishycode/docs`, converted in place. Asked whether to rename it `book/`, the
  maintainer noted a rename "may create an issue on its own", and chose to keep `docs/` once its cost was measured
  (§7).
- b. **URL:** `heima.hafro.is/~einarhj/fishybook`. The internal edition was to be served "locally only", but ask c
  made it unnecessary.
- c. **What may be published:** all of Part IV, "as long as no data goes with it": rendered figures and tables, no
  data files. Asked further: an interactive widget counts as data, so vessel-level data are shown as static figures
  (§6).
- d. **The four leftover pages:** removed, with git keeping them.
- e. **The 2026 meeting folder:** moved under `$FISHYDATA/raw/external/ices/` with provenance, and cited only once the
  group's 2026 report is published. That covers others' working documents. The flow diagram and its text, presented
  at WGSFD 2026, are the maintainer's own and are used now (maintainer, the same day).
- f. **Title:** *From pings to effort and catch*, subtitle *Spatial fisheries data with ramb*. "fishybook" stays the
  working name and the URL.

**Still open, by the maintainer's choice:** g. where simulated data live (§6), decided downstream, when the first
chapter needs them.

## 13. Measured and assumed

**Measured** (by Claude, 2026-10-19):

- §2: the doc spaces, line and link counts, the licences printed in the reports, the meeting folder's contents, and
  ramb's visibility;
- §6: the profile behaviour, on a scratch book with Quarto 1.8.26, and that only one docs page has an interactive
  map;
- §7: the cost of a rename.

**Assumed:**

- the book's structure (§4), provisional until the reports are mined (§11.1), and each chapter's shape (§5);
- that a member of the groups reads the book in the order given;
- what the writing will cost.
