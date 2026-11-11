# 073 — Local seabed features by best estimate: features found on the seabed, every source's statements linked to them, a name proposed for each, judged by a person feature by feature

**status:** proposal — written 2026-11-11 at the maintainer's request, with a read-only count the same day
(`$FISHYDATA/archive/2026-11-11-local-features/`, scripts 00-04, their logs in `notes/`); the same day a confidence in each
name and place, coloured on the map, and a category for each feature (a mound, a wreck), added at the maintainer's
word (§2.2, §2.8); nothing built ·
**2026-11-11** · **see:** plans 044, 070, 071 (§2.2-§2.5, steps 1, 4 and 8), decisions 221-224, 272, 301, 302, 304 and
309, the örnefni map and in-use studies (`$FISHYDATA/archive/2026-11-08-ornefni-map/`,
`$FISHYDATA/archive/2026-11-09-ornefni-in-use/`), TODOs 144, 186 and 197

Drafted with AI assistance (Claude) on 2026-11-11; a person has not yet checked it.

**Measured** (by Claude, 2026-11-11): the counts in §1. They are by box: Reykjaneshryggur as longitude -30 to -22.6
and latitude 60 to 63.7, Kolbeinseyjarhryggur as -20.5 to -16 and 66.9 to 69.6, each cut at 200 m on the 50 m grid.
The boxes are a measuring device, not the ridges' outlines.

**Assumed:**
- that a feature word says which form it names (a hill word a high, a hole word a low). Plan 071 §1 bears this out for
  holes and the charts' rings, not for the Vestmannaeyjar map's klakkar;
- that ÍSOR's mapped features (EMODnet Geology 2025) were drawn from multibeam, so their positions are a witness
  independent of the fishers' statements. Their names may come from the fishers, so they are not assumed independent;
- that the grid shows the features where Olex sounded. Where that is, is not known (§1.2).

The maintainer, 2026-11-11:
- "We have kind of successfully build the major fishing areas - the grounds and the deep. We used the sea-chart as the
  base." Next: "things like mounds ... the örnefni that are not in the sea-charts, e.g. all the mounds on
  Reykjaneshryggur and Kolbeinseyjarhryggur";
- the sources are "of different quality, with errors in location, typos in the data entry, often type as short cuts
  ("G-HOLL" for Gullhóll, ...)", with wrecks and ground information beside them, some files "possibly encoded as latin
  rather than UTF-8", "And then we have synonyms";
- "Given olex we have now also much better information about the sea bed landscape than were available when some of
  the placenames were setout";
- "Explore different ways to come up with your best estimate of a location and a name of a mound ... I foresee that a
  human would go over your suggestion. This is a little bit of a different approach than we tried few days a ago with
  manual editing of every raw point";
- during the drafting: natt.is's land names "may be useful if a data reference we have is actually some reference to a
  land-based feature"; "use all the raw-data you have for this, including the vernd_i_hafi"; "Mounds is one thing, but
  we also have other features at the more local scale - think we may sort of expand the scope in the plan"; "check also
  if the source file may still be coded in latin, not utf-8 - that way we may cover the "?" in names".

## 1. What is at hand (measured 2026-11-11)

### 1.1 The two ridges

- **The gazetteer's statements deeper than 200 m** (`curated/place_name/evidence.parquet`, script 00):

  | | Trackwell | channel | tag recaptures | the plotter | Oracle | LMÍ | uv | charts |
  |---|---|---|---|---|---|---|---|---|
  | Reykjaneshryggur | 32,283 | 345 | 270 | 360 | 70 | 30 | 14 | 3 |
  | Kolbeinseyjarhryggur | 15,549 | 385 | 142 | 88 | 132 | 22 | 10 | 0 |

  Trackwell's are 103 and 67 vessels' statements, not as many witnesses (plan 070 §2.2).
- **Their names:** 457 keys on Reykjaneshryggur and 279 on Kolbeinseyjarhryggur. 291 and 169 of them come from one
  source family alone.
- **Their feature words** (`terrain()`): 27 and 5 a hill, 8 and 35 a ridge, 45 and 27 a deep, 41 and 32 a bank. 309 and
  151, two in three, carry no feature word at all.
- **The plotter's marks** (one person's, `staging/ornefni/plotter_mark.parquet`): 49,662 and 17,794 deeper than 200 m.
  430 and 93 of them are named, with 287 and 66 distinct names; 123 and 17 of the named marks are short capitals, the
  kind of the maintainer's "G-HOLL". The rest are numbers under one symbol mostly; what they mark is not known (ask b).
