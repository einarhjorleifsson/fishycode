# 336 — The place names by region: plan 080's revision adopted, asks k-q answered

*2026-11-19, late. At the maintainer's word: the plan revised by region ("Yes, draft it - but I think if we are going regional
we have then to take in more sources, like Trackwell"); its asks k-q answered one by one the same night, each by choosing
among the options offered. Drafted by Claude (AI); a person has not checked the record.*

## What was chosen

Plan 080 §3 and §5.3-§5.6 (`curate/plans/080-place-names-in-versions.md`): after version 2, the place names go forward by
region, each region taking in every source it needs; the model and the rules of versions 1 and 2 hold everywhere.

- **k, the regions** ("As proposed"): Reykjaneshryggur; the Kolbeinsey Ridge north of Grímsey; Vestmannaeyjar and the south
  shelf; Faxaflói and Breiðafjörður with the west shelf; the Westfjords' shelf; the north shelf with the Tjörnes zone; the
  north-east and east shelf; the south-east shelf; the Iceland-Faroe Ridge and the deep ocean. **The order** ("Side by side"):
  the Kolbeinsey Ridge opened while Reykjaneshryggur's review goes on, each frozen when its review is done.
- **l, versions** ("Several at a time", not the proposal of a version a region): finished regions go out together, fewer
  ogisdata versions.
- **m, LMÍ's copies** of Trackwell's and Hafrannsóknastofnun's deliveries ("As proposed"): the name taken, never the place;
  each placed on a feature or listed; the polygon a weak witness of where the name is used.
- **n, Trackwell** ("Candidates, my yes"): a name a candidate only, by the named-features study's rule, held to a feature its
  use falls on, in the list only by his yes on the page. Public since decision 335.
- **o, the depth model's own features** ("Region by region"): built as each region opens.
- **p, ÍSOR's landforms** ("All Iceland now"): its troughs, moraines, shelf break, channels and streamlines into
  `seabed_feature` for all Iceland.
- **q, the gazetteer's other sources** ("Region by region"): witnesses where a region needs them, a name from them a candidate.

## Built the same night: ÍSOR's landforms (ask p)

By Claude, at the maintainer's word ("Yes, start"); no person has checked the counts. `sources/isor/landform.R` stages ÍSOR's
ten landform layers as delivered (11,481 records; each keyed by its layer's own unique number, OBJECTID_1 for the moraines,
whose OBJECTID repeats). `reference/seabed/seabed_feature.R` takes the eight kinds ask p named into `seabed_feature`: 28
troughs, 728 moraines, the shelf break, 55 canals, 159 turbidity channels, 21 meltwater channels, 1,674 glacial and 549
gravity streamlines (3,215; 5,262 features in all); the 8,265 plough marks and the grounding line left out, not asked for,
each counted. A line's place is its middle, an area's a point inside it. 96 polygons repaired, 72 of them refused by the maps'
DuckDB; no line was refused, and the repair now only simplifies a line (the buffer out and back would leave a sliver).
`curate/checks/seabed_feature_accounting.R`: 7 checks, all holding. The page draws them as four layers, off when it opens.

**Found**: ÍSOR's landforms carry no names. Their `Name` holds a type word ("djúp" on every trough, "Terminal_moraines" on 704
moraines) or a code; Claude had said the troughs were all named and 712 moraines named, counting filled fields. They are
features, as the plan wants them; a trough's name comes from the charts and LMÍ.

## Reykjaneshryggur by the recipe, the same night

At the maintainer's word ("Yes, Reykjanes first": the recipe built on the region already open before the Kolbeinsey Ridge
opens). By Claude; no person has checked the counts; the thresholds are Claude's, his to correct.

- **The region**: `reference/names/place_name_region.R` draws it by rule, the hull of ÍSOR's Reykjanes Ridge features and its
  eleven ridge systems widened by 10 km, cut at 63.95° N (106,479 km²), to `curated/reference/place_name_region.parquet`;
  `overrides/place_name_region_open.csv` opens it at his word.
