# 014 — One line between Icelandic preprocessing and the generic flow

**status:** executed — approved and built 2026-10-09 (decisions 075–079) · **2026-10-09** ·
**see:** TODO 45 (closed by this plan), plan 013, `docs/one_flow.qmd` (the one-flow document; `~/stasi/wgsfd2026/` is retired)

Drafted with AI assistance (Claude) in plan mode on 2026-10-09, from the maintainer's direction (TODO 45), the terms
the maintainer chose in the same session, read-only measurements and an adversarial review. Its decision records
(075 on) carry the same AI-use line.

**Measured:** the counts under "Measured in plan mode" below (read-only, 2026-10-09).
**Assumed:** everything from §1 on is design. In particular: that gps in the union under the `pos_basis` rule
leaves voyages and stays unchanged; that the `stk_event` change moves few stays; that the gear rule can be chosen
from counted disagreements. Each is counted in phase 3 before the rebuild.

## Context

You asked (2026-10-09) to redraw the graph around the WGSFD one-flow.

Much of fishycode only prepares Icelandic inputs: the STK key, the harbour class, the GPS fault and the feed merging.
Mixing that with the flow made the graph long and fragile. For example, the port radius and the class depended on
`ping_clean`, and through it on the key and all of step 0.

Already decided:

- three one-time fixes, frozen outside the flow;
- harbours have no class (decision 074), with one minimum stay;
- `afli_coords.R` is removed;
- preprocessing uses **no AIS** (restated 2026-10-09 from "per source, never cross-source"). The logbook and the
  landings are two declarations about one trip, and reconciling them (the match, the gear) is preprocessing; anything
  that needs the track is the flow's. AIS may later qualify trips with no logbook or landing that are truly fishing,
  as a flow item.

Folded in: plan 013 phase 3, and TODOs 46, 47, 48 and 37. **One rebuild at the end.**

TODO 45's check ("a plan … approved before any of it is built") is met: the maintainer approved this plan on
2026-10-09, with three amendments the same day (the no-AIS rule, the landing link, gear from the landings).

**Measured in plan mode** (read-only):

- **TODO 41, GPS half.** `curated/logbook/sensor_gps` has 0 rows with a wrong vid (of 49,324,452), although the
  `.tid`-only join hits 14,843 fs_afladagbok samples. **Freezing today's file is safe.**
- **STK events.** Of 3,400,403 events (2017+, with a port), the cleaned-track neighbour test (`io_jump`) rejects only
  **40** that step 0 kept. Events can be tagged from STK alone.
- **Mixed port columns.** `ais/trip`'s `hid1`/`hid2` hold port ids (`IS-THH`), while the logbook trip's `hid1` is the
  landing code.
- **GPS through step 0** (review, 2020): 233,465 of 2,554,093 gps fixes (9.1 %) have an AIS ping within 10 s and
  would be set aside as duplicates. `curated/ais/ping` 2023 has 9,554 duplicate `(vid, time)` rows that only
  `ais_ping_trail.R` removes today.

## 1. The boundary

| Layer | May read | Runs |
|---|---|---|
| **Preprocessing** (Icelandic) | raw/staging, reference tables, the frozen fixes; logbook ↔ landings reconciled here; **never AIS** (except the frozen fixes) | main project |
| **One-time fixes** | anything, including flow outputs; cycles are broken here by a human | project `once`, only by decision |
| **Generic flow** | the standard inputs; everything that uses the track (voyages, stays, trip ↔ voyage, `T2` from AIS) | main project; thin callers of ramb `rb_` steps |

- **No directory moves.**
  - Each script named in `_targets.R` or `_targets_once.R` states its layer in a header line, e.g.
    `# Side: preprocessing (afli)`, `# Side: flow, step 1`, `# Side: once (vessel key)`.
  - `check_bookkeeping()` enforces it.
  - Corrections stay in `curate/corrections/`, flow-side ones (`adb_gear.R`) included.
