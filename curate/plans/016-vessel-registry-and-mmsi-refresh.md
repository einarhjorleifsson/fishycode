# 016 — Refreshing the vessel registry and the MMSI archive, and SKB pleasure craft through the AIS flow

**status:** partly built — steps 1–6b written and tested 2026-10-14 (ASTD +849k pings, no vessel loses any); the rebuild (step 8) not run · **2026-10-14** · **see:** TODO 17, 23, 24, 63; decisions 015, 038, 041, 047, 067;
plans 003, 008, 009

Drafted with AI assistance (Claude) on 2026-10-14, at the maintainer's request, from read-only checks of the code
and the data. The choices in §7 are the maintainer's to make.

**Measured** (read-only, 2026-10-14): the files and their differences (§1–§3), the ASTD pings on each MMSI (`staging/ais/astd`, to
2026-01-31), the SKB codes in the lists and in STK (§5), and the pleasure craft in the trail (§6).
**Assumed:** that a Fjarskiptastofa list is the official allocation on its date, and that a pair present in two lists was
held in between. Also that the Oracle snapshots behind the archive's sources 1–4 can still be dumped (§4 step 1).

Two rules from the maintainer (2026-10-14) shape the proposal:
- a **vid is an integer**;
- **it identifies a hull for life, like an IMO number**, except the foreign vids 3700–4999.

## 1. What arrived, and what reads it

- `raw/mmsi/Númer - Skip - MMSI númeraröð090326.xlsx` is byte-identical to `mmsi-iceland_fjarskiptastofa_2026-03-09.xlsx`,
  which has been in `raw/mmsi/` since 2026-09-20. It adds nothing.
- `raw/vessels/` was dumped from Oracle again on 2026-10-14 (21:31). The 2026-04-25 set is kept, checksums verified, at
  `$FISHYDATA/archive/raw-vessels_2026-04-25/` (32 files).
- Readers:
  - `reference/vessels/registry.R` reads `vessel_v` and the MMSI archive, and is the `vessel` target.
  - `reference/vessels/ais_key_foreign.R` reads the archive; it is not a target.
  - `curate/checks/ais_key_segments.R` reads `vessel_hist_v`, in the `once` project.
- **Not tracked:** the `vessel` target depends on no raw file, so neither change shows in `tar_outdated()`.
- **Downstream of `vessel`:**
  - 17 main targets: `vessel_identity`, `ais_ping_union`, `ais_ping_tag`, `ais_ping_clean`, `port_stay`, `ais_voyage`,
    `voyage_gear`, `trip_voyage`, `station_event`, `ais_trail`, `ais_catch`, and six checks;
  - in `once`, through `main_vessel`/`main_vessel_identity`: the key cascade, ten checks and `vessel_ais_key`. These are
    frozen and redone only by decision.

## 2. The MMSI archive is not the lists

| file | what it is | read by |
|---|---|---|
| `raw/vessels/mmsi_iceland_archieves.parquet` (same md5 as `raw/mmsi/mmsi_iceland_2025-MM-DD.parquet`) | the archive in use, 3,999 rows | `registry.R`, `ais_key_foreign.R` |
| `raw/mmsi/mmsi_iceland_2026-03-25.parquet` | `mmsi.R`'s merge of the 2026-03-09 list into it, 4,078 rows: +79 (39 vessels, 37 navigational aids, 1 coast station, 2 child vessels) | nothing |
| four Fjarskiptastofa lists: 2024-08-21 (3,811 rows), 2024-11-07 (3,833), 2025-04-10 (3,862), 2026-03-09 (3,926) | the official allocation on each date | `mmsi.R` reads the latest only |
| `raw/vessels/vessel_mmsi.parquet` | Oracle's own MMSI table: 3,462 rows of vid, call sign, MMSI, type (`VES`/`BUO`/`COM`), note; unchanged April → October | nothing |

**How the archive was built:** by `fishydata_2024-2026/scripts/older/00_DATASET_ISL-mmsi_historical-consolidation_TOBEDELETED.R`.
- Sources 1–3 are Oracle snapshots (`ops$einarhj.vessel_mmsi_20190627`, `_20201215`, `_20220405`), and source 4 is
  `omar::mmsi_icelandic_registry`. Together they are 73 vessel rows and 55 navigational-aid rows, none of them in any of the four lists.
