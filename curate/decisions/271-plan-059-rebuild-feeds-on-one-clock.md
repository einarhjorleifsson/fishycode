# 271 — Plan 059's rebuild: the feeds on one clock in the store, two stops fixed on the way, every difference explained; TODOs 178 and 179 closed

*2026-11-01. Plan 059 steps 8 and 9 (TODO 178), with TODO 179's port calls and decision 268's logbook side. The
maintainer's go: "Rebuild" (from the prepared folder). At the second stop the maintainer chose the fix: "Fix the tag
pass". On the disk: "Yes, delete it" (the old scratch store), and "Write the record". Run, diagnosed and written by
Claude (AI); the numbers come from its runs, and no person has checked them. Everything is in
`$FISHYDATA/archive/2026-11-01-plan059-rebuild/` (its README, "How the run went", with the scripts behind each
explanation).*

## The run

`before.R` chose 27 targets: every outdated one, plus `ais_ping_union` and `check_ais_feed_clock`, whose scripts had
changed where `targets` cannot see. Everything downstream came with them, except `ais_catch` and
`check_allocation_audit` (decision 261). It fingerprinted their 784 output files and counted the trail and the whack
per year. `build.sh` started at 15:26 at f5285d9, with a clean tree, DuckDB 1.5.6 and ramb 2026.11.01.2 (ad088e3), kept
awake by `caffeinate`. It stopped twice. Both stops were fixed in code and committed, and the build was resumed with
`resume.sh` (`build.sh` without its invalidation, so the union was not redone). It was built at 18:41 at 7216654.
Afterwards only `ais_catch` and the audit are outdated.

1. **The tag pass ran out of memory on 2014** (19.1 GB at DuckDB's defaults), at step 9 of 27.
   - It is not the copy step's near pairs: there are 45,245 of them in 2014, against 2,902 in 2013.
   - It is not a setting either: with 4 threads and a 12 GB cap it ran out at 11.1 GB in 34 s.
   - As one lazy query over the year, some operator cannot spill. With each ramb step computed into a table before
     the next, the defaults suffice: 2014 takes 16 s and 2017 (72 M pings) 95 s. 2013 equals the one query's output row
     for row, every column.
   - Fixed in 27de860. In the rebuild the tag pass took 12 min.
2. **The trail stopped at 2014, 2 fixes over its source,** at step 15 of 19.
   - 53 astd pings were moved back across New Year by their measured lag (11-63 s): 2 from 2015 into 2014, 12 from 2016
     into 2015 and 39 from 2026 into 2025.
   - The tag pass had kept each ping in its delivered year's partition (step 8's choice, tested only on 2026, where no
     New Year is crossed). The trail takes a month by `time` and joins a fix's voyage on `year(time)`. So 2014's
     December took the two pings from 2015's files, and their voyage would have been the other year's.
   - The maintainer chose the fix in the tag pass over one in the trail, where 53 fixes would have sat under one year
     with the next year's voyage numbers. After its loop the tag pass moves each such ping to the partition of the year
     of `time` (`moved_from_<year>.parquet`), and checks that every row of the union is still there once.
   - Tested on APFS clones of the live 2014-2016 and 2025-2026 partitions. Fixed in 7216654. The tag pass was
     invalidated by hand and everything from it rebuilt.
   - An old scratch store from step 8's test was an APFS clone of the store. It held the only copy of the replaced files
     (43 GB) and left 60 GB free, under `build.sh`'s 70 GB. It was deleted on the maintainer's word, and its logs kept.

## Before and after

`after.R` fingerprinted the same targets' outputs again: 710 files changed, 3 new (the moved pings' files) and 74
unchanged. Each change is explained.

- **The union has 5,827 rows fewer** (589,267,384 → 589,261,557). All are astd's, in 2013-2019, and all are exact
  copies.
  - astd delivers some reports twice. The old forward speed, from the feed's own next-point fields, gave the two
    copies different speeds, so both survived.
  - The central difference (step 7) gives them the same speed. They are then equal in every column, and `d_for()`'s
    `union()` (SQL `UNION`) keeps one.
  - For 2015, the old branch's distinct rows less the new branch's come to 2,888, the union's loss to the row
    (`scripts/astd_rows.R`). The astd branch itself gives the same 23,855,239 rows, old and new.
- **The clean and the whack.** Kept pings rose from 580,639,236 to 580,659,851, and each year's clean reconciles (its
  own check).
  - STK's flags fell from 1,351,745 to 1,158,026 (forward −136,533, vmask −56,204, spike −982). Every one of those
    pings is now kept.
  - Duplicates rose from 6,809,368 to 7,088,752 (astd +267,752, astdB +8,088, emodnet +3,544). A copy moved onto
    STK's time is now a duplicate. So no `copy` reaches `curated/ais/ping` or the trail; the copies are in
    `ping_whacky`.
- **The trail.** It has 580,659,851 fixes, every year equal to `curated/ais/ping`.
  - 27,458,384 fixes are moved by a measured lag. These are astd's in its offset months (3,367 vessel-months of 450
    vessels, −168 to +93 s), and 6,069 of STK's VMS stream (see "Left").
  - STK's `fishing` and `fishing_flow` change by less than 1 % in every year. astd's `fishing_flow` hours change by
    −0.1 to −1.9 %, but by −7.0 % in 2017 (fixes −5.0 %), and emodnet's by −2.7 % in 2017. This is the speed stamp
    (step 7 measured −0.15 % on 2019), and has not been looked into further.
