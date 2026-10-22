# 164 — The STK trail's time and identity: lag explains no whack, the false whacks are mostly a cross-feed offset, and `I`/`U` rows are events

*2026-10-22. Found, not decided. A read-only study by Claude (AI) in a side session, at the maintainer's request; the
counts are Claude's and have not been checked by a person. Study, scripts, logs and 25 result tables:
`$FISHYDATA/archive/2026-10-stk-trail-order/` (§1 is the result in one page, §12 the decisions). The choices it
leaves go to TODO 88 (the whack) and TODO 117 (what the flow takes from STK).*

- **Time.** 98.72 % of the 303.8 M rows are within an hour of receipt. The 3,896,231 late ones are a few structures,
  not scattered errors: 18 mass-delivery days (3,745,293 pings; the reload of 2026-10-12 to -14 holds 927,058, 1-5 days
  late), a re-import in 2012, units whose date is stuck (2016: 23,939 pings, none with a vid), and copies. The
  trigger's 22-26 hour band is empty in every year (decision 163).
- **Order and identity.** Arrival order is receipt order: `trailid` and `recdate` disagree on 20 rows; `moddate`
  equals `recdate` on all but 29,850, so it is no second clock. 7.41 M rows are later exact copies, and 3.12 M a unit
  at one instant in two places. `trail_multi_rectime_v` is 99.6 % exact copies.
- **Lag explains no whack.** Of the late pings the flow kept in 2008, 2016 and 2025, 8, 0 and 0 misfit the track. Lag
  is a label, never a flag. 2026 was not tested.
- **The whacks against an independent receiver** (ASTD/ASTDB within 60 s, 2013-2026). Of 337,375 removed pings with a
  witness, 254,361 (75 %) are supported (`forward` 99.7 %, `vmask` 54 %); of 20.0 M kept, 2,780 are contradicted. 63 %
  of the supported removals have only cross-feed legs within 0.3 nm: a feed-aware distance floor would keep every
  confirmed catch and 36.5 % of the false removals. That is scored on counts; a prototype re-run in ramb is in hand
  (`~/R/Pakkar/ramb_wt_whack`, branch `whack-feed-aware-evidence`).
- **`I`/`U` rows are events, not fixes.** 66.8 % of the contradicted pings are `I`/`U`-flagged; 115 positions each used
  by 10 or more units hold 482,668 `U` pings, regional port markers within 2 km of the polygon for 94 %; `I` jumps lie
  inside their own harbour with at-sea neighbours the witness contradicts. Against 154,146 labelled landings the events
  of 2007-2011 are as clean as 2017-2020 (74-80 % against 79-81 % clean pairs), 2012-2016 is the bad stretch (52-57 %),
  and the junk is per unit. Decision 059's cut at 2017 and decision 075's dropped jump test were measured on 2017 on.
- **Before 2007** `tilk_stk` carries the vessel and alone supports 57-77 thousand port stays a year (2004-2007).
- **The cleaning account**, 293,246,639 pings in one cell each: 82,995,441 from units that are not vessels, 27,864,251
  from vessel units with no vid (decision 161), 1,357,460 whacked, 180,073,757 (61.4 %) clean and consistent, the
  rest jumps kept or contradicted.
- **The dumper.** The overview row of `stk.trail` says 20,681,877 rows (the 2026 partition) of 303,795,653, and
  `afli.sjalfvirkir_maelar`'s is stale too; the code was fixed in 9ef7596, the rows were never recomputed (TODO 110).
