# 150 — Seven ICES reports mined; the flow diagram holds as the book's centre and is amended (plan 033 §11.1)

*2026-10-19.*

- **Who chose.** The choices are the maintainer's, made in chat the same day. That covers mining the reports first,
  the recent ones before the old, at paragraph depth once the weekly usage showed the cost was no constraint, and the
  go to amend the diagram: "Go ahead: write the decision record, amend the diagram …".
- **Who did the work.** AI subagents (Claude, Anthropic) read the reports; Claude checked their rows, drew the
  diagram, and wrote the text and this record. None of it has been reviewed line by line by a person.
- **What it carries out.** Step 1 of plan 033, for the reports from 2019 on. The six of 2013-2018 are still to read.

## Decided (the maintainer)

- **The reports are mined before the book's outline is used**, because the WGSFD and WKSSFGEO reports should decide its
  main chapters (plan 033 §11).
- **The diagram is open to the test.** "I will stand corrected if your review is that the diagram is wrong" as the
  centre, and it may be amended "if your reading of the reports etc. says so" (plan 033 §4).
- **Recent reports first, old ones later**, to cut cost. Then the cost turned out not to matter ("the weekly token
  usage has hardly moved at all"), so the reading stayed at paragraph level and ran in parallel.
- **The reports are template text for the book.** The map is the index. The chapters are drafted from the cited pages:
  adapted where the licence is CC BY 4.0, paraphrased where it asks for permission (plan 033 §3).
- **The amendments below are made**, on the go above.

## Found (measured)

**What was read.** Seven reports, 642 pages: WGSFD 2019, 2022 (2021 meeting), 2025a (2024 meeting) and 2025b;
WGSFDGOV 2023; WKSSFGEO 2022; WKSSFGEO2 2023. They were fetched the same day from the ICES library, which holds 11
WGSFD reports in all, since the group reported in multi-year cycles.

**The rows.** 983 topic rows and 362 code rows.
- The checker flags 20 topic rows (2 %, mostly lists of names) and 3 code rows.
- WGSFD 2025b was also checked by hand, 8 rows.
- A paragraph-level reading of WKSSFGEO 2022 gave three times the rows of a section-level one (147 and 48) for 28 %
  more tokens.

**Cost.**
- 1.36M subagent tokens for the six reports read in the run, 1.49 per character of compact text.
- 1.88M for all the mining, with the pilot and two tests.
- A pilot at full depth would have cost about 5.9M. Compacting the text (60 % of the layout text) and reading each
  part in one read and one write did most of the saving. Converting to Markdown would not have helped.

**The diagram test.**
- **On the rows.** 370 of the 537 rows that set out a method, a definition or a finding (68 %) fall on a row of the
  diagram, over all seven; it was 69-71 % on WGSFD 2025b alone, read twice.
- **Off the rows.** Four themes recur there as a method or definition in three or more reports:
  - workflow and code (4);
  - data quality of submissions (3);
  - c-squares and gridding (3);
  - the data call (3).
- **Seabed pressure** does not: the readers put swept area under effort.

**Rows that fit no box of their row.**

| Row | Rows in no box | What they are |
|---|---|---|
| ping | 56 | ping rate and temporal resolution, polling rules, interpolation and downsampling, device types (VMS, iVMS, AIS A/B, green boxes), gaps and jamming |
| fishing | 34 | validation: observers, electronic monitoring, expert-labelled tracks, gear sensors, metrics, misclassification modelled |
| effort | 32 | fishing days and their definitions, static-gear effort (soak, hauls, net length), effort statistics compared across sources (FDI, GFW, the data call) |
| gear | 19 | code vocabularies (FAO, BENTHIS, DATSU, métier levels), several gears in one trip |
| trip | 6 | trips cut at gaps, or by the device's power |

## Built

- **The verdict.** The diagram holds as the centre and is amended, not replaced.
  `docs/figures/one_flow_cascade_v3.svg` adds six things to version 2, which is kept:
  1. a closing row, **7. Products**: grid (c-squares), the data call's delivery, and the quality of submissions;
  2. a **validation band** down the side, from trip to catch: labelled tracks, observers, EM, gear sensors;
  3. a **ping-rate band** under the ping flags: interpolate or downsample to a regular series, with gaps and the
     device kept;
  4. on **effort**, boxes for static gear (soak, hauls) and fishing days (days at sea);
  5. a **gear band**: codes mapped to one vocabulary (FAO, DATSU, métier), and a trip may use several gears;
  6. on **trip**, a box for gaps and device power.

  "Workflow and code" passes the test, but it is the book's own tools chapter and ramb itself, not a row.
- **`docs/one_flow.qmd`** shows version 3 and carries its text. That covers the ping rate, trips from gaps, the gear
  vocabulary, validation, static-gear effort and fishing days, each cited by report and page, plus a new section
  "7. Products". It also has a products row in "What exists, and where", a section "Version 3: what the groups'
  reports added", and the reports in its sources.
- **`docs/ices_reports.yml`**, the reading map: 7 reports, 983 topic rows, 362 code rows, with a header that states
  the AI use and the checks.
- **`dump/ices/`**, the tools:
  - `mark_pages.sh` (page-marked text), `compact_text.py` and `split_parts.py`;
  - the readers' instructions, `lean_instructions.md`;
  - `merge_parts.R`, `check_rows.py` and `check_all.py`.
- **`$FISHYDATA/raw/external/ices/text/`**: the page-marked and compact texts of all 13 reports, with a provenance
  entry, so that chapters are drafted from the cited pages.
- **Plan 033 §4** revised to the amended diagram (see the plan).

## Not done

- **The six reports of 2013-2018.** Their texts are ready. They reproduce only with permission, so they are
  paraphrased.
- **`docs/figures/one_flow_status.svg`** colours the version-2 boxes only. Whether its colours come from the gap file
  is plan 033 step 4. *Amended 2026-10-27:* redrawn by hand on the version-3 boxes, at the maintainer's request; the
  gap file is still step 4.
- **The WGSFD 2026 meeting folder**, to be moved and mined (plan 033 step 7).
- **Themes the readers coined twice** ("vmes" and "vulnerable marine ecosystems") are left as written. They are
  merged when the old reports are read.