- **Port calls** fell from 1,631,285 to 1,623,781 and voyages from 1,430,712 to 1,428,823. This is TODO 179's merge
  and the clock. `check_port_call_logbook` lost 79 rows, `check_vessel_activity` 556 and `trip_voyage` 142.
- **Unchanged:** the place names (all 5 files), `station_window`, `station_note`, `catch_by_species_station`, the
  logbook app profile, the user tables' check, and 64 months of `trail_match` (2007-2012 and July-October 2026).
  Decision 268's logbook side therefore changed no station window and no place name.
- `before.log`'s per-year trail print understated some years. It used `aggregate(... ~ year)`, which drops groups
  with an NA sum. `trail_before.csv` is right: for 2024, 32,999,360 fixes, not 32,200,866.

## The feeds on one clock (TODO 178's check)

The test on the Icelandic feeds is plan 059's steps 1, 3 and 5 (decision 270, `curated/check/ais_feed_clock`). It is
now in the data:
- Every ping has a `stream`.
- A ping is moved by its own lag if it copies a report STK's streams hold. Otherwise it is moved by its vessel-stream-
  month's lag where the check finds an offset.
- `time_delivered`, `lag_s` and `lag_basis` stand beside the harmonised `time`, in `staging/ais/ping_tagged`,
  `curated/ais/ping`, `ping_whacky` and the trail.
- `curate/corrections/ais_feed_clock_offset.yml` is repaired in the data.

**The trail's windows are corrected.** Everything downstream of the tag pass reads the harmonised `time`: the duplicate
flag, the whack (with TODO 88's 0.3 nm floor between feeds), the port calls and voyages, the station windows, the
±10 min speed window behind `fishing`, and the effort intervals.

**Its turns:** the trail derives no turn. Its `speed` is a feed's own reading, or derived within one MMSI (astd,
emodnet). The rule "derive within one stream" (AGENTS.md, Rules) governs any turn or spread a consumer derives, plan
058's labeller included. Harmonised times put the streams' pings in the right order. They do not make a turn across
two feeds' positions safe, since 18-27 % of the merged intervals are under 60 s and the feeds' positions differ by
hundreds of metres.

## What closes

- **TODO 178** is deleted. Its check is met here, and plan 059 is executed. Plan 048 (STK's streams into the flow) and
  TODO 117's `stk_receipt` were left by the maintainer for a later rebuild of the same stages.
- **TODO 179** is deleted. Its check:
  - the fix is built (ramb 2026.11.01.1, `curate/port_call.R`);
  - the rebuild's fingerprints are compared (`after_files.csv`);
  - 26,451 port calls span New Year, and none is cut at the stroke. 37 pairs at one port lie 6-90 min apart across
    midnight; these are departures and returns.
- **TODO 88** is told the floor and the evidence are in the data. It stays open on its own check: a plan with the
  filter's recall and precision.
- `docs/data-dict.yaml` describes the five columns in `ais_ping` and `ais_trail`, and the new table `ais_ping_whacky`
  with the whack's evidence. `validate-spec`'s JSON report gives the same 10 errors and 261 warnings as before, and the
  new table passes `validate-meta` and its 35 data checks. Its text report panics on a snippet that the longer file
  puts across an "í" (a bug in the CLI's renderer); the JSON report does not.

## Left

- **Eight vessel-months of STK's VMS stream in 2007-2010** (6 vessels) were judged offset, and their 6,069 pings were
  moved by the rule. Three of them are vids 975 and 1809, by −51 to −67 min. *Looked into the same evening at the
  maintainer's word* (`scripts/vms_hour_lag.R`, `notes/vms_hour_lag.log`): the hour is a unit's clock, real and not
  steady.
  - **One unit, two streams.** Each vessel's VMS and AIS streams come from the same STK mobile id (101092 for vid 975,
    101499 for 1809), so the VMS track is no other hull's.
  - **The shift scan.** The VMS stamps were shifted by every minute from −30 to +120 and compared with the AIS track
    interpolated at the shifted time.
    - Vid 975, October-November: 3.0 km apart unshifted, a sharp minimum of 258 m at +57 min.
    - Vid 1809, December: 22.3 km apart unshifted (11 kn for an hour), 264 m at +69 min.
    - The control, vid 2677 (lag −69 s): 82 m at +1 min, 87 % of pings within 200 m.
  - **Not a mispairing.** A position paired with the previous report's stamp would give each ping a shift equal to its
    interval to the next report. It does not: correlation 0.19 for vid 975 and −0.21 for 1809, against intervals of
    14-62 min.
  - **The clock moves.** Vid 975 was 54 min late in October and 64 in November. Vid 1809 was on time in September,
    an hour late for 62 % of its pings in October, 38 % in November and all of them in December (69 min).
  - **What the store holds.** The monthly lag brought 975's two months and 1809's December from 3-22 km to about
    260 m, three times the control's residual, since the error drifts within a month. 1809's October and November
    (3 and 0 pairs, not measurable) were not moved, so about half of its 1,012 VMS pings in those two months are an
    hour off.
  - **Not measured:** how many other VMS units do the same in months the check cannot measure.
- astd's 2017 `fishing_flow` hours, −7.0 %.
- The effort map's two grids (`products.sh`) are built from the trail and are no target. They were rerun the same
  evening on the maintainer's word and finished at 19:15 (`products.log`). Their check passed: the hours, kW-hours and
  fixes of all 730 preset-gear-years equal the trail's (`fishing` 9,169,792 h, `fishing_flow` 11,361,216 h). The user
  tables (target `user_tables`) were rebuilt and link the new trail. Release 2026.10.31.1 is frozen and untouched.
- Plan 048 and TODO 117, in a later rebuild of the same stages.
