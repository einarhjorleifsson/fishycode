# logbooks — Raw data source schemas

*Carried over from the predecessor repository. Updated with AI assistance (Claude) on 2026-10-21: the paths, the
dumps' table counts and sizes, the afli section's reading of `fs_afli` (decision 124), and the adb and `logbook`
sections. How the merge uses each source is in [merge.qmd](merge.qmd) (decision 160).*

Raw data live in `$FISHYDATA/raw/` and are never in git. Each Oracle schema is
dumped as it is to `raw/oracle/<schema>/` by `dump/oracle/<schema>.R`, through
`dump_oracle_schema()` (`R/dump_oracle.R`; decision 105, plan 018), with an
overview, the columns' types and comments, and a `_data-dict.yaml`. Each
adapter, `sources/<schema>/convert.R`, writes `staging/<schema>/`, and
`curate/logbook.R` merges the logbook schemas into `curated/logbook/`.

Dump sizes on 2026-10-21: `raw/oracle/afli/` 5.0 GB, `raw/oracle/fs_afli/`
5.6 GB, `raw/oracle/fs_afladagbok/` 66 MB, `raw/oracle/adb/` 191 MB.

---

## `fs_afladagbok/` — FisheryScan digital logbooks (static dump)

Modern electronic submission format from Fiskistofa; a one-time dump whose
records end on 2025-11-28, thinning from 2025-11-19 (decisions 125, 160).
Converted by `sources/fs_afladagbok/convert.R` →
`staging/fs_afladagbok/{trip,station,fishing_sample,catch}.parquet`.

The dump (`raw/oracle/fs_afladagbok/`) holds 32 tables and views; the eight
below are the ones the adapter reads. The rest include change-log tables
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

Converted by `sources/afli/convert.R` →
`staging/afli/{trip,station,fishing_sample,sensor,catch,aggregate}.parquet`.
Since decision 124 the adapter also reads `fs_afli`, the Directorate's copy of
the schema: the deletion flag from `fs_afli.rafr_stofn`, and the paper stations
of `fs_afli.stofn` that `afli.stofn` lacks, with their detail rows (the merge's
tier 2b, [merge.qmd](merge.qmd)).
Coordinates in `stofn.parquet` stored in DDMM integer format; converted via
`geo::geoconvert.1()` (×100 before passing in; longitude negated for West).

**Tables used by `sources/afli/convert.R`** (from `afli`, and from `fs_afli` as above):

| Table (parquet) | Description |
|---|---|
| `stofn.parquet` | Fishing station/event records; `visir` is the unique key; 6.9 M rows |
| `afli.parquet` | Catch records by species |
| `toga.parquet` | Tow/mobile gear records |
| `lineha.parquet` | Longline and gillnet records |
| `gildra.parquet` | Trap records |
| `hringn.parquet` | Purse seine / ring net records |

**Additional key tables of `afli` (not read by the adapter):**

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

`fs_afli`'s `afladagb_xml_mottaka` is read by `curate/corrections/afli_end_longitude.R`, and the two logger
tables by `curate/logbook_sensor_gps.R`, a one-time fix (plan 014).

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

Script: `reference/gear/mapping.R`  
Output: `curated/reference/gear.parquet` (the predecessor's `gear_mapping`)  
Reference: `raw/oracle/asfis/asfis.parquet` (loaded but not yet used). The raw
gear dump, `raw/oracle/gear/` (20 tables), is produced by `dump/oracle/gear.R`,
but the mapping itself is hand-maintained in the script.

The gear table maps codes between the two schemas and assigns ICES
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

## `adb/` — a view of the same e-logbook, derived in-house

A schema of MFRI's Oracle that re-serves the Directorate's e-logbook in a layout
that partly emulates `afli`, derived from fs_afladagbok and other schemas, and
running on past the dump's end: 467,635 of fs_afladagbok's station ids are in
adb (decision 125), and adb adds errors of its own (decision 160), among them a
dropped west sign (`curate/corrections/adb_vs_fs_afladagbok.yml`). **Uses the
old (afli-era) gear code system**: the adapter keeps the code as `gid_old` and
leaves `gid` empty, and `curate/corrections/logbook_gear.R` reads adb's own
crosswalk (`fishing_gear`) to the new gid (plan 034).

Converted by `sources/adb/convert.R` →
`staging/adb/{trip,station,fishing_sample,catch}.parquet`. The dump
(`raw/oracle/adb/`) holds 32 tables and views. `sources/adb/convert_brute_force.R`
is an alternative reader kept for reference.

The merge reads adb only from 2025-11-19, where fs_afladagbok's dump thins and
ends, for the vessel-days no higher tier holds (tier 3, decision 160): see
[merge.qmd](merge.qmd).

---

## `logbook/` — trial work, not a source

Path: `raw/oracle/logbook/`, dumped by `dump/oracle/logbook.R`. Trial work, not
a source (maintainer, 2026-10-21): its `trip` is a derived afli trip table
(`system` is `afli` in all its 1,097,466 rows). Nothing in fishycode reads it.
Twelve tables: `trip`, `station`, `catch`, `bycatch`, `trawl`, `seine_net`,
`purse_seine`, `net`, `dredge`, `hook_line`, `trap`, `diving`.
