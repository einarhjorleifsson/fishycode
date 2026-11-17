# 324 — `$FISHYDATA/legacy/` deleted, its 28 scripts kept in `archive/`, to free disk for the next rebuild

*2026-11-17. At the maintainer's word ("Keep scripts, delete"), after the question why the disk was so full. Measured,
searched and carried out by Claude (AI); no person has checked it.*

## Why

The disk had 33 GiB free of 926 (97 % full). The next rebuild (TODO 182, decisions 310-314) and the effort map's grids
need more: `grid.R`'s spill reached 48 GB on 2026-10-30 (decision 265). Decision 187 set the store's home to be looked
at again below about 50 GB free, and named `legacy/` (then 60 GB) a candidate for removal, since nothing read it.

Where the disk went (2026-11-17, `du`): `$FISHYDATA` 610 GiB, of it PAME's astd and astdB about 300 (`raw/ais` 145 as
the delivered zips, `staging/ais` 153 as parquet), the rest of the AIS flow 98, `raw/oracle` 43, `legacy/` 61,
`archive/` 65 (32 of it plan 074's named-features study); the old repository's trail 32; the rest outside the store.

## Checked before the delete

- **Nothing reads it.** A search on 2026-11-17 of every repository under `~/stasi`, every study script under
  `$FISHYDATA/archive/` and the packages in `~/R/Pakkar`, for `legacy/` and the old `_data/legacy` path: only records
  name it. The `logbooks` repository's `data` and `data-raw` links point to `~/stasi/_data/legacy/`, broken since
  September (decision 168).
- **What had a copy.** `h3_indices.parquet` is in `raw/aux/` byte for byte (decision 002), `gebco.fgb` in
  `staging/aux/`. The other area shapes and port layers are older builds whose inputs are in `raw/aux/` and
  `raw/ports/`. The trails, logbook, landings, vessel and gear tables and staged STK and logbook data were derived
  from dumps and are superseded by fishycode's build.
- **What had none: the scripts.** The `logbooks` repository kept its scripts inside its data folders, so the tree held
  28 scripts and a log. Against `~/stasi/logbooks`' git history: 18 equal a commit, 5 were edited after their last
  commit, 5 were never committed. They were copied, byte for byte, to
  `$FISHYDATA/archive/2026-11-17-legacy-scripts/scripts/` under the same paths, each with its status in the README.
- **Kept, not touched:** `~/stasi/fishydata_2024-2026/data/ais/trail` (32 GiB). The 2025 ICES datacall reads it
  (`ices-datacall/2025/2025_vms-datacall.R`), as do that repository's 2025 ramb posts; it was taken back from the Trash
  on 2026-10-14 for the same reason.

## Done

- `legacy/`'s file list (223 files, 60.04 GiB: path, bytes, modified) written to
  `archive/2026-11-17-legacy-scripts/legacy_files.csv`.
- `legacy/` deleted permanently (`rm -rf`, not the Trash). The store has no backup (decision 187), so its data are gone.
- Free disk: 37 GiB just before the delete (33 earlier in the day), 97 GiB after (`df -g`).
- One personal file, not project data, found misfiled under `legacy/curated/ports/`, was moved to the maintainer's home
  folder before the delete.

## Left

Nothing for `legacy/`. The rebuild of TODO 182 and the effort grids after it wait on the maintainer's word as before;
the disk now holds room for both.
