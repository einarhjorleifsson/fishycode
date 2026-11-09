# 071 — The names in use beside the charts' names: every other source's names linked to the official layer, each small feature placed on the seabed, and issues raised, never a boundary moved

**status:** proposal — written 2026-11-09 at the maintainer's request, with a read-only count the same day
(`$FISHYDATA/archive/2026-11-09-ornefni-in-use/`, `scripts/00_inventory.R`, its log in `notes/`); the same day step 1
run as a study at the maintainer's word ("Yes, start step 1"): the highs printed at 1:40 000 passed its rule (31
names moved onto the grid's high in the örnefni map), and with a mend, a closed high tuned west and judged east, the
highs printed at 1:100 000 (19 more); the deeps and skerries left at their label (§3); nothing else built ·
**2026-11-09** · **see:** plans 044, 045 (§2, ask c), 067 (ask a), 070 (§2.2, §2.8-§2.10), decisions 272, 286,
300-302 and 304, the örnefni map (`$FISHYDATA/archive/2026-11-08-ornefni-map/`), TODOs 144, 186, 193 and 194

Drafted with AI assistance (Claude) on 2026-11-09; a person has not yet checked it.

**Measured** (by Claude, 2026-11-09): the counts in §1, by key, on the gazetteer as built 2026-11-06 and the örnefni
map as it stood on 2026-11-09. The seabed figures in §1 are plan 070's scan and decision 301's, not measured again.

**Assumed:**
- that the charts are independent of the other sources, so the official layer can measure them. Two sources are not:
  the gazetteer's own `sjokort` lines, and LMÍ, which cites Trackwell for 124 sea polygons (decision 222). Both are
  left out of the measurement;
- that a name's feature word says which feature it names: a hill word a local high, a hole word a local low. Plan
  070's scan bears this out for holes and for the charts' rings, not for small knolls (§1);
- that the 50 m grid shows a feature the chart rings. Where Olex sounded and where GEBCO fills is not known (plan 070
  ask c).

The maintainer, 2026-11-09, on the names the charts lack, now that the charts' names have a model of their own:
- "some of them are of some quite questionable quality - particularly the trackewell (where captains may just use the
  last value entered). But there are still a lot of gems there, including names in the more deeper areas, as well as
  names that can.be considered unofficial version";
- "these names should not overwrite the current boundaries we have come up with - but possibly though raise issues if
  warranted";
- "You will of course use the olex depth model to get the best estimate of the location of an örnefni (something we
  actually forgot to do for the more "local" featured örnefni in the sea-charts)", "like obvious mounds", "Similar
  things apply to obvious deeps", and "The location of e.g. a mound is different from the location of the text".

## 1. What is at hand (measured 2026-11-09)

- **The official layer** is the örnefni map's (`out/names.csv`, `out/areas.geojson`):
  - 1,467 chart sea names from TODO 186's reading, 326 of them with an area (360 pieces: 101 seabed, 259 bays);
  - parents from decision 302's three versions, seabed and bays apart; the bays from the one pass (decision 304);
  - a zoom from each area's size;
  - a place from the chart: the label inside its area, a point inside the area, a named ring (decision 301), or else
    the label. A point name's place is mostly its label's.
- **The gazetteer** (`curated/place_name/`) holds 9,384 keys: 8,243 names, 575 descriptions and 566 composites.
- **Shared names:**
  - 835 name keys are an official name's key, and 114 more join one only through their proposed group (decision 272,
    not reviewed);
  - 1,641 match some name of TODO 186's reading, land names included.
