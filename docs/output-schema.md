# The logbook tables: columns, times and effort

*Carried over from the predecessor repository. Updated with AI assistance (Claude) on 2026-10-21: the paths, the
schemas each column is noted for, the landing link and the depth unit, and the merge section, which now points to
[merge.qmd](merge.qmd) instead of describing the merge before the restructuring (decision 160).*

The merged tables are `$FISHYDATA/curated/logbook/{trip,station,fishing_sample,catch}.parquet`, written by
`curate/logbook.R`; each source's own are `$FISHYDATA/staging/<schema>/`, written by `sources/<schema>/convert.R`.
Each file's columns are described once, in `docs/data-dict.yaml` (its tables `logbook_trip`, `logbook_station`,
`logbook_fishing_sample` and `logbook_catch`), which `data-dict validate-meta` checks against the files. This page
keeps what the dictionary does not hold. Its four column tables, carried over from the predecessor repository, were
retired on 2026-10-30 at the maintainer's word (TODO 111, plan 054 ask l), with AI assistance (Claude).

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

> The trip's landing is not a column of `trip.parquet`. The landings match writes it to its own table,
> `curated/logbook/lid_map.parquet` (`curate/link_lid_map.R`: `.tid`, `schema`, `.lid`, `match_type`, ...).

`T1` and `T2` are declared, not departure and arrival times (AGENTS.md, Terms). In afli both are dates at
midnight, so widen them before using them in a `between()` join with the track.

---

## `station.parquet`

One row per fishing operation. Narrow spatial/temporal envelope only —
gear and effort detail is in `fishing_sample.parquet`.

> In the per-schema `staging/<schema>/` files `.tid` is still numeric; the merge casts it to character
> ([merge.qmd](merge.qmd)).

---

## `fishing_sample.parquet`

One row per fishing operation (1:1 with `station.parquet`; join on `.sid`).
Gear-specific columns are `NA` where not applicable. A mishap is a flag: the haul and its catch stay as recorded. From
1996 afli holds no tow without catch, so afli's effort lacks the empty tows (plan 050 §6).

**`afli`-only gear-detail columns** (`NA` for the other schemas): `bottom_type`,
`catch_nperkg`, and the SDN net dimensions `length_togle`, `length_virle`,
`mesh_vod`, `length_headline`, `length_fotreipi`.

> **`date` lives in `station.parquet`**, not here — join on `.sid`.

### Timestamp population by schema and gear class

Reworked 2026-04-22 (`t0`–`t3` → `t1`–`t4`) and again 2026-05-06 for
`fs_afladagbok`. "Mobile" means OTB / OTM / DRB / SDN.

| Schema · class | t1 | t2 | t3 | t4 | `duration_m` |
|---|---|---|---|---|---|
| `afli` mobile | `NA` | from `ibotni` (hhmm, gear on bottom) | `t2 + duration_m` (from `togtimi`) | `NA` | `togtimi` (tow time) |
| `afli` static (LLS/GNS/GND) | `logn_hefst` | `NA` | `drattur_hefst` | `drattur_lykur` | as recorded (`klst`, `naetur`) |
| `fs_afladagbok` mobile | `NA` | `upphaf_timi` | `lok_timi` | `NA` | `NA` (from the times) |
| `fs_afladagbok` static (LLS/GNS/GND/LHM/FPO) | `upphaf_timi` | `NA` | `milli_timi` | `lok_timi` | `NA` (from the times) |
| `adb` | as `fs_afladagbok` (its `fishing_start`, `tow_start`, `fishing_end` are `upphaf_timi`, `milli_timi`, `lok_timi`; read the same way since plan 050 step 2, `R/logbook_effort.R`) | | | | |

**The 2021 ends.** fs_afladagbok's 2021 feed (`ws_veidiferd.uppruni` TRACKWELL, STOKKUR) has a start and no end. The merge keeps 22,359 of its stations, on vessel-days afli lacks (handline 18,884, gillnet 2,710, longline 763). Their `t3`/`t4` are NA and `.duration_source` is `"missing"`. Neither afli's sent messages nor adb holds the ends (plan 050 step 6).

