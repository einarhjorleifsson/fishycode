# 024 — Every source station accounted for: what the logbook merge keeps, drops, and why

**status:** proposal — measured on the build of 2026-10-16, nothing built (2026-10-17); §6 asks open (TODO 79)
· **2026-10-17**
· **see:** `curate/logbook.R`, decisions 023, 094, 123 and 124, TODO 77, 78 and 80

Drafted with AI assistance (Claude) on 2026-10-17, after the maintainer asked whether the curated logbook keeps a
record of its sources. For the records it keeps, it does: each station carries `schema`, `copy` (decision 124), its
source `.sid` and `.tid`, the basis columns of each corrected value, and every file the merge writes is stamped with
the md5 of its staging inputs (`fd.inputs`). For the records it leaves out, it does not. `curate/logbook.R` drops a
staging station by a date bound or by a (vid, date) tier, and the station is simply absent: nothing says that it
existed, why it went, or whether its catch reached the product some other way. Done-criteria 1 and 2 (AGENTS.md)
ask for exactly that account.

**Measured** (read-only, 2026-10-17, on `staging/{afli,fs_afladagbok,adb}` and `curated/logbook` as built on
2026-10-16): every count in §2 and §3. The merge's bounds and tiers were rerun in SQL on the staging tables; the
stations they keep equal `curated/logbook/station` row for row in every schema (6,844,567 afli, 374,681
fs_afladagbok, 83,223 adb), and curated holds no station staging lacks. **From decision 124, not on disk:** the 189
paper stations read from `fs_afli` and the 17 of them tier 2b drops (scratch run; they arrive with TODO 77's build).
**Assumed:** that the rules to record are those of `curate/logbook.R` today; that round weight by
`curate/catch_by_species_station.R`'s rule (gutted / 0.8) is the right scale to compare a dropped e-logbook station
with an afli one; the 1 % tolerance in §2.3.

## 1. What the merge drops, and where

| rule in `curate/logbook.R` | afli | fs_afladagbok | adb |
|---|---|---|---|
| lower date bound | none | `FS_DATE_MIN` 2020-01-01 | `ADB_DATE_MIN` 2026-01-01 |
| upper date bound | `DATE_MAX` 2026-12-31 | `FS_DATE_MAX` 2025-12-31 | `DATE_MAX` 2026-12-31 |
| vessel-day held by a higher tier | — (tier 1; tier 2b, `copy` fs_afli, yields to tiers 1 and 2) | afli | afli, fs_afladagbok, fs_afli |
| no date (`filter()` drops NA) | 0 today | 0 | 0 |

A trip goes when none of its stations is kept, and catch and fishing_sample rows follow their station. The tiers
are by station, so a trip can be split: 8 fs_afladagbok trips are today.

## 2. Measured: what each source loses, and to which rule

### 2.1 By source and reason

| source | staging stations | kept | dropped: vessel-day held | dropped: before lower bound | dropped: after upper bound |
|---|---|---|---|---|---|
| afli | 6,844,567 (45,985 kt) | all | 0 (17 of the 189 `fs_afli` stations after TODO 77, decision 124) | — | 0 |
| fs_afladagbok | 469,881 (5,420 kt) | 374,681 (3,927 kt) | 95,009 (1,493 kt), all held by afli | 165 (0.4 kt) | 26 (0.03 kt) |
| adb | 691,011 (7,418 kt) | 83,223 (780 kt) | 0 | 607,762 (6,638 kt) | 26 (0.03 kt) |

kt is the catch as recorded (`catch` summed), the weight of `curated/logbook/catch` and `curate/ais_catch.R`. Staging
holds no catch row without a station, so staging kg = kept kg + dropped kg in every schema. Trips: 20,782
fs_afladagbok and 222,743 adb trips go whole. A further 31,873 fs_afladagbok and 46,997 adb staging trips have no
station at all and go too; a table of stations cannot see them (§6 c).

Apart from adb's 2019-2025 and fs_afladagbok's 57 of 2019, the stations outside the bounds (134 fs_afladagbok, 195
adb) carry dates that cannot be right (years 3 to 800, 2027 to 2031) or are strays from 2001 to 2018, up to 50 a
year, mostly the same in both copies.

### 2.2 By year, and whether the vessel-day reached the product another way

A date bound stands in for a tier: below `ADB_DATE_MIN`, adb is taken to be redundant with fs_afladagbok
(decision 023). Whether it is can be measured: does `curated/logbook` hold the dropped station's vessel-day from any
source? Stations (kt):

| year | fs_afladagbok, tier: held by afli | adb, date bound: day held by afli | adb, date bound: day held by fs_afladagbok | adb, date bound: **day not held** |
|---|---|---|---|---|
| 2019 | — (57 below the bound, held by afli) | 1,198 (3.0) | 0 | 0 |
| 2020 | 643 (3.1) | 102,176 (931.1) | 14 (0.0) | 364 (0.0) |
| 2021 | 55,461 (770.6) | 86,182 (1,019.8) | 22,001 (19.8) | 32 (0.0) |
| 2022 | 37,093 (711.1) | 38,012 (719.0) | 65,340 (666.4) | 191 (0.2) |
| 2023 | 1,801 (8.0) | 1,803 (8.0) | 94,910 (1,349.6) | 0 |
| 2024 | 11 (0.0) | 11 (0.0) | 97,232 (934.5) | 1 (0.0) |
| 2025 | 0 | 0 | 92,879 (929.3) | **5,247 (56.5)** |
| other years | — | 61 (0.0) | 0 | 134 (0.2) |

Every station a tier drops has its vessel-day held, by construction. Of the 607,762 adb stations below
`ADB_DATE_MIN`, 5,943 (56.8 kt) are on vessel-days no source in the product holds: 5,009 of them (52.4 kt) from
2025-11-27 on (§3), 826 (4.3 kt) from 2019 to 2025-11-26, and 108 before 2019.

### 2.3 Where the vessel-day is held: a copy, or more catch than was kept?

On each held vessel-day, the dropped source's round weight was set against the round weight `curated/logbook` keeps
for it (afli records whole fish; the e-logbooks record the landed state, gutted at 0.8):

| dropped | vessel-days | equal within 1 % | kept more | dropped more | dropped excess |
|---|---|---|---|---|---|
| fs_afladagbok, tier held by afli (2020-2024) | 37,406 | 37,104 (99.2 %) | 193 | 109 | 12.5 kt (2021: 10.0, 2022: 2.5) |
| adb, date bound, day held (2019-2025) | 298,185 | 295,260 (99.0 %) | 2,722 | 203 | 14.4 kt (2021: 10.1, 2022: 4.2) |

As recorded, without the round-weight step, only 44 % of the fs_afladagbok vessel-days agree, so the comparison is
meaningless without it. The drops on held vessel-days are copies of what is kept on 99 % of days. The vessel-days
where the dropped copy holds more catch, 2021-2022 above all, are where a tier may lose kg; the two rows overlap,
since adb and fs_afladagbok are the same e-logbook.

## 3. Found while measuring: December 2025 is missing from `curated/logbook`

`FS_DATE_MAX` = 2025-12-31 and `ADB_DATE_MIN` = 2026-01-01 rest on fs_afladagbok's dump reaching the end of 2025
(decision 023). It does not: fs_afladagbok has 217 stations on 2025-11-26, 25 on 11-27, 2 on 11-28, then 4 strays
to 12-12, while adb runs on at up to 300 a day. adb's stations from 2025-11-27 to 12-31 are dropped by
`ADB_DATE_MIN`, and nothing else holds their vessel-days: **5,009 stations, 1,947 vessel-days, 193 vessels, 1,070
trips, 52.4 kt as recorded (56.3 kt round)**. None of those trips has a station kept in 2026. This is a defect in the
product, not a matter for this plan to fix; it is TODO 80. The fate table is what would have shown it.

## 4. The design: `curated/logbook/station_fate.parquet`

**Where, and by whom.** Written by `curate/logbook.R` itself, beside the four tables, through `write_curated()` with
the same inputs. The merge already holds every staging station in memory, and it is the only place the rules are
applied. A second script deriving the drops again would be a second copy of the tier rules, and copies drift
(AGENTS.md). Each tier's anti-join keeps the stations it removes, with their reason, instead of discarding them.

**Rows.** One per staging station of each source, kept or not: 8,005,459 today, 8,005,648 after TODO 77. Key
(`.sid`, `schema`), as in `curated/logbook/station`.

| column | holds |
|---|---|
| `.sid`, `.tid`, `schema`, `copy` | the staging station and trip, as in `curated/logbook` (`.tid` character; `copy` afli or fs_afli for schema afli, NA otherwise) |
| `vid`, `date` | the tier key as the merge saw it: `vid` from the staging trip, `date` as in `curated/logbook/station` |
| `kg` | the station's catch as recorded, summed; NA when it has no catch row |
| `kg_round`, `kg_round_basis` | round weight by `catch_by_species_station.R`'s rule; basis `recorded`, `reconstructed` (gutted / 0.8), `synthesised` (no condition) or `none` (no catch row) |
| `in_curated` | TRUE when the station is in `curated/logbook/station` |
| `reason` | NA when kept; else `date_before`, `date_after`, `date_missing`, `vessel_day_held`, or `other` (dropped, and no rule above names it: the merge stops instead of writing it) |
| `held_by` | for a dropped station, the highest tier holding its vessel-day in `curated/logbook`: `afli`, `fs_afladagbok`, `fs_afli` or `adb`; NA when none. For `vessel_day_held` it names the tier that won; for a date drop it says whether the vessel-day reached the product another way |
| `day_match` | for a dropped station whose vessel-day is held: `equal` (round weight within 1 %), `held_more` or `dropped_more`, the source's dropped stations of that vessel-day against what is kept; NA otherwise |

**Basis.** Only `kg_round` is an inferred value, so only it carries a basis. `in_curated`, `reason` and `held_by`
record what the merge did, as `twin` does, and `day_match` compares two weights; none is an estimate. The round-weight
rule moves into one function in `R/` that both `catch_by_species_station.R` and the merge call, so it is not copied.

**Invariants, checked by the merge before it writes** (it stops otherwise): one row per staging station; the
`in_curated` rows are exactly `curated/logbook/station`'s keys; per schema, staging kg = kept kg + dropped kg, and
kept kg = the kg of `curated/logbook/catch`; no `other`. The anti-joins match an NA `vid` to an NA `vid` (dplyr's
default). No fs_afladagbok or adb station has an NA `vid` today, but 21 afli stations do; step 2 joins with
`na_matches = "never"`, so a vessel-day with no vessel is never "held".

**What reads it.**

- `docs/merge.qmd`: a section with §2's tables by source, reason and year, read from the file. The page reads the
  staging tables today, and describes an older merge (adb left out).
- The account that done-criterion 2 asks for: this is the merge's link of kg in = kg out. The links before it (the
  adapters, §6 d) and after it (`curate/ais_catch.R`) keep their own.
