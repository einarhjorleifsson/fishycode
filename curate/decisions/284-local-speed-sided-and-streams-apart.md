# 284 — The `local` rule's local speed follows a change of speed, and each stream may be judged alone: ramb's `local_speed` and `stream =`

*2026-11-05. Plan 065's ask f and plan 068, each step at the maintainer's word: "Yes, measure it", "Yes, write the
plan", then, before executing it, "would it be of help to look manually at other datasets first ... every messy dataset
is messy in its own way, every tidy dataset is the same" ("Yes, count them", "Yes, prepare the page"), "Yes, as
recommended" (the plan's asks a-d), "Yes, step 0" to "Yes, step 4". Measured, prototyped and built by Claude (AI); the
hand checks are the maintainer's: Iceland's 40 cases (decision 282), EM4SSF's CS1, 30 cases (me_code
`analyses/hand_check_cs1/`), and 32 episodes on five more datasets. ramb 2026.11.05.10 (5a83342) and 2026.11.05.11
(b7109d4), committed to its local `main`, not installed or pushed. The study and every script:
`$FISHYDATA/archive/2026-11-05-local-allowance/`.*

## What was found

- **The margin is not the lever.** ramb's `local` rule holds a leg impossible when it is longer than
  `m0 + (1.5 v + 5 kn)(dt + te)`. On `dansk_truth` each 5 kn more of margin costs about 6 points of the wrong positions
  caught, for a quarter to a third fewer good pings flagged.
- **The local speed is.** `v` was the median of the recorded speeds of the 5 pings on each side, the ping's own left
  out. Leaving a berth, or hopping between two, the pings at rest outvote those that move: on CS1 the steps that start
  the false forward runs had a local speed of 0 while the device recorded 15.7 kn, and every flag the rule added to
  the 26 kn rules was a good ping (the maintainer, 30 cases).
- **Legs between streams.** On `dansk_truth` at 1 min, 1,425 of the 1,529 good legs the allowance failed joined two
  streams whose clocks differ; fishycode's own rule is to derive within one stream (plan 059).
- **A constant passed in `...` could be taken for `kn_max`**: `k = 3` matched it partially and never reached the
  engine (found in step 0, when a variant equalled its base in every cell).
- **A derived speed is taken as recorded.** WorldFish's PDS speed is the step speed (1.00 of it), yet the local rule
  judges by it; Ireland's pots (0.64) and iapesca's Danish seiner (1.54) have a speed column of unknown unit. ramb does
  not tell a user so.

## What was built (ramb)

- **`rb_flag_ping_impossible(local_speed = c("larger_side", "both_sides"))`**: the local speed the larger of the median
  of the `k` before and the median of the `k` after, the ping's own counted on each side (one value of `k + 1`, so a
  single glitch is outvoted); `"both_sides"` the old median, bit for bit. **A change of default** for `"local"`.
- **`rb_flag_ping_impossible(stream = )`**, opt-in for every method: no leg, scan, vote or piece of evidence joins two
  streams; the limits by vessel, or by vessel and stream. With it the warning on unharmonised clocks is not given.
- **`...` after `method`**, so the arguments after it are named in full and `k =` reaches the method.

## What the evidence says

With the vote, each vessel's own limits and the recorded speed, margin 5 kn; the maintainer's verdicts where there are
verdicts:

| | the old local speed | `"larger_side"` |
|---|---|---|
| `dansk_truth` 1 min: wrong positions caught; good pings flagged per 10,000 alone / beside a fault | 65.9 %; 12.2 / 111 | 65.5 %; 9.8 / 110 |
| `dansk_truth` 6 min | 67.7 %; 104 / 517 | 66.7 %; 50 / 508 |
| the same, each stream alone, 1 min / 6 min (caught; beside) | 60.6 %, 60.8 %; 57, 280 | 59.8 %, 59.8 %; 57, 270 |
| CS1: flagged; of the 411 good pings flagged beyond the 26 kn rules, left | 474; 411 | 137; 75 |
| Iceland's 40 cases, streams together: right · wrong | 30 · 6 | 33 · 3 |
| the same, each stream alone | 29 · 7 | 34 · 2 |
| five datasets, the 26 decided episodes where the two part: right · wrong (of 4 times off, flagged) | 1 · 21 (4) | 20 · 2 (2) |

- The sided median was chosen over two variants (step 0): leaving the ping's own speed out did a little worse at 6 min
  and on CS1; 3 pings a side lost catch, the planted misplaced fills among it.
- Judging each stream alone halves the good pings flagged beside a fault for 6-7 points of catch: the planted ties,
  two reports of one time in two streams, show only on legs between them. A trade, so an option.
- Built and checked: ramb's flags and bases equal to the prototype's in 20 runs on the two planted sets (step 1);
  `stream =` equal to each stream run as its own vessel for `clean`, `forward` and `local` (step 2); every number above
  reproduced with ramb itself (step 3). ramb's suite passes (2,977).

## What was chosen

- **`"larger_side"` as `"local"`'s default** (ask a): better on every set, and nothing in fishycode's production calls
  `"local"`. **`stream =` opt-in** for every method (ask c). The names as proposed (ask b). The factor 1.5, the margin
  5 kn and `k` 5 stay.
- **Production is unchanged** (TODO 192): `curate/ais_ping_clean.R` runs `clean` at 25 kn; nothing in fishycode calls
  `"local"` or passes `stream =`.

## What it leaves

- **dansk's four times off** (E06-E09): the old local speed flagged them, as positions; the new one keeps them, and the
  time flag labels none of dansk's pings. The cost of the change.
- **Production's speed rule** (TODO 192): the own limits with the recorded speed, the new local speed, the vote and,
  stream by stream, `stream =` are now one candidate, against `clean`'s 25 kn that flags fast vessels' good pings; a
  rebuild, the maintainer's.
- **A derived speed taken as recorded**: a robustness question for ramb, in no TODO yet.
- **New witnesses** (the maintainer's question, "are we now moving into the cascading evidence approach?"): the rule
  is a cascade of the recorded speed, the vessel's ceiling and the fixed limit, each flag with its basis; plan 068
  sharpened its first tier. The errors the hand checks found beyond it (STK's event rows, plan 048; two vessels under
  one vid; clocks between streams; a speed column not knots over ground) want witnesses of their own: a design, not
  built.
- **ramb installed and pushed**: at the maintainer's word.
