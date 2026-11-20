# 338 — Plan 081 step 1 built: Claude's proposals for the deeps, Bjarni Sæmundsson a witness, a review mode on the names page

*2026-11-20. Plan 081 §7 step 1, at the maintainer's word ("Yes, start step 1", after decision 337). Built, tested and
written by Claude (AI); the reading of Bjarni's articles by a reading agent of Claude's; no person has checked the counts or
the code. Study: `$FISHYDATA/archive/2026-11-20-proposal-deeps/`.*

## What was built

- **`reference/names/place_name_proposal.R`** (standalone, run by hand after `marine_name.R`): a proposal for every deep of
  ours (a name ending -djúp, -dýpi, -áll, -renna; 108) and for every one of ÍSOR's 28 troughs no deep takes (3), to
  `curated/reference/place_name_proposal.parquet` (a row a proposal: its kind, element, thing, extent, the witnesses
  agreeing and against, flags, his verdict), `place_name_proposal_evidence.parquet` (each witness on each candidate trough)
  and `place_name_proposal_shape.parquet` (the extents, the parts of shared troughs, the deeps' thalwegs), stamped `fd.version`
  081.1. The witnesses: the charts' letterings; LMÍ's records, each by its source (the Coast Guard's, the general map's and
  Sjómælingar Íslands' copies of the charts, Trackwell's and Hafrannsóknastofnun's of 2020 of the skippers); the skippers'
  tows by concentration ("-dýpi" joined with "-djúp"; his ignored names out); Bjarni's statements (below). The proposal: the
  candidate with the most independent witnesses agreeing, a copy counted with its source; ties, witnesses against and single
  witnesses flagged.
- **Bjarni Sæmundsson as a witness** (plan 081 §8 h): the 200 paragraphs of his Andvari articles that name a deep of ours,
  read into 203 statements (the study's `out/bjarni_deep_readings.csv`, read by the build); a statement agrees with the
  trough nearest the fjord, bay, headland or bank it places the deep by, a depth only confirms a trough the others name, a
  name the reader inferred or the text's fjord silent.
- **Rules tried and chosen** (Claude's, his to correct): a deep's place is the deepest 200 m cell within its trough's
  largest inscribed circle (the deepest cell of the whole outline lay on its edge for 25 of 40, 16 at the mouth on the
  slope; the circle is the outline's own, no distance chosen), the same rule now in `marine_name.R`'s trough links
  (Skerjadjúp's place moved 50 m, 377 m against 378 m: only a cell whose centre lies inside counts now); a trough several deeps take split among them by their nearest evidence, flagged.
- **`curate/checks/place_name_proposal_accounting.R`**: 9 checks (every deep in one proposal, every trough in one outcome,
  the witnesses counted from the evidence, a thing inside its extent, every verdict on a proposal), all holding.
- **The review mode** on the names page (`products/marine_feature_map/`, port 8822): a "Claude's proposals" section (the
  proposals by status, their extents, the thalwegs), a proposal panel with its evidence by candidate trough, Accept and
  Reject (ledger rows `accept proposal` and `reject proposal`, the key in `link_to`; for a trough no name takes, Accept also
  writes his `new` name over it), and a queue, the flagged first, by Review the proposals, Previous and Next.
- **`marine_name.R` applies an accepted proposal** before his hand links and pins (which win): the thing at the proposal's
  place, its extent the proposal's (LMÍ's set aside), its seabed link the trough. `place_name_versions.R` gives the change
  its reason. Tried with an Accept of Lónsdjúp on the test page's ledger copy and both builds in a scratch copy of
  `$FISHYDATA`: applied, every check holding; the scratch copy deleted, the real ledger untouched.

## What it found

111 proposals: 42 on a trough, 10 of them backed by three independent witnesses (Grindavíkurdjúp, Jökuldjúp, Húnaflóaáll,
Skagafjarðardjúp, Eyjafjarðaráll, Húnaflóadjúp, Lónsdjúp, Litladjúp, Kolluáll, Djúpáll), 29 of the 42 flagged; 69 deeps
wait for the depth model's outlines (step 5), most of them inshore channels. Among the flags: Reyðarfjarðardjúp (the
charts' trough 17, the skippers' trough 28), Faxadjúp and Jökuldjúp sharing trough 7, six deeps sharing trough 10, Nesdjúp
and Skagafjarðaráll on one witness against the charts. The thalwegs (14) are drawn, untried, for step 3.

## The skippers' "-dýpi", the same day

Asked by the maintainer whether the skippers or Bjarni use "-dýpi" for a place beyond "-djúp" (his reading of
Reyðarfjarðar-). Measured by Claude (study, scripts 02-03): no. No vessel writes both forms of one root (11 roots written both
ways); 144 vessels write "-dýpi", 23 "-djúp"; the two forms lie at the same distance from land for Reyðarfjarðar- (84.9 and
84.4 km), both mostly outside the charts' trough 17. Bjarni's "-dýpi" words (10 of 308 compounds) are all depths. In the
stored timarit.is pages a place name in "-dýpi" first appears in the 1970s. The maintainer: "I like this chronological
hypothesis of going from -djúp to -dýpi. Also that "dýpi" is more of a reference to depth rather than being a reference to
placename. Think we should keep this in mind in our work." Of Reyðarfjarðardjúp: "I think we "lock in" that
Reyðarfjarðardjúp and ISOR through 17 as being "the same"", to be entered by his Accept of `deep:5278` and his label's
move on the page. The page wrote first, at 08:01, an Accept of `deep:trough:28` (the skippers' Reyðarfjarðardýpi over
trough 28) twice and its `new` name; then his Accept of `deep:5278` and his label's move (08:02-08:03). Of trough 28, the
maintainer: "we should use "ÍSOR trough 28" as the name for what skippers call "Reyðarfjarðardjúp" - The thinking here is 1)
It is an inter-rim "measure" 2) It makes clearly the point that the skippers possible name is ambiguous, should be treated as
a possible synonym only. By naming it "ÍSOR trough 28" it is a clear reminder downstream that this has to be resolved
downstream." Entered as a `rename` of his name over trough 28 to "ÍSOR trough 28", Reyðarfjarðardýpi kept as its source's
spelling and synonym. Built: Reyðarfjarðardjúp on trough 17 (254 m), its label where he moved it; ÍSOR trough 28 on trough 28
(278 m), its extent the trough.

**Fixed on the way**: accepting a trough no name takes makes a name, the trough is then taken, and the proposal's key his
verdict cites went away (the proposal check failed). `place_name_proposal.R` now keeps that key on the name he made (matched
by the trough it is over, so a rename keeps it), counts his names over a trough among the deeps, and reads a name's synonyms
as its forms in the skippers' tows; `marine_name.R` gives such a name the trough as its extent, not a hull of its members.
Every check holds.

## Jökuldjúp and Faxadjúp: one deep (trough 7), the same day

Put to the maintainer with the evidence (the study's `out/trough7.png`, script 04): trough 7 runs 180 km from the slope into
Faxaflói with no sill and no moraine across it (one small one at its far south-west); the charts letter Jökuldjúp at three
scales in its middle and inner part and Faxadjúp at 1:300 000 just south of them and at 1:1 000 000 west of it; the skippers'
Jökuldjúp/-dýpi, 6,277 tows of 50 vessels, spread over it, their Faxadjúp 4 tows of one vessel. Bjarni Sæmundsson, Andvari
1929 p. 46 (timarit.is/page/4319032): "Jökuldjúp er nafnið á slakka þeim eða lægð, sem gengur frá úthafsdjúpinu", north-east
into northern Faxaflói, about 80 nm long and 20 nm broad; Andvari 1933 p. 62 (timarit.is/page/4319512), of the Danish sea
charts, a fault in his eyes: "ný nöfn í stað gamalla, eins og Faxaflóadjúp í staðinn fyrir Jökuldjúp"; Andvari 1935 p. 45
(timarit.is/page/4319683): the ocean deep its continuation outward. Claude's reading: today's Faxadjúp is that chart name.

His answer: "One deep, a synonym". Entered as a new ledger action, `join` (the row that goes in `feature`, the row kept in
`link_to`; `unjoin` undoes): Faxadjúp (5735) joined into Jökuldjúp (5731), its name Jökuldjúp's synonym, its two chart
letterings and its LMÍ record now Jökuldjúp's records (roles "lettering of Faxadjúp, a row joined into it by the
maintainer"), its own row gone, so the names map draws no Faxadjúp of its own, while the charts' own image behind it still
prints it. Then his Accept of Jökuldjúp's proposal, now trough 7 whole: its thing the deepest cell within the trough's largest
inscribed circle, 470 m in its outer basin (24.78 W 63.65 N), its extent the trough, LMÍ's set aside; the Accept row carries
Bjarni's three statements. `marine_name.R` takes his joins into its own joins (one thing from two sources), his kept row's
name used; a chart row's letterings now follow a join (the first chart row joined); both checks count and explain his joins.
Every check holds. The maintainer, of the chart's lettering: "we actually would need to remove the Faxadjúp lettering from
the chart ... I kind of think that it should happen concurrently": it does, with the join.

## Trough 10: the deeps sharing it, split by the trough's own shape, the same day

Nine deeps had been put on trough 10 (8,250 km², to 682 m) and split by the nearest evidence. Studied by Claude (study,
scripts 05-07; `out/trough10.png`, `out/trough10_divided.png`): the trough's basins by depth find only its outer basin (an
áll is no closed basin); its shape does. On 1 km cells, each cell's distance from the deepest cell along the trough; flooded
from the farthest in, a branch ends where it meets a longer one. Four arms (64, 57, 38 and 25 km; the next 9 and 4 km), the
main line cut where they meet it, its widths stepping at the junctions (about 11 km in the southern finger, 21-27 km beyond).
Each witness points a name to a part (the charts: the part of its largest-scale lettering; the skippers: the part with most
of its tows, two vessels or more; Bjarni: the part nearest the place he sets it by), each part to one name, the strongest
claim first. It gave Bjarni's description of 1933: Húnaflóadjúp sending two álar, Reykjarfjarðaráll and Húnaflóaáll, with
Kolkugrunn (the skippers' "Tungan") between them; a broad deep forking either side of Fljóta- and Siglunesgrunn into
Skagafjarðardjúp and Eyjafjarðaráll; no name of ours for the broad deep (682 m), the passage north of it or the outer part.
Drangaáll, Hornáll and Skagafjarðaráll have no lettering or tow inside the trough (only Bjarni's "Strandagrunn" and
"Skagagrunn" put them there: a large bank's point lies nearest whichever trough) and leave it, awaiting step 5; Fjallsdjúp's
one lettering lies at the inner end of Skagafjarðardjúp's part.

The maintainer: "Consider Reykjafjarðaráll, Húnaflóaáll and Húnaflóadjúp settled. My proposal is that Eyjafjarðaráll takes
over a much larger area northwards compared to what you draw. For the time being my suggestion is to extend the that name
all the way to the end of through 10. Then Skagafjarðardjúp is sort of the "left over", not going more westward than an
imaginary extention of Fljótagrunn." Then: "Skagarfjarðardjúp should then not go much more north than Sporðagrunn", and
"Sporðagrunn is actually the max. For lack of any suggestion a line from Sporðagrunn to Fjótagrunn could mark the boundary
of Skagafjarðargrunn." Claude's reading: the line bounds Skagafjarðardjúp on the east (it lies west of Fljótagrunn, Bjarni's
west fork), and Sporðagrunn is the one on Claude's figure, the skippers' tows' median (19.51 W 66.83 N, 2,912 tows of 46
vessels); the charts letter Sporðagrunn 25 km south-west (19.97 W 66.64 N), on Skagagrunn's northern tail, and a line from
there would cut the fork across. Fljótagrunn is the charts' place (19.33 W 66.20 N); its crest, the shallowest cell of each
200 m row across the bank, runs at about 19.24 W (script 06).

Entered at his word: `accept proposal` of Reykjarfjarðaráll (the western arm), Húnaflóaáll (the southern finger) and
Húnaflóadjúp (the main line beyond them); two new ledger actions, `limit` (a name kept to the left of a line walked from
`lon`/`lat` to `comp_lon`/`comp_lat`; `unlimit` undoes) and `rest` (a name takes every cell of the trough in `link_to` no
other name holds; `unrest` undoes): Skagafjarðardjúp kept west of the line from Fljótagrunn to Sporðagrunn and south of
Sporðagrunn's parallel, Eyjafjarðaráll the rest of trough 10. Built (each thing the deepest 200 m cell within its part's
largest circle): Reykjarfjarðaráll 364 m, Húnaflóaáll 311 m, Húnaflóadjúp 419 m; Skagafjarðardjúp the western fork, 302 m
at 19.58 W 66.45 N; Eyjafjarðaráll from the eastern fork through the broad deep to the trough's northern end, 700 m at
18.85 W 66.74 N. His Accept of both ("Yes, accept both", entered at his word); he had moved the five labels on the page.

**The rule, tried and changed on the way.** First an arm was a branch longer than the largest drop in the sorted lengths;
on the build's own 1 km grid (aligned to the whole depth model, not to the trough) the lengths came 64, 57, 38, 25, 9 against
the study's 66, 54, 38, 26, 9, and the largest drop moved from 26-9 to 57-38: two arms instead of four. Now an arm is a
branch longer than the trough is half wide near where it joins (the largest distance to the outline's edge among the cells
within one branch length of the junction): trough 10's four arms pass on both grids (64, 57, 38, 25 km against 18, 18, 12,
18 km), the 9 and 4 km branches do not (9.5 and 4.5 km; on a grid shifted 500 m, 8 against 9.1). The margin for the 9 km
branch is thin. The rule applies to every shared trough, so the proposals of troughs 8, 25, 26 and 27, later in the
queue, changed with it: Víkuráll takes trough 8 whole (Nesdjúp off it), Axarfjarðardjúp a part of 25 (Öxarfjarðardjúp,
its other spelling, off it), Kolluáll a part of 26 (Bjarneyjaráll off it), Djúpáll and Þveráll parts of 27 (Ísafjarðardjúp
off it), and parts no name takes in 25, 26 and 27. **Also fixed**: the charts' own spellings of a name are forms of it for
the skippers' tows (the 1:100 000 and 1:300 000 charts letter "Reykjafjarðaráll", as 70 vessels write it; the name's row
is "Reykjarfjarðaráll", so the skippers had not counted). `place_name_proposal_accounting.R` now holds 10 checks: a
witness count on its part, and a shared trough's parts never overlapping.

