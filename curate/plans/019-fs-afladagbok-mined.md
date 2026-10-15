# 019 — fs_afladagbok by the grammar: the tables it becomes, the tour app, and what the rest holds

**status:** proposal — prototyped in scratch, nothing in the pipeline changed · **2026-10-15** · **see:** plan 018
(the dump it reads), plan 014 (preprocessing side), `docs/grammar.qmd`, decisions 066, 094

Drafted with AI assistance (Claude) on 2026-10-15, at the maintainer's request: format fs_afladagbok by the grammar,
and find what in it the workflow does not yet use. The choices in §6 are the maintainer's.

**Measured** (read-only, 2026-10-15): `raw/oracle/fs_afladagbok/` (the dump of commit a202f39, 32 tables and views)
against `staging/fs_afladagbok/`, `staging/landing/agf/` and `curated/logbook/`; a prototype of §4 written to scratch
only. **Assumed:** that a tour trip and a `ws_veidiferd` trip of the same vessel and landing day are the same trip
(supported by identical catch, §2 item 1).

## 1. What the adapter reads

`sources/fs_afladagbok/convert.R` reads 8 of the 32 objects (`ws_veidiferd`, `ws_veidi`, `ws_afli` and five gear
tables) and already writes the grammar's four tables. The other 24 are below, with what they hold.

## 2. Findings

1. **The tour app** (`tour`, `fishing_spot`, `catch`, `mammals_birds`: 2020-01 to 2022-03, written by the web logbook
   `AFLADAGBOKWWW`) holds 35,792 trips, 31,785 fishing spots and 57,234 catch rows. These are small boats, 828 of
   them (797 in the vessel registry), mostly on jigs.
   - **It is the same record as the `ws_*` trips of source `STOKKUR`.** 25,971 tour trips have a `ws_veidiferd` trip of
     the same vessel and landing day, and `STOKKUR` holds 25,974 trips. Of the 19,707 such trips with catch in both,
     19,704 hold the same kg and 19,705 the same number of stations.
   - **9,821 tour trips were never imported** (7,518 in 2020, 2,303 in 2021). They hold 8,423 fishing spots and 9.9 kt
     of logged catch. For 8,339 of them the vessel landed within a day (agf), and the product has a logbook trip within a
     day for 1,022. The rest reach the product only as landings.
2. **`STOKKUR` in `ws_veidi` and staging is degraded.** All 23,362 stations have the latitude as a whole degree:
   24,498 of 24,570 matched stations hold `round(lat)` of the tour position, a median 20 km off in latitude alone.
   They have a start time and no end time, so staging has no duration and no effort for any of them. The product keeps
   21,485 of these trips as fs trips. `fishing_spot` has the full decimal position, and the hours (jigs, lines) or
   nights (nets) in the sea, and the jigs, nets or hooks for every spot.
3. **The app has its own port codes.** Only 498 of 40,695 matched pairs share a code. The 71 codes translate through
   the trips in both systems (the most common pairing holds for 97 % of them), and 64 reach a `pid`.
4. **Nothing new in the views.** `logbook_trip_v`, `logbook_station_v`, `logbook_gear_v` and `logbook_catch_v` are
   drawn from `ws_*`: every id is in `ws_veidi` or `ws_veidiferd`, `t2` is `upphaf_timi` throughout, `gear_json` is
   empty, and positions mix degrees with radians. In `target_assemblage_trip_v`, the target is the species with the
   largest catch in 172,426 of 173,357 trips.
5. **`xml_trackwell_vorpun` confirms the afli-first rule.** It links 20,842 fs trips to afli's Trackwell trips, and for
   19,894 of them the product already takes afli's trip of the same day. The fs `TRACKWELL` trips (20,129 in
   2020-2022) have no effort in staging, but 19,204 have an afli trip the same day, so nothing is lost.
6. **Bycatch of mammals and birds is recorded and unused.** `ws_medafli` holds 3,647 records (11,392 animals of 49
   kinds, 2014-2025) and `mammals_birds` 815 records (counts summing to 514,674, not checked for typos). This is
   outside the effort and catch aim, but it is data for protected-species bycatch work.
