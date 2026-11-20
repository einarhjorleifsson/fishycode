# 341 — Plan 081 step 3 on the east coast built: the banks' outlines from the deeps' lines, their parts placed in them

*2026-11-20. Plan 081 §7 step 3, the east first (§8 f), at the maintainer's word ("Start step 3, east coast banks"), his
review of the deeps' lines, and "Yes, build them". Built, tested and written by Claude (AI). No person has checked the counts
or the code. Study: `$FISHYDATA/archive/2026-11-20-proposal-banks/`.*

## What was tried

- **The texts' rule as it stood** (§4.1): the sea under 200 m, less the deeps as step 1 decided them, cut by each deep's
  thalweg toward its fjord. It failed on the east: one piece held eight banks and another four, because the banks join
  round both ends of each cut. Inshore a thalweg ends in mid-bay; offshore a trough ends short of the 200 m line.
- **The lines carried on**, at his word ("the thalwegs split -> you could always extrapolates these a bit"). Inshore each
  line runs straight on until it meets land; offshore it runs along the trough's axis until water of 200 m.
  - Found and fixed on the way: Lónsdjúp's line ran to a pond named Lón by Reyðarfjörður, and now runs to Lón's lagoon.
- **His review of the lines** ("not all of the thalwegs are useful - we did not review them").
  - Norðfjarðardjúp's was dropped: "a case in point that just does not do its job. Or you could put it the other way, what
    we call Norðfjarðardjúp is a bit of an enigma"; "Drop it".
  - The two pieces that several banks share were left whole: "Leave them for now", to be split later. These are
    Þistilfjarðargrunn with Langanesgrunn and Rifsbanki, and Skrúðsgrunn, Hvalbaksgrunn and Breiðdalsgrunn.
- **His questions on the starting point.** Plan 070's areas from the charts' names were weighed, and LMÍ's polygons; ÍSOR
  has no bank outlines.
  - His note on LMÍ: "the LMÍ polygons are rather crude, I think the main objective of them was only to find a rough spot
    to put the "letters" in". So LMÍ counts only by where its record lies, never by its outline.

## What was built

- **`reference/names/place_name_proposal.R`, its step 3 section** (stamped 081.3). It reads the study's reviewed pieces
  (`out/bank_pieces_extended.geojson`); the rule moves into the build when it is taken to the other coasts. Only pieces
  closed by lines on both sides count.
  - **Banks.** In each piece the bank the charts letter at the coarsest scale takes it; several at that scale share it,
    flagged.
  - **Shoals.** A bank lettered only finer is a shoal in it.
  - **A piece no chart bank takes.** A piece whose names are lettered at 1:100 000 or finer only gets a proposal of its
    own. There is none on the east.
  - **A bank's witnesses** on each piece: the charts' letterings, LMÍ's records (a copy with its source), and the skippers'
    tows (the piece holding most of them, at two vessels or more).
  - **A bank's thing** stays where the names have it, its extent the piece. Rifsbanki's place lies 1.8 km outside its
    piece, so its thing is the charts' coarsest lettering inside it.
  - **A part's or shoal's whole** is the bank its root names (Hvalbaks-halli, Hvalbaks-grunn). Failing that, it is the bank
    whose piece holds its lettering; in a shared piece, the bank lettered nearest it, flagged.
- **`curate/checks/place_name_proposal_accounting.R`**: 18 checks, all holding. Four are new for step 3:
  - a name in one proposal of each class;
  - every bank on its piece, a piece one bank's or shared and flagged;
  - every part's whole a bank;
  - every witness counted.
- **`marine_name.R`** applies an accepted bank and part.
  - A bank's extent becomes its piece, and its letters move inside the piece along its axis (decision 338's rule). A bank
    in a shared piece keeps its letters until the piece is split.
  - An accepted part or shoal takes its bank as holder, unless his own `part of` says otherwise.
  - `place_name_versions.R` gives the change its reason.
  - Tried with accepts of Papagrunn, Skrúðsgrunn, Hornfláki and Þúfugrunn on a copy of the ledger in a scratch
    `$FISHYDATA`: every check held. The copy was deleted; the real ledger is untouched.
