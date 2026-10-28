# 234 — Mendo et al. 2023's set finder is no better than ramb's at any ping rate, and ramb's own fails badly on pots

*2026-10-28. A side session of the ramb session that ported iapesca 1.3 (ramb `ab0504f`, `cab18b7`), on the
maintainer's ask: "check if mendo2023 is warranted in ramb. and a comparison between iapesca and mendo may be of
interest". Run and written by Claude (AI); every number comes from its runs, and no person has checked them. Nothing
built in ramb or fishycode. ramb `cab18b7` (2026.10.28) was installed from the local clone and not yet on GitHub when
this was written; it was pushed the same day with 2026.10.28.1 (`dfd693d`), which cites Mendo et al. in
`rb_link_record_sets()` and lists `jepol` in `inst/COPYRIGHTS`. Working files: `$FISHYDATA/archive/2026-10-mendo-vs-iapesca/` (README, the full report).*

## The yardstick: a reason to recode someone's method

The maintainer, 2026-10-28, after ramb recoded iapesca 1.3's trip rule and set finder: "We have to be careful here
with respect to plagiarism. This also [is] stealing somebody's ideas. In my view a justification of including
iapesca functionality is because a difference in code flow (lazy / duckdb vs sf) or because of speed of execution
differ vastly. Otherwise one really should think about pointing a user to the original."

So a method from outside code enters ramb only for a different code flow at the flow's scale (lazy, every vessel in
one DuckDB query, where the original is sf in memory, one vessel at a time) or a vastly faster run, timed in fresh
processes and given as a ratio at several sizes. Otherwise users are pointed to the original. Two further lines from
the maintainer the same day: the CNR and jepol recodes "are not in a formal package", so there is no function to point
users to; and a method fishycode's own flow truly needs (STK, ASTD, ASTD-B, EMODnet) can be called from its package or
amended in fishycode rather than recoded in ramb. Neither iapesca recode is called by fishycode's flow (decision 158
dropped set times from the track). Both stay in ramb, with iapesca cited as the original (the maintainer, 2026-10-28):
they meet the rule on flow and on speed (iapesca 1.3's time over ramb's, fresh processes, timed in the ramb session:
trips 12, 66 and 137 at 6, 60 and 300 vessels; sets 2.4, 14 and 13 at 1, 10 and 50). Where the original exists only
as scripts or PDFs, a recode stands on that alone, if it is checked against the original's output and attributed in
ramb's `inst/COPYRIGHTS` (the maintainer, the same day). That covers CNR's R4AIS (`method = "cnr"`) and the datacall's
`define_trips_pol` (`method = "jepol"`, not yet in `COPYRIGHTS`).

## The method, by intent

Mendo et al. (2023, *Ecol. Indic.* 154: 110822) want soak time for gillnets and pots from high-rate tracks alone.
A classifier labels the hauling pings; the set is found through the haul. The haul's track is buffered
(`width_buffer`), and the vessel's longest non-hauling pass inside it is taken, day by day back from the haul, up to
30 days, if it covers over 70 % of the haul's length and the soak is over 2 h (written into the code body). Soak = the
haul's mean time minus the pass's. Their R code exists only as two PDF supplements: Sup. Mat. 4 (Denmark, "DK", the
general form) and Sup. Mat. 3 (Peru, "PE", every non-hauling ping within 500 m in the same trip). Mendo et al.'s 2024
repository has no set or soak code.

The paper's French case (one vessel, 8 trips, 39 hauls, 15 min, 2 failures) matches `iapesca::positions` in every
count it gives, and iapesca's author is a co-author. The paper does not say which code produced it: a lead, not
established.

## How it was run

- Mendo's code transcribed from the PDFs, one character changed (the PDF's `ˆ`). On its own two samples it gives the
  published results (Peru: 3 hauls, soaks 3.35, 2.95, 4.17 h; Denmark: 8 hauls, 67-74 h).
- On ramb's four labelled tracks, put into its stated contract: UTM per vessel, a regular time grid, trip =
  vessel-day, hauling = the labelled haul pings, one vessel per call. A haul of one ping is dropped (the code stops for
  the whole vessel on one).
- ramb's `rb_link_record_sets()` (iapesca 1.3) exactly as `vignettes/articles/sets.qmd` runs it; its numbers reproduce
  the vignette's.
- Scored as the vignette scores: truth is the labelled set run nearest each haul; a found set is right when its span
  overlaps that run. Mendo PE's span is every pass it pools, so its "right" is generous; the last column, the median
  gap between found and labelled set times, holds every method to the same measure.

## Right / wrong / missed, by ping rate

