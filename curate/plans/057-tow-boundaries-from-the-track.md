# 057 — A tow from the track: each fix labelled by an unsupervised neural network on speed, steadiness and turning, the tow's start and end from the labels, and its events learned from many tows

**status:** proposal — written 2026-10-31 at the maintainer's request after a case in the vessel overview, and
rewritten the same day after a scoping study (`$FISHYDATA/archive/2026-10-31-tow-scoping/`, §1); nothing built in the
flow; the A to J sequence as a prior added the same day (§3.7); asks a-k (§9): a and c answered the same day, e, f and k
by plan 058's study (decision 270: a hidden-state model labels each ping, not the map), the rest open (TODO 72) · **2026-10-31** · **see:** plan 013 items 9 and 10 (TODO 72), decisions 090,
092, 103 and 104, `curate/checks/survey_tow_times.R`, TODO 146 (the A to J protocol), plan 048 (heading and course),
plan 053 (the app profile)

Drafted with AI assistance (Claude) on 2026-10-31. The aim, the choice of unsupervised learning, the weight on
direction and speed of execution, the question of what the survey's end marks (ask c), and the idea that events show
across many tows rather than in one, and the A to J sequence as a prior for each fix (§3.7), are the maintainer's. The scoping, the measurements, the literature search and the
design are Claude's. No person has checked the numbers.

**Measured** (by Claude, read-only, 2026-10-31): every number in §0, §1 and §5, in the study's scripts and results.
**Assumed:**
- that `channel.station.vessel_no` is the vid (6,020 of 2023's 6,029 timed samples are on a vid with a 2023 track);
- that `channel`'s `tow_start` and `tow_end` are the start and end of the station entered in Hafriti, which the A to J
  protocol's original puts at the gear settling on the bottom (D) and the start of hauling (E) "as is customary" (ask
  c, answered);
