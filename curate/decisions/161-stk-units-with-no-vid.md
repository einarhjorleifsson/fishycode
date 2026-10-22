# 161 — STK units with no vid: what names them, and the order in which they can get one

*2026-10-22. A read-only study by Claude (AI) in a side session, at the maintainer's request; every count is
Claude's and has not been reviewed by a person. Study, scripts and logs: `$FISHYDATA/archive/2026-10-stk-unlinked-units/`
(its README holds the tables and the options D1-D10). Nothing in the key, the crosswalk or the ledger was built or
changed.*

## Found

- **The set.** The STK key's units with pings and no vid: 14,709 (13,494 of class `vessel`, 1,215 `unknown`),
  27,864,251 pings. Every unit and every ping is in one outcome (O1-O8) and one link class (L1-L9), the undecidable
  included. The 14,036 mobile ids the key never saw are outside it.
- **The identity is the global id**, not the local id (a placeholder in 97.5 % of units): a call sign in 6,347 units
  (82.1 % of the pings), a ship MMSI in 6,982 (7.1 %). They are foreign, mostly Faroese and other Danish-kingdom
  vessels (1,022 units, 13.3 M pings); 10 units carry a TF call sign and 91 an Icelandic MMSI.
- **What names them**, first match in a fixed order: an Icelandic vid 109 units (4.0 % of the pings), a foreign
  register 1,896 (45.2 %; Faroese call signs alone 649 units, 10.8 M pings), an AIS feed's identity only 5,483, STK's
  own mapping 25, a register number only 194, no registry we hold 6,681 (10.2 M), no usable identifier 309 (2.4 M, of
  which mobile id 133897 alone 1.97 M).
- **A match is an exact string, with no witness.** No co-location test was run; no unit is shown to be the hull it
  names. The Faroese register is one undated snapshot whose call signs are reused (decision 041); for 220 units its
  window does not meet the pings. Ambiguity is recorded, not resolved: 283 units name two or more hulls, and 42 call
  signs (1.09 M pings) are each held by 2-3 foreign landing vids (3700-4999) over the same days.
- **The key is consistent.** Every unit naming an Icelandic vid is left unlinked by the key's own rules, but 13 whose
  MMSI only `vessel_identity` misses. 9 segments labelled `continuity` have no vid, and the segment stage dropped
  mids 106118 and 153090.

## Not yet ready for the vessel list

- **No route from an STK unit to a hull.** `vessel_ais_link` carries the frozen key, these units are `unkeyed`, so
  `allocate_vids()` cannot number them. They can take only a vid the MMSI side has numbered, linked at a `once` redo
  by decision (plan 021 step 7, TODO 25), and the maintainer's order is not before the foreign hulls have vids
  (decision 128, plan 022 §7 ask 3).
- **The ledger is empty.** The first allocation (TODO 65) has not run. Once it has, the hulls of 6,360 of these units
  (6,048 hulls, 11.65 M pings) exist with vids, because the crosswalk already resolves their MMSI or carries their
  register hull by another MMSI; their units link only at the redo.
- **The study is not a pipeline product**: archive scripts on a scratch DuckDB, not stamped, its hull keys not the
  crosswalk's, and its foreign check read a candidate file of 2026-09-27 built before GFW v3 and the key redo.

## The order

1. The first allocation (TODO 65), the maintainer's go.
2. The classification as a `once` check, on the crosswalk's keys and the ledger, the never-keyed mids included.
3. Claude drafts the review lists (D2 call-sign collisions, D3 a second transmitter per hull, D4 STK's own mapping,
   D7 register numbers only, D10 mid 133897); the maintainer confirms them into `overrides/`.
4. A redo by decision with two rules: a foreign MMSI as the key's `NA_mmsi`, and a call sign through a register only
   with co-location against the register MMSI's track; D5 (the 13) and D6 (560 units that are not vessels, an entity
   class with no vid) at the same redo.
5. A call-sign hull key (Norway, call-sign-only Faroese and EU hulls; 542 units) needs a plan amendment: plan 021 §4
   works from MMSIs only.

Without a vid, with a reason, is a valid outcome: the 6,802 units no registry or identifier names and the 560 that
are not vessels. TODO 116 carries the rest.
