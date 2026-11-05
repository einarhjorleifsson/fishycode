# 065 — ramb's speed flags from the data itself: each vessel's own ceiling, its clock's error in the margin, a planted set that holds today's faults, and the viewer to review it

**status:** executed — written 2026-11-05 at the maintainer's request, its asks answered the same day as recommended
("Yes, as recommended"), the set named `dansk_truth`; its six steps done the same day, each at the maintainer's word,
built, scored and judged by Claude (AI), not checked by a person (ramb 2026.11.05.3-.8: d87c781, bb6333e, c2fc469,
3df2adc, 943eee9, 4b4c2bc; the article 01d8825; none installed or pushed); recorded in decision 282 · **see:** decision
282, the study `$FISHYDATA/archive/2026-11-05-speed-ceiling/` (its README), TODOs 191 and 192, plans 062 (step 0,
`dansk_planted`), 059 and 060 (the feeds' clocks), 064 (the time panel), decisions 067, 280 and 281, me_code
`checks/cs1_clock_minute.R`

Drafted with AI assistance (Claude) on 2026-11-05; a person has not yet checked it. **Measured:** everything in §1, by
the study (Claude). **Assumed:** that the faults of §3 are those real data have (they are what today's data showed,
not a census); that the viewer of §4 needs only the changes listed; every step's size.

## 1. What the study measured

Every speed rule in use runs at a fixed 25 kn (26 in EM4SSF's case study); no record gives a source. The study replaced
it with three properties each vessel's own data give, and scored the result on every dataset at hand:

- **The ceiling: the highest speed the vessel records twice in a row** (a running median of 3 recorded speeds, at least
  30 reports over 1 kn). On ramb's planted faults it catches as many faults of 1 km or more as 25 kn at every rate
  (89.6 against 88.3 % at 1 min), flags 124 good fishing pings per 10,000 at 1 min against 314, and keeps the fast
  stretches 25 kn flags 71-99 % of. In Iceland's 2024 it keeps the 10,687 pings production flags on the 140 vessels
  whose own ceiling is over 25 kn.
- **How far the written times may be off,** the larger of the clock's grain and the timing error measured against the
  recorded speed: with it, none of the case study's 50 known-good pings is flagged (EM4SSF's loop and 26 kn flag 15),
  and ramb's `local` falls from 3,489 flags there to 122. The Adriatic set's steps written 3 minutes long: 219 flags
  to 5.
- **The noise,** a dataset's median at rest (1-8 m): it matters only at steps of seconds.

What failed or is open: a ceiling from the track alone (the faults set it where clocks or feeds interleave; it is a
check, agreeing with the recorded ceiling for about 90 % of vessels); the timing error on sparse streams (155
Icelandic vessels get 5-15 minutes, which is speed changing between STK's reports); the forward scan's wait after a
jump with no return; and the 41,487 pings the data's ceiling flags in Iceland that production keeps, unjudged (no
truth). The planted set could not settle the last two: it has one clock, whole seconds, every ping with a recorded
speed, and no fill.

## 2. What the user gets (ramb)

```r
lim <- rb_create_ping_limits(pings)            # a row per vessel (and stream): ceiling, time error, noise, each with
                                               # its basis and the evidence it rests on
pings |> rb_flag_ping_impossible(method = "local", limits = lim)   # each vessel judged by its own limits
pings |> rb_flag_ping_time(limits = lim)       # the time written off: a step pair that one late time explains
```

- **`rb_create_ping_limits()`**: per vessel, and per stream where a stream column is given: `ceiling_kn`
  with `ceiling_basis` (`"recorded"`: the highest recorded twice in a row; `"track"`: the 99.9th percentile of the
  track's 5-step median over steps the noise moves by under a knot; `"default"`: under the evidence floor, the fixed
  value given); `grain_s`; `time_error_s` with its basis (`"recorded"`, `"grain"`, `"none"`); `noise_m` with its basis
  (`"rest"`, `"dataset"`); the counts it rests on; and `ceilings_agree`, the track's against the recorded (a vessel
  whose two witnesses disagree by more than a quarter is a finding for the user, not a choice for the function).
