# 206 — The logbook times' app dummies are flagged and set aside, the skipper's rounding is labelled, the Danish seine's window stays one operation

*2026-10-23. The maintainer's answers to TODO 107, asked by Claude (AI) in a status review of the repository, on the
two drafts of 2026-10-21 (`$FISHYDATA/archive/2026-10-time-offsets/` and `../2026-10-time-offsets-towed/`, each with
its README, scripts and tables). The numbers are the drafts', measured by Claude on the build of 2026-10-21 and not
yet checked by a person. Nothing is built.*

## Chosen

**App dummies, set aside with the original kept** (a declared correction beside `logbook_set_placeholder.yml`, or an
extension of it; every value it replaces stays in its own column, AGENTS.md's rule):
- **Static set times next to the placeholder:** 269, 271 and 1,711 min (3,023 stations: 16-20 % in port, 54-60 %
  steaming at the set) are the placeholder a second to a minute off. The rule takes ±1 min around 270 and 1,710, once
  the real soaks that close are counted from the neighbouring minutes.
- **A constant offset on most of a vessel-year** (three gillnet vessels at 210 min, one at 60) is the app's signature:
  set NA and flagged, as the placeholder is.
- **Hauls and tows of 0-4 minutes** (6,156 static hauls; 10,126 electronic tows, 6,467 of them Danish seine): start and
  end pressed together by the app. Flagged, and the station is treated as date-only for its window (the day, basis
  `synthesised`), not given a 1-4 min window that holds a fix only a third of the time.
- **Other electronic towed dummies, all Trackwell's:** starts copied from the trip's departure (2,664), fs_afladagbok's
  2022 `TRACKWELL` batch (1,488: a start at 00:00 or the departure, no end), ends at the arrival saved at that moment
  (152). The dummy time is set NA and flagged, and the station falls back to its day window. The 23-hour kelp records
  on three dredges (138) are labelled day records, not tows.

**The skipper's rounding, labelled, not changed:**
- **Static gear's half-hour grid:** a set time the app computed from the haul start less a soak in half hours (about
  32,600 stations) is basis `derived`, the grammar's word for a value computed within the record, with a precision
  modifier (half hour); the 8,477 exactly on the grid the same. Whole-hour haul lengths carry the modifier `rounded`.
  Decision 158's truth set leaves out both.
- **The paper logbook's tow times** (42 % of starts on the hour, lengths in whole or half hours) keep basis `recorded`,
  since the skipper wrote them, with a precision modifier (hour, half hour, 5 min) as `capped` is a modifier; no new
  basis word.

**The Danish seine's window stays the whole operation.** Its recorded start is the setting (45 % of starts at 6 kn or
more, the ropes laid round the ground), and the window keeps set and haul. The trail's `phase` marks setting and
hauling by speed, so either can be taken.

**A bug, not a choice:** adb's trawl `duration_m` (32,329 OTB, 1,367 OTM, 2,174 DRB) is computed from `fishing_start`
and `fishing_end` instead of `tow_start`, which adb leaves empty; fixed with the logbook batch.

The Danish seine's lost `togtimi` (99,028 stations recoverable from the sent record) is plan 037 phase 2's (TODO 115).

## Left

The correction and the modifiers built as a step of the logbook batch, a scratch build first, the windows and the
fishing fixes traced before and after.
