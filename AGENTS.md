# fishydata — Agent Memory

> Seeded 2026-09-20 during the restructuring. The full rationale is in
> `curate/decisions/000-restructuring.md`. **Do not let this file drift from the
> code** — that is the failure it is replacing.

## What this project is

The name is the thesis: the Icelandic logbook, landings and AIS data contain
errors, and the value added here is detecting and correcting them using
cross-source evidence. **Corrections are the core of the product, not exceptions
to it.**

The deliverable is a *sweep of parquet files* an analyst opens and works with
directly, with no pipeline knowledge required. The ICES VMS datacall is one
consumer, not the destination.

## The two committed boundaries

Everything else is a directory and may be moved with `git mv`. These two are
permanent — they are the only structure that survived every previous restart.

1. **Source-shaped vs merged-shaped** — `$FISHYDATA/staging/<source>/` vs
   `$FISHYDATA/curated/`.
2. **Data vs documents** — parquet outputs vs the Quarto site in `docs/`.

## Rules

- **All data lives under `$FISHYDATA`.** Nothing is written into this repo. No
  absolute paths anywhere; use `R/paths.R`.
- **Corrections live in `curate/`, never in a source adapter.** An adapter that
  reads two other sources is no longer an adapter.
- **Never destroy the original.** A correction adds columns; it never overwrites.
  Precedent: wacky-coordinate recovery retains `w_lon`/`w_lat` beside the
  corrected `lon`/`lat`.
- **The written record is enforced, not promised.** `check_bookkeeping()`
  (`R/check_bookkeeping.R`) verifies every rule the three `README.md` files
  assert: records indexed, index rows resolving, no finished item left in
  `TODO.md`, corrections declared, and no path in *this file* that does not
  exist. Run it before committing. It is pure base R and needs no `$FISHYDATA`.
- **Where a thing is written down.** `AGENTS.md` = what is true now.
  `TODO.md` = what is open, a few paragraphs each. `curate/plans/` = designs
  not yet built. `curate/decisions/` = what was chosen or found, after the
  fact. `curate/corrections/` = data defects. A finished `TODO.md` item is
  **deleted** from it and recorded in `decisions/`, never left in place
  wearing a done marker.
  An item that cannot move without the maintainer carries **`needs: maintainer`**;
  `check_bookkeeping()` lists those at the end of its report.
- **Every inferred value carries a `basis`** (`"recorded"` / `"reconstructed"` /
  `"synthesised"`). See `station_type` in `docs/grammar.qmd`.
- **Cycles are broken by a human, outside the DAG.** Cross-checks are circular
  (AIS → vid assignment → logbook activity → validates the vid assignment). A
  reviewed override in `overrides/` re-enters as an *input*, never as a computed
  output.
- **Shared functions live in `ramb`**, never copied into a script here. The
  previous tree accumulated ~9 copies of the STK matcher and 3 of the ports
  domain by copying instead of depending.
