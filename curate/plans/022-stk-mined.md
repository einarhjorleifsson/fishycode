# 022 — stk mined whole: the mobile-id key, the trip table, and what the rest holds

**status:** proposal — only the inventory measured, nothing in the pipeline changed · **2026-10-16** · **see:** plan
009 (the STK key), plan 018 (the dump), plan 021 (registries for every ping), plan 023 (the landings, which build on
this one), TODO 68, decisions 047, 075, 094 and 109

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

## 6. How it runs

- **Read-only:** it reads `raw/oracle/stk/` and `curated/`, and writes to scratch. Nothing goes into `staging/` or
  `curated/`.
- **Alongside the rebuild:** the rebuild does not read or write `raw/`. No tracked file is edited while the build
  runs, as the build stamps every file it writes with whether the repo had uncommitted changes (`fd.dirty`).
  Findings are written into this plan after it.
- **In this order,** in a session of its own:
  1. the triage (§2);
  2. the mobile id and the vessel (§3). It needs nothing rebuilt, since the key is frozen in the once project and the
     rebuild does not change it. The undumped `ops$einarhj` tables come in when the maintainer has dumped them;
  3. the trip table against the trail (§4), once the rebuilt voyages are there;
  4. the rest (§5).
- **What plan 023 takes from it:** the vessel for each notification (§3), and how far STK's trips can be trusted, by
  period (§4).

## 7. Asks

1. **Where the knowledge sits:** who knows what STK's export and backup tables were made for, and why rows were
   removed from the trail?
2. **The write-up:** findings here, in plan 019's form, or a plan for each piece that turns out to matter (say, the
   notifications as a source of departures)?
