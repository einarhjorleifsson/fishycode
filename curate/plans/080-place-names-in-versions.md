# 080 — The place names in versions: a ladder from the charts' names to every source, each version frozen, measured against the one before and shipped

**status:** executed — versions 1 and 2 built (decisions 332, 334, 336); its forward design (§3, §5.3-§5.6) superseded by plan
081 on 2026-11-20 at the maintainer's word (decision 337), its §4 rules kept there; version 2 built 2026-11-19 for review (decision 334); revised the same evening at the maintainer's word from a ladder by source to versions by region, every source a region needs taken in, Trackwell among them (§3, §5.3-§5.6); asks k-q answered the same night (decision 336): k, m-q as proposed, the order side by side, l "Several at a time"; written 2026-11-19 at the maintainer's word ("Otherwise write up the plan"), from his seven points
of the same day and a read-only count (§2); revised the same day at his word, from one version's design to a ladder of
versions (§1); asks a-j answered the same day (decision 333): a-h and j as proposed, i "None for now"; version 2 built the same day for the maintainer's review (§5.2, decision 334); amended the same evening at his word: ÍSOR's craters and mounds brought into version 2 from version 3 (§5.2a) · **see:** plan 074 (version 1: step 12, decision 332), plan 078 §3.9 (the names in
ogisdata), plans 044, 045, 067, 070, 071 and 073 (§6), TODOs 144, 181, 186, 193, 194, 197, 199 and 201, the
named-features study (`$FISHYDATA/archive/2026-11-11-named-features/`, its README and scripts 118-126 on the ridge)

Drafted with AI assistance (Claude) on 2026-11-19 and revised with it the same day; a person has not yet checked it.
What §2 calls measured, Claude measured.

## 1. Why

The maintainer, 2026-11-19, on how to proceed: "The plan should be made from a "holistic view", were we will have to go
through things in systematic stages, i.e. versions of placenames. We may be should e.g. start with what we now got and
fix those part, but then the next version goes further down the ladder, e.g. the inclusion of the Trackwell data (which
by the way will be part of the final version), etc."

So the place names are built as a ladder of versions. Each version adds one kind of thing to the one before, is frozen,
is measured against it (every difference explained), is reviewed by the maintainer on the map, and ships in ogisdata
before the next begins. Version 1 is built (plan 074 step 12). The last version holds every source, Trackwell's names
among them.

His points of the same day are information for the rungs, each placed where it bites (§5):

- "The ÍSOR renaming - Steinahóll -> Steinahólar. I.e. I will be "responsible" for overwriting names - we will keep
  account of those. Question if we should actually do such corrections in the ogis editor." (version 2)
- "We keep or edit slightly the ISOR areas" (version 2)
- "We must decide how to decide on offshore names when we have two sources (Geirfuglasker e.g.)" (version 2)
- "We must also try to make a clear distinction "how a name appears" vs the pinpointed coordinates (aka Díönuboði)"
  (version 2)
- "We must also "curate" the morenas and other features from ISOR - these will not be part of örnefni but a separate
  file. They are though helpful, e.g. when determining boundaries." (version 3)
- "The ÍSOR mounds, Steinahóll 1, 2, ... etc - there are then names we keep for the mounds, if a mound does not already
  have a name"; "it is in the ISOR data"; "On ISOR craters - my plan is that we at a later date put a proper name to
  them." (version 3, and alongside)
- "The trackwell names - we know they are a mess, but at one time we need to incorporate at least those that are
  non-ambigous. Question how we "bring them in" to place name table." (version 4)

