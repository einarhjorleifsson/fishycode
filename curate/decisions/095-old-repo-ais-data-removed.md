# 095 — The old repo's AIS data removed

*2026-10-14. The maintainer's decision; checked and moved by Claude (AI-assisted). Closes TODO 8.*

`~/stasi/fishydata_2024-2026` held 40 GB that the restructuring never moved: two directories, each now known to
hold nothing the project needs.

- **`data-raw/ais/stk/stk_trail` (8.4 GB)** was an older copy of the STK dump. For every year 2007-2025 it is row
  for row identical to `$FISHYDATA/raw/ais/stk/trail`: the same row count and the same sum of row hashes over
  `.id, mid, time, lon, lat, speed, heading, hid, io, recdate`. Raw also has 2026.
- **`data/ais/trail` (31 GB, 476 M rows, 2007-06 to 2025-07)** was the old production trail: AIS joined to the
  logbook, the landings, metiers and spatial attributes. It was derived, its inputs are in `$FISHYDATA/raw`, and
  `curated/ais/trail` supersedes it. The maintainer first kept it in case a past ICES datacall delivery needed it,
  then chose to remove it.

Both were moved to the macOS Trash (`fishydata_2024-2026_stk_trail`, `fishydata_2024-2026_ais_trail`), not deleted,
so they can be recovered until the Trash is emptied. The repo itself stays; it is now 34 MB, with no directory over
1 GB. Its git history is on GitHub (`einarhjorleifsson/fishydata`). Making it read-only was TODO 9, dropped the same day (decision 097).
