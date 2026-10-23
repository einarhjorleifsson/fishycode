# 041 — afli's monthly summaries back in the logbook: a coarser unit, each kilogram once

**status:** parked (the maintainer, 2026-10-23: "park this / put on hold") — written and measured read-only
2026-10-23; nothing built or changed; asks a-g (§7) open (TODO 136) · **2026-10-23** · **see:** plan 020 §6 and
`$FISHYDATA/archive/2026-10-logbook-notes/README.md` §3.1 (where the summaries were found), plan 038 §7.1 and decision
191 e (the catch units), plan 039 §2 (period 0, the landings' own vessel-months), decisions 084 and 094,
`docs/grammar.qmd` (§ What a row covers, § The coarser unit), `$FISHYDATA/archive/2026-10-afli-summaries/` (this
plan's script and log)

Drafted with AI assistance (Claude) on 2026-10-23, in a session started from the notes study (TODO 73). The design and
the numbers are Claude's; no person has checked them yet. The maintainer's words of 2026-10-23: keeping the summaries
apart "may have been the wrong decision"; they carry spatial information and belong in the logbooks.

**Measured** (by Claude, read-only): `raw/oracle/afli/{stofn,afli,toga,skikar}`, the staged afli hauls
(`staging/afli/`), fiskifelagid's weighing register (`vigtarskra66_81`), and what each reader of
`curated/logbook/{station,trip,fishing_sample,catch}` does with a station of 1953-1999 (code read, no data). The
script is `$FISHYDATA/archive/2026-10-afli-summaries/scripts/01_summaries.R`; every number below is in its log,
`results/01_summaries.log`, by section (1a-3c). **Assumed:**
- that rows identical in every value and consecutive in `visir` are parts of one source record (§1.3), until
  `ops$sigfus` is dumped and read (§6);
- that the summaries' weights follow the convention of afli's hauls of the same years: where both exist, the summary
  equals the hauls (§2);
- that `toga.togtimi` on a summary is minutes (§1.2).

## 0. Where this stands

- Today `sources/afli/convert.R` (l. 62-68) drops the 40,967 summary stations before it derives trips. It writes them
  to `staging/afli/aggregate.parquet`, which nothing reads (decision 084 l. 75: "not station rows here").
- Decision 191 e (2026-10-23) made them vessel × month × rectangle units of plan 038 §7.1's catch account, "after a
  check that they do not repeat stations already held".
- This plan says where the records live, which of them repeat records afli holds, and how their kilograms are counted
  once. It reverses decision 084's line for afli's monthly aggregates, and only that line.

## 1. What the summaries are

### 1.1 Three loads, one stamp each

Every afli station whose note says "samantekt" carries one of three stamps (40,967 of 40,967, log 1a):

| stamp in `stofn.aths_texti` | kind | stations | years | kt | species | old gear | vessel unknown |
|---|---|---:|---|---:|---|---|---:|
| `Frá OPS$SIGFUS.GAMALL_HUMAR, samantekt` | Nephrops | 26,405 | 1960-1999 | 82.8 | 40 | 9 | 5,023 (36.5 kt) |
| `Frá OPS$SIGFUS.GOMUL_RAEKJA, samantekt` | shrimp | 12,708 | 1953-1986 | 105.1 | 41 | 14 | 7 |
| `Frá afli.gomul_dragnot, samantekt, fjöldi kasta: N` | Danish seine | 1,854 | 1960-1966 | 11.5 | 23 (3 rows 56) | 5 | 1,854 |

- **Time:** each record is dated the 15th, and `veman` is that month in every row. `ldags` equals `vedags`. No
  departure or landing port is recorded. The day is a placeholder: the record's time is the month.
- **Place:** Nephrops and the seine give the statistical square (`reitur`); Nephrops gives the sub-square on 18,081
  rows. Shrimp gives a shrimp area (`skiki`), 25 codes. They are named grounds (Ísafjarðardjúp, Húnaflói, Arnarfjörður,
  Norðurkantur, ...). Of those codes, 24 are in `afli.skikar`, which maps each area to its squares (1 to 128). Code
  90, on one record, is not there. No record holds a position or a depth (log 1c, 1d).
- **Vessel:** Nephrops has no vessel on all records of the 1960s, and on 2,005 of the 1970s (`skipnr` 0 or empty).
  Those records are a fleet's month and square. The seine's `skipnr` holds the old table's own boat codes (−41 to 4,
  and 0): 46 codes, none a vid (log 1a, 1b).
- **Catch:** one species per record.

### 1.2 Effort is recorded

- **Tow minutes:** `toga.togtimi` holds the tow time on 26,402 Nephrops and 12,694 shrimp records.
  - Summed per vessel-month, it gives a median 192 tow hours for Nephrops and 69 for shrimp.
  - A summary's kg per tow hour (median 37.5 Nephrops, 115 shrimp) is near afli's own hauls of 1975-1999 (35.6,
    161). So the unit is minutes, summed over the month (log 1f).
  - 9 Nephrops and 29 shrimp vessel-months sum to more than a month's 744 hours, and are flagged.
- **Sets:** the seine's note gives the number of sets on every record (124,765 sets).

### 1.3 One source record, loaded as several rows

Some records repeat a row exactly: the same vessel, month, square, area, species, kg and tow minutes.
- **Nephrops:** 986 such groups (5,435 rows, up to 65 in one). Every one is consecutive in `visir`.
- **Shrimp:** 691 groups (2,494 rows, up to 155). Of them, 590 are consecutive.
- **Minimal splits:** every Nephrops group, and 630 shrimp groups, hold exactly as many rows as it takes to keep each
  row's tow time at or under 9,999 minutes. The tow time is a four-digit field (log 1g). So the loader split a record
  whose tow time did not fit, kg and minutes alike, into equal parts.
- **The parts add up:** the yearly totals bear this out. Nephrops 1966-1972 sums to fiskifelagid's weighed Nephrops
  within 1-2 % only when every part is counted (§2, log 3c).

The parts are kept as rows. Their sum is the record.

## 2. Which summaries repeat records afli already holds

**Vessel known.** The cell is vessel × month × gear × species. Its summaries are set against afli's hauls (staged
stations, both copies) with the same old gear code and species (log 2a):

