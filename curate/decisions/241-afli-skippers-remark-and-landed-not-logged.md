# 241 — afli's skipper's remark read: the rig and the mishap as flags, a second witness for the count of trawls, and catch landed but not logged

*2026-10-29. TODOs 158 and 161, from the comparison of fishycode's merged logbook with the new mar's (plan 050 §6).
The maintainer chose each rule the same day ("Two if either says two", "`rig` and `mishap`", "A third rule in
catch_flag", "Close it, record why"). Built in ed59740, run first in a scratch store against the live one, then the
store rebuilt. Built and written by Claude (AI); the numbers come from its runs, and no person has checked them.*

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

Closes TODOs 158 and 161.
