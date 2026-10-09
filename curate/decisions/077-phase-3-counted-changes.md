# 077 — Plan 014 phase 3: the counted changes before the rebuild

*2026-10-09. Changes made and counted by Claude (AI-assisted) on today's inputs, written to scratch, never into
`curated/`. The rules were chosen by the maintainer where marked. Each change is its own commit with its counts.
ramb: 8467357 (names), f6faf9b (speed), not yet pushed.*

| Step | Change | Counted |
|---|---|---|
| 3a | gps joins the feed union (`pos_basis` reconstructed); step 0's duplicate and impossible tests, the stays and the voyage cut read recorded positions only; an exact `(vid, time)` tie is a step-0 flag (`tie`); `ais_ping_trail.R` removed; the gps1/gps2 choice made deterministic | 2019: 2,657,695 gps fixes = the 2,643,043 the old trail had + 14,652 at an AIS `(vid, time)` (now `tie`); 125 speeds differ only by the fixed choice |
| 3b | STK events tagged from STK alone (`sources/stk/event.R`); a stay trusts an event that is `io_ok` and kept by step 0; no harbour class; one 2 h minimum stay (decision 074) | 8,197,409 events; 23 change what a stay trusts; stays 1,551,598 → 1,565,463 (+0.9 %); Hornvík 78 → 137, Helguvík 711 → 1,073 |
| 3c | port, stay and voyage names (decision 075): `ais/voyage.parquet` (`voyage`, `pid1`/`pid2`), `ais/port_stay.parquet` (a `stay` key), pings carry keys only | names only; first real run is the rebuild |
| 3d | afli depth units: ties broken by the station's first time, then `.sid` (TODO 47) | two runs identical; 163 stations differ from today's build |
| 3e | the two DEFLATE64 astd months loaded (TODO 14) | 2023-08: 24,819,518 rows; 2023-09: 22,823,275 |
| 3f | `station_type` not written: is a jig or longline record one operation or a day? (TODO 3, asked) | LHM/LLS one record per vessel-day for 92–99 % of vessel-days; OTB 3.6–3.8 |
| 3g | `catch_by_species_trip.R` grouped on `(.tid, schema)` (TODO 41) | 8,285,715 rows, 0 changed |
| 3h | ramb's trip SQL numbers rows per vessel (TODO 48) | a 4.9 M-ping batch: 24.0 → 7.3 s, output identical |
| 3i | `lid_map` keyed on `(.tid, schema)`, the pelagic step runs, the landing's date and port on the link, many-to-many declared (`n_trips`) (TODO 43) | links 790,632 → 790,875; pelagic step 0 → 118; 790,380 trips keep their landing, 140 change, 112 lose, 355 gain; 3,608 landings on 2+ trips |
| 3j | a station's gear is its landing's where the landing names one metier (maintainer's rule; `logbook_gear.R`, every schema); `metier` (gear_target2, e.g. OTB_NEP) carried to the windows and the trail | afli 63,076, fs_afladagbok 12,573, adb 20,275 stations take the landing's gear |

## What the maintainer added on the way

- **Gear codes changed.** agf landings carry the new gear code (90–94 % equal to the logbook's new `gid`), lods
  landings the old one (99.5 % equal to `gid_old`). A lods gear is mapped to the new code before anything is
  compared. Comparing codes without that would have been wrong for 7,484 afli stations.
- **Compare and work in metier labels.** Gears are compared as gear + target2 (OTB_NEP), not as a code: by code,
  184,607 afli stations "disagreed", mostly Lína ↔ Landbeitt lína ↔ Línutrekt (all LLS_DEF). The logbook's
  `gid` and the landing's `gid_landing` are both kept, and downstream works from `metier`.

## Open

- The window rules (`gear_window`) are still keyed on the gear id. Within a metier they agree, except LLS_DEF:
  its three ids carry two rule sets. Keying the rules on metier needs one rule for LLS_DEF.
- TODO 48 closes on the rebuild's full timing (the check is at most 10 min; the batch rate suggests about 15).
- TODO 14 closes when the rebuild puts the two months into `ping_union`.
- The data dictionary, the docs and three fishyweb pages follow the renames after the rebuild.
