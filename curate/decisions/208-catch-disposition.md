# 208 — The catch's disposition: five values with agf's code kept, the 159 landing kept apart and joined through trip_landing, carried to the trip and not to the fixes

*2026-10-23. The maintainer's answers to plan 036's asks (TODO 112), asked by Claude (AI) in a status review of the
repository. The plan's numbers are Claude's of 2026-10-21 (`$FISHYDATA/archive/2026-10-landing-disposition/`), not
yet checked by a person. Nothing is built.*

## Chosen

- **a. Five values:** `home`, `export`, `abroad`, `export_or_abroad`, `transfer`/`unknown` on the landings' catch rows,
  with a basis (`recorded` where agf's `afdrif` says it; `derived` from LODS's code 159 or the port code's class), and
  agf's `afdrif` kept raw beside it.
- **b and c. The landing at 159 stays apart:** its own landing at 159 with its origin port (`hid_origin`, carried
  since decision 180), so the keys stay and `lid_map` is untouched. It joins the trip that claims a landing of the same
  vessel at its origin port on the same day or the day before, through plan 027's `trip_landing` in plan 038's step
  3, basis `export`.
- **e. A class for every port code that is not a harbour**, in a small reviewed table beside
  `reference/ports/port_code.R`: 159 `disposition`; the country codes, 196 and 198 `abroad`; 155, 300-302 `transfer`;
  150, 197, 900, 999 `placeholder`. Codes 41, 71, 197 and 200 ("Gjögur") are looked up in `kvoti.stadur` and
  `ask.londunarstadir`, and their landings counted, before they are classed. 159 never gets a pid.
- **f. The disposition stops at the trip.** It is a property of the landing and the trip, not of where the fish was
  caught; `ais_catch` gets no extra rows, and an analyst joins it to the fixes by trip.

## Answered elsewhere

- **d. The export weight to 2013-08:** the container tables' sold weight, LODS's K + A rows the witness (plan 039 ask
  d, decision 192).
- **g. LODS's origin port:** read from LODS's table since decisions 169 and 180 (`hid_origin` on the landings).

## Left (TODO 112)

Built with plan 038's step 3 and plan 039: the vocabulary and the classes in preprocessing, the join through
`trip_landing`, the trip's disposition; landed kilograms unchanged and the trips' logged over landed near 1.0.
