# 241 — afli's skipper's remark read: the rig and the mishap as flags, a second witness for the count of trawls, and catch landed but not logged

*2026-10-29. TODOs 158 and 161, from the comparison of fishycode's merged logbook with the new mar's (plan 050 §6).
The maintainer chose each rule the same day ("Two if either says two", "`rig` and `mishap`", "A third rule in
catch_flag", "Close it, record why"). Built in ed59740, run first in a scratch store against the live one, then the
store rebuilt. Six tows that the rule missed were fixed in ea574e6 and the store rebuilt again, without the AIS catch,
which has left the store. Built and written by Claude (AI); the numbers come from its runs, and no person has checked
them.*

## The remark

afli's `stofn.athugas` is a code of its table ATHUGASEMDIR (`rafr_stofn_aths_skipstjora`, 45 codes), the skipper's
remark on a haul, until now read nowhere (the notes read the free text, `aths_texti`). Its twenties are the rig: 0-14
names none, 20-34 two trawls ("Tvö troll"), 40-54 a pair trawl ("Tvílembingar", one trawl towed by two vessels); the
rest is the mishap, 0 none, 1-14: snagged, snagged and torn, torn, headline or fishing line broken, fouled ("Óklárt"),
leg or bridle broken, sweep or footrope broken, codend holed, released ("Fráleyst"), warp broken, trawl lost, winch
broken, engine failure, steering failure. Code 0 is "no remark", not "one trawl", so the remark can confirm a twin rig
and never deny one.

## Decided and built

- **The fishing sample's `rig` and `mishap`** (afli only; NA for the other sources), flags: the haul and its catch stay
  as recorded (`AGENTS.md`: an extreme value is flagged, not corrected). `rig` on 80,554 stations (79,066 twin, 1,488
  pair), `mishap` on 273,437 (torn 89,754, snagged 82,405, codend holed 33,703, …).
- **The count of trawls is two where either witness says two**: afli's twin flag (`tvo_veidarf`, 0/1, decision 240)
  or the remark. 25,269 tows more count two trawls, basis `derived`: 19,777 bottom-trawl tows with no flag (one trawl
  `synthesised` before), 5,484 flagged single, and 8 dredges and midwater trawls. A pair trawl counts one trawl.
  - **A gap, found after the build and fixed:** the rule was applied only where afli's towing record (`toga`) is
    read. Six bottom-trawl tows have the twin remark and no towing record, and they counted one trawl, `synthesised`.
    The code comment's 19,783 includes them. The remark now gives them two trawls in the sample's assembly, which makes
    25,275 tows in all. In the scratch store these six rows were the only change to every afli and merged logbook
    table. The second rebuild is below.
  - The twin remark on 9 Danish seines and 1 purse seine changes nothing: a seine is one gear.
- **`catch_flag` rule 3, `landed_not_logged`**: a trip whose linked landing holds catch and none of whose stations holds
  any; one row per (trip, species landed), with no station (`.sid`, `sid`, `kg` NA), the landing's kilograms as the
  witness. 2,817 rows on 1,415 trips, 21.9 kt landed: afli 599 trips (21.0 kt), fs_afladagbok 792 (0.8 kt), adb 24
  (0.1 kt). Nothing is filled in.
- **From 1996 afli holds no tow without catch**, so its effort lacks the empty tows: said in `docs/output-schema.md`.

## TODO 161 closed, no code

The trial trips and test values it named are flagged already. The ten catch lines of 1,000 t or more that look like
placeholders (9,999,999 kg once, 7,999,999 six times, 3,703,703 three times; about 69 kt) are all in `catch_flag`
under rule 1 or 2. Trips with no landing show as unlinked in `lid_map`, which no rule narrows to trials: e-logbook trips
of 2021-2025 with no landing number 400-1,500 a year over 200-440 vessels.

## The rebuild

`$FISHYDATA/archive/2026-10-29-todo158-rebuild/` holds `rebuild.sh`, its logs and both fingerprints. The run was at
ed59740 with a clean tree, under DuckDB 1.5.6 and ramb 2026.10.28.3. `afli` and `catch_landing_contradicted`, whose
scripts changed, were invalidated by hand. `tar_make_isolated()` built them and the 27 targets downstream in 65 minutes
(17:43-18:48 UTC), and no target is outdated after. The AIS catch and the allocation audit were built this once. The
maintainer, during the build: "think next time around we want to drop the AIS catch from the rebuild workflow".
Later rebuilds leave both out unless asked, and say so.

The fingerprint taken after was compared with the one taken before. Each of 8,083 files falls in one outcome:

- **The same: 7,996.** The merged station, trip and catch tables are among them, and so are `trip_voyage`,
  `station_window` and the trail but for one month.
- **Rows or schema changed: 4.**
  - The staged and merged fishing samples (6,844,756 and 7,310,942 rows, unchanged) gained `rig` and `mishap`. Their
    `effort_count` and its basis moved as above, and nothing else in them.
  - `catch_flag` gained 2,817 rows: rule 3.
  - One AIS catch file of 2023 lost 40 rows: the tie below.
- **Values moved, rows and schema the same: 83.**
  - `voyage_gear` and one month of the trail (July 2023: `gid_voyage`, its class and its speed range). Nothing
    `voyage_gear` reads changed: the fishing sample's times and judged times are the same. These are TODO 139's ties.
    `arg_max(gid, n)` picks a different gear between runs under 1.5.6 (decision 239).
  - The AIS catch, 79 files in `kg` and `kg_flagged`, and the allocation audit, which reads it. The cause is that tie
    and the order of float sums. Decisions 203 and 216 measured the latter at 1e-10 kg. It was not traced row by row
    this time.
  - `landed_logged`. None of its inputs changed. Its query, run twice, differs from itself and from the file by at
    most 1.1e-15 relative: the order of float sums.

Then the user tables and the effort map's grids were rerun (`products.sh`): `user_tables.R` took 9 s, `grid.R` 5 min
45 s and `grid.R fixes` 1 min 26 s. `v0_rerun.R` summarised them before and after; its output is in
`v0_rerun_compare.log`.

- v0's `trip` and `catch` are the same. Its `station` has the same 7,301,171 rows, with `rig` and `mishap` added.
- Each of the four grids holds the same hours, kW-hours and fixes in 729 of its 731 preset-gear-years. One more is
  counted as moved only because its kW-hours are NA on both sides.
- Under `fishing_flow` in 2023, 5.0 h of hand line (gid 14) became 4.3 h of sea angling (gid 19): 27 fixes out, 22
  in. The other 0.7 h and 5 fixes fall outside sea angling's speed range. This is the same voyage tie. `grid.R`'s own
  check holds: the grid's hours, kW-hours and fixes are the trail's.

## The second rebuild: the six tows, without the AIS catch

The maintainer chose to fix the six tows before the record was committed ("Fix the 6 tows first"), and to commit first
so the build stamps a clean tree. The fix and this record so far are ea574e6. The run is in
`$FISHYDATA/archive/2026-10-29-twin6-rebuild/`, under DuckDB 1.5.6 and ramb 2026.10.28.3. `afli` was invalidated by
hand. `tar_make_isolated()` built it and the 26 targets downstream of it in 44 minutes (19:28-20:12 UTC). It left out
the AIS catch and its only reader, the allocation audit (the maintainer: "think next time around we want to drop the
AIS catch from the rebuild workflow"). Those two are the only targets outdated after.

**The AIS catch is out of the store.** The maintainer, during the build: "remove the curated product for ais catch".
After the fingerprint before was taken, `curated/ais/catch` (6.4 GB, 80 files) and v0's link to it went to the macOS
Trash, where they stay until it is emptied. The code that builds it, `curate/ais_catch.R`, stays, and builds it only
when asked. `products/user_tables.R` links the table only where it exists, and `docs/data-dict.yaml` says it is out of
the store (e8af470). `curated/check/allocation_audit.parquet` is still the audit of the removed catch, and its target
is outdated.

Each of the 8,083 files of the fingerprint before falls in one outcome:

- **The same: 7,992.**
- **Only before: 80**, the AIS catch.
- **Values moved, rows and schema the same: 11.**
  - The staged and merged fishing samples, in `effort_count` and its basis only: the six tows, as in the scratch store.
  - `voyage_gear` and six months of the trail (2008-03, 2008-05, 2010-09, 2019-07, 2022-11 and 2023-07):
    `gid_voyage`, its class, its speed range and `fishing_flow`. Nothing `voyage_gear` reads changed, so this is
    TODO 139's tie again.
  - `catch_flag`'s `vessel_kg_largest`: 51 values differ from the scratch copy by at most 2e-16 relative, the order of
    float sums.
  - `landed_logged`: the order of float sums, as above.

Then v0's user tables and the effort map's grids were rerun on that store (`products.sh`, 20:18-20:24 UTC;
`v0_rerun.R`, `v0_rerun_compare.log`):

- v0's `trip` and `catch` are the same. Its `station` has the same 7,301,171 rows, and the six tows' count moved.
- Each grid holds the same hours under `fishing` in every gear and year. Under `fishing_flow`, 6 of the 731
  preset-gear-years changed hours, all by the tie:
  - 2019: monkfish net +7.6 h, hand line −5.7 h;
  - 2023: hand line +5.0 h, sea angling −4.3 h, which undoes the first rebuild's switch;
  - 2008: lumpfish net −1.7 h, traps +0.6 h.

  The net change is +1.6 h and 9 fixes in 11.6 M hours. Two more groups count as moved: one gains a fix of no hours,
  and one only because its kW-hours are NA on both sides. `grid.R`'s own check holds.
- **A fault of the guard, found and fixed.** The first guard in `user_tables.R` asked `fd_curated()`, which creates the
  directory it names. So it made an empty `curated/ais/catch` and linked v0 to it. The guard now asks `fd_path()`
  whether the table holds files, and it removes a link left from a store that held the catch (e705b71, 71acfc1). The
  empty directory was removed by hand and `user_tables.R` run again: v0 holds no AIS catch link, and `curated/ais` no
  catch.

Closes TODOs 158 and 161.
