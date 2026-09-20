# Restructuring `logbooks/` + `fishydata/`

## Context

**The goal.** A *sweep of parquet files* an analyst opens and works with directly — no
pipeline knowledge required. Everything else is machinery in service of that sweep. The
ICES VMS datacall is one consumer, not the destination.

**What the project actually is.** The name is the thesis: the logbook and landings data
contain errors, and the value added here is detecting and correcting them using
cross-source evidence. Corrections are therefore **the core of the product, not exceptions
to it** — roughly nineteen already exist or are suspected (see the correction registry
below). Any structure that treats correction as a special case will be fighting the domain.

**The problem.** Two sibling repos do overlapping work with no shared code, and disagree
on which modern logbook source is authoritative. Neither knows the other exists.

**The failure mode is forking, not restarting.** Measured:

| Evidence | Count |
|---|---|
| Copies of the STK mid→vid matcher across the tree | ~9 |
| Copies of the ports domain (`../kaenugardr` shares 365/384 lines with fishydata) | 3 |
| Forked-and-drifted script pairs between the two active repos | 8 |
| Logical datasets written under the same name by both repos | 13 |
| `logbooks/R/wacky_points.R` is a fork of the installed `ramb` package | 3 of its 4 `rb_*` functions are `ramb` exports |
| Abandoned trees in `~/stasi` | `logbooks_tanked`, `STASI_tanked`, `scripts/garbage/`, `trials/`, `*_RETIRED.R` |

Every restart forked the same scripts again. The design criterion is therefore not
elegance — it is **making reuse cheaper than forking**.

**Three facts that constrain the design:**

- `station_type`, `grammar.qmd`'s flagship contribution, appears 5× in prose and **0× in
  any script**. The spec is not yet a contract.
- `FS_DATE_MAX = 2025-12-31` in `logbooks_merge.R` **expired 9 months ago** (today 2026-09-20).
- Disk: **339 GiB free, tree ~360 GB.** A second full copy does not fit.

**Constraints (user-stated).** Anti-churn is primary. Destination genuinely unsettled.
Consumers are Hafró colleagues. `data/logbooks/{trip,station,fishing_sample,catch}.parquet`
and `lid_map.parquet` must keep working throughout.

**Out of scope.** `data-dict.yaml` work, deferred. The survey stack (`opus`/`obus`/`imbus`)
is not touched and is not used as a model.

---

## The product: the sweep

```
$FISHYDATA/curated/
  logbook/    trip  station  fishing_sample  catch
  landing/    landing  catch
  link/       lid_map  trip_voyage
  ais/        ping  trip
  vessel/     vessel  vessel_ais_key        ← a fitted model, carries confidence
  reference/  gear  species  port  area_h3  dictionary
  check/      disagreement reports, one table per cross-check
```

`check/` is part of the product, not a by-product. An analyst asking "can I trust this
row?" gets a dataset to join against, not a PDF to read.

Keys: `.tid` `.sid` `vid` `sid` `gid` `hid` `pid` `h3`.

| Tier | Contents | Size | Distribution |
|---|---|---|---|
| A | Analysis sweep minus AIS pings | **365 MB** | Publish over HTTPS, versioned + manifest |
| B | Reference incl. `h3_indices`, ports | 1.3 GB | Publish, versioned |
| C | AIS pings | 44 GB | Local/server, **one copy**, hash-stamped |
| D | Raw dumps | 311 GB | Server, never leaves, never versioned |

Verified: `/u3/geo`, `/heima/einarhj`, `/net/hafgola.hafro.is` are unreachable from the
laptop; `https://heima.hafro.is/~einarhj/...` returns 200. A shared filesystem cannot be
the contract; HTTPS can, for tiers A and B only.

---

## Committed vs deferred

Only **two structural boundaries** are permanent. Both exist today and have survived every
restart:

1. **Source-shaped vs merged-shaped** — `staging/<schema>/` vs `curated/`.
2. **Data vs documents** — parquet outputs vs the Quarto site.

Everything else is a *directory*, movable with `git mv`:

| Deferred | Until |
|---|---|
| Spec as its own layer | `station_type` ships in two adapters and something breaks when violated |
| Reference data as its own layer | `stk_vessel_match` stops being a fitted model (>100-ping threshold, `2028-12-24` sentinel, 35 overlapping vid periods) |
| Extraction as its own layer | `data-dump` stops living on the laptop (156 GB of it does today) |
| Splitting curation from products | The landings cascade and the datacall stop sharing tunables (`WEIGHT_TOL_*`, `DATE_ERR_*`) |

