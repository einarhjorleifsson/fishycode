# 050 — The logbook merge against a colleague's Nephrops checks: the count of trawls, the 2021 ends, tails, adb's gear in the merge, and the new mar's merge compared

**status:** partly built — written 2026-10-29 at the maintainer's request; asks a and d answered the same
day (§5), and steps 2-6 need not wait for step 1 (maintainer); step 4, `lid_map`'s pelagic set and `gear_code` coded the
same day and run in a scratch store against the live one (§6), not yet in the live store (step 7); step 5 (ask c
answered) coded and run the same way, then held on branch `plan-050-step5-tails`, off main, at the maintainer's word:
its factor belongs to a review of whole weight across species, periods and databases (plan 051); step 2 (ask b
answered) and step 6 the same day, run in the scratch store (§6); step 1's e-logbook half the same day, in a side
session over the new mar's parquet (§6), its afli half open; asks e and h answered, f and g open (§5); step 7 done
the same day: the store rebuilt from 93dfbdb (decision 240) · **measured** (§1), by Claude the
same day, read-only, on the store rebuilt from raw on 2026-10-28 (decision 239): the staged and merged logbook, the
afli dump, the curated landings, adb's `trawl_and_seine_net`, and after the answers the count per source and gear and
adb's gear code there and back; it redoes the check of 2026-10-28 (539ba46, TODOs
152-154), made on the build of 2026-10-23 · **assumed** (§2): what the new mar's merge does, which is inferred from
the colleague's figures until its product arrives · **see:** TODOs 107, 152, 153, 154, decisions 084, 154, 160,
`curate/logbook.R`, `curate/corrections/logbook_gear.R`

Drafted with AI assistance (Claude) on 2026-10-29; a person has not yet checked it.

An MFRI colleague moved the Nephrops catch and CPUE series (2000-2026) to the new mar (version 2026-10-27) and raised
five issues with its merged logbook: (1) the twin-trawl field `two_fg` coded 0/1 to 2020 and 1/2 from 2021, with effort
= tow minutes x `two_fg`; (2) no tow times in 2021, every 2021 Nephrops-trawl station read from `ws_veidi`; (3)
Nephrops logged as tails not converted to whole weight from 2019; (4) the detailed landings wrong for Nephrops in
2000-2007; (5) seven single-trawl tows of vid 2048 in May 2026 logged as twin. The new mar's author answered that 1-4
are errors to be fixed and 5 comes from the Directorate's data. The maintainer, 2026-10-29: "Review the merge script
used here in light of the issues raised"; "my hypothesis is that [the new mar's merge] drops off the afli data in 2020,
using the newer source from 2021+. which has its faults." Later the same day, on the asks: "should we not have just
one count column for all gears - so for longline it is number of hooks, nets number of nets, pots number of pots,
towed gear number of trawls. i think we already have that thinking in the grammar"; "the adb is an inhouse
convertion. it messed up the gear code, trying to convert gear to the legacy gear code […] instead of us trying to
move things in the other direction in our merge." Then, while step 4 was coded: "we want the merged product to have
the 'home-made' XXX-YYY letter code as well. the XXX is the general gear, the YYY is more related to the 'target'.
these should have a perfect match with the new numerical gear code"; and "the logbook gear recording is generally less
accurate than what is in the landings database for the corresponding trip. … the final merged logbook records (those
that users will use) should have that double cross-checking correction." And when step 5 was built: "the whole weight
(un-gutted) vs gutted weight is a big issue on its own … the convertion factors may have changed over time. this
includes all species, the landings databasis and the logbook databases. and then how lumpfish roe barrel weight is
converted to ungutted weight! wander if we need to take a broader review on that rather than doing some quickfix
here, just on nephrops."

In the side session that read the new mar (2026-10-29, as it recorded them): Rafn reads the live `fs_afladagbok`, not a
dump, and so mostly bypasses adb; "what needs to be done is to check the fs_afladagbok dump we have vs the live tables
accessible by mar. They 1) may not be the same, 2) Me and Rafn may have interpreted the data differently." fishycode
wants in the end to bypass adb ("it is and has always been a mess"), and keeps afli first per vessel and date. With
twin trawling, the duration and `t1`-`t4` are the fishing duration whatever the number of trawls, and the analyst
decides downstream whether to multiply; "in the downstream processing the user may want to define effort e.g. of
longlines using the duration t1 -> t4. some other may want to use t3->t4 as duration."

## 1. What is measured

**The 2021 cut.** afli is not a pre-2021 source. Vessel-days per year in staging:

| year | afli | fs_afladagbok | both |
|---|---|---|---|
| 2019 | 60,590 | 20 | 20 |
| 2020 | 51,628 | 278 | 263 |
| 2021 | 36,074 | 41,892 | 22,123 |
| 2022 | 14,913 | 49,673 | 14,221 |
| 2023 | 818 | 46,318 | 788 |
| 2024 | 12 | 48,418 | 11 |