- **LMÍ's copies** (ask m): `marine_name.R` brings in every copy left out by version 1 whose area's point lies in an open
  region, 35 (and Gullhóll, his own, there too), each placed on the shallowest of ÍSOR's craters or guyots in its area, else a
  seamount's top, else the depth model's shallowest cell (9 on ÍSOR's features, the rest on the depth model), flagged for his
  review; ids 2,100,000,000 and LMÍ's own; a copy with no place would be listed (none).
- **Trackwell's candidates** (ask n): `reference/names/trackwell_candidate.R` puts each of Trackwell's 268 names with a tow in
  the region in one outcome (already a name 34, one vessel 172, carried in 44, a candidate on a feature 2, a candidate with no
  feature 16) to `curated/reference/marine_name_candidate.parquet`. The page draws the 18 candidates with Accept and Reject
  (rows `accept`, `reject`, the key in `link_to`), the other 250 as a layer off at start; an accepted one is a name at the next
  build (`src` trackwell, ids from 2,140,000,000: 2,200,000,000, first written, is past R's integer limit and was moved).
  Tried on the test page and a scratch build: an accepted candidate a name, its record "accepted by the maintainer".
- **Checks**: the names 34, the table 13, the versions 3, the seabed 7, all holding; the version check explains the 36 rows
  brought in and 4 wrecks now in a copy's area.
- **Not yet**: the depth model's own features for the region (ask o); the review itself (his).

## The maintainer's first verdicts on Reykjaneshryggur, the same night

Entered by Claude at his word as ledger rows (by "the maintainer (entered by Claude at his word)"): Kiddahóll the name used,
Trackwell's Vigga grunn its synonym ("likely synonums"), Kiddahóll's LMÍ area set aside ("the area stuff is off"); Urð og grjót
removed ("a meaningless area, remove from curated"); Pínulitlibanki pinned on the mound's top, 452 m, followed uphill from where
Trackwell's tows of the name centre ("Almost spot on, would move the point to the shallowest contour"); Márar his own name for
ÍSOR's mounds west of Arabinn (Reykjanes Ridge crater 244, Njörður crater 2, Reykjanes Ridge craters 291 and 292: "the Turks are
more eastward in the Medeterrainina and the Moores more westward. The Arabs were in the middle"). The build gained the actions
these need: `remove`, `area aside` and `new` (his own name over ÍSOR features, ids from 2,130,000,000); his renames and synonyms
are laid on once every name exists. Trackwell's names are matched to ours with case, accents and doubled letters aside, and in
another case within 5 km (Pínu Littli Banki, Bangsimon, Vigga grunn now "already a name"; 15 candidates left). Every check holds.
Claude's question to him misstated two places (Kiddahóll is on ÍSOR's seamount 167; crater 245 was where the rule had put
Pínulitlibanki), not his choice.

## Litlibanki and Pínulitlibanki measured, and the skippers' Skerjadýpi set aside, the same night

**Measured** by Claude at the maintainer's question ("Does the effort data support that the current polygon is fished /
trawled?", then "reviewed / anlyzed in relation to Pínulitli banki"); no person has checked the numbers. The fishing hours of
`products/effort_map/cells.parquet` (2007-2026) and Trackwell's named tows put the two names on one trawled band, the
Reykjanes Ridge's east flank at 450-620 m. Litlibanki's tows (957, 20 vessels) centre at 24.744 W 62.805 N, about 8 km east
of where the rule put it (Reykjanes Ridge crater 353, on the ridge's top, hardly trawled); Pínulitlibanki's (152, 10
vessels) at 24.954 W 62.674 N, about 1 km from his pin. Every one of the 9 vessels that log both puts Pínulitlibanki 11-24 km
south-west of its Litlibanki, along the ridge. The cores of the tows are fished at 37-40 h/km², the window at 21; LMÍ's
Litlibanki polygon (Trackwell's delivery) at 21.6, holding 5 % of the tows of that name; LMÍ's Pínulitlibanki (Hafró's
delivery), 27 km west, at 3.9, holding none. Reykjanes Ridge crater 354 (a guyot, 537 m), which he takes for the mound under
the name ("the mound could be called Litli hóll"), lies inside Litlibanki's core with 2.1 h/km² within 2 km. **Found**: a pin
leaves a link made by place in force: Pínulitlibanki stays linked to crater 245 on Hafró's polygon, 22 km from his pin (one
of the 6 pinned names). Proposed, not entered: Litlibanki pinned on the flank, Litli hóll his own name on crater 354, the
two LMÍ areas set aside, a pin dropping a link made by place over 3 km away.

**Set aside** at his word: "All skippers registry of "Skerjadýpi" should be ignored", then "also Skerjadjúp". A new ledger
action, `ignore`, keys a name of Trackwell's by its spelling joined (`link_to` "trackwell:skerjadypi", "trackwell:skerjadjup")
in every region; `reference/names/trackwell_candidate.R` gives it the outcome "ignored by the maintainer" before any rule,
kept in the table, never a candidate; `marine_name.R` records it so; the page draws it among the other names. Skerjadýpi was
a candidate with no feature (8,272 tows by 51 vessels); the chart's Skerjadjúp stands. 14 candidates are left (3 on a
feature, 11 with none). The feature table had been built before the names' last build and failed its check; rebuilt, every
check holds (the names 36, the versions 3, the table 13).

**His direction, not yet a rule**: "the Skerjadýpi/-djúp! fiasco should / could be applied to a lot of their records. Only
when it comes to "narrower" name may they be of any use", and "we have already pretty much established where "Skerjadjúp"
proper is. Same goes for a lot of other deeps and grounds. So any skipper records that are way off those should be
ignored." Measured by Claude, for his thresholds: of the 36 skippers' names in the region that are already ours, the
vessels' centre of 20 lies within 5 km of our place, of 6 at 5-15 km, of 10 beyond (Sæmundarrenna 108 km, Melsekkur 54,
Skerjadýpi 49 from the chart's Skerjadjúp, Reykjaneshryggur 32, Taglið 29, Gleðibanki 25, Hafnaleir 25, Matthildur 21,
Reykjanesgrunn 20), and 53 % of their tows lie more than 30 km from our place; several of those places are LMÍ's copies
placed by rule, not established. The radius holding 80 % of a name's tows: the two ignored 55-59 km, the 14 candidates 3-76
km (Úthaf 76, eldeyjarsvæði 40, Sparisjóður 26, Myrkur 26, Fjöllin 25).

