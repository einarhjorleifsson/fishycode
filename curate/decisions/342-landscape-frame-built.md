# 342 — Plan 081 step 3: the landscape frame built, the deeps, their lines, the ridges and the grounds over the whole shelf

*2026-11-20, at the maintainer's word ("Start the frame's build, plan 081 step 3", then "Yes, finish the frame"). Built,
checked and written by Claude (AI). No person has checked the counts or the code. Study:
`$FISHYDATA/archive/2026-11-20-proposal-banks/` (scripts 11-18).*

## What was built

- **`reference/seabed/landscape_frame.R`.** The coarsest level of the shelf's landscape (plan 081 §4.6), as adopted and
  tested in decision 341. No name enters a rule.
  - **The shelf** lies inside ÍSOR's shelf break, on 500 m cells of the Olex depth model, less Iceland. At his word ("You may
    have to add "Iceland" as a void here"), the mainland is the one void. An island is land only where the depth model says
    so: at 500 m the islands' outlines had closed inner Breiðafjörður's water into small patches.
  - **The deeps** are ÍSOR's 28 troughs. Each trough is split by its own shape, plan 081 step 1's rule.
  - **The deeps' lines.** Each arm, the parts on one branch, gets a line: from its deepest point up the arm to its head (the
    point nearest the mainland), on by the cheapest route to the mainland's coast, and seaward out of the shelf. That gives
    40 lines.
    - Trough 16's is not drawn, at his word on Norðfjarðardjúp's line ("Drop it", decision 341). It is the frame's one
      exception.
  - **The two ridges** are elements of their own. Each crest is traced through ÍSOR's craters (215 of 448 for the Reykjanes
    Ridge, 74 of 126 for the Kolbeinsey Ridge). Each area is the ridge's volcanic systems and a corridor of the craters'
    spacing. The crests split the shelf by plate.
  - **The grounds** are the rest, cut by the lines into pieces. A piece stands where a name belongs to it, in place of the
    study's floor (decision 341):
    - the charts letter a bank in it (-grunn or -banki, 1:300 000 or coarser);
    - or a skippers' name of two vessels or more has most of its tows there;
    - or one of LMÍ's named water areas lies mostly in it and covers most of it.

    A piece no name belongs to joins the neighbour it borders most, else the nearest ground on its own side of the crests.
    No ground lies on both sides.
  - It writes `curated/reference/landscape_{element,line,piece,cell}.parquet`: the elements as polygons with their basis and
    the charts' banks in them, the lines, every piece with its outcome and witness, and every cell with its element.
- **`curate/checks/landscape_frame_accounting.R`: 19 checks, all holding.**
  - The shelf counted again from its sources: every cell in exactly one element, each element's area its cells'.
  - Every deep inside its trough, and every trough a deep.
  - Every arm with its line (trough 16's left out), landing on the mainland's coast and running out of the shelf; each crest
    from the land out of the shelf.
  - Every piece in one outcome, every ground on the one piece a name belongs to, numbered once each, on one plate.
  - Every chart bank's lettering in one outcome, none in two grounds.
- **`R/trough_shape.R`.** Plan 081 step 1's `deepest_in()`, `trough_parts()` and its flood moved out of
  `place_name_proposal.R`, so the frame uses them without a copy.
  - `marine_name.R`'s own second copy of `deepest_in()` is gone.
  - The proposals and the names, rebuilt with them, are identical to before, table for table.
  - One guard is added: a trough with no branch at all, which the proposals never met, no longer stops `trough_parts()`.
- **The names page** (port 8822) has a section "The landscape frame", off by default: the deeps, grounds and ridges
  coloured by plate, the deeps' lines and the crests, and the grounds' numbers.

## What it gave

- **The cover:** 183,323 km² of sea on 733,293 cells. Deeps 46,531 km², grounds 134,712 km², ridges 2,080 km².
- **The grounds:** 32 in all, 12 on the west plate and 20 on the east.
- **The pieces:** of 360, 32 stand: by a chart bank 26, by a skippers' name 4, by an LMÍ area 2. The other 328 join.
- **The chart banks:** of the 116 letterings, 112 lie in a ground, 3 in a ridge and 1 off the shelf. No bank lies in two
  grounds.
- **For his review:**
  - Ground 6 stands by an LMÍ area: the charts' small Berufjörður in Reykhólasveit, by Reykhólar, 6 km². It is a namesake
    of the east coast's, closed off where a deep's line reaches the coast. Its case is the inshore boundary's.
  - Öxarfjörður stands the same way, 720 km².

## Tried on the way, the same night

His remark: "I think we are trying solve this: [the Mandelbrot set]", "the difference is that it is no regular - but this is
a known issue. care to check the web". The web gives:
- Mandelbrot's statistical self-similarity (1967);
- river networks as the solved case (Horton, Strahler, Tokunaga);
- Pfafstetter's recursive coding of basins and interbasins;
- prominence and the merge tree.

Tested at his word ("Yes, test it"), study scripts 18a-c.
- **The method:** flow routed seaward over the shelf by a priority-flood fill, every cell ranked by Strahler's order.
- **The top level, partly:** the highest orders run in the troughs (order 8 99 % inside them, order 7 80 %).
- **The next level, no:** banks on one platform cross channels of order 5-6 as often as banks with a trough between them.
- **Claude's reading:** on a gentle shelf, flow gathers by area whether or not there is a valley. The self-similar rule
  should rank, not cut at a size, as his point has it, but rank by relief, not by area. The frame's deeps are ÍSOR's troughs,
  relief at the coarsest grain. So it stands as built.

## What is next

- His review of the frame coast by coast on the names page, the coasts the ridge and the hotspot left alone first.
- Then the grounds as proposals, in place of step 3's 21 east pieces.
- Then the banks' anatomy inside them (plan 081 §4.1): the frame's rule again where a trough lies between two banks, what
  each is named for where they share a platform.
- Still open: the inshore boundary, and the depth rule where there is no trough.