- that a pattern found on one year of four-minute fixes holds on others: §6 step 3 tests it;
- that a gear's phases keep one order and similar speeds across its vessels within a length class (§3.7): the stacked
  profiles of every gear (the study's `report/`) show it for the medians, not for single vessels;
- that the literature in §2 says what its abstracts say.

## 0. Where this stands

- **The question** (the maintainer, 2026-10-31): the best estimate of an actual towing operation, using direction as
  well as speed. "This has to be unsupervised learning ... the main objective is of course to classify the pings, but
  ... in the end you would obtain the start-end time." And: "the speed of execution matters here, we do not want in the
  end wait hours and hours to run the whole dataset."
- **The case** (vid 1972, 2026-06-19, trip 247996, adb): an aborted tow folded into haul 537653 (900 kg) with the stop
  and the next tow's first 26 min; haul 537654's end entered at 15:22 mid-tow, 3 h 55 min before the speed breaks, after
  a wide 180° turn at towing speed; a stop at 19:19 that is a snag or a quick haul-back. Each logbook position is the
  vessel's own position at the logbook's minute: the times are when the skipper entered each event. The flow takes them
  as the window (`win_basis` "recorded"), so the catch is spread over the wrong fixes, and no rule flags it.
- **Every gear stacked** (the maintainer's request, 2026-10-31): each gear's fixes around its logged times, by
  length class, 2019 (afli's logbook, fixes every 2.3 min) and, for the handline and the purse seine, November 2025 to
  June 2026, with the A to J protocol mapped per gear, in a report for an MFRI colleague (the study's
  `report/gear_events.html`). The logged times agree with the track within a minute or two for the bottom trawls' D and
  E and the static gears' E and I, and disagree for the purse seine's `t1` (after the circle), the Danish seine's `t2`
  (mid-circle) and small gillnetters' `t1` (no set seen). These profiles are the prior of §3.7.
- **The labelling model is chosen** (decision 270, plan 058's study, the same day): a hidden-state model of towing and
  its look-alikes (the run-in before the tow, hauling after it), in continuous time, decoded by LaMa, the map not one of
  its inputs. Both ends of a survey tow within 5 min for 52 % (2019) and 47 % (2026), the declared speed range 28 and
  15 %; the whole trail in about 9 min. The maintainer, during the study: only which pings are towing (or, for static
  gear, setting and hauling) is wanted, not the A to J letters. §3's map and §6's steps 2-3 are superseded by it; the tows
  from runs, the outcomes and the review of §4 stand.
- **What exists:** ramb's towing stretches and their pairing with the declared tows (speed only, decision 092); their
  score on the spring survey to 2019 (±10 min, decision 104); plan 013 item 10, a haul's times against the track, not
  built; item 9, track models, the Gaussian mixture benched on speed alone (decision 103).

## 1. The scoping (2026-10-31)

### 1.1 Data

- **Ground truth:** `channel`'s 2023 bottom-trawl samples with a start and end (to the minute) on a tracked vessel:
  1,311 tows on 29 vessels. Spring survey 580, autumn survey 372, inshore shrimp survey 88 (1,040 survey tows);
  inspectors 224 and the discard project 47 (271 commercial).
- **Fixes:** each vessel's track from 6 h before to 6 h after each tow: 86,693, median spacing 4.0 min.
- **The inspectors' times are not timing truth:** 84 of the 197 with an e-logbook tow within 3 h start at the
  logbook's very minute (one entry); 32 % of all 224 start and end on a whole or half hour (the surveys 0-1 %); 38 last
  more than 8 h; of ten that disagree with the track, two are in port (speed 0) and two steaming at 12-13 kn.

### 1.2 Labelling methods, on the survey tows

A fix's features: speed, the bearing between fixes and its change (turn), each as a median over the fix and two on each
side. Runs of fixes labelled towing (a majority over 3 or 5 fixes, at least 15 min) are tows; each ground-truth tow
takes the run overlapping it most. Naming which clusters are towing is the one light labelling step.

| method | learns from | start ≤ 10 min | end ≤ 10 min | both | median end | s on 86 k fixes |
|---|---|---|---|---|---|---|
| A declared speed range (2.625-4.7 kn), a rule | nothing | 69 % | 44 % | 37 % | +9.1 | 0.0 |
| B Gaussian mixture, 4 components | speed, turn | 66 % | 50 % | 37 % | +8.3 | 7.8 |
| C hidden Markov model, 4 states (`moveHMM`) | speed, turning angle | 9 % | 10 % | 1 % | +49 | 453 |
| D self-organizing map, 8 × 8 (`kohonen`) | speed, turn | 76 % | 50 % | 42 % | +8.3 | 5.2 |
| **E** the same map with the speed's spread and the largest nearby turn, 3-fix majority | speed, spread, turn | **78 %** | **81 %** | **71 %** | **+0.7** | 6.8 |

- **The pooled HMM fails** (a state at towing speed with erratic turning swallows neighbouring tows) and is slow.
- **Mixtures and maps split towing in two** (straight and turning); every cluster at towing speed that turns slowly is
  towing.
- **Edges from the raw speed** help the rule (both ≤ 10 min: 37 to 51 %) and not the map. A systematic offset taken out
  of sample (one survey's median off another's) lifts D to 66 %.
- **Commercial tows score 14-30 % with every working method,** but their truth is the inspectors' (§1.1).

### 1.3 Steadiness and turning: what made E

Between two logged tows on vid 2904 (2023-07-12: 07:47 and 08:21) the vessel hauls and re-shoots at 2.6-3.4 kn. What
marks it is one fix at 0.7 kn, a speed that swings fix to fix where towing holds 3.6-3.9, and an 83° turn at the
re-shoot. With the speed's spread over ±2 fixes and the largest turn over ±1 as features, the map finds two groups at
the same speed: **steady towing** (3.71 kn, spread 0.15 kn, largest turn 3.7°; 48,712 fixes) and **handling at towing
speed** (3.77 kn, spread 1.36, largest turn 61°; 5,889). Runs longer than 1.5 × their tow fall from 41 to 13 (survey)
and 13 to 2 (commercial). The features were chosen after looking at one case and the threshold after seeing the
groups: in-sample, to be confirmed (§6 step 3).

### 1.4 The events across many tows

Every fix within 30 min of a survey tow's recorded start or end, by its time from the event in 2-min bins. Fixes fall
at random moments relative to an event, so 1,040 tows give the typical profile at about a minute's resolution, though
each has a fix every 4 min. Median speed and turn per fix:

- **The start:** steaming at 9.6-9.8 kn to 17 min before; slowing (8.6 to 6.0 kn) and turning from 15 min before; about
  5 kn with the most turning (10.8°) at 9 min before (shooting); 4.8 kn at the start, 3.9 by 5 min after (the gear
  taking the bottom); steady towing (3.85 kn, ~1.5°) from 7 min after.
- **The end:** steady towing (3.84 kn, ~1°) to the last minute; 3.3 kn in the first minute after, 2.0-2.2 kn from 3 to
  7 min with the turns growing (6 to 12°); 2.6-4.0 kn and 14-17° from 9 to 13 min; speeding up from 15 min; steaming
  from 21.

The track breaks at the recorded end, the start of hauling (E, ask c), within a minute or two of it. The profiles are a
template of the events of a tow (the A to J protocol, TODO 146), learned from many tows, against which one tow can be
matched.

### 1.5 Speed

The trail is 580.6 M fixes, 2023 33.2 M. Measured on the scoping set: the features in R 16 µs a fix (2.6 h over the
trail); the map 6.8 s to train on 85 k fixes; the HMM about 5 ms a fix (about 48 h for 2023). Applying a trained map is a
nearest-node lookup among 64 codebook rows, a cross join in DuckDB.

## 2. What others do

From a short search (abstracts only) and the code already mined:
- **Hidden Markov models on speed and turning angle** are the common method for VMS and AIS (Vermard et al. 2010;
  Walker & Bez 2010; de Souza et al. 2016); the WKSSFGEO repositories hold the Irish Marine Institute's practice.
  Here, pooled over vessels, it failed and was the slowest.
- **Segments over points** (JMSE 2023; arXiv 2207.05514), **learned models** with observer labels (an LSTM, Skylight;
  gradient boosting on speed and course change, CNR's SoftwareX benchmark) and **validation against recorded hauls**
  (ICES JMS 2025) are the other strands.
- **What none does:** most label fixes fishing or not. Few place a tow's start and end; none found learns the events
  of a tow from many tows.

## 3. The method

### 3.1 Features, per fix

In DuckDB windows over each vessel's fixes, a segment broken at a gap over 15 min: speed (reported, else from
distance); its median and its spread over ±2 fixes; the bearing between fixes; the turn at a fix and the largest turn
over ±1; the median turn rate over ±2. Counted in fixes, not minutes, so their meaning shifts with the spacing: step 3
scores them by spacing class.

### 3.2 Labels: a self-organizing map

A self-organizing map (a Kohonen network, a neural network that learns without labels) trained on a stratified sample
of about 1 M fixes (year, provider, spacing, gear class), its nodes cut into groups, each group named by one fixed rule:
towing where speed is in the gear class's range, the turn slow and the spread small; handling at towing speed; slow
or stopped; steaming. Applied to every fix as its nearest node, a cross join in DuckDB. **The label is the fix's**
(the maintainer's "classify the pings"). The mixture (B) and the rule (A) run in the same harness as the floor to beat.

### 3.3 Tows from labels

Runs of towing fixes (a 3-fix majority, at least 15 min). Where the logbook has records, decision 092's pairing (one
tow, one run; a run holding two declared tows cut at its least steady fix between them); where it has none, the runs
stand alone, as the flow runs at any resolution.

### 3.4 Events from many tows

The profiles of §1.4 as templates, by gear class and vessel kind (research vessels, hired trawlers, commercial): the
shooting, the gear taking the bottom, steady towing, hauling and the gear leaving the bottom (E and F, almost one
moment, ask c). Each tow's run matched to them (a
matched filter on speed, spread and turn), placing the start and end, and the events between, each with an uncertainty
from the match.

**Events named by their letters, not by variants of `t1`-`t4`** (the maintainer, 2026-10-31, with E settled, ask c):
a model places an event as one of the protocol's actions A to J, which name every event, those with no `t` (C,
F, G, H) too. The recorded times keep their names, and the grammar's table gives each its letter (`t1` = B, `t2` = D,
`t3` = E, `t4` = I). A recorded `t3` and a model's E are then two rows of the same event with two bases, not two
columns (`t3`, `t3_track`). A gear that takes the vessel twice (a longline's set and haul) opens A to J twice, as the
grammar's longline table has it.

On a cruise run under the protocol itself, two of its phases are runs at towing speed on the tow's course: F to G with
the gear off the bottom (5 min at most) and I to J with no gear (3 to 5 min or longer, the energy baseline). Speed,
spread and turn label both towing; only the template, or the bridge's presses, can tell them from the tow.

### 3.5 What it gives

Per fix: a label and its node. Per tow: its events, one row each (the station, the letter, the time, the basis:
`recorded` or `track`, and an uncertainty), the recorded times kept beside (never destroy the original); its outcome
against the declared tow (§4).

### 3.6 Deeper networks

An autoencoder on windows of fixes (`torch`, a few hundred MB, not installed) only if the map plateaus on step 3's
out-of-sample scores.

### 3.7 The A to J sequence as a prior (the maintainer, 2026-10-31)

"Start to think about how we could use this 'prior' generic knowledge pattern in a model that determines each
sequential ping within the A->J framework as a guidance ... see if it would not help us getting more confidence in the
classification algorithm."

**The model.** A gear's operation is a fixed order of phases, the intervals between the protocol's letters (the
report's table per gear). For example:
- a bottom trawl: shooting (A to D), towing (D to E), hauling (E to I), then the next shooting or steaming;
- a longline: setting (B to D), the soak elsewhere, the approach, hauling (E to I);
- a handline: drifting, and moving between drifts.

A hidden semi-Markov model whose hidden states are these phases, in that order (left to right, with a loop from J to
the next A), gives each fix the probability of each phase, given the whole sequence of fixes:
- **emissions:** per phase, the distribution of speed, its spread and the turn, by gear and length class. They are
  taken from the fixes whose phase the logged times fix where the stack shows them right (between `t2` and `t3`:
  towing; minutes after `t3`: hauling), and checked on the survey's Hafriti times;
- **durations:** per phase, from the logged spans (towing) and the profiles (a trawl's shooting 10 to 20 min, its
  hauling 5 to 15 min after E);
- **the fix spacing:** transitions in continuous time, so that a gap of 10 min allows more change than one of 2;
- **the logbook as evidence, not truth:** a logged time enters as an observation of its event, with an error model by
  gear and period. The model is tight where the stack shows agreement (the trawls' D and E, the static gears' E and
  I), wide where it does not (the purse seine's `t1`, the small gillnetters' `t1`, the new providers' stand-ins), and
  absent where nothing is logged (a longline's D).

**What it gives over the map's labels (§3.2, §3.3):**
- the order does what the map's smoothing does by hand. A single slow fix mid-tow, or a fix at 10 kn from a mixed
  feed (eight single survey tows of 2026 show them), cannot start hauling unless the fixes after it look like
  hauling, then shooting;
- handling at towing speed between tows (§1.3) sits where the sequence expects it: after E and before the next D;
- every fix gets a probability per phase, and every event a time with an interval: the confidence asked for. Its
  calibration is scored on the survey: of the 90 % intervals, the share that hold Hafriti's D and E;
- one engine serves every gear, with the topology from that gear's A to J table. The map's groups can be its inputs
  in place of raw speed and turn.

**Speed.** The parameters come from the profiles, or are fitted once on a sample. Applying them is one forward-backward
pass per vessel-year, linear in fixes (phases × phases per fix: under 100 operations), so seconds per million fixes in
compiled code. The pooled HMM of §1.2 failed on both counts, and neither cause applies here:
- on speed, because `moveHMM` fits by numerical optimisation over all the data;
- on accuracy, because its states had no order.

The implementation is an existing package for hidden semi-Markov models (`mhsmm`, `hsmm`) if one takes irregular
spacing and fixed parameters. Otherwise, a small compiled forward-backward in ramb, under the outside-methods rule.

**Risks:**
- **The order differs by fishery.** Commercial tows follow each other with no steaming; the survey steams between
  stations. So the topology is per gear, and the loop optional.
- **Phases shorter than the spacing.** A phase shorter than the fix spacing (a trawl's shooting at 4 min) is carried
  by its duration prior, not by its fixes.
- **Not yet measured:** whether one model per gear and length class holds across vessels. Step 4 measures it.

## 4. Ground truth and scoring

- **Timing truth:** the survey tows (spring, autumn, inshore shrimp; research vessels and hired trawlers), by
  `channel` from 2008 to 2026. The inspectors' and the discard project's times are set aside as timing truth (§1.1).
- **Per tow, every tow in one outcome:** paired, no run, or joined; start and end offsets within 5, 10 and 15 min and
  beyond; by survey, vessel, spacing class and year; per tow between methods (both right, one, neither).
- **The commercial tows, which have no timing truth:** every towed e-logbook record of the year in one outcome under
  the method: agree, start late or early, **end early** (an end with no break near it and towing fixes after it, as
  537654), end late, **joined** (no haul-back between two declared tows), **split** (a haul-back inside one, as 537653),
  **short stop** (shorter than any haul-back in the template, as 19:19: not decided), no run, too few fixes; by app
  (plan 053) and gear, with checked vessel overview links, a sample of each class reviewed by the maintainer.
- No pass rate fixed in advance. A method is worth adopting if it beats the recorded times where truth exists, makes no
  class worse, and holds out of sample.

## 5. Speed

The target: the whole trail labelled in under an hour, a year in minutes (speed good enough, not fastest). Training is
a sample's work (seconds to minutes in R); applying is SQL. The features move from R (2.6 h for the trail) to DuckDB.
The HMM is dropped from the main line (about 48 h for 2023 alone).

## 6. Steps

All read-only, in a study under `$FISHYDATA/archive/`, until step 6's choice.

1. **Features in DuckDB** for all of 2019 (ask a), timed, equal to the scoping's R features on its 86,693 fixes.
2. **The map trained** on a stratified 2019 sample and applied in DuckDB to all of 2019, timed; groups named by the
   fixed rule per gear class; scored on 2019's surveys.
3. **Out of sample:** the 2019 map applied to 2017-2018, the 2026 spring survey and 2023 (a sparser feed), and
   leave-one-vessel-out on 2019; scored by spacing class.
4. **Events, with the A to J sequence as a prior (§3.7):** prototyped on the bottom trawls first, on the 2026 spring
   survey (D and E from Hafriti, fixes every 2.3 min) and 2019's commercial tows; scored against the map on both ends
   within 5 and 10 min and on the calibration of its intervals; then gear by gear with the topologies of the report's
   tables. A to J named with TODO 146.
5. **The commercial picture:** every 2019 towed record in one outcome, by gear, with links; the maintainer reviews a
   sample of each class.
6. **A decision record**, and the choice: adopt, amend or stop. Adoption is a ramb step (features, labels, runs and
   pairing, events, lazily in DuckDB; `kohonen` called for training, the outside-methods rule) and a flow plan: the
   window cascade gaining basis `track`, the fix label on the trail.

## 7. What changes elsewhere

Nothing until step 6. If adopted: `station_window` gains a `track` basis where the track places a boundary, the
recorded times beside it; the catch split and the effort follow; the trail carries each fix's label; the app profile
(plan 053) may gain a row for times entered, not done; the vessel overview draws the reconciled window under the
recorded lines.

## 8. What it does not do

- Static gear: the gillnet survey's 3,888 sets of 2023 are its later ground truth (plan 013 item 8).
- Decide a snag against a haul-back: the short stop is its own outcome.
- Change the logbook's times: a reconciled boundary is a new column with its basis.
- Leave MFRI: `channel` and the logbooks are internal; any outside use needs an agreed basis first.

## 9. Asks

| | ask | recommended |
|---|---|---|
| a | The years | **answered** (the maintainer, 2026-10-31): 2019 to build, not 2023. The track is denser (2.3 min against 4.9), and the logbook is afli's: the new providers' set times for static gears are often stand-ins. 2014 is left out (quality unknown, odd towing patterns). The handline and the purse seine, for which afli has no times, from November 2025 to June 2026. Trawls are split by target (fish, shrimp, Nephrops) and by length |
| b | Gear in the first round | towed gear (bottom and midwater trawl, Danish seine, shrimp trawl by gear class); static later |
| c | What `channel`'s `tow_start` and `tow_end` mark: the start the gear taking the bottom (D)? the end the start of hauling (E, the grammar's answer of 2026-10-30) or the gear leaving the bottom (F)? | **answered** (the maintainer, 2026-10-31, with the protocol's original): D and E. The original enters the station's start in Hafriti at D ("veiðarfæri sest á botn") and its end at E ("hífing hefst, tog endar"), each "eins og venja er"; the grammar's table and the figures stand. The gear leaving the bottom (F) is a fine distinction: in Icelandic tows E and F are almost the same moment (the maintainer, the same day) |
| d | The inspectors' and discard project's times | set aside as timing truth (§1.1); their tows still scored as commercial outcomes |
| e | The neural network | **answered** (decision 270): not the map. Trained out of sample it placed both ends of a 2019 survey tow within 5 min for 25 %, against 52 % for the hidden-state model, and as an emission it pulled the end 4-5 min early |
| f | A deeper network | **answered** (decision 270): not needed; the hidden-state model decodes the trail in about 9 min, and plan 058 left the CNN and LSTM line for a plateau that did not come |
| g | The short stop (the 19:19 case) | its own outcome, counted and linked, not decided |
| h | The fix label beside or instead of `fishing_flow` | beside, until step 6 shows which is better |
| i | Finer data for the A to J events | the maintainer: the cruise protocol of TODO 146 (b), a GPS logger's or the research vessels' own logs, if any are finer than AIS |
| j | How a model's events are named and stored | by their letters A to J (the maintainer's direction, 2026-10-31, E settled by ask c), one row per event with its basis, not `t`-variant columns; the column names go to TODO 127's review |
| k | Whether the A to J sequence (§3.7) becomes the labelling model, with the map as one of its inputs, or stays a check on the map's runs | **answered** (decision 270, plan 058's study): it becomes the labelling model, without the map. Its states are towing and its look-alikes, not the letters A to J: a model of towing against "other" alone starts every tow 10-14 min early. Its 90 % intervals hold the survey's D and E 87-96 % of the time |

## References

From the search of 2026-10-31 (abstracts only):
- Vermard, Y., et al. 2010. Ecological Modelling 221: 1757-1769. <https://ideas.repec.org/a/eee/ecomod/v221y2010i15p1757-1769.html>
- Walker, E., and Bez, N. 2010. Ecological Modelling 221: 2008-2017. <https://ideas.repec.org/a/eee/ecomod/v221y2010i17p2008-2017.html>
- de Souza, E. N., et al. 2016. PLOS ONE 11: e0158248. <https://pmc.ncbi.nlm.nih.gov/articles/PMC4930218>
- Gloaguen, P., et al. 2016. Aquatic Living Resources 29: 210. <https://archimer.ifremer.fr/doc/00359/47030>
- Segment-level fishing recognition. JMSE 11(6): 1245 (2023). <https://www.mdpi.com/2077-1312/11/6/1245>
- Fishing activity from the geometry of trajectories. arXiv 2207.05514. <https://arxiv.org/pdf/2207.05514>
- Skylight's fishing model (LSTM, observer labels). <https://allenai.atlassian.net/wiki/x/BwD93wY>
- AIS fishing events against self-sampling hauls. ICES JMS 82(3): fsaf033 (2025).
  <https://academic.oup.com/icesjms/article/82/3/fsaf033/8090016>

Mined before: the WKSSFGEO repositories' HMM practice (plan 013, `docs/wkssfgeo.qmd`); CNR's SoftwareX benchmark
(Lattanzi et al. 2026). Packages used in the scoping: `kohonen` 3.0.13, `mclust` 6.1.3, `moveHMM`.
