# 021 — A vessel registry for every ping, whatever the flag

**status:** partly built — §6 answered 2026-10-16 ((a) revised 2026-10-17), step 1 built (decision 114), steps 2-4 code,
checked in scratch (decision 115), §6 c amended 2026-10-17; the first vid allocation, decision 115's readings and
the review of the proposed overrides wait on the maintainer (§6 i answered 2026-10-17) · **2026-10-15** · **see:** plans 008, 016, 017; TODO 17, 22, 63, 65; decisions
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
| ASTD | MMSI | 546,892, of which 99,978 invalid | 2,817 M | PAME's Arctic Ship Traffic Data ([pame.is](https://pame.is)), all flags, not Norway's AIS; per ping: name, IMO, flag, `astd_cat`, size group, ice class; no call sign |
| astdB | MMSI | 68,663, of which 30,496 invalid | 901 M | PAME's class-B archive; `cc_iso3`, length, breadth, draught; no name, IMO or call sign |
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
   - *Done 2026-10-17 (decision 114):* plan 008's adapters, `identity_foreign.R` and `identity_all.R` are in
     `_targets.R` (plan 008 Phase 7), and GFW is v3.
   - Add the six `ops$einarhj` MMSI tables to `dump/oracle/ops_einarhj.R`; the maintainer runs it.
   - Refresh the EU register: the adapter reads `vesselRegistryListResults.csv`, downloaded 2024-02-19.
2. **The feeds' claims:** `staging/astd/identity.parquet` and the astdB counterpart (§4).
   - *Code 2026-10-17 (decision 115), run in scratch only:* `sources/astd/identity.R`, `sources/astd_b/identity.R` and
     `sources/emodnet/identity.R`, targets `astd_identity`, `astd_b_identity`, `emodnet_identity`.
3. **The crosswalk:** each MMSI and period to a hull, by the rule in §4. The 1,056 MMSIs with two IMOs in one year go
   to a check table, and are linked only through `overrides/`.
   - *Code 2026-10-17 (decision 115), run in scratch only:* `curate/vessel_ais_link.R` → `vessel_ais_link.parquet` and
     `curated/check/vessel_ais_link_review.parquet`; reviewed links in `overrides/vessel_ais_link.csv` (empty); §2.2 by
     year in `check_vessel_ais_link_routes`. Periods are dated segments (half-open UTC timestamps), cut at clean
     handovers (§6 c as amended). The held-out cases and their counts are in decision 115.
   - GFW's Vessels API pass (§6 d) is not built; the token is in place, and the pass's place is marked in the script as
     one more register by MMSI.
4. **vids:** 200000 + n from the append-only table.
   - *Code 2026-10-17 (decision 115):* `R/allocate_vids.R`; the ledger is `curated/vessel/vid_ledger/`, a file per
     allocation, read as the input `vid_ledger`. Not yet allocated: the maintainer runs `allocate_vids(dry_run = FALSE)`
     once the targets are built, then rebuilds `vessel_ais_link`. What a vid does when a hull's key changes is §6 i:
     it keeps its vid (answered 2026-10-17).
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