On the vessel-days both hold, the trawls (OTB, OTM) have an end time in afli on 99.9 % of 34,066 stations in 2021 and
21,790 in 2022, and in fs_afladagbok on 0 % of 34,039 (2021) and 1.5 % of 21,996 (2022). `curate/logbook.R` takes afli
first per vessel-day, so the merge keeps all 87,962 of afli's 2021 stations, the same count as in the afli dump, and fills
22,363 from fs_afladagbok (TODO 154: handline, gillnet and longline with a start and no end). Of afli's 2021 stations,
32,451 lie on vessel-days fs_afladagbok lacks (OTB 18,411, Danish seine 4,475, longline 3,988, gillnet 2,435, handline
2,137, the rest 1,005); 1,343 in 2022, 89 in 2023. A merge that cuts afli at 2020 and takes `ws_veidi` from 2021 loses
the trawl ends and those stations, unless it fills them back.

**Nephrops trawl in the merge** (OTB stations with a catch of sid 40, duplicates left out). 2021: 757 from afli with an
end on 99.9 %, 2 from fs_afladagbok. The colleague counts 655 Nephrops stations in 2021, all from `ws_veidi` and
all without an end. The two counts are not yet reconciled.

**Issue 1, the count of trawls.** Trawl effort here is never multiplied by the flag: `effort_count` is 1 on every
afli and fs_afladagbok OTB and OTM station but 1,203 with none, and `effort` equals `effort_duration` on every
Nephrops trawl. But `n_units` holds two codings: afli's `tvo_veidarf` 0/1 (OTB: 3,654,592 zeros of 4,118,626), and
fs_afladagbok's count (Nephrops trawl: 2 on all 75 stations of 2022 and 2024). adb's `two_fg` is not read, so
`n_units` is empty on all 88,464 adb stations (TODO 153). **The colleague's effort fault exists here for dredges.** afli's
dredge takes `effort_count = coalesce(n_units, 1)` from the same `tvo_veidarf`, so 13,396 of afli's 79,370 dredge
stations have `effort_count` 0 and 13,351 have `effort` 0. All are gid 15, in 2010-2019, of 28,101 gid-15 stations in
that decade. fs_afladagbok's dredges count dredges: 188 with 2 or more, none with 0.

**Issue 2, the 2021 tow times.** Answered by the merge order (above). The afli dump keeps the 2021 tows:
`toga.togtimi` on 68,415 of 87,962 stations and `tvo_veidarf` on 49,751 (2022: 28,197 and 20,645 of 38,075). The
colleague expects afli to be out of reach in Oracle after 2026-12-01. Here it stays readable from
`$FISHYDATA/raw/oracle/afli/` as long as the dump is kept.

**Issue 3, tails** (TODO 152, reproduced). Per trip, the logbook's Nephrops over the landed weight (median):

| vid | 2000-2006 | 2007-2018 | 2019-2026 |
|---|---|---|---|
| 173 | 1.01 (110) | 0.99 (336) | 0.28 (59) |
| 1645 | 0.33 (74) | 1.06 (532) | 0.34 (76) |
| 1752 | 1.01 (10) | 0.92 (384) | 0.35 (56) |
| 2048 | | 1.00 (281) | 0.28 (48) |
| other vessels | 0.95 (3,644) | 0.99 (3,676) | 1.04 (174) |

`calc_whole_weight()` (`R/whole_weight.R`) knows the states GUTT, UNGU and RELE, not tails. Nothing converts these
trips, and their whole weight carries basis `recorded`.

**Issue 4, the landings.** `curated/landing` gives the Nephrops tonnes the colleague quotes from `lods_oslaegt`:
1,239, 1,419, 1,548, 1,666, 1,437, 2,030 and 1,876 t in 2000-2006. 2007 is 1,888 (lods) + 118 (agf) = 2,006 against
the colleague's 2,007. Nothing to do.

**Issue 5, vid 2048 in May 2026.** adb's `two_fg` is 2 on all 65 stations of 2-25 May, the 10 of 11-13 May
included, and 1 on the 11 of 27-31 May. The count does change, but between trips, not within one (TODO 153: no adb
Nephrops or shrimp trawl trip changes it). This is consistent with an app that keeps the trip's setting. None of it
reaches `curated/`.

**Found here: adb's gear never reaches the station type.** The adb adapter leaves `gid`, `gear`, `n_units` and
`effort_count` empty on purpose. `curate/corrections/logbook_gear.R` fills the gear downstream, from adb's
own crosswalk (decision 154). But `curate/logbook.R` reads the station type's gear from `fishing_sample`, so every adb
vessel-year is one pattern across its gears, and the rule that longlines are always `operation` never fires. 3,836 of
adb's 6,012 longline stations (gear from `gear.parquet`) are typed `event` with basis `derived`. A known longline
cannot get that type in afli or fs_afladagbok. The same pooling touches gillnets (2,900 of 5,486 `event`) and every
vessel that fishes two gears in a year. What this does to the windows downstream is not measured. `gear.parquet`
is built from `logbook`, so the merge cannot read it without a cycle.

