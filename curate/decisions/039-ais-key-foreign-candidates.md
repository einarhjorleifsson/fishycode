# 039 — Plan 008 Phase 5: foreign identity candidates for STK's unmatched residual

*2026-09-27. Plan `008-north-atlantic-vessel-registry.md` §7 Phase 5.*

## A correction found while building this

The plan's original §5 said `vessel_identity_foreign.parquet`'s `source`
column would include `marinetraffic_match`. Building the matcher showed why
that never fit: MarineTraffic's rows are already-matched STK-`mobileid`-keyed
candidates (§3, one person's manual lookups), not vessel-registry periods with
a native id and a time window — forcing them into that table's shape would
have been artificial. Corrected: `marinetraffic` stays out of
`vessel_identity_foreign.parquet` and is instead a direct `mobileid` join,
exactly as §5/Phase 5's own prose already described it before the schema
table overreached.

## What was built

**`reference/vessels/marinetraffic.R`** — the small loader plan 008 §7 Phase 2
called for and this session had skipped. No `staging/` table (1,230 rows
isn't worth persisting a copy of); returns `marinetraffic_matches` in memory.
`CS_MARINE_TRAFFIC_MATCH4.xlsx`'s 823 rows are confirmed a strict subset, by
`mobileid`, of `STK_MARINETRAFFIC_MATCTH.xlsx`'s 1,230 — the larger file is
used whole, its `n_vms` column (a rough confidence count) carried over.

**`reference/vessels/ais_key_foreign.R`** → `curated/check/ais_key_foreign_candidates.parquet`
— a **separate** script from `ais_key.R` (~700 lines already; plan 003's own
closing note against bundling a rewrite with new behaviour applies here too).
Reads `vessel_ais_key.parquet`'s currently-unmatched vessel-class mobile-ids
(12,587, 23.8M pings) and runs them through three stages, each only trying
what the previous one left unmatched:

| stage | method | candidates |
|---|---|---|
| 1 | `marinetraffic`, direct `mobileid` join | 910 |
| 2 | `cs`, time-aware, via `match_time_aware(id_col = "external_id")` | 193 |
| 3 | `mmsi`, time-aware, same function | 106 |
| **total** | | **1,209** mobile-ids, 9,052,146 pings |

**11,378 mobile-ids remain unmatched** after all three stages — plan 008
Phase 6's ASTD residual pass.

**This assigns nothing.** Per `AGENTS.md`'s cycle rule, every row is a
candidate for a human to review, re-entering through `overrides/` only once
confirmed — same shape as `curate/checks/ais_key_reused_callsign.R`'s own
candidate list. A found-and-fixed bug along the way: the first version's
`ident_lookup` (identity context shown to the reviewer) fanned out, because
one `external_id` can carry several periods with different name/cs/mmsi (plan
008 §5.0) and a bare `distinct()` kept every combination rather than one
representative row per `external_id` — caught by `dplyr`'s own
many-to-many join warning, fixed by taking each `external_id`'s most recent
period.

## What's still open

Plan 008 §7 Phase 6 (ASTD residual pass) and Phase 8 (the human review loop
that actually promotes any of this to `overrides/`).
