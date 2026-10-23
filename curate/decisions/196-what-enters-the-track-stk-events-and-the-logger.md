# 196 — What enters the track: STK's I/U rows are events, receipt time goes to a side table, events are screened per unit, and the GPS logger is re-interpolated in the flow with a gap limit

*2026-10-23. The maintainer's answers to TODO 117 (the STK trail-order study's §12, decisions 1, 2, 4-7, 9 and 10, and
its finding that STK's I/U rows are events) and TODO 98 (the afli GPS logger in the track), asked by Claude (AI) in a
status review of the repository. The evidence is the study's (`$FISHYDATA/archive/2026-10-stk-trail-order/README.md`,
decision 164) and TODO 98's (`$FISHYDATA/archive/2026-10-todo98/`), measured by Claude and not yet checked by a person.
Nothing is built: each choice is a step of its own, a scratch build and its account first.*

## STK (TODO 117)

- **I/U rows are events, not fixes.** In the STK adapter: each event keeps its time and harbour, and no `U` position, nor any
  position at a marker many units share (115 positions, 482,668 `U` pings), is fed to the whack filter or the track as
  a fix. An `I` position counts only inside its own port polygon. (66.8 % of the pings ASTD contradicts are I/U rows.)
- **Receipt time in a side table** (decisions 1, 2): `staging/ais/stk_receipt.parquet`, one row per ping of a vid
  (trail id, receipt time, lag class, mass day, stuck-date unit, identity and unit class, the ground-truth class and the
  ASTD harbour tag where a witness exists), joined by (vid, time) when needed. The lag is a label, never a flag. No
  column is carried through the AIS layers and no chain is rebuilt for it.
- **Events screened per unit** (decision 4): the year cut `EVENT_FROM` 2017 (decision 059) goes. A unit's events are used
  unless the unit is a burst or jumper unit (§4.6), so the clean events of 2004-2016 count too.
- **Port calls before mid-2007 from events** (decision 5): 2004 to mid-2007 from `tilk_stk`'s events alone, basis
  `reconstructed`, cleaned by the stream rules, the phone line a timing check for the line vessels. They are witnesses of
  a trip's departure and return where the trail has no track.
- **Dwell in port** (decision 6): the commercial AIS in port where it exists (6-7 pings an hour where STK is silent), else
  STK's I → U pair once the unit passes the screen; each with its basis.
- **Unlinked and non-vessel units** (decision 7): each ping's unit class goes into `stk_receipt`; linking the vessel units
  with no vid stays with TODO 116 and plan 021.
- **Oracle reads and questions** (decisions 9, 10): the three read-only reads (the trail's sequence, the trigger and
  sequence creation dates, a count of `stk.trail`) go into the next dump run; the maintainer takes the questions to STK.

## The GPS logger (TODO 98)

The maintainer would not leave the logger out: its own speed and heading are the high-resolution record of what a vessel
did (the time-speed profile). Its positions were never its own, since they are the AIS track interpolated
(decision 075). So:
- **Redone with a gap limit, as a flow step on every build.** The logger's positions are interpolated on each build's
  cleaned track, after the whack filter, and its fixes join the trail there. A fix across a silence longer than the
  limit keeps its time, speed and heading and gets no position (basis `none`). The frozen one-time fix `sensor_gps`
  retires, so the logger never again follows a superseded track or key (decision 075's freeze of it is reversed when
  this is built).
- **The limit is measured first:** fixes kept and fixes more than 5 km off the recorded track at 15, 30 and 60 min; the
  maintainer picks from the numbers. Today's 861 off-track fixes all span gaps over an hour.

## What this supersedes, once built

Decision 059's `EVENT_FROM` 2017 and decision 075's frozen `sensor_gps`. Their records are amended when the steps are
built, not now.
