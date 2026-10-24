# 222 — The place names staged: thirteen source-shaped tables from the ornefni data, every row accounted for

*2026-10-24. The maintainer: "finish the staging" (plan 043). Built, checked and written by Claude (AI), not checked by
a person.*

## What was built

`sources/ornefni/`, twelve scripts on the preprocessing side, write `staging/ornefni/`. They are wired into
`_targets.R` (`ornefni_raw`, `ornefni_*`) and were built by name, so `tar_outdated()` is empty again.

| Table | Rows | From |
|---|---|---|
| `trackwell_haul` | 484,734 | Trackwell's per-haul names (2022-11-07) |
| `trackwell_area` | 1,096 | Trackwell's picklist summary |
| `plotter_mark` | 519,589 | the plotter's GPX waypoints and TimeZero objects |
| `plotter_track` | 1,866,505 | the plotter's GPX track points |
| `chart_name` | 272 | sjókort lines |
| `lmi_name` | 5,821 | LMÍ's polygons (2022) |
| `recapture_place` | 20,317 | the tag recaptures' place text |
| `recapture_reading` | 40,573 | the hand readings of those texts |
| `name_dictionary`, `tag_word` | 9,285; 2,439 | the hand-made name lists |
| `fiskislod`, `drawn_area` | 566; 1 | the recapture hulls, the hand-drawn polygon |
| `article_record` | 151 | the data-md records |
| `document_name` | 394 | Skjálfandi's table (271) and ÍSOR's entries (123) |

- **The common columns:** each table carries the name as written beside a trimmed copy, `source`, and a position with
  `position_basis` (AGENTS.md's vocabulary) and `position_kind` (point, line, polygon, track, drawn or text). Lines
  and polygons are WKB, written by `write_parquet_sf()` (`R/write_parquet.R`, new) so that `read_curated_sf()` reads
  them back.
- **The plotter:** its GPX files are read as text by `read_gpx_marks()` and `read_gpx_tracks()` (`R/gpx.R`, new),
  since some are not valid XML.
- **Not staged, as plan 043 says:**
  - the 2022-11-03 Trackwell file: 484,289 of its 484,306 named rows are in the 11-07 file, and its 848 rows with no
    name are counted in the script;
  - the machine copies of the hand-made workbooks;
  - `older/vesturhluti 2.gpx`: all 30,773 of its points are in the 2022 export;
  - the Vestmannaeyjar map and the images.

## Plan 043's asks, as taken

The maintainer said "finish the staging", so each of these follows the plan's recommendation:
- **b:** the plotter's tracks are staged.
- **c:** the names that lost their letters are staged as they are and flagged (`text_lost`). The TimeZero export's
  geometry is decoded so its 446 named marks, the ones that keep their letters, have positions.
- **d:** the maps are not digitised.
- **e:** the side is preprocessing, in the main project.
- **g:** the folder is `staging/ornefni/`.
- **h:** answered "proceed to curation", which is plan 044.

Still open: a (the originals in `~/stasi/ornefni`) and f (dumping `fiskar.ornefni` and `fiskmerki.endurheimtur`).

## Found while staging

- **Trackwell's vessel field:**
  - it holds a vid (179 vessels), a Faroese or Danish call sign (OY.., OW..: 6,077 hauls), or a colour (Red,
    Orange, White, Yellow: 186 hauls, around and south of the Faroes; what they are is not known);
  - 29 hauls carry an impossible year (2000, 2095, 2099), not 37 as decision 221's first count said.
- **TimeZero's geometry** (the maintainer asked why decode it: it is the only copy of those names with their letters,
  and it holds positions only in this field):
  - a mark is one type byte, then x and y as big-endian 32-bit integers in centimetres of World Mercator (EPSG:3395);
  - this matches the GPX copies of 191 marks within 0.58 m, and its times are seconds since 2000-01-01;
  - 5 named marks start with 00 and decode the same way, plausibly (Gígurinn falls on Trackwell's tows of that name);
  - 12 objects stay undecoded: 7 of type 3 and 5 lines or areas. The original field is kept on every row.
- **The plotter's marks** are mostly not names:
  - 446,969 are numbers, 778 symbols ("!!") and 67,972 unnamed;
  - 49,348 carry the plotter's placeholder date 1984-12-31, and 8,284 are dated after the delivery (to 2033);
  - both exports of `vesturhluti 2.gpx` are cut off before their end (no `</gpx>`), so the last track is kept as far
    as it goes.
- **LMÍ's layer** names Trackwell as the source (`heimild` V202005003, Trackwell) of 124 of its 1,775 sea polygons, so
  Trackwell's picklist reached Iceland's official map layer.
- **Skjálfandi's table:** each word is placed in its column by the empty vertical strips on its page, since the cells
  start left of their headers. Its ditto marks ("II") are kept, with filled-down copies beside them.
