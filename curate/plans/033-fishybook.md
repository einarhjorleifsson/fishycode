# 033 — fishybook: one Quarto book that consolidates the ICES groups' thinking, with ramb as its code

**status:** proposal · **2026-10-19** · **see:** TODO 94; plan 001 (the three-repo boundary: what `fishyweb` was to
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
| Superseded | `logbooks`, `logbooks_tanked`, `fishydata_2024-2026`, `fishyweb_2026-09-24` (22 posts of 2025 in `ramb/`). Two claim `/~einarhj/logbooks` and two `/~einarhj/fishydata`. |

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

**Second reader: an analyst using the Icelandic data**, for whom Part IV is the manual.

**Using the texts.** The book paraphrases and cites by page. Quotes are short, marked and attributed. A figure is
reused only where its licence allows: the CC BY 4.0 reports with attribution, and never a third-party figure inside
them on that licence alone. The 2013-2019 WGSFD reports are paraphrased and cited, with no figure without ICES's
permission. The 2026 meeting folder informs the text, but the public edition cites only what is published (ask e).

## 4. The book's parts

A chapter is listed in `_quarto.yml` only once its text exists (§8). The outline below is the only place a chapter
that is not yet written is named. "Seed" is the text it starts from; "sources" are what it distils.

**Part I — The problem and the tools**

1. *The problem*: effort and catch, fix by fix. Seed: `AGENTS.md` ("What this project is"), `one_flow.qmd`'s
   opening. Sources: WGSFD terms of reference; the EU request on methods to calculate fishing effort (2026).
2. *A grammar of sea-going data*. Seed: `grammar.qmd`.
3. *What ramb can do for you*: organised by the data the reader has, the rows of "How far down each kind of data
   gets", each cell naming the ramb functions that give it, and each row a runnable example on a bundled set that
   has that level of data. A row with no public set is a gap in ramb's example data. To write.
4. *Large tracks on a laptop: parquet, DuckDB, lazy tables*. Seed: `notes_duckdbfs-vs-duckspatial.md`; ramb's
   `flow` article (a data frame and a lazy table give the same result). Sources: decisions 073, 111, 144.

**Part II — The flow, step by step** (the steps and their order are given: ramb's reference already groups this way)

5. *One flow*. Seed: `one_flow.qmd` (its generic sections; the file keeps its path), ramb's `flow` article.
6. *Vessels: linking feeds*. Seed: ramb's `vessels` article. Sources: decision 146.
7. *Pings: label, never drop*. Seed: fishyweb's `notes/whacky-positions.qmd` (its vessel tracks go to Part IV or
   become aggregates), ramb's `tools` article. Sources: decision 067, TODO 88.
8. *Trips: port calls and voyages*. Seed: ramb's `trips` article. Sources: plan 031, decisions 058-065, 147, 149.
9. *Records: windows, sets and hauls*. Seed: ramb's `sets` article. Sources: decisions 088, 091, 094.
10. *Gear*. Seed: ramb's `gear` article.
11. *Fishing*. Sources: decisions 093, 101. To write.
12. *Effort*. Sources: decision 099. To write.
13. *Catch*. Seed: ramb's `catch` article. Sources: decisions 100, 102.

**Part III — The groups**

14. *WKSSFGEO (2021) and WKSSFGEO2 (2023)*. Seed: `wkssfgeo.qmd`.
15. *WGSFD, 2013-2025*: what each report set out to do, and what it asked of methods. To write, from the 11 reports.
16. *WGSFD 2026*. Seed: `one_flow.qmd`'s "The diagram as presented at WGSFD 2026". Sources: the meeting folder.
17. *The ICES VMS and logbook data call, seen through the flow*. Seed: `one_flow.qmd`'s section of that name.

Later meetings are appended, one chapter each.

**Part IV — The Icelandic data** (the internal edition only, until TODO 15 decides otherwise; §6)

- *Sources*: `afli-tables`, `source-schemas`, `grammar_logbooks`, `skipaskra`, `stk_data-inspection`, `on_ais`,
  `ports`.
- *Building the data*: `pipeline`, `merge`, `afli-backentry`, `landings-match`, `landings_match2`, `ais_trail`,
  `output-schema`, `one_flow.qmd`'s "How fishycode runs this flow", fishyweb's data dictionary.
- *Defects and corrections*: `wacky-tracks_recovery`, `afli-dropped-stations`, `qc_fs_afladagbok_2025`,
  `convert-bugs`, fishyweb's species 445.
- *Uses*: `datacall-strategy`, fishyweb's trawl footprint.

Each keeps its file path in `docs/`, so the record's links keep working. The parts are made in `_quarto.yml`, not by
moving files. `ports.md` is a standalone render today: step 1 decides whether it renders inside the book.

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

**Out of the book**: `on_disk.qmd` (macOS disk notes), `ramb-list.qmd` (8 lines), `notes_mid-to-vid.md`, and
`project-review.qmd`. Where they go is ask d. fishyweb's 26 outlines are dropped.

## 5. Each chapter's shape

The planning worth doing is per chapter, not per book. A Part I-III chapter runs:

1. what the groups say (reports, pages);
2. the problem, in general terms;
3. what the data offer, along the information spectrum;
4. how others approach it, by intent;
5. the ramb code, on example data, runnable;
6. how well it works (→ appendix B);
7. what ramb does not do yet (from the gap file);
8. sources: the reports, decisions and plans it distils, linked (fishycode and ramb are public).

Every chapter carries the AI-use callout the docs pages already use, and a review line (who reviewed it and when),
so machine and human text stay distinguishable. Part IV chapters keep the manual's shape: the source, its defects,
what the build does, the columns and their basis.

## 6. Two editions from one source (measured with Quarto 1.8.26, in a scratch book)

- `docs/_quarto.yml` is the **public edition**: Parts I-III and the appendices.
- `docs/_quarto-internal.yml` lists **only Part IV**, and `project: output-dir: _book-internal`.

Measured: a profile's `book: chapters:` are **appended** to the base list, and land after the base chapters and before
the appendices. The generic chapters therefore keep their numbers in both editions. Each edition renders to its own
folder, and the public folder holds no Part IV page. A cross-reference from a base chapter into Part IV renders in the
public edition as `WARN: … Unable to resolve crossref`.

Rules:

- Parts I-III and the appendices never link or cross-refer into Part IV. Part IV may refer back.
- No kennitala in either edition (`AGENTS.md`: never in `docs/`).
- A Part IV chapter moves into the public edition only under TODO 15's rule (ask c).
- **Assumed, not tested:** that an Icelandic example inside a generic chapter can be kept out of the public output
  with `::: {.content-visible when-profile="internal"}`. Its code still runs on a public render, which needs
  `$FISHYDATA`. Prefer Part IV for such examples.

## 7. Where it lives: `fishycode/docs`, converted in place

**Proposed:** `docs/` becomes the book (`project: type: book`), and its directory keeps its name. Why here:

- Part IV must change in the same commit as the code that makes its columns.
- The ~130 links into `docs/` keep working.
- `check_bookkeeping()` can enforce the book's rules.
- fishycode is already public, so the source is no more exposed than `docs/` is today. `_book*/` is added to
  `.gitignore` (today it ignores `_freeze/` and `_site/`).

`fishyweb` gives its five real pages to the book (step 4). Its unpushed commit and untracked note are settled, and it
is archived read-only, as `kaenugardr` was (decision 006). The open web page of plan 001 becomes the book's public
edition. Plans 001 and 002 and TODO 15 and 16 are updated in that commit.

**Alternative** (the maintainer's first framing): `fishyweb` renamed `fishybook`, as its own repo. That is a
cleaner unit to publish, but Part IV would leave the code it documents and its links would break. This is ask a.

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

1. every chapter listed in `_quarto.yml` and `_quarto-internal.yml` exists, and every `.qmd`/`.md` in `docs/` is
   listed or on a short, named exclude list;
2. no listed chapter contains "To be filled in";
3. every chapter carries the AI-use callout and a review line;
4. every `rb_` name in a chapter's code or backticks is exported by the installed ramb (read from its `NAMESPACE`
   via `find.package()`; skipped with a note if ramb is absent);
5. every function in the gap file's `ramb` column exists in ramb, and a `nowhere` row whose named function now exists
   is flagged;
6. no Part I-III or appendix file links or cross-refers to a Part IV file or label (a static scan, cheaper than
   rendering).

## 11. Steps

1. **Convert `docs/` to a book in place, with no new text.** `type: book`, the parts from existing pages, Part IV in
   the internal profile; fix the title, URL, GitHub link, the two phantom render entries and the four pages in no
   menu; `_book*/` in `.gitignore`. Both editions render. The pages out of the book go where ask d says.
2. **`check_book()`** (§10), wired into `check_bookkeeping()`.
3. **The gap file** (§9), seeded from `one_flow.qmd`, whose two tables are then generated from it; the status
   diagram decided.
4. **fishyweb's five pages in**: the data dictionary, species 445 and trawl footprint to Part IV; whacky positions to
   chapter 7 (generic, public data) and Part IV (the tracks); the AIS trip tutorial checked against ramb 2026.10.19.2's
   names, then into chapter 8 or dropped. Settle 27b35ff and the untracked note; archive fishyweb; update plans 001,
   002 and TODO 15, 16.
5. **ramb's seven articles into Part II**, one at a time, each deleted from ramb when its chapter lands; ramb's "Get
   started"; `distance-2026-10-12.qmd` to appendix B.
6. **The ICES texts indexed**: appendix D, by step and page; the `asked` column filled. The meeting folder moved under
   `$FISHYDATA/raw/external/ices/` with its provenance, if the maintainer agrees (ask e).
7. **New chapters, one at a time**, in the shape of §5: 1, 3, 4, 11, 12, 15, 16 first. Each is its own commit and
   enters the book only when written.
8. **Publish the public edition** (ask b). It replaces the old 2026-09-01 grammar page at `/~einarhj/logbooks`.

## 12. Asks (needs: maintainer)

- a. Where the book lives: `fishycode/docs` converted in place (proposed), or its own repo.
- b. The public edition's URL, and where the internal edition is served (only locally, or on an internal server).
- c. Which Part IV chapters may go into the public edition: TODO 15's rule (the minimum cell, the table allowlist).
  Until then, none.
- d. Where `on_disk.qmd`, `ramb-list.qmd`, `notes_mid-to-vid.md` and `project-review.qmd` go: the Trash, or kept
  outside the book.
- e. Whether the 2026 meeting folder moves under `$FISHYDATA/raw/external/ices/`, and whether its working documents
  may be cited in the public edition before the group's report is published.
- f. The book's title.

## 13. Measured and assumed

**Measured** (by Claude, 2026-10-19):

- §2: the doc spaces, line and link counts, the licences printed in the reports, the meeting folder's contents, and
  ramb's visibility;
- §6: the profile behaviour, on a scratch book with Quarto 1.8.26.

**Assumed:**

- the book's structure (§4) and each chapter's shape (§5);
- that `when-profile` blocks keep internal examples out of the public output;
- that a member of the groups reads the book in the order given;
- what the writing will cost.