- **ÍSOR's mapped features** (EMODnet Geology 2025, in `raw/external/vernd_i_hafi`, decision 309): 1,600 volcanic
  features in the two boxes, 1,446 labels. By type: craters 562, ridges 435, seamounts in three size classes 242,
  eruptive fissures 203, flat-topped edifices 109. 99 % of the labels are numbered ("Reykjanes Ridge crater 23",
  "Seamount 100-500m 238"). A few carry a proper name, and ÍSOR numbers a named feature's parts: Gullhóll 42 features,
  Steinahóll 36 with its craters, Njörður 29, Grjótahryggur 24, Stóri-Brandur 20.
- **The other sets of decision 309** in the boxes: LMÍ's 2017 sea features (13 and 6), the regulations' named areas
  (188/2023, 960/2019, 961/2019, Fiskistofa's in force: 6 and 3), the Steinahóll vent field (4), a plotter's named
  wrecks (20 and 4), and the plotter's TimeZero export of 2025 (100 objects).

### 1.2 The grid on the ridges

A lattice of points deeper than 200 m in the boxes (script 01: 16,644 on Reykjaneshryggur, 6,371 on
Kolbeinseyjarhryggur):
- the 50 m grid lies within 5 m of GEBCO 2026 at 55 % and 45 % of the points, within 20 m at 87 % and 77 %;
- the residual from a plane over 450 m is under 0.5 m at 17 % and 14 %, with a median of 1.28 m on both.

Neither number tells sounded from filled. GEBCO may hold soundings of its own on the ridges (its type-identifier grid,
not fetched, would say), so agreeing with it proves nothing, and flat mud is smooth too. Where Olex sounded is still not known (plan 071's assumption, plan 070 ask c).

### 1.3 The letters and the encodings

The maintainer asked whether the "?" in names come from files read in the wrong encoding. They do not.
- **No reader misreads its file.** Every staged place-name table and the gazetteer's statements were searched for the
  marks of a wrong decoding (Ã, Â, the replacement character): none.
- **The lost letters are the plotter's.** 779 of its names and 1,628 of its comments hold a "?" between letters, and
  773 of the gazetteer's statement names. Elsewhere a handful: 31 tag-recapture texts, 3 channel names, 2 in the name
  dictionary.
- **They are lost in the file.** The three large GPX exports hold no byte above 127: they are pure ASCII. The "?" is the
  byte 0x3F, the same in every code page, so the exporting program dropped the letters, and no reading in Latin-1
  brings them back (the study README).
- **Recovery by match** (script 02). The GPX marks hold 911 "?" names, 572 distinct. Each was matched two ways:
  - 8 found at the same position (within 10 m) in a TimeZero export, 2021's or 2025's, with their letters;
  - 93 fit exactly one name of the vocabulary (the gazetteer's names, the charts' and the TimeZero exports'), each "?"
    one non-ASCII letter;
  - 9 fit several;
  - 462 fit none: the plotter's own names are mostly in no other source.
- **Latin-1 files that are not yet read:** decision 309 found three shapefiles in vernd_i_hafi in Latin-1 with no
  `.cpg`, and the coral polygons' ground names spelt in ASCII (17 spellings of 15 names).
- **The land's names, for telling a land reference:** the charts' reading (TODO 186) holds 3,571 land names and 153
  lights beside its 1,487 sea names; LMÍ's IS 50V of 2017 (decision 309) holds 114,526 features, land and sea.

## 2. The design (proposal)

### 2.1 Feature first, one judgement per feature

Plan 071 step 8 had the maintainer edit place by place: a ledger entry for each name, a verdict on each name in use.
This plan turns it round.
- **Two inventories meet.** The features, found on the seabed and taken from the sources that map it (§2.4). The name
  groups, built from every statement of every source (§2.5).
- **The machine proposes**, by rules fixed before the run: a name for each feature, a feature for each name group, each
  with its evidence, its category and its confidence (§2.2, §2.6-§2.8).
- **The person judges a proposal per feature** (§2.10). The answer binds the feature, its name group and every
  statement under it, so one answer settles many raw points.
- **The raw is never edited.** Each statement gets an outcome by rule; a cleaned form sits beside the text as written.
- **The charts lead.** Plan 071 §2.1 holds: the charts' names are the official layer, an input here. Where a chart
  names a feature, its name is the proposal. The 50 chart names placed on the grid (plan 071 step 1) are kept.

### 2.2 Each feature's category

Widened from mounds at the maintainer's word ("Mounds is one thing, but we also have other features at the more local
scale"), and every feature categorised ("you should also categorize your feature, a mound, a shipwreck etc.").

- **Two levels a feature.** `category`, at most eight values so that a map tells them apart by colour, and `type`, the
  finer term.
- **The code lists come first**, before any vote (decision 252: a code is defined by its list):
  - for the seabed's forms, the IHO-IOC GEBCO terms for undersea features (publication B-6), whose definitions, by
    relief and shape, are read before any threshold is set (ask c: not yet in `raw/external`);
  - for wrecks, snags and foul ground, INT 1 Section K (in `raw/external/chart_symbols`, decision 301);
  - for the materials, INT 1 Section J (the same);
  - ÍSOR's EMODnet types (seamount in three size classes, flat-topped edifice, cone, crater, ridge, eruptive fissure)
    mapped onto those terms, not used as a list of their own.

| category | types (examples) | name words (examples) | form on the seabed | placed at | witnesses |
|---|---|---|---|---|---|
| high | mound, knoll, hill, seamount, flat-topped seamount, cone | -hóll, -klakkur, -haus, -bunga, -hnúkur, -kollur, -boði | a closed high | its top; its outline down to its saddle | the charts' named rings, ÍSOR's seamounts and cones |
| ridge | ridge, fissure ridge, spur | -hryggur, -rani | a long high | its crest line, a point on it | ÍSOR's ridges and fissures |
| low | hole, crater, pit, trough, valley, small deep | -hola, -pyttur, -gígur, -gjá, -dalur, a -djúp, -áll or -dýpi with no area of its own | a closed or long low | its bottom or axis; its outline up to its sill | ÍSOR's craters, the Vestmannaeyjar map's holur and leirur, the charts' rings (two) |
| part | edge, corner, tongue | -kantur, -horn, -fláki, -tota, -tunga | a share of its parent (plan 070's rules) | inside its parent | the maintainer's definitions |
| ground | rough ground or lava, mud, sand, gravel, coral or sponge ground | -hraun, -leir, -for, -grjót (small names only) | a material, not a form | the patch | the charts' bottom marks (decision 301), the coral and habitat polygons |
| wreck | wreck, dangerous or not (INT 1 K) | Flak alone, a vessel's name with Flak | a mark; at most a small high on the grid | its mark | the plotter's wreck layer, the charts' K symbols, a wreck list (ask d) |
| snag | snag, foul ground, obstruction | -festa | a mark | its mark | the plotter's marks, the charts' K symbols |
| unknown | | no feature word, no form found | | its statements' centre | |

- **How a feature gets its category.** Each witness gives one, with its basis:
  - the source's own class: ÍSOR's type, a chart symbol, the plotter's symbol and layer, LMÍ's feature class, the
    gazetteer's terrain class;
  - the seabed's form where it is sounded: the detector's high or low, closed or long, and its relief;
  - the name's word.

  The rule, fixed before the run: a mapped class first (ÍSOR, a chart symbol, the plotter's wreck layer), then the
  seabed's form, then the word. `category_basis` lists every witness's answer, and `category_agree` counts those that
  agree among those that judge.
- **Where they disagree** ("the name says -hóll; the seabed shows a hollow") the card carries a wart, and the place's
  confidence loses its third criterion (§2.8). A name with no feature word takes the seabed's category, marked
  inferred: two in three of the names on the ridges (§1.1).
- **A land reference is no feature.** A statement naming land, a skerry or a light, or a direction from one, is linked
  to that land feature as an outcome of the statement, and takes no place on the seabed. Its witnesses are the charts'
  land names, LMÍ's IS 50V and natt.is (ask c).
- **Words.** They are `curate/place_name.R`'s `terrain()` and plan 070's `AREA_WORD`, extended where the check asks
  (ask a). A substrate word goes with the small name it ends, never with a broad one (the maintainer, 2026-11-08).

### 2.3 Where the seabed can be read

The first step: a mask over the grid, per 500 m cell, saying sounded, filled or not known. Each witness is measured,
none assumed:
- the grid against GEBCO 2026, and GEBCO's type-identifier grid (where GEBCO holds soundings of its own; public);
- the residual roughness at 50 m against that of patches known to be filled;
- EMODnet's DTM source references (where surveys exist);
- ÍSOR's mapped features, drawn from multibeam;
- the grid's maker: how it was made, the open question in its provenance note (ask c).

A feature found on a filled cell is no witness. There a name keeps its statements' position, with the basis
`statements`.

### 2.4 The features, found

One inventory over all the waters the grid covers. Each feature has an id, a category and a type (§2.2), a point (top or bottom), an outline
(the closed contour to its saddle or sill), a prominence, an area, a depth, its coverage basis, its parents (a top in a
mound on a ridge), and a zoom from its size (the örnefni map's 35 px rule).
- **Detectors, prototyped and scored, not reasoned out:**
  - the closed high or low with a prominence threshold, plan 071 step 1's mend (A2), which passed at 1:100 000;
  - the merge tree of the contours, which gives the nesting at once;
  - scale-space blobs (Lindeberg 1998);
  - a local BPI at a few radii.
- **Features from the sources that map them**, each with its own id and basis: ÍSOR's cones, craters, ridges and
  seamounts (1,600 on the two ridges), the charts' named rings (325, decision 301), the charts' K symbols where read,
  plan 070's areas as parents.
- **One feature, several witnesses:** a feature found on the grid and one ÍSOR maps in the same place are one.
- **Unnamed features stay.** They are what the names are matched to, and the obvious test needs them.

### 2.5 The statements, cleaned

One statement table over every raw source. A row: the source, the unit that makes an independent statement (a vessel
within Trackwell, the plotter's person, a document, a regulation), the text as written, the position and its kind, the
source's position error, the years.
- **The sources: all the raw at hand.**
  - Trackwell; the plotter (the GPX exports, TimeZero 2021 and 2025); channel; the tag recaptures; Oracle's place tables;
    uv.
  - LMÍ's 2022 polygons and its IS 50V of 2017; the charts' reading (sea, land, lights), their bottom marks and named
    rings.
  - vernd_i_hafi: ÍSOR's EMODnet layers; the regulations' named areas (188/2023, 960/2019, 961/2019, 814/2026,
    Fiskistofa's); the coral and habitat polygons.
  - ÍSOR's reports in `raw/external/ornefni/documents`.
  - The Vestmannaeyjar map, Skjálfandi, the maintainer's 151 records, the readings of Andvari, Ægir and timarit.is,
    the name dictionary.
- **The cleaning**, each step a column beside the text, never over it, with its basis:
  1. *Encoding.* Each file read by its declared code page: a `.cpg`, a DBF's language byte, an XML header. Otherwise
     tested: valid UTF-8, or Latin-1 when its high bytes are Icelandic letters. A "?" between letters is flagged as
     lost (§1.3).
  2. *Lost letters,* recovered by match: the same mark in a TimeZero export; the vocabulary, each "?" one letter; the
     candidates within the source's error first. A proposal with its witness, never silent.
  3. *Short forms.* A capitalised or cut form ("G-HOLL") expanded to candidates: its letters, its feature word and its
     place against the vocabulary. Scored by letters and by place; a proposal.
  4. *Spellings.* Letters folded (ð/d, þ/th, accents, case, hyphens) and an edit distance. Two spellings are joined only
     when near in letters and in place, the rule of the gazetteer's `spelling` relation.
  5. *Synonyms:* the gazetteer's synonym table (spellings, the dictionary's readings, the articles, LMÍ's alternates),
     the maintainer's records' synonyms, the review's answers ("a form of", "another name for").
  6. *Not a name, a direction, a land reference:* plan 071 step 4's sorting (`08_sort_names.R`). The land, skerry and
     light names of the charts and LMÍ are the vocabulary of land.
- **Out:** name groups, each its spellings with their statements. `curate/place_name.R`, `curate/name_group.R` and the
  variant rules are extended, never copied.

### 2.6 Linking names to features

For each name group and each candidate feature within its statements' error:
- **distance** to the feature's outline, not its top. Tows lie on a feature's flanks (plan 070 §1); a mark lies on it;
- **category:** the name's word against the feature's category;
- **obvious:** the feature's prominence against its neighbours within the error;
- **support:** the independent units on it, weighted as plan 070 §2.2 has it. In a Trackwell run the stamp counts most
  and the last hauls least;
- **agreement** of ÍSOR's or the charts' name.

Each link gets a confidence in its place and one in its name, by fixed rules (§2.8). Up to three alternatives are
kept, each with its own.

Each name group gets one outcome: one feature; several (ambiguous); none on a sounded seabed (kept at its statements'
centre); the seabed not readable (kept, basis `statements`); a land reference; not a name; too weak to place.

Two or three assignment rules are prototyped and scored on the witnesses, not reasoned out: the nearest obvious
feature; the best score; one matching over a region, so that two names land on one mound only as synonyms.

### 2.7 A name for each feature

- The chart's name, where a chart names the feature.
- Else the name group with the most independent support; ties go to the better source, then the older one.
- Of one ground's forms, the oldest ending found rules, the current form kept (decision 302's history rule).
- ÍSOR's names count as one document's statement. Their positions are from multibeam, but their names may come from the
  fishers, so agreeing with them is not an independent vote until shown otherwise.
- The other names are "also called", with sources and years. Names of two eras both show, dated.
- No name is invented for an unnamed feature.

### 2.8 Confidence, and its colour on the map

The maintainer, 2026-11-11: "we may also put some weight on how confident you are in a place name. One could then e.g.
colour mark your confidence on a rr map."

- **Two confidences a proposal.** A name can be right and its mound wrong, and plan 071's review asks the two apart:
  - the place: that the feature is where the name belongs;
  - the name: that this is the name the feature is known by.
- **Counted from criteria.** Each criterion is met, not met or not judged, and the card lists them, so the reader sees
  why. No weight is fitted and no probability claimed: checks are bookkeeping, not modelling.

  | | the place | the name |
  |---|---|---|
  | 1 | sounded: the seabed under the feature is sounded (§2.3) | families: two source families or more use it for this feature |
  | 2 | obvious: one feature stands out within the error, the next candidate's prominence well below | support: three independent units or more (vessels, persons, documents) |
  | 3 | category: the name's word agrees with the feature's category | as written: no letter recovered and no short form expanded, or recovered from the same mark in a TimeZero export |
  | 4 | tight: the independent statements lie within their sources' measured error of the feature | alone: no other name group claims the feature with like support, synonyms aside |
  | 5 | witness: a mark, a named ring or ÍSOR's feature places it | printed: a chart, ÍSOR or a regulation names it |

- **Four levels each, an ordered factor:** `place_confidence` and `name_confidence`.
  - high: four or five met, and the first criterion among them (sounded for a place, two families for a name);
  - medium: three met, or four or five without the first;
  - low: one or two met. A place on a filled seabed is low at most;
  - none: no criterion met.

  `confidence`, the lower of the two, is what the map colours first.
- **Calibrated before the review.** On the names a witness places (§2.9, held out), each level's share whose feature is
  the witness's is counted by category and region. The levels must come out in order (high above medium above low)
  in every category with ten witnesses or more. Where they do not, the criteria are revised and the run repeated, before the
  review and never after it to fit the answers. The shares are reported beside the levels as background, never as a
  pass.
- **The review is kept apart.** A column of its own, `review` (accepted, changed, rejected, not yet), says what the
  person settled. The machine's confidence stays beside it, never overwritten.
- **On the map** (rebelrebel, as plan 072 §3 designs it). The three confidences are written as ordered factors (DuckDB
  ENUMs), so:
  - `colour = c(confidence, place_confidence, name_confidence, category)` gives viridis in the levels' order for the
    confidences, Okabe-Ito for the categories (unordered, at most eight), a "Colour by" switch and a legend;
  - `choose = c(confidence, category, type, review)` lets the reader show only the high ones, only the wrecks, or only
    those left to review;
  - a symbol for each category where rebelrebel has one (a wreck as the chart's sign), the colour otherwise;
  - unnamed features, when shown, are grey.

  Which end of the scale should stand out on the light seabed is ask h.

### 2.9 The check, before the review

The witnesses of place are independent of the statements they check:
- the charts' named rings (325);
- the Vestmannaeyjar map's marks (within about 90 m);
- ÍSOR's named features (positions from multibeam);
- the maintainer's records' descriptions, as text.

Each witness is held out when the rule it checks is scored. Every name group gets one outcome against its witness:
nearer, farther, not moved, or not judged. The rule is fixed before the run: a category is applied in a region only where
moves nearer outnumber moves farther 3:1 (plan 071's bar). Counts are split by category, scale and region (the ridges, the
shelf, the fjords), never pooled.

### 2.10 The review, feature by feature

On the örnefni viewer (ramb's map viewer, rebelrebel's once plan 072 moves it), a layer of proposals, ranked by
confidence and support.
- **A proposal's card:** the feature (its outline and top), the proposed name and why, its two confidences with each
  criterion met or not, the alternatives, the statements coloured by source family with their years, the warts ("one vessel", "letters recovered", "short form expanded",
  "seabed filled here").
- **The answers:** accept; another name (from the alternatives, or typed); another category; merge with another feature; split; not this
  feature (pick another); not a feature; not sure; a note.
- **The ledger:** under `$FISHYDATA`, internal, appended and never changed. The rules re-run with the answers as an
  input: the cycle is broken by a person, outside the DAG.

### 2.11 What it makes

All under `$FISHYDATA`, internal: Trackwell's and the plotter's names are in it.
- **The features:** the inventory of §2.4, each with its category, type and their witnesses.
- **The names:** each feature's proposal, its two confidences and the lower of them (ordered factors), its alternatives;
  after the review, the answer in `review` beside them.
- **The statements' outcomes:** every statement's cleaning, its link and its outcome.

The örnefni map reads them. They become targets after the review, on the preprocessing side (no AIS).

## 3. Steps

Each step is a script in the study (`$FISHYDATA/archive/2026-11-11-local-features/`), with its log in `notes/`. The
chain runs over all the waters at once; the review goes in an order.

1. **The coverage mask** (§2.3).
2. **The feature inventory** (§2.4): the detectors prototyped and scored; ÍSOR's and the charts' features joined.
3. **The statements and their cleaning** (§2.5): lost letters and short forms as proposals, every statement in one
   outcome of the cleaning.
4. **Each source's error,** on the names a witness places (plan 071 §2.3): by source, by vessel, by category and region.
5. **The links** (§2.6): two or three rules, scored on the witnesses (§2.9).
6. **The names and their confidence** (§2.7, §2.8): the levels calibrated on the witnesses before anything is shown.
7. **The proposals on the örnefni viewer** with the review's answers (§2.10), checked against a list of click paths.
8. **The maintainer's review,** where he chooses to start. Proposed: the two ridges, where ÍSOR gives a witness.

## 4. How it is checked (bookkeeping, not modelling)

- Every statement is in one outcome, and the outcomes sum to the statements.
- Every feature is in one outcome: named (by confidence: high, medium, low, none), unnamed, or joined with another
  witness's.
- Each confidence level's share placed as its witness says, by category and region, in order before the review (§2.8).
- Every lost letter and short form is recovered with its witness, proposed, or left as written; none is rewritten
  silently.
- The official layer equals its frozen md5s after the run (plan 071 §4).
- Every feature has one category, its witnesses' answers listed; `unknown` is counted, never dropped.
- Counts are split by category, scale and region.

## 5. Asks

- a. **The categories, their types and words** (§2.2): complete? Words to add or move.
- b. **The plotter's numbered marks:** most of its marks on the ridges are numbers. What do they mark: a top, a snag, a
  depth, a tow's turn? If they mark features, they are statements with no name.
- c. **What to fetch or ask for:**
  - GEBCO's type-identifier grid, EMODnet's DTM source references and IHO-IOC's B-6, the undersea feature terms
    (public downloads);
  - how the grid was made, from its maker;
  - MFRI's own multibeam surveys, if they can be reached;
  - natt.is's names as data, if it serves them;
  - a fresh TimeZero export of the plotter, with its letters: 462 of the 572 "?" names no match recovers.
- d. **Wrecks:** a wreck list to be had (Landhelgisgæslan's?), or the plotter's wrecks and the charts' symbols only.
- e. **The review's form** (§2.10), and whether the high-confidence proposals in view may be accepted in one go.
- f. **Unnamed features on the map.** Proposed: a layer of their own, off at the start.
- g. **ÍSOR's names** as one document's statement (§2.7). Proposed: yes.
- h. **The confidence's colours** (§2.8): whether doubt or confidence should stand out on the light seabed, and whether
  the map colours by the lower of the two confidences at first. Proposed: viridis as rebelrebel gives it, the lower of
  the two first.

## 6. Not in this plan

- **The broad areas** (plan 070, decisions 302 and 304): inputs here.
- **A ground's extent** where the name is a fishing ground, not a feature: plan 071 §2.5.
- **Placing names on the effort:** flow-side work.
- **Bulk text from timarit.is:** it needs the maintainer (plan 067).
- **Publishing.** The work stays internal: plan 001 draws the boundary.
