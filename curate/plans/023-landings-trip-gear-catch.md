# 023 — The landings: a landing's trip, gear and catch, from the original source of each period

**status:** proposal — only the inventory and the columns measured, nothing in the pipeline changed; §8 asks open
(TODO 74) · **2026-10-16**
· **see:** plan 007 (fishycode's landings), plan 018 (the dump), plan 022 (stk, which this one builds on), TODO 74 (and 24, where 67 went),
decisions 094, 109 and 110

Drafted with AI assistance (Claude) on 2026-10-16, at the maintainer's request, now that ask, kvoti and agf are dumped
whole (decision 109). The mining runs while the flow is rebuilt. Its scope is the maintainer's (2026-10-16):
- **Focused** on three things: the trip that belongs to a landing, the gear associated with it, and its catch.
  Whatever bears on none of these is out of scope: quota, fees, control, buyers, owners.
- **For each period, the "original" source,** the system the landing was first entered in, with its copies checked
  for discrepancies.
- **A true trip table in the landings,** if one exists, is matched with STK's trip table.
- **At the end, the landings are matched with STK's trips.** That needs plan 022 first: STK's trip table checked
  against the trail, and its notifications put on vessels through the mobile-id key.

The logbooks are a witness here, not a subject: their trips are read from `curated/` (§6). The choices in §8 are the
maintainer's.

**Measured** (read-only, 2026-10-16): the overviews of `raw/oracle/{ask,kvoti,agf}/`, and their column names and
Oracle comments. **Assumed:** that a column's name and comment say what it holds. The profiles (§2) test that.

## 1. The corpus

| Schema | Objects (tables, views) | Rows written | With Oracle's comment | Change journals (`_jn`) | Named tmp, test or dated | Read by fishycode today |
|---|---|---|---|---|---|---|
| ask | 235 (138, 97) | 221 M | 124 | 57 | 22 | nothing |
| kvoti | 748 (435, 313) | 374 M | 224 | 50 | 29 | 2: `lods_londun`, `lods_oslaegt` |
| agf | 17 (4, 13) | 44 M | 9 | 0 | 1 | the base table `aflagrunnur` and some views |

About 1,000 objects. Only those that bear on a landing's trip, gear or catch are mined. By a scan of column names,
those with a landing key number 66 in ask, 19 in kvoti and 7 in agf; to them come kvoti's trip tables (§5) and the
code lists they refer to.

fishycode builds its landings today from agf's base table and two LODS tables (plan 007), and matches logbook trips to
landings in preprocessing.

## 2. Method

1. **Find and triage** the objects above: *empty*, *leftover*, *journal*, *copy or derived*, *code list* or *record*,
   as in plan 022 §2.
2. **Profile each record:** what one row is, its span by year, and its keys (vessel number, landing id `londun_id`
   and ask's ids, port `hid` → `pid`, species, gear).
3. **Measure** §3 to §6 against each other, and against `curated/`, read-only.

## 3. Which source for which period

The maintainer's preference: the "original", the system a landing was first entered in, with each copy checked
against it for discrepancies. The periods come from the maintainer's hypothesis on the lineage, checked on aggregates
on 2026-10-16 and not yet recorded as a decision:

| Period | Original | Copies to check against it |
|---|---|---|
| 1992-2006 | kvoti's LODS, entered directly (LODS 1 from 1992, LODS 2 from 1996) | — |
| 2007/08 to 22 July 2020 | ask (`landanir`, `vigtanir`) | kvoti's LODS 1 and 2 (`lods2_afli.vigtun_ask_id` points to `ask.vigtanir`); agf's rows, whose ids are ask's |
| 22 July 2020 on | agf (`aflagrunnur`), built in-house | kvoti's LODS 1, which runs on, fed by something not yet known |

Measured for each period:
- the landings in the original that are missing from a copy, and those in a copy but not in the original;
- for the same landing, whether the kg by species, the gear, the port and the day agree;
- the changeovers, 2007/08 and July 2020: are there landings in both systems, or in neither?

## 4. Trip, gear and catch, from the original

What the columns show (names and Oracle comments, 2026-10-16; still to be measured). ask has no trip table, by name,
column or Oracle comment, and no journal of one. Its record has three levels:
- **The landing,** `landanir` (723,129 rows): vessel, port, the day landing began (`londun_hefst`), and when it was
  registered and closed;
- **The weighing note,** `vigtarnotur_tab` (2.48 M rows; `vigtarnotur` itself is empty): one or more per landing, with
  its date, the gear, and the buyer and receiver;
- **The weighing,** `vigtanir` (10.5 M rows): one per line of a note, with stock, fishing area (`veidisvaedi_id`),
  condition, storage, product and kg.

Across the sources:
- **The trip.** No landing record seen holds a departure; it holds the landing's own times:
  - ask's `landanir`: when the landing was registered, and when it was closed;
  - ask's `vigtanir`: each weighing's time;
  - LODS: the landing day.

  So a landing gives the end of its trip; the start comes from one of the four sources in §6. The landing's times
  may bound the arrival more tightly than its day.
- **The gear:**
  - agf's `veidarfaeri`;
  - LODS 2's `veidarf`, "the gear in the trip";
  - in ask, on the weighing note, so one landing may carry more than one gear. How often it does is measured.

  kvoti's `radst_vskyrslur` (1.37 M rows) holds, per vessel and month, the gears used, the crew and the days with
  landings.
- **The catch,** by species, storage method and condition (gutted or not), as weighed:
  - ask's `vigtanir`: 10.5 M weighings, with the fishing area and the factor `upphafsstudull` that converts a
    product's weight;
  - the `landanir_vnotur_*` views on it;
  - agf's base table;
  - LODS 2's `lods2_afli`.

Measured:
- whether a landing's gear agrees with the logbook's, and with the gear the flow infers (`voyage_gear`), by period;
- what `radst_vskyrslur` adds for vessels without a logbook;
- which weight each source holds (as landed, gutted, ungutted, after reweighing), and the factors that convert one to
  another.

## 5. Trip tables in the landings, all in kvoti

Neither ask nor agf has one. Found by name and column in kvoti (2026-10-16), none read by fishycode:
- **`veidiferdir`:** 3,407 trips, made 1991-1999, with start and end dates, port and arrival number (`komunr`).
  `veidiferd_afurd` (23,872 rows) holds the products of each trip.
- **`nyting_haus`:** 9,690 trips, 1999-2017, with "trip from" and "trip to" dates, the day landing began, port and
  arrival number. The products are in `nyting_linur`. Yield reports, most likely from processing vessels.
- **`tilkynningar`:** 13,199 notifications, 1998-2010, with trip number, area, catch and landing day. Its dates are
  partly garbled: years from 0001 to 2228.
- **`bradab_lods_afli`:** 404,877 provisional monthly rows by vessel, port and gear, with the number of trips and the
  catch by species.

Measured: which vessels and years each covers, and how its trips match its landings. Where it overlaps STK's trip
table, 2003-2017, the trips are matched with STK's, by vessel and dates. That is also a second check of the
notifications, beside the trail's (plan 022 §4).

## 6. At the end: each landing to its trip, from four sources

Once plan 022 has checked STK's trip table and put its notifications on vessels, and each period's landings are
settled (§3), each landing is matched with the trip that ends at it, by vessel, port and time. The trip comes from
each of four sources:
1. **The logbook trip,** where a logbook records the trip and its departure. It is read from `curated/`, not from the
   logbook schemas:
   - `logbook/trip.parquet`: `T1`, the departure, and `T2`, the return, with their ports. Twin trips are left out,
     as every consumer of the logbook must (decision 094).
   - `logbook/lid_map.parquet`: the trip → landing link that preprocessing already makes.
   - `link/trip_voyage.parquet`: trip ↔ voyage.
2. **kvoti's trip tables** (§5), 1991-2017.
3. **STK's notifications** (`tilk_stk_allt`), 2003-2021.
4. **The voyages cut from the track,** 2007 on.

The result, for each period and kind of vessel:
- how often the sources find the same trip for a landing;
- how far apart their departures are;
- the sources ranked as the flow's cascade would take them: the best first, each with its basis.

That ranking says where a landing can be given its trip's start, and from what.

## 7. How it runs

- **Personal data:** none is needed. Vessel, port and time are the keys, so tables of persons and companies are left
  out. So are the columns that name a person:
  - the seller in ask's `landanir`;
  - the buyer and receiver on its weighing notes;
  - an inspector's id number and the staff stamps in `nyting_haus`;
  - the captain in `tilkynningar`.

  Nothing personal enters this repository, which is public. This follows MFRI's gagnastefna on personal data.
- **Read-only:** it reads `raw/oracle/` and `curated/`, and writes to scratch. Nothing goes into `staging/` or
  `curated/`.
- **Alongside the rebuild:** the rebuild does not read or write `raw/`. No tracked file is edited while the build
  runs (`fd.dirty`); findings are written into this plan after it.
- **In this order,** in a session of its own:
  1. the source for each period, with its discrepancies (§3);
  2. gear and catch (§4);
  3. the trip tables (§5).

  None of these needs plan 022. Then, once plan 022's §3 and §4 are done and the rebuild is there: the trip tables
  matched with STK's (§5), and each landing with its trip from the four sources (§6).

## 8. Asks

1. **Where the knowledge sits:** who at the Directorate of Fisheries or MFRI IT knows what feeds LODS 1 and agf since
   2020?
2. **The write-up:** findings here, in plan 019's form, or a plan for each piece that turns out to matter?
