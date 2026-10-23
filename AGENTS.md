# fishydata — Agent Memory

> Seeded 2026-09-20 during the restructuring. The full rationale is in
> `curate/decisions/000-restructuring.md`. **Do not let this file drift from the
> code** — that is the failure it is replacing.

## What this project is

**The aim is fishing effort and catch at high resolution in time and space**:
where and when each vessel fished, with what gear, and what it caught. For every
vessel at sea, each fix says:

- which logbook and landing events it may belong to (the station with its gear
  and phase, the trip, the voyage, the landing), with the evidence for each link
  (the window and its basis, the fix's speed against the gear's speed range);
- the time it stands for, its dt, from which the effort (hours, kW-hours,
  pressure) is summed over the fixes a filter keeps;
- under each of the flow's filters, whether it was fishing and its share of the
  catch (kg by species).

**The main output is the link** (maintainer, decision 215): the user chooses a
filter over the linked fixes (the speed range, the time window, both, or another);
the effort is the sum of the kept fixes' dt, and the catch, or any additive quantity
the record reports (value, hooks, nets, logged soak hours), is split over them by the
same dt, labels inherited; ramb's split keeps every unit in one outcome whatever the
filter. The flow's own filters, `fishing` and `fishing_flow`, are presets.

Each value carries the path and basis it came from. All six steps of the flow
belong here, effort and catch included (maintainer, 2026-10-14).

It is a data product, not a picture. A map such as
[veidar.hafogvatn.is](https://veidar.hafogvatn.is) (relative effort by gear,
2008-2024) is one view of it and the ICES VMS datacall another; the data serve
analyses beyond both.

It is done when:

1. every fix is accounted for: the events it may belong to, or none, with why;
   and under each preset filter fishing, not fishing, or undecided;
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
catch to every ping. The diagram `docs/figures/one_flow_cascade_v3.svg` is this
design in one picture (rows the steps, boxes the sources, best first, closed by the
products made from the fixes, with validation across the rows). It was amended from
version 2 on a reading of seven ICES reports (decision 150), and is the centre of
the book of plan 033. `docs/figures/one_flow_status.svg` colours version 2's boxes by
where each is built.

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
2. **Data vs documents** — parquet outputs vs the Quarto book in `docs/`.

## Preprocessing, one-time fixes, flow (plan 014)

Every script in a targets project is on one of three sides, and says which in a `# Side:` header line
(enforced by `check_bookkeeping()`):

- **preprocessing**: Icelandic data into standard inputs. It may reconcile the logbook with the landings
  (the trip-landing match, gear from the landings) but **reads no AIS**.
- **once**: the one-time fixes, i.e. the STK mobile-id → vid key, the GPS logger positions, the port radius,
  and the annual ship register's history to 2023-12-19 (decision 132). They are a second targets project
  (`_targets_once.R`, `TAR_PROJECT=once`, `_targets.yaml`), built once, reviewed, and frozen as inputs of the
  main project. They are redone only by a decision record, and built by name, never as a whole project
  (`tar_make_isolated(names = )`): a whole build redoes every fix whose watched files changed.
- **flow**: the generic WGSFD one-flow, as thin callers of ramb `rb_` steps. Everything that uses the
  track (voyages, port calls, trip ↔ voyage, `T2` from AIS) is here.

**Terms** (decision 075; "port call" since decision 147):

- **port** is the place word, and `pid` is its id. `hid` is a source's own port code (logbook, landings,
  STK).
- A **port call** is an interval in port (a *stay* until decision 147). Its values live once, in its table
  (`curated/ais/port_call.parquet`, key `port_call_id` per vessel); pings carry keys only (`port_call_id`, and
  `voyage_id` per vessel-year: ramb's names since decision 149), and the trail's few voyage values on each fix are a
  recorded exception (decision 147).
- A **voyage** is any movement from one port call to the next, cut from the track; a **trip** is a fishing
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
- **adb only where fs_afladagbok ends** (maintainer, decision 160): fs_afladagbok is the dump of record of the
  e-logbook, a copy from the Directorate fed no longer (last registration 2025-12-12). adb is MFRI's nightly copy of
  the Directorate's records, read by Java code no one at hand knows and put into MFRI's codes: fs_afladagbok's tables
  field for field, with losses of its own (decision 171). It is read only from 2025-11-19, when the dump starts to
  thin. Before that day a reader, a test or a comparison takes fs_afladagbok.

## Rules

- **All data lives under `$FISHYDATA`.** Nothing is written into this repo. No
  absolute paths anywhere; use `R/paths.R`.
- **Corrections live in `curate/`, never in a source adapter.** An adapter that
  reads two other sources is no longer an adapter.
- **Never destroy the original.** A correction adds columns; it never overwrites.
  Precedent: wacky-coordinate recovery retains `w_lon`/`w_lat` beside the
  corrected `lon`/`lat`.
- **Kennitala may be carried up to and including `curated/`** (maintainer, 2026-10-18, a general rule), under
  `$FISHYDATA` only: never in this repo, `docs/`, or anything published. What a public source prints (owners,
  addresses, phones) is kept the same way (decision 130), and the Oracle dumps take persons' tables too (decision
  159). Read them by counts and columns; never print their rows into a session.
