# 022 — stk mined whole: the mobile-id key, the trip table, and what the rest holds

**status:** proposal — §2, §3 and §5 measured; §4 waits for the maintainer's go (the voyages were rebuilt 2026-10-16,
decision 112); §7 asks 1 and 4 open, 3 and 5 answered 2026-10-17 (decision 128; TODO 25, 68); the key redo of
decision 128 took SKB and the units with an Icelandic vid's own MMSI ·
**2026-10-16** · **see:** plan 009 (the STK key), plan 018 (the dump), plan 021 (registries for every ping), plan 023
(the landings, which build on this one), TODOs 68 and 71, decisions 047, 075, 094 and 109

Drafted with AI assistance (Claude) on 2026-10-16, at the maintainer's request, now that stk is dumped whole
(decision 109). The mining runs while the flow is rebuilt. Its scope is the maintainer's (2026-10-16):
- **Broad-based:** every object, "mind you, there are a lot of tables that are backup copies".
- **The STK mobile id and the vessel:** as many of STK's pings as possible on a vessel, Icelandic or foreign. The
  witnesses are STK's own records, the registries (Icelandic, Faroese, Norwegian, EU) and the other AIS feeds (ASTD,
  astdB, EMODnet, GFW's list), measured against fishycode's key. The ad-hoc tables in `ops$einarhj` are reviewed.
- **STK's trip table against the trail's signal,** before the landings are matched with STK's trips (plan 023).

The logbooks are a witness here, not a subject: their trips are read from `curated/` (§4). The choices in §7 are the
maintainer's.

**Measured** (read-only, 2026-10-16): stk's overviews and column names in `raw/oracle/stk/`, the server dump of
decision 109; the share of STK units whose global id has an MMSI's form; `ops$einarhj`'s tables; the trail's
positions in the ping union by year, and 2023's by the key's class. **Assumed:** that an
object's name says what it was made for, since only 2 of the 63 carry an Oracle comment. The triage (§2) tests that
before anything rests on it.

**Measured since** (read-only, 2026-10-16), by Claude (AI) in a side session. A person has not yet checked the numbers.
- **What:** the triage of all 63 objects (§2.1, with the catalogue in the appendix); §3 for every year, with
  co-location against ASTD, astdB and EMODnet (§3.1); and §5 (§5.1).
- **On what:** `raw/oracle/stk/`, the frozen key, and copies of the vessel and register tables taken before plan 018's
  rebuild. So the rebuild does not change these results.

## 1. The corpus

63 objects, 46 tables and 17 views, with 994 M rows written. Of those rows, 911 M are in three whole-trail copies
(`stk_vms_v`, `trail_all`, `view_trail`, kept on the server). Two objects carry an Oracle comment, and 15 have tmp,
test or dated names. fishycode reads the trail alone. Two views are not dumped: `tilk_stk_por_v`, which Oracle does
not finish evaluating, and `toti2_mobile_skip_v`, which Oracle cannot read for this login (ORA-00942).

## 2. Method: triage every object, profile what is left, then decide its use

1. **Triage, every object, from the files alone.** Each gets one class:
   - *empty*;
   - *leftover*: a tmp, test or dated name, confirmed by content (its rows a subset of a live object, or ending long
     before it);
   - *copy or derived*: a backup copy, or a view or table whose rows and columns come from others (keys a subset,
     values equal on the shared columns). Many of stk's tables are backup copies (maintainer), so the triage names
     what each copies, and only its source is profiled;
   - *code list*: a small table that others refer to;
   - *record*: the rest.

   The output is one catalogue in scratch: one row per object, with its class, rows, time span, keys and, for a
   copy, what it copies.
2. **Profile each record:**
   - what one row is;
   - its span by year, against the trail;
   - its keys: mobile id, trail id, vessel number (`skip_nr`), port (`hofn`, `harborid` → `pid`).
3. **Decide its use:**
   - which step of the flow it informs: vessel identity, ports and stays, voyages;
   - whether it adds to what fishycode has, checks it, or replaces it.

   Each use is measured against `curated/`, read-only, and judged on what it gains over the status quo.

### 2.1 What the triage found (2026-10-16)

Every object has a line in the appendix: its class, rows, span, keys and what it holds. The trail-shaped objects were
joined to the trail by `trailid` and compared on every shared column. The mobile-shaped ones were compared with
`mobile` by mobile id.

| class | objects | rows |
|---|---|---|
| record | 12 | 310.4 M (the trail 303.8 M) |
| code list | 8 | 453 |
| derived | 22 | 51.0 M |
| copy | 5 (3 on the server only) | 911.4 M |
| leftover | 10 | 3.9 M |
| empty | 4 | 0 |
| not dumped | 2 | |

1. **Most of stk is the trail again.** Each trail-shaped object below equals the trail row for row:
   - **By unit:** the research-vessel, survey and capelin views hold every position of their units.
   - **By time:** `trail_one_week` and `trail_two_days`.
   - **Exports:** `vms_stk_export_2007`-`_2013` and `coral_stk_export` (5,966,564 of 5,966,565 rows), each with
     `skip_nr` added.

   The selection behind `trail_multi_rectime_v` (3.41 M of the trail's 9.46 M groups of positions sharing a receipt
   time) was not found.
2. **The records beyond the trail and `mobile`** are the port events (`tilk_stk`) and the Coast Guard's phone
   notifications (`tilk_vss`). `tilk_stk_allt`'s voyages are derived from the port events: every one of its 2,768,717
   out and 3,100,951 in trailids is a `tilk_stk` event of the same `skip_nr`. The pairing rule was not reproduced.
