# 276 — Plan 062 step 3: copies first, then a speed rule against the vessel's recorded speed; what was tried and dropped

*2026-11-04. The maintainer's steers in the discussion of 2026-11-03 behind plan 062 (quoted below where given).
Step 3 was run by Claude (AI) on 2026-11-02 and 11-03. This record was written by Claude, and no person has checked
it. Every number is in the study `$FISHYDATA/archive/2026-11-02-plan062-step3/README.md`, which names its sections
and result files. They are not restated here. Nothing went into ramb. The prototypes are scripts in the study.*

## What was measured

Step 0's flaggers were scored ping by ping on two sets. The first is ramb's planted faults, `dansk_planted` (ramb
378bf21, unpushed): ten faults in clean, fishing-labelled tracks at 10 s, 1 min, 6 min and 1 h. The second is the
reload of 2026-10-12 to 10-14, labelled from the raw trail's receipt as decision 143 measured it. It is the one
Icelandic set with a truth, and that truth covers its day-shifted copies only. Every ping falls in one outcome. The
number to watch is the good fishing pings flagged. The time and memory were measured at 1, 10 and 100 M pings.

## Kept

- **Copies first, then the speed rule.** The speed rules' cost in fishing pings comes from the copies. Where a copy
  interleaves with the true track, a true ping between two copies looks as wrong as the copy. Taken out first, the
  copies leave the rule against recorded speed flagging as few fishing pings as the best of the others at 10 s and
  1 min (the study's "Tuned" and "A prototype copy rule").
- **A speed rule against the vessel's own recorded speed over ground** (`local_sog`, `scripts/local_speed.R`). Each
  leg is judged against the median recorded speed of the pings around it, with no heading. It catches the most
  wrong pings at every rate. That includes out-and-backs under 25 kn, which no fixed-limit method catches. It also
  keeps a truly fast vessel, which every fixed-limit method flags. Its parameters are a first guess, kept after
  tuning (below). It is the candidate for plan 062's step 4c in place of the turn features.
- **`clean` and `forward` both, for a track with no recorded speed.** Neither is best everywhere. `clean`'s sda stage
  erodes good pings beside a fault it cannot resolve. `forward` loses a stretch when its anchor, the first ping after
  a gap, is wrong (Part A). The fixed 25 kn rule stays as the fallback. No method flags a good fishing ping with no
  fault near.
- **A copy is one report twice**, told by position, recorded speed and course (`scripts/copy_rule.R`). Within 2 s in
  one feed, the later ping is a near copy. Across two feeds, the later feed's ping is the copy. This finds the
  reload's repeated reports. Which of a pair is the copy is a separate question (below).
- **An undecided pair keeps both pings, labelled `repeat`** (the maintainer, 2026-11-03: an unresolved repeat keeps
  both pings, labelled). It is a label, not a removal.

## Tried and dropped

- **The local speed from the legs alone** (`local_track`). Where copies interleave, every leg is long, so the median
  it judges by is long too. It catches too few faults at 10 s. Recorded speed is the better reference.
- **Tuning the thresholds** (`scripts/tune_local.R`, fitted on half the vessels, judged on the other half). The
  thresholds hardly change the fishing cost, and the tuned rule lost most out-and-backs. The first guess stays.
- **The two-legs stage alone**, without the forward scan. It saves few fishing pings and loses the runs of bad
  pings.
- **The fit to the neighbours as the copy decider.** On the planted faults it decides well, because their copies sit
  in clean tracks. On the reload it picks the live ping as the copy. There, the live track is itself interleaved
  with other reloaded pings, and the true ping often fits worse. Run by run, it still decided most reload runs wrongly
  when it needed every decisive pair to agree. On one feed it should decide none.
- **A second feed as the witness. Kept in the proposal, but untested.** Another feed that places the vessel at a ping
  decides which ping of a pair is the copy. The reload days hold STK's pings alone (no astd), so it had nothing to
  decide there. On the planted faults the scores hardly moved.
- **A state-space model with turns.** The maintainer asked about treating the pings as state-space, as in the
  search for fishing windows. Such a model expects speed and heading to persist from ping to ping. A fishing vessel
  turns hard when it shoots, hauls and tows in patterns, so the pings that matter most would score as surprises. It
  was set aside without a run. The maintainer chose to leave turns out and judge speed alone, as distance and time
  step.
- **The receipt time as the copy decider.** It would decide the reload's pairs, but there it is also the answer key,
  so it could not be judged on that set. The maintainer declined it, 2026-11-03 ("not the receipt time").

## Proposed, not decided

Step 0 as a cascade by evidence, like every other step of the flow (the maintainer, 2026-11-03: "if we have these
variables then use this, if poorer ..."). Each flag takes the best evidence the ping has and records it as its
basis:

- copies decided by a witness (`witness`), else kept as `repeat` (`none`);
- impossible positions judged against recorded speed (`recorded`), else by the fixed 25 kn rule (`track`);
- a label where nothing can decide.

The design is in plan 062. The maintainer said "not yet" to building it. Plan 062's "To finish" lists what is left:
the cheap checks of its item 1, then its asks 1-4 and the cascade, which are the maintainer's.
