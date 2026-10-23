# 197 — Port calls by a time budget instead of the frozen departure radius, records as evidence on four conditions, a logbook time at sea cuts a call only with its trip's own landing

*2026-10-23. The maintainer's answers to plan 031's asks i-k and to the question the audit of 2026-10-23 raised about
the frozen per-port departure radius (decisions 060, 075), asked by Claude (AI) in a status review of the repository.
The numbers are plan 031's (§3.6, §3.10, §3.11), measured by Claude and not yet checked by a person. Nothing is built.*

## Answers

- **The departure radius retires for the time budget.** Plan 031 §3.6 found the frozen radius (`port_radius`, a one-time
  fix since decision 075) the clear cause of missed port calls: 12,295 calls missed, 79 % confirmed by a record. Step 3's
  time budget, in ramb at each vessel's own steaming speed with 6 kn as the fallback (ask b), accepts 98 % of them and cuts
  the voyages holding several logbook trips by 63 % in 2010 and 24 % in 2018 (§3.10). It is applied to Iceland as plan
  031's step 7 **with the AIS batch**: after the STK key redo (TODO 25) and the STK-event changes (decision 196), in the
  same AIS rebuild, on the maintainer's go. `port_radius` then retires, and decisions 060 and 075 are amended.
- **i. A logbook time at sea cuts a port call only with the cut trip's own landing:** the trip's landing in `lid_map`,
  dated on or after the station's day and two days or more after the call began (a landing weighed the day after
  arrival belongs to the arriving voyage). 798 cuts on the measure of 2026-10-20, to be re-measured on the corrected set
  times (decision 158) and the time budget. Otherwise such stations are listed in the check.
- **j. The allocation audit judges a static-gear station by all its times**, after TODO 103's correction: all of them
  in a port call, in a port call; some, the times disagree (a record error, not an allocation error); none, at sea.
- **k. Records as evidence go into ramb**, `rb_create_port_calls(records = )`, each call with its `basis` (`landing`,
  `logbook`) and the unplaced records returned for the check, on four conditions: the calls placed with the time budget
  and §3.11 re-measured with it; the records one generic table (vessel, date or time, port, kind); not applied to
  Iceland before the many-to-many trip link (ask f; decision 193's spanning trips are its first piece); pieces under 10
  pings kept (§4.7).

## Left

Every ask of plan 031 is answered. Step 4 into ramb and its re-measure, the gear set (step 5), the simulated scenarios
(step 6), then step 7 with the AIS batch. Still open from step 3: ramb's defaults against the plan's choices, a short
voyage by time rather than pings, the weak `gap_budget`, and the gap rules for a feed silent in port (TODO 89).
