# 059 — The feeds' clocks: the first test on every track, right after the union, and the feeds harmonized before any speed or turn is derived across them

**status:** partly built — written 2026-11-01 at the maintainer's request ("Feed clocks first"), from the drafts plan
058's study left, reviewed against the code and one new measurement; steps 1 and 5 run as a study the same day, step 2
built in ramb (2026.11.01, installed), step 3 built as the target `check_ais_feed_clock`; the tag pass (§3) and the
rebuild not built; asks a-h (§7) answered by the maintainer 2026-11-01, each as recommended, b amended by step 5
(TODO 178) ·
**2026-11-01** · **see:** decision 270 (its section "Time is an observation"), decisions 164, 196 and 233, TODO 88 (the
whack's distance floor, §8c), TODO 117 (`stk_receipt`), plan 048 (STK's streams into the flow), plan 013 (ramb's step
0), `curate/ais_ping_union.R`, `curate/ais_ping_tag.R`, `curate/ais_ping_clean.R`,
`curate/corrections/ais_feed_clock_offset.yml`, `curate/corrections/ais_cross_feed_duplicates.yml`

Drafted with AI assistance (Claude) on 2026-11-01. The framing is the maintainer's (2026-11-01, during plan 058's
study): time is an observation with an error of its own, like position; the first test on any track is how many clocks
it holds; the task is to harmonize the feeds, not to find true UTC; the dt patterns first, a derived speed only
confirms; fix it upstream. The design is Claude's, from the study's draft (`$FISHYDATA/archive/2026-11-01-phase-model/notes/2026-11-01-feed-clocks-records-draft.md`)
as amended in §1. No person has checked it.

**Measured:**
- decision 270 and its study (`$FISHYDATA/archive/2026-11-01-phase-model/`, scripts 02 and 10-14): astd behind stk by
  30-75 s from September 2015 to January 2016 and 15-90 s from October 2025 to May 2026, 0 from February 2016 to
  September 2025 and in June 2026; on the 2026 survey the offset is a position error along the track (−165 to −452 m,
  growing with speed, one lag of 85-87 s) and none across; merged, 18-27 % of the intervals are under 60 s and the next
  ping comes from the other feed 45-64 % of the time; speed derived across feeds 85 s apart drops the pings inside tows
  labelled towing from 95 to 58 %;
- STK's time by stream (Claude, 2026-11-01, `$FISHYDATA/archive/2026-11-01-feed-clocks/`): §1 item 2;
- in the code (read 2026-11-01): astd's speed in the union is `dist_nextpoint / sec_nextpoint`, a forward difference
  stamped at the interval's start; astdB's speed is the feed's own field, labelled `derived`; the cross-feed duplicate
  flag takes a lower feed's ping within 10 s and 128.6 m of a higher one; `ping_union` is 17 GB, `ping_tagged` 17 GB,
  `ping_clean` 16 GB (`du`).

**Assumed:**
- that STK's server clock is right: it gives the offsets their direction, not their size;
- that one lag per vessel, stream and month is fine enough (2026's moved by month): step 1 shows where it is not;
- that astd's copies of stk's reports escape the duplicate flag in the offset months (§1 item 5): step 1 counts them;
- that aligning first removes most of the whack's false removals in those months (decision 164: 63 % of the supported
  removals are cross-feed legs within 0.3 nm; TODO 88 §8c: a lag varying by year): step 5 measures it.

## 0. Where this stands

