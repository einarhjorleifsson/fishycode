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

**This assigns nothing on its own authority**, but "every row awaits human
review" turned out to be more caution than the evidence supports — corrected
same day, after the maintainer asked plainly what judgement was actually
needed. Cross-referencing each candidate's `external_id` against
`curate/checks/vessel_identity_foreign_conflicts.R`'s own output (already
built, decision 036) splits the 1,209 cleanly:

- **1,206 `needs_review == FALSE`** (1,205 before the `sources/eu` fix below) —
  a unique, unambiguous call-sign or MMSI
  match, no conflicting claim anywhere in `vessel_identity_foreign.parquet`.
  The same evidentiary bar the Icelandic cascade's own tier A/B matches clear
  with no per-row sign-off — there is no principled reason to hold the
  foreign candidates to a stricter standard for being foreign.
- **originally 4 `needs_review == TRUE`**, each with a concrete, narrow
  question, not a vague "look at this": `GINNETON`/`CETON` share an MMSI the
  EU registry itself shows claimed by two vessels over an overlapping window;
  `OLGARRY`'s call sign (`EIDF`) belonged to a different vessel for two years
  right up against this match's own period start; `PUNTA VIXIA`'s call sign
  (`FIKF`) overlaps another EU-registered vessel's claim to it.

A found-and-fixed bug along the way: the first version's `ident_lookup`
(identity context shown to the reviewer) fanned out, because one
`external_id` can carry several periods with different name/cs/mmsi (plan 008
§5.0) and a bare `distinct()` kept every combination rather than one
representative row per `external_id` — caught by `dplyr`'s own
many-to-many join warning, fixed by taking each `external_id`'s most recent
period.

## Phase 8, done same day: all 4 resolved

The maintainer's ask: make an educated guess, checking the real STK ping
data. Each of the 4 cases was resolved by comparing the mobile-id's **actual
observed ping window** (`raw/ais/stk/trail`, not the key's own extended `d1`/
`d2`) against the full period histories of every vessel competing for the
call sign or MMSI in question:

- **`PUNTA VIXIA` (mid 122163) — the flag was a source data-quality artifact,
  not a real conflict**, and disappeared once fixed. One of its two flags was
  a literal string `"null"` recorded as a call sign (an EU export defect, not
  a real blank) coinciding with another vessel's own null-string period; the
  other was a one-month typo `"FIFK"` (letters of `FIKF` transposed) colliding
  with an unrelated vessel genuinely named that. **Fixed in
  `sources/eu/convert.R`** (`na_if(cs, "null")` — 3 rows repo-wide), which
  removed this flag entirely on rebuild (`cs_overlap` 1,472 → 1,471,
  `needs_review` 4 → 3).
- **`GINNETON`/`CETON` (mid 114004) and `CETON`/ex-`ROCKALL` (mid 143927)** —
  real pings 2014-07 and 2021-10–2024-02 respectively, each squarely inside
  its own candidate's call-sign-holding period (`OYEC` and `OUHA`, distinct
  signs, matched by `cs` not `mmsi`). The flagged MMSI overlap
  (`265828000`) is a same-name (`CETON`) ownership-transfer artifact between
  these two *different* hulls, years after (2019–2021) mid 114004's pings and
  overlapping only the start of mid 143927's — irrelevant to matches made on
  the call sign.
- **`OLGARRY` (mid 148561)** — a single day's pings, 2023-11-26. The flagged
  `cs_overlap` (`EIDF` shared with `SALTEES QUEST`) is real but confined to
  2004–2007 in the registry; only `OLGARRY` still claims `EIDF` by 2023 (its
  period runs open through the export horizon), so the two-decades-old
  overlap has no bearing on a 2023 ping.

All four confirmed and recorded in
`overrides/stk_foreign_identity_reviewed.csv`, with the reasoning above per
row. Not yet wired to feed back into the matching cascade automatically —
that plumbing is separate, later work.

## What's still open

Plan 008 §7 Phase 6 (ASTD residual pass). Phase 8's review loop is now
demonstrated end-to-end for this batch; a mechanism for `overrides/` entries
like this one to actually feed back into `ais_key_foreign.R`'s output is
still to be built.
