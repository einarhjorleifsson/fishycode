# The logbook tables: columns, times and effort

*Carried over from the predecessor repository. Updated with AI assistance (Claude) on 2026-10-21: the paths, the
schemas each column is noted for, the landing link and the depth unit, and the merge section, which now points to
[merge.qmd](merge.qmd) instead of describing the merge before the restructuring (decision 160).*

The merged tables are `$FISHYDATA/curated/logbook/{trip,station,fishing_sample,catch}.parquet`, written by
`curate/logbook.R`; each source's own are `$FISHYDATA/staging/<schema>/`, written by `sources/<schema>/convert.R`.
The column tables below were written for afli and fs_afladagbok and list fewer columns than the files hold (raw
values, basis columns, twins, station type, set-time placeholders); `docs/data-dict.yaml` describes the columns of
each file.

---

## Dictionary

Column renaming from source vocabulary is handled by `wk_translate()` (from the
`whack` package) using `curated/reference/dictionary.parquet` (built by
`reference/dictionary.R`).

| Column | Description |
|---|---|
| `clean` | Unified / target column name |
| `messy` | Raw source column name |
| `level` | Hierarchy level the column belongs to (see `grammar.qmd`) |
| `sample_type` | Sample type the column belongs to |
| `schema` | Source system (`"afli"`, `"fs_afladagbok"`, `"adb"`) |
| `table` | Raw source table the column comes from |

Convert scripts filter to their schema at the top:

```r
SCHEMA <- "fs_afladagbok"
dictionary <- read_parquet(fd_curated("reference", "dictionary.parquet")) |> filter(schema == SCHEMA)
```

No bare `rename()` calls should remain in convert scripts except for
truly table-specific ambiguous names (e.g. `id` appears in multiple
`fs_afladagbok` tables and is renamed inline; `breidd` in `ws_plogur` means
plow width, not latitude — kept as an inline rename to avoid polluting the
schema-level dictionary). Dictionary is currently **154 entries**: `afli` 98,
`fs_afladagbok` 38, `adb` 18.

---

## `trip.parquet`

