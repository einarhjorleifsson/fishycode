# 288 — Plan 048 step 1: the heading switch as sharp on either clock, 4.55 M event rows out of the track, and without them the speed filter frees the own-port arrivals and more fixes than it flags

*2026-11-06. Plan 048 step 1, TODO 148, at the maintainer's word ("Yes, run it", on the measurements proposed). Measured
by Claude (AI), read-only on the store (the build of 2026-11-02, decision 274; the dump of 2026-10-16) under ramb
2026.11.05.11 and DuckDB 1.5.6; no person has checked the counts. The study, its scripts and every table:
`$FISHYDATA/archive/2026-11-06-plan048-step1/` (its README; the tables in `out/summary.md`).*

## What was measured

- **Ask b, the heading switch** (decision 233: AIS true heading to 2010-06-09 17:40, course after): every cut from
  17:30 to 17:50 by the second, on the receipt time and on the position time, counting the rows it puts on the wrong
  side (a 511 after it, a course in tenths before it), and every trail row whose two times lie on two sides of it.
- **The track with and without the event rows** (§2.2, ask d): every row of the tagged track labelled `stk_event` in one
  outcome.
- **The speed filter rerun on 2008, 2016 and 2024**: production's chain of `curate/ais_ping_clean.R`, constant for
  constant, on the tagged track as it is (a control) and without the event rows that leave; every ping in one outcome.
- **Ask c, the codes**: heading and course on every row of the tagged track, by provider and stream.

## What it found

**The switch is as sharp on either clock.** Both columns put 40 rows on the wrong side at 17:40:00 and 37 from 17:40:13
to 17:40:32 (courses in tenths sent before the switch, wrong under any cut). No row with a 511 or a course in tenths
has its two times on two sides of the cut; the 15,507 AIS-grid rows that do carry position times of 1975-2000 (one of
2007), heading 0 and speed 0. Claude's tie-break, for step 3: `posdate`, which the union carries, true heading before
2010-06-09 17:40:13.

**4,549,650 of the track's 8,460,441 event rows leave; 3,910,791 stay.** They stay as 3,904,700 own-port `I` rows
at no shared marker (3,904,337 events; plan 048 §1.3 counted 3,904,338) and 6,091 rows equal to a fix of the dump.
They leave as 4,044,067 `U` rows, 339,829 own-port `I` rows at a shared marker, 157,629 other `I` rows, 7,815 `I`
and `U` rows at one instant, and 310 rows with no event of the vessel there. The track goes from 589,261,557 to
584,711,907 rows (STK's -2.5 %). Of the 895,725 event rows production flags today, 564,754 leave and 330,971 stay.

**Without them the speed filter frees the own-port arrivals and more fixes than it flags.** The control equals the
store's labels each year (0 rows apart). Without the leaving rows:

| | 2008 | 2016 | 2024 |
|---|---|---|---|
| own-port `I` rows kept as fixes, flagged with → without | 31,711 → 15,816 | 52,786 → 3,701 | 8,041 → 997 |
| fixes freed; of them astd copies of an event row | 1,266; 0 | 11,691; 8,486 | 8,501; 5,908 |
| fixes newly flagged | 619 | 391 | 134 |

The labels explain most changes (an event row the ping's anchor or neighbour, a copy whose STK partner was an event
row, a tie); the rest lie within a day of an event row that leaves, but one fix of 2008. STK's fixes after another STK
stream are flagged 0.73 → 0.68 %, 3.45 → 3.12 % and 1.36 → 0.60 %; a third, a sixth and 3 % of their flags stay at a
switch between streams, TODO 88's question.

**The codes are as §1.6 counted them**, and STK's 511 is on every stream before the switch: 863,501 on the AIS
stream, 99,122 on event rows and 10,173 on the centiminute one.

## What it means for the plan

- The stream is already on every ping since plan 059 (`ping_stream_sql()`), as `stk_ais`, `stk_vms`, `stk_unit` and
  `stk_event`. It labels an event by time and position alone, which reaches the 6,091 rows equal to a fix and the 310
  rows with no event of the vessel. Step 3 takes the event from the dump row's own `in_out_of_harbor`.
- A code becomes NA on every stream, not only the AIS stream's heading (ask c as answered).
- "Kept by the ping filter", today's `good` in `port_call.R`, moves with the event rows alone: step 2's track test
  replaces it, as planned.

## What it leaves

- Whether the newly flagged fixes and the freed ones are right: step 3's account, or a hand sample if the maintainer
  wants one.
- Step 2, `rb_flag_port_event()` in ramb: at the maintainer's word.
- The candidate rule of TODO 192 without the event rows: plan 069's night after plan 048 is built (decision 287).
