# dump/ices — the ICES reports as text, and their reading map

The ICES expert-group reports behind plan 033's book: WKSSFGEO, WKSSFGEO2, and every WGSFD report in the ICES library
(2013-2025). The PDFs were fetched by hand from the ICES library on figshare, at the maintainer's request on
2026-10-19. Each one's DOI, licence, size and sha256 is in `$FISHYDATA/raw/external/ices/README-provenance.txt`.

Plan 033 §11.1 has the design, and decisions 150 and 152 what the reading found.

## Text (writes `raw/external/ices/text/`)

| Tool | Does |
|---|---|
| `mark_pages.sh <pdf> <out.txt>` | the PDF's text (`pdftotext -layout`), one block per page, each opened by `===== PDF page N · printed page P =====`; the printed number is read from the ICES page header |
| `compact_text.py <marked.txt> <out.compact.txt>` | the same text, compact for reading. Runs of spaces are collapsed. Contents lines, lines that are mostly digits (table bodies; captions stay), reference lists and participant lists are dropped. Page markers are kept |
| `split_parts.py <compact.txt> <max_chars>` | splits a long report at page markers into parts a reader takes in one read (`<id>.part1.txt`, …) |

`raw/external/ices/text/` holds both texts for all 13 reports: `<id>.txt` (full, page-marked) and
`<id>.compact.txt`. The chapters of the book are drafted from the full text at the pages the map cites.

## The reading map (writes `docs/ices_reports.yml`)

1. **Reading.** One AI subagent reads each report or part, following `lean_instructions.md`: one read, one write,
   no self-check. It writes a YAML with the report's aims, terms of reference, data call and outputs; topic rows with
   their diagram row and box, theme, kind, pages, a one-sentence paraphrase and the report's terms; a code trail; and
   vocabulary.
2. **Merging.** `Rscript merge_parts.R <out.json> <part1.yml> [<part2.yml> …]` merges a report's parts into one JSON.
3. **Checking.** `python3 -I check_rows.py <marked.txt> <rows.json>` checks one map. For each topic row it tests:
   - that its pages agree with the markers;
   - that one of its own terms appears on its cited pages;
   - that its summary copies no 8-word run of the report.

   `python3 -I check_all.py <dir> <id> …` runs that over several reports, adds a looser check of the code rows (a
   distinctive word of the name on its pages), and prints the diagram test of plan 033 §11.1.
4. **Writing.** The checked maps are written into `docs/ices_reports.yml` under a header that states the AI use and
   the checks.

All 13 reports are read: the seven from 2019 (decision 150) and the six of 2013-2018 (decision 152), whose header
format (`8 | ICES WGSFD REPORT 2015`) `mark_pages.sh` handles. Before the maps are written, themes that two readers
coined for one thing are merged (decision 152 lists them).

Python is used here for text handling only; the pipeline itself stays R.
