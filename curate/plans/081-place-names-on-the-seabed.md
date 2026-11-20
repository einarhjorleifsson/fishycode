# 081 — The best proposal for each place name: Claude's estimate from the seabed, the fishing and the texts, then an interactive review against every record

**status:** partly built — step 1 (the troughs and the deeps) built 2026-11-20 at the maintainer's word ("Yes, start step 1";
decision 338), his review of it next; written 2026-11-20 at the maintainer's word ("So review the plan from scratch - think we have plenty
of things to work from now"), revised the same night after a dig on ÍSOR's troughs and moraines, the effort and the texts
already read ("You may even have now enough to make your own proposal. Care to dig in a bit. Take you time"), and set on
its goal ("the goal of this plan is that you come up with the best proposal to a placename. We would then go through that
against other records in an interactive review"); its questions answered by Claude's own recommendations, the alternatives
explored ("if you have questions - try to explore the alternatives to a recommendation yourself"), each for his word
(§8); answered the next morning one by one, every recommendation taken, the banks' outlines tried first on the east
coast (decision 337); it takes over plan 080's forward design (its §3 and §5.3-§5.6; §8 i); nothing of it built beyond
what decision 336 records · **see:** plan 080 (versions 1 and 2, its §4 rules), decision 336, plan 073 (its "best estimate"
and its first trial, decisions 315-317), plans 070 and 074 (the endings and outlines tried), plan 067 (records), decisions
295, 302, 304; TODOs 181, 193, 201 and 206; the studies `$FISHYDATA/archive/2026-11-19-skipper-names-beyond/`,
`2026-11-20-place-name-plan-review/` and those §2.3 names

Drafted with AI assistance (Claude) on 2026-11-20; a person has not yet checked it. What §2 calls measured, Claude measured;
what it says the texts say, Claude read (through two reading agents' reports, checked against the studies' files where
quoted). No person has checked either.

## 1. The goal

The maintainer, 2026-11-20: "the goal of this plan is that you come up with the best proposal to a placename. We would
then go through that against other records in an interactive review."

So the plan has two halves. **The proposal**: for every name, Claude's best estimate of what it names (its kind, where the
thing is, its extent, the whole it belongs to and its parts, its forms), made by rule from every witness at once, each
witness's say kept beside it. **The review**: the maintainer goes through the proposals on the page, each beside the other
records, and accepts or corrects; his verdicts are ledger rows the next proposal respects.

What the night of 2026-11-19/20 showed a proposal can stand on, in his words:

- "this is a mound, the "banki" refers to a fishing "ground"" (Litlibanki): a name may stand for a ground, not a shape.
- "Only when it comes to "narrower" name may they be of any use"; "we have already pretty much established where
  "Skerjadjúp" proper is. Same goes for a lot of other deeps and grounds. So any skipper records that are way off those
  should be ignored"; "An arbritrary bound comes back to haunt you."
- "the problem is that Trackwell fed LMÍ."
- "this latest ISOR polygon of Skerjadjúp really helps"; "moraine 229 is "Táin" as in "Selvogsbankatáin""; "moraine 155 is
  what captains call "Brjálaði Hryggurinn""; "moraine 143 then more or less depicts Suðurkantur/Suðurkantar".
- "One witness for all this are the articles we have already mined - some of the mentioned fishing grounds may give
  relative hints about location of grounds (west/north/south/east of, ....)".
- "We already looked into what "sub-regions" to a ground they may refer to"; "-táin (or just tá) goes along the same way."
- "entertain going through the effort raster map to see if there is any correlation between names and effort hotspots /
  effort "trajectories". the boundaries of where the effort hotspots is could also be a guiding lead."

## 2. What there is to work from

### 2.1 The material

- **The names, versions 1 and 2** (plan 080; decisions 332, 334, 336): 25,911 rows in `marine_name`, version 1 frozen; the
  page on port 8822 with its ledger (move, turn, zoom, rename, synonym, pin, link, part of, join, accept, reject, ignore, remove,
  area aside, new, accept proposal, reject proposal, and since decision 338 limit and rest, his division of a shared trough)
  and the old land maps as backgrounds. A link takes an ÍSOR area or line as the name's extent, a trough's
  deepest point as a deep's place.
