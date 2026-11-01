# 270 — Each ping towing or not: a hidden-state model of the target and its look-alikes, in continuous time, decoded by LaMa; plan 058's study, and plan 057's ask k

*2026-10-31. Plan 058's study, run read-only by Claude (AI) in a session of its own at the maintainer's request, from
the evening of 2026-10-31 (its README dates its notes 2026-11-01, a day ahead of the clock). The maintainer steered it
on the way (quoted below) and asked for this record to be written from its draft recommendation. Nothing is built in
the flow, and nothing under `curated/` is written. No person has checked the numbers. The scripts, the results and the
full account are in `$FISHYDATA/archive/2026-11-01-phase-model/` (its `README.md`). The scoping before it is
`$FISHYDATA/archive/2026-10-31-tow-scoping/`.*

## The answer

**A hidden-state model labels each ping towing or not, and for static gear setting, hauling or neither.** The map is
not one of its inputs. Plan 057's ask k is answered: the sequence model is the labeller, not a check on the map's runs.

- **Its states are the target and what the track mistakes for it, not the A to J letters.** The maintainer, during the
  study: "in the end of the day we should not try to solve the A->J model, only the pings associated with towing or if
  static gear setting and hauling". For bottom trawl that means five states: slow, steam, the run-in before the tow
  (B to D), the tow, and hauling after it.
- **A model of towing against "other" alone fails.** It starts every tow 10-14 min early, since the run-in (the vessel
  straight at towing-like speed while the warp pays out) looks like towing. Only the order, a run-in before a tow and
  lasting minutes, tells them apart. Both ends within 5 min on the 2019 survey: 1.6 % with three states, 41 % with the
  run-in, 50 % with hauling added.