- **The cascade today:** the feeds meet in `ais_ping_union` (preprocessing; each feed's speed derived within the feed)
  → `ais_ping_tag` (flow step 0, the port flag; rewrites every ping) → `ais_ping_clean` (the duplicate flag, then the
  whack's step speeds, both across feeds) → `port_call`, `ais_voyage` → the trail → links, effort, user tables.
- **What reads across feeds:** the duplicate flag, the whack, decision 164's witnesses, TODO 88's floor and plan 058's
  turns and spreads. The trail's `speed` does not, so the flow's speed filter is safe from the offsets.
- **TODO 88's remedy** is a distance floor between feeds inside the whack (0.3 nm frees 22 % of 2016's false removals
  and 80 % of 2026's). It treats the symptom downstream, and no one floor fits every year (§8c).

## 1. What the review of the study's draft changed

1. **No second decision record.** Decision 270 holds the measurements and the study the detail; this plan cites them.
   Two records of one fact drift.
2. **STK's time did not change meaning about 2011; its streams' mix did.** The study measured the whole trail by month.
   Split by STK's three streams (decision 233, by the position's grid; port events left out):
   - the AIS stream is stamped at receipt (or within its second) in every year 2007-2024: `posdate` = `recdate` for
     87-99 %, median gap 0. 2009's 61 % is decision 233's clock episode (2009-09-14 to 2009-10-05);
   - STK's own units (no grid) stamp their own time, a median 3-5 s before receipt. They were 76 % of 2007's fixes and
     0.2 % of 2012's: that is what moved the share;
   - the centiminute (VMS) stream lies 1.4-3 min before receipt to 2010, and is mostly stamped at receipt from 2012;
   - **the change of meaning is May 2025, within the AIS and centiminute streams:** equal 99.2-99.4 % from January to
     April 2025, 65 % in May, then 25-94 % by month to October 2026. The astd lag begins five months later.

   Decision 270's sentence is amended to this.
3. **No split by delivery channel.** `comsystemid` is 100 on every row (decision 233). The test's unit is STK's stream,
   told by the grid.
4. **No third full copy.** The draft put the harmonizing in a new stage between the union and the tag, a third 17 GB
   copy of every ping. The tag pass rewrites every ping already; the lag is applied there, from the check's small
   table (ask c).
5. **The duplicate flag is at risk in the offset months.** If astd's ping is a copy of stk's report stamped 45-90 s
   later, it falls outside the flag's 10 s and stays in the track as a second ping a minute off, which the whack then
   judges. Not counted yet: step 1 counts them.
6. **astd's speed stamp is not a source fact.** Moving it from the interval's start to its midpoint (or a central
   difference within astd) changes the flow's speed on 61-76 % of the pings, so every fishing filter and effort sum. The
   study's evidence (the model's D 3.3 min early with it, 1.2 with speed derived up to each ping) is a hint. It is
   measured on effort before it is adopted (step 7).
7. **"Prefer not to merge" was left out of the draft.** The study's method had it as step 2: per vessel and period one
   regular stream is the track, the others only fill its gaps. Against it: the study's own table (2019 survey, both
   ends within 10 min) gives 78.3 % merged, 76.7 % astd alone, 63.0 % stk alone; and every ping is in the product. The
   recommendation: keep every ping, carry its stream, align, and derive within one stream (ask d).

## 2. The first test: `check_ais_feed_clock`, right after the union

A standing check, read-only, run on every rebuild: `curate/checks/ais_feed_clock.R` →
`curated/check/ais_feed_clock.parquet`, a target that reads `ais_ping_union`. Nothing waits on it but the alignment (§3).

**Its unit** is the vessel, the stream and the month. A stream is the provider, and STK's three by their grid; the
logger is its own.

**Per unit**, in the order the maintainer gave (the dt patterns first):
1. *the dt pattern:* pings; the stream's own cadence (the median interval within it) and phase; pings off its grid; in
   the merged track, the share of intervals under 60 s and of consecutive pairs that cross streams;
2. *recording or receipt:* for STK's streams, the share of `posdate` equal to `recdate` and the median gap (by stream
   and month, from the dump: §1 item 2 in 3 s);
3. *the lag against the reference stream* (ask a): the shift that brings the stream's track, interpolated, closest to
   the reference's positions, on moving pings (reference speed over 2 kn), with the distance at the best lag and at none
   and the pings it rests on; the along- and across-track split by speed, a slope along being a clock;
4. *copies the duplicate flag misses:* pairs from two streams within a few metres of each other and 10-180 s apart.

**Every unit in one outcome:** aligned (best lag 0), offset (a lag clearly better than none, by a fixed rule), not
measurable (too few moving pings in both), one stream (nothing to compare). A summary by stream and month beside it.

A new dump with a new offset, or a stream whose time changes meaning, then shows on the next rebuild without anyone
having to remember.