- **The written record is enforced, not promised.** `check_bookkeeping()`
  (`R/check_bookkeeping.R`) verifies every rule the three `README.md` files
  assert: records indexed, index rows resolving, no finished item left in
  `TODO.md`, a plan's status agreeing with its index row and every open plan
  named in `TODO.md`, corrections declared, and no path in *this file* that
  does not exist. Run it before committing. It is pure base R and needs no `$FISHYDATA`.
- **Where a thing is written down.** `AGENTS.md` = what is true now.
  `TODO.md` = what is open, a few paragraphs each. `curate/plans/` = designs
  not yet built. `curate/decisions/` = what was chosen or found, after the
  fact. `curate/corrections/` = data defects. `curate/issues/` = defects found in
  other people's code, for their authors. A finished `TODO.md` item is
  **deleted** from it and recorded in `decisions/`, never left in place
  wearing a done marker.
  An item that cannot move without the maintainer carries **`needs: maintainer`**;
  `check_bookkeeping()` lists those at the end of its report.
- **Checks are bookkeeping, not modelling** (maintainer, 2026-10-21: "an accountant exercise, not a random forest
  model"). Every record and every kilogram is placed in one outcome, the unjudgeable included, and every difference
  is explained or listed as unexplained (decision 155's audit is the method). An agreement rate is never a pass,
  however high; statistics only test in the background.
- **Oracle tables, not views** (maintainer, 2026-10-22, a general rule). A reader takes the table and does in R what
  the view did. A view's conversions can be wrong (adb's `station_v` positions, decision 165; lods' tonnes read as kg,
  decision 169), and the code it calls may be hidden from the dump account (decision 166). Its text is in
  `raw/oracle/<schema>/_code/all_views.parquet`. New code reads tables. A reader still on a view (the three `once`
  readers, TODO 25) switches when it is next opened, with the view rebuilt from its table first.
- **Every inferred value carries a `basis`**, its provenance (`"recorded"` / `"derived"` /
  `"reconstructed"` / `"synthesised"`, or `"none"` when no source has it). `derived` =
  computed from recorded values of the same record (`t2` + duration); modifiers such as
  `capped` go in their own column. See `station_type` in `docs/grammar.qmd`.
- **Cycles are broken by a human, outside the DAG.** Cross-checks are circular
  (AIS → vid assignment → logbook activity → validates the vid assignment). A
  reviewed override in `overrides/` re-enters as an *input*, never as a computed
  output. So does a one-time fix (`_targets_once.R`). It is computed once,
  reviewed, and frozen, and the main project reads it as a file it never builds
  (decision 075). So does the vid ledger: a vid once given never moves, so the
  numbering of non-Icelandic hulls is appended by hand, `allocate_vids()`
  (`R/allocate_vids.R`), and the crosswalk reads it as an input (plan 021 §6 f,
  decision 115).
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
  fishing cascade, the catch units, the landing links and the stable units of 2026.10.14.6-.14 (decisions 099-102), and the names by
  output shape of 2026.10.19.2 (`rb_create_*()`, `rb_add_*()`, port calls; decision 147), and `rb_add_trip_time()` of
  2026.10.22.2 (a trip's departure and return from ranked witnesses; decisions 173, 174): so ≥ 2026.10.22.2. The data on disk were built with ramb 2026.10.15.1: every
  target the rebuild of 2026-10-16 reached (decision 112), from the raw readers and plan 016's vessel tables to
  `ais_catch`, the foreign vessel tables of 2026-10-17 (decision 114), and both halves of the rebuild of 2026-10-17: the logbook, landings and vessel half (decision 127), and the AIS chain on the STK key redone that day (decision 129). The register, its four readers (`vessel_sign`, `vessel_class`, `vessel_year`, `vessel`) and the AIS chain through `ais_catch` were rebuilt again on 2026-10-18 and 2026-10-19, at e2f741f (decision 144), with the same ramb. The AIS flow from `port_call` through `ais_catch`, with its checks, was rebuilt once more on 2026-10-19 at 72183bd with ramb 2026.10.19.2, when the tables took ramb's keys (decision 149). On 2026-10-20, at c7fa8c7 with the same ramb, the AIS chain from `ais_ping_union` through `ais_catch` and the logbook's `lid_map`, `logbook_gear`, `station_window` and `catch_by_species_trip`, with their checks (22 targets), were rebuilt for plan 034 and the logger exclusion (decision 154); `voyage_gear` through `ais_catch` and the checks again that evening at 5cec0f4 (decision 155). On 2026-10-21, at de25239 (452f83e in the published history, decision 158) with the same ramb, `logbook` (with `afli_end_longitude`) and everything after it through `ais_catch` and the checks (21 targets) were rebuilt for the placeholder set times and afli's end longitude (decision 158); and at f05de18 the same 20 for decision 160, adb only from 2025-11-19. On 2026-10-22, at 003b194 with ramb 2026.10.22.2 (0c3020b, installed from GitHub), 62 targets were rebuilt in three steps (decision 180): the port codes and the vessel register from their tables (175), lods in its own units (169), adb from its tables (165, 170), the kvoti and ops$einarhj re-dump, the departure and return of every trip (`trip_reconciled`, 173-174), the AIS chain through `ais_catch` and its checks, and afli's sent layer for the first time; `tar_outdated()` is empty since. On 2026-10-23, at f7c82eb with the same ramb, the logbook chain (`logbook` through `ais_catch` and its
  checks, 20 targets) was rebuilt for the fate tables, every landing in the link and the reconciled trip across voyages
  (decision 205); `tar_outdated()` is empty again. The geometry and lookup targets it did not reach (`ports_iceland`, `ports_all`, `dictionary`, `shapes_raw`,
  `shapes`, `area_h3`, `lookups`) are from the rebuild of 2026-10-13 with 2026.10.13.3 (decision 086). In the `once`
  project the STK key and its checks are the redo of 2026-10-17 (decision 128), and the register's history the build of 2026-10-18 at e2f741f (decision 144); `port_radius` and `sensor_gps` are older. 2026.10.14.4 added the towing-stretch pairing (decision 092), which nothing here
  calls.
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
| `dump/` | Extraction only — Oracle, vendor archives, web fetches. Writes `raw/`. The only home of a dump script: none lives beside the data (decision 105). `dump/ices/` turns the ICES reports in `raw/external/ices/` into page-marked text (`raw/external/ices/text/`) and holds the tools of their reading map, `docs/ices_reports.yml` (decision 150). Each Oracle schema is dumped as it is, names and units unchanged, by `dump/oracle/<schema>.R` to `raw/oracle/<schema>/`, every table and view, with Oracle's comments in a `_data-dict.yaml` and the dump time stamped in each file (`dump_oracle_schema()`, `R/dump_oracle.R`; plan 018). The dictionary carries the hand-kept overlay `dump/oracle/meta/<schema>.yml`: units, position formats, code labels, evidence and assertions for the columns fishycode reads (plan 040, decision 176); `rewrite_data_dict()` and `check_data_dict()` (`R/data_dict.R`) rewrite and check it when a dump is adopted. The preferred form is made after, never in the dump. Run by the maintainer, since the password is in the macOS keychain: `run_dump(schema, resume = FALSE)` (`R/run_dump.R`) starts each script in its own background Rscript, with a log in `raw/oracle/<schema>/_logs/`; `dump_status()` says where each stands. `dump/oracle/catalogue.R` lists every schema Oracle holds, from the data dictionary, to `raw/oracle/_catalogue/objects.parquet` (decision 121). `dump/oracle/code.R` keeps the SQL behind each dumped schema (views' text, stored code, triggers, dependencies, columns' defaults), from the data dictionary, in `raw/oracle/<schema>/_code/` (decision 166). On the server, through ROracle (decision 109; steps in `dump/oracle/README.md`): `Rscript dump/oracle/all.R --check`, then `nohup Rscript dump/oracle/all.R &` runs every schema in turn; `compare_dumps()` (`R/compare_dumps.R`) checks a server dump against the Mac's before it replaces it. |
| `sources/<name>/` | One adapter per source system. `raw/` → `staging/<name>/`. An Oracle table is read where the dump put it, `fd_raw("oracle", <schema>, <table>.parquet)`, as Oracle holds it; the STK trail and mobile ids through `stk_trail()` and `stk_mobile()` (`R/stk_trail.R`), their preferred form over the dump with no copy (decision 111). |
| `reference/` | Vessels, geo, ports, gear, species. Note: `vessel_ais_key` is a *fitted model*, not a registry — it carries confidence. |
| `curate/` | Merge, linkage, corrections, cross-checks. `staging/` → `curated/`. |
| `curate/checks/` | Cross-source disagreement checks; emit `curated/check/`. `ais_key_audit.R` audits the whole STK mid→vid key row by row against witnesses that never read it, `ais_key_split_candidates.R` finds where a mobile-id changed hands, `ais_key_coverage.R` checks that no ping of a mid with a vessel is unassigned, `ais_key_segments.R` rebuilds the assignment as a segment table that tiles every mid, and `ais_key_twins.R` keeps mids heard with two vessels (plan 009, decision 047). These key checks build the key and run with it in the `once` project. `sources/stk/event.R` tags every STK port `I`/`U` event from STK alone, one row per ping (plan 011, decision 059; preprocessing since plan 014); `curate/port_call.R` builds the port calls from them and from the pings, with the per-port departure radius of `reference/ports/port_radius.R` (decision 060; a frozen one-time fix since decision 075); `curate/ais_voyage.R` cuts voyages at those port calls (decision 061), and `curate/ais_trail.R` builds the product from them: `curated/ais/trail`, every fix with its voyage, station and logbook trip, partitioned by year and month (decision 065). `allocation_audit.R` tests every link the flow makes (station to trip and voyage, fix to trip, trip to landing, catch to fixes) against the records' own times, counting every record in one outcome, the unjudgeable too (decision 155). |
| `curate/corrections/` | The correction registry — one declarative entry each. |
| `curate/issues/` | Defects and suggestions found in code fishycode does not depend on, written up for its authors: one YAML per package, its drafts with their reprexes, and when and how they were sent (`sent`, `sent_how`). |
| `curate/decisions/` | Decision records. Why, not what. Indexed in its `README.md` — a finished `TODO.md` item is deleted and recorded there, or in `corrections/`. |
| `curate/plans/` | Forward design — written *before* the work, for anything too big to sit inside a `TODO.md` item. Indexed in its `README.md`; a plan states what is measured and what is assumed. |
| `overrides/` | Small, hand-maintained, human-reviewed correction inputs. |
| `products/` | Consumers of the sweep — datacall, ad-hoc exports, and the vessel overview (`products/vessel_overview/`, plan 030): an R service on 127.0.0.1 with a column allowlist, and the repo's only JavaScript, a page whose libraries are pinned and loaded from jsdelivr. Internal use only (newspaper photos, owners' names). Its map shows the AIS voyages alone, never a logbook position (decision 156). Its bundle mode is a demo that opens from a file, with no R or server: `products/exports/vessel_demo.R` writes it to `exports/`, anonymised, with the key beside it (decision 153). |
| `docs/` | The book of plan 033, *From pings to effort and catch*: a Quarto book since decision 151, rendered by `quarto render` here into `_book/` (untracked), and to be published at `heima.hafro.is/~einarhj/fishybook`. A chapter is listed in `docs/_quarto.yml` only once it has text, a skeleton of sections with its planned cases counting (2026-10-20). Its main part is one chapter per row of the flow diagram (`docs/flow_*.qmd`), with cases on ramb's example data; the Icelandic data are in the appendices. Reads `curated/`; never rebuilds it. It shows rendered figures and tables, never data files, and vessel data only as static figures (plan 033 §6). `docs/ices_reports.yml` is the reading map of the ICES reports, the index the book is drafted from. |
| `R/` | **Function definitions only.** `targets` sources this directory wholesale, so a script here executes on every `tar_make()` — `R/oracle.R` connected to Oracle at load and broke the graph until it was moved to `dump/`. |
| `tests/` | Tests that need no data, run from the repo root (`Rscript -e 'testthat::test_file("tests/test_dump_oracle.R")'`). A dumper test never reaches Oracle: DuckDB stands in for it, and `dump_connect()` is replaced. |

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
- **Date-times are UTC.** Both targets projects set `TZ=UTC`: the dumps hold plain TIMESTAMPs in UTC, which
  `nanoparquet::read_parquet()` would otherwise read in the session's zone (decision 111).
- **An open end is NA in a written table** (maintainer, decision 184). A far date may stand in for it inside a
  computation only, turned back to NA before writing (`reference/vessels/vessel_register.R`). Never a near date. Older
  tables keep theirs: the STK key's and the MMSI periods' 2028-12-24 is an arbitrary open-end date, which every reader
  treats as open (decision 183), and `vessel_sign` and `vessel_class` write 2099-12-31. A source's own end is kept as
  given.
- **`duckdbfs` for parquet I/O.** Never `library(arrow)` in a pipeline script —
  arrow and nanoparquet write `TIMESTAMP WITH TIME ZONE`, which DuckDB cannot
  subtract. `duckdbfs::write_dataset` writes plain `TIMESTAMP`.
  Exception: `write_curated()` uses `COPY … (FORMAT parquet, KV_METADATA {…})`,
  which also writes plain `TIMESTAMP` *and* embeds provenance —
  `duckdbfs::write_dataset` writes no KV metadata at all.
- **Never `nanoparquet::read_parquet(col_select = )` on a file nanoparquet wrote.** Version 0.5.1 drops the NULLs of an
  optional integer column and shifts its values up: 157,501 of Hreiðar's 164,164 years came back as another row's
  (decision 144). Read the whole file, then `select()`.
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
