# 319 — Plan 074 step 1: the letter boxes read again and judged first, on a map of one chart scale at a time

*2026-11-12, at the maintainer's word as he read the maps: "fix Glettinganesgrunn's western half"; then "focus first and
foremost on getting the bbox of each örnefni at each 1:xxxx. If angular, we would also get the angle / the main axis. We
could then visually put those on the map, and I could make judgement on how good they are. The boundary of areas would
then come later"; "at each zoom see the boxes that were drawn on that zoom. otherwise this is confusing"; "select 1:xxx
and within that section we have the boxes and axis ... Now we just have too many controls to work on. I can then see the
same map at all zooms"; "Yes, link them"; "push rebelrebel". Built and written by Claude (AI); no person has checked the
counts or the boxes. Study: `$FISHYDATA/archive/2026-11-11-named-features/` (internal; its README section "The boxes
first, 2026-11-12").*

## The order changed

The outlines of decision 318 wait on the boxes they grow from: the maintainer judges each chart name's letter box at each
chart scale first, with its main axis and angle, and the outlines are redrawn from the boxes he accepts. Last night's
outline map (port 4820) stays as it was, drawn from the first form's boxes.

## Why Glettinganesgrunn lost its western half

At 1:300 000 the name is lettered in spaced capitals across two windows. The text recognizer read the eastern piece
"T I N G A N E S G R U N N" as "INGARNESGRUN,N", and the first form dropped it: a box counted only if its text was
nearer its own name than every other chart name in the country. The western piece "G L E T T I" kept a box read 60
degrees off, tall and tilted. The flood grew from that one box and its reach cut the bank.

## The boxes' second form (script 07)

Measured at every scale before any change: 34 of 626 readings had lost their box to that test (mostly pieces of labels
cut by a window's edge, and plain names misread), and many kept boxes were single letters. The rule, at every scale:

- a box is the union of a run of the recognizer's pieces (it splits spaced capitals into "G L", "LETTI"), on one line or
  on two for a two-line label, in either direction (it reads text at any quarter turn itself: a horizontal label comes
  back tall at -90 degrees);
- the run holds as many of the reading's letters as any run does, and no more than two beyond them; a word with a digit
  (a sounding, a light's "Fl 4s 30m 10M") counts for no letters;
- its text is nearer its own reading than any other label read in the same crop (the guard against a neighbour's
  letters, the Syðrahraun case, kept local);
- over a grid cell from the reader's mark it must read near-exactly (0.95);
- of the runs left, the tightest box: least area per letter.

564 of 626 readings have a box (563 in the first form; 24 lost, 25 gained). Glettinganesgrunn at 1:300 000 has both
pieces, its lettering 34 km long.

Tried in this form and dropped: a box within a cell of the reader's mark (the AI readers' cells are sometimes three
off: Leirinn and Færabakur were read exactly 200 px away); a box elongated for its letters (curved labels are fat at
every turn, and italic names run 0.38 of their height a letter); the most elongated of the near-best (it took the next
word on the line, "Djúpáll Fl"); one letter short allowed (it dropped the G of "G L E T T I"); half again the reading's
letters allowed ("Eyjafjarðaráll Flatey").

A slip on the way: test scripts that sourced 07's head without reusing the recognizer's output reran it, and one stopped
mid-run cut the output at job 523. The recognizer was rerun in full (all 626 jobs) before the counts above.

## The box map (script 17, port 4821)

- Three layers: each reading's box, each name's main axis at each scale (the longest line across its boxes, over the
  pieces of a cut label) with its bearing, and the readings with no box at the reader's grid cell.
- One choice above them, the chart scale, one at a time from 1:2 000 000 to 1:40 000, the same at every zoom, the view
  kept when it changes; each scale shows its own chart series alone beneath. The address sets it (`?scale_l=1:300 000`).
- Each box takes a verdict (on the letters, part of the lettering, not this name's letters, and a note), kept in the
  study's `notes/box_verdicts.csv` and read back by its row (`out/box_rows.csv`). None given yet.
- Tried first: one layer per scale and each series in a zoom band of its own; the maintainer found the controls too
  many and the zooms confusing.

## rebelrebel 2026.11.12

The chart following the choice needed two changes to rebelrebel (committed 96de711, pushed 2026-11-12 with the 11 local
commits before it):

- a choice's option may name a base map, `base`, shown while that value is the one chosen;
- mended: the page never switched between two base maps written as styles with no glyphs. It wrote `glyphs: undefined`
  into the new style, which fails MapLibre's validation, and MapLibre then keeps the old style without a word.

Still open there: a base map given as a tile address cannot come first (the page does not start), and a choice's extent
refits the view on every pick (the box map leaves the extents out).

## What is left

- The maintainer's verdicts on the boxes, scale by scale.
- The fat and tilted boxes he will see (Seyðisfjarðardjúp at 1:300 000, read whole only at a turned angle), and boxes of
  spaced capitals that take a sounding inside the label.
- Then the outlines redrawn from the accepted boxes (decision 318's rule), and the comparison of witnesses again.
