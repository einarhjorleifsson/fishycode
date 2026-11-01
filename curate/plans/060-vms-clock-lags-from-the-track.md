# 060 — STK's VMS clocks: each fix's time from STK's own receipt where the unit's clock drifts, checked against the vessel's AIS track, the rest flagged

**status:** proposal — written 2026-11-01 at the maintainer's request ("Lag from the scan": a lag where the clock can be
judged, a flag where it cannot; "plan it first"). Revised the same evening after the maintainer's question on `posdate`
and `recdate`, which give a lag for every VMS fix whose `posdate` is the unit's own, with AIS or without ("Don't we need
a plan here?"; "hold before you start executing the plan"); ramb's hardening added as §8 at the maintainer's word
("Into plan 060"); asks a-h answered 2026-11-01, each as recommended, h (added by Claude) a full rebuild of every
main-project target from raw · **2026-11-01** · **see:** TODO 180, TODO 117 and
decision 196 (`stk_receipt`), `curate/corrections/stk_vms_clock.yml`, decision 271, plan 059, `dump/oracle/meta/stk.yml`,
the study `$FISHYDATA/archive/2026-11-01-vms-clock-scan/` (its README)

Drafted with AI assistance (Claude) on 2026-11-01, from the study run the same evening. No person has checked it. The
choice of repair is the maintainer's; the design and every number are Claude's.

## Where the first version stood

The first version (5f59213, e419ce0) took the lag from the shift that puts each VMS fix on its vessel's AIS track. That
judges only fixes near an AIS track (7,305 vessel-months with 10 or more judged fixes), and it is a model of where the
vessel was. STK's own two timestamps measure the clock directly, for every fix whose `posdate` is the unit's own. The
track shift now checks them, rather than being the source.

**Measured** (the study, scripts 01-05; the store of 2026-11-01 at 7216654):
- **The scan** (scripts 01-02).
  - Each VMS fix of a vessel with an AIS stream that year (3.48 M of 4.05 M) was placed on the vessel's moving AIS
    track within 2 h, by the shift that brings it nearest. It is judged where the track moves at its stamp and the fit
    is within 300 m.
  - 6,947 vessel-months are on time (−1.0 to +3.0 min, 5-95 %). 43 are an hour off (14 vessels, 33-118 min, mostly
    2007-2009), and 251 are off by minutes (40 vessels, mostly 2007-2013). 38,203 have fewer than 10 judged fixes.
  - 3,744 hour-off and 63,257 minute-off VMS fixes are in the store unmoved.
- **The mechanism** (script 04). Month by month the shift is a sawtooth: it grows 8-12 min a month (15-25 s a day),
  then drops to about 0. Vid 1476 did so three times in 2013-2017, vid 2040 twice in 2019. Several vessels later hold
  steady at about 1 min, as if the unit was replaced. This is a free-running unit clock set right now and then. The
  largest drifts reach 110-125 min.
- **STK's two clocks** (script 05, 2007 only so far). In 2007 the VMS stream's `posdate` is the unit's own, and
  `recdate − posdate` carries the scan's shift plus 1-2 min:

  | 2007 | recdate − posdate | the scan's shift |
  |---|---|---|
  | vid 975, Oct / Nov / Dec | 55.3 / 66.4 / 75.4 min | 54.7 / 66.0 / 73.0 |
  | vid 1809, Sep → Dec | 48.0 → 71.3 | 46.6 → 69.5 |
  | vid 2643, Aug → Dec | 72.1 → 102.5 | 69.5 → 100.6 |
  | vid 2677, the control | 2.2-2.5 | 1.1-1.2 |

  The unit's `posdate` drifts; STK's `recdate` does not. The gap sees the drift where no AIS track is: vid 975 shows
  37 and 45 min in August and September 2007, the start of its ramp.
- **When `posdate` is the unit's own** (STK's dictionary overlay, plan 059 step 4):
  - the VMS stream's `posdate` is the report's own time to 2010 (`posdate` = `recdate` on under half);
  - from 2016 to April 2025 it is mostly the receipt's (on 75 % or more of a year file's fixes);
  - it changes again from May 2025.
  - STK's own units stamp their own time, 3-5 s before receipt. The AIS stream (the reference) is stamped at receipt.
