# 068 — ramb's `local` rule: a local speed that follows a change of speed, and each stream judged alone

**status:** proposal — written 2026-11-05 at the maintainer's word ("Yes, write the plan"), from the study
`$FISHYDATA/archive/2026-11-05-local-allowance/` (its README), which measured plan 065's ask f; nothing built ·
**see:** TODO 192, decisions 282 (its last two sections: Iceland's 40 cases and EM4SSF's CS1, checked by the
maintainer) and 283, plan 065 §6 ask f, plan 059 ("derive within one stream"), me_code `analyses/hand_check_cs1/`

Drafted with AI assistance (Claude) on 2026-11-05; a person has not yet checked it. **Measured** (by Claude, the
study's scripts 01-09): every number in §1 and §2, on ramb's planted set `dansk_truth`, on EM4SSF's CS1 (counts only)
and on the 32 Icelandic vessels of the 40 hand cases (2024), scored on the maintainer's verdicts where there are
verdicts. **Assumed:** that a sided median is the change to build (two variants are tried first, step 0); that the
hand cases, drawn where other rules disagree, stand for the rest; that the flags the new way adds beyond production's
in Iceland (not judged) are no worse than those it removes.

## 1. The fault

ramb's `rb_flag_ping_impossible(method = "local")` holds a leg impossible when it is longer than
`m0 + (1.5 v + 5 kn)(dt + te)`. `v` is the local speed: the median of the recorded speeds of the 5 pings on each
side, the ping's own left out, the larger of a leg's two ends' in the forward scan. On CS1 every flag it adds to the
26 kn rules was a good ping by the maintainer's check (decision 282).

- **The margin is not the lever.** On `dansk_truth` each 5 kn more costs about 6 points of the wrong positions caught
  for a quarter to a third fewer good pings flagged alone (study 02).
- **The local speed is.** On CS1 the 107 steps that start its forward runs are one-minute steps of about 460 m
  (6.2 kn) whose local speed is 0 (median; 90 % under 1.1 kn) while the device records 15.7 kn at the run's first
  ping (03): leaving a berth, the neighbours at rest outvote the moving ones, the allowance falls to the bare margin,
  and the scan blames the good pings after.
- **Legs between streams.** Of the good legs today's allowance fails on `dansk_truth` at 1 min, 1,425 of 1,529 join
  two streams whose clocks differ (01); fishycode's own rule is to derive within one stream (plan 059).

## 2. Two changes, prototyped

In a copy of ramb's engine (the study's `local_engine.cpp`, whose mode 0 gives ramb's flags ping for ping), with the
vote (decision 283) and the margin of 5 kn:

| | today | the larger of the medians before and after |
|---|---|---|
| `dansk_truth` 1 min: wrong positions caught; good pings flagged per 10,000 alone / beside a fault | 65.9 %; 12.2 / 111 | 65.4 %; 10.0 / 110 |
| `dansk_truth` 6 min | 67.7 %; 104 / 517 | 66.7 %; 67 / 512 |
| CS1: flagged; of the 411 flags beyond the 26 kn rules, left | 474; 411 | 194; 126 |
| Iceland's 40 cases (the maintainer's verdicts): right · wrong | 30 · 6 | 32 · 4 |
| the same, each stream judged alone | 29 · 7 | 34 · 2, no good ping flagged |
| Iceland's 32 vessels: pings flagged, every stream together | 16,381 | 12,619 |

- **The sided local speed** keeps the catch within a point and flags 18-35 % fewer good pings alone on the planted
  set, 70 % fewer of CS1's false ones. At 6 min it flags as few good pings alone as a 10 kn margin, with 8 points
  more caught.
- **On five more datasets, checked by the maintainer** (the study's 07-09, added 2026-11-05 at the maintainer's word,
  "every messy dataset is messy in its own way"): every episode where the two ways part on a recorded speed was
  judged, 32 in dansk, Italy's AIS (CNR-IRBIM), the Adriatic passive gear, Ireland's gillnets and iapesca's French
  trawler. The sided speed is borne out in 21 (28 pings), today's in 1; 6 undecided. Its cost: 4 times off in dansk
  that today's rule flags, as positions, and the sided one keeps; the time flag labels none of dansk's pings. Portugal's
  GPS sets, Ireland's pots and iapesca's Danish seiner have no flag under any rule.
