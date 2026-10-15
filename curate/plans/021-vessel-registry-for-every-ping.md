# 021 — A vessel registry for every ping, whatever the flag

**status:** proposal — nothing built · **2026-10-15** · **see:** plans 008, 016, 017; TODO 17, 22, 63, 65; decisions
015, 036–043, 067, 107; `curate/corrections/astd_2026_imo_only.yml`

Drafted with AI assistance (Claude) on 2026-10-15, at the maintainer's request: "a comprehensive vessel registry for
the pings we have in the data", and "we no longer limit ourselves to Icelandic vessels". The numbers come from
read-only queries; nothing was written under `$FISHYDATA`. The choices in §6 are the maintainer's.

**Measured** (read-only, 2026-10-15):
- every MMSI in staged ASTD (2013-01 to 2026-01, 155 months) and astdB (2014–2024), summarised by MMSI and year in
  one pass (4 min for 2.8 B rows), with the feed's own claims: its most frequent IMO, name, flag and `astd_cat`;
- each MMSI matched to the identity sources we hold, by MMSI or by the feed's IMO (§2.2);
- the MMSI tables in `raw/oracle/ops_einarhj/` and `raw/oracle/vessel/` against the copies plan 016 reads (§3).

STK is taken from plan 017 §2.2 (2026-10-14), not re-measured.

**Assumed:**
- the MID gives the flag where no register does;
- an IMO in ASTD's static data that passes the check digit names a hull (not checked against any register beyond
  ours);
- the *box* is plan 017's, 35 °W–0°, 58–71 °N, and stands for Icelandic and Faroese waters;
- hours are `sec_nextpoint`, capped at 1 h.

## 1. In short

- **Few MMSIs matter.** ASTD carries 546,892 MMSIs (2.82 B pings, 338 M hours) and astdB 68,663 (0.90 B pings), 63,536
  of them not in ASTD. But 504,759 ASTD MMSIs have fewer than 100 pings: the 31,226 with at least 1,000 hold 99.8 % of
  the pings.
- **Only the Icelandic ones reach the flow today.** 998 MMSIs on the Icelandic lists carry 348 M ASTD pings (12 %).
  The union keeps MID 251 and `cc_iso3 == "ISL"`, and no foreign vid has an MMSI (plan 017 §2.1).
- **Around Iceland and the Faroes the registries we hold already reach most of it.** Of ASTD's hours in the box,
  88 % reach a vessel through the Icelandic lists, the Faroese register or an IMO in a register. With GFW that is
  90 %, and with the feed's own IMO 98 %.
- **Over the whole ASTD area they reach little.** The same sources reach 15 % of the hours. Norwegian MIDs hold 53 %
  of ASTD's pings, and Norway's register has no MMSI, so Norwegian vessels reach a register only through GFW (36 % of
  their pings) or an IMO.