**The count, per source and gear** (after ask a). The grammar already has the one count: `effort_count`, "what
fishes at once: hooks, nets, jigs, traps; 1 for a single towed gear" (`docs/grammar.qmd`, the fishing sample).
`n_units` is not in the grammar. Beyond the adapters, only `products/user_tables.R` reads it. In the merge:

- **afli and fs_afladagbok** fill `effort_count` for the passive gears: hooks (longline, median 13,440 and 18,000),
  nets, jigs and traps. Towed gear is 1 on every station, the twin trawl included. fs_afladagbok's adapter says
  "n_units unreliable, assume 1". The exception is afli's dredges, which take the 0/1 flag (the 13,396 above).
- **adb** fills it on none of its 88,464 stations. Its raw tables hold every count: `line_and_net.hooks`, `nets`
  and `pole_and_lines`, `trap.number_of_traps`, `dredge.two_dredges` and `trawl_and_seine_net.two_fg`. Its
  `effort_unit` is its own vocabulary ("hours towed", "netnights", "hookhours"), several per gear.
- **aflaskeyti** fills it on none of its 3,058 stations.

**adb's gear code, there and back** (after ask d). adb writes the legacy code (`fishing_station.fishing_gear_no`
only) and its map `fishing_gear` gives each legacy code one FS id: Nót and Plógur repeat, with the same id. On the
stations fs_afladagbok also holds, adb's code read back through the map gives fs's FS code on:

| period | recovered | wrong | not in the map |
|---|---:|---:|---:|
| 2019-2024 | 368,940 | 5,256 | 432 |
| 2025 to 11-18 | 90,672 | 0 | 0 |
| 2025-11-19 on | 2,200 | 0 | 0 |

The wrong ones are decision 171's collapse: shrimp trawl (FS 8) and Nephrops trawl (FS 7) written as bottom trawl,
4,352 and 848. Landbeitt lína and Línutrekt (FS 13, 21) are written as 99. All of them fall in years the merge takes
from fs_afladagbok (decision 160). From 2025-11-19, where adb is the only source, Nephrops trawl (legacy 9, 103
stations) and shrimp trawl (14, 1,012) map back right, and no station holds 99.

## 2. What is assumed

- That the new mar's `afladagbok.ws_veidi` is the table dumped here as `raw/oracle/fs_afladagbok/ws_veidi.parquet`.
  Not checked.
- That the new mar's merge takes `ws_veidi` alone from 2021 (the maintainer's hypothesis). Every one of the
  colleague's figures for 2021 fits it: the source of every gear-7 station, no end time, `two_fg` 1/2. If it holds,
  the product has no 2021-2022 trawl end and about 32 thousand fewer stations in 2021.
- That afli's `tvo_veidarf` 0 on a dredge means one dredge, not none.
- That the tail factor is 3.3, as the colleague gives it, from 2019 as before.

## 3. The steps

1. **The comparison**, when the new mar's merged logbook arrives. Read-only, archived under
   `$FISHYDATA/archive/2026-10-29-mar-logbook/`. Per year and source, each vessel-day and station goes in one
   outcome (both, ours only, theirs only, unjudgeable). On the shared ones: times, the count of trawls, the gear, and
   the Nephrops catch, with each difference explained or listed as unexplained. This tests §2's hypothesis and the
   655-against-757 gap. The asks to the new mar's author go out from its result, with links. *E-logbook half done
   2026-10-29 (§6); the afli half, 1950-2020 by `visir`, is open.*