- **The seabed** (`seabed_feature`): ÍSOR's 740 craters and guyots and 1,307 volcanic areas; its landforms (28 troughs, 728
  moraines, the shelf break, 55 canals, 159 channels, 21 meltwater channels, 2,223 streamlines). The depth model, Olex 50 m
  with GEBCO, its interpolated parts known (decision 315). Outlines drawn from it before: plan 073's merge tree and flood
  (decisions 316, 317: highs 0.93, lows 0.90 against the charts' labels, but 64 of 339 highs outlined), the örnefni map's
  sea-chart model, plan 070's areas.
- **The fishing**: the effort grid (`products/effort_map/cells.parquet`, 0.005°, by gear and year, 2007-2026); Trackwell's
  named tows, public (decision 335), 438,053 clean tows of 200 m or more.
- **The texts**: the charts' letterings (plan 074, every scale); LMÍ's names with their sources traced (decision 336);
  timarit.is's stored pages (4,132) and what was read from them (§2.3).

### 2.2 The dig of 2026-11-20 (measured; study `2026-11-20-place-name-plan-review/`, scripts 02-13)

- **Concentration is the skippers' measure.** Of all the tows a name carries, the share on a feature, at two vessels or
  more. By vessels the broad names lead (the wholes a feature lies in); by concentration the narrow ones (the parts).
- **Troughs**: in 17 of the 25 of ÍSOR's troughs that hold a deep of ours, the skippers' most concentrated name inside is
  that deep, mostly as "-dýpi" for the charts' "-djúp" (Hornafjarðardýpi 81 %, Breiðamerkurdýpi 75 %, Jökuldýpi 71 %, Lónsdýpi
  69 %, Skeiðarárdýpi 63 %). Trough 6 (Skerjadjúp) is Heimsmeistarahryggur 57 % and Guðbjargarhólar 55 % to the skippers,
  never Skerjadýpi. Five troughs with no deep of ours carry a skippers' name (Skaftárdýpi, Vikið, Paradísarhola, Þúfurnar,
  Djúpendi).
- **Moraines**: trawlers tow along them (59 % of the tows within 250 m run within 20° of the moraine, 22 % by chance,
  falling to chance by 50 km). By concentration along a moraine: Táin and Selvogstá on 229, "Hryggurinn v. Vikurál" on 155,
  Eldeyjarbankakantur on 143, and ridge, edge, horn and heel names elsewhere (Hællinn, Skötuhryggur, Kattarhryggur,
  Norðurkantur, Þverálshorn). "Brjálaði hryggur" (one vessel) crosses 155 rather than running along it.
- **The parts of a ground** (21 skippers' part names on the charts' -grunn and -banki roots, two vessels or more): every
  part but -bugt lies farther from land and deeper than its whole; -flak not steeper (flat), -kantur steeper and at the
  shelf break, -tota and -tá near a moraine (Gerpistota, Selvogstá; Táin is moraine 229), -dýpi the deep beside
  (Selvogsdýpi). Namesake roots give false families 217-598 km apart, the true 10-90 km: a gap, no distance chosen. Our own
  names hold almost no parts (3 -flak, 1 -tota); they live in the skippers' names.
- **The effort's hotspots** (the fishing hours, log, smoothed at 1, 2 and 4 km; a hotspot the cells that climb to one
  peak): their boundaries do not fall between names. A named tow's nearest tow of another name lies in another hotspot
  about as often as its nearest of the same name (all gears, 2 km, pairs 1-2 km apart: 6.2 % against 5.3 %; the same at every
  scale and distance). Names nest in hotspots instead: up to 29 named grounds in one, wholes over parts (Halinn, Kanturinn
  vestan v. Halann, Djúpkrókur, Barðið; Fjöllin, Skerjadýpi, Eldeyjarbanki, Sparisjóður). Along an elongated hotspot (a
  band, its long axis twice its short) the names lie one after another more than side by side in 70 of 118 (2 km) and 36
  of 51 (4 km), as Litlibanki and Pínulitlibanki do, but they explain little of the spread (7-14 %). So the effort gives a
  ground its footprint and a band its order of parts, not boundaries between names.