- **AGENTS.md rule amended** (decision 075). "A reviewed override re-enters as an input" is widened: a one-time fix is
  computed once, reviewed, and re-enters the main project as a frozen input. The principle is the same, a human
  breaking the cycle.

### The three frozen fixes

All three are frozen as decision 073 built them.

| Fix | Frozen input | Built by (targets move to `_targets_once.R`) |
|---|---|---|
| STK mobile-id → vid | `curated/vessel/vessel_ais_key.parquet`, `vessel_ais_device.parquet` | `ais_key_cascade.R`, `ais_key.R`, the 10 `checks/ais_key_*.R`, `sources/skipaskra` |
| GPS logger positions | `curated/logbook/sensor_gps/` | `curate/logbook_sensor_gps.R` |
| Port departure radius | `curated/reference/port_radius.parquet` | `reference/ports/port_radius.R` (renamed from `harbour_radius.R`) |

**Mechanics.**

- `_targets.yaml` defines the project `main` (store `_targets`, unchanged) and the project `once` (store
  `_targets_once/`, added to `.gitignore`).
- Frozen inputs are command-less `format = "file"` targets on `fd_path()`, not `fd_curated()`, which would create a
  missing directory. A `stopifnot()` checks that each is present and non-empty.
- `once` is validated (`tar_validate`, `tar_manifest`), not run. `tar_make_isolated()` already honours `TAR_PROJECT`.
- `port_radius.parquet` is a stamped copy (`write_curated`, input = `harbour_radius.parquet`). It is the only data
  written before the rebuild.

**Fixes for a future redo** (code only; nothing is rerun now):

- the logger interpolation reads `provider != 'gps'`;
- the key's AIS witness reads `provider NOT IN ('stk', 'gps')`, in `R/audit_witnesses.R:42`, `ais_key_audit.R:56`,
  `ais_key_vessel_recall.R:49` and `ais_key_twins.R:67-69`. Otherwise gps rows, positioned from STK, would confirm
  the key;
- `port_radius.R` takes `in_clean` from `ping_clean` (STK pings) now that `stk_event` no longer has it;
- TODO 41's `(.tid, schema)` join in `logbook_sensor_gps.R`.

**Port polygons stay upfront in the main project**: raw files plus reviewed corrections, with no flow dependency. A
guard in the stay script stops if a frozen radius `pid` has no polygon (a rename re-mints pids, TODO 36).

## 2. Standard inputs

| Input | Path | Contract |
|---|---|---|
| pings | `staging/ais/ping_union/year=*` | `vid`, `mmsi`, `time`, `lon`, `lat`, `speed` (kn), `speed_raw`, `speed_basis`, `pos_basis`, `heading`, `cog`, `provider` (stk, astd, astdB, emodnet, gps), `year`; gps only: `sid_gps`, `n_sid_gps`, `dt_sec` |
| ports | `staging/aux/ports.fgb` + `port_radius.parquet` | `pid`, polygon, `r_out_m`; one minimum stay (2 h) |
| port events (optional) | `staging/ais/stk_event.parquet` | `vid`, `time`, `io`, `pid`, `io_ok` from STK-only tags (`io_pos`, `io_dup`, `io_short`) |
| declared trips | `curated/logbook/trip.parquet` | `.tid`, `schema`, `vid`, `T1`, `T2`, `hid1`/`hid2` (logbook codes), `pid1`/`pid2` |
| records | `curated/logbook/{station,fishing_sample}.parquet` | `.sid`, `schema`, `.tid`, `t1`–`t4`, gear, position, `resolution` (TODO 3) |
| landings | `curated/landing/{landings,catch}.parquet` | `.lid`, `schema`, `vid`, `date`, `hid`, `pid` |
| trip ↔ landing link | `curated/logbook/lid_map.parquet` (own table, decision 025 kept) | `.tid`, `schema`, `.lid`, landing `date`, `hid`, `pid`, `match_type`; many-to-many allowed |
| record gear | `curated/logbook/gear.parquet` (from `adb_gear.parquet`, every schema) | `.sid`, `schema`, `gid` (logbook), `gid_landing`, `gid_used`, `gid_basis`; the logbook's `gid` is never overwritten |
| vessels, gear rules | `vessel.parquet`, `gear.parquet`, `gear_window.parquet` | as now |

