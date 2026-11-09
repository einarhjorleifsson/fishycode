# 304 — Plan 070's boundaries by rule: neighbours split along the trough or the ridge (the levels rebuilt), the bays drawn in one pass, no-man's land with limits

*2026-11-08 to 09. At the maintainer's word: "the boundaries of the coastal bays, or for that matter fjords follow the
same logic/algorithm as the boundaries of offshore areas"; "The areas do not necessarily have to touch each other - you
can have a "no-mans" land"; "this should apply to all shapes, but with limits"; "do not revolutionize the approach
here"; "Yes, redraw them"; "I would use the shortest deepest "through" between them as a boundary. Similar logic could
be applied when creating boundaries between fjords, except there the shallowest route through them. The route should
follow the shortest deep / shallow distance through the feature"; "Yes, prototype it"; "Yes, apply it"; "Yes,
rebuild"; "Yes, rerun them". Coded, run and counted by Claude (AI); no person has checked the code, the areas or the
counts, and nothing here is adopted. The study: `$FISHYDATA/archive/2026-11-06-place-name-areas/` (its README, from "No-man's
land with limits"); the reruns in `../2026-11-08-old-chart-names/` and `../2026-11-08-ornefni-map/`.*

## Why

Plan 070's areas split two neighbours on the straight line halfway between their labels: "never a cell nearer another
bank's (deep's, bay's) label than its own" ran through the deeps, the banks, the gap filling and the bays. The
maintainer saw the lines (Vestrahraun and Syðrahraun; Meðallandsbugur's seaward edge across three grounds) and set the
rule instead: a boundary follows the seabed, the deepest short route between two rises, the shallowest between two
deeps or fjords. He added what the record of the areas is for: "rule-based decisions, albeit often quite complicated,
and then with exceptions. Ad-hoc decisions are what we observe in the sea-charts. E.g. deciding what features get
exposed at what zoom level. The boundaries system, with certain no-mans land recognizes that things are not binary but
the serve as our placeholder for at what zoom level a name gets "exposed" on a map."

## What was found and done

- **No-man's land, measured** (`35_voids.R`): a gap a level may leave is up to twice its gap width (10 km at 1:2M,
  7.7 at 1:1M, 4.9 at 1:300k, about 3 km finer). At every level together, the gaps wider than that hold a chart name (15
  of them) or a gazetteer name (15), mostly part-words that will take them up ("-kantur", "-horn", "-sund", "-tota",
  "-tunga"); 6 small ones on the outer shelf (596 km²) hold no name. The rule changes none of it.
- **The bays in one pass** (`37`-`39`): each sea cell's enclosure, the smallest window at which the land round it closes
  it in, and each name's water flooded through it as a tree: siblings by size, the joined water named by a label in it,
  no rank by a name's ending (the maintainer: "There is no logic really when it comes to -flói, -fjörður, -vík"), a
  town's label for a fjord the charts letter only as a town; open coves from their coast to the current charts'
  contour. It reproduces the maintainer's east coast (Norðfjarðarflói holds Norðfjörður, Hellisfjörður and Viðfjörður and
  is apart from Mjóifjörður; Seyðisfjörður and Loðmundarfjörður apart; Reyðarfjörður holds Eskifjörður; Sandvík and
  Vaðlavík apart). The broad bays still close on straight lines at their mouths; 24's bays are unchanged.
- **The rule** (`route_tools.R`): between two touching areas of one kind, the least-cost path between the ends of their
  shared edge, each step's cost its length times exp(-1.5 z) (z the depth's rank: deep cheap between rises, shallow
  between deeps), the two cut along it; water shared among several, by fronts from their edges (deep water slow for a
  rise, shallow for a deep or a cove). A route is not used where it would leave both areas' labels on one side or an
  area with under half its water (a first rebuild put Reykjarfjarðaráll's five labels in Húnaflóaáll and emptied
  Hornbanki). A watershed from the labels was tried and dropped (a label lettered on a flank, Sporðagrunn's, loses the
  shared top). Between Vestrahraun and Syðrahraun the trough is flat, 44-47 m, and today's line already lies in it; the
  route moves it 1-2 km onto its axis.
- **The levels rebuilt** (`23_level_fill.R`, `ROUTE=1`; `rebuild_levels.sh`): the chain's outputs of 2026-11-07 kept in
  `out/before_route/`; rerun first with `ROUTE=0`, the same to the cell; then with the rule: 19's, 20's and 32's areas
  unchanged; at 1:2M 48 of 49 areas changed, 3,388 km² changing hands (11 pairs re-split, 2 left), at 1:1M 494 km², at
  1:300k 8, none finer; no label leaves its area, no area changes by more than a quarter. The coves (39) share water by
  fronts too, changing little.
- **The reruns**: decision 302's figures, rerun on the rebuilt levels, are updated in it; the depth tree now bears out
  Rifsbanki under Þistilfjarðargrunn (they join at 120 m, with Kjölsenbanki alone). The örnefni map's 1,454 names barely
  change.

## Not done

The sibling fjords still stop before they meet (the water between no one's); the rule could split it on the shallowest
route. The broad bays' straight mouths. A name's zoom on the örnefni map from its area and place in the tree, not the
chart's print scale. The maintainer's review on the map.
