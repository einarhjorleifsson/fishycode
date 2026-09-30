# TODO

Open work items. One line of provenance each, and a **check** that decides when the
item is closed — so this file can be audited against the code rather than believed.

Not a diary. Why a thing is the way it is goes in `curate/decisions/`. Data defects
with a detection rule and a repair go in `curate/corrections/*.yml`. This file is
only for work that is *not done yet*.

**An item is a stub, not an essay — 35 lines at most, enforced.** It says what is open,
points at the record that holds the evidence, and states its check. When an item wants
sections, tables and its own numbers it is a plan or a correction, and what stays here
is the pointer. This file reached 871 lines by ignoring that; the cure was mechanical —
four "Resume note" sections were 211 of them, and seven items were restating a plan or a
correction that already said it better. Session state belongs in the git log, which is
where "what happened when" is recorded.

Status: `open` · `blocked` · `parked` · `in progress` · `done` (delete when done and
recorded elsewhere)

`parked` is a deliberate stop, not an obstacle: the work could proceed and a decision
was taken that it should not. `blocked` means something outside the item is in the way.
Conflating them hides which ones a session could actually pick up.

An item that cannot move without the maintainer — a decision, an account, a
credential, anything outside this repo — also carries **`needs: maintainer`**, and says
in one line what is being asked. Without that marker a session either stalls on it or
does it twice.

---

## 3. `station_type` is prose, not a contract
**status:** open · **files:** `sources/afli/convert.R`, `sources/fs_afladagbok/convert.R`

`grammar.qmd`'s flagship contribution. Appears 5x in prose and **0x in any script**,
unchanged since this restructuring began. Step 3 of the plan, still not started.

**check:** `grep -rn station_type sources/` returns the column being written by both
adapters.

---

## 3c. `hid` and `pid` are not the same concept
**status:** open · **raised by the maintainer 2026-09-21, while resolving item 4**
**see:** `curate/decisions/007-hid-maps-to-pid.md` — the mapping is built; typing is what remains

The landings/logbook harbour code answers **"where did this fish go?"**. A harbour
polygon answers **"where was the vessel?"**. These coincide most of the time and then
diverge exactly where it matters:

- **A landing place that is not a harbour.** Hellissandur (41) and Hnífsdalur (71) appear
  to be processing sites, not berths (decision 004). Forcing them into the harbour-polygon
  domain is what produced the bad record in the first place.
- **A code that is not a place at all.** `300 Flutningaskip` is a vessel type,
  `900 Fiskistofa skráningar` an administrative sentinel, `150 Ýmsir staðir` a catch-all.
- **A code that is a whole country.** The eight foreign codes (decision 007) resolve to a
  country, not a port.
- **A harbour that is not a landing place.** Any polygon a vessel visits without landing.

So the crosswalk cannot be `hid ↔ pid` 1:1. It needs a **type** on each code —
place / processing-site / country / sentinel — and a `pid` only where the code really
denotes a physical harbour. Building it as a plain join will silently invent harbours
that do not exist, which is the defect this project is supposed to detect.

**check:** every harbour code carries an explicit type; no code typed non-harbour
carries a `pid`.

---

## 20. `adb`'s `gid` is `NA` throughout the merged logbook
**status:** open · **file:** `sources/adb/convert.R`
**see:** `curate/corrections/adb_vs_fs_afladagbok.yml` (`defect_3_gear_coding`),
`curate/decisions/023-adb-wired-into-logbook.md`

`adb`'s own gear code doesn't resolve against `reference/gear.parquet` (codes
92/99/91/29 valid only as `gear$map`, code 10 only as `gear$gid`, 53/51 as
neither), so `sources/adb/convert.R` leaves `gid` `NA` and keeps the raw code as
`gid_old`. A crosswalk is already DERIVED, not guessed, from the 467,635 stations
`adb` shares with `fs_afladagbok` (same defect record) — it just isn't applied.
Now that `adb` is merged in (20,530 stations, all 2026), every downstream
gear-dependent step (pelagic/demersal splits, effort by gear) is blind for 2026.

