# 129 — The rebuild of 2026-10-17, second half: the AIS chain on the redone STK key

*2026-10-17. Run and checked by Claude (AI-assisted) on the maintainer's go. fishycode 50f84b0, ramb 2026.10.15.1.
The scripts, the build log, the fingerprints and the counts are in `$FISHYDATA/archive/2026-10-17-rebuild/`
(`before_ais.R`, `build_ais.R`, `after_ais.R` and their logs). Completes TODO 77, whose first half is decision 127;
the key it reads is decision 128's.*

## What was run

- **Before:** fingerprints of the 5,164 files the store records (5.1 min), and counts of the trail, the catch and plan
  026 §8.5.
- **Build:** a plain `tar_make_isolated()` of the 21 outdated targets, detached under `caffeinate`, from 18:26:23 to
  20:23:22 UTC. 21 of 21 were built and the run ended "ALL DONE". The 21 are decision 127's 20 and the main
  project's file target for the key. The longest steps were `ais_trail` (32.5 min) and `ais_catch` (20 min). No
  tracked file was edited while it ran.
- **Warnings:**
  - `ais_ping_union`, `vessel_ais_link` and `ais_catch` give the SQL aggregation notice on missing values;
  - `vessel_ais_link` also has "NAs introduced by coercion" in its `vid` `case_when`.

## After

- `tar_outdated()` is empty.
- `check_sync()`: all 761 curated files are stamped. The 687 this build wrote carry 50f84b0 and `fd.dirty` false.
- **Fingerprints, against before this half:** only the AIS stack changed:
  - `staging/ais/stk`, `ping_union`, `ping_tagged` and `ping_clean`;
  - `stk_event`;
  - `curated/ais/` (port stays, voyages, voyage gear, `ping`, `trail`, `trail_match`, `catch`);
  - `curated/link`;
  - five checks.

  New to the store:
  - decision 115's `curated/vessel/vessel_ais_link.parquet` (655,184 rows), built for the first time;
  - its two checks (`vessel_ais_link_review` 3,023 rows, `vessel_ais_link_routes` 534);
  - four `staging/ais/stk` partitions holding 14 pings with stray timestamps (1936, 1997, 1999, 2032), whose units
    now carry a vid. The union starts in 2007, so they go no further.
- **Against decision 127's after set** (`fingerprints_after_pre.rds`): the same, plus the key (19,323 → 20,710 rows,
  decision 128). Nothing else in the store differs.

**The trail**, 584,391,263 → 584,827,322 fixes (+436,059), more in every year:

| provider | fixes before | after | of them SKB, after |
|---|---|---|---|
| stk | 180,516,611 | 180,955,408 | 366,749 |
| astd | 348,410,072 | 348,408,879 | 4,796 (was 5,313) |
| astdB | 10,710,478 | 10,708,933 | 9,775 (was 11,281) |
| gps | 26,823,062 | 26,823,062 | 0 |
| emodnet | 17,931,040 | 17,931,040 | 0 |

- **STK's SKB pings reach the trail.** 368,784 are in the union, and the clean step's generic filters leave
  366,749. They are on 185 vids, 2008-05-02 to 2026-10-16. All are leisure (`leisure_basis` "skb") and none is
  fishing.
- **The ASTD and astdB fixes that fell:** `ais_ping_clean` drops a lower-priority feed's copy of a fix STK already
  has (`FEED`, STK first). The copies of the newly keyed SKB and Icelandic units now go: 2,023 SKB fixes and 715
  others.
- **Fixes on a logbook station:** 158,378,684 → 159,001,502 across the providers, from the 8,894 stations decision
  127 added.

**The catch** (`curated/ais/catch`, both approaches): 28,072.71 → 28,085.62 kt. `ais_catch.R` stops unless kg in
equals kg out for every year and vessel group, and it did not stop. Under `fishing_flow`, by source and basis:

| | before, kt | after, kt |
|---|---|---|
| logbook, on fixes | 22,093.43 | 22,390.19 |
| logbook, no fishing fix | 866.42 | 907.71 |
| landing, on fixes | 3,796.48 | 3,534.11 |
| landing, no fishing fix | 1,316.38 | 1,253.61 |

The catch decision 127 added to the logbook moves from the landings path to the logbook's: adb's late-2025 trips and
the ERS hauls had been counted by their landings in Iceland.

## Plan 026 §8.5 and §8.6

**§8.6 passes.** For the foreign ERS vessels in 2014-2018, kg in (their logbook catch and their landings with no
logbook trip) is 507.30 kt and kg out 507.30 kt under both approaches, equal in every vessel-year. 280.27 kt of it is
the ERS hauls, on the record path (source logbook):
- 232.96 kt lies on fishing fixes (`fishing_flow`), most of it at day resolution (225.56 kt), since a purse seine's
  window is its day;
- 47.31 kt is kept with basis `none`: its unit, trip and vessel-month hold no fishing fix. These vessels reach the AIS
  only through STK; ASTD's foreign hulls wait for plan 021 step 6.

**§8.5 holds as the design allows, not as the plan worded it.** The plan expected the foreign hauls with fixes to be
"on their station windows", and counted 2,191 hauls with a fix between `t2` and `t3`. Measured on the new trail:
- 2,277 of the 2,778 foreign hauls have a fix of their vessel inside their own station window;
- 1,883 of the 1,903 hauls with `t2` and `t3` are purse seines (gear class `other`), whose window is the synthesised
  day;
- every fix inside a foreign haul's window is accounted for. Where the haul is the vessel-day's only window, the fix
  carries the haul's `.sid`: 1,028 hauls. Where the day holds two or more hauls' day windows, the fix carries no
  single station and `n_sid` = the number of hauls (2 to 8).

That is decision 091's exclusive windows, "one fix, one record", and it is not particular to the ERS rows. In afli
2016, 28,211 of 28,742 day-window stations alone on their vessel-day are on fixes, and none of 2,096 on vessel-days
with two or more. The catch is not affected: `ais_catch` makes one unit of a vessel-day's day-window stations. Whether
a fix on such a day should name its hauls is a question for the trail (plan 026 records it), not for this build.

## Left

- TODO 77 is deleted.
- TODO 25 carries the next key redo.
- Plan 026 records §8.5's reading and §8.6.