7. **The change logs carry provenance only.** `ws_veidi_breytingar` and `ws_afli_breytingar` hold earlier versions of
   2,313 stations: the start time changed for 181, the position for 17 and the gear for 1.
8. **`ws_rekjanleiki`** gives each trip a traceability id, updated to 2026-09-09. It is not a landing id: its numbers
   occur among agf's `londun_id` for 193,455 of 207,188 trips, but the vessel agrees for 164 of them and vessel and day
   for none. The two id ranges overlap by chance. What it points to is not known.
9. **Implausible catch rows, with no correction declared.** `STOKKUR` holds 10 rows of 100 t or more (up to
   9,999.999 t on jig boats) and the tour app 15. The curated logbook holds 39 fs rows of 1,000 t or more. A fixed
   threshold does not separate them from pelagic hauls: `Trackwell raun` has 7,587 rows of 100 t or more, which are
   real.
10. **The depth unit depends on the app, not on the gear.** The test: the GEBCO depth of each station's H3 cell, divided
    by the recorded depth converted from fathoms (stations around Iceland, `STOKKUR` left out because its positions are
    whole degrees).
    - **Fathoms:** the Trackwell apps (1.02-1.04, 405,000 stations).
    - **Metres:** Marína (0.56-0.58) and FRA TAKTIKAL (0.59-0.62), about 21,000 stations.
    - **Mixed:** Fontos, Jóhann Gíslason, Reiknistofa fiskmarkaða and Fishtech, about 11,000 stations.
    - **It is water depth, not the gear's:** the ratio is about 1 for every gear, midwater trawl (1.03) and purse seine
      (1.07) included.

    `curate/logbook.R` converts every fs depth as fathoms ("uniformly fathoms"), so about 21,000 stations are 1.83 times
    too deep in the product. These are the same apps the adapter already treats as DDM for coordinates.
11. **Implausible counts of mammals and birds.** The tour app's `mammals_birds` holds 500,000 animals of taxon 508 at
    one spot and 10,000 of taxon 3 at another, against a median of 1 and a 99th percentile of 100. Both lists share one
    code list.
12. **No key links fs, or any logbook schema, to the landings.** fs, adb and the rebuilt `logbook` hold only the
    landing date and port. afli's `londun_faersla` is a flag (`F`/`L`), not an id, and `xml_londun_sending_visir` is
    Trackwell's own transmission id. The link between a trip and a landing stays an inferred match by vessel, date and
    port: a crosswalk, never a shared key (`docs/grammar.qmd`).

## 3. fs_afladagbok in the grammar

The grammar sorts every field by level (trip, station, sample, observation) and by field group. DATRAS's haul header
(HH) is the richest worked example of a station record: one wide row per haul holding every field group, for one gear
class (towed). fs records many gear classes. So the layout follows HH where a measure applies to every gear, and goes
by part and measure where it is gear-specific (`gear_part`, plan 020).

### 3.1 HH's field groups, and what fs records of each

