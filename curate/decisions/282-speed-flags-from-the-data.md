# 282 — Speed flags from the data: each vessel's own limits, a time flag and a planted truth in ramb, scored; production unchanged

*2026-11-05. Plan 065, from the maintainer's question that morning: "the arbitrary max speed - we have that both in the
em4ssf code and in ramb ... can we find a more robust method ... anything in the property of data itself that one may
be able to use ... take your time", then "if you drop / filter data, you can not go easily back to check what was
dropped", "Yes, a plan", its asks "Yes, as recommended" (the set named `dansk_truth`), and each step at the
maintainer's word ("Start step 1", "Commit, then step 2", "Yes, step 3" to "Yes, step 6"). Built, scored and the
Icelandic cases judged by Claude (AI) the same day; the 40 cases checked by the maintainer that evening (the last
section). ramb 2026.11.05.3-.8 (d87c781, bb6333e,
c2fc469, 3df2adc, 943eee9, 4b4c2bc; the article 01d8825), each committed to ramb's local `main` when its check
passed, not installed, not pushed. The study and every script: `$FISHYDATA/archive/2026-11-05-speed-ceiling/`.*

## What was built (ramb)

- **`dansk_truth`**, a planted set of today's clocks: four of `dansk_planted`'s vessels at 1 and 6 min, written through
  eight clocks and streams (the fix's own time, cut or rounded to the minute, jittered, stamped on receipt, an hourly
  stream beside, resampled with fills, a derived speed), with new faults of position, time and speed; every row holds
  the report as written and as it truly was, and what an ideal flagger does with it.
- **The time panel's marks by colour and span buttons**, to review such a set a fault at a time.
- **`rb_create_ping_limits()`**: per vessel, or per vessel and stream, its ceiling (the highest speed it records twice
  in a row; else what its track sustains, the lower of the speeds from one and two pings back; else 25 kn), its clock
  (the grain; the time error measured against the recorded speed on steps of at most 300 s, or from measured lags),
  and the dataset's position noise, each with its basis and the count it rests on.
- **`rb_flag_ping_impossible(method = "local", limits = )`**: each vessel judged by its own limits, the flag's basis
  `"ceiling"` where its ceiling decided. Without `limits` the flags are as before, bit for bit.
