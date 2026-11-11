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

## Amended 2026-11-11: better centres

At the maintainer's word ("go with better centres first"; scripts 44-46 in the study). The lever script 42 named.
- **Eight ways of taking a name's centre** were scored on the held-out witnesses, at each witness's precision:
  - the old one (the median of the best class present), with Trackwell at its runs' medians or at their stamps (a
    run's first haul);
  - a name's units clustered in space at 3, 6 and 12 km, the cluster with most support taken.
- **The best: clusters cut at 3 km, Trackwell at its stamps.** 35.0 % of witnessed names within the witness's radius
  against 30.2 %, the median distance 2.2 km against 3.7. Choosing the best cluster every time would give 36.8 %, so the
  rest of the misses have no cluster near the witness. The stamps alone changed nothing.
- **Splitting the precise class** into marks (the plotter, the Vestmannaeyjar map) and labels (charts, LMÍ 2017, ÍSOR)
  in any order of trust did no better than one class.
- **Moving to a feature still gains nothing** from the better centres (R2: 8 gained, 10 lost).
- **So each name group is split into its places**, one proposal each, the one with most support its main place, the
  others places where the name is also used (plan 073 §2.4's homonym). A coarse unit counts as support for the nearest
  place within 10 km, never in its centre. 8,973 groups give 12,713 places; 8,698 proposals once land and bay names are
  left out; 1,005 names have two places or more, mostly the broad -grunn and -djúp.
- **Calibration** (the main places): within the witness's radius 58 % of low, 82 % of medium and 88 % of high.

## Amended 2026-11-11: spellings near in place

At the maintainer's word (two points on one mound spelt differently, a short form and the full name; script 47; the
names themselves are in the study, internal).
Places of different name groups within 2 km are joined by three rules:
- **abbreviation:** each token of the short form begins a part of the other (the maintainer's "G-HOLL" for Gullhóll), or
  one cut token of 4 letters or more begins it;
- **spelling:** Levenshtein 1 or 2 on the folded letters, the rarer form 2 units or fewer;
- **same feature:** the same candidate, Jaro-Winkler 0.9 and Levenshtein 3 or less.

The letter tests catch 69 % of the 1,862 pairs in the maintainer's name dictionary whose reading differs from the
name as written (18 % before the cut-token rule and the lost letter read as one letter). The guards, each added when
the sample read wrong, keep apart:
- names whose categories differ;
- two printed names;
- names differing in a side or size word (eystri/vestri, a single A/V/N/S, dýpri/dýpra);
- names whose numbers differ;
- a feature and its part (a -grunn and its -grunnskantur);
- a name and the same name with words added (a name and the name followed by "(utarlega)").

Joined: 304 groups into 140. The proposals fall to 8,312, each card listing its spellings, so a join can be judged.
Orkustofnun's licence titles were dropped from the statements: they are not place names.

## Amended 2026-11-11: wider joins, strays, track records and outlines

Each at the maintainer's word, as he read the map (scripts 46-49 in the study; the names are in it, internal).
- **Joins widened to 10 km.** Two more rules:
  - a bare feature word with its article names the one compound nearby that ends in it;
  - a one-word name that is the end of a one-word compound is its short form, unless the dropped front is a modifier
    (pínu-, næst-, innri-).

  Guards added on reading the samples: folded side words and superlatives, feature and part words in folded form
  (botn, mynni, brún), and a whole name never taken as a bare word. Two printed names stay apart only when each has
  3 units or more; a misreading of one joins it. The joins now build on each other: 705 groups into 309. Testing every
  pair took over 15 minutes, so the costly tests now run only on the pairs a cheap test lets through: under 2 minutes.
- **Places are cut at 6 km**, scoring as 3 km did (script 44), so one name over a ground stays one place.
- **Strays.** A name is established by the maintainer's review, then the chart layer (a chart name's area at 3 km, its
  position at 5 km), then a named ring, then a main place of medium confidence. A near miss is another place of the
  name 3 to 30 km from its anchor, without support of its own (3 families and 5 units); for a chart anchor, only places
  holding the chart's own spelling, whatever their support, since "Synonyms are a different matter". Such a place is a
  stray: a likely wrong record, kept, counted and drawn apart. Beyond 30 km a place is another feature of the name
  ("Two or more features far apart having the same name are of course likely true"). The result: 390 strays, 411 other
  features of a name.
- **Each unit's track record** (script 49): its statements on established names and the share that are strays.

  | sources | stray share |
  |---|---|
  | Trackwell | 30 % |
  | the plotter, channel, LMÍ 2017, Oracle | 13-15 % |
  | LMÍ 2022 | 8 % |
  | ÍSOR and the tag recaptures | 6 % |
  | the charts | 4 % |

  18 Trackwell vessels are suspect. A unit's support is weighted by its record, and a suspect unit stays out of a
  centre where others stand. One round only.
- **Outlines** (script 48). The extent is the smallest feature up the nesting whose ellipse holds half of the place's
  statements, else the candidate. The boundary is the cells strictly above its saddle joined to its peak; a first run
  took the saddle cell too, and each outline spilled into its parent. 2,779 outlines. ÍSOR's outlines are whole
  edifices at 1:100 000, a median of 95 km², so their overlap is only a background check: a median of 0.23 for the rule,
  0 for the candidate alone. The run's "clipped" flag was wrong for every outline (fixed in the script, not rerun).
- Calibration on the main places: 58 / 84 / 89 % within the witness's radius (low, medium, high).

## What this does not do

Nothing is in the pipeline and nothing is reviewed. Not built: the review's answers (step 8, the maintainer's), the
homonyms split before a centre is taken, and the category word lists moved into `curate/place_name.R`'s `terrain()`.