- Before-and-after checks of a merge change: TODO 78's check after TODO 77's build, and TODO 80's fix.
- Not the flow. The flow reads `curated/logbook`'s four tables, and a dropped station stays out of them.

## 5. Steps

1. Move the round-weight rule into a function in `R/`, called by `catch_by_species_station.R`; its output must not
   change (compare row for row).
2. `curate/logbook.R` builds the fate table along its tiers, checks the invariants, and writes it. Test as decision
   124 did, on a scratch `$FISHYDATA`: the table reproduces §2's counts exactly.
3. Its entry in `docs/data-dict.yaml`, the section in `docs/merge.qmd`, and a decision record; this plan's TODO item
   is then deleted.
4. Built with TODO 77's build, not on its own.

## 6. Asks

- **(a)** The place and name: `curated/logbook/station_fate.parquet`, written by the merge (recommended), or a check
  in `curate/checks/` writing to `curated/check/`.
- **(b)** `kg_round` and `day_match` in the table (recommended: without round weight the copy question cannot be
  read, §2.3), or `kg` alone.
- **(c)** The 78,870 staging trips with no station: a `trip_fate` beside it, or out of scope.
- **(d)** The drops before staging (the afli adapter's 23,570 stations, decision 098; `fs_afli`'s 1,898 electronic
  stations, which are not read, decisions 123-124): later, each adapter writing its own, or never.