**Reconstructed positions do not shape the track.**

- gps fixes enter the union with `pos_basis = "reconstructed"`. Step 0's duplicate and impossible tests, the stays,
  the voyage cut and `min_pings` read only the recorded positions.
- Reconstructed fixes take only the invalid test and the exact-tie rule. They get their voyage or stay by time
  afterwards (`rb_assign_trip`).
- This is a generic ramb rule, so ramb takes a `pos_basis` filter and documents it. It keeps today's behaviour (gps
  never touched the cleaning, stays or voyages) while the feed sits in the union as the maintainer decided.
- **Exact `(vid, time)` ties** become an explicit step-0 rule, `ais_ping_trail.R`'s rule ported as it is (stk over
  the commercial feeds; gps never displaces AIS). The losing rows go to the set-aside table, so `speed_gps` leaves the
  trail, and `checks/gear_speed_range.R` reads the gps row from the set-aside table.

## 3. Scripts by side

- **Preprocessing:**
  - `reference/*` (without `harbour_class.R`, which is removed, and `port_radius.R`, which goes to `once`);
  - `sources/*` (without `skipaskra`, which goes to `once`);
  - `curate/corrections/{afli_depth_units,adb_vs_fs_afladagbok,ports_iceland}.R`;
  - `curate/{logbook,landing,catch_by_species_station,catch_by_species_trip,ais_ping_union}.R`;
  - `curate/link_lid_map.R` (the logbook ↔ landings match; TODO 43 fixed) and the gear correction from the
    landings, `curate/corrections/adb_gear.R` widened to every schema (renamed `logbook_gear.R` + `.yml`);
  - new: `sources/stk/event.R` → target `stk_event`. It is moved from `checks/stk_event.R`, keeps its stamp, and no
    longer reads `ping_clean`.
- **Flow:**
  - step 0: `ais_ping_tag.R`, `ais_ping_clean.R`;
  - step 1: `port_stay.R` (from `harbour_stay.R`), `ais_voyage.R` (from `ais_trip.R`), `link_trip_voyage.R`;
  - steps 2 and 4: `station_window.R`, `ais_trail.R`;
  - checks: `port_stay_logbook`, `voyage_sharing`, `trail_agreement`, `trail_sid_coverage`.
- **Removed:**
  - `ais_ping_trail.R` (gps is now in the union);
  - `harbour_class.R` and its target;
  - `curate/corrections/afli_coords.R`. Its yml stays, and so does its output `staging/afli/sensor_gps`, the record
    behind parked TODO 19's corroboration check; the check's header says so.
  - The adapter's trailing diagnostic block that reads landings (`sources/afli/convert.R:397-418`) writes nothing; it
    moves into a check or goes.
- `overrides/harbour_class.csv` is kept as `overrides/port_class.csv`. It holds the three reviewed labels and sets
  nothing in the flow. `products/exports/wgsfd_harbours.R` reads it in place of `harbour_class.parquet`.
- **Size:** the main project goes from 60 targets to about 42; `once` has about 15.

## 4. Terms (the maintainer's answers, 2026-10-09)

- **Port** everywhere.
  - `pid` = port id, kept in fishycode.
  - In ramb, the `harbour*` names become `port*`: `harbour_id` → `port_id`, `harbour_from`/`harbour_to`,
    `stay_harbour_id` and `rb_trip_jepol(in_harbour)` likewise.
  - `rb_flag_ping_harbour` → `rb_flag_ping_port` (with a warning alias), and the `harbours` argument → `ports`.
  - The rule value `gap_near_harbour` → `gap_near_port`, in the stay table's `rule`/`evidence`.
