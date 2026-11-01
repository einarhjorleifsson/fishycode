# The place-name explorer

A read-only page for the gazetteer of plan 044 (`$FISHYDATA/curated/place_name/`): find a name, see its footprint,
places and occurrences on the map by source, its spellings, candidate synonyms, parent and children, and filter the
names by source, class, terrain, gear, cross-check and level. The first step towards plan 045's review page (§3.1),
without its answers: it writes nothing, to `overrides/` or anywhere else.

Built 2026-11-01 by Claude (AI), at the maintainer's request; a person has not yet used it.

**Internal use only.** The names from Trackwell's hauls and fishermen's plotters are not public: the service listens on
127.0.0.1 and the page is never published (plan 045 §5).

## Start it

From an R session at the fishycode root (an RStudio project opens there):

```r
source("products/place_names/place_names.R")
place_names()                    # every name
place_names("Litli banki")       # opens on a name: any spelling, matched by the gazetteer's key
place_names_stop()
```

It answers while the console is idle. From a terminal, until the process is stopped:

```sh
Rscript products/place_names/server.R    # http://127.0.0.1:8797, or PLACE_NAMES_PORT
```

The service reads the tables once at start (about 4 s). After a rebuild of the gazetteer, restart it.

## Files

| File | Holds |
|---|---|
| `api.R` | The service: its endpoints, the column allowlist (`ALLOW`) and the columns kept back (`NOT_SERVED`). |
| `place_names.R` | `place_names()`, `place_names_stop()`: the service in the background of an R session. |
| `server.R` | The service from a terminal. |
| `check.R` | Tests the service with no server: the allowlist, every endpoint's columns, rows and time, and refusals. |
| `www/index.html`, `www/app.js` | The page: MapLibre GL 4.7.1 from jsdelivr, pinned; no other library. |
| `checklist.md` | Every control and click path, tested before each change to the page. |

## What it serves

The names, places, synonyms, spellings and footprints go to the page once, whole (2.1, 0.5, 0.1, 0.8 and 10 MB as
JSON), and the page does every filter and link itself. A name's occurrences are asked when it is chosen (up to 30,642
rows, 0.1 s). Kept back from the occurrences: a finder's free text (it may name a person), Trackwell's own vessel name
(the vid is served) and the source's row id.

## Why its own page, not ramb's map viewer

`rb_map()` (plan 046), which the effort and voyage maps use, is a map of layers with filters on them: it has no list
to search, no panel for a chosen record and no tables linked to the map, which are most of this page. It is also
ramb's generic engine, and a gazetteer of Icelandic names is not a generic need. So the page is its own, in the
vessel overview's manner (plan 030: an R service with an allowlist, a page with pinned libraries), and it takes from
the viewer what serves it: the same MapLibre version, ramb's base maps (`rb_map_basemaps()`, served to the page), and
the effort map's way of drawing names from their minimum zoom.

## Not in this version

- the filters in the address (only the chosen name and the map's position are);
- the review queues and answers of plan 045 §3.1: who reviews, and whether a reviewer's name is kept, are open
  (plan 045 ask c);
- the effort, depth or habitat under a name (plan 045 §3.2-3.4).
