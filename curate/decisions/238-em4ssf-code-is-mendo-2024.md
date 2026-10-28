# 238 — EM4SSF's shared code is Mendo et al. 2024's published workflow: no new method, kept private outside the repo

*2026-10-28. The maintainer was given access to the EM4SSF project's private GitHub organisation and asked for it to be
added to the knowledge base, with care, since "these scripts come from somewhere! and they may be public already". The
maintainer cloned it to `~/stasi/em4ssf`. Claude (AI) traced every script to its public origin, downloaded the paper's
supplement for it, and wrote this record. No person has checked it. Nothing went into ramb, and the scripts were not
run.*

## What was shared

Two repositories, one of R and one of Python, with 13 scripts and 4,370 lines between them. They hold no data, no
licence and no README. The R has four commits, from 2026-05-21 to 2026-08-27 (c9fd1ed). The Python has two, on
2026-06-16 and 2026-06-25 (57e8b7c). Both say in their first commit that the code is from the paper.

## Where each script came from

The paper is Mendo et al. 2024, *A workflow for standardizing the analysis of highly resolved vessel tracking data*,
ICES JMS 81: 390 (https://doi.org/10.1093/icesjms/fsad209), under CC BY 4.0. It prints its code in PDF supplements, S1
in R and S2 in Python. They are now in `raw/external/mendo2024/`, with checksums in its `README-provenance.txt`.

Each script was measured by line. Its code lines, with whitespace removed, were looked up in the text of the
supplement's PDFs. The PDF's wrap markers were removed, and one column's two names were treated as one.

| scripts | origin | code lines found in the supplement | what EM4SSF changed |
|---|---|---|---|
| R steps 1-4, first commit (b4d86b0) | S1 | all; the one miss is a comment the PDF wraps | nothing: copied from the PDF, its typographic circumflexes included |
| R steps 1-4 now | S1 | 60-100 % | D2.1's column names, another study area, projection, coastline and local paths, the PDF's characters fixed. The method and its thresholds are the same |
| R `EM4SSF_WP2_preprocessing.R` | S1, step 1 | 58 % | step 1 in one script, with trips by vessel and day or between mooring sites. Columns take D2.1's names, and the trip's source is coded as analysis (`TRIP_ID_SOURCE`) |
| Python steps 1-5 (d423a82) | S2 | 88-100 % | the authors' working copy, not the printed one: a vessel column, the default trip option, a date format, plot limits |
| Python, two scripts not in S2 by name | S2, steps 4 and 5 | 62 % and 78 % | an earlier version of the mooring-site step and a copy of step 5, with the same method and the same Outer Hebrides inputs |
| Python `EM4SSF_WP2_preprocessing.py` | the R preprocessing | 6-8 % (a translation) | the R preprocessing in pandas |

Mendo's GitHub repository `identify_fishing_workflow` (decision 148) holds an earlier draft of the R. It has 15-39 %
of the code lines.

## What it changes here

- **No new method.** EM4SSF's WP2 preprocessing so far is Mendo et al. 2024's workflow, written in D2.1's exchange
  format. That format is the only new thing, and decision 229 already read it from D2.1. The scripts show it in use, and
  they use D2.1's source code for a trip found by analysis.
- **The wish list is unchanged.** `docs/one_flow.qmd` already names Mendo et al. 2024 for mooring sites learned from the
  track (plan 031 §4.3), and its EM4SSF rows came from the deliverables.
- **A recode would follow decision 234.** Mendo et al. 2024 exists only as scripts and PDFs. A version in ramb would
  stand only if checked against its output and attributed to the paper. None is planned.

## How the private code is handled

- The clone stays in `~/stasi/em4ssf`, outside this repository, ramb and `$FISHYDATA`. It is read only, never run and
  never copied.
- What is public is cited from its public home: the paper and its supplements S1 and S2, never the EM4SSF copy.
- What is EM4SSF's own stays private until the project publishes its code (D4.1, May 2027). That is the D2.1 renaming,
  the two preprocessing scripts and the Python working copies. It is described in our own words and never quoted. It is
  not cited in `docs/` or in ramb.
- The scripts' input files and paths are not repeated anywhere, since they name the partners' vessels and drives.

## Not done

- No `TODO.md` item has been opened. Whether ramb takes up the mooring-site step is plan 031's question, as before.