3. **The trail before 2007 is almost gone.**
   - Its 2003-2006 partitions hold 11,515 rows, 9,460 of them with a 2006 time.
   - The 2003 clean-up split that year's ids between `trail_deleted_rows` (414,467) and the keep-list
     `trail_ok_ids_before_8_des_2003` (1,008,647). Only 23 of the kept ids are in today's trail.
   - 763,721 port events of 2003-2006 point at trailids that are no longer there. For those years the events are the
     only record of where vessels went, and they carry no unit.
4. **`mobile` keeps only each unit's current identifiers.** Against the snapshots of 2012-11-17 (`tmp_mobile`) and
   2003-12-16 (`mobile_test`), `localid` changed for 73 and 105 units, and `globalid` for 24 and 17.
5. **STK's mapping tables take the vessel from the local id.**
   - `skip_nr` is `localid` in 2,636 of `mobile_skip_mv`'s 2,842 rows, and in every row of `mobile_tab` and
     `view_mobile`. None of them has a date.
   - The exception is `skipnr_globalid_mapping`: call signs of foreign vessels (Oracle's comment).
6. **The assumption that a name says what an object is held, with three exceptions:**
   - `lodnuskip_stk` (capelin vessels) also holds the two research vessels;
   - `vms_skip_ar` is mostly vessels under 12 m (318 of 496 in 2007);
   - `trailtmp` is a four-day import of 2.9 M positions that the trail does not hold (§5.1, finding 3).

## 3. First: the mobile id and the vessel

**The aim** (maintainer, 2026-10-16): as many of STK's pings as possible on a vessel, Icelandic or foreign.

**Where it stands** (measured 2026-10-16, read-only):
- **42 % of the trail is not in the flow.** Of its 303.8 M positions, 175.2 M are in the ping union, every one of them
  with a vessel; the 128.6 M others are not. The share left out rises from 11-24 % in 2011-2015 to 64-65 % in
  2023-2025. 2026's 88 % is partly the union's older cut-off.
- **2023, by the key's own class of each mobile id.** 64 % of the year's positions (12.1 M) belong to 3,702 mobile ids
  the key knows but gives no vessel; 36 % have one.

  | Class (the key's `entity_class`) | Mobile ids | Positions, 2023 |
  |---|---|---|
  | vessel, with no vid | about 2,820 | 3.3 M |
  | shore station | 70 | 5.7 M |
  | net relay (a net buoy registered under an id derived from its ship's) | 132 | 1.2 M |
  | aquaculture, institute, navigation aid, buoy, beacon | about 195 | 1.6 M |
  | unknown | 222 | 0.25 M |
  | child vessel (a tender) | 258 | 21 k |

  Most of the unassigned units, 2,790 with 11.9 M positions, have a global id that is not MMSI-shaped. Among those
  that are, the MID is mostly foreign: Faroese (231) first, with 108 units.

**Where a unit's identity is** (maintainer, 2026-10-16): in its `localid` and `globalid`. The mobile id carries
none. It follows STK's registration date exactly (rank correlation 1; 0.9986 with first contact), so it is the order
in which STK created its units, not when a vessel used one. Measured by the ids' shape (letters as A, digits as 9):
- **`localid`:**
  - a vessel number (four digits) for 3,060 units, 2,254 of them with a vid;
  - the literal `unkown` (sic) or `Unknown` for about 29,000 units, which have no local id at all;
  - call-sign forms for some hundreds.
- **`globalid`:**
  - nine digits, an MMSI's form, for 20,785 units, of which 116 have a vid;
  - four letters, a call sign, for 2,872 (772 with a vid; 578 Icelandic `TF..`, 486 with a vid);
  - four digits, a vessel number, for 2,461 (1,941 with a vid);
  - letters and digits in other countries' call-sign forms (`AAAA9`, `A9AA9`, `AA9999`, `AAA9999` and more) for some
    thousands, few with a vid;
  - free text, the names of shore stations and fish farms.

So for most units with no vessel, the global id is the only identity: an MMSI, a call sign, or a name.

**What the key's cascade does with them** (`reference/vessels/ais_key_cascade.R`, in the once project). It matches
them to the Icelandic registry, time-aware:
- a vessel number in both ids;
- a vessel number confirmed by its call sign;
- a vessel number stated outright;
- a call sign alone;
- a nine-digit MMSI;
- older matches.

Foreign vessels are left to a stage of their own ("VID 3700-4999: no further matching effort planned"):
`reference/vessels/ais_key_foreign.R`. For the units still without a vessel it tries, in order:
1. MarineTraffic's manual matches;
2. call signs, time-aware, against the foreign registries (`curated/vessel/vessel_identity_foreign.parquet`);
3. nine-digit MMSIs, time-aware;
4. ASTD's and astdB's broadcasts, flagged for review.

Its output is candidates, not assignments (`curated/check/ais_key_foreign_candidates.parquet`). Of the 3,702 units
with no vessel that moved in 2023, 1,919 have a candidate, holding 2.9 M positions. None of them is in the key. The
other 1,783 hold 9.2 M positions, most of them shore stations and other non-vessels. So the largest gain in reach is
in deciding those candidates, with the witnesses below.

So the target is the vessels with no vid, about 2,800 units and 3.3 M positions in 2023 alone. Then the net relays
and child vessels, whose positions belong to a ship: a net relay's are the gear's, not the vessel's. Then the
unknowns. Shore stations, aquaculture, navigation aids and the like stay off vessels, and are named as such. The year
2023 is one sample; the same split is made for every year.

fishycode's STK key (`curated/vessel/vessel_ais_key.parquet`, plan 009) gives each mobile id a vessel by period. It
is a fitted model, not a registry. It is built from the segment table (decision 047), audited against witnesses that
never read it, and frozen in the once project. The audit's witnesses today:
- W1, other providers' AIS beside the STK pings, by MMSI;
- W2, logbook stations;
- W3, landing ports;
- a check against the vessel registry (`curate/checks/ais_key_registry.R`).

Three kinds of record bear on the same tie, most of them unused by the key:

1. **STK's own records** (new):
   - `mobile_skip_mv` and `mobile_skip_v`: 2,842 mobile ids with a vessel number, name, class and size. `mobile_tab`
     (1,260) and `view_mobile` (1,156) have the same columns. `skipnr_globalid_mapping` (233) ties a vessel number to
     STK's global id. None of them has a date.
   - **STK's unit register,** `mobile` (34,580): each unit's local and global id (above), the date it was registered
     (2003 to 2026), and its first contact and first update.
   - **The notifications:** every one names both the vessel and a trail id, so it ties a mobile id to a vessel at a
     known time. There are 5.9 M port events (`tilk_stk`) and 3.19 M voyages (`tilk_stk_allt`), and none of them read
     fishycode's key.
   - `pos_import` (call sign, name and local id with positions), and the vessel groups in `stk_ge_group_ships`.
2. **The registries,** with call sign and MMSI by date. They are evidence, which a vessel's own track can overrule:
   - Icelandic: the vessel schema and skipaskra, already in `curated/vessel/vessel.parquet`, with fishycode's MMSI
     history in `curated/vessel/mmsi.parquet`;
   - Faroese, Norwegian and EU: `raw/external/fro`, `nor` and `eu`, the subject of plan 021. They matter where STK's
     unit is foreign, or the MMSI is ambiguous.
3. **The other AIS feeds,** for the units the key has no vessel for, as W1 does for those it has: co-located pings
   give an MMSI, and with it the feed's own identity claims (IMO, call sign, name, flag, ship type):
   - ASTD (342 M pings in the union, 2013 on) and astdB (11 M), which carry those claims;
   - EMODnet (19.6 M);
   - GFW's fishing-vessel list (`raw/external/gfw`, by MMSI: flag, gear and size by year). It holds no positions, so it
     is a witness of identity and class only.

   A foreign hull gets its vid as plans 017 and 021 set out.
4. **The witnesses the audit already uses** (W1 to W3 above), which the new records join or check.

**The tables in `ops$einarhj` are under review, not witnesses** (maintainer, 2026-10-16: built with ad-hoc methods,
"they are not the truth"). They are the maintainer's own MMSI snapshots and earlier matches of STK to vid:
- **dumped:** `vessel_mmsi_20190627`, `_20201215` and `_20220405` (3,286 to 3,470 vessels each: registration number,
  vid, MMSI, call sign); `mmsi_icelandic_registry` (3,759); and `mobile_vid` (29,044 mid → vid rows, with periods);
- **not dumped yet:** `mmsi_icelandic_registry_20230115`, `vessel_mmsi`, `mmsi_mid`, `pame_vid_mmsi`, `stk_mid_vid`,
  `stk_mid_vid_2020`, `mid_vid_icelandic_20220418`, `mobile_vid_20240212`, `temporary_mid_vid` and `vessel_mid`.
  `dump/oracle/ops_einarhj.R` names the tables it dumps; these are added to that list and dumped on the server.

Each of their claims is tested against 1 to 4, as the key's are, and none decides anything by itself. The review says,
table by table: what it claims, how often the claims hold, and whether anything in it is worth keeping, which then
needs a witness of its own.

**fishycode already reads four of them.** `reference/vessels/mmsi.R` (plan 016) takes the three `vessel_mmsi_*`
snapshots and `mmsi_icelandic_registry` as sources for `curated/vessel/mmsi.parquet`, the MMSI history. They sit
beside the Fjarskiptastofa lists (`raw/mmsi/*.xlsx`) and Oracle's `vessel.vessel_mmsi`. So the review also says which
rows of the MMSI history rest on these tables alone, with no list or register behind them. The rebuild makes the MMSI
history as plan 016 has it; what the review finds changes it afterwards, by a correction or a decision.

**How a global id is matched,** by its form, for the units the cascade leaves without a vessel:
- **An MMSI:** to the MMSI sources by date (the Icelandic MMSI history; the Faroese, Norwegian and EU registries;
  ASTD's and astdB's claims; GFW's list). It is confirmed where the other AIS feeds have the same MMSI at the same
  place and time.
- **A call sign:** to the registries' call signs by date, the Icelandic and the foreign. The ITU prefix gives the
  flag, and ASTD's call-sign claims are checked beside it.
- **A vessel number:** as the cascade does now.
- **A name:** never to a vessel. Names only class a unit as a shore station, fish farm, institute and the like, and
  say which.

STK's own ties, from the mapping tables and the notifications, stand beside these whatever the ids say.

Measured:
- for each year, the positions on a vessel, and those off one by class, as in the table above;
- for each unassigned vessel unit, ranked by its positions: the vessel its global id points to, by the forms above,
  Icelandic or foreign; how strongly; and whether STK's own ties and co-located AIS agree;
- for each mobile id and period, whether STK's records (1) and the registries (2) give the same vessel as the key;
- the mobile ids one source ties to a vessel and the key does not, and the reverse;
- the notifications against the key's segments: does the vessel change where the key says it does?
- for the units with an MMSI as global id: does the registries' vessel for that MMSI at that date agree with the
  key's?
- the `ops$einarhj` tables, claim by claim, against the same.

A disagreement is a candidate for review, not a change. The key is redone only by a decision record (plan 014,
decision 075). Identifiers are vid, registration number, MMSI and call sign, never names, as in the key's audit. The
owner columns in `mmsi_icelandic_registry` and `vessel_mmsi_20220405` are not read.

### 3.1 What §3 found (2026-10-16)

Drafted by Claude (AI), read-only. The inputs:
- the raw trail;
- the frozen key (`vessel_ais_key.parquet`, 19,323 rows);
- copies of the vessel and register tables, taken before plan 018's rebuild.

**The aim, restated by the maintainer (2026-10-16):** one vessel table. Icelandic hulls by vid, and an MMSI for every
vessel and accessory (net relays, tenders, gear devices; the SKB pleasure craft included). Reach is counted in MMSIs
first and in vids second.

**Co-location** is W1's method (decision 047) with the MMSI as the label instead of a vid:
- a unit's moving STK pings (≥ 1 kn) are matched with ASTD's (2013 on), astdB's (2014-2024) and EMODnet's (2017)
  within 300 s and 2 km, in 58-71 °N, 35 °W-0°;
- a month counts as *strong* for an MMSI at opportunity ≥ 20 and score ≥ 0.8.

1. **The share of positions on a vid** (key rows joined by mobile id and time):

   | year | 2007 | 2010 | 2013 | 2014 | 2016 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
   |---|---|---|---|---|---|---|---|---|---|---|---|---|---|
   | positions (M) | 4.92 | 9.79 | 23.15 | 23.08 | 17.14 | 14.56 | 14.41 | 15.88 | 18.54 | 18.36 | 18.97 | 19.23 | 19.89 |
   | on a vid | 63 % | 74 % | 94 % | 94 % | 83 % | 67 % | 55 % | 49 % | 43 % | 41 % | 36 % | 37 % | 36 % |

   All years, by the key's class: Icelandic vid 182.0 M (59.9 %), foreign vid 6.78 M, shore stations 58.0 M, vessels
   with no vid 25.3 M (12,562 units), net relays 12.5 M, navaids 6.62 M, other non-vessels 8.88 M, unknown 3.02 M, child
   vessels 0.12 M, not in the key 0.50 M (14,221 units, 1,772 of them first seen in 2026, after the key's dump).
   2023 reproduces the table in §3 above.
2. **STK's own ties are a dated copy of STK's local id, and they agree with the key.**
   - **The port events:** 5,078,603 tie a unit to a vid through `trailid` (2006 to 2021-02-08). 97.3 % name the
     key's vid. The event's `skip_nr` is the unit's current local id in 99.2 % of them.
   - **Where they differ** (136 k events, 86 units), they mostly keep a local id the key left on physical evidence: in
     54 of 90 cases, 103 k events. The TFBR case is one (mid 101759).
   - **The foreign kept overrides:** 0 of 9,666 events agree. Those events carry `skip_nr` 0.
   - **The exports:** 2,653 of 2,705 unit-years agree (`vms_stk_export_*`), and 1,071 of 1,141 (`coral_stk_export`).
   - **The segment boundaries:** of the key's 123 changes of vid, only 10 have events on both sides within a year.
3. **They reach almost none of the units with no vid:** `mobile_skip_mv` 58 vessel units (0.99 M positions), the
   exports 5, the events 22.
4. **The register's holder of a unit's own identifiers**, set against each key row with a vid:
   - **Agree:** 1,924 rows by the vessel number in the global id, 435 by the one in the local id, and 586 by call sign.
   - **For call signs, 346 rows count several holders.** Oracle's history keeps a struck hull's call sign open, so
     that count is too high.
   - **Another vessel:** 41 rows (0.86 M pings), mostly a stale local id. They are a review list.
5. **The vessel units with no vid: an MMSI by route.** 12,562 units, 25.3 M positions:

   | class | units | positions | share |
   |---|---|---|---|
   | M1 its own MMSI (global id), confirmed by co-location | 2,392 | 0.74 M | 2.9 % |
   | M2 a co-located MMSI that a register, the SKB code or a candidate also names | 829 | 13.74 M | 54.2 % |
   | M3 a co-located MMSI alone | 2,632 | 4.28 M | 16.9 % |
   | M4 one claim, not seen co-located | 4,767 | 5.28 M | 20.8 % |
   | M5/M6 contested | 54 | 0.03 M | 0.1 % |
   | M7 no MMSI | 1,888 | 1.26 M | 5.0 % |

   **How strong M3 is:** a single strong month for 1,363 units (1.06 M positions), and 6 or more for 248 (2.16 M).

   **The hull behind the MMSI:**
   - the Faroese register: 1,080 units, 12.64 M positions;
   - an IMO in ASTD's broadcasts: 7,271 units, 8.48 M;
   - broadcast only: 1,120 units, 2.02 M;
   - the EU register: 146 units, 0.31 M;
   - SKB: 128 units, 0.15 M;
   - an Icelandic vid: 43 units, 0.10 M.
6. **Pairs are Faroese.** 50 units have two MMSIs about equally strong.
   - Units in the Faroese register hold 1.75 M of their 1.80 M positions. This fits pair trawling, which the
     maintainer says is common in the Faroes and almost unknown in Iceland.
   - The register settles 21 of them: one of the two is the register's MMSI for the unit's call sign.
   - Among Icelandic units in the key's W1, 1.0 % of unit-months have two strong vids.
   - So for Faroese fishing vessels, M3 needs a second route.
7. **Accessories.**
   - **Net relays:** 206 of 288 have a strong co-located MMSI (11.2 M of 12.5 M positions). For 192 units it is the
     MMSI of a vid whose own transponder is in the key at the same time: the carrier. 102 also sit beside an MMSI in
     the 99 range, likely the buoy's own.
   - **Child vessels:** all 682 carry an MMSI.
   - **Navaids and beacons:** 1,218 units carry their own MMSI.
   - **No MMSI:** aquaculture, institutes, buoys, and most shore stations.
8. **Positions on a vid.**
   - **Icelandic:** 181.3 M of 182.0 M lie in key rows that carry the vid's MMSI.
     130 Icelandic vids in the key have no MMSI on record at all, 671,987 of the key's pings (counted on the
     rebuilt archive 2026-10-17, decision 117). The archive's refresh did not reach them; co-location is the route left.
   - **Foreign:** no foreign vid has an MMSI in fishycode. Co-location gives one to units holding 6.55 M of the 6.78 M
     positions on foreign vids.
9. **The foreign candidates** (`ais_key_foreign_candidates`, 2026-09-27) cover 7,540 of the 12,562 units: 21.3 M
   positions (84 %).
   - **Tested by co-location, where it reaches,** they agree for fro 232 of 260, marinetraffic 661 of 734, eu 57 of
     71, gfw 78 of 79, and astd 1,603 of 1,608. The nor candidates (38 testable) have no MMSI to test.
   - **The 5,024 units with no candidate** (4.16 M positions) are call signs of flags whose registers fishycode does
     not hold (prefixes DNK, NOR, GBR, NLD, FRA first), or MMSIs no source holds. Most start in 2023-2025.
   - **Co-location gives 2,518 of them an MMSI** (3.08 M positions), 2,479 of them by co-location alone.
10. **Review lists, not changes** (the key is redone only by a decision):
    - 43 vessel units with no vid whose MMSI is an Icelandic vid's at the time (21 with that vid on another unit
      then);
    - the 41 key rows above;
    - the 37 `ops$einarhj.mobile_vid` claims that name another vid. Of its 3,044 claims, 2,397 match the key and 491
      fall on units the key does not hold.
11. **`ops$einarhj`'s ten undumped tables.** Judged from the overview's columns and row counts, nine are held already
    or are earlier versions of a dumped table. One adds to the MMSI history: the list of 2023-01-15. It is not on the
    Mac (TODO 71). The dumped `mmsi_icelandic_registry` is not that list either: it shares 3,756 of its 3,759 MMSI-vessel
    pairs with the list of 2024-08-21, and `mmsi.R` reads it with no date.
12. **What could make it wrong:**
    - co-location proves unit ↔ MMSI, not MMSI ↔ hull;
    - ASTD's extraction changes by year (decision 107);
    - a unit's identifiers are today's (§2.1, finding 4).

The working tables and the ranked list of units with every witness (no names) are in the session's scratchpad. They
are not kept: they rebuild from `raw/` and the frozen key.

## 4. Then: STK's trip table against the trail's signal

Nothing rests on the notifications until this is known (maintainer). `tilk_stk_allt`'s voyages are compared with the
voyages and stays cut from the track (`curate/ais_voyage.R`, `port_stay.R`) where both exist, mid-2007 to February
2021, with the vessel from §3:
- the share of each that has a match, by vessel and time;
- the offsets at departure and arrival, and whether the ports agree;
- what the one has and the other lacks, by year and by kind of vessel.

Where a logbook records departures, its trips are a third witness beside the trail. They are read from `curated/`,
not from the logbook schemas: `logbook/trip.parquet` (`T1`, the departure; `T2`, the return; twin trips left out,
decision 094) and `link/trip_voyage.parquet`.

Before mid-2007 the notifications stand alone, so how far they can be trusted there is judged from the overlap.
`tilk_stk` (the port events behind the voyages), `tilk_stk_allt_v` (1.95 M of the voyages: which selection?) and
`tilk_vss` (calls to the traffic service, 2010-2013) are profiled with it.

## 5. The rest, by name and size, to be confirmed by the triage

- **The trail's history and quality:**
  - `trail_deleted_rows`: 414,467 positions removed from the trail. Removed by whom, and why?
  - `trail_ok_ids_before_8_des_2003`: 1.0 M;
  - `trailtmp`: 2.9 M;
  - `trail_multi_rectime_v`: 3.4 M, positions with more than one receipt time?
  - `trail_one_week` and `trail_two_days`.
- **Groups of vessels and their tracks:**
  - `hafroskip_stk`: 561,299 positions, MFRI's vessels;
  - `leidangrar_stk`: 2.0 M, with in and out of port. Research cruises?
  - `leidangrar_ctrl`;
  - `lodnuskip_stk`: 1.1 M, capelin vessels;
  - `stk_hvalaskip_mobile_v`: whaling vessels.
- **Exports:**
  - `coral_stk_export`: 5.97 M;
  - `coral_skip_ar` and `coral_skip_veidarf_ar`: vessel by year, and by year and gear;
  - `vms_skip_ar`;
  - `vms_stk_export_2007` to `_2013`: 1.8 to 10.7 M a year. Against the trail of the same years?
- **Ports:** `stk_hafnir`, STK's own 170 ports, against fishycode's `pid`.
- **Whole-trail copies:** `stk_vms_v`, `trail_all` and `view_trail`. `trail_all` was checked: the same positions as
  the trail.
- **System tables:** `brand`, `comsystem*`, `customer`, `error_log`, `error_timi`, `lcf1_msg_type`, `msgformat`,
  `stk_speed_colors`, `posrep_current`.

### 5.1 What §5 found (2026-10-16)

1. **The 2003 clean-up.**
   - **What was removed:** `trail_deleted_rows` holds 414,467 positions of 976 units, received 2003-09-09 to
     2003-12-05. All 976 units are in `mobile`.
   - **Not visibly worse than the rest:** 3 bad times, no bad coordinates, 171 legs over 30 kn, and almost no
     duplicates.
   - **Against the keep-list:** none of the deleted rows is on it. 46,681 of 2003's 54,463 port events point at kept
     ids, and none at a deleted one.
   - Who removed them, and why, the data do not say (ask 1).
2. **Duplicates in the trail.**
   - **Exact copies:** 6.98 M rows repeat a unit's receipt time, time and place, mostly in 2013-2014 (about 1 M a
     year), and 0.23-0.28 M a year since 2020.
   - **Same instant, two places:** 5.75 M rows put a unit at one instant in two places, rising to about 1.07 M a year
     in 2023-2025. In 2023 they are almost all shore stations, fish farms and institutes (units carrying several
     devices), with 17 positions on a vid.
   - **`trail_multi_rectime_v`** holds 3.41 M of these 9.46 M groups, mostly pairs.
3. **`trailtmp`:** a four-day import (2011-09-30 to 10-03) of 725 units at a median 15,774 positions each, about
   one every 20 s. The trail holds 40,890 positions in those days. It adds nothing to the flow.
4. **Vessel groups.**
   - **The named views:**
     - `hafroskip_stk` is MFRI's two research vessels (vids 2350 and 1131);
     - `leidangrar_stk` is those two and 5 commercial trawlers;
     - `lodnuskip_stk` is the two and 4 pelagic vessels.
   - **Survey windows:** `leidangrar_ctrl` gives 40 survey windows on 6 of those units, 2016-2023, three of them almost
     a year long. They could mark the survey tows of chartered vessels in the trail (ask 4).
   - **Whale-watching and whaling:** 19 units, 18 with the key's vid.
   - **User-made lists:** `stk_ge_group_ships` holds 23 undated lists of vessel numbers by fishery, regime or flag, among
     them the coastal fishery's areas A-D, the longline allowance (355), Norway (134), the Faroes (66) and Greenland
     (4).
5. **The exports add nothing the trail lacks.**
   - **What they hold:** `vms_stk_export_*` holds 43-62 % of each year's positions on an Icelandic vid. Its list
     (`vms_skip_ar`) is mostly vessels under 12 m, so it is not a "15 m and over" rule.
   - **The coral export** is 2007-2010's longliners and bottom trawlers (gears 1 and 6).
   - **What they say** is which vessels were sent where (ask 1).
6. **Ports: `stk_hafnir` checks fishycode's crosswalk (`curated/reference/stk_hid_pid.parquet`), it does not
   replace it.**
   - **Agree:** of its 170 codes, 97 name the same harbour as the crosswalk.
   - **No real number:** 59 carry 0 or 999.
   - **Disagree:** 5 name another harbour (`SKAR`, `GJ`, `GJO`, `G`, `HVE`), a review list.
   - **Not comparable:** 9.
   - **Missing:** 42 codes used in the 2023 trail are not in it (20 % of the events). The crosswalk covers 245 codes.
   - **The events' numbers:** `tilk_stk`'s numeric port is `stk_hafnir`'s number for 3.79 M of 4.58 M events.
7. **System tables carry nothing for the flow.**
   - Every trail row has message type 0 and com system 100. The entry and exit message types are unused: the trail
     marks port events in `in_out_of_harbor`.
   - `error_log` holds the insert trigger's errors (mostly 2011-2012 and 2017-2021).
   - `posrep_current` is frozen at 2005-01.
8. **Use (§2, step 3):**
   - **Vessel identity:** STK's records check the key and add almost nothing beyond it.
   - **Ports:** `stk_hafnir` checks the crosswalk.
   - **Voyages:** `tilk_stk_allt` is §4.
   - Nothing replaces what fishycode has. The survey windows and the vessel lists are candidates as labels, not as
     sources.

## 6. How it runs

- **Read-only:** it reads `raw/oracle/stk/` and `curated/`, and writes to scratch. Nothing goes into `staging/` or
  `curated/`.
- **Alongside the rebuild:** the rebuild does not read or write `raw/`. No tracked file is edited while the build
  runs, as the build stamps every file it writes with whether the repo had uncommitted changes (`fd.dirty`).
  Findings are written into this plan after it.
- **In this order,** in a session of its own:
  1. the triage (§2);
  2. the mobile id and the vessel (§3). It needs nothing rebuilt, since the key is frozen in the once project and the
     rebuild does not change it. Of the undumped `ops$einarhj` tables only the MMSI list of 2023-01-15 adds
     anything, and it is not on the Mac (§3.1, TODO 71);
  3. the trip table against the trail (§4), once the rebuilt voyages are there;
  4. the rest (§5).
- **What plan 023 takes from it:** the vessel for each notification (§3), and how far STK's trips can be trusted, by
  period (§4).

## 7. Asks

1. **Where the knowledge sits:** who knows what STK's export and backup tables were made for, and why rows were
   removed from the trail?
2. **The write-up:** findings here, in plan 019's form, or a plan for each piece that turns out to matter (say, the
   notifications as a source of departures)? *Answered (maintainer, 2026-10-16): here; see §2.1, §3.1 and §5.1.*
3. **The MMSI routes into the key.** One vessel table (maintainer, 2026-10-16) needs each STK unit's MMSI in the key.
   Should routes M1 and M2 of §3.1 (14.5 M positions of vessel units with no vid) enter the frozen key?
   - It would be a `once` redo, which can also take the 1,772 units created since the key's dump.
   - It needs a decision record (plan 014, decision 075).

   *Answered (maintainer, 2026-10-17, decision 128): not now. Their hulls are mostly Faroese and otherwise foreign,
   so they wait for plan 021 step 6 to give foreign hulls vids.*
4. **Survey windows:** should `leidangrar_ctrl`'s windows mark the survey tows of chartered vessels in the trail (§5.1)?
5. **The review lists:** who reviews them, and where?
   - §3.1 finding 10: 43 units, 41 key rows, 37 claims.
   - §5.1 finding 6: 5 port codes.

   *Answered (maintainer, 2026-10-17, decision 128): Claude drafts each list with its witnesses and a proposed verdict
   per row, and the maintainer confirms. Confirmed rows enter `overrides/` for the next key redo (TODO 25).*

## Appendix: the 63 objects of stk (§2)

One line per object, from the files, 2026-10-16. Spans are the 1st to 99th percentile of the object's main time
column. fishycode reads only `trail` and `mobile`.

| object | class | rows | span (1st-99th percentile) | keys (distinct) | holds |
|---|---|---|---|---|---|
| `coral_skip_ar` | record | 6,884 | 1991 to 2010 | skipnr 1,278; ar 20 | export list: vessel by year |
| `coral_skip_veidarf_ar` | record | 6,975 | 1991 to 2010 | skipnr 1,278; ar 20 | export list: vessel, year, gear 1 (longline) or 6 (bottom trawl) |
| `error_log` | record | 3,979 | 2011-09 to 2026-01 |  | errors of the trail's insert trigger |
| `error_timi` | record | 2 | 2004-12 to 2025-10 |  | two timestamps of the import |
| `leidangrar_ctrl` | record | 40 | 2016-02 to 2021-02 | mobileid 6 | 40 survey windows on 6 of `leidangrar_stk`'s units |
| `mobile` | record | 34,580 | 2003-08 to 2026-08 | mobileid 34,580; localid 4,159; globalid 34,579 | the unit register: each unit's current `localid`, `globalid` and registration; fishycode reads it (`stk_mobile()`) |
| `stk_ge_group_ships` | record | 1,782 |  | ship_no 1,415; group_id 23; id 1,782 | the groups' vessel numbers (fishery, regime, flag); no dates |
| `tilk_stk` | record | 5,924,175 | 2004-01 to 2020-09 | trailid 5,924,175; skip_nr 2,178; harborid 219; hofn 75 | port events (out 1, in 2): trailid, `skip_nr` (the vid), STK and numeric port; trailid in the trail from 2008. Its `timi` runs 2003-09 to 2021-02. Joined to the trail (2008-2020, 4.9 M rows) each is the trail's own `I`/`U` row, same time and code; it holds 74-84 % of the trail's `I` to 2013, 63-75 % after, and 32-39 % of its `U` from 2014 (not the code-less copies). Its 763,721 events of 2003-2006 are the only record of those years' trail rows (2026-10-28) |
| `tilk_vss` | record | 170,355 | 2010-05 to 2013-03 | skip_nr 2,065; hofn 72; id 170,355 | the Coast Guard's phone notifications (Oracle's comment); not the line-incentive check's phone line, which is `simalinu.tilk_linu_sokn` (decision 163) |
| `trail` | record | 303,795,653 | 2007-06 to 2026-10 in volume (by receipt; 11,515 rows in 2003-2006, 9,458 of them in 2006-12, and 41 in 2007-02 to -05) | trailid 303.8 M; mobileid; harborid | the trail: one row per position, trailid unique; fishycode reads it (`stk_trail()`) |
| `trail_deleted_rows` | record | 414,467 | 2003-09 to 2003-12 | trailid 414,467; mobileid 976; harborid 86 | positions removed from the trail in the 2003 clean-up; none in the trail; 94-96 % on no position grid, STK's own units (2026-10-28) |
| `vms_skip_ar` | record | 2,034 | 2007 to 2011 | skipnr 616; ar 5 | export list: vessel by year, mostly under 12 m |
| `comsystem` | code list | 2 | 2003-06 |  | com systems (the trail uses 100 only) |
| `comsystem_type` | code list | 3 | 2003-06 |  |  |
| `customer` | code list | 3 | 2003-06 |  |  |
| `lcf1_msg_type` | code list | 13 |  |  | message types (the trail uses 0 only) |
| `skipnr_globalid_mapping` | code list | 233 |  | skipnr 233; globalid 232 | call sign to vessel number for foreign vessels (Oracle's comment); no dates |
| `stk_ge_groups` | code list | 23 |  | id 23 | 23 user-made vessel groups |
| `stk_hafnir` | code list | 170 |  | harborid 170; stad_nr 69 | STK port code to numeric port (`stad_nr`): 59 of 170 are 0 or 999 |
| `stk_speed_colors` | code list | 6 |  |  | display colours by speed |
| `coral_stk_export` | derived | 5,966,565 | 2007-06 to 2010-09 | trailid 5,960,181; mobileid 415; skip_nr 404; harborid 78 | trail 2007-2010 of the longliners and bottom trawlers on `coral_skip_ar`, with `skip_nr` |
| `hafroskip_stk` | derived | 561,299 | 2007-10 to 2026-08 | trailid 561,299; mobileid 2; harborid 60 | every position of MFRI's two research vessels |
| `hafroskip_stk_m` | derived | 2,056 | 2026-10 | trailid 2,056; mobileid 2; harborid 4 | their last 3 days |
| `leidangrar_stk` | derived | 2,018,618 | 2007-10 to 2026-05 | trailid 2,018,618; mobileid 7; harborid 93 | every position of 7 survey vessels |
| `lodnuskip_stk` | derived | 1,102,509 | 2007-10 to 2026-08 | trailid 1,102,509; mobileid 6; harborid 89 | every position of 6 vessels (2 research, 4 pelagic) |
| `mobile_skip_mv` | derived | 2,842 |  | mobileid 2,828; skip_nr 2,550; localid 2,465; globalid 2,827; kallmerki 471 | units with a vessel number, class and size; the number is the `localid` for 2,636 rows; no dates |
| `mobile_tab` | derived | 1,260 |  | mobileid 1,260; skip_nr 1,220; localid 1,220; globalid 1,260 | an older, smaller `mobile_skip_mv` |
| `pos_import` | derived | 34,579 | 2004-08 to 2026-10 | harborid 194; localid 4,149; callsign 34,579 | the trail's insert table: each unit's last position |
| `stk_hvalaskip_mobile_v` | derived | 19 |  | mobileid 19; skip_nr 17; localid 17; globalid 19; kallmerki 14 | 19 units of whale-watching and whaling vessels, with `skip_nr` |
| `tilk_stk_allt` | derived | 3,186,904 | 2004-02 to 2020-09 | skip_nr 2,178; hofn_ut 74; hofn_inn 75; trailid_ut 2,768,655; trailid_inn 3,100,951 | voyages paired from `tilk_stk`'s events: out and in time, port, trailid; `skip_nr` |
| `tilk_stk_allt_v` | derived | 1,953,346 | 2003-12 to 2020-09 | skip_nr 2,177; hofn_ut 73; hofn_inn 75; trailid_ut 1,535,097; trailid_inn 1,867,393 | a subset of `tilk_stk_allt` (selection: §4) |
| `trail_multi_rectime_v` | derived | 3,409,995 | 2013-06 to 2026-08 | mobileid 10,458; min_trailid 3,409,995; max_trailid 3,409,995 | groups of a unit's positions sharing one receipt time (a selection of them) |
| `trail_one_week` | derived | 1,150,900 | 2026-10 | trailid 1,150,900; mobileid 1,537; harborid 102 | the trail's last 7 days by receipt time |
| `trail_two_days` | derived | 84,003 | 2026-10 | trailid 84,003; mobileid 605; harborid 84 | the trail's last 2 days |
| `view_mobile` | derived | 1,156 |  | mobileid 1,156; skip_nr 1,103; localid 1,103; globalid 1,156 | a subset of `mobile_skip_mv` |
| `vms_stk_export_2007` | derived | 1,824,532 | 2007-06 to 2007-12 | trailid 1,824,532; mobileid 493; skip_nr 483; harborid 94 | the year's trail of the units of `vms_skip_ar`'s vessels, with `skip_nr` |
| `vms_stk_export_2008` | derived | 3,735,244 | 2008-01 to 2008-12 | trailid 3,731,724; mobileid 444; skip_nr 439; harborid 100 | as 2007 |
| `vms_stk_export_2009` | derived | 4,052,360 | 2009-01 to 2009-12 | trailid 4,052,360; mobileid 417; skip_nr 412; harborid 104 | as 2007 |
| `vms_stk_export_2010` | derived | 3,867,202 | 2010-01 to 2010-12 | trailid 3,867,202; mobileid 329; skip_nr 328; harborid 100 | as 2007 |
| `vms_stk_export_2011` | derived | 3,937,647 | 2011-01 to 2011-12 | trailid 3,937,647; mobileid 355; skip_nr 350; harborid 104 | as 2007 |
| `vms_stk_export_2012` | derived | 3,380,799 | 2012-01 to 2012-12 | trailid 3,380,799; mobileid 327; skip_nr 319; harborid 98 | as 2007, no list on disk |
| `vms_stk_export_2013` | derived | 10,690,982 | 2013-01 to 2013-12 | trailid 10,690,982; mobileid 339; skip_nr 336; harborid 146 | as 2012 |
| `mobile_skip_v` | copy | 2,842 |  | mobileid 2,828; skip_nr 2,550; localid 2,465; globalid 2,827; kallmerki 471 | the view `mobile_skip_mv` materialises |
| `stk_vms_v` | copy | 303,784,194 | as the trail |  | the trail with `skip_nr` (server only) |
| `trail_all` | copy | 303,790,717 | as the trail |  | the trail (server only) |
| `view_posrep_current` | copy | 419 | 2005-01 | mobileid 419 | the same 419 rows |
| `view_trail` | copy | 303,791,859 | as the trail |  | the trail with `msg_type_code`, no trailid (server only) |
| `mobile_test` | leftover | 1,643 | 2003-08 to 2003-12 | mobileid 1,643; localid 1,606; globalid 1,643 | `mobile` as of 2003-12-16 |
| `posrep_current` | leftover | 419 | 2005-01 | trailid 419; mobileid 419; harborid 40 | a current-position table frozen in 2005-01 |
| `tmp_mobile` | leftover | 5,269 | 2003-08 to 2012-08 | mobileid 5,269; localid 3,873; globalid 5,265 | `mobile` as of 2012-11-17 |
| `tmp_mobile_20_11_2012` | leftover | 5,269 | 2003-08 to 2012-09 | mobileid 5,269; localid 3,876; globalid 5,268 | `tmp_mobile` two days later |
| `tmp_pos_import` | leftover | 5,269 | 1996-08 to 2012-11 | harborid 106; localid 3,878; callsign 5,269 | `pos_import` as of 2012-11-19 |
| `tmp_tilk_vss` | leftover | 465 | 2010-05 | skip_nr 235; hofn 50; id 465 | 465 rows of `tilk_vss` under other ids, 2010-05 |
| `trail_ok_ids_before_8_des_2003` | leftover | 1,008,647 |  | trailid 1,008,647 | the 2003 clean-up's keep-list (ids only), 23 in today's trail |
| `trail_tmp` | leftover | 9,406 | 2007-06 to 2012-11 | trailid 9,406; mobileid 8; harborid 56 | 9,406 trail positions of 8 units (a sample) |
| `trail_tmp1` | leftover | 9,341 | 2007-06 to 2012-10 | trailid 9,341; mobileid 7; harborid 56 | `trail_tmp` less 65 rows |
| `trailtmp` | leftover | 2,903,269 | 2011-09 to 2011-10 | trailid 2,900,481; localid 667; globalid 725 | a 4-day import of 725 units at ~20 s, other id range; not in the trail |
| `brand` | empty | 0 |  |  |  |
| `msgformat` | empty | 0 |  |  |  |
| `temp_skip_tt` | empty | 0 |  |  |  |
| `temp_stk_tt` | empty | 0 |  |  |  |
| `tilk_stk_por_v` | not dumped |  |  |  | out and in events paired (columns only; not dumped: Oracle does not finish it) |
| `toti2_mobile_skip_v` | not dumped |  |  |  | `mobile_skip_mv`'s columns (not dumped: ORA-00942) |
