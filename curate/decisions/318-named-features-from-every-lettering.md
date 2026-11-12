# 318 — Plan 074 step 1: named features drawn from every lettering at every chart scale; the rules tried, where each broke, and the one that holds best so far

*2026-11-11 late and the night to 2026-11-12. Plan 074 step 1, at the maintainer's word as he read the maps: "forget the
old stuff for now, start anew"; "Your model is awful ... when you have these "big labels" on the sea-chart"; "anything but
a midpoint"; "the zoom level count here as well"; "you have to check every zoom level for every placename"; "change the
rules then to get Glettinganesgrunnur"; "if you have to break them often enough, create a new rule. That is you job";
"nope not the halfway between - here olex comes in"; "use that "rule" at any scale for a landmark. Until of course the
rule breaks!!!!! If the rule breaks go back to the beginning and figure out if another rule could be used at any scale.
if not, and only if not, you start thinking about exception clauses"; "the sea-chart is a composit of different
original map at different true scale"; "be careful that the sea-charts may use different version of a name at different
1:xxxxxx"; "do not forget the meaning of different -endings ... check the archives"; and for the night, "take you time
here, you are even allowed to start from scratch". Built, scored and written by Claude (AI) while the maintainer slept;
no person has checked the counts or the maps. Study: `$FISHYDATA/archive/2026-11-11-named-features/` (internal; its
README lists every script and every failed rule).*

## The lettering

