# fishydata — Agent Memory

> Seeded 2026-09-20 during the restructuring. The full rationale is in
> `curate/decisions/000-restructuring.md`. **Do not let this file drift from the
> code** — that is the failure it is replacing.

## What this project is

**The aim is fishing effort and catch at high resolution in time and space**:
where and when each vessel fished, with what gear, and what it caught. For every
vessel at sea, each fix says:

- whether it was fishing, and with what gear;
- the effort it stands for (hours, kW-hours, pressure);
- its share of the catch (kg by species).

Each value carries the path and basis it came from. All six steps of the flow
belong here, effort and catch included (maintainer, 2026-10-14).

It is a data product, not a picture. A map such as
[veidar.hafogvatn.is](https://veidar.hafogvatn.is) (relative effort by gear,
2008-2024) is one view of it and the ICES VMS datacall another; the data serve
analyses beyond both.

It is done when:

1. every fix is accounted for: fishing, not fishing, or undecided, with why;
2. every kilogram logged or landed sits on fixes, or explicitly on a coarser
   unit (kg in = kg out);
3. each path's error is known, measured on the well-recorded part of the data.

The work is split in two (maintainer, 2026-10-14):

- **`ramb`** provides generic helper functions for every point on the information
  spectrum, from pings alone to hauls with times (`docs/one_flow.qmd`).
- **fishycode** is the scripts that apply them to the Icelandic data.

**Each step is a cascade** (`docs/one_flow.qmd`): ping by ping, it takes the best
source it has, falls back when that is missing, and records which source
answered (the basis). The path differs between datasets, and within one dataset
between periods, records and pings, so no single method assigns effort and
catch to every ping. The diagram `docs/figures/one_flow_cascade_v2.svg` is this
design in one picture (rows the steps, boxes the sources, best first);
`docs/figures/one_flow_status.svg` colours each box by where it is built.

The Icelandic data are rich, but their resolution differs by period, by record
and by variable, and most of them are not exactly right. The AIS track is most
likely the best ground truth for time and place. **Coverage is the general
problem**: logbooks or landings missing, vessels not linked to their AIS, and so
on.

The name is the thesis: the Icelandic logbook, landings and AIS data contain
errors, and the value added here is detecting and correcting them using
cross-source evidence. **Corrections are the core of the product, not exceptions
to it.**

The deliverable is a *sweep of parquet files* an analyst opens and works with
directly, with no pipeline knowledge required.

## The two committed boundaries

Everything else is a directory and may be moved with `git mv`. These two are
permanent — they are the only structure that survived every previous restart.

1. **Source-shaped vs merged-shaped** — `$FISHYDATA/staging/<source>/` vs
   `$FISHYDATA/curated/`.
2. **Data vs documents** — parquet outputs vs the Quarto site in `docs/`.

## Preprocessing, one-time fixes, flow (plan 014)

Every script in a targets project is on one of three sides, and says which in a `# Side:` header line
(enforced by `check_bookkeeping()`):

- **preprocessing**: Icelandic data into standard inputs. It may reconcile the logbook with the landings
  (the trip-landing match, gear from the landings) but **reads no AIS**.
- **once**: the three one-time fixes, i.e. the STK mobile-id → vid key, the GPS logger positions and the
  port radius. They are a second targets project (`_targets_once.R`, `TAR_PROJECT=once`, `_targets.yaml`),
  built once, reviewed, and frozen as inputs of the main project. They are redone only by a decision
  record.
- **flow**: the generic WGSFD one-flow, as thin callers of ramb `rb_` steps. Everything that uses the
  track (voyages, stays, trip ↔ voyage, `T2` from AIS) is here.

**Terms** (decision 075):

- **port** is the place word, and `pid` is its id. `hid` is a source's own port code (logbook, landings,
  STK).
- A **stay** is an interval in port. Its values live once, in the stay table; pings carry keys only.
- A **voyage** is any movement from one stay in port to the next, cut from the track; a **trip** is a fishing
  trip. Declared dates are not arrival times: the reconciled trip table is a flow output, never fed back into
  the declarations' own match.
- The flow runs at any data resolution and never stops for a missing table: the output's shape is the same,
  its content and basis depend on the data (plan 013, decided item 9). `docs/one_flow.qmd` describes the flow
  and what exists where (ramb, fishycode, outside code).
- **One fix, one record** (maintainer, decision 090): an assignment puts a fix in at most one logbook record and one
  phase of it. `trail_match` holds candidates, not assignments. The windows and `station_event` keep it since
  decision 091.
- **Twin records** (decision 094): a logbook station entered again (same vessel, t1-t4 and catch) is `twin`
  `duplicate` in `station.parquet`, and a trip submitted again is `duplicate` in `trip.parquet`. Every sum, count and
  link leaves duplicates out; a new consumer of the logbook must too. `same_time` records are kept.

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
- **Every inferred value carries a `basis`**, its provenance (`"recorded"` / `"derived"` /
  `"reconstructed"` / `"synthesised"`, or `"none"` when no source has it). `derived` =
  computed from recorded values of the same record (`t2` + duration); modifiers such as
  `capped` go in their own column. See `station_type` in `docs/grammar.qmd`.