**check:** `curated/logbook/fishing_sample.parquet` has no `NA` `gid` where
`schema == "adb"`.

---

## 5. `ping_union` carries duplicate position keys — measured, not repaired
**status:** open · **see:** `curate/corrections/ping_union_duplicate_keys.yml`

Duplicate `(vid, time)` keys survive into the union. Measured and declared; the repair
rule is the open part, and the correction records one proposed rule that was **rejected**
— preferring the smaller `sec_nextpoint` would have selected the placeholder every time.

**check:** `staging/ais/ping_union` has no duplicate `(vid, time)`, or the correction
states why the surviving ones are legitimate.

## 7. Verification scripts test shape, not substance
**status:** open · **files:** `R/check_ready.R`, `R/check_paths.R`, `R/paths.R`

Three times now a check has reported "ready" or "clean" about something that was not:
`check_paths.R` missed seven absolute paths, `check_ready.R` did not recognise
`read_excel`, and both were fooled by empty directories. The root cause of the last
one is `.fd_writable()` **creating a directory as a side effect of resolving a path**,
so `dir.exists()` cannot distinguish "never built" from "built and empty".

Today's failures were all in code that had never executed, and two would have failed
*silently* — a character/integer comparison that wrote an empty dataset, and those
empty directories.

**check:** `check_ready.R` reports not-ready for an existing but empty dataset
directory.

---

## 8. `fishydata_2024-2026` still holds 40 GB that step 1 never moved
**status:** open

Step 1 of the plan symlinked `logbooks/` into `$FISHYDATA`. It was never applied to
`fishydata_2024-2026`, which still has `data/ais/trail` (31 GB) and
`data-raw/ais/stk` (8.4 GB) as **real directories**. Its `trail` is a *third* trail,
distinct from `legacy/curated/trail` (13 GB) and `trail2` (19 GB), so it cannot be
deleted until someone establishes whether anything in it is unique.

**check:** no directory under `~/stasi/fishydata_2024-2026` exceeds 1 GB.

---

## 9. No archive date for the old repos
**status:** open · **kaenugardr done 2026-09-21 (read-only, write refused)**

The plan calls a fixed, agreed archive date a non-optional safeguard, and names
parallel development as how the forks were born.

`kaenugardr` is now read-only, closing the window in which its scripts existed in
two editable places (decision 006). **`logbooks` and `fishydata_2024-2026` are
still writable** and no date is set for them.

**2026-09-22: a third one.** `~/stasi/fishyweb` was pulled from GitHub and is
writable, and it holds yet another copy of the ports and source-conversion scripts
(item 16). It cannot be made read-only until item 16 decides what survives it, so it
is listed here as known-open rather than silently missing from the check.

**check:** `logbooks`, `fishydata_2024-2026` and `fishyweb` are read-only.

---

## 10. `reference/species` is an empty directory
**status:** open
**see:** `curate/decisions/019-the-check-layer-exists.md`

This item used to read "`curated/check/` does not exist". That half is **closed** —
it holds three tables and the contract a check owes its reader is written down in
decision 019. The claim had gone stale before anyone noticed, which is why it is
recorded rather than quietly edited.

What is left is the species reference. `reference/species/` is an empty directory and
`curated/reference/` has no species table, so nothing in the sweep resolves a species
code to a name. Every other reference domain — gear, ports, geo, vessels — has one.

**check:** `curated/reference/species.parquet` exists and the catch tables' species
codes all resolve against it.

---

## 11. Datasets named `year=YYYY` are not actually partitioned
**status:** open · **files:** `curate/ais_ping_clean.R`, `curate/ais_trip.R`, `curate/logbook_sensor_gps.R`
**see:** `curate/decisions/003-undeclared-dump-inputs.md`