## Eyjafjarðardjúp a synonym of Eyjafjarðaráll, the same day

The maintainer: "Eyjafjarðaráll vs Eyjafjarðardjúp. The Latter comes from LMÍ. Care to check the issue. In one sense I have
certain sympathy with Eyjafjarðardjúp, -áll is normally a narrow construct. But then the Eyjafjarðardjúp is something that I
hear being commonly used." Measured by Claude (study, script 08, `out/eyjafjardardjup.png`): LMÍ's one record is a fishing
ground from Aðalkort, 1st edition 1984 (638 km²), 96 % of it over Eyjafjarðaráll's eastern fork, all three of the charts'
Eyjafjarðaráll letterings inside it; no skipper, no statement of Bjarni's and no stored timarit.is page has Eyjafjarðardjúp
(Eyjafjarðaráll: 102 tows of 7 vessels, 7 statements, 7 pages from the 1910s to the 2000s); one web search found no page
with it, another the Met Office's earthquake reports naming the graben off North Iceland Eyjafjarðaráll, from the
Húsavík-Flatey fault to the Kolbeinsey ridge's southern end (by the search's summary). His answer: "Yes, a synonym".
Entered as a `join` of LMÍ's row (1248090776) into Eyjafjarðaráll (3990). Aðalkort's record names what the charts do not,
against the build's grouping of Aðalkort's records with the charts: a lead for that rule, not changed.