**The QC taxonomy is not used to site boundaries.** Tested against the 13 known issues it
cleanly homes only 6; issue 1 is circular, issues 3/4/10 have two homes each, and 5/9/13
have none. Merge precedence ("afli wins") and irreducible inference (#13, "a heuristic, not
a source-derived rule") are two further classes it omits, and both are cross-layer by
nature. The taxonomy is useful for deciding *where a check is written*, not where a repo
boundary goes.

---

## Decisions

### D1 — Repo layout: a third, new repo (user's choice)

| Option | Pros | Cons |
|---|---|---|
| **New repo** *(chosen)* | Neither existing repo is right — `logbooks` has better code, `fishydata` has breadth and history; clean structure inherits neither mess | It is the pattern behind the abandoned trees; risks becoming the next one |
| Keep one | Least change; no migration | Forces a repo whose shape is wrong either way |
| 5–7 layered repos | Clean isolation | Contradicts anti-churn; one cross-cutting column becomes six release cycles |

**Non-optional safeguards:**

- **Data moves out first.** Once 360 GB lives under `$FISHYDATA`, a repo is just code and a
  third repo costs megabytes. This is what distinguishes it from previous restarts, which
  copied whole trees *with* their data.
- **A fixed archive date, agreed up front.** `logbooks` and `fishydata` go read-only on that
  date whether or not migration is complete. No parallel development — that is how forks were born.
- **Harvest before archiving.** Promote anything durable from each repo's `AGENTS.md`,
  `decisions` and Claude memory scope into the new repo first. Memory is keyed to the
  absolute path and does not migrate; the `consolidate-memory` skill does this pass.

### D2 — `fs_afladagbok` vs `adb`

Confirmed by the user: two versions of the same data; `fs_afladagbok` is the source, `adb`
its live view. Corroborated — both converted outputs carry identical junk future-date
records (2027: 3, 2028: 6, 2029: 4, 2030: 9, 2031: 4).

Never a source conflict, only **structure quality vs recency**. `fs_afladagbok` has the
better converter but ends 2025-12-31; `adb` is live and holds 20,530 stations for 2026.

**Rule for `curate/`, recorded once in `decisions/`:** `afli` where it exists → then
`fs_afladagbok` through its dump end → then `adb` beyond it. Merged max date is currently
`2025-12-12`; this closes that hole.

### D3 — Shared code

`ramb` (installed, 62 exports, v2025.09.18) already holds `rb_trip`, `rb_add_tripid`,
`rb_pad_harbour`, `rb_whacky_speed*`, `rb_cap_effort`, `rb_get_ices_metier5/6`, `dc_*`. It is
the home for shared functions; the pipeline depends on it and never copies from it.

### D4 — Corrections, cross-checks, and the human loop *(the core of the project)*

Cross-checking between datasets is the primary workload, not a QA afterthought. Corrections
already implemented: wacky coordinate recovery, `back_entry`, `eytt_deleted`, `coord_flag`,
duration caps, sentinel handling, the longitude sign heuristic, the error-tolerant landings
cascade. Suspected but unimplemented: DRB durations, gid 9 encoding, junk future dates
(2027–2031), lumpfish match rates, gear-code cross-check via landings, longline
`effort_count` semantics, **wrong vid assigned to STK data**, the 35 overlapping mid periods.
Roughly nineteen in total.

**Four rules.**

1. **Corrections live in `curate/`, never in an adapter.** A correction draws on other
   sources; an adapter that reads two other sources is no longer an adapter.
   `01_afli_wacky-tracks-interpolate.R` currently sits in the afli source area while reading
   `data/trail` — it moves.

2. **Never destroy the original.** A correction adds columns; it never overwrites. The
   precedent already exists and is right: wacky recovery retains `w_lon`/`w_lat` beside the
   corrected `lon`/`lat`. Generalise it — original, corrected, `basis`, confidence.
   `.tid` in particular is a published join key; silently re-deriving it would break saved
   analyst work and the must-keep-working constraint.

3. **Every inferred value carries a `basis`.** `grammar.qmd` already defines this vocabulary
   as `station_type`, including `"reconstructed"` = "station derived from VMS / AIS ping
   classification". Implementing it is what turns the grammar from prose into a contract.

4. **Cycles are broken by a human, outside the DAG.** Cross-checks are genuinely circular —
   AIS → vid assignment → logbook activity → *validates the vid assignment*. `targets` cannot
   express that. The resolution:

   ```
   sources → curate/checks/ → curated/check/ (disagreement report)
           → [human review] → overrides/ (committed, hand-maintained) → back in as INPUT
   ```

   The reviewed override is a **source**, not a computed output, so the DAG stays acyclic.
   This pattern already exists and works: `stk_mobile_match-and-duals.ods` is exactly such an
   override file. Formalise it as `overrides/` in the repo — small, version-controlled,
   diffable, with each entry carrying a reason.

**The correction registry.** One declarative entry per correction in `curate/corrections/`,
naming: what is wrong, how it is detected, which check produces the evidence, what is emitted
(corrected column, retained original, `basis`, confidence), the residual uncertainty, and a
status — `suspected` / `implemented` / `wont-fix` / `escalated`.

Two things follow. It gives a home to the issues the QC taxonomy could not place — #13 (the
longitude heuristic) is a correction with declared residual uncertainty; #5 (DRB durations)
is `suspected`; #9 (mid overlaps) is `wont-fix`. And **the QA documents are generated from
the registry**, so they cannot drift from the code — which is precisely the failure this
session spent its first half repairing, and which issue #10 still exhibits today: its `T2`
fix lives only as prose in `AGENTS.md` and is implemented in no script at all.

