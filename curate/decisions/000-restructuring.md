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

- [ ] **2. Copy code in from both archives.** `logbooks` wins all 8 forked pairs; take each
      unique `fishydata_2024-2026` contribution (datacall, Norway, Faroe, GFW, ports,
      `rb_scrape_marinetraffic.R`). Nothing is deleted from either archive. Seed
      `curate/corrections/` with the ~19 known entries, most as `suspected` — this converts
      the drifting numbered list in the old `AGENTS.md` into something runnable.

- [ ] **3. Move data to `$FISHYDATA`; symlink the old paths.** Both archives and `data-dump`
      are on one filesystem (device `16777231`), so each move is an instant rename — no
      half-copied failure mode, and 339 GiB free would not permit a copy anyway. The symlinks
      keep the archives runnable during the equivalence gate. Undo: remove symlink, `mv` back.

- [ ] **4. Fold the new whack functions into `ramb`** (`whack_fwdbwd`, `whack_forward`,
      `whack_sequential_fast`); do not migrate the four forked `rb_*` copies.

- [ ] **5. Two cheap premise tests, in the new repo.**
      - Add `station_type` to `station.parquet` in the `afli` and `fs_afladagbok` adapters.
        Two hours; tells you whether the grammar is a contract.
      - Fix `FS_DATE_MAX`, expired 9 months ago. The next refresh forces a merge-rule change.

- [ ] **6. Equivalence gate.** Rebuild the sweep; compare against current outputs. Only on
      success do the archives go read-only, on the agreed date.

- [ ] **7. Publish tiers A and B** with manifests. *External action — needs explicit
      confirmation before the first publish.*

- [ ] **8. Trip reconstruction** — the worked example above, as the first real new work.

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
