# The place-name explorer: every control and click path

Plan 045 step 1, its first, read-only part. Each change to the page is tested against this list, one item at a time,
before the next change begins. An item a change removes on purpose is struck out here in the same commit.

How to test:
- a click is preceded by a hover, as a person's is;
- the browser pane must be visible for anything the map draws (a hidden pane draws no frame);
- the service first: `Rscript products/place_names/check.R`.

All items passed on 2026-11-01 (the first version), at 1400 × 850 and at 375 px; M4, M5 and M6 added and passed the
same day (M6 at 1024 px and 375 px); G6 and M7 added and passed on 2026-11-02, at 1024 px and 375 px.

## Load

- **L1** `/` lists all 9,281 names, ordered by positions, 300 at a time; the status line says "9,281 names".
- **L2** The list shows before the map's tiles: the map's layers come when its style has loaded.
- **L3** Each filter lists its values with their counts over every name, the commonest first (level in order).
- **L4** The map opens at lon -19, lat 65, zoom 5, with every footprint faint and the labels from their minimum zoom.
- **L5** A service of another version than the page's (`API_VERSION`) puts a red banner on top.

## Search

- **Q1** Typing narrows the list to the names whose key, or a spelling's key, holds the typed key (accents, case,
  spaces, hyphens and doubled letters ignored: "litli banki" finds Litli banki, Littli banki, Litlibanki).
- **Q2** The exact key first, then those that begin with it, then the rest.
- **Q3** Enter chooses the first in the list.
- **Q4** Clearing the box (✕) brings the whole list back, the filters still applied.

## Filters (each narrows the list and the map's labels and footprints together)

- **F1** Class, terrain, gear, cross-check and level: one value or all; a name with none is `none`.
- **F2** Source chips: a name used by any chosen source; a second click takes a chip off.
- **F3** Filters combine (composite and OTB: 62, as the data say).
- **F4** "clear filters" appears with any filter set and sets every one back to all.
- **F5** A list of 500 names or fewer is drawn at every zoom, each label with a dot.
- **F6** "300 more" at the foot of the list adds the next 300.

## Choosing a name (from the list, a label, a footprint, a link or the address)

- **C1** A list item: it is marked, the detail panel fills, the map fits the footprint and places, and the occurrences
  load ("<name>: N occurrences").
- **C2** A label on the map: chooses the name, the map stays where it is.
- **C3** A click in footprints with no label or point under it: the smallest footprint's name.
- **C4** Parent, child and synonym links in the panel choose that name; a synonym with no key of its own is text.
- **C5** The address carries `#key=` beside MapLibre's `map=`; a reload, or `#key=` pasted into the tab, opens that
  name.
- **C6** Choosing scrolls the list to the name, never the page (the narrow layout).

## The chosen name

- **D1** The panel: name, key, class, terrain, cross-check, level; positions, sources with counts, years, vessels,
  spread, footprint size, depth and slope, gear and its share, the families, the zoom it shows from, region, LMÍ.
- **D2** Parent (with its basis) and children; spellings with counts, sources, rule, repair and reading; candidate
  synonyms with relation, letters and km; places (two or more) with positions, share, support and families.
- **D3** The map: its footprint outlined dark on a white casing (seen on every base); its parent's dashed; its
  children's thin; its places numbered (two or more); its occurrences coloured by source (ColorBrewer's Paired, a pair
  per family, the commoner light), the rarer sources drawn on top; a flagged position or Trackwell's picklist summary
  left off the map.
- **D4** Occurrences: a chip per source with its count, bars by year stacked by source in the sources' colours, and the
  first 200 rows. The class, terrain, cross-check and level badges carry their footprint colour.
- **D5** A source chip hides that source's occurrences on the map, in the table and in the bars; a second click shows
  them; the panel keeps its scroll. A newly chosen name starts with every source on.
- **D6** An occurrence row: the map flies to it and opens its popup. A place row: the map flies to the place.
- **D7** An occurrence point on the map: a popup with source and table, position kind and basis, time, vid, gear,
  square, LMÍ feature, ÍSOR group, uv area.

## One place, one name (where `curated/place_name/name_group.parquet` is built; tested 2026-11-01 on a scratch copy)

- **G1** A key of a group of two or more: "One place, one name (proposed)", the single name as a link, and each key of
  the group with its positions, how it joined (most positions, same core, a locator dropped, the hand reading), the
  words dropped and its distance from the head; its own row in bold.