- **`rb_flag_ping_impossible(limits = )`**: a leg is impossible when longer than
  `2 noise + v (max(dt, min_dt_s) + time error)`, v the vessel's ceiling; for `"local"`, also the recorded speed near,
  as now, with the margin from `limits` in place of 50 m. Without `limits`, as today (25 kn), so nothing changes for a
  caller who gives none. Each flag keeps its `ping_flag_basis` and says which limit judged it.
- **`rb_flag_ping_time()`**: the morning's lesson, that the 08:23 ping's time was wrong and not 08:24's
  position, as a label of its own: a ping whose step in carries about one cadence more and whose step out one less
  (or the reverse) than its recorded speed covers, while the chord past it fits, is labelled `"time"`, its position
  kept. Today every rule blames the next position.
- **Labels, never drops** (the maintainer, 2026-11-05): every result is a column; nothing is removed.

## 3. The truth: a planted set that holds today's faults

A new example in ramb, built by `data-raw/` from the same clean base as `dansk_planted` (dansk, 14 vessels at 10 s,
public, WKSSFGEO's), so plan 062's scores stay comparable and nothing Icelandic or EM4SSF's goes into ramb. Named
`dansk_truth` (the maintainer, 2026-11-05): a new example beside `dansk_planted`, which stays as plan 062 scored it.

**Every row carries both truths:** the position and the time as written, and as they were (`true_lon`, `true_lat`,
`true_time`), with `wrong_position`, `wrong_time`, `fault`, `fault_id` (one id per planted event), and `expect`, what an
ideal flagger does with the ping (`"keep"`, `"flag position"`, `"flag time"`, `"copy"`). Per vessel, the truth of its
limits: its true top speed, the clock's true grain and error. So a rule is scored ping by ping and the limits it
estimated are scored too.

**The same tracks, written through each kind of clock and stream met today:**

| clock or stream | what it does | met in |
|---|---|---|
| fix time, whole seconds | as now | dansk, AIS |
| truncated to the minute | every time cut to its minute: one-cadence steps carry 0 to 2 cadences' travel | CS1 |
| rounded to the minute, with a ping dropped where two land on one minute | CS1's late stamp and missing ping | CS1 |
| written up to half a cadence off at random | steps of half or one and a half cadences | the Adriatic set |
| receipt time with latency | a second stream stamped when received, 1-90 s late, drifting | STK's AIS stream, astd (plan 059) |
| an hourly stream | a VMS-like stream at its own clock beside the AIS | STK's VMS (plan 060) |
| resampled to 1 min with linear fills | fixes stamped to the minute, the gaps filled along straight lines; one fill run drawn to a misplaced fix | CS1 |
| speed derived from the positions | a stream whose `speed` is computed, not recorded | astd, the PDS trackers |
| a single wrong speed report | one report at 60 kn in a stretch at 8 | (the ceiling's robustness) |

**And the faults of the present set**, planted on top as now (spike, run, detour, lon_eq_lat, shifted_copy,
clock_offset, summer_time, near_copy, tie, first_after_gap, and the fast stretches, which are good), plus two seen
today: **a relocation** (a jump with no return, the vessel staying where it jumped: the anchor before it wrong, or the
jump real after a silence) and **a slow vessel's fast fill** (CS1's 10.7 kn on a 5.4 kn vessel).

At four rates (10 s, 1 min, 6 min, 1 h) as now. The seed fixed, so a rerun gives the same file. Size: assumed about
2-3 times today's 7.7 MB.

## 4. The truth in the viewer: a fault at a time, its verdicts beside it

The time panel already does most of it. A review of the set, on ramb's map viewer, served or bundled:

```r
planted |>
  rb_map_track(expect, time = "time", by = vid) |>                     # the track coloured by what should happen
  rb_map_pings(stream, popup = c(fault, true_time, planted_m, planted_s)) |>   # a click shows the truth
  rb_map_time(
    c(speed, step_speed, time_error),                                  # the recorded and the step speed, and how far
                                                                       # each time is off
    marks = c(truth = "wrong", clean = "flag_clean", own = "flag_own", time = "flag_time"),
    lanes = list(fault = "fault", clean = "outcome_clean", own = "outcome_own"),
    span = c(fault = "fault_id")                                       # one span per planted fault
  )
```

- **One span per planted fault** (decision 281's per-value spans): the list steps through the faults one at a time, and
  the map shows only that fault's pings (the map follows the span), so a reviewer sees each fault whole, its time
  around it, and nothing else.
- **The truth and each rule's verdict as marks**, so caught, missed and false flags read at a glance on the same ping:
  needs the change below.
- **A lane per rule of its outcome** (`caught`, `missed`, `flagged, beside a fault`, `flagged`, `kept`), runs of a column,
  so a rule's collateral (clean's vmask eroding 45 steps) shows as a bar.
- **The time error as a column on the chart**, so a doubled step and the time that explains it are seen together.
- **The fault types as the page's choices** (`group_by(fault)`): chips that show one kind at a time.
- **A bundle** that opens from its `index.html`, so a colleague can review the set with no R.

Changes to the viewer this needs (plan 064's panel):

1. **Marks by column, each in its own colour and row** of ticks along the chart's top, with its ring on the map and a
   legend in the sidebar's *Time* group (today every mark is one red).
2. **Step buttons beside the span list** (‹ ›), for stepping through hundreds of faults.
3. **The span's name from a label column** where one is given (`list(data = , label = )` already does it for tables).
4. **An outcome helper**, the scoring of plan 062 step 3 as a function: `rb_add_ping_outcome(x, truth =,
   flags =)` adds a column per rule from the labels and the truth, so the viewer and the tests read the same outcome.

## 5. Steps

Each step committed when its check passes, ramb's tests whole, nothing pushed without the maintainer's word.

1. **The truth set** (`data-raw/`, the data dictionary, a test that every fault is as planted and every row's two truths
   agree with its fault). **check:** each fault's count by rate and clock; a page of the set reviewed in the viewer as it
   is today, before any change.
   **Built 2026-11-05** (ramb d87c781): 13 tracks of a vessel each (8 clocks, 1 min and 6 min where the clock is
   written at both); every new fault on its clock (relocation 40 reports, late_stamp 15, speed_glitch 8,
   misplaced_fill 31, jitter 6,419, rx_copy 6,593); rounding to the minute drops the copies that land on a minute
   taken (69 of 147 shifted copies left at 1 min, no near copy); one 6 min track had no stretch for a late stamp. In
   today's viewer each fault is a span 15 min either side (`span = list(fault = <table>)`, added to the span work for
   it), the truth's columns are marks, the faults and `expect` lanes, the time error a column: the late stamp shows,
   and so do the gaps of step 2 (one mark colour, no legend).
2. **The viewer's changes** (§4, 1-3), one at a time, every click path tested (plan 064's checklist). **check:** the
   review of step 1 with marks in colour, the span buttons, served and bundled.
   **Built 2026-11-05** (ramb bb6333e, c2fc469): each mark column its own colour, row of ticks above the chart and ring
   on the map, named in the sidebar (`marks = c(position = wrong_position, ...)`), the readout listing every mark; ‹ ›
   beside the span list, off at either end; a vessel's own spans no longer carried to another vessel. One change at a
   time, each checked on `dansk_truth` in a browser: rows, colours, rings, legend, readout, a vessel and a span
   changed, the address, a change of base map, a phone's width, and a two-track bundle with no server; and on `dansk`
   with one mark column, as before. Item 3 (a span's name from a label column) came with step 1's named table.
3. **`rb_create_ping_limits()`**, scored on the set's per-vessel truth (ceiling, grain, time error), and on the study's
   data (its numbers reproduced). **check:** each limit's error against the truth, by clock and rate.
   **Built 2026-11-05** (ramb 2026.11.05.6, 3df2adc): a row per vessel, or per vessel and stream (§2): the vessel's
   ceiling on each of its streams' rows, the clock by stream, the dataset's noise, each value with its basis and the
   count it rests on (`recorded_n`, `recorded_moving_n`, `track_n`, `time_error_n`); the noise's basis is `"rest"`,
   `"geometry"` or `"none"` (§2's `"dataset"`: every vessel takes the dataset's). Equal to the study's `rules.R` on
   `dansk_planted` and four other examples, but for three changes, each from a score:
   - a thinned step's speed is the lower of the speeds from one and from two pings back: `dansk_planted`'s
     `shifted_copy`, a copy of the track interleaved ping by ping in its stream (two transmitters on one id), jumps
     every step, and set the track's ceiling at 61-226 times the true one on the set's 1 min tracks, now 0.90-0.95. On
     Iceland's 2024 the vessels whose track reads over 1.5 times their recorded ceiling fall from 35 to 3 and those over
     40 kn from 27 to 1; the median ratio falls from 0.936 to 0.919, and the share within 0.8-1.25 from 0.896 to 0.887.
     The speed over two steps alone did worse on the set (0.91-2.35);
   - both running medians count only where their window is whole: a stream's first step has one ping back, and its raw
     jump set a ceiling of 226 kn in a test; at the ends the study took a report recorded once as recorded twice. 100
     Icelandic vessels' recorded ceilings fall to what they record twice in a row (one from 16.6 to 10.2 kn);
   - where the time error is not measured the grain stands for it, `time_error_basis` `"grain"`, and
     `ceilings_agree` compares the two ceilings, not the recorded speeds' 99.9th percentile, which one 60 kn report
     moved.

   Scored on the set by clock and rate (108 streams of 52 tracks; a derived speed passed as none):
   - the grain right on every stream;
   - the recorded ceiling 0.98-1.01 of the true at 1 min (the receipt clock 0.94), 0.86-0.97 at 6 min, where the
     vessels' top speed is a burst of three pings that neither witness sees;
   - the track's ceiling, where no speed is recorded, 0.90-0.95 at 1 min and 0.33-0.88 at 6 min;
   - the time error, or the grain for it, at least the true step error on every stream but one of the receipt clock's
     12 (the slow EX_10's received stream: 17.5 s against 1 s, too few steady steps to measure);
   - the hourly stream's measure 1,253 s against a true 0: over an hour the vessel's speed changes between reports, the
     sparse streams of step 5.

   Iceland's 2024 (as the study read it, production's invalid and duplicate pings out) lazily in 29 s: 1,850
   vessels in 5,990 vessel-stream rows; ceilings recorded 1,526, from the track 10, the default 314; the two
   witnesses agree for 1,235 of 1,392. The study's saved Iceland table predates its own guard of 30 moving reports
   (`out/iceland_2024_props.csv` written 11:18, `rules.R` changed 11:21): 55 vessels with a recorded ceiling there
   have none under the rule. Tests: `test-ping_limits.R` (11 blocks) and an etiquette case; ramb's whole suite passes.
4. **`rb_flag_ping_impossible(limits = )` and `rb_flag_ping_time()`**, scored on the set (every ping in one outcome,
   plan 062's way) against today's methods. **check:** the summary by clock, rate and fault; the review in the viewer.
   **Built 2026-11-05** (ramb 2026.11.05.7, 943eee9; scripts 11-14 of the study, its `out/score_truth.csv`):
   - `rb_flag_ping_impossible(method = "local", limits = )`, by vessel or by vessel and stream: a leg is impossible
     when longer than 2 noise + v (max(dt, `min_dt_s`) + time error), v the recorded speed near (by `local`'s factor
     and margin, as before) or else the vessel's ceiling (basis `"ceiling"`), of a leg's two ends the larger. Without
     `limits` the flags are 2026.11.05.1's bit for bit on both sets; with them and no recorded speed, `flag_own()`'s.
   - `rb_flag_ping_time()`: a ping whose step in and step out disagree with its steady recorded speed by opposite
     amounts, while the chord past it fits, is labelled `"time"`, its error estimated (`ping_time_error_s`), the worst
     first, and set aside as an anchor; the allowance is the grain, the noise and the speed's spread, not the clock's
     jitter. An along-track position error reads the same, and is rare.
   - `rb_add_ping_outcome()`: §4 item 4, plan 062's outcomes from a rule's labels, the truth and a run without the
     wrong pings.

   Scored on the set (wrong positions caught %; good pings flagged in 10,000 of the rule's own, at 1 min / 6 min):

   | rule | positions | own flags | wrong times caught as times |
   |---|---|---|---|
   | `clean`, 25 kn | 56 / 45 | 45 / 29 | 0 / 0 |
   | `forward`, 25 kn | 52 / 37 | 44 / 29 | 0 / 0 |
   | `local`, recorded speed | 70 / 59 | 20 / 92 | 0 / 0 |
   | own limits, no recorded speed | 53 / 52 | 17 / 79 | 0 / 0 |
   | own limits, recorded speed | 65 / 64 | 15 / 110 | 0 / 0 |
   | time flag, then own limits and recorded speed | 65 / 65 | 17 / 122 | 22 / 15 |

   (With step 5's cap on the time error's steps; before it, 112 and 125 own flags at 6 min.)

   - The time flag is the gain: 1,572 of the 4,425 pings jittered over 10 s (`steady` 20 %; at 10 %, 1,056 for 32
     fewer good pings flagged), its estimate within a median 2 s, and 4 of the 15 late stamps in the chain: the rest at
     under 2 knots or a speed changing by more than 20 %, where the recorded speed is no witness to the time.
   - The own limits are no clear gain over `local` with a recorded speed, and with none they beat the fixed 25 kn only
     at 6 min. At 1 min their margin (the ceiling times a minute clock's grain) lets detours through (55 % caught
     against 72 %, both rates); at 6 min the slow EX_10's recorded ceiling (7.65 kn) is under what its positions run on the true
     track (85 of the 106 good pings flagged have a true step over it). Ask f (`local`'s constants from the data) is
     where this goes.
   - Reviewed in the viewer (`14_review_truth.R`): each rule's outcome a lane; a late stamp caught as a time by the time
     flag alone; on the jittered clock the time flag's good pings flagged are all beside a fault.
5. **Iceland's disagreements judged:** a sample of the study's 41,487 and 21,126, checked by hand in the vessel overview
   (a checked link per case), and the timing error on sparse streams settled with plan 059's lags. **check:** each
   sampled ping in one outcome, with its witness.
   **Done 2026-11-05** (by Claude; not checked by a person; ramb 2026.11.05.8, 4b4c2bc; the study's scripts 15-23):
   - **The time error settled.** With no cap, every Icelandic stream the recorded speed measured steps 5 minutes or
     more (STK's AIS a median 275 s, astdB thousands), and plan 059's copies (the same report heard by astd and STK)
     put the feeds' clocks within about 70-90 s: 213 of 219 streams read more than twice the copies' spread. The
     measure now takes steps of at most 300 s (`max_step_s`): 6 of 34 then (none of 7 at 120 s, but the Adriatic set's
     steps written 3 min long need 300 s), and the truth's hourly stream loses its 1,253 s. A stream whose lags are
     measured takes their spread where it is the larger (`lag`, basis `"lag"`): astd, whose speed is derived and so has
     no other measure, a median 72 s on 276 streams, from its copies, which production labels duplicates, so the limits
     are measured on the judged pings and those. Even on whole seconds the measure reads 12-42 s at 1 min steps on the
     truth (turns within a step): a margin more than the clock's error alone.
   - **The disagreements, rerun with the built rule** (each vessel and stream's own limits, no recorded speed,
     production's 0.3 nm floor between feeds, as the study's): 27,501 pings it flags and production keeps (42,862
     before the copies' lags), 24,189 the reverse, 22,549 both.
   - **The hand check.** The vessel overview shows the trail, from which production drops the pings it flags, so the
     cases are judged on ramb's viewer with every tagged ping (`19_review_iceland.R`, 127.0.0.1:8809) and a table of each
     case's neighbourhood within 10 min (`21_case_tables.R`), each case's overview link kept beside. Of 200 drawn from
     each side, 20 each, every one in one outcome with its witness (`out/iceland_2024_sample_hand.csv`):

     | the flag of | right | wrong | a time off | undecided |
     |---|---|---|---|---|
     | the built rule (production keeps) | 3 | 16 | 0 | 1 |
     | production (the built rule keeps) | 3 | 12 | 1 | 4 |

     Where they disagree, both flag mostly good pings. The built rule's 16 wrong: 12 its forward scan anchored on a bad
     ping it kept, 9 of them an STK port event row recording 0 kn and placed 0.8-2 km from the vessel's other reports
     of the moment (production's `clean` catches it by its angle; the local rule finds one leg impossible, not two); 2
     a vessel steaming just over its ceiling (18.4-19 kn against 18.5); 2 astdB reports delivered late. Production's
     12 wrong: 7 fast vessels whose own ceiling is over 25 kn, 4 anchored on a bad ping, 1 beside a VMS report a minute
     off. Counted on all 400: 86 of production's 200 on vessels whose own ceiling is over 25 kn; at least 41 of the
     built rule's 200 after a ping production flags and it kept (29 an event row at 0 kn). The automatic witnesses
     (another feed near, the legs against the recorded speed) are a proposal only: of the 8 positions they called
     wrong, 4 were right.
   - **What it leaves**, none built here: STK's port event rows are events, not fixes, and the tag pass knows them
     (`stk_event`); judged as fixes they cost the local rule good pings. The forward scan's anchor after a bad ping it
     cannot resolve (§7) costs both rules. A ceiling from the recorded speed under what the vessel's positions run
     (EX_10 on the truth, B013 and B016 here) is ask f's.
6. **The record:** ramb's NEWS and article; a decision here; fishycode's `curate/ais_ping_clean.R` on the vessels' own
   limits is its own decision, with a rebuild (not this plan).
   **Done 2026-11-05**: ramb's NEWS at each version; its trips article shows the limits and the time flag on `dansk`
   (01d8825; the code run with the package loaded, not rendered: the installed ramb is older); decision 282. Production
   is unchanged (TODO 192); the forward scan's anchor is TODO 191; the event rows go to plan 048 (TODO 148).

## 6. Asks

Answered by the maintainer on 2026-11-05, each as recommended ("Yes, as recommended"):

a. **Names:** `rb_create_ping_limits()` for the table of limits, and `limits =` for the flag's argument.
b. **The set:** a new example, `dansk_truth` (the maintainer's choice of name over `dansk_clocks`); `dansk_planted` stays
   as plan 062 scored it.
c. **The time check** is a flag of its own, `rb_flag_ping_time()`.
d. **The outcome helper** is in ramb, `rb_add_ping_outcome()`, so the viewer and the tests read one outcome.
e. **The default** where a vessel has no recorded speed and too short a track: 25 kn, its basis `"default"`, said.
f. **`local`'s factor (1.5) and margin (5 kn)** from the data: after this plan, not in it.

## 7. Not in this plan

- fishycode's production on the new limits (a rebuild, its own decision).
- The forward scan's design after a relocation (§1): the set shows it, a fix is a plan of its own if wanted.
- Classifying fishing from the flagged pings.
