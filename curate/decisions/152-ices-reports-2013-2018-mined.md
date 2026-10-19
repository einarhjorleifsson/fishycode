# 152 — The six WGSFD reports of 2013-2018 mined; the version-3 diagram holds over all 13 (plan 033 §11.1)

*2026-10-19.*

- **Who chose.** The maintainer chose to read the old reports after the recent ones, with cost no constraint
  (decision 150). The theme merges, the term fixes and the verdict below are Claude's, proposed and not yet reviewed.
- **Who did the work.** AI subagents (Claude, Anthropic) read the reports, one per part. Claude, in a side session,
  merged and checked their rows, hand-checked 24 of them, ran the diagram test, and wrote this record. None of it has
  been reviewed line by line by a person.
- **What it carries out.** Step 1 of plan 033 for the six reports of 2013-2018. All 13 reports are now read.

## Found (measured)

**What was read.** WGSFD 2013, 2014, 2015, 2016, 2017 and 2018: 663 pages, 0.78M characters of compact text, in nine
parts (2015, 2016 and 2018 in two). The method was decision 150's, unchanged (`dump/ices/README.md`).

**The licences, as printed.** 2013-2017 ask that permission to reproduce be sought from the ICES General Secretary.
2018 prints the same statement as 2019: reuse for non-commercial purposes with the recommended citation, other
reproduction through the General Secretary, so it carries 2019's licence line in the map. The readers were told to
paraphrase strictly either way, and the map holds no text of these reports beyond terms.

**The rows.**

| Report | Pages | Topic rows | Code rows | Vocabulary |
|---|---|---|---|---|
| WGSFD 2013 | 34 | 76 | 18 | 25 |
| WGSFD 2014 | 106 | 104 | 23 | 25 |
| WGSFD 2015 | 152 | 216 | 39 | 50 |
| WGSFD 2016 | 246 | 169 | 29 | 49 |
| WGSFD 2017 | 44 | 77 | 12 | 25 |
| WGSFD 2018 | 81 | 152 | 28 | 45 |
| **all six** | 663 | 794 | 149 | 219 |

- **The checker** flagged 15 summaries that copied an 8-word run, mostly lists of fields, gears or regions. All were
  reworded. It also flagged 13 rows whose term was split on the page by hyphenation, a table layout or a plural. Their
  terms were reset from the page; the rows themselves were faithful. All six now pass with no flag, and every code
  row names something found on its pages.
- **The hand check.** Four rows of each report, 24 in all, were read against their pages. All are faithful. One row
  (2018, logbook duties by length) follows the source's own muddle over which length limit applies.
- **A fault in the checker, fixed.** A row with a single term comes out of the merge as a string, and
  `check_rows.py` iterated its letters, so the term check passed for every single-term row, here and in decision 150.
  The fix is one line. In the seven reports read before, it exposed five rows of WGSFD 2025a with layout-split terms.
  Their terms are now taken from the page, and those reports still have decision 150's 20 flagged rows.

**Cost.** 1.22M subagent tokens for the six, 1.56 per compact character (1.49 for the recent six; the plan's estimate
was about 1.4M). That makes 3.10M for all the mining. Each part took one read and one write.

| Part | Compact characters | Tokens | Tokens a character | Minutes |
|---|---|---|---|---|
| 2013 | 51,996 | 111,861 | 2.15 | 3.3 |
| 2014 | 115,519 | 162,067 | 1.40 | 6.9 |
| 2015, 1 of 2 | 125,191 | 179,272 | 1.43 | 8.3 |
| 2015, 2 of 2 | 110,373 | 156,452 | 1.42 | 3.4 |
| 2016, 1 of 2 | 101,964 | 146,860 | 1.44 | 5.5 |
| 2016, 2 of 2 | 89,631 | 125,150 | 1.40 | 2.9 |
| 2017 | 62,866 | 116,571 | 1.85 | 3.5 |
| 2018, 1 of 2 | 67,135 | 115,683 | 1.72 | 3.6 |
| 2018, 2 of 2 | 60,073 | 110,010 | 1.83 | 3.1 |
| **all** | 784,748 | 1,223,926 | 1.56 | |

A short part costs more a character, since the instructions and the written map weigh more against the text.

**Themes coined twice, merged across all 13.** Each pair names one thing:

- "vmes" and "vulnerable marine ecosystems";
- "pressure indicators" (2013) and "indicators" (2014, 2016), both DCF indicators 5-7, now "dcf indicators";
- "static gears" (2019, the effort indicators for static gear), now "effort indicators";
- "sensors", now "validation" (WKSSFGEO 2022, gear sensors used to validate).

Kept apart, since each names something distinct: "benthic habitat indicators" (OSPAR BH1-BH3), "tracking devices",
"ping rate" and "spatial modelling".

**The diagram test over 13 reports** (the criterion of plan 033 §11.1).

- **On the rows.** 614 of the 949 rows that set out a method, a definition or a finding (64 %) fall on a row of the
  diagram. That is 244 of 412 (59 %) for 2013-2018, and 370 of 537 (68 %) for the seven read before.
- **By report, the share follows the remit, not the year.**
  - 46-55 %: 2013, 2015, 2016, 2019 and 2022, the years of the OSPAR and HELCOM requests and the spatial-planning
    terms of reference;
  - 63 %: 2014;
  - 69-75 %: 2017, 2018, 2025a and 2025b;
  - 85-90 %: the two workshops.
