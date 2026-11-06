# 070 — Place-name areas and the seabed's terrain classes: a hierarchy of overlapping areas, from the names' own occurrences, framed and edged by the seabed

**status:** proposal — written 2026-11-06 at the maintainer's request, with a feasibility scan the same day
(`$FISHYDATA/archive/2026-11-06-place-name-areas/`, its README). The same day: steps 1, 2 (its partition dropped at the
maintainer's word), 4, 5 and 6 (with its edge rule and the name groups drawn once) run as studies; the evidence's
weights, the effort and the terrain classes added at the maintainer's word; asks a-f answered. Nothing built ·
**2026-11-06** · **see:** plans 043 §3.4, 044 §2 and §4, 045 §2 and §3 (steps 3-4), decisions 222-226, 272 and 286,
TODOs 144 and 185, the effort map (decision 220)

Drafted with AI assistance (Claude) on 2026-11-06; a person has not yet checked it.

**Measured** (by Claude, 2026-11-06, the scan): the numbers in §1, on the Olex 50 m grid and the gazetteer as rebuilt
that morning (decision 286).

**Assumed:**
- that the names' occurrences are the evidence of an area, and the seabed only frames and edges it. The scan supports
  this (§1), but it does not prove it;
- that a trough is a boundary, and the shelf between two troughs is a bank's unit. That is read from one picture of the
  west shelf (§1), not tested;
- that the methods in §5 fit. They are leads from Claude's knowledge, not read against their sources;
- that the mobile gears' effort concentrations mark grounds, and the gaps between them their boundaries (the
  maintainer, 2026-11-06). Not yet measured.

The maintainer, 2026-11-06: "I am wander if we are the stage to try some algorithm to demarcate the places names. … a
hierarchical approach, starting with the main grounds and deeps and work ourself then to the next level, örnefni within
those area, …. The thinking is that the demarkation should not be treated as exclusive, i.e. one could think of having
overlapping areas in most cases." What is new since plan 045 was parked: more names and sources (decisions 285, 286),
and the Olex 50 m grid (TODO 185).

## 1. Is it time? What the scan measured

**Yes for the top of the hierarchy, and for areas drawn from the occurrences. Not yet for placing a name on its knoll
from the grid.**

- **The shelf break comes first.** A plain BPI (a cell minus the mean within 25 km) puts nearly every name above its
  surroundings, deep names too (median share 0.66), because a circle near the shelf break takes in the slope.
  Thresholded, it makes the south coast's shelf one rise of 10,000 km². The hierarchy has to start from the shelf
  itself.
- **Kept to the shelf, the grid tells banks from deeps.** With cells shallower than 600 m, at 25 km:
  - bank names' positions lie above their surroundings with a median share of 0.80, and deep names' 0.36;
  - a bank name ranks above a deep name with a chance of 0.78 (0.70-0.74 at 5-10 km).
- **The troughs are objects; the banks are mostly not.**
  - In the north and east the cross-shelf troughs stand out, with the deep names in them.
  - On the west shelf, Látragrunn, Breiðafjarðarflak, Kópanesgrunn and Barðagrunn are flat ground between troughs
    (Víkurál, Kolluál, Jökuldjúp), not rises.
- **Seabed regions do not hold the names.**
  - Of 162 bank names, 14 have half their positions or more in one thresholded rise; of 135 deep names, 20 in one
    trough. The positions are tows on flanks and flat ground, while a region is a feature's core.
  - So an area cannot be a seabed object with a name pinned on it. It has to come from the occurrences, with the seabed
    for the frame and the edges.
- **At the fine scale, holes show and knolls do not.**
  - On the Vestmannaeyjar map (positions within about 90 m), the 7 leirur all lie below their surroundings within
    1.5 km, and 4 of the 5 holur too. The 38 klakkar lie above no more often than chance (0.42; 0.55 allowing 150 m).
  - The plotters' hill marks lie above their surroundings 0.66 of the time, against 0.54 for other marks. A weak
    tendency.
  - A grid averaged into 550 m blocks sees about the same at 1.5 km. What the 50 m grid adds lies below 500 m, where
    the knoll test fails.
- **Where the grid is Olex and where it is GEBCO's fill is not known.** The scan's measure of detail is as large on
  random ocean cells as at the names.