- **Banks and the 200 m line**: the sea shallower than 200 m (1 km cells, land taken away) is one piece of 106,703 km²
  holding 77 of the charts' 86 -grunn and -banki; at 150, 250 and 300 m the same. And the shelf less ÍSOR's 28 troughs is
  one piece holding 83. Neither the depth line nor the troughs alone divide the banks: the troughs do not reach the coast.
- **The deeps' roots**: by Claude's reading of the charts' deep names, mostly fjords and bays (Skagafjarðar-, Eyjafjarðar-,
  Axarfjarðar-, Héraðsflóa-, Seyðisfjarðar-, Reyðarfjarðar-, Berufjarðar-, Hornafjarðar-, Ísafjarðar-, Arnarfjarðar-,
  Húnaflóa-, Faxa-); on the south coast, with no fjords, rivers and glaciers (Skeiðarár-, Skaftár-, Breiðamerkur-, Jökul-).
  The script's own matching to LMÍ's land names (`out/einar_rule.csv`) is too crude to count by.

### 2.3 What the texts already read say (the reading of 2026-11-20)

From the studies `2026-11-05-timarit-ornefni`, `2026-11-07-seabed-landscape`, `2026-11-07-andvari-bjarni`,
`2026-11-08-fiskikort`, `2026-11-07-aegir-early` and `2026-11-08-old-chart-names` (references there by timarit.is page):

- **The rule of the deeps and banks**: Einar Jónsson (Víkingur 1979, his series on names beyond the shore): the shelf edge
  is indented like the coast, the deeps named for the fjords and bays, the banks between for the headlands, with named
  exceptions. Bjarni Sæmundsson (Andvari 1933): troughs run from the open sea into the bays with the banks between; a broad
  outer deep forks into narrower álar either side of an inner bank (an áll can be a branch of a djúp); he measured a bank's
  size to the 200 m line.
- **banki**: a part of a grunn (Jökulbanki the outer part of the bank off Snæfellsnes; Hvalbaksbanki the southern part of
  Breiðdalsgrunn; Hornbanki a shoal on Strandagrunn's outer part) or the fishermen's name for a whole grunn (Selvogsgrunn
  as Selvogsbanki, "Bankinn"); Eldeyjarbanki the broad bank north and west of Eldey out to Suður-Kantar (Andvari 1937), as
  the maintainer has moraine 143.
- **flak, fláki**: a broad flat stretch, often a bank's outermost part (Reyðarfjarðarfláki the outer part of Skrúðsgrunn);
  a flak's edges named in turn (the south kantur of Digranesflak).
- **kantur, brún**: an edge; Kanturinn the shelf edge, Kantarnir (Norður- and Suður-) a long ground at the shelf edge off
  Faxaflói; Álsbrún the north-east edge of Djúpáll.
- **hali against halli**: Halinn a horn running out of the shelf, steep on three sides; Hallinn (Hvalbakshalli) a bank's
  slope to the ocean deep.
- **horn, rani, haft, tá, fótur**: a projecting spur, a snout, a neck between two horns, a toe (Táin on Selvogsbanki, the
  English "Baby Foot"), a foot. **tota**: the texts are silent.
- **hryggur**: sills across fjord mouths, the ridge carrying Grímsey and Kolbeinsey, named ridges on grounds (Brjálaði
  hryggurinn on Látragrunn, as the maintainer has moraine 155). **hóll**: mounds (Hóllinn in Álsbrún).
- **dýpi**: a later form of -djúp (not in Bjarni; in Ægir 1961 and 1978), as the skippers use it (§2.2).
- **hraun, leir**: bottom types made names (Hraunið the rough part of Selvogsbanki; leir small mud patches).
- **bugur, bugt**: coastal bights only. **mið, slóð**: generic; the old broad slóðir split into many named grounds when
  the stern trawlers came.
- **The placings checked** (the 2026-11-05 study, 305 placings of 19 documents against the gazetteer): 72 agree, 39
  disagree, 194 unjudged (no position 80, no bearing word 49, the landmark unplaced 15, no depth 13, namesakes far off
  about 21); most disagreements are of extent, a big ground's parts far from its middle (Fjöllin, Rósagarðurinn, Melsekkur).
- **Not yet read**: Bjarni's 29 articles were scanned by script (938 paragraphs flagged, unread); about 200 ranked
  candidate pages and 1,951 phrase hits; the night harvest (686 of 824 tier-1 names, all of tier 2); early Ægir 1966-1990;
  the fiskikort sweep (83 documents); Reykjaneshryggur's 549 sentences (§2.2's script 01).