- **The review page** (port 8822) takes the banks and parts:
  - step 3 first in the queue;
  - a bank's outline drawn;
  - a part's candidates its banks.

## What it found

There are 21 proposals:
- **11 banks on a piece.** Vopnafjarðargrunn, Glettinganesgrunn, Gerpisgrunn, Papagrunn and Stokksnesgrunn are each
  alone. The other six share two pieces.
- **Six shoals:** Þúfugrunn, Hafnþúfugrunn, Langsgrunn, Skerjagrunn, Kjölsenbanki and LMÍ's Digranesbanki.
- **Four parts:** Digranesflak to Vopnafjarðargrunn, Reyðarfjarðarflak to Skrúðsgrunn (as Bjarni has it), Hornfláki to
  Gerpisgrunn, and Hvalbakshalli to Hvalbaksgrunn by its root.

The witnesses agree with the pieces:
- LMÍ's records lie inside them.
- 53-100 % of a bank's own tows fall in its piece (Hvalbaksgrunn 79 % of 1,864, Papagrunn 61 % of 5,190).
- Plan 070's areas lie 38-100 % inside.

## The model after it, the same evening

His idea, tested on the east in the study (its scripts 08-10):
- **The cover:** the shelf inside ÍSOR's shelf break as deeps and grounds, with no no-man's land. The grounds are numbered
  between the deeps' lines and the banks are a level inside them. Seven grounds cover the east with no gap, and every chart
  bank lies in one.
- **The outer band:** the bottom trawl's ridge along the shelf break, from 2 km outside to 4 km inside it. It peaks at 56
  hours a km², with the same profile over the sea open to the trawl. The skippers name its stretches after the bank or deep
  behind them, -dýpi forms among them.

His word: "the basic concept is still clear: deeps, grounds and the outer band model", "with a no-man's land rule". The
rule is what his three elements settle for what is neither: the depth of deep against ground, the inshore boundary, and the
outer band's treatment. He noted that regulations (the
closures, the bottom trawl's own inshore limits, which follow the 12 miles only in the west and the north) explain some of the
effort's patterns.

Open, the no-man's land rule's three elements:
- the outer band's form: each ground's and deep's outer part, or a unit of its own;
- the inshore boundary;
- the depth rule where there is no trough.

Step 3's proposals still stand on the pieces: grounds and the band will replace them. Plan 081 revised at his word (§4.6):
"We want to start with the most simplistic model, and then dig in. The rules we use should be general"; its objectives "1)
Create robust rule to come up with "outer" area placenames and their boundaries, 2) augment the ÍSOR science stuff, that only
has focused on the deeps, volcanos, moraines, ... and ignored the gounds". Step 3 is the coarsest level over the whole shelf
first, the banks' anatomy a level below.

## Over the whole shelf, the same evening

The study's scripts 11-13, at his word ("Yes, the whole shelf"); plan 081 §4.6 revised with it.

- **No band at the coarsest level.** "the coarsest rule does not need to include the outer bound, it could be just deep and
  grounds"; "There is really not something "trawl ridge"". The bottom trawl's ridge at the break, measured on every coast,
  is the fishery's and the regulations'.
- **The ridges are elements of their own.** "They are an element of their own, even on a global model, this separates the
  American and the Eurasian tectonic plates"; "A grunn should at least not be able to "spill over" the Reykjaneshryggur".
  - Each crest is traced through ÍSOR's craters ("You see this Tjörnesgrunn - Kobeinsey fracture by just following the ISOR
    craters"): the longest path of their minimum spanning tree, carried on to the land and out of the shelf.
  - Its area is the ridge's volcanic systems and a corridor as wide as the craters' spacing.
  - The two crests cut the shelf into the two plates' sides: the west 103,599 km², the east 77,166 km². No ground lies on
    both.