- **Turning counts as part of the sequence, not as a filter on each ping.** On 2019's fully logged groundfish trawl
  voyages (the scoping's `11_speed_turn.R`), the flow's speed rule keeps 111.8 % of the logged tow hours. Adding a turn
  filter (the largest turn under 20°) brings it to 91.5 %, by cutting 15 points of real towing for 6 points outside the
  tows. In the model, a turn whose distribution has a uniform part, so that a tow may turn at the end of a line, is the
  largest single gain.

## What was measured

**Both ends of a tow within 5 / 10 min.** On the spring surveys D and E come from the bridge (Hafriti); on the
commercial tows the truth is the logged `t2` and `t3` (`t3` = `t2` + the logged duration), which is weaker:

| | survey 2019 (561 tows) | survey 2026 (550) | commercial, 50 m and over (23,900) |
|---|---|---|---|
| the declared speed range (2.625-4.7 kn), 5-ping majority | 28.5 / 69.0 | 14.9 / 36.4 | 14.4 / 26.3 |
| the map (speed, spread, turn), trained out of sample | 25.1 / 65.1 | 10.4 / 31.5 | 3.5 / 11.2 |
| fishymodel's step-and-turn HMM, per segment | 0.5 / 3.2 | 0.0 / 0.2 | not scored |
| **the kept model (eT)** | **51.7 / 78.3** | **46.7 / 74.9** | **17.2 / 32.0** |

- **Its 90 % intervals hold the bridge's D and E** for 94 and 87 % of the 2019 survey tows, and 96 and 89 % in 2026.
- **D is 3.3 min early** at the median on the 2019 survey, as every method's is. The vessel reaches towing speed while
  the warp still pays out.
- **The commercial tows stay hard.** 9-21 % of the logged tows (by length class) hold a stop under 2 kn mid-tow: two
  hauls under one record, or a snag. Of the large trawlers' tows the model splits 2,908 and joins 5,248, and the small
  trawlers' 4,167 tows have no run under any method.

**Built up layer by layer, each layer kept only if it gained:**

| layer | kept | because |
|---|---|---|
| a left-to-right chain, speed gamma and turn von Mises | the base | |
| a robust turn (von Mises with a uniform part) | yes | the largest gain: 26 → 45 % within 5 min (2019 survey) |
| durations (phase-type: expanded states, a soft minimum for the tow) | yes | 45 → 50 %; an Erlang tow cut long tows in two |
| continuous time (exp(Q dt) for each ping's own gap) | yes | equal at 2 min; at every third ping (7 min) 33 → 72 % within 10 min |
| an outlier part, 1 %, in the emission | yes | the mixed feeds of 2026: 58 → 70 % within 10 min |
| tempered emissions (P^0.5) | for the intervals | they hold only when tempered; on commercial runs tempering joins back-to-back tows |
| the logged times as evidence (σ 2-5 min, gross errors ρ 10 %) | where the record is trusted | 78 → 83-85 % with synthetic logged times, but 80 → 63-69 % where a time is grossly wrong |
| the mixture's or the map's nodes as emissions | no | E 4-5 min early; worse on 2026, the thinned set and commercial |
| emissions refined by EM | no | worse on every set: the phases drift from what the labels meant |

**Speed is no constraint.** Parameters are fitted once per length class (seconds). LaMa's compiled forward-backward,
with one transition matrix per ping, decodes 0.67 s per million pings. All of 2019 at sea (24.7 M pings), features
included, took 0.7 min on one core and 0.4 on eight. The whole trail (319.4 M pings at sea) extrapolates to 9 min on
one core, against plan 058's budget of an hour. Of the packages, only LaMa decodes irregular `dt` with fixed
parameters. hmmTMB took 105 s per million pings and mhsmm smooths only by moving the parameters, so neither is needed,
and nothing is recoded (decision 234).

**The longline does not work yet.** The chain carries over, but hauling (1.9 ± 1.7 kn) and lying (1.1 ± 0.9 kn) have
the same speed and turning. A feature of a haul's slow progress along a line (net displacement over path length) is
the likely missing piece; it was not tried.

## Time is an observation

The maintainer, during the study: time is observed, like position, with an error of its own. So the first test on any
track is how many feeds it holds, with how many clocks, and whether a feed's time is the moment of recording or of
receipt. Measured on the Icelandic feeds:

- **astd lies behind stk** by 15-30 s from October to December 2025, 45-90 s from January to May 2026, and 30-75 s from
  September 2015 to January 2016, the lag changing by month. From February 2016 to September 2025, and in June 2026,
  they agree to the second. On the 2026 survey the offset shows as a position error
  along the track, growing with speed (165 m at 2-4 kn, 452 m at 9-13 kn), and none across it.
- **STK's time changed meaning once, in May 2025.** *Amended 2026-11-01 by Claude (AI), plan 059 §1; not checked by a
  person.* This said the units' own time to 2010 and the receipt time from 2012, measured over the whole trail. Split
  by STK's three streams (decision 233), it is a change of mix: the AIS stream is stamped at receipt in every year
  2007-2024 (87-99 %), STK's own units at their own time, 3-5 s earlier, and those units were 76 % of 2007's fixes and
  0.2 % of 2012's. Within the AIS stream the share equal falls from 99 % in April 2025 to 65 % in May, and 25-94 % by
  month since (`$FISHYDATA/archive/2026-11-01-feed-clocks/`). Where not equal it lies 1-2 s before receipt: a change of
  a second or two (plan 059 step 4, `dump/oracle/meta/stk.yml`).
- **The trail's `speed` is never derived across feeds,** so the flow's speed filter is safe from the offsets. At risk is
  what is derived from consecutive merged positions (turn, spreads) in the offset months. On the 2026 survey, speed
  derived across the feeds drops the pings inside tows labelled towing from 95 to 58 %. With the trail's speed, the
  robust turn absorbs the offset (75 against 77 % with astd aligned).

The study drafts a generic test (the dt pattern first, then recording or receipt, then the offset by vessel, feed and
period) and a harmonizing step: prefer one feed, and correct the others beside their original times, never over them.
That goes to TODO 178. Nothing is built.

## Plan 058's asks

| | ask | answer |
|---|---|---|
| a | where the model lives | the fitting in fishymodel beside its HMMs (gamma moments and a von Mises-uniform EM per phase on the labelled pings, the chain from each gear's sequence); the apply step, if it becomes a flow step, a thin ramb step that builds exp(Q dt) per ping and calls LaMa |
| b | packages | LaMa adopted; hmmTMB and mhsmm not |
| c | light supervision | yes: emissions from the pings whose phase the trusted logged times fix; the model runs where nothing is logged (the surveys have no logbook) |
| d | the years | 2019 to build and the 2026 survey to test, both done; 2017-2018 and 2023 not tested |
| e | Python or a GPU | no |
| f | the first gears | bottom trawl, groundfish: kept; longline: not until a feature tells hauling from lying |

## Found on the way

- **fishymodel's HMM functions hung on an all-NA column.** `moveHMM::prepData()` carries every column as a covariate,
  and its filling of missing values runs past the last row of an all-NA one, such as an unknown `behaviour`. Fixed in
  fishymodel (9f13881, its main, not pushed): `prepData()` gets the coordinates alone, `behaviour` is optional, and a
  zero-mass start is added for steps of exactly zero. Its test covers the three cases.
- **fishymodel's HMM is too slow for the trail:** fitted per segment, 0.5-0.9 ms per one-minute ping, about 8-12 h for
  2019's track at sea, against 0.7 min for the kept model.

## Open, in the order of what they would gain

1. The commercial splits reviewed on a sample in the vessel overview (plan 057 §4); then perhaps a haul-back signal (a
   stop) for a split.
2. The feeds' clocks tested and harmonized before any speed or turn is derived (TODO 178).
3. D still 3-5 min early: the run-in's emission mixes the turning shoot and the straight descent.
4. The small trawlers' 4,167 tows with no run under any method. *Amended 2026-11-01 by Claude (AI); not checked by a
   person:* 4,094 of them are dredge hauls (Plógur, gear code DRB_DES: the logbook's `gid` 6, the landing's 15 taken as
   `gid_used`, basis "reconstructed", as the flow uses it), which the study's selection on `gid` took for bottom
   trawl: 6,155 of its 2019 tows on 9 small vessels, and 1,537 of the 30-50 m class's no-run tows. Refitted and
   scored on groundfish trawl alone, eT places both ends within 5 / 10 min for 28.7 / 45.8 % (under 30 m; this record
   15.8 / 26.7), 20.0 / 37.6 % (30-50 m; 15.2 / 29.9) and 17.0 / 31.6 % (50 m and over, unchanged), with 65, 53 and 164
   tows with no run (`$FISHYDATA/archive/2026-11-01-label-covariates/`, "Found on the way").
5. The logged times' error model per gear and period, from the stacks.
6. Out of sample in time (2017-2018, 2023 at 5 min) and by vessel.
7. The longline's straightness feature, then the static gears.

Building the model into the flow stays plan 057's, under TODO 72 item 10.