## Trough 8: Víkuráll's, Nesdjúp a deep of its own, the same day

Put to the maintainer with the evidence (study, script 09, `out/trough8.png`): the charts letter Víkuráll inside trough 8 at
three scales and the skippers' Víkuráll gathers at its mouth on the shelf edge, their "Víkurál A-Horn" and "V-horn" (68
and 59 vessels) on the shoulders north-east and south-west of the mouth, a lead for the parts of later steps; Nesdjúp lies
42-54 km east of the trough by the charts' three letterings and the skippers' Nesdýpi (4,059 tows, 67 vessels; 15 inside
trough 8, enough for the skippers' rule, which compares troughs only, to name it), in no trough of ÍSOR's. His answer: "Yes,
both". Entered: `accept proposal` of Víkuráll (trough 8 whole) and of Nesdjúp (no trough, its place the charts', awaiting
step 5). He asked, of the page, whether ÍSOR's shelf break (291889) was linked to trough 8: it is linked to nothing; it is one
polygon, the whole shelf inside the break (288,856 km²), so a click anywhere on the shelf took it. At his word ("Can you
separate the ÍSOR's channels and shelf break on the map"), the names page draws the shelf break as a layer of its own, its
line (the polygon's outer ring), and the channels apart.

## Orkustofnun's names: ÍSOR's reports of 2008 attached, the same day

Asked by the maintainer, of Grænlandssund's source "Orkustofnun V201404005", whether Orkustofnun's material was mined. It
was: LMÍ's 70 records of that delivery (entered 2014-11, 2017-12 and 2022-12; 47 polygons, 23 points, coded fishing grounds
though they are seabed features, mostly far offshore) are, for 65, names of ÍSOR's four reports of 2008 for Orkustofnun
(GRG-ISOR-08041, 08044, 08045, 08125; staged in decisions 222 and 285; 145 names, 123 coined); the reports hold no
coordinates, the delivery gave the names their only geometry. Not in the reports: Sörlahryggur, Drekasvæði, Jan
Mayenhryggur, Norður-Atlantshaf, Noregshaf. At his word ("Yes, attach them"), `marine_name.R` gives each row of that
delivery its report entry: `report` (report, page, section), `report_entry` (its description), `name_en`, `coined`; 65
rows, 54 coined; LMÍ's Niflingur takes the report's Niflungur, a letter apart, flagged. `marine_name_accounting.R` counts
the 70 in one outcome (37 checks), `place_name_versions.R` gives the flag its reason, the names page shows the entry.

## Trough 25: Axarfjarðardjúp, Öxarfjarðardjúp its synonym, the same day

Put to the maintainer with the evidence (study, script 10, `out/trough25.png`): trough 25 runs from Öxarfjörður's mouth
north between the Mánáreyjar ridge and Sléttugrunn; the charts letter its inner part Axarfjarðardjúp at 1:100 000 and
1:1 000 000 and Öxarfjarðardjúp at 1:300 000 and 1:2 000 000, all within about 10 km; LMÍ has Öxarfjarðardjúp (the Coast
Guard's copy of the charts); Bjarni (Andvari 1933 p. 23) and the skippers write Axarfjarðardjúp, Bjarni the eastern of
the two narrower deeps the broad deep between Grímseyjargrunn and Sléttugrunn forks into. His answer: "Yes,
Axarfjarðardjúp". Entered: a `join` of Öxarfjarðardjúp (5901) into Axarfjarðardjúp (4371), then the `accept proposal` of
Axarfjarðardjúp on trough 25 whole. Its thing by the rule, the deepest 200 m cell within the trough's largest circle, lies
in the trough's outer part (17.01 W 66.72 N), about 20 km north of the charts' letterings; its label stays where the charts
put it. **Fixed on the way**: six coastal names (the fjord Axarfjörður among them) were held by the row joined away, and
two more by rows the rule had joined: `marine_name.R` now gives such a name the row kept as its holder, with a note;
`place_name_versions.R` gives the change its reason. Every check holds.

## Trough 26: Kolluáll's, whole; the outer basin asked of, the same day

The maintainer: "ÍSOR Trough 26 should be the cornerstone here. Then we go from there." Put to him with the evidence
(study, script 11, `out/trough26.png`): trough 26 (7,531 km²) runs from Breiðafjörður's mouth along northern Snæfellsnes
past Öndverðarnes to a basin up to 100 km across at the shelf edge. The build had split it into three parts (Kolluáll b2.2;
b1 and b2.1 unnamed) because the charts' Bjarneyjaráll lies in it. Kolluáll's witnesses: the charts at five scales on the
inner half (24.06-24.60 W), Aðalkort 1935's polygon (23.91-25.05 W, 86 % inside), Bjarni from "the main deep" in towards
the Breiðafjörður islands, the skippers' tows in all three parts. His answer: "Yes, whole through", after ÍSOR's troughs
were shown on the names page around trough 26 (the layer was there, off when the page opens). Entered: a `rest` of
Kolluáll (2108) on trough 26, then the `accept proposal` of `deep:2108`. Its thing by the rule lies in the outer basin
(26.76 W 64.13 N, 378 m), 151 km from the charts' 1:100 000 lettering; its label stays where the charts put it, off
Öndverðarnes. `place_name_proposal.R`'s texts now say "the trough whole" where a rest row gives a name every cell. Every
check holds.

Found on the way, not yet put to him as decisions: the names list's second Kolluáll (1181095462) is another feature, LMÍ's
case V202401009 (2024), an áll of 0.3 km² at 1:25 000 among the islands by Flatey, 28 km from the trough, joined to the
deep by name only (its proposal stands, unaccepted); Bjarneyjaráll, lettered only at the trough's inner end (1:300 000,
K42) and drawn by Aðalkort from 23.40 W to Bjarneyjar, is off the trough as a point name, its holder Breiðafjörður.

Then his question: "I am kind of intrigued how wide area Kolluáll will cover. Are there no infos that the deepest part does
then not have some specific name." Measured by Claude (study, script 12, `out/trough26_basin.png`, `out/trough26_bands.csv`):
no source names the basin itself. The charts letter nothing in it; LMÍ's names there are fishing grounds on its hills,
edges and tongue from the 2020 deliveries of Hafrannsóknastofnun and Trackwell (Hóllinn, Wilsonhorn, Jökultunga,
Narfahóll, Brattikantur); Bjarni calls what Kolluáll runs out of "the ocean deep" (úthafsdjúpið, 1929; aðaldjúpið, 1898),
unnamed; the gazetteer's entries there are positions and edges ("40 sml Kolluál", "Kanturinn N-við Jökultungu"), the rest
Oracle's island names at one default point. But Bjarni's own measures (Andvari 1929 p. 47) end Kolluáll where the basin
begins: "about 80 sjómílur" long by Bjarneyjar (148 km along the trough reaches 25.1 W), "narrower than Jökuldjúp" (which
he gives about 20 sjómílur broad), running in "between Jökulbanki and Látragrunn". Along the trough the width is 8-26 km
to 25.1 W and 30-100 km beyond; the depth falls to a sill of 256 m there between the deep off Öndverðarnes (342 m) and the
basin (350-430 m). Aðalkort's polygon ends at 25.05 W. Within 148 km lie about 1,900 km² of the trough, beyond it about
5,600 km². The skippers carry Kolluáll out into the basin (547 of their 1,489 tows inside the trough, 32 vessels).
Claude recommended ending Kolluáll at 25.1 W, the basin left to a part no name of ours takes. His answer: "Keep it whole".
Nothing changed: Kolluáll keeps trough 26 whole, as entered.

Then Bjarneyjaráll. Put to him: a part of Kolluáll at the charts' place (Claude's recommendation, as Bjarni has Kolluáll
keep 100 m "in under Bjarneyjar"), or the trough's inner end cut for it from 23.40 W (Aðalkort's polygon), which would need
a `limit` to hold against a `rest`. His question first: "So Bjarneyjaráll then becomes a "sub-channel" within Kolluáll,
right?"; then "Yes, part of". Entered: a `part of` of Bjarneyjaráll (5652) in Kolluáll (2108); its holder was Breiðafjörður.
`place_name_versions.R` now gives a holder set by his `part of` its reason. And LMÍ's Kolluáll by Flatey: "I would then keep
the LMÍ Kolluáll by Flatey as is." Entered: a `reject proposal` of `deep:1181095462`, the row kept as LMÍ has it. His
question: "we have tow Kolluáll in this region, they are though separate entities": yes, two rows, the deep (2108) and the
áll by Flatey (1181095462), neither joined to nor a synonym of the other.

