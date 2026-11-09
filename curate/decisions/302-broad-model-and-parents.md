# 302 — A broad model for plan 070: the first areas' outlines moved onto the charts' isobaths, and each name's parents from three versions as witnesses

*2026-11-08. At the maintainer's word: "Take the contours from both the tif-map as well as the natt.is sea-chart as an
indicator of the örnefni boundary"; "check what each countour-boundary model for an örnefni gives vs what we currently
have. i.e. explore some alternatives"; "Different rules / "models" may apply to different levels of granularity / zoom
depth for places names"; "i am wandering if you can come up with some "optimization" for a final proposal. What we do
not want in the final is some obvious radius ... this is not rocket science, but expert judgement"; "The objective in
the end is not the boundary themselves, but being able to tell 1) In which broad area are we, 2) what örnefni are child
of another örnefni, 3) what örnefni are actually potentially child from two parents"; "we can have a virgin child (aka
Jesus) or the natural child that has two or even more parents"; and "I trust your judgement to make the best call. so
proceed on you own". Coded, run and counted by Claude (AI); no person has checked the code, the areas or the counts,
and nothing here is adopted. The study, its scripts and every table: `$FISHYDATA/archive/2026-11-08-old-chart-names/`
(its README, from "The contour boundaries against the current areas"). Rerun on 2026-11-09 on plan 070's levels
rebuilt with the maintainer's boundary rule (decision 304); the figures here are the rerun's.*

## Why

Decision 300 found that the charts give a broad name its depth level, the old 1:750 000 chart (model A) and the current
ones (model B) alike, and left open how that level becomes an area. Plan 070's first model draws the areas from the
depth model's relief against a local plane, level by level down the charts' hierarchy (2026-11-06 and 07). The question
was whether the charts' contours improve it, or reach the same answer from another basis.

## What was compared

`12_boundaries.R`: the 120 broad sea names (printed at 1:300 000 or coarser; 89 with a first-model area), each
label's level read off both families' lines, and seven ways of drawing an area from it, against the first model:

- **The first model's outlines do not follow the charts' lines**: about 5 % of an outline runs on the chart's level,
  a median 3.0 km from the current charts' line; a median 40 % of an area lies past that level. It draws from relief,
  not isobaths.
- **The contour alone does not reproduce the areas**: median iou 0.18-0.30 for every contour-only way. Most broad names
  are open at their level, and whatever closes the open side (a radius, a size cap, the neighbours) draws most of the
  rest. Where the level closes round a feature at a size its scale allows, the two agree (Mýragrunn, Nesdjúp,
  Öræfagrunn, Hrísnesáll, 0.55-0.71).
- **By kind more than by zoom level**: a deep's first-model area lies mostly inside its chart level at every level; a
  rise's runs past the line nearest its label (78 % at 1:1M), that line ringing the bank's top.

## The broad model

`14_proposal.R`: the first model kept, each outline moved onto a chart's isobath where one runs near it.

1. The level is the chart's line the outline already runs nearest (the largest share of outline within 2 km of that
   level's line points), among the levels enclosing a label that keep 60 % of the area or more: chosen by the outline,
   not the label. Without the floor, a first run cut Faxabanki from 1,815 to 51 km².
2. The area is cut at that level, and widened onto the line by at most 5 km, into sea no other area holds, only between
   the old edge and the line and only where the line, the coast or a neighbour stops it. No radius or offset line can
   show; where no line runs near, the outline stays the first model's.

- **The two maps reach the same answer**: where both families take a level (34 areas) they take the same one 33 times,
  and their versions overlap at a median iou of 0.92. B takes a level for 81 of 89 areas, A for 35.
- **A light touch**: the combined version (B's where it takes a level, A's where only A does, the first model's
  otherwise) overlaps the first model at a median iou of 0.83 (0.74-0.92 by level and kind); 4 small areas change more,
  grown onto their line. The outline on the line goes from 47 to 69 %. A tolerance of 1-3 km and a reach of 2.5-5 km
  give 0.80-0.86.

## The parents

