# 330 — ogis 2026.11.18.14-17: the sea floor, effort by cell, place names and vessel tracks in one line each; the side sessions folded in and closed

*2026-11-18. Built in a side session ("Icelandic depth model in ogis: size, format, S3") and the sessions it started,
each step at the maintainer's word in that session (quoted below); folded into one record and the sessions closed at
the maintainer's word in the session that started them ("Yes, all of it"). Written by Claude (AI); no person has
checked the numbers. The study and the trial scripts: `$FISHYDATA/archive/2026-11-18-depth-model-in-ogis/` (its
README).*

## The study first: the Icelandic depth model in ogis

The maintainer asked for its size and format if it were in ogis, and what serving it from an in-house S3 bucket would
take (`report.md` in the archive):
- The model is Julian Burgos's Olex 50 m grid with GEBCO (4.19 GB GeoTIFF, EPSG:5325). In ogis's forms, zooms 0-8 are
  105 MB as `og_tiles_dem()`'s PNG and 51 MB as lossless WebP at 0.1 m; zooms 0-10, the most a 50 m grid warrants,
  1.22 GB and 0.54 GB.
- **It does not ship in ogis** (public, and CRAN's 5 MB holds zooms 0-6 at about 500 m a pixel). It is shared as one
  file, fishycode's `products/bathymetry_map/depth.mbtiles`, each colleague naming it in `.Renviron` (`OGIS_DEPTH`).
- **An S3 bucket readable from MFRI's network only** (one PMTiles archive, range requests, a CORS rule) was
  prototyped against a local stand-in: drawn served, as a bundle from a folder and on a web host, the look staying the
  reader's. ogis would need a dem or contour layer from a tile address (about 80 lines). Recommended, a plan
  warranted: TODO 204.

## What ogis gained (all on GitHub's `main`)

| Version | Commit | What | The maintainer's word |
|---|---|---|---|
| 2026.11.18.14 | 71b9111 | `og_relief()` and `og_contour()`: the sea floor in one line each, the model from `OGIS_DEPTH`, an MBTiles file, a grid or a tile function | "can we not just have a ogis wrapper", "Yes, build it" |
| 2026.11.18.15 | 1f723a5 | `og_cells()`: values by cell (fishycode's effort map) from a table or the Parquet file `OGIS_CELLS` names, summed by DuckDB to about a pixel; `og_names()`: curated place names from `OGIS_NAMES`, searched, clicked, areas a layer of their own; Find takes ð, þ, æ; a geometry collection drawn as its parts | "would like that the user could do similar thing but from within ogis"; the name `og_cells()`: "we may have different data of the same format" |
| 2026.11.18.16 | 90b1763 | `og_tracks()`: pings (ramb's columns or EM4SSF's D2.1) as track, activity, a time panel and effort by cell, for the EM4SSF hackathon (Ancona, 1-4 December 2026); `og_cells()` live grid sizes (0.01-0.5°, the ICES rectangle), at-least-N vessels, following the panel's vessel; the article "Vessel tracks" | in that session |
| — | 3e17085 | `og_tracks(compare = )`: two methods' trips, or inferred against observed activity, marked where they disagree (CS1: 15,652 of 1,020,999 pings, at Ancona's harbour mouth) | in that session |
| 2026.11.18.17 | c6f3bcf | Two faults found by the Icelandic example (decision 329): a vessel id with a space was refused its effort tiles (the server read a query's `+` as itself), and `og_tracks(pings = x)` with no map stopped; each with a test that failed before | in the fix session |
| — | f2c5aa2, 2092b8a | `AGENTS.md`: ogis's map for agents (what it is, where things are, how a change lands, rules, state); `CLAUDE.md` loads it; both out of the package build. **Not yet read by the maintainer** | in the fix session |

ramb 2026.11.18.1 (eda610d, ea05430) took the track viewer's three wishes: `voyage_key` (one value per trip across
vessels and years), `rb_add_trip_gear()`, and `rb_flag_ping_clock_jump()` (a stream's clock jumping ahead by a zone's
step; CS1's three found), with the fix of `rb_add_voyages()`'s `vid` under another name.

The Icelandic example (decision 329, TODO 202) was asked for in the same session and stays open there.

## Checked before the push

On `main` at 2092b8a, macOS:
- R CMD check `--as-cran`: no error or warning, 1,339 tests passed. One NOTE, CRAN's incoming check: a new
  submission, and four `https://doi.org/` links in the example data's help pages (`dansk`, `dansk_harbours`,
  `dansk_relief`) that CRAN would have as `\doi{}`. These were there before this work.
- The whole suite with `NOT_CRAN=true`, the browser tests included: 1,584 passed, none failed or skipped.
- Installed: ogis 2026.11.18.17 (from f2c5aa2; the knit and Rscript tests pass against it), ramb 2026.11.18.1.
- GitHub's CI on 2092b8a: R CMD check passed on Ubuntu, Windows and macOS; the site's build failed. GitHub's source
  archive, from which pak installs ramb for the site, holds ramb's Git LFS example data as 132-byte pointers, so the new
  article "Vessel tracks" had nothing to read. The workflow now installs ramb again from a clone that fetches them
  (0c4ed35); the article built locally first. CI on 0c4ed35: all passed, the site published with the article.
  `AGENTS.md`'s state updated after (2bdd9aa, CI skipped).

## Folded in and closed

- **Servers stopped**: two `og_tracks()` viewers (ports 8815, 8817; one on CS1, local only) and a static server
  (8813), all run from the side session's scratchpad.
- **Records**: the study and the trial scripts moved from the side-session notes and scratchpad into the archive above;
  this record; TODOs 203-205 for what was left open.
- **Deleted** at the maintainer's word: the side session's scratchpad (about 12 GB: the depth tiles, archives and COGs,
  the trial effort and names files, copies of CS1), remade by the archived scripts.
- **Pushed**: ogis (71b9111..2bdd9aa) and ramb (09182bc..ea05430).
- **The four sessions archived**: the depth study, the Icelandic example, the ogis fix, ramb's wishes.

## Open

- TODO 203: a vessel id with a comma is still refused by the effort's cells (the server splits a filter's values at
  commas).
- TODO 204: the depth model from an in-house S3 bucket (the study's option C), a plan at the maintainer's word; and the
  five small ogis faults the study found.
- TODO 205: the files `OGIS_CELLS` and `OGIS_NAMES` name, built as fishycode products (only trials exist; their
  scripts are in the archive), so colleagues can set them as they set `OGIS_DEPTH`.
- `AGENTS.md` in ogis, for the maintainer to read.
