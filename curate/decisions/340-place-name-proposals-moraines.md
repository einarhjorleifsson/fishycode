# 340 — Plan 081 step 2 built: Claude's proposals for the ridge, edge, toe and tip names on ÍSOR's moraines

*2026-11-20. Plan 081 §7 step 2, at the maintainer's word ("Start step 2"), after step 1 closed (decision 338). Built,
tested and written by Claude (AI). The texts were read by a reading agent of Claude's. No person has checked the counts,
the reading or the code. Study: `$FISHYDATA/archive/2026-11-20-proposal-moraines/`.*

## What was built

- **`reference/names/place_name_proposal.R`, its step 2 section.** A proposal for:
  - every water name of ours, not a deep, one of whose words ends as the grammar's ridge, edge, toe, tip, horn, heel, tail,
    slope, snout, neck or foot (plan 081 §4.2; oblique forms too). There are 122.
  - every skippers' name of those endings that no name of ours takes and that names a moraine (below). There are 18.

  Rows are keyed `moraine:<name id>` and `moraine:skippers:<spelling>`, with class `moraine`, the kind by the ending, and the
  moraine or `none`. Stamped 081.2.

  The witnesses on each candidate moraine are:
  - **the charts**: the moraine nearest a lettering, within the corridor.
  - **LMÍ's records**: likewise, a copy counted with its source.
  - **the skippers**: the moraine holding the largest share of the name's own tows within its corridor, at two vessels or
    more. Spellings are joined, the definite article off, his ignored names out. A namesake's tows go to the namesake
    nearest that moraine, and to none beyond the namesakes' gap (plan 081 §2.2; 150 km).
  - **his word**: his link to a moraine, or his own name on one.
  - **the texts read for this step**: Bjarni's Andvari reports and the stored timarit.is pages. They agree with the candidate
    nearest the place a statement sets the name by, where there are two candidates or more; a depth agrees with a moraine
    whose middle lies within it.

  The proposal is the candidate with the most independent witnesses agreeing. Ties, witnesses against and single witnesses
  are flagged. Its thing is the moraine's middle and its extent the moraine; the other moraines its skippers' tows run
  along are drawn beside it (`spread`).
- **Rules tried and chosen** (Claude's, his to correct; the study's scripts 01-05):
  - **The corridor.** It is the distance at which the share of tows running along their nearest moraine (within 20°, 2/9
    by chance) has fallen half way to chance. The build measures it on every tow: 5 km. Corridors of 1 and 3 km were also
    tried, with all tows and with the aligned only; his three came out the same at each.
  - **No chaining of ÍSOR's pieces.** The gaps between them run evenly from 50 m to 10 km, with no break to take.
  - **Broad names.** A skippers' name of its own is proposed only where it is its moraine's most concentrated name, or
    where more of its tows lie on the moraine than off every moraine. Either test alone was worse:
    - The plurality alone dropped his Eldeyjarbankakantur (38 % on 143, 39 % off).
    - The mutual best alone dropped Hællinn and Fóturinn, beaten by Utan fótar.
    - With neither, Kolbeinseyjarhryggur came in at 1 % of its tows.

    A name of ours keeps the skippers' witness as the plan has it, flagged where its tows lie mostly off every moraine or
    another name tops its moraine.
  - **Off the shelf or volcanic.** A name whose place lies off the shelf, beyond ÍSOR's shelf break (726 of the 728
    moraines lie on it), or in ÍSOR's volcanic ridges takes no moraine. Ridges there wait for step 4: Reykjaneshryggur,
    lettered at 1:300 000 by a moraine at the shelf's foot. The rest wait for steps 3 or 5: Hvalbakshalli, a bank's slope
    to the ocean.
- **`curate/checks/place_name_proposal_accounting.R`**: 14 checks, all holding. Five are new for step 2:
  - every name of the endings in one proposal;
  - each proposal on a moraine or none;
  - its element and extent the moraine;
  - its witnesses counted from the evidence;
  - no name off the shelf on a moraine.
- **The review mode** on the names page (port 8822):
  - step 2 first in the queue;
  - a "Proposed moraines" layer;
  - the panel's candidates as moraines;
  - the spread drawn in orange.

  Accept and Reject are the same ledger rows as in step 1. For a skippers' name, Accept also writes his `new` name on the
  moraine, citing the key.
- **`marine_name.R` applies an accepted moraine proposal** as it does a trough's: the thing at the moraine's middle, the
  extent the line, the seabed link the moraine. Its letters sit midway on the line, along its direction, and its zoom is
  rule e on the line's length (decision 338's rule, for a line). `place_name_versions.R` and `marine_name_accounting.R`
  give the change its reason.

  This was tried with Accepts of Suðurkantar and of the skippers' Fóturinn on a copy of the ledger, building in a scratch
  `$FISHYDATA`. The run caught one fault, a single line handed to `st_line_merge()`, which was fixed. Then:
  - both were applied;
  - Fóturinn became his own name on moraine 193 and kept its key;
  - every check held.

  The copy was then deleted; the real ledger is untouched.

## What it found