- **`rb_flag_ping_time()`**: a ping whose written time is off is labelled `"time"`, its error estimated, its position
  kept and set aside as an anchor, so the speed rule after it blames no position (the case study's 08:23 ping).
- **`rb_add_ping_outcome()`**: every ping in one outcome under a rule against a truth (plan 062's scoring), read by the
  tests, the scores and the time panel's lanes alike.

## What the scores say

On `dansk_truth` (wrong positions caught %, the rule's own flags of good pings in 10,000, wrong times caught as times
%; at 1 min / 6 min):

| rule | positions | own flags | times |
|---|---|---|---|
| `clean`, 25 kn | 56 / 45 | 45 / 29 | 0 / 0 |
| `local`, recorded speed | 70 / 59 | 20 / 92 | 0 / 0 |
| own limits, no recorded speed | 53 / 52 | 17 / 79 | 0 / 0 |
| own limits, recorded speed | 65 / 64 | 15 / 110 | 0 / 0 |
| the time flag, then own limits | 65 / 65 | 17 / 122 | 22 / 15 |

- **The time flag is the gain**: it labels times no speed rule labels, a fifth of them at 1 min, its estimate within
  a median 2 s; late stamps under 2 knots, or where the speed changes by more than 20 %, it cannot see.
- **The own limits are no clear gain over `local` with a recorded speed.** They keep fast vessels, and lose detours at
  1 min and slow vessels at 6 min whose positions run faster than their recorded ceiling. Without a recorded speed they
  beat the fixed 25 kn at 6 min only.
- **The time error is a margin more than the clock's error.** On whole seconds it still reads 12-42 s at 1 min steps
  (turns within a step); over longer steps it reads the vessel's changes of speed: in Iceland's 2024, 213 of 219
  streams more than twice the spread of plan 059's copies with no cap, 6 of 34 at 300 s.

In Iceland's 2024 the built rule (own limits, no recorded speed, production's 0.3 nm floor between feeds) and
production disagree on 27,501 and 24,189 pings. Of 20 each judged from every ping of the vessel within 10 min:

| the flag of | right | wrong | a time off | undecided |
|---|---|---|---|---|
| the built rule (production keeps) | 3 | 16 | 0 | 1 |
| production (the built rule keeps) | 3 | 12 | 1 | 4 |

Where they disagree, both flag mostly good pings. The built rule's wrong flags are mostly its forward scan anchored on
a bad ping it kept (12 of 16), most often an STK port event row recording 0 kn and placed 0.8-2 km from the vessel's
other reports, which production's `clean` catches by its angle. Production's are mostly fast vessels whose own ceiling
is over 25 kn (7 of 12; 86 of the 200 drawn on such vessels).

## What was chosen

- **Production is unchanged.** `curate/ais_ping_clean.R` stays on `clean` at 25 kn: neither the scores nor the
  Icelandic cases show the own limits better where it matters, and moving production is its own decision with a
  rebuild (plan 065 §7; TODO 192).
- **The ramb functions stay as options** beside the defaults: `limits = ` is opt-in, and the time flag a step of its
  own. ramb's article on trips shows them on `dansk` (code run; the article not rendered, the installed ramb older).
- **Nothing is dropped**: every result is a label (the maintainer, 2026-11-05).

## What it leaves

- **STK's port event rows are events, not fixes**: judged as fixes they cost the local rule good pings. Plan 048 (TODO
  148) takes the events out of the track; this is evidence for it.
- **The forward scan's anchor after a ping it cannot resolve** costs both rules (12 of the built rule's 16 wrong flags,
  4 of production's 12): TODO 191.
- **`local`'s constants and a ceiling with a margin from the data** (ask f; the truth's EX_10, Iceland's B013 and B016),
  and production on the own limits and the time flag: TODO 192.
- **The automatic witnesses** of the hand check (another feed near, the legs against the recorded speed) proposed 8
  wrong positions, 4 of them right: a proposal, not an outcome; a check of Iceland's flags needs the hand, or a truth.
- **ramb installed and pushed**: at the maintainer's word.

## The hand check, checked by the maintainer (added 2026-11-05)

That evening, at the maintainer's ask ("Can we do the Hand check here?"), the maintainer judged the 40 cases on the
review page, each case alone with two hours either side, blind to Claude's verdict, which was shown after each answer
(the study's scripts 19 and 25, `out/iceland_2024_sample_checked.csv`). The verdicts agree with Claude's on 29 of 40.
The table above, on the maintainer's verdicts:

| the flag of | right | wrong | two vessels | undecided |
|---|---|---|---|---|
| the built rule (production keeps) | 1 | 16 | 1 | 2 |
| production (the built rule keeps) | 3 | 16 | 1 | 0 |

- **Where the rules disagree, both flag mostly good pings**: confirmed, more strongly for production. All 9 drawn on
  vessels whose ceiling is over 25 kn were good pings.
- **Claude's reading moved most where the maintainer saw the neighbour**: B003's bad ping is an astdB report where the
  vessel was an hour before, kept by both rules, not the case; B001's is the astd ping, not the event row beside it.
- **Two vessels under one vid** on the two foreign vids drawn (4941 and 4426; vids 3700-4999 are not keel ids): an
  identity question, which decision 283 left open.
- **STK's event rows**: of the 15 drawn, 11 placed right, 3 wrong, 1 undecided, and at a trip's start one "may be the
  best we have" (B009); beside 7 other cases the maintainer pointed out one recording 0 kn and placed off. Taking them
  out of the track (plan 048) must keep them as events.
- **Bad pings both rules keep**, seen beside the cases: B003's astdB report, the event rows beside B011 and B019.