## 2. The design (proposal)

### 2.1 What an area is

- **A place's area is a membership surface,** a value from 0 to 1 per cell of the 500 m grid. It is drawn as two
  outlines: the core (0.5) and the extent (0.2).
- **Areas overlap.** Two names of one level may share cells (two skippers' names for one ground, or grounds that run
  into each other).
- **Nesting is soft.** A child's parent is the area holding 70 % or more of the child's membership, as plan 044's
  footprint rule holds positions. A child may have two parents where two pass.
- **A place, not a key.** Areas are made per place, as the gazetteer gives them (a key can mean several places), and a
  name group (decision 272) is drawn once.

### 2.2 The evidence: weighed by quality, not counted

The maintainer, 2026-11-06:
- "the different data souces are of different quality. And number of observations are not always an indicator of
  evidence. A case in point are the trackwell pings with placenames";
- "time may be an important factor - the recording on a particular ground may continue if the captain forgets to
  switch/stamp in a new ground. And they are also often indicator of 'in the vicinity of ....'".

So no statistic of this plan counts occurrences:
- **The unit of evidence** is a statement made independently: a vessel within a source, a document, a mark. One
  vessel's thousand tows under a name are one statement, and each source counts alike until its quality is measured.
- **A source's weight is its measured error.** It is the spread of its positions about the names that independent
  families confirm (the gazetteer's `confirmed`), measured per source, and for Trackwell per vessel.
- **Trackwell's runs.** A run is a vessel's hauls under one name in a row, in time order.
  - **Its first hauls carry the most.** The name was stamped there.
  - **Its later hauls carry less,** by the time and the distance since the stamp.
  - **Its last hauls may lie on the next ground:** the last 4 before a switch lie nearer the next name 15.8 % of the
    time, against 7.3 % mid-run (measured 2026-10-24, plan 043 §3.1).
- **A name is often "in the vicinity of".** Trackwell's positions then describe the neighbourhood the name is used
  for, its extent. The marks (plotters, maps, LMÍ) and a run's first hauls describe the core.

### 2.3 The levels

- **Level 0, the frame,** from the grid alone:
  - the coastal band, the shelf, the shelf break, the slope and the deep basins;
  - the shelf break traced region by region, where the slope steepens, not at a fixed depth (the scan's 600 m cut drew
    a false trough along it).

  Every name gets its zone, and the BPI of level 1 is taken within the shelf.
- **Level 1, the troughs and the rises:** objects from the shelf's own relief against a plane at 25 km, overlapping
  whatever else covers them. They are not a partition.
  - **The partition is dropped.** Step 2 also cut the shelf into units by a watershed (2026-11-06). The maintainer:
    "A watershed model may not be a good starting point here".
  - **Why:** a watershed puts every cell in one unit, against §2.1's overlap. It follows the relief's tops, while a
    ground is defined by its use. On the flat west it has nothing to cut. And LMÍ's outlines covered only 6 % of the
    unit they lay in.
  - **What replaces it:** the names' areas come from their own evidence and the effort (levels 2-3). A broad name such
    as Látragrunn gets its area from its own evidence, not from a cut in the seabed.
- **Levels 2-3, the grounds:**
  - **The density:** a kernel density over the place's positions, weighed as §2.2 says. The core comes from the marks
    and the runs' first hauls, the extent from the rest.
  - **The effort:** the mobile gears' effort density (bottom trawl and Danish seine first) cut into concentrations,
    each concentration's edge where the effort falls to a valley between it and the next. It shows where the grounds
    are, and where they part.
  - **The edge:** where the name's density fades near an effort valley or a seabed break within reach (a trough's
    edge, an isobath, the shelf break), the edge is pulled to it.
  - **A coarse name placed:** a name known only by a square, an area or a text (Oracle's squares, the recaptures, the
    articles) is put on the effort concentration of its gear within its square or area. Its basis is then
    `effort`, and it is not an independent position.
  - **The parent:** by soft containment in level 1.
- **Level 4, the marks:** a point from the marks (plotters, the Vestmannaeyjar map, LMÍ), with a radius from the
  source's own error. The seabed is a check only: holes and mud patches show, knolls did not.

### 2.4 Outputs (flow side: the effort is read from the track)