| | vessel-months | summaries' kt | hauls' kt | summary over hauls (quantiles 5, 25, 50, 75, 95 %) |
|---|---:|---:|---:|---|
| Nephrops 1986-1999, with hauls | 2,290 | 20.6 | 21.4 | |
| Nephrops 1975-1985, with hauls | 137 | 0.93 | 0.95 | |
| Nephrops, all with hauls | 2,427 | 21.5 | 22.4 | 0.90, 0.97, 1.00, 1.00, 1.00 |
| shrimp 1975-1985, with hauls | 138 | 2.5 | 2.3 | 0.35, 0.88, 1.02, 1.55, 4.85 |
| Nephrops, no hauls | 3,115 | 24.8 | | |
| shrimp, no hauls | 7,538 | 102.6 | | |

- **Nephrops repeats its hauls.** Wherever a Nephrops summary has hauls in its cell, it equals or falls short of them
  (95th percentile 1.00). Ten vessel-months of 1975-1985 hold more, by 0.02 kt in all. In 1986-1999 every
  vessel-month but one has hauls. The summary was made from the hauls.
- **Shrimp is mixed.** Where both exist (138 vessel-months), the summary holds more than the hauls in 64 of them
  (0.6 kt more). Those hauls look like part of the month.
- **No repeat is missed by the gear code.** Of the 3,115 Nephrops vessel-months with no hauls, one has Nephrops on
  another gear that month (14 shrimp-trawl stations, 0.8 t). Shrimp has none (log 2b).

**Vessel unknown.** The cell is month × square × gear × species. The Nephrops fleet records of 1969 and 1970 hold
afli's hauls (log 2c, 3c):
- Of the 1969 summary cells, 82 of 89 hold hauls; up to 40 vessels' hauls fall in one cell.
- In 1969 the summaries sum to 3,586 t and the hauls to 2,129 t; the weighed Nephrops is 3,511 t. The summaries alone
  match the landings, and summaries plus hauls are 1.6 times them. 1970 is the same: 4,025 t and 868 t, against
  4,029 t weighed.
- In 9 cells the hauls hold more than the summary.
- No other year has an unknown-vessel summary in a cell with hauls. The seine (1960-1966) has none.

## 3. The design

### 3.1 Where they live: stations of type `monthly_aggregate` (recommended, ask a)

The grammar has the row type already: `station_type = "monthly_aggregate"`, "an aggregate over a month", keyed on
year, month, vessel, gear, rectangle. It also gives two ways to keep aggregates (`docs/grammar.qmd`, § What a row
covers). They can be **in their own table**, preferred when stations are the main source. Or they can be **as
stations**, with a synthetic trip, flagged.

