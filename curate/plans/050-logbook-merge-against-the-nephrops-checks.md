# 050 — The logbook merge against a colleague's Nephrops checks: the count of trawls, the 2021 ends, tails, adb's gear in the merge, and the new mar's merge compared

**status:** proposal — written 2026-10-29 at the maintainer's request; nothing built; asks a and d answered the same
day (§5), and steps 2-6 need not wait for step 1 (maintainer) · **measured** (§1), by Claude the
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
move things in the other direction in our merge."

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
   655-against-757 gap. The asks to the new mar's author go out from its result, with links.
2. **One count, `effort_count`, the grammar's** (TODO 153; ask a). The number fishing at once, for every gear and
   source: hooks, nets, jigs, traps, and for towed gear the number of trawls or dredges.
   - afli's `tvo_veidarf` 0/1 becomes 1/2, basis `derived`. fs_afladagbok's count is read as recorded, with no
     "assume 1". adb's six counts are read, and its units mapped to the grammar's. aflaskeyti stays `none`.
   - A new `effort_count_basis` says which. `effort` stays `effort_count × effort_duration`, as the grammar has it,
     so a twin tow counts twice its minutes. A gear factor (1.8 for twin Nephrops trawls) is the user's to apply
     from the two columns.
   - `n_units` leaves the fishing sample, and `products/user_tables.R` changes with it.
   - afli's dredges come out of this step too: the 13,396 with effort 0 are recounted.
   - The trip setting, ask b.
3. *(Folded into step 2: the dredges' count is the same column.)*
4. **adb's gear at the adapter** (ask d). adb's conversion to the legacy code is where the fault lies, so it is undone
   where it enters: the adb adapter reads its legacy code back to the FS code through adb's own map
   (`raw/oracle/adb/fishing_gear.parquet`, a table of the same source, so the adapter rule holds). It fills `gid`
   and `gear` as afli and fs_afladagbok do, which is exact for every station read (§1). `logbook_gear.R` drops its
   adb path, which amends decision 154. Then the station type of adb is recounted by gear, with no longline `event`.
   A note for adb's author asks for the FS code beside the legacy one, and gives the 2019-2024 collapse.
5. **Tails** (TODO 152). A correction, `curate/corrections/logbook_nephrops_tails.{yml,R}`, finds the trips by a
   rule (logbook over landed per vessel and period, which needs ask c). It converts their Nephrops to whole weight
   in a column of its own, with basis `reconstructed`, and keeps the weight as logged.
6. **The 2021 ends** (TODO 154). Look for the 22,363 fs-only stations' ends in `afli_sent`. Otherwise declare them
   basis `none` where the analyst reads the haul times.
7. **Rebuild** the logbook and what reads it, with fingerprints before and after (`R/fingerprint.R`), and the merge's
   fate account rerun. Then a decision record.

Steps 2-6 do not wait for step 1. Each one is checked alone before the next.

## 4. What it changes

`sources/afli/convert.R`, `sources/fs_afladagbok/convert.R`, `sources/adb/convert.R` (the count, the dredge
effort, adb's gear), `curate/corrections/logbook_gear.R`, a new correction pair, `docs/grammar.qmd` (`effort_count_basis`),
`products/user_tables.R` (`n_units` gone), and every target downstream of `logbook`. `curate/logbook.R` itself changes only if step 4 is done in the merge instead of the adapter.
TODOs 152-154 close into the decision record.

## 5. Asks

- a. *Answered (maintainer, 2026-10-29):* one count for every gear, which is the grammar's `effort_count` (step 2).
- b. Whether the count being a trip setting is flagged (proposed) or left as recorded with a note. The new mar's author
  calls issue 5 the Directorate's data.
- c. The tail rule: the factor (3.3?), and whether a trip qualifies by its own ratio or by its vessel and period.
  This includes vid 1645 in 2000-2006, outside afli's converted years.
- d. *Answered (maintainer, 2026-10-29):* the fault is adb's conversion to the legacy code, and it is undone where it
  enters, at the adapter (step 4).