---

## Worked example: reconstructing afli trips from AIS + landings

The task the architecture must accommodate. `fs_afladagbok` has a real trip table
(`ws_veidiferd`); `afli` does not — its `.tid` is synthesised as `min(.sid)` within
`(vid, T2, hid2)`.

Measured scope:

| | Count |
|---|---|
| afli trips post-2007 (AIS era) — addressable | **681,548** |
| afli trips pre-2007 — never reconstructable | 979,343 |
| afli trips with `T1 == T2`, a zero-length window | **1,329,167 (80%)** |
| AIS trips available, 2007–2026 | 717,823 across 2,729 vessels |

Near one-to-one magnitude with the trips to be reconstructed — a good feasibility signal.

**Where it lives:** `curate/trip_reconstruct.R`, ordered after `ais_trips.R` and
`landings_match.R`, before `logbook_merge.R`. In `targets` that is a dependency edge.

**What it emits:** a new `curated/link/trip_voyage` mapping `.tid` ↔ AIS `(vid, year, trip)`
with `basis` and a confidence measure, plus improved `T1`/`T2` as *new* columns. Nothing
existing is mutated, so the must-keep-working constraint holds absolutely and analysts opt in.

**BUILT 2026-09-20** as `curate/link_trip_voyage.R` → `curated/link/trip_voyage.parquet`.
Matching is by temporal overlap on `vid`, taking the voyage overlapping the logbook trip by
the most seconds, with the issue-10 `T2` repair applied inside the query — without it the
1,329,167 afli trips whose `T1 = T2` have a zero-length window and can never match anything.

| Schema | Era | Trips | Linked | Rate |
|---|---|---|---|---|
| `afli` | <2007 | 979,339 | 6,152 | 0.6% |
| `afli` | ≥2007 | 681,532 | **652,587** | **95.8%** |
| `fs_afladagbok` | ≥2007 | 154,532 | **151,251** | **97.9%** |

Coverage of each logbook trip by its matched voyage: median 0.991, p90 1.0, but p10 0.386 —
about half the links are near-exact and there is a real tail of partial overlaps.
Multiple candidate voyages occur for 3.1–3.3% of links, consistent with the 35 vids that
have overlapping mid periods (issue 9) rather than widespread ambiguity.

**A cross-check fell out of it.** 6,152 `afli` trips dated before 2007 match an AIS voyage.
AIS did not exist then, so those logbook trips almost certainly carry wrong dates. That is a
QC signal the linkage produces for nothing, and the first concrete instance of the
cross-checking the architecture was built for.

