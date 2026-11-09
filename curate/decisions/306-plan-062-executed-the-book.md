# 306 — Plan 062 executed: the ping chapter written on step 0 as ramb built it, and the plan closed

*2026-11-08/09. Plan 062 step 6 ("the book"), TODO 184 (closed), at the maintainer's word: "Yes, start it", "Yes, C3
next", "The time flag", "Yes, C5 next", "Yes, C7 next", "Yes, C2 and C6", "Yes, the appendix" and "Yes, close it".
Written and measured by Claude (AI); no person has reviewed the chapter. The chapter is `docs/flow_pings.qmd`, its
appendix `docs/scores_pings.qmd` (commits fb8818c, beec122, 1eb9854 and d68de26); the cases are plan 061's.*

## Why

Plan 062 revised step 0 of the flow in ramb and moved fishycode's own copies of that work onto it. Its last step was
the book: the ping chapter to describe step 0 as built, with the scores in an appendix. Steps 0-5 were done before:

- steps 0-3, 2026-11-02 to 11-04: ramb's branches and the whack studies tidied, two tests on 2017, ramb's planted
  faults (`dansk_planted`), every method scored (decision 276);
- step 4, 2026-11-04: the ramb release 2026.11.04 (the copy rule, `ping_flag_basis` on every flag, the `"local"`
  method, `rb_add_ping_speed()`, three methods withdrawn after a warning), pushed 2026-11-05;
- step 5, 2026-11-08: fishycode on that release and the live store rebuilt (decision 303).

## What the chapter now says

Every planted number is computed by the page, on ramb's example data; Icelandic counts appear in the text only,
labelled as measured.

- **With ramb** and **Not yet in ramb**, brought to ramb 2026.11.07.1: the step 0 functions in the order they run,
  ramb's advice on the method, and the arguments that matter (the limits, the vote, the local speed, `stream`).
- **One feed, one report twice** (plan 061's C3): a copy repeats position, recorded speed and course. The ICES data
  call's duplicate rule removes none of `dansk_planted`'s copies; ramb labels 90 of 110 near copies and pairs 763 of
  918 shifted ones, which no rule can tell from their originals on one feed. On Iceland's reload of October 2026 no
  speed rule caught more than 13 of 1,802 day-shifted copies (decision 276).
- **One vessel, one second, two places** (C7): ramb has no tie rule; its speed test catches 106 of 124 planted ties,
  most of the rest within the floor between feeds. The position nearer the line between its neighbours is the right
  one in 119 of 124.
- **Time: a written time that is off** (C8, new: ramb gained `rb_flag_ping_time()` under plan 065): on `dansk_truth`'s
  jittered clock 1,655 of 6,419 jittered pings labelled `time`, each error estimated within a median 1.6 s; on those
  slow tracks no speed rule blames a late ping's neighbour, so the flag's gain is the times it labels.
- **Judged against the vessel's own speed** (C5): `"local"` with the recorded speed, own limits and the vote catches
  71-100 % of the out-and-backs that `"clean"` and `"forward"` never see, and keeps the truly fast stretches they flag
  almost whole. Iceland's night runs (decisions 287, 297) are its counterpoint: over long silences the angle of
  `"clean"`'s first stage still catches what `"local"` misses.
- **A floor under the step, not a rule on the interval** (C2): the ICES data call's five-minute rule, run with its own
  `vmstools::intervalTacsat()`, keeps 0-0.36 % of ramb's tracks at 10 s to 1 min.
- **A regular series, as a recipe** (C6): a grid of minutes and `rb_interpolate_track()`, the code shown; a split at
  a distance is the user's choice, since at six minutes a 500 m split cuts a day into 55 pieces.
- **The scores' appendix** and **Methods compared**: seven settings of the speed rule after the copies, every ping in
  one outcome, by rate, by fault and with the copy rule's one part or both.

## What changed against the plan

- **Direction as evidence (step 4c) was not built**, so the chapter's case for impossible positions shows `"local"`
  as built, not the whack with direction the plan named.
- **Ties decided on evidence (Decided f) were not built**: the chapter shows the gap, and the evidence a rule could use.
- **A case the plan lacked**: the time flag, built in ramb after the plan was written.
- **A correction on the way**: "Not yet in ramb" first said a tie's flag depends on the input order; ramb orders a
  tie by position itself (beec122).
- **A ramb defect found by the appendix**: one column as both `feed` and `stream` stopped
  `rb_flag_ping_impossible()`, or judged the streams together without a word. Fixed in ramb 2026.11.07.2 (55d42a6,
  ramb's local `main`, 2026-11-09); the appendix passes a copy of the column, which works under either version.

## What it leaves

- In ramb, not built: direction as evidence (4c), ties decided on evidence (Decided f), the zone check (4f).
- TODO 88, `needs: maintainer`: closed, or kept for what is left (normal Icelandic days, a lone feed's copies, about
  6,000 fixes near harbours).
- The chapter's three sections still in outline, and the maintainer's review of it: TODO 183 (plan 061).
- The pushes of fishycode and ramb, and the install of ramb 2026.11.07.2: the maintainer's.
