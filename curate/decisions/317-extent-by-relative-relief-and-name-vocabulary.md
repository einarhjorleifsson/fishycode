# 317 — A named feature's extent by relative relief, for highs, lows and slopes; the names' endings as parts and by region; the Olex grid's merge marks

*2026-11-11, evening. Plan 073, the maintainer's word as the work went: "Your current ground truth is the sea-chart
labelling of placenames and the olex model"; "wander if we do not even need a broader "scale". and a simple radius may not
be the best here, we possible need to think about ellipsoid ... with angles"; "think of Vestrahraun and Syðrahraun in
Faxaflói"; "the seabed lows should be just as much of a focus as the seabed highs"; "the in-betweens, like
Hvalbakshalli. Suðurkantur"; "the ban i put on trying anything along the coastal areas is now lifted"; "There is a problem
in olex - some of the ruggedness comes from merging different datasources of different quality"; and on the names'
endings, given below. Built, scored and written by Claude (AI); no person has checked the counts. Study:
`$FISHYDATA/archive/2026-11-11-local-features/`, scripts 56-67 (internal). Nothing here is applied to the örnefni map yet.*

## The extent by relative relief

A feature's surface, minus its mean within a neighbourhood (sea cells only), and the cells above zero, above half the top,
above the area's elbow, or up to the first saddle into a neighbour rising a quarter of the top (split), joined to the top
nearest the name. Five surfaces: depth (a high), depth turned over (a low), slope (steep), slope turned over (flat), and
small-scale ruggedness. Neighbourhoods: circles of 1-32 km and ellipses 2.5 times as long as wide, across or along the
feature (the label's angle where it is turned, else the outline's own axis). Judged only by the chart: an areal name's
label inside its outline, no label of another name of its kind and scale inside, no label of the other kind (a low in a
high, a high in a low) inside; the rings, the label's size, and the maintainer's reviewed mound beside them. 431 chart
names: 343 highs, 71 lows (deeps, channels, trenches), 17 slopes (the chart's slope class: halli, kantur, brún).

- **Broad neighbourhoods win, for every kind and chart scale.** At 1-2 km fewer than one areal label in ten falls inside
  its outline; a neighbourhood matched to the chart's scale did worst (0.21). Even 1:100 000 names do better at 16-32 km.
- **Each kind is caught best on its own surface** (the coast allowed, as below):

  | Kind | Surface, neighbourhood, rule | Label in | Siblings out | Other kind out | Drawn |
  |---|---|---|---|---|---|
  | high | depth, circle of 32 km, split | 0.93 | 0.91 | 1.00 | 64 of 339 |
  | low | depth turned over, 32 km, split | 0.90 | 0.95 | 1.00 | 21 of 68 |
  | slope | slope, ellipse of 16 km across the band, elbow | 0.86 | 1.00 | 0.86 | 7 of 17 |

  Flatness is a strong second for highs (many banks are flat-topped). Ruggedness beats depth neither for the highs nor for
  the 13 -hraun names; too few to settle, and see the merge marks below.
- **On the maintainer's reviewed mound** (Eldeyjarboðagrunn, 42 km²) the split at 8 km overlaps it by 0.86, half or split
  at 16 km by 0.83-0.84: near his own rule (0.93, decision 316) and above the halfway level (0.69).
- **The label's size hardly follows the outline's** for any method (a rank correlation of 0.25 at most).
- **Coverage is the weakness, and it is the split rule's.** On the coarse grid of a 32 km neighbourhood it often stops at
  the first small bump beside the top, under 4 cells: 274 of 339 highs get no outline. The half rule draws more, but at
  32 km two in three highs run off the window. Next: split only where the outline would join a neighbour at least as
  large as itself.
- **Vestrahraun and Syðrahraun** (inner Faxaflói, the charts' 1:1 000 000 names, 673 and 440 km² in the örnefni map's
  broad model) stand above their surroundings as two patches at 8-16 km, with the chart's channels (Rennur, Mið-renna,
  Syðsta-renna) in the low between them; the broad model parts them by a straight line that cuts the Vestrahraun patch.
  The split at 16 km gives 246 and 208 km², each label inside and the other outside.
- **The coast.** The maintainer lifted his ban of decision 316 (no outline at the coast). Scored again with outlines
  that reach land (they stop at the coast: they are sea cells), more names are drawn (the half rule at 16 km: 154 highs
  against 75) and the ranking holds.

## The regional contrast and the forces behind it