- **The terrain classes** (§2.6), from the depth grid alone:
  - `curated/reference/seabed_terrain.parquet`: one row per cell of the 500 m grid, with its zone, unit, slope, relief
    at both scales, and class;
  - `curated/reference/seabed_unit.parquet`: the zones, the troughs, the shelf's units and the shelf break (a line,
    with its depth) as geometries.

  They carry no names.
- `curated/place_name/area_unit.parquet`: the names attached to the seabed's units, with their shares.
- `curated/place_name/area.parquet`: one row per place and outline (core, extent), with its geometry, level, basis
  (`unit`, `density`, `density, edged`, `effort`, `mark`), positions, witnesses and parents.
- `curated/place_name/area_cell.parquet`: the membership by cell of the 500 m grid, for an analyst who wants the
  surface, not the outline.
- **Every place in one outcome:**
  - an area by unit, by density, or a mark;
  - too few positions (under 5);
  - placed by squares only (Oracle's anchors, TODO 144);
  - text only.

**The side.** The terrain classes read only the depth grid, a preprocessing script under `reference/geo/`. The
names come from the gazetteer, also preprocessing. The effort
is the flow's, from the AIS track (`$FISHYDATA/products/effort_map/grid.parquet`, decision 220: hours by 0.001° cell,
gear and year). So the area step is a flow script, beside the trail. The gazetteer itself stays preprocessing, as
plan 045 step 2 has it.

### 2.5 Views

- **The bathymetry map** (`products/bathymetry_map/`) gains a layer group, one layer per level, the areas as
  transparent fills that may overlap, and the core and extent outlines.
- **The place-name explorer** (`products/place_names/`) draws a name's area with its occurrences.

### 2.6 A by-product: the seabed's terrain classes

The maintainer, 2026-11-06: "I can foresee we have a bioproduct that could be terrain classification". Levels 0 and 1
read the depth grid alone, so what they make is a terrain classification of its own, apart from the names:
- **The classes:**
  - the frame's zones;
  - the shelf break as a line, with its depth;
  - the troughs and the shelf's units between them;
  - the relief at a broad and a fine scale (against a plane), the slope, and the classes the two scales give (crest,
    depression, flat, slope, as in the Benthic Terrain Modeler).
- **Its uses beyond the names:**
  - the effort by terrain: where the mobile gears tow, and what they avoid;
  - a frame for the habitat records (the corals, sponges and worms of the timarit study);
  - a finer layer than EUSM's for the datacall's habitat questions.
- **Part of this plan** (the maintainer, 2026-11-06: "Include the terrain classification in this plan"). It is built
  by step 3, from the rules of steps 1-2:
  - `reference/geo/seabed_terrain.R`, a preprocessing script that reads no AIS and no names;
  - its outputs in §2.4;
  - a layer on the bathymetry map.
- **It may be published.** Julian Burgos approves publishing what is made from the grid (TODO 185), so the classes,
  unlike the names, are not held back by the names' internal sources.
