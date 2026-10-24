# 221 — The ornefni repo's data in raw: 206 files by source, the PDFs moved

*2026-10-24. The maintainer, on the sister repo `~/stasi/ornefni` (fishing-ground names, 2022-2023): "make sure we
have the data that is now in ornefni/ is in fishydata/raw", the PDFs to be moved where they hold names and
coordinates, and "at minimum stage these datasets" (plan 043). Not to bring the Trackwell names into the logbooks for
now. Copied, checked and written by Claude (AI), not checked by a person.*

## What was done

`$FISHYDATA/raw/external/ornefni/`, a folder per source: `trackwell/`, `fra_gudmundi-a-bjarna/` (plotter marks
and tracks sent by email in 2022), `sjokort/`, `lmi/`, `fiskmerki/` (tag recaptures' place text), `dictionary/`, `qgis/`,
`documents/`, `images/` and `data-md/`. 206 files, 0.5 GB, copied with `rsync --ignore-existing` and checked by md5
against the originals, all equal. `_manifest.csv` lists each file's original path, bytes and md5.
`README-provenance.txt` says what each file holds, with counts, where it came from and what was left out.

- **Moved:** the five PDFs. `~/stasi/ornefni/data-raw/doc` went to the macOS Trash and is now a symlink to
  `documents/`. Its only reader is the repo's `scripts/read_pdf-data.R`. Each PDF names places with positions:
  - the 2004 Skjálfandi report lists about 271 grounds with landmark bearings, 4 with coordinates;
  - ÍSOR's three 2008 reports propose undersea feature names, each with a map on a lat/lon graticule;
  - a 2016 map of the grounds off Vestmannaeyjar shows its names on the map only.
- **Copied, originals kept:** everything else, until plan 043's ask a settles it. The one-home rule (move, then a
  symlink) waits on that ask, because the dictionaries and `data-md/` are a person's working files: a symlink would
  have them edited under `$FISHYDATA`.
- **Not copied:**
  - the repo's derived copies (`*_fix.csv`, `*_leidrettur.gpx`), the byte-identical `older/` files, and three
    GeoPackages its scripts rebuild from the kept files;
  - the scripts, empty templates, a JSON test file, the QGIS project and rendered HTML.

## Found while copying

- **Nearly untracked:** almost nothing in `~/stasi/ornefni` is in git. That includes `data-md/`, 152 hand-written
  records of ground names, which existed only on this disk.
- **Trackwell:** the names are Trackwell's own record of its logbook app's hauls. In the 2022-11-07 file, 92 % of the
  rows match a curated logbook haul on vid and start minute.
  - The name never reached Oracle: the sent XML has no element for it.
  - The skippers' xlsx is Trackwell's summary of the same picklist, whose default "Ekkert valið" (nothing chosen) is
    absent from the per-haul file.
- **The plotter exports:** the three large GPX files have lost the Icelandic letters ("?"), and some are invalid
  XML. The TimeZero export of 2021 keeps the letters.

## What this does not do

Nothing is staged. Plan 043 is the design, with its asks (TODO 143).
