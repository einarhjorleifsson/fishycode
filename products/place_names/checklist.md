# The place-name explorer: every control and click path

Plan 045 step 1, its first, read-only part. Each change to the page is tested against this list, one item at a time,
before the next change begins. An item a change removes on purpose is struck out here in the same commit.

How to test:
- a click is preceded by a hover, as a person's is;
- the browser pane must be visible for anything the map draws (a hidden pane draws no frame);
- the service first: `Rscript products/place_names/check.R`.

All items passed on 2026-11-01 (the first version), at 1400 × 850 and at 375 px.

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
- **D3** The map: its footprint filled, outlined; its parent's dashed; its children's thin; its places numbered (two or
  more); its occurrences coloured by source, a flagged position or Trackwell's picklist summary left off the map.
- **D4** Occurrences: a chip per source with its count, bars by year, and the first 200 rows.
- **D5** A source chip hides that source's occurrences on the map, in the table and in the bars; a second click shows
  them; the panel keeps its scroll. A newly chosen name starts with every source on.
- **D6** An occurrence row: the map flies to it and opens its popup. A place row: the map flies to the place.
- **D7** An occurrence point on the map: a popup with source and table, position kind and basis, time, vid, gear,
  square, LMÍ feature, ÍSOR group, uv area.

## The map's controls

- **M1** Footprints off hides every listed footprint (the chosen name's stays); on brings them back.
- **M2** Base map: the six of ramb's `rb_map_basemaps()`; every layer, the labels and the footprints' on/off are kept
  through a change.
- **M3** Zoom buttons, scale bar, pan and zoom; the address's `map=` follows.

## Layout

- **W1** Above 1000 px: list | map | detail, each scrolling on its own.
- **W2** At 375 px: map, then detail, then the list; no side scroll.

## Not in this version

- the filters in the address (only the name and the map's position are);
- answers of any kind: plan 045's review page writes to `overrides/`, and its questions are open.