**A "beyond" that sets itself, explored** at his word ("Explore if the you can set an dynamic "beyond" established deep and
grounds ... 1) An arbritrary bound comes back to haunt you, 2) The 15 km was just your guess based on just looking at
Reykjaneshryggur??": it was). By Claude, all Iceland; the study is `$FISHYDATA/archive/2026-11-19-skipper-names-beyond/`.
A fixed bound does not hold: past 15 km lie 43-76 % of the skippers' tows of an established name, whatever the place's size.
A bound in the size the names table carries does not either: where that size is LMÍ's area it is no outside measure
(Skerjadjúp's 52 km makes the skippers' Skerjadjúp look inside). The maintainer: "the problem is that Trackwell fed LMÍ".
Traced by LMÍ's heimild: of the 148 places, 8 take their size from LMÍ's areas of the deliveries V202005003 (Trackwell, 1)
and V202005002 (Hafrannsóknastofnun 2020, 7), there Trackwell judged by its own copy; 95 from LMÍ's other sources (the
Coast Guard's V201412010 and 011, LMÍ's general maps 1945-1992, its atlas), Skerjadjúp's from the general map of 1992; 45
from the chart's own lettering. A deep's own outline does: of the 23,042 tows of the names
whose place lies in one of ÍSOR's 28 troughs, measured outside the trough in its own mean width, 86 % lie within one width,
the count falls to a valley at 4-8 widths and a far group lies beyond 8, so the cut is read from the data. Skerjadjúp's are
off by it (4 % inside, 48 % beyond two widths); Berufjarðaráll, Víkuráll and Kolluáll are not (84-94 % within one). It
reaches only the 30 deeps ÍSOR mapped as troughs (of 436); the rest, and the grounds, need the depth model's own outlines
(ask o). Not built: no bound is applied.

