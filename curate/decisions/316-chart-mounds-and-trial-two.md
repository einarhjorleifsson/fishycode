# 316 — The chart names' mounds outlined on the Olex grid and added to the sea-chart model; trial 2 without Trackwell

*2026-11-11. Plan 073, at the maintainer's word, as he read the maps: "proceed by excluding the Trackwell data - I think
they are the real culprit here"; "Can you add the refined chart based model to the map. And then add also the sea-chart
as a background"; "There are obvious names here that are not mapped"; "add to the map" as "made part of the sea-chart
polygon map"; "These sea-chart "boundaries" - where they not created via an R-script. And should we then not just add to
that R-script"; "Take you time here, try different avenues to estimated the perimeters of mounds. And there are of course
mounds in other places, e.g. check Kolbeinseyjarhryggur". Built, scored and written by Claude (AI); no person has
checked the counts. Studies: `$FISHYDATA/archive/2026-11-11-local-features/` (scripts 30, 51, 53, flood.cpp) and the
örnefni map's (`$FISHYDATA/archive/2026-11-08-ornefni-map/`, scripts 10 and 01); internal.*

## What was done

- **Trial 2.** Trackwell out, and the chart layer, its names, their forms (within 30 km) and their derivatives (the same
  root within 50 km, the maintainer's "Gerpisgrunn, Gerpistota, Gerpisflak") labelled out of the statements, not dropped:
  7,233, 1,532, 4,155 and 172 units; 14,477 in use. The chain ran through the proposals and track records; its outlines
  were paused at the maintainer's "Hold on" and are not drawn.
- **The sea-chart model on a map of its own**, over the charts themselves (Náttúrufræðistofnun's WMS map cache, nine
  scales at their own zooms, as the place-name explorer draws them): broad (73) and finer (30) grounds and deeps, 259
  bays, the chart names by how each was placed. Checked: the scripts that build these areas read the charts and the
  depth model only, no Trackwell and no gazetteer.
- **Mound perimeters, five ways and the maintainer's rule**, each a stage of one flood from the peak (the cells taken
  highest first). Scored on the 634 chart rings with a printed level and on his reviewed mound (Eldeyjarboðagrunn,
  42 km²).
  - On his mound his own rule (the in-use study's 05_reviewed.R: from the main top down to the last level before it
    takes in another high rising P m) fits best at P 40 m: 44 km², an overlap of 0.93. The relief jump gives 0.76 and
    convexity 0.63; the saddle, area elbow and slope foot take only a small top.
  - The rings judge none of them well (the best, the area elbow, a median overlap of 0.2). A ring is drawn at the
    charts' standard isobaths round a feature, so it gives a feature's place, not its foot.
  - A threshold scaled to the mound's own relief did worse (0.66).
- **The chart names' mounds into the model** (`10_chart_mounds.R`, beside `01_names.R`). The names are each chart name of
  a high without an area (766), the maintainer's additions (Grjóthryggur and Langagrunn, on the chart but missed by
  TODO 186's reading) and a parent he named (Fuglasker, the mound holding Geirfuglasker and Geirfugladrangur). Each
  starts from the name's ring, seabed high or label.
  - His rule found a foot for 252 names. On a small shoal no high rising 40 m comes within reach, and on a ridge of
    several tops it stops early (Grjóthryggur 0.6 km² against ÍSOR's 19). So the areas take his rule, else the area
    elbow: 489 mounds.
  - `01_names.R` adds them to `areas.geojson` (`src` "mound", owned by their name; a name keeps its place and zoom), and
    the maintainer's added names as points. His synonym and part are kept beside them: Röstin another name for
    Reykjanesröst, Húllið a channel within it.
  - The relief jump and the area elbow are drawn for comparison.
- **Mounds elsewhere.** Every main top rising 40 m or more on cells the grid did not interpolate, by his rule: 3,603,
  148 of them named (an ÍSOR name inside 96, a statement of trial 2 44, a chart name 8); 239 on Kolbeinseyjarhryggur,
  20 named.
- **Two rebelrebel defects** (plan 072). `rr_segment()` calls `ST_MakeLine` without DuckDB's spatial extension. A tiled
  layer refuses a column both coloured and in its pop-up ("Duplicate struct entry name"); worked round with copies.

## What this does not do

Nothing is reviewed and nothing is in the pipeline. The mound rule's threshold rests on one reviewed mound. Ridges of
several tops need a rule of their own, and the maintainer's judgement on the map decides among the three perimeters.
Trial 2's outlines are not drawn, and its proposals are not on the chart map.
