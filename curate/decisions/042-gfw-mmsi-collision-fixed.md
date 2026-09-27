# 042 — GFW's own MMSI rows were blocking real registry matches

*2026-09-27. Plan `008-north-atlantic-vessel-registry.md` §7 Phase 5, found
while reviewing the top fishing-relevant ASTD candidate.*

## What was found

Walking through the single highest-ping candidate in the fishing-relevant
slice of the flagged ASTD pool (mid 114277, MMSI `231009000`) turned up
something worth more than that one row. Checked by hand:

- ASTD's **full** broadcast history for this MMSI (not just the one snapshot
  the cascade used): 813,524 pings, 2013–2026, name `BAKUR` in 99.97% of
  them, IMO `9258820`, flag Faroe Islands — as internally consistent as
  evidence gets.
- `vessel_identity_foreign.parquet` **already had this exact IMO**, under
  `source = "fro"`: `BAKUR`, call sign `OW2335`, MMSI `231009000`, registered
  since 2002.

So why was this sitting in the ASTD fallback tier at all, rather than
matching at stage 3 (MMSI, against the registry) days earlier in the
cascade? Because `gfw`'s own row for the same MMSI (`external_id =
"gfw_231009000"` — `gfw`'s `external_id` is always `gfw_<mmsi>`, plan 008
§5.0) was *also* sitting in the table, and `match_time_aware()` saw two
candidates sharing that MMSI and correctly refused to pick between them —
except they were never competing identities, just the same vessel described
twice, once by a real registry and once by GFW's own generic placeholder.

**Measured, not assumed, before fixing**: of 6,322 distinct MMSIs in
`vessel_identity_foreign.parquet` claimed by more than one `external_id`,
**6,306 (99.7%) are exactly this pattern** — `gfw` plus exactly one real
source. Only **16** are genuine multi-registry disagreements.

## What was built

In `ais_key_foreign.R`, immediately before stage 3: `gfw`'s row for a given
MMSI is dropped from the candidate pool whenever a non-`gfw` source
(`eu`/`fro`/`nor`) also claims that MMSI. `gfw` still competes normally for
any MMSI it is the *only* source for.

**Effect**: stage 3 (`mmsi`) rose 736 → **913** (+177, all now registry-backed
and unflagged); stage 4 (`astd`) fell 4,295 → 4,200 and stage 5 (`astdb`) fell
722 → 659 — the same 177 candidates, no longer needing the weaker fallback
tiers at all. `needs_review == FALSE` rose 2,529 → **2,706**.

## A second collision pattern checked, and left alone — for now

Also checked `cs_overlap` (1,471 rows) for a similarly dominant, fixable
pattern. It isn't one: **all** are same-source (`eu`↔`eu` except one
`nor`↔`nor`), and only ~100 of 1,471 trace to malformed placeholder call
signs (`"TBA"`, single letters, bare ITU prefixes like `"9H"`). The rest —
the large majority — are two *different* EU vessels (`CFR`s) genuinely
sharing a call sign at overlapping times, both sides typically an
active-looking `MOD`/`CEN` event, not a stale exit-event sentinel. Unlike
`fro`, EU has no `status`-style field saying which of two claimants is
current, so the succession-chain fix that worked for `fro` (decision 041) has
no clear signal to key off here. Left as a genuine, documented residual
rather than forcing an under-justified heuristic.
