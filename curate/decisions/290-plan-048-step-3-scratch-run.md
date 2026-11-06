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

- **Only the good events go to the pairs** (`STAY_EVENTS = "good"`, the branch's default since e8006d6). The maintainer,
  the same day: "“Good events only” is my recommended setting - should we not just proceed with that?" It loses 12,868 fewer of today's calls than every event, for 2,160 more new ones.
- Whether the new port calls are better than today's (19,241 lost, 26,488 new) is not settled by counts. Plan 069's
  21,600 lost calls were judged by hand; Claude recommends the same here before step 4's rebuild.

## What it leaves

- **A hand check** of a sample of the lost and new calls (and the moved), on a review page: after plan 048 §7's design
  (below).
- **Merging the branch**: the maintainer's, after the check.
- **The scratch store** (`/Users/einarhj/stasi/scratch-048-step3/`, 44 GB of its own): deleted 2026-11-06 after step 3c,
  the hand check put off ("Not now"), at the maintainer's word ("i trust you here, proceed"); the disk back to 70 GB
  free. The study's README says how to rebuild it for the hand check (about an hour).
- **Step 4** (the rebuild) and step 5 (products, docs, `stk.yml`, AGENTS.md).

## The course changed (added 2026-11-06)

- **The THH/THO departures.** At the maintainer's word ("Yes, fix and rerun") `event.R` gave a departure under a code
  that names no port (THH, THO: `BY_POSITION`, settled 2026-10-01, plan 011), lying in no polygon, the pid of the
  vessel's arrival just before it under the same code (e10e2c3, `pid_basis`): 65,535 departures. Rerun on the scratch
  store, the port calls lose 8,845 of today's and gain 26,954 (`out/calls_good2.csv`); not built on.
- **The maintainer, then:** "I am a little bit worried that we may be going in the wrong direction here. what is your
  verdict?" Claude's: the goal stands (steps 1 and 2), but the first design took away the presence the event rows gave
  the port calls as pings and put back only pairs, so each gap became an STK patch, and it bundled the dropped 2017 cut.
  The maintainer: "Yes, revise the plan". Plan 048 §7: the good events back as presence in the port-call rules (a ramb
  option), the 2017 cut kept for the pairs, events before 2017 a step of their own with the logbook's dates as witness.
  The hand check waits for that design. §7.5's asks answered as recommended ("Yes, as recommended"), and §7.4's step
  3a built ("Yes, build it"): ramb 2026.11.06.1 (1f720f6), `rb_create_port_calls(presence = )`, installed, not pushed.

## Step 3c: the good events as presence (added 2026-11-06)

At the maintainer's word ("Yes, go ahead"): ramb 2026.11.06.1 installed; `port_call.R` on the branch passes every good
event as presence at its recorded position, the pairs from 2017 (79f021d). That first run was wrong: the events of the
years either side, passed for the pairs, became presence with none of their pings around them, and made 22,005 stays
of a median 6 months, absorbing 268,972 of today's calls. With presence from the run year's own events (0b60ad4):

| against today's 1,623,775 | |
|---|---|
| port calls | 1,628,605 |
| the same | 1,421,991 (88 %) |
| changed / split / merged | 182,326 / 8,142 / 5,285 |
| lost | 11,316 (2,194 from 2017) |
| new | 10,022 (5,057 from 2017) |

Of the changed calls one to one, the ends moved by up to 1 h on about 96 %. The lost calls: an event flagged by repeat,
flicker or track 6,241; a good pair that presence did not rebuild 2,647 (2,404 before 2017, where pairs are withheld);
no departure or no event at the port 1,977. The logbook's own dates witness 2017 on only: there the lost calls look like
ordinary calls (5 of 134 judged inside a logbook trip, the unchanged calls about 5 %), so losing them is a loss. Not
settled by counts: the flagged events of the lost calls, the pre-2017 pairs presence does not rebuild, the new pairs.
A hand check of a sample is next, at the maintainer's word.