## Trough 27: Djúpáll and Ísafjarðardjúp, split at moraine 54; Þveráll off, the same day

Put to the maintainer with the evidence (study, script 13, `out/trough27.png`): trough 27 (944 km²) is one narrow trough,
3-10 km wide and 130 km long, from inside the fjord Ísafjarðardjúp out past Deild and Ritur along Djúpáll to the shelf
edge at Halinn. The build had split it into Djúpáll's b2.2, Þveráll's b1 (the outer end) and an unnamed b2.1. The charts
letter Djúpáll at four scales outside the fjord and Ísafjarðardjúp at four inside its mouth; LMÍ's Ísafjarðardjúp is the
General Staff's fjord (641 km², to Deild); Bjarni's Djúpáll is "the áll off Ísafjarðardjúp", his Ísafjarðardjúp always the
fjord; the skippers' Djúpáll tows all lie outside the mouth. Þveráll is not on this trough: the skippers' (5,284 tows of
68 vessels) lie north of Kögurgrunn, 24 on trough 27 (the concentration comparing troughs only, as Nesdjúp on trough 8);
LMÍ's of Aðalkort 1984 lies off the trough on Barðagrunn's side. His words: "Through 27 is in principle only two entities:
Ísafjarðardjúp and Djúpáll"; then "I think moraine 54 is a nice candidate for splitting". ÍSOR's moraine 54 (11.2 km, its
top 118 m) arcs across the trough 4-5 km outside the Deild-Ritur line: the fjord's side 250 km² (its deepest 139 m),
Djúpáll's 695 km² (199 m within 10 km); the charts' eight letterings, the skippers' tows of both names and the depth all
part there. His answer: "Yes, split there".

