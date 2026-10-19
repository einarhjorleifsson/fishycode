# 148 — Other fleets' small-scale tracking data and code gathered for testing ramb (plan 031 §4.8)

*2026-10-19. The maintainer asked for the WKSSFGEO reports to be checked against ramb, and for anything missing to be
found. A Claude session (AI) did the search, the downloads (each on the maintainer's go), the checks and this
record; no person has checked the counts yet. Nothing went into ramb (the maintainer). The data are under
`$FISHYDATA/raw/external/` and are not tracked. Each folder's `README-provenance.txt` gives every URL, DOI, licence and
checksum, and is the reference for the files.*

## What exists for testing, and where

| where | what | licence | of use for |
|---|---|---|---|
| `raw/external/cnr/anonymized_dataset.rds` | Lattanzi et al. 2026, SoftwareX 34: 102579 (CNR-IRBIM). 5 Italian passive-gear vessels, 846 trips, 30 s, fishing/not fishing labelled by hand. Positions and dates anonymised; features scaled 0-1 | GNU GPL 3 | fishing/not fishing methods; trip cutters on the providers' trips |
| `raw/external/cnr/zenodo_5783920/` | Pulcinella et al. 2022, Sensors 22: 839 (CNR-IRBIM). One vessel's raw tracker log, Ancona, November 2021, 60 s, with power, satellites and geofence events, and its R code | CC BY 4.0 | trips cut by gaps and power-on, with no port list; a tracker silent in port |
| `raw/external/mendo2023/` | Mendo et al. 2023, Ecol. Indicators 154: 110822, supplements. Soak-time R code (two PDFs) and two samples: Peruvian gillnets (3 trips, 3 min) and a Danish gillnetter (4 days, 1 min). The labels are a random forest's | CC BY 4.0 | the set finder (`rb_link_record_sets()`), with a second method to compare |
| `raw/external/ices/` | the two workshop reports. Their AI summary moved the same day to `docs/wkssfgeo.qmd`, and the wish list to `docs/one_flow.qmd` (What exists, and where) | CC BY 4.0 | the wish list |
| `~/stasi/identify_fishing_workflow` | Mendo et al. 2024, ICES JMS 81: 390, the WKSSFGEO sequel: trips, fishing and mooring sites, in R. Cloned at 78b757b | none: read only, never copied | learned ports (plan 031 §4.3) |
| `~/stasi/pipe-anchorages` | Global Fishing Watch: anchorages learned from AIS or VMS, then port visits and voyages. Python, shallow clone at 3065fa2 (v4.6.4) | Apache 2.0 | learned ports, port calls and voyages at scale |

The WKSSFGEO and WKSSFGEO2 data on GitHub were already in ramb (`b93d9fe`, plan 031 §4.8), except iapesca's, which is
left out by the maintainer's choice.

## Not obtainable

- **Five of WKSSFGEO2's ten example sets** (DK_DTU_1897_EM, ES_AZT_2018_AIS, ES_IEO_2021_GRB, IE_MII_2019_IVMS,
  PT_CCM_2021_GP) were never on GitHub. Only the chairs (Rufino, Mendo) can release them.
- **The Gabon HMM data** (Cardiec et al. 2020, PLoS ONE): the paper's Dryad share link returns HTTP 422.
- **Guillot et al. 2017's HMM-VMS code**: the link returns 404, and the Danish data were never shared.
- **Not used, with reasons:** a 5-vessel Italian file in WKSSFGEO2's history (`ITA_SSF_WKSSFGEO2_CNR_Annon.csv`, added
  4292d67, removed f04e3bd) was removed by CNR-IRBIM, so ask them before using it. Lattanzi et al. 2026's gear
  data (figshare 29647448) hold only a 2 KB sample.

## Found against ramb (the reports' wish list)

The reports ask for these, and ramb lacks them:
- trip rules that need no port list: a gap, a coastline, power or ignition, learned ports;
- movement features (turning angle, sinuosity, jerk), learned classifiers, and gear from the track;
- cubic Hermite interpolation, and downsampling for ping-rate tests;
- days at sea and fishing days;
- net length from the hauling distance, static-gear pressure, and counts of hauls and sets;
- spreading hours over cells by track length;
- scoring functions, and anonymising tracks.

The track models (Gaussian mixture, EMbC, HMM) are in fishymodel, not ramb. `rb_create_port_calls(crs_m = 3575)` is still
centred on Iceland (decision 078).

Plan 031 §4.8 left CNR's coastal zones out of ramb as belonging to gear, not voyages. But they decide the CNR
method's joins: 72 trips with the zone and 70 without, on CNR's own tracks (ramb NEWS 2026.10.19). ramb ships
none, so its `cnr` method cannot reproduce CNR's trips from ramb's data alone.
