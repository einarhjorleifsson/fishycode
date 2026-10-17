# 124 — The afli adapter takes the deletion flag and 172 paper stations from fs_afli

*2026-10-17. Chosen by the maintainer: decision 123's options 2 and 4 ("proceed with recommendation"). Written by
Claude (AI-assisted). Tested by running the adapter, the depth correction and the merge against a scratch
`$FISHYDATA`: `raw/`, `curated/reference/` and the other adapters' staging were read through links, and nothing
under `$FISHYDATA` was written. Not built; that is TODO 77's build.*

## What changed

- **`sources/afli/convert.R`** takes `eytt` from `fs_afli.rafr_stofn`, which runs to 2024; afli's stopped on
  2020-07-23. It adds the paper stations of `fs_afli.stofn` that `afli.stofn` lacks (positive ids, 189, decision
  123's group E), with their `toga`, `lineha`, `gildra`, `hringn` and `afli` rows. A new station column, `copy`,
  says which copy each station was read from (`afli` or `fs_afli`). Each copy makes its own trips, so no afli trip
  and no `.tid` changes. fs_afli is a copy of the same schema, so the adapter still reads one source (AGENTS.md).
- **`curate/logbook.R`** has a tier 2b. A station read from fs_afli is kept only on a vessel-day that neither afli
  nor fs_afladagbok holds. Where either does, it is the same haul entered again: of the 17 such stations, 14 carry
  the same kg as a station already there, and one has no catch. Group C, fs_afli's electronic stations, is not read:
  those are fs_afladagbok's hauls (decision 123).
- **`_targets.R`**: `afli_raw` declares fs_afli's seven files, and no longer afli's `rafr_stofn`. `tar_outdated()`
  lists `afli_raw`, `afli`, `afli_depth_units` and `logbook`.
- **`docs/data-dict.yaml`** describes `copy` and where `eytt_deleted` comes from; `docs/afli-tables.qmd` says the
  same.

## Tested against the current build

Every table below was compared with today's, row by row on its key, and column by column on shared rows:

| table | change | shared rows |
|---|---|---|
| `staging/afli/station` | +189, none removed | equal, but for `eytt_deleted` |
| `staging/afli/trip` | +180, none removed | equal |
| `staging/afli/fishing_sample` | +189 | equal (`.checks` too), but for `eytt_deleted` |
| `staging/afli/catch` | +386 | equal |
| `staging/afli/depth` | +189 | equal |
| `staging/afli/aggregate`, `sensor` | none | equal |
| `curated/logbook/station` | +172, none removed | equal, but for `eytt_deleted`; no `station_type` changes |
| `curated/logbook/trip` | +165 | equal |
| `curated/logbook/fishing_sample` | +172 | equal, but for `eytt_deleted` |
| `curated/logbook/catch` | +363, none removed (whole rows compared) | equal |

`eytt_deleted` changes on 165,463 stations: NA to FALSE on 165,398, NA to TRUE on 61, and FALSE to TRUE on 4, deleted
in fs_afli after afli's copy stopped. fs_afladagbok's 374,681 stations and adb's 83,223 are unchanged.

The 172 stations kept hold 152.9 t: 133 jig (LHM, 86.1 t) and 39 gillnet (GNS, 66.8 t), from 2020-05-08 to
2022-06-14. They are the 162 that decision 123 checked against the landings and the track, and 10 that lie one day
from a curated station of the vessel. Of the 10, 5 have a landing on each of the two days, so they are separate
trips. 2 look like the same haul a day off and carry no catch (vessels 1904 and 5713). 3 lie 77-124 km from their
neighbour, and differ in catch where both have one.

## Not done here

- The build (TODO 77) writes it to `$FISHYDATA`; TODO 78's check follows it.
- The 22 stations far from the track keep their recorded positions (decision 123). A fix would be a correction in
  `curate/corrections/`.
- What the merge leaves out is recorded nowhere: a station dropped by a tier is simply not in `curated/logbook`.