- **Why plan 059's check misses them.** Its pairs method finds 44,135 of the 48,298 VMS vessel-months `not
  measurable`. Speed is not the cause: 74.5 % of VMS fixes report 2 kn or more.

**Not yet measured** (step 1):
- the 2007 agreement over every year: `recdate − posdate` against the scan's shift wherever both exist;
- 2011-2015, and the minority of fixes with their own `posdate` after 2016. The scan's drifts in 2016-2019 (vids 1476
  and 2040) fall in the period when `posdate` is mostly `recdate`, and are not yet explained;
- backlogs. A late delivery with a right `posdate` makes a large gap and a shift of 0. How often, and whether a
  running median of the gap per unit tells them from a drift;
- the delivery delay (gap less shift, about 1.1-1.3 min on the 2007 control), by year;
- the 0.57 M VMS fixes of vessels with no AIS stream that year, which the scan does not cover;
- STK's own units (`stk_unit`, 10.2 M fixes, never measured by plan 059's check), on the same gap.

**Assumed:**
- that STK's server clock (`recdate`) is right: it is the AIS stream's clock, the reference;
- that a drift is slow (15-25 s a day) and a backlog a burst, so a running median over a day separates them;
- that a VMS report's delivery delay is about constant within a period, so one baseline per period removes it;
- that a vessel's VMS and AIS streams are one hull (one STK mobile id for vids 975 and 1809; the key's audits, plan 009).

## 1. The lag: each fix's own, from STK's receipt

Each fix whose `posdate` is the unit's own gets an own lag. It is the running median of `recdate − posdate` over the
unit's fixes within a day either side, less the stream's delivery baseline for the period. A burst of late deliveries
moves the median little, so a right `posdate` stays put, while a drift of 15-25 s a day carries the median with it.

- **The cascade.** It is an own lag, so it comes first in plan 059's cascade (`rb_add_ping_own_lag()`: copy, residual,
  now receipt), before a unit's lag (`rb_add_ping_time()`).
- **Generic.** It is a method for any feed that keeps a fix's time and its receipt: `method = "receipt"`, with the
  receipt column, the window and the baseline. A fisheries monitoring centre usually keeps both; NAFO's VMS format
  carries both.
- **No lag where there is no information.** Where `posdate` equals `recdate`, the fix already has the receipt's time,
  on the reference's clock, and gets no lag from this.

## 2. STK's receipt in the flow: decision 196's `stk_receipt`

The union carries STK's `recdate` into the flow, as decision 196 decided for TODO 117: the side table `stk_receipt`,
with the receipt time, the lag and each unit's class. Plan 060 builds that part of it, and TODO 117 keeps the rest:
the events and the `U` positions.

## 3. The check against the AIS track

The study's scan becomes the independent check. After the lag, the VMS fixes in every judged vessel-week must sit on
the AIS track within ±3 min of shift; a vessel-week that does not is listed with its outcome. The track method can go
into ramb (`rb_create_ping_lags(method = "track")`, as the first version proposed) for feeds with no receipt time, which
is the case for other countries without an FMC's receipt column (ask e).

## 4. The flag

`lag_basis` gains `receipt`. A VMS fix keeps `unmeasured` where its `posdate` is its own but the gap cannot be read: a
backlog the running median cannot separate, or a gap that the track check contradicts.

## 5. Steps

1. **Measure, in the study, before any code:** every bullet under "Not yet measured". Then the method's numbers: the
   window, the baseline per period, and what share of fixes it moves. Ends in a short note in the study's README and an
   amendment here.
2. **ramb:** `rb_add_ping_own_lag(method = "receipt")` with tests, the track method if ask e is yes, and the items of
   §8 that ask g keeps. A release, run on a full Icelandic year, installed from GitHub.
3. **fishycode:**
   - the union carries STK's `recdate` (decision 196's `stk_receipt`);
   - the tag pass takes the receipt lag for STK's VMS stream (and its units, if step 1 finds them off);
   - the check gains the track check per vessel-week.

   All of it run in a scratch store on 2007, 2017 and 2019, with the scan rerun on the result.
4. **The rebuild** of every target of the main project from raw (ask h, as decision 218's), prepared as plan 059's,
   about 3.5-4 h. `ais_catch` and the audit are left (decision 261); the `once` project is not touched.
5. **A decision record.** TODO 180 closed, `stk_vms_clock.yml` repaired, the dictionary's `lag_basis` with
   `receipt`.

## 6. What it does not do

- It does not move STK's AIS stream, the reference, which is stamped at receipt.
- It does not touch the commercial feeds' lags (plan 059).
- It does not build TODO 117's events or `U` positions (plan 048).

## 7. Asks

**Answered 2026-11-01** by the maintainer, a-h each as recommended. Claude's notes on the recommendations, given with
them: in b, a backlog's fixes are left out before the median is taken, so a flushed outage cannot become a lag (step 1
sets the rule); in c, the on-time VMS fixes with their own `posdate` (most of 2007-2010) also move, by about a minute;
in f, only the receipt time is built, as a side table the tag pass joins, and `recdate` is carried no further (decision
196); in g, with `recdate` in the union a fix STK received twice is two rows, and the de-duplication keeps the earliest
receipt and counts what it drops.

- a. **The source:** STK's receipt, with the AIS track as the check (recommended), or the AIS track alone, as in the
  first version.
- b. **The smoothing:** a running median over a day either side (recommended: a drift moves about 20 s in a day), each
  fix's own gap, or a week.
- c. **The baseline:** the stream's delivery delay by period subtracted, so that the VMS fixes sit on the AIS stream's
  clock (recommended, plan 059's rule: harmonize to the reference), or none.
- d. **STK's own units:** judged by the same method if step 1 finds them off (recommended), or the VMS stream alone.
- e. **The track method in ramb:** built, as the check here and for countries with no receipt time (recommended for
  WGSFD), or kept as study code.
- f. **TODO 117:** this plan builds `stk_receipt`'s receipt time (recommended: it is the same column), or waits for
  TODO 117.
- g. **ramb's hardening (§8):**
  - items 2-4 and 6 with this plan (recommended: they guard the methods it adds and the clean it relies on);
  - items 1 and 5 next, or all of §8 now. Item 1 touches every lazy step, and item 5 is a diagnostic of its own.
  - fishycode's `union()` in any case, at the next union build.
- h. **The rebuild** (added by Claude): every target of the main project from raw, as decision 218 (recommended: every
  file then has one commit, one ramb and one DuckDB, and a script edit `targets` cannot see is caught; about 3.5-4 h, and
  `lookups` and `gear` read the web), or from the union down (about 2-2.5 h).

## 8. ramb's hardening

The maintainer, 2026-11-01: "we may need to make the ramb functions more robust". Each item comes from something that
failed or misled on 2026-11-01, in plan 059's rebuild (decision 271) or in this plan's study. The step registry
(`.rb_steps`, plan 013) already stops a step whose columns are missing and one run twice on its own output. It has no
rule on when clocks are measured, or on comparing streams before their times are harmonised. Tests for each item, then
a check on fishydata before release.

1. **Scale.** `rb_add_ping_own_lag()` → `rb_add_ping_time()` → `rb_flag_ping_port()`, chained as one lazy query,
   ran out of memory on 2014 (19.1 GB, and 11.1 GB at 4 threads and a 12 GB cap), though each step alone runs in
   seconds. fishycode materialises between steps (27de860). ramb promises a lazy flow at the flow's scale (decision
   234), so it should materialise its own large intermediate steps, and a release is run on a full Icelandic year, not
   only on example data.
2. **A ping moved across a period.** `rb_add_ping_time()` can move a ping into another month or year: 53 crossed New
   Year, and the trail, partitioned by the delivered year, stopped on them (fixed in fishycode, 7216654). ramb says so
   in its documentation and gives the caller what to partition on: the period of the harmonised time.
3. **The order of the steps, in the registry:**
   - **A clock measured after the clean** (`rb_create_ping_lags()`, `rb_add_ping_own_lag()`) sees only the
     survivors: vid 1809's clock looked as if it flipped (decision 271's first look). The functions warn when the
     input carries the clean's flags.
   - **Streams compared before harmonising** (`rb_flag_ping_duplicate()`, `rb_flag_ping_impossible()` on vessels with
     two or more streams and no `lag_basis`) get the guiding message "harmonise first (`rb_add_ping_time()`)": plan
     059's rule ("derive within one stream", AGENTS.md).
4. **The methods of this plan:**
   - `rb_add_ping_own_lag(method = "receipt")` (§1);
   - `rb_create_ping_lags(method = "track")` (§3, ask e), for sparse streams with no reliable speed;
   - **the hard rule that a fix cannot be received before it is made** (time ≤ receipt): a flag for a fast clock
     that needs no AIS. STK has 2.03 M fixes stamped after their own receipt, 1.19 M of them in 2009 and 266 thousand
     of those by more than a minute (`$FISHYDATA/archive/2026-10-stk-trail-order/`, §3);
   - **the order of the fixes.** Neither time alone is right. `posdate` is wrong where a clock drifts, runs fast or
     has a stuck date. `recdate`, STK's insert time, would put a flushed backlog (3.1 M fixes 26 h or more late in
     2026) at the moment of the flush. So the flow sorts by `posdate` up to the tag pass, and by the harmonised time
     from it, with both raw times beside it. ramb documents this as the step 0 contract.
5. **The clean's removals as evidence.** `rb_flag_ping_impossible()` reads a clock error as bad positions. A
   diagnostic sums its flags by vessel, stream and period, and points out the units whose removal rate stands far
   above their stream's. With the whack's evidence columns (in the store since decision 271), it can also test
   whether the removed fixes lie along the track, displaced by about speed × a time. It would have shown these clocks
   long ago.
6. **Tests with an injected fault.** A drifting stream (a sawtooth with resets, a fast clock, a backlog) in ramb's
   example data, so every method and guard above is tested on a known clock error.

**In fishycode, not ramb:** the union's `union()` in `d_for()` is SQL `UNION`, which drops rows equal in every column
silently: 5,827 astd copies on 2026-11-01 (decision 271). It becomes `union_all()` with a counted, explicit
de-duplication.

## 9. For WGSFD

The study shows that a VMS unit's clock can drift by an hour, and differently on every vessel. A test against one time
zone for a whole dataset (WGSFD 2019 and 2022, recommendation 2) does not find that. The receipt method needs no AIS,
only the fix time and the receipt time an FMC keeps, so any member state can run it on its own VMS. The track method
needs an AIS track per vessel. Both are generic in ramb once built. A document for WGSFD drawn from this states its
AI use, under MFRI's policy, and carries no vessel-level Icelandic data out of MFRI.
