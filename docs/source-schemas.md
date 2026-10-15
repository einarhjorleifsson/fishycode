# logbooks — Raw data source schemas

> Load this file when working on raw data, convert scripts, or the dictionary.

Raw data live in `$FISHYDATA/raw/` and are never in git. They are dumped from
Oracle by the scripts in `dump/oracle/` and `dump/ais/stk.R`, one per schema or
source, through `dump_oracle_schema()` (`R/dump_oracle.R`; decision 105). The
paths below are from before the restructuring.

Dump sizes: `data-dump/ais/` ~149 GB, `data-dump/logbooks/` ~3.4 GB,
`data-dump/aux/` ~2.4 GB, `data-dump/landings/` ~797 MB.

---

## `fs_afladagbok/` — FisheryScan digital logbooks (static dump)

Modern electronic submission format from Fiskistofa; records through 2025-12.
Converted by `data-raw/logbooks/01_fs_afladagbok_convert.R` →
`data-raw/logbooks/fs_afladagbok/{trip,station,fishing_sample,catch}.parquet`.

The dump holds 27 tables (plus `_overview_tables` / `_overview_views`); the eight
below are the ones the convert script reads. The rest are change-log tables
(`*_breytingar`), seaweed (`ws_thang_thari`), bycatch (`ws_medafli`,
`mammals_birds`), traceability (`ws_rekjanleiki`), and `ws_stofn_*` gear-detail
lookups.

| Table (parquet) | Key columns | Description |
|---|---|---|
| `ws_veidiferd.parquet` | `id` (→ `.tid`), `skipnr`, `upphafstimi`, `londunardagur` | Trip records; `id` is the primary key, renamed to `.tid` |
| `ws_veidi.parquet` | `id` (→ `.sid`), `veidiferd_id` (→ `.tid`), `veidarfaeri_id` | Fishing event records; `id` primary key, `veidiferd_id` links to trip |
| `ws_afli.parquet` | `veidi_id` (→ `.sid`), `tegund_id` (→ `sid`), `afli` (→ `catch`) | Catch by species |
| `ws_dragnot_varpa.parquet` | `veidi_id` (→ `.sid`), `grandarar_lengd` (→ `g_width`) | Mobile gear (trawl, dragnót) — gear width; covers gid 1–9, 11 |
| `ws_plogur.parquet` | `veidi_id` (→ `.sid`), `breidd` (→ `g_width`) | Dredge (plógur) — plow width; gid 15 only |
| `ws_linanethandf.parquet` | `veidi_id` (→ `.sid`), `fj_kroka` (→ `n_hooks`), `fj_dreginna_neta` (→ `n_nets`), `fj_faera` (→ `n_jigs`) | Static gear (longline, gillnet, handline); gid 1–5, 12, 14, 22 |
| `ws_gildra.parquet` | `veidi_id` (→ `.sid`), `fj_gildra` (→ `n_units`) | Trap records |
| `ws_hringn.parquet` | `veidi_id` (→ `.sid`) | Purse seine / ring net records |

**Coordinates** in `ws_veidi.parquet` are stored as integers in either DMS
(`DD×10000 + MM×100 + SS`) or DDM (`DD×10000 + MM.CC×100`) format depending on
the data source (`uppruni`). The convert script classifies each trip as `"dms"`
or `"ddm"` using a row-level signal (last-2-digits ≥ 60 is impossible in DMS)
lifted to trip level, combined with a hard list of known DDM sources
(`DDM_SOURCES`). Conversion uses `wk_convert_dms()` / `wk_convert_ddm()` from
the `whack` package.

**Longitude sign handling** (reworked 2026-05-06). Conversion no longer negates
before `wk_convert_*`; sign is a separate step. All longitudes are negated, then
records landing at `lon > 10.75` with `lat < 67.66` are flipped back on the
assumption they were already correctly negative. Range filter: lon ∈ [−178, 178],
lat ∈ [0, 85].

