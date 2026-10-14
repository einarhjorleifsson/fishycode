# 087 — afli keeps the tow starts before 01:00

*2026-10-14. Found and fixed by Claude (AI-assisted) while checking the event times for TODO 54; fixed on the
maintainer's go, in the trail rebuild of decision 089.*

## What was wrong

`sources/afli/convert.R` reads a tow's start (`ibotni` in `toga`, and the seine's in `hringn`) as hh:mm, and kept it
only from 01:00 (`hhmm >= 100`). Every start between 00:00 and 00:59 became NA. Those tows lost their window, and
fell back to a whole-day window. The rule came in with the migration of 2026-09-20 (bde740b), and neither archived
repo explains it.

The hour is an ordinary one in the raw data:

| hour of `ibotni` | 23 | 0 | 1 | 2 |
|---|---|---|---|---|
| tow starts | 158,605 | 185,943 | 160,769 | 156,077 |
| on the whole hour | 28.9 % | 24.2 % | 36.6 % | 37.4 % |

00:00 itself (45,048) is not elevated: the share at the whole hour is lower at 0 than at the hours around it.

## What was chosen

Keep every hh:mm from 00:00 to 23:59. Hours of 24 or more, and minutes of 60 or more, stay NA as before.

## Measured before the rebuild

`convert.R` was run without its writes and compared with `staging/afli/fishing_sample`:
- t2 restored on 189,373 stations, and t3 on 175,195 (start plus towing time).
- No time lost or changed.
- `.checks` changed on 209,262 stations:
  - of the newly timed tows, 149,219 are "ok", 14,178 have no end, and 25,976 overlap a neighbour;
  - 19,283 tows that were "ok" now overlap one of the restored starts.

  Since decision 083 an overlap is a flag, and no time is dropped for it.