There are 140 proposals: 26 on a moraine (8 of ours and the 18 skippers' names), and 114 with none. Of those 114, 21 wait
for step 4 (the ocean and volcanic ridges), 8 lie off the shelf, and 85 wait for step 3 or 5. Most of the 85 are LMÍ's
coastal horns, toes and kambar at 0-30 m, not on any moraine.

His three are borne out:
- **Táin on 229**: the skippers and his word. The charts' one lettering, at 1:300 000, lies by moraine 212, 4.3 km off.
- **Suðurkantar on 143**: three witnesses, the charts, Bjarni and his word. The skippers' Eldeyjarbankakantur lies on the
  same moraine.
- **Brjálaði hryggurinn on 155**: his word, with the skippers' Hryggurinn v. Vikurál and Víkurál V-horn on the same moraine.

Flagged for his eye:
- **Hali**: the charts and Bjarni put it on 121, the skippers' Halinn on 665, where Litlavikið is narrowly the most
  concentrated name.
- **Vesturálkantur**: the charts on 115, the skippers on 66.
- **Heimsmeistarahryggur**: the skippers' only, with 6 % of its tows on 38.

The texts gave 155 statements using the names as names, none calling one a moraine. Two names are two places each:
Norðurkantur (Faxaflói's Norður-Kantar in Bjarni, and shrimp grounds north of Horn) and Grjóthryggur.

## His review, the same day

His verdict on the moraines: "I really do not find using moraine very helpful." He adopted five, each entered at his word,
and set the rest aside: "The rest of the suggestion are all highly suspect and I would not adopt them, for now at least."
None of the rest has a verdict yet, so they stay in the queue.

- **Brjálaði hryggurinn on 155**: an `accept proposal` row.
- **Suðurkantar on 143**: an `accept proposal` row, with Eldeyjarbankakantur entered as a `synonym` beside Suðurkantur. He
  first wrote 142, then "that was a typo, it is 143". 142 lies 4.7 km south-west, under Belgableyða and Taglið (study script 08).
- **Norðurkantur on 219**, "at least as a first placeholder": the skippers' proposal accepted, and his `new` name on the
  moraine.
- **Táin on 229**, "the outer edge of Táin": an `accept proposal` row.
- **Ostahryggur on 220 and 221**, "a good placeholder": the skippers' proposal accepted, and his `new` name on both moraines.

Three things changed in the code with them:
- **His word may name several moraines.** His own names took one moraine until now. The proposal's extent and his name's
  are now the moraines his word names, kept as lines. The letters go to the point of them nearest their middle.
- **Letters along the line only for ridges and edges.** A ridge's or an edge's letters go midway on its line, along it, and
  its zoom is rule e on the line's length. He had asked: "I am assuming that you are linking the letters of the moraine
  numbers that you also take care of setting the angle". A toe's, tip's, horn's, heel's, foot's or tail's moraine marks its
  outer edge (§4.2), so its letters and zoom stay where they were: Táin, of which he wrote "not sure what to do about Táin,
  because the full area is bigger than the moraine". Táin's own area waits for step 3, the banks' anatomy.
- **The checks.** Rebuilt in two passes, so his new names exist before their accepts apply. Every check holds.

He asked why moraines 41, 68 and 69 found no name (study script 08):
- **69** carries the skippers' Seyðisfjarðardýpi: 61 % of its 5,043 tows lie within 5 km, from 51 vessels, the most
  concentrated name on any moraine. It lies inside ÍSOR's trough 14 (Seyðisfjarðardjúp). Step 2 took only the ridge, edge,
  toe and tip endings, and left the -dýpi names to step 1's deeps.
- **68** (trough 14) carries Seyðisfjarðardýpi at 7 % and Glettinganesflak at 3 %.
- **41** (trough 8) carries Víkuráll at 2 %, and no chart or LMÍ name lies within 5 km.

## Step 2 closed: version 3 frozen and shipped, the same day

His word: "Yes, close step 2 first". Done by Claude, as step 1 was closed (decision 338):

- Step 2 was committed (ec824f7). The names, the proposals, the map's table and `names.parquet` were rebuilt from that
  commit, the tree dirty only with another session's notes and export script. Every check holds.
- **Version 3 frozen** into `curated/reference/place_names/v3/`: 11 files with their md5s, the names' eight and the
  proposals (081.2).
- **ogisdata 2026.11.20.1**: `files.R`, under a UTF-8 locale, took `names.parquet` (27,338 rows) under plan 078's rule.
  Installed, its 20 tests pass. Not committed in ogisdata (its tree holds the other session's 2026.11.19.4 and 2026.11.20),
  and not copied to the share, which is the maintainer's.
- **Version 4** begins (`VERSION <- 4L`), measured against version 3: all 27,338 rows the same.

## What is next

Plan 081 step 3, the banks' anatomy, the east coast first (§8 f). Many of step 2's names wait there, Táin's area among
them. The rest of step 2's proposals stay set aside, with no verdict. After it, step 3, the banks' anatomy (their edges, tips and horns,
where 85 of these names wait). TODO 206.
