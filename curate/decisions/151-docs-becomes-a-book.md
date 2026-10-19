# 151 — `docs/` becomes a Quarto book, with no new text (plan 033 step 2)

*2026-10-19.*

- **Who chose.** What the step does is the maintainer's: asks a-d and f of plan 033 (§12). The choices the asks left
  open are Claude's, made in a side session and not yet reviewed by the maintainer: `ports.md` inside the book, a part
  with no chapter left out, the landing page unnumbered, `embed-resources` dropped, and how the STK page reads its
  table.
- **Who did the work.** Claude (Anthropic), in that side session: the configuration, the removals, the static figures
  and this record. No chapter text was written.
- **What it carries out.** Step 2 of plan 033.

## Done

- **`docs/_quarto.yml` is a book**: *From pings to effort and catch*, subtitle *Spatial fisheries data with ramb*,
  `site-url` `https://heima.hafro.is/~einarhj/fishybook`, and the GitHub link (`repo-url`) to fishycode. The
  website's menus and its `render:` list are gone. A book renders only its listed chapters, so the two phantom entries
  (`AGENTS_data_sources.md`, `AGENTS_output_schema.md`) went with the list, and so did `AGENTS.md`, which `docs/` does
  not hold either.
- **The parts, from the pages that exist** (§4):
  - *The problem, the flow and the tools*: `one_flow`, `grammar`.
  - *The groups*: `wkssfgeo`.
  - *The Icelandic data*: 19 pages in §4's order: sources (7), building the data (7), defects and corrections (4),
    how the data are used (1). A Quarto book has one level of parts, so §4's four groups are an order within the part,
    marked by comments in `_quarto.yml`.
  - *The flow, row by row* is not listed. None of its chapters is written in `docs/`: its seeds are ramb's articles
    (step 6) and fishyweb's whacky-positions note (step 5). It enters with its first chapter. The parts carry no
    numerals, since Quarto does not number them and one is missing.
- **The four pages that were in no menu are placed**: `stk_data-inspection` and `on_ais` among the sources,
  `qc_fs_afladagbok_2025` among the defects, `datacall-strategy` among the uses.
- **`ports.md` renders inside the book**, among the sources, where §4 puts it. That is one render instead of two, and
  once the book is published a link to its page serves the data providers as the standalone file did. The stale
  standalone render (`docs/ports.html` and `ports_files/`, untracked) went to the Trash. The `.gitignore` line for
  `docs/*_files/` stays as a guard, with its comment corrected.
- **Not listed:** `notes_duckdbfs-vs-duckspatial.md`, a seed of chapter 5 (§4). It is not rendered.
- **`index.qmd`**, the landing page a book requires, keeps the website's text. Its title moved from the YAML to an
  unnumbered heading, so that it is not counted as chapter 1. The preface (§8: it prints `packageVersion("ramb")`) is
  still to write.
- **Removed** with `git rm` (ask d): `on_disk.qmd`, `ramb-list.qmd`, `notes_mid-to-vid.md` and `project-review.qmd`,
  with `on_disk`'s freeze. Decisions 022, 069 and 081 still cite `project-review.qmd`; git keeps it.
- **`.gitignore`** ignores `_book/`.
- **`stk_data-inspection.qmd`**: its five mapdeck maps (`ramb::rb_plot_trail()`) are static `ggplot2` figures, drawn by
  a helper in the page (ask c). The page's frozen output with the maps was 295 MB, nearly all of it the points written
  into the page.
- **`qc_fs_afladagbok_2025.qmd`** loses `embed-resources: true`. In the book, pandoc tried to inline the link to the
  next chapter and warned (`Could not fetch resource ./convert-bugs.html`). A self-contained page has no place inside a
  book.

## Found

- **The STK staging table holds a partition from an old build.** `staging/ais/stk/year=2006/` has 2 pings (one
  vessel, 2006-12-31 12:28) from the build of 2026-09-23, without the column `d2e` that the rebuild of 2026-10-17
  wrote into the other 27 partitions. That rebuild wrote no 2006 partition, and `duckdbfs::write_dataset()` in
  `sources/stk/convert.R` does not remove a partition it no longer writes. The STK page could not re-execute (DuckDB:
  schema mismatch in the glob), so it reads with `unify_schemas = TRUE`. The store is untouched; the fix is TODO 95.
- **The render.** `quarto render` in `docs/`, Quarto 1.8.26, with `freeze: auto`. Re-executed: `afli-tables` and
  `ais_trail`, whose freezes predated their last edits, and the two pages edited here; the STK page took 5 minutes and
  11.7 GB, and its freeze is now 628 KB. The last full render: 23 pages, no warning, and no data file in `_book/`. The
  rendered HTML was not read.
- The STK page's prose numbers (169.6M clean records and so on) date from an earlier build. They were not compared
  with the re-executed tables.

## Not done

- `check_book()` (step 3). Its exclude list will need `notes_duckdbfs-vs-duckspatial.md`.
- The preface, and every chapter not yet written (step 8).
- Publishing (step 9).