**Known limits to record up front:** AIS coverage is partial — only 3,144 of 31,852 STK mids
matched to a vid, and small vessels may carry no transponder, so reconstruction is partial
even post-2007. Issue #10's `T2 = pmax(T2, floor_date(T1,"day") + days(1) - seconds(1))`
must be applied before any `between()` join. The 35 vids with overlapping mid periods
(issue #9) will yield ambiguous assignments.

**Why it is a good early task:** it is the real-scale test of whether the grammar is a
contract, and it pays for itself — 80% of afli trips currently have no usable time extent.

---

## Code ↔ data sync

Data is not in git. Three mechanisms, distinct jobs, one enforcing wrapper.

| Layer | Answers | Mechanism |
|---|---|---|
| `targets` | "Am I stale here, now?" | `tar_outdated()` — already in use |
| Parquet KV metadata | "What built *this file*?" | Travels inside the file; inseparable from it |
| `manifest.yml` per release | "What is in this release?" | Fetchable over HTTPS without downloading 1.3 GB |

Verified: `duckdbfs::write_dataset` writes **no** KV metadata (`parquet_kv_metadata()` on
`trip.parquet` returns zero rows). `COPY … (FORMAT parquet, KV_METADATA {…})` does work —
tested round-trip — and writes plain `TIMESTAMP` natively, so it does not reintroduce the
TIMESTAMPTZ problem that banned arrow/nanoparquet.

**One writer: `write_curated()`.** The only way anything enters `curated/`. Stamps repo,
commit SHA, dirty-tree flag, script, build time, input hashes, row count, schema hash; writes
the sidecar. Forgetting becomes impossible.

**`check_sync()`** walks `curated/`, reads each file's KV, and reports which commit built it,
whether that commit is an ancestor of HEAD, and whether input hashes still match. Run at
session start. Both bugs found today would have been caught: the stale `sensor_GPS`
(input-hash mismatch) and `trail2`'s +70 rows (recorded vs actual row count).

Two rules: **nothing under `$FISHYDATA` is ever hand-edited**, and laptop and server each keep
their own root with `published/<version>/` as the reconciliation point.

---

## How we work

| Where | What | Migrates? |
|---|---|---|
| `AGENTS.md` + `decisions/` | **Facts** — schemas, counts, decisions, layout | Yes (repo) |
| `.claude/skills/` | **Procedures** — how a recurring task is done | Yes (repo) |
| Claude memory | **Preferences** — how you like to work | No — keyed to absolute path; re-seed |

Sessions run from the new repo root, reading the archived repos and `$FISHYDATA` from there.
The archive date is also when we stop working from the old paths, so memory does not fragment
again. Keep the `AGENTS.md` convention; do not switch to `CLAUDE.md`.

**Skills — prefer enforcement over instruction.** A skill is instructions and can drift
exactly as `AGENTS.md` did; a function or test cannot. So `write_curated()` is a function,
conformance is a test, path resolution is `R/paths.R`. Skills only where the work is
judgement-shaped. Start with two, not a library (there are currently zero):

- **`add-source-adapter`** — the operation the architecture rests on, and the one most likely
  to be done inconsistently. Scaffold `sources/<name>/`, conform to the four-table contract,
  map t1–t4 per gear class, register in `_targets.R`, write the conformance test, record a
  `decisions/` note. Also the thing you hand a colleague.
- **`verify-agents-md`** — this session's first half made repeatable: every path resolves,
  every count matches the actual parquet, the targets count matches `_targets.R`, no renamed
  scripts still referenced.

---

## Sequencing — as executed (option B)

Option B was chosen over the original plan: **the new repo is built first and code is copied
into it, so neither archive is ever edited.** The only change to an existing tree is a
directory rename and, later, symlinks. Each step stands alone if the next never happens.

- [x] **0. Clone `ramb`** to `~/R/Pakkar/ramb`. Its source was not on this machine, only the
      installed binary. Confirmed `HEAD == bb2e007 ==` the installed build, so the 62-export
      inventory and the `wacky_points.R` fork finding both hold.

- [x] **1. Rename the old repo and create the new one.** `~/stasi/fishydata` →
      `~/stasi/fishydata_2024-2026` (0.018 s — same filesystem, an instant rename; 40 G and
      git history intact). A clean `~/stasi/fishydata` now holds the skeleton, `.gitignore`,
      `R/paths.R`, `AGENTS.md` and this record. Verified safe first: the only references to
      the old path were prose in `.qmd` files; no script reads it.

- [x] **2. Copy code in from both archives.** 93 files, 20,602 lines, under the new naming
      scheme (commit `bde740b`). Mapping recorded in `001-file-migration.tsv`. Neither
      archive was modified.

- [x] **3. Move data to `$FISHYDATA`; symlink the old paths.** All three moves were
      instant renames (0.004 s, 0.002 s, 0.002 s for 156 G, 155 G, 49 G). Verified after:
      `logbooks/data/logbooks/trip.parquet` still reads 1,815,425 rows through its symlink,
      so the must-keep-working constraint holds.

      **Layout decision made here:** legacy output is parked under `_data/legacy/` so the new
      pipeline can write to empty `_data/staging` and `_data/curated` without destroying what
      the equivalence gate compares against. `raw/` is shared — it is immutable input.

      | Was | Now | Symlink left behind |
      |---|---|---|
      | `logbooks/data-dump` (156 G) | `_data/raw` | yes |
      | `logbooks/data-raw` (155 G) | `_data/legacy/staging` | yes |
      | `logbooks/data` (49 G) | `_data/legacy/curated` | yes |

      Also preserved: `fishydata_2024-2026/data-raw/mmsi/` → `_data/raw/mmsi/` — the
      Fjarskiptastofa MMSI registry (through 2026-03-09), the one dataset the older archive
      held that `logbooks` did not. It is a source for the vid-assignment problem.

      **Known consequence:** `logbooks` git now reports 33 tracked scripts as deleted, because
      they lived inside `data-raw/`/`data-dump/` and git does not follow symlinks. All 33 exist
      both in this repo and at `_data`; nothing is lost. It does argue for making the archives
      read-only sooner rather than later, so no stray `git checkout` writes into `_data`.

- [x] **4. Fold the new whack functions into `ramb`.** `ramb` commit `0032b52`,
      installed locally (65 exports, up from 62). `R/wacky_points.R` deleted from this repo;
      `curate/ais_trip.R` and `curate/checks/ais_residual_whacks.R` now `library(ramb)` and
      pass `kn_max = KN_MAX` explicitly rather than relying on a global leaking into a default.

      Verified before dropping the fork: the four `rb_whacky_*` functions were **byte-identical
      in executable code** to `ramb`'s, so removing the copies is behaviour-neutral. The fork's
      roxygen was better and went back into `ramb` (it had replaced a `#' Title` placeholder).
      Packaging fixes on the way in: `kn_max = KN_MAX` → literal `25` (the global does not exist
      inside a package), examples no longer `source()` a script or name a private data path,
      and `dbplyr` + `glue` added to Imports for the lazy SQL path.
      Functional check: both filters flag a synthetic teleporting ping and nothing else.

      **`ramb` is committed locally but NOT pushed** — that needs your go.

      **Discovered while doing this: a second fork.** `fishydata_2024-2026/R/ramb_functions.R`
      holds 10 functions, 5 of which are already in `ramb` (`rb_mmsi_category`, `rb_mmsi_flag`,
      `rb_track_time`, `rb_st_keep`, `rb_st_remove`). Drift checked: three identical, and
      `rb_st_remove` has drifted in `ramb`'s favour — `ramb` namespaces `sf::st_intersects()`
      while the fork dropped it. So nothing in the fork is worth keeping. The 5 functions *not*
      in `ramb` are `letters_only`, `numbers_only`, `str_extract_between_parenthesis`,
      `rb_leaflet_raster`, `rb_cap_value` (which belongs with `ramb`'s existing `rb_cap_*` family).

      **Resolved (same day).** Investigated properly, fork #2 needed **nothing added to `ramb`**:

      | Function | Disposition |
      |---|---|
      | `rb_mmsi_category`, `rb_mmsi_flag`, `rb_mapdeck`, `rb_track_time`, `rb_st_keep` | already in `ramb` — dropped |
      | `rb_st_remove` | already in `ramb`, and `ramb`'s is *better* (namespaces `sf::st_intersects()`) — dropped |
      | `rb_cap_value` | verified to produce **identical output** to `ramb`'s existing `rb_cap_winsorize` — a redundant reimplementation, dropped |
      | `letters_only`, `numbers_only`, `str_extract_between_parenthesis`, `str_extract_dmy_period` | generic string helpers with no caller in migrated code — left in the archive rather than adding unused API surface |
      | `rb_leaflet_raster` | the **only** function the migrated code actually used (once, in `buseful_2025-05-05.R`). Inlined into that script rather than dragging `leaflet`, `raster` and `viridis` into `ramb` for one ad-hoc caller. |

      Its original called `cap_value()`, which is **defined nowhere** — the function had been
      broken in the old repo. Replaced with `ramb::rb_cap_winsorize()` on the way in.

      Also checked: `logbooks/astd.R` defines `rb_astd_build_parquet`, but shares only 7 lines
      with the migrated `dump/ais/astd.R` (69 vs 477 lines) — an early draft, superseded, left
      in the archive.

      Net effect: both known `ramb` forks are gone, and `ramb` gained three functions while
      losing none.

- [ ] **5. Two cheap premise tests, in the new repo.**
      - Add `station_type` to `station.parquet` in the `afli` and `fs_afladagbok` adapters.
        Two hours; tells you whether the grammar is a contract.
      - Fix `FS_DATE_MAX`, expired 9 months ago. The next refresh forces a merge-rule change.

- [x] **6. Equivalence gate — PASSED (2026-09-20).** The logbook chain was rebuilt from
      `raw/` and every curated table reproduces the legacy build exactly:

      | Table | Rows | Match |
      |---|---|---|
      | `logbook/trip` | 1,815,425 | exact |
      | `logbook/station` | 7,219,248 | exact |
      | `logbook/fishing_sample` | 7,219,248 | exact |
      | `logbook/catch` | 16,741,776 | exact |
      | `logbook/lid_map` | 780,203 | exact |
      | `landing/landings` | 942,984 | exact |
      | `landing/catch` | 3,818,564 | exact |

      Row counts alone would not prove much, so content was checked too — total catch
      weight, species and station counts, date and coordinate ranges, vessel counts,
      matched-landing counts, gear counts, total effort and duration, and the full
      `match_type` distribution. All identical.

      Per-adapter, also exact: `afli` (6 tables incl. 6,844,567 stations and 3,953,564
      sensor rows), `fs_afladagbok` (4), `adb` (3).

      **Scope, stated honestly.** The AIS chain was *not* rebuilt — by the decision above,
      since its model is about to change and rebuilding 565 M pings to validate something
      known to be wrong is waste. The **shapes chain was not executed either**: reference
      inputs (`staging/aux/*`, `curated/reference/port.parquet`) were seeded from
      `legacy/`, because the gate tests the logbook chain and rebuilding 2.18 M eusm
      polygons is off-purpose. `shapes_raw` and `shapes` are declared and parse, but have
      never run end to end. Worth a separate run before relying on them.

      Defects found by running, all fixed — see commit `4c00ad2`. Two of them were in code
      that had never executed at all.

- [ ] **7. Publish tiers A and B** with manifests. *External action — needs explicit
      confirmation before the first publish.*

- [ ] **8. Trip reconstruction** — the worked example above, as the first real new work.

---

## Target architecture for the vessel trail (user's stated intent, 2026-09-20)

Recorded because the code does not currently implement it, and step 8 needs a spec rather
than a memory.

| Layer | Intent | State in the code |
|---|---|---|
| **L1 Merge** | Merge *measured* positions from four peer sources: `stk`, `astd`, `astdB`, logger GPS (`afli` schema) | Present, but merges five (adds `emodnet`) and the logger source is **not measured** — it is AIS interpolated onto logger timestamps. See `curate/corrections/afli_coords.yml`. |
| **L2 Whacky removal** | Drop implausible positions — speed outliers, mostly from `stk` | Present but **misplaced**: fused into `ais_trip.R`, so the merged table still contains them |
| **L3 Interpolation** | Interpolate within trips, on top of the merged data | **Missing entirely** — no interpolation anywhere in the AIS chain. `ramb::rb_interpolate()` exists and is unused |
| **L4 Trip id** | Harbour-to-harbour trip id, **with a join key to the merged logbook data** | Trips exist (717,823) but carry **no logbook join key** |

The end product is L4: a trip identity that joins vessel movement to logbook trips.

### Naming: two different defects share a name

- **whacky point** — an implausible position (speed outlier), mostly `stk`. Handled by
  `ramb::whack_fwdbwd()` / `rb_whacky_speed()`.
- **wacky coordinate** — the DDMMmm→seconds encoding fault in the `afli` logger tables.

The repo has used *wacky* and *whacky* interchangeably for both. Fix the vocabulary when L1
is rebuilt, and rename `provider = "wacky"` to `provider = "logger"`: that source is a
measurement, and "wacky" was a defect in it that was corrected.

### Sequencing decision

**Fix after the move, not during.** The equivalence gate exists to prove the move changed
nothing; if the AIS model changes in the same pass, a difference cannot be attributed to
either. One change at a time.

Consequences, agreed 2026-09-20:

- **Step 6 is scoped to the logbook chain only** (`dictionary` → `gear` → `port` →
  `afli`/`fs_afladagbok`/`adb` → `logbook` → `lid_map`). That was the stated
  must-keep-working constraint. The AIS chain is **not** rebuilt for the gate — hours of
  compute to validate a model we have agreed is wrong.
- **Step 8 is re-scoped** from "trip reconstruction" to "rebuild the vessel trail on the
  four-layer intent", with trip reconstruction as its final layer.

---

## Open question: wacky positions inside the AIS ping table

Surfaced while declaring the build graph. A decision for the user, not a refactor to make
unilaterally.

`curate/corrections/afli_coords.R` reads `staging/ais/ping_union` to interpolate corrected
positions for the afli GPS loggers, then writes `sensor_GPS` — which `ais_ping_union.R`
folds back in as `provider = "wacky"`. Union depends on correction; correction depends on
union. Confirmed in code at `afli_coords.R:62` and `ais_ping_union.R:72`.

It sits outside the graph for now, on the same principle as `overrides/` — a genuine cycle
is broken by a person, not pretended away.

But the cycle is a symptom of the *method*, not of the data. **26.8 M of the 565.9 M rows
in the AIS ping table are not AIS**: they are logbook GPS positions whose coordinates the
current implementation replaces with AIS interpolated onto the logger timestamp.

That method looks wrong. Verified 2026-09-20 on 200,000 synthetic records against the
documented formula: the wacky encoding is **not uniquely invertible**, but it collapses to
exactly **two** candidate decodings of the vessel's own GPS reading, separated by a constant
741 m, and the truth is one of them in 100.00% of cases (60% no-rollover, 40% rollover).
So AIS is needed only to *choose* between two candidates — not to supply the position.

Choosing instead of replacing would keep the logger's own ~18 m precision rather than an
interpolation whose quality varies with `dt_sec`, would work without AIS for most points
(the logger track itself disambiguates: the wrong candidate implies a 741 m jump and an
immediate jump back), and would make the output logbook data rather than AIS-derived —
at which point the circular dependency disappears entirely.

Full write-up in `curate/corrections/afli_coords.yml`. The dataset used to derive them
contains them. Three ways out:

1. **Split the table.** `curated/ais/ping` holds real AIS only (~539 M); recovered GPS lives
   at `curated/logbook/sensor_gps` with its own `basis`. Consumers union explicitly when they
   want both. Fixes the data model, matches the "everything inferred carries a basis" rule —
   but changes the AIS row count, so the equivalence gate must expect it.
2. **Materialise a base union.** `ping_base` (4 real providers) → `afli_coords` →
   `ping_union`. Breaks the cycle properly and keeps the current output, at the cost of an
   extra 13 GB and a full extra pass.
3. **Leave the bootstrap outside the graph.** What is in place now. Correct output, but
   `tar_outdated()` cannot tell you the recovery has gone stale.

Recommendation: **option 1** — the only one that fixes the model rather than the plumbing,
and `provider` already separates the rows, so nothing is lost.

---

## Shapes chain — verified end to end (2026-09-20)

Run after the main gate, because the gate had *seeded* its reference inputs from `legacy/`
rather than building them. Both stages were executed from `raw/` and compared on substance:

| Layer | Features | Area km² | |
|---|---|---|---|
| `ports.gpkg` / `.fgb` | 6,019 | 6,499.2 | identical |
| `ices_areas_500m-buffer.gpkg` / `.fgb` | 66 | 14,439,705 | identical |
| `eusm.fgb` | 2,140,649 | 11,477,618 | identical |
| `gebco.fgb` | 9 | 13,858,337 | identical |
| `reference/port.parquet` | 143 rows | — | identical |

`port.parquet` matching matters most: it feeds both logbook adapters, so the earlier
equivalence gate — which used the seeded copy — now stands on a reproducible input.

### Two bugs found, both latent for months

**1. `write_sf()` appends to FlatGeobuf.** GDAL cannot `DeleteLayer` on that driver, so
writing to an existing `.fgb` *adds* to it. Re-running `shapes.R` silently doubled every
`.fgb`: ports went 6,019 → 12,038 features, ICES areas 66 → 132, with identical bboxes and
exactly doubled area. GeoPackage replaces correctly, so the two formats of the same object
disagreed. All 12 `write_sf()` calls now pass `delete_dsn = TRUE`.

The legacy files were correct only because they were first written into an empty directory.
This surfaced *only* because the directory had been seeded — a clean-room run would never
have shown it. Suggests the verification suite should include a **rerun-idempotency check**:
build twice, confirm the second build matches the first.

*Possible link to known issue #11* (`trail2` has 70 more rows than `trail`): `ais_ping_tag.R`
spatially joins `staging/aux/ports.fgb`, and a duplicated polygon is an overlapping polygon,
which is exactly the recorded symptom. Unconfirmed — the count is small for a wholesale
doubling, so partial duplication would be the mechanism — but it is now testable.

**2. `harbour_codes.R` was pointed at the wrong artifact.** `kaenugardr` publishes two port
files and they are not interchangeable:

| File | Contents | Used by |
|---|---|---|
| `ports_all.gpkg` | 6,019 global ports, `hid` **character** | `shapes.R`, for the AIS harbour join |
| `ports_iceland_faroe.gpkg` | 159 Iceland+Faroe ports, `hid` **numeric** | `harbour_codes.R`, the harbour crosswalk |

Repointing it at `ports_all.gpkg` during the migration produced 6,003 rows of global ports
instead of the 143-row Icelandic crosswalk, and failed on a type mismatch first. Like
`shapes_raw.R`, this script had never run locally — its original input, `data/ports/ports.gpkg`,
does not exist in the legacy store at all.

---

## Full `targets` build — passed (2026-09-20)

Everything except the AIS chain, built by `tar_make()` from `raw/` with no seeded inputs:
15 targets, 19m 59s wall clock. This is the first time the graph derived the build order
itself rather than following an order chosen by hand.

| Table | Rows | vs legacy |
|---|---|---|
| `logbook/trip` | 1,815,425 | identical |
| `logbook/station` | 7,219,248 | identical |
| `logbook/fishing_sample` | 7,219,248 | identical |
| `logbook/catch` | 16,741,776 | identical |
| `logbook/lid_map` | 780,203 | identical |
| `landing/landings` | 942,984 | identical |
| `landing/catch` | 3,818,564 | identical |
| `vessel/vessel` | 7,043 | identical |
| `vessel/vessel_ais_key` | 31,859 | +7 — explained below |

**The +7 is correct behaviour, not a regression.** All seven are unmatched records
(`step = NA`); every matching step is identical, and matched rows total 3,144 in both —
the figure the old `AGENTS.md` recorded. They are mids 154034–154040, and the cause is
input drift: `raw/ais/stk/mobile.parquet` was dumped **2026-04-27**, while the legacy
match table was built **2026-04-25**. Seven transponders appeared in those two days. The
legacy artifact is stale with respect to its own input; the new build is right.

Worth noting *how* that was diagnosed: by comparing file timestamps, because the legacy
table carries no record of which input version produced it. That is exactly the gap
`write_curated()`'s manifest closes.

**Idempotency confirmed.** `shapes` rewrote into a directory that already held its
outputs — the condition that silently doubled every `.fgb` before the `delete_dsn` fix —
and all counts held: ports 6,019, ICES areas 66, eusm 2,140,649, gebco 9.

**Timings**: `shapes` 14m 40s, `shapes_raw` 10m 34s, `afli` 1m 56s, `lid_map` 1m 40s,
`vessel_ais_key` 48s; everything else under 25s.

---

## Verification

- **Equivalence gate (step 5):** rebuilt `trip`/`station`/`fishing_sample`/`catch`/`lid_map`
  must match current counts row-for-row — 1,815,425 / 7,219,248 / 7,219,248 / 16,741,776 /
  780,203 — or every difference must be explained.
- **No-fork check:** `comm -12` across all remaining scripts; no pair above ~50 shared non-blank
  lines without written justification.
- **Reachability:** every referenced path resolves from laptop and server. Today: 2 broken
  `../landings/...` reads, and a site reading `/u3/geo/fishydata/data/ais/trail`, which no
  script writes.
- **Collision check:** no logical dataset has two writers. Today 13 do.
- **Analyst smoke test:** on a clean machine with nothing checked out,
  `duckdbfs::open_dataset("<url>/curated/logbook/station.parquet")` works and a
  station→catch→vessel→gear join runs from the published keys alone.

---

## Reversibility

| Action | Undo | Cost |
|---|---|---|
| The commit (step 0) | `git reset --soft HEAD~1` | Seconds |
| Data move + symlink (step 1) | `rm` symlink, `mv` back | Seconds — same filesystem |
| New repo | Delete it | Seconds |
| Archiving old repos | `chmod` back | Seconds |
| Publishing tiers A/B | Stop publishing | Cannot un-fetch what others already pulled — **needs explicit confirmation before the first publish** |

The 311 GB of raw dumps are never modified by anything, so every curated output remains
regenerable throughout.

## The main risk

Not technical. It is **stalling halfway and ending up with three trees instead of two** —
which is the mechanism behind the abandoned trees. It is survivable only because data is
extracted first (step 1), so the new repo is code rather than a 360 GB copy, and because the
old repos get a hard archive date with no parallel development. If either safeguard slips,
this becomes the next `_tanked` directory.
