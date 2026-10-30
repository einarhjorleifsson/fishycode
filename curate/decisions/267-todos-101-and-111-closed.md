# 267 — TODOs 101 and 111 closed: built, declined or carried elsewhere

*2026-10-30. At the maintainer's word ("close loose ends, check if TODO's can be reduced"), after decisions 261, 265 and
266. Recorded by Claude (AI) from the decisions and the code, not checked by a person.*

## Closed

**TODO 101, the allocation audit's fixes (decisions 155, 199).** Every fix chosen on 2026-10-23 is now built, declined
or parked elsewhere:
- **built:** stations deleted in the source are left out of the links that read the stations
  (`curate/voyage_gear.R`, `curate/trip_reconciled.R`, `curate/station_window.R` read `eytt_deleted`) and kept in the
  merge; `voyage_gear` is deterministic (the tie-breaks of 7204d9a, checked in decision 265 under TODO 139);
- **declined by decision 261** (the catch on the fixes is the user's; nothing here builds or waits for `ais_catch` or
  the allocation audit, which reads it): the transfer trips' excess as an outcome in `ais_catch`, the catch on stations
  with no window, the two landing-to-voyage rules compared in the audit, and the audit as a generic ramb tool;
- **parked** (plan 054's cut, the maintainer, 2026-10-30): the merge's flag on stations dated outside their trip's days
  (fs_afladagbok 3.0 %, adb 3.6 %), moved to TODO 102, parked with the trips that overlap.

**TODO 111, `docs/output-schema.md`'s column tables.** Its question is answered and done: the tables are retired for
`docs/data-dict.yaml` (decision 247). What it left, the dictionary as a page of the book, is plan 033 step 5's (the
data dictionary among fishyweb's five pages; TODO 94).

## Moved

- **The area rules** that the Nephrops and shrimp study left open (decision 266): what agf's area codes `NE`, `GL`
  and `NA` and LODS's `U` mean, and a record's ICES area from its position by polygon rather than the study's box,
  go to TODO 123 (the landings).
