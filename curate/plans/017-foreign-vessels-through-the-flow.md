# 017 — Foreign vessels through the flow, the Faroese first

**status:** proposal — nothing built; steps 1-3 moved to plan 021 (2026-10-16), asks e-g open (e and f in TODO 65, g in TODO 62) · **2026-10-14** · **see:** TODO 62 and 65 (22 folded into 65, 63 closed); plans 008 (§7 Phase 7, Phase 9), 013,
015, 016; decisions 039–043, 067, 075, 102

Drafted with AI assistance (Claude) on 2026-10-14, at the maintainer's request, from read-only queries of the code and
the data. Nothing was written under `$FISHYDATA`. The choices in §6 are the maintainer's to make.

**Measured** (read-only, 2026-10-14, on the tables as built *before* plan 016's rebuild): the foreign rows of the
registry, the key and the candidates (§2.1); STK, ASTD, astdB and EMODnet around Iceland and the Faroes (§2.2–2.4);
the foreign fixes, stays, voyages and catch in the curated flow (§3); foreign landings in Iceland (§4).
**Method:** each AIS table was read once (ASTD, astdB, and the raw STK trail with each ping's vid from the frozen key,
time-aware as in `ais_ping_union.R`). The pings in a box 35 °W–0°, 58–71 °N were counted by year, MMSI (STK: mobile-id
and vid) and 0.1° cell, and each cell centre was placed in an ICES area (`staging/aux_valid/ices_areas.gpkg`; cells on
land in Iceland or the Faroes count to 5.a or 5.b). Hours are ASTD's `sec_nextpoint`, capped at 1 h. A *slow* fix is
one at 1–5 kn (ASTD: distance over time), a rough stand-in for fishing used only to compare flags. *Fishing category*
is ASTD's `astd_cat`, which the maintainer finds unreliable (plan 008 §6): it ranks here, it never selects. A flag
is the MMSI's MID (231 is the Faroes) or `vessel.parquet`'s `flag` (from the `uid` prefix of a foreign vid).
**Assumed:** that ICES 5.a stands for Icelandic waters (there is no EEZ polygon on disk, and the EEZ reaches into 14.b
and 2.a); that an MMSI with MID 231 is a Faroese vessel; that STK's coverage of 5.b from 2019 is a feed from the
Faroes (inferred from the jump in §2.2, not documented).

## 1. In short

- **Most foreign fishing around Iceland is Faroese.** In 5.a in 2013–2025, foreign MMSIs in ASTD's fishing category
  have 159 k slow hours, and 116 k of them are Faroese. Icelandic MMSIs have 4.16 M slow hours there. Foreign slow
  hours are about 4 % of the Icelandic ones, and Faroese about 3 %.
- **The flow already carries the foreign vessels STK knows by an Icelandic foreign vid.** 364 mobile-ids (6.39 M
  pings, 78 of them Faroese with 4.05 M) go through the union, the stays, the voyages, the landing gear and the catch.
  In 2019–2025, 68–83 % of the foreign landed weight in Iceland already sits on fixes.
- **What is missing:**
  1. **Unkeyed mobile-ids.** STK holds 1,083 `fro` candidates (9.44 M pings) with no vid. 96 % of their pings are in
     5.b, in Faroese home waters; 88 of them reach 5.a, with 0.30 M pings.
  2. **ASTD.** The union keeps MID 251 only, and no foreign vid has an MMSI (0 of 1,288), so ASTD could not reach one
     even without that filter. For the Faroese vids STK already keys, ASTD adds about 1 %. The real gain is 52
     Faroese fishing-category MMSIs that no keyed vid covers: 83 k hours in 5.a, 35 k of them slow, in 2013–2025.
  3. **Ports outside Iceland and the Faroes.** The port radius holds only Icelandic and Faroese ports. Non-Faroese
     foreign voyages are longer than 60 days in 10 % of cases (Icelandic: 0.2 %).
  4. **Gear.** A foreign voyage gets gear only from a landing in Iceland. 4.05 M of the 6.32 M foreign fixes have
     none, so they are never fishing.
  5. **kW.** No foreign vid has one, so every foreign fix has `kw_hours` NA.
  6. **Catch landed abroad.** There is no source for it (TODO 62).

## 2. Where foreign vessels appear

### 2.1 The registry, the key and the candidates

- **`curated/vessel/vessel.parquet`:**
  - 1,288 foreign vids (3701–4999). By flag: NOR 376, RUS 250, FRO 215, GRL 72, UNK 71, GBR 36, DNK 36, DEU 35,
    then 27 more flags.
  - None has an MMSI or a kW; 992 have a length.
  - 47 call signs are on two or more foreign vids.
  - Oracle `vessel_v` (latest row per vessel) has 1,290 with status `Erlent`, the rule of plan 016 §7 c.
- **`staging/fro/vessel.parquet`** (the Faroese register, scraped 2024-02-19):
  - 3,813 vessels: 1,433 with a MID-231 MMSI, 2,451 with a call sign, 331 with an IMO, 3,445 with kW;
  - type: 3,007 have none, 399 Fiskiskip, 202 Handilsskip;
  - 32 call signs are on two vessels (decision 041's chains).
- **The frozen key** (`vessel_ais_key.parquet`), the 364 mobile-ids on a foreign vid:
  - 343 come from `segment: foreign: kept override` (`overrides/stk_foreign_mid_vid.csv`), 8 from `landings`,
    13 from `continuity`;
  - by flag: FRO 78 (4.05 M pings), NOR 151 (0.94 M), GRL 31 (0.62 M), UNK 24, RUS 41.
- **`curated/check/ais_key_foreign_candidates.parquet`** (plan 008, not read by the flow), mobile-ids with no vid:

  | source | mobile-ids | pings | needs review |
  |---|---|---|---|
  | fro | 1,083 | 9.44 M | 0 (all tier B) |
  | marinetraffic | 910 | 8.66 M | 0 |
  | eu | 221 | 0.40 M | 3 |
  | astd | 4,200 | 0.40 M | all |
  | isl_pleasure_craft | 94 | 0.19 M | 0 (SKB, plan 016) |
  | nor, astdb, gfw | 84, 659, 317 | 0.31 M | astdb all |

### 2.2 STK (the raw trail, 290 M pings)

| class (from the frozen key) | mobile-ids | pings | in 5.a | in 5.b |
|---|---|---|---|---|
| Icelandic vid | | 175.4 M | | |
| foreign vid, FRO | 78 | 4.05 M | 1.67 M | 1.97 M |
| foreign vid, other flags | 286 | 2.34 M | 1.38 M | 0.36 M |
| `fro` candidate | 1,083 | 9.44 M | 0.30 M | 9.07 M |
| `marinetraffic` candidate | 910 | 8.66 M | 5.74 M | 2.24 M |
| no vid, entity class vessel | 5,028 | 3.62 M | 2.10 M | 1.04 M |

- **STK sees 5.b from 2019.** Pings in 5.b without an Icelandic vid were 1–16 k a year in 2007–2018, then 0.9 M in
  2019 and 2.1–3.1 M a year since.
- **The unkeyed vessel mobile-ids in 5.a,** by the flag their call sign suggests (`staging/aux/callsign_prefix.parquet`,
  longest prefix): NOR 1.87 M pings, DNK (Faroese call signs included) 1.41 M, NLD 0.89 M, GBR 0.68 M, SWE 0.49 M,
  then flags of convenience. Most are merchant ships (the `marinetraffic` class), with at most 0.21 M slow pings per
  flag.
- **The Faroese in 5.a by year:**
  - the 22–30 keyed vids have 74–114 k pings a year in 2010–2025, 32–58 k of them slow;
  - the `fro` candidates have 0–3 k a year until 2019, then 14–68 k a year from 2020, at most 5 k of them slow.
- **The `marinetraffic` candidates in 5.a** are mostly cargo, passenger, sailing and pleasure craft, by the sheets'
  own `class`. About 112 mobile-ids are marked fishing or trawler, with 0.51 M of the 5.74 M pings.

### 2.3 ASTD (480 M pings in the box, 386 M in 5.a, 340 M of those Icelandic)

5.a, 2013–2025, MMSIs other than MID 251:

| flag (MID) | MMSIs | hours | fishing-category MMSIs | their hours | their slow hours |
|---|---|---|---|---|---|
| GRL (331) | 225 | 301 k | 69 | 297 k | 11 k |
| FRO (231) | 367 | 523 k | 85 | 240 k | 116 k |
| NOR (257–259) | 1,190 | 916 k | 196 | 163 k | 25 k |
| RUS (273) | 126 | 69 k | 64 | 64 k | 1 k |
| DNK (219, 220) | 190 | 188 k | 6 | 8 k | 0 |
| other valid MIDs | 12,987 | 1,768 k | 229 | 201 k | 5 k |
| invalid MMSI | 2,762 | 334 k | 8 | 0 | 0 |
| **all foreign** | **17,847** | **4,099 k** | **657** | **973 k** | **159 k** |

- **Faroese in 5.a by year:** 43–102 MMSIs, and 37–56 k hours a year since 2015, 9–12 k of them slow. In 5.b,
  125–421 MMSIs and 0.42–0.89 M hours a year.
- **Of the 77 Faroese MMSIs with more than 1,000 hours in 5.a,** the hours total 504 k of the 523 k.
- **How the 367 Faroese MMSIs in 5.a could find an identity:** the MMSI is matched to the Faroese register, then
  its call sign to `vessel.parquet`'s foreign vids. Snapshot match, not time-aware.

  | fishing category | path | MMSIs | hours | slow hours |
  |---|---|---|---|---|
  | yes | a foreign vid, keyed in STK | 33 | 157 k | 81 k |
  | yes | a foreign vid, not keyed (the call sign is on 2+ vids) | 8 | 12 k | 5 k |
  | yes | the Faroese register only | 20 | 21 k | 7 k |
  | yes | none | 24 | 50 k | 23 k |
  | no | a foreign vid, keyed | 5 | 10 k | 2 k |
  | no | the Faroese register only (container, cargo, ro-ro) | 49 | 237 k | 6 k |
  | no | none | 228 | 36 k | 1 k |

- **ASTD adds little where STK already keys the vessel.** The 38 keyed Faroese vids that an MMSI reaches have 167 k
  ASTD hours in 5.a. Only 1.7 k of those fall in a year and cell where STK has no ping of the vid (3 of 244
  vid-years).

### 2.4 astdB and EMODnet

- **astdB:** 13.1 M pings in the box, 10.9 M of them Icelandic. MID 231 has 0.6 k pings in 5.a (11 MMSIs) and 62 k in
  5.b. Too small to matter for 5.a.
- **EMODnet 2017:** an Iceland extract, 19.6 M rows, with no MID-231 ping and 10,640 rows not on MID 251.

## 3. Where they fall out of the flow today

| step | where | what happens to a foreign vessel |
|---|---|---|
| key (`once`, frozen) | `ais_key_segments.R`, `overrides/stk_foreign_mid_vid.csv` | A foreign vid enters only through the kept override, plus 21 by landings or continuity. The candidates (§2.1) and `ais_key_all.parquet` are read by nothing in the flow: plan 008 Phase 7 was never wired. |
| union, STK | `curate/ais_ping_union.R:77`, `sources/stk/convert.R:31` | An inner join to key rows with a vid. An unkeyed mobile-id is dropped. |
| union, MMSI identity | `curate/ais_ping_union.R:51-63` | `idy` holds `vessel_identity`'s MMSI periods. Foreign vids have none. |
| union, ASTD | `curate/ais_ping_union.R:94` | Only 9-digit MMSIs starting 251 are kept. |
| union, astdB | `curate/ais_ping_union.R:128` | Only `cc_iso3 == "ISL"` is kept. |
| clean | `curate/ais_ping_clean.R:83` | A ping with no vid is outside the flow (decision 067). |
| stays | the port radius (`once`, frozen; decision 075) | 157 ports: IS 129, FO 28. Foreign stays: 10,319 at FO ports (161 vids) and 8,555 at IS ports (280 vids), none elsewhere. |
| voyages | `curate/ais_voyage.R` | Generic, per vid. Faroese: 8,593 voyages, median 4.1 days, 5.0 % longer than 60 days, 5.3 % with no start port. Other foreign: 8,678 voyages, 10.0 % and 18.9 %. Icelandic: 0.2 % and 0.2 %. |
| voyage gear | `curate/voyage_gear.R` | The `landing` path works for a landing in Iceland. Of 6.32 M foreign fixes, 2.01 M have landing gear (0.82 M fishing by speed) and 4.05 M have none. |
| logbook | TODO 62 | `curated/logbook/trip.parquet` has 35 trips on vids 3699–4999 (afli 34 in 1999–2018, fs_afladagbok 1 in 2022). TODO 62 says 6; its definition was not re-derived. |
| effort | `R/trail_sql.R` | No foreign vid has kW, so `kw_hours` is NA on every foreign fix. |
| catch | `curate/ais_catch.R` | Landings in Iceland are shared (§4). Catch landed abroad has no source. |

**Two more findings:**
- **`raw/logbooks/afli/steini.parquet` is a foreign logbook that TODO 62 does not mention.** No script reads it. It
  holds 74,425 tows from the oceanic redfish fishery in 1989–2017: pelagic trawls (Gloria and others), median
  position about 61 °N 28–33 °W. They come from six nation codes (`thjod`), and 11,575 rows are on foreign vids. It is
  not the Icelandic-waters logbook TODO 62 asks for, but it is a partial one.
- **Code that tests a vid range** (plan 016 §5 lists some of these):
  - `reference/vessels/ais_key_cascade.R:195,202,542`;
  - the `once` checks `ais_key_registry.R:100,159`, `ais_key_landings.R:57,71,87`, `ais_key_reused_callsign.R:70`,
    `ais_key_split_candidates.R:28`, `ais_key_segments.R:340` and `ais_key_vessel_recall.R:40`;
  - `R/audit_split_reader.R:90`;
  - `docs/landings-match.qmd`.

  No main-flow script tests the range. Two checks select `flag == "ISL"`: `gear_logbook_vs_landing.R:79` and
  `gear_speed_by_vessel.R:29`.

## 4. What landings say

- **Foreign landings in Iceland** (`curated/landing`, flag from `vessel.parquet`):
  - by year: 36–313 kt, on 52–134 vessels;
  - Faroese: 6–132 kt on 5–31 vessels.

  | year | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
  |---|---|---|---|---|---|---|---|
  | foreign, kt | 137 | 147 | 186 | 313 | 290 | 249 | 193 |
  | of which FRO, kt | 54 | 112 | 75 | 117 | 132 | 106 | 73 |
  | all landings, kt | 1,201 | 1,184 | 1,361 | 1,749 | 1,688 | 1,263 | 1,249 |

- **By flag, 2007–2025:**
  - FRO 1,044 kt (78 vessels);
  - NOR 821 kt (176), GRL 651 (38), UNK 193 (34), DEU 106 (10), GRC 97 (2), RUS 81 (33);
  - 18 vids with no `vessel.parquet` row land 11 kt.
- **By species, 2007–2025** (Faroese in brackets):
  - capelin (31) 1,033 kt (196), blue whiting (34) 662 (374), herring (30) 432 (368);
  - cod 268 (27), shrimp (41) 260 (22), mackerel (36) 177 (9);
  - Greenland halibut (22) 118, oceanic redfish (11) 116.
  - The Faroese demersal landings in Iceland are small: cod 2.1–2.4 kt and haddock 1.1–2.0 kt a year in 2019–2025.
- **By gear, 2019–2025:** pelagic trawl 842 kt, purse seine 307, bottom trawl 197, shrimp trawl 101, longline 67.
- **Keyed or not, 2019–2025:** foreign vids that have a key row land 1,307 of 1,516 kt. For the Faroese it is 585 of
  671 kt (38 of 46 vessels).
- **On fixes:** under `fishing_flow`, 68–83 % of the foreign landed weight is on fixes each year in 2019–2025
  (`catch_basis` derived). The rest is kept with basis `none`: kg in = kg out.
- **What landings cannot say:** how much Faroese catch is taken in 5.a and landed in the Faroes. That needs the
  foreign logbooks (TODO 62). A landing in Iceland also says nothing about where the catch was taken. The trail puts
  it on the vessel's fishing fixes of the linked voyage, which may lie outside 5.a.

## 5. Proposal

Run plan 016's rebuild first, without waiting for this plan. Steps 1–3 touch the same scripts (`registry.R`,
`identity.R`, the key), so this plan builds on 016's output; a second main rebuild follows.

1. **MMSI periods for foreign vids** (preprocessing).
   - `identity.R` (rewritten by plan 016 step 4) gains a second input. A foreign vid's MMSI comes from the Faroese
     register, matched by call sign. The match is time-aware: the vid's call-sign periods
     (`vessel_sign.parquet`, if it covers `Erlent` vessels, not yet checked) against `vessel_identity_foreign`'s
     periods, with `match_time_aware(id_col = "external_id")` in `R/vid_match.R`.
   - `basis` derived. One holder per MMSI at a time is asserted, as for Icelandic MMSIs.
   - Measured reach: 48 of the 78 keyed Faroese vids, and 41 of the 85 Faroese fishing-category MMSIs in 5.a. Eight
     of these go through a call sign held by two or more vids, which the time-aware match must split or leave out.
   - Norway's register has no MMSI. Other flags would go through EU (MMSI on about 8 % of rows), GFW and ASTD itself
     (plan 008 §5).
2. **A vid for a foreign vessel that has none** (`once` project, frozen, redone only by decision).
   - A crosswalk table (vid, source, external_id, t1, t2, basis) with **vid = 200000 + n**, as SKB has 100000 + n
     (plan 016 §5).
   - Its rows enter `vessel.parquet` with a `register` of their own (`fro`), the flag, and length and kW from the
     register.
   - A foreign vessel that already has an Icelandic foreign vid keeps that vid, because its landings use it.
   - This replaces TODO 22's `external_id`-keyed ping: the flow stays keyed on an integer vid. The SKB decision
     rejected a character key for the same reason: it touches every join.
3. **The key** (`once`, by decision).
   - The 1,083 `fro` candidates (all tier B, none flagged) get a vid through step 1 when an existing foreign vid holds
     the same call sign at the time, and through step 2 otherwise.
   - The `marinetraffic` candidates (5.74 M pings in 5.a, mostly merchant and pleasure craft, §2.2) follow only if
     §6 a says all vessels. Their about 112 fishing vessels could come in with the Faroese.
4. **The union: identity decides, not the MID.**
   - Drop `str_sub(mmsi, 1, 3) == "251"` (`:94`) and `cc_iso3 == "ISL"` (`:128`). The time-aware join to `idy`
     already keeps exactly the MMSIs that have a vessel, whatever their flag.
   - Time the union before and after. ASTD partitions are read whole either way, so the join grows by the foreign
     MMSIs of each year.
5. **Ports** (`once`, a frozen fix redone by decision).
   - Add the ports that foreign vessels use to the port radius. Take them from `ports_all` (24,653 harbours), chosen
     where foreign tracks stop.
   - The need is measured: non-Faroese foreign voyages have no start port in 19 % of cases.
6. **Gear for a foreign voyage with no landing in Iceland:** see §6 e.
7. **kW for foreign vids.**
   - Into `vessel_year` (plan 016 step 5) from the Faroese register (kW for 3,445 of 3,813 vessels) and the EU and
     Norwegian registers.
   - `kw_basis` says which register.
8. **Catch.**
   - No change for landings in Iceland.
   - Foreign logbooks for Icelandic waters stay TODO 62.
   - `afli.steini` could be staged as a partial foreign logbook (§6 g).
9. **What the analyst sees.**
   - No new trail column: `vessel.parquet`'s `flag` and `register` select foreign vessels.
   - If §6 b keeps whole tracks, the area a fix is in needs a column or a polygon join documented in `docs/`.
   - `check_vessel_activity` and the datacall (plan 015) select on `flag`.
10. **Code.** The vid-range tests in §3 move to the flag, as plan 016 §7 c already says ("as they are touched").
11. **Record and rebuild:** a decision record, the `once` redo (key, ports), and one main rebuild.

## 6. Asks of the maintainer

a. **Which vessels?**
   - Faroese first, or every foreign vessel?
   - Fishing vessels only, by register type, or all? MMSIs outside ASTD's fishing category hold 3.1 M of the 4.1 M
     foreign hours in 5.a.
   - Recommended: Faroese fishing vessels first, with code that does not depend on the flag.
b. **Which waters?**
   - The whole track of a foreign vessel, Faroese home waters included? A voyage needs its home port: 96 % of the
     `fro` candidates' pings are in 5.b.
   - Or only Icelandic waters, and then by which polygon: ICES 5.a, or the EEZ, which is not on disk?
c. **A vid for foreign vessels with none:** 200000 + n from a frozen crosswalk? And is an Icelandic foreign vid
   (3700–4999) a hull? 47 call signs are on two or more of them.
d. **ASTD:** lift the MID-251 filter so that identity decides? Recommended.
e. **Gear where a foreign voyage has no landing in Iceland.** Options:
   - none, as now: the fixes are never fishing;
   - the vessel's landing gear of the same year, with a basis that says so;
   - register gear: EU `gear_main` (the Faroese register has no gear).
f. **Ports:** extend the frozen port radius to foreign ports (a `once` redo)?
g. **TODO 62:**
   - Where are the foreign logbooks for Icelandic waters? Decision 126: `dw.dw_aflaskeyti` holds haul-level records
     of Norwegian and Faroese vessels for 2014-2018; whether to take them in is TODO 62's ask, and 2019-2025 is open.
   - Should `afli.steini` (oceanic redfish, 1989–2017, six nations) be staged as a partial foreign logbook?
h. **Order:** plan 016's rebuild first and this plan after it (two rebuilds, recommended), or wait and do one?

**Settled by plan 021 §6, 2026-10-16 (the maintainer):** plan 021 takes over steps 1-3 (MMSI periods, vids, the key)
for every flag, and this plan keeps the flow side for non-Icelandic hulls: ports, gear, kW, catch. Plan 021's answer
(a), as revised on 2026-10-17, answers asks a (foreign fishing vessels of every flag, by register evidence or a
landing in Iceland), b (whole voyages that enter ICES subareas 1, 2, 5, 12 and 14 and NAFO subarea 1) and d (the MID-251
filter is lifted; identity decides). Ask h is moot: plan 016's rebuild ran on 2026-10-16 (decision 112). Ask
c's first half is plan 021's (b), 200000 + n; whether an Icelandic foreign vid (3700-4999) is a hull, with 47 call
signs on two or more of them, goes to plan 021's crosswalk. Asks e (gear), f (ports, now over that area and the home ports of the vessels fishing in it) and g
(foreign logbooks, TODO 62) stay open here.

## 7. Checks (done when)

- Every Faroese MMSI seen in ASTD in 5.a either has a vid or is listed with the reason it has none.
- TODO 22's check, restated on vid: a ping of a foreign vessel with no Icelandic vid survives into
  `curated/ais/voyage.parquet` with a voyage key and `pid1`/`pid2` resolved.
- For foreign voyages, the share longer than 60 days and the share with no port are close to the Icelandic shares,
  or each difference is explained.
- Foreign fixes have `kw_hours` with a `kw_basis` naming the register.
- The share of foreign landed weight on fixes is reported per year (68–83 % before this plan).
- No script in the main project selects foreign vessels by a vid range.