- Every reading of a chart name at every chart scale (TODO 186's readings: window, grid cell, text) is cropped and read
  for its box by macOS's text recognizer, the box turned back into the chart's frame (script 07). Readings are matched
  to a name by the folded name (case, accents, ð/d), by a confirmed version of it (the same ending and a form alike:
  Héraðsdjúp / Héraðsflóadjúp, Axarfjörður / Öxarfjörður, "examples cited correct"), and as fragments a cut label
  absorbed; a box counts only if its text is nearest its own name (a Syðrahraun box had counted for Vestrahraun). 563
  boxes for 211 of 236 chart names of highs, lows and slopes; names lettered at two scales or more: about half.
- Families with another ending are different areas (the maintainer: Héraðsflói "an inlet/bay", Héraðsflóadjúp "a deep
  that extends from the flói, quite a lot bigger").
- The chart is a composite of source charts at their own true scales, so no one scale's lettering is trusted alone.
  Glettinganesgrunn: 8 km of lettering at 1:100 000, 34 km across two windows at 1:300 000 (checked on the window image,
  in spaced capitals out over 160-190 m soundings), 38 km at 1:1 000 000.

## The rule, as it stands (the map's default)

At each chart scale a name is lettered at, its letter boxes are its marker; all names lettered at that scale flood the
depth grid at once (highs from their tops, lows from their bottoms; each cell to the marker reaching it first), so
neighbours part along the troughs and saddles between them; a name's kind comes from its ending where the ending says
(the maintainer's glossary); the reach is two lettering lengths along and one and a half across; the cut is **the
charts' standard isobath one level beyond the first that holds eight tenths of the lettering** (the archive's "rises fit
one level out", decisions 300, 302); where that breaks, a knoll's own ground to its key saddle, sought at the chart's ring
round it where one is drawn (the spot); lows lose fingers and keep one
piece; a size cap of four times the scale's median area among areas; where a high and a low overlap, the convex part of
the Olex surface goes to the high and the concave to the low, the curvature at an eighth of the lettering's length
("here olex comes in"). Nothing in it is fixed in metres: the grid, the band, the reach and the smoothing follow the
lettering and the scale (scripts 10 and 13).

## The rules tried, and where each broke

| Rule | Where it broke |
|---|---|
| the label's middle (01) | "awful": the big labels unused; depth relief fails on a bank joined to the coast |
| the letters' ellipse, then the isobath level covering it (04) | the flood climbed onto the coast; a label running past its bank flooded far |
| a watershed from one label's box, cut at the growth (06) | too big (a reach of 1.5 label lengths as a disc) |
| every scale's boxes, all names flooding at once, cut at the first steepening (08), the flank by curvature (09) | held on Glettinganesgrunn (904 km², 96 % of its letters inside); curvature at 1 km was noise, at 5 km it follows the flank |
| the same at every scale, reach 0.75 by 0.5 lettering lengths (10) | 117 of 567 name-scales broke, 95 "no break before the reach", mostly 1:100 000 and finer |
| reach 2 by 1.5, the nearest sea for letters on land (10, second) | 58 breaks; but some outlines filled the reach's ellipse (an arc off the Westfjords: "follow the landscape") |
| spaced lettering an area, plain a spot (13, first) | the readers wrote broad names without spaces: 47 of 51 names at 1:2 000 000 became spots; the cap over spots capped real banks |
| the area rule first, the spot where it breaks; cap among areas (13) | holds; the cuts below compared |
| the landscape's objects first (a saddle chain), names second (16) | a bank joined to the coast is no closed object, and siblings merge before either's letters are in: the names must compete (as the archive found) |
| the finest scale's level kept at broader scales (13, XSCALE) | nesting best, but the finest lettering marks only a bank's top (Glettinganesgrunn 150 m against the 1:300 000 lettering's 200 m) |

## The comparison (script 14), on witnesses the rules do not use

| Cut | Breaks | Overlap with the broad model (decisions 300-304) | Named rings inside | Finer inside broader |
|---|---|---|---|---|
| reach 2 by 1.5, first steepening, no cap (10, second) | 0.12 | 0.26 | 0.80 | 0.65 |
| first steepening (13) | 0.20 | 0.27 | 0.60 | 0.64 |
| isobaths onward until the area doubles | 0.19 | 0.27 | 0.55 | 0.64 |
| first steepening snapped to a standard isobath | 0.20 | 0.31 | 0.60 | 0.63 |
| **one standard isobath out** | **0.17** | **0.32** | 0.55 | **0.67** |
| one isobath out, the finest scale's level kept | 0.16 | 0.27 | 0.54 | 0.71 |
| first steepening, the finest scale's level kept | 0.20 | 0.25 | 0.59 | 0.78 |
| one isobath out, knolls to their key saddle | 0.20 | 0.32 | 0.55 | 0.63 |
| **one isobath out, a spot sought at the chart's ring round it** | 0.22 | **0.32** | **0.65** | 0.64 |

The broad model shares the charts' contour levels, so part of the isobath cuts' lead over it is by construction; the
rings favour large outlines (the uncapped rule holds most). The knolls lose their rings under every capped rule: the spot
rule drew them at 0.02-0.9 km², stopped at their own bumps on the fine grids; a knoll is now drawn to its key saddle, where
the flood would reach ground higher than its top (the archive: "a knoll stops at its saddle"), and sought at the chart's
named ring round it where the chart draws one (Ægisklakkur's and Ingimundarklakkur's rings now inside; that part of the
rings witness is then by construction). That last form is the map's default; one isobath out without it and every other
rule are layers beside it. The saddle rule (16) was stopped after two hours at 1:100 000 (its stage search grows with the
square of the window) and wrote nothing; it had already failed on the named cases.

## What is left

- The maintainer's eye on the map (port 4820, `15_map_rules.R`, one layer per chart scale and the other rules as layers):
  his two reviewed outlines (Eldeyjarboðagrunn, Eldeyjarboði-Taglið) are not lettered on the charts, so no witness of his
  judges these rules yet.
- His guidelines for deeps not yet in: fill and spill, to the shelf edge, never in the inshore strip.
- The parts on their wholes' outlines (plan 074 step 4), the hazards, the relational and hydrographic names.
- Plan 070's "A watershed model may not be a good starting point": the flood here is seeded from the lettering at each
  scale, not a partition of the seabed; told to the maintainer, for him to judge.
