# 230 — A fishing operation is a sequence of events: `t1`-`t4` the four every gear shares, a trawl's A to J and a longline matched to it

*2026-10-26. The maintainer gave section 5.1 of a cruise protocol in Icelandic, "Skráning aðgerða" (recording the
actions), and asked to include it in the grammar's thinking of a fishing operation and to match, for example, a
longline along it, the protocol translated to English by its letters A to J. Claude (AI) translated it, matched the
longline and wrote the section "Events between and around the four" in `docs/grammar.qmd` and this record. No person
has checked them. Nothing went into ramb or the pipeline. Amended 2026-10-27: the maintainer answered TODO 146 (c),
"The A-J protocol translation may stay public"; it had been pushed to the public repository the same day, before the
answer.*

## What the protocol records

Ten actions per tow, A to J, each a button pressed on the bridge as it begins, so that the phases can be compared
between tows. The station's start (D) and end (E) also go into Hafriti as before. The run from I to J, the vessel on the
tow's course and towing speed with all the gear on board, is the baseline subtracted from the tow's energy use to give
the energy the trawl takes. It is done at every station because it varies with weather and current, and is to be
reconsidered for the next cruise if its variation stays within the error. The translation, with each action placed
against `t1`-`t4`, is the table in the grammar's section.

Words chosen in the translation: *kollína* is the codline (the codend's closing end), *togferð* towing speed, *hlerar í
gálga* doors at the gallows, *leiðangur* a cruise. Which cruise the protocol belongs to is not recorded.

## What the grammar takes from it

The concept is extended, nothing renamed:

- **`t1`-`t4` are the four events every gear shares**, out of a longer, ordered sequence. A protocol may record
  events between them (C, F, G, H), which split a phase, and around them (A, J), which bound the vessel's work at the
  station. Each pair of consecutive events bounds a phase. The active interval stays `[t2, t3]`.
- **For towed gear, `t3` covers two events.** The grammar defines it as off the bottom (F); Hafriti and
  `fs_afladagbok`'s `lok_timi` record the start of hauling (E), and between the two the gear is still on the bottom.
  Left open for the maintainer (TODO 146); the grammar says a recorded `t3` is the start of hauling.
- **A and J are station events, B to I the sample's.** Recorded, they make the station's `s1`/`s2` times of their own,
  wider than the sample's.
- **A phase can exist only to measure.** I to J is at towing speed and on the tow's course with no gear, so no speed
  filter can tell it from the tow; a filter over the fixes (decision 215) can keep or drop such a phase by name once a
  record holds it.

## The longline matched

A longline occupies the vessel twice, to set (A to D) and to haul (A again, then E to J), with the soak between. Every
trawl action has a counterpart except G, the restart after the off-bottom tow; the nearest is a parted line, hauled
from its other end. Gillnets and pots have the same shape. ramb's `set` and `haul` windows already cover B to D and E
to I. In A to J's terms, `fs_afladagbok` records a longline at B, E and I (`upphaf_timi`, `milli_timi`, `lok_timi`)
and a trawl at D and E (`upphaf_timi`, `lok_timi`; `docs/grammar_logbooks.qmd`).

**A line fishes hook by hook**, not as one unit. Each hook soaks from its own set (between `t1` and `t2`) to its own
haul (between `t3` and `t4`), so every hook soaks at least `t3 − t2` and at most `t4 − t1`. With steady setting and
hauling the mean soak is `(t3 + t4)/2 − (t1 + t2)/2`, whichever end is hauled first (worked from a hook at fraction
`u` of the line, set at `t1 + u(t2 − t1)` and hauled at `t3 + u(t4 − t3)` or `t3 + (1 − u)(t4 − t3)`).
`t3 − t1`, the approximation where `t2` is not recorded (`docs/grammar_logbooks.qmd`), differs from the mean by half
of `(t4 − t3) − (t2 − t1)`. This is arithmetic on the definitions; it was not measured on the data.

## What was not done

- No names or columns for the events between and around the four: that is for the names' review (TODO 127).
- `t3`'s definition unchanged, the choice being the maintainer's (TODO 146).
- No code: ramb's windows and `phase` keep their four-event design.
