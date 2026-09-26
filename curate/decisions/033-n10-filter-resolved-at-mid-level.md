# 033 — The `n >= 10` filter is restored at mid level, not as originally written

*2026-09-26. Plan `003-stk-vessel-identity.md` §3.5, step 9. Measured against
`$FISHYDATA` as it stands.*

## The bug

```r
STK |> group_by(mid, year) |> mutate(n = n()) |> ungroup() |>
  mutate(n = n()) |>            # overwrites the grouped count with nrow()
  filter(n >= 10)               # therefore always TRUE
```

`reference/vessels/ais_key.R:236` (old numbering). The second `mutate()` ran on
ungrouped data, so `n` became the total row count of the whole trail and the
filter never removed anything. Confirmed: the trail has 31,791 distinct `mid`
and the key had 31,791 too.

## Why "restore it exactly as written" was rejected

Restoring the literal `group_by(mid, year)` grouping was measured first, not
assumed. It drops 12,822 mobile-ids entirely (avg. ~2.1 pings each — clearly
noise) but **also** drops 264 vids' only mobile-id outright, because a vessel
that pings 5–10 times a year across several years never clears 10 in any single
year, even when its lifetime total is fine (up to 43 pings, just spread thin).
**166 of those 264 carry an MMSI or are 15 m+** — exactly the "should be
trackable" population plan `003` §4.7 calls the real gap. The per-year grouping
would have silently handed the completeness check (`ais_key_registry.R`'s
`icelandic_vessel_not_in_ais`) 166 false negatives while fixing a no-op.

## What was built instead

The threshold is applied to the mobile-id's **lifetime** total (`group_by(mid)`,
not `group_by(mid, year)`). Measured: this removes the same noise population —
12,628 mobile-ids, same ~2 pings/mobile-id average — while orphaning only 203
vids, **zero** of which carry an MMSI or are 15 m+. Same intent (drop mobile-ids
that never produced a real track), none of the collateral cost.

| | per-(mid, year) (rejected) | per-mid lifetime (built) |
|---|---|---|
| mobile-ids dropped | 12,822 | 12,628 |
| pings dropped | 43,529 (0.015%) | — |
| vids orphaned entirely | 264 | 203 |
| orphaned vids with MMSI or 15 m+ | **166** | **0** |

## Effect on the key, measured

Rebuilt against decision 032's version (step 6, already landed):

| | before (filter still broken) | after |
|---|---|---|
| key rows | 31,862 | 19,234 |
| distinct vid assigned | 3,038 | 2,820 |
| `two_mids_open` | 95 | 90 |
| `outside_vessel_lifetime` | 39 | 27 |
| `negative_vid` | 15 | 14 |

Coverage percentages are essentially unchanged (62.39% → 62.48% vid, 59.74% →
59.84% mmsi) — the rows removed carried almost no pings between them. The row
count drop is real but is the filter finally doing its job: noise leaving the
key, not vessels.