## 3. The harmonizing, in the tag pass

`ais_ping_tag` reads the check's lag table and writes, beside each ping:
- `time`, harmonized: where the ping is a copy of a report the reference stream also holds (within 2 m, at most
  180 s), the delivered time minus that copy's own gap; else the delivered time minus the unit's lag where the outcome
  is "offset"; else unchanged. Step 5 showed why both: a month's lag alone pushed 3,500-14,300 copies a year that were
  on time a minute off, and left 2,000-23,500 late ones unflagged (ask b, 2026-11-01);
- the delivered time kept beside it, with the lag and its basis (`copy`, `measured`, `none`, `unmeasured`), as
  `w_lon`/`w_lat` stand beside `lon`/`lat` (names to TODO 127);
- the ping's stream.

A ping whose stream or lag cannot be told is flagged, not moved. The duplicate flag and the whack then run on
harmonized time. Declared as `curate/corrections/ais_feed_clock_offset.yml`, its implementation named there when built.

**Why here.** Not earlier: a lag needs two feeds, and a source adapter reads one. Not later: every stage after it
derives across pings (the duplicate flag, the whack's step speeds, port calls, turns, the trail's windows).

*A candidate, 2026-11-01* (the study's `scripts/10_tag_pass_candidate.R`, its README "Step 3 and the tag pass"): run on
a scratch store for 2016 and 2026 with the flow's whack unchanged after it, every row in and out once. Against the live
run in 2026 the whack's false removals of STK pings fall from 97,535 to 9,622 for 55 true ones, the late copies are
flagged (90,764), only 267 on-time copies come apart, and reversals between feeds fall from 12.5 to 2.4 %. To adopt it:
the script in place of `ais_ping_tag.R`, the check among its dependencies, `ais_ping_clean.R` carrying the four new
columns, then step 8's rebuild.

## 4. Generic, in ramb: step 0 of the one flow

Before `rb_flag_ping_impossible()`, as functions any dataset can call:
- the streams from the dt pattern (cadence, phase, off-grid pings), for data with no provider column;
- the lag between two streams: position alignment for dense streams, the along-track residual pair (−d, +d) for a
  sparse intruder;
- the alignment, the delivered time kept.

Tested on ramb's `dansk` (289 single pings about 40 s late in a 10-s stream, 201 off its grid) and on the Icelandic
check. §2 and §3 call them; until they are in ramb, the check's queries are a study's.

## 5. Steps

1. **The check in a study** (`$FISHYDATA/archive/2026-11-01-feed-clocks/`): §2's four parts on the current union for
   2016 and 2026 (the offset years TODO 88 prototyped on) and 2019 (none), then every year; timed. Its outcome table,
   and the missed copies counted. *Run 2026-11-01 (the study's README, "Step 1"):* 589 M pings in 105 s; astd offset
   from STK's AIS stream in September 2014 to January 2015, March 2015, August 2015 to January 2016, some vessels in
   August 2025, October 2025 and December 2025 to May 2026 (10-86 s), 0-1 s between; vessels differ within some months,
   so a lag per vessel and month (ask b); the duplicate flag misses 266 thousand of astd's copies of STK's fixes, 50-76 %
   of the copies in the offset years, and in 2023-2025 some of STK's own late deliveries (−27 to −71 s).
2. **ramb's step 0 functions** (§4), checked against step 1's numbers and on `dansk`. *Built 2026-11-01 on ramb's
   branch `feed-clocks-step0`, not merged or pushed (the study's README, "Step 2"):* `rb_add_ping_stream()` (the dt
   pattern), `rb_create_ping_lags()` (the lag per vessel, stream and period, with its outcome), `rb_add_ping_own_lag()`
   (a copy's or a displaced ping's own lag) and `rb_add_ping_time()` (the harmonized time, the delivered time beside,
   the lag and its basis: `copy`, `residual`, `measured`, `none`, `unmeasured`). On 2016 and 2026 the lag equals step
   1's SQL on every unit once it runs on ramb's sphere and takes a stream's same-time pings by a fixed rule; step 1 as
   run differs by those two alone (every outcome kept but one at the 30-pair bound). The copies are step 1's, plus
   20 (2016) and 1,143 (2026) whose STK fix was not the nearest on its side; the aligned time is step 5's but for 1-3 s
   where a lag rounds to another second. `dansk`: 288 pings some 39 s late and one early.
3. **The check as a target** after `ais_ping_union`, calling them. *Built 2026-11-01* (`curate/checks/ais_feed_clock.R`,
   target `check_ais_feed_clock`, `curated/check/ais_feed_clock.parquet`, 467,647 vessel-stream-months 2007-2026, 3 min
   20 s; fishycode 0c06c93, ramb 2026.11.01): every unit has an outcome; astd's offset vessel-months by year equal step
   1's but at the 30-pair bound (646 / 647 in 2014, 1,498 / 1,497 in 2015, 387 / 388 in 2025), and its copies beyond
   10 s step 1's plus those step 1's join could not reach (2014: 24,706 / 23,669; 2026: 91,575 / 90,445). The logger
   keeps its outcome, "reconstructed positions", and no lag.
4. **STK's time semantics by stream** in `dump/oracle/meta/stk.yml` (§1 item 2), with an assertion on the share equal by
   stream and period that `check_data_dict()` tests when a dump is adopted; astdB's `speed_basis` `recorded`, at the next
   union build.
5. **The alignment in scratch** on 2016 and 2026: the duplicate flag's and the whack's removals before and after, against
   decision 164's witnesses. *Run 2026-11-01, with 2015 added (the study's README, "Step 5"):* the as-delivered run
   equals `ping_whacky` ping for ping; aligned, the whack's false removals of STK pings fall 56 % (2015), 11 % (2016)
   and 90 % (2026) for 0.4-1.1 % of its true ones; reversals between feeds fall to about the rate within one feed
   (2026: 12.5 to 2.7 %); the duplicate flag catches 69-76 % of the late copies, but 3,500-14,300 copies a year that
   were on time are pushed apart, so a lag per vessel and month is the bulk and a copy's own lag the rest; the 2026
   survey's labels gain 4 points (both ends within 5 min, 46.7 to 50.9 %).
6. **TODO 88 re-measured on aligned pings:** its floor kept, shrunk or dropped.
7. **astd's speed stamp**, the midpoint or a central difference within astd, measured on one year's effort by gear
   before it is adopted.
8. **The rebuild from `ais_ping_union` down**, bundled with TODO 88, plan 048 and TODO 117's `stk_receipt` (the same
   stages), clocks first.