- **The feed itself is the largest identity source.** 54,177 MMSIs carry a valid IMO that no register of ours holds
  (38 % of ASTD's pings, 42 % of its hours). Plan 008 §5 proposed this table (`source = "astd"`), and it was never
  built.
- **What is proposed:** one integer `vid` for every hull the pings carry, a crosswalk from each feed identity and
  period to a `vid` with the basis of the link, and the flow choosing which hulls it carries (§6 a).

## 2. What the pings carry

### 2.1 The feeds

| feed | key | identities | pings | what it says about the vessel |
|---|---|---|---|---|
| STK | mobile-id | (plan 017 §2.2) | 290 M | `loid`/`glid`; keyed to a vid in the `once` project. 175.4 M pings on Icelandic vids, 6.39 M on 364 foreign-vid mobile-ids, 9.44 M on 1,083 `fro` candidates, 8.66 M on 910 `marinetraffic` candidates, 3.62 M on 5,028 vessel mobile-ids with no vid |
| ASTD | MMSI | 546,892, of which 99,978 invalid | 2,817 M | per ping: name, IMO, flag, `astd_cat`, size group, ice class; no call sign |
| astdB | MMSI | 68,663, of which 30,496 invalid | 901 M | `cc_iso3`, length, breadth, draught; no name, IMO or call sign |
| EMODnet 2017 | MMSI | | 19.6 M | an Iceland extract; 10,640 rows not on MID 251 |
| GPS logger | vid | | | Icelandic only |

**The ASTD extraction has changed over time.** MMSIs per year: 51,524 (2013), 65,054 (2014), 24,480 (2016), 132,968
(2019), 118,629 (2020), 35,145 (2021), 76,438 (2025). The 2026-02 to 2026-06 deliveries carry only vessels with an IMO
number (`astd_2026_imo_only.yml`, loaded as delivered). So coverage has to be stated by year.

### 2.2 What reaches each ASTD MMSI

Routes are tried in order, and each MMSI takes the first that reaches it. *Icelandic lists* means the four
Fjarskiptastofa lists, the Oracle snapshots and `vessel_mmsi`. The EU, Faroese and GFW routes go through
`vessel_identity_foreign`. *IMO in a register* is the feed's IMO found in the EU or Faroese register or in
`vessel_identity`.

| route | MMSIs | pings (M) | % of pings | hours (M) | % of hours | % of box hours |
|---|---|---|---|---|---|---|
| 1 Icelandic lists | 998 | 348.5 | 12.4 | 30.2 | 8.9 | 64.1 |
| 2 EU register (by MMSI) | 1,060 | 33.1 | 1.2 | 3.9 | 1.1 | 0.5 |
| 3 Faroese register (by MMSI) | 314 | 84.3 | 3.0 | 10.2 | 3.0 | 19.2 |
| 4 IMO in a register | 674 | 46.1 | 1.6 | 5.9 | 1.8 | 4.0 |
| 5 GFW only | 6,509 | 629.1 | 22.3 | 76.8 | 22.7 | 2.4 |
| 6 the feed's own IMO only | 54,177 | 1,075.9 | 38.2 | 142.1 | 42.1 | 7.4 |
| 7 nothing but the broadcast | 383,182 | 592.4 | 21.0 | 67.7 | 20.1 | 1.3 |
| 9 invalid MMSI | 99,978 | 7.3 | 0.3 | 0.9 | 0.3 | 1.0 |

By flag, share of the group's pings (MMSIs in brackets):

| MID | pings (M) | box hours (k) | register (1–4) | GFW only | own IMO only | nothing |
|---|---|---|---|---|---|---|
| ISL (251) | 348.6 | 29,976 | 99.9 % (1,013) | 0.0 % (2) | 0.0 % (1) | 0.0 % (10,600) |
| FRO (231) | 96.2 | 10,143 | 98.3 % (376) | 0.0 % (1) | 0.5 % (19) | 1.1 % (3,577) |
| NOR (257–259) | 1,497.8 | 1,291 | 1.1 % (94) | 36.4 % (1,967) | 36.6 % (2,318) | 26.0 % (50,479) |
| other Europe | 554.0 | 2,071 | 7.2 % (1,315) | 0.4 % (509) | 60.9 % (12,602) | 31.4 % (112,105) |
| RUS (273) | 101.7 | 675 | 6.6 % (69) | 53.1 % (862) | 35.7 % (2,536) | 4.5 % (17,193) |
| GRL (331) | 13.9 | 803 | 25.9 % (30) | 47.5 % (55) | 18.7 % (39) | 7.9 % (2,489) |
| rest of world | 197.2 | 1,272 | 1.3 % (149) | 10.7 % (3,113) | 76.7 % (36,662) | 11.2 % (186,739) |

- **ASTD's fishing category** (it ranks, it never selects: plan 008 §6) holds 70 M hours in all, 20 M of them in the
  box. 3,270 fishing-category MMSIs reach only GFW, with 39.6 M hours, almost all outside the box.
- **The feed says an MMSI changes hands.** 1,336 MMSIs carry two or more IMOs over the years, and 1,056 do so within
  one year (a holder change, or a misconfigured transponder).
- **astdB** reaches GFW for 3,991 MMSIs (553 M pings, 61 %) and the Icelandic lists for 1,718 (11.1 M). 32,071
  (270 M pings) reach nothing.

## 3. What exists, and where it stops

- **Icelandic.** `vessel.parquet` and `vessel_identity.parquet` (vid), the MMSI archive (plan 016, rebuild not run)
  and the STK key (`once`, frozen). The `ops$einarhj` snapshots and `vessel.vessel_mmsi` from plan 018's dumps match
  plan 016's copies row for row, so plan 018 phase 3 can switch the readers with no change of content. `ops$einarhj`
  lists six MMSI tables that are not dumped and that nothing reads: `mmsi_icelandic_registry_20230115` (3,687 rows,
  a dated list between plan 016's 2022-04 and 2024-08 sources), `vessel_mmsi` (3,687), `vessels` (7,181),
  `stk_mid_vid` and `stk_mid_vid_2020`, and `pame_vid_mmsi` (533).
- **Foreign.** Plan 008's `vessel_identity_foreign.parquet`: EU 1.08 M rows (18,711 MMSIs), Faroese 3,813 (1,417),
  Norwegian 25,220 (no MMSI), GFW 114,191 (one per MMSI; no name, call sign or IMO). `external_id` is the IMO first,
  then the source's own id. `vessel_identity_all.parquet` is the union with the Icelandic table. Both were built by
  hand on 2026-09-26 from staging of the same day, outside `targets` (plan 008 Phase 7 was never wired). The
  candidates (`ais_key_foreign_candidates.parquet`) are read by nothing in the flow.
- **GFW** is `fishing-vessels-v2` (2012–2020), fishing vessels by design.
- **The flow** keeps MID 251 in ASTD and `cc_iso3 == "ISL"` in astdB, and joins an MMSI to a vid through
  `vessel_identity` (`curate/ais_ping_union.R`). A foreign vid has no MMSI.

## 4. Proposed shape

The registry is the existing vessel tables widened to every hull, not a parallel table.

1. **`vessel.parquet`** — one row per `vid`, every hull the pings carry.
   - `vid` ranges: Icelandic as now; the Icelandic foreign vids 3700–4999 kept, because landings use them; SKB
     pleasure craft 100000 + n (plan 016); **every other hull 200000 + n**, plan 017 §6 c widened to all flags.
   - A `vid` never changes once given. It is assigned from an append-only table: a new hull takes the next number,
     and no rebuild moves an existing one.
   - New columns: `register` (`isl`, `skb`, `eu`, `fro`, `nor`, `gfw`, `imo`, `broadcast`); `flag` with
     `flag_basis` (`register` or `mid`); `fishing` with `fishing_basis`, from register evidence only (the Icelandic
     usage category, the EU and Norwegian registers, the Faroese type, GFW), never from `astd_cat`.
2. **`vessel_identity.parquet`** — one row per `vid` and attribute period for every hull: name, call sign, MMSI, IMO,
   flag, length and kW, each with its source and basis. The Icelandic rows stay as they are.
3. **`vessel_ais_link.parquet`** (new) — one row per feed identity and period: `feed` (`stk`, `astd`, `astdb`,
   `emodnet`), `feed_id` (mobile-id or MMSI), `t1`, `t2`, `vid`, `link` (the route), `basis`. The STK rows are the
   frozen key. One `vid` per feed id at a time is asserted.

**Which hull an MMSI names**, by plan 008 §5.0's hierarchy:
1. a `vid` where the MMSI is Icelandic (plan 016's archive);
2. else an IMO with a valid check digit, from a register, else from the feed;
3. else a register's own id (EU CFR, Faroese id, Norwegian id), matched by MMSI only. Norway and ASTD share no key,
   because ASTD has no call sign;
4. else the MMSI itself (`register = broadcast`). It is one hull until the feed's own IMO history splits it.

A name never matches.

**ASTD's and astdB's own claims** become a source-shaped table, `sources/astd/identity.R` → `staging/astd/identity.parquet`:
pings and hours by MMSI, year, IMO, name, flag, `astd_cat` and size group. astdB gets the same with `cc_iso3` and
length.

## 5. Steps

0. **After plan 016's rebuild and plan 018 phase 3**, which are one rebuild already queued. The 2026-02 to 2026-06
   ASTD months were loaded as delivered, with the gap declared (decision 107).
1. **Sources.**
   - Wire plan 008's adapters, `identity_foreign.R` and `identity_all.R` into `_targets.R` (plan 008 Phase 7).
   - Add the six `ops$einarhj` MMSI tables to `dump/oracle/ops_einarhj.R`; the maintainer runs it.
   - Refresh the EU register, last copied 2026-09-26, and GFW if there is a newer release (§6 e).
2. **The feeds' claims:** `staging/astd/identity.parquet` and the astdB counterpart (§4).
3. **The crosswalk:** each MMSI and period to a hull, by the rule in §4. The 1,056 MMSIs with two IMOs in one year go
   to a check table, and are linked only through `overrides/`.
4. **vids:** 200000 + n from the append-only table.
5. **The vessel tables** for every hull: `register`, `flag` and `fishing` with their bases. Length and kW come from
   the best register into `vessel_year` (plan 017 step 7).
6. **The union:** identity decides, not the MID (plan 017 step 4). Which hulls enter is §6 a.
7. **STK:** the foreign candidates (plan 008 Phase 5) link to the same vids. This is a `once` redo of the key, by
   decision.
8. **Record and rebuild:** a decision record, and a rebuild of the vessel tables and the flow.

## 6. Asks of the maintainer

a. **Which hulls go through the flow?** The registry holds all of them. For the flow:
   - (i) all of them;
   - (ii) fishing vessels by register evidence, all flags, whole track;
   - (iii) by area, the box or 5.a.

   ASTD is 2.82 B pings, against 348 M Icelandic ones; the union is about 566 M rows today. Recommended: (ii).
b. **vid 200000 + n for every non-Icelandic hull**, broadcast-only hulls included, given once and never moved?
c. **The feed's own IMO as a hull id** where no register has it: 54,177 MMSIs, 38 % of ASTD's pings. Recommended:
   yes, with basis `broadcast`.
d. **Norway:** 50,479 Norwegian MMSIs (26 % of Norwegian pings) reach nothing. Searched 2026-10-15:
   - The Directorate of Fisheries' open merkeregister data (its data documentation, updated 2022-07-04) has `Fartøy
     ID`, `Radiokallesignal` (the call sign, held for every active vessel of 15 m and over, and missing for about
     4 % of active vessels of 10.67–15 m), the fishing mark, name, size and engine. It has no MMSI, as our copy shows.
     So a Norwegian vessel is reached through its call sign, and the step missing is MMSI to call sign.
   - GFW's Vessels API (v3, `public-global-vessel-identity`, free token, R client `gfwr`) gives, by `ssvid` (MMSI),
     the AIS self-reported name, call sign and IMO with their transmission dates, and registry matches from over 40
     registries. This is the likely route, and it covers every flag, not only Norway. Its terms for bulk use need
     reading first.
   - Kystverket's open AIS carries call signs in its static data, but leaves out fishing vessels under 15 m, the ones
     missing here.
   - The Directorate also lists a vessel API (`api.fiskeridir.no/vessel-api/`); its schema could not be read. Asking
     them (postmottak@fiskeridir.no) whether it returns MMSI is cheap.

   Which route, if any?
e. **GFW:** we hold `fishing-vessels-v2` (2012–2020). Fetch a newer release, if there is one?
f. **Where the crosswalk sits.** In the flow, rebuilt with each delivery, with conflicts held out to `overrides/`;
   nothing in it is circular, unlike the STK key. Or in `once`, frozen. Recommended: the flow.
g. **Plan 017:** does this plan take over its steps 1–3 (MMSI periods for foreign vids, vid 200000 + n, the key),
   leaving 017 the flow side (ports, gear, kW, catch)? Recommended.
h. **ASTD's extraction:** are the changes by year (§2.1) known: area, filters? Coverage would be documented per year.

## 7. Checks (done when)

- Every MMSI in ASTD, astdB and EMODnet, and every STK mobile-id, has a row in `vessel_ais_link`: a `vid`, or the
  reason it has none (invalid, conflict).
- One `vid` per feed id at a time, and one `vid` per IMO.
- §2.2's table is rebuilt from the product, by year.
- The Icelandic vids, pings and trail are unchanged except where a link is new (checked on one year).
- A rebuild with one more ASTD month changes no existing `vid`.