- **The cover.** Deeps 46,524 km², 28 grounds 134,427 km², ridges 2,079 km², no gap. 52 of the charts' 54 banks lie in one
  ground each; Stóragrunn and Tjörnesgrunn lie in the northern ridge.
  - Four grounds hold no chart bank and stand because the skippers name them: Nýjagrunn north of Skagi, the skippers'
    Sléttugrunn east of the northern crest (the charts letter Sléttugrunn one ground further east), Eldeyjarboði and Boðinn
    by the Reykjanes crest, and Pétursey.
  - A piece no one names joins a ground on its own side of the crests. Three bays still join across a deep's line:
    Skjálfandi, Öxarfjörður, Stakksfjörður.
- **The lines.** Jökuldjúp's runs to Snæfellsjökull at his word ("Jökuldjúp -> Snæfellsjökkul"), and Kolluáll has none.
- **Land and sea as one landscape** (his): "the elephant in the room is our split into terrestrial vs marine waters".
  - The Reykjanes Ridge runs ashore, and the boundary goes east, then north to about Tjörnes, then west to the Kolbeinsey Ridge.
  - The north-west and the east are the oldest, carved by the glaciers. The mounds on the ridge through Iceland are
    post-glacial.
  - Wikipedia's pages, read for the picture, match: the Tjörnes Fracture Zone has three zones, Grímsey's, Húsavík-Flatey's
    and Dalvík's. The craters' crest follows Grímsey's.
- **Trough 11.** "here is a natural way to split Skjálfandadjúp and Paradísarholan, follow the ISOR volcano ridge".
  - The crest crosses the trough at about 66.55° N, through ÍSOR's volcanic system Skjálfandadjúp. Step 1 split it at
    66.7761° N.
  - Entered at his "Yes, enter it": the parallel undone (`unlimit`), each name kept on its side of the crest's segment
    across the trough (`limit`). Skjálfandadjúp is now 226 km², Paradísarhola 1,730 km²; every check holds, and version 4
    differs from version 3 in these two rows only.
  - Paradísarhola's name is for later: "That is not the objective".

## The names on trough 11, and a common coarse rule (the same evening)

**Trough 11's names**, at his word ("I would actually like to have the working tile "Skjálfandajúp" and then "Ytra
Skjáflandadjúp". Rather than the latter being called Paradísarholan. That hole may well exit within the "Ytra ..."").
- Paradísarhola's limit was undone and its proposal rejected. It leaves the trough and is kept as LMÍ has it.
- Ytra Skjálfandadjúp was entered as his own name on the part north of the crest, by accepting that part's proposal
  (`deep:trough:11:b1`), as Vikið Norðurkanti was on trough 9.
- Three changes in `place_name_proposal.R` made that possible:
  - a lone name with his limit is divided as a shared trough is;
  - a name he makes from a part's proposal keeps the part's key and takes the part;
  - such a name sits on its trough with no witness.
- In `place_name_versions.R`: a reason for a name his reject sends back to its source.
- Every check holds: proposals 18, names 37, versions 3. Version 4 against version 3: two rows changed, one new.
- He then: "forget the Skjálfandjúp issue for now"; "To me Skjálfandjúp should be what ÍSOR did. We split it afterwards, when
  we operate on the finer levels"; and of the deep's edge there, "determined by the shallowest ground, not the volcanic
  mountains". The coarse model draws trough 11 as one deep, and the names' split waits for the finer levels.
- Trough 11 is the only one of ÍSOR's 28 troughs holding a volcanic system (study script 14).