Entered: a `limit` of Djúpáll (5742) and of Ísafjarðardjúp (5403) by moraine 54, each with the charts' 1:100 000
lettering as the point on its side, a `rest` of each on trough 27, a `reject proposal` of Þveráll (1201989137); after the
proposals' rebuild, the `accept proposal` of `deep:5742` and `deep:5403`. Djúpáll's thing by the rule lies at the trough's
outer end (24.58 W 66.85 N, 207 m), its label where the charts put it. **The rule changed** (`place_name_proposal.R`):
a `limit` may name one of ÍSOR's lines across a trough (`link_to`), the name kept on the side holding the row's point, the
line carried on along its end segments to the outline (a cell on the line itself to its nearer side); a name's limits hold
against its own `rest`; a name whose proposal he rejects takes no part of its trough (its place its own; LMÍ's Kolluáll by
Flatey leaves trough 26 so too). `marine_name.R`: an accepted fjord (LMÍ's feature fjörður) keeps its own place and its
own area, the area joined with its part of the trough (Ísafjarðardjúp's 641 km² to 670, its 38 names held as before);
otherwise the accept would have set the fjord to the trough's strip. Every check holds.

## Trough 11 asked of; Paradísarhola brought in; LMÍ's oceans off the map, the same day

Put to the maintainer (study, scripts 14 and 15, `out/trough11.png`): trough 11 (1,945 km²) runs 100 km from Skjálfandi
north to 67.22 N, 400-500 m deep; the charts letter Skjálfandadjúp at its southern end, LMÍ's Aðalkort 1984 polygon reaches
66.78 N, Bjarni has "the broad deep between Grímseyjargrunn and Sléttugrunn" fork into Skjálfandadjúp and Axarfjarðardjúp,
no skipper writes the name; the second row, ÍSOR's Skjálfandadjúp (2000000014), is its volcanic system of that name beside
the trough. Claude's recommendation, Skjálfandadjúp to 66.78 N, awaits his word. His question: "If so, what could be the
name north of the "end"?" No source names that part but for Paradísarhola: LMÍ's fishing ground of 150 km² in it (Trackwell's
delivery of 2020, citing Fiskifréttir 28.05.14), 45 tows of 3 vessels (2010-2021), and Fiskifréttir 31 May 2002 (a stored
timarit.is page): shrimp grounds north of Grímsey, a large valley but not deep.

His word: "I have a hard time getting LMÍ Paradísarholan on the map. So please do so." Brought in by
`overrides/marine_name_include.csv` (as Gullhóll), a name of the list from the next build. And: "these very broad LMÍ areas,
like Norður-Atlantshaf, Íslandshaf - get rid of them." Claude first entered ledger `remove` rows for LMÍ's five ocean names
(Íslandshaf, Norður-Atlantshaf twice, Noregshaf, Grænlandshaf), which failed four checks (a removed row of version 1 had no
outcome there); before they were fixed he corrected it: "Removal from a map is different than a removal from the records."
The removes were undone by `restore` rows; the names page (`products/marine_feature_map/marine_feature_map.R`) leaves LMÍ's
oceans out of its LMÍ areas layer, an ocean LMÍ's feature haf in its large class (Íslandshaf and Norður-Atlantshaf; LMÍ's
races are haf of the small class). The records are as before. Every check holds.