**LMÍ's other sources, traced** at his question ("When was the Coast Guard's delivery made. And what may have been LMÍ's
general maps 1945–1992. Do we have them?"). By Claude, from IS 50V's records and the libraries' catalogues. The Coast Guard's
deliveries V201412010 and V201412011 (84 records, 75 of them fishing grounds) were entered into LMÍ's register in November
and December 2014 (78 in December); 71 of their 76 sea names are the charts' names, 69 within 10 km of the chart's place, so
they are the charts, not a witness beside them. "Aðalkort" is LMÍ's general map, *Ísland 1:250 000, aðalkort* (Uppdráttur
Íslands), nine sheets, some the Geodætisk Institut's surveys revised by LMÍ, depths by contours and soundings on some; LMÍ
entered its 98 records on 14-18 November 2014, citing first editions of 1935 (Breiðafjörður), 1945 (the north-east), 1984
(the north-west and north), 1990 (the south-east) and 1992 (the south-west: Eldeyjarbanki, Reykjanesgrunn, Skerjadjúp); 77 of
its 100 sea names are the charts'. "Atlaskort" is the 1:100 000 atlas sheets (87, the Danish survey's of 1900-1940, last
revised 1989), served by the national map service as `LMI_raster:atlas`. None is in `$FISHYDATA`. The American Geographical
Society Library (University of Wisconsin-Milwaukee) holds the general map's nine sheets scanned, both sides (18 JPEG 2000
images of about 10,000 by 7,300 pixels, 19-42 MB each; the verso an index of places), collection agdm, item 24260. Not
taken further, at his word: "I think we should not really go this deep here - if these are just images, not vectorized
stuff we would have a lot of work to do." Then: "But the link to a server of those may be a helpful map background": the
names page (`products/marine_feature_map/`) has three more base maps from the national map service's cache, the Atlaskort
1:100 000 (`LMI_raster:atlas`), the Danish 1:50 000 (`LMI_raster:Atlas_50`) and AMS 1:50 000 (`AMS`), images only, read
for no name; the general map has no server.

**Found and fixed** on the way: a move, turn or zoom of a row the build makes after version 1's rows (a copy brought in, a
Trackwell name accepted, his own name) found no feature and stopped the build, so the page would not start (his move of
Sæmundarrenna's label, 23:24). `marine_name.R` now applies such edits once those rows exist; the label moves, the thing stays
where the rule or his pin puts it. Every check holds.

**Skerjadjúp on ÍSOR's trough 6**, at his word ("Yes, do it", to Claude's proposal): ledger rows `link` (Skerjadjúp to
`isor:landform:trough:6`) and a new action, `part of` (Sæmundarrenna, the whole's id in `link_to`). `marine_name.R`: a name
linked by hand to an ÍSOR area takes that outline as its extent, LMÍ's set aside as for ÍSOR's own areas; one linked to a
trough has its thing at the trough's deepest 200 m cell of the depth model. Skerjadjúp: its thing from "a point inside
LMÍ's area" (23.428 W 63.431 N) to the deepest point, 378 m at 23.358 W 63.336 N; its extent from LMÍ's 1,510 km² (the
general map of 1992) to the trough's 818 km², 37 km across; its label his, unchanged. Sæmundarrenna's holder Skerjadjúp; its
thing on rule m's rise until he pins it. Left as they are: Skerjadjúp's holder, Reykjaneshryggur by version 1's hierarchy
(Claude: it looks wrong, a shelf trough off Reykjanes; his to say), and Heimsmeistarahryggur, an LMÍ copy whose place lies
inside the trough. The version check gives the change its reasons; the page draws the linked outline among ÍSOR's areas.
Every check holds.

**Heimsmeistarahryggur**, the maintainer with the trough drawn: "what Heimsmeistarahryggur refers to, at least for the moment
is the shallow ridge that sits a little bit south of Skerjadjúp", "southward of the deepest area of Skerjadjúp, sort of before
the landscape goes deeper again", and "could actually be a moraine". Measured by Claude on the depth model: a sill on the
trough's south rim, crest 297-307 m at 63.205-63.225 N from 23.70 to 23.45 W, 9-29 m above the trough to its north (most at
23.60-23.55 W), the slope south of it to 450-480 m by 63.15 N; ÍSOR maps no moraine there (its moraines in the band lie west,
24.0-23.8 W). Rule m had put the name on that sill (308 m, 23.594 W 63.201 N); pinned there, so the place is his word, not
the rule's. The skippers' tows of the name (1,111, 59 vessels) centre on the sill (23.505 W 63.213 N); LMÍ's area (Trackwell's
delivery of 2020) lies mostly on the slope south of it, kept as it is. With ÍSOR's moraines drawn round the trough: "Heimsmeistarahryggur
does not seem to b associated with an ISOR morain. But of course ISOR has not done everything, yet."