**A common coarse rule** for the coasts the ridge and the hotspot left alone (his: "Find a common corse rule for a landscape
model"; study script 11, `FREE_LINES=1`):
- **The deeps** are ÍSOR's troughs.
- **Each deep's line** runs from its deepest point up its own trough to its head (the point nearest the mainland), on by the
  cheapest route to the mainland's coast, and seaward out of the shelf. It needs no name. The place its name points to is a
  witness: on the east the lines land 6-19 km from it, and Jökuldjúp lands 10 km from his Snæfellsjökull.
- **The grounds** are the pieces between the lines. A piece at least as large as the smallest named one (372 km²) stands; a
  smaller one joins a neighbour on its own side of the ridges' crests.

Result: 35 grounds, 52 of the 54 chart banks in one ground each. The west alternates trough and bank from Faxaflói to Húnaflói.
The north-west's grounds are the largest, its troughs being few and long.

Open:
- the outer troughs with no fjord behind them, whose lines converge at the coast;
- the inshore boundary (Breiðafjörður, Húnaflói and Faxaflói lie inside their grounds).

**Adopted:** "Yes, keep them". The lines without names and the floor are the coarse rule (study script 11's default).

**Faxabanki** (his: "the Faxabanki not just another Danish misnomer, aka Faxadjúp"; study script 15):
- It is a name of today's charts (1:100 000-1:1 000 000) with no witness of use. LMÍ's copy is from the Coast Guard's list of
  2014, as its Faxadjúp is.
- The skippers' Eldeyjarbanki (14,653 tows, 85 vessels) is centred on the charts' Faxabanki lettering. Bjarni's Eldeyjarbanki
  (Andvari 1937) is the broad ground north and west of Eldey out to the Suður-Kantar. The 1:750 000 sheet IS26 letters
  Eldeyjarbanki there. No stored text names Faxabanki.
- That it is Danish is not shown, as no Danish chart of the place is on hand.
- Joined into Eldeyjarbanki at his word ("Yes, join Faxabanki into Eldeyjarbanki"), as Faxadjúp was into Jökuldjúp. Both of
  its rows were joined, the charts' (1809) and LMÍ's (1036075551), and Faxabanki is now Eldeyjarbanki's synonym.
  - Two checks were taught the join. `marine_name_accounting.R` counts a flagged pair of duplicates he settled by joining
    a row away (this pair was flagged "for his hand" on 2026-11-19). `place_name_versions.R` gives the reason for a name
    whose feature was joined away.
  - Every check holds: proposals 18, names 38, versions 3. Version 4 against version 3: two rows gone (joined), five
    changed, one new.
- Today's charts still print it. The Coast Guard's catalogue of 7 April 2025 gives the charts that do:
  - chart 35 Fuglasker, 1:100 000, first published 1972, current edition 12/2022 (identified by its name);
  - chart 31 Dyrhólaey - Snæfellsnes, 1:300 000, first published 1972, current edition 01/2020;
  - chart 21 Ísland, 1:1 000 000, 2008.

  Chart 15 (1:2 000 000, 2011) letters Eldeyjarbanki alone. Whether the 1972 first editions had Faxabanki is not known here.

## The weak points tested, and plan 081 revised (the same night)

At his word ("Yes, run tests 1-3"), with his objectives for the rule: "as few "exception" as possible" and "easy to explain
to a layman, like a vessel captain". Study scripts 16-17.
- **The bank level is two rules, not one, and not a regional matter.** Of 24 pairs of neighbouring chart banks in one
  ground, 11 have a sag or a trough between them, where the frame's rule applies again. 13 share one platform, parted
  only by what each is named for. Both kinds occur on every coast.
- **The frame is robust.** Six variants changed no chart bank's grouping: the floor at its second and third rank, the
  ridges' corridor halved and doubled, the outer troughs with no landward line, trough 10's lines from its shape. Three of
  its parts can go: the names in the troughs' parts, the outer troughs' exception, and the floor (fragile: it moves with
  one piece). In its place, a piece stands where a source names a place in it.

Plan 081 revised at his word ("Yes, revise the plan"):
- §4.6 states the rule as adopted, with his objectives and the tests.
- §4.1 gives a bank's outline by the two rules.
- §7 makes step 3 the frame's build: a curated layer with its check, the grounds as proposals in place of the 21 east
  pieces, then the banks. Step 4 is the ridges' finer parts. Step 5 drops "the grounds from the effort".
- §8 e and f are marked overtaken.

## What is next

- The frame into the build (plan 081 §7 step 3), then his review coast by coast; the inshore boundary.
- The inshore boundary, and the depth rule where there is no trough.
- Then the grounds and the ridges into the build in place of the east's pieces, and the banks' anatomy as the level below.
- Step 3's 21 east proposals stand on the pieces until then. Their two shared pieces are to be split later, by a line from
  Langanesdjúp, by lines from Hola or Litladjúp, by the banks' parts, or by the skippers' footprints.
