# 038 — One vessel-identity table an analyst actually opens

*2026-09-27. Plan `008-north-atlantic-vessel-registry.md` §7, addition to
Phase 3.*

## The gap

Phases 1–4 built `vessel_identity_foreign.parquet` as a table separate from
the existing `vessel_identity.parquet` — deliberately, since `vid` is a real
primary key other scripts (`ais_key.R`, `mmsi.R`) rely on, and folding foreign
rows into it would mean either faking a `vid` for a vessel that never had one
or giving up `vid`'s status as a key.

That reasoning is still right for the two *specialized* tables. It is not a
reason to stop there. `AGENTS.md`'s premise is a sweep of parquet an analyst
opens with no pipeline knowledge required — and two vessel-identity tables an
analyst has to know exist and combine themselves is exactly the pipeline
knowledge that is supposed to stay hidden. Caught by the maintainer asking,
plainly, "are we not going to have a single vessel.parquet that covers
everything?"

## What was built

**`reference/vessels/identity_all.R`** → `curated/vessel/vessel_identity_all.parquet`
— a union built fresh each run, not a third source of truth. `vessel_identity.parquet`
and `vessel_identity_foreign.parquet` are untouched and still exist for the
pipeline's own internal joins (`ais_key.R` against the former,
`ais_key_foreign.R` — plan 008 Phase 5, not yet built — against the latter).

The union: 1,228,374 rows, `source` = `ISL`/`eu`/`fro`/`nor`/`gfw`,
`external_id` populated for **every** row (IMO-first, same check-digit rule as
the foreign table; `isl_<vid>` for Icelandic hulls with no IMO — 533 of 7,043
have one), `vid` surviving as its own column, populated only where
`source == "ISL"`. A lookup by IMO now works regardless of which side of the
union a vessel came from; a lookup that only cares about the Icelandic fleet
filters `source == "ISL"` and gets exactly `vessel_identity.parquet`'s own
5,169 rows back.

Written with `write_curated()` — third adopter, after `harbour_codes.R` and
`identity_foreign.R` (TODO item 12).
