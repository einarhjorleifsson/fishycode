# 332 — One table of what the map shows: the names of the charts, LMÍ and ÍSOR, the wrecks and the aids (plan 074 step 12)

*2026-11-19. At the maintainer's word: "one complete set that take the seachart mined data, the ISOR data and the LMÍ data
forward. Leaving behind for now the data from trackwell"; the wrecks "part of this build"; names, wrecks, lights and
beacons "in one single dartaframe, seperable by filter on a variable name"; plan 074's asks u-y his (2026-11-19); the
names' route his ("Freeze v1 as an input"). Built by Claude (AI), the wreck list's port by a subagent of Claude's and
checked by Claude; no person has checked the counts.*

## What was built

- **Version 1 frozen** in the named-features study (`scripts/133_freeze_names_v1.R`): the names map's results as the chain
  left them on 2026-11-17, 20 files with their md5s in `out/frozen/names_v1/`, every chain script older than its output.
  Fishycode reads them and never makes them, as `chart_names` reads the frozen chart reads (decision 323); a rule is ported
  when it next changes.
- **The sources staged**: `sources/is50v/name.R` (IS 50V's 200,674 names, every bearer), `sources/isor/seabed_name.R` (ÍSOR's
  five named layers, 2,825 records, keyed as the study's 131 keyed them: 2,825 of 2,825 agree).
- **The names list**, `reference/names/marine_name.R` to `curated/reference/marine_name{,_source,_record,_extent}.parquet`:
  25,879 features (the charts' 5,899, LMÍ's 19,958, ÍSOR's 22), each with one place, one angle and the zoom it deserves,
  each with its basis; every source record in one outcome (the charts' 8,203 labels, IS 50V's 200,674 names, ÍSOR's 2,825
  records). On version 1 it lays: the submerged rocks at LMÍ's position (decided 2026-11-17: 204 of 283 rock-or-shoal
  features joined to LMÍ moved, a median 460 m, 49 flagged `far_from_chart`; 8 joined to another bearer kept, flagged); the
  three misreads (ask v) from `overrides/marine_name_reading.csv`, each checked against the chart's window image ("Reykjane"
  is the 1:100 000's spaced REYKJANESGRUNN cut short, folded into feature 5420; Suðurgarður as printed; Faxagarður, read from
  the chart's list of the piers' names, its place the list's, flagged `legend_entry`); the two duplicates flagged
  (`overrides/marine_name_duplicate.csv`); the maintainer's edits (`overrides/marine_name_edits.csv`, the editor's record
  moved here, 131 rows: 105 moves or turns, 7 reverts; the zoom a stream of its own).
- **The wreck list**, ported as the aid list was: `sources/{isor,hi,emodnet,osm}/wreck.R`, `sources/ornefni/plotter_wreck.R`,
  `reference/wrecks/wreck.R` to `curated/reference/wreck{,_record,_pair,_description}.parquet`, `curate/checks/wreck_accounting.R`
  (38 checks); equal to the study's 91 value for value in every table (the id column named `wreck`, as the aids' `aid`).
  `R/curated_list.R` gains `cl_best_which()`; the aid list rebuilt with it into a scratch folder is unchanged (the subagent's check, not repeated).
- **The one table**, `reference/marine_feature.R` to `curated/reference/marine_feature.parquet` (27,305 rows: 25,879 names,
  801 aids, 625 wrecks; `id` "name:", "aid:", "wreck:"; `type`, `kind`; `rank` 1 a name, 2 an aid, 3 a wreck; an aid's name
  from zoom 10, a wreck's from 13; `holder` on names, `on_feature` on aids, 109 of 801, and wrecks, 258 of 625; `internal`
  on 122 wrecks) and `marine_feature_link.parquet` (453 links, one chosen a row).
- **The checks**: `curate/checks/marine_name_accounting.R` (16 checks; every difference from version 1 explained: 235
  features, 201 submerged rocks, 29 long names whose computed place is kept while version 1 drew them along their line, 2
  reading corrections, 1 folded piece, 2 edits made after version 1 was written), `curate/checks/marine_feature_accounting.R`
  (11 checks). All hold.
- **The page**, `products/marine_feature_map/` (port 8822): the study's 132 on ogis, reading the tables; the search over
  names, aids and wrecks; the edits appended to `overrides/marine_name_edits.csv`, laid on by `marine_name.R` alone (the
  server reruns it and `marine_feature.R` when the record is newer). Tested on a copy saving to a scratch file: the names,
  the routes, a selection from the search, a turn saved and shown.

## Chosen here (Claude's, each the maintainer's to correct)

- A submerged rock: the point class "rock or shoal" joined to LMÍ records whose bearers are all a rock's (boði, sker,
  skerjaklasi, rif, drangur, klettur, steinn, stapi, flös, flaga, hlein, grynning); LMÍ's position a point's, a line's
  middle, a polygon's point on its surface.
- A light that held names in version 1's hierarchy (made before the lights left the names) gives them to the next holder up
  (291 features).
- A wreck's `on_feature` the smallest LMÍ or ÍSOR area of a listed name that holds it; a wreck's name from zoom 13.
- The page's edits go to `overrides/` directly (his edits are the reviewed input); the long names drawn along their lines
  by the page, the table keeping the computed place.

## Left open

- The study's 75 (port 4836) is retired: its record is now `overrides/marine_name_edits.csv`.
- The other piers' names in the 1:10 000's list (Faxagarður's neighbours) were not read as names; only Faxagarður was.
- The wreck list keeps the study's digit precision (finest step, the coarser of latitude and longitude), the aid list the
  opposite (`cl_digits_min()`): the two lists differ there.
- `wreck_accounting.R` reads the study's `out/wrecks/hi_depth_unit.csv` when it exists: the study keeps it.
- `tz_point()` is parsed out of `sources/ornefni/plotter_mark.R` by both plotter readers; a home in `R/` would be cleaner.