9. **A decision record;** AGENTS.md's Layout row for `curate/` names the check and the alignment.

## 6. What it does not do

Find true UTC; correct a feed's absolute time; touch the source adapters; change STK's receipt lag as a label (decision
196); decide the whack (TODO 88); drop a ping.

## 7. Asks

**Answered** by the maintainer, 2026-11-01, each as recommended below; b as amended after step 5 (a copy's own lag
before the month's). h is in `AGENTS.md` under Rules.

| | Ask | Recommendation |
|---|---|---|
| a | The reference stream | STK's AIS stream where it sends, else the densest regular stream; a convention, recorded per row, not a claim of true UTC |
| b | The period of one lag | a month per vessel and stream, overridden per ping where a copy of the same report gives that ping its own lag (step 5) |
| c | Where the lag is applied | in `ais_ping_tag`, which rewrites every ping already, not a new 17 GB stage |
| d | Align, or one stream per vessel and period with the others filling gaps | align and keep every ping, its stream carried, derivations within one stream |
| e | The lag measured on every rebuild and applied by a fixed rule, or reviewed and frozen as an input (as the `once` fixes) | measured on every rebuild: new dumps bring new offsets (October 2025 on), and the check shows each unit's outcome |
| f | The columns | `time` harmonized, the delivered time, the lag and its basis, the stream beside (names to TODO 127) |
| g | Where the generic step lives | ramb, step 0 of the one flow |
| h | A rule in AGENTS.md now, before anything is built: a speed, turn or window is derived within one stream, never across streams whose clocks may differ | yes: it costs nothing and guards every new derivation |
