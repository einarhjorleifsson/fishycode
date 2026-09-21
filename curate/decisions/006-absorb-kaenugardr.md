# 006 — kaenugardr is absorbed into fishydata

*2026-09-21. Raised by the maintainer after a session spent fixing a harbour
defect across both repos. Supersedes a rule currently written in `AGENTS.md`.*

## What this supersedes

`AGENTS.md` says, under **Rules**:

> **Upstream repos are consumed as artifacts, never as copied code.** Two exist:
> | Repo | Produces | Consumed here as |
> | [`ramb`] | R functions | `library(ramb)` |
> | [`kaenugardr`] | port polygons | `fd_raw("ports", "ports_all.gpkg")` |

The `ramb` half stands. The kaenugardr half does not, and is withdrawn.

## Why the rule fits `ramb` and not kaenugardr

They are different kinds of thing, and the rule was written for the first:

| | `ramb` | `kaenugardr` |
|---|---|---|
| form | R package — `DESCRIPTION`, `NAMESPACE`, `R/` | loose scripts, no package files |
| consumed as | `library(ramb)` — a real dependency | a **hand copy** of its output files |
| live consumers | several | **one: this repo** |

Checked, not assumed: the only references to kaenugardr outside itself are in
this repo, in `logbooks` and `fishydata_2024-2026` — the two predecessors this
repo already replaced and which are never to be edited again — and in a legacy
data tree. There is no second consumer to protect.

## Why absorbing is not the failure the rule guards against

The rule exists because **forking** killed the previous trees: five `ports-*.R`
scripts had been copied into the old fishydata, one sharing 364 of 384 lines
with kaenugardr's, and they drifted. That is a real failure and the rule is
right about it.

But absorbing is the opposite operation. Forking creates a second copy;
absorbing removes one. After this there is exactly one `ports_all.R` in
existence, which is what the rule wanted all along.

## The four reasons

1. **The hand copy is itself the defect.** `$FISHYDATA/raw/ports/ports_all.gpkg`
   and `ports_iceland_faroe.gpkg` are byte-identical (md5) to kaenugardr's
   outputs, placed by hand, with no import step and no version stamp (TODO 3b).
   That is not a sync problem to be solved with more process; it is a
   consequence of the boundary. Removing the boundary removes it, and satisfies
   3b's check clause outright.

2. **The split made the defect unfixable from either side.** Fixing the
   Hellnar/Hellissandur/Hnífsdalur polygon needed kaenugardr's code *and* this
   repo's verification — `ping_tagged`, the trail, the row counts. Neither
   repo alone could do it. TODO item 4 had already recorded the asymmetry: a
   session opened inside kaenugardr "starts blind: its memory scope is that
   path, its `AGENTS.md` documents the schema but not this defect, and it has no
   `decisions/` convention at all."

3. **Data stops living in git.** kaenugardr carries **745 MB of Git LFS**
   precisely because its data sits in the repo. This repo's rule is "All data
   lives under `$FISHYDATA`. Nothing is written into this repo." Under that
   rule the port data needs no LFS at all.

4. **The conventions this needs are defined here, and partly built.** `targets`
   owns staleness — 23 targets, real. `curate/corrections/` pairs a `.yml`
   declaration with a `.R` implementation, 5 entries, which is exactly the shape
   of `ports-iceland-corrections.R`. `curate/decisions/` is this file. And the
   still-open **pid registry** is precisely an `overrides/` case: "a reviewed
   override re-enters as an *input*, never as a computed output."

   **Correction, 2026-09-21, same day.** This reason was first written claiming
   that `write_curated()` stamps repo/SHA/inputs/row-count and that
   `manifest.yml` versions a release. That was taken from `AGENTS.md` and is
   **false**: `write_curated()`, `check_sync()`, `manifest.yml` and
   `KV_METADATA` have **zero references** anywhere in the code. The only KV
   metadata in `curated/reference/port.parquet` is Arrow's own schema blob.
   `overrides/` exists but is empty. See TODO item 12.

   The reason survives in weakened form — `targets`, `corrections/`,
   `decisions/` are real and are what the migration actually leans on — but the
   provenance machinery is a plan, not an asset, and absorbing kaenugardr does
   not inherit it. It does put the port data where that machinery will apply
   once built, which is still an argument, just a smaller one.

## What this costs, stated plainly

The port database is pan-European and global, and embedding it in an Icelandic
fisheries repo makes it less obviously reusable. That cost is accepted because
there is no other consumer today, and because a reusable release can still be
published from `$FISHYDATA/published/` without a separate repo.

## The endgame

kaenugardr becomes the **third** repo absorbed and archived, after `logbooks`
and `fishydata_2024-2026`. Its history is pushed to GitHub first so nothing is
lost, then it is made read-only. The same safeguard TODO items 8 and 9 ask for
applies to it.

## Not decided here

**Settled 2026-09-21:** the product is split. All 24,655 features go to
`staging/ports/ports_all.gpkg`; the deduplicated one-row-per-port artifact goes
to `curated/reference/`. That matches what the code already produces and keeps
"never destroy the original" intact.

One constraint discovered while implementing it: `AGENTS.md` says
`write_curated()` is the only way into `curated/`, and that function does not
exist (reason 4 above). So there is no parquet-with-provenance route for the
deduplicated artifact today; it is written with the same `write_sf()` the rest
of `reference/geo/shapes.R` uses, and converting it is folded into TODO 12.

---

## Completed 2026-09-21

All four steps ran and were verified the same day.

| step | outcome |
|---|---|
| 0 preserve | pushed `6cf42a4..c82d053`, 52 MB of LFS uploaded |
| 1 code | 10 scripts moved; the 214 MB leaflet widget was not carried over |
| 2 data | everything under `$FISHYDATA`; no LFS; `raw/` restored to the original 159-harbour artifact and the correction writes 157 into `staging/` |
| 3 targets | `ports_iceland` and `ports_all` added; `port` and `shapes` depend on them |
| 4 archive | `~/stasi/kaenugardr` is **read-only** — a write is refused |

Verified end to end: `staging/ports/ports_all.gpkg` 24,653 features / 17,994
pids, matching the pre-migration run; `curated/reference/port_geometry.parquet`
17,994 ports with `pid` unique and geometry round-tripping through WKB;
`staging/aux/ports.fgb` with **zero** features sharing a geometry, where it had
two.

**Consequence to carry forward:** `ports.fgb` went from 6,019 to 10,047
features, because `shapes.R` lost its hardcoded `source %in% c("einar","gfw")`
filter — a crude hand version of the priority rule, applied in the wrong place —
and now reads the deduplicated set. More harbours are detectable, which is the
improvement, but it changes which pings are in harbour and therefore **trip
segmentation**. A trail built before 2026-09-21 is not comparable with one built
after.

TODO items 3b and 3d are deleted as done. Three of 3b's four check clauses pass
(no source filter; no shared geometry; both port outputs carry provenance
stamps). The fourth — every harbour code resolving to a `pid`, a country code or
an explicitly-typed sentinel — is **not** done and is the whole of item 3c.
