# 275 — EM4SSF's meetings and comparisons move to a repo of their own, me_code; the book describes the best approach

*2026-11-02. The maintainer's choices in a discussion of ramb's revision (plan 062), which began as "Ramb revisions":
the branches, and the functions that detect whacky pings against the ICES data call, EM4SSF and iapesca. Written by
Claude (AI); no person has checked it.*

## What was chosen

- **The book describes the best approach, not a meeting** (the maintainer: the book "should not focus on the upcoming
  em4ssf meeting, but the 'best approach'"). Plan 061 is rewritten a second time: the ping chapter presents step 0 rule
  by rule, each with the fault it catches, and another workflow appears only where a choice needs the contrast.
- **EM4SSF's meetings and comparisons are dealt with outside fishycode and ramb**, in a repo of their own:
  `~/stasi/em4ssf/me_code`, beside the two private clones (`R_code`, `Py_code`), with no remote. Set up the same day
  with a README (its rules, carried from decision 238) and a `TODO.md`. The name is the maintainer's, after the clones.
- **The flow work stays in fishycode and fishydata**, and a method reaches ramb through a fishycode plan, never from
  `me_code` (the maintainer: "we would of course still keep what we are doing in the code flow in
  fishycode/fishydata").

## What moved

| from | to |
|---|---|
| TODO 155 (a), the time zone of D2.1's `DATE_TIME`, a question for its authors | `me_code`'s `TODO.md` item 1. Its ramb side, a check of a track's zone from the data alone, is plan 062's ask 4 |
| TODO 155 (b), the trace again as EM4SSF's code grows | `me_code` item 2 |
| plan 061's C5, Mendo et al. 2024's speed rule against ramb's | `me_code` item 3, run from the paper's supplements on plan 062's planted faults |
| plan 061's C7, iapesca's side (`CalcSpeed()` on same-second fixes) | `me_code` item 4 |

TODO 155 is deleted from `TODO.md`. Decision 273 cites it as it stood that day.

## Why a repo of its own

- fishycode is public, and EM4SSF's code is private: decision 238 keeps the clones outside every repo and its changes
  undescribed in public until D4.1 (May 2027). A private repo beside the clones keeps that rule more easily than a
  public one that must not name what it compares.
- The meetings run to D4.1, D4.2 and D4.3 (January 2028) and WKSSFGEO3 (December 2027); a repo named for the work, not
  the hackathon, outlives Ancona.

## What stays in fishycode

Decisions 229, 232, 238 and 273 as records; the EM4SSF rows of the wish list in `docs/one_flow.qmd`, which are asks and
definitions that shape the approach; `curate/issues/iapesca.yml`, the channel to iapesca's author.
