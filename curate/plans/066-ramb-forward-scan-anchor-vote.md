# 066 — ramb's forward scan: the pings after a jump decide which end is wrong

**status:** executed — written 2026-11-05 for TODO 191, from a study that prototyped seven ways and scored them on
`dansk_truth` and on Iceland's 40 hand cases (`$FISHYDATA/archive/2026-11-05-forward-anchor/`, its README); the
maintainer's answer the same day, "Yes, build it" (asks b and c taken as recommended); built in ramb 2026.11.05.9 (e50568f) as
`anchor = "vote"`, equal to the prototype's mode 7 on both sets, committed to ramb's local `main`, not installed or
pushed; recorded in decision 283 ·
**see:** decision 283, TODO 191 (closed), decision 282, plan 065 §7 and step 5, the study
`$FISHYDATA/archive/2026-11-05-speed-ceiling/` (scripts 21-23), TODO 148 (plan 048, STK's event rows), TODO 192

Drafted with AI assistance (Claude) on 2026-11-05; a person has not yet checked it. **Measured** (by Claude, the study's
scripts 01-04): every number in §1 and §2, on `dansk_truth` and on the 32 Icelandic vessels of the 40 hand cases
(2024); the hand judgements of §2 are Claude's, from each ping's neighbourhood within 10 min, not a person's.
**Assumed:** that the hand cases and the sampled changes stand for the rest of Iceland's years; that the constants
(5 pings, a factor of 2 and 50 m) need no tuning (5 pings against 3 and 10 changed at most two of `dansk_truth`'s
160,097).

## 1. The fault

Every forward scan in ramb (`local`'s stage 2 in `src/whack_local.cpp`; `forward`, and `clean`'s second stage, in
`src/whack_forward.cpp`) keeps the last ping it kept as its anchor. When the next ping cannot be reached from it, the
scan always blames the next ping, and every ping after it until the vessel could have covered the jump. When the anchor
is the wrong one, the scan flags good pings for it.

- **In Iceland's 2024** (decision 282's hand check): 12 of the 16 good pings the built rule wrongly flagged, and 4 of
  production's 12. Typically an STK port event row recording 0 kn, placed 0.8-2 km from the berth: its leg in is long
  (minutes) and so possible, its leg out short (seconds) and impossible, so `local`'s first stage, which needs both legs
  impossible, cannot judge it, and the scan keeps it.
- **On `dansk_truth`** (script 01): of the good pings each rule flags, those flagged by the forward stage behind a
  wrong anchor it kept, both rates: `local` with the recorded speed 511 of 2,607, own limits 712 of 2,681, `clean` 377
  of 3,525, `forward` 2,110 of 2,710 (mostly a wrong first ping after a gap). The anchors: copies (`rx_copy`,
  `summer_time`, `clock_offset`), runs, ties and first pings after a gap.

## 2. Seven ways, scored

Each prototyped as a mode of a copy of both engines (the study's `anchor_engines.cpp`), run through ramb's own R
code; mode 0 equals today's flags on both sets (plan 065's `dansk_truth` score, and production's stored labels on all
1,126,818 pings of the 32 vessels).

| mode | at a jump from anchor j to the next ping q |
|---|---|
| 0 | today: q is flagged |
| 1, the vote | of the 5 pings after q, n_q can be reached from q and not from j, n_j the reverse; if n_q > n_j and the leg that skips j is possible (from p, the ping kept before j; or j the first of a stretch), j is flagged instead, once per anchor |
| 2 | as 1, the vote between j and p (TODO 191's wording) |
| 3, the chain | the most pings that can be kept with every kept leg possible (dynamic programming, 30 predecessors), the rest flagged |
| 4 | today's scan forward and backward, a ping flagged when both flag it |
| 5 | as 1, the window the scan's wait (until j could reach q) |
| 6 | the chain, ties (and a bias of 0.5 or 1) to today's choice |
| 7, the vote and the detour | as 1, and where the vote ties (none voting included), j is flagged when its detour, d(p,j) + d(j,r) − d(p,r) with r the ping after q, is more than twice q's plus 50 m |

**`dansk_truth`** (script 02; wrong positions caught %, good pings flagged, both rates; every ping in one outcome by
`rb_add_ping_outcome()`):

| rule | 0, today | 1, the vote | 3, the chain | 4 | 6, ties to today | 7, vote and detour |
|---|---|---|---|---|---|---|
| `local`, recorded speed | 67.0 · 2,607 | 67.6 · 2,491 | 69.4 · 2,213 | 61.9 · 1,864 | 68.3 · 2,383 | 68.7 · 2,458 |
| own limits | 52.7 · 2,681 | 53.7 · 2,423 | 54.3 · 2,143 | 47.7 · 1,788 | 54.3 · 2,299 | 55.0 · 2,385 |
| own limits, recorded speed | 65.0 · 2,571 | 65.6 · 2,413 | 66.9 · 2,169 | 60.0 · 1,857 | 66.5 · 2,287 | 66.3 · 2,389 |
| `clean`, 25 kn | 53.4 · 3,525 | 54.4 · 3,409 | 55.0 · 3,265 | 51.9 · 2,912 | 54.4 · 3,410 | 54.5 · 3,389 |
| `forward`, 25 kn | 48.2 · 2,710 | 51.3 · 1,192 | 54.1 · 802 | 42.8 · 396 | 52.4 · 1,034 | 52.8 · 1,146 |

Modes 2 and 5 do less than 1; 1 at 3, 5 or 10 pings is the same within a ping. The cost of 1, 3, 6 and 7: the planted
relocations (five pings before a silence of 30 min, moved 2-10 km together) at 6 min, where the leg that skips the
anchor covers the jump and the five consistent wrong pings outvote it: of the 20 planted at 6 min, `local` misses 4
of the 10 it caught (own limits 3 of 6, `clean` 1 of 6; none lost at 1 min); the chain loses more (`clean` 5 of 6).
Mode 7 catches the planted ties best (`local` 89.9 % against 75.1).

**Iceland's 40 hand cases** (script 03; the cases of decision 282, every one in one outcome against the hand's
verdict: right, wrong flag, missed; the 5 undecided and the 1 time off are the rest of the 40):

