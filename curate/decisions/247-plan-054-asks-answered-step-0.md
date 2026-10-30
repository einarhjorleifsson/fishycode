# 247 — Plan 054's asks answered, and its step 0: TODOs 100 and 107 closed, plan 020 built as plan 052, towed `t3` the start of hauling, the logbook column tables retired

*2026-10-30. The maintainer answered plan 054's asks a-r, which Claude (AI) put with AskUserQuestion. The maintainer
amended ask h's answer the same day, and added §7's items ("fold them in"). Step 0 of the plan, the records, was done by Claude
the same day and has not been checked by a person. Nothing is built. Plan 054; TODO 168.*

## Chosen

Each ask was taken as recommended, with three exceptions:
- **h d was amended.** The recommendation misread its quote, which was about the logger's depth readings becoming AIS
  columns, not about its fixes. The logger stays in the AIS track, as decision 196 has it. Its readings go into
  `vessel_sensor`, which is long, like `sensor_summary`, and has no positions (plan 052 §5, amended).
- **m b is not known.** Which cruise the A to J protocol comes from, and whether its records exist, stays open in
  TODO 146.
- **q had no recommendation.** Norway's open ERS files are to be named and sized first, and downloaded only on the
  maintainer's yes.

In short (plan 054 §5 has each answer):
- **a:** each change on a scratch store of its own, then all together, then one live rebuild (A, with B if it is
  ready).
- **b:** plan 027's four asks: a flow table `trip_landing`; any port within 7 days, until the vessel next fishes;
  in-port landings that the logbook lacks are joined; the voyage rule for `lid_map`'s misses becomes a TODO of its own.
- **c:** the Directorate's trace id is a witness on every link. The maintainer dumps `ops$rafn.rekjanleikanumer`
  before B.
- **d:** plan 051's table and TODO 167's source are built now, with the lumpfish rows provisional.
- **e:** one TODO for every outside wait, TODO 169.
- **f:** TODO 102's overlaps are treated by class, as proposed. A class over 1 % of trips comes back to the maintainer.
- **g:** 126 and 138 are unparked, to ride A.
- **i:** `g_*` is kept until TODO 140.
- **j:** the tour app closes TODO 141, and the rest of the gap is declared.
- **k:** Claude drafts the tour app's port override, and the maintainer reviews it before A.
- **l:** the column tables are retired, and the dictionary becomes a page of the book.
- **m a:** towed `t3` is the start of hauling.
- **n:** TODO 70's query at the maintainer's next Oracle sitting.
- **o:** the riders: decision 198's drift rule; the tie-breaks of TODO 139 (`voyage_gear` by decision 199,
  `trip_reconciled`'s STK witness by the later return, then the lower voyage id); the nets' 0.2 kn floor.
- **p:** the catch halves of 81 and 101 are checked on the scratch store only.
- **r:** 131, 135 and 136 stay parked.

§7 added 24, 34, 95, 98, 110, 139, 142 and 151 for little cost, and gathered every Oracle read into one sitting.

## Done in step 0

- **TODO 100 closed.** The sensor readings are a product:
  - the per-haul readings are `sensor_summary` (decision 244), with every unit in the dump overlay (decision 245);
  - the logger's stream is `vessel_sensor` (TODO 163), built in rebuild A;
  - which column measures what is in plan 052 §3 and the overlay: `botndypi` is the water depth under the vessel,
    `hofudlinudypi` the headline depth, and `botnhiti` most likely the hull's sea temperature (place `unknown` until
    checked).

  The logger cannot time a haul beyond its speed, as TODO 100 measured.
- **TODO 107 closed.** Decision 206 decided every draft, and plan 053's ask d reversed its towed dummies: the tow and
  seine times are kept (T11), and their build is plan 053's (TODO 165).

  Decision 206 also called adb's empty `duration_m` a bug to fix. There is nothing to fix:
  - since decision 240, `duration_m` is NA by design wherever a record's times are read (`.duration_source` `times`,
    `R/logbook_effort.R`);
  - adb's 36,689 towed samples all carry `t2` and `t3` (plan 054 §1).

  So their effort loses nothing.
- **Plan 020 executed**, built as plan 052 (decisions 244, 245). Its gear detail is `gear_part` and `rigging_part`,
  and its environment is `sensor_summary`, with v0's `environment` a pivot of it. Plan 019's half of TODO 73 stays,
  for plan 054 step 2e.
- **Plan 036's header** now says its asks were answered by decision 208, not "seven asks open".
- **TODO 111, in part.**
  - `docs/output-schema.md`'s four column tables are deleted. The page points to `docs/data-dict.yaml`.
  - What only the page held moved into the dictionary: `gear_code`, the only column of the four files it lacked, and
    notes on `date`, `gid`, `gid_old` and `effort_count_basis`.
  - Left: the dictionary as a page of the book (`data-dict render`), with the book's next render (TODO 94).
- **TODO 146, in part.** `docs/grammar.qmd` now says a towed `t3` is the start of hauling (E), as Hafriti and the
  e-logbook record it, with off the bottom (F) between `t3` and `t4`. The table of the four events, the A to J table and
  the paragraph that called `t3` open all follow. The data do not change, because a recorded `t3` already was the start
  of hauling. Left: ask m b.
- **TODO 70** waits for the query at the next Oracle sitting.
- **TODO 169** holds every outside wait. TODOs 103, 141, 156, 157 and 165 point to it.

## Left

Plan 054's step 0 holds one more item, TODO 110's `--resume` fix, a code change with its own test. Then come step 1's
read-only studies, step 2's changes on scratch stores, and rebuild A, which waits for the maintainer's go.