2. **One count, `effort_count`, the grammar's** (TODO 153; ask a). The number fishing at once, for every gear and
   source: hooks, nets, jigs, traps, and for towed gear the number of trawls or dredges.
   - afli's `tvo_veidarf` 0/1 becomes 1/2, basis `derived`. fs_afladagbok's count is read as recorded, with no
     "assume 1". adb's six counts are read, and its units mapped to the grammar's. aflaskeyti stays `none`.
   - A new `effort_count_basis` says which. `effort` stays `effort_count × effort_duration`, as the grammar has it,
     so a twin tow counts twice its minutes. A gear factor (1.8 for twin Nephrops trawls, the colleague's "standard
     factor" in the email of 2026-10-29) is the user's to apply
     from the two columns.
   - `n_units` leaves the fishing sample, and `products/user_tables.R` changes with it.
   - afli's dredges come out of this step too: the 13,396 with effort 0 are recounted.
   - Ask b: a note, no column. adb's times are read as fs_afladagbok's with it, since its effort needs the grammar's
     duration (§6).
3. *(Folded into step 2: the dredges' count is the same column.)*
4. **adb's gear at the adapter** (ask d). adb's conversion to the legacy code is where the fault lies, so it is undone
   where it enters: the adb adapter reads its legacy code back to the FS code through adb's own map
   (`raw/oracle/adb/fishing_gear.parquet`, a table of the same source, so the adapter rule holds). It fills `gid`
   and `gear` as afli and fs_afladagbok do, which is exact for every station read (§1). `logbook_gear.R` drops its
   adb path, which amends decision 154. Then the station type of adb is recounted by gear, with no longline `event`.
   A note for adb's author asks for the FS code beside the legacy one, and gives the 2019-2024 collapse.
   - **`lid_map`'s pelagic set** with it. `curate/link_lid_map.R` took the pelagic gears' gids from both code
     versions, while `fishing_sample`'s gid is the new code. So Nephrops trawl (new 7), shrimp trawl (8) and the
     longlines (12, 13, 21) went to the loose weight step (07) as pelagic: 292 of its 335 links. Step 4 gives adb new
     codes too, so the set is taken from the new code alone.
   - **`gear_code`** (the maintainer, above). The new code's letter twin, `XXX_YYY`: the general gear and the target.
     It is `gear` + `target2` where that pair is the gid's alone, and the maintainer's choice where it is not or where
     there is no gear: Rauðmaganet (4) GNS_LUR, Landbeitt lína (13) LLS_LBL, Línutrekt (21) LLS_TRK, Eldiskví (18)
     AQU_CAG, Kræklingalína (20) AQU_MUS. It lives in `reference/gear/mapping.R`, which stops unless each of the 25
     new codes has one and no two share one. The merge carries the logbook's own code beside `gear`. `gear.parquet`
     carries the code of `gid_used`, the landing's gear where the landing names one, as do the v0 user tables, which
     already took that cross-checked gear. `logbook_gear.R` still compares by `gear` + `target2`, so Lína and Landbeitt
     lína do not disagree.
5. **Tails** (TODO 152; ask c). A correction, `curate/corrections/logbook_nephrops_tails.{yml,R}`, finds the trips
   by declared vessel and period, guarded by the trip's own ratio, and writes a side table after `lid_map`.
   `calc_whole_weight()` takes its factor, so the per-station whole weight and v0's catch rows have it. `catch` stays
   the weight as logged (§6). *Held on branch `plan-050-step5-tails` (maintainer, 2026-10-29):* which trips were logged
   as tails stands, and the 3.3 waits for the review of whole weight (plan 051), which sets every factor from one table.
6. **The 2021 ends** (TODO 154). Look for the 22,363 fs-only stations' ends in `afli_sent`. Otherwise declare them
   basis `none` where the analyst reads the haul times.
7. **Rebuild** the logbook and what reads it, with fingerprints before and after (`R/fingerprint.R`), and the merge's
   fate account rerun. `targets` cannot see the script edits, so `gear`, `afli`, `afli_sent`, `fs_afladagbok`, `adb`,
   `logbook`, `lid_map`, `logbook_gear`, `station_window`, `voyage_gear`, `trip_reconciled` and
   `check_allocation_audit` are invalidated by hand. `products/user_tables.R` is rerun after, and
   the vessel overview's haul line moves from `effort` to the count in the same step (`products/vessel_overview/api.R`
   and `www/app.js` read the live store), with its click paths tested. Then a decision record. *Done 2026-10-29: decision 240.*

Steps 2-6 do not wait for step 1. Each one is checked alone before the next.

## 4. What it changes

`sources/afli/convert.R`, `sources/fs_afladagbok/convert.R`, `sources/adb/convert.R` (the count, the dredge
effort, adb's gear), `curate/corrections/logbook_gear.R`, a new correction pair, `docs/grammar.qmd` (`effort_count_basis`),
`products/user_tables.R` (`n_units` gone), and every target downstream of `logbook`. `curate/logbook.R` itself changes only if step 4 is done in the merge instead of the adapter.
TODOs 152-154 close into the decision record.

## 5. Asks

- a. *Answered (maintainer, 2026-10-29):* one count for every gear, which is the grammar's `effort_count` (step 2).
- b. *Answered (maintainer, 2026-10-29):* first "Yes, flag them", as proposed. Then the measurement found that no
  source holds the count once per trip: on towed gear it changes within 558 of fs_afladagbok's 8,266 trips of two or
  more counted stations, 722 of adb's 10,014 (`two_fg`), and 1,505 of afli's 35,933 in 2008-2019 (801 of 158,677
  before 2008). Given that, the maintainer chose the note, with no column: the count is as recorded, and an
  e-logbook's may be the app's value carried from the last haul (issue 5). A flag of constant counts would mark about
  95 % of trips. The new mar's author calls issue 5 the Directorate's data.
- c. *Answered (maintainer, 2026-10-29):* vessel and period at x 3.3, then, when the measurement found whole-weight
  trips inside the periods, the period with a trip guard. The periods were narrowed from the measurement: vid 1645
  logged whole weight in 2002-2003, so its early period is 2004-2006, not the 2000-2006 first proposed.
- d. *Answered (maintainer, 2026-10-29):* the fault is adb's conversion to the legacy code, and it is undone where it
  enters, at the adapter (step 4).

- e. *Answered (maintainer, 2026-10-29):* drop the stored effort. The fishing sample keeps `t1`-`t4`, the count with
  its unit and basis, and a recorded duration where the record gives one; `calc_effort()` makes the duration and the
  effort with the interval, the count and the unit as arguments (§6). The colleague's email had said the same: "keep
  plain tow minutes and a harmonised twin flag (or number of trawls), and leave any gear factor to the user".
- f. How fishycode reaches the live `fs_afladagbok` tables, to dump them source-shaped (the new mar's parquet is
  already interpreted): which account, and whether they are the `ws_*` tables of the dump. For Rafn or IT. Then a plan
  of its own: the live tables in place of the dump and adb. The live build loses month-end trips (§6), so it can replace
  the dump and adb only once that is fixed upstream; the fault is for the new mar's author (ask g).
- g. Whether and when the new mar's candidate defects (`$FISHYDATA/archive/2026-10-29-mar-logbook/mar-package.md` §8)
  go to its author, as `curate/issues/`.
- h. *Answered (maintainer, 2026-10-29):* move it downstream. "The decision taken at the time was ad-hoc. we deal with
  this issue downstream when it comes to joining things to ais etc." The sample keeps the recorded times and
  durations and flags what is above the gear's limit (`.duration_source` `implausible`); `judged_time_sql()`
  (`R/duration_limit.R`) leaves out the end a flagged duration ran to where the times are read: `station_window.R`,
  `voyage_gear.R`, `trip_reconciled.R`, `allocation_audit.R`, and `calc_effort()` by default. Before, the limit had been
  set for the windows as well as the effort (plan 010 §12, decision 057). It flags about 4,000 of 7.3 M stations, nearly
  half of them afli gillnets soaking 7-10 days.

## 6. Built so far

**Step 4, `lid_map`'s pelagic set and `gear_code`**, coded 2026-10-29. They were run by Claude in a scratch store: the
gear reference, the adb adapter, the merge, `lid_map` and `logbook_gear`, each in its own R session, on the live
store's other inputs. Each output was compared with the live store's, read-only, and the real store was untouched.
Not checked by a person.

- **Unchanged:** the reference but for `gear_code` (25 codes, one to each new gid). adb's staging but for its gear
  columns. Every merged table's rows and every other column.
- **adb's gid** is filled on all 88,464 merged stations, equal on every one to the gid `logbook_gear.R` read before.
  `gid_used` and `gid_basis` are equal for every adb station.
- **Station type:** 3,826 adb longlines `event` → `operation`, with 11 left `event` where the logbook's own gear is not
  a longline and the landing's is. adb gillnets 350 → `operation` and 117 → `event`, handlines 41 and 36. fs_afladagbok
  gillnets 224 → `operation`, on vessel-years whose gear group adb's stations now join.
- **`lid_map`:** the loose step holds 45 links (335 before). Of its 292 non-pelagic trips, 255 keep their landing
  through the tight step (06) or the order step (09), and one goes to another landing. 43 trips lose their landing:
  32 longline, 7 shrimp trawl and 3 Nephrops trawl from the loose step, and one longline from step 09. 33 gain one:
  30 by the tight step, 3 by order. No landing passes from a lost link to a gained one, so this is the tolerance, not a
  swap. adb's 2 pelagic trips go to the loose step.
- **`gear.parquet`:** 14 afli stations change their gear with their trip's landing. `gear_code` pairs one-to-one
  with `gid_used` (24 gids, 24 codes). 5 stations have no gear.

**Step 5, the tails**, coded 2026-10-29 and run the same way, then held on branch `plan-050-step5-tails`, not in main: the merge again, `catch_by_species_trip`, the correction,
`catch_by_species_station`, and v0's catch rows built as `products/user_tables.R` builds them.

- **The rule** (`curate/corrections/logbook_nephrops_tails.yml`): vids 173, 1752 and 2048 from 2019, vid 1645 in
  2004-2006 and from 2019; factor 3.3 on the weight as logged; guard 0.55. The tails of adb's vid 2048 are logged as
  GUTT, and the factor replaces the gutted rule there.
- **Every candidate trip in one outcome:** 283 trips, 267 `tails` and 2 `tails_no_landing` (2,110 stations,
  converted), and 14 `whole` (79 stations, as logged).
- **Unchanged:** the merge's tables and fates, since `calc_whole_weight()`'s factor branch is unused there. All
  16,989,795 other per-station rows.
- **Changed:** the 2,110 converted rows, from 126.7 t to 413.9 t, basis `reconstructed`. Per trip, sid 40's whole
  weight over landed (median), before → after: vid 173 0.28 → 0.92, 1645 0.32 → 1.05, 1752 0.34 → 1.13,
  2048 0.30 → 0.94. The whole trips stay as they were (0.62-1.22).
- **v0's catch:** one row per catch row, as before (16,997,458), now with `catch_round`, `round_basis` and
  `round_factor`. 2,110 rows carry the factor: afli 2,047, fs_afladagbok 13, adb 50.
- **Found on the way:** `station.parquet`'s `date` is a date-time. The correction's first run compared it with Dates and
  found no candidate, so it now stops on an empty set.

**Step 2, one count**, coded 2026-10-29 and run the same way, on top of step 4: the three adapters, the merge and
`station_window`. Every output was compared with step 4's scratch output (the merge, adb) or the live store's (afli's and fs_afladagbok's
staging, `station_window`), read-only. The real store was untouched. Not checked by a person.

- **The rule** (`R/logbook_effort.R`, shared by afli, fs_afladagbok and adb). `effort_count` is what fishes at once,
  with `effort_count_basis`: `recorded`, `derived`, `synthesised` (one gear, for a towed gear or a seine that records
  none) or `none`. A count of 0 is no count. The count's unit and the duration's are columns of their own,
  `effort_count_unit` and `effort_duration_unit` (maintainer, 2026-10-29: so hook-hours can be made as well as
  hook-days). `n_units` and `n_total` stay in staging and leave the merge.
- **afli's twin flag** (`tvo_veidarf`, 0/1 on trawls and dredges; one station holds 5): 0 is one gear and 1 two, basis
  `derived`. Per vessel with 50 or more counted tows, afli 2018-2022 against fs_afladagbok from 2022: 40 of 42 vessels
  that afli almost never flags log one trawl in fs_afladagbok, and 4 of 6 it almost always flags log two or more. No
  vessel flagged in afli is single in fs_afladagbok. On shared vessel-days fs_afladagbok has no count (its 2021-2022
  feed has no `ws_dragnot_varpa` row), so the check is per vessel, not per tow.
- **adb's counts** equal fs_afladagbok's on every station both hold: `two_fg` 217,569, `two_dredges` 4,578, hooks,
  nets and jigs 124,737, traps 65.
- **The count changes within trips in every source** (ask b): 558 of fs_afladagbok's 8,266 towed trips of two or more
  counted stations, 722 of adb's 10,014, and 1,505 of afli's 35,933 in 2008-2019 (801 of 158,677 before 2008).
- **adb's times.** `elogbook_times()` reads them as fs_afladagbok's adapter does: a towed start and end in `t2` and `t3`,
  the duration, and the duration limit. adb's towed stations had no duration and no effort until now. `station_window.R`
  no longer moves them. Its tow windows are the same on 51,288 of 51,292. 604 adb hauls differ because their own gear
  is towed (584 dredges, 20 Danish seines) and their landing's is static (traps). The adapter now reads their times by
  the logbook's own gear, as fs_afladagbok's 1,588 and afli's 876 dredges with a trap landing already are. 117 set or
  haul windows lose an end to the duration limit, which adb now takes as fs_afladagbok does.
- **Unchanged:** every staged and merged table but the fishing sample's effort columns (and adb's times). Every
  station's type, and every `station_window` row of afli, fs_afladagbok and aflaskeyti.
- **Changed:**
  - afli's dredges with effort 0, 13,351 → 0.
  - The effort's sum: afli's bottom trawl ×1.041 (142,572 twin tows), dredges ×1.034, and fs_afladagbok's bottom trawl
    ×1.24 (30,406 tows of 2 or 3).
  - adb's towed stations gain an effort: bottom trawl 32,626, Danish seine as before, dredge 2,682, midwater 1,367.
  - adb's passive gears now take fs_afladagbok's units and soak (`t4 - t1`). Before, adb's own units ran from the haul's
    start, so the sums are not comparable.
  - Basis on the towed and seine stations: afli 3.90 M `derived`, 1.64 M `synthesised`; fs_afladagbok 155 k
    `recorded`, 70 k `synthesised`.
  - Stations with no count: afli 4,758, fs_afladagbok 23,855, aflaskeyti 3,058.

**Step 6, the 2021 ends.** The merge's 22,359 fs_afladagbok stations of 2021 (duplicates left out) are handline
18,884, gillnet 2,710, longline 763 and 2 trawls: each with a start, and 11 with an end. Neither source holds the rest:
- **afli's sent messages** (`staging/afli_sent`): 29 of their 748 vessels appear there in 2020-2022, and none on the
  same vessel-day or with a start within a minute.
- **adb**, which shares the station ids: it holds 22,063 of them, with 12 ends.

So their ends are not recorded anywhere we hold. They stay NA, with `.duration_source` `missing`, and
`docs/output-schema.md` says so where the haul times are described.

**Step 1, the e-logbook half**, 2026-10-29, by Claude in a side session: the R package mar at `~/R/Pakkar/mar`
(b5763ef) and the parquet it reads on `s3://prod-parquet-vocal-mule/`, in aggregates. Findings, counts and scripts in
`$FISHYDATA/archive/2026-10-29-mar-logbook/` (`mar-package.md`); the live e-logbook's rows of 2021 on in its `live/`.
No Oracle. Not checked by a person.

- **The hypothesis holds.** The new mar's logbook is afli to 2020 and the live e-logbook from 2021 (to 2026-10-25),
  cut by the trip's landing year, with no adb and no aflaskeyti. Its build code (`mfriops/Landings`) is not reachable.
- **The five issues placed:**
  - (1) afli's 0/1 flag enters as a count, so `effort` is 0 on 2.21 M single trawls to 2007.
  - (2) 2021 is the e-logbook alone: its 655 Nephrops stations, the colleague's count, have no end, where ours come
    from afli.
  - (3) The catch is `magn` as logged, with no state and no factor.
  - (4) The Nephrops landings equal ours to the kilogram. But the LODS pelagics are read in tonnes as kg, so 1994-2006
    hold about a third of the catch.
  - (5) `two_fg` 2 on all 65 of vid 2048's May stations, from the source.
- **The live e-logbook against our dump**, by the Directorate's ids (the same as our `.sid`):
  - 2021: the live holds 29,964 stations the dump lacks (all but 116 in adb; their towed days lie on afli's).
  - 2022-2025: the dump holds 2,382-4,354 stations a year (30-51 kt) that the live does not, most of them in our
    merge, with no record of the vessel that day in the live.
  - 2026: the live covers 80,590 of adb's 83,223 stations, plus 1,397 adb lacks.
- **Read the same** as ours: gear, towed times, Danish seine, depth as recorded, `magn`, the twin count.
- **Read differently:**
  - Positions: the new mar reads the 6-digit integers as decimal minutes. They are seconds, so ours holds.
  - Static soak: the new mar takes `t3 - t1`, ours `t4 - t1`. The grammar's soak is `t3 - t1` where `t2` is missing.
- **Leads for fishycode:**
  - afli's pre-2000 Nephrops tow times: `sources/afli/convert.R` blanks 132,730 tows whose `togtimi` looks sound
    (median 300 min). The implausible values are on the 26,412 without `tvo_veidarf`.
  - The coordinate-format prior reads about 2.2-2.8 k stations a year (2023-2025) as decimal minutes, with little
    sign of it.
  - The dump-only stations of 2022-2025 (above).
  - adb's missing tow ends are mended by step 2.

**Ask e, and two leads from step 1**, coded 2026-10-29 and run the same way: the three adapters, the merge and
`station_window`, compared with the step-2 scratch run.

- **No stored effort.** `effort`, `effort_unit`, `effort_duration` and `effort_duration_unit` leave the adapters, the
  merge and v0's station table. The count, its unit and its basis stay.
  - `duration_m` is the record's own duration: afli's 5.63 M and aflaskeyti's 2,179.
  - It is NA for the e-logbook, whose `.duration_source` is `times` (fs_afladagbok 347,871, adb 87,886).
  - v0 gains `duration_m_raw` and `.duration_source`.
  - `calc_effort()` (`R/logbook_effort.R`) makes the effort. It equals step 2's stored effort wherever both use the
    same interval. It differs on:
    - 23,016 e-logbook sets whose set time is the app's placeholder (`t1_placeholder`): the stored effort had a soak
      from it, `calc_effort()` has none;
    - 149,141 afli static sets with times, where it takes `t1` → `t4` over the recorded nights or hours, and 866
      that gain an effort from their times;
    - 223 afli and 176 e-logbook sets whose span is zero, negative or missing, where it gives none.
- **afli's Nephrops tows to 1999.** The rule that blanked them ("hours not minutes") is gone. Their `togtimi` is
  minutes, median 270-300 and 95 % at or below 360 in every five years from 1965.
  - 132,684 of 132,741 tows keep their duration and 131,517 a tow end; the limit takes 10.
  - 131,501 of afli's window rows change with them.
  - Their overlap labels change: 121,990 `end time missing` → `ok`, and 9,527 now overlap a neighbour.
  - 156 afli stations change their twin flag: the restored ends tell twins apart.
- **fs_afladagbok's coordinate format** is read by adb's rule (`logbook_position_hundredths()`, decision 211): Taktikal,
  or a six-digit value ending in 61-99 in any of the four.
  - Marína raun was read as hundredths of a minute on its app alone. Its six-digit latitudes of 2024-2025 never end
    in 60 or above (0 of 9,269), so 8,482 of its stations of 2023-2025 move to seconds, by 0.2' median. 436 move
    the other way, on evidence in a longitude or an end position.
  - Trackwell raun 2022-2023 (2,162 stations) and Jóhann Gíslason raun 2022-2023 (325) were read as hundredths on a
    signal from their four- and five-digit latitudes, which are degrees and minutes (decision 211). They are now read
    as seconds.
  - Reiknistofa's 23 stations with a rounded 60 are seconds too.
- **Unchanged:** every other column and table. `station_window` differs on 11 e-logbook handlines, from `jig` to
  `day`: their old window was made from a duration spanning the placeholder set time.

**Why the live e-logbook differs from our dump**, 2026-10-29, by Claude in a subagent: the live rows copied by the side
session against the dump, adb and afli, every differing record in one outcome
(`$FISHYDATA/archive/2026-10-29-mar-logbook/live-vs-dump.md`, `scripts/lvd_causes.py`). Not checked by a person.

- **2021's 29,964 live-only stations are not e-logbook records.**
  - They are the Directorate's paper and Trackwell-book records: adb's feeds `TRACKWELL BAEKUR` (27,372) and `PAPPÍR`
    (2,476), and 116 not in adb.
  - They carry afli's ids: 29,949 have the same id, vessel and day in afli's `stofn`, so the merge holds them from afli.
  - The dump's `ws_veidiferd` never held those feeds. 2022's 1,090 are the same.
- **The dump-only stations of 2022-2025 are lost in the live's read, not deleted.**
  - A trip whose `snt` falls on the last day of a month is missing from the live 98-99.5 % of the time, any other 0.1-0.4 %.
    Checked in the main session on the dump's trips: 2022 1,541 of 1,552, 2023 1,466 of 1,493, 2024 610 of 613, 2025
    907 of 912.
  - The loss continues in adb's records after the dump ends: 818 of 830 month-end trips against 20 of 41,229 others.
  - They are real trips (97-99 % landed, every vendor, 27-51 kt a year), and no copy marks them.
  - The mechanism (a monthly read that drops the month's last day) is inferred; the build code is not reachable.
  - The rest, a few hundred a year, are trips that never landed, from a few vessels per vendor, which look like trials.
    `STOKKUR` 2021 holds 340 two-minute trips with test weights.
  - Unexplained: 13-29 stations a year.
- **2021's shared trips that differ** (2,258) are an id collision: the live holds the tour app's trips under
  `ws_veidiferd` numbers. Only 5 trips of 2025 changed after the dump (`ws_rekjanleiki`, 2025-12-02).
- **For fishycode:** keep the dump's month-end trips. Reading the live in place of the dump and adb would inherit
  the loss until it is fixed upstream.

**Ask h, the duration limit as a flag**, coded 2026-10-29 and run the same way: the three adapters, the merge,
`station_window`, `voyage_gear`, `trip_reconciled` and `allocation_audit` (the last three for the first time in the
scratch store, on the live store's AIS and links). Compared with the run before it, and the last three with the live
store.

- **The rule.** `flag_duration_limit()` (`R/duration_limit.R`, renamed from `apply_duration_limit()`) keeps the value
  and flags it in `.duration_source`. It flags a duration above the gear's limit, a recorded duration of 0 or less
  (afli's 35 tow times, its static hours and nights), and an e-logbook span below 0. A span of exactly 0 is not
  flagged:
  - 2,199 handlines and about 200 nets, lines and traps carry one time in every slot;
  - the windows give them a typical haul, and leaving their end out turned about 190 of them into day windows (a
    first run, flagging 0 too).
- **Kept.** afli's impossible intervals are kept, no longer blanked (`.checks` keeps the label; none occurred).
- **Applied where the times are read.** `judged_time_sql()` gives `station_window.R`, `voyage_gear.R`,
  `trip_reconciled.R` and `allocation_audit.R` the times they read, and `calc_effort()` leaves out the same unless told
  `implausible = TRUE`.
  - Against the run before it, those times are equal on every station but the 179 fs_afladagbok sets whose end is
    before their start. Their end is now left out, which changes 187 window rows; no window runs backwards either way.
  - `calc_effort()` gives the same effort on every station.
  - The sample now keeps 3,708 afli durations and 722 tow ends it had blanked, and the e-logbook's 612 flagged ends
    (fs_afladagbok 522, adb 90). afli's overlap labels change on 975 stations, and 10 twin flags and one station type
    move. Flagged in all: afli 3,708, fs_afladagbok 701, adb 90, aflaskeyti 54.
- **Downstream, against the live store** (all of steps 2, 4, 6 and asks e and h):
  - `voyage_gear`: 266 of 1,430,712 voyages change their gear.
  - `trip_reconciled`: 3 trips change T1, 1 its landing port.
  - The audit: 1,387 stations move from "no time of day" to "in no voyage or port call" (pre-2000, no AIS), its
    unexplained catch falls by 110 t, and every other outcome moves by 1-5 records.
- **The rest of the chain**, checked against the maintainer's rule that an extreme value is flagged, not corrected
  (`AGENTS.md`). None is an extreme measurement:
  - 10,009 afli tow starts that are no clock time, and about 930 positions off the globe, stay NA: nothing can be
    decoded from them, and the integer stays in `raw/`.
  - 26 e-logbook stations are dated 2027-2031 on trips landed in 2022-2023, held in both fs_afladagbok and adb. They
    stay out of the merge, in the fate table with reason `date_after`: the date is the key that places the record.
  - The 77,953 app placeholder set times stay NA with `t1_placeholder` (decision 157): a value the app made up.
  - aflaskeyti's 63 hauls of duration 0 stay NA with `implausible`; its adapter is not part of this step.