Recommended: **as stations**, in `curated/logbook/{trip,station,fishing_sample,catch}.parquet`:
- **One table where totals close.** The grammar's § The coarser unit prefers one table with resolution "where totals
  must close": a sum over one table cannot lose a kilogram between two. An analyst who sums the logbook's catch by
  year or square then gets the summaries, and `station_type` tells them apart. Analysts already filter on
  `station_type` (`operation` or `event`) and on `twin`.
- **The same shape as plan 039.** Plan 039's period 0 keeps the landings' vessel-months as rows of the one landings
  table, at their resolution.
- **The flow's rule.** Records at any resolution, one output shape (plan 013 item 9). ramb's `record` is "a logbook
  record at any resolution".
- **The merge's account covers them unchanged.** `station_fate` and its checks (kg in = kept + dropped, per source)
  take the summaries as staging stations like any other. A table of their own would need an account of its own.

The cost is in the readers (§3.6). Two of them need a change, and the merge needs one section.

**Alternative:** `curated/logbook/monthly_aggregate.parquet`, written by its own target.
- Nothing downstream is invalidated or changed. A build is then one target, not the logbook chain.
- But the logbook's kilograms sit in two tables, and §7.1's account must read both.

### 3.2 The rows

| table | a summary's row |
|---|---|
| `station` | `.sid` = afli's `visir`. `date` = the 15th as recorded. `station_type` = `monthly_aggregate`, `station_type_basis` = `recorded` (the load's stamp says it). `sq` and `ssq` as recorded. `lon*`/`lat*`, `z1`/`z2` NA: no position is invented (the grammar's "rectangle's centre" is declined). New: `area`, the shrimp area code (`afli.skikar`), NA elsewhere. New: `part_of`, the first `.sid` of a split group (§1.3), NA elsewhere. |
| `trip` | One trip per vessel-month and kind. The vessel is the source's: the seine's code or `skipnr`. A fleet's records have no vessel, so their trip is a month and kind. `.tid` = the lowest `.sid` of its summaries (afli's own rule). `vid` is NA for the seine and the fleet records. `T1`, `T2` NA with `T1_basis`/`T2_basis` `none`: a vessel-month is not a trip, and no departure or return is known (ask b). Ports NA. |
| `fishing_sample` | The old gear code and its mapping (`curated/reference/gear`: 9 Humarvarpa and 14 Rækjuvarpa, `OTB` with `target2` NEP and SHR; 5 Dragnót, `SDN`). `t1`-`t4` NA. `duration_m` = the month's tow minutes, not limited by `R/duration_limit.R`, which bounds one haul, nor by the adapter's OTB NEP rule before 2000. Effort: tow minutes in gear-minutes; the seine's sets as `effort_count` with unit `setting`. Tow time over 744 hours a month gets a flag. |
| `catch` | The species and kg as recorded. Where hauls are taken out (§3.3), `catch` is the rest and `catch_raw` keeps the record's weight. |

The adapter reads the stamp: a comment column is the only sign of an aggregate, as the grammar says. It stages the
summaries as afli stations, trips, samples and catch, beside the others. Its own trip rule, `(copy, vid, T2, hid2)`,
is not applied to them. Measured: 164 afli hauls share a summary's vessel, `T2` and empty `hid2`, and that rule would
put them into the summary's trip. `staging/afli/aggregate.parquet` is retired.

### 3.3 The rule: each kilogram once (ask c)

Declared as a correction, `curate/corrections/afli_summary_repeat.yml`, beside `logbook_twin.yml`, and implemented in
the merge.
- **The cell.** For a known vessel it is vessel × month × gear (old code) × species. For an unknown vessel (the
  fleet's, the seine's codes) it is month × square or area × gear × species. Each cell's summaries are set against
  afli's hauls in it (both copies, duplicate twins left out).
- **No hauls:** the summary is the only record, kept as recorded.
- **Hauls holding at least 95 % of the summary's kg:** the summary repeats them. It leaves the curated tables, and
  `station_fate` gives `reason = "summary_repeats_hauls"`, `held_by = "afli"`. The 5 % is the notes study's tolerance.
  It takes a summary up to 5 % above its hauls as rounding. A summary at or below its hauls repeats them at any
  tolerance. Of the Nephrops vessel-months with hauls, 86 % agree within 5 % (log 2a).
