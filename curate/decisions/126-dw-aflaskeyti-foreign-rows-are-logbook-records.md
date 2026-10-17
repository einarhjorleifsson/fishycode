# 126 — dw_aflaskeyti measured: its Norwegian and Faroese rows are haul-level logbook records, 2014-2018

*2026-10-17. Written by Claude (AI-assisted). The maintainer first chose to leave the table out of the logbook and the
landings, then asked for a proper analysis: "if these are true logbook records (position, gear, catch, ...) we may
want to include them". Measured read-only on `raw/oracle/dw/dw_aflaskeyti.parquet` (dumped 2026-10-17, decision 122)
against witnesses that never read it: `curated/ais/trail/`, `curated/landing/`, `curated/logbook/` and
`curated/vessel/vessel.parquet`. Nothing was written under `$FISHYDATA`. The maintainer took the recommendation
the same day; the design is plan 026.*

## What the table is

The Directorate's data warehouse copy of the ERS catch messages Iceland exchanged with Norway and the Faroes.

- 21,627 rows, one per haul and species, from 3,756 messages. Every row is a catch report (`ers_type` DCA, `virk`
  J). There are no departure, return, landing or correction messages.
- Hauls from 2014-01-20 to 2018-06-08, loaded from 2015-09-28 (the 2014 messages in one batch) to 2018-06-14, when
  the load stopped.

| flag | rows | vessels | hauls | kt | where |
|---|---|---|---|---|---|
| ISL | 15,317 | 33 | 5,050 | 254.2 | Norwegian and Faroese waters, reported to Norway and the Faroes |
| NOR | 3,205 | 93 | 2,138 | 264.6 | 2,130 of the hauls in Icelandic waters |
| FRO | 3,105 | 18 | 640 | 15.8 | all in Icelandic waters, from 2017-10-14 |

The counts are of the rows as dumped, so a haul sent in more than one message counts once per message. Taking the
latest message of each haul, as the adapter does (plan 026 §1), leaves 4,992 Icelandic hauls and 236.8 kt; Norway
2,138 hauls and 264.5 kt (one 80 t row was sent twice); the Faroes unchanged.

## Are the foreign rows logbook records?

- **One record per haul.** 2,777 of the 2,778 foreign hauls are in one message, with one row per species (one
  duplicate). No vessel's hauls overlap in time. No position, time, duration, gear, species or kg is missing.
- **Position and time, against AIS.** The trail fix nearest t2 (within 15 min) lies a median 0.12 nm from the
  reported start for Norwegian purse seines (`PS_2`, 696 hauls), 0.16 nm (`PS`, 279) and 0.61 nm (`PS_1`, 534). At t3
  the fix lies 0.04-0.60 nm from the reported end. AIS speed is a median 0.7 kn inside the haul and about 6 kn in
  the 6 hours before it. Norwegian longlines: 0.34 nm (`LL`, 91); `LLS` (70) lie 3.4 nm off at the start and 0.12 nm at
  the end.
- **Faroese times are local.** Faroese longlines (`LLS`, 472) lie 5.1 nm off. On the 259 hauls from 2018-03-25,
  summer time, a shift of −60 min fits best: 1.8 nm, against 5.7 nm unshifted. On the 205 before it, no shift
  fits better than 0 to +15 min (3.0 nm). The summer-time days of 2017-10-14..28 were not tested separately.
- **Gear and species in Icelandic codes.** `id_veidarfaeri` is the Directorate's gear code (1 longline, 6 bottom
  trawl, 7 pelagic trawl, 14 shrimp trawl, 56 and 57 purse seine with one or two boats), with the FAO code beside it.
  `id_fisktegund` is the Icelandic species code (1 cod, 31 capelin, 34 blue whiting), also with the FAO code.
- **Catch, against landings in Iceland.** The 111 vessels landed 918 times in Iceland from 2013-12 to 2018-07 (104
  vessels, 486.9 kt). 317 of those landings have ERS hauls in the 45 days before. For the 279 Norwegian ones, 144.0 kt
  was reported and 140.7 kt landed (0.98); for capelin, 136.4 against 138.2 kt (1.01). For the 38 Faroese ones, 11.3
  kt was reported and 12.5 kt landed (1.11). Demersal species were landed 5-13 % heavier (median per landing).
- **Completeness, against AIS.** The proxy is a vessel-day with at least 3 fixes marked `fishing_flow` in ICES 5.a,
  not the truth.
  - Norway: every Norwegian vessel that AIS shows fishing there is in the feed. The days with an ERS haul are 29 of
    48 (2014), 107 of 132 (2015), 221 of 311 (2016), 158 of 210 (2017) and 215 of 306 (2018, to 06-08).
  - Faroes: 16-18 vessels fish there every year, about 700 vessel-days a year, none of them in the feed before
    2017-10. In 2017 the feed has 12 of 674 days, in 2018 490 of 570.