The maintainer: the spreading ridges (Reykjaneshryggur, Kolbeinseyjarhryggur) are volcanic and rugged, the contrast
falling outward; the fjords and deeps away from them were carved by ice; regions such as Selvogsbanki were flushed with
glacial-river sediment and have less relief. EMODnet's sea-floor geology for Iceland (ÍSOR's, already in `vernd_i_hafi`)
maps the units: troughs, drumlins, meltwater channels, moraines, volcanic systems, landslides, the shelf break, igneous
rock against sediment. Over measured cells, the ruggedness falls with distance from its oceanic ridge zones (off the
shelf, median 0.82 m within 25 km to 0.37 m beyond 100 km; on the shelf 0.50 to 0.35 m). The relief over 16 km is
dominated by the shelf edge and is not the contrast meant.

## The Olex grid's merge marks

The anisotropy of the 50 m grid's second differences maps its sources: blocks with straight edges, each with its own
texture (survey rectangles on the shelf, smooth blocks in the north-east, striped tracts in the south-western deep). The
ruggedness at 150 m carries vessel tracks and the blocks' edges; inner Faxaflói has a striped block on the two hraun. The
ratio of fine to coarse roughness is speckle at 200 m; the ruggedness of the smoothest direction leaves tracks and blocks
as they were (tracks run at every angle). So small-scale ruggedness from this grid is not used until its sources are told
apart: by segmenting the anisotropy blocks, or by their footprints from the grid's maker (a question the grid's
provenance note already lists for Julian Burgos). The relief surfaces, on cells of 200-1,600 m, are far less touched.

## The names: an ending names a part, and the endings are regional

The maintainer: "-grunn, -flak, -tota, -xxx, .... are endings that refer to different part of a shallow area (relative to
a deep area)"; "... -hali"; "you may then have a different system of -endings in the north-western system, local lingos";
"-röst is normally associated with hydrographic conditions - strong currents (tidal or otherwise)"; "fishermen name
anything that is rugged hraun"; and his glossary: horn a corner (elbow), kantur and brún an edge (slope), nef a nose
(protrusion), haus "the head of something, i would assume the end of something, may be wrong here", flak "not really
sure, but most like the end of something", oddi a point, hali a tail, tota "as in tongue, tail". **Amended the same
evening** with his words on the lows: kriki a corner (of a depth), pollur a pool (local), hola and gat a hole, dalur a
valley, botn "the deepest part", gjá "like a narrrow steep channel", gil "a canyon (on a small scale)", garður a fence,
slóð "like a track", flói "normally a wide area, not a fjord", sund "something between two landmarks", whose first part
names "area at the end of the journey" (Grímseyjarsund, from the mainland to Grímsey; Grænlandssund; Viðeyjarsund), so a
-sund lies between the mainland and the place its first part names; krókur a hook or
corner, eyri "normally a land based feature, some thing that protrudes from something", djúp a large deep fjord
(Ísafjarðardjúp) or a subsurface "fjord", "not really a steep thing, just a deep thing relative to the adjacent
grunnur", áll "normally something narrow, but Kolluáll is certainly not". Kept in the study's
`notes/part_endings_glossary.md`.

- **The charts carry the whole, the other sources the parts.** Families on the charts (one root, two or more endings) are
  mostly a headland's sker, vík, fjörður and boði; the parts of a bank (flak, tota, öxl, horn, nef, hali) sit in LMÍ,
  fiskmerki, the Oracle tables, the channel and the plotter, and trial 2 labelled many of them out as a chart name's
  derivatives. For this step they come back as parts of a known whole, not as positions.
- **The vocabulary differs by region** (eight sectors, no Trackwell): north-west oddi, tota, hali, botn, áll; east fles,
  kambur, flak, halli; west (Breiðafjörður) brot, straumur, flaga; south-west grandi, klakkur, hraun; south gjá, djúp;
  south-east garður, ós, dýpi. An ending's meaning in the landscape is to be found region by region.
- **Where each ending's names lie** (relative elevation within 8 km, slope): the endings of the lows (djúp, dýpi, áll,
  renna, pollur, hola, dalur, botn) lie below their surroundings more often than not, -grunn and most part endings
  above; positions are noisy and the split is weak. -röst and -straumur are hydrographic: placed by the water, the depth
  only a proxy.

## What follows

The wholes by their own kind's surface at a broad scale, once the split rule is fixed; then the parts on each whole's
outline by ending (a corner, a lobe, a tip, a tail, an edge), region by region; the hydrographic names apart. This is
the substance of plan 074, proposed and not drafted (TODO 199). Nothing is on the örnefni map yet.