- **Its limits are the grid's:** knolls are not resolved, and where Olex sounded is not known (ask c).
- **The ground type from the gears** (the maintainer, 2026-11-06: EUSM "never took into account the fisheries / effort
  distribution"; each gear has its limits on what ground it can cover, fish trawl against shrimp and Nephrops trawls).
  - **The idea:** a substrate layer from where each gear works and where none does: soft ground where the Nephrops and
    shrimp trawls work, smooth ground for the Danish seine, rough ground where only the static gears go.
  - **Where it belongs:** it reads the track's effort, so it is flow-side, beside the terrain classes rather than in
    them.
  - **A quick test** (the study's `06_gear_ground.R`): where the bottom trawls work, mud (leir) and sand names lie in
    Nephrops and shrimp cells about twice as often as other names (0.29 and 0.31, against 0.15). Lava (hraun) names
    lie there at the base rate (0.16).
  - **The test's limits:** 34 mud names, and the region mixed with the ground. A hint, not yet a measure.

## 3. Steps

Each step starts as a study under `$FISHYDATA/archive/`, and becomes a target only once its rule is accepted.

1. **Level 0:** the frame, with the shelf break traced by region. The check: the false trough is gone, and every name
   has its zone. **Run 2026-11-06** (the study's `04_frame.R`):
   - **The break:** traced at 145-490 m by bearing, steep on most of the edge. The Denmark Strait side is gentle and
     cut at 600 m.
   - **The leak:** onto the Iceland-Faroe Ridge, taken off the shelf by a second pass at the local break. It is kept as
     a zone of its own, with the shelf for the levels above (the maintainer: "keep that as well"). 64 keys lie on it,
     Rósagarðurinn and Þórsbanki among them.
   - **The false trough:** gone with a plane in place of the mean (17 % of the outer edge's cells below -1 sd,
     against 12 % inside).
   - **The names:** 90 % of 7,406 keys lie clearly in one zone, weighted by source and vessel.
   - **The maintainer's answers:**
     - Halinn "straddles shelf and slope";
     - on the north-west edge, a dig (the study's `04b_nw_edge.R`). The steepening there is half done at about 450 m,
       against the 600 m cut. But a rule for one region was "not kosher" (the maintainer), and a gentler slope rule
       failed.
   - **The frame stays as reviewed,** one rule everywhere. A half-way rule for every bearing alike is an option left
     open.
2. **Level 1:** the troughs and the shelf's units, with the names attached. Checks:
   - LMÍ's polygons, by overlap: an outline made apart from the occurrences (dropped from step 6 on, 2026-11-06: the
     maintainer judged them rough; the step 2 numbers below used them). `staging/ornefni/lmi_name.parquet` keeps
     them, 1,775 of them in the gazetteer;
   - the maintainer's eye on the map, with the west shelf first.

   **Run 2026-11-06** (the study's `07_units.R`):
   - **The units:** a watershed of the relief against a plane, written in R, gives 158 units (a median of 532 km²).
     On the depth itself every basin merged along the shallow inner shelf.
   - **The troughs and rises:** 67 troughs and 73 rises, overlapping the units.
   - **The names:**
     - 99 of 105 bank names have half their weight or more in one unit;
     - 55 of 113 deep names in one trough's reach;
     - 30 units hold one name of levels 1-2, 29 several, and 99 none.
   - **LMÍ's bank outlines** lie in their name's unit (median 1.00) but cover only 6 % of it. So the units frame, and
     the names' own areas come from levels 2-3.
   - **The north, east and south** read as the named banks between troughs. The flat west is coarse: Látragrunn's
     unit is 15,213 km².
   - **The maintainer:** "A watershed model may not be a good starting point here". The units are dropped; the troughs
     and rises are kept as objects. Next, at the maintainer's word ("Agree, proceed"): step 5, the effort's
     concentrations, then steps 4 and 6.
3. **The terrain classes (§2.6):**
   - level 0 and 1 cell by cell, with the relief at 25 km and at a fine scale (against a plane), and the slope;
   - the classes they give (crest, depression, flat, slope), on the 500 m grid first, and on the 50 m grid where it
     has soundings once ask c is answered.

   Checks:
   - every sea cell in one class;
   - the classes under the names' terrain words (banks on crests, deeps in depressions, edges on slopes), weighted by
     source and vessel;
   - the maintainer's eye on the bathymetry map.
4. **The evidence's weights (§2.2):** each source's error on the confirmed names; Trackwell's runs and how the error
   grows along a run, from the first haul to the switch.
5. **The effort's concentrations,** per mobile gear: cut into concentrations, their valleys, and how names fall on
   them (the share of a name's weight on one concentration, and the names per concentration).

   **Run 2026-11-06** (the study's `08_effort.R`):
   - **The levels:** set on a log scale (the maintainer: "You have to use log scale or some other transformation on
     the effort map to get clear cut boundaries"): 0.1, 1 and 10 hours per 500 m cell over 2007-2026. Levels set by
     the share of the hours had all lain in the heaviest grounds.
   - **The edges are clear-cut on the log scale:** the belts, the cores and the closed boxes as sharp holes.
   - **Bottom trawl** fishes most of the shelf at 0.1 h as one region (151,763 km²). Its 10 h cores hold 59 % of the
     hours, but the names lie mostly in the 1 h belt and LMÍ's outlines outside the cores. So it gives the names'
     areas edges and holes, not the areas.
   - **Danish seine's** grounds are discrete and nearly name-sized: 90 of 125 seine names have half their weight in one
     region.
   - Next: steps 4 and 6.
6. **Levels 2-3:** the densities, the outlines and the edge rule. Checks:
   - each source held out: its statements inside the area made without it (LMÍ's polygons until 2026-11-06, dropped at
     the maintainer's word, below);
   - the gazetteer's footprint today (the densest 80 % of the positions in cells of 0.05 by 0.02 degrees), weighed
     against it: "better than the status quo?";
   - a sample per level, read by the maintainer.
   **Steps 4 and 6 run 2026-11-06** (the study's `09_areas.R`):
   - **The sources' errors** on the confirmed names run from 0.3 km (the Vestmannaeyjar map) through 3-6 km (Oracle,
     LMÍ, sjókort, the tags, the plotters, channel) to 9-10 km (Trackwell, uv); a source's weight is 1 / its error.
   - **Trackwell's runs barely matter:** the first hauls are no better placed than the middle ones, and the run factors
     are 0.85-1.0.
   - **The areas:** 1,196 of levels 1-3, one piece each with a kernel as wide as each name's own spread.
   - **Against LMÍ's outlines:** a median overlap of 0.15 against today's footprint's 0.12, and 0.33 against 0.19
     where the sizes match. But most extents are over twice LMÍ's size ("in the vicinity of").
   - **The chart's names** (TODO 186's reading, never in the gazetteer) were added at the maintainer's word ("Chart names
     first"):
     - their broadest scale follows the areas' size (median extent 61 km² at 1:100k to 760 km² at 1:2M; rank
       correlation 0.49), so the chart's zoom is evidence of extent, as the maintainer said;
     - as a source, weighted by each scale's measured error ("high weights, but still be sceptical"), they give 1,210
       areas, tighter ones, and an overlap with LMÍ of 0.17 against today's 0.13;
     - the core matches LMÍ no better than the extent.
   - **The chart's scale as a prior on extent** was tested and not adopted: on the 143 names with a scale, the overlap
     with LMÍ is 0.25 with it and 0.28 without. Names on the charts are where the areas work best (0.28 against today's
     0.11).
   - **The edge rule and the name groups, run 2026-11-06** (the study's `12_edges.R`, at the maintainer's word: "Edge
     rule, step 6"):
     - **The rules:** an extent is barred from the frame's zones its core hardly holds, from troughs it does not hold
       (or, for a trough's ground, from beyond 5 km of its troughs), from depths outside its core's, and from cells its
       gear does not fish. It keeps what stays joined to its core.
     - **One-sided, but small:** each rule helps two to seven times as many names as it hurts against LMÍ's outlines
       (all four: 116 better, 54 worse). But they take 12-14 % of an extent, and the median overlap stays at 0.17.
     - **The gap is the size:** 165 of 295 extents are over twice LMÍ's polygon. A higher threshold alone (membership
       0.3) lifts the median to 0.19 but hurts 97 names, and the edges add nothing to it. Whether an extent is LMÍ's drawn outline or the name's
       neighbourhood ("in the vicinity of") is the maintainer's to say.
     - **A name group drawn once** from its spellings' pooled evidence: the outline hardly changes (33 better, 31 worse),
       and 1,210 keys give 1,044 areas.
   - **LMÍ dropped, each source held out** (2026-11-06). The maintainer, of LMÍ's polygons: "Have the feeling it was
     really a rough job to begin with. It may still be useful for the vocabulary list"; then "Yes, do it". LMÍ's
     positions are out of the evidence and its polygons out of the check; its names stay in the gazetteer.
     - **The check in its place:** each name's area is made again without one source, and that source's statements
       inside it are counted. An honest extent (80 % of its own evidence) holds about 80 % of statements it never saw.
     - **The extents are honest for the marks** (chart, plotters, sjókort: 80-86 %), and somewhat tight for the loose
       sources (Trackwell's vessels 59 %, channel 67 %; all 68 %). Against LMÍ they had looked too wide.
     - **The edge rule is not kept:** no edge finds emptier ground than a plain higher threshold (the cost of a cut
       0.31-0.53 against the threshold's 0.32), and with extents already under 80 % any cut makes them less honest.
     - **The relief as the area** (the maintainer: "to demark "Lónsdjup" this would be sufficient "relief against a
       plane""): right for a clear trough like Lónsdjúp, whose trough holds all three held-out marks. But on the 100
       names whose core lies in one object it holds fewer unseen statements than the density (0.54 against 0.65); the
       two together hold 0.76.
   - **Adopted** (the maintainer, 2026-11-06: "Yes, adopt that"; the study's `14_final.R`): each name's density,
     unedged, the name groups drawn once, and where half or more of a name's core lies in one trough, the trough
     joins its extent. 1,028 areas, 46 with a trough; 0.685 of unseen statements inside (the density alone 0.677).
   - **The view** (the study's `15_view.R`): the areas on the bathymetry map, with its depth, relief and their controls
     (the maintainer: "A background map similar as we had in the "app" would be nicer"); this is step 8's view in the
     making.
   - **The "-grunn" prior, adopted** (the maintainer: "Yes, adopt 15 km"; the study's `16_grunn.R` and `14_final.R`): a "-grunn" name's shelf block (the shelf joined to
     its core, in no trough, within 15 km) added to its extent. On 58 areas the held-out sources' statements inside
     rise from 0.67 to 0.89 (Trackwell's vessels 0.59 to 0.82), at 2.5 times the area. In the north and east the troughs
     bound the block (Skagagrunn); in the west the reach does, as step 2 drew few troughs there.
     With it, the adopted areas hold 0.722 of unseen statements, the density alone 0.677.
   - **The landscape's bank, a candidate** (the maintainer, seeing the 15 km discs: "I thought we were going to try to
     follow the landscape"; the study's `17_grunn_relief.R`): a relief level lowered from the core's top until the bank
     would take in a neighbour's heart. It holds 0.79 of unseen statements, at less area than the 15 km block (0.89). It
     follows the troughs, but runs along the coastal shallows and into bays.
   - **The deeps first** (the maintainer: "We could also actually start with the deeps - if they are more easily
     demarcated we would adopt those first and they then serve as a boundary candidate when we move to the grunn"; the
     study's `18_deeps.R`): the banks' rule upside down, a relief level raised from the core's lowest point until the
     depression would take in a neighbour's heart, or reach the plane. 106 of 122 deeps get one; they hold 0.77 of
     unseen statements, against 0.71 for the trough rule and 0.67 for the density. A candidate.
   - **The deeps, three rounds on the map** (the maintainer, 2026-11-06, in notes pinned on the study's map and in chat;
     the study README has each comment and its rule). Each comment became one rule for every deep:
     - **Names:** -djúp and -dýpi are one name; a deep's parts join it ("Skeiðarárdýpi grunnt", "fyrir
       Berufjarðarál", KAPALL); a group takes its highest-level key's terrain word and its most-used spelling.
     - **The place by quality, not counts:** the 30 km reach round the quality-weighted median of the sources, not
       the gazetteer's place. Skerjadjúp moved to where the chart prints it; 716 places moved over 10 km.
     - **The deep's shape:** no holes, no fingers (an opening of 2.5 km), one piece; never in the inshore strip; to the
       shelf edge (the trough followed downhill to the cliff); where the shelf is narrow, the 140 m isobath shoreward;
       a stop where it would spill into another basin near the plane; only deeps stop a deep, and a lower-level name
       never takes a higher ground.
     - **The check:** the deep alone holds about half of unseen statements, the deep with the name's density about two
       thirds. The trough is the deep; the name's use reaches wider.
     - **Open:** Jökuldjúp against Faxaflóadýpi (the maintainer's to say, the evidence in notes on the map); Kolluáll's
       distance names; spellings no rule joins (Skerjardýpi).
   - **The broad areas from the official charts alone, under the charts' names** (the maintainer, 2026-11-06: "try only
     using the official map data"; "lets keep the names from the sea-chart as a rule. e.g. Faxadjúp"; the study's
     `19_chart_deeps.R`). Each deep, channel or trench the sea charts print (TODO 186's reading) seeds a depression at
     its label, shaped by the deep rule; a trough two chart names share is split between them. 50 of 68 chart features
     get an area. The charts name the outer trough west of Faxaflói Faxadjúp, and Jökuldjúp its inner part. The deeps
     may be amended where the major banks clash with them (the maintainer).
   - **Next:** the banks from the charts, bounded by the chart deeps; then the deeps and banks reconciled; the places
     beyond a key's main one; step 3 (the terrain classes) and the targets of step 9.
7. **Level 4:** the marks.
8. **The views,** one step at a time, each click path tested.
9. **The targets:**
   - `reference/geo/seabed_terrain.R` for the terrain classes, after the maintainer's review of steps 1-3;
   - a flow script for the areas, after the review of steps 4-6.

Plan 045 step 3, the gazetteer's depth, slope and BPI from the Olex grid in place of GEBCO, is small and independent.
It may come first.

## 4. How it is checked (bookkeeping, not modelling)

- **Every place is counted,** in one outcome (§2.4).
- **Every disagreement is listed:**
  - a child outside every parent;
  - a source's statements outside the area made without it;
  - a name attached to units far apart.

  Each is explained, or listed as unexplained.
- **No outline is taken from uv's closures.** A closure's box is not its ground's edge (decision 226).

## 5. Methods to read (leads, unread)

- **The Benthic Terrain Modeler** (Lundblad et al. 2006; Walbridge et al. 2018): broad and fine BPI into zones and
  structures. The scan's BPI is its first half.
- **Geomorphons** (Jasiewicz & Stepinski 2013): a landform per cell, with an adaptive scale (GRASS `r.geomorphon`,
  WhiteboxTools).
- **The British Geological Survey's two-part scheme** for seabed geomorphology (Dove et al. 2020): the shape first,
  then the named feature. It is close to levels 0-1, then the names.
- **IHO-IOC publication B-6** on undersea feature names: what a bank, knoll, trough or shelf is.
- **Vague places** (Montello et al. 2003; Jones et al. 2008): areas as densities with thresholds (plan 045 §2).
- **Scale-space blob detection** (Lindeberg 1998): mounds and basins at their own scale, a hierarchy by
  construction. It is for when a grid shows the knolls.

## 6. Asks

All answered by the maintainer on 2026-11-06.
- a. **The framing:** areas from the names' own occurrences, with the seabed as frame and edge, and knolls from marks,
  not from the grid (§1). **Answered:** "Agree, proceed", to areas from each name's weighted evidence and the mobile
  gears' effort, with the troughs, rises, shelf break and isobaths as edges (after the watershed was dropped).
- b. **What a "grunn" is on the west shelf.** **Answered:** the shelf off a headland, between two troughs. So the west's
  "-grunn" names are read as the shelf off their headland (Látrabjarg, Kópanes, Barði), bounded by the troughs on
  either side: a prior for their areas in step 6, beside their own evidence.
- c. **How the grid was made:** where Olex sounded, where GEBCO fills, and how it was smoothed (TODO 185's question for
  Julian Burgos). **Answered:** proceed without it. The work stays at 500 m, and the fine scale is treated as unknown.
- d. **How an area is held.** **Answered:** outlines at two levels (core, extent) and the membership by 500 m cell, as
  §2.4 proposes.
- e. **Who reviews the areas, and where.** **Answered:** the maintainer, on the bathymetry map.
- f. **Which gears' effort, and which years.** **Answered:**
  - **the gears:** bottom trawl, Danish seine, and the shrimp and Nephrops trawls; not the pelagic gears;
  - **the years:** all, 2007-2026, summed.
- **Two more answers on step 1:**
  - **Halinn:** "Straddles shelf and slope": a shelf-edge ground whose area overlaps both zones, as Torgið and
    Hampiðjutorg may too.
  - **The north-west edge:** the maintainer: "You may have to do a little digging here regarding what is best".

## 7. Not in this plan

- **The 30 km place rule of plan 044 stays** (the maintainer, 2026-11-06: "Leave it"). The four homonyms of decision
  286 stay one place each.
- **EUSM's habitat** (plan 045 step 4), tested 2026-11-06 at the maintainer's question (the study's `05_eusm.R`):
  - **Little substrate:** half the shelf and the ridge has none in EUSM (upper bathyal sediment, unsaid).
  - **No match with the names' words:** hraun names lie on rock 0.17, against 0.14 for other names; leir names on mud
    0.07, against 0.17.

  So it is no help at the names' scale; at most a coarse layer for levels 0-1, beside the troughs and the effort.
- **Publishing** the areas outside MFRI: plan 001's boundary; the names' sources are internal. The terrain classes
  are another matter (§2.6).