| field group | HH columns | fs_afladagbok | goes to |
|---|---|---|---|
| Identification | Country, Ship, StNo, HaulNo, Year | `ws_veidiferd.id`, `skipnr`; `ws_veidi.id` | `trip` (`.tid`, `vid`); `station` (`.sid`) |
| Sampling intent and design | Survey, DataType, StdSpecRecCode, BySpecRecCode, Stratum | not recorded; the logbook system (`uppruni`) | `trip.source` |
| Temporal envelope | Year to Day, TimeShot, HaulDur, DayNight | `upphafstimi`, `londunardagur`; `upphaf_timi`, `milli_timi`, `lok_timi` | `trip` `T1`/`T2`; `fishing_sample` `t1`-`t4` with basis; `station` `date`, `s1`/`s2` (derived) |
| Spatial envelope | ShootLat/Long, HaulLat/Long, StatRec | start and end positions; `upphafshofn`, `londunarhofn` | `station` `lon1`-`lat2`, `sq`/`ssq`; `trip` `hid1`/`hid2`, `pid1`/`pid2` |
| Outcome and validity | HaulVal, ReasonHaulDisruption | `fj_tapadra_veidarfaera` (gear lost), `breytt` (edited); twins (decision 094) | `fishing_sample` `n_lost`, `edited`; `station` `twin` |
| Pre-deployment configuration | Gear, GearExp, DoorType, DoorWgt, DoorSurface, SweepLngt, Warplngt, Rigging, Tickler, Buoyancy, KiteDim, WgtGroundRope, CodendMesh | `veidarfaeri_id`; the six gear tables; `veidarfaeri_efni` | `fishing_sample.gid`; `gear_part` (plan 020) |
| In-situ measurements | Netopening, DoorSpread, WingSpread | none | — |
| Execution and navigation | Distance, TowDir, GroundSpeed, SpeedWater, Min/MaxTrawlDepth | none (the recorded depth is water depth, §2 item 10) | reconstructed from the AIS trail (basis `reconstructed`), in the flow |
| Environment | Depth, WindDir/Speed, Swell, SurTemp, BotTemp, salinity, currents, tide, Secchi | water depth only (`upphaf_dypi`/`lok_dypi`, the unit by app, §2 item 10); nothing else in 260 columns | `environment` `z1`/`z2` |
| Observation | the HL and CA tables | `ws_afli`, `ws_thang_thari` (seaweed); `ws_medafli` | `catch`; protected-species bycatch (§6) |

### 3.2 The tables fs becomes, measured

**How it was built** (in scratch, 2026-10-15). First, the current adapter was run unchanged on `raw/oracle/fs_afladagbok/`.
It reproduces today's staging exactly (207,189 trips, 469,881 stations, 1,415,346 catch rows, the same types), so for fs
plan 018 phase 3 is a change of path. Its output was then reshaped into the grammar's tables (`docs/grammar.qmd`, as
rewritten 2026-10-15), with the tour app (§4) and `gear_part` (plan 020).

| table | level, field group | rows | key | columns |
|---|---|---|---|---|
| `trip` | 1 | 217,010 | `.tid` | `vid T1 hid1 pid1 T2 hid2 pid2 port n_crew source` |
| `station` | 2, envelope | 478,304 | `.sid` | `.tid date s1 s2 lon1 lat1 lon2 lat2 coord_flag` |
| `fishing_sample` | 3, collapsed onto the station | 478,304 | `.sid` | `gid gid_old gear target target2 t1 t2 t3 t4 w1 w2 duration_m duration_m_raw .duration_source effort_count effort_duration effort_unit effort n_lost edited note` |
| `gear_part` | 3, configuration | 1,470,122 | `.sid`, `part` | plan 020 |
| `environment` | environment | 446,519 | `.sid` | `z1 z2 z1_raw z2_raw z_unit` |
| `catch` | 4 | 1,430,220 | `.sid`, `sid`, `condition` | `catch catch_whole undersized_kg` |
| `protected_bycatch` | 4 | 4,462 | `.sid`, `taxon`, `taxon_list` | `n length_cm sex note` |

Every table also carries `schema`.

**Checks:** every key is unique; every station has its trip and every sample its station; `s1 <= s2` for all 478,304
stations.

**Against today's staging:**
- **Positions:** where two tables hold the same station, the more precise is taken (maintainer). The 25,971 `STOKKUR`
  trips give way to their tour copies, so positions in whole degrees fall from 25,890 to 2,528.
- **Trips and stations:** 9,821 tour-only trips are added, so trips go to 217,010 and stations to 478,304 (+8,423).
- **Effort:** 381,051 stations, against 349,266 today.
- **Catch:** 2,061.3 kt, against 2,051.5 kt (the 9.9 kt of the tour-only trips), without rows of 100 t or more. Rows of
  one species and condition at one spot are summed, as the adapter already does for `ws_afli`.
- **Depth:** water depth, in `environment`, with the unit by app (§2 item 10). 414,507 stations from fathom apps are
  converted; 21,023 from metre apps are kept as recorded; 10,989 from mixed apps keep their raw value with `z1`/`z2`
  empty and `z_unit = "unknown"`.

**Not in fs at all:** in-situ geometry; execution (reconstructed from the track, in the flow); and any environment beyond
depth.

