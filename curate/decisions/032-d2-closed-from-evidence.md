# 032 — `d2` closed from evidence, not left open by default

*2026-09-26. Plan `003-stk-vessel-identity.md` §4.3, step 6. Measured against
`$FISHYDATA` as it stands.*

## What was built

`reference/vessels/ais_key.R`'s date-extension step used to write the
`2028-12-24` sentinel onto the last period of **every** mobile-id, unconditionally.
That is what made §3.2's 124 vids exist twice at once: when a vessel changes
transponder, the old mobile-id's window never closed, so its sentinel and the new
mobile-id's window overlap for years.

The fix measures first, per §4.3. For each of the **123** vids currently carrying
more than one assigned mobile-id, its mobile-ids are ordered by their own
first-observed ping (from `stk`, before the manual-duals join and before any
extension — the machine's own record, not the registry or landings, so the cycle
rule in `AGENTS.md` is not touched). Each mobile-id is then one of:

- **`currently_live`** — the chronologically last mobile-id for its vid. Nothing
  to compare it against; keeps the sentinel.
- **`clean_handover`** — a later mobile-id for the same vid starts after this one's
  last observed ping. The old device fell silent first, so `d2` is closed at that
  last ping instead of the sentinel. **49 of 172 mobile-id periods.**
- **`overlap`** — the later mobile-id starts *before* this one's last observed
  ping, in some cases by years (vid 1902's `mid 101406` pings on through a
  corrupted `2106-02-06` timestamp — §3.6's defect — while `mid 143788` has been
  live since 2021). That is either a genuine two-transponder vessel or a matcher
  error (§3.1's class), and deciding which is a human call that re-enters through
  `overrides/`, not this script. **82 of 172**, left exactly as before (sentinel,
  open).

A new column, **`d2_is_open`**, carries the distinction explicitly rather than
overloading the date itself — a mobile-id that is genuinely still transmitting and
one whose `d2` has been closed from evidence both used to look like "runs to
2028"; now only the former does.

## What it actually fixed, measured

`curate/checks/ais_key_registry.R`'s `two_mids_open` check — which reports exactly
this defect (`d2 > .next_d1` on the stored key) — needed no code change: closing
the 49 clean-handover periods removes them from it automatically, since their
`d2` no longer extends past the next mobile-id's start.

| | before | after |
|---|---|---|
| `two_mids_open` rows | 137 | **95** |

The remaining 95 are the genuine `overlap` population (some vids contribute more
than one flagged row when they carry three or more mobile-ids). Nothing in this
change withdraws or reclassifies them — they are exactly as reviewable as before,
just no longer mixed in with cases that had a clean answer.

**Gated:** no vid assignment changed, no `pings`/`step`/`entity_class` column
changed row for row for any already-assigned mobile-id; the only new state is
`d2_is_open` and, on the 49 closed periods, a `d2` that now equals a real observed
last ping instead of the sentinel.

## What is still open

The 82 `overlap` periods are the residual plan 003 step 6 was not asked to
resolve — routing them to `overrides/` (transponder-swap-with-handover vs.
matcher error) is a human review pass, not a rule. `curate/checks/
ais_key_registry.R`'s `two_mids_open` output is where that review starts.
