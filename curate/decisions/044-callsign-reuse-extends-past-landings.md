# 044 — The reused-call-sign defect extends well past the landings-only review

*2026-09-28. Extends `curate/corrections/ais_key_callsign_reuse.yml` and
decision 020's candidate review.*

## What was found

The maintainer's own cross-check: `open_dataset(curated/ais/ping) |> count(vid,
provider) |> spread(...) |> filter(is.na(stk))` — which Icelandic vids have real
pings in ASTD/astdB/EMODnet but **none at all** in STK, Iceland's own domestic
receiver network. **19 vids**, several with substantial volume (DÍSA 881,869
ASTD pings, PÁLL PÁLSSON 824,964, KEILIR 624,651).

All 19 hold a call sign shared by 2–4 other vids in `vessel.parquet` (checked
directly, not assumed). One (vid 1599, `ÖNGULL`) is already documented in the
correction as genuinely never transmitting — not a defect. The other 18 were
reviewed the same way decision 020 did, with one adaptation: decision 020's
check required a *landing* to define the vessel's real activity window, which
excludes non-fishing classes entirely (Coast Guard `ÓÐINN`/`TÝR`, the ferry
`HERJÓLFUR`, and others in this list have no landings at all). Substituting
the vessel's own **other-provider ping window** (from `curated/ais/ping`,
already built) as the independent activity signal instead of a landing window
covers exactly the same population this correction's own scope note excluded
by construction.

**Result: all 18 show a real STK mobile-id broadcasting their exact call sign,
with a ping span genuinely overlapping their independently-confirmed activity
window, that `vessel_ais_key.parquet` never assigns to them.** Same defect as
the confirmed `TFBR`/vid 3047 case (`ais_key.R`'s flat, timeless call-sign
lookup), just never measured outside the landings-only population before.

Bucketed the same way decision 020 did (ghost / handover / overlapping),
substituting the *other holder's* own other-provider evidence for the
landings comparison:

- **9 ghost** (the vid the call sign is currently pinned to has *zero*
  independent evidence anywhere): PÁLL PÁLSSON (already known, `ais_key_reused_callsign.parquet`), THE LADY, ARCTIC ROSE, GRETTIR STERKI,
  SIGURVIN, SMYRILL, HANNES Þ. HAFSTEIN, BJÖRG, and DÍSA (against holder 1473).
- **8 overlapping** (the current holder has real, independent activity in the
  *same* window — two vessels genuinely active under one call sign, not
  decidable from AIS alone): HERJÓLFUR, OCEAN SPIRIT, KEILIR, TEISTA, ÓÐINN,
  SIF, INGIBJÖRG, GULLTOPPUR.
- **DÍSA (vid 2815) is both**: `TFBR` is a genuine three-way collision —
  HÓLMBERG (1473, ghost, the call sign's current holder), HILDUR (3047,
  already patched by the correction, real overlapping activity), and DÍSA
  (2815, real overlapping activity, still unassigned). The existing patch
  fixed 3047 as if `TFBR` were a clean two-way split; it is not — DÍSA's own
  activity overlaps the same era HILDUR's does.
- **TÝR (vid 1421)** is a fourth pattern: mid 101444 shares its call sign
  (`TFGA`) and overlaps its activity window, but is **not present in
  `vessel_ais_key.parquet` at all** — not assigned elsewhere, simply absent
  from the cascade.

## What was not done

This REPORTS, per the correction file's own rule and `AGENTS.md`'s cycle
rule — no vid was reassigned, and `ais_key.R`'s structural fix (already
proposed, not implemented, per the correction) is still not built. A
conclusion here re-enters only through `overrides/`, reviewed one case at a
time, same as the original 3 that were patched.

**Scope note for whoever resolves these next**: the "ghost" bucket is the
same strength of evidence as the original 3 fixes; the "overlapping" bucket
and DÍSA's three-way case are exactly the ambiguous middle decision 020 left
for a human, not a computed answer.
