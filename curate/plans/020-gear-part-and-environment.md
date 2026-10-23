# 020 — Gear detail and environment as tidy tables beside the fishing sample

**status:** proposal — `gear_part` prototyped for fs_afladagbok in scratch, nothing in the pipeline changed; §5 answered
2026-10-23 (decision 210) ·
**2026-10-15** · **see:** plan 019 (fs_afladagbok mined), plan 018 (the dumps), `docs/grammar.qmd` (field groups,
sensor layer), decision 022 (depth in metres)

Drafted with AI assistance (Claude) on 2026-10-15, at the maintainer's request. The design choices in §2 are the
maintainer's, and the questions in §5 are for the maintainer.

**Measured** (read-only, 2026-10-15): the gear and environment columns of `raw/oracle/fs_afladagbok/`, of afli (its
April dump in `raw/logbooks/afli/`, and Oracle's comments), of adb and of the rebuilt `logbook` schema. What the fs
adapter and its dictionary keep. Fs depths against GEBCO. A prototype of `gear_part` for fs, written to scratch only.
**Assumed:** that fs's `medal_lengd_neta` is in metres; Oracle gives no unit, and adb's `net_length` is metres.

## 1. What is lost between raw and staging

fs_afladagbok is the exact dump of the Directorate of Fisheries' original data (maintainer); adb is an in-house merge
of it with afli, used here only for its names. The fs adapter keeps six gear columns, and its dictionary folds the
source columns into them with mixed units and meanings:

| kept as | trawl | Danish seine | dredge | gillnet | purse seine |
|---|---|---|---|---|---|
| `g_width` | bridle length, fathoms | | width, feet | | |
| `g_length` | | rope length, fathoms | length, feet | nets × mean net length | seine length, fathoms |
| `g_height` | | | height, feet | net height, *meshes* | seine depth, fathoms |
| `g_mesh` | codend, mm | codend, mm | bag, mm | net, mm | seine, mm |

What is dropped: headline length, door weight, sorting grid, square-mesh window, codend mesh orientation
(T0/T45/T90), meshes around a shrimp trawl, one or two gears, dredge, trap and seine types, gear material, the free-text
note, and the number of divers. Nothing reads the `g_*` columns past the adapters: they reach
`curated/logbook/fishing_sample` for analysts only. afli holds more still: `toga` has the footrope, door area, upper
bridles, grid bar spacing, codend length, and headline depth and temperature.

## 2. The design (maintainer, 2026-10-15)

A few tidy tables, not one per gear. The same measure goes in the same column whatever the gear: a mesh size is a mesh
size on a codend, a gillnet or a seine, and a count of nets, hooks, traps, jigs or trawls is one measure. DATRAS's haul
header (HH) is the model for grouping. Environmental data come from each schema itself, and the other schemas give only
ideas.

**`gear_part`**: one row per fishing operation and gear part, keyed on (`.sid`, `schema`), and later `.smid` once
there is a sample table.
- **Parts:** `gear`, `headline`, `footrope`, `sweep`, `rope`, `door`, `codend`, `net`, `hook`, `line`, `jig`, `trap`,
  `dredge`, `seine`, `grid`, `square_window`, `diver`.
- **Measures, one column each:**
  - `n`: the count of the part;
  - `length_m`, `width_m`, `height_m`, `weight_kg`, `area_m2`;
  - `height_meshes`: a height counted in meshes;
  - `mesh_size_mm`, `mesh_orientation` (T0/T45/T90), `meshes_around`;
  - `type`: the source's own type code or text;
  - `material`;
  - `present`: for a part that is either there or not, such as a square window.
- **Units:** metric. Feet, fathoms and inches are converted (0.3048, 1.8288 m and 25.4 mm). The source values stay in
  `raw/oracle/`, and the data dictionary records each conversion.
- **Filled rows only:** a part with no recorded measure gets no row.

**`environment`**: one row per station, keyed on (`.sid`, `schema`): the grammar's environment field group, with its
names (`docs/grammar.qmd`, rewritten 2026-10-15). A value read at both ends takes the numeric suffix: 1 at the start,
2 at the end. The columns are:
- `z1`, `z2`: the water depth, which by the grammar is environment, not the station's envelope;
- `temp1_surface`, `temp2_surface`, `temp1_bottom`, `temp2_bottom`, `temp1_headline`, `temp2_headline`, `temp1_air`;
- `wind_direction`, `wind_force`, `wind_speed`, `sea_state`.

These follow the names afli's dictionary already uses.
- **fs_afladagbok** holds water depth only: no wind, temperature or sea state. Its depth is water depth for every gear,
  and its unit depends on the logbook app (plan 019 §2 item 10). Trackwell records fathoms; Marína and Taktikal record
  metres. `curate/logbook.R`'s flat conversion from fathoms makes about 21,000 stations 1.83 times too deep.
- **afli** has the data:
  - wind: `stofn` (6.9 M stations) and `rafr_stofn` (1.15 M) hold direction and Beaufort force, and `rafr_stofn`
    speed in m/s too;
  - temperatures on trawls: `toga` (5.5 M) and `rafr_toga` (0.93 M) hold bottom, headline and surface, at start and
    end;
  - on lines and nets: `lineha` (1.29 M) and `rafr_lineha` (0.21 M) hold air, surface and bottom temperatures and sea
    state;
  - on purse seines: sea state;
  - the automatic sensors (`sjalfvirkir_maelar`, 28 M readings) are time series, the grammar's sensor layer. They are
    not part of this table.

**`fishing_sample`** keeps the operation: gear, `t1`–`t4`, duration and effort. `effort_count` is the count of the
gear's main part in `gear_part` (nets, hooks, traps, jigs).

## 3. The fs prototype, measured

`gear_part` for fs, from the `ws_*` gear tables and the tour app's `fishing_spot` (plan 019), written to scratch:

- **Coverage:** 1,470,122 rows (15 columns) for 381,653 of fs's 501,666 operations. The other 120,013 operations
  have no row in any gear table.
- **Parts recorded:**
  - **trawls:** 150,423 bottom trawls (`OTB`) with codend mesh and orientation, doors, headline and sweeps at 100 %;
    3,146 with a grid type entered and 87 with a square window. 9,807 midwater trawls (`OTM`) the same, with a grid
    type entered on every one. Most grid-type entries are `Engin skilja` (no grid).
  - **Danish seine:** 57,619 (`SDN`), with codend, headline, rope and sweeps.
  - **dredges:** 4,580, with dimensions, weight, type and bag mesh.
  - **gillnets:** 26,755 (nets, mesh 97 %, height in meshes 97 %, length 2 %).
  - **lines and jigs:** 28,265 longline operations with hooks, 2,312 with lines (tubs), and 102,805 jig operations
    with jigs.
  - **other gears:** 103 traps, 1,278 purse seines (length, depth, mesh, type) and 2 diving operations.
- **Medians after conversion:**
  - mesh: codend 135 mm, gillnet 228 mm, purse seine 20 mm;
  - length: headline 49 m, sweeps 80 m, rope 2,195 m;
  - weight: doors 3,250 kg;
  - purse seine length: 450 m.
- **One bottom trawl, as a check:** codend 30 mm T0, doors 75 kg, headline 32.9 m, sweeps 45.7 m, one gear of
  "Plast og stál".
- **The grid type** is free text: `Engin skilja` 8,701, `Meðaflaskilja` 2,251, `Fiskiskilja` 824,
  `Smárækjuskilja/Seiðaskilja` 816, `Seiðaskilja` 356, and five stray entries.

## 4. Steps

1. **fs:** `sources/fs_afladagbok/convert.R` writes `staging/fs_afladagbok/gear_part.parquet`, after plan 018 phase 3
   has pointed it at `raw/oracle/fs_afladagbok/`, together with plan 019's tour app.
2. **afli:** `sources/afli/convert.R` writes `gear_part` and `environment` from its own tables. adb gets `gear_part`
   from its own tables if it stays a tier.
3. **curate:** `curate/logbook.R` binds both across schemas for the stations it keeps (one schema per station, as for
   the other four tables), into `curated/logbook/gear_part.parquet` and `curated/logbook/environment.parquet`.
4. **docs:** `docs/grammar.qmd` gets both tables under the field groups, and `docs/data-dict.yaml` gets their entries
   (TODO 51).

## 5. Questions

1. **Hooks per jig line against total hooks.** `fj_kroka` is the hooks per jig line on jigs (median 5) and the total
   on longlines (median 18,000). Should part `hook` on a jig hold the total (jigs × hooks), or should it be its own part
   (`hook_per_jig`)?
2. **Net length.** Is `medal_lengd_neta` in metres? (It is filled for 2 % of gillnets.)
3. **The `g_*` columns in `fishing_sample`.** Drop them once `gear_part` is in place, or keep them for a release so that
   analysts can move?
4. **Grid types.** Map them to a short code list, or keep the text as entered?
5. **`environment`.** Build it now from afli? (Start and end as columns `temp1_…`/`temp2_…` is settled by the grammar's
   numeric suffix.)
6. **The free-text note** (`athugasemd_txt`, e.g. "11 lúður"). On `fishing_sample`, or left in raw?

## 6. The free-text notes, classified (2026-10-23)

Claude's read-only study of question 6 (answered in decision 210), not checked by a person; every number, rule and
script is in `$FISHYDATA/archive/2026-10-logbook-notes/README.md`. Notes may name people: they stay under `$FISHYDATA`,
and only counts and patterns are written here.

- **Where:** 104,590 notes in the counting set: fs (23,885, 2020-2025; adb's 5,223 from 2025-11-19, decision 160),
  afli's `stofn.aths_texti` (52,755, 1953-2023) and 15,053 more the apps sent that Oracle never stored, the purse seine's
  `athskipst` (2,342), the lumpsucker effort notes (5,042, 1977-2015) and the bycatch tables (290). None in the tour app.
- **The rules:** 73 regular expressions in 18 classes, with the spellings found (makríll, makrill, mak, mac; dælt,
  dlt, baelt; sleppt, slept, sleft); 3.1 % stay "other", mostly fishing-ground names. 45 % of fs's notes are exactly
  afli's coded remark (`stofn.athugas`: gear trouble 1-14, "Tvö troll" 20-34, "Tvílembingar" 40-54) written as text by
  Trackwell, so the two can share one code list.
- **Transfers:** 7,262 notes; a partner vid for 98 % of the e-logbook's, by register number, call sign, district
  number or name (flagged), the routes agreeing on 91 %. In the e-logbook the receiver logs pumped catch, not the
  catcher (1,890 of 1,899 matched pairs): 70-100 kt of pelagic catch a year sits on the receiver's station, its catcher
  named in 97 %. Decision 199's carrier trips have a note naming the catcher in 15-27 %. The maintainer (2026-10-23):
  the catch stays on the vessel that caught it; the landing goes with the vid of the vessel that landed it.
- **Samples:** survey notes find their MFRI survey sample (`channel`) in 88-100 %; other sample notes a sample of the
  same vessel within 2 days in 55-66 %, mostly the crew's (category 4). `rdbes` cannot be joined (encrypted vessel).
- **Released halibut:** 869 notes; the station records halibut on 19 of 275 fs ones, so it is outside the recorded
  catch. fs and adb also record a released condition (RELE, 158-190 t of halibut a year since 2022), which sits inside
  `catch_round`.
- **afli's 40,967 summary stations** (stamped "Frá OPS$SIGFUS.GAMALL_HUMAR, samantekt", shrimp, Danish seine) are
  logbook catch by vessel, month and square, not landings. The adapter sets them aside in
  `staging/afli/aggregate.parquet`, which nothing reads. For Nephrops 1986-99 they repeat afli's hauls (double
  counting if summed); elsewhere they are the only record (175 kt). The maintainer (2026-10-23): they belong in the
  logbooks; `ops$sigfus` is added to the dump (d57a8ee).
- **Proposed for staging**, basis `derived`, keyed on (`.sid`, `schema`): `station_note` (the text, class and tags);
  `remark` (one code list for afli's `athugas` and the e-logbook's code texts); `transfer` (catching vid and station,
  receiving vid, date, species, kg); `released`; `sample`. Asks a-d in the README's §5.
