# 035 — Plan 008 Phases 1–2: raw data landed, four adapters built

*2026-09-27. Plan `008-north-atlantic-vessel-registry.md` §7, Phases 1–2.*

## What was built

**Phase 1** — moved from `~/garbage/vessels_from_...` into
`$FISHYDATA/raw/external/{eu,fro,nor,gfw,marinetraffic}/`, verified by md5/diff
on a sample from each. The two GFW effort-grid zips and the confirmed-duplicate
`dffc3970-...zip` were left out, per the plan.

**Phase 2** — four adapters, each a literal translation of its source's own
layout, no cross-source reasoning:

- **`sources/gfw/convert.R`** → `staging/gfw/vessel.parquet`, 114,191 rows.
  Kept every `_inferred`/`_registry`/`_gfw` triple and `registries_listed`;
  dropped `fishing_hours_*` (activity, not identity).
- **`sources/eu/convert.R`** → `staging/eu/vessel_event.parquet`, 1,079,981
  rows (one per `cfr`/event, unchanged from the source's own ledger).
  `uvi` → `imo` only where it passes the IMO check-digit algorithm — asserted
  with `stopifnot()`, not assumed; still true on the full table (42,780 of
  42,780 populated rows).
- **`sources/fro/convert.R`** → `staging/fro/vessel.parquet`, 3,813 rows (one
  per FRO `vid`, pivoted from the long per-vessel files). Found and fixed two
  defects in the source itself while building this: its own NA marker is
  spelled both `"Einki ásett"` and `"einki ásett"` (709 of 6,129 sampled
  occurrences are the lowercase form), and the `Byggiár / skipasmiðja`
  (build-year/shipyard) field's separator is `" / "` — a stray
  non-breaking space before the slash, not a plain space — which silently
  failed every split until traced to the byte level (`nchar` 16 vs `bytes`
  17 was the tell). Both normalized once, at read time, rather than patched
  in every downstream regex.
- **`sources/norway/vessel_registry.R`** → `staging/norway/vessel_registry.parquet`,
  153,755 rows (one per `fartoy_id`/year, 2001–2022; placed in the existing
  `sources/norway/` directory alongside its VMS/logbook/catch adapters, not a
  new `sources/nor/`, to avoid two Norway directories with different names).
  Found 199 `(fartoy_id, year)` groups carrying more than one owner row
  ("Fartøy og eier i **første** eierledd" — first ownership tier is not
  always one owner) — deduplicated to the largest `ownership_share`, same
  call as `fro`'s: a full ownership breakdown is not what this table is for.

## What's still open

Phase 3 (the merge script, `curate/vessel_identity_foreign.R`) and everything
after it in plan 008 §7 — this decision covers Phases 1–2 only.
