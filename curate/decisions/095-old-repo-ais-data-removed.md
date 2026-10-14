# 095 — The old repo's AIS data: the STK copy removed, the old trail kept

*2026-10-14. The maintainer's decision; checked and moved by Claude (AI-assisted). Closed TODO 8; amended the same
day (below), which reopened it.*

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

## Amended the same day: the old trail is the 2025 ICES delivery's input, and is restored

Looking at TODO 27b the same afternoon turned up the answer to the question the maintainer had first held the trail
for. `fishydata_2024-2026/ices-datacall/2025/2025_vms-datacall.R`, the script behind the 2025 ICES VMS datacall
delivery, reads `here("data/ais/trail")`: this directory. It uses its enriched columns (`.cid`, `whack`, `met6`,
`lb_base`, `.msfd_bbht`, `.depth`, `catch_total`), and the delivered CSVs are not kept locally. So the trail is the
only way to reproduce that delivery, and the baseline against which a datacall built on `curated/ais/trail` is
checked (TODO 27b).

It was moved back from the Trash on the maintainer's decision, unchanged (31 GB, 19 year partitions). It stays
until a datacall built on the curated trail supersedes the 2025 delivery (TODO 8, reopened). The STK copy stays in
the Trash: it was identical to `raw/` and the delivery never read it.

### The earlier reading, superseded

"It is unique only as the record of what the old method produced" was true, but that record is a delivery to ICES.
"The maintainer first kept it ... then chose to remove it" stands as what happened. The removal was decided before
anyone had looked at which files the 2025 script read.
