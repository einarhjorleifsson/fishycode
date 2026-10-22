# 163 — The line-incentive check links landings to STK's port events by a date-and-port rule: a witness, not a clock

*2026-10-21. A read-only study by Claude (AI) in a side session, at the maintainer's request; the counts are Claude's
and have not been checked by a person. Study, scripts and logs: `$FISHYDATA/archive/2026-10-ivln/`.*

- **What the check holds.** `kvoti.ivln_tilkynning_londun` (172,451 landings, 2004-2020; already dumped) links a
  line vessel's landing to the departure and arrival that qualified it for the line incentive. All 154,146 STK pairs
  are `stk.tilk_stk.trailid`, and all 123,165 phone pairs (to 2014) are `simalinu.tilk_linu_sokn.id` (`stk.tilk_vss`
  was the wrong table; simalinu was dumped for this, decision 162).
- **How it picks.** The quota system's own rule by date and port: where a day has several candidate arrivals (50,354
  landings) it takes the last of the day on 40,640. So the link says which voyage the landing belongs to, not when the
  vessel arrived. `kvotix.log_ivln_tilkynning_londun` (1,695,056 rows) is the history of its recomputation, with
  nothing of its own.
- **Against fishycode's chain, from 2007-06** (110,356 landings): the voyage arrives within 30 minutes on 91,757; at
  another time on 9,716; no logbook trip on 7,446; a trip with no voyage on 1,437. On 345 the arrival's second holds
  only another vessel's ping. These are unexplained, and go to plan 023 §6 as a fifth trip witness (TODO 74).
- **The writer** is most likely the PL/SQL package `KVOTI.LINU_IVILNUN`, which the dump account cannot read (it has
  `SELECT ANY TABLE`, not the catalogue role). `get_source_ivln.sql` (21 read-only statements) needs KVOTI's owner or
  a DBA.
- **The trigger** `STK.TRAIL_BEF_INS_TRG` numbers each row from a sequence, sets `moddate`, and moves `posdate` by a
  day when it lies 22-26 hours from `recdate` (its comment: the telecom server garbled the date twice a day). Of the
  check's STK ids, 184, all of 2004, are about a day off.
