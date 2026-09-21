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

4. **Every convention the remaining open items need already exists here.**
   `write_curated()` stamps repo, SHA, dirty flag, inputs, row count and schema
   hash. `targets` owns staleness. `manifest.yml` versions a release.
   `curate/corrections/` pairs a `.yml` declaration with a `.R` implementation —
   which is exactly the shape of `ports-iceland-corrections.R`. And the still-open
   **pid registry** is precisely an `overrides/` case: "a reviewed override
   re-enters as an *input*, never as a computed output."

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

Where the consolidated product lands is left open, because it tests committed
boundary 1 (source-shaped `staging/<source>/` vs merged-shaped `curated/`).
`ports_all` merges nine sources, which argues for `curated/`; but it is
reference geometry, and reference outputs already live in `curated/reference/`.
See the migration item in `TODO.md`.