- **Off the rows.** Ten themes have method or definition rows in three or more reports: workflow and code (8),
  c-squares and gridding (7), data quality of submissions (7), seabed pressure and impact (6), data access and
  governance (4), marine spatial planning (4), dcf indicators (3), data coverage (3), high-resolution data (3), and the
  data call (3). Four passed before and are in version 3 (the products row) or the book (chapter 5). Six pass for the
  first time:

  | Theme | Reports | What its off-diagram method and definition rows are |
  |---|---|---|
  | seabed pressure and impact | 2013, 2015-2018, 2025a | DCF indicators 5-7 (2013, 2015); habitat impact: the BH3 components, sensitivity, an impact matrix, population-dynamic and longevity approaches (2015, 2016); classing skewed abrasion values for maps (2015, 2016); effort by depth and buffers round VME records (2017, 2018, 2025a) |
  | dcf indicators | 2013, 2014, 2016 | extent (positive area), aggregation (spreading area, Gini index, the top share of intensity), untrawled area |
  | data access and governance | 2013, 2017, WGSFDGOV 2023, 2025a | three of the four are disclosure rules: métiers with fewer than six vessels aggregated, confidentiality in stress-level analysis, vessel anonymity for publication; 2025a's is the route for changing the call |
  | marine spatial planning | 2015, 2017, 2019, 2022 | effort in protected areas, around wind farms and near shipping lanes; displacement; individual stress-level analysis |
  | data coverage | 2015, 2016, 2025a | the share of landed weight and fishing days that VMS covers, and coverage maps; 2025a's row is the workflow's scope |
  | high-resolution data | 2018, 2019, WKSSFGEO 2022 | spatio-temporal models of effort (EOF, INLA), VMS simulated from AIS, a definition: no method in common |

  The recent readers put swept area under effort. These readers put the indicators and the impact work under no row,
  which is where they belong: they are made from the gridded pressure, after the last row.
- **Rows in no box of their row.** 157 of the substantive rows over 13 reports, of which the six add 41. Most fall in
  version 3's bands (ping rate, interpolation and devices; validation by sensors; static-gear effort and fishing days;
  gear codes). Four patterns are new:
  - vessel: an anonymous vessel key that rotates, such as NEAFC's random id, renewed every six months (2013, 2015-2018);
  - fishing: putative tows built from consecutive fishing pings (2016-2018);
  - catch: catch reports with no date, or spanning several days (NEAFC, 2016-2018);
  - ping: speed derived from the positions in place of the reported speed (2017, 2018).

## The verdict (proposed by Claude, not made)

**The version-3 diagram still holds as the centre.** Close to two-thirds of the groups' substantive work over 13 years
falls on its rows. No theme off them calls for a new row: what the old reports add lies after the last row, where
version 3 put Products. They ask for the products row to be filled in, not for the diagram to change shape.

Candidate amendments, for the maintainer to accept or decline (the diagram is not changed without the maintainer's go):

1. **Products: indicators from the grid.** Extent, aggregation and untrawled area (DCF indicators 5-7, later MSFD
   D6). Method or definition rows off the diagram in four reports (2013-2016), and named in every report of
   2013-2018 (a keyword count).
2. **Products: disclosure.** Aggregate so that no vessel can be told apart: a minimum number of vessels a cell, and
   anonymous ids. Method rows in three reports.
3. **Products: coverage.** Each product states what share of the logged catch and days its fixes carry (VMS weight
   against logbook weight). Method rows in two reports and a related one in a third, so this is borderline on the
   criterion. It is `AGENTS.md`'s second "done" criterion seen from the groups' side.
4. **Products: impact.** Pressure combined with habitat sensitivity (BH3, longevity, population dynamics). Method rows
   in two reports only (2015, 2016), below the criterion. It is named because some row of twelve of the 13 reports
   touches impact (a keyword count, not a reading).

**Beyond the diagram: the products' uses.** Protected areas, wind farms, shipping lanes, displacement and stress-level
analysis pass the criterion (four reports). They are uses of the products, not a step towards them, so they would be a
chapter of the book, not a box. Plan 033 §4 has no such chapter. Whether it gets one, and where, is the maintainer's
call.

**Box-level notes, not amendments.** The dated vessel key may be an anonymous id that rotates (vessel row, "register /
dated MMSI"). Tows from consecutive fishing pings fit "phases (dense track)", catch reports over several days fit
"several trips / weekly landing", and derived speed belongs to the ping row's own computation. Each would be a line in
its chapter.

## Built

- **`docs/ices_reports.yml`**: 13 reports, 1,777 topic rows, 511 code rows. The six sit before WGSFD 2019, so the
  WGSFD series runs by year, each with its DOI and licence from the provenance file. Themes are merged across all 13,
  and the five 2025a term lists set from the page. The header names the reports read, the counts, the hand checks and
  this record.
- **`dump/ices/check_rows.py`**: the single-term fix.
- **`dump/ices/README.md`**: the six reports read.

## Not done

- **The amendments above.** Version 3 stands until the maintainer decides.
- **Plan 033 §4** is unchanged: no chapter for the uses until the maintainer decides.
- **Terms of reference listed twice.** In two-part maps (2016 here; 2019, 2022 and WKSSFGEO2 before), where both parts
  list them, the merge appends both lists. Left as decision 150 left them.
- **The 20 rows of the seven recent reports** that decision 150's checker flagged stay as they were. Those reports are
  CC BY 4.0.
- **The part maps** were written in the session's scratch folder and are not kept; the reading map holds their
  content.
