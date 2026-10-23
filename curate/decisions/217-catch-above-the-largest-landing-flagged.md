# 217 — On a trip with no linked landing, catch above the largest landing of its species or of its vessel is flagged

*2026-10-23. The maintainer chose the witnesses ("both witnesses"); the measurement, the code and every number below
are by Claude (AI), not checked by a person. A second rule of decision 216's correction; plan 038 §8 step 1c.*

## Why a second rule

Decision 216 judges a trip's logged catch against the landing it is linked to. 684,246 (trip, species) pairs, 4,861
kt, belong to trips with no linked landing, most of them logged before 2007. Decision 214's four remaining STOKKUR
entry errors are among them: three stations of one trip, 11,111 t of species 29, and 333 t on a fourth. Without a
landing, the witness has to come from the landings as a whole.

## Measured

`$FISHYDATA/archive/2026-10-todo126-ais-check/17*.R`. Every pair with no linked landing in one outcome, by source and
period, against two witnesses, with the margin of decision 216 (more than 10 times the witness and at least 1 t more):

- **The vessel's own largest landing, all species, any year and source.** As a witness alone it is weak. 90,305
  pairs (582 kt) are of vessels with no landing on record, among them all four STOKKUR cases. Of the 479 pairs it
  flags, 461 rest on 12 vessels whose largest landing weighs under 100 kg, and 344 on vessels with fewer than 5
  landing records. Where 50 landing records or more stand behind it and it weighs over 0, it flags 10 pairs
  (10.4 kt), among them 8,000 t of cod on a trip by a vessel whose largest landing in 2,557 is 24.8 t.
- **The largest landing of the species, by any vessel, any year and source.** It flags 18 pairs (11.9 kt), all four
  STOKKUR cases among them: no landing has held more than 211 kg of species 29. It is inflated by carriers (2,200 t of
  cod in one landing), so it errs toward flagging too little, never too much. 7,521 pairs (144 kt) are of species
  no landing holds, 7,423 of them code 999; those it cannot judge.
- The two witnesses flag different pairs: none is flagged by both.

## Chosen

Rule 2, `largest_landing_exceeded`: on a trip with no linked landing, a (trip, species) is flagged where its logged
kilograms are more than 10 times either witness and at least 1,000 kg more. The species' largest landing is always a
witness where the species has been landed. The vessel's is a witness only where 50 landing records or more stand
behind it and it weighs over 0. The flag is written as rule 1's is: every station of the trip with the species, in
`curated/logbook/catch_flag.parquet`, with `species_kg_largest`, `vessel_kg_largest` and `witness`. It travels to the
fixes in `kg_flagged`, and nothing is corrected.

Four of the vessel-witness pairs are herring logged before 2006. They may be catch pumped onto another vessel
(plan 042, parked). The flag marks them and moves nothing, so plan 042 can still claim them.

## Checked on a scratch store

The code ran on the scratch store of decision 216, with the real store's inputs linked into it; nothing under the
real `$FISHYDATA` was written. `$FISHYDATA/archive/2026-10-todo126-ais-check/18*.R`:

- Rule 1's 87,838 rows are identical to the built table; rule 2 adds 275 (station, species) rows on 28 pairs, 22.3 kt
  (species witness 230 rows, 11.9 kt; vessel witness 45 rows, 10.4 kt). (station, species) stays unique.
- Every row meets its rule's assert in `docs/data-dict.yaml`.
- The known cases: STOKKUR's stations 45559-45561 and 59912 (species 29), and station 198973 (7,999,999 kg of cod),
  are flagged. 59912's 333,333 kg of species 288 is not: no landing has held 288.
- `ais_catch` for the six years where rule 2's catch has a window from 2007 on (2010, 2019, 2021, 2022, 2023, 2025):
  every row and kilogram the same as the built catch, and `kg_flagged` grown by rule 2's kilograms of the year, under
  both approaches: 2.2 t, 21.9 t, 11,666.7 t, 165.0 t, 8,000 t and 575.7 t. Kg in equals kg out for both columns in
  all 24 vessel-year groups. Rule 2's other 1,833.5 t sit on stations of 1969-2003, before the catch begins.

## Built

With the complete rebuild of decision 218.
