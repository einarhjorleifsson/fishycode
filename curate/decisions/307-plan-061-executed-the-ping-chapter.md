# 307 — Plan 061 executed: the ping chapter written case by case, read by the maintainer, and closed

*2026-11-08/09. Plan 061, TODO 183 (closed), at the maintainer's word: the cases one by one ("Yes, C3 next", "The time
flag", "Yes, C5 next", "Yes, C7 next", "Yes, C2 and C6", "Yes, the appendix", "Yes, those next"), a correction ("we
should not use the 5 minute rule on the danish data - can one not change it?"), the read ("ok read the article - it
is fine") and "Yes, close and commit". Written and measured by Claude (AI); read by the maintainer. The chapter is
`docs/flow_pings.qmd`, its appendix `docs/scores_pings.qmd`.*

## Why

Plan 061 set out the ping chapter of the book: the best approach to step 0, each rule shown with the fault it catches,
on ramb's planted faults, other workflows only where a choice needs the contrast. Its check was every case C1-C7 in
the chapter, or dropped with a reason, and a clean render. Both now hold, and the maintainer has read the chapter.

## What was written

The cases, each on ramb's example data, every number computed by the page; Icelandic counts in the text only,
labelled as measured. What each case found is in plan 061 under the case and in decision 306.

- C1, placeholders with the latitude copied into the longitude (2026-11-02).
- C2, a floor under the step, not a rule on the interval, and C6, a regular series as a recipe (2026-11-09).
- C3, copies within one feed, and C7, one vessel in one second at two places (2026-11-08/09).
- C4, two feeds interleaved, unchanged from 2026-10-20.
- C5, impossible positions judged against the vessel's own speed, on ramb as built (2026-11-08).
- C8, a written time that is off, added since ramb gained `rb_flag_ping_time()` (2026-11-08).
- "With ramb" and "Not yet in ramb" brought to ramb 2026.11.07.1, the scores' appendix with "Methods compared", and the
  last three outline sections: what if a source is missing, checking it, and the ICES data call (2026-11-09).

## What the maintainer changed

The ICES data call's interval rule was first shown at its default of five minutes on tracks that report every ten
seconds. The maintainer: that rule should not be used on the Danish data, and the setting can be changed. The chapter
now treats `intThres` as the setting it is (`0_global.R`): at one minute it keeps one ping per vessel and minute, the
floor the data call's minute format sets (`dansk`: 66,295 of 395,558, and 55,242 after the harbours, against 139 at
the default), and above the ping rate it removes nearly every ping.

## What it leaves

- The chapter's first three sections ("The problem", "What the groups say", "From ramb's articles") are still the
  outline's notes; the last describes ramb's trips article as it was before plan 062.
- The book's other flow chapters are outlines (plan 033).
- In ramb, not built: direction as evidence, ties decided on evidence, the zone check (decision 306).