Superseded in part — these now write real `year=YYYY/` directories. But
`ais_ping_union.R`'s claim that partitioning enables "partition pruning" should be
re-checked now the layout has changed, and the `year` data column now coexists with a
hive column of the same name.

**check:** reading each dataset yields exactly one `year` column, of a stable type.

---

## 12. Provenance stamping — built, adopted by 1 of 19 curated writers
**status:** open · **`write_curated()` built 2026-09-21** (`R/write_curated.R`)

Found while planning 3d: `AGENTS.md` asserted `write_curated()`, `check_sync()`,
`manifest.yml` and `KV_METADATA` as existing machinery. All four had **zero
references** in the repo. This session had already copied that claim into
`curate/decisions/006` as a reason before checking it — the exact failure the
file's own header names.

**Now built and tested.** `write_curated()` writes
`COPY … (FORMAT parquet, KV_METADATA {…})` stamping `fd.repo`, `fd.commit`,
`fd.dirty`, `fd.script`, `fd.built`, `fd.rows`, `fd.schema_hash` and
`fd.inputs`. `sf` is accepted — geometry as WKB, CRS in `fd.crs`, round trip
verified feature-for-feature on 157 harbours. `curated_provenance()` reads the
stamps; `check_sync()` reports drift against HEAD.

**Adopted by one writer**, `reference/ports/harbour_codes.R`. The remaining ~18
still use `duckdbfs::write_dataset()` or `nanoparquet::write_parquet()`.

**The blocker for the rest is real, not laziness.** `write_curated()` takes a
materialised data frame. The `write_dataset()` callers pass **lazy duckdb
relations**, some writing partitioned `year=YYYY/` directories — `logbook.R`,
`link_lid_map.R`, `ais_*`, `h3_index.R`. Materialising those to stamp them
would reintroduce exactly the accumulation `R/write_parquet.R` exists to avoid
(48 GB spilled across ~130 month groups). They need a variant that stamps a
`COPY (SELECT …)` straight from the relation, and a partitioned dataset needs
its metadata at the directory level, which parquet KV cannot express.

`manifest.yml` remains unbuilt and is not started.

**check:** `grep -rn "duckdbfs::write_dataset\|nanoparquet::write_parquet" `
over scripts writing to `fd_curated()` returns nothing.

---

## 14. Two months of astd are in `raw/` and were never loaded
**status:** open · **see:** `curate/corrections/astd_missing_months.yml`

Two months of ASTD sit in `raw/` and never reach the union, so the AIS track has holes
nobody sees. Measured and declared in the correction, which holds the month list and what
was checked.

**check:** every month present in `raw/ais/astd` appears in `staging/ais/ping_union`.

## 19. The dropped afli stations — PARKED
**status:** parked · **see:** `curate/corrections/afli_rafr_stofn_stations_dropped.yml`,
`curate/plans/005-recover-the-dropped-afli-stations.md`

**Parked by the maintainer 2026-09-23. Nothing is queued and the product is unchanged.**
23,570 live electronic submissions are absent from `stofn` and therefore from everything
this repo builds. That is measured twice and is not in doubt. What to do about it is.

The position moved three times in one session — hold for an upstream answer, lift the
hold on AIS corroboration, then a claimed two-thirds reversal on supersession that was a
conditioning error caught by one further check. The measurements underneath were sound
every time; the readings of them were not. That is why it is parked rather than pushed.

**What is published and stays:** `curate/checks/afli_rafr_stofn_loss.R` and
`afli_rafr_stofn_corroboration.R` into `curated/check/`, and
`docs/afli-dropped-stations.qmd`, which names the 53 vessels whose per-vessel figures
are wrong. Parking the repair is not a finding that the data is fine.

**Before resuming**, read the yml's `parked` and `the_supersession_hypothesis_failed`
sections. The second is the most recent thing learned and the most expensive to
rediscover.

**check:** none — a parked item has no completion test. It closes when the maintainer
reopens it or decides the rows stay out for good.

---

