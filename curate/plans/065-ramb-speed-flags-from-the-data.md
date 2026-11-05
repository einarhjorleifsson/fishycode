# 065 — ramb's speed flags from the data itself: each vessel's own ceiling, its clock's error in the margin, a planted set that holds today's faults, and the viewer to review it

**status:** partly built — written 2026-11-05 at the maintainer's request, its asks answered the same day as
recommended ("Yes, as recommended"), the set named `dansk_truth`; step 1 built the same day, committed to ramb's local
`main` as 2026.11.05.3 (d87c781), and step 2, the viewer's marks by colour and the span buttons, as 2026.11.05.4
and .5 (bb6333e, c2fc469), none installed or pushed (step 1: `data-raw/truth.R`, 160,097 rows, 3.3 MB, its test passing, reviewed in today's viewer, §5); ("Yes, a plan"; "wondering if we need also to
generate new truth dataset where we take into account some of the issues discovered here - like different streams and
any rounding e.g. from AIS seconds to minutes ... think about how a truth dataset with planted errors can easily be
exposed using the interactive app") · **see:** the study `$FISHYDATA/archive/2026-11-05-speed-ceiling/` (its README),
TODO 190, plans 062 (step 0, `dansk_planted`), 059 and 060 (the feeds' clocks), 064 (the time panel), decisions 067,
280 and 281, me_code `checks/cs1_clock_minute.R`

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
4. **`rb_flag_ping_impossible(limits = )` and `rb_flag_ping_time()`**, scored on the set (every ping in one outcome,
   plan 062's way) against today's methods. **check:** the summary by clock, rate and fault; the review in the viewer.
5. **Iceland's disagreements judged:** a sample of the study's 41,487 and 21,126, checked by hand in the vessel overview
   (a checked link per case), and the timing error on sparse streams settled with plan 059's lags. **check:** each
   sampled ping in one outcome, with its witness.
6. **The record:** ramb's NEWS and article; a decision here; fishycode's `curate/ais_ping_clean.R` on the vessels' own
   limits is its own decision, with a rebuild (not this plan).

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
