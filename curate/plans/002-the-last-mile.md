# 002 — The last mile: what still has to be built before the sweep is usable

**status:** proposal — nothing built · **2026-09-22** · **see:** `TODO.md` item 16,
plan `001-three-repo-publication-boundary.md`

**Measured** — by reading `~/stasi/fishyweb` on 2026-09-22 and comparing it line by
line against this repo (normalised, comments and blanks stripped, best-match by shared
lines):

- which of the 27 documents in `fishyweb` read which tables;
- the columns those documents filter on;
- for each of the 37 `fishyweb/scripts/*.R`, the percentage of its lines that appear
  in some script here;
- which of the enrichment columns exist in `curate/` today (by grep).

**Assumed** — everything about *how* the gap should be closed: the script names below,
which layer each belongs to, and whether the enrichment belongs in `ais_ping_tag.R` or
in a new script. Nothing here has been built or tried.

## 1. What the consumer actually does

The finding that drives this plan is not that `fishyweb` is old. It is that the
`fishyweb` documents **answer questions with a filter, not a pipeline**:

```r
filter(.cid > 0,                           # not in harbour
       whack == FALSE | is.na(whack),      # not a bad position
       between(speed, s1, s2),             # the gear's own speed window
       between(time, t1, t2),              # logbook haul start and end
       gid_trip == 6)                      # bottom trawl
```

`s1`, `s2`, `t1`, `t2`, `gid_trip` are **already columns on the ping row**. The site's
own index page says it in a comment: *"use what is already in the data"*. No document
that answers a question performs a join to do it; the joins were paid for upstream.

That is what `AGENTS.md` means by "a sweep of parquet files an analyst opens and works
with directly, with no pipeline knowledge required". This plan is about the distance
between that sentence and what `curate/` currently emits.

### The de-facto column contract

Filtered or selected across the documents that read the ping table:

`.cid` · `.sid` · `vid` · `time` · `lon` · `lat` · `speed` · `t1` · `t2` · `s1` ·
`s2` · `dt` · `dd` · `whack` · `agf_gid` · `gid_trip` · `lb_base` · `catch_total` ·
`year`

These names are an API. Renaming one breaks written work.

**Not the only table.** Of the 27 documents, 10 read the ping table, 7 read no project
data at all (methods arguments on synthetic data), 4 go straight to Oracle for logbook
QC, 4 read other sweep tables without the pings, and 2 read only GIS layers. At least
eight further tables are in play — `logbooks/{catch-for-ais,station-for-ais,catch,
stations}`, `landings/agf_stations`, `vessels/{vessels_iceland,stk_vessel_match}`,
`gear/gear_mapping`, `auxillary/*`. The sweep is a sweep.

**The `-for-ais` suffix is a design signal.** `catch-for-ais.parquet` and
`station-for-ais.parquet` exist *beside* plain `catch.parquet` and `stations.parquet`.
Consumer-shaped variants, built for joining against pings. Whatever replaces them here
should keep that idea rather than expect the analyst to reshape.

## 2. The gap is the tail, not the pipeline

`fishyweb/scripts/43_DATASET_ais_trail.R` is the assembler, and **3%** of its lines
appear here. That number is misleading in the reassuring direction: the *front* of it
is genuinely rebuilt here, and better factored —

| `43_DATASET_ais_trail.R` does | rebuilt here as |
|---|---|
| union STK + ASTD | `curate/ais_ping_union.R` |
| land / harbour classification | `curate/ais_ping_tag.R` (spatial join to ports) |
| `.cid` trip numbering, `whack`, `dd`, `dt` | `curate/ais_ping_clean.R`, `curate/ais_trip.R` |

What is **not** rebuilt is the tail. `curate/ais_ping_tag.R` ends at ports, H3 and
`depth`/`bbht`/`fao`. Nothing in `curate/` joins onto a ping:

- gear `s1` / `s2` speed windows, `met5`, `met6` — from `gear_mapping`
- logbook haul `t1` / `t2`, and `.sid`
- `catch` and `lb_base`
- vessel `loa`, `kw`

Those four lines are the difference between a curated ping table and a table someone
can ask a question of.

## 3. Two name collisions, measured

**`t1` / `t2` mean different things in the two repos.** In `fishyweb`'s ping table they
are the **logbook haul** start and end. In this repo `curate/ais_trip.R:5` writes
`t1`/`t2` meaning the **harbour-to-harbour voyage** start and end, and
`curate/link_trip_voyage.R:59` already has to alias them `T1_ais`/`T2_ais` to keep them
apart from the logbook's `T1`/`T2`. Twenty occurrences of `t1` in `curate/` mean the
opposite of what every written post means by it. This must be settled *before* the
enrichment lands, not after.