His answer on trough 11: "Suggest northern end of Skjálfandadjúp where the northern end of LMÍ Skjálfandadjúp is now. And
then lets use Paradísarhola." Entered: a `limit` of Skjálfandadjúp (4232) south of the parallel of LMÍ's (Aðalkort 1984)
northern tip (17.6158 W 66.7761 N), a `limit` of Paradísarhola (2100139696) north of it, a `rest` of each on trough 11;
after the proposals' rebuild, the `accept proposal` of `deep:4232` and `deep:2100139696`. Skjálfandadjúp holds 679 km²
(66.34-66.78 N), its thing at 17.80 W 66.63 N; Paradísarhola 1,277 km² (66.78-67.22 N), its thing at 18.10 W 67.07 N; both
labels where they were. **The rule changed** (`place_name_proposal.R`, its check): a name he gives the rest of a trough is
a deep of that trough whatever its ending (Paradísarhola ends -hola), his `rest` setting its trough. ÍSOR's Skjálfandadjúp
(2000000014, its volcanic system) shares the deep's proposal, undecided. Every check holds.

Then ÍSOR's row, Claude's recommendation to keep it as ÍSOR has it, a separate entity; his answer: "Yes, keep it apart".
Entered: a `reject proposal` of `deep:2000000014`; it leaves trough 11 by the reject rule, its place and area ÍSOR's.

## Troughs 19 and 20: Langanesdjúp and Þistilfjarðardjúp, each whole, the same day