- **The maintainer's own glossary** (decision 317, plan 070's study): the east's endings "-grunn, -flak, -tota, -xxx, ....
  are endings that refer to different part of a shallow area (relative to a deep area)"; "you may then have a different
  system of -endings in the north-western system, local lingos"; tota "as in tongue, tail"; flak "most like the end of
  something" (unsure); djúp "just a deep thing relative to the adjacent grunnur"; áll "normally something narrow, but
  Kolluáll is certainly not"; hryggur "like our spine, long and elongated"; "-kantur" "refers to the outer edge of
  something, quite often "follwed" by a steeper slope"; "-horn" "refers to a corner of something"; "-fláki" "refers to a
  relatively narrow "tounge" that protrudes from the main area"; "Boðagrunn is the whole thing, the tail is here the
  southwestern part". Plan 070's study measured -flak (the east, about 170 m, 52 km off, a flat-topped ridge from a
  headland) apart from -fláki (Breiðafjörður, about 75 m, a flat at a bay's mouth), and the endings by region (the
  north-west's oddi, tota, hali, botn; the east's fles, kambur, flak).

Assumed, not measured:

- that a name's kind and place in a ground's anatomy can be read first from its ending, region by region, and set right
  by him;
- that the depth model's own outlines can be drawn well enough where ÍSOR has none;
- that ÍSOR's outlines are where ÍSOR draws them, and that ÍSOR has not mapped every moraine (the maintainer: "of course
  ISOR has not done everything, yet").

## 3. What a proposal is

One proposal per name (and one per named feature with no name of ours yet), each a row with its evidence:

| Part | What | By |
|---|---|---|
| **kind** | a seabed feature (a deep, a rise, an edge, a ridge or moraine, a toe or tip, a flat), a ground (where the fishing is), or a point thing (rock, skerry, island) | its ending (§4.2), its element, his word over both |
| **the thing** | a deep's deepest point, a rise's top, a line's middle, a ground's middle of fishing, a point thing as version 2 | the element it is matched to (§4.1) |
| **extent** | its outline: ÍSOR's, the depth model's, a bank's (§4.1), a ground's footprint in the effort, or a line | the element |
| **whole and parts** | the bank or ground it belongs to and its own parts (X-grunn holds X-flak, X-tota, X-kantur) | the root, the anatomy, containment |
| **forms** | the name used and every form seen (the charts' -djúp, the skippers' -dýpi, LMÍ's spelling) | the joined spellings and form pairs |
| **evidence** | each witness in one outcome: agrees, disagrees, silent, a copy (not counted); the count of independent witnesses agreeing | §4.5 |
| **flags** | what the review should look at: a conflict, a single witness, a copy, a gap | §4.5 |

The proposals are a curated table of their own (`curated/reference/place_name_proposal.parquet`, a version stamp), never a
change to the names until he accepts one; the names keep their sources (plan 080 §4: nothing destroyed).

## 4. How the proposal is made

### 4.1 The seabed's elements, and a bank's anatomy

- **The elements**: ÍSOR's troughs (deeps), moraines (ridges, toes, edges, sills), volcanic features (mounds, ridges), its
  shelf-break line; the depth model's own rises, basins and flats where ÍSOR has none (plan 073's merge tree and flood,
  the interpolated parts flagged).
