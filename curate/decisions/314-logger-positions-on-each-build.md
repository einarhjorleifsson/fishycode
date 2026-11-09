# 314 — TODO 98 and 99 closed: the GPS logger positioned on each build's cleaned track, on one voyage, within 60 min

*2026-11-09. TODO 98 and 99, at the maintainer's word: the bracket measured first ("I will go with your
recommendation"), then "Yes, no position"; `sensor_gps` read as retired "for the time being". Built and tested by
Claude (AI); no person has checked it. Study: `$FISHYDATA/archive/2026-11-09-logger-brackets/`.*

## Why

Decision 196 put the afli GPS logger's positions on each build's cleaned track with a gap limit, so that the logger
never again follows a superseded track; decision 251 measured the limit, 60 min, and left whether a bracket may cross
from one voyage to another. The frozen `sensor_gps` held positions interpolated once on the track of 2026-10-09 with no
limit: 861 fixes lay over 5 km off today's track (TODO 98), and the whack test does not test interpolated positions
(TODO 99).

## What was measured

On decision 251's table of every logger fix, with its witness (the logger's own reading, or its longitude's sign
flipped): of the fixes with a bracket of 60 min or less, those whose two AIS pings are not on one voyage (84,449) lie
over 5 km from the reading 4.53 % (under 30 min) and 11.32 % (30-60 min) of the time, against 0.39 % and 0.97 % for those
on one voyage. Their median is about the same (0.76 against 0.71 km).

## What was chosen

`curate/ais_voyage.R`, once the voyages are cut: each logger fix (provider `gps`) takes the position on the line between
the recorded pings either side on its own voyage, in proportion to time (`ramb::rb_interpolate_track(by = c("vid",
"voyage_id"))`), where they are at most 60 min apart (`LOGGER_GAP_S`, from the bracket's `dt_sec`). Otherwise it gets no
position (`pos_basis` "none"), its time, speed and heading kept. No ramb change: the function already returns the
bracket's length and bounds it by group.

Tested in the script's test mode on a scratch store, vids 2917, 2173 and 2411: every ping kept; 268,991 logger fixes
positioned and 5,663 without; the positioned ones a median 0-11 m from their `sensor_gps` positions, and 1,269 over 5 km
(vid 2173's and 2411's old off-track fixes, now on the track). Built with decision 310's rebuild.

- **TODO 98's check is met by construction:** no logger fix lies more than 5 km from a recorded ping at the same moment,
  since each lies on the line between two of them.
- **So is TODO 99's for the logger,** the only source of interpolated positions in the track.

## What it leaves

- `sensor_gps` stays, for the time being, the source of the logger's fixes, time, speed and heading (a frozen one-time
  fix, decision 075); its positions are no longer used. Reading the logger from the dump instead, which retires it, is
  not done.
- Between the AIS track's stages before `ais_voyage` (the tag pass, the clean, the port calls), a logger fix still carries
  its `sensor_gps` position; the clean gives it the invalid test only, and the port calls use recorded positions only.
- A generic ramb flag for an interpolated position away from the recorded track (TODO 99's proposal) is not built: the
  logger was its only case.
- vid 2411's 2020-07-23 (the logger 277 km from the track at 9 min brackets) is still listed for a look at the key
  (decision 251).
