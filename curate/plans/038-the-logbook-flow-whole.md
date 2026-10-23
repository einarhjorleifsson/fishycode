# 038 — The logbook flow, whole: from each logbook source to its trips, stations and catch on the AIS fixes

**status:** proposal — written 2026-10-22 at the maintainer's request; nothing built or changed; the baseline measured
read-only on the store as built at f05de18 (§1); the split with plan 039 agreed between the sessions (§0); nine asks
open (§9, TODO 122) · **2026-10-22** · **see:** `docs/one_flow.qmd` (the cascade and what is built where),
`docs/grammar.qmd`, TODO 121 and decisions 155, 160 and 165-174, plans 019, 020, 024, 026, 027, 031, 036, 037, 039 and 040

Drafted with AI assistance (Claude) on 2026-10-22. The maintainer asked whether to plan the full logbook flow next,
after decisions 170-174. Every number below is Claude's and has not been checked by a person.

**Measured** (read-only, by Claude, 2026-10-22): `curated/logbook/`, `curated/link/`, the first year of
`curated/ais/trail/`, and `curated/check/{allocation_audit,trail_sid_coverage}.parquet`, as built at f05de18 (decision
160's rebuild). Also `staging/afli/aggregate.parquet`, fs_afladagbok's tour app (`tour`, `fishing_spot`, `catch` in
`raw/oracle/fs_afladagbok/`) and the years of `raw/oracle/stk/trail/`. **Cited:** the numbers of decisions 155 and
157-174 and of plans 019, 024, 026, 027, 034, 036 and 037, each where it is used. **Assumed:** that the pending
rebuild (36 targets, TODO 119 and 121) moves the baseline's proportions no more than decision 160's rebuild did
(253 t); that a tour-app trip and a logbook trip of one vessel-day are one trip (plan 019's assumption).

The plan orders what exists, step by step, and designs only two things no record designs yet: what reads the
reconciled trip (§5.1, decision 174's open end), and the logbook's kilograms accounted over every year, not only
the years with fixes (§7.1). Every other open piece is a TODO item or a plan already, and is named by its number.

## 0. The split with the landings plan

A parallel session planned the full landings flow: plan 039 (`039-the-landings-flow.md`). The trip ↔ landing link,
the return time `T2` and the quota system's regime and gear are shared ground. This plan proposed the split below,
and plan 039 §0 answers it, quoting it word for word. The answer is quoted here in the same words.

- **This plan:** the logbook sources and their layers (afli, afli_sent, fs_afladagbok's `ws_*` and tour app, adb
  from 2025-11-19, aflaskeyti); `curate/logbook.R` and its corrections; `trip_reconciled` (`T1`, `pid1`, `T2`,
  `pid2`); the stations on the fixes; the effort; and the logbook's catch on the fixes. It also designs the trip ↔
  landing link, keyed by logbook trip: `lid_map` and plan 027's flow table `trip_landing`.
- **The landings plan:** the landings sources and their layers (LODS, ask, agf, kvoti), `curate/landing.R`, and what
  one landing record is: its time (ask's first weighing, plan 025's `t_weighed`), port, gear, catch and disposition
  (plan 036). It also owns every landing the link leaves unclaimed, which reaches the fixes through the voyages
  (`ais_catch.R`'s unit 4). It stages the quota system's regime, gear code and hand-baited line flag as attributes of
  the landing, since `quota_trip` is keyed by landing.
- **Shared, one owner each:**
  - **The link:** this plan designs it. The landings plan states what each landing brings to it.
  - **The return:** `trip_reconciled` owns the reconciled `T2`. The landing is its last witness, and the landings
    plan supplies the landing's time.
  - **Regime and gear:** the landings plan stages them on the landing. This plan carries them onto the trip through
    the link, and into the gear cascade.

**Answer** (plan 039's session, 2026-10-22): agreed, with three additions.
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

(The section and ask letters in the answer are plan 039's.) This plan designs addition 1's step and builds addition
2's change, both in §4 and in step 3 of §8, and reads addition 3's columns in §4 and ask d.

## 1. The flow as built, and the baseline

| Step | Scripts (side) | Output | ramb | Built |
|---|---|---|---|---|
| L1 sources and layers | `sources/{afli,afli_sent,fs_afladagbok,adb,aflaskeyti}/`; the trip witnesses `sources/{stk/voyage,quota_trip,phone_call}/` (preprocessing) | `staging/<source>/` | — | the logbooks; `afli_sent` staged on a scratch store and read by nothing (plan 037); the trip witnesses coded, not built (TODO 121) |
| L2 merge and corrections | `curate/logbook.R`, `curate/aflaskeyti_trip.R`, `curate/corrections/`, `logbook_gear.R`, `catch_by_species_station.R` (preprocessing) | `curated/logbook/{trip,station,fishing_sample,catch,gear,catch_by_species_station}` | — | built |
| L3 trip ↔ landing | `curate/link_lid_map.R`, `catch_by_species_trip.R` (preprocessing) | `curated/logbook/{lid_map,catch_by_species_trip}` | — | built |
| L4 the trip reconciled | `curate/link_trip_voyage.R`, `curate/trip_reconciled.R` (flow, step 1) | `curated/link/{trip_voyage,trip_reconciled}` | `rb_link_trip_voyages`, `rb_add_trip_time` | `trip_voyage` built; `trip_reconciled` coded, not built (TODO 121) |
| L5 stations on fixes | `station_window.R`, `link_station_event.R`, `voyage_gear.R`, `ais_trail.R` (flow, steps 2-4) | `station_window`, `station_event`, `voyage_gear`, `curated/ais/{trail,trail_match}` | `rb_create_record_windows`, `rb_link_record_events`, `rb_add_record`, `rb_add_fishing` | built |
| L6 effort and catch | `ais_trail.R` (effort), `ais_catch.R` (flow, steps 5-6) | the trail's `hours`, `kw_hours`; `curated/ais/catch` | `rb_add_effort`, `rb_add_catch_units`, `rb_share_catch`, `rb_link_trip_landings` | built |
| checks | `curate/checks/{allocation_audit,landed_logged,trail_sid_coverage,survey_tow_times,port_call_logbook}.R` | `curated/check/` | — | built |

**Measured** (by Claude, the build at f05de18). Trips and stations are rows, twins included; kg leaves the duplicate
twins out:

| logbook | dates in the merge | trips | stations | kt | trips with a landing (`lid_map`) | trips on a voyage | stations with a fix, 2008 on |
|---|---|---:|---:|---:|---:|---:|---:|
| afli | 1950 to 2024-06 | 1,661,056 | 6,844,739 | 45,936.7 | 638,460 | 644,600 | 98.3 % of 1,784,558 |
| fs_afladagbok | 2020 to 2025-12-12 | 154,534 | 374,681 | 3,899.4 | 149,720 | 147,752 | 97.0 % of 370,322 |
| adb | from 2025-11-19 | 37,878 | 88,464 | 834.7 | 37,344 | 37,342 | 97.5 % of 88,200 |
| aflaskeyti | 2014-01 to 2018-06 | 595 | 3,058 | 283.0 | 521 | 481 | 83.6 % of 3,058 (99.8 % of those heard) |

The logbook's kilograms by period, against decision 155's audit of the catch on the fixes. Stations deleted in the
source and duplicate twins are left out:

| period | stations | kt logged | kt on fixes | kt on a unit with no fix |
|---|---:|---:|---:|---:|
| before 1990 | 1,301,503 | 2,727.9 | — | — |
| 1990-2002 | 2,735,190 | 18,394.8 | — | — |
| 2003-2006 | 719,648 | 6,504.4 | — | — |
| 2007 on | 2,380,060 | 23,322.5 | 22,414.6 | 908.3 (797.2 of it in 2007; 0.0-21.3 a year after) |

So 27.6 of the logbook's 50.9 Mt (54 %) is logged before 2007, and the flow gives it no unit at all. The trail
starts in 2007, and so does the STK trail Oracle holds (2007-02-09, with 9,820 stray positions in 2006). Before that,
STK has voyages (port events from 2003-09, decision 172) but no positions. Within the years with fixes, kg in
equals kg out but for two outcomes the audit leaves unexplained: 4.2 kt deleted in the source, and 57 t on stations
with no window (TODO 101).

## 2. L1: the sources and their layers

Plan 037 is the design for layers: one adapter per layer, and the choice between layers made only in `curate/`, by
a declared precedence per field group. This plan does not restate it. Source by source:

- **afli** (MFRI's logbook, 1950 to 2024-06; electronic from 2008). The adapter reads the edited layer (`afli.*`) and
  fs_afli's paper stations (decision 124). The sent layer is staged by `sources/afli_sent/convert.R` (plan 037 §2.1,
  ask i) and is read by nothing yet. Open:
  - plan 037 phase 2, the sent layer chosen per field group: TODO 108 (positions, `TOGTIMI`, `KLST`, `FAERSLA_LOKUD`),
    113 (the end depth) and 114 (catch as logged);
  - TODO 118 (23,513 loaded hauls, not deleted, that never reached `afli.stofn`), 75 (410 trips lost whole; 1,854
    rows before 2007-09) and 70 (stored values `TO_CHAR` rejects);
  - TODO 98 and 100, the logger and the sensors.

  **Measured:** the adapter stages afli's monthly summaries in `staging/afli/aggregate.parquet` (40,967 records,
  199.4 kt: nephrops 1960-1999, shrimp 1953-1986, Danish seine 1960-1966), and nothing curated reads them (ask e).
- **fs_afladagbok** (the e-logbook's dump of record, 2020 to 2025-12-12, decision 160). The `ws_*` tables are read.
  The tour app (2020-01 to 2022-03, 35,792 trips) is not (plan 019 §4 and ask 1, TODO 73). **Measured:** 6,991
  tour-app trips (7,864 fishing spots, 9.2 kt without 10 catch rows over 20 t; most of them in 2020) fall on
  vessel-days that no curated source holds. Decision 171 found 9,374 of plan 019's 9,821 unimported tour trips in
  adb as `APP TÖFLUR`. adb is no longer read before 2025-11-19 (decision 160), so the tour app is now the only route
  in. Whether these trips entered through adb before decision 160 is not measured here. *Counted 2026-10-23 by
  Claude, not checked by a person:* adb's 9,374 `APP TÖFLUR` trips carry 428 stations and 2 catch rows, so their
  catch never entered through adb; the 9.2 kt is the unread tour app, not a loss of decision 160. Plan 019's asks
  2-7 and plan 020 (`gear_part`, `environment`) stand as written. The change tables (`ws_*_breytingar`) are plan 037
  phase 4.
- **adb** (MFRI's copy of the Directorate's records, decision 171), from 2025-11-19 only (decision 160), and read
  from tables, not views (decisions 165, 170). Open:
  - its ports have no `pid` in `curated/logbook/trip.parquet` (decision 172), so each reader maps them itself (ask f);
  - `duration_m` is empty on its trawls and dredges (TODO 107);
  - adb's conversion faults (shrimp and Nephrops trawl written as bottom trawl, zeros for NULLs, catch lacking; decision
    171) end before 2025, outside the dates read. Nothing would see them come back (ask h).

  The header of `curate/logbook.R` still calls adb "derived from" fs_afladagbok, which decision 171 corrected
  everywhere else. That changes when the script is next opened.
- **aflaskeyti** (the ERS catch reports, 2014-2018; plan 026). Built (decisions 127, 129). The foreign logbooks of
  2019-2025 are not held (TODO 62).
- **The trip witnesses**, which are not logbooks: STK's voyages, the quota system's trip records (line incentive
  2004-2020, coastal fishing 2009-2023) and the phone calls. They are coded and staged on a scratch store only (TODO
  121). Plan 023 names two small trip tables in kvoti that decision 172 does not weigh: `veidiferdir` (3,407 trips,
  1991-1999) and `nyting_haus` (9,690 trips, 1999-2017) (ask i).
- **Out of scope:** the `logbook` schema, a trial of derived afli trips (maintainer, 2026-10-21); the flow before
  1990 (decision 103), but see ask e.

**Order within L1:** plan 037 phase 1 (the precedence table; the whole weight read by name); plan 019's tour app,
the largest gap in held records measured here; plan 037 phase 2 (afli's sent layer); TODO 62 when the data come.

## 3. L2: the merge and the corrections (`curate/logbook.R`)

**Built:** tiers by vessel-day (afli, fs_afladagbok, fs_afli's paper stations, adb from 2025-11-19, aflaskeyti),
with each correction as a side table (depth, end longitude, adb's longitude sign, aflaskeyti's three). Also the twin
records (decision 094), the station type (decision 084) and the placeholder set times (decision 157). Beside it,
`logbook_gear.R` sets each station's gear: the landing's where it names one metier, adb's own code (decisions 066,
154). `catch_by_species_station.R` gives the whole weight.

**Measured:**
- on the build of 2026-10-16 (plan 024 §2): 702,988 staging stations dropped (8,131 kt), and 99 % of the vessel-days
  that hold them are copies of what is kept. Nothing records a drop;
- at f05de18: duplicate twins are 5,813 afli, 3,696 fs_afladagbok and 264 adb stations;
- stations dated outside their own trip: 3.5 % of adb's and 3.0 % of fs_afladagbok's (TODO 101).

**Open:**
- TODO 79 (plan 024's `station_fate`, asks a-d);
- TODO 102 (trips overlapping another trip of the same vessel: afli 21,220, fs_afladagbok 4,116, adb 624);
- TODO 103 and 107 (app-made times);
- TODO 113 and 114 (parked for plan 037);
- TODO 111 (the column tables in `docs/output-schema.md`);
- adb's `pid` (ask f).

**Proposed:** no new rule. Plan 024's `station_fate` is written by the merge itself. Each later source change (the
tour app, the sent layer, TODO 118's hauls) then shows as rows moving between outcomes, measured before it is built.
This is why plan 024 comes first in §8.

## 4. L3: the trip ↔ landing link (`lid_map`)

**Built:** a nine-step cascade in preprocessing, reading no AIS (plan 014). Since plan 034 it includes trips with no
catch, and step 9 matches by order. The landing's date, port and `pid` are carried on the link.

**Measured:**
- matched trips: afli 638,460, fs_afladagbok 149,720, adb 37,344, aflaskeyti 521. 93 % of afli's are exact
  (593,373), 95 % of fs_afladagbok's (142,051) and 96 % of adb's (35,900);
- the link reads landings from 2007-09-01 only. afli's 234,256 trips of 2003-2006 have no landing, and 2007 has
  11,494 of 44,063. Plan 039 measured what a match on LODS would find for afli's 704,004 trips of 1992-09 to 2006:
  613,679 at the same vessel, day and port, 73,414 more within a day or with the port dropped, and 16,911 none
  (`$FISHYDATA/archive/2026-10-landings-flow/04_lid_map_before_2007.log`). It also measured what the bound costs on
  the fixes: the landings of June-August 2007, unclaimed, put 40.2, 50.3 and 40.2 kt a month there (approach
  `fishing`) beside their trips' logged catch, against 5.7-8.7 kt a month in June-August 2008 (`06`);
- decision 155's audit of each link against the voyages: the landing falls on the voyage's end day at the same port
  for 220,077 afli, 112,574 fs_afladagbok and 27,897 adb trips. It falls before the voyage ended for 10,633, 3,212
  and 1,711, and more than a day after for 6,377, 3,699 and 724. 4,870 of those landed before the voyage ended are a
  trip matched to a landing made before it finished (TODO 81).

**Open:**
- TODO 81 (plan 027: a trip's further landings, the flow table `trip_landing`, asks a-d);
- TODO 112 (plan 036: the 159 part off 4,073 trips, 107.6 kt);
- TODO 74, with the landings plan: plan 007's question 3 (the link keys on `.lid` alone; 104,192 ids are shared
  between agf and lods) and plan 025's `withdrawn` (631 trips matched to zero-kg landings);
- the link before 2007-09: the bound's lifting, proposed by plan 039 (its ask e) and built here, and the month step,
  designed here (plan 039 §0, additions 1 and 2);
- TODO 75 (lost trips that have a landing).

**Proposed:** `lid_map` stays the declarations' own match. AGENTS.md says the reconciled trip is never fed back into
it. Plan 027's `trip_landing` becomes the flow's link: `lid_map`'s pairs, plus the further landings. Its track rule
is restated on the reconciled trip: a landing that follows the trip's reconciled return, before the vessel's next
reconciled departure, joins that trip. The regime, gear and line flag of each landing reach the trip through
`trip_landing`, counted where its landings disagree. `ais_catch.R` then reads `trip_landing`, not `lid_map`.

Two changes to `lid_map` itself, from plan 039 §0:
- **The lower bound goes** (plan 039's ask e, built here). `lid_map` reads the landings of every period plan 039
  supplies, LODS from 1992-09 with the same nine steps. The 2007 surplus on the fixes is the measure that the bound is gone. Before it is built, the
  steps are run on 1992-09 to 2007-08 in scratch, and each trip lands in one outcome: matched by step, or none.
- **A month step for the years before LODS.** `fiskifelagid` (1966-1981) and `vor` (1982 to 1992-08) give a vessel's
  month, not a landing. A new last step joins a vessel's trips whose `T2` falls in a month to that month's row, many
  to one, as `match_type` `10 month`, with `n_trips` as for any shared landing. The catch then compares by
  vessel-month, not by trip. The years it reaches depend on ask e.

## 5. L4: the trip reconciled

**Built:** `trip_voyage` (the voyage that overlaps a trip most; 644,600 afli, 147,752 fs_afladagbok, 37,342 adb and
481 aflaskeyti trips). `trip_reconciled` is coded and tested on a scratch store (decisions 173, 174). It takes `T1`,
`pid1`, `T2` and `pid2` from ranked witnesses: AIS, the logbook's own, STK, the quota system, the phones, and the
landing last for `T2`.

**Measured** (decisions 172-174, scratch):
- a departure time on 1,029,869 of 1,853,260 trips, and a return time on all but 122 (837,307 of them dates only);
- AIS against the logbook's own: a median of 13-14 min at the departure (76-77 % within 1 h) and 29-31 min at the
  return (65 %);
- 798,111 afli trips before 2004 have no departure witness. Their `T1` stays the first fishing day.

**Open:**
- TODO 121 (the build);
- what reads the result (§5.1);
- the quota regime and gear on the trips (ask d);
- adb's `pid` (ask f);
- `trip_voyage` gives a trip one voyage, so the AIS witness of a trip that spans voyages is one voyage's bounds. That
  is TODO 90 (plan 031 ask f, many-to-many) and the first item of TODO 101. On such a trip `T1` and `T2` from AIS are
  the bounds of the one linked voyage, not the trip's; decision 155 counted 13,084 trips with timed stations in two or
  more voyages (noted 2026-10-23 from Claude's audit, not checked by a person; also in decisions 173 and 174);
- TODO 117 (what the voyages take from STK's events).

### 5.1 What reads the reconciled trip (proposed)

Each reader switches only after a scratch build has measured it: the fixes that change trip, and the catch traced
kilogram by kilogram (plan 037 §6). The declared times stay in `trip.parquet`, and nothing feeds `lid_map`.

a. **The trail's trip.** Today a fix outside every window takes the logbook trip of its voyage only where the voyage
   has exactly one (`.tid_voyage`). The audit counts 2.44 M afli fixes on voyages that name no trip, 0.34 M naming
   another trip and 3.53 M on voyages shared by trips. Proposed: a fix also takes the trip whose reconciled `T1` to
   `T2` holds it (`.tid_trip`, with the basis of the witness), one fix to one trip, beside `.tid_voyage`, which is
   kept. This is the one-flow's step 1 (`assign_trip`) on the declared trips.
b. **`ais_catch.R`'s unit 3**, a logbook trip from `T1` to the day after `T2`: the reconciled times as its bounds,
   so catch moved up a level lands on the trip's own fixes.
c. **The day windows:** a date-only station's day window clipped to its reconciled trip, so no window is open before
   the departure or after the return. TODO 105's stretch past midnight keeps within the same bounds.
d. **`trip_landing`** (§4).
e. **The audit:** the station ↔ trip and trip ↔ landing tests read the reconciled times too, beside the declared
   ones.

## 6. L5: the stations on the fixes

**Built:**
- `logbook_gear` (the gear and metier of each station);
- `station_window`, one row per station and phase, with `win_basis`, one fix to one record (decisions 090, 091);
- `station_event`, the fix that bounds each event (decision 088);
- `voyage_gear`, each station on the voyage of its own time (decision 155);
- the trail: `fishing` (the window and the ±10 min median speed, decision 093) and `fishing_flow` (the window, else the
  voyage gear's speed range, decision 101).

**Measured:** 7,486,172 window rows. Recorded windows: 4,355,860 tows, 259,038 hauls and 96,743 jigs. Synthesised:
2,437,872 day windows (33 % of the rows), 189,586 sets and 6,152 hauls. 123,753 tows are capped. From 2008, 97-98 %
of the stations of every Icelandic logbook have a fix. The audit puts 92,673 afli stations by their own time in
another voyage than their trip's, and 23,398 afli, 21,844 fs_afladagbok and 3,879 adb stations in a port call.

**Open:**
- TODO 105 (the day window stretched along its fishing stretch, judged by the survey tows);
- TODO 103 (the 643,298 freed fixes) and 107;
- TODO 101's remaining items;
- TODO 34 (speed ranges, the last haul);
- TODO 72's items 4, 8, 9 and 10. Item 10, declared `t1`-`t4` reconciled with the track, is the station-level
  counterpart of `trip_reconciled`;
- TODO 98 and 100 (the logger, the sensors);
- TODO 104 (the vessel overview draws the flow's windows), closed by decision 177;
- TODO 86 and 49 (gear from the track; voyages with neither record);
- plan 020 (gear quantity, which static-gear pressure needs).

**Proposed:** no new design. The order is in §8.

## 7. L6: effort and catch on the fixes

**Built:**
- `hours` and `kw_hours` on every fix (decision 101);
- the catch per fishing fix, unit, species and approach, with `raise_factor` (decisions 100, 102). Its units are a
  timed station, a vessel-day of untimed stations, a logbook trip, and a landing with no logbook trip. Kg in equals
  kg out per year and approach, and the script stops if not.

**Measured:** §1. 22,414.6 kt of logged catch is on fixes. 908.3 kt is on units with no fix. Everything before 2007,
27.6 Mt, is in no unit.

**Open:**
- TODO 81 (raising to every landing of a trip; 23.0 kt counted twice);
- TODO 112 (the disposition);
- TODO 114 (the catch as logged, the whole weight by name; plan 037 phase 1);
- TODO 101 (4.2 kt deleted in the source, 57 t with no window);
- TODO 72 item 8 (static-gear pressure, blocked by the placeholder set times, decision 158);
- TODO 24 (vessels never heard on AIS);
- TODO 62 (foreign logbooks);
- TODO 27b (plan 015, the data call from the trail).

### 7.1 Every logged kilogram in one unit, every year (proposed)

The aim's second done-criterion: every kilogram sits on fixes, or explicitly on a coarser unit. Today that holds
only from 2007. Proposed: the catch units become a table of their own, `curated/logbook/catch_unit.parquet`, written
before the sharing. It holds every station's, vessel-day's and trip's kg by species at its resolution, with its
place and time (the record's position or rectangle and its window), for every year in scope. `ais_catch.R` shares
those units that have fixes. Every unit then falls in one outcome:

- on fixes;
- no fixes that year (the years before 2007);
- vessel never heard (TODO 24);
- no fishing fix;
- deleted in the source;
- no window.

The audit sums the outcomes to the logged total of each year. Effort is unchanged. The scope, from 1990 or from
1950, with or without afli's monthly summaries, is ask e.

## 8. Order of work

0. **The pending rebuild** (the maintainer's): TODO 119 and 121 with decisions 165, 169 and 170, 36 targets. **Done
   2026-10-22** (62 targets with the re-dump and decision 175; decision 180).
   Fingerprints are taken before and after, and the audit is read after. Nothing else is built before it.
1. **The instruments:** plan 024's `station_fate` (TODO 79) and §7.1's `catch_unit`. Every staging station and every
   logged kilogram is then in one outcome, so each later change shows as a move between outcomes.
2. **The trip:** §5.1's readers a-c, measured on a scratch store, then built (asks b, c). adb's `pid` goes into the
   merge (ask f), and the quota regime and gear onto the trips (ask d).
3. **The link:** with plan 039, `withdrawn` and `lid_map` keyed on (`.lid`, `schema_land`) (TODO 74); `lid_map`'s
   lower bound lifted, and the month step before LODS (§4). Then plan 027's `trip_landing` on the reconciled trips
   (TODO 81), plan 036's disposition through it (TODO 112), and `ais_catch.R` reading it.
4. **The sources:** plan 037 phase 1, then plan 019's tour app (TODO 73), then plan 037 phase 2 (TODO 108, 113, 114,
   118, 75), then TODO 62 when the data come.
5. **The stations:** TODO 103's freed fixes, then 105, 107, 101's remaining items, 102's classes, and TODO 72's
   items 8 and 10.

Each phase follows plan 037 §6: a scratch build, the catch traced kilogram by kilogram, a decision record, then the
maintainer's build by name. Phases 2 and 3 come before 4 because TODO 121 is coded and its readers are the open
question now. Phase 4 is larger, and phase 1 measures it.

Plan 040's phase 2 runs inside every phase here (the maintainer, 2026-10-22): whoever opens a reader writes, in the
same change, its source columns' overlay in `dump/oracle/meta/<schema>.yml` (measure and units, position format,
sign and precision, code labels, the evidence, an `assert` per claim the data can test) and its adapter's staging
dictionary, the ledger of the conversions it makes.

## 9. Asks

a. **The split with plan 039** (§0), as the two sessions agreed it: confirmed, or changed.
b. **What reads `trip_reconciled`** (§5.1 a-e): all of them, each after a scratch measure (recommended), or some.
c. **A fix inside two reconciled trips of one vessel** (TODO 102's overlaps): no trip and a flag until TODO 102 classes
   the overlaps (recommended), or the later departure.
d. **The quota system's regime, gear and hand-baited flag:** carried onto the trip (recommended). Should the gear
   also be a witness in `logbook_gear`, below the logbook's own gear and the landing's?
e. **The kilograms accounted** (§7.1): from 1990, decision 103's scope (recommended), or from 1950. Should afli's
   199.4 kt of monthly summaries be month × square units, or left out?
f. **adb's ports:** mapped to `pid` in the merge (recommended), or by each reader. Either way adb's departure port 0
   is a placeholder, not Skarðsstöð: 5,094 adb trips in `trip.parquet` have `hid1` 0 (decision 172), and the merge
   keeps it as a port; `trip_reconciled` already reads it as missing (decision 174). Noted 2026-10-23 from Claude's
   audit, not checked by a person.
g. **The order of §8.**
h. **adb's conversion faults** (decision 171): a check in `curate/checks/` that the records read from 2025-11-19 do
   not carry them (recommended), or none.
i. **kvoti's `veidiferdir` and `nyting_haus`** (13,097 trips) as trip witnesses: measured first, and staged if they
   hold a departure. Or left out.

## 10. The TODO items this plan touches

None is folded in: each keeps its own check, and each is built in its step's phase.

| Step | Items |
|---|---|
| L1 sources and layers | 62, 70, 73 (plans 019, 020), 75, 98, 100, 108, 110, 113, 114, 115 (plan 037), 118, 120 |
| L2 merge | 79 (plan 024), 102, 103, 107, 111 |
| L3 the link | 74 and 123 (plan 039), 81 (plan 027), 112 (plan 036) |
| L4 the trip | 121, 90 (plan 031), 117 |
| L5 stations on fixes | 34, 72 (items 4, 8-10), 86, 101, 104, 105 |
| L6 effort and catch | 24, 27b (plan 015), 49 |
