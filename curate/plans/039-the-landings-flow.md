# 039 — The landings, from the first record to now: one cascade of sources, the same output in every period

**status:** proposal — written 2026-10-22 at the maintainer's request (the whole landings flow planned as one, not
period by period); measured read-only the same day, on top of the upstream study; nothing built; plan 038's split (the
logbook flow) answered here, agreed with three additions (§0); eight asks in §11 (TODO 123) · **2026-10-22** ·
**see:** plan 038 (the logbook flow, written beside this one), plans 007, 023, 025, 027, 036, 037 and 040, decisions 031,
155, 169 (as amended) and 172-174, TODO 74, 81, 112, 119, 121 and 122,
`$FISHYDATA/archive/2026-10-lods-upstream/README.md` ("the study"), `2026-10-lods-oslaegt/`,
`2026-10-landing-disposition/`, `2026-10-landings-flow/` (this plan's scripts `01`-`06`)

Drafted with AI assistance (Claude) on 2026-10-22, at the maintainer's request that the whole landings flow be
planned as one. The design and the measurements are Claude's, and a person has not yet checked the numbers. While it
was being written the maintainer added: "we should anticipate that the logbooks will have logbook trips back in
time". So the plan reaches back to the first landing record in Oracle (1966), not to LODS's first (1992), and it
says what the output holds for a trip older than any landing.

**Measured** (by Claude, read-only; dump of 2026-10-16, build of 2026-10-21): the layers of 1992-2007 and the end of
ask, in the study (its §1-6); agf against LODS landing by landing from 2007-07 (`01`, `02`); what the built tables
hold and link, by period (`03`, `04`, `06`); what holds landings before 1992 (`05`). Scripts and logs are in
`$FISHYDATA/archive/2026-10-landings-flow/`. No column naming a person was read. **Assumed:** listed in §10. The main
assumptions are the units of the monthly tables before 1992, and which of them is upstream of the other. Others are
the roe factor before 2007, and the cause of 2007's surplus on the fixes.

**Form (recommended, ask a).** A new plan, not an amendment of plan 023.
- Plan 023 is an inventory of ask, kvoti and agf, made for a landing's trip, gear and catch.
- Its trip half (§5, §6) is separate work, built in part as decisions 172-174.
- A build design for 1966-2026 added to it would give one plan two subjects.

What this plan does with the other plans:
- It **replaces** plan 023 §3 (the source of each period) and the catch part of its §4.
- It **takes in** plan 025 §4 unchanged, as its design for 2007-09 to 2020-07.
- It **takes in** plan 036 §3 as its disposition.
- It **is** plan 037's phase 3, for the landings.
- **Plan 007's merge** (decision 031) becomes its rule for rows from 2007-09 on (§3.1).

This draft does not change the headers of plans 023, 025 and 036. Once the maintainer accepts, each header says which
of its sections this plan replaces or takes in.

## 0. The split with the logbook plan (plan 038)

Plan 038 was written beside this one, in another session. It proposed the split below, and this plan answers it.
The proposal is quoted in plan 038's own words (its §0):

- **This plan** [plan 038]: the logbook sources and their layers (afli, afli_sent, fs_afladagbok's `ws_*` and tour
  app, adb from 2025-11-19, aflaskeyti); `curate/logbook.R` and its corrections; `trip_reconciled` (`T1`, `pid1`,
  `T2`, `pid2`); the stations on the fixes; the effort; and the logbook's catch on the fixes. It also designs the trip
  ↔ landing link, keyed by logbook trip: `lid_map` and plan 027's flow table `trip_landing`.
- **The landings plan:** the landings sources and their layers (LODS, ask, agf, kvoti), `curate/landing.R`, and what
  one landing record is: its time (ask's first weighing, plan 025's `t_weighed`), port, gear, catch and disposition
  (plan 036). It also owns every landing the link leaves unclaimed, which reaches the fixes through the voyages
  (`ais_catch.R`'s unit 4). It stages the quota system's regime, gear code and hand-baited line flag as attributes of
  the landing, since `quota_trip` is keyed by landing.
- **Shared, one owner each:** the link (plan 038 designs it; the landings plan states what each landing brings to
  it); the return (`trip_reconciled` owns the reconciled `T2`; the landing is its last witness, and the landings plan
  supplies the landing's time); regime and gear (the landings plan stages them on the landing; plan 038 carries them
  onto the trip through the link, and into the gear cascade).

**Answer** (this session, 2026-10-22): agreed, with three additions.
1. **Landings before LODS.** The landings sources also include `fiskifelagid` and `vor`. Before 1992-09 they give a
   vessel's month, not a landing (§2). The link needs a step for them: the trips of a vessel-month joined to its month
   row, many to one. This plan supplies the rows and their `resolution`, and plan 038 designs the step.
2. **The link's lower bound.** `lid_map` reads landings from 2007-09-01 only (§6). This plan proposes lifting it
   (ask e), measured what the bound costs (`04`, `06`), and supplies landings for every period. Plan 038, which owns
   the link, cites it and builds the change. The surplus the bound leaves on the fixes in 2007 falls in unit 4, which
   is this plan's (§6).
3. **The regime, gear and line flag on the landing.** They come from `quota_trip`, keyed by LODS's landing (`hofn`,
   `komunr`: the line incentive 2004-2020, coastal fishing 2009-2023). The landing tables' own flag is a second
   source: `lods_londun.linu_ivilnun` and agf's `er_linuivilnun`, whose spans are not measured. They are columns of
   `landings.parquet` (§4): basis `recorded`, layer `quota` or the landing table, `none` elsewhere.

## 1. What is asked, and what is decided already

- **One flow:** one landings flow from the first record to now.
- **One cascade per value:** each value from the best layer that holds it, then the next. The layer that answered is
  recorded, and every value has a `basis`.
- **One output shape:** the same tables and columns in every period. Their content and basis vary (AGENTS.md: the
  flow runs at any data resolution).
- **The best layer** is the most upstream one that states its unit and keeps the most precision. A later deliberate
  change wins, and a downstream copy is a witness (plan 037 §1).
- **The checks are bookkeeping:** every landing and every kilogram of every layer is placed in one outcome, and the
  unexplained are listed (decision 155's method; AGENTS.md).

Decided by the maintainer:
- agf's rows with ask's columns for 2007-09 to 2020-07 (plan 025 §4, 2026-10-17);
- agf alone after 2020-07-22 (TODO 74, 2026-10-22);
- Oracle tables, not views (AGENTS.md);
- every `gerd` summed, A included (decision 169, amended).

## 2. The periods

A period ends where the best layer changes. Each boundary is a layer's own first or last day.

| period | span | the rows come from | above them, for some values | a row is |
|---|---|---|---|---|
| 0a | 1966-01 to 1981-12 | `fiskifelagid.vigtarskra66_81` | nothing | a vessel's month, by landing port, gear and species |
| 0b | 1982-01 to 1992-08 | `vor`'s monthly vessel totals (`afli_einstakra_skipa`, whose yearly sums equal `vigt_linur`'s); from 1991 also `fiskifelagid.landed_catch_pre94` (port, gear, area) | nothing | a vessel's month |
| 1 | 1992-09-01 to 2007-06-30 | LODS 1 (`lods_londun`, `lods_afli`); the exports at 159 from the container tables | LODS 2 from 1999 (weighing detail); `lods_slaegt`, for the conversion of its time | a landing |
| 2 | July and August 2007 | as period 1 | ask, for the landings it holds | a landing |
| 3 | 2007-09-01 to 2020-07-22 | agf; LODS's exports at 159 (to 2013-08) and the few landings agf lacks | ask (plan 025 §4) | a landing |
| 4 | 2020-07-23 on | agf | nothing in MFRI's Oracle (study §6) | a landing |

**Before 1966** no table holds a landing, except LODS's 59 stray landings of 1915-1992 (plan 007; `05`). The logbook
holds trips from 1950: 762 in 1950-1963, by a few vessels. From 1969 it holds 243 to 59,044 a year (`05`). For those
early trips the output exists, and the landing's values are `none`.

**Period 0 is coarser than a landing.**
- Every `vor` row before 1995 is dated the 1st of a month.
- `vigtarskra66_81` counts landing days on 6-21 % of its rows from 1972, but holds no day.
- `landed_catch_pre94` has no vessel in 1982-1990, so `vor` answers there.

A row of period 0 is therefore a vessel's month. That is the "coarser unit" of AGENTS.md's second done criterion: the
kilograms sit on it explicitly, not on a landing.

## 3. The cascade, value by value

| value (grammar) | period 0 | periods 1 and 2 | period 3 | period 4 |
|---|---|---|---|---|
| the landing: vessel, day, port, gear | the monthly table's vessel, month, port and gear; day `none` | `lods_londun`; exports: the container table by `komunr`; else `lods_slaegt` | agf; else `lods_slaegt` | agf |
| weight as weighed, kg | the monthly weight (§10: whether as weighed or whole) | `lods_afli`'s products; ask's lines where LODS 2 links them (period 2) | agf's net `magn` | agf's net `magn` |
| gutted and whole weight | `landed_catch_pre94.magn_oslaegt` (1991-); else `none` | `lods_slaegt`'s conversion where it holds the landing and species; else computed from the products with `lods_fragang` and `lods_i_oslaegt_vsv` | agf's, corrected for yield (plan 025 §3.2) | agf's, `provisional` for about two years (§3.3) |
| an export's weight (159) | `none` | the container tables' sold weight; else `lods_slaegt` with every `gerd` | the container tables to 2013-08; agf's `afdrif` U from 2013-09 | agf's `afdrif` U |
| an export's port of landing | `none` | `i_gam.lhofn`, `g_i_gam.l_hofn`, `g_skip.hofn` | `g_skip.hofn` = `upprunahofn`; agf: the landing's own port | agf: the landing's own port |
| how the weight was reached | `none` | LODS 2's lines from 1999; ask's lines (period 2) | ask's lines (plan 025 §4.3) | `none` |
| first weighing time | `none` | ask, where linked (period 2) | ask (plan 025 §3.1) | `none` |
| withdrawn | `none` | `none` | ask's copy-and-reverse; agf's zero-kg landings | agf's zero-kg landings |
| fishing area | `landed_catch_pre94.veidisvaedi` (1991-) | the product's area (`lods_vorur`) | agf's `veidisvaedi`; ask's line area | agf's `veidisvaedi` |
| disposition (plan 036) | `none` | 159 and the codes abroad (plan 036 §3.1); `g_skip.for_fra` from 1998 | 159 to 2013-08; agf's `afdrif` | agf's `afdrif` |

The basis follows from the layer. A weight as weighed and a code are `recorded`. A gutted or whole weight is `derived`
in every period, whoever computed it. Its layer says whose conversion it is: LODS's of the time, agf's, or
fishycode's with today's factors.

### 3.1 The rows

- **Periods 1 and 2** take their rows from `lods_londun`/`lods_afli`, not from `lods_slaegt` (study §4). Those tables
  keep:
  - kilograms for every species;
  - the products;
  - deep-sea redfish apart from redfish;
  - the lumpsucker roe;
  - the foreign port;
  - the undersize weight in full;
  - 13.8 kt of landings and the 20 landings before 1992-09-01 that `lods_slaegt` lacks.
- **`lods_slaegt` stays the layer of the whole weight** where it holds the landing and species. Its conversion is the
  one of its time: the frozen products' factors per trip, and the factors that were edited later (study §1; ask b).
  Where it files two species as one (deep-sea redfish to 1996), its weight is split by the products' shares, basis
  `derived`.
- **Periods 3 and 4** follow plan 007's rule: agf's landing where agf has the vessel, day and port, else LODS's. This
  is the cascade's fallback.
- **What LODS adds in period 3** (`01`):
  - the 6,282 export landings at 159 (151.2 kt);
  - 22 landings at placeholder codes;
  - one landing abroad;
  - one landing at a port (14 t, 2009).
- **Period 4:** LODS adds nothing.
- **Period 2:** ask gives no rows. It gives columns, as in period 3. They are joined by the recorded link
  `lods2_afli.vigtun_ask_id` → `ask.vigtanir`, not by vessel and day. The vessel-days ask holds that LODS 1 lacks (23
  in July, 50 in August; study §5) are placed by the account (§5).

### 3.2 The exports at 159, 1992 to 2013-08

The container tables hold the weight sold abroad and the port the catch was landed at (study §3). `lods_slaegt`'s
K + A rows are their witness. Their outcomes:
- **Exports from a processing plant** (`for_fra` V, or K + A = 0 where no `for_fra` is kept) carry no kilograms: their
  catch is in a domestic landing (decision 169, finding 2). They stay as zero-kg rows with the disposition `export`
  (plan 036).
- **Sales in lots `lods_slaegt` does not hold** (1995-1998, 3,380 lot × species keys; study §3):
  - **never loaded:** 1,717 keys (4.5 kt), with a weight only in `g_solumagn`. They enter as rows, flagged by their
    empty `g_i_gam.stada`;
  - **plant exports:** 977 keys (2.4 kt), already in a domestic landing. They add no kilograms;
  - **unexplained:** 677 keys (553 t), listed.
- **`lods_slaegt` is the only weight** for the 1996 Flemish Cap shrimp (17.3 kt) and for the 97 export landings that
  no container table holds.
- **The 479 landings abroad of 1999-2004** are rows at their foreign port in `lods_afli`, for 829 of their 837 keys.

From 2013-09, agf records the export per row (plan 036 §1), and `g_skip` (to 2016) is its witness.

### 3.3 Period 4 moves after the fact

agf rewrites the live weight of factory-vessel products about two years after the landing (plan 025 §3.2). Its rows
are rebuilt on a rolling basis (study §6).
- The values of the last two years carry `provisional`, a modifier column, not a basis (ask g).
- Each rebuild's fingerprint lists what moved.
- ask's columns are `none` in this period.

### 3.4 Lumpsucker, one rule in every period

The two systems record lumpsucker differently:
- **agf** records whole lumpsucker (951), computed from the roe.
- **LODS** keeps the roe as weighed (949).
- **2007-2020:** 25,962 landings differ for that alone (`02`). agf has 27,185 t of 951; LODS has 6,849 t of 949 and
  1,381 t of 951.
- **Before 2007:** `lods_slaegt` keeps such a landing as 951 at 0 kg, and `lods_afli` keeps the roe (study §1, §2).

Proposed, in every period: the roe as weighed (949, `recorded`), and the whole fish computed from it (951,
`derived`), each with the factor of its time. ask's `grasleppa_hrogn_studlar` gives the factor from 2006. Where the
factor comes from before 2006 is ask c.

### 3.5 Period 0

The rows are vessel-months (§2). `landed_catch_pre94` and `vor` overlap in 1991 to 1992-08, and no one knows which is
upstream of the other. The first holds port, gear and area; the second the plants' weighing lines. Step 1 (§8)
measures it, along with their units and what each includes. `fiskifelagid` holds 1966-1981 alone, and `vor` holds
1982-1990 alone with a vessel (`05`).

## 4. The output, the same in every period

The tables keep their keys and gain columns. The names follow plan 037's phase 1: under its ask e (answered),
`catch` becomes the weight as weighed and every consumer reads the whole weight by name. Until then this plan adds and
renames nothing.

- **`curated/landing/landings.parquet`**, one row per landing or vessel-month:
  - **the keys:** `.lid`, `schema`, `vid`, `date`, `hid`, `pid`;
  - **`resolution`:** `landing` (vessel, day, port) or `month` (vessel, month, port where known). A `month` row's
    `date` is the month's first day;
  - **ask's columns:** `t_weighed` with its basis, `withdrawn`, `withdrawn_by` (plan 025);
  - **the export's port:** `hid_origin`, `pid_origin` (plan 036);
  - **`provisional`** (§3.3);
  - **the quota system's regime, gear code and hand-baited line flag** (§0, addition 3), for plan 038 to carry onto
    the trip;
  - **the layer of each field group** (plan 037 ask b: a column per field group).
- **`curated/landing/catch.parquet`**, one row per landing × species × gear × stock × disposition:
  - three weights: as weighed with its state, gutted, and whole (today's `catch`), each with its basis and layer;
  - `disposition` with its basis (plan 036);
  - the fishing area.
- **`curated/landing/weighing.parquet`** (plan 025 §4.3), one row per line of the finest layer:
  - ask's lines, 2007-2020;
  - LODS 2's lines, 1999-2007;
  - LODS 1's products, 1992-2007, where LODS 2 holds none;
  - no rows in periods 0 and 4.

**The keys:**
- agf's `.lid` stays `min(londun_id)` over a vessel, day and port.
- LODS's stays the hash of (vid, date, hid) (decision 031).
- A month row's is a hash of (vid, month, hid, `month`).
- A LODS landing whose port changes gets a new `.lid`. That is the 918 keys (235.9 kt) whose foreign port replaces
  159.

**The precedence:** a declared table read by `curate/landing.R`, one row per period and field group, as plan 037 §4
asks. It is not written into the code.

## 5. Witnesses, and the account of each

A copy that never answers is checked, not read into the rows. The check is `curate/checks/landing_witness.R` →
`curated/check/`. In it, every landing and kilogram of the witness is placed in one outcome, per period, and the
unexplained are listed.

| period | witness | what is measured so far |
|---|---|---|
| 0 | `vor` against `landed_catch_pre94` (1991-1993), and both against LODS (1992-09 to 1993) | nothing |
| 1 | `lods_slaegt` against the products | study §1: 3,938,498 keys, 5,540 unexplained |
| 1 | `lods_slaegt` against the container tables at 159 | study §3 |
| 1 | LODS 2 against `lods_afli`, 1999-2006 | study §4: 29,636 and 22,349 one-sided keys, causes not sought |
| 1 | `vor`, per vessel × day × product, 2000-2006 | study §5: 264,985 keys differ, `vor` 2-11 % higher, unexplained |
| 1 | `kvotix`'s change logs (`log_lods_slaegt` 20,838 rows, `log_lods_afli` 1,078, `log_lods2_londun` 67,685, `log_g_skip` 38,093): the in-house edits, a later deliberate change (plan 037 §1) | not read |
| 2 | LODS 2 against ask, line by line | study §5: equal on every linked line but 6 |
| 2 | `lods_slaegt` | nothing |
| 3 | `lods_slaegt` | `01`: of 701,952 landings in both, 674,203 within 1 %; of 27,617 that differ, 25,962 are lumpsucker (§3.4) and 1,015 differ in herring alone (whole tonnes); agf alone 173 (7.9 kt); LODS alone 6,306 (§3.1) |
| 3 | `lods_afli` | `02`: equal to agf's net weight on 701,950 of the 702,149 landings in either |
| 3 | ask's net view, `g_skip` at 159 | plan 025 §3.2; plan 036 §1 |
| 3 | `vor` | nothing |
| 4 | `lods_slaegt` | `01`: of 256,589 landings in both, 256,419 within 1 %; of 165 that differ, 63 are of 2026 (agf 1.2 kt higher); agf alone 56; LODS alone none |
| 4 | `lods_afli` | `02`: equal to agf's net weight on 250,686 of the 256,648 landings in either; 5,753 agf landings not in it |
| 4 | `vor.samantekt_a_lods` (to 2026, source not known: plan 037 §3.3) | nothing |

Who wrote `lods_slaegt` last (`02`; its stamp `sng_cur`, counted, not printed): agf's package for 72,443 rows of 2016
and nearly all rows of 2017-2024; another writer for most of 2025 and 2026. Before 2016 the stamp is mostly empty.

## 6. Downstream

- **`curated/landing`** is read by 23 scripts and pages in this repo: `link_lid_map.R`, `catch_by_species_trip.R`,
  `ais_catch.R`, `voyage_gear.R`, `aflaskeyti_trip.R`, `corrections/logbook_gear.R`, twelve checks, the vessel
  overview's API, `licence_evidence.R` and three docs pages. Columns are only added, so those that select by name do
  not break. Rows change in four ways:
  - new rows: period 0, the 13.8 kt, the 4.5 kt and the 20 landings of §3.1;
  - new keys: the 918 foreign ports;
  - weights: the pelagics × 1000 (TODO 119);
  - the lumpsucker.

  The `once` project's readers keep the old landings until a decision redoes them (AGENTS.md).
- **The link** (`lid_map`, then plan 027's `trip_landing`) is plan 038's (§0). It reads landings from 2007-09-01 only.
  The bound is at `curate/link_lid_map.R:72`, carried over in the migration (bde740b) and never revisited. So no
  logbook trip before that day has a landing. What the bound misses (`04`):
  - **1992-09 to 2006:** 613,679 of 704,004 afli trips meet a landing of the same vessel, day and port. Another
    73,414 meet one within a day with the port dropped, and 16,911 meet none.
  - **January to August 2007:** 29,685 of 32,594 meet one by vessel, day and port.

  What this plan brings to the link, landing by landing:
  - a landing (or a vessel-month, with `resolution`) in every period from 1966;
  - `withdrawn` (plan 025);
  - the 159 landing with its port of landing (plan 036 §3.4);
  - the landing's time, port, gear, regime and line flag.

  Asked of plan 038 (ask e):
  - lift the bound;
  - add a month step for period 0 (§0, addition 1);
  - check the cascade's tolerances, set on 2007 on, against 1992-2006 before they are trusted there.
- **`ais_catch.R` counts January-August 2007 twice, most likely.** Every landing of those months is a landing with no
  logbook trip, because of `lid_map`'s bound. So it becomes a catch unit of its own on the fixes, beside its trip's
  logged catch. Catch on the fixes from landings, approach `fishing` (`06`):
  - **June, July, August 2007:** 40.2, 50.3 and 40.2 kt;
  - **September-December 2007:** 3.7-16.3 kt a month;
  - **June-August 2008:** 5.7-8.7 kt a month.

  Lifting the bound removes the surplus. The surplus is measured; its cause is assumed, not traced unit by unit (§10).
  Unit 4 also carries the landings of 6,991 tour-app trips (9.2 kt): they fall on vessel-days that no curated logbook
  holds, so their landings are unclaimed (plan 038 §1, measured there).
- **`catch_by_species_trip.R`** gains landed catch for every trip `lid_map` links. A month row is compared at the
  vessel-month, not per trip.
- **`trip_reconciled.R`** (decisions 173, 174) uses the landing as the last witness of the return, and its quota
  records are keyed by landing. Both go through `lid_map`, so both reach back with it. A month row is no witness of a
  day.
- **`allocation_audit.R`** (decision 155) extends its trip–landing outcomes to the whole span.
- **The port of landing** (plan 036). For exports at 159:
  - 1992-1995: `i_gam.lhofn` gives the port for 8,049 of 17,211 landings;
  - 1995-1998: `g_i_gam.l_hofn` gives it for all 10,275;
  - from 1998: `upprunahofn`, which equals `g_skip.hofn` (study §3).

  A landing abroad keeps the foreign port that `lods_afli` gives it. 159 never gets a pid (plan 036 §3.1).

## 7. What each change moves

| change | what moves | by how much | measured in |
|---|---|---|---|
| TODO 119 (decision 169's units) | LODS's herring, capelin and blue whiting | 19.1 → 19,086.8 kt to 2006; 0.7 → 735.9 kt in 2007 | decision 169 |
| `lid_map` without its bound | trips with a landing; 2007's surplus on the fixes | +613,679 trips at the first step (1992-09 to 2006); +29,685 (2007-01 to 08); June-August 2007's 130.7 kt from landings on the fixes, against 21.6 kt in June-August 2008 | `04`, `06` |
| period 1 from `lods_afli` and the container tables | species, units, ports, landings | the study's §4 list; +4.5 kt (1995-1998); 918 keys (235.9 kt) from 159 to their foreign port | study §3, §4 |
| period 0 | new month rows | 1,151-1,597 vessels a year (1966-1981); 1,483-2,277 (1982-1992) | `05` |
| period 2: ask's columns | `t_weighed` and the weighing lines for ask's vessel-days (1,146 of 4,840 in July, 2,574 of 3,853 in August); kg unchanged | | study §5 |
| period 3: plan 025 §4 | `t_weighed`, `withdrawn` (6,743 zero-kg agf landings, 631 trips matched to them), the weighing table | | plan 025 §3 |
| exports from the container tables, 1992 to 2013-08 | the export's weight is K + A where they agree; the port of landing | equal on 83,304 + 22,676 + 31,257 keys | study §3 |
| lumpsucker | 951 computed from the roe in every period | 25,962 landings of 2007-2020 differ between agf and LODS for this alone | `02` |
| disposition | splits rows; kg unchanged | | plan 036 §4 |
| period 4 | `provisional`; `none` for ask's columns | flags only | |

## 8. Order of work

0. **The pending rebuild** (TODO 119 and 121; plan 038 §8 step 0). **Done 2026-10-22** (decision 180). TODO 119 fixes today's LODS units and depends on
   nothing here. It is best done with the kvoti re-dump (TODO 110).
1. **Measure what §10 assumes.** Read-only:
   - period 0's tables: their units, which is upstream, what they include, and their overlap with LODS in 1992-1993;
   - the roe factor before 2006;
   - `kvotix`'s LODS logs.
2. **The link without its bound** (ask e; plan 038's step 3). First today's steps over periods 1 and 2, then the
   month step. Rebuild from `lid_map` by name, fingerprints first, and measure what moves (§7, second row).
3. **The output shape on today's sources** (plan 037 phase 1, for the landings): the columns, the basis, the layers,
   the precedence table and `resolution`.
4. **One adapter per layer** (plan 037 §4): `sources/lods1/`, `sources/lods_export/` (the container tables),
   `sources/lods2/`, `sources/ask/` (plan 025 §4.1), `sources/fiskifelagid/` and `sources/vor/`.
   - `sources/lods/` (`lods_slaegt`) and `sources/aflagrunnur/` stay as they are.
   - Each adapter reads one layer, chooses nothing, and reads no person's column.
5. **`curate/landing.R`** chooses by the precedence table, then adds the disposition (plan 036) and the weighing table.
6. **The witness account** (§5).
7. **The rebuild** from `landing` through `ais_catch`, by name, with fingerprints first and the kilograms accounted
   for (plan 037 §6).

Plan 040's phase 2 runs inside steps 3 to 5 (the maintainer, 2026-10-22): each adapter written or opened here writes,
in the same change, its source columns' overlay in `dump/oracle/meta/<schema>.yml` (LODS's units and their tonnes,
the container tables' and `gerd`'s and `for_fra`'s code labels, ask's and agf's weights, with their evidence and an
`assert` each) and its staging dictionary, the ledger of the conversions it makes.

## 9. Checks (done when)

- Every period's rows have the same columns. Every value has a basis and a layer, and `none` where no layer holds it.
- Every landing and kilogram of every layer, witnesses included, is in one outcome per period (§5). Per period and
  species, the kg in the rows plus the kg listed out equals the answering layers' kg.
- No landing is in two periods, and no gap opens at a boundary: 2007-06/07, 2007-08/09, 2020-07-22/23, and for the
  exports 2013-08/09.
- The link (plan 038's) joins trips in every year that has landings. 2007's landing-sourced kg on the fixes, month by
  month, is in line with 2008's.
- `check_bookkeeping()` is clean.

## 10. Measured and assumed

**Measured**, by Claude, not checked by a person:
- the study's numbers as cited;
- `01`-`06`: counts by period on the raw tables and the build of 2026-10-21.

**Assumed:**
- **The monthly tables' units.** `vigtarskra66_81`, `landed_catch_pre94` and `vor` are in kg; their yearly sums are of
  the size of the national catch of those years. Whether a weight is as weighed or whole is not known, nor whether it
  includes exports and landings abroad.
- **Period 0's upstream.** Which of `vor` and `landed_catch_pre94` is upstream of the other in 1991-1993.
- **The roe factor before 2006**, and that agf's 951 is computed from the roe.
- **`lods_slaegt`'s feed.** That agf's package fed `lods_slaegt` in 2007-2015 too, where the stamp is empty.
- **Period 4's 2026 differences** are LODS lagging behind agf.
- **2007's surplus on the fixes** is the double count of §6. The surplus is measured, not traced unit by unit.
- **The sold weight is the exported catch** (the study's caveat on K, §3).

## 11. Asks

a. **The form:** a new plan (recommended), or an amendment of plan 023.
b. **Period 1's whole weight:** `lods_slaegt`'s conversion of its time where it holds the landing and species
   (recommended), with the recomputation as a witness; or today's factors everywhere.
c. **Lumpsucker:** the roe as weighed and the whole fish computed from it, in every period; where the factor comes
   from before 2006.
d. **The exports to 2013-08:** the container tables' sold weight (recommended), with `lods_slaegt`'s K + A as the
   witness; or the reverse.
e. **`lid_map`'s bound**, with plan 038 (which owns the link): lifted first, as a step of its own, before the sources
   change (recommended).
f. **Period 0:** month rows in `curated/landing` with `resolution` (recommended), or a table of their own.
g. **Period 4:** `provisional` on the last two years, or the fingerprints alone.
h. **`kvotix`'s LODS logs:** measured before the build (step 1, recommended), or after it.