- **A bank's outline**, from the two texts' rule (§2.3) since neither the 200 m line nor the troughs alone divide the shelf
  (§2.2): seaward, the 200 m line (Bjarni's measure); on its sides, the deeps either side of it, each deep's thalweg (its
  lowest line on the depth model) carried in from the trough toward the fjord or bay it is named for (Einar's rule; on the
  south coast the river or glacier); landward, the coast. A bank is named for its headland between the two deeps.
- **Within a bank**, its parts by the grammar (§4.2): its flat outer part, its tip or toe at the outer moraine, its edge on
  the shelf break or a deep's side, its corners and tails, the rough patches and mud.
- **A deep's outline**: ÍSOR's trough where there is one; else the depth model's basin; split from the next deep by the
  moraines and ridges between them (the maintainer: offshore boundaries "glacial, not watershed").

### 4.2 The names' grammar

A name is a root and an ending. The root ties a part to its whole (Gerpis-grunn, Gerpis-flak, Gerpis-tota; Selvogs-banki,
Selvogsbanka-tá) and, for a whole, says what it is named for (a headland for a bank, a fjord or bay for a deep); the
ending says which element it is. The first table, from the texts (§2.3), his glossary and the dig (§2.2), his word over it,
read region by region ("local lingos"):

| Ending | Element | Witnesses |
|---|---|---|
| -grunn | the whole bank off a headland, between two deeps, to the 200 m line | Einar, Bjarni, his glossary |
| -banki | a part of a grunn (often its outer, broad-ridge part) or the fishermen's name for a whole grunn; for him a fishing ground | Bjarni; his word |
| -flak, -fláki | a broad flat stretch, often the outer part (-flak the east's flat-topped ridge, -fláki the west's flat at a bay's mouth, his "narrow tongue") | Bjarni, plan 070, his glossary; the dig: farther out, not steeper |
| -tota | the tongue or tail of a bank, the north-west's ending | his glossary, plan 070; texts silent; the dig: near a moraine |
| -tá, -táin | the toe of a bank, at its outer moraine | Táin (moraine 229); his word |
| -kantur, -kantar, -brún | the outer edge, the slope beyond it steeper; the shelf edge; a deep's edge | Bjarni, his glossary; the dig: at the shelf break, steeper |
| -djúp, -dýpi, -áll, -renna | the deep, named for its fjord or bay; an áll a narrower branch; -dýpi the later form | Einar, Bjarni, his glossary; the dig: 17 of 25 troughs |
| -hali / -halli | a horn running out of the shelf, steep on three sides / a bank's slope to the ocean | Bjarni |
| -horn, -rani, -haft, -fótur, -oddi | a corner or spur, a snout, a neck, a foot, a point | the texts, his glossary |
| -hryggur | a long ridge: a moraine, a sill, a volcanic ridge | his glossary, the texts; the dig: moraines |
| -hóll, -hólar | mounds: craters, guyots, hills | the texts; decision 334 |
| -hraun, -leir | rough ground; a mud patch | the texts |
| -bugur, -bugt | a coastal bight | the texts; the dig: inshore |
| -mið, -slóð | generic grounds | the texts |

Forms are joined: the skippers' "-dýpi" and the charts' "-djúp" are one name. "-dýpi" is the later form, a vessel's habit, not
another place: no vessel writes both of one root, Bjarni's "-dýpi" words are all depths, and in the stored pages a place name
in "-dýpi" first appears in the 1970s (study `2026-11-20-proposal-deeps/`, scripts 02-03). The maintainer, 2026-11-20: "I like
this chronological hypothesis of going from -djúp to -dýpi. Also that "dýpi" is more of a reference to depth rather than being
a reference to placename. Think we should keep this in mind in our work." A root shared by namesakes far apart (the
gap of §2.2) makes no family. A whole and its part are never joined into one (decision 315).

### 4.3 The fishing

- **The skippers' names** measured by concentration on an element: inside an outline no distance at all; along a line, the
  corridor the alignment's fall gives (§2.2). A broad name (low concentration everywhere) is a whole or nothing, never a
  place; a name used off its element (Skerjadýpi) is ignored, not moved.
- **The effort** gives a ground its footprint (the cells its named tows cover, within the hotspot they concentrate in) and a
  band its order of parts, not boundaries between names (§2.2). A hotspot with no name of ours but a concentrated skippers'
  name is a candidate ground.

### 4.4 The texts

- **The charts** (where each scale prints the name, plan 074) and **LMÍ's names** (their sources traced; a copy is no
  witness).
