# 297 — Production's speed rule stays for good: plan 069's night again after plan 048, the logbook still on production's side

*2026-11-07. TODO 192 (closed), at the maintainer's word: "Yes, plan the night run", "Delete, then start" and, on the
reading, "Keep production's rule". Run, measured and counted by Claude (AI); no person has checked the scripts or the
counts. The study, its scripts and every table: `$FISHYDATA/archive/2026-11-07-speed-rule-night-2/` (its README).*

## Why

Decision 287 kept production's speed rule (`clean` at 25 kn) after plan 069's first night. Most of the candidate's
losses there came from STK's event rows placed out of port, which the candidate keeps and production's angle test
flags. It parked TODO 192 until plan 048 took those rows out of the track. Plan 048 has now done so (decisions 288-296),
so the night was repeated to see whether the candidate's case had changed.

## What was run

Plan 069's night again, 2026-11-07 21:03-22:57, detached, on a fresh `cp -c` clone of the store as decision 296 left
it, with code 0304e9a and ramb 2026.11.07.1.

- The steps:
  - production's own clean step as a control;
  - the candidate of decisions 282-284 in its place;
  - the 16 targets below it;
  - the comparison, every record in one outcome against the live store;
  - every AIS trip end moved by over 6 h, put against the logbook trip's own date (`12_trip_dates.R`, now at night).
- There was no sweep: its years were measured before plan 048.
- **The checks:**
  - the control was equal to the store's flags in every year;
  - all 611 files written were stamped 0304e9a, with a clean tree;
  - no live file was written by the night.
- The 339 live files written that night were timarit.is pages fetched by another session's study.

## What it found

| | first night (decision 287) | after plan 048 |
|---|---|---|
| pings the candidate flags, production keeps | 701,615 | 553,103 |
| pings production flags, the candidate keeps | 680,276 | 291,808 |
| — STK event rows at 0 kn | 256,959 | 49,953 |
| port calls changed, split or lost | 166,648 | 16,241 |
| voyages changed, split or lost | 131,771 | 51,236 |
| `trip_reconciled` rows changed | 64,997 | 17,530 |
| fishing hours | +0.007 % | −0.013 % |
| trip ends moved by over 6 h (departures; returns) | 7,381; 13,458 | 1,837; 4,148 |

Every moved trip end has a logbook date, and the logbook puts each on one side:

| on whose day the logbook puts it | departures | returns |
|---|---|---|
| production's day | 992 | 2,773 |
| the candidate's day | 350 | 226 |
| both rules' day | 57 | 315 |
| neither, production nearer | 322 | 601 |
| neither, the candidate nearer | 116 | 233 |

Plan 048 removed about seven tenths of the disagreement. Where the two rules still part, the logbook sides with
production: about 3 to 1 on departures and 12 to 1 on returns. That is the same direction as the first night, and
stronger on returns. The moved ends lie mostly in 2007-2011.

## What was chosen

- **Production's speed rule stays**: `curate/ais_ping_clean.R` runs `clean` at 25 kn. Nothing in the pipeline or the
  live store changed.
- **TODO 192 is closed.** The candidate stays in ramb as opt-in methods (decisions 282-284) for other data.

## What it leaves

- **The scratch store**, `/Users/einarhj/stasi/scratch-192-candidate-2/` (about 47 GB of its own): deleted 2026-11-07
  at the maintainer's word ("Yes, delete it"), the disk back to 82 GB free. The study's own files stay.
- **Production's own wrong flags on fast vessels.** On vessels over 25 kn it flags 97,716 pings the candidate keeps;
  in 2024, 10,812 the vessels' own limits keep, all 9 hand-checked good (TODO 192). A flagged ping hands its time on,
  so the effort barely moves; not pursued. Tested on 2024 on 2026-11-08 (`$FISHYDATA/archive/2026-11-08-fast-vessel-ceiling/`,
  by Claude (AI)): production's rule with each fast vessel's own ceiling in place of 25 kn gives back 7,570 pings on
  115 of 133 vessels, 0.8 % of theirs, mostly steaming at 25-30 kn; 1,246 of them with a recorded speed under 15 kn, not
  checked by hand.
- **The trip ends the candidate gets right**, 576 by the logbook's date: production's own wrong ends, not looked at.
- **A hybrid rule**, `clean`'s angle before the vessel's own limits (decision 287): not built.
- **The logbook's date as a witness of the AIS trip ends**: counted twice in studies, and already in the
  pipeline. `trip_reconciled` puts each trip's AIS ends against the logbook's own (`T1_ais`, `T1_own`; `T1_outcome`
  agree, differ or one, within 1 h or on the day), every trip in one outcome per end. This line said "still in no check
  of the pipeline" until 2026-11-08, when Claude (AI) found it built (decisions 173, 174).
