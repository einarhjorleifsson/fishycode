# 311 — An STK event at a placeholder position gives no presence

*2026-11-09. At the maintainer's word: "Yes, check it" (the check before TODO 182's rebuild) and "Yes, add it".
Measured and written by Claude (AI); no person has checked the counts. Study:
`$FISHYDATA/archive/2026-11-09-event-placeholder-positions/` (its README holds every number).*

## Why

Closing TODO 88 (decision 308) found STK departures at a longitude of 180°. `curate/port_call.R` gives the dwell rules
every good event at its raw position as presence, a ping of the vessel at that place and time
(`rb_create_port_calls(presence = TRUE)`, plan 048 §7.3). A departure's position is never judged, so a placeholder
judged good becomes a ping nowhere.

- **The placeholders**: 1,012 of STK's 8,482,796 events, all departures, with no real place. 874 are out of range
  (521 at longitude −181, 313 at −180, 8 at 628.1, the rest scattered; 174 vessels, 2007-2024) and 138 at 0,0 (24
  vessels, a marker by the shared-position rule). Decision 308's "866 at longitude 180" is corrected there.
- **The judge passes them**: 848 are good (157 vessels); 145 are `repeat`, 13 `track`, 2 `unit`, 1 `flicker`, and 3 are
  not judged.
- **They cut stays in two.** Production's `port_call.R` was run twice on a scratch store: A as it was (equal to the
  live store in every column), B with the placeholders given no position.
  - No event changes its judgement.
  - 786 port calls change on 141 vessels: 491 are in A only and 295 in B only, 196 fewer in B.
  - Every call A alone has is covered by B's calls for 90 % or more of its span, so B loses no time in port and adds
    about 21,800 hours.
  - The likely mechanism, read from ramb's code and not traced case by case: a good placeholder departure that the
    track contradicts sits among the in-port pings as a ping at sea. The pair guard measures only pings strictly
    before a pair's departure, so the departure's own position never breaks its own pair.
- **The records**: one of the 786 changed calls holds a fishing day inside, against 0.89 % of every event-pair call.

## What was chosen

`curate/port_call.R`: an event at a placeholder position (a longitude beyond 180, a latitude beyond 90, or 0,0) goes to
the event judge with no position and gives no presence, as run B tested; the event still counts in its pair. The
script was unchanged since the tested commit (9851eeb). `port_call` is in the rebuild of decision 310 and TODO 182, so
the rule costs no build of its own.

## What it leaves

- **Far departures**: 25,157 departures lie over 1,000 km from their port and 100,785 at 100-1,000 km. A departure is
  often sent after the vessel has left, and its position is never judged. Whether those in-range positions agree with
  the track is not measured.
- **The placeholders' cause** at the source is not traced.