**Answered by the maintainer, 2026-10-16** (put to them one by one with Claude's recommendation; the notes under each
answer are Claude's). They are read with the aim the maintainer restated the same day (plan 022): one vessel table,
Icelandic hulls by vid, and an MMSI for every vessel and accessory.

- **a. Revised by the maintainer, 2026-10-17.** The registry is as complete as the feeds allow: the identity of every
  vessel in any AIS dataset. The flow is not the whole AIS: it carries **all Icelandic vessels and foreign fishing
  vessels**, in the North Atlantic from the West Greenland fishery to the Barents Sea, drawn as **ICES subareas 1, 2,
  5, 12 and 14 and NAFO subarea 1** (12 added by the maintainer: the Reykjanes Ridge, where oceanic redfish is fished
  with 14), and it keeps **whole voyages that enter that area**, so each voyage keeps its ports;
  fishing and catch are reported for the fixes inside it. A foreign vessel is a fishing vessel by register evidence
  (EU, Faroese and Norwegian registers, GFW's list) or by landing in Iceland, never by ASTD's own category. The ICES
  areas are on disk (`staging/aux/ices_areas_500m-buffer`); NAFO subarea 1 is not. The volume is not measured.
  (The answer of 2026-10-16 was every hull through the flow, about 650-700 GB for the AIS chain: superseded.)
- **b. vid 200000 + n for every valid non-Icelandic hull,** broadcast-only hulls included, given once and never moved.
  The MMSI, IMO and call sign are attributes in `vessel_identity`, by period; an MMSI is not a hull, since 1,336 ASTD
  MMSIs carry two or more IMOs. An invalid MMSI gets no vid, only the reason. Accessories (net relays, tenders) get no
  vid of their own: they link to their ship's vid in `vessel_ais_link`, with their role.
- **c. The feed's own IMO decides the hull,** with basis `broadcast`, where the check digit passes and no register
  holds it. The 1,056 MMSIs with two IMOs in one year, and an IMO on two MMSIs at the same time, go to a check table
  and are linked only through `overrides/`.
  *Amended by the maintainer, 2026-10-17:* "cut clean handovers at the ping boundary, review only overlaps, and count
  how many of the two-IMO MMSI-years are clean." Where one MMSI-year's claims hand over without overlapping in time
  (one IMO's last ping before the next one's first), the period is cut at the first ping of the new one and each side
  links to its own hull; only claims that overlap go to the check table. The same boundary applies, where it can, to
  an IMO followed or preceded by pings with no IMO under another name (decision 115 says what that rests on). Counted
  in decision 115: of 900 non-Icelandic MMSI-years with two or more valid IMOs, 261 are clean and 639 overlap.
- **d. GFW's Vessels API for every flag**, not only Norway, once its terms for bulk use are read and fit (Claude reads
  them; the token is the maintainer's). The query sends only MMSIs. In parallel the maintainer asks the Directorate of
  Fisheries (postmottak@fiskeridir.no) whether its vessel API returns MMSI. Kystverket is not used.
  *Terms read by Claude, 2026-10-16* ([license and rate limits](https://globalfishingwatch.org/our-apis/documentation/docs/license-rate-limits)):
  non-commercial use only, under CC BY-NC 4.0, which fits MFRI's research use; anything shown carries GFW's
  attribution, downstream users' too (relevant to `fishyweb`, TODO 15); the token is not to be shared or published;
  50,000 requests a day and 1.5 M a month per user, a breach blocking the token for a day or 30 days. Each dataset
  may carry its own licence, and GFW's registry fields from S&P Global (since June 2026) are limited in distribution.
  The search takes at most 50 entries a page and a `where` with OR; whether one request can carry several MMSIs is
  to be tested. gfwr 3.0 (installed) reads the token from `GFW_TOKEN`.
  *2026-10-17:* the token is in place. The maintainer added `GFW_TOKEN` to fishycode's own `.Renviron` (git-ignored;
  R reads only the working directory's one), and a test query answered. The pass no longer waits on the token, only
  on being built (decision 115 marks its place in the crosswalk).
- **e. GFW v3.** GFW's static fishing effort release v3.0 (March 2025) covers 2012-2024, against v2's 2012-2020, with
  a vessel list laid out differently from v2's one row per MMSI
  ([GFW FAQ](https://globalfishingwatch.org/faqs/2025-march-static-apparent-fishing-effort-v3-difference-with-map/)).
  The maintainer downloads it (GFW login) into `raw/external/gfw/`; `sources/gfw/` gets a reader for its layout, and
  v2 moves to `archive/` once v3 is staged and compared. GFW's inferred class, length and kW carry their own basis,
  apart from a register's. GFW's API notes say its hand-entered IMO records for fishing vessels give way to S&P
  Global's from June 2026.
  *Downloaded 2026-10-17* (`raw/external/gfw/fishing-vessels-v3/`, provenance in `README-provenance.txt` beside it).
  Measured: 773,165 rows, one per MMSI and active year, on 192,582 MMSIs (v2: 114,191), of which 32,029 are listed
  on a registry. 86,320 MMSIs are new, and 7,929 of v2's are gone. For 1,277 MMSIs the class changes between years,
  and for 1,054 the flag. Against every ASTD MMSI (2013-01 to 2026-06): v3 holds 9,628 of them, 1,046 M pings
  (36 %), and v2 held 8,624 with 987 M pings. v3 adds 1,260 MMSIs (78.8 M pings, 2.1 M hours in the box). It drops
  256 that v2 held (19.1 M pings, 0.6 M hours in the box), for reasons not given; GFW's README names a spoofed
  identity, a registry that calls the vessel non-fishing, and too little activity as grounds for leaving one out.
- **f. The crosswalk in the flow, the vid numbering outside it.** Which hull an MMSI period is follows from the inputs
  and is rebuilt with each delivery. Which vid a hull has depends on earlier builds, and a step cannot read its own
  output, so hull → vid is an append-only ledger read as an input, like `overrides/`, stamped and never rewritten. A
  small `allocate_vids()` extends it when a delivery brings new hulls; until then a new hull's pings carry `vid` NA
  with the reason `unallocated`, and the flow does not stop. Numbering in the flow (by first-seen date, say) was
  rejected: a backfilled month, such as full 2026-02 to 06 ASTD months, would move every later vid.
- **g. Split as proposed.** This plan owns identity (MMSI periods, vids, the crosswalk); plan 017 keeps the flow side
  (ports, gear, kW, catch) for non-Icelandic hulls. Answer (a) settles 017's asks a, b and d. Its port question (017
  §6 f) grows: stays and voyages for foreign fishing vessels need ports over the area and their home ports.
- **h. Not known.** The maintainer asks the provider what changed by year, and whether the full 2026-02 to 06 months
  can be sent again. Claude measures each year from staging (extent, MMSIs, IMO share, category mix), so coverage is
  documented whatever the answer. *2026-10-17:* the maintainer has written to the provider, PAME (pame.is), about the
  drop from 2026-02 to vessels with an IMO number; no answer yet.
- **i. Put to the maintainer 2026-10-17 ("pass as an open question"), answered the same day: what does a hull's vid do when new data
  change which hull key an MMSI resolves to?** The ledger stays append-only either way, and a never-seen hull gets a
  new number; two cases are open:
  1. *An upgrade.* A broadcast hull (`mmsi_<n>`) gains an IMO, from new feed data, a register or the GFW API pass, so
     its key becomes `imo_<n>`. Done naively, the IMO hull gets a second vid and the pings move to it.
  2. *A split.* The IMO history later shows one MMSI on two hulls, so one hull becomes two.

  Recommended to the maintainer (theirs to choose): for an upgrade, a ledger row that gives the new key the vid the
  old key had (an alias); for a split, the earlier period keeps the old vid and the new hull takes the next number.
  Either way an analyst's vid changes only where it really was two vessels. The ledger already carries either answer:
  each row has `basis` (`new`, or `inherited` with the old key in `from_hull`), and `allocate_vids(inherit = )`
  writes the aliases (`TRUE`) or numbers every new key afresh (`FALSE`).
  *Answered by the maintainer, 2026-10-17: the vid is kept.* An upgrade keeps its vid through a ledger row with basis
  `inherited`; in a split the earlier period keeps it and the new hull takes the next number. `inherit = TRUE` is now
  `allocate_vids()`'s default. A third case, a **merge** (a broadcast hull found to be a hull that already has a vid),
  keeps the existing vid and retires the other; the answer includes recording the retired vid's successor, so an
  analyst's old number still leads somewhere. The ledger has no row for that yet: it is not built.

## 7. Checks (done when)

- Every MMSI in ASTD, astdB and EMODnet, and every STK mobile-id, has a row in `vessel_ais_link`: a `vid`, or the
  reason it has none (invalid, conflict).
- One `vid` per feed id at a time, and one `vid` per IMO.
- §2.2's table is rebuilt from the product, by year.
- The Icelandic vids, pings and trail are unchanged except where a link is new (checked on one year).
- A rebuild with one more ASTD month changes no existing `vid`.