This is a heuristic, so `station.parquet` carries a `coord_flag` QC column
(flags only, never filters):

| `coord_flag` | Rule | Stations |
|---|---|---|
| `"meridian"` | `lon1` within ±1° of 0 — digit-encoding error; true position likely 1–9°W | 5,445 |
| `"west"` | `lon1 < −40`, or `< −35` for non-OTM gear | 1,108 |
| `"south"` | `lat1 < 62` for non-OTM gear (OTM south of Iceland is expected) | 300 |
| `NA` | no flag | 463,028 |

**Known coordinate limitation:** gid 9 (Flotvarpa / midwater trawl) rows in
`ws_veidi.parquet` use mixed decimal-degree (1–2 digit integers) and DMS (5–6
digit integers) encoding that cannot be disentangled without per-source
(`uppruni`) classification. 4,635 stations now carry a positive `lon1` (gid 6:
2,378; gid 9: 2,242; others: 15). Positive longitude is **not** automatically an
error — Icelandic vessels fish east of the prime meridian — so the genuine
residual needs re-quantifying; the pre-rework figure of 639 no longer applies.

---

## `afli/` — legacy Oracle logbook system (primary)

92 tables spanning five decades (plus the metadata files `_overview_tables.parquet`
and `_overview_fields.parquet`). Full inventory in `afli-tables.qmd`.

**Three schema eras:**

| Era | Tables | Date range |
|---|---|---|
| Paper logbooks | `stofn`, `afli`, `toga`, `lineha`, `gildra`, `hringn`, … | ~1950–present |
| Early electronic submissions | `rafr_stofn`, `rafr_afli`, `rafr_toga`, … | ~2000–2022 |
| Mandatory digital + compliance | `afladagb_skil`/`_linur`, `afladagb_xml_mottaka` | 2014–2021 |

Converted by `data-raw/logbooks/01_afli_convert.R` →
`data-raw/logbooks/afli/{trip,station,fishing_sample,catch,aggregate}.parquet`.
Coordinates in `stofn.parquet` stored in DDMM integer format; converted via
`geo::geoconvert.1()` (×100 before passing in; longitude negated for West).

**Tables used by `01_afli_convert.R`:**

| Table (parquet) | Description |
|---|---|
| `stofn.parquet` | Fishing station/event records; `visir` is the unique key; 6.9 M rows |
| `afli.parquet` | Catch records by species |
| `toga.parquet` | Tow/mobile gear records |
| `lineha.parquet` | Longline and gillnet records |
| `gildra.parquet` | Trap records |
| `hringn.parquet` | Purse seine / ring net records |

**Additional key tables (not used by convert script):**

| Table (parquet) | Rows | Description |
|---|---|---|
| `rafr_stofn.parquet` | 1,149,278 | Electronic-era fishing stations; carries `xml_sending_visir` → `afladagb_xml_mottaka.id` back-link; coordinates as DDMM integers |
| `rafr_afli.parquet` | 3,625,502 | Electronic-era catch records |
| `rafr_toga.parquet` | 931,260 | Electronic-era trawl records |
| `rafr_lineha.parquet` | 209,257 | Electronic-era longline/gillnet records |
| `sjalfvirkir_maelar.parquet` | 28,234,223 | Automatic logger positions — older, wider (incl. `vindhradi`/`vindstefna`); **wacky coordinates** |
| `rafr_sjalfvirkir_maelar.parquet` | 23,610,639 | Automatic logger positions — leaner; **identical coordinate values** to `sjalfvirkir_maelar` for 685,656 overlapping `visir`; **wacky coordinates** |
| `afladagb_xml_mottaka.parquet` | 483,738 | Raw XML submissions; `sending` column holds full XML; software (`hugbunadur`) predominantly Trackwell variants |
| `afladagb_skil.parquet` | 9,961 | Compliance master table (from Jan 2014) |
| `afladagb_skil_linur.parquet` | 46,561 | Compliance detail by fishing month |
| `rafr_hledsla_log.parquet` | 6,595,396 | Oracle import run log; Icelandic-language messages |

