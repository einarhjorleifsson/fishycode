# 334 — Place names, version 2 built for review: the thing apart from its label, the renames, one thing from two sources

*2026-11-19. At the maintainer's word ("Yes, start v2"), plan 080 §5.2 under decision 333's answers. Built by Claude (AI);
no person has checked the counts. Version 2 is a candidate: frozen only after the maintainer's review on the page.*

## What was built

- **Version 1 frozen** by `reference/names/freeze_version.R` into `curated/reference/place_names/v1/`: the seven files as
  decision 332 wrote them (marine_name and its source, record and extent tables, marine_feature and its links, and
  `products/marine_feature/names.parquet`), byte for byte, with a manifest of md5s and build stamps. `write_curated()` gains
  `stamps =`, so a file carries `fd.version` (ask b).
- **The ledger** `overrides/marine_name_edits.csv` gains `new_name` and `why`, the header changed and the 131 rows left as
  they were; four `rename` rows entered: his names for ÍSOR's systems, synonyms in version 1 (Fagurhóll to Fagurhólar,
  Geirfuglasker to Fuglaskerin, Gullhóll to Gullhólar, Steinahóll to Steinahólar), `by` saying Claude entered them.
- **`reference/names/marine_name.R`**, version 2, laid on version 1:
  - the renames: the name used his, `name_source` the source's spelling, also among the synonyms, `name_basis`;
  - where the thing is (`lon`, `lat`, `place_basis`) apart from where its name is drawn (`label_lon`, `label_lat`,
    `label_basis`; `rotate_deg` and `z_rule` are the label's); 7,441 `point_kind` rows (a dot at the thing);
  - one name from two sources within 10 km, every pair in `marine_name_pair.parquet` in one outcome: 200 pairs, one thing 5
    (Grjóthryggur the charts' and ÍSOR's; Súgandafjörður, Hrútafjarðaráll, Hrómundarbót, Meðallandsfjörur the charts' and
    LMÍ's), whole and part 3 (Eldey, Eldeyjarboði and Dritvík inside ÍSOR's systems of their names), doubtful 15
    (Stóragrunn, Vestmannaeyjar, Nafir, Skjálfandadjúp and eleven of the charts' and LMÍ's), namesakes 177. A joined row
    is gone, its records, links and extent with the row kept.
- **`reference/marine_feature.R`** carries the new columns and `version`; an aid's link to a joined row goes to the row
  kept. 27,300 rows (names 25,874, aids 801, wrecks 625).
- **The checks**: `marine_name_accounting.R` 25 checks, every one holding, the 244 differences from version 1 each with a
  reason (235 of version 1's own, 5 rows joined, 4 renames); `marine_feature_accounting.R` 13, holding, two of them
  mended to test row by row (they had compared vectors of unequal lengths, recycled); the new `place_name_versions.R`:
  version 1's 27,305 rows in one outcome each (the same 27,255, changed 45: 41 a version 2 flag, 4 a rename; gone 5,
  joined), every change with its reason.
- **`products/marine_feature/names.R`**: `label_lon`, `label_lat` the label's, the thing's `lon`, `lat`, `point_kind`,
  `name_source`, `name_basis`, `version`; 27,300 rows, 2.3 MB.
- **The page** `products/marine_feature_map/`: the names at their labels; a point kind's dot at the thing from its name's
  zoom (a text layer of bullets: ogis's `og_point()` has no start zoom by row) and its name beside it; a Rename box (a
  `rename` row with the new name and why); the review layer, opening on Faxaflói and Reykjaneshryggur (ask j): 151 places
  (doubtful 30, whole and part 6, joined 5, renamed 4, possible duplicates 4, LMÍ's position far from the chart's 89,
  another bearer 8, known faults 5) and 23 lines between namesakes. Tried on the test page (`marine-feature-map-test`,
  its ledger a scratch copy): Díönuboði's dot on the shoal's top, its name to the right; a rename saved to the scratch
  ledger only and shown at once.
- **Where the thing is, by his hand** (added the same evening at the maintainer's question, "Can I not change the location of
  the Sökkubani - not the name but the pinpoint position on the mound"): the page shows the thing as a ring of its own when a
  name is chosen; Save the point writes a `pin` row (the point, and the rule's place as `comp_lon`, `comp_lat`), Point back an
  `unpin`. `marine_name.R` lays the latest on over every rule (`place_basis` his hand, `pinned_at`, the rule's place kept as
  `thing_lon_computed`, `thing_lat_computed`), a point kind's label following unless he moved the label; a pinned name gets a
  dot. Tried on the test page and built on a scratch copy against its ledger: Sökkubani's thing moved to the pin, its label
  where he had put it; `marine_name_accounting.R` checks every latest pin laid on (26 checks).
- **Another name added by his hand** (the same evening, "Yes, add Boðagrunn as a synonym"): the page's Add as a synonym writes
  a `synonym` row, the name used unchanged; `marine_name.R` adds each to the feature's synonyms, checked (27 checks). ÍSOR's
  Eldeyjarboði renamed Eldeyjarboðagrunn at his word, Boðagrunn its synonym, and Eldeyjarboði (the charts') pinned on the
  depth model's shallowest top in that area, 24 m (LMÍ's point 56 m deep, 6.4 km NNE). `place_name_versions.R` gives his
  moves, turns, zooms and pins since version 1 their reasons.
- **ÍSOR's area the primary source of a row joined with it** (the same evening, of Grjóthryggur: "We should have that area as
  the primary source in "our" version. And then the name would be along the polygon axis"): such a row's `src` is ÍSOR's,
  its extent ÍSOR's (Grjóthryggur 13.5 km, the charts' box 10.6), its label inside the area along its long axis on the map
  (Web Mercator, -65° for Grjóthryggur, his own turn of 2026-11-15 -63°) unless he moved it; his old turn placed back at his
  word. The page draws ÍSOR's areas as a layer (18) and LMÍ's as another, hidden (15,377), a click on an area choosing its
  name.
- **Two faults mended on the way.** An edit saved under the study's number of a feature and a later one under today's were two
  streams, so a later place back did not supersede an earlier move: each edit is now matched to its feature first and the
  feature's latest counts. Version 1 had kept Strandagrunn's move of 2026-11-15 18:08 though he placed it back at 21:05; version
  2 honours the place back, its reason in the names check. And a joined row listed its own name twice among its synonyms (the
  added names were not split): mended.
- **ÍSOR's area over LMÍ's** (the same evening: "I think the LMÍ area should be removed here. But that is probably a general
  rule when we have ISOR area and LMÍ area. And in general LMÍ areas are in my view highly suspect, although they should not
  be excluded as a rule"; kept at his word, "Keep it"): where a row has both, LMÍ's area is set aside, kept in
  marine_name_extent with `used` FALSE and why; an LMÍ area alone stays in use. 20 of LMÍ's set aside, not looked at one by
  one; checked (28 checks). The page shows it from its next start.
- **Records brought in by his word** (the same evening, of LMÍ's Gullhóll: "Yes, bring it in"): `overrides/marine_name_include.csv`
  lists records a rule of version 1's left out; each becomes a name, its id 2,100,000,000 plus LMÍ's own, its place the centre
  of the largest circle in its area (version 1's for LMÍ's areas), its extent the longer side of its box, its zoom and size the
  median of LMÍ's sea names of its extent within 25 %, its record's outcome "brought in by the maintainer". The first:
  Gullhóll, LMÍ's fishing ground (fiskimið), left out as a copy of Hafrannsóknastofnun's delivery of 2020 (V202005002), which
  cites Fiskifréttir 8 June 2017; 45 km², overlapping ÍSOR's Gullhólar by 3.8 km², placed at 63.1286 N 24.2658 W, from zoom
  8.1. The charts letter no Gullhóll at sea; ÍSOR's 7 craters and 36 fissures of the system carry its old name with a number.
  Checked (29 checks).
- **ÍSOR's craters and mounds brought into version 2** (plan 080 §5.2a, the maintainer the same evening: "Yes, as proposed"):
  `reference/seabed/seabed_feature.R` writes `curated/reference/seabed_feature.parquet`, version 3's table begun: ÍSOR's 740
  crater, guyot and other points and its 1,307 volcanic areas (675 ridges, 614 seamounts, 18 systems), ÍSOR's labels as
  placeholders, every attribute; a seamount's place its top on the depth model (524; 90 off the grid at a point inside);
  70 geometries repaired in metres, 51 of them refused by the maps' own path (DuckDB) though GEOS called them valid; checked
  by `curate/checks/seabed_feature_accounting.R` (5 checks). `marine_name.R` links names (`seabed_id`, `seabed_link`): ÍSOR's
  own 21 to their areas; 292 names of a mound's size (3 km at most) within reach of a crater or guyot, the sea's kinds moved
  there; 2 inside a seamount; 229 flagged doubtful (within 3 km, beyond reach) for review; his `link` and `unlink` rows (the
  ledger's new column `link_to`) by hand, his pins after. Checked (31 checks). The page: ÍSOR's craters (from zoom 7) and
  seamounts (hidden) as layers, Link to this mound and Unlink; tried on the test page (Gullhóll linked to Gullhóll crater 2,
  the row in the scratch ledger) and the build on a scratch copy took it.
- **Faults found on the way, mended**: `sources/isor/seabed_name.R` had dropped every attribute of ÍSOR's layers (sf's st_sf
  kept its first data frame alone; ÍSOR's `Name` now `isor_Name`, DuckDB's names ignoring case); a doubtful flag written for
  many rows at once recycled one text over all and wiped their flags (caught by the names check before it reached the page);
  ogis took a seamount's `lon`, `lat` for points and ignored its polygon.
- **ÍSOR's two studies and its guyots** (the same evening, the maintainer: "I am pretty sure that these come from different
  ISOR studies. Care to check"): ÍSOR's points cite the 2018 report (Hjartarson and Erlendsson, ISOR-2018/027) or the 2023
  mapping (Erlendsson, Blischke, Hjartarson et al., EGU23-15536); both label a crater by its system (2018 110, 2023 79) and by its
  ridge (242, 252), the label following where it lies (175 of 196 system-labelled inside their system, 439 of 494
  ridge-labelled outside every system), but every guyot (124) is the 2023 mapping's and labelled by its ridge, 34 inside a
  system (Steinahólar's six). At his word ("Show the guyots apart from the craters on the map"): the page draws ÍSOR's guyots
  as a layer of their own, its craters with a chooser by study. The 2023 abstract fetched at his word ("get The 2023 mapping")
  by `dump/isor/references.R` to `raw/external/isor/references/` (the page as served, its text, a manifest with sha256, CC BY
  4.0): a web page only, no PDF; it does not explain the labels or mention guyots.

## Chosen here (Claude's, each the maintainer's to correct)

- His 105 moves are taken as moves of labels, not of things (104 are the charts' sea names, one an island).
- The thing of a chart's areal name with an extent of LMÍ's is a point inside that extent (1,583 rows); of every other row
  version 1's computed place. Where version 1 kept no computed basis for a name moved by hand, `place_basis` says so.
- A point kind: the charts' rock or shoal and skerry or stack, LMÍ's records whose bearers are all a rock's (version 1's
  list, `ROCK`), ÍSOR's points. Islands are not, and LMÍ's skerries are (6,843 of the 7,441).
- The rule for two sources: a reach half the extent, 250 m at least, a point with no extent 0.5 km across; one thing where
  the places meet within the two reaches, the sizes within 2 times and of one broad kind (sea, isle, land); whole and part
  from 5 times, the smaller within the larger's extent or reach; namesakes beyond 3 times the reaches; doubtful between.
  Pairs within 10 km only. A row one thing with two rows of another source is doubtful, not joined.
- The row kept: the charts', else LMÍ's; the thing at ÍSOR's area where ÍSOR's is one of the two, at LMÍ's position for
  an island; the label the kept row's.

## Left open

- The maintainer's review on the page, Faxaflói and Reykjaneshryggur first; then version 2 frozen and shipped in ogisdata
  (plan 078's rule), measured against version 1 as above.
- ogis: `og_names()` draws no dot at a point kind (its areas layer takes polygons and lines), so ogisdata's maps show
  version 2's labels without the dots until ogis does.
- Not on the review layer: version 1's 106 near-spelling pairs (the study's list) and the long diagonal features whose box
  wants a corridor (no list of them was kept).
- ÍSOR's areas not edited (ask i, "None for now").
- The page's test configuration in `.claude/launch.json` now names this session's scratchpad for its ledger copy; the old
  path was an archived session's.
