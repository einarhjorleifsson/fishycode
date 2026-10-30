# 260 — Plan 053 executed: the e-logbook's app profile coded and traced; its build rides plan 054's rebuild A

*2026-10-30. Closes TODO 165, at the maintainer's word ("can we close 053 properly"). Recorded by Claude (AI). The work
was done in side sessions on 2026-10-29 and 30, each piece traced on a scratch store and recorded in the decisions
below. Nothing is built on the live store.*

## What plan 053 set out to do, and where each piece is

Plan 053: one reviewed app profile (`curate/corrections/logbook_app_profile.yml`, 45 rows plus decision 249's) that
`curate/` reads by rule; every value kept with per-field flags, which the windows leave out; a check that lists a new
app or a moved share; the app names out of the adapters' code. Its steps:

| step | what | where |
|---|---|---|
| 1 | the measurement | the plan, §1-§3 (2026-10-29) |
| 2 | the app on every station | decision 253 |
| 3 | the rows, reviewed by the maintainer | the profile; asks a-e and h answered |
| 4 | the check | decision 256 |
| 5, 6 | the flags, and the windows that read them | decision 255 |
| 7 | one position decoder; short longitudes value by value | decision 258, amending 211 |
| 8 | depth by app | decision 259 |
| 9 | the combined scratch build, then the live build | plan 054's combined build and rebuild A (TODO 168) |

The merge these run in was made lean on the way (decision 254).

Asks f and g, the live feed and Trackwell's own haul file, wait for outside contact (TODO 169).

## Closed

- **TODO 165's check:**
  - the asks are answered (f and g moved to TODO 169);
  - the profile, the flags and the check are coded, and every station is in one outcome on scratch;
  - the windows are traced before and after;
  - the work is recorded.
- **The live build is plan 054's**, with the rest of its rebuild A, so TODO 165 is deleted and TODO 168 carries the
  build.
- **TODO 164** (folded in earlier) and TODO 107's built items close with it.

## Left, in TODO 170

The small pieces the steps named and did not build:
- P8's 8 merged stations as a frozen list;
- a station-level `position_uncertain` flag (the staged form says it for now);
- `z_unit` "uncertain" for the vessels D2 and D3 note (Taktikal 37, Reiknistofa 34);
- 21 fs stations of pattern 5/4 for a person to judge;
- I4 by adb's apps once rebuild A carries adb's `source`;
- decision 255's open point for the maintainer: 1,767 pressed records start at the trip's departure and 821 at its
  landing.

The data dictionary and v0 take the new columns with rebuild A.