- **The articles**: each statement placing a name (a bearing from another place, a distance, a depth, "between", "within",
  "out to") read into the 2026-11-05 study's schema and checked against the proposal (agrees, disagrees, unjudged with
  why); an extent disagreement (a big ground's parts far from its middle) is a disagreement with the extent, not the
  place. The reading is done for each step's names as the step is taken up (§7), from what is stored first (§2.3's unread
  lists), more pages fetched only at his word.
- **The seabed writers** (Bjarni, Einar, Thoroddsen, Trausti) for the terms (§4.2) and the landscape.

### 4.5 One proposal from many witnesses

For each name, every element it could name (by its ending and root, its whole's anatomy, its places in the texts, its
skippers' use) is a candidate; each witness gives each candidate one outcome. The proposal is the candidate with the most
independent witnesses agreeing; a copy counts with its source, never twice. Ties, conflicts and single witnesses are
flagged for the review, not decided. Bookkeeping, not a model (AGENTS.md: every record in one outcome, no agreement rate a
pass).

## 5. The interactive review

On the names page (port 8822), a review mode: a name chosen shows Claude's proposal (its thing, extent and parts drawn) and
beside it every record (the charts' letterings, LMÍ's polygon and its source, the skippers' tows of the name with their
concentration, the effort's footprint, the articles' statements as arrows from their reference places, the old maps
behind). His actions: accept; accept with a move or a pin; choose another candidate; link to another element; `part of`;
rename; ignore a witness. Each a ledger row; the next proposal respects them. A queue of the flagged first, by feature
class and region. A trough several names share is split by its own shape (its arms, and its main line between them), each
part to the name its witnesses point to; he divides it otherwise by a line (`limit`: a name kept to one side of it) and by
giving a name the rest of the trough (`rest`) (decision 338, trough 10). Since trough 27 a `limit` may be one of ÍSOR's lines across
the trough (a moraine: the name kept on the side of the point given), a name's limits hold against its own `rest`, a name
whose proposal he rejects leaves its trough, and an accepted fjord keeps its own place and area, its area joined with its
part (decision 338). A name he gives the rest of a trough is a deep of that trough whatever its ending (trough 11's
Paradísarhola). An accepted name's letters stand at its area's middle along its long axis, a move of his after 2026-11-20
13:37 UTC winning, and its zoom rule e on that area's length along the axis, a zoom edit of his winning (decision 338).

## 6. The worked example (decision 336)

Skerjadjúp on ÍSOR's trough 6 (its deepest point, 378 m), Sæmundarrenna a part of it; Heimsmeistarahryggur the sill on its
south rim; Táin on moraine 229 (Selvogsbanki's toe); Suðurkantar on moraine 143 (Eldeyjarbanki's edge, "out to Suður-Kantar"
in Bjarni's words of 1937); Brjálaði hryggurinn on moraine 155 (on Látragrunn in the texts); Litlibanki and Pínulitlibanki
two grounds one after another on one effort band of the Reykjanes Ridge's east flank; the skippers' Skerjadýpi ignored, the
trough's own skippers' names elsewhere. Each is what §4 would have proposed; each was settled by his eye.

## 7. Order of work

1. *Built 2026-11-20 (decision 338): `reference/names/place_name_proposal.R`, its check, the review mode; reviewed the same day, all 28 of ÍSOR's troughs decided; closed by version 2, frozen and carried by ogisdata 2026.11.20. The 72 deeps on no trough wait for step 5.* **The troughs and the deeps**, over all Iceland: a proposal for every deep name (17 of 25 already agree, §2.2); the
   unnamed troughs with the skippers' names; the deeps' thalwegs toward their fjords; reviewed.
2. **The moraines and the ridge, edge, toe and tip names**: the proposals from the moraines' concentration and the grammar;
   reviewed.
3. **The banks' anatomy**: each bank's outline (§4.1), its parts placed in it (§4.2); reviewed.
4. **The volcanic ridges** (Reykjaneshryggur, the Kolbeinsey Ridge) on the links of decision 334.
5. **The depth model's own outlines** where ÍSOR has none, and **the grounds** from the effort; the rest of the names.

Each step a version (plan 080 §4: frozen, measured against the one before, shipped in ogisdata); the articles read for its
names as it is taken up.

## 8. Recommendations (the alternatives explored by Claude), answered

Put to the maintainer one by one on 2026-11-20 ("Yes, one by one"), each answered by choosing among the options offered;
every recommendation taken (decision 337). His choice in brackets.

a. *Answered* ("As proposed"). **The proposal (§3)**, in a table of its own until accepted. *Alternative*: write proposals straight into the names.
   Rejected: the names would lose their sources' say, against plan 080 §4.
b. *Answered* ("By feature type"). **The order (§7): feature class by feature class over all Iceland, troughs first, each reviewed by region.**
   *Alternative*: region by region with every source (plan 080). The dig favours classes: the troughs agree in 17 of 25 at
   once over all Iceland, a measure only a whole class gives; a region holds a few of each class.
c. *Answered* ("Concentration"). **The skippers' measure (§4.3): concentration**, no distance inside an outline, along a line the corridor the alignment
   gives. *Alternatives explored*: a fixed distance (past 15 km lie 43-76 % of tows whatever the size), the place's size from
   the names table (LMÍ's areas behind it), counts of vessels (the broad names first). Concentration alone found Táin,
   Eldeyjarbankakantur and the deeps.
d. *Answered* ("As proposed"). **The grammar (§4.2) as the first rule, region by region, his word over it; "-dýpi" one name with "-djúp".** *Alternative*:
   no grammar, every part placed by hand. The texts, his glossary and the dig agree on most endings; the regions differ
   (his "local lingos").
e. *Answered* ("As proposed"). **The grounds: the effort's footprint by gear, all years together; the effort not as boundaries.** *Explored*: hotspot
   boundaries as name boundaries; they are not (§2.2). Kept: footprints, and a band's order of parts.
f. *Answered* ("Yes, the east first"). **A bank's outline from the texts' rule (§4.1)**: the 200 m line seaward, the deeps' thalwegs toward their fjords on the
   sides, the coast landward. *Explored*: the 200 m line alone, the troughs alone (one piece each, §2.2); the depth model's
   merge tree (64 of 339 highs outlined, decision 317); a 15 km block (the maintainer: "I am seeing a certain radius as a
   demarcation"). The thalweg construction is untried: built first on one coast (the east, whose names are cleanest) and
   measured before the rest.
g. *Answered* ("As proposed"). **LMÍ: the name only, its source traced; the 1,909 chart names sized by an LMÍ area sized instead by their outline when
   proposed, else their lettering.** *Alternative*: keep LMÍ's sizes; they set zooms from areas he distrusts, and the
   general map's are drawn broad.
h. *Answered* ("As proposed"). **timarit.is: what is stored read for each step's names as it is taken up** (Bjarni's 938 flagged paragraphs first, for
   the troughs and banks); more pages fetched only at his word. *Alternative*: read everything stored first; it holds
   little per name and the steps say what to look for.
i. *Answered* ("As proposed"). **Plan 080's forward design superseded by this plan**; its versions 1 and 2 and its §4 kept.
j. *Answered* ("A mode on the page"). **The review on the names page**, a review mode added, not a new page: the page already holds the ledger, the layers and
   the old maps (plan 076's rule: one UI step at a time).

## 9. Not in this plan

Publishing outside MFRI; the harbours (plan 075); digitising the old land maps (the maintainer: "we should not really go
this deep here"); the catch on the fixes (decision 261).