- **`hid`** is the logbook's, the landings' and STK's own code. AIS tables carry `pid` only:
  - `ais/voyage`'s `pid1`/`pid2`;
  - `trip_voyage`'s `pid1_ais`/`pid2_ais`.
- **Stay** stays the one-word name of the interval in port. Its values live once, in `curated/ais/port_stay.parquet`
  (from `harbour_stay.parquet`).
  - Pings carry keys, never stay values. `stay_pid` (the stay's port repeated on every ping) becomes `stay`, a key
    into the stay table, as `voyage` keys into the voyage table.
  - This is Claude's reading of the maintainer's "values get repeated" point.
- **Voyage**:
  - the ping column `trip` → `voyage`;
  - `curated/ais/trip.parquet` → `curated/ais/voyage.parquet`.
- Also renamed:
  - `harbour_radius` → `port_radius`;
  - `curated/reference/harbour.parquet` (the landing system's code list, read by nothing) → `port_code.parquet`.
- **Not renamed** (the maintainer's choice): STK `io`, the whacky/clean table names, `provider`.
- **Glossary** in `docs/grammar.qmd`: port, pid, hid, stay, voyage, trip, record, ping, provider, frozen input.
- **Consumers updated with the renames** (from the review):
  - `R/trail_sql.R`: it globs `*.parquet`, since it reads only `part_001` today and `ais/ping` has six parts per year;
    and it takes the new columns;
  - `R/check_ready.R`: paths derived from `tar_manifest()`;
  - `checks/voyage_sharing.R`, `checks/afli_rafr_stofn_corroboration.R`, `checks/gear_speed_range.R`;
  - `docs/data-dict.yaml`, `docs/ais_trail.qmd`;
  - `curate/corrections/{logger_speed_placeholder,ping_union_duplicate_keys,stk_event_duplicate_rows}.yml`;
  - fishyweb: `linkage/ais-logbook-linkage.qmd`, `data-sources/data-dictionary.qmd`,
    `tutorials/ais_trip_tutorial.qmd`, as a separate commit there.

## 5. Phases

Each phase ends with:

- ramb tests passing;
- `check_bookkeeping()` passing;
- a decision record;
- a commit per repo.

**Stops for the maintainer:** before the rebuild, before any ramb push, before any claude.ai change.

1. **Record and split, with no output change except the `port_radius` copy.**
   - Plan 014 into `curate/plans/`.
   - Decision 075: the boundary, the terms, the frozen fixes, the AGENTS.md amendment and the three port labels.
     TODO 45 closes; TODO 44 covers plans 013 and 014.
   - `_targets.yaml` and `_targets_once.R`; frozen file targets; `Side:` headers and their check.
   - AGENTS.md names `tar_make_isolated()` as the way to build, which closes TODO 37.
   - Check: `tar_validate()` passes for both projects.
2. **Plan 013 phase 3, exact port on today's inputs**, while `ping_trail` still exists.
   - `rb_limit_record_duration`, `rb_build_record_windows`, `rb_assign_record`, `rb_link_record_pings` and
     `rb_assign_fishing(method = "window")`.
   - `R/duration_limit.R`, `station_window.R`, `R/trail_sql.R` and `ais_trail.R` call them.
   - Check: one month of the trail is identical, written to scratch.
3. **The changes**, each its own counted commit, tested on real data in scratch:
   - (a) gps into the union, with the `pos_basis` rule and the tie rule. On the gps vessels of one year: unchanged
     voyages and stays, and the ties counted.
   - (b) events and stays together: `stk_event` from STK only; an event counts as good when `io_ok` and step 0 kept
     its ping; class gone; one 2 h minimum stay. Counted against decision 073's 1,551,598 stays.
   - (c) the renames: port, voyage, stay key, pid columns, in ramb and fishycode.
   - (d) TODO 47: depth ties broken by time of day. Two runs identical; stations whose unit changes counted.
   - (e) TODO 14: the two recoverable astd months (`dump/ais/astd.R`).
   - (f) TODO 3: `resolution` on records, if each adapter's unit is unambiguous; otherwise TODO 3 stays open with the
     reason.
   - (g) TODO 41: `catch_by_species_trip.R` keyed on `(id, schema)`, rows changed counted.
   - (h) TODO 48: profile the voyage step and fix it in ramb. Check: at most 10 min on today's full `ping_clean`, same
     output.
   - (i) TODO 43: `lid_map`'s pelagic step runs (`isTRUE()` on a column), and no `(.lid, schema)` is taken by two
     trips within one step unless the link is a declared many-to-many. The landing date, `hid` and `pid` go into the
     table. Counted against today's 790,632 links (3,642 landings on two or more trips).
   - (j) Gear from the landings for every schema. First count the disagreements between logbook and landing gear,
     by gear pair and schema; the rule for `gid_used` is chosen on those counts (stop for the maintainer). `station_window`
     then reads `gid_used`, so windows and the trail change (counted).
4. **One rebuild** (stop for the maintainer's go).
   - Fingerprints before (rows, schema, row hash, per-column hashes), saved outside scratch.
   - `tar_invalidate(everything())`, because `produces()` cannot see script edits and `staging/ais/astd` is no
     target.
   - `tar_make_isolated()`.
   - Fingerprints after, every difference attributed to a step of phase 3 or to a renamed path.
   - The renamed scripts (3c) first run here: today's `ping_clean` has no `pos_basis`, so 3a and 3c cannot run
     end to end before step 0 is rebuilt. A failing target is fixed and `tar_make_isolated()` resumes.
   - After the rebuild: `docs/data-dict.yaml` redrafted for the renamed and new tables (it is drafted from the
     parquet files), the docs rendered, and the three fishyweb pages updated in that repo.
   - The superseded outputs (`harbour_stay`, `ais/trip`, `ping_trail`, `check/stk_event`, `harbour_class`,
     `harbour_radius`, `harbour.parquet`) are moved by a scripted step into `$FISHYDATA/legacy/2026-10-plan014/`.
   - A decision record.
5. **WGSFD doc v2.** "harbour" → "port" in the local md, with an AI-use line. The claude.ai master changes only on
   the maintainer's yes.

## 6. TODO items against this plan

| | Items |
|---|---|
| **close** | 45 (phase 1), 37 (phase 1), 46 (the key leaves the graph; the witness excludes gps), 47, 48, 41, 14, 3, 43 (phase 3), 44's phase-3 part (phase 4) |
| **new stub (phase 1)** | AIS as a qualifier: tracks that look like fishing with no logbook or landing (flow side, later) |
| **touched, stay open** | 34 (its question 3: the landing's gear now reaches the records); 36 (a frozen radius makes pid re-minting sharper; guard added); 25, 39, 17, 38 (the key and step-0 review: the key is now redone only by decision) |
| **needs the maintainer; could join phase 3** | 29: the afli overlap check blanks `t2`/`t3`. It fits if the maintainer chooses "keep the times and flag". |
| **not this plan** | 3c, 8, 9, 10, 15, 16, 18, 19, 21, 22, 23, 24; 27b (plan 013 phase 4) |

## Verification

- **Phase 1:** `tar_validate()` passes for both projects and `tar_manifest()` shows the new graph. The only data
  written is `port_radius.parquet`.
- **Phases 2–3:** real data written to scratch and compared with `$FISHYDATA`, never written into `curated/`.
  Differences are counted. ramb's `devtools::test()` passes; install with `R CMD INSTALL --preclean .`.
- **Phase 4:** per-file fingerprints compared, every difference with a cause in its decision record. `tar_outdated()` is
  empty afterwards and `check_bookkeeping()` passes.
