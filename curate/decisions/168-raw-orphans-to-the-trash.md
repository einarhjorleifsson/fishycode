# 168 — Ten files in `raw/` that nothing reads, moved to the Trash

*2026-10-22. Asked by the maintainer ("check if there are now redundant files in the raw directory ... orphan
files/directory"), who approved the move. Written by Claude (AI); the sweep and the checksums are Claude's. The
maintainer ran the move, since Claude's own move into the Trash was refused by its permission check.*

## The sweep

- **`raw/oracle/`:** each of the 28 schema directories has its `dump/oracle/<schema>.R`, and every file in it is a
  row of its `_overview_tables.parquet`. The only rows marked written with no file are stk's three copies of the whole
  trail (`stk_vms_v`, `trail_all`, `view_trail`), kept on the server by decision 109. Nothing to remove.
- **The rest of `raw/`:** every file and folder was searched for by name in fishycode's code (scripts, pages, the
  targets files; not `archive/`, decisions, plans or `TODO.md`), in the two predecessor repos and in
  `~/stasi/ICES-VMS-and-Logbook-Data-Call`. The old repos read their own `data-raw/` and `data/`, or
  `$FISHYDATA/legacy/`, never these copies.

## Moved

To `~/.Trash/fishydata-raw-orphans_2026-10-22/`, paths kept, 3.8 GB:

| Path under `raw/` | Size | Why |
|---|---|---|
| `ais/trail2/` | 2.6 GB | An aborted first write of the legacy `trail2` (2026-05-07, 11:00-11:28, years 2007-2014, the 2014 file without a parquet footer, TODO 95). The finished one, 2007-2026, is `$FISHYDATA/legacy/curated/trail2/`. |
| `aux/hab_and_bathy_layers.zip` | 1.2 GB | The ICES datacall's delivery of `eusm.rds` and `ICES_GEBCO.rds`, which lie unpacked beside it: both identical by md5 to the zip's members. |
| `aux/ICESareas.fgb`, `aux/ices_areas.fgb` | 24 MB each | Copies of the ICES areas in another format. `reference/geo/shapes_raw.R` reads `ICESareas.gpkg`. |
| `aux/FAO_AREAS_ERASE.gpkg` and its `-journal` | 110 KB | An interrupted write of 2026-05-02: a 64 KB GeoPackage with its rollback journal left beside it. The layer is whole in the `.geojson`, and no FAO file is read after `dump/aux/wfs_layers.R` fetches it. |
| `external/BrimAfladag2022-2026.zip` | 3.3 MB | The same nine files as the folder beside it, compared file by file. |
| `mmsi/mmsi_iceland_2025-MM-DD.parquet` | 100 KB | Identical by md5 to `vessels/mmsi_iceland_archieves.parquet`, the archive in use (plan 016 §1). |
| `mmsi/mmsi_iceland_2026-03-25.parquet` | 104 KB | An earlier build's merge of the 2026-03-09 list into the archive; read by nothing (plan 016 §1, plan 028). |
| `ports/ports_osm.fgb` | 2.3 MB | Written beside `ports_osm.gpkg`, the file `reference/ports/ports_all.R` reads. `dump/ports/osm.R` no longer writes it (e0cd88a). |

**Check:** `tar_outdated()` was taken before and after, in both projects, and is unchanged: main 25 targets, `once`
21. These were outdated before the move: decision 165's adb chain, `afli_sent`, `mbl_photo`, and the `once`
project's whole-project view. `raw/` went from 198 to 195 GB.

## Kept

- `mmsi/Númer - Skip - MMSI númeraröð090326.xlsx`, byte-identical to `mmsi-iceland_fjarskiptastofa_2026-03-09.xlsx`
  (plan 016 §1). `reference/vessels/mmsi.R` drops it by md5, but `mmsi_raw` lists every `.xlsx` in the folder, so
  removing it would make `mmsi` outdated. It goes at the next MMSI rebuild.
- With a reason recorded elsewhere: `logbooks/logbook/` (decision 111), `aux/h3_indices.parquet` (decision 002),
  `ports/archive/` (the ports' first bootstrap, kept there by `reference/ports/bootstrap_iceland_faroe.R` and named by
  `curate/corrections/ports_iceland.R`) and
  `survey/datras_HH.parquet` (decision 104).

## Seen in passing

`~/stasi/logbooks/data` and `~/stasi/logbooks/data-raw` are links to `~/stasi/_data/legacy/{curated,staging}`, which no
longer exist: the tree is `$FISHYDATA/legacy/` (60 GB). The old repo is not edited (AGENTS.md), so they stay broken.