Notes:
- **SDN in `fs_afladagbok`** is treated as mobile. If `milli_timi` ≠ `upphaf_timi`
  (three distinct timestamps) the script instead reads t1=`upphaf_timi`,
  t2=`milli_timi`, t3=`lok_timi` — not seen in the current data, where
  `milli_timi == upphaf_timi` for 100% of SDN rows.
- **LHM in `afli`** carries timestamps in `lineha` for only ~3% of rows;
  duration comes from `klst` / `naetur` instead.
- A static set's duration is the analyst's choice: `t1` → `t4` (shooting to the end of hauling), `t1` → `t3` (the
  soak) or `t3` → `t4` (the hauling), by `calc_effort(from, to)`.

---

## `catch.parquet`

One row per species per station. Orphan catch records (no matching station)
dropped via `inner_join`.

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

## The count and the effort

The sample stores the count, not the effort (plan 050, ask e, 2026-10-29). `effort_count` is what fishes at once,
read by each adapter from its own fields (`R/logbook_effort.R`):

| ICES `gear` | `effort_count_unit` | afli | fs_afladagbok, adb |
|---|---|---|---|
| OTB, OTM | `trawls` | `tvo_veidarf` 0/1 as 1/2 (`derived`) | `tvo_veidarf` / `two_fg` (`recorded`) |
| DRB | `dredges` | `tvo_veidarf` 0/1 as 1/2 (`derived`) | `ws_plogur.tvo_veidarf` / `two_dredges` |
| SDN, PS | `seines` | 1 (`synthesised`) | 1 (`synthesised`) |
| LLS | `hooks` | `fj_kroka`, else hooks per set × sets (`derived`) | `fj_kroka` / `hooks` |
| GNS, GND | `nets` | `dregin` | `fj_dreginna_neta` / `nets` |
| LHM | `jigs` | `faeri` | `fj_faera` / `pole_and_lines` |
| FPO | `traps` | `gildrur` | `fj_gildra` / `number_of_traps` |

A towed gear or a seine with no count recorded takes 1 (`synthesised`); a passive gear's missing or 0 count is NA
(`none`). The effort is made from the times, the record's own duration and the count, with the analyst's choices,
by `calc_effort(sample, from, to, by_count, unit)`: by default a mobile gear's `t2` → `t3` and a static gear's `t1` →
`t4`, `duration_m` where those times are missing, times the count, in hours.

### The duration and its limit

