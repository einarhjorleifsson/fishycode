# 074 — The sea-chart names on a map you zoom through: each name read from every chart, one best place for it, shown at zooms of our own choosing

**status:** partly built — written 2026-11-11 at the maintainer's word ("Yes, draft it"), from what held up in plan 073's
trials and the measurements of decision 317; step 1 built as a study the same night (decision 318): the lettering at
every chart scale as the marker (§3 amended: "anything but a midpoint", every zoom), the rules tried and compared, the
one isobath out holding best so far; on 2026-11-12, at his word, the letter boxes first (decision 319): each name's box,
axis and angle at each chart scale read again and judged by him on a map of their own, the outlines redrawn from the
boxes he accepts; by 2026-11-15 the lettering read at all nine chart scales and reproduced box for box by fresh reads,
by the same day all nine frozen; step 1 revised 2026-11-15 at his word ("Yes, revise"): the lettering alone,
reviewed by Claude's look and then cards, the place a step of its own (1c); the aim revised 2026-11-15 at his word ("Yes,
revise the plan and start"): one best place a name, steady as the map zooms, shown at zooms chosen for our users, the
outlines a later step if wanted; step 7 revised 2026-11-15, night, at his word: the display zoom and the traffic jam apart; step 8 added 2026-11-16 at his word: guides from the new sources; step 9 the same day: curated lists from several witnesses (wrecks, harbours, aids, bottom type), revised the same day at his word: the islands and skerries above water from LMÍ, the charts their witnesses, and the aids apart from the names, each feature listing the aids on it; step 11 drafted the same night: LMÍ's names on the names map (its Breiðafjörður pilot built the same night), the wreck list built as a prototype in the study the same day, a plotter's marks added to it, and at his word kept standalone, outside the targets flow, its conflicts listed, not resolved; amended 2026-11-17 at his word: asks k, l and n parked for another plan, the harbours and the bottom type out of this plan, the wreck list into fishycode, the submerged rocks at LMÍ's position, the ridge's volcanic systems by ÍSOR's names with his as synonyms; step 11 extended to the whole coast the same day; step 12 drafted 2026-11-19 at his word: one curated table of what the map shows, the names of the charts, LMÍ and ÍSOR, the wrecks and the aids, told apart by type, Trackwell left out; asks u-y settled the same day: the table `marine_feature`, the page 132 on ogis · **2026-11-11** · **see:** plan 073 (and its
decisions 315, 316, 317), plans 070 and 071, decisions 300, 302 and 304 (the main grounds and deeps), the local-features
study (`$FISHYDATA/archive/2026-11-11-local-features/`, scripts 56-70, its `notes/part_endings_glossary.md`) and the
örnefni map study (`$FISHYDATA/archive/2026-11-08-ornefni-map/`), TODO 199

Drafted with AI assistance (Claude) on 2026-11-11, step 1 revised with it on 2026-11-15, the aim revised with it the
same day, and step 12 drafted with it on 2026-11-19; a person has not yet checked it.

**The aim, revised 2026-11-15.** The maintainer: "Is the process not that we find the "best location" for a particular
name, rather than the outlines. I am thinking e.g. when it comes to these maps, users are going to zoom in and out. What we
should be building is a "smoothed" experience for the user. So e.g. a name for lets say Eyjafjarðaráll does not jump back
and forth just because that is where the location was on the sea-charts at different 1:xxx"; and "the decision of when a
name appears and disappears is not dictated by when that happens in the sea-charts. you see the objective of the sea-chart
is different than ours. That is e.g. why Díönuboði appears at a very coarse map level in the sea-charts. We may actually
let it appear at a higher zoom level." So:
- **A feature** is a name and every lettering of it, on every chart that prints it (step 2).
- **Its best place**, one, held at every zoom: a point name's anchor (step 1c); an areal name's place from its letterings,
  the finest chart's lettering first; its angle from the shape of the landscape (the maintainer: "And yes the shape of the
  landscape should dictate the angle of the name"), the feature's own axis on the depth model, the charts' angles a witness;
  a long feature perhaps a line along its axis (step 3).
- **When it shows** is ours, not the charts': a chart is made for navigation, so a hazard such as Díönuboði is printed on
  the coarsest charts. When a name appears is chosen for our users, by the feature's kind and extent (step 5).
- **A hierarchy** (the maintainer: "I am also thinking if we need to think hierarchical here a bit (althouh i hate binary
  trees) - But you see we know Syðra-hraun in Faxaflói is reasonably big. But then within that we have more detailed
  örnefni. I would argue that Syðra-hraun appears at a lower zoom level than the more detailed feature within it"; "How
  extensive a feature is can be partially judge by the "font" size use, if there is spacing in letters, etc. That is
  guide, not a rule"): each feature's extent, guessed from its letterings (the letters' height on their chart, spaced or
  not, the lettering's length, the coarsest chart that prints it), the depth model to temper it; a feature within another
  shows no earlier than the one that holds it; a name shows from the zoom where its feature on the screen can hold its
  label (step 3).
- **The check**: what a user's eye would jump as the map zooms, now and with one place a name, in screen pixels; a chart
  lettering far from the chosen place (12 mm on its own chart) is the maintainer's to judge.
- The outlines of §3, the vocabulary, the parts and the relational names (the steps 2-8 as written on 2026-11-11) are kept
  as later steps, if wanted; the sections below describe them as written.

**Measured** (by Claude, 2026-11-11, decision 317; no person has checked the counts):
- on the chart's labels as the only judge, the extent by relative relief at 16-32 km fits best for every kind: highs on
  the depth (an areal label inside its outline 0.93, no sibling label inside 0.91, no low's label inside 1.00), lows on the
  depth turned over (0.90, 0.95, 1.00), slopes on the slope in an ellipse across the band (0.86, 1.00, 0.86; 7 names);
  neighbourhoods of 1-2 km fail (fewer than one label in ten inside);
- no single scale draws every name: at 32 km 64 of 339 highs get an outline, on finer scales the label falls outside;
- on the maintainer's reviewed mound the best of these overlap it by 0.83-0.86 (his own rule 0.93);
- the Olex grid's sources show as blocks of their own anisotropy, and their marks (tracks, block edges) spoil the
  ruggedness at 150 m; neither a fine-to-coarse ratio nor the smoothest direction removes them;
- the endings of the names differ by region (the north-west's oddi, tota, hali; the east's fles, flak; Breiðafjörður's
  brot, straumur, flaga), and the charts carry a family's whole (-grunn) while the parts sit in the other sources.

**Assumed:**
- that a chart name's label marks its feature, "a little off" at times (the maintainer), so that a scale chosen by the
  label is the feature's scale. The labels then no longer score the outlines, and the rings, the maintainer's reviewed
  mound and his review are left to judge them;
- that the relief surfaces, on cells of 200-1,600 m, are little touched by the Olex grid's merge marks. Seen on the
  pictures, not measured;
- that an ending's meaning in the landscape holds within a region. The maintainer's glossary gives the words; what each
  means on the seabed is to be measured, region by region;
- that the main grounds and deeps are right where the charts and depth model put them. They are the base, not tested
  here.

The maintainer, 2026-11-11:
- "Your anchor is of course the sea-chart names - the angle of the name gives you a hint of the rough shape / outline.
  "zoom" levels matter here. Note thought that in some cases the names can be a little off the feature";
- "Add to plan 074 - think about how we can cleverly interactive proceed with things, once we get to that point. And
  also keep in mind that we already did some reasonable job on the main grounds and deep - do not throw everything done
  so far down the drain";
- "Your current ground truth is the sea-chart labelling of placenames and the olex model";
- "the seabed lows should be just as much of a focus as the seabed highs here. given we are now thinking "glbally"";
  "and then you have the in-betweens, like Hvalbakshalli. Suðurkantur";
- "the ban i put on trying anything along the coastal areas is now lifted";
- "There is a problem in olex - some of the ruggedness comes from merging different datasources of different quality";
- on the endings: "-grunn, -flak, -tota, -xxx, .... are endings that refer to different part of a shallow area (relative
  to a deep area)"; "you may then have a different system of -endings in the north-western system, local lingos"; his
  glossary of the parts and of the lows, and the motives (below).

## 1. What is kept

The main grounds and deeps of the örnefni map (the chart's broad and finer areas, the bays, built from the charts and the
depth model: decisions 300, 302, 304; plans 070, 071) are the fixed frame. Every feature this plan draws nests in them
as a child, or beside them. Where an outline contradicts one of them (Vestrahraun and Syðrahraun, parted by a straight
line through the Vestrahraun patch: decision 317), that is a question for the maintainer, never a move of the base.
Trackwell stays out of every step (decision 316). The coast is open (the ban is lifted).

## 2. Each name's class, and how each class is placed

| Class | Examples | Placed by | Its witnesses |
|---|---|---|---|
| landform whole | -grunn, -banki, -djúp, -dýpi, -áll, -hryggur, -hraun | its outline on the landscape of its kind (§3) | the rings, the reviewed mound, the review |
| landform part | -horn, -nef, -tota, -hali, -oddi, -flak, -haus, -kantur, -brún; -kriki, -botn | its place on its whole's outline (§4) | its own sources' positions, weakly |
| relational | -sund | between the mainland and the place its first part names (Grímseyjarsund: from the mainland to Grímsey) | the two places' positions |
| hydrographic | -röst, -straumur | off the headland its root names, over the sill or narrows; its extent needs current data (§5) | a tide or ocean model |
| motive | -garður (Rósagarður, Kartöflugarður: the biota the trawl brings up; Töfragarður), Hampiðjutorgið (torn trawls), Kirkjugarður (lost ships?) | its sources' positions | biota records, ruggedness, a wreck list |
| hazard | -sker, -boði, -flös | a point | the chart's ring, the shoal on the grid |
| route, mark, regulation | -slóð, -mið, regulated areas | their own sources | none here |

A name's class comes from its ending (script 65's generics), with the chart's class where the chart has one. A name may
change class region by region if its ending means another thing there (step 3 measures it).

## 3. The wholes: relative relief on the landscape of their kind

- **Surfaces:** a high on the depth, a low on the depth turned over, a slope on the slope; flatness as a second for highs
  (flat-topped banks). Ruggedness waits for §7.
- **Candidates:** for each name, the outlines at circles of 4-32 km and ellipses of 8-16 km at the label's angle or the
  feature's own axis, by four rules (above zero, half the top, the area's elbow, the split at a neighbour rising a
  quarter of the top), from the top nearest the label (an areal name) or the place (a point name).
- **The scale chosen by the label** (the anchor): of the candidates that hold the name's label and no label of another
  name of its kind and scale, nor of the other kind, the one first by a fixed order: split before half before elbow,
  the broader scale before the finer, the circle before the ellipse. A name with no such candidate is left for the review,
  with its nearest candidate shown.
- **Confidence:** how many rules and scales agree on the chosen outline (their overlap), the label's distance from the
  feature's top, and whether the ring and the reviewed mound agree.

**Amended 2026-11-12 (decision 318).** The label's middle is not the anchor: the anchor is every lettering of the name at
every chart scale it is printed at, the boxes of its letters (the maintainer: "anything but a midpoint"; "you have to
check every zoom level for every placename"). All names lettered at a scale compete for the seabed at once; the cut is the
charts' standard isobath one level beyond the first holding eight tenths of the lettering; a knoll is its own ground to
its key saddle; a high and a low overlapping are parted by the Olex curvature. The candidates of this section, scale
chosen by the label, were tried first and dropped.

## 4. The parts on their whole's outline

The maintainer's glossary (the study's `notes/part_endings_glossary.md`): horn a corner (elbow), kantur and brún an
edge (slope), nef a nose (protrusion), oddi a point, hali a tail, tota "as in tongue, tail", flak "most like the end of
something", haus "the head of something ... may be wrong here"; and of the lows, kriki a corner of a depth, botn the
deepest part, pollur a local pool, hola and gat a hole, dalur a valley, gjá a narrow steep channel, gil a small canyon,
áll "normally something narrow, but Kolluáll is certainly not", djúp a deep beside its grunn, "not really a steep thing".

- **Families:** one root, a whole and its parts (Gerpis-grunn, -flak, -tota, -öxl, -dýpi), from the charts and every
  source but Trackwell, the chart names' derivatives that trial 2 left out read back as parts.
