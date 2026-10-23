# 212 — The metier is Iceland's own, carried on the fixes; ICES's codes are mapped from it when a datacall is answered; the regulation's mesh first

*2026-10-23. The maintainer's answers to plan 015 §4 a's asks (TODO 131 and 132), put by Claude (AI) in a status
review of the repository. The record is Claude's and has not been checked by a person. Nothing is built. TODO 132 is
folded into TODO 131.*

## Answered

- **ICES's codes are a mapping at delivery, not the product.** The maintainer: "once we get to answering ICES
  datacalls we map the 'icelandic' metier system to the icesVocab." So the flow carries an Icelandic metier per fishing
  operation: gear, target, mesh, rigging and selection devices, as practised and recorded, each with its basis. A
  datacall maps it to icesVocab's codes in `products/`, when that datacall is answered (TODO 27b). Three things move
  from the metier rule to that mapping:
  - **What is delivered where Icelandic practice has no code** allowed in its area, and whether to ask ICES for codes
    (ask a4's second half, TODO 132). The practices are twin and triple rigs, the Nephrops trawl's panels, sea cucumber
    and sea urchin dredges, seaweed harvesting and diving.
  - **Which list decides** (ask a4's first half): the vocabulary's live area links (`icesVocab::getCodeDetail()`) or
    rdbes's copy of 2025-10-23. The maintainer holds it ("needs further thought"), and it is decided with the mapping.
  - **The proposed rule's first and last steps.** RDBES's code for an operation becomes a witness the Icelandic metier
    is checked against. The narrowest allowed range in the fix's ICES area becomes the mapping's step.

  Ask a3 follows. Twin trawls (`tvo_veidarf`), triple rigs, grids and panels are kept in the Icelandic metier as
  recorded (plan 020's `gear_part`), and their ICES codes are the mapping's.
- **a1. The regulation's mesh comes first** for the gears whose regulation fixes the class: bottom trawl, Nephrops
  trawl, shrimp trawl and Danish seine. The recorded mesh is a witness. Where the two disagree, the operation is listed
  and keeps the regulation's class. Today's read puts that at 18.6 % of Nephrops fixes (100 mm or more), 0.17 % of
  bottom trawl and 0.09 % of seine. Where the regulation leaves the class open (nets, pelagic trawl, purse seine), the
  recorded mesh decides. The legal values are to come from the regulations themselves (TODO 133, ask a5), so that the
  `regulation` basis can cite them. Today they are constants in a study script.

## Held

- **a2. The target where the gear code does not give it.** The maintainer: "this may need some further thought." In
  Icelandic terms the question is narrower than in ICES's. The new gear codes (`reference/gear/mapping.R`) name the
  target of the nets (monkfish, cod, lumpfish, Greenland halibut) and of the Nephrops and shrimp trawls. Three gears
  name none: Plógur (15, every dredge), Flotvarpa (9, pelagic trawl) and Gildra (16, traps). For those three the
  target is in the catch, or nowhere.
- **a4's list**, as above.

## What changes

- TODO 131 becomes the Icelandic metier per fishing operation. The rule of plan 015 §4 a revised is redrawn in those
  terms: gear and target from `gid_used`, the mesh with its basis (a1), rigging and devices as recorded. Open: a2.
- TODO 132 is folded into TODO 131: its practices are part of the Icelandic metier, and its question goes to the
  mapping.
- TODO 27b holds the mapping to icesVocab, with a4's list, beside plan 015 §4 b-d and i.
- TODO 133 (the dated regulation table) stands. a1 makes it the source of the `regulation` basis.