`15_membership.R`: the three versions (the first model, moved onto A's lines, onto B's) as three witnesses, as three
skippers would be. Children are every seabed area and bay the levels drew below 1:2M and the charts' 751 spots and
hazards. Each of a child's cells goes to the finest coarser areas holding it; a parent's weight is its share averaged
over the witnesses, counted from 0.2. Seabed areas and bays are two families of parent, apart: a place can be in
Faxaflói and on Faxadjúp at once. An area's parts more than 3 km apart are separate places (the bays' rule had joined
homonyms: Álftafjörður, three fjords).

- **No parent and several parents are both outcomes.** Of 1,037 children: 71 have a seabed and a bay parent, 721 a bay
  parent only, 84 a seabed parent only, 161 neither. 18 of the 23 seabed areas at 1:1M have no 1:2M parent (the east
  coast's deeps, Rauðatorgið, Rósagarðurinn): broad names in their own right.
- **The witnesses agree**: the same seabed parents for 993 of 1,037 children, the same bay parents for all 1,037. Several
  seabed parents (3) come only where they disagree (Skötuhryggur: Eyjabanki 0.67, Selvogsbanki 0.33). Several bay
  parents (46) come from bays drawn over each other (Steingrímsfjörður in Hrútafjörður 0.72 and Húnaflói 0.28).
- **Which broad area a place is in**: the 62 places at 1:2M hold 108,699 km² all three witnesses agree on and a fringe
  of 13,944 km² that one or two do, where a place belongs to a broad area in part.

## What it means

The broad level stands: two charts a generation apart and the depth model's relief place the broad names, and name the
same parents, nearly everywhere. The boundary is expert judgement and stays so; what matters downstream is which broad
area a place is in and each name's parents, and their disagreement is a weight, not an error. The charts' lines are a
light correction to the first model, not a replacement. Plan 070 takes this as §2.9.

## Open

- The maintainer's review on the study's map (`scripts/13_map.R`, port 8813); nothing adopted.
- Moving in: the open-coast bights (Meðallandsbugur, Mýrabugur, Eyrarbakkabugur) have no rule that draws them; a long
  fjord's window runs past its own mouth (Hrútafjörður takes Steingrímsfjörður), and a fjord closed by its narrowest
  mouth was tried and dropped (54 of 90 fjords shrank, Arnarfjörður from 642 to 35 km²); the small names as points from
  the charts' rings and symbols (decision 301).
- The thresholds (0.2, 60 %, 2 km, 5 km) are first guesses; the sensitivity runs say the answer does not hang on them.
- The maintainer's comments on the broad level, the same night: a name printed at 1:2M can be another's child
  (Hornbanki under Strandagrunn, Skagagrunn the mother of Innragrunn, Skagagrunn proper and Sporðagrunn, Hali a tail),
  and two voids (Héraðsflóadjúp between Vopnafjarðargrunn and Glettinganesgrunn, Grímseyjarsund). Tested on the depth
  model's own tree on the shelf in 10 m steps (`scripts/16_merge_test.R`): it bears out Hornbanki (joining Strandagrunn alone at 90 m), Skagagrunn,
  the north-west mother and, on the rebuilt levels, Rifsbanki under Þistilfjarðargrunn (at 120 m, with Kjölsenbanki
  alone; before the rebuild only with the whole shelf at 170 m); not Digranesflak under Vopnafjarðargrunn (a child by
  place, not by nesting); the voids are real. Not built.
- A name's history (the maintainer: "as accurate location for a name of a ground (not the boundary) but add to that
  name historical content"; "örnefni change with time"): Bjarni Sæmundsson's reports bear out the Skagagrunn family's
  chronology (1900's Skagagrunn where Innragrunn lies today; Sporðagrunn a famous name with no known place in 1933; the
  study's README). His names share today's roots with other endings (Húnaflóadjúp for Húnaflóaáll), so a history is
  matched by root; and of a ground's forms the oldest ending found rules, as the principle of priority in taxonomy,
  the chart's form kept as current usage, while the grounds keep the names in use (the maintainer: "the purist would say
  that the oldest name should rule"; "current Skagagrunn holds ... I was more thinking about the ending part, djúp vs
  áll"). Not built.