**H3 resolution.** `curate/ais_ping_tag.R:46` tags at resolution **8**. The posts work
at **5** (overview) and **9** (detail), never 8. Either 8 is the right storage
resolution and the consumer re-derives, or it is a third resolution nobody asked for.
Cheap to decide, expensive to discover later.

## 4. Script disposition — the item 16 check, discharged for the code half

26 of the 37 scripts are **≥78% superseded**; the migration happened. The unsuperseded
ones are, almost exactly, the scripts that build what the web reads.

| `fishyweb/scripts/` | overlap | disposition |
|---|---|---|
| `43_DATASET_ais_trail.R` | 3% | **port the tail.** Front superseded (§2); the enrichment joins are the work |
| `12_DATASET_logbooks.R` (`:915`, `:918`) | 21% | **port.** Sole producer of `station-for-ais` / `catch-for-ais` |
| `01_DATASET_vessels_combine-registry.R` | 20% | **read both, then decide.** Writes `vessel-registry.parquet` across flags; `reference/vessels/registry.R` is Iceland-shaped |
| `00_DATASET_aux_various-lookups.R` | 26% | **port.** `callsign_prefix`, `agf_gear`, `agf_species`; `agf_species` is read by the slides |
| `00_DATASET_aux_shapes.R` | 2% | **mostly superseded.** `reference/geo/shapes_raw.R` + `shapes.R` cover ICESareas, ICES_GEBCO, eusm from the same raw inputs, rewritten around `fd_*()`. Genuinely absent: `ICESrectangles` (only *consumed*, at `products/ices_vms_datacall/build.R:257`) and the `hab_and_bathy_layers.zip` fetch |
| `05_DATASET_ais_stk-to-parquet.R` | 5% | **superseded.** `sources/stk/convert.R` is a DuckDB rewrite of the same job; low overlap is the rewrite, not a gap |
| `00_DATASET_ais_astdB_zip-to-parquet.R` | 15% | **superseded.** `dump/ais/astd_b.R` likewise, and it carries the fault history 003 records |
| `00_DATASET_gear.R` | 25% | **read both.** The tribble carries the `s1`/`s2` windows §2 needs; `reference/gear/mapping.R` may already hold them |
| remaining 29 | 78–100% | **superseded.** Includes the three item 16 called "no counterpart": `80_DATASET_SMB_demo.R` → `products/exports/smb_demo.R` (100%), the two `91_datacall_*` → `products/exports/` (93%, 100%), and `ices-datacall/2025/ICES_VMS_QC-main/` → `products/ices_vms_datacall/qc/`, **byte-identical** |

## 5. What this plan does not decide

- **Disclosure.** Nothing here says what may leave `$FISHYDATA`. That is plan 001 §3
  and `TODO.md` item 15, and it is the maintainer's. Worth knowing while deciding it:
  the rule is already *implemented* in `fishyweb/ramb/2025-06-16_on-anonymity/` —
  `n_distinct(vid)` per hex-year, binned `>= 3` to `"3+"`, applied at the H3
  aggregation step rather than at export.
- **The prose.** The 22 `ramb/` posts are `fishyweb`'s own content and stay there;
  `fishyweb` is alive, not an archive. Item 16's question about their "destination"
  was posed on the assumption it might be archived, and that assumption is withdrawn.
- **Repathing.** Every post uses one of four roots (`here("data/...")`,
  `/u3/geo/fishydata/...`, `~/stasi/fishydata/...`, `/home/haf/einarhj/...`). The
  relink is a `fishyweb` job, wanting one helper there, not edits here.

## 6. Order, and why

1. **Settle `t1`/`t2` and the H3 resolution** (§3). Naming first: every later step
   writes columns that inherit the answer.
2. **Port the `-for-ais` producers** (`12_DATASET_logbooks.R`). The enrichment has
   nothing to join to until these exist.
3. **Port the enrichment tail** onto the tagged pings (§2). This is the step that makes
   the sweep answerable by filter.
4. **Port the lookups** (`00_DATASET_aux_various-lookups.R`) and settle the two
   read-both rows.
5. Everything ported enters `curated/` through `write_curated()` — see `TODO.md` item
   12; these are new writers and should not add to the ~18 that carry no provenance.