**Táin on ÍSOR's moraine 229**, 2026-11-20, the maintainer: "This is plain beutiful: moraine 229 is "Táin" as in
"Selvogsbankatáin"." Ledger row `link` (the chart's Táin, 5800, to `isor:landform:moraine:229`, a terminal moraine 24.5 km
long, 219 m at its middle). `marine_name.R` now takes a line linked by hand as the name's extent too (its length the
`extent_km`, the line a row of `marine_name_extent`), LMÍ's area set aside as for an area; the thing moves to the moraine's
middle (it was a point inside LMÍ's area, 4.9 km off); the label, the charts', unchanged. Left as they are: Táin's holder,
Grindavíkurdjúp by version 1's hierarchy, and no synonym added (Selvogsbankatáin is his gloss, not yet a row). Every check holds.

**Two more moraines**, the same night, the maintainer: "moraine 155 is what captains call "Brjálaði Hryggurinn" - you may
find the name in the trackwell records" and "moraine 143 then more or less depicts Suðurkantur/Suðurkantar". Ledger rows:
`link` of the chart's Suðurkantar (1805) to `isor:landform:moraine:143` with `synonym` Suðurkantur (his slash, one name);
`new` Brjálaði hryggurinn on `isor:landform:moraine:155` (id 2,130,000,002; Claude's spelling of his "Brjálaði Hryggurinn",
his to rename; Trackwell has "Brjálaði hryggur", 34 tows of one vessel). `marine_name.R`: a name of his own over one ÍSOR line
takes the line as its extent, its length the size (a hull of points before). LMÍ's Suðurkantur (the Coast Guard's of 2014)
stays a row of its own, 4.7 km from the moraine's middle: one thing with the chart's, not joined, the spellings differing.
Every check holds. The dig that followed is plan 081 §2.2.

**Found the same night, for plan 081** (study `$FISHYDATA/archive/2026-11-20-place-name-plan-review/`, scripts 01-13; by
Claude, no person has checked the counts): the skippers' names measured by their concentration on a feature find the
deeps in 17 of the 25 of ÍSOR's troughs that hold one of ours ("-dýpi" the skippers' form of "-djúp"), and the narrow names
on moraines (Táin, Eldeyjarbankakantur); the effort's hotspots are not boundaries between names (a tow's nearest of another
name crosses a hotspot's boundary as often as its nearest of the same name), but a ground's footprint and a band's order of
parts; neither the 200 m line nor ÍSOR's troughs alone divide the shelf into banks; the texts already read (Bjarni
Sæmundsson in Andvari, Einar Jónsson in Víkingur, Ægir) give the rule of the deeps and banks and the terms' meanings.

**Sæmundarrenna**: "Here Sæmundarrenna is part of Skerjadjúp" (the maintainer, on the page, of ÍSOR's trough 6, which holds
the chart's Skerjadjúp). **Found**: rule m puts a copy on the shallowest point of LMÍ's area, right for a bank and wrong for
a deep; LMÍ's Sæmundarrenna, the only deep of its 34 copies, sits on a rise inside the basin (289 m; the basin reaches 378 m).
The skippers' Sæmundarrenna spreads from 31° N to 63° N, 2 of its 258 tows in the trough.

## What is next

ÍSOR's landforms into `seabed_feature`; the Kolbeinsey Ridge opened (its bounds, its features, LMÍ's copies and Trackwell's
candidates, the depth model's lows and slopes), beside Reykjaneshryggur's review on the page. TODO 206.
