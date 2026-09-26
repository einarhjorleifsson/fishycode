# 037 — `R/vid_match.R` generalized to `id_col`, not duplicated

*2026-09-27. Plan `008-north-atlantic-vessel-registry.md` §7 Phase 4.*

## What was built

`match_time_aware()`, `confirm_vid()` and `match_identity_pair()` each gained
an `id_col = "vid"` parameter. Every existing call site in `ais_key.R` is
unchanged (the default preserves current behaviour exactly), and the same
three functions now also work against `vessel_identity_foreign.parquet` with
`id_col = "external_id"` — no second matcher for
`reference/vessels/ais_key_foreign.R` (Phase 5) to write.

## A regression, caught before it shipped

The first version of `confirm_vid()`'s rewrite dropped the join's second key
by accident — the original joins `by = c("vid", "val")` (candidate id **and**
corroborating value must both match); the rewrite joined `by = "..id"` alone,
so a probe row confirmed against *any* period of the right vid regardless of
whether the corroborating field actually matched.

Caught by running `ais_key.R` end to end and diffing against the last
committed baseline rather than trusting memory of the numbers: distinct
assigned vid rose from 2,820 to 2,824, tier B from 472 to 498 rows — small,
plausible-looking deltas that would have been easy to wave off as noise.
Restoring the two-column join (`by = c("..id", "val")`) reproduced the
baseline exactly — same row count, same tier counts (A 1,842 / B 472 / C 485
/ D 141 / E 3), same `step` counts down to the last row, same
`d2_is_open` split. Verified with a git-stash A/B comparison against the
pre-change file, not just re-running once and eyeballing the diff.

## New behaviour, smoke-tested

All three functions confirmed working against
`vessel_identity_foreign.parquet` with `id_col = "external_id"`: a real
`(cs, t1, t2)` row resolves through `match_time_aware()`, the same row
confirms through `confirm_vid()` given its own `external_id` as the stated
candidate, and a `(cs, mmsi)` pair resolves through `match_identity_pair()`.

## What's still open

Plan 008 §7 Phase 5: `reference/vessels/ais_key_foreign.R`, the
candidate-matching script that actually calls these against STK's unmatched
residual.
