# 290 — Plan 048 step 3: the new chain on a scratch store, every year; port calls lose 19,241 and gain 26,488 with the good events only, and a hand check comes before the rebuild

*2026-11-06. Plan 048 step 3, TODO 148, at the maintainer's word ("Yes, as recommended" on the design and run plan;
"Tag year by year" when the disk ran short). Written, run and counted by Claude (AI); no person has checked the code
or the counts. The code is on fishycode's branch `plan048-step3` (76484d6, cbc77ae), not on `main`. The study, its
scripts and every table: `$FISHYDATA/archive/2026-11-06-plan048-step3/` (its README, `out/account.md`).*

## What was built (on the branch)

- **`stk_trail()`**: `stream` (`ais`, `centiminute`, `ungridded`, the grid rule the tag pass used), `heading` (true
  heading on the AIS stream before 2010-06-09 17:40:13), `cog` (course from then, and on the other streams), codes NA;
  `tests/test_stk_trail.R` (7 expectations, no data).
- **The union**: STK's event rows out but an arrival inside its own port at no marker (read from `stk_event`, a new
  edge); every provider's heading and course codes NA; STK's `stream` and `io` carried.
- **The tag pass and the feed-clock check**: the stream from the union's own columns, a kept arrival `stk_event` by its
  own `io`. The tag pass also runs year by year (`TAG_YEARS`), each year in a fresh process: on the scratch store its
  DuckDB spill reached 34 GB by 2017 beside a second union and the run stopped itself.
- **`sources/stk/event.R`**: STK's adapter only (`mid`, `marker`; `io_dup`, `io_short`, `io_ok` gone to ramb's step).
- **`curate/port_call.R`**: STK's events judged year by year by `ramb::rb_flag_port_event()` against the cleaned track,
  the 2017 cut gone (decision 196), `STAY_EVENTS` `"all"` (every judged event to the pairs, as before) or `"good"`.

## What the scratch run found

On a `cp -c` clone of the store, every year, from a clone of the branch:

- **The union** loses STK's event rows as step 1 counted them, year by year, but for 2,391 rows net not traced row by
  row (1,633 in 2009); every row of it tagged once. The speed filter flags 7,559,645 pings against the store's 8,504,968.
- **Port calls** against today's 1,623,775:

| | every judged event | good events only |
|---|---|---|
| the same / changed / split | 935,774 / 651,990 / 3,902 | 934,875 / 664,507 / 5,152 |
| lost | 32,109 | 19,241 |
| new | 24,328 | 26,488 |

- **The lost calls stood on STK's event rows used as pings.** With the good events only: 11,478 have an arrival but no
  departure event at their port, 521 a departure but no arrival, 2,329 no event there at all, 4,316 an event flagged
  (repeat 2,497, track 1,016, flicker 794, other port 9), 62 an event the track could not judge, 535 a good pair that
  made no call. Passing every event, repeats break 11,127 more.
- **The new calls**: 17,062 event pairs before 2017 (decision 196's gain), 4,316 from 2017 on pairs today's tags did not
  trust, 353 on pairs they did, 4,757 from pings alone.
- **The changed calls**: from 2017, of 234,886 one-to-one, 1,746 T_in and 1,800 T_out moved by over 6 h, 76,272 T_out by
  10 min to 1 h; 3,511 change port.
- Of the 5,951 calls today that rest on events alone, 4,035 stay the same, 1,294 change, 621 are lost.

## What was chosen

Nothing yet. Claude's reading: `STAY_EVENTS = "good"` is the better setting (12,868 fewer lost for 2,160 more new);
whether the lost calls were real, and the new ones are, is not settled by counts. Plan 069's 21,600 lost calls were
judged by hand; these get the same before step 4.

## What it leaves

- **A hand check** of a sample of the lost and new calls (and the moved), on a review page, at the maintainer's word.
- **`STAY_EVENTS`'s default** (the branch has `"all"`) and **merging the branch**: the maintainer's, after the check.
- **The scratch store** (`/Users/einarhj/stasi/scratch-048-step3/`, 44 GB of its own; the disk at 26 GB free): delete at
  the maintainer's word, and before any live rebuild.
- **Step 4** (the rebuild) and step 5 (products, docs, `stk.yml`, AGENTS.md).