- **Cycles are broken by a human, outside the DAG.** Cross-checks are circular
  (AIS → vid assignment → logbook activity → validates the vid assignment). A
  reviewed override in `overrides/` re-enters as an *input*, never as a computed
  output. So does a one-time fix (`_targets_once.R`). It is computed once,
  reviewed, and frozen, and the main project reads it as a file it never builds
  (decision 075).
- **Build with `tar_make_isolated()`** (`R/tar_make_isolated.R`). It runs one R
  session per target. A one-session `tar_make()` swelled to 111 GB on a 24 GB
  machine (decision 073). `targets` cannot see script edits (`produces()` hashes a
  path), so invalidate an edited script's target by hand.
- **Shared functions live in `ramb`**, never copied into a script here. The
  previous tree accumulated ~9 copies of the STK matcher and 3 of the ports
  domain by copying instead of depending.
- **Upstream repos are consumed as artifacts, never as copied code.** One does:

  | Repo | Produces | Consumed here as |
  |---|---|---|
  | [`ramb`](https://github.com/einarhjorleifsson/ramb) | R functions | `library(ramb)` |

  **Which ramb.** The code needs the argument names of 2026-10-12,
  `rb_calc_speed(method = )`, `rb_link_record_events()` (decision 088) and the exclusive windows and event links
  with `win_opened_by` and `ping_lost` (decision 091), `window_s` for the ±10 min fishing speed (decision 093), and the effort, the
  fishing cascade, the catch units, the landing links and the stable units of 2026.10.14.6-.14 (decisions 099-102): so ≥ 2026.10.14.14. The data on disk were built with ramb 2026.10.13.3 (the full
  rebuild of 2026-10-13/14, decision 086), the afli → trail chain with 2026.10.14.1 (decision 089), `station_window`
  with 2026.10.14.2, `station_event` with 2026.10.14.3 (decision 091), the trail with 2026.10.14.5 (decision 093), `voyage_gear` and the trail with 2026.10.14.9 (decision 101), and `ais_catch` with 2026.10.14.14 (decision 102). 2026.10.14.4 added the
  towing-stretch pairing (decision 092), which nothing here calls.
  `targets` does not track ramb, so a ramb change shows up in no
  `tar_outdated()`: compare fingerprints (`R/fingerprint.R`) before and after a rebuild.

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
| `dump/` | Extraction only — Oracle, vendor archives, web fetches. Writes `raw/`. The only home of a dump script: none lives beside the data (decision 105). Each Oracle schema is dumped as it is, names and units unchanged, by `dump/oracle/<schema>.R` to `raw/oracle/<schema>/`, every table and view, with Oracle's comments in a `_data-dict.yaml` and the dump time stamped in each file (`dump_oracle_schema()`, `R/dump_oracle.R`; plan 018). The preferred form is made after, never in the dump. Run by the maintainer, since the password is in the macOS keychain: `run_dump(schema, resume = FALSE)` (`R/run_dump.R`) starts each script in its own background Rscript, with a log in `raw/oracle/<schema>/_logs/`; `dump_status()` says where each stands. |
| `sources/<name>/` | One adapter per source system. `raw/` → `staging/<name>/`. |
| `reference/` | Vessels, geo, ports, gear, species. Note: `vessel_ais_key` is a *fitted model*, not a registry — it carries confidence. |
| `curate/` | Merge, linkage, corrections, cross-checks. `staging/` → `curated/`. |
| `curate/checks/` | Cross-source disagreement checks; emit `curated/check/`. `ais_key_audit.R` audits the whole STK mid→vid key row by row against witnesses that never read it, `ais_key_split_candidates.R` finds where a mobile-id changed hands, `ais_key_coverage.R` checks that no ping of a mid with a vessel is unassigned, `ais_key_segments.R` rebuilds the assignment as a segment table that tiles every mid, and `ais_key_twins.R` keeps mids heard with two vessels (plan 009, decision 047). These key checks build the key and run with it in the `once` project. `sources/stk/event.R` tags every STK port `I`/`U` event from STK alone, one row per ping (plan 011, decision 059; preprocessing since plan 014); `curate/port_stay.R` builds the stays from them and from the pings, with the per-port departure radius of `reference/ports/port_radius.R` (decision 060; a frozen one-time fix since decision 075); `curate/ais_voyage.R` cuts voyages at those stays (decision 061), and `curate/ais_trail.R` builds the product from them: `curated/ais/trail`, every fix with its voyage, station and logbook trip, partitioned by year and month (decision 065). |
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
6. **Corrections pair a declaration with an implementation**: `afli_depth_units.yml`
   beside `afli_depth_units.R`.

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

> **Adopted — 2026-10-08.** Every file under `curated/` is stamped (669 of 669,
> decision 070). `write_curated_sql()` (same file) does the same for a `SELECT` too
> big to hold in R, one stamped file per partition. `manifest.yml` is still unbuilt;
> it belongs to publishing (decision 000, step 7).

## Provenance of this repo

Supersedes two repos, never to be edited again. They stay writable, as they are (maintainer, decision 097):

- `~/stasi/logbooks` — QA/methodology; `targets`; `afli` + `fs_afladagbok`
  adapters; landings match; AIS trip chain. Won all 8 forked script pairs.
- `~/stasi/fishydata_2024-2026` — production ETL; the ICES datacall; Norway,
  Faroe, GFW, EMODnet, ports.