- **Not on the charts: 6,601 name keys.** By the source families that name them:

  | family | names |
  |---|---|
  | channel (MFRI's sampling stations) alone | 1,789 |
  | the plotter (one person's marks) alone | 1,136 |
  | Oracle's place tables alone | 908 |
  | LMÍ alone | 705 |
  | Trackwell alone | 532 |
  | the tag recaptures alone | 341 |
  | the Vestmannaeyjar map alone | 77 |
  | others alone | 13 |
  | two families or more | 1,100 |

  380 of them have no position.
- **The deep ones.** By the gazetteer's depth (GEBCO), 1,440 lie deeper than 200 m: 978 at 200-500 m, 287 at
  500-1,000 m and 175 deeper. Of these, 501 are the plotter's alone, 261 channel's, 240 Trackwell's, 121 Oracle's and
  239 from two families or more.
- **Outside the official areas.** Of the 6,221 with a position, 3,043 lie in no official area, 1,071 of them deeper
  than 200 m. The charts frame little beyond the shelf.
- **Trackwell.** 873 names not on the charts carry Trackwell, 619 of them from one vessel alone.
- **Shared names' places.** Of 833 shared names with a position, the gazetteer's median lies within 5 km of the official
  place for 437, at 5-20 km for 245 and over 20 km for 151. Oracle's squares are among the families of 115 of those
  151 (alone on 37), and LMÍ is alone on 13. The gazetteer's median counts occurrences, so it is no statement of place;
  §2.3 measures afresh.
- **The seabed:**
  - plan 070's scan (2026-11-06) used the Vestmannaeyjar map, whose marks are within about 90 m:
    - its 7 leirur all lie below their surroundings within 1.5 km, and 4 of its 5 holur too;
    - its 38 klakkar lie above their surroundings no more often than chance (0.42);
    - the plotters' hill marks lie above theirs 0.66 of the time, against 0.54 for other marks;
  - decision 301 found 325 named rings on the charts, 319 of them TODO 186's names. A ring lies a median 1.6, 0.9 and
    0.5 km from its name's label at 1:300 000, 1:100 000 and 1:40 000. At 1:100 000 the grid agrees on 866 of the 898
    rises it can judge.

## 2. The design (proposal)

### 2.1 Two layers, one direction

- **The official layer** is the charts' names, with their places, areas, parents and zoom (the örnefni map's), after
  §2.2. It is an input here, frozen by version (its files' md5s). Nothing in this plan writes to it after §2.2.
- **The layer in use** is every other source's names:
  - Trackwell, the plotter, channel, the tag recaptures, uv and Oracle's place tables;
  - the documents, the Vestmannaeyjar map and Skjálfandi;
  - LMÍ, as vocabulary only.
- **The links run one way.** A name in use is linked to the official layer: a form of an official name, a child of an
  official area, or a name beyond them. The official layer never takes a position, an outline or a parent from the
  layer in use.
- **Where the two disagree, an issue is raised** (§2.6) for the maintainer. A change it leads to enters the official
  layer as a rule applied to every name (decision 304: rules over ad hoc), never as one name moved by hand.

### 2.2 A small feature where it is, its text beside it

The maintainer's point: the place of a mound or a hole is not the place of its text. A chart sets the text beside the
feature, and the label is all TODO 186 read, so most small names now sit at their text.

- **Two positions per name.** `feature_lon`/`feature_lat` give where the thing is: a mound's top, a hole's or a small
  deep's bottom. `label_lon`/`label_lat` give where its text is drawn.
  - The map marks the feature (a dot, or the ring where the chart draws one) and sets the text beside it, as a chart
    does.
  - An area name's text stays in its area, as now.
- **Which names.** A point name whose word names a feature:
  - a high: -hóll, -klakkur, -boði, -bunga, -hæð, -hnúkur;
  - a low: -hola, -pyttur, -gjá, and a -djúp, -dýpi, -áll or -dalur with no area of its own.

  The word lists are `curate/place_name.R`'s `terrain()` and the study's `AREA_WORD` (plan 070), extended where the
  check asks. A name with no feature word is not moved. Neither is a wreck or foul ground: -festa, and Flak alone, is
  no seabed feature.
- **Where to look.** Within the error of the position the name comes from:
  - for a chart label, the label-to-ring distance at its scale (decision 301's, the 80th percentile);
  - for a source in use, its error as measured in §2.3.
- **What counts as obvious.** One local high (or low) inside that radius whose prominence stands well above the grid's
  noise there, found at the feature's own scale. Two candidates of like prominence, or none, and the name is not moved.

  Two detectors are prototyped side by side, not reasoned out:
  - scale-space blob detection (Lindeberg 1998, plan 070 §5);
  - a local BPI at a few radii, with a prominence threshold.
- **What is kept.** The source's own position stays beside the seabed's, in `src_lon`/`src_lat` with a
  `feature_basis` (`ring`, `seabed`, `mark`, `label`), as wacky coordinates keep `w_lon`/`w_lat`. A named ring stays
  the ring's position; the grid only checks it.
- **The check, run before anything is applied.** It uses the names whose place has a witness of its own:
  - the named rings: does the step, started from the label, land on the ring?
  - the Vestmannaeyjar map's marks (within about 90 m).

  Every name gets one outcome: moved nearer its witness, moved farther, not moved (nothing obvious, two candidates, no
  feature word), or not judged (no grid). The rule is fixed before the run: the step is applied only to the kinds and
  scales where moves nearer clearly outnumber moves farther, counted by chart scale and kind. A kind that fails keeps
  its source position, as the klakkar may.
- **The official names first.** This is the one change to the official layer in this plan, made by rule for every
  small name, with the chart's positions kept beside.

### 2.3 Each source measured against the official layer

Plan 070 §2.2 stands:
- the unit of evidence is an independent statement (a vessel within a source, a document, a mark), never an
  occurrence;
- in a Trackwell run, the stamp counts most and the last hauls least.

What is new: the official layer is an independent witness, so each source's error is measured, not assumed.
- **Where:** on the names both layers hold (835 keys; the 114 by group once the groups are reviewed or taken as
  proposed).
- **What:** each statement's distance from the official place, and whether it lies inside the official area.
- **By what:**
  - by source;
  - Trackwell by vessel and by place in the run (the stamp, mid-run, the last four);
  - the plotter as one person's marks;
  - each by chart level and kind, never pooled (the maintainer: different rules may apply at different zoom levels).
- **The weight:** a source's weight follows its error. Trackwell's "use last value" is measured here, not presumed.

### 2.4 Every name in one outcome

Each of the gazetteer's 9,384 keys gets one outcome:

| outcome | what it is | what follows |
|---|---|---|
| `form` | another form of an official name (unofficial, older, misspelt): the same key, its proposed group, a synonym relation (plan 044), or the same root within one family of feature words (-djúp/-áll/-dýpi; -grunn/-banki/-flak, the history's rule), its statements at the official place | "also called" on the official card, with source and years; search finds the official name by it |
| `child` | a name not on the charts whose place lies in one or more official areas | its parents with weights, seabed and bays apart (decision 302's method: none, one or several) |
| `beyond` | a name not on the charts, placed outside every official area: the slope, the basins, the gaps | its frame zone (plan 070 level 0) and its nearest official names by distance; no parent invented. The deep gems are here (1,071 with a position) |
| `homonym` | an official name's key whose statements stand at another place, a place of its own (plan 044's places) | a name in use of its own, linked to the official one as a namesake |
| `attested` | a name too weakly placed to draw: Oracle's squares alone (anchors, TODO 144), LMÍ alone (vocabulary), a text with no position, a single statement whose error exceeds the area it would sit in | listed and searchable; shown on the card of the official area it falls in, if any; no point on the map |
| `not_a_name` | descriptions, composites, relative phrases ("Innan við …"), a species' ground (Grálúðumið), the plotter's defaults | counted: 1,141 keys by class, more by rule |

The rules are fixed before the run. The counts sum to the gazetteer's keys, and a key no rule takes is listed as
unexplained.

### 2.5 A name in use, placed

- **Its point** is the weighted median of its independent statements; a vessel's statement is its stamps' median. A
  mark's position is used where there is one. Then §2.2 for a small feature. Tows lie on a feature's flanks (plan 070
  §1), so a hill name's tows ring its top rather than mark it.
- **Its extent** is soft: a core and a fringe from the weighted density (plan 070 §2.1), drawn only when the name is
  chosen. It is never cut to an official outline, and it never cuts one.
- **Its zoom** follows its extent, as the official names' does (35 px), and is never before its official parent's. A
  name in use never wins a label collision against an official name.
- **Its years** come from its statements (Trackwell 2003-2022, the plotter's exports, channel's stations), shown on its
  card. Names change with time, so a name is never moved to another ground by date.

### 2.6 Issues, raised by rule

An issue names an official name or boundary and the statements against it. It is raised only where the evidence is
independent of what it questions and enough by §2.3's weights. Proposed: two families, or three vessels from two
sources, after the weights. The kinds:
- **used elsewhere:** an official name's core in use lies outside its official area, or farther from its official place
  than the sources' error;
- **across a boundary:** a name in use whose core is split between two official neighbours, 30 % or more in each.
  Decision 304's line between them is questioned;
- **parent contradicted:** a child that the official family puts under one area is used inside another;
- **the feature contradicted:** the statements of a small name ring a feature other than the one §2.2 chose.

Some disagreements are card lines, not issues: an official name that no source uses where the ground is fished
(Seyðisfjarðarflói, "printed, not in use"), and one name in use spread over two official areas.

Each issue is a row: the official id, the kind, the statements by source, vessel and years, and a score. It shows as a
wart on the map at its place, with a link. The maintainer's answer (keep, a homonym, a rule to change) enters through
a ledger (plan 045 ask c, plan 067 ask a: where a person's decisions are kept).

### 2.7 On the map

The örnefni map (a page of its own) gains:
- the names in use as a layer of their own, lettered apart from the charts' names, off at the start, behind a switch;
- on each official card, "also called" and "in use": the statements by source and years, the core against the
  official area, and any issue;
- for each name in use, a card of the same build: its sources, years and statements, its parents or frame, its history
  by root (`02_history.R`), and its warts ("not on the charts", "one vessel", "Trackwell: may be a last value",
  "placed on the seabed from …");
- each small feature marked where it is, with its text beside it (§2.2), for both layers.

## 3. Steps

Each step is a script in the study (`$FISHYDATA/archive/2026-11-09-ornefni-in-use/`), with its log in `notes/`. The
örnefni map's `01_names.R` and `03_page.R` read the study's outputs. The steps become a target after the maintainer's
review, on the preprocessing side: no AIS, no effort.

1. **The seabed step on the official small names** (§2.2): two detectors prototyped, checked on the rings and the
   Vestmannaeyjar marks, every name in one outcome. Applied in the örnefni map's `01_names.R` for the kinds that pass,
   with the feature and its text apart, and the map rerun.

   **Run 2026-11-09** (Claude (AI); the study README's "Step 1", the rule written before the run). 758 point names
   were searched (394 highs, 30 lows, 334 skerries) by two detectors.
   - **Passed: the highs printed at 1:40 000.** Detector A, a local extreme, had 24 good moves and 2 bad on the rings
     and marks. It placed 31 names on the grid's high, a median 0.44 km from the label, and the map was rerun. Nothing
     else changed.
   - **Failed:**
     - the highs at 1:100 000 (35 good, 17 bad: 2:1 against the 3:1 asked);
     - the deeps, which only the displacement test can judge: the rings hold 2 hollows;
     - the skerries.
   - **The grid test.** Started on the Vestmannaeyjar marks themselves, the detectors find almost none of them within
     0.15 km (klakkar 0-2 of 29, holur 0 of 6). The displacement test there measures the grid more than the method,
     and the deeps have no fair witness yet.
   - **Why the 1:100 000 highs fail** (the same day, read-only).
     - In 14 of the 17 bad moves the grid holds no high in the ring's own chart cell. The detector takes the lone
       high within reach, which passes as obvious with nothing to compare it with.
     - Of those 14, the grid misses the charted shoal in 5 (Hafnarrif 3.7 m on the chart, 36 m on the grid); in 4 the
       shoal is joined to the shore or land; in 5 the chart prints no depth to compare.
     - Mending it (a lone candidate not obvious by itself; the ring's depth as a test that the grid holds the shoal)
       needs rings it was not tuned on: the study README.
   - **The mend** (the same day, at the maintainer's word: "Yes, try the mend").
     - Detector A2 takes a high only where it is a closed high on the grid: no higher ground, land or window edge in
       its area within the drop. Its prominence must reach 5 m or 2 % of its depth.
     - It was tuned on the west half of the failing groups' witnesses (no pair passed there) and judged on the east
       half by the rule unchanged.
     - **The 1:100 000 highs pass**: 19 good, 3 bad. Over both halves A2 makes 36 good and 9 bad moves where A made
       35 and 17. The 1:100 000 skerries fail (2 good, 7 bad).
     - 19 more names moved, a median 0.75 km: 50 in all on the örnefni map.
2. **Freeze the official layer:** names, feature and label positions, areas, parents, an id each, with md5s.
3. **Measure each source** against it (§2.3).
4. **Every key in one outcome** (§2.4).
5. **Place the names in use** (§2.5), with §2.2 for the small features.
6. **Issues by rule** (§2.6).
7. **The layer, the cards and the issues on the örnefni map**, checked in the browser against a list of click paths.
8. **The maintainer's review on the map**, the answers into the ledger (ask e).

   **Begun 2026-11-09**, ahead of steps 2-7, at the maintainer's word ("we should start to "correct" or improve
   things. Lets start with Eldeyjarboði").
   - **The ledger**, in the in-use study's `review/` folder under `$FISHYDATA` (internal), holds the maintainer's
     words and choices. The in-use study's
     `05_reviewed.R` draws each name on the grid by one of three rules:
     - a top, the local high nearest a chosen point;
     - a mound, the closed high holding its tops, down to the last level before it takes in another high of its own;
     - a part, a mound's share falling to one of its tops.
   - **The uses judged:** kept on the place; near, on its ground above the deep, placing nothing; an error across
     the deep, kept in the data and used by nothing; a vague word's, placing nothing.
   - **The örnefni map** reads it: a name the charts lack joins with its area, a chart name takes the review's point.
   - **The first entry:**
     - Eldeyjarboði, the chart's point, moved onto its 49 m high;
     - the mound it lies on, 42 km² to 135 m, and the mound's south-west part, 30 km², drawn as areas under names in
       use (the names are in the study, internal);
     - a word in use for its vicinity vague;
     - 1,172 uses across the deep errors, 1,136 of them east and south-east of the ridge and on the north-east spur.
   - **Verdicts on the map** (the same day, the maintainer: "a yes/no marker in the popups for these "Örnefni" that
     do not come from "sjókort" ... these answers would then be gathered and not used in the final map proper";
     "Yes, build it").
     - On the örnefni viewer each name in use (the gazetteer's names layer) takes a verdict in its pop-up: right,
       wrong place or not a name, with a line of the maintainer's own.
     - The answers are kept in the same folder, `place_name_verdicts.csv`, a row an answer, never a row changed: the name's
       key, the place judged, the answer, the line, the time. A later answer replaces the earlier.
     - This is ramb's `rb_map_serve(verdicts = )` and `rb_map_verdicts()`, 2026.11.09.
     - Step 4 reads them: "not a name" puts the key in `not_a_name`; "wrong place" leaves the name's uses within
       5 km of the point judged out of its place, kept and labelled. The ledger keeps the considered cases.

## 4. How it is checked (bookkeeping, not modelling)

- Every key is in one outcome, and the outcomes sum to the gazetteer's keys.
- After steps 2-7 the official layer equals the frozen one, file for file (md5s). This is the guarantee that no name in
  use moves a boundary, a place or a parent. Step 1 is the one change to it, by rule, with the chart's positions kept
  beside.
- The seabed step puts every name in one outcome against its witness, and a kind is applied only where it passed.
- Every issue lists its statements, none of them from a source left out of §2.3's weights.
- Counts are split by chart level and kind, never pooled.

## 5. Asks

- a. **The lettering of the names in use**, and whether they show at the start. Proposed: apart from the charts' names
  (grey), off at the start.
- b. **The threshold for an issue.** Proposed: §2.6's.
- c. **LMÍ alone (705) and Oracle alone (908)** as `attested`, not placed. Proposed: yes. LMÍ is vocabulary
  (2026-11-06), and Oracle's squares are anchors (TODO 144).
- d. **The plotter**: one person's marks, 1,136 names that only it holds, 501 of them deeper than 200 m. Proposed: each
  mark a statement, the person one witness; on the map under the plotter's name, internal only.
- e. **Where the answers to issues are kept** (plan 045 ask c, plan 067 ask a). **Answered** (the maintainer,
  2026-11-09): a ledger, one entry per place in the maintainer's words; at first `overrides/place_names.yml`,
  moved the same day into the in-use study (`$FISHYDATA/archive/2026-11-09-ornefni-in-use/review/`) at the
  maintainer's word ("Yes, do it"), since its names come from Trackwell's and the plotters' marks, internal, and
  this repo is public. Its first entry is Eldeyjarboði's (§3, step 8, begun ahead of steps 2-7).
- f. **How a feature is marked under its text**: a dot, a small ring, or the chart's own symbol. Proposed: a dot, or
  the ring where the chart draws one.

## 6. Not in this plan

- **The effort.** Placing a coarse name on its gear's effort (plan 070 §2.3) is flow-side work. Oracle's squares stay
  anchors here.
- **Unread chart material:** the 729 harbour-plan windows TODO 186 did not read, and the hazard symbols' pass
  (decision 301).
- **Other place-name work:** the review of the proposed name groups (TODO 144), and plan 067's records (parked,
  TODO 193).
- **Publishing.** The map stays internal: the charts are Landhelgisgæslan's, the records name people, and plan 001
  draws the boundary.