- **Hauls holding less:** the summary is kept with the hauls' kg taken out. Each of the cell's rows keeps the same
  share, and `catch_raw` keeps what was recorded. Its basis is `derived`: the summary's own weight less the hauls'
  recorded weights (ask c).

| outcome (log 3a, the rule above) | cells | rows | recorded kt | in the logbook, kt |
|---|---:|---:|---:|---:|
| only record | 11,682 | 27,511 | 167.87 | 167.87 |
| kept less the hauls in it | 207 | 1,372 | 8.99 | 5.17 |
| repeats hauls | 2,501 | 12,084 | 22.54 | 0 |
| **all** | **14,390** | **40,967** | **199.40** | **173.04** |

- **The account closes:** 199.40 kt recorded = 173.04 kept + 3.82 held by hauls inside kept summaries + 22.54 in
  summaries that repeat hauls.
- **Kept by kind:** Nephrops 1960-1988 (58.3 kt), shrimp 1953-1986 (103.2 kt), Danish seine 1960-1966 (11.5 kt)
  (log 3b).
- **Against the weighed landings:** with the rule, the logbook's Nephrops matches fiskifelagid's weighed Nephrops in
  1966-1972 (0.99-1.02; 1969 1.02 and 1970 1.00, where the hauls were taken out of the fleet's records). It holds
  0.77-0.95 of them in 1973-1981, where the records name vessels (log 3c).
- **The simpler rule:** "out wherever a known vessel has hauls in the cell" would keep 172.43 kt (log 3a). It would
  drop 0.61 kt that only the summaries hold, nearly all of it in the 64 shrimp and 10 Nephrops vessel-months where the
  summary holds more than the hauls.

### 3.4 kg in = kg out in the merge

Every summary station is a staging station, so `station_fate` holds it. A new column, `kg_in_hauls`, is the weight
taken out of a kept summary (NA elsewhere). The merge's check becomes staging = kept in `catch` + dropped +
`kg_in_hauls`, per source. The vessel-day sets of the tiers (`afli_vid_date`) leave the summaries out: a summary
holds a month, not a day. No tier below afli holds a day before 2014, so nothing changes today. The twin rule never
sees them, since they have no times. `station_type`'s pattern (decision 084) leaves them out, and the merge sets
their type itself.
Otherwise a vessel-month with several squares would look like many records on the 15th: it would be typed `operation`
and would skew the vessel-year's pattern.

### 3.5 On the fixes: a unit of month × square

The flow takes a coarser record "within the record's period and area" (`docs/one_flow.qmd`, step 4). For catch,
`ramb::rb_add_catch_units()` already takes such a unit:
- `start`/`end` the month, `resolution = "month"`;
- `match_by` the square, or for shrimp the area's squares from `afli.skikar`.

`rb_share_catch()` would share its catch over the vessel's fishing fixes in that month and square, by effort, and move
it up a level where there are none. For Iceland the question never arises: the last kept summary is from 1988, and the
track starts in 2007. In plan 038 §7.1's `catch_unit` each summary is a unit of resolution vessel × month × square
(or area, or month × square with no vessel), outcome "no fixes that year", as decision 191 e has it. Effort on fixes
is unchanged.

### 3.6 The readers

What each reader of the four tables does with a summary station (code read 2026-10-23; no data):

| reader | today, with a summary in the tables | change |
|---|---|---|
| `curate/station_window.R` | would give it a day window on the 15th (`dayw`, `synthesised`); a vessel-NA trip is counted "no unambiguous vessel" | **leave out `monthly_aggregate`**: the month is not a day, and the catch unit (§3.5) carries it |
| `curate/checks/allocation_audit.R` | the station-trip link would call it "trip or station undated" | **an outcome of its own**, "monthly aggregate", so it is not counted as a defect |
| `curate/link_lid_map.R` | `T2` NA: never linked (step 9 drops a missing date) | none. Month bounds as `T2` would compete with real trips for LODS landings from 1992 (ask b) |
| `curate/catch_by_species_station.R` | a row per station and species, whole weight | none: analysts get the summaries' catch here, with `station_type` |
| `curate/catch_by_species_trip.R`, `checks/landed_logged.R` | sum catch only on trips with a landing | none |
| `curate/trip_reconciled.R` | a row per trip, basis `none` (no witness) | none |
| `curate/link_trip_voyage.R` | counted in afli's denominator, never linked | none (11,000 trips beside 1.66 M) |
| `curate/corrections/logbook_gear.R` | a gear row per station | none |
| `reference/species/species.R` | stops on an unknown species code | none (40, 41, 23, 56 are known) |
| `products/vessel_overview/` | vessel-NA records never shown; with `T2` NA a vessel-month leaves the year queries | none |
| AIS-side readers (`ais_trail`, `ais_catch`, `trail_sql`, `station_event`, `voyage_gear`), the checks from 2004 or later, the data call | never see 1953-1999 | none |

## 4. Steps

1. **Read `ops$sigfus`** once the maintainer has run its dump (`dump/oracle/ops_sigfus.R`), and check the summaries
   against it (§6), before any code.
2. **Code:**
   - the adapter stages the summaries (§3.2);
   - the merge applies the rule and the account (§3.3, §3.4);
   - `station_window.R` and the audit change (§3.6);
   - the correction's declaration; `docs/grammar_logbooks.qmd` (its "Option A" passage) and `docs/output-schema.md`
     (the `aggregate.parquet` section) rewritten; `docs/data-dict.yaml` gets `area`, `part_of`, `catch_raw`,
     `kg_in_hauls`.
3. **Test on a scratch store:**
   - the adapter and the merge, the account closing;
   - the kept kilograms as in §3.3;
   - every curated row that is not a summary identical to the store's;
   - `station_window` with no summary in it.
4. **Build by name** with `tar_make_isolated()`, on the maintainer's go: `afli`, its two correction targets and the
   logbook chain (about 20 targets, as decision 205). Fingerprints before and after. Best joined to the next rebuild of
   that chain (ask f).
5. **Record:** a decision, an amendment to decision 084's line, and plan 038 §7.1's scope (the summaries are units).

## 5. What it does not do

- It does not join the summaries to the landings of their month. That is plan 039's period 0, a vessel-month against a
  vessel-month, when it is built.
- It does not raise the 1973-1981 Nephrops to the weighed landings.
- It does not give the fleet's and the seine's records a vessel.
- The 21 Nephrops squares with no haul inside a vessel-month that has hauls elsewhere (0.07 kt) are not kept apart.
  The cell is the vessel-month.

## 6. What `ops$sigfus` should settle

`ops$sigfus` is the source: `gamall_humar` 20,949 rows, `gomul_raekja` 10,531 and `gomul_dragnot` 2,792 (catalogue of
2025-03-31). `ops$rafn.afli_gomul_dragnot` (1,855 rows) is the seine's load copy. Not dumped yet. Read by counts and
columns first (decision 159).
- **The parts:**
  - afli's Nephrops rows less the split parts' extra rows leave 21,956 records, against 20,949;
  - shrimp leaves 10,905, against 10,531.
  - Does each source row match one record or group, at the same kg and minutes?
- **The vessel:**
  - does `gamall_humar` name a vessel for the fleet's records of 1960-1972?
  - does `gomul_dragnot` say what the seine's codes stand for?
- **The rows not loaded:** `gomul_dragnot` holds 2,792 rows, of which afli has 1,854. What are the rest?
- **The units:** Nephrops as whole weight or tails, and tow time in minutes.

## 7. Asks

a. **Where:** as stations of type `monthly_aggregate` in the logbook's own tables (recommended), or a table of their own
   in `curated/logbook/` (§3.1)?
b. **The trip:** one per vessel-month with `T1`/`T2` NA, basis `none` (recommended), the month's first and last day
   (which would compete for landings from 1992), or no trip at all? With no trip, a station carries no vessel.
c. **The rule** (§3.3): one rule at 5 % for both kinds of cell, with the rest kept where hauls hold less (recommended;
   173.04 kt), or out wherever a known vessel has hauls (172.43 kt)? And the basis of a summary's weight with the
   hauls taken out: `derived` (recommended) or `synthesised`?
d. **The split parts:** kept as rows with `part_of` (recommended), or summed to one row per source record (which drops
   rows Oracle holds)?
e. **The shrimp area:** a column `area` with `afli.skikar`'s codes (recommended), with the area-to-squares table
   staged only when something needs it?
f. **When:** built with the next rebuild of the logbook chain (recommended), or on its own?
g. **`ops$sigfus` first:** read the dump before coding (recommended), or code now and check after?