- **Upstream repos are consumed as artifacts, never as copied code.** One does:

  | Repo | Produces | Consumed here as |
  |---|---|---|
  | [`ramb`](https://github.com/einarhjorleifsson/ramb) | R functions | `library(ramb)` |

  The point of the rule is that **forking** killed the previous trees: five
  `ports-*.R` scripts had been copied into the old fishydata, one sharing 364 of
  384 lines with its upstream, and they drifted. Never keep a second copy.

  **`kaenugardr` was listed here until 2026-09-21 and is being absorbed instead**
  — it is a loose script collection, not a package, with this repo as its only
  consumer, and it was "consumed" by hand-copying its output files, which was
  itself the defect. Absorbing removes a copy rather than creating one, so it
  serves the rule rather than breaking it. See
  `curate/decisions/006-absorb-kaenugardr.md`. **Done 2026-09-21**: the scripts
  live here, the data is under `$FISHYDATA`, `ports_all` is a target, and
  `~/stasi/kaenugardr` is archived read-only.

## Layout

| Directory | Holds |
|---|---|
| `dump/` | Extraction only — Oracle, vendor archives, web fetches. Writes `raw/`. |
| `sources/<name>/` | One adapter per source system. `raw/` → `staging/<name>/`. |
| `reference/` | Vessels, geo, ports, gear, species. Note: `vessel_ais_key` is a *fitted model*, not a registry — it carries confidence. |
| `curate/` | Merge, linkage, corrections, cross-checks. `staging/` → `curated/`. |
| `curate/checks/` | Cross-source disagreement checks; emit `curated/check/`. `ais_key_audit.R` audits the whole STK mid→vid key row by row against witnesses that never read it, `ais_key_split_candidates.R` finds where a mobile-id changed hands, `ais_key_coverage.R` checks that no ping of a mid with a vessel is unassigned, `ais_key_segments.R` rebuilds the assignment as a segment table that tiles every mid, and `ais_key_twins.R` keeps mids heard with two vessels (plan 009, decision 047). `stk_event.R` tags every STK harbour `I`/`U` event, one row per ping (plan 011, decision 059); `curate/harbour_stay.R` builds the stays from them and from the pings, with the per-harbour departure radius of `reference/ports/harbour_radius.R` (decision 060). |
| `curate/corrections/` | The correction registry — one declarative entry each. |
| `curate/decisions/` | Decision records. Why, not what. Indexed in its `README.md` — a finished `TODO.md` item is deleted and recorded there, or in `corrections/`. |
| `curate/plans/` | Forward design — written *before* the work, for anything too big to sit inside a `TODO.md` item. Indexed in its `README.md`; a plan states what is measured and what is assumed. |
| `overrides/` | Small, hand-maintained, human-reviewed correction inputs. |
| `products/` | Consumers of the sweep — datacall, ad-hoc exports. |
| `docs/` | Quarto site. Reads `curated/`; never rebuilds it. |
| `R/` | **Function definitions only.** `targets` sources this directory wholesale, so a script here executes on every `tar_make()` — `R/oracle.R` connected to Oracle at load and broke the graph until it was moved to `dump/`. |

## Script naming

The two predecessor repos used three prefix conventions between them (`DUMP_`,
`DATASET_`, bare) plus numeric ordering prefixes that had rotted into gaps —
`00, 01, 05, 11, 12, 41, 43, 80, 91`. Replaced by six rules:

1. **The directory encodes the layer; the filename encodes the subject.** No
   `DUMP_` or `DATASET_` prefixes — `dump/` and `sources/` already say it.
2. **No numeric prefixes.** `targets` owns execution order; a number in a filename
   can only go stale.
3. **Name for the output, not the action.** From a dataset you can find its
   producer by name alone.
4. **`snake_case` throughout.** No hyphens (the old tree mixed both, sometimes in
   one filename: `stk-mid_vessel-vid_match.R`).
5. **File path and target name are derivable from each other.**
   `sources/afli/convert.R` → target `afli`.
6. **Corrections pair a declaration with an implementation**: `afli_coords.yml`
   beside `afli_coords.R`.

Deliberate exception: `curate/ais_ping_union.R` and `ais_ping_tag.R` are two
scripts producing one sweep table, because the intermediate is 44 GB and the
tagging pass must be restartable without redoing the union.

## Coding conventions

Carried over unchanged — they are good and were consistent across both previous
repos.

- **dplyr-first**; DuckDB/SQL only for performance.
- **Base R pipe** `|>`, not `%>%`.
- **`duckdbfs` for parquet I/O.** Never `library(arrow)` in a pipeline script —
  arrow and nanoparquet write `TIMESTAMP WITH TIME ZONE`, which DuckDB cannot
  subtract. `duckdbfs::write_dataset` writes plain `TIMESTAMP`.
  Exception: `write_curated()` uses `COPY … (FORMAT parquet, KV_METADATA {…})`,
  which also writes plain `TIMESTAMP` *and* embeds provenance —
  `duckdbfs::write_dataset` writes no KV metadata at all.
- **`purrr::map()` must be qualified** — `duckdbfs` loads `maps`, which masks it.
- **Comments**: non-obvious reasons only; every script head states input and output.
- **Section headers**: single-dash style only.
  ```r
  # Header -----------------------------------------------------------------------
  ## Subheader -------------------------------------------------------------------
  ```

## Provenance and sync

Data is not in git. Three mechanisms, distinct jobs:

| Mechanism | Answers |
|---|---|
| `targets` | Am I stale here, now? |
| Parquet KV metadata | What built *this file*? |
| `manifest.yml` per release | What is in this release? |

`write_curated()` (`R/write_curated.R`) is the way anything should enter
`curated/`. It writes `COPY … (FORMAT parquet, KV_METADATA {…})` and stamps
`fd.repo`, `fd.commit`, `fd.dirty`, `fd.script`, `fd.built`, `fd.rows`,
`fd.schema_hash` and `fd.inputs` (name=md5 per input). `sf` input is accepted:
geometry is stored as WKB with the CRS in `fd.crs`, read back with
`read_curated_sf()`. `curated_provenance(path)` prints the stamps and
`check_sync()` reports drift against HEAD. Nothing under `$FISHYDATA` is ever
hand-edited.

> **Partly adopted — 2026-09-21.** Built and in use by
> `reference/ports/harbour_codes.R`. The other ~18 writers still call
> `duckdbfs::write_dataset()` or `nanoparquet::write_parquet()` and carry no
> provenance. `write_curated()` takes a materialised data frame, so the
> `write_dataset()` callers (lazy duckdb relations, partitioned directories)
> need a separate path before they can convert. See TODO item 12.
> `manifest.yml` is still unbuilt.

## Provenance of this repo

Supersedes two repos, both archived read-only and never to be edited again:

- `~/stasi/logbooks` — QA/methodology; `targets`; `afli` + `fs_afladagbok`
  adapters; landings match; AIS trip chain. Won all 8 forked script pairs.
- `~/stasi/fishydata_2024-2026` — production ETL; the ICES datacall; Norway,
  Faroe, GFW, EMODnet, ports.