One row per fishing trip (voyage). `.tid` origin differs by schema:
- `afli`: derived as `min(.sid)` within `(vid, T2, hid2)` — not a raw source column; `T1` is the minimum fishing date within the trip.
- `fs_afladagbok`: taken directly from `ws_veidiferd.id`.
- `adb`: `fishing_trip.id` (the view `trip_v`'s `trip_id`, decision 170); `aflaskeyti`: its trips are cut at landings in Iceland by `curate/aflaskeyti_trip.R`
  (plan 026).

| Column | Type | Description |
|---|---|---|
| `.tid` | chr | Trip identifier (cast to character in the merged output) |
| `vid` | int | Vessel identifier |
| `T1` | datetime | Departure time (or earliest fishing date for `afli`) |
| `hid1` | dbl | Departure harbour ID (`NA` for `afli`) |
| `T2` | datetime | Landing date/time |
| `hid2` | dbl | Landing harbour ID |
| `n_crew` | int | Crew count |
| `schema` | chr | Schema tag (`"afli"`, `"fs_afladagbok"`, `"adb"`, `"aflaskeyti"`) |
| `port` | chr | Landing port name |
| `source` | chr | Source system tag (within the `fs_afladagbok` and `aflaskeyti` schemas; `NA` for `afli` and `adb`) |

> The trip's landing is not a column of `trip.parquet`. The landings match writes it to its own table,
> `curated/logbook/lid_map.parquet` (`curate/link_lid_map.R`: `.tid`, `schema`, `.lid`, `match_type`, ...).

`T1` and `T2` are declared, not departure and arrival times (AGENTS.md, Terms). In afli both are dates at
midnight, so widen them before using them in a `between()` join with the track.

---

## `station.parquet`

One row per fishing operation. Narrow spatial/temporal envelope only —
gear and effort detail is in `fishing_sample.parquet`.

> Types below are those of the **merged** `curated/logbook/` files. In the
> per-schema `staging/<schema>/` files `.tid` is still numeric; the
> merge casts it to character ([merge.qmd](merge.qmd)).

| Column | Type | Description |
|---|---|---|
| `.tid` | chr | Trip identifier |
| `.sid` | dbl | Station identifier |
| `date` | datetime | Fishing date |
| `lon1`, `lat1` | dbl | Start position (decimal degrees) |
| `lon2`, `lat2` | dbl | End position (decimal degrees) |
| `sq` | int | Statistical square [1–999]; `afli` only — `NA` for the other schemas |
| `ssq` | int | Statistical sub-square [0–4]; `afli` only — `NA` for the other schemas |
| `z1`, `z2` | dbl | Start / end depth (m), converted to metres by `curate/logbook.R` (`curate/decisions/022-depth-unit-is-metres.md`); `z1_raw`/`z2_raw` keep the recorded value and `z1_basis`/`z2_basis` say which happened |
| `schema` | chr | Schema tag |
| `eytt_deleted` | lgl | `TRUE` for records flagged deleted in the source (392 stations in the build of 2026-10-21; read from `fs_afli` since decision 124); `afli` only |
| `coord_flag` | chr | Suspect-coordinate QC label — `"meridian"`, `"west"`, `"south"` (`fs_afladagbok`, see [source-schemas.md](source-schemas.md)) or `"lat_lon_swapped"` (`aflaskeyti`, `curate/corrections/aflaskeyti_coordinates.R`), else `NA`. Flags; does not filter. |

---

## `fishing_sample.parquet`

One row per fishing operation (1:1 with `station.parquet`; join on `.sid`).
Gear-specific columns are `NA` where not applicable.

| Column | Type | Description |
|---|---|---|
| `.tid` | chr | Trip identifier |
| `.sid` | dbl | Station identifier (PK = FK to `station`) |
| `gid` | dbl | Gear type code — "new" version; unified across schemas. `NA` for `adb`, whose gear is read through adb's own crosswalk into `curated/logbook/gear.parquet` (`curate/corrections/logbook_gear.R`, plan 034) |
| `gid_old` | int | Counterpart old-version gear code; `NA` where no mapping exists. For `adb`, its own code as recorded |
| `gear` | chr | ICES GearType code (e.g. `"OTB"`, `"LLS"`) |
| `target2` | chr | Custom Icelandic target code |
| `t1` | datetime | Gear deployment starts (Event 1) |
| `t2` | datetime | Gear deployment ends / gear on bottom (Event 2) |
| `t3` | datetime | Gear retrieval starts (Event 3) |
| `t4` | datetime | Gear retrieval ends (Event 4) |
| `duration_m` | dbl | Operation duration (minutes) — see the table below |
| `.duration_source` | chr | `"data"`, `"capped"`, or `"missing"` |
| `.t2_source`, `.t3_source` | chr | `"data"` or `"derived"` — whether the timestamp came from a raw column or was computed |
| `.checks` | chr | Convert-time validation notes |
| `effort_count` | dbl | Count component of effort (hooks, nets, jigs, trap units, or gear count) |
| `effort_duration` | dbl | Time component in the natural unit of `effort_unit` |
| `effort_unit` | chr | Unit label: `"gear-minutes"`, `"hook-days"`, `"net-days"`, `"jig-hours"`, `"trap-hours"`, `"setting"` |
| `effort` | dbl | `effort_count × effort_duration` |
| `n_units` | dbl | Number of gear units (nets, hook sets, traps, trawls) |
| `n_total` | dbl | Total hooks for LLS (`fj_kroka`, or `n_hooks_per_set × n_sets`) |
| `n_per_unit` | dbl | Hooks per set (LLS) or hooks per jig (LHM) |
| `n_lost` | dbl | Number of lost gear pieces (`fs_afladagbok` only) |
| `g_mesh` | dbl | Mesh size |
| `g_width` | dbl | Gear width (trawls: beam/wing span; dredge: plow width) |
| `g_length` | dbl | Gear length (seine: rope length; gillnet: total net length) |
| `g_height` | dbl | Gear height (dredge height; gillnet height) |
| `back_entry` | lgl | `TRUE` for pre-1980 records with `.sid > 2,500,000` — retrospective back-entries; `FALSE` for genuine contemporaneous records and all post-1979 data. `afli` only; `NA` for the other schemas. See `afli-backentry.qmd`. |
| `eytt_deleted` | lgl | `TRUE` for records flagged deleted in the source; `afli` only |
| `schema` | chr | Schema tag |

**`afli`-only gear-detail columns** (`NA` for the other schemas): `bottom_type`,
`catch_nperkg`, and the SDN net dimensions `length_togle`, `length_virle`,
`mesh_vod`, `length_headline`, `length_fotreipi`.

> **`date` lives in `station.parquet`**, not here — join on `.sid`.

### Timestamp population by schema and gear class

Reworked 2026-04-22 (`t0`–`t3` → `t1`–`t4`) and again 2026-05-06 for
`fs_afladagbok`. "Mobile" means OTB / OTM / DRB / SDN.

| Schema · class | t1 | t2 | t3 | t4 | `duration_m` |
|---|---|---|---|---|---|
| `afli` mobile | `NA` | from `ibotni` (hhmm, gear on bottom) | `t2 + duration_m` (from `togtimi`) | `NA` | `t3 − t2` (tow time) |
| `afli` static (LLS/GNS/GND) | `logn_hefst` | `NA` | `drattur_hefst` | `drattur_lykur` | `t4 − t1` (approx soak) |
| `fs_afladagbok` mobile | `NA` | `upphaf_timi` | `lok_timi` | `NA` | `t3 − t2` |
| `fs_afladagbok` static (LLS/GNS/GND/LHM/FPO) | `upphaf_timi` | `NA` | `milli_timi` | `lok_timi` | `t4 − t1` (approx soak) |

Notes:
- **SDN in `fs_afladagbok`** is treated as mobile. If `milli_timi` ≠ `upphaf_timi`
  (three distinct timestamps) the script instead reads t1=`upphaf_timi`,
  t2=`milli_timi`, t3=`lok_timi` — not seen in the current data, where
  `milli_timi == upphaf_timi` for 100% of SDN rows.
- **LHM in `afli`** carries timestamps in `lineha` for only ~3% of rows;
  duration comes from `klst` / `naetur` instead.
- Static `duration_m` includes hauling (`t4 − t1`) rather than true soak
  (`t3 − t1`), for consistency between the two schemas.

---

## `catch.parquet`

One row per species per station. Orphan catch records (no matching station)
dropped via `inner_join`.

| Column | Type | Description |
|---|---|---|
| `.sid` | dbl | Station identifier |
| `sid` | int | Species identifier |
| `catch` | int | Total catch, kg (summed within `.sid × sid`) |
| `schema` | chr | Schema tag |

---

## `aggregate.parquet` (`staging/afli/` only — not in merge)

Monthly summary records from `afli/stofn` that were back-entered as aggregates
rather than individual hauls. Excluded from `station.parquet`,
`fishing_sample.parquet`, and the merged output because they do not represent
discrete fishing operations. Preserved here for catch time-series and coverage
work.

**Three source types**, all with `date` pinned to the 15th of the month and no
coordinates:

| `agg_type` | `gid` | Records | Date range | Original `comment` |
|---|---|---|---|---|
| `"nephrops"` | 9 | 26,405 | 1960–1999 | `Frá OPS$SIGFUS.GAMALL_HUMAR, samantekt` |
| `"shrimp"` | 14 | 12,708 | 1953–1986 | `Frá OPS$SIGFUS.GOMUL_RAEKJA, samantekt` |
| `"dseine"` | 5 | 1,854 | 1960–1966 | `Frá afli.gomul_dragnot, samantekt, ...` |

**Schema:** one row per aggregate station × species.

| Column | Type | Description |
|---|---|---|
| `.sid` | int | Station identifier (links to raw `stofn`) |
| `vid` | int | Vessel identifier (`NA` for some dseine rows) |
| `gid` | int | Gear code (new version) |
| `date` | datetime | Month midpoint (always the 15th) |
| `sq` | int | Statistical square |
| `ssq` | int | Statistical sub-square |
| `agg_type` | chr | `"nephrops"`, `"shrimp"`, or `"dseine"` |
| `sid` | int | Species identifier |
| `catch` | dbl | Catch (summed within `.sid × sid`) |
| `duration_m` | dbl | Aggregated tow time from `toga`; `NA` for dseine (no toga records) |

---

## Effort units by gear class

`effort = effort_count × effort_duration`. Both convert scripts dispatch on the
**ICES `gear` code**, not on the numeric `gid` — the gear code is resolved from
`gear_mapping` first, so the same block serves both schemas.

| ICES `gear` | `effort_count` (afli) | `effort_count` (fs_afladagbok) | `effort_unit` |
|---|---|---|---|
| OTB, OTM | `1L` (`n_units` unreliable) | `1L` | `"gear-minutes"` |
| DRB | `coalesce(n_units, 1L)` | `coalesce(n_units, 1L)` | `"gear-minutes"` |
| SDN | `1L` | `1L` | `"setting"` |
| LLS | `n_total` = `n_hooks`, else `n_hooks_per_set × n_sets` | `n_hooks` (`fj_kroka`) | `"hook-days"` |
| GNS, GND | `n_units` = `n_nets` (`dregin`) | `n_units` = `n_nets` (`fj_dreginna_neta`) | `"net-days"` |
| LHM | `n_jigs` (`faeri`) | `n_jigs` (`fj_faera`) | `"jig-hours"` |
| FPO | `n_units` (`gildrur`) | `n_units` (`fj_gildra`) | `"trap-hours"` |
| PS | `1L` | `1L` | `"setting"` |

`effort_duration` is derived identically in both scripts from the capped
`duration_m` (minutes):

| `effort_unit` | `effort_duration` |
|---|---|
| `"gear-minutes"` | `duration_m` |
| `"hook-days"`, `"net-days"` | `duration_m / (60 × 24)` |
| `"jig-hours"`, `"trap-hours"` | `duration_m / 60` |
| `"setting"` | `1` |

> SDN and PS record a duration but their effort is per setting, so
> `effort_duration = 1` regardless of `duration_m`.

### Duration caps

Maximum plausible operation duration; anything above is capped and
`.duration_source` set to `"capped"`. The two schemas key their caps differently.

**`afli` — keyed by (`gear`, `target2`), hours:**

| gear | target2 | cap | gear | target2 | cap |
|---|---|---|---|---|---|
| OTB | DEF | 10 | GNS | DEF / LUM / MON / GHL | 168 (7 d) |
| OTB | NEP | 8 | GND | SPF | 1 |
| OTB | SHR | 16 | LLS | DEF | 24 |
| OTM | SPF / XXX | 24 | LHM | DEF | 24 |
| DRB | ARI | 4 *(suspiciously low — CHECK)* | FPO | GAD / CRB / WHL | 480 (20 d) |
| DRB | ECH / SCL | 12 | SDN | DEF | 3 |

**`fs_afladagbok` — keyed by `gid`, hours:**

| gid | gear | cap | gid | gear | cap |
|---|---|---|---|---|---|
| 1 Skötuselsnet | GNS | 168 | 11 Dragnót | SDN | 4 |
| 2 Þorskfisknet | GNS | 168 | 12 Lína | LLS | 24 |
| 3 Grásleppunet | GNS | 168 | 13 Landbeitt lína | LLS | 24 |
| 4 Rauðmaganet | GNS | 168 | 14 Handfæri | LHM | 24 |
| 5 Reknet | GND | 24 | 15 Plógur | DRB | 20 |
| 6 Botnvarpa | OTB | 12 | 16 Gildra | FPO | 480 |
| 7 Humarvarpa | OTB | 12 | 21 Línutrekt | LLS | 24 |
| 8 Rækjuvarpa | OTB | 16 | 22 Grálúðunet | GNS | 168 |
| 9 Flotvarpa | OTM | 30 | | | |

## Merged output (`curated/logbook/`)

`curate/logbook.R` merges the schemas by vessel-day, in tiers: afli, then fs_afladagbok, then the paper stations
read from `fs_afli` (2b), then adb (only from 2025-11-19, decision 160), then aflaskeyti (plan 026). The tiers,
the date bounds, the rationale and the record counts are in [merge.qmd](merge.qmd), which computes its counts from
the files; the landings match then writes `curated/logbook/lid_map.parquet` (`curate/link_lid_map.R`).
