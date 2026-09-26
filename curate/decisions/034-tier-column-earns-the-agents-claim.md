# 034 — `vessel_ais_key` earns its "carries confidence" claim

*2026-09-26. Plan `003-stk-vessel-identity.md` §4.4, step 7. Measured against
`$FISHYDATA` as it stands, after decisions 032 and 033.*

## What was built

`AGENTS.md`'s layout table has always said `vessel_ais_key` "is a *fitted
model*, not a registry — it carries confidence." It never did — the cascade's
step order is a confidence ranking, but it lived only in the order rules ran in,
unlabelled. `reference/vessels/ais_key.R` now writes a `tier` column, mapped
from `step`:

| tier | rules | rows | rests on |
|---|---|---|---|
| A | `vid_vid`, `vid2_vid2` | 1,842 | `loid == glid`, both parse as a registered vid — not time-gated, a vid is the keel |
| B | `vid_cs`, `vid2_cs`, `uid_cs`, `NA_vid`, `loid_cs` | 472 | one identifier, corroborated by a second field, time-aware against `vessel_identity` |
| C | `manuals` | 485 | the duals spreadsheet — a person decided |
| D | `NA_csts`, `NA_mmsi`, `afmadur` | 141 | one weak field, no corroborating field (`afmadur` rests on absence of a clash, not a second identifier) |
| E | `older` | 3 | a previous session's match, gated only on `pings > 100` — the script's own comment calls it a hail mary |

`loid_cs` and `afmadur` did not exist when §4.4 was drafted (they were added by
decision 013, after step 3) and are placed here for the first time: `loid_cs` is
tier B because it is a second-field corroboration exactly like `vid_cs`, just
sourced from `loid` instead of `glid`; `afmadur` is tier D because its evidence
is a single field (a parsed `loid`) plus the *absence* of a clash, not a second
identifier confirming the first.

A check runs on every build: `filter(!is.na(vid), is.na(tier))` must be empty,
so a future step added to the cascade cannot silently go untiered.

## What tier A does not mean

Tier is a confidence ranking over *how the match was made*, not a guarantee the
result is right. Mid 101661's `vid_vid` match — two fields agreeing, tier A —
resolves to vid `-2605`, which nothing in the cascade validates; it is still
flagged separately by `curate/checks/ais_key_registry.R`'s `negative_vid` check.
Tier and the registry checks are complementary, not redundant: tier says how the
evidence was assembled, the checks say whether the assembled result holds.

## The `AGENTS.md` line

Left as written — it is now true. No further action needed there.
