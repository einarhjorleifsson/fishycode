# 315 — Plan 073's first run: the seabed read by its texture, features by their merge tree, names placed by their statements with the seabed's candidate beside them

*2026-11-11. Plan 073, at the maintainer's word ("proceed with the plan, take you time to test alternative approaches
... the time is less of a concern than token cost"); the downloads at his word too ("proceed with that"). Built,
tested and written by Claude (AI); no person has checked it. Study: `$FISHYDATA/archive/2026-11-11-local-features/`
(its README has every count, by script; internal: Trackwell's and the plotter's names). The plan's asks a-h were taken
as the plan proposes them.*

## Why

Plan 073 asks, feature first, for every local feature a category, a place, a name and a confidence, for a person to
judge feature by feature. Each step was run as a study, alternatives scored on witnesses held out.

## What was found

- **Two sources fetched into raw:** GEBCO 2026's type-identifier grid (`raw/external/gebco/`, the zip as delivered,
  read in place) and IHO-IOC's B-6, edition 4.2.0 (`raw/external/iho/`), each with an md5 and a provenance note. B-6
  defines a mound, knoll, hill and seamount by relief above "the deepest isobath that surrounds most of the feature":
  under 500, under 1,000 and over 1,000 m.
- **Where the grid can be read (step 1).** A cell interpolated from a coarser grid has an exact signature at 50 m: a
  median |laplacian| under 10^-2.5 m, with a trough between it and the rest. GEBCO's type then says what the fill
  rests on. The fill from prediction is 3 % of Reykjaneshryggur deeper than 200 m and 15 % of Kolbeinseyjarhryggur.
  The rest is "not interpolated", an upper bound on sounded: neither the texture, nor the difference from GEBCO, nor
  the fishing fixes split Olex's soundings from its own gridding. How the grid was made stays a question for its
  maker.
- **Features (step 2).** A merge tree (Rcpp) gives every high and low its saddle, prominence, area, parent and an
  ellipse of the same moments: 559,124 with 2 m of relief or more over the whole grid, in about 6 minutes. Scored on
  the charts' 3,300 rings, ÍSOR's craters and seamounts and the Vestmannaeyjar marks against controls 3 km off, it
  finds a high at about 75 % of the 1:40 000 and 1:100 000 rings at 5 m (25-43 % at the controls) and 64 % of ÍSOR's
  seamounts (16 %). The same on a grid smoothed by 75 m does worse everywhere and loses the small highs. Lows are
  weaker, ÍSOR's craters mostly too small for 50 m.
- **Statements (step 3).** About 27,000 units, each an independent statement. Of 548 units with lost letters, 30 take a
  full name from a known spelling within 30 km; of 128 short forms, 22.
- **Links (steps 5-6): no rule passed.** Four rules (the nearest peak of 5 m, the smallest outline holding the centre,
  the outline holding most units, the first else the second) were scored on 270 witnessed names held out. At each
  witness's own precision the best changes almost nothing: 8 names come within the witness's radius, 8 leave it.
  Outlines pick features too big (a whole bank). The gain is not in the seabed step but in the centres: homonyms and
  coarse units.
- **So the place stays the statements' centre** (from its most precise units: marks and chart labels, then Trackwell
  vessels, then the coarse), and the seabed's feature is a candidate on the card, never the place. This is plan 073
  §2.9's rule, applied.
- **Categories and confidence (step 6).** Of 8,973 name groups, 1,959 name land and 1,447 an area (bays), left out;
  5,571 proposals, 3,406 of them with no category word. The place's confidence, counted without its witness
  criterion, comes out in order on the witnessed names: within the witness's radius 14 % of none, 51 % of low, 87 % of
  medium and 96 % of high (the centres include the chart's label units, so the high levels are partly the charts').
- **The map (step 7):** a rebelrebel bundle (`out/map/`), the names coloured by confidence, a "Colour by" switch to the
  category and either confidence, chosen by confidence, category and B-6 type, the candidate's peak beside each.
  Served on 127.0.0.1 for the check. rebelrebel 2026.11.11.4's `rr_segment()` calls `ST_MakeLine` without loading
  DuckDB's spatial extension, so the line from a name to its candidate is left out (plan 072).

## What this does not do

Nothing is in the pipeline and nothing is reviewed. Not built: the review's answers (step 8, the maintainer's), the
homonyms split before a centre is taken, and the category word lists moved into `curate/place_name.R`'s `terrain()`.