- **Each part's measures against its whole:** how far toward the end along the whole's long axis, how near its edge,
  how sharply the outline or its contours turn there, its depth and slope against the whole's.
- **Each ending's signature, region by region:** the measures of its parts where the whole is drawn; where an ending
  shows none (flak, haus may), it is reported as such and its parts placed by their sources.
- **Placing:** a part's outline is the piece of its whole that its signature picks nearest its sources' positions (a
  corner, a lobe, a tip, the edge band).

## 5. Relational, hydrographic and motive names

- **-sund:** the water between the place its first part names and the nearest mainland coast, at the scale the place
  sets (an island's size; Grænlandssund between countries).
- **-röst, -straumur:** placed off the headland its root names, over the shallows or narrows there; drawn only with a
  current model's peak speeds (an MFRI model if one exists, else a global tide model, which is a download: asked first).
- **Motive names:** their sources' positions; the motive's witness where data exist: the bycatch of corals and sponges
  in the surveys and observers' records (script 70 found Kartöflugarður near Geodia records), ruggedness for torn gear
  (after §7), a wreck list for losses.

## 6. The regional frame

The maintainer's account of the forces: volcanic spreading ridges, rugged, the contrast falling outward; glacial carving
of the fjords and the cross-shelf deeps; glacial-river sediment smoothing some regions (Selvogsbanki). EMODnet's
sea-floor geology for Iceland (in `vernd_i_hafi`) maps the units; the regional contrast comes from the grid. They serve
as strata: does the chosen surface, scale or rule differ by force? Thresholds that are absolute today (the 40 m of the
mounds elsewhere) are set against the region's own contrast.

## 7. The Olex grid's sources

Its sources are visible as anisotropy blocks with straight edges (decision 317). Before ruggedness is used (the hraun,
the texture of -hryggur, torn-gear grounds), the blocks are either segmented from the grid (the anisotropy and the
roughness level, edges kept straight) or taken from their maker's footprints: the grid's provenance note already lists
the question for Julian Burgos.

## 8. The review: interactive, on the map

- **The lettering (step 1):** cards on what Claude's look at the candidates leaves open, one question a card (step 1),
  never a whole chart's boxes for verdicts.
- **Where (the outlines):** on rebelrebel's viewer, one verdict per proposal (its `rr_serve(verdicts = )`, plan 071's machinery):
  accept; another nesting level; wrong feature; split; merge; another name; a note. The answers go into a ledger under
  `$FISHYDATA` (internal), which re-enters as anchors: a cycle broken by a person, as the record's rule asks.
- **What first:** where the rules disagree most, so each answer tells the most; where all rules and witnesses agree,
  accepted in bulk on one answer.
- **In what order:** region by region, broad to fine (the wholes before their parts).
- **Live:** an outline takes seconds, so the rules rerun after each answer, and the answers recalibrate the choices
  (the rule order, the scale order) by class and region.

## 9. Steps

