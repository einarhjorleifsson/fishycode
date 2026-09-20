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
- **Every inferred value carries a `basis`** (`"recorded"` / `"reconstructed"` /
  `"synthesised"`). See `station_type` in `docs/grammar.qmd`.
- **Cycles are broken by a human, outside the DAG.** Cross-checks are circular
  (AIS → vid assignment → logbook activity → validates the vid assignment). A
  reviewed override in `overrides/` re-enters as an *input*, never as a computed
  output.
- **Shared functions live in `ramb`**, never copied into a script here. The
  previous tree accumulated ~9 copies of the STK matcher and 3 of the ports
  domain by copying instead of depending.

## Layout

| Directory | Holds |
|---|---|
| `dump/` | Extraction only — Oracle, vendor archives, web fetches. Writes `raw/`. |
| `sources/<name>/` | One adapter per source system. `raw/` → `staging/<name>/`. |
| `reference/` | Vessels, geo, ports, gear, species. Note: `vessel_ais_key` is a *fitted model*, not a registry — it carries confidence. |
| `curate/` | Merge, linkage, corrections, cross-checks. `staging/` → `curated/`. |
| `curate/checks/` | Cross-source disagreement checks; emit `curated/check/`. |
| `curate/corrections/` | The correction registry — one declarative entry each. |
| `curate/decisions/` | Decision records. Why, not what. |
| `overrides/` | Small, hand-maintained, human-reviewed correction inputs. |
| `products/` | Consumers of the sweep — datacall, ad-hoc exports. |
| `docs/` | Quarto site. Reads `curated/`; never rebuilds it. |

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

`write_curated()` is the **only** way anything enters `curated/`; it stamps repo,
commit SHA, dirty flag, script, build time, input hashes, row count and schema
hash. `check_sync()` reports drift. Nothing under `$FISHYDATA` is ever hand-edited.

## Provenance of this repo

Supersedes two repos, both archived read-only and never to be edited again:

- `~/stasi/logbooks` — QA/methodology; `targets`; `afli` + `fs_afladagbok`
  adapters; landings match; AIS trip chain. Won all 8 forked script pairs.
- `~/stasi/fishydata_2024-2026` — production ETL; the ICES datacall; Norway,
  Faroe, GFW, EMODnet, ports.
