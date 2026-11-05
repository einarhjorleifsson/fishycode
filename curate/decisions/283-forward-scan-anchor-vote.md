# 283 — The forward scan's anchor: the pings after a jump decide which end is wrong, in ramb as `anchor = "vote"`, opt-in

*2026-11-05. TODO 191 and plan 066. The maintainer, on how to find the rule: "take your time here to think of the best
approach, explore potential alternatives ... too much thinking -> high token cost, executing code on big data -> low
token cost"; on plan 066: "Yes, build it" (asks b and c taken as recommended). Prototyped, scored, judged and built by
Claude (AI) the same day, not checked by a person. ramb 2026.11.05.9 (e50568f), committed to its local `main` at the
maintainer's word ("Commit both"), not installed or pushed.
The study and every script: `$FISHYDATA/archive/2026-11-05-forward-anchor/`.*

## What was found

Every forward scan in ramb keeps the last ping it kept as its anchor and, at a jump, blames the next ping and every
ping after until the vessel could have covered it. When the anchor is the wrong one, the good pings after it are
flagged. On `dansk_truth` that was from a tenth to three quarters of each rule's good pings flagged (`clean` 377 of
3,525, `local` with the recorded speed 511 of 2,607, `forward` 2,110 of 2,710); in Iceland, decision 282's hand check, 12 of the built rule's 16 wrong
flags and 4 of production's 12, mostly STK port event rows at 0 kn placed 0.8-2 km off the berth, whose leg in is long
and possible and leg out short and impossible, so `local`'s first stage cannot judge them.

Seven ways were prototyped as modes of a copy of ramb's two scan engines (today's scan reproduced exactly on both
sets) and scored on `dansk_truth`, every ping in one outcome, and on the 40 hand cases and their 32 vessels' whole
tracks (plan 066 §2 has the tables):

- **The vote of the pings after the jump** (of the 5 after it, those reached from the next ping and not from the
  anchor, against the reverse), **with the detour deciding a tie**, gained for every rule on the planted set and in
  Iceland: with the vessels' own limits 55.0 % of the wrong positions caught against 52.7, 2,385 good pings flagged
  against 2,681; the built rule's hand verdicts right 31 against 15, wrong flags 3 against 16.
- **The chain** (dynamic programming, the most pings kept) scored higher on the planted set and on the hand cases, but
  the cases were drawn where today's scan flagged good pings, which favours a rule that breaks ties the other way.
  Unselected, it changed a third more pings, kept event rows placed off after the berth's reports by breaking ties
  toward the later ping (5 of the 16 pings it newly kept in the draw), and lost more planted relocations.
- **Forward and backward**, the vote between the anchor and the ping before it, the scan's wait as the window, and the
  chain weighted to today's keeps did less.

The vote's cost: a run of consistent wrong pings before a silence long enough that the leg skipping a good anchor
covers it, the planted relocations at 6 min (`local` misses 4 of the 10 it caught there; none lost at 1 min).

## What was built (ramb 2026.11.05.9)

- **`rb_flag_ping_impossible(anchor = c("kept", "vote"))`** for `"clean"` (its second stage), `"forward"` and
  `"local"` (its second stage). `"kept"`, the default, is the scan as before: bit for bit the installed 2026.11.05.8's
  flags and bases on `dansk_planted` and `dansk_truth` for five rules, and production's stored labels on all 1,126,818
  pings of the 32 vessels. `"vote"` flags a wrong anchor in its place, stage `"anchor"` or `"local_anchor"`, its basis
  the leg's; its constants `vote_n` (5) and `detour_m` (50 m) in `...`, an error when given without the vote.
- **One implementation for both engines**, `src/scan_vote.h`; `whack_forward_vote_cpp()` new, `whack_local_v_cpp()`
  takes the option.
- **Equal to the prototype**: on `dansk_truth` every outcome count of every rule, and in Iceland the 40 cases' flags and
  the vessels' totals (built rule 10,454 flagged, 3,636 newly kept, 2,743 newly flagged; production 9,824, 1,584,
  1,425). The built rule's vote flags 2,732 anchors there, 2,288 of them STK event rows at 0 kn.
- **Tests** (`test-ping_anchor.R`): an anchor placed off is found by the pings after; a planted relocation at 1 min
  still caught; a spike and a run as before (and `forward`'s run, whose last ping today's scan keeps, found); a wrong
  first ping after a gap; a tie decided by the detour; the lazy route; the misuse messages. ramb's whole suite passes.
  NEWS and the function's documentation say what it does and what it costs.

## What was chosen

- **Opt-in.** Nothing in fishycode calls it. Whether production's `clean` takes it is TODO 192's decision, with a
  rebuild: on the 32 vessels it changes production's flags on 3,009 pings, but production's wrong flags in the hand
  check are mostly fast vessels over 25 kn, which no anchor rule touches.
- **The chain is not built**: its tie error is systematic, and the vote says which pings decided.

## What it leaves

- **STK's event rows** are most of Iceland's wrong anchors; taking them out of the track (plan 048, TODO 148) removes
  them at the source.
- **Vessels whose reports alternate between two places** (4941, 3.3 km apart; 4426's jumps of 8-12 km): most of the
  vote's other changes cannot be judged from the track; an identity or stream question, not the scan's.
- **ramb installed and pushed**: at the maintainer's word.