`duration_m` is the duration the record gives as a duration: afli's tow time (`togtimi`) and its jigs' hours or
nights, aflaskeyti's haul length. The e-logbook gives times, not a duration, so its `duration_m` is NA and
`.duration_source` is `"times"`. Each duration, or for the e-logbook the span of its times (a tow `t3 − t2`, a set
`t4 − t1`), is judged against the gear's plausible maximum, `dur_max_min` in `curated/reference/gear_window.parquet`
(`R/duration_limit.R`). Above it `.duration_source` is `"implausible"`, a flag: the times and the duration stay as
recorded (plan 050 ask h, 2026-10-29; until then decision 057 set them NA here). The limit is applied where the times
are read: the windows, the voyage links and the audit leave out the end a flagged duration ran to (a mobile gear's
`t3`, the e-logbook's static `t4`) and the duration, through `judged_time_sql()`, and so does `calc_effort()` unless
told `implausible = TRUE`. Otherwise `.duration_source` is `"data"` (a recorded duration), `"times"` or `"missing"`.

## Merged output (`curated/logbook/`)

`curate/logbook.R` merges the schemas by vessel-day, in tiers: afli, then fs_afladagbok, then the paper stations
read from `fs_afli` (2b), then adb (only from 2025-11-19, decision 160), then aflaskeyti (plan 026). The tiers,
the date bounds, the rationale and the record counts are in [merge.qmd](merge.qmd), which computes its counts from
the files; the landings match then writes `curated/logbook/lid_map.parquet` (`curate/link_lid_map.R`).

## Gear, rigging and sensors (`gear_part`, `rigging_part`, `sensor_summary`)

*Added with AI assistance (Claude) on 2026-10-29 (plan 052, decision 244); not checked by a person.*

Three tables beside `fishing_sample` in `curated/logbook/`, keyed on (`.sid`, `schema`) for the stations the merge
keeps, duplicate twins left out (decision 094). They carry no time. Each source's own are
`staging/<schema>/{gear_part,rigging_part,sensor_summary}.parquet` (`sources/<schema>/part.R`), bound by
`curate/logbook_part.R`. `docs/grammar.qmd` (Configuration, Environment) gives the shape; `docs/data-dict.yaml`
every column.

- **`gear_part`**: the netting and what is fixed to it, one row per station and part (`headline`, `codend`, `net`,
  `footrope`, `grid`, `hook`, `dredge`, `seine`, …), one column per measure in SI units.
- **`rigging_part`**: what joins the units to the vessel and to each other, and how many: `rig` (single, twin,
  triple, pair; `n` the units fished at once), `unit` (nets, tubs, jigs, traps, divers), `hook_total`, `door`,
  `sweep`, `upper_bridle`, `rope`, `wire`.
- **`sensor_summary`**: one row per station and reading (`quantity`, `place`, `moment`, `instrument`): the
  temperatures, the headline depth, wind, sea state, the bottom, and which sensors were fitted. afli only: fs_afladagbok
  and adb hold no reading but the water depth, which stays on the station (`z1`, `z2`).

**Where each value comes from.** `curated/reference/gear_part_map.parquet` names every column of every source table in
one outcome: the part and measure it fills, its unit and factor to SI, the gears it applies to, its plausible range and
code list, or why it is not used. afli is read from its loaded `rafr_` tables first (afli's copy, then fs_afli's for
2020-07 to 2023), the values the loader lost from the sent messages (hook type and size, hand-baiting, hooks per jig,
the dredge's size, the headline depth), and its edited tables (the paper years). Where the edit changed a loaded value,
the edit answers on records to 2018 and wherever the domain expert last changed the station (his manual corrections,
trusted by the maintainer), the loaded value on the afli route's import of 2019 on; per measure the best layer holding
a value answers, and `layer` names every table a row's values came from. fs_afladagbok and adb are read
from their gear tables (adb from 2025-11-19, as the merge has it).

**Units.** afli's headline and sweeps are metres (not the feet and fathoms of Oracle's comments; plan 052 §2), its
gillnet mesh mm (not inches), its Danish seine rope and wire and its purse seine's length and depth fathoms.
fs_afladagbok's and adb's headline is feet, their sweeps, rope and the purse seine's length and depth fathoms. The
headline depth is metres or fathoms by the element the app sent, read per record from the message. A gillnet's mean
length is metres in every source, read from the values (basis `reconstructed`: the regulation's 60 fathoms of netting
per net hang some 55 m; decision 245). A dredge's size is kept raw (`length_raw`, `unit_raw` "unknown"), with no
metres: the documents say feet and the scallop dredges agree, but the sea urchin and sea cucumber dredges read as metres
(decision 245). A door area above 40 m² is flagged implausible, kept as recorded: not square feet, on some vessels the
area with its decimal point lost (decision 245).

**Flags.** A value outside its plausible range is kept and flagged `implausible`; an unknown code `unknown_code`.
In `sensor_summary` a placeholder (a temperature of 0.0, a headline depth of 0 or 1, a sea state or wind speed of -1,
a wind direction of 0 with no wind) keeps `value_raw` and has no `value`. A 0 in a gear or rigging measure is a form's
empty field: no value. A row in another gear's table than the station's (left there when the station's gear was
corrected and the old row not deleted) is not carried. `curated/check/logbook_part_column.parquet` counts every
source column's values by outcome; `curated/check/logbook_part_station.parquet` puts every kept station in one outcome
per table, and sets `effort_count` read from `rigging_part` against `fishing_sample`'s.