Next in the queue, both flagged as one witness only (the charts). Study script 16 (`out/trough19_20.png`): each trough
carries one name. Trough 19 (1,017 km², 54 km from off Langanes north-east to 67.05 N, 220-284 m): the charts letter
Langanesdjúp inside it at 1:300 000, 1:1 000 000 and 1:2 000 000; LMÍ's polygon (Landhelgisgæslan 2014, the charts', 826 km²)
over it; the skippers tow it as Brettingsstaðir, Langanesgrunn and Rifsbanki, and Langanesdjúp is one vessel's. Trough 20
(1,602 km², 85 km from off Þistilfjörður north-west to 67.27 N, deepening from 247 to 429 m): the charts letter
Þistilfjarðardjúp inside it at 1:300 000; LMÍ's polygon (the charts', 437 km²) over it; the skippers' tows there are
Rifsbanki's (474 of 548), a ground, and Þistilfjarðardjúp is one vessel's. One stored timarit.is page names both
(Náttúrufræðingurinn 1963, of the fjords' catchments). No second name of a deep for either trough.

His word, before Claude had put a recommendation: "I think there is no discussion here, we use the ÍSOR as base." Entered:
`accept proposal` of `deep:5941` (Langanesdjúp, trough 19 whole) and `deep:5912` (Þistilfjarðardjúp, trough 20 whole).

## Eleven troughs of one name each, accepted whole, the same day

His question after troughs 19 and 20: "I think there are quite a few we should treat the same way. care to list them."
Study script 17 (`out/one_name_troughs.csv`): every ÍSOR trough with its proposals and the share of it each takes, the
charts' letterings of a deep's name inside it, LMÍ's sea names of a deep lying half or more inside it, the names list's
deeps placed in it, Bjarni against, and the skippers' names inside it. Of the 17 troughs without his verdict, 11 carry one
deep's name, every witness agreeing, nothing else naming a deep inside, the proposal the trough whole: 1 Skeiðarárdjúp,
2 Skaftárdjúp, 3 Reynisdjúp, 5 Grindavíkurdjúp, 12 Hornafjarðardjúp, 13 Lónsdjúp, 14 Seyðisfjarðardjúp, 15 Bakkaflóadjúp,
16 Norðfjarðardjúp, 18 Litladjúp, 22 Breiðamerkurdjúp. His answer: "Yep all 11". Entered: an `accept proposal` of each.

The six left have a second name or a doubt: 4 Háfadjúp (LMÍ's Eyjafjalladjúp, Aðalkort 1990, inside), 6 Skerjadjúp (the
charts alone; LMÍ's Sæmundarrenna inside; the skippers' Skerjadýpi towed mostly outside the trough), 9 (no chart name; the
skippers' Vikið Norðurkanti, two vessels), 21 Berufjarðaráll (Bjarni against), 23 (the charts' and LMÍ's Hola inside, a
-hola name the build did not take as a deep's; the skippers' Gulateppið proposed), 24 Héraðsflóadjúp (the charts'
Héraðsdjúp at 1:1 000 000, LMÍ's Seyðisfjarðaráll inside).

## Troughs 4, 6 and 24: Háfadjúp, Skerjadjúp, Héraðsflóadjúp, each whole, the same day

His word on three of the six: "Through 4 - Let Eyjafjalladjúp be a synonym of the the main name, Háfadjúp. / Through 6 ->
Skerjadjúp / Through 24 -> Héraðsflóadjúp, Héraðsdjúp a synonym." Entered: a `join` of LMÍ's Eyjafjalladjúp (1215631762, a
fishing ground from Aðalkort 1990, 280 km², 62 % of it inside trough 4) into Háfadjúp (3674), as Eyjafjarðardjúp into
Eyjafjarðaráll; a `synonym` Héraðsdjúp of Héraðsflóadjúp (5930), whose row already holds the 1:1 000 000 lettering and LMÍ's
record of that name (Aðalkort 1945); and the `accept proposal` of `deep:3674`, `deep:1807` and `deep:5930`, each trough
whole. Sæmundarrenna stays a part of Skerjadjúp by his word of 2026-11-19. LMÍ's Seyðisfjarðaráll inside trough 24
(Hafrannsóknastofnun's delivery of 2020) is not in the names list (decision 336) and is left as it is.

## Troughs 23 and 9: Hola, Gula teppið its synonym; Vikið Norðurkanti for now; trough 21 asked of, the same day

His word: "Trough 23 - Lets use Hola, "Gula teppið" a synonym. / Trough 9 - Call it Vikið Norðurkanti for now". Hola is the
charts' row 5916 (Hola at 1:300 000, Hóla at 1:1 000 000, LMÍ's Hola, the charts', its record), a -hola name the build did not
take as a deep's. Entered: a `rest` of Hola on trough 23 (a rest makes any name a deep of its trough), a `synonym` Gula teppið
(his spelling of the skippers' Gulateppið), and after the proposals' rebuild the `accept proposal` of `deep:5916`: Hola takes
trough 23 whole, its witnesses the charts and the skippers (by the synonym). Trough 9 as trough 28 was: the `accept proposal`
of `deep:trough:9` and a `new` name Vikið Norðurkanti over the trough citing the key, an interim name.
**The build changed** (`place_name_proposal.R`): with both, every ÍSOR trough carries a name, and the build stopped on its
empty table of the troughs no name takes; an empty one is now left out of the bind, as an empty table of parts was.

His "Lets hear the story" of trough 21, Berufjarðaráll (study script 18, `out/trough21.png`): the charts letter it inside
ÍSOR's trough 21 at all four scales; LMÍ's polygon (the charts', 475 km²) 67 % inside; the skippers' tows on the east coast
(10,658 of 76 vessels) 36 % inside the trough and 50 % within 5 km beyond its outer end, along the shelf edge (Trackwell's
Berufjarðarálshorn, 62 km², there; 913 more tows of 50 vessels under the name off the south-west, at 23 W, another use). The
build's "against: Bjarni" is its rule's, not Bjarni's: his "the bank between Lónsdjúp and Berufjarðaráll I call Papagrunn"
was read as Berufjarðaráll adjoining Papagrunn, placed in Papagrunn's nearest trough, 13 (17 km) over 21 (18 km). Read
together his statements give the order along the coast Lónsdjúp, Papagrunn, Berufjarðaráll, Hvalbakur (Breiðdalsgrunn's
southern part), Litladjúp, and the middle of Papagrunn and Hvalbakur lies inside trough 21; he fished both its edges and its
north-east edge at the mouth, and found a coral forest (Primnoa) inside the mouth. Claude's recommendation: trough 21 whole.
His answer: "Yes, trough 21 whole". Entered: the `accept proposal` of `deep:5074`. **Every one of ÍSOR's 28 troughs is now
decided**: 38 verdicts with this one, 34 names on a trough.

## The trough names' letters along their areas; the zoom asked of, the same day

His question, "I am wandering if I should not hand edit all the names we now have for these trough's", then "ahhh, so the
letters on the map as we have now are not linked to the shapes?": no. An accept set a name's thing and its area, its letters
staying at version 1's place and angle (his hand placements of version 1 for 25 of the 34, else a box's middle, the finest
lettering or ÍSOR features' middle). Study script 19: 24 of 34 within 20 degrees of their trough's long axis, 33 inside it.
His answers: "Yes, where no hand", then before it was built "I think we may as well process all the letter positions the
same way. Do do them all." **The rule** (`marine_name.R`, at the accepts): an accepted name's letters at its accepted area's
middle (a fjord's area joined with its own), turned along the area's long axis (the principal direction of a regular grid of
about 600 points inside it, no random offset), version 1's hand placements and his earlier moves included; a move or turn of
his after his word (`LETTERS_RESET`, 2026-11-20T13:37:50Z) wins. All 34 set so. The checks `marine_name_accounting` and
`place_name_versions` give the change its reason. On round troughs (Vikið Norðurkanti, ÍSOR trough 28) the axis means little.

Claude's earlier statement that the zoom follows the area was wrong: `z_rule` is version 1's rule e on version 1's extent,
not recomputed when an accept changed the extent. His "You may as well also start thinking about the zoom levels, now that
you have area values": study script 20 (`out/zoom_vs_area.csv`) sets the 34 names' zoom now against rule e (the label twice
its area's length, 7.5 px a letter at 16 px) on the accepted area: by its long axis 28 within a zoom of now, 6 a zoom or
more earlier (Jökuldjúp, Paradísarhola, Víkuráll, Kolluáll, Héraðsflóadjúp, Þistilfjarðardjúp), none later; median a third
of a zoom earlier; Kolluáll and Jökuldjúp at the floor, zoom 4. The axis against the box's side: 7 % longer, 0.08 zoom, so
the choice hardly matters. Against the coarsest chart lettering the name (a guide only, his word of version 1): rule e
earlier for 28, a median zoom. Claude's recommendation, rule e on the new area, as the letters follow it; his answer: "Yes,
rule e on the area". **The rule** (`marine_name.R`, with the letters): an accepted name's zoom (`z_rule`, and
`z_rule_computed`) rule e on its accepted area's length along its long axis in the map's metres, its size with it (16 px at
20 km or more, 14 at 5); a zoom edit of his wins. The 34 agree with study script 20 within 0.03 of a zoom; Kolluáll 4.00 and
Jökuldjúp 4.01 at the floor, Reynisdjúp 7.86 the last; Háfadjúp, Litladjúp, ÍSOR trough 28 and Reynisdjúp at 14 px. The two
checks give it its reason. Every check holds.

## Lóndjúp and Fjallsdjúp parts of their deeps, the same day

His question, "Are we now not done with this phase?": the troughs are, step 1 not. Of its 108 proposals 74 deep names lie
on no ÍSOR trough and wait, by the plan, for step 5 (the depth model's own outlines): 50 inshore channels under 100 m (most of
them Breiðafjörður's small álar of LMÍ's, the Westfjords' fjord álar, Faxaflói's rennur), 13 on the shelf outside the troughs,
11 in the ocean (5 channels at 1,700-2,600 m, 6 beyond the depth model); 6 of them his already (Nesdjúp accepted; Þveráll,
LMÍ's Kolluáll by Flatey and ÍSOR's Skjálfandadjúp rejected; Bjarneyjaráll and Sæmundarrenna parts). Two lie inside a deep he
decided: Lóndjúp in Ísafjarðardjúp's inner arm toward Ísafjörður, Fjallsdjúp at the southern head of Skagafjarðardjúp's part
of trough 10 (study script 21): each the charts' one lettering at 1:100 000, LMÍ's one record, no other witness. Claude's
recommendation, a part of each, as Bjarneyjaráll; his answer: "Yes, both part of". Entered: `part of` of 2959 into 5403
and of 5396 into 3957.

His question, "does that mean we have to extend the Ísafjarðardjúp and Skagafjarðardjúp boundary?": no; `part of` sets the
part's holder, not its whole's area. Lóndjúp's area (LMÍ's, 21.7 km²) lies wholly inside Ísafjarðardjúp's, Sæmundarrenna's
inside Skerjadjúp's; Fjallsdjúp's (29.4 km²) lies 54 % south of Skagafjarðardjúp's, beyond the trough's end toward
Skagafjörður, as Bjarneyjaráll's (56 km²) lies 54 % beyond Kolluáll's, into Breiðafjörður.

## Step 1 closed: version 2 frozen and shipped, the same day

His word: "Yes, close step 1". Done by Claude in this order:

- **Committed**, 7c6f996 (not pushed). Then the names, the proposals and the map's table were rebuilt from that commit
  (`marine_name.R`, `place_name_proposal.R`, `marine_feature.R`, `products/marine_feature/names.R`), so their stamps name
  it. The tree was dirty only with another session's notes and an untracked export script, none of the names' code. All
  checks pass: 10, 37, 3, 13 and 7.
- **Version 2 frozen** by `reference/names/freeze_version.R` into `curated/reference/place_names/v2/`, 11 files with their
  md5s in its manifest. Eight are the names' own: `marine_name` with its source, record, extent and pair tables,
  `marine_feature` with its links, and `names.parquet`. The other three are the proposals it was reviewed on,
  `place_name_proposal` with its evidence and shapes (their version "081.1"), which the script now copies beside them.
- **ogisdata 2026.11.20**: `data-raw/files.R` took `names.parquet` under plan 078's rule (its stamps, its own code
  committed, `marine_feature_accounting` holding on the same input): 27,336 rows, 2.3 MB. Installed, its 20 tests pass
  on the installed package. Not committed in ogisdata, whose tree holds another session's uncommitted 2026.11.19.4, and
  not copied to the share, which is the maintainer's.
  - Found on the way: `files.R`, run by Rscript with no locale set ("C"; ogisdata has no `.Renviron` as fishycode has),
    wrote `files.csv` cut at its first non-ASCII letter, "LM" of LMÍ, and two tests failed. Run again under
    en_US.UTF-8 the file is whole. `files.R` now stops unless its locale is UTF-8.
- **Version 3** begins: `VERSION <- 3L` in `marine_name.R` and `marine_feature.R`. The names from now on are version 3,
  measured against the frozen version 2 by `place_name_versions.R`: of 27,336 rows 27,335 the same, 1 changed, none gone
  or new.
  - The one change: Grjóthryggur's angle, -65.1° to -65.0°. Its letters run along ÍSOR's area by `along_axis()`, whose
    points came from `st_sample(type = "regular")`. That grid has a random offset, so the angle moved a few tenths of a
    degree from build to build. `along_axis()` now calls `axis_of()`, whose grid is fixed. Grjóthryggur is the only row
    it places.
  - Also found: the check stopped when no row was gone, the first time it met that case. Its table of gone rows now
    holds zero rows.

## What is next

Step 1 is closed. The 72 deeps on no ÍSOR trough and no decided deep await step 5 (the depth model's outlines). Next is
plan 081 step 2, the moraines, whose proposals will be version "081.2". TODO 206.