**Revised the same evening, by region** (the maintainer, 2026-11-19, moving from Reykjaneshryggur to the Kolbeinsey Ridge
before the first was done: "my hunch is we need to revise a little bit the plan for this version of Örnefni. Going to "Kol..."
you will learn something so we can revise the plan"; of the finding below, "Yes, draft it - but I think if we are going
regional we have then to take in more sources, like Trackwell"; and "Trackwell is though notorious, if you have not heard me
say so"). The ladder by source (versions 3-6 below, as first written) cut across what a region needs: on the Kolbeinsey
Ridge the names worth having are LMÍ's copies of Trackwell's and Hafrannsóknastofnun's deliveries, which version 1 leaves
out; three of the nine hold ÍSOR's craters, six are slopes, valleys and ridges that want the landforms and the depth model.
So the place names go forward region by region, each region taking in every source it needs (§3, §5.3-§5.6); the model and
the rules of versions 1 and 2 hold everywhere.

## 2. Measured (by Claude, 2026-11-19, read-only; no person has checked the counts)

- **Version 1** (`curated/reference/marine_feature.parquet`, decision 332) holds 27,305 rows: 25,879 names (LMÍ 19,958,
  the charts 5,899, ÍSOR 22), 801 aids, 625 wrecks. Each row has one place (`lon`, `lat`) with its basis (the names: an
  area's middle 12,438, a point 5,367, the finest chart lettering 4,628, a line's middle 1,889, LMÍ's position 776, 1c's
  anchor 288, an island group's middle 272, the maintainer's hand 105, others 119), an angle, a zoom (`z_rule`) and a
  vertical label offset (`label_dy`). No column says where a name is drawn apart from where its thing is.
- **Díönuboði** is one row: the charts' name, a rock or shoal, placed at 1c's anchor (the shoal's top), shown from
  zoom 11. The charts letter it 12.7, 2.4 and 0.8 km from its shoal at 1:2 000 000, 1:300 000 and 1:100 000 (plan 074
  step 1c): the lettering is how the name appears, the shoal where the thing is.
- **Geirfuglasker** off Reykjanes is two rows of one name, the charts' finest lettering and ÍSOR's area middle, about
  2.4 km apart, ÍSOR's flagged `namesake_inside`; LMÍ's Geirfugladrangur lies about 6 km west-southwest of the
  lettering. Vestmannaeyjar's Geirfuglasker, an island at LMÍ's position with a light, is a namesake 130 km east.
- **ÍSOR's names in version 1**: 22, ÍSOR's spelling the name; 4 carry the maintainer's name as a synonym (Steinahólar
  beside Steinahóll), so his name is not the one used.
- **ÍSOR's raw layers** (`raw/external/isor/`): craters (points) 740, 704 of them labelled by a system or region and a
  number in 28 stems ("Steinahóll crater 1" to "17"; "Reykjanes Ridge crater" 355); fissures (lines) 378, 351 numbered
  ("Steinahóll 1" to "9"); volcanic areas 1,307, 602 of them numbered seamounts ("Seamount<100m", "Seamount 100-500m",
  "Seamount >500m"). ÍSOR spells a system differently between layers (Grjóthryggur and Grjótahryggur, Hóllinn and
  Hólinn). Its landforms: terminal moraines 728, glacial streamlines 1,674, troughs 28, the shelf break and the LGM
  grounding line one each, canals along the shelf edge 55, turbidity or bottom-current channels 159, gravity
  streamlines 549, meltwater channels 21, plough marks 8,265; dykes 784, tectonic lines 7,586, submarine landslides
  202, scarps 1,158, offshore geothermal sites 242; the substrate (68) and sedimentation rate (42); coastal type 2,452.
- **The maintainer's edits** (`overrides/marine_name_edits.csv`): 131 rows, move 66, move and turn 39, revert 19,
  turn 7. The page (`products/marine_feature_map/`) writes a place, an angle, a zoom or a revert; no rename and no
  verdict on a candidate. The file is in the public repo.
- **Trackwell on the ridge** (the study's 118-126): a provenance rule kept 39 names (120); the maintainer judged the
  hauls of no use for placing the ridge's mounds, the trawls towing the systems' flanks, with exceptions on banks
  fished on top (the study's README, "The maintainer's verdict, on the heat maps"). Its names were held internal until 2026-11-19,
  public since (decision 335); its wrong years are among its faults (TODO 181).
- **The gazetteer's other sources** (plan 044, staged in `sources/ornefni/`): Trackwell's hauls and areas, the plotters'
  marks, tracks and wrecks, MFRI's Oracle names, fiskislóð, the tag recaptures' places, documents, articles and maps,
  channel names, underwater-video areas; and, outside it, the Breiðafjörður list of 2007
  (`raw/external/ornefni/breidafjordur/`).

- **The Kolbeinsey Ridge** (north of 67.2° N, 20-12° W; the evening of 2026-11-19): our list holds 4 names there, all broad
  (Kolbeinseyjarhryggur 328 km, Norðurbrún 281 km, Norður-Atlantshaf, Íslandsslétta); LMÍ holds 9 more, all left out by
  version 1 as copies (8 of Trackwell's delivery of 2020, 3 of them citing Fiskifréttir 2014: Gígurinn, Gamli Skratti,
  Litli-Skratti, Hólakantur, Hraunið, Dauðidalur, Litlihryggur, Ostahryggur; and 1 of Hafrannsóknastofnun's, Kolbeinseyjargrunn),
  rough shapes of 10-21 vertices and 18-236 km²; 3 of the 9 (Gígurinn, Gamli Skratti, Litli-Skratti) hold 1-3 of ÍSOR's craters each (the shallowest 236-340 m), 6
  hold none, the nearest crater 6-40 km off: slopes, valleys and ridges by their endings. ÍSOR has 57 craters, 12 guyots,
  77 seamounts and 38 ridges there.
- **LMÍ's copies left out, all Iceland**: 246, of Hafrannsóknastofnun's delivery of 2020 125 (107 fishing grounds, 18 skerries,
  shoals and the like) and of Trackwell's 121 (all fishing grounds); 133 shallower than 200 m on the depth model, 81 at 200-500 m,
  30 deeper. Version 2 brought one in by hand (Gullhóll, decision 334).
- **Trackwell's own delivery** (the gazetteer's staging, plan 044): 1,094 area names and 1,372 names on 484,734 hauls; public since 2026-11-19 (the maintainer: "Treat all trackwell stuff public", decision 335).
  The maintainer has judged its hauls of no use for placing the ridge's mounds, the trawls towing the systems' flanks (the
  named-features study's README), and its years wrong in part (TODO 181).

**Assumed, not measured:**
- that each rung needs the one before it (§3), so the order is not a matter of taste;
- that ÍSOR's features are where ÍSOR draws them; their positions are not tested here beyond the craters' mounds (the
  study's 125);
- that most of a new source's names join a name or a feature by rule, and few are left for the maintainer;
- that the page can carry a rename and a verdict as it carries a move, with no new kind of page.

## 3. The ladder, revised: versions by region

*As revised the same evening (§1).* Version 1 is built; version 2 corrects it and brings in ÍSOR's craters and mounds (§5.2,
§5.2a), its review on Reykjaneshryggur under way. From there each version finishes several regions at a time (ask l): within a region every
source it needs comes in (§5.4), the names are placed on features (§5.3), the maintainer reviews it on the page, and the
version is frozen, measured against the one before and shipped. A region not yet reached keeps what the version before gave
it. The model and the rules of versions 1 and 2 hold in every region (§4): where the thing is apart from its label, the
ledgers, one name from two sources, ÍSOR's area over LMÍ's, every record in one outcome.

The regions (Claude's proposal, ask k; the order the maintainer's): Reykjaneshryggur (its volcanic systems, under way); the
Kolbeinsey Ridge, north of Grímsey; Vestmannaeyjar and the south shelf; Faxaflói and Breiðafjörður with the west shelf; the
Westfjords' shelf; the north shelf from Húnaflói to Melrakkaslétta with the Tjörnes zone; the north-east and east shelf; the
south-east shelf; the Iceland-Faroe Ridge and the deep ocean (Íslandshaf, Vesturdjúp, the Ægir ridge).

*The ladder as first written, by source, kept for the reasoning; its rungs 3-6 are now the ingredients of every region (§5.4):*


| Version | Adds | Needs | Done when |
|---|---|---|---|
| 1 (built 2026-11-19) | the charts' names, LMÍ's names at sea, on islets and the shore's landforms, ÍSOR's 22 names; the aids; the wrecks; one place a row | — | decision 332; in ogisdata 2026.11.19.3 |
| 2: version 1 corrected | no new source. Where a thing is apart from how its name shows; the name used apart from every source's spelling, the maintainer's renames a ledger; one thing from two sources by rule, the conflicts listed; ÍSOR's areas kept or edited slightly; version 1's known faults and flags settled | version 1 | every item of §5.2 settled or listed as left, with why; frozen; in ogisdata |
| 3: the seabed's features | ÍSOR's landforms, volcanic and tectonic features as a curated table of their own, not names; each name pointing to its feature; ÍSOR's numbered crater and fissure labels as placeholders on mounds with no name | version 2's model (a name's thing apart from its label) | every ÍSOR record in one outcome; every name with a feature or a reason for none |
| 4: Trackwell | Trackwell's unambiguous names, behind an acceptance rule, placed on features (internal as first written; public since decision 335) | version 3's features: a Trackwell name is placed on the feature that holds its use, not where its hauls lie | every Trackwell name in one outcome; the taken in the names |
| 5: the other names in use | the gazetteer's other sources (the plotters' marks, MFRI's names, fiskislóð, the tag recaptures, documents and maps), the Breiðafjörður list, Trackwell's ambiguous names looked at again; each linked to the names before it in one outcome (plan 071's way) | versions 2-4: the names and features they link to | every source record in one outcome |
| 6: the extents | each name's area and its boundaries: troughs shared by names, the grounds' limits, the bays' outer limits (TODO 201), the outlines of plan 070 and plan 074 step 10, the bottom type where a witness exists | version 3's features (moraines, troughs, the shelf break) and versions 2-5's names | every areal name with an extent and its basis, or listed |
| alongside | the craters' proper names (the maintainer's, "at a later date"); the names' stories, their history and records (plan 067, timarit.is, the old charts) as annotations | — | each a ledger row or a record, entering at the next version |

Each rung needs the one before: version 2's model (a name's thing apart from its label, the ledger, the rule for two
sources) is the door every later source enters by; version 3's features are what version 4 places Trackwell's names on;
version 5 links the remaining sources to what 2-4 settled; version 6 draws extents once the names and features stand.

## 4. What holds at every version

- **A version is frozen**: its inputs, rules and outputs; written by `write_curated()` with a version stamp (ask b); a
  decision record when it is made; never rewritten after. A fix found later enters the next version.
- **Measured against the version before**: every row in one outcome (kept, changed, new, gone), every difference
  explained; the review on the map (`products/marine_feature_map/`) before the next version starts.
- **Shipped**: each version a new ogisdata version (plan 078 §3.8's rule).
- **Every source record in one outcome**, the unjudgeable included (AGENTS.md: checks are bookkeeping).
- **Nothing destroyed**: every source's spelling, place and extent kept beside the one used; the name used, its place
  and its label each with a basis.
- **The maintainer's hand as ledgers**, appended, read back by the build as reviewed inputs: those on public sources in
  `overrides/` (as now), those on internal sources (the plotters, the internal wreck lists) under `$FISHYDATA`, never in this
  repo; Trackwell's are public since 2026-11-19 (decision 335) and go in `overrides/`.
- **Internal flagged**: a row from an internal source carries `internal`, so a copy shared outside MFRI drops it by one
  filter (as the wrecks do in version 1).
- **The asks of a version are put when it is reached**, not all now; §5 lists those already known.

## 5. The versions in turn

### 5.1 Version 1 (built)

As plan 074 step 12 and decision 332 describe it. It ships in ogisdata 2026.11.19.3, or 2026.11.19.4 with the demo's
filters (plan 078 §4.3).

### 5.2 Version 2: version 1 corrected

No new source; the model fixed and version 1's open items settled.

- **Where a thing is, and how its name shows** (Díönuboði): each name carries two sets of columns, each with its basis.
  Where the thing is: its point (`lon`, `lat`), its geometry (an area, a line or a point), `place_basis`. How the name
  shows: `label_lon`, `label_lat`, `label_angle`, `label_zoom` and the offset, `label_basis` (rule e, a chart's
  lettering as a guide, the maintainer's hand). A point kind (a rock, a shoal, a skerry, a wreck, an aid) has a dot at
  the thing and its label beside it, as the charts letter it; an areal kind its label inside. ogis's `og_names()` takes
  `label_lon`, `label_lat` and a geometry; whether it draws a point geometry as a dot is to be checked, and if not, a
  small ogis step.
- **The name used, and the ledger** (Steinahóll to Steinahólar): every source's spelling kept (`name_source`, with its
  source), the name used a column with its basis. The maintainer's renames are ledger rows (the row, from, to, who,
  when, why), made on the page (ask e); ÍSOR's four synonyms of version 1 become rows (his name used, ÍSOR's kept).
- **One thing from two sources** (Geirfuglasker), one order of precedence for each attribute, not one source over
  another (asks f-h):
  - the same thing or not: the same name (spellings joined as the study's rules join them) and places that meet (a
    lettering inside or beside the other's area, or within a point kind's reach); otherwise namesakes, both kept
    (Vestmannaeyjar's and Reykjanes's Geirfuglasker); the doubtful listed for the maintainer, both kept, no single cut
    deciding (as for the wrecks, plan 074 ask o);
  - the spelling: the maintainer's, LMÍ's, the charts' print, ÍSOR's;
  - where the thing is, by kind: an island, skerry or submerged rock at LMÍ's position (settled, plan 074); a volcanic
    feature at ÍSOR's; a bank's or mound's top on the depth model (1c's anchor); an areal sea name from its letterings
    and area; the maintainer's hand over all;
  - how it shows: rule e, the charts' letterings a guide;
  - the conflicts a list, a layer on the page.
- **ÍSOR's areas** kept as ÍSOR delivers them; the maintainer's slight edits a geometry override beside the original,
  made in QGIS into a GeoJSON file, not on the page (a polygon editor in a web page is a large build for a few areas).
  Ask i answered "None for now": ÍSOR's areas as delivered in version 2, their edits left to a later version.
- **Version 1's known faults and flags**: the duplicates flagged (Faxabanki, Skerjafjörður); the island pairs on one
  anchor; 106 near-spelling pairs; the Breiðafjörður approach charts' offset of about 500 m; Eldeyjarbanki's crest,
  Skeiðarárdjúp, and the long diagonal features' boxes (a corridor along the line); the other piers' names at 1:10 000;
  decision 332's code ends (the wreck and aid lists' digit precision, `wreck_accounting.R` reading the study's file,
  `tz_point()` into `R/`).
- **The review**, region by region on the page, the conflicts and the faults as layers (ask j).
- *Built 2026-11-19, a candidate* (decision 334; by Claude, no person has checked the counts): version 1 frozen
  (`reference/names/freeze_version.R`, `curated/reference/place_names/v1/`); the ledger's renames (his four ÍSOR names);
  `marine_name.R`'s version 2 (the thing apart from its label, 7,441 point kinds; 200 pairs within 10 km, one thing 5,
  whole and part 3, doubtful 15, namesakes 177); every check holding and every difference from version 1 explained
  (`curate/checks/place_name_versions.R`); the page with a Rename box, dots at point kinds, a pin for where the thing is (the maintainer's question the same evening) and the review layer. The
  thresholds of the rule for two sources are Claude's (decision 334), the maintainer's to correct. Left: his review, then
  version 2 frozen and shipped; ogis's `og_names()` to draw a point kind's dot; the near-spelling pairs and the corridor
  faults not on the review layer.

### 5.2a Version 2 amended: ÍSOR's craters and mounds brought in (2026-11-19)

The maintainer, 2026-11-19, on LMÍ's Gullhóll, an octagon off the ridge on flat seabed: "This example ... is why the LMÍ is
just a fuckup when it come to the offshore proper. In particular Hafrannsóknastofnun source"; "ISOR had mound/volcano
locations ... My hunch is that we should really bring ÍSOR into this version. Know it is a change of plan, but in my view it
is has the best mound/volcano position there is. And if we bring this in now we can make the link here between the ISOR
mound position and "our" name." Proposed and answered the same evening ("Yes, as proposed"):

- **A table of ÍSOR's volcanic features, not names**, version 3's table begun: ÍSOR's 740 crater and guyot points and its
  1,307 volcanic areas (675 ridges, 614 seamounts, its 18 volcanic systems), each with ÍSOR's label as a placeholder and
  every attribute kept, built in the layers (`sources/isor/` to `staging/isor/`, a standalone script to
  `curated/reference/seabed_feature.parquet`, its accounting in `curate/checks/`). The other landforms (moraines, troughs,
  streamlines) and the 378 fissures stay in version 3.
- **A link from each name to its mound** (`seabed_id`), by rule: a name whose thing lies within its reach of a crater
  (a reach as the rule for two sources has it, the crater's 250 m) is linked to the nearest; for the sea's kinds (rocks,
  shoals, sea names, ÍSOR's points) the thing moves to the crater (ask h's "a volcanic feature at ÍSOR's", over LMÍ's
  position for a rock where a crater lies within reach), unless he placed it by hand; an island is linked only, at LMÍ's
  position; a crater within 3 km but beyond reach listed for review; a name inside a seamount and near no crater linked to
  the seamount; ÍSOR's own names linked to their areas.
- **On the page**: ÍSOR's craters as a layer one clicks; with a name chosen, *Link to this mound* (a ledger row `link`, the
  feature's id in `link_to`) moves the name's thing to the crater, *Unlink* undoes it.
- *Built the same evening* (decision 334; by Claude, no person has checked the counts): the table (2,047 features), 292 names
  linked to a crater by rule, 21 of ÍSOR's own to their areas, 2 to seamounts, 229 doubtful for review; the page's layers and
  link action; every check holding.

### 5.3 A region, step by step

1. **The region's bounds**, a polygon on the map (ask k); every source's records inside it listed.
2. **Its features**: ÍSOR's craters, guyots, seamounts, ridges and volcanic systems (in since §5.2a); ÍSOR's landforms where the
   region has them (troughs, moraines, the shelf break, channels, streamlines; ask p: in for all Iceland since 2026-11-19,
   decision 336; they carry no names); the depth model's own tops and lows where
   ÍSOR has none (plan 073's inventory; ask o). Features, not names, in `seabed_feature`.
3. **Its names**, from every source the region needs (§5.4), the same name from two sources joined by the rule of §5.2, each
   name's thing placed by its kind on a feature (a crater-like name on a crater, guyot or seamount; a slope, valley or ridge on
   the landform or the depth model's line), its label by rule e; a name no feature holds listed, not placed.
4. **Every record in the region in one outcome**: in the list, joined, a candidate for review, or left out with why.
5. **The review on the page**, the region's layers: its candidates, its doubtful pairs and links, its unplaced names; the
   maintainer's ledgers (moves, pins, links, renames, synonyms, verdicts).
6. **Done** when every record is in one outcome and the review is through: the version frozen (`freeze_version.R`), measured
   against the one before (`place_name_versions.R`), shipped in ogisdata.

### 5.4 The sources, and how each comes into a region

- **The charts** (`chart_names`, version 1's rules), as now.
- **LMÍ's names** (IS 50V), as now; and **LMÍ's copies** of Trackwell's and Hafrannsóknastofnun's deliveries of 2020 (246 left out by
  version 1): the *name* is taken, never the *place* (the maintainer, of Gullhóll's octagon off the ridge: "the LMÍ is just a
  fuckup when it come to the offshore proper. In particular Hafrannsóknastofnun source"); each placed on a feature by step 3,
  else listed (ask m). Their polygons kept as a weak witness of where the name is used.
- **ÍSOR** (the seabed map): its named systems and its features (§5.2a); its landforms as step 2 needs them.
- **The depth model**: features where ÍSOR has none (step 2), and the tops a name's thing is placed on.
- **Trackwell** (public since 2026-11-19, the maintainer: "Treat all trackwell stuff public", decision 335; and notorious: "Trackwell is though notorious"): its GPS trails are the messy part (the maintainer, of the decision: "that include the data from the gps trails - that is the messy part") and its names a mess too (carried-over
  names, namesakes, spellings, wrong years, TODO 181), and its hauls place nothing (the trawls tow the flanks). So a Trackwell
  name enters only as a **candidate**, by an acceptance rule (the named-features study's 120: each vessel one vote, a name
  carried in from another ground or a namesake left out, spellings joined), held to a feature its use falls on, and is in the
  list only by the maintainer's yes on the page (ask n); his verdicts rows of the page's ledger in `overrides/`. LMÍ's copies
  of Trackwell are the same names, published again through IS 50V: one name, two witnesses.
- **The other names in use** (the gazetteer's: the plotters' marks, internal; MFRI's own names; fiskislóð; the tag recaptures'
  places; documents and maps; the Breiðafjörður list of 2007): witnesses where a region needs them, a name from them a
  candidate as Trackwell's (ask q).
- **The extents** (TODO 201's troughs, grounds' limits and bays' outer limits, plan 070's areas): in a region when its names
  need them, else later.

### 5.5 What the Kolbeinsey Ridge would take

LMÍ's 9 copies (their names), ÍSOR's 57 craters, 12 guyots, 77 seamounts and 38 ridges, the depth model's lows and slopes for
the 6 names no crater holds, Trackwell's candidates there (counted when the region opens), and the charts' and LMÍ's 4 broad
names; its review on the page. It opens while Reykjaneshryggur's review goes on, side by side (ask k).

### 5.5a Reykjaneshryggur by the recipe (built 2026-11-19)

The region drawn by rule and opened; LMÍ's 35 copies in it brought in, placed on features; Trackwell's 268 names there in one
outcome each, 18 candidates for his Accept or Reject on the page (decision 336). His review of the region continues on the page.

### 5.6 Alongside any version

- The craters' proper names, the maintainer's, as ledger rows entering at the next version.
- The names' stories: a name's history and records (plan 067, timarit.is, the old charts), as annotations a click
  shows, not as places.

## 6. The threads folded in

Several place-name plans and TODOs are open beside plan 074. Each becomes a rung or stays where it is (ask d, answered as proposed; decision 333):

| Thread | Was | Settled | Its rung |
|---|---|---|---|
| plan 074 (TODO 199) | partly built | executed with version 1; its step 10 and its known faults carried here | 1, 2, 6 |
| plan 073 (TODO 199) | partly built | parked; its feature inventory and its names carried here | 3, 4; since the revision, step 2 of a region |
| plan 071 (TODO 197) | proposal | parked; its linking of the names in use carried here | 5; since the revision, §5.4 |
| plan 070 (TODO 194) | proposal | parked; its areas carried here | 6 |
| plan 067 (TODO 193) | proposal | parked as it is | alongside |
| plans 044, 045 (TODO 144) | partly built | kept as the gazetteer, the staging of versions 4 and 5's sources | 4, 5 |
| TODO 186 | parked | dropped: plan 074 step 1 read every chart scale, the harbour plans too | — |
| TODO 181 | parked | kept, needed by version 4 | 4 |
| TODO 201 | parked | kept, version 6's asks | 6 |

## 7. Asks

All ten answered by the maintainer on 2026-11-19, one by one, each by choosing among the options offered (his
choice quoted); decision 333.

On the ladder:

a. *Answered* ("As proposed (Recommended)"). Asked: The ladder (§3): its rungs and their order as proposed? Anything to add, or to move up?
b. *Answered* ("Stamp, column, frozen (Recommended)"). Asked: A version marked in the data: a `version` stamp in each file's metadata and a column on the rows, each version's
   files kept frozen under `$FISHYDATA` beside the current one?
c. *Answered* ("At each version (Recommended)"). Asked: A new ogisdata version at each version of the names (the proposal), or only at some?
d. *Answered* ("As proposed (Recommended)"). Asked: The threads of §6: as proposed?

On version 2, the one to build next:

e. *Answered* ("In the page's ledger (Recommended)"). Asked: Your renames: an action `rename` in the page's ledger (`overrides/marine_name_edits.csv`), or a ledger of their own?
f. *Answered* ("By rule, doubtful listed (Recommended)"). Asked: One thing from two sources: joined by the same name and meeting places, the doubtful listed (the proposal), or every
   pair to your eye?
g. *Answered* ("Yours, LMÍ, charts, ÍSOR (Recommended)"). Asked: The spelling's order: yours, LMÍ's, the charts' print, ÍSOR's?
h. *Answered* ("As proposed (Recommended)"). Asked: Where the thing is, by kind (§5.2): as proposed?
i. *Answered* ("None for now"). Asked: ÍSOR's areas you want changed: how many, roughly, and is QGIS into a GeoJSON override acceptable?
j. *Answered* ("Faxaflói and Reykjaneshryggur (Recommended)"). Asked: The review: which region first?

On the revision by region (asked the same evening, 2026-11-19):

k. *Answered* ("As proposed"; the order "Side by side": the Kolbeinsey Ridge opened while Reykjaneshryggur's review goes on, each frozen when its review is done). Asked: The regions: as proposed in §3, or your own (and their bounds)? Their order after Reykjaneshryggur: the Kolbeinsey Ridge
   next (the proposal), Reykjaneshryggur's review finished first or both side by side?
l. *Answered, not as proposed* ("Several at a time": finished regions go out together, fewer ogisdata versions). Asked: A version a region (each finished region frozen and shipped in ogisdata), or a version for several regions at a time?
m. *Answered* ("As proposed"). Asked: LMÍ's copies (of Trackwell's and Hafrannsóknastofnun's deliveries): the name taken, never the place, each placed on a
   feature or listed (the proposal)?
n. *Answered* ("Candidates, my yes"). Asked: Trackwell: a name a candidate only, by the study's rule, in the list by your yes on the page (the proposal); or in by
   itself where the rule passes and a feature holds it?
o. *Answered* ("Region by region"). Asked: The depth model's own features (tops and lows, plan 073's inventory) where ÍSOR has none: built region by region (the
   proposal), or for all Iceland first?
p. *Answered* ("All Iceland now"). Asked: ÍSOR's landforms (troughs, moraines, the shelf break, channels): into `seabed_feature` for all Iceland now (the proposal),
   or region by region?
q. *Answered* ("Region by region"). Asked: The gazetteer's other sources (the plotters, MFRI's names, fiskislóð, the tag recaptures, documents): witnesses region by
   region as needed (the proposal), or later?

## 8. Not in this plan

Publishing outside MFRI; the harbours (plan 075); the aids' and wrecks' own lists beyond what the names need (plan 074
step 9 built them).