- Source 5 is a list of 2024-10-22 that is not in `raw/mmsi/`.
- Windows run 2007-06-01 → 2028-12-24 by default. The exception is "takeovers", set partly by inspecting STK by hand.

**What the files show:**

a. **Every list has one vessel MMSI per vid.** The March list has 2,525 vessel rows on 2,525 vids, SKB excepted.

b. **The archive carries what three boats broadcast, not their official numbers.** No script writes these three, and
   they are labelled source 5 as if they came from a list. `registry.R`'s own tail lists them as numbers picked up in
   ASTD that are not in the registry.

   | vid | official: all four lists and Oracle | archive in use | ASTD |
   |---|---|---|---|
   | 2411 Huginn | 251439000 | 251139000 | 251439000 2013-01-03 → 2021-02-27 (533,363 pings); 251139000 2021-03-02 → 2026-01-31 (350,167) |
   | 1357 Níels Jónsson | 251454110 | 251396098 | 251454110 2013-01-03 → 2017-12-09 (283,362); 251396098 2015-05-23 → 2026-01-31 (873,730); both on 202 days |
   | 2935 Gunna Valgeirs | 251216110 | 251216100 | 251216110 never; 251216100 2017-09-30 → 2026-01-31 (695,854) |

   **1357's shared days, measured 2026-10-14 (§7 d):** these are not two transponders on one boat.
   - **May–Dec 2015:** 251396098 is heard 2015-05-23 → 2015-12-11 about 243 km from 251454110 on every paired ping
     (44,866 pairs within 5 min). Its median position is 23.6 °W 65.68 °N, in the Westfjords; 251454110 is in
     Eyjafjörður. 251396098 was then another boat.
   - **2016:** 251396098 is not heard at all.
   - **2017-12-09:** 251454110 is last heard at 13:47 and 251396098 starts at 13:49, in the same place (0 km). That is a
     transponder swap on 1357, the same shape as Huginn's in 2021.

c. **The March list's row for 1612 is a source error.**
   - The first three lists hold Hallgrímur SI-77 on 1612 (251237110, "Afskráð 25.1.2011. Sökk").
   - The March list instead puts 251237000, "Júlíus Geirmundsson ÍS-270", call sign TFKJ, on 1612.
   - Júlíus Geirmundsson is 1977 (TFKU, 251036110), and that row is in the same list. TFKJ was 1424's call sign.
   - Oracle has 1612 → 251237110, and 251237000 is never heard in ASTD.
   - A vid never changes hull.

d. **`mmsi.R`'s merge has three defects:**
   - it gives a new MMSI t1 = 2007-06-01;
   - it keeps an MMSI open after it leaves the list;
   - it reads `fd_staging("mmsi", …)`, which does not exist.

   15 vessel MMSIs left a later list (9 between Nov 2024 and Apr 2025, 6 between Apr 2025 and Mar 2026). They are
   deregistered boats, sold abroad, scrapped or sunk, with the date in the note. 14 are still open to 2028-12-24 in
   the March merge.

e. **Only two list rows never reached either archive:**
   - 261860840 → 7899, which the old script deliberately corrected to 251860840;
   - a net buoy on 2727.

f. **The March merge cannot be adopted as it stands.** It gives two open vessel MMSIs to 1357, 1612, 2411 and 2935.
   `registry.R` joins MMSIs by vid, so `vessel.parquet` would go from 7,043 rows to 7,047.

g. **What a correct adoption gains:**
   - ASTD pings that the union's inner join drops today: Huginn 533k, Níels Jónsson 283k, 3068 59k, 3066 9.8k, 7900 4.1k,
     9839 98. That is about 890k in all.
   - The 51,735 EMODnet 2017 pings on 251439000, which have no vid today (decision 067), get vid 2411.

h. **Some vids are still missing from the register.** 12 vids that got an MMSI in March were not in April's `vessel_v`.
   After the October dump 11 are still missing (only 7913 arrived): 7912, 7916, 3068, 3062, 3043, 3053, 7914, 7777, 7918,
   3070, 3073. 3068 "Vinur ÞH" has call sign TFAX, which `vessel_v` has on 3048 VINUR since 2026-03-17.

i. **TODO 17's TFUT case is already resolved.** All four lists and Oracle give TFUT to 2173 Tómas Þorvaldsson GK-10
   (251017000). The key already assigns mid 133558 to 2173 (step `segment: registry`). The TODO's text is stale.

## 3. The October Oracle dump