- **Each stream judged alone** (the rule run with vessel and stream as its vessel) halves the good pings flagged
  beside a fault on the planted set (111 to 57 at 1 min, 517 to 280 at 6 min) for 5-7 points of catch. The catch lost
  is the planted ties (two reports of one time, one wrong, in two streams: 137 of 169 lost), which show only on legs
  between streams; runs, detours and first pings after a gap are caught a little more. In Iceland, with the sided
  speed, it is the best on the cases. A trade, so an option.

## 3. Proposal

- **`rb_flag_ping_impossible(local_speed = c("larger_side", "both_sides"))`**, for `method = "local"`: `"larger_side"`
  the larger of the median of the `k` recorded speeds before and the median of the `k` after, the ping's own left out
  (a single glitch still outvoted on its side); `"both_sides"` today's, bit for bit. The default is ask a.
- **`rb_flag_ping_impossible(stream = NULL)`**, for every method: given a column, each vessel's streams are judged
  apart, so no leg, scan, vote or piece of evidence joins two streams; `limits =` keyed by vessel and stream, as
  `rb_create_ping_limits(stream = )` makes them. `NULL`, the default, judges a vessel's streams together, as today.
- **The constants stay**: the factor 1.5, the margin 5 kn, `k` 5 (step 0 tries 3).

## 4. Steps

0. **Two variants more** in the study's prototype, scored as its 04-06: the ping's own recorded speed counted on the
   side it would join (a glitch then excuses its own leg, the risk to measure on the planted `speed_glitch`), and `k`
   3. **check:** each variant's three tables beside §2's; the one built is the best on all three sets, or the sided
   median stays.
1. **Build `local_speed`** in ramb (`src/whack_local.cpp`, the R argument passed to the engine, documentation, NEWS, a
   version): tests that `"both_sides"` gives 2026.11.05.9's flags on `dansk_planted` and `dansk_truth`; a track that
   leaves a berth at one-minute steps (no good ping flagged under `"larger_side"`, flagged under `"both_sides"`); a
   spike and a run still caught; ramb's whole suite. **check:** the suite passes; `"both_sides"` bit for bit.
2. **Build `stream =`** for every method (the vessel's key taken with the stream inside, the limits by both, the
   evidence's legs within the stream): tests that `stream = NULL` gives today's flags, and that a stream column gives
   the flags of running each stream as its own vessel (the study's way) on `dansk_truth`, for `clean`, `forward` and
   `local`. **check:** the suite passes; both equalities.
3. **Score with ramb itself**: the study's 04-06 rerun with ramb's options in place of the prototype. **check:** §2's
   numbers exactly, every ping in one outcome.
4. **The record**: a decision here, TODO 192 updated, AGENTS.md's "Which ramb". Installed and pushed at the
   maintainer's word.

## 5. Asks

a. **The sided local speed**: `local`'s default (recommended: better on all three sets, and nothing in fishycode's
   production calls `local`), with `"both_sides"` for today's; or opt-in, as the vote is.
b. **The names**: `local_speed = c("larger_side", "both_sides")` and `stream = NULL` (recommended; `stream` as
   `rb_create_ping_limits()` and `rb_flag_ping_time()` name it), or others.
c. **`stream =`** opt-in and for every method (recommended), or for `local` only.
d. **Step 0** first (recommended), or the sided median built as prototyped.

## 6. Not in this plan

- Production's rule (TODO 192): whether `ais_ping_clean.R` moves, with a rebuild, stays the maintainer's.
- The vote as a default (decision 283), the factor and margin, the time flag.
- The 126 flags CS1 keeps beyond the 26 kn rules and the 63 every rule shares (me_code TODO 6): not judged.
- STK's event rows and the foreign vids' two vessels: upstream of any speed rule (plan 048; decision 283).
