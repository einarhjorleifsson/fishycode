# 002 — The last mile: what still has to be built before the sweep is usable

**status:** partly built — steps 1 and 5 done (decisions 010, 011, 070); the tail built as the trail by plan 010
(decisions 065, 085, 101); the species lookup is decision 182; the fishyweb port is now plan 033 step 5 (fishyweb's pages into the book, TODO 94) · **2026-09-22** ·
**see:** `TODO.md` item 16,
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

### This is not hypothetical: the datacall build already depends on it

**Measured against `$FISHYDATA` itself on 2026-09-22**, not inferred from the source.
`products/ices_vms_datacall/build.R` is written against the enriched table *as if it
existed*:

- `:72` opens `staging/ais/ping_union` and filters it on `.cid`, `whack`, `.sid`,
  `between(speed, s1, s2)` and `between(time, t1, t2)`. The table has **eleven**
  columns — `vid, mmsi, time, lon, lat, speed, heading, provider, imo, cog, year` —
  and **none** of the fourteen the consumer reaches for is among them.
- `:95` opens `curated/logbook/station-for-ais.parquet`. `curated/logbook/` holds
  `catch`, `fishing_sample`, `lid_map`, `station` and `trip`. The file is not there,
  and no script here produces it.

So the ICES datacall — the one consumer `AGENTS.md` names — cannot run today, and the
reason is precisely the missing tail. It also reads `ping_union` from *staging*,
bypassing `ais_ping_clean.R` and `ais_ping_tag.R` altogether, which is a second
question worth asking when the tail lands.

*A third item stood here until 2026-09-22 and was wrong: that `:69` reads
`curated/reference/gear.parquet` while the producer writes `gear_mapping.parquet`.
`reference/gear/mapping.R:135` writes exactly `gear.parquet`; the claim came from that
file's header comment, which still names the old path. Read the write, not the header —
this repo's stale comments have now cost two false findings in one session.*

## 3. Two name collisions — settled 2026-09-22

Both were raised here as blocking. Both now have an answer in
`../decisions/010-time-variable-naming.md`, so step 1 of §6 is discharged.

**`t1`/`t2`.** Case encodes the level: `T1`/`T2` is trip or voyage, `t1`…`t4` is event.
A harbour-to-harbour voyage is therefore `T1`/`T2`, and `curate/ais_trip.R:4` writing
it lowercase is what forces the `v.t1 AS T1_ais` alias at
`curate/link_trip_voyage.R:59`. The rename makes that alias an ordinary name.

The event times **stay four**, because which interval assigns a ping to fishing moves
with the gear — a towed gear fishes between `t2` and `t3`, a static gear does not work
that way. The enrichment tail therefore carries `t1`…`t4`, not the collapsed pair
`fishyweb`'s `station-for-ais.parquet` carries, and the per-gear rule lives in
`reference/gear/mapping.R` beside the `s1`/`s2` windows and the max-duration and
max-distance criteria its header already anticipates.

**H3 resolution — settled as *experimental*,** `../decisions/011-h3-in-storage-is-experimental.md`.
`curate/ais_ping_tag.R:46` tags at resolution **8**; the posts work at **5** and **9**,
never 8. H3 does two jobs: a transient join key into `area_h3.parquet` (load-bearing),
and a column carried into storage by `curate/ais_ping_clean.R:58` (the experiment).
The enrichment tail must not add anything keyed on a ping's `h3`. Note that res 8 is
also the grain at which GEBCO depth is averaged, so it is an analytical commitment —
and one that cannot be revisited until the raster in `../decisions/002` is recovered.

**A third issue, found while settling these, is not a naming problem.** In
`fishyweb/scripts/12_DATASET_logbooks.R:883`, a station with no recorded fishing times
gets `t1` = 00:00:00 and `t2` = 23:59:00 of its date. `between(time, t1, t2)` then
means "during the haul" for some rows and "anywhere that day" for others, unflagged.
That is a `basis` defect (`recorded` vs `synthesised`), now declared as
`../corrections/station_time_whole_day.yml`. The repair is decided — keep the times,
add `basis` — and it lands **with** the producer in step 2 below, not after it. The
same rows are also an aggregate of several stations, so `n.sids` comes across too.

## 4. Script disposition — the item 16 check, discharged for the code half

26 of the 37 scripts are **≥78% superseded**; the migration happened. The unsuperseded
ones are, almost exactly, the scripts that build what the web reads.

| `fishyweb/scripts/` | overlap | disposition |
|---|---|---|
| `43_DATASET_ais_trail.R` | 3% | **port the tail.** Front superseded (§2); the enrichment joins are the work |
| `12_DATASET_logbooks.R` (`:915`, `:918`) | 21% | **port.** Sole producer of `station-for-ais` / `catch-for-ais` |
| `01_DATASET_vessels_combine-registry.R` | 20% | **deliberately narrowed, not drifted** — read both 2026-09-22, see §4a. Nothing to port unless foreign-flag vessel identity is wanted back |
| `00_DATASET_aux_various-lookups.R` | 26% | **port.** `callsign_prefix`, `agf_gear`, `agf_species`; `agf_species` is read by the slides |
| `00_DATASET_aux_shapes.R` | 2% | **mostly superseded.** `reference/geo/shapes_raw.R` + `shapes.R` cover ICESareas, ICES_GEBCO, eusm from the same raw inputs, rewritten around `fd_*()`. Genuinely absent: `ICESrectangles` (only *consumed*, at `products/ices_vms_datacall/build.R:257`) and the `hab_and_bathy_layers.zip` fetch |
| `05_DATASET_ais_stk-to-parquet.R` | 5% | **superseded.** `sources/stk/convert.R` is a DuckDB rewrite of the same job; low overlap is the rewrite, not a gap |
| `00_DATASET_ais_astdB_zip-to-parquet.R` | 15% | **superseded.** `dump/ais/astd_b.R` likewise, and it carries the fault history 003 records |
| `00_DATASET_gear.R` | 25% | **port the tribble's `s1`/`s2`.** Measured 2026-09-22: `reference/gear/mapping.R` does **not** carry them; only this tribble does. Decision 010 puts the per-gear fishing-interval rule in the same table |
| remaining 29 | 78–100% | **superseded.** Includes the three item 16 called "no counterpart": `80_DATASET_SMB_demo.R` → `products/exports/smb_demo.R` (100%), the two `91_datacall_*` → `products/exports/` (93%, 100%), and `ices-datacall/2025/ICES_VMS_QC-main/` → `products/ices_vms_datacall/qc/`, **byte-identical** |

### 4a. The vessel registry, read on both sides

The 20% was misleading in the *other* direction from `43_DATASET_ais_trail.R`: nothing
drifted here, and nothing is missing by accident.

`fishyweb` splits the work in two — `00_DATASET_vessels_iceland.R` builds the Icelandic
registry, and `01_DATASET_vessels_combine-registry.R` reads that in at its `:40` and
consolidates it with **FRO, NOR, EU, ASTD and GFW** into `vessel-registry.parquet`.

`reference/vessels/registry.R` is the *first* of those two, not the second — which is
why `00_DATASET_vessels_iceland.R` matches it at **84%** while the combine script
matches at 20%. It then absorbs the combine script's Icelandic tail (the MMSI join, the
Hreiðar year range) and writes `curated/vessel/vessel.parquet`, **Iceland only**.