- **G2** On the map, the other keys' footprints dotted in purple, over the chosen name's own.
- **G3** A key's link in the group's table opens it, with the same group.
- **G4** In the list, "≈ <single name>" where a key's group is named otherwise, "one of N keys" where it names its group.
- **G5** Without the table (the store before the build), no group anywhere and no error; the "one name per place"
  switch hidden, every key its own label (retested 2026-11-02 on a scratch copy without the table: 9,554 labels).
- **G6** "one name per place" on the map (maintainer, 2026-11-02: use the proposed name on the map rather than the
  versions, as a switch), on by default: the listed keys of a group are one label, the proposed name, at that name's
  own key (else the listed key with most positions), from the earliest zoom of any of them, coloured by that key's
  values; its other places only. `#key=utanholfbreidafirdi&map=7.02/64.626/-27.835`: one "Utan við Hólf" from zoom 6
  where there were 14 versions (9,021 labels, 9,554 off). The label is enlarged when any key of its group is chosen,
  even one a search has left out of the list; a click on it chooses the key it stands at. Off brings every key's own
  label back; the state is kept through a change of base map.

## The map's controls

- **M1** Footprints off hides every listed footprint (the chosen name's stays); on brings them back.
- **M2** Base map: the six of ramb's `rb_map_basemaps()` and LMÍ's sea charts (M6); every layer, the labels and the
  footprints' on/off are kept through a change.
- **M4** The names are legible on every base (maintainer, 2026-11-01: the broad white halo made them hard to read):
  upright semi-bold, dark ink with a narrow soft halo on the light bases (light, voyager, ocean, none), light ink with a
  dark halo on dark and satellite; the chosen name's halo wider; the base map's own sea names hidden, on every base
  and after a change.
- **M3** Zoom buttons, scale bar, pan and zoom; the address's `map=` follows.
- **M5** "coloured by" (maintainer, 2026-11-01: the map too bland, use ColorBrewer's colours; and it is solely for
  looking at the names, for QC now): the names themselves and their footprints, by cross-check (the default: RdYlGn's
  ends, several places in PuOr's orange), terrain (Dark2, a hazard in Set1's red), level (YlGnBu, the footprints only)
  or one colour. A name's ink is the dark end of its colour on a light base and the light counterpart (RdYlGn's light
  end, Set2) on a dark one; a grey value (one family, no terrain word) leaves it in plain ink, and its footprint
  fainter. The chosen name is 4 px larger. The legend below follows the scheme; a click on a value filters the list to
  it and sets the sidebar's filter, a second click takes it off, and a sidebar filter lights its value in the legend.
  The colours are kept through a change of base map.

- **M6** "Sea charts (LMÍ)" (maintainer, 2026-11-01: the sea charts LMÍ serves as an optional background), before
  "None": Sjómælingar Íslands' charts from `gis.natt.is`, the smallest scale below and each from about its own scale
  (`api.R`, `SEA_CHART`): 1:2,000,000 at the opening view, 1:300,000 at zoom 8.5 off Reykjanes, 1:100,000 at 10.2 and
  1:35,000-50,000 at 11.6 off Reykjavík, its harbour at 1:10,000 at 13.6; a chart three zooms past its scale is not
  asked (four layers at 13.6, not nine). The names in dark ink on a white halo; the attribution says "not for
  navigation". Outside a harbour chart's frame the cache answers 404, and now and then 500 at a chart's edge: in the
  console only, nothing on the page.

- **M7** "heat map" (maintainer, 2026-11-02: a heat map as an option), off by default: the chosen name's occurrences
  as a heat map in ColorBrewer's YlOrRd, with a "few … most" key beside the switch, in place of the points. Its darkest
  is the most occurrences in one cell of the kernel's radius at the zoom it is seen at, over all the name's drawn
  occurrences: Halinn (30,639 drawn) 601 at zoom 8.1, 43 at 10.3, its core dark red and its spread yellow; a name of a
  few points is a blob each. A source chip rescales it (Halinn without Trackwell: 335, 19). Kept through a change of
  base map; off brings the points back. An occurrence row still flies to it and opens its popup.

## Layout

- **W1** Above 1200 px: list | map | detail, each scrolling on its own.
- **W2** At 375 px: map, then detail, then the list; no side scroll.

## Not in this version

- the filters in the address (only the name and the map's position are);
- answers of any kind: plan 045's review page writes to `overrides/`, and its questions are open.