| rule | 0, today | 1, the vote | 3, the chain | 4 | 6 | 7, vote and detour |
|---|---|---|---|---|---|---|
| built (own limits) | 15 · 16 · 3 | 25 · 8 · 1 | 33 · 1 · 0 | 30 · 1 · 3 | 25 · 8 · 1 | 31 · 3 · 0 |
| production (`clean`) | 19 · 12 · 3 | 20 · 11 · 3 | 29 · 4 · 1 | 27 · 4 · 3 | 20 · 11 · 3 | 21 · 10 · 3 |

Production's wrong flags left are mostly fast vessels over 25 kn, which no anchor rule touches (TODO 192).

**Beyond the 40, on the vessels' whole tracks** (script 04; the cases were drawn where today's scan flagged good
pings, so they favour any rule that breaks a tie the other way): the built rule under mode 7 keeps 3,636 pings
today's scan flags and flags 2,743 it keeps, 2,288 of them STK event rows at 0 kn; under the chain 4,658 and 3,751.
Sampled and judged from the neighbourhood: the vote's changes that involve an event row read right (8 of 8 in the
first draw, of mode 1, whose flips mode 7 makes too; mode 7's own were not drawn apart); of mode 7's other changes, 32
drawn with the event rows left out, 7 read right, 1 wrong (an STK report flagged, an event row 638 m off kept) and 24
cannot be judged from the track (vessel 4941's reports alternating between two places 3.3 km apart,
4426's jumps of 8-12 km, fast vessels under 25 kn). The chain's changes beyond mode 7 hold a systematic error: at a tie
it keeps the later ping, so an event row placed 1-1.4 km off after the berth's reports is kept and a berth report
flagged (5 of the 16 pings it newly keeps in the draw).

## 3. Proposal: mode 7 in ramb, opt-in

- **`rb_flag_ping_impossible(anchor = c("kept", "vote"))`**, for `"clean"`, `"forward"` and `"local"`. `"kept"`, the
  default, is today's scan bit for bit. `"vote"`: at the first ping q an anchor j cannot reach, the 5 pings after q
  vote (reached from q and not from j, or the reverse); when more side with q, or the vote ties and j's detour is more
  than twice q's plus 50 m, and the leg that skips j is possible, j is flagged and q judged again from the ping before
  j. Once per anchor; a stretch after a gap starts as today.
- **The label**: a flagged anchor's stage is its own, `"local_anchor"` and `"anchor"`, so a user sees which flags the
  pings after decided; its basis is the leg's, as today. `evidence = TRUE` needs no new column (its side is `"next"`).
- **The constants** (5 pings, the factor 2, 50 m) hand-set, measured insensitive for the count, passed in `...` as
  `local`'s are.
- **The limits**: the scan's own leg rule decides every vote, so with `limits =` each vessel's ceiling, margin and time
  error decide it too.

Not proposed: the chain (mode 3). It scores best on the planted set and on the selected hand cases. But it changes a
third more pings, makes the tie error above, and loses more relocations. Its dynamic programming also hides which
ping decided. Mode 6 (the chain with ties to today) does no better than mode 7 in Iceland.

## 4. Steps

1. **Build** in ramb (both engines, the R argument, documentation, NEWS, a version): tests that `"kept"` gives the
   flags of today on `dansk_planted` and `dansk_truth` for the three methods; small tracks for an anchor placed off
   between a long leg in and a short leg out (resolved), a planted relocation at 1 min (still caught), a spike and a
   run (unchanged); ramb's whole suite. **check:** the suite passes; `"kept"` bit for bit.
2. **Score** with ramb's option in place of the prototype: the study's scripts 02 and 03 rerun. **check:** the
   prototype's mode 7 numbers of §2 exactly, every ping in one outcome.
3. **The record:** a decision here, TODO 191 closed; whether production takes it is TODO 192's (a rebuild).

## 5. Asks

a. **Build mode 7** as `anchor = "vote"`, opt-in (recommended), or another mode, or park the item.
b. **The names**: `anchor = c("kept", "vote")`, and the stages `"local_anchor"` and `"anchor"` (recommended), or the
   flag kept under `"local_forward"` and `"forward"`.
c. **The relocation's cost at 6 min** (4 of 20 planted pings for `local`) taken as the price (recommended); a rule
   that tells a relocation from a bad anchor needs evidence past the silence, which a count does not give.

## 6. Not in this plan

- Production's rule (TODO 192); STK's event rows taken out of the track (plan 048, TODO 148), which would remove most
  of the Icelandic anchors at the source.
- The chain as a method of its own.
- Vessels whose reports alternate between two places (4941): an identity or stream question, not the scan's.