- **26 of 32 tables changed.** Three vids are new:
  - 3699 KONGSFJORD (LFNT), status `Erlent`, **foreign but below 3700**;
  - 3700 Doggi (LLIA), `Erlent`;
  - 7913 LITLI ÖRN VE.
- **Real changes on 10 vids:**
  - kW: 6360 119 → 159.6, 7259 116 → 175, 6394 119 → 116, 6941 119 → 196, 3069 0 → 336;
  - length: 6569 7.89 → 8.47;
  - port and number: 1701, 1765 and 6365 (6365 also went from category 62 to 33);
  - 1277 was struck from the register.
- **The rest is noise.** 601 lengths, 198 kW values and 702 GRT values differ by at most 3e-14, which is floating-point
  representation. No vessel crosses a length-class break (8/10/12/15/18/24/40 m).
- **Column types changed.** The `rjdbc` driver returns integer columns as doubles (`registration_no`, `usage_category_no`,
  `mmsi_no`, …), and `hist_session` changed from numeric to character.
- **MFRI's copy of the register looks stale.** `valid_from` by month: 2026-02 89, 03 45, 04 78, 05 11, 06 1, none after.
- **The dump script ran from the wrong place.** The run used `raw/vessels/DUMP_vessels.R`, a copy of
  `dump/oracle/vessels.R` with `connect_mar(rjdbc = TRUE)` and a relative output path. A script does not belong in `raw/`.

## 4. Proposal: one pass

1. **Rebuild the archive from its sources.** `reference/vessels/mmsi.R` is rewritten (preprocessing side) and becomes a
   target `mmsi` upstream of `vessel`, writing `curated/vessel/mmsi.parquet`.
   - **Inputs, as files:** the Oracle snapshots behind sources 1–4, dumped to `raw/mmsi/` by a `dump/` script; the four
     lists; Oracle's `vessel_mmsi`.
   - **Windows:** an MMSI–holder pair holds from its first list to its last.
     - t1 is the default 2007-06-01, unless the MMSI or the vid had another holder before. Then it is the first list
       date, or the note's date.
     - t2 stays open while the pair is listed. Once it drops off, t2 is the note's date ("Afskráð …"), or else the last
       list date.
   - **Provenance:** every row keeps its source file and a `basis`.
   - **Asserts:** one holder per MMSI at a time, and one recorded vessel MMSI per vid at a time.
2. **Two declared corrections** in `curate/corrections/`, reviewed before they enter (as files in `overrides/`):
   - the three broadcast MMSIs map to their vid, with windows from ASTD and `basis = "reconstructed"`;
   - the March list's 251237000-on-1612 row is rejected.
3. **`registry.R`:**
   - `vid` (and `mclass`) as integer;
   - stop if any vid has two rows;
   - `mmsi` is the vid's current recorded vessel MMSI from step 1;
   - the foreign flag for 3699 as decided (§7 c);
   - SKB as decided in §5.
4. **`identity.R` takes its MMSI periods from step 1 and step 2**, one row per vid and period, rather than from
   `vessel.parquet`'s single `mmsi`. Its per-MMSI overlap and gap checks stay.
5. **`reference/vessels/vessel_year.R`**, a new target writing `curated/vessel/vessel_year.parquet`: one row per vid and
   year from 2007. It holds the usage type, kW and length of that year, each with its `basis` (§7 h, i). The
   fisheries-management class goes in a separate period table, `vessel_class.parquet` (vid, t1, t2, class), because it
   changes within a year.
   - **Effort follows the year.** `R/trail_sql.R` takes kW from `vessel_year` by (vid, year), not from
     `vessel.parquet`, so each ping's `kw_hours` uses the kW of its own year. This needs no ramb change:
     `ramb::rb_assign_effort()` takes `vessel_by = c("vid", "year")`.
   - **Coverage gaps by year** (maintainer, 2026-10-14). The class and usage type of the year tell an expected absence
     from a gap. A boat with AIS and no logbook or landings in a year is a coverage gap if it held a fishing licence
     class that year. It is expected if it was in Núllflokkur, a leisure class or a non-fishing type.
     `curate/checks/vessel_activity.R` and `ais_key_landings.R` classify by it.
   - **Leisure follows the class.** The trail marks a fix as leisure when the boat is in a frístundaveiðar class at that
     time, or its usage type that year is Frístundafiskiskip or Skemmtiskip, or it is an SKB boat (§7 b).