So the disposition is: **narrowed on purpose.** What is genuinely absent is
consolidation across the other five registries, and nothing here produces or consumes
`vessel-registry.parquet`. Whether that matters is a real question, not a defect: the
ASTD feed carries foreign vessels inside the Icelandic EEZ, and today they have no
identity beyond an MMSI. Answering it is out of scope for this plan.

Two things found while reading, both small and both real. **Both fixed 2026-09-22:**

- **Dead code with dangling references.** `reference/vessels/registry.R` ended in an
  `if(FALSE)` block referring to `vessel_registry`, `vessel_ASTD` and `vessel_NOR` —
  objects the combine script creates and this file never does. Those dead lines were
  the only mentions of any of them in the repo, so it read as though a consolidation
  existed. Deleted, 25 lines; grep for all six `vessel_*` object names now returns
  nothing.
- **The Faroe scrape wrote into the repo.** `reference/vessels/faroe_scrape.R:32`
  wrote `data-external/vessels/færeyjar/vid-NNNN.csv`, a relative path, not `fd_*()`.
  It is a web fetch, so by the `AGENTS.md` layout table it belongs in `dump/`. Now
  `dump/vessels/faroe.R`, writing `fd_raw("vessels", "faroe")` beside the Oracle
  vessel dumps, with the directory created the way the other `dump/` scripts do it.
  Still consumed by nothing — it is the FRO half of the consolidation above — and
  still 20,000 requests at `Sys.sleep(2)`, roughly 11 hours, so its header now says
  how to run it deliberately rather than by accident.

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
   writes columns that inherit the answer. **Done** — decisions 010 and 011, and the
   `T1`/`T2` rename landed 2026-09-22 across `ais_trip.R`, `link_trip_voyage.R` and
   `logbook_sensor_gps.R`. Three other files keep lowercase `t1`/`t2` deliberately,
   because theirs are event times (`products/ices_vms_datacall/build.R`,
   `products/exports/buseful_2025-05-05.R`) or an MMSI validity window
   (`products/exports/astd_iseez.R:124`, a third meaning that wants a better name).
2. **Port the `-for-ais` producers** (`12_DATASET_logbooks.R`), carrying `basis` and
   `n.sids` from the start per `../corrections/station_time_whole_day.yml` — adding
   them later means re-deriving which rows were synthesised. The enrichment has
   nothing to join to until these exist.
3. **Port the enrichment tail** onto the tagged pings (§2). This is the step that makes
   the sweep answerable by filter.
4. **Port the lookups** (`00_DATASET_aux_various-lookups.R`) and settle the two
   read-both rows.
5. Everything ported enters `curated/` through `write_curated()` — see `TODO.md` item
   12; these are new writers and should not add to the ~18 that carry no provenance.