- **No overlap.** The curated logbook holds no station of the 111 vessels in 2014-2018.

Within its span, then, each foreign row records one haul: its time, start and end position, gear, species and kg,
each confirmed by a source that never read the table. The faults are known and can be repaired:

- the coordinates are swapped on every row (below);
- Faroese times are local in summer;
- 63 hauls have duration 0: 41 Faroese and 9 Norwegian purse seine sets, and 13 Norwegian `LL` hauls;
- Norwegian `LL` hauls repeat the start position as the end.

What the rows lack is the trip.

## How to read it

Measured on the Icelandic rows, matched to their own logbook stations by vid and time (duplicates left out):

- **Latitude and longitude are swapped.** `lengd_byrjun` and `lengd_endir` hold latitude, and `breidd_byrjun` and
  `breidd_endir` hold longitude, though *lengd* means longitude. After swapping, 4,716 of 5,050 hauls agree with a
  station to a median of 0.005° in each coordinate; read as named, they are 53° off.
- **`dagsetning_hols_dt` is t2.** 4,716 hauls match a station's t2 within a minute (median 0 min). t3 matches in 15.
- **`lengd_hols` is t3 − t2 in minutes.** Equal within a minute in 4,693 of the 4,716.
- **`id_skip` is the vid.** All 144 resolve in `vessel.parquet` and 141 carry the same flag. The other three are
  Norwegian vessels whose flag there is `UNK`. `skip_id` is the warehouse's own key, one for each vid, not the IMO.
- **The weight of demersal species varies.** Blue whiting is equal in 578 of 582 station-species pairs. Cod,
  haddock, saithe, ling and tusk are either equal, or the logbook holds 1.25 × the ERS weight (cod: 1,231 of 4,073
  equal, median 1.25), in every year. `afli_athugasemd` reads "live weight in kg." on every row, and `afli_fjoldi`
  equals `afli_kg` on every row.
- `id_veidisvaedi` is the zone as a letter (`I` ISL, `X` NOR, `O` FRO, `H` Svalbard).

## The Icelandic rows

They are not needed: 4,716 of the 5,050 hauls are in the Icelandic logbook. The same haul is often sent again, 1,131
of them in two or more messages. Of the other 294 hauls (3.7 kt, mostly 2014-2015), 282 lie on 86 vessel-days that
the Icelandic logbook lacks entirely; by vessel and start time they are 280 hauls, two of them sent again with a
corrected position (plan 026 §11). They could fill those days, as adb fills the days fs_afladagbok lacks.

## What including the foreign rows would take

- **An adapter**, `sources/aflaskeyti/convert.R`, staging the four tables.
- **Two corrections** in `curate/corrections/`, declared with the evidence above: the coordinate swap and the
  Faroese summer time. They do not belong in the adapter (AGENTS.md).
- **A trip, which the data lack.** Either the hauls up to a landing in Iceland within 45 days, with a gap rule for
  the rest, or a gap rule alone, with basis `reconstructed`. A landing in Iceland follows 144.0 of the 264.6 Norwegian
  kt and 11.3 of the 15.8 Faroese kt. The flow's trip ↔ voyage step reconciles either with the track.
- **A tier in `curate/logbook.R`** for the foreign vids. None of them overlap.
- **The span stated on the table and on the docs page.** Foreign records exist only from 2014-01 to 2018-06. They
  are whole by vessel for Norway from 2014 and for the Faroes only from 2017-10, and foreign fishing outside that
  span takes the pings path. That is the cascade as designed: each step takes the best source it has and records
  the basis.

**Claude's recommendation:** include the Norwegian and Faroese rows as a logbook source, with the two corrections and
trips from landings in Iceland where one follows, else a gap rule. Keep the Icelandic rows out, except, if wanted,
the 282 hauls on vessel-days the Icelandic logbook lacks.

**The choice (maintainer, 2026-10-17):** include them, plan first. Plan 026 is the design; whether the 282 Icelandic
hauls come too is its ask a. Nothing is built.

## The rest of the feed, and other leads

- **`dwstg`'s load history.** `stg_catch_haul_hst`, `stg_catch_log_hst` and `stg_catch_species_hst` hold 16,035,
  11,037 and 38,796 rows by Oracle's estimates (against `dw_aflaskeyti`'s 21,627), and `stg_port_notification_hst`
  holds 601. By their names they are the same feed, and the port notifications could give trips their ports. They are
  worth a dump if the foreign rows are taken in.
- **`ops$sigfus`'s foreign tables.** `erlend_afli`, `erlend_sokn` and `erlend_samantekt` (3,049, 2,843 and 466 rows)
  are foreign catch and effort, aggregated by the look of them. They are not dumped.
- **2019-2025.** For Norwegian vessels the lead is Norway's open ERS data. `sources/norway/logbooks.R` reads them,
  but it is not a target, it reads from `staging/` instead of `raw/`, and the files are not on disk. The Faroese half
  has no lead.