## 18. Fishing windows from behaviour, not from the logbook
**status:** open · **see:** `curate/plans/004-behavioural-fishing-windows.md`

Infer each station's fishing window from the logger's own speed and heading, instead of
from logbook times that 7,336 stations a year do not record at all. Five cheap
measurements decide whether it is worth building; none has been done.

**check:** plan 004's five measurements are recorded in its header.

## 17. Full review of the STK vessel match
**status:** open · **needs: maintainer** · **see:** `curate/plans/003-stk-vessel-identity.md`,
`curate/plans/008-north-atlantic-vessel-registry.md`, `TODO.md` item 25 (the audit)

Reviewed 2026-09-22; steps 1–7 and 9 done (decisions 015, 020, 021, 032, 033,
034). Step 8 (foreign-vessel identity) is absorbed by and built in plan 008 —
`ais_key_foreign.R`'s six-stage cascade, 7,549 candidates proposed (decisions
036, 039, 040, 041). Plan 008's own Phase 7 (`_targets.R` wiring) and ongoing
candidate review remain open there, not here.

**`TFPH`/`TFUT`** (named here since 2026-09-23 as "device changes hands
mid-span, can't recover the split") **re-diagnosed 2026-09-27, more precisely
wrong than that**: for `TFUT` at least, both `raw/vessels/vessel_v.parquet`
(Oracle) and `raw/vessels/mmsi_iceland_archieves.parquet` (Fjarskiptastofa)
show only two historical holders, both ending **1995** — the real mobile-id
has pinged since 2019. The source data itself has no current holder, not a
split we failed to recover. Same class as the 88-vid ask below.

**Asked of the maintainer:** the 88 Icelandic vids with no MMSI on record
(`ais_key.R:16-19`'s own TODO note) plus `TFUT` above — a Fiskistofa/
Fjarskiptastofa data refresh, not a code fix.

**check:** the 88-vid gap and `TFUT` both resolve against a refreshed pull, or
this item states why they can't.

## 15. The three-repo publication boundary
**status:** open · **needs: maintainer** · **see:** `curate/plans/001-three-repo-publication-boundary.md`

**Asked of the maintainer, in the plan's own words:** restrict or relocate the Mapbox
token (§4), decide when the GitHub remote goes up and whether history is rewritten
first (§4), set the aggregation rule for what may leave `fishydata` for an open
`fishyweb` (§3), and say where `fishydata` lives and whether it is backed up (§5). The
disclosure rule blocks item 16. Everything else in the plan I can act on unblocked.

**check:** the four questions in plan 001 §§3–5 are answered in the plan, and the
Mapbox token no longer appears in the working tree.

`fishycode` public on GitHub, `fishydata` never public, `fishyweb` an open web page.
The design, the evidence and the open questions are in the plan; this stub exists so
the work is visible here. Two things in it are time-sensitive: there is still **no git
remote**, so history is free to rewrite until the first push, and a Mapbox `pk.` token
is committed in three files. The boundary that actually needs a rule is
`fishydata` → `fishyweb`, which is a data-disclosure question and binds item 16.


---

## 16. `~/stasi/fishyweb` — port the last mile
**status:** blocked · **see:** `curate/plans/002-the-last-mile.md`, item 15

`fishyweb` is alive, not an archive (maintainer, 2026-09-22) — the third repo of plan
001, keeping its 22 `ramb/` posts. The question is what to *port*, and the design is in
plan 002. Blocked on item 15's disclosure rule, which decides what may leave
`fishydata` at all.

**check:** plan 002's port list is built and item 15's disclosure rule exists.


---

## 21. GFW effort data may be worth cross-checking against STK
**status:** open · **see:** `curate/plans/008-north-atlantic-vessel-registry.md`

Not a vessel registry — GFW's own effort grids are activity data, the same kind as
`staging/ais/astd`, not identity like the rest of plan 008. Landed alongside it in
`~/garbage/vessels_from_.../gfw/`, not yet moved into `$FISHYDATA`:
`mmsi-daily-csvs-10-v1-5-2018.zip` (per-MMSI, 0.1°, 2018 only) and
`fleet-daily-csvs-100-v2-2020.zip` (flag+geartype, 0.01°, 2020, no MMSI).

Partners the maintainer has worked with have questioned GFW's data quality. The
Icelandic fleet is exactly the population where that is answerable — STK is this
project's own authoritative trail for it. A comparison here would be the same shape as
`curate/checks/ais_key_landings.R` (report disagreement, never correct from it).

**check:** a check exists comparing GFW-attributed Icelandic fishing effort against
STK's own trail for at least one overlapping year (2018, via `mmsi-daily`).

---

## 22. Foreign vessels never reach trip segmentation, even once identified
**status:** open · **see:** `curate/plans/008-north-atlantic-vessel-registry.md`

`reference/ports/ports_all.R` (kaenugardr, absorbed) already merges 24,653 harbours
globally — GFW's 12,831 worldwide anchorages, EMODnet's 946 European ports, GISCO's
2,440 EU ports, plus OSM/vmstools/local sources. The geometry side of "a foreign
vessel's trip start/end harbour" is ready and has been since the absorption.

The identity side is not, in three specific places, all keyed strictly on Icelandic
`vid`: `sources/stk/convert.R:28` and `curate/ais_ping_union.R:66` both
`inner_join(..., filter(!is.na(vid)))` — a ping with no Icelandic vid is dropped
before it ever reaches `curate/ais_trip.R`, which then groups trips by `vid` alone.
Plan 008's `external_id` (§5–§7) will resolve identity for vessels that were never
going to get an Icelandic vid — but as things stand today, their pings never survive
long enough to be segmented into trips at all, no matter how good that resolution is.

**check:** a ping carrying an `external_id` but no `vid` (plan 008's foreign match)
survives into `curated/ais/trip.parquet` with a trip key, `hid1`/`hid2` resolved
against `ports_all`.

---

## 23. Icelandic pleasure craft (SKB) have no entity_class or registry home
**status:** open · **needs: maintainer** · **see:** `curate/decisions/041-fro-succession-and-skb-pleasure-craft.md`

`reference/vessels/registry.R:35` excludes `sknr` starting `SKB` from `vessel.parquet`
with no decision record explaining why — found to look mechanical (`SKB` codes are
alphanumeric, never fit the integer `vid` join) rather than a deliberate policy call.
Measured: 94 of 157 `SKB` mobile-ids in STK's unmatched residual resolve cleanly
against `raw/vessels/mmsi_iceland_archieves.parquet`'s own `sknr` field (192,554 of
256,292 pings) — including the single largest entry anywhere in the residual. A
resolution path now exists (`ais_key_foreign.R`'s `isl_pleasure_craft` stage, `source`/
`external_id` of their own, `vessel.parquet` untouched), but they still default to
`entity_class == "vessel"` in the main cascade and sit in the unmatched residual
looking like missed real vessels rather than a recognized class.

**Asked of the maintainer:** should `R/entity_class.R` recognize `SKB` as its own
class, and should `registry.R`'s exclusion be revisited now that it's shown to cost
real, resolvable AIS coverage?

**check:** `SKB`-prefixed mobile-ids carry a distinct `entity_class`, and
`registry.R:35`'s exclusion has a decision record (kept or changed) either way.

---

## 24. `landed_but_no_ais`'s top vessels have no MMSI on record at all
**status:** open · **see:** `curate/checks/ais_key_landings.R`

83 Icelandic vessels land fish (2007-09 to 2025-12) with zero STK identity. The
top 10 by landing-trip count (vid 980 STAFNES, 1035 HEIMAEY, 6723 BETA, 2362
HREFNA, 257 SIGURVON, 1263 ATLAVÍK, 1261 BERGKVIST, 6965 ARNAR, 2302 MÁNI, 978
SVANUR) carry **no `mmsi` in `vessel.parquet` at all** - not stale, absent -
so ASTD/astdB (both MMSI-keyed) can't be checked for them with a restricted
lookup the way plan 008's foreign candidates were. The only way to check is a
`vesselname`-matched scan across ASTD's ~2.77 billion rows, which is exactly
the full-table scan this repo has deliberately avoided everywhere else - so
it wasn't run; do it as a deliberate, budgeted pass, not incidentally.

**check:** each of the 83 has either an ASTD/astdB name-match result recorded,
or a note that none exists.

## 25. Resolve the STK key audit's discrepancies, and reach the rows no witness reaches
**status:** open · **needs: maintainer** — review of proposed overrides ·
**see:** `curate/plans/009-independent-audit-of-the-mid-vid-match.md`,
`curate/decisions/047-independent-audit-of-the-mid-vid-match.md`

Built 2026-09-29: `ais_key_audit` (ledger of every key row, 132 discrepancies, 884
vid-claiming rows no witness reaches) and `ais_key_split_candidates` (silences where a
human-style reading says the vessel changed; 19 strong not in the ODS). Open: plan 009 —
phase 2 (segment table built with logbook and landings: tiles every mid, 90 % of pings with direct evidence, Icelandic ODS rows 87 % reproduced without the ODS; review open), phase 3 (review in the app),
phase 4 (reach the continuity segments, MMSI series, foreign vessels), phase 5 (the ODS is retired:
switch `ais_key.R` to the segment table, then delete the ODS; decided 2026-09-29).
`ais_key_resolution` (built, first pass) reads each discrepancy as eras: 30 proposals on 25 mids;
track correlation confirms 12 of the 14 strong ones (decision 047), the other 2 need a person.
The `curated/check/` tables build the next time the `check_ais_key_*` targets run.

`ais_key_coverage` finds the pings the key leaves unassigned (39,487 on mids with a vessel; the largest
is a d1/d2 typo on mid 101097) and proposes a fill; the maintainer's invariant is no unassigned ping.

`ais_key_vessel_recall` accounts for every Icelandic vessel-month AIS or the logbook shows active: 0.3 % of
AIS-heard months have no mid assigned (decision 047).
`ais_key_twins` keeps the mobile-ids heard with two vessels (a candidate fishyweb case example).
Side observation, NOT validated and not pursued: on the uncleaned 2019 union, implied-speed jumps
(> 50 kn) are 0.09 % of consecutive pairs for stk, 0.04 % for astdB, 0.02 % for astd.

Mid 101444 = vid 1421 (call sign TFGA) is now assigned by dated-holder ranking; the registry's own dated
call-sign history only starts 2023-12-19 and cannot date a reuse in the STK era (decision 047).

The segment table now uses each hull's registration date (a vid cannot precede its vessel): 0 impossible segments,
108 stretches / 97,850 pings for a person. The review of decision 048 was made on the earlier table and is to be
redone on this one before any verdict is used.

**check:** `ais_key_coverage` reports 0 unassigned pings, and every row of `curated/check/ais_key_audit_discrepancy.parquet` is resolved
through `overrides/` or carries a stated reason, and the 884 are re-counted.

## 26. Land the annual ship register (`skipaskra`) and use it to date call-sign holders
**status:** open · **needs: maintainer** — the copy of `~/stasi/skipaskra` into `$FISHYDATA/raw/external/skipaskra/` ·
**see:** `curate/decisions/049-annual-call-sign-register-found.md`

The annual register gives the call sign per vessel per year for 2009-2022 (5,283 vessel-years). Open: land the raw matrices,
an adapter to `staging/skipaskra/annual_call_sign.parquet`, use it as the time source for call-sign holders in the segment table
(replacing Hreidar's years and the placeholder MMSI windows), and tidy 2004-2008 so 2007-08 (the start of STK) are covered.

**check:** `staging/skipaskra/annual_call_sign.parquet` exists for 2007-2022, and the segment table reports how many
call-sign stretches it settles that the identity windows left ambiguous.