6. **Wiring:**
   - file targets for `raw/vessels/vessel_v.parquet` and the archive's inputs, so a new dump or list shows in `tar_outdated()`;
   - `dump/oracle/vessels.R` gets `rjdbc = TRUE` and becomes the script that runs; `raw/vessels/DUMP_vessels.R` goes.
     Done for every dump script, decision 105.
6b. **Call sign, local sign and name over time: `vessel_sign.parquet`, one row per vid, kind (`cs` | `uid` | `name`),
   value and period** (maintainer, 2026-10-14: the call sign and the local sign, ÍS-8, wander across hulls over time,
   like the MMSI). It is a table of its own: splitting
   `vessel_identity`'s rows by call sign would repeat its MMSI windows, and through `ais_ping_union` the pings. Measured
   2026-10-14:
   - **the annual register** (`staging/skipaskra/annual_call_sign.parquet`, the state at the start of each year,
     2007–2022): 114 of its 517 call signs belong to more than one hull over the period, and 10 hulls change call sign;
   - **Oracle's identification history** (`raw/vessels/vessel_identification_hist_v.parquet`, call sign, local sign and
     home port by `vessel_id`, mostly from 2023-12): a struck hull keeps its last call sign open, so TFBR stands current
     on 1473, 2815 and 3047 at once. A period closes at the hull's deregistration (`vessel_hist_v` status);
   - **the MMSI lists and snapshots**: dated call-sign observations, 2019–2026;
   - **the local sign** (`kvoti.skipasaga`'s `einkst` and `einknr`, dated 1990s–2023-12; Oracle's identification history
     after that): of the periods reaching 2007 or later, 1,614 of 4,101 local signs belong to more than one hull, and
     1,240 hulls have more than one sign. ÍS-8 has had four: 1660 (from 1996, never closed), 6325 (1998–2014), 6347
     (2014–2019) and 7056 (from 2020). As with Oracle's call signs, a struck hull's last sign stays open and must close at
     deregistration. The value is kept as the register writes it (ÍS-8), with a folded key for matching (Í→I, number
     padded to three digits, as `vessel.parquet`'s `uid`); some STK mobile-ids carry it in `loid` that way (ÞH061, EA300);
   - **the name** (`heiti` in `kvoti.skipasaga`, `name` and `previous_name` in Oracle's history), the same way. It
     wanders most and identifies least: of 5,142 hulls with periods reaching 2007, 1,250 have had more than one name, and
     on 2020-07-01 638 of 3,430 names were on more than one hull at once (HAFDÍS on 21). A name is history for a reader,
     never a key.
   - **names broadcast in AIS** (maintainer, 2026-10-14: they appear in ASTD, astdB and GFW). On disk only ASTD carries
     them: `vesselname` and `imonumber` on every ping (`staging/ais/astd`). The astdB archive as dumped
     (`raw/ais/astdB/astd_classb_2014-01-01_2024-12-31.zip`) has length, breadth and draught but no name, and GFW's
     `raw/external/gfw/fishing-vessels-v2.csv` has none. The name an MMSI broadcast, by year, goes beside the register's
     holder in the key review as a reader's aid. Under the rule of 2026-09-29 it is never evidence or a match key.
   As with the MMSI, each period carries its source and `basis`, and one call sign or local sign has one holder at a time
   (asserted; names repeat and are not asserted). Nothing in the main project reads it: its consumer is the key review
   (step 7), where call-sign reuse is the known failure (decisions 020, 044, 045), and an analyst who meets a vessel by
   its marks.
   **Built 2026-10-14** (`reference/vessels/vessel_sign.R`, tested into scratch): 29,664 periods. Oracle's identification
   history reaches back to 1954, not only 2023. The sources' placeholder start, 1901-01-01, becomes the hull's first
   registration: it alone caused 711 of the first version's 735 conflicts. A hull's period ends where its next value
   begins, so skipasaga's exact day beats Oracle's 1 January. Call signs have no conflicts. Local signs keep 91 periods
   where two hulls hold one sign at once (14 of 6,905 reaching 2007), flagged `conflict` for a reader. 26 periods have a
   hull with two values of one kind at once. ÍS-8 reads 401 (1961), 40 (1962), 1660 (1983–95), 1052 (1995–98), 6325
   (1998–2014), 6347 (2014–19), 7056 (2020–25), 7008 (from 2025-10); TFBR 2815 (2012–22), then 3047 from 2025-01-10, as
   decision 045 found from the track.
7. **Review the STK key against the archive** (`once` project, a key redo by decision; maintainer, 2026-10-14). The
   hand-curated match (the reviewed rows behind the segment table, `overrides/ais_key_*_reviewed.csv`,
   `overrides/stk_foreign_mid_vid.csv`) is untouched by this pass: the main rebuild reads the frozen key. Measured
   2026-10-14, read-only, the key's rows with an MMSI the rebuilt archive knows:
   - **agree:** 2,412 mobile-ids, 173.9 M pings;
   - **disagree:** 14 mobile-ids, 626k pings. All are MMSIs handed from one hull to another, e.g. mid 101130 (TFSR),
     1903 in the key for its whole span, while the archive has 251179000 passing to 3009 in 2015. The key's `mmsi` is
     attached from the register, not observed, so these are cases to review, not errors;
   - **resolvable:** 42 mobile-ids with no vid (15k pings) whose MMSI the archive gives to a vid, mostly SKB boats
     broadcasting it as `glid`;
   - **SKB:** 179 mobile-ids (358k pings), none with a vid; the code in `glid` gives each one (§5).
   A check in the `once` project would list these for review, as `ais_key_reused_callsign.R` does for call signs.
8. **Record and rebuild:**
   - a decision record;
   - one main rebuild of the 17 targets;
   - the `once` key stays frozen, except as §5 asks.

## 5. SKB pleasure craft through the AIS flow

**Measured:**
- **In the lists:** 187 → 203 SKB codes over the four lists, on 207 MMSIs. No MMSI ever has two codes, but 4 codes have
  two MMSIs:
  - SKB122: two MMSIs, both "Þytur";
  - SKB225: a boat and its rubber dinghy;
  - SKB908: a boat and an AIS buoy;
  - SKB905: two boats. "Gunnar" was sold ("nú SKB402"), and "Bylgja" holds SKB905 in the same lists.
- **In STK:** a code appears only in the global id (`glid`), on 179 mobile-ids with 357,642 pings. The local id is always
  "Unknown" (sometimes typed "Unkown"). SKB009 is on two mobile-ids (`SKB009`, `SKB009_MF`). None has an MMSI in the key.
  - The archive in use resolves 111 of the 179 (280,291 pings); the March list adds 3 more (105 pings).
  - 65 are in no list (77k pings, mostly SKB280 with 61k since 2022).
- **In ASTD:** 5 SKB MMSIs, with 5,346 pings (2019–2025).
- **As integers:** after the prefix, 202 of 203 codes are numbers (2–2772) with no collisions; `SKBXXX` is not.

**Today, SKB fixes never reach the trail.** The union's STK part keeps only mobile-ids with a vid, and ASTD/astdB/EMODnet
pings need an MMSI in `vessel_identity`. SKB has neither, so its fixes are not accounted for (aim 1).

**Options:**
- **A. SKB stays outside `vid`.** SKB gets its own entity class and the `isl_pleasure_<code>` identity (decision 041). The
  key knows the boats, but their fixes still never reach the flow.
- **B. An integer vid in a reserved range: vid = 100000 + SKB number** (SKB271 → 100271). It is one-to-one for 202 of
  203 codes, and vid stays an integer. Like 3700–4999, the range is an exception to "a vid is a hull": it names a
  registration, which has been reused at least once (SKB905), and which can cover a tender or a buoy. **Recommended:**
  it is the only way SKB fixes reach the trail and are accounted for without making vid character.
- A character vid was rejected because it touches every join.

**Option B, step by step:**

| step | what SKB gets | what changes |
|---|---|---|
| archive (§4 step 1) | SKB rows kept, with MMSIs and windows | nothing new: they are already rows |
| `registry.R` | ~203 rows: vid 100000 + n, a new column `register = "SKB"`, flag ISL, no length or kW (no Oracle record), name from the list | the SKB exclusion becomes this encoding |
| `vessel_identity` | SKB MMSI periods | ASTD/astdB/EMODnet pings on SKB MMSIs resolve (5 MMSIs, 5,346 ASTD pings) |
| `once` key (frozen) | a direct rule: `glid` `^SKB(\d+)`, suffix dropped, → vid 100000 + n, for all 179 mobile-ids (357,642 pings). This includes the 65 in no list, which get a vessel row from the key with `basis` saying so. Entity class: pleasure craft | a key redo, by decision: cascade → audit → segments → key |
| `ais_ping_union` | +357,642 STK pings, +5,346 ASTD | generic |
| `ais_ping_tag`, `ais_ping_clean` | the generic filters | none |
| `port_stay`, `ais_voyage` | stays and voyages per vid | marinas may not be in the port list; a boat whose berth is missing gets long voyages (plan 011's problem). Measure after |
| `voyage_gear` | no landings, so no gear | none |
| `trip_voyage`, `station_event` | no logbook, so nothing | none |
| `ais_trail` | voyages with no gear get no fishing (2023: 4.57 M pings on such voyages, 0 fishing, basis `none`) | every SKB fix is accounted for as undecided, with no gear and no effort |
| `ais_catch` | no catch | none |
| checks, products | `check_vessel_activity` counts SKB boats as "AIS but never landed" unless it filters on `register`; the datacall selects fishing fixes, so none | filter on `register` |

**Code that assumes a vid range** (to audit before option B):
- `reference/vessels/ais_key_cascade.R:542` (`vid < 9900`);
- `docs/landings-match.qmd:381` (`vid >= 7555 ~ "tourist_angling"`);
- `curate/checks/ais_key_landings.R:87` and `curate/checks/ais_key_reused_callsign.R:70` (`vid < 3700`);
- every `vid %in% 3700:4999` (correct as long as the range stays foreign).

## 6. Pleasure craft already in the registry (for §7 b)

These vessels have ordinary vids and are in `vessel.parquet` and the trail now (all years):

| usage category | boats with AIS | pings | fishing hours | basis of that fishing | landings |
|---|---|---|---|---|---|
| 60 Seglskip (sailing ships) | 62 | 178k | 0 | — | — |
| 62 Skemmtibátur (pleasure boats) | 271 | 2.25 M | 26.8k | 21.7k logbook window (42 boats with trips), 5.1k speed | 87k rows, 1992–2024, mostly before 2017 |
| 68 Frístundafiskiskip (recreational fishing boats) | 39 | 2.37 M | 123.9k (8.5 M kWh) | speed; one logbook trip | 4,683 t on rod and line (sjóstöng, gid 19), 2008–2025, 38 boats |

- **Category 68 is the Westfjords sea-angling fleet** (ÍS 4xx, about 7 m, 67.2 kW). Rod-and-line gear from their landings
  reaches 31,558 of their 47,344 voyages.
- **`mclass` is today's category, applied to every year.** 340 of the 591 current skemmtibátar were in another category
  earlier in `vessel_hist_v`. That history mostly starts in 2023 (decision 047), so the dates of the switches are not reliable.

## 7. Asks of the maintainer

a. **SKB:** option B (vid = 100000 + n, through the whole flow), or A?
b. **Pleasure-craft fishing:** does it count as fishing effort? Category 68 sea angling has 124k hours from the speed rule,
   with rod-and-line landings. SKB boats would have none (no gear).
c. **3699 KONGSFJORD:** extend the foreign range to 3699–4999, or take "foreign" from the status `Erlent`?
d. **1357 Níels Jónsson:** both MMSIs are heard on 202 days (2015-05 → 2017-12). Two transponders, or one on another hull?
   This sets the windows of the correction.
e. **1612:** reject the March row (§2 c)? Should it be reported to Fjarskiptastofa?
f. **3068:** is it 3048 VINUR (TFAX)?
g. **Sources:** where are the Oracle snapshots (sources 1–4) and the 2024-10-22 list, so step 1 can read them as files?
   And who refreshes MFRI's copy of the register (stale since about June)?
h. **`mclass` over time:** take it from `vessel_hist_v`, or keep today's category for all years?

**Answered by the maintainer, 2026-10-14:**

- **a. SKB:** option B. vid = 100000 + SKB number, through the whole flow.
- **b. Pleasure-craft fishing:** it counts as fishing effort, marked as leisure. A column says so, so analysts and the
  datacall can drop it.
- **c. Foreign:** decided from the register's status `Erlent`, not from the vid range. `registry.R` sets the flag from
  status. The code's `vid %in% 3700:4999` checks move to the flag as they are touched.
- **d. 1357:** the maintainer was not sure, so it was measured (§2 b). The correction maps 251454110 → 1357 until
  2017-12-09 and 251396098 → 1357 from 2017-12-09. 251396098's 2015 pings belong to another, unidentified boat.
- **e. 1612:** the March row is rejected by a declared correction. It is not reported onward.
- **f. 3068 is 3048.** A declared correction moves 251777340 to 3048 VINUR (TFAX).
- **g. The snapshots are still in Oracle.** A `dump/` script copies them to `raw/mmsi/`.
- **h. `mclass` over time:** taken from `vessel_hist_v` where it has rows, and today's category before that, with a
  basis column saying which. The maintainer then pointed to `~/stasi/skipaskra`, already copied to
  `raw/external/skipaskra/`. Measured 2026-10-14, it holds two different histories:
  - **Usage type over time.** The annual register's `gerd` column (`data/skipaskra_2009-2017_almost-tidy.rds`) gives
    FISKISKIP, SKEMMTISKIP, SEGLSKIP, FRÍSTUNDAFISKISKIP, … per vid and year for 2009–2017: 2,564 vids, 2,237–2,298 a
    year. 269 vids change type: 172 from SKEMMTISKIP to FISKISKIP, 43 the other way. The 2018–2022 page matrices hold
    no type text (2018 checked).
  - **Hreiðar's table fills the gap.** The maintainer next pointed to `~/stasi/hreidar` (moved into `raw/external/` with
    `~/stasi/skipaskra` on 2026-10-14: one copy, not copies of copies), which is byte-identical to
    `raw/external/hreidar/data-raw/`. `registry.R` reads only `yh1`/`yh2` from it.
    - `HREIDAR_Islensk_skip.xlsx` ("Data main") is one row per vid and year, 1710–2021: 5,900 vids, about 2,270–2,560 a
      year since 2000. Each row has the usage type (`Notkunarteg`, in the register's vocabulary), Hreiðar's own fleet
      segment (`Megingerð`: Groundfish, Pelagic, Stern, Multi, Trawl boat, …), measured kW, length, open or decked, and
      operator.
    - Its usage type agrees with the register's `gerd` on 98.0% of the 20,441 vid-years both have (2009–2017). Most of
      the rest is spelling ("Fiski,farþegaskip" against "FISKISKIP/FARÞEGASKIP").
    - In 2007–2021, 437 of 2,835 vids change usage type. The sea-angling boats are Frístundafiskiskip throughout.
    - **So the usage type over time is:** Hreiðar for 2007–2021, `vessel_hist_v` from 2023, and today's category for
      2022 and before 2007. `basis` says which. The register (2009–2017) stays as a consistency check, not independent
      evidence. Hreiðar is keyed on `Skskr.nr.`, which decision 046 found reliable only from 2007 on, the years used here.
  - **The fisheries-management class over time.** `data/history.rda` has vid, `t1`, and a class code with its name
    (`mgtm_class`), for 5,100 vids, 1991–2021, in 40 classes. These include Frístundaveiðar (−11, 95), Strandveiðar
    (−12), aflamark, krókaaflamark and Núllflokkur. This is a different thing from the usage type. It becomes its own
    dated column, and it also serves answer b: a fix by a boat in a frístundaveiðar class at that time is leisure
    fishing. It ends 2021-12-15, and what built it is not yet traced.

- **i. kW and length follow the year too** (asked and answered 2026-10-14). The trail's `kw_hours` uses today's kW for
  every year, but 351 of 2,762 vids change measured kW in Hreiðar's table in 2007–2021. The sources are Hreiðar to
  2021 and Oracle's `vessel_engines_hist_v` / `vessel_measurement_hist_v` from 2023, with a basis column.

**Still open, not asked:** who refreshes MFRI's copy of the register (stale since about June), and where the 2024-10-22 list is.
  The four lists bracket that list, so step 1 does not wait for it.

## 8. Checks (done when)

- **`vessel.parquet`:** `vid` is an integer and unique, and no vid has two current MMSIs.
- **`vessel_identity`:** no MMSI on two vids at once. ASTD pings on 1357, 2411 and 2935 are counted before and after, and
  the 51,735 EMODnet 2017 pings on 251439000 carry 2411.
- **`tar_outdated()`:** shows `vessel` after a change to `raw/vessels/vessel_v.parquet` or a list.
- **With option B:** every SKB fix is in the trail, with fishing basis `none` unless it has gear; no code filters out
  vids ≥ 100000 by accident.
- **TODO 17:** its check is rerun against the rebuilt archive. Rerun 2026-10-17 (decision 117): `TFUT` and `TFPH`
  resolve; the 88 vids below 3700 still have no MMSI, and 42 above 4999 with them.
