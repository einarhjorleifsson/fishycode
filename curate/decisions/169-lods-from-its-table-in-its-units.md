# 169 — lods is read from its table `lods_slaegt`, in its own units, without the export surcharge

*2026-10-22. The maintainer's ask ("start reviewing lods_oslaegt against its base tables", then "go ahead with the
adapter fix and decision 169"). Written by Claude (AI); the study, the code and the scratch run are Claude's and have
not been checked by a person. Study, scripts and logs: `$FISHYDATA/archive/2026-10-lods-oslaegt/` (README). Dump of
2026-10-16. Nothing under `$FISHYDATA` is rebuilt: TODO 119.*

## Found

`sources/lods/convert.R` read the view `kvoti.lods_oslaegt`, which is 11 of its table's 21 columns with
`ROUND(magn_oslaegt)` (`kvoti/_code/all_views.parquet`, decision 166). Rebuilt in DuckDB from `kvoti.lods_slaegt`, the
view's 9,978,840 rows are equal to it. Read as the adapter read it:

1. **Herring, capelin and blue whiting are tonnes, read as kg.** `lods_slaegt` keeps `fteg` 30, 31 and 34 in tonnes and
   every other species in kg. Oracle says so three times: the views `lods_slaegt_v` and `lods_slaegt_kg_v` multiply
   those three by 1000, the column comments say so, and the table's trigger multiplies their cod equivalents by 1000
   "because they are always in kg". The data agree: `thorskigildi` / `magn` has a median of 150, 60 and 80 for the
   three, and at most 2 for any other species. In `curated/landing/`, the lods-only trips held 19,087 kt of the three
   to 2006 and 736 kt in 2007 (810 trips, agf's first year) as 19.1 and 0.7.
2. **The export surcharge was summed as catch.** `gerd` 'A' is the quota surcharge on unprocessed exports
   (`kvoti.gerd`). It has 210,868 rows, all at `hofn` 159, 1992-2013, 167,180 of them negative (−66.9 kt), a median
   −9 % of the same landing. `lods_til_kvota` negates it to charge the quota. agf has no counterpart, so no landing
   with an A row matches agf.
3. **The water deduction is catch.** `gerd` 'V' (2 % on pelagics) is kept: with it a landing matches agf within 1 %
   on 99.99 % of shared keys, without it on 5 %.
4. **`ROUND()` cost nothing that matters.** The tonne species are stored as whole tonnes, and for the rest it moves the
   total by +231 t over 1992-2026.
5. **The view drops `upprunahofn`**, the port an export (`hofn` 159, "gámar/sigling") was landed at: 360,991 of the
   518,863 rows at 159 carry it, 56 ports. Everywhere else it equals `hofn`. 168 export days have two or three.
6. **`magn_oslaegt` is derived**: `kvutil.i_oslaegt(fteg, l_dags, veidisvaedi) * magn`, by the table's trigger. `magn`
   is the gutted weight, itself converted from product weights (`lods_fragang`).

**The rows are made elsewhere** (the maintainer's note that kvoti may have its origin in another system). The
table's three triggers, which compute `magn_oslaegt`, the cod equivalents, the period, the stamps and `upprunahofn`, are
DISABLED in MFRI's database, yet every row carries their values. The packages named as writers (`kvoti.lodsinn2`,
`agf.lods_slaegt_pkg`, `kvoti.gamahledsla`) are not visible to the dump account. The table is still fed (landings to
2026-10-14 in the dump of 2026-10-16), with no creation stamp since 2025-05-13. From 2021, `sng_cur` names a third
writer that is no schema of this database. The reading rules above are the table's own, so they hold wherever it is
made.

## Chosen

- `sources/lods/convert.R` reads `lods_slaegt` (`lods_raw` in `_targets.R`), multiplies `fteg` 30, 31 and 34 by 1000
  (`TONNES`), leaves `gerd` 'A' out, and keeps the unrounded value.
- Two columns on the lods catch rows, kept through `curate/landing.R` (NA for agf):
  - `hid_origin` (`upprunahofn`): the port, kept per catch row because an export day can have several;
  - `catch_gutted` (`magn`, in kg).
- The key (`vid`, `date`, `hid`) is unchanged, and so is the 159 landing; whether to join it to its home landing is
  plan 036's ask b (TODO 112).

## Checked

On a scratch `$FISHYDATA` (raw, agf's staging and the port reference linked, nothing written to the real store):

- agf's landings and catch are unchanged.
- lods loses 4 of 1,240,680 trips, which held only surcharge rows.
- lods' kg species gain 61.9 kt to 2006 and 4.8 kt after, the surcharge no longer subtracted.
- The tonne species go from 19.1 to 19,086.8 kt to 2006, and from 0.7 to 735.9 kt after.
- 160,061 of the 233,601 lods catch rows at `hid` 159 carry `hid_origin`; elsewhere it equals `hid` on every row.

The data dictionary's `landing_catch.catch` says the current build is wrong for lods until the rebuild.

## Not done

- The rebuild, which belongs with the kvoti re-dump (TODO 110), since that dump changes `lods_raw` too: TODO 119.
- The new columns in `docs/data-dict.yaml` (its validator reads the built files).
- A `basis` on the landings' catch (derived, for lods and agf alike).
- One layer up: `lods_slaegt` against kvoti's LODS tables (`lods_londun`, `lods_afli`, `lods2_*`) for 1992-2006, the
  years lods alone covers.