**Left in raw, read when needed:**
- the code lists (`ws_stofn_*`), which are the labels for `gear_part.type`;
- the change logs (`*_breytingar`);
- the traceability ids (`ws_rekjanleiki`);
- the Trackwell crosswalk (`xml_trackwell_vorpun`, linking fs trips to afli's), which is never an identity;
- the derived views (`logbook_*_v`, `target_assemblage_trip_v`);
- `takt_json_form` (not dumped);
- personal data: the vessel's phone (`skip_farsimi`) and the operator's id (`utgerd_kt`).

**The dictionary** (`reference/dictionary.R`) gets a level and a field group for every fs column it maps. Today `level`
is empty for all 38 fs entries, so `docs/grammar.qmd`'s mapping table shows afli only.

## 4. Proposal: the tour app as the record of its trips

In `sources/fs_afladagbok/convert.R` (preprocessing side), after plan 018 phase 3 has pointed it at
`raw/oracle/fs_afladagbok/`:

- **trip:** `.tid = -tour.id`, so tour ids never meet `ws_veidiferd`'s in one schema. `vid = ship_id`,
  `T1 = start_date`, `T2 = landing_date`, `hid2`/`pid2` through the port translation, `source = "tour"`.
- **station:** `.sid = -fishing_spot.id`. `lon1`/`lat1` as recorded (decimal degrees), `date` from `date_time`, and
  `z1` from `depth`, which is empty in these data.
- **fishing_sample:** `gid = equipment_id`, which is `ws_veidi`'s code list and resolves in `reference/gear`.
  `t1 = date_time`, the same minute as `ws_veidi`'s `upphaf_timi`. `duration_m` comes from the hours or nights in the
  sea (basis `recorded`), and `t4 = t1 + duration` (derived). `effort_count` is the jigs, nets or hooks, in the
  adapter's units (`jig-hours`, `net-days`, `hook-days`).
- **catch:** `sid = species_id` (53 of 54 codes are `ws_afli`'s), `catch = estimated_weight` (kg), `condition`
  `RELE`/`GUTT`/`UNGU` from the two flags, and `undersized` kept.
- **The `STOKKUR` copies** of the 25,971 tour trips are left out of `ws_*`'s output: they hold the same catch with
  worse positions and no effort.

**Measured in the prototype:**
- 35,792 trips, 35,720 of them with a landing port `pid`;
- 31,785 stations, all with a decimal position, a duration and effort (25,498 jig, 3,975 net, 2,312 line);
- 31.5 kt of catch, without the 15 implausible rows (flagged, not dropped);
- in the product, 9,821 more trips, 8,423 more stations and 9.9 kt more logged catch;
- 23,362 `STOKKUR` stations that go from whole-degree positions and no effort to recorded positions and effort.

The staging tables keep their shape, so no reader changes.

## 5. Not done here

- The adapter itself (it waits for plan 018 phase 3).
- A rebuild.
- A correction for implausible catch (§2 item 9; it belongs in `curate/corrections/`).
- Bycatch of mammals and birds in the product.
- Moving the readers of `station.z1`/`z2` to `environment`.
- A correction for the depth unit by app (§6).

## 6. Asks

1. **The tour app** replaces the `STOKKUR` copies (proposed), or only adds positions and effort to them?
2. **The port translation**, derived from the trips in both systems: a reference built each run, or a reviewed
   override in `overrides/`?
3. **Implausible catch:** by what rule? Per gear, per vessel size, or against the trip's landing?
4. **Bycatch of mammals and birds** (§2 item 6): wanted as a table in the product?
5. **`rekjanleiki_id`:** what does it point to?
6. **The depth unit by app** (§2 item 10). Proposed: a declared correction, `curate/corrections/fs_depth_units`. It
   converts the Trackwell apps from fathoms, keeps Marína and Taktikal as recorded, and classifies the mixed apps' stations
   against GEBCO, as `afli_depth_units` does. The alternative is by app only, leaving the mixed apps unconverted.
7. **`protected_bycatch`:** the name, and whether it holds counts only (`ws_medafli` also has length and sex for
   whales)?
