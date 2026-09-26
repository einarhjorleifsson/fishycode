# 036 — Plan 008 Phase 3: `vessel_identity_foreign.parquet` built

*2026-09-27. Plan `008-north-atlantic-vessel-registry.md` §7 Phase 3.*

## What was built

**`reference/vessels/identity_foreign.R`** — placed alongside `registry.R`/
`identity.R`/`mmsi.R`/`ais_key.R`, not under `curate/`, matching the existing
convention that vessel-domain scripts live together in `reference/vessels/`
regardless of layer (`identity.R` itself is a merge step and lives there too;
plan 008 originally said `curate/vessel_identity_foreign.R`, corrected here).

Reads all four Phase 2 staging tables, resolves `external_id` (IMO where it
passes the check-digit algorithm, `<source>_<native_id>` otherwise — plan 008
§5.0), and writes `curated/vessel/vessel_identity_foreign.parquet`:

| source | rows | notes |
|---|---|---|
| `eu` | 1,079,981 | one per (CFR, event) — the source's own real periods, unchanged |
| `fro` | 3,813 | one snapshot per vessel, `t2` unbounded |
| `nor` | 25,220 | collapsed from 153,755 year-rows into change periods (below) |
| `gfw` | 114,191 | one snapshot per MMSI, no dates at all |

**1,223,205 total rows, 319,576 distinct `external_id`** — close to the sum of
each source's own distinct count (183,748 + 3,813 + 17,835 + 114,191 ≈
319,587), meaning cross-source IMO merging is real but rare so far: only
43,111 of 1,223,205 rows resolve to an actual IMO rather than a source-local
id, and the small gap between 319,587 and 319,576 is the entire measured
overlap. Not surprising — a vessel genuinely tracked by both an EU flag state
and GFW's own registry cross-reference is the exception, not the rule.

**NOR's period-collapsing** (22 one-year snapshots → change periods, per
`fartoy_id`, split wherever `cs` or `name` changes, an NA↔non-NA transition
counting as a change) worked as intended — spot-checked `nor_1920009102`:
`FIRDA` (2001–2003) → `FIRDA SENIOR` (2004), two periods, not 22 identical
rows for one hull.

Written with `write_curated()` — the **second** adopter after
`harbour_codes.R` (TODO item 12), materialised data frame, no lazy-relation
blocker.

## The conflicts check

**`curate/checks/vessel_identity_foreign_conflicts.R`** →
`curated/check/vessel_identity_foreign_conflicts.parquet`, mirroring
`identity.R`'s own overlaps/gaps assertions:

| check | rows | what it means |
|---|---|---|
| `mmsi_overlap` | 20 | an MMSI resolving to two `external_id`s at an overlapping time — the case a time-aware join is built to prevent |
| `cs_overlap` | 1,472 | same, for call sign — the primary match key in practice, so it earns the same check |
| `imo_flag_conflict` | 843 | the same IMO appearing under more than one flag across sources — **not time-aware yet**, so most of these are plausibly ordinary reflagging over the years, not data errors; worth narrowing before this is used for review, not before it's built |

**Reports only, resolves nothing** — per `AGENTS.md`'s cycle rule, same as
`ais_key_registry.R`.

## What's still open

Plan 008 §7 Phases 4 onward: generalizing `R/vid_match.R`'s `id_col`, the
candidate-matching script, human review, the ASTD residual pass, and
`_targets.R` wiring.