1. **The lettering** (the maintainer, 2026-11-12: "focus first and foremost on getting the bbox of each örnefni at each
   1:xxxx ... The boundary of areas would then come later", decision 319; 2026-11-15: "I think we are mixing two things
   here: 1) The digitization of the names, 2) The precise location ... Think we should stick with that now"): each name's
   box, angle, axis and text at each chart scale, and every text in one outcome; no outline, and no place beyond the box
   (the place is step 1c). Built as the study `$FISHYDATA/archive/2026-11-11-named-features/`.
   - **Read** (done 2026-11-14): all nine chart layers (1:2 000 000, 1:1 000 000, 1:300 000, K42 1:160 000, 1:100 000,
     K44 1:70 000, the approaches 1:35 000-1:50 000, the harbour plans 1:15 000 and 1:10 000). Each is stitched into one
     picture by its coordinates, read by the recognizer in overlapping tiles turned in 5-degree steps, and its spaced
     lettering chained; every listed name is in one outcome; one frozen set of scripts reads all charts. Read again from
     scratch, top down and bottom up (2026-11-14/15): the same box for every name on every chart, in either order and
     against the day's reads. The exception is 1:1 000 000, whose fresh mosaic took in six more windows: the same names, some
     boxes moved.
   - **The read's own rules** (the study's `read_rules.R`, one copy used by the freeze, the candidates, the checks and the
     map since 2026-11-15):
     - a chart's note or abbreviation read in no list (digits or punctuation, under four letters, short capitals, the charts'
       margin words);
     - a piece of a name (a small first letter);
     - for lettering no name matched: the charts' notes and legends, and grey chains that do not end as the charts' names end
       and read as no words (K42's grey random capitals).
     They are outcomes of the read and leave the frozen table, unless the maintainer judged the box. 1:300 000 was frozen
     again with them (17 boxes left out, all notes or pieces).
   - **Review, chart by chart, broadest first:** the checks sort each chart's boxes (29) and list its candidates (36: a box
     doubted, a listed name not found, a spelling, a name dropped by a rule, lettering with no name). Claude looks at every
     candidate first, on crops, and settles what the witnesses settle. What is left goes to the maintainer as cards (34,
     35: one question a card, answered blind, Claude's view shown after), never a whole chart's boxes. 2,440 candidates
     wait after the read's rules settled 2,273 of 4,713 (1:100 000 727, K42 388, K44 202, 1:35 000-1:50 000 265, 1:15 000
     88, 1:10 000 770).
   - **Accepted:** a box judged right, on a card or on the map, or by Claude's look where the crops settle it (said so in the
     frozen table's outcome); a box he saw on a map and left unmarked, if it passes the
     read's rules. 1:300 000's "IS.Sir" and "YS.Sh" passed by silence before those rules were mended. A box he never saw is
     "not judged", never accepted by silence (28 with the reviewed read as its third argument).
   - **Spelling:** each chart's own print is kept (the maintainer, 2026-11-13: "Keep each chart's own print"; "I suggest we
     keep account of the different spelling"), with the forms at the other scales beside it when the charts are joined.
   - **Frozen** per chart once every box is judged or accepted (28):
     - 1:2 000 000 (round 4, 2026-11-12; round 5, 2026-11-15, from the fresh read, 233 kept, Íslands-Færeyjahryggur boxed);
     - 1:1 000 000 (round 2, 2026-11-15, from the fresh read);
     - 1:300 000 (round 1, 2026-11-12, and again with the read's rules; round 2, 2026-11-15, from the fresh read, 1,032 kept);
     - 1:100 000 (round 2, 2026-11-15): not reviewed whole, so a box with no answer is "the checks confident, not
       judged" (3,100), and its doubted land names are kept as read, "not checked" (392; the maintainer: "Keep, marked
       unchecked"); of 71 names found lettered but not boxed, 31 boxed (13 from the read's own letters, 18 drawn by hand along
       their letters), the rest already boxed or fragments, 2 for a card (4,018 kept);
     - K42 (round 1, 2026-11-15, 561 kept): answered nothing by him, so its verdicts are Claude's look (84 candidates) or the
       witnesses' (48 boxes at sea, the same name in natt.is, the place-name map or a frozen chart); its 16 names lettered but not
       boxed boxed (4 from the read's letters, 11 by hand, 1 already part); 2 for cards;
     - K44 (round 1, 2026-11-15, 252 kept): the old Danish sheet, its leading-line texts and margin views left out; 55 candidates
       looked at, its 5 names lettered but not boxed drawn by hand, 1 for a card;
     - the approaches 1:35 000-1:50 000 (round 1, 2026-11-15, 1,212 kept): 76 candidates looked at, 65 boxes settled by the
       witnesses, its 6 names lettered but not boxed boxed (4 by hand), 1 for a card;
     - the harbour plans 1:15 000 (round 1, 2026-11-15, 56 kept) and 1:10 000 (round 1, 2026-11-15, 509 kept): 17 and 191
       candidates looked at, 16 and 152 boxes settled by the witnesses, none lettered but not boxed, none for a card; the
       plans' legend heading over their lists of quay names ("Nöfn á bryggjum") added to the read's note words.
     Every chart scale is frozen. The five items left for a card answered by the maintainer the same day (Líney,
     Króksfjarðaráll and Áll boxed, "Store" joined to the line under it as Store Örfersey-Dyb, 1:100 000's printed J Ö R Ð U R
     boxed as part of Breiðafjörður, "a hic-up by the cartographer"); none left for a card.
     The read's all-capitals rule refined the same day: a short all-capitals word is a note unless it has an Icelandic
     letter or is a word of the charts' own names (9 of 10 real names it had taken kept, none of 11 notes).
   *Check:* on every chart, every text and every listed name in one outcome; every frozen box judged, or accepted by the
   rule above; the fresh reads equal to the frozen ones, except where the mosaic differs.
1b. **The lettering into the pipeline** (the maintainer, 2026-11-12: "is this table in the end not something that will have a
   home in fishydata, aka like staged -> curated approach we have been using?"; "yes, write the promotion step into plan
   074"), chart by chart once each is frozen: the rules have held since the fresh reads of 2026-11-15 (they changed each
   round before), so 1:2 000 000, 1:1 000 000 and 1:300 000 may go first. Built so far as a study,
   `$FISHYDATA/archive/2026-11-11-named-features/` (scripts 18-39, 53); then, by the project's layers:
   - **raw**: the chart windows (the WMS images of gis.natt.is, 1024 px at twice print scale, on the grid from 30 W and
     68 N) under `raw/external/sjokort/<series>/`, fetched by a script in `dump/`, with a provenance note: one home, where
     they now sit in two studies (the chart-names-coast study's `img/` and this study's `out/scale/<series>/windows/`).
   - **once**: a chart's read (the mosaic, the recognizer in 5-degree turns, the spaced lettering, the matching, the
     marks). The recognizer is macOS's own (Vision), slow and not the same on every machine, so the read is made once
     per chart, reviewed by the maintainer, and frozen as an input; nothing after it needs a Mac.
   - **staging** (source-shaped, one chart at a time): `staging/sjokort/<series>/` with the labels (the box along its own
     direction, the angle, the axis, the text read, how alike, where the name came from: listed at that chart, known
     elsewhere, spaced lettering, read in no list), the position marks (crosses, lights' stars, linked or not), and every
     text read in one outcome.
   - **curated** (merged-shaped): one table, one row a label a chart (the name twice where two charts letter it, the
     `chart` variable saying which), each with the nearest label of the same name on every other chart (its row, the
     distance, the angle difference), the boxes never merged; under `curated/reference/` (a `chart_names` table and its
     marks), written by `write_curated()` with the geometry as WKB and its CRS stamped. The study's
     `25_labels_all_charts.R` is its prototype.
   - **overrides/**: the maintainer's verdicts per chart (on the boxes, the unmatched texts, the marks) as the reviewed
     input that re-enters the build: a cycle broken by a person. The chart names are public (Landhelgisgæslan's charts),
     so the public repo holds them; a note naming an internal source stays under `$FISHYDATA`.
   *Check:* every chart's labels, texts and marks in one outcome in staging; every curated row traceable to its chart's
   frozen read and to the verdicts it passed; `check_bookkeeping()` and the provenance stamps as for any curated table.
   *Built 2026-11-15, the lighter step* (the maintainer: "I thought as long as we did have a list of all the örnefni, with
   coordinates and writing angle we would then just need to build a single file from those"; decision 323): the windows in
   `raw/external/sjokort/` (`dump/sjokort/`), and `curated/reference/chart_names.parquet` (target `chart_names`) built
   from the nine frozen tables, 8,207 labels, equal to them row for row. Staging from the read and the verdicts as
   `overrides/` wait until the freeze itself is wanted in the pipeline.
1c. **The place**, after step 1 (the maintainer, 2026-11-15: the digitization of the names and "the precise location"
   are two things): where each named feature is, apart from where its name is lettered. A chart letters a name 6-8 mm
   beside its feature on its own paper, so Díönuboði's labels lie 12.7 km, 2.4 km and 0.8 km from its shoal at 1:2 000 000,
   1:300 000 and 1:100 000.
   - The point names (a rock, shoal, skerry, island, stack) anchored to their feature. A prototype is the study's 54:
     natt.is's islet or point of the name, else the shallowest top on the Olex grid, with the harbour plans keeping their
     labels; built 2026-11-15 and parked. The soundings the charts print are a witness still to be read.
     Run again on every frozen chart (2026-11-15, "Yes, start 1c"): 1,110 point names, each in one outcome; tested against
     the harbour plans' labels of the same names (a plan letters within a few hundred metres): above water the anchor is
     nearer the plan's label than the coarser label in 112 of 153, submerged in 37 of 77, so for rocks and shoals near the
     coast neither the grid's top nor natt.is's point beats the label by more than the witness is good for; the printed
     soundings are the next witness.
     The printed soundings read (the study's 66, four charts, in metres, 71-88 % within 25 % of the depth model but K44's
     45 %): the shallowest within reach of the label lands nearer the plan's label in 23 of 76 pairs, the grid's top in 41,
     so as a shallowest-within-reach rule they are no witness for a rock's place. The charts' rock crosses (the study's 20):
     10 of the 77 pairs have one linked to their name, lying 0.6-2.7 km from the plan's label; no witness either. The point
     names keep 54's anchors with their basis and offset, for the maintainer's look.
   - The wholes' outlines by §3, moved here from step 1.
   - The Reykjaneshryggur naming trial (2026-11-14, the study's 43-52, with the other sources' names) belongs here too, as
     a trial, not as step 1.
2. **The features** (the aim as revised): each name's letterings across the nine charts grouped into features, the same
   name near enough to be the same thing. *Check:* every lettering in one feature; every feature with its charts, its
   coarsest and finest, and the spread of its letterings (km, and mm on its coarsest chart); a name printed twice far
   apart on one chart two features.
3. **The extent and the hierarchy**: each feature's extent guessed from its letterings, a guide not a rule (the letters'
   height on their chart, spacing, the lettering's length, the coarsest chart that prints it), tempered by the depth model;
   which features lie within which. *Check:* every feature with an extent and its basis; every containment listed, a
   feature in two holders the maintainer's to judge.
   *Built 2026-11-15* (the study's 68; the maintainer: "I guess the extent is just a bbox"): each feature's extent a box
   round its letterings (each widened by half its length), a point name's capped round its anchor; one feature holds another
   when its box is twice as large and covers a third of the other's, a feature at sea held only at sea or by an island.
   At sea 1,732 of 2,101 held, 213 held by two of a like size; Faxaflói holds Syðrahraun, which holds its renna and kriki.
   The maintainer: "As said, this should not necessarily be a binary tree, more like a mosaic overlap. But then again this
   exercise is largely to get the place name rough in order, so i guess we are ok": a feature may lie in several boxes, and
   step 5 shows a name no earlier than any box that holds it, not its nearest holder alone.
   *Grown 2026-11-15* (the study's 72; the maintainer: "Yes, grow them"): a long feature's line (step 4) followed outward
   along its crest, trough or steepest slope until it stands out less than 0.3 of its contrast on its own line, or no depth,
   with stops by kind (a trough off the shelf, a bank's crest too deep, a slope at twice its line); its box unioned with its
   letterings'. 60 of 61 grown, 26 to more than twice their line; Reykjaneshryggur 21 to 470 km, Reykjanes to the depth
   model's edge, its name from zoom 5, holding 40 at sea. A long diagonal line's box takes in corners it never reaches (48 of
   355 held names over 20 km from their holder's line): a corridor along the line is the mend, not made.
   *Towns and their fjords apart* 2026-11-15 (the maintainer: "where is Vopnafjörður?", "There are more of these fjord
   missing"): the read's lists class a fjord's own letterings as its town's (or farm's), so a fjord named for a town stood
   on land; a land-listed lettering at sea with a water ending (-fjörður, -vík, -vogur, -flói) is now the water's, and a
   town's letterings on land a feature of their own (61 letterings, 39 names; 15 fjords and coves newly at sea). A fjord's
   name still comes late (zoom 8-10): its box is its short fine-chart letterings. A fjord's extent as its enclosed water was
   tried (the study's 74) and fails for wide and long fjords: not wired, an open question.
   *A fjord's water by rays* 2026-11-15 (the maintainer: "Yes, try it"; the study's 76): from each sea cell 36 rays, each
   reaching 8 times the cell's distance to shore; a cell is enclosed where 75 % of them meet land (a fixed reach finds no
   Breiðafjörður; at 0.65 the water runs out into the bay). The sea is shared among the fjord, bay and deep names, each cell
   to the nearest along the water; a fjord's water is the enclosed water it owns that holds its letterings' middles, pieces of
   one name in touching water one fjord. Of 112 fjord features, 102 have their own water, 4 are joined into 2 fjords and 6
   are open water (the wide bays keep their larger letterings' box). Checked by eye in six windows; Eyjafjörður 49.8 km,
   Seyðisfjörður 11.6, Hafnarfjörður 4.2. The box is the union of the letterings' and the water's: 62 fjords come in
   earlier, most by half a zoom to one and a half (Seyðisfjörður 10.2 to 9.0).
4. **The best place** of each feature, one for every zoom: a point name's anchor (1c, a harbour plan's label where one
   letters it; an island's or a skerry's above water LMÍ's position since 2026-11-16, a submerged rock's since 2026-11-17, step 9); an areal name's finest lettering (ask i), level unless a chart turns it (then its angle the feature's own axis on the depth model at the scale
   of its extent (the maintainer's word), the charts' lettering angles a witness. A lettering more than 12 mm from the
   chosen place on its own chart is listed for the maintainer.
   *Begun 2026-11-15* (the study's 69): the axis of the depth model across a feature's box agrees with the charts' turned
   letterings within 20 degrees in 84 % at coherence 0.5-0.7 (boxes of 5 km or more), but fails for deeps across the shelf
   (the continental slope in the box) and small bays. The maintainer: "we could roughly find the deepest line for
   Eyjafjarðaráll - then the place could be a point somewhere along that line": a trough's deepest line, a ridge's or bank's
   shallowest, followed on the depth model; the place on it, the angle its direction there. A group's extent (Vestmannaeyjar)
   the box round all its islands (the maintainer).
   The lines built (the study's 70): a low's deepest, a high's shallowest, a slope's steepest (the maintainer, of
   Suðurkantur: "we follow the axis of the steepest gradient"), section by section across the longest lettering, against
   the flanks; on 426 features at sea with a box of 5 km or more, a line for 138, their angles within 20 degrees of the
   charts' turned letterings in 59 of 63, the places 1.7 km from the finest lettering at the median. Bays, fjords and
   the other kinds not yet; the groups' extents not yet.
   Then, at the maintainer's word ("I am wandering if we are not taking this angular labelling too far ... a simple
   horizontal label would suffice"): a name is turned only where a chart turns its lettering, its angle the landscape
   line's; a name the charts letter level is drawn level at its finest lettering, with no line. A long feature's name
   lettered at far parts by different charts is one feature (Norðfjarðardjúp). 60 names turned; the rest level.
   After the south coast's corrections (Reynisdjúp off the shelf, Skaftárdjúp east of its deep): the line finder no longer
   sets a place, too fragile (each fix moved other names); the place the finest chart's lettering (from 1:100 000 up for a
   feature of 10 km or more), the angle where a chart turns the name the landscape line's if within 30 degrees of the finest
   turned lettering, else that lettering's. The maintainer: "part of the problem we have is our sense of the scale of a
   feature. E.g. Reykjaneshryggur is generally considered to be a feature that extends the whole ridge within the Icelandic
   EEZ": a long feature's extent from its crest or trough followed until it stops standing out, not from its letterings.
5. **When a name shows**, by our own rule (ask j): from the zoom where its feature on the screen can hold its label, and
   never before any feature whose box holds it (a mosaic, not a tree); names that would collide at a zoom give way by rank.
   *Four rules prototyped side by side 2026-11-15* (the study's 71 and 73; the maintainer: "what dictates when a feature first
   appears?", "Yes, prototype them side by side"), chosen on the map: a, the box alone; b, the box moved by its relief for its
   size (twice one zoom earlier); c, moved by its letters' height against its chart's middle size; d, a's order with 40 px of
   room round each name. Names at sea by zoom 7: a 90, b 109, c 162, d 41. b favours boxes over the shelf edge (the slope's
   relief), c a fjord lettered large on a fine chart (the height relative, not in metres). A name comes in at a whole zoom
   (MapLibre's filter on the tile's zoom), 5.25 from 6.
   The maintainer: "c reads best, but measure letter height in metres"; "some balance is needed here": c's height now on
   the ground (a coarse chart's lettering taller than a fine chart's), twice as tall half a zoom earlier, 2 at most; e, c
   with a name in every 256 px square of the screen where one is due within two zooms. Names at sea by zoom 5: c 82, e 83;
   by 10: 572 and 622. c alone fills the east (a coarse chart letters every region); e acts from zoom 9.
   *e chosen* (the maintainer: "e it is, keep it as the zoom rule"); the map draws it alone. Names printed in capitals
   alone drawn in ordinary case ("Get rid of the all caps"), the print kept in the curated table.
6. **The map**: each feature at its one place across its zooms; the jump a user sees, before and after, measured.
   *A first form 2026-11-15* (the study's 71, port 4834; the maintainer: "Can you redraw the map from scratch, only showing
   what we are dealing with now"): one name a feature at its place, the long features turned to their lines, shown by the
   interim step 5 rule (the box on the screen as long as the name, never before a holder). A large feature's finest
   lettering is a poor place (Eyjafjörður at its head, a harbour plan's): ask i.
7. **The review**, on the map, region by region (ask b), the maintainer's verdicts feeding back.
   *The names editor begun 2026-11-15* (the study's 75, port 4836; the maintainer: "If i click on a name i can move it",
   "i can change the angle", "this type of map does not have to be done from within rebelrebel"): a click shows where each
   chart printed the name, the name drags and turns, each save a row of the maintainer's edits (append-only), read by 71 as an
   input; a revert goes back to the computed place.
   *The zoom by hand and the first fixes from the map* 2026-11-15 (the maintainer: "question is also if i could upgrade or
   downgrade a zoom level of a feature. although that invites the problem that i will not be consistent"; "Add earlier/later
   zoom buttons to the names editor? - Yes"): a name a whole zoom earlier or later, the rule's zoom kept beside it, a name it
   holds never before it; the hand zooms read back by kind (the study's 77), three or more of a kind all one way a rule to look
   at, so the edits teach the rule rather than replace it. The editor's background is the depth model ("I will need the depth
   model as a background"). His first two finds on the map were pieces of letterings kept as names: a word cut by a chart
   window and completed as a fjord's name (Reykjafjörður, on land), and the first letters of a spaced fjord name (Reyd). A
   search found five more of the like (lines of one name kept apart, a second box on a hand-boxed name); each read from its
   crop with a witness, 1:300 000 and 1:100 000 frozen again, `chart_names` rebuilt (8,207 to 8,203 labels), the map's names
   6,014 to 6,005.
   *His edits teach the place* 2026-11-15 (the maintainer: "Big names at middle"; 84 edits, "this was a really useful way to do
   things"): he moved large features' names toward their middle; from a box of 30 km his place lay a median 10.3 km from the
   finest lettering and 5.0 km from the box's middle. A box of 30 km or more now places its name at its box's middle, at sea
   (the study's 78), but where its longest lettering is a town's printed at sea, whose box is a coarse chart's label; the fjord
   water's and the line's middles did worse than the box's. A chart's misprint (K42's Bjarneyjaáll; on 2026-11-16 the 1:1 000 000's Héraðsdjúp, Héraðsflóadjúp
   on the other charts) is named as meant on the map and kept as printed in the curated table. Names that grow with the zoom are on trial in the editor.
   *No two names meeting, at any zoom* 2026-11-15 (the maintainer: "looks like a traffic jam"; "Is the problem that we really do
   not [have the] extent of a feature to begin with"; "it has to work "globally" within the Icelandic EEZ ... at different zoom
   levels"): the boxes are not extents (807 of 952 names at sea rest on their letterings alone; on the south-east shelf a
   ground's box shares up to 73 % of its area with the deeps beside it), and the zoom rule let names overlap everywhere (at zoom
   6, 148 names in the EEZ and 688 overlapping pairs). Sharing the sea among peers (the names first lettered on the same chart)
   was tried (the study's 80) and set aside. Taken, from the literature on consistent dynamic labeling (Been, Nöllenburg, Poon,
   Wolff 2008/2010; Mapbox GL's first placement): each name a start zoom from which it is shown, greedily by importance (a hand
   zoom, the coarsest chart, the larger box), two names' rectangles ending their overlap at a zoom found in closed form, no
   extent needed (the study's 81): no overlap in any region at any zoom; names fewer (zoom 6: 22 in the EEZ, 8: 131). A name
   that holds back a peer waits for it when that one starts within a zoom ("Keep one-zoom wait"; all together put the
   south-east shelf at zoom 8.4). The editor draws no name over another, turned names along short straight lines.
   Grounds between turned deeps are turned with them below zoom 9 and level from 9 ("Try turning ground names along their
   banks"), and drawn smaller there; with them turned the one-zoom wait and the names' growth were dropped ("Yes, drop both"):
   the south-east shelf's grounds and deeps start side by side from zoom 5.6-6.3, and the map shows each name from its start
   exactly, fractions too (35 names in the EEZ at zoom 6, 146 at 8, none overlapping).
   The charts' classes no longer order the names ("we can not be constrained by something whose rule we do not have any
   knowledge of"), nor the letters' height or the boxes' holding; a label may be twice its feature's box, a level name
   may stand a line above or below its place; an island's extent is LMÍ's outline of its name, not its letterings (a
   median 4.8 times the island). The box still ranks by span, so a long narrow trough goes before a broad bay (Kolluáll
   before Faxaflói): outlines and their area in its place are put to the maintainer, and islands as a tier of their own.
   Tested and not taken: a long feature's area across its line (the study's 82) as its rank. Its aspect agrees with the
   charts (highs they turn 10.1, highs lettered level 5.0), and it puts Faxaflói at 4.93, but it ranks measured features
   against the others' boxes, which are twice their longest lettering, and 37 long features start later (Eyjafjarðaráll
   7.86).
   Tried too (the study's 83): an importance from outside the label with discrete isolation, as maps from OpenStreetMap do
   (Gröbe and Burghardt 2021). The isolation spaces the names (a fifth to a half as many wait); no importance at hand
   serves: the charts' ties, the effort rewards small names by busy grounds ("the effort map is not a prior here"), the
   letters' pitch still reads length, Icelandic Wikipedia has the bays, not the seabed. Where boundaries are unknown,
   others' ranks are set by hand (Natural Earth).
   *The display zoom and the traffic jam apart* (revised 2026-11-15, night; the maintainer: "There is a distinction to be
   made here - names overlapping (the traffic jam) vs zoom display"; "try then to complete whatever you can of the (revised)
   plan"). Until now one number did both: 81 turned every clash into a later zoom, so a name that deserved zoom 4.76
   (Faxaflói) was drawn from 6.08, and the editor showed only the result. Two steps, apart:
   - **the display zoom**, when a feature deserves its name: 71's rule (`z_rule`), the box for now, the maintainer's
     earlier and later buttons, hand ranks later (step 10). Judged on its own;
   - **the traffic jam**, whether the words fit: placement first, a level name a line above or below its place, a turned
     name sliding along its own line (one place a name at every zoom, as before), and a wait only where no place fits,
     recorded as the name's wait and its cause, never as its display zoom;
   - **in the editor**: both on a name (the zoom it deserves; from when it is drawn, and for which name it waits), and a
     switch that draws every name from its display zoom with overlaps allowed, to judge the hierarchy alone;
   - **measured**: the names that wait and by how much (724, a median 0.71 zooms, before the slide), and no overlap in any
     region at any zoom.
   Built the same night (the study's 75, 81, 71): the editor shows both and has the switch; 16 of 31 turned names slide, each
   choosing the spot with the least wait, its own and the rest's; 81 now reckons a turned name where the editor draws it (it
   had used a place up to 28 km off) and reads only computed places, so a pass repeats the last. Waits weighted by box 5 %
   less, 733 names waiting (724); Faxaflói still waits (6.06), its label at zoom 5.5 twice the bay: a question for hand ranks.
   The maintainer's answers, 2026-11-16: the hierarchy left as is ("Leave as is"); islands a tier of their own ("Yes"), placed
   after every name at sea, so none holds a sea name back (53 did; Vestmannaeyjar now from 11.43, his Earlier button where he
   wants it sooner); Reykjafjarðaráll named as meant, Reykjarfjarðaráll ("We have Reykjarfjörður"), and Héraðsdjúp as
   Héraðsflóadjúp; two island pairs on one anchor each (Haffjarðarey and Útey, Öxney and Örney) flagged, to check later.
   For his second review in the editor (2026-11-16, "My intent is to have a second go at the review and editing using this
   map"): the depth in rebelrebel's palettes (grey at 75 %), its relief off by default with a shade slider, any sea chart
   as a background (gis.natt.is's WMS, all at one scale per zoom band or one alone), LMÍ's island, skerry and rock names
   (natt.is) as dots named on hover.
   Lights, buoys and beacons apart from the names (2026-11-16; the maintainer: "lights should in the end be held as a separate
   entity / layer from the name proper"): an aid's lettering (the read's lights, or a characteristic such as Fl G 3s beside it
   where its chart letters the feature apart; the study's 84) forms an entity of its own, a light, never the feature's place
   or anchor (Kerlingasker's name had sat on its buoy); in the editor a layer of their own.
   Positions apart from labels (2026-11-16; the maintainer: "the position are in general a separate entity from where a label
   appears"; "the LMÍ location should overrule the location from the sea-charts"): measured (the study's 85), 448 point names
   stand at a harbour plan's label a median 275 m from LMÍ's feature; the official sources fetched (fishycode's dump/vegagerdin,
   natt, isor, vedur, gebco, emodnet, seafloor): the List of Lights in force read (546 aids at their listed positions, the
   study's 86; the map's lights a median 851 m from them, 87), ÍSOR's named troughs and seabed landforms, EMODnet Geology,
   GEBCO's undersea names; all on a map of their own (the study's 88). Not yet applied to the names.
   The sources mined for the names begun (the study's 89; paused 2026-11-16): ÍSOR's 28 troughs take 32 deep names, the named
   palaeo-channels 18, landslides and volcanic areas more. The maintainer's next step: guides, not limits by the letter, for
   the deeps (ÍSOR's troughs), the ridges' natural breaks (Reykjaneshryggur, Kolbeinseyjarhryggur), the fjords' outer limits,
   then the grounds between them, the bottom type (grab samples, cores, substrate maps) as a guide ("the deeps have in a lot
   of cases different sediment / substrate types than -grunn").
8. **Guides from the new sources** (revised 2026-11-16 at the maintainer's word: "Since we now have more data, the plan needs
   revising. But I guess you need to mine the new data in order to "see" which of it can be used in the plan and then potentially
   how"; "Not saying this should be used by the letter, just as guides"). The sources fetched that day (fishycode's dump/:
   Vegagerðin and the List of Lights, the national map service's layers at sea, ÍSOR's seabed, EMODnet Geology, Veðurstofan,
   GEBCO, GSFML, the USGS, the drill holes), mined by the study's 89 and 90. The order his: the deeps first, the ridges' and the
   fjords' and bays' limits, then the grounds between them.
   *Amended 2026-11-17* (the maintainer: "8.k - park, do it in a another plan", and the same for l and n): the deeps' split
   (ask k), the grounds' limits (ask l) and the large bays' outer limits (ask n) are parked for another plan (TODO 201); the
   measurements below are kept for it. The ridges and the positions stay in this plan.
   - **The deeps** (measured): ÍSOR's 28 troughs (BGR's in EMODnet are the same) hold 33 of the 64 deep names (half a name's
     line or more within); 24 troughs carry a name, 5 several (the north system, 8,244 km2: Húnaflóaáll, Reykjarfjarðaráll,
     Húnaflóadjúp, Skagafjarðardjúp, Eyjafjarðaráll, Fjallsdjúp); a trough split among its names by their lines (a Voronoi of
     the lines within it) gives each a part whose longer side is a median 0.89 of its box (quartiles 0.65-1.11). The 31 outside
     are inshore: fjords' channels, -renna, small deeps. A deep's guide: its part of its trough; outside, its grown line (72).
   - **The ridges** (measured): within 30 km of Reykjaneshryggur's line, 764 craters along 455 of its 470 km, 62 seamounts, 42
     volcanic ridges; of Kolbeinseyjarhryggur's, 206 craters along 189 of 223 km, 20 seamounts. A ridge's guide: the extent of
     its volcanic features; its mounds the seamounts and crater clusters (plan 073's mounds), some named (Eldeyjarboði,
     Steinahóll, Gullhóll on the one, Stóragrunn, Hóllinn on the other).
     Reykjaneshryggur's eleven volcanic systems and their mounds, worked through on 2026-11-16 (the study's 117-126; by Claude,
     AI, for the maintainer's review). ÍSOR's 121 craters there lie on 66 of the depth model's mounds (94 craters; the other
     27 on no mound of their own). The systems first took the maintainer's better names (Fagurhólar, Steinahólar and Gullhólar,
     Grjóthryggur, Fuglaskerin), and Claude proposed names for the four he left open. *Amended 2026-11-17* (the maintainer:
     "suggest we use the ÍSOR names for the volcanic areas - with my suggestion as synonyms"): the eleven systems take
     ÍSOR's names (Njörður, Fagurhóll, Steinahóll, Gullhóll, Stóri-Brandur, Eldeyjarboði, Grjóthryggur, Langagrunn,
     Geirfuglasker, Eldey, Reykjanes), his better names their synonyms (Fagurhólar, Steinahólar, Gullhólar, Fuglaskerin;
     Grjóthryggur is ÍSOR's own). Claude's four proposals are dropped; Boðagrunn stays his name for its mound.
     *Built the same evening* (the maintainer: "I am not seeing things like Steinahóll ... aka the stuff from ÍSOR"; the
     study's 131, by Claude, no person has checked the counts): every record of ÍSOR's five named seabed layers in one outcome
     (2,825: 2,348 numbered labels, 400 sites named as descriptions, 15 land lavas' edges under the sea and 5 named by their
     volcanic district, both by ÍSOR's own fields, 35 a witness on a chart or LMÍ name); 22 on the names map, the 18 volcanic
     areas as wholes (11 with a chart name inside, flagged), a line and three craters, in a layer of their own, his names
     their synonyms. ÍSOR's map reaches Kolbeinseyjarhryggur and the Jan Mayen ridge, but names features there only by
     number; the names SW of Jan Mayen are Orkustofnun's, on the map through LMÍ.
     Of the 66 crater mounds, 9 carry a top the charts name or a name he decided (Boðagrunn), and 47
     have no proposal, mostly deep and little fished. 11 names from the fishermen's logbook app are ranked as leads for
     unnamed mounds, kept in the study only (internal). The maintainer on those names: "in principle useless", because most tows run beside the
     systems; the exceptions are names whose use lies inside ÍSOR's outlines (Langagrunn, Stuttagrunn).
   - **The bays** (measured): Landhelgisgæslan's baseline encloses 1,491 of the 1,693 names at sea, a coastal belt, but its
     segments close the large bays between named points (Faxaflói Skálasnagi-Geirfugladrangur, Breiðafjörður Bjargtangar-
     Skálasnagi, Húnaflói Ásbúðarrif-Horn, Skagafjörður Siglunes-Ásbúðarrif, Eyjafjörður Flatey-Siglunes). A large bay's guide:
     the baseline's segment across its mouth; a fjord within keeps its water by rays (76).
   - **The grounds** (measured): the shelf inside the shelf break (ÍSOR's outline; 45 names lie beyond it, the 8 slope names
     within, slopes on the shelf), between the deeps' parts, outside the bays. The bottom differs as the maintainer expected:
     the troughs' grab samples mud-rich 50 %, gravelly 15 %, against the grounds' (within 10 km, outside the troughs) 28 % and
     33 %; the measured mud share a median 51 % against 6 %; EMODnet's substrate (1:1 000 000) mud or sandy mud under 43 % of
     the deeps' lines against 11 % of the grounds' places, coarse or rock under 9 % against 41 %. 30 of 126 grounds, banks and
     ridges have a terminal moraine within 10 km. A ground's guide: the sandy, coarse or rocky shelf between the deeps' parts,
     its edge where the bottom turns muddy (EMODnet's 1:250 000 and 1:50 000 substrate and ÍSOR's samples).
   - **The positions** (measured): a point name's position LMÍ's where LMÍ has its name, over a harbour plan's label (448 names
     a median 275 m off); the aids at the List of Lights' listed positions (546; the map's 110 lights a median 851 m off them,
     Grótta on its islet), apart from their labels; Landhelgisgæslan's 61 named baseline points; named volcanic points and
     geothermal vents as witnesses.
   - **The rank** (to test): with the deeps, the large bays, the islands and the ridges measured, an area may rank the names (the
     test of the study's 82 failed only because the rest kept a box twice their lettering); tested again once the grounds have
     their guides.
   - **In the editor**: the guides as layers for the review (the troughs and their parts, the shelf break, the moraines, the
     craters, the substrate, the aids).
   *Assumed*: that ÍSOR's troughs and EMODnet's substrate hold at the scale the names are judged at; that a deep's part nearest
   its own line is its share of a shared trough; that the bottom changes at a ground's edge. *Check*: every name at sea in one
   outcome (its guide and its basis, or none and why), the maintainer's verdicts on the map.
9. **Curated lists from several witnesses** (added 2026-11-16 at the maintainer's word: "we have a list of wrecks in the new
   data. now these wreck list can by matched against any of the other wreck list we have in already gathered datasource. This
   way we have more than one witness -> here the aim is to come up with a curated wreck list. similar as we will have a curated
   harbour list, curated list of lights, beacons, curated sediment list (some of those infos will come from the sea-charts)").
   Each a reference table of fishycode (reference/<list>/ to curated/reference/<list>.parquet, as plan 075's landing sites),
   every source staged as delivered, every record in one outcome: the same thing seen by several witnesses (matched by place
   within a distance of each witness's precision, and by name where both name it), seen by one, or witnesses in conflict; its
   position and its attributes from the best witness for each, with the basis beside (as `basis` everywhere); internal sources
   kept internal (fishycode's rules: no internal name in the repo, persons by counts). The names use them as witnesses: a
   wreck's or an aid's name and position, a harbour's, a ground's or a deep's bottom.
   - **Wrecks** (measured): Landhelgisgæslan's 279 (on ÍSOR's map server; its comments carry names and depths), the list
     Háskóli Íslands' researcher shared (80, internal: raw/external/wreck_hi, to be asked before anything is published), SKFI's
     18 named wrecks, ÍSOR's 16 points, 57 diving sites; of the 80, 30 lie within 500 m of one of Landhelgisgæslan's; the 18 are
     all among the diving sites. Joined within 500 m, 344 places: 304 seen by one list, 22 by two, 18 by three to five. Still to
     read: the charts' wreck symbols (INT 1 section K, raw/external/chart_symbols, decision 301's code lists) and their names;
     EMODnet's human-activities wrecks; the plotters' and Trackwell's (internal; outside plan 074, decision 316; the plotter
     taken into the prototype as a witness and Trackwell counted on 2026-11-16, below).
   - **Wrecks, the prototype** (built in the study the same day, its 91 and 92, at the maintainer's word: "Let's go for the
     wreck list"). Two more lists fetched: the UK Hydrographic Office's wrecks as EMODnet Human Activities serves them (283 in
     the box 32 W to 6 W, 59 N to 70 N, Open Government Licence; `dump/emodnet/human_activities.R`) and OpenStreetMap's (22;
     `dump/osm/wrecks.R`). Found on staging: 22 of Landhelgisgæslan's 279 are not its own (symbol 0, coordinates 0 in their
     columns): 19 are copies of the diving map's wrecks or ÍSOR's points, 3 have no original; SKFI's 18 are the diving map's
     folder Flök, at the same places; the diving map's other 39 sites are not wrecks; some of Landhelgisgæslan's IDs and
     comments were stored in Mac Icelandic and read as Windows-1252 (kept as given, a reading beside). Added the same day:
     a skipper's TimeZero plotter (internal, as Háskóli Íslands' list; raw/external/ornefni/ and raw/external/vernd_i_hafi/),
     its 2021, 2022 and 2025 exports one witness: 856 marks, 724 of them wrecks by the plotter's wreck icons (310, Landhelgisgæslan's list read into it, 149
     of its 182 within 1 m of an LHG record; 10, the owner's own) or by name, 132 not (depth marks, an anchor and chain, marks
     with neither a wreck icon nor a name); 659 copies (511 at Landhelgisgæslan's records, 2 at UKHO's, 18 re-marks of an
     icon-310 wreck, 128 earlier states of a mark), 65 witnesses, 59 places known from it alone, 6 joined to other lists.
     Trackwell's ground names hold one that names a wreck (21 hauls of one vessel, no position for the wreck; "Flakið" none,
     the other -flak names banks): counted, not a witness (the study's README has it). 1,611 records in all, each in one outcome: 155 seen by several lists,
     526 by one, 63 in conflict, 696 copies, 171 not wrecks; 625 places (68 with several witnesses, 526 with one, 31 in
     conflict: 27 crowded, 4 years sunk disagreeing, 2 names, 2 a list twice). 13 of the joins between Landhelgisgæslan and
     UKHO lie at the same position (under 1 m): one survey, two lists. The 92 places only the internal lists know (Háskóli
     Íslands' 32, the plotter's 59, both 1), and every attribute taken from them, are internal. Every descriptive field of
     every list is kept, one row a field (the maintainer: keep any "description" information; later sources such as
     timarit.is may add rows, not this plan's job), and all text is UTF-8 (the maintainer). The charts' wreck symbols wait (the
     maintainer, 2026-11-16: "mining the sea-charts again for any wreck information waits for now"). The conflicts are
     listed, not resolved (the maintainer, 2026-11-16: "for now we are not going to resolve conflicts").
     Depth and the date sunk, the same day (the maintainer: "Be careful with units"; the date sunk "as a common variable if
     possible"). Two depths, one column each: the seabed at the wreck and the least depth over it. A text depth is read only
     where its unit is written (metres or fathoms) and a depth word or fathoms say it is a depth, the text, unit and pattern
     beside it. UKHO's two fields and OpenStreetMap's tags are read by their documentation. A number whose unit is stated
     nowhere is listed, not read. Háskóli Íslands' depth column states its unit nowhere. It is read in metres, measured
     against the witnesses and the depth model (the maintainer: "Yes, metres", then "Test HI's depth unit"). Against another
     witness's metres, 18 of 25 pairs agree within 25 %. Against the Olex depth model within 500 m of each position, 33 of its
     41 depths fit only as metres, 6 either way, 1 neither (metres within 1 km) and 1 only as fathoms; that one is flagged and
     left out, not converted. The test's controls of known unit fall where they should: 12 of 12 fathom depths, and UKHO's
     metres as metres or either way in 172 of 185. Of 1,611 records, 407 depths read, 22 ambiguous and 89 not depths (torpedo
     sinkings, "U 99 M TUNDURSK"; a length); 315 places have a seabed depth, 35 a least depth. The date
     sunk is ISO 8601 truncated to what is known (day, month or year), with its precision and basis and the year for sorting.
     In comments it is read only beside a word of loss, in the diving map's prose only within that sentence. 626 records read
     (493 to the day), 40 ambiguous (no year, a decade, a range, an uncertain year, malformed); 289 places have a date.
     Witnesses are compared at their common precision: 6 places differ (5 in the year, 1 by a day). Places now 67 with several
     witnesses, 526 with one, 32 in conflict (27 crowded, 6 dates, 2 names, 2 a list twice); records 152 seen by several
     lists, 526 by one, 66 in conflict.
     The wreck list stays outside fishycode's targets flow (the maintainer, 2026-11-16: "we do not at this moment really
     want this to be part of the huge rebuild / target flow"). *Amended 2026-11-17* (the maintainer: "9 - wrecks go to
     fishycode"): it moves into fishycode's layers as the aids did, standalone scripts run by hand outside the targets flow
     (ask p), the internal lists and every attribute taken from them kept internal; not moved yet. As everything else in
     fishycode: the lists as delivered in raw/external/ (done, dump/), each staged as delivered with the common columns
     (`staging/<list>/wreck.parquet`, sources/), then the join and the best witnesses into `curated/reference/wreck.parquet`,
     its records and descriptions beside (reference/wrecks/), checked by `curate/checks/wreck_accounting.R`, as plan 075's
     landing sites (ask p).
   - **Harbours**, *out of this plan* (the maintainer, 2026-11-17: "9 - harbour, leave out of this plan"); as drafted:
     plan 075's landing sites (curated/reference/landing_site.parquet, its ports a subset by basis) with
     Vegagerðin's 83 harbours, the charts' harbour plans and names, and the List of Lights' harbour lights as more witnesses.
   - **Aids** (lights, buoys, beacons, leading marks, radar beacons): the List of Lights in force (546, its positions exact to a
     hundredth of a minute in 514; the study's 86), Vegagerðin's 101 national lights, the charts' letterings of lights and
     their characteristics (the study's 84), the charts' light symbols (barely read so far); Notices to Mariners
     (Tilkynningar til sjófarenda) for changes since the list's edition.
   - **Aids, the prototype** (built in the study the same day by a Claude session, its 93 and 94; no person has checked the
     counts). Three more lists fetched by fishycode's dump/: OpenStreetMap's seamarks (`dump/osm/seamarks.R`, 495 in the box,
     355 aids; 292 from US NGA Pub. 115 of 2010), LMÍ's IS 50V lighthouses (`dump/natt/lighthouses.R`, 108, accuracy 1-10 m)
     and Wikidata's lighthouses (`dump/wikidata/lighthouses.R`, 130). NGA's own Pub. 115 was not had: its portal was under
     maintenance, and the Wayback Machine's copy (a PDF of 2024-11-30) is the maintainer's to fetch. Found on staging:
     Vegagerðin's 101 lights are the List's own (every Admiralty number shared, positions within the List's rounding, 10 m);
     all 12 of Vegagerðin's wave buoys are in the List as lit special buoys (öldudufl, Fl(5)Y), kept not aids as asked;
     the List gives one number to two lights three times. Measured with the Admiralty number as the test: at 100 m the
     nearest alone joins 14 pairs whose numbers differ and misses 55; the number first, then kind and characteristic, joins
     776 by number, none differing, 6 missed (chosen). The charts' letterings and printed characteristics are labels,
     attached to an aid by characteristic within 5 mm of their box (261) or by name within 10 mm (350); 120 stand alone,
     289 with no aid within 20 mm are readings, not aids. 2,422 records, each in one outcome (1,376 several witnesses, 466
     one, 125 conflict, 3 copies, 452 not aids); 801 places, 737 in Iceland (304 several witnesses, 409 one, 24 in
     conflict). The 25 conflicts are listed: 20 positions farther apart than their digits allow (OSM's Mjóeyri 1.6 km
     and Miðleiðarsker and Skarfaklettur 440 m from the List, Vegagerðin and IS 50V; IS 50V's Málmey 1.05 km from all the
     others), 7 characteristics (Sauðanes Fl W 15s in the List, 20s in Vegagerðin and OSM), 2 lists holding one light
     twice. Most "several witnesses" are one official record seen through copies of several dates; IS 50V is the one
     independent witness of position. Every descriptive field kept (25,039), all text UTF-8, 28 checks hold. The
     maintainer, the same day: "no more fetching" (NGA's Pub. 115 stays unfetched); "wave buoys may help explain gap in
     the effort maps" (a first table, the study's 95, then "do later"); ask m dug into (below); ask p answered (below).
   - **Islands and skerries, LMÍ first; the aids apart from the names** (revised 2026-11-16 at the maintainer's word:
     "Islands and skerries - Here we should be using LMÍ and official lists as the source of truth, not the sea-charts. If
     only because the LMÍ names are already tied to coordinates. We will use the sea-charts as witness, and if there are
     conflicts we raise a flag in the data"; "if a placename is already in LMÍ we should should use the coordinates for
     those. What we though should do is keep a list of what types light, beacon types are associated with each feature. And
     if e.g. a beacon location is offhore we should not really put a proper nameplace to those"; "Ergo Lights and beacons
     are separate from örnefni"). His answers the same day: the features above water only (LMÍ's bearers eyja, eyjaklasi,
     hólmi, sker, drangur; a boði, flös or grunn stays chart-led, as the banks; a submerged rock at LMÍ's position since
     2026-11-17, below); LMÍ's spelling the name, the chart's kept
     beside it as a variant, flagged where they differ; a chart's island or skerry with no LMÍ name near it kept at the
     chart's place, flagged chart_only; built in the study first. So:
     - An island list from witnesses, as the wrecks and aids: natt.is's IS 50V names of those bearers (raw/external/is50v,
       on IS 50V's coast polygons by the study's 42) the source of truth, each name with its position and its polygon;
       the official lists that name islands as more witnesses (Landhelgisgæslan's named baseline points); the charts'
       letterings and anchors witnesses. A chart feature and an LMÍ name are one island when their names agree (the same
       key, or a variant of `notes/name_variants.csv`) and the LMÍ name is the nearest of that name. Its position and
       spelling are LMÍ's; the chart's spelling, place and distance kept beside. Flags, never a join or a drop:
       `spelling_differs`; `far_from_chart` (the chart's place more than 12 mm at its scale from LMÍ's, step 4's listing
       rule); `lmi_other_name` (an LMÍ island or skerry of another name at the chart's anchor: Gróttutangi on the charts,
       Grótta in LMÍ); `chart_only`. LMÍ's names that no chart letters are in the list too (`lmi_only`); whether the map
       shows them, and from which zoom (LMÍ's display scale, birtingarkvardi, offers one), is the maintainer's. A name whose
       only source in LMÍ is Hafrannsóknastofnun's delivery (V202005002) is a witness, not the truth: weighted as Trackwell,
       at his word of 2026-11-14.
     - The aids apart: a light, buoy or beacon is no örnefni. The names map loses its light names (the study's 84 entities,
       sort "light"); the aids are a layer of their own at their positions from fishycode's curated aid list, by their own
       names. Each örnefni feature carries the aids that stand on it, a long table (feature, aid, its kind: lighthouse,
       light, beacon, buoy, leading light, radar beacon; how linked: within the feature's IS 50V polygon, at its point,
       or lettered in its name by the charts). An aid on no named feature (offshore, a harbour mole, a buoy) gives no
       place name: it is listed, its name the aid's alone.
     - The charts show the aids too (the maintainer, the same day: "keep a note that the light and beacons are on the
       sea-chart, you may even think of including the lon-lat list estimated from the sea-chart scanning. could act as an
       accuracy test downstream"): each aid keeps, beside its official position, every chart's estimate of it from the
       scanning (its lettering's and printed characteristic's place on each chart, as the study's 84 and 97 read them;
       a light symbol's where one is read), with the chart's scale and the distance in metres and in chart mm. Kept as a
       test of the charts' georeference and of the reading, chart by chart, downstream; never a position.
     - *Built in the study the same afternoon* (its 110, 111 and 112, by Claude; no person has checked the counts). No
       distance decides a join (a 12 mm cut, tried first, split one bay's skerries at 12.1-12.7 mm): the names agree and
       the chart's anchor lies on the LMÍ island or on no other islet; on another islet the chart names that islet, flagged.
       6,091 LMÍ names in scope in 6,063 islands; of the charts' 926 island, skerry and light features 639 joined; 809
       islands shown, 572 at LMÍ's place, 39 in LMÍ's spelling; 5,438 LMÍ islands no chart names, listed, not shown (the
       maintainer's call). An island group keeps the chart's place where the chart names it among its islands (45). The
       names map lost its 128 light names (20 back as the island they alone name); of the 737 aids in Iceland 104 stand on a
       named island, 33 are lettered with a named feature's name, 600 give no place name (176 offshore). The charts' labels
       of the aids lie a median 6-12 mm from the aids on every sheet. Found on the way: most flagged far_from_chart lie in
       one bay on the 1:35 000-1:50 000 sheet, 480-640 m off, a shift of that sheet in the georeference by the look of it.
       The submerged ones measured, not decided (the maintainer's word): against the depth model LMÍ's point lies shallower
       than the chart's label in 149 of 166 pairs, and shallower than the depth model's top found from the label alone in
       60 of 72; the chart's position there is its label's (its rock symbols not read), so the test leans against it.
       *Decided 2026-11-17* (the maintainer: "Submerged rocks - position from LMÍ"): a submerged rock's position is LMÍ's
       where LMÍ has its name, the chart's label a witness, flagged where they part, as the islands above water. Taken
       as the names 112 measured (the charts' point names of rocks, shoals and reefs; Claude's reading of "submerged
       rocks"); a bank lettered as an area stays chart-led. Not built yet.
     - *The same evening* (the study's 113-115, by Claude; no person has checked the counts). On the map of the submerged
       ones the maintainer found LMÍ "pretty much spot on for location of these screrries and things", one place left to
       judge (Gerpisfles and Mávastapar, both LMÍ's). IS 50V's names fetched whole, every bearer (fishycode's
       `dump/natt/ornefni.R`, 200,674) and linked to IS 50V's islets ("Yes, link them"): of the 3,212 islets the six bearers
       left nameless, 1,305 are named one way or another (part of a named island, group or chain 1,090; a landform 145, the
       islet itself at high water; an island name missed 40; named parts 26; things on it 4), 609 lie under water names
       only, 1,298 have none within 50 m. A direction, not yet built (the maintainer: "I think we may have to forget the
       difference between the sea and terrestrial stuff, at least when it comes to Breiðafjörður. We should similarily
       possible not limits our nameplace mining for the main Iceland island either - possibly use something like a 1 km
       inward buffer from the shoreline"): IS 50V holds 35,282 names on the mainland within 1 km of the shore, 7,745 on
       islets and 8,684 at sea (Breiðafjörður 13,059 in all), about six times the charts' letterings; which bearers the
       names map takes, and from which zoom (LMÍ's display scale offers one), is his. A list of Breiðafjörður's names at sea
       found by a side session ("Örnefni í sjó á Breiðafirði", 2007, for Breiðafjarðarnefnd: 468 names placed by GPS, never
       entered in IS 50V) linked as a witness ("Yes, link it"): 164 on an islet IS 50V names the same, 129 on one it names
       otherwise (27 a spelling, 16 a qualifier, 86 another name, most a feature at the islet), 1 on one it leaves nameless,
       174 at sea (96 with no IS 50V namesake within 500 m); the charts letter 67 of the 468 within 1 km.
   - **Bottom type** (sediment), *out of this plan* (the maintainer, 2026-11-17: "9 - bottom type: leave out of this plan";
     with ask l, TODO 201); as drafted: the charts' bottom marks (decision 301, at 1:300 000, 1:100 000 and 1:40 000), ÍSOR's 3,444 grab
     samples (their Folk class; their shares measured in 1,634) and 530 cores, ÍSOR's substrate map (68 polygons over 766,000
     km², 18 of them generalised to 1:1 000 000; refetched 2026-11-16 with its geometry, which the server's query withholds),
     EMODnet's substrate at 1:1 000 000 (14 polygons for Iceland over 1.53 million km²; its 1:250 000 and 1:50 000 maps hold
     no Iceland, measured 2026-11-16), each witness at its own scale; a cell or a sample's class with its witnesses, for
     step 8's grounds and deeps.
   *Assumed*: that a witness's precision can be stated (Landhelgisgæslan's surveyed wrecks exact, fishermen's snags not;
   the List of Lights' two decimals exact, one decimal approximate); that one list's record is one thing (a wreck may be two
   pieces, a harbour two basins). *Check*: every record of every source in one outcome; the conflicts listed for the
   maintainer.
10. **Later, if wanted**, as written on 2026-11-11: the wholes' outlines (§3), the vocabulary (§2, §4), the parts on their
   wholes (§4), the relational, hydrographic and motive names (§5), the regional frame (§6), the grid's sources (§7).
   And, an idea for later (the maintainer, 2026-11-15: "Report the hand ranking as an idea to pursue later"): hand ranks
   the Natural Earth way, a rank of 1-3 set in the names editor for the names that matter at zooms 5-7, discrete isolation
   spacing them (the study's 83 and 81's `RANK`), the names not ranked below them on their box.
11. **LMÍ's names on the names map** (drafted 2026-11-16 at the maintainer's word: "Plan which of LMÍ's names go on the
   names map next? - Yes, plan it"; his direction the same evening: "I think we may have to forget the difference between
   the sea and terrestrial stuff, at least when it comes to Breiðafjörður. We should similarily possible not limits our
   nameplace mining for the main Iceland island either - possibly use something like a 1 km inward buffer from the
   shoreline"; and of the skerries' positions: "By a spot check it looks like the LMÍ is pretty much spot on").
   *Measured* (the study's 127, by Claude; no person has checked the counts): IS 50V's whole name set (200,674 names, 217
   bearers; fishycode's `dump/natt/ornefni.R`) holds 51,711 names at sea (8,684), on islets (7,745) and on the mainland
   within 1 km of the shore (35,282). By kind (the study's 115 classes): island 7,043, landform 15,770 (nes, tangi, höfði,
   klettur, rif, eyri ...), on it 19,858 (farms, ruins, fields, hills, streams: things on the land), water 9,040 (vík,
   vogur, sund, fiskimið ...). The names map holds 2,687 of them already (a feature of the same name within 2 km, or its box
   holding the name; corrected 2026-11-17, below); 49,024 are new, 9,986 of them in Breiðafjörður. The other way: of the
   names map's 2,113 names at sea and on islands, 1,500 have an LMÍ name of the same within 2 km. The two deliveries the maintainer counts as copies
   (Hafrannsóknastofnun's V202005002, Trackwell's V202005003) hold 485, nearly all at sea; 87 cite the sea charts. LMÍ's
   display scale (birtingarkvardi) is 1:10 000 for three in four, 1:25 000-1:50 000 for a quarter, coarser for about 1,000
   (most of them water names); LMÍ's size class (ornefnaflokkur: Lítið, Mið, Stórt) marks 1,426 new water names Mið and
   39 Stórt. Geometry: 29,439 areas (a median 190 m across), 8,571 lines, 13,701 points; 2,894 new names span 1 km or more
   (1,540 of them water). The new names crowd: a median 5 per 10 km square, the 90th percentile 176, the thickest 989.
   *Settled as proposed* (asks q-t, the maintainer the same night: "Yes, as proposed"); the pilot built, below:
   - **Which names**: by kind, island, water and the shore's landforms at first; the things on the land (farms, ruins,
     fields, hills, streams, 19,451 new) left out or a later layer (ask q). The two deliveries left out as copies unless
     another witness holds the name. A pilot region first, Breiðafjörður (ask r), then the whole coast.
   - **One name, one feature**: an LMÍ name and a chart feature of the same name within 2 km, or inside the feature's box,
     are one; the names map keeps one name. Its place as now (an island's LMÍ's; an areal sea name the charts' rule), its
     extent LMÍ's area or line where LMÍ has one (ask s); the spelling LMÍ's with the chart's print kept, flagged, as the
     islands are.
   - **When a name shows**: rule e (step 5) on LMÍ's own extent, its area's or line's; an islet's name by the islet's area;
     a point with no extent from LMÍ's display scale (1:10 000 from about zoom 14, 1:25 000-1:50 000 from 12-13), moved
     earlier by LMÍ's size class (Mið, Stórt). The charts' names placed first in the traffic jam (81), LMÍ's after; no
     name dropped when zooming in.
   - **How it looks**: LMÍ's names drawn as the charts' are, by kind, or apart in a lighter style and a layer of their own
     in the editor (ask t).
   - **Every name in one outcome**: shown from a zoom; already the chart's feature (one name); a copy left out; a kind left
     out; outside the pilot. The witnesses' disagreements flagged, never undone.
   *Assumed*: that LMÍ's areas and lines bound the features they name well enough for rule e; that a 2 km namesake is the
   same feature (measured for the islands, 110: a namesake moved 2-4 km was flagged). *Check*: in the pilot, names a
   screen at zooms 11-15 and the names 81 holds back, against the map today.
   *The pilot built* the same night (the study's 128-130; the names map's 71, 81 and the editor 75 take it by a switch,
   without which the map is as before, byte for byte). Built by Claude while the maintainer slept; no person has checked
   the counts, and each choice below is his to correct.
   - Every name in one outcome, 21 checks holding (the study's 129). Of 127's 51,711 names, 10,572 lie in the pilot's
     box. 4,034 are left out as things on the land: 2,819 of 115's class on_it, and 1,215 fields, ponds, streams and
     the like that 115 had sorted as landforms or waters. Leaving those out too is Claude's reading of this step's
     words ("fields ... streams"). 537 are one name with 521 chart features. 5 are copies with no other witness. 5,996
     are shown, as 5,947 names of LMÍ's own (records of one name within 300 m, or on one islet, one feature).
   - Of the 521 joined chart features, 22 take LMÍ's spelling and one keeps the maintainer's. 473 take LMÍ's area or
     line as their extent, so 240 of them start later, a median 1.33 zooms. LMÍ's area is the feature's own, and a
     chart's box is about twice its lettering. A headland's LMÍ area is often only its tip (flagged).
   - LMÍ's names are drawn by kind as the charts' names are, in a layer of their own in the editor. They are placed
     after every chart name, none overlapping in the box at zooms 9-15. Among themselves LMÍ's islands are no tier
     (Claude's choice: more names drawn at zooms 12-14 and shorter long waits than with the tier).
   - *Measured* in the box against the map before: names drawn by zoom 13, 1,439 (494 before); by zoom 15, 4,983
     (589). A screen of 1280 x 800 px holds at most 88 names at zoom 13 and 92 at zoom 15 (39 and 11 before), a median
     of 11 and 4. 1,886 of LMÍ's names wait for room, a median 0.62 zooms.
   - Elsewhere one long name slid 25 km along its line, because 81 weighs the others' extents when it slides a name.
   - Seven alternatives were measured one at a time, each named in the study's README.
   - Found: 68's boxes are in EPSG:5325 and 127 tested them in EPSG:3057, so 127's "box holding the name" never held.
     Its 2,508 names already on the map were the 2 km rule alone; 127 fixed and rerun on 2026-11-17 against the charts' names
     only (the map file now holds LMÍ's too): 2,687 on the map, 193 of them by a box beyond 2 km; the counts above corrected.

   *The whole coast* (the maintainer, 2026-11-17: "Extend now", the pilot's choices standing; built by Claude the same
   morning, the study's 128-130 under a switch for the region, no person has checked the counts). Every name of 127's
   51,711 in one outcome, 21 checks holding: 29,189 things on the land left out (19,858 on_it, 9,331 fields and the land's
   waters by the step's words), 2,187 one name with 2,152 chart features, 247 copies with no other witness, 20,088 shown as
   19,958 names of LMÍ's own (islands 5,808, the land's 8,209, the sea's 5,941). Three findings, fixed: a name whose area
   or line gives no place takes its record's point (5, flagged); a chart name joined by LMÍ's second name only keeps its
   own name, LMÍ's first name beside it, flagged (33: another name, not a spelling, in most), so 44 take LMÍ's spelling;
   names at one point with another flagged (11; 2 never drawn). LMÍ's source (heimild, in full) and its kind are fields
   of their own on every LMÍ name and joined chart name (the maintainer, the same morning: "Can we actually include the
   source of the names as a variable"). Against the map before, names drawn by zoom 13 1,882 to 6,640, by zoom 15 2,100
   to 17,968; a screen of 1280 x 800 px holds at most 90 names at zoom 13 and 110 at zoom 15 (37 and 25 before), a median
   of 3 and 2; the most crowded screens in Breiðafjörður, where the coast run draws as the pilot did. 4,650 of LMÍ's names
   wait for room, a median 0.58 zooms. No chart name gone or new; 1,322 start later (a median 1.53 zooms, nearly all those
   whose extent is now LMÍ's); 16 turned names slid along their lines, up to 26 km. Offshore, LMÍ's sea names include 20
   fishing grounds and 2 seas over 50 km across, shown from low zooms. The map's file of names is now 22 MB.
12. **One table of what the map shows: the names, the wrecks, the lights and beacons** (drafted 2026-11-19 at the
   maintainer's word: "My thinking is that we build one complete set that take the seachart mined data, the ISOR data and
   the LMÍ data forward. Leaving behind for now the data from trackwell"; of the proposal, "Yes, amend plan 074"; then "I
   think the wrecks should be part of this "build""; "hold on what happens to lights and beacons"; "i am wandering if
   names, wrecks and lights and beacons should not be all in one single dartaframe, seperable by filter on a variable
   name"; of the proposal, "Yes, amend step 12 that way"). Three lists, each built in fishycode's layers with its own
   records, outcomes and checks, and one curated table that binds what they share: one row a thing on the map, told apart
   by `type` (name, wreck, aid) and `kind`. A buoy and the skerry it marks are two rows, never one name (step 9, "Ergo
   Lights and beacons are separate from örnefni").
   *Measured* (Claude; no person has checked the counts): on the study's `out/place_map/names.geojson` of 2026-11-17,
   25,880 names, 5,900 of them the charts', 19,958 LMÍ's and 22 ÍSOR's, 104 placed or timed by the maintainer's hand
   (`notes/name_edits.csv`, 131 rows), and none of the names scripts (71, 75, 127, 128, 131, 132) reading Trackwell's
   tables (127 and 128 name its delivery only to leave its copies out); the wreck list (the study's 91, 2026-11-16), 1,611
   records in one outcome, 625 places; the aids (fishycode's aid list, the study's 111), 737 in Iceland, 104 on a named
   island, 33 lettered with a named feature's name, 176 offshore, 424 on the coast, and 76 named features listing the aids
   on them.
   - **Version 1 frozen first**: the study's rules as they stand on 2026-11-19, no rule changed while the lists move. A
     later round changes the product and is measured against version 1.
   - **Settled before the freeze** (asks u-w, the maintainer, 2026-11-19): the sea, the islands and LMÍ's shore
     landforms within 1 km of the shore, as now, the page's "names on land" switch hiding LMÍ's shore names too (u); the
     three misreads corrected in `overrides/` ("Reykjane", Faxagaröur and Sudurgaröur), the two duplicates (Faxabanki,
     Skerjafjörður) kept with both witnesses' places and flagged, for his hand later (v); the page 132, on ogis (w). The
     submerged rocks at LMÍ's position (decided 2026-11-17, not built) are built into version 1.
   - **The names**, from three public sources alone: the charts' letterings (`curated/reference/chart_names.parquet`),
     LMÍ's names (IS 50V's whole name set, `raw/external/is50v/ornefni_all/`, fetched by `dump/natt/ornefni.R`) and ÍSOR's
     seabed map (`raw/external/isor/`). Trackwell, the plotters and plan 044's gazetteer (`curate/place_name.R`) are read
     in no role; LMÍ's records that only copy Trackwell's or Hafrannsóknastofnun's 2020 deliveries stay out as copies
     (step 11). LMÍ's names staged by an adapter of their own in `sources/is50v/` (the gazetteer's
     `sources/ornefni/lmi_name.R` holds only the 2022 polygons), ÍSOR's map by one in `sources/isor/`, the charts'
     letterings as now. The join, the outcomes, the place, the angle and the zoom a name deserves in one standalone
     script in `reference/`, run by hand outside the targets flow, as the aid list's (ask p), its accounting in
     `curate/checks/`: every chart lettering, LMÍ record and ÍSOR record in one outcome (129's and 131's checks carried
     over). 79's lines and 81's deserved zoom come along in the language they are written in, unless a reason to port
     them shows. A name's letterings stay in `chart_names`, linked by key; LMÍ's source (heimild) comes with each LMÍ
     name, as LMÍ publishes it on the web (the maintainer, 2026-11-19: "the LMÍ data was obtained from source on the
     web").
   - **The wrecks**: step 9's wreck list (the study's 91 and 92) moved into the layers as the aid list was: each list
     staged by its own script in `sources/<source>/`, the join, the outcomes and the best witnesses in
     `reference/wrecks/wreck.R` to `curated/reference/wreck.parquet` with its records, pairs and descriptions beside,
     the accounting in `curate/checks/wreck_accounting.R`, the shared machinery `R/curated_list.R`. Its witnesses as ask
     o settled them: Landhelgisgæslan's list, UKHO's, OpenStreetMap's, the diving map and the internal ones, their owners
     named under `$FISHYDATA` only, never in this repo. Trackwell's names are no witness here either (the study found one
     wreck name in them, with no position for the wreck). The conflicts listed, not resolved (ask o); the charts' wreck
     symbols still wait.
   - **The lights and beacons**: the aid list as built on 2026-11-16 (`reference/aids/aid.R`, its tables unchanged). The
     study's 111 moves into the build: which named feature each aid stands on, and every aid in Iceland in one outcome
     (on a named island, lettered with a named feature's name, offshore, on the coast).
   - **The one table**, written after the three lists by a standalone script in `reference/`, to
     `curated/reference/marine_feature.parquet` (ask x) by `write_curated()`, the geometry as WKB. One row a name's feature, a wreck's place or an aid:
     - `id`, `type`, `kind` (a name's island, water, land and the rest; an aid's light, beacon, buoy; a wreck);
     - its name and synonyms (LMÍ's spelling with the chart's print kept, ÍSOR's name with the maintainer's), empty where
       a wreck has none;
     - one place and one angle, each with its basis (a chart's lettering, 1c's anchor, LMÍ's position, ÍSOR's area, an
       aid's or a wreck's best witness, the maintainer's hand);
     - the zoom it deserves (`z_rule`) with its basis;
     - `holder`, the name a name lies within, and `on_feature`, the named feature an aid stands on or a wreck lies in;
     - its extent where a source gives one (LMÍ's area or line, ÍSOR's area);
     - its sources, each with its own id (the chart feature, LMÍ's uuid, ÍSOR's record, the aid's and the wreck's own);
     - `internal`, a wreck known only from internal lists or taking an attribute from them, so that a copy shared outside
       drops it by one filter.
     What only one list has (a light's characteristic, height, range and number; a wreck's year sunk, depth and
     witnesses; a name's letterings and LMÍ's heimild) stays in that list's own tables, joined by `id`.
   - **The traffic jam stays with the page** (step 7, 2026-11-15): which name gives way when two collide depends on the
     screen, so the table carries the zoom each row deserves and the page the zoom it is drawn from. Place names, aids'
     names and wrecks' names compete in one ranking (ask y): a place name wins a collision, an aid's name shows from zoom
     10, a wreck's name from a fine zoom, its dot always.
   - **The maintainer's edits** re-enter as a reviewed input in `overrides/`, as step 1b's verdicts would: the cycle
     broken by a person. Checked when moved that they name no internal source.
   - **One page**, 132 on ogis (ask w): its rebelrebel calls moved to ogis's `og_` functions, the gaps it listed in the
     package (the study's README, 2026-11-18) filled in ogis with a test each, the page in fishycode's `products/` as the
     port map on ogis is. It reads the one table, with one search across the types, so the rule that lays the edits on
     lives once (71, 75 and 132 each hold it now); 75 is retired once 132 draws from the table.
   - **Left apart**: the outlines, the vocabulary and the parts (step 10); Trackwell's names, until the maintainer brings
     them back.
   *Assumed*: that the study's names map, wreck list and links of the aids are the sets to carry forward, as they stand
   but for asks u-w. *Check*: every row of the one table traced to its list's row and every list's row in the table or in
   an outcome that says why not; the names equal to the study's map for every name, place, angle and deserved zoom, but
   for what asks u-w change, each difference listed; the wreck tables equal to the study's 91 record for record (outcome,
   place, attributes), as the aid list's were; the aids' links equal to 111's `out/aids/feature_aid.csv`; every source
   record in one outcome; `check_bookkeeping()` and the stamps as for any curated table; the page drawing from the one
   table as it drew from the study.

## 10. Asks

Asked on 2026-11-15, with the aim revised (both settled, the maintainer, 2026-11-16: "Plan asks: i and j settled"):

i. *Settled*: the finest lettering, a large feature's name at its box's middle (78), a long feature's on its line (79),
   the maintainer's hand on the map. Asked: An areal name's best place: its finest chart's lettering (printed nearest the feature), or a place agreed among all its
   letterings, nearer the finer charts? A long feature (Eyjafjarðaráll) as a point, or as a line along its axis? (Its angle
   settled: the landscape's shape.)
j. *Settled*: rule e (step 5), the display zoom apart from the traffic jam (step 7), hand ranks later (step 10). Asked:
   When a name shows: by its kind (a ground, a deep, a rock) and its extent (the length of its lettering on the coarsest
   chart that prints it, or the feature's size on the depth model), a rock or a shoal from a fine zoom whatever the charts?
   (Its direction given: a hierarchy, the holder before what it holds, the extent guessed from the lettering as a guide.)

Asked on 2026-11-16, with the new sources (step 8):

k. *Parked for another plan* (the maintainer, 2026-11-17: "park, do it in another plan"; TODO 201). Asked: A trough shared by several names: split by their lines (a Voronoi of the lines within it), or by the maintainer's hand on the
   map?
l. *Parked for another plan* (the maintainer, 2026-11-17: "park, do it in another plan"; TODO 201). Asked: The grounds' limits: the bottom type first (ÍSOR's substrate map and grab samples; EMODnet's finer maps hold no Iceland), or the depth
   model's relief first, the bottom as a check?
m. The aids: the List of Lights as their source (position, characteristic, kind), the charts' letterings their labels?
   *Dug into* (2026-11-16, the maintainer: "m - not sure, can you dig in"; the study's 96, by Claude, no person has checked
   it): the witnesses against each other. Position: where the List (1/100 minute), Vegagerðin and IS 50V hold one
   lighthouse (95), Vegagerðin's geometry lies nearer IS 50V than the List in 58, the List in 20, the same in 17 (medians
   4.3 m and 7.5 m): its finer digits are the List's position before rounding. The List agrees with IS 50V within 25 m at
   89 of the 95; where witnesses part, the odd one is OSM (NGA's 2010 positions: a digit at Mjóeyri, 440 m at
   Miðleiðarsker and Skarfaklettur, twelve lights 100-300 m off, harbour lights most) or IS 50V (Málmey 1.05 km).
   Characteristic: Vegagerðin agrees with the List in 100 of 101, OSM in 221 of 227, Wikidata in 26 of 27, the charts'
   printed characteristics in 45 of 59 within 5 mm of a List light (the rest fragments of the read or older editions).
   Kind: the List's parts and OSM's types agree in every joined pair. Labels: a chart's lettering lies a median 2-4 mm
   from its aid on its own chart (367 m on the 1:100 000), a label's place. So the working answer holds with one
   refinement: position Vegagerðin's geometry where it has the light, else the List; the List for characteristic, kind,
   height, range and number; IS 50V, OSM, Wikidata as checks; the charts' letterings the labels.
   *Settled* (the maintainer, 2026-11-16: "Proceed with m"); fishycode's aid list takes its best witnesses so. Proceeded
   with in the study's 98: each light of the names map linked to its aid, so that it has a position apart from its label.
   Of the map's 128 lights, 118 link by their own letterings (12 of them lettered for 2-3 aids, the most lettered taken),
   5 by an aid of their name within 3 km; 5 link to none, the nearest aid of their name 7-29 km off (namesakes elsewhere,
   or a light the List no longer holds). From the label's place to the aid's position: a median 872 m, 84 over 500 m, 43
   over 1 km. 37 aids are lettered only in another feature's name (an island, a point, a shoal: Engey, Grímsey, Hrísey,
   Helgasker's buoy): the feature keeps the name, the aid its position. In the names editor the same day (the maintainer:
   "Yes, in the editor"): the aids at their positions from the curated aid list, a dot each by kind, a line from each to its
   light's name; 618 aids, 110 linked to a name; the 119 only a chart shows have no position and no dot. The names map
   (71) still draws a light at its label.
n. *Parked for another plan* (the maintainer, 2026-11-17: "park, do it in another plan"; TODO 201). Asked: A large bay's outer limit: the baseline's segment across its mouth?
   *On a map, not decided* (2026-11-16, the maintainer: "take [the fjord model] up at the same time"; the study's 107 and 108,
   port 4842, by Claude, AI, no person has checked it): the baseline closes 35,799 km2 into pockets, a cut from each of its 31
   offshore points to the main land closing the water behind; each pocket held by its largest name lettered in it, two shared
   by large bays of their own (three behind Glettinganes-Langanes; Breiðafjörður with Rauðasandsbugur); the fjords nested with
   their water by rays (76). The fjord model with its 80 km reach cap lifted, so that a bay is judged as a fjord is, puts the
   wide bays' mouths well inside the baseline: at 60 % 23-34 % of the three largest pockets, at 50 % 31-51 %, while two
   narrower bays' water at 50 % runs out past it. No one threshold meets the baseline. The south coast's bights lie mostly
   outside it. 9 of the 20 held pockets of 100 km2 or more pass the law of the sea's semicircle test. A third way, closing
   lines between each bay's named headlands (the study's 109), ran once, unchecked. Closed there (the maintainer, 2026-11-16:
   "I think this exercise was a bit futile"); ask n stays open.

Asked on 2026-11-16, with the curated lists (step 9):

o. *Settled* (the maintainer, 2026-11-16): the conflicts listed, not resolved ("for now we are not going to resolve
   conflicts"); the internal witnesses in, the plotter added the same day, internal like Háskóli Íslands' list; the charts'
   wreck symbols wait. The distance without a knife edge ("Do we really need to do this here - as long as we flag a potential
   issue. I hate knife edge decisions, at least on this one"): records join at 500 m, mutual nearest; two places whose
   witnesses are each other's nearest but lie apart within 1 km, or within the two records' coordinate digits, are flagged
   as maybe one wreck, on both places, never joined, their outcomes unchanged. On the prototype: 29 pairs on 42 places, their
   names agreeing in 6, differing in 3, one side or both unnamed in 20; none beyond 1 km by the digits. Asked: The wreck list's witnesses: every list above with the charts' wreck symbols, and the
   internal ones (Háskóli Íslands' list, the plotters') kept as internal witnesses; which distance makes two records one wreck
   (500 m, or each witness's own precision)? Measured on the prototype with the plotter: 500 m gives 625 places, 31 in
   conflict; 1 km, 602 and 51 (29 more joins, 7 with the plotter; 6 confirmed by names, 3 contradicted, 20 with a name on one
   side or none); 500 m widened by the coordinates' digits (114 of UKHO's 283 to the whole minute), 622 and 31 (3 more
   joins). Before the plotter: 567 and 30; 548 and 49; 564 and 30.
p. *Decided for now* (the maintainer, 2026-11-16: "we do not at this moment really want this to be part of the huge rebuild /
   target flow"): the wreck list stays a standalone script in the study (its 91 and 92), outside fishycode's targets flow.
   Asked: The curated lists in fishycode's reference/ as tables of their own (as plan 075's landing sites), built before the
   names use them; or first within this study?
   *Answered again* (the maintainer, 2026-11-16, of the aid list: "p - this whole process should go into the flow: raw ->
   staged -> out or curated"): every curated list, the wrecks' and the aids' alike, goes raw -> staging -> curated in
   fishycode's layers. A sketch, on plan 075's landing sites: each list staged by its own script in sources/<source>/ to
   staging/<source>/ (the List of Lights' PDF read in R, as the study's 86 does in Python; Vegagerðin's lights and wave
   buoys; OSM's seamarks; IS 50V's lighthouses; Wikidata's lighthouses), the charts' printed characteristics frozen in the
   study first and read as a frozen input, as chart_names is (only the names are frozen now); the join, the outcomes and
   the best witnesses in reference/aids/aid.R to curated/reference/aid.parquet with its records, pairs and descriptions
   beside (write_curated, stamped); the accounting (the study's 94) in curate/checks/aid_accounting.R; the machinery both
   lists share (mutual nearest across lists, places, outcomes, best witness, the long descriptions) once, in R/.
   *Settled* (the maintainer, 2026-11-16: "Standalone in layers"): standalone scripts in those layers, run by hand, outside
   the targets flow and its rebuild. The aid list built so the same day (by Claude; no person has checked it):
   `sources/{vitaskra/aid.R, vegagerdin/light.R, osm/seamark.R, is50v/lighthouse.R, wikidata/lighthouse.R, sjokort/aid_label.R}`
   to staging/, `reference/aids/aid.R` to `curated/reference/{aid,aid_record,aid_pair,aid_description}.parquet` and
   `curated/check/aid_join_rules.parquet`, `curate/checks/aid_accounting.R` (24 checks hold) to
   `curated/check/{aid_accounting,aid_conflict}.parquet`; the shared machinery `R/curated_list.R` and
   `R/light_characteristic.R`, tested by `tests/test_curated_list.R`; the charts' printed characteristics and 84's aid
   letterings frozen by the study's 97. The R reading of the List of Lights gives 86's table field for field; the curated
   tables give the prototype's record for record (outcome, kind, attachment, aid, every attribute). The wreck list is its
   own session's to move; `R/curated_list.R` is there for it.

Asked on 2026-11-16, with LMÍ's names (step 11); all four settled as proposed the same night (the maintainer: "Yes, as
proposed"):

q. *Settled as proposed*: island, water and the shore's landforms; the things on the land left out for now. Asked: Which of LMÍ's names go on the names map: island, water and the shore's landforms (the proposal), the things on the land
   too (farms, ruins, fields, hills, streams: 19,451 new near the shore; 19,458 before the fix of 2026-11-17), or a list of bearers?
r. *Settled as proposed*: Breiðafjörður first. Asked: A pilot first, Breiðafjörður (10,008 new names; 9,986 after the fix of 2026-11-17), then the whole coast?
s. *Settled as proposed*: the chart's place, LMÍ's extent. Asked: Where a chart's sea name and an LMÍ area or line of the same name meet: the chart's place with LMÍ's extent (the
   proposal), or LMÍ's place too?
t. *Settled as proposed* (both offered: drawn by kind as the charts' are, and a layer of their own in the editor to show or
   hide). Asked: LMÍ's names drawn as the charts' are, by kind, or apart: a lighter style and a layer of their own in the
   editor?

Asked on 2026-11-19, with the one set (step 12); all five settled the same day (the maintainer, choosing among the
options offered, and naming the table himself):

u. *Settled*: as now, the switch hiding LMÍ's shore names too ("As now; switch hides them"). Asked: The land names: the
   set as the names map has it, the sea, the islands and the shore's landforms within 1 km of the shore (LMÍ's 8,209
   names of the land shown, its 29,189 things on the land left out), or the sea and the islands only? And should the
   page's "names on land" switch hide LMÍ's shore names too (the smoke test, 2026-11-17)?
v. *Settled*: the misreads corrected, the duplicates flagged ("Fix misreads, flag duplicates"). Asked: The duplicates
   and misreads the smoke test found: Faxabanki twice (the chart's and LMÍ's fishing ground, 11 km apart), Skerjafjörður
   twice (chart features 508 and 693, 3.5 km apart), "Reykjane" (chart 2359, a lettering cut short?), Faxagaröur and
   Sudurgaröur (ð read as ö). Each corrected by the maintainer's hand as an override, or left flagged?
w. *Settled*: 132, on ogis ("132, on ogis"). Asked: The page kept: the names editor (75) or the names map on rebelrebel,
   now ogis (132)?
x. *Settled*: `marine_feature`, the maintainer's own name (offered: `sea_feature`, `map_feature`). Asked: The one
   table's name: one that holds a nameless wreck too (`sea_feature`, `map_feature`), or another? (`named_feature`,
   offered first, no longer fits once the wrecks and the aids are rows.)
y. *Settled*: places first, aids' names from zoom 10, wrecks' from a fine zoom ("Places first; aids z10; wrecks fine").
   Asked: The ranking on the screen across the types: a place name before an aid's name or a wreck's where they collide,
   an aid's name from zoom 10 as the editor has it, a wreck's name from a fine zoom; or a wreck's name shown only on a
   click?

Asked on 2026-11-11, for the outlines (now a later step):

a. The scale chosen by the label (§3): with it, the labels no longer score the outlines. Accept?
b. Where to begin the review: Faxaflói and Reykjaneshryggur (where the maintainer has looked), or another region?
c. The chart names' derivatives left out in trial 2, read back as parts (§4), from every source but Trackwell?
d. The grid's sources: ask Julian Burgos for the footprints (an email, to be sent by the maintainer or at his word), or
   segment them from the grid?
e. Current data for -röst and -straumur: does MFRI hold a tide or ocean model for Icelandic waters, or a global model
   downloaded?
f. Witnesses for the motive names: the surveys' and observers' bycatch records of corals and sponges, and a wreck list,
   from which tables?
g. The regions: eight bearing sectors (script 65), the maintainer's own coastal regions, or regions found where the
   vocabulary changes?
h. The review page: the chart map (port 4813) with verdicts, or a page of its own?

## 11. Not in this plan

Mounds without a name (the mounds elsewhere stay a layer, re-thresholded in step 6); Trackwell in any role; a name's
history (plan 067's records); publishing outside MFRI. Since 2026-11-17 (the maintainer): the deeps' split, the grounds'
limits and the large bays' outer limits (asks k, l and n) and the bottom type, parked for another plan (TODO 201); the
harbours (plan 075's landing sites).
