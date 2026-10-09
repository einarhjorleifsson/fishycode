# 078 — Outside code mined for ramb: iapesca, WKSSFGEO, WKSSFGEO2

*2026-10-09. Read, benchmarked and measured by Claude (AI-assisted) at the maintainer's request; nothing was built, and nothing
was written into ramb. The scripts ran in a session scratchpad and were not kept. The numbers below come from those runs.*

Three outside sources were read for what ramb could use:
- **iapesca:** Ifremer, `~/R/Pakkar/r-packages_iapesca`, 2022.
- **WKSSFGEO:** ICES 2021, `~/stasi/WKSSFGEO`, branches main, dev_branch and pkg.
- **WKSSFGEO2:** ICES 2023, `~/stasi/WKSSFGEO2`.

All three are GPL or MIT. Anything taken is rewritten in ramb with attribution, never copied (AGENTS.md).
**ramb is judged as the generic WGSFD flow for any fleet, not by what the Icelandic data need** (maintainer, 2026-10-09).

## For the step being built

Read the row before building that step.

| Step | What to pick up | Where it is |
|---|---|---|
| 0 | Fast vessels (TODO 38) — **measured.** A run of 3+ consecutive legs over 25 kn whose two-ping legs are also fast is real running. In June 2023 (3,295,103 pings) these runs held 1,115 of `rb_flag_ping_impossible("clean")`'s 8,942 flags, and recorded SOG was over 20 kn on 90–98 % of them. The rule needs a speed cap: the 99th percentile was 67 kn and the maximum 406 kn. | idea from iapesca's `CleanSpuriousSpeeds` |
| 1 | **Stays at landing sites not on the port list**, and trackers that stop transmitting in port. ramb's stays need a known port. Three rules: a gap of 2 h or more ends a trip (Irish); a gap with one end inside a coastal band ends a trip at the nearest port (Italian); a coastline buffer when there is no port list (iapesca). | WKSSFGEO `R-dev/Gmartin`, dev_branch `R-dev/galdelli_pulcinella_tassetti/R/global_functions.R` (`create_fishing_trip`, `closest_port_recovery`), iapesca `Detect_FishingTrips` |
| 1 | **ramb's default `crs_m = 3575` in `rb_find_trip_stays()` — measured.** A 2,000 m port buffer comes out as 1,941–2,047 m at 64° N, 1,771–2,259 m at 35° N, 1,586–2,532 m at 15° N and 1,003–4,003 m at 30° S. A projection centred on each port (azimuthal equidistant) gives the exact radius anywhere. | iapesca `CustomizedProjectedCRS` (a local projection per track) |
| 3 | **Gear from the track when no logbook names it:** smoothed speed (Savitzky–Golay), k-means with speed centres per gear, rules, DBSCAN, then a random forest for each vessel's gear per month. The method is generic. The centres and the model file are Adriatic-trained, so ramb would need a way to train on a user's labelled data. The classes are Mediterranean towed gears plus "other". | WKSSFGEO dev_branch `R-dev/galdelli_pulcinella_tassetti` |
| 4 | **Labelled passive-gear data (MIT)**, the ground truth for the `"gmm"`, `"embc"` and `"hmm"` methods and for set↔haul pairing. Pots, 1 vessel at 60 s: 426 setting, 1,607 hauling, 1,675 not fishing. Pots and dredges, 5 vessels: set 264, hauling 632, tow 3,438. | WKSSFGEO2 `data_examples/IT_CNR_2023_GP.csv`; WKSSFGEO `data-examples/example_data_GPS.csv` |
| 4 | **The HMM in practice** (Irish Marine Institute): fit per ping-rate class after resampling; drop trips with irregular pings (sd(dt)/rate > 1) and with 50 pings or fewer; handle zero steps; take starting values from a mixture model fitted by EM; refit with 2 states when only 2 are decoded. From reading the code, the sigmas are not reordered with the sorted means, and the 2-state fallback `c(0.01,0.2,)` errors. | WKSSFGEO dev_branch `R-dev/Gmartin/FPO classification program`, WKSSFGEO2 `R/MI_HMMmodels.R` |
| 4 | **Set↔haul pairing.** Build the net line from the haul pings. Then find the earlier pass over that line, within 330–550 m, in the same trip or up to 2 trips back and within 240 h. The result is the set time and the soak. This bears on plan 004 and the passive-gear under-cover in `logger_runs_past_the_station`. | iapesca `Create_Nets`, `Retrieve_SettingOperations` |
| 4 | **Movement features** for classification: heading, turning angle, jerk, sinuosity, and lagged copies of each value. | iapesca `CalcFeatures` |
| 5 | **Static-gear effort** is net length × soak time. **Track-length apportioning** splits a track's hours across cells by the length of track inside each cell, not by ping counts. | WKSSFGEO2 `EffortMethodComparison_IFR_iapesca_Dataset.Rmd`; Italian `estimate_fishing_effort` |
| — | **Interpolation:** a cubic Hermite spline that uses course and speed (vmstools, Hintzen 2010). It passes through both fixes, so it has no closing error, unlike the dead reckoning plan 004 §7 sets aside. ramb has linear interpolation only. | WKSSFGEO `R/interpolate_ais.R` |
| — | **Anonymising tracks for sharing** (WGSFD's work on shared training data): vessel to code, one time shift for the dataset, a per-vessel longitude shift (exact distances; latitude stays visible), and the WGSFD labelled-data schema. | WKSSFGEO `code_example/220928_…AnomyzingGeolocationInformation.html` |

## Measured and settled: the speed filter

iapesca's `CleanSpuriousSpeeds` and `rb_flag_ping_impossible("clean")` both run on one core. iapesca is 55–60× slower: about 26 s against 0.5 s per million pings. On June 2023 it leaves 17 legs over 35 kn in 16 vessels; ramb leaves none. It also returned 9 NA rows and stopped on 10 vessels. Nothing to take for step 0 beyond the fast-run idea above.

## Not taken

- the Italian 4-ping trip state machine, which the stays supersede;
- the Adriatic model file;
- the WKSSFGEO pkg branch's `Calc*` and `tune_RF`, which are iapesca's ancestors;
- the maintainer's own `rb_` drafts, already plan 013's spec for the gmm, embc and hmm methods.