| dataset (hauls with a set) | method | own rate | 2 min | 5 min | 10 min | 30 min | error, own (h) |
|---|---|---|---|---|---|---|---|
| pots (56) | ramb, defaults | 33/22/1 | 36/19/1 | 37/15/4 | 19/12/25 | 6/3/47 | 0.1 |
| | ramb, `soak_h = c(0, 240)` | 16/40/0 | 14/42/0 | 22/31/3 | 16/16/24 | 6/3/47 | 24.5 |
| | Mendo DK as published | 27/13/16 | 17/6/33 | 6/0/50 | 0/0/56 | 0/0/56 | 0.1 |
| | Mendo DK, ramb's buffer and window | 36/19/1 | 29/17/10 | 15/6/35 | 4/1/51 | 0/0/56 | 0.1 |
| | Mendo PE as published | 0/56/0 | 0/51/5 | 0/39/17 | 0/26/30 | 0/10/46 | 45.3 |
| gillnets (72) | ramb, defaults | 56/12/4 | 56/12/4 | 55/10/7 | 42/6/24 | 4/1/67 | 0.7 |
| | ramb, `soak_h = c(0, 240)` | 70/2/0 | 70/2/0 | 67/2/3 | 45/3/24 | 4/1/67 | 0.8 |
| | Mendo DK as published | 8/13/51 | 8/9/55 | 5/5/62 | 2/4/66 | 1/0/71 | 2.6 |
| | Mendo DK, 330 m, 10 d, > 0 h | 68/4/0 | 69/3/0 | 59/4/9 | 41/5/26 | 4/0/68 | 0.8 |
| | Mendo PE as published | 72/0/0 | 72/0/0 | 69/0/3 | 48/0/24 | 5/0/67 | 1.1 |
| iapesca's vessel (39) | ramb, defaults | 37/2/0 | 37/2/0 | 37/2/0 | 37/2/0 | 33/6/0 | 0.1 |
| | Mendo DK as published | 3/0/36 | 3/0/36 | 3/0/36 | 3/0/36 | 2/0/37 | 0.0 |
| | Mendo DK, length rule off | 27/11/1 | 27/11/1 | 27/11/1 | 27/11/1 | 9/7/23 | 0.1 |
| | Mendo PE as published | 0/30/9 | 0/30/9 | 0/30/9 | 0/30/9 | 0/20/19 | 65.4 |

"As published" is 75 m, 70 %, 30 days, over 2 h; "ramb's buffer and window" 330 m, 10 days, over 1 h. Labelled
medians: gillnets soak 1.8 h, set run 5 min; pots 44 h, 9 min; iapesca's vessel 64 h, 30 min. The other variants are
in the report.

- Mendo DK beats ramb's defaults in one cell, dense pots at their own rate (36 against 33), and falls behind from
  2 min on. On gillnets, with no soak floor, the two are level (68 and 70 of 72, both 0.8 h). At 15 min its length
  rule fails: a set run of a few pings never covers 70 % of the haul.
- PE cannot look past the trip, so every multi-day set is wrong, by design.
- On Mendo's own two samples (labels from a random forest, no truth) both methods find the same pass for each of the
  11 hauls both match.
- Speed, Mendo ÷ ramb, fresh processes, median of three after a warm-up: DK 12, 5, 12, 23 and 49 at 1, 3, 4, 8 and 40
  vessels; PE 4 to 27. Mendo's time grows with the vessels (it loops by vessel and day in sf), ramb's is mostly fixed
  cost at these sizes.

## Found

1. **Mendo's method is not warranted in ramb.** The yardstick would allow a lazy recode, but ramb already has a set
   finder with that flow and speed, and Mendo's beats it nowhere from 2 min on. Its one idea not in iapesca's is an
   acceptance rule (no set unless the pass covers 70 % of the haul): fewer wrong sets for more misses, a gain on dense
   pots and the cause of its failures at VMS rates.
2. **ramb's set finder fails badly in three places**, judged on its own score, not against Mendo: dense pots, 33 of
   56; pots and gillnets from 10 min on (19 of 56, 42 of 72, down to 6 and 4 at 30 min); drive-in gillnets with its
   1-hour floor, 56 of 72 against 70 without it. The ~22 wrong pot sets are not classified. Three causes are possible,
   none checked: the run-in to the buoy (the hour floor removes part of it), other passes over the line, and a truth
   rule that may pick the wrong one of several nearby sets. On Icelandic static gear decision 158 found the same: the
   track does not recover the set.
3. **`rb_link_record_sets()` does not check that `key` is unique.** Repeated haul ids across 40 vessels ran over 13
   minutes, then were stopped, with no error or warning; unique ids take 0.6 s. The cause was not looked into.

## The maintainer's direction (2026-10-28, on reading it)

> * a method / function should be tested against different dataset - if it fails badly it needs to be ammended
> * one could think about using multiple methods on the same data and then kind of score things between them and
>   somehow use the best of the two.
> * ideally one should come up with one unified method that is robust against different scenarios / data-richness.
>   or somehow what method to use is deemed by the nature of the data (ping frequency, ...)

What this comparison bears on each (the rest is TODO 149):

- The amendment starts by classifying the wrong pot sets.
- Scoring two methods against each other needs, per haul, whether they err on different hauls (both right, one,
  neither). Not measured; the saved harness gives it in seconds.
- A choice by the data: at 2 min or denser both methods work; at 10 min or sparser most hauls have fewer than two
  pings and the line fails, which leaves the declared positions (`method = "record"`); drive-in gillnets need
  `soak_h[1] = 0`, pots the hour left out. Four labelled datasets only: three pot vessels, four gillnet fishers, one
  French gillnetter.

## Decided, and what is left

1. **Mendo's method is not recoded** (the maintainer, 2026-10-28). It is cited in `rb_link_record_sets()`'s references
   and in `sets.qmd` as the other published set/soak method, with what it needs (haul labels, a dense regular track)
   and the lead on its French case. The per-haul check (TODO 149) would reopen this if the two methods err on
   different hauls.
2. Open, in TODO 149: if the acceptance rule is wanted, measure it as an option of ramb's own function (a minimum
   share of the line covered), not as a second method.
3. Open, in TODO 149: Mendo's two samples (`raw/external/mendo2023/`, CC BY 4.0) as an agreement test for
   `rb_link_record_sets()`, not a truth test, since their labels are a model's; TODO 93's ask to Mendo or Glemarec
   for the observed times would make them one.