**Raw column vocabulary (afli system → unified name):**

| Raw | Unified | Meaning |
|---|---|---|
| `visir` | `.sid` | Station identifier |
| `skipnr` | `vid` | Vessel identifier |
| `veidarf` | `gid` | Gear type code |
| `dags` | `date` | Fishing date |
| `tegund` | `sid` | Species code |
| `magn` | `catch` | Catch amount |
| `timi` | `timi` | Timestamp (logger positions) |
| `lengd` | `lengd` | Longitude — logger positions (**wacky error**; see `wacky-tracks_recovery.qmd`) |
| `breidd` | `breidd` | Latitude — logger positions (**wacky error**; see `wacky-tracks_recovery.qmd`) |
| `skip_hradi` | `skip_hradi` | Instantaneous vessel speed (knots) |
| `skip_stefna` | `skip_stefna` | Instantaneous vessel heading (degrees) |

---

## `gear/` — gear code vocabulary (hand-maintained)

Script: `data-raw/DATASET_gear-codes.R`  
Output: `data/gear/gear_mapping.parquet`  
Reference: `data-dump/species/asfis.parquet` (loaded but not yet used). The raw
gear dump `data-dump/gear/` (`gear_fishing_gear`, `gear_gear_category`,
`gear_isscfg`, `gear_veidarfaeri_v`, `orri_veidarfaeri`, `orri_veidarfaeri_ny`)
is produced by `data-dump/gear/DUMP_gear.R` but the mapping itself is
hand-maintained in the script.

The `gear_mapping` table maps codes between the two schemas and assigns ICES
metier vocabulary. One row per gear per version.

| Column | Description |
|---|---|
| `version` | `"old"` (afli) or `"new"` (fs_afladagbok) |
| `gid` | Gear code in this version |
| `veiðarfæri` | Icelandic gear name |
| `map` | Canonical counterpart gid in the **other** version |
| `gear` | ICES GearType code (e.g. `"OTB"`, `"LLS"`) |
| `target` | ICES TargetAssemblage code (e.g. `"DEF"`, `"SPF"`) |
| `target2` | Custom target aligned with Icelandic fisheries (partially FAO ASFIS; not ICES-validated) |

**`map` semantics.** One-way canonical lookup only. The mapping is many-to-one
in both directions (e.g. five midwater trawl sub-types in old → one "Flotvarpa"
in new). Round-trips are lossy. Do **not** rely on `map` for bijective
conversion.

Old-side codes 91 (Skötuselsnet), 92 (Grálúðunet), and 99 (Óskráð veiðarfæri)
are explicit rows in `gear_mapping` for new→old lookup completeness; they do
not appear in actual `afli` logbook data (`stofn.parquet`).

---

## `adb/` — live-streaming feed (in-house conversion)

Current live feed from Fiskistofa, converted in-house to partially emulate the
historical `afli` format. Data content effectively the same as `fs_afladagbok`,
just restructured differently. **Uses the old (afli-era) gear code system** —
gear codes stored in `gid_old` in converted output; `gid` derived via
`gear_mapping` (old→new) at merge time.

Converted by `data-raw/logbooks/01_adb_convert.R` →
`data-raw/logbooks/adb/*.parquet`. The dump holds 26 tables.
`01_adb_convert_brute-force.R` is an alternative reader kept for reference.

`adb_files` is still built by `_targets.R`, but the merge is **two-tier**
(`afli` > `fs_afladagbok`) and does not read the adb output.

---

## `logbook/` — experimental restructuring (not in use)

Path: `data-dump/logbooks/logbook/`. Experimental re-layout of `fs_afladagbok`.
Not actively developed; no conversion script planned. Eleven tables:
`trip`, `station`, `catch`, `trawl`, `seine_net`, `surr_net`, `net`, `dredge`,
`hook_line`, `trap`, `diving`.
