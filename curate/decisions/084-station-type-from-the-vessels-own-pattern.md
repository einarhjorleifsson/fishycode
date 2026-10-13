# 084 — `station_type` is read from the vessel's own pattern

*2026-10-13. Measurement and code by Claude (AI-assisted). The rule is the maintainer's (2026-10-09, TODO 3).
The threshold and the longline basis are Claude's proposal from the measurement below, shown to the
maintainer before the 2026-10 rebuild. Closes TODO 3.*

## The rule (maintainer, 2026-10-09)

Longlines are normally reported by operation, with exceptions. Jiggers and netters more often send one record a
day. It changes over time, and bigger vessels (such as the Greenland halibut net fishery) more often report each
setting. So there is no fixed rule per gear: it is read per vessel, year and gear from the vessel's own pattern,
the share of its fishing days with more than one record. Basis `derived`. Longlines are `operation` unless the
pattern says otherwise.

## Measured (curated logbook of 2026-10-09, 7,239,451 stations, deleted records left out)

Per vessel, year and gear: the share of fishing days with more than one record. Percentage of each gear's
stations in vessel-years whose share falls in each bin:

| gear | stations | 0 | (0, .1] | (.1, .25] | (.25, .5] | (.5, .75] | (.75, 1) | 1 |
|---|---|---|---|---|---|---|---|---|
| OTB | 4,269,625 | 0 | 0 | 0 | 0 | 2 | 96 | 1 |
| SDN | 1,148,686 | 0 | 0 | 0 | 0 | 1 | 82 | 17 |
| LLS | 542,388 | 53 | 43 | 3 | 1 | 0 | 0 | 0 |
| LHM | 503,695 | 77 | 18 | 4 | 1 | 0 | 0 | 0 |
| GNS | 395,827 | 54 | 24 | 6 | 4 | 3 | 8 | 1 |
| OTM | 158,456 | 0 | 1 | 8 | 50 | 28 | 12 | 1 |
| PS | 109,441 | 0 | 0 | 2 | 7 | 45 | 44 | 1 |
| DRB | 83,950 | 27 | 23 | 7 | 3 | 3 | 29 | 7 |

- Vessel-years pile up at 0 and near 1. Across all gears, of those with at least 5 fishing days, 34,215 lie at or below 0.1 and 11,994
  above 0.75; 5,294 lie between.
- **Midwater trawl** sits at 0.25–0.5: its tows are long, one or two a day, and are plainly operations. A
  threshold in the middle of the valley would call half of them daily records. The threshold is therefore low,
  **0.1**: a vessel that sends several records on at least one fishing day in ten reports by operation. Below
  that, an occasional second record is what a daily record split by area also gives.
- **Longlines** sit at 0–0.1 (96 % of stations), because a longliner sets once a day. The share cannot tell one set
  a day from one record a day, so it never makes a longline `event` (the maintainer's rule).
  - Such a longline is `operation` with basis `synthesised`: set by rule, not read from its pattern.
  - The 4 % with a share of 0.1 or more are `operation`, `derived`.
- Gillnets swing from 83–91 % at or below 0.1 in 1985–2004 to 48–52 % since 2020. This matches the maintainer's
  account of bigger netters reporting each setting.
- Vessel-years with fewer than 5 fishing days hold under 1.5 % of any main gear's stations, so they get no rule of
  their own.

## What was built

`curate/logbook.R`, on the merged tables (the tiers by vessel and date mix schemas within a vessel-year, and adb
is a third schema), adds to `curated/logbook/station.parquet`:
- `station_type`: `operation` where the share is at least 0.1 or the gear is LLS, otherwise `event`.
- `station_type_basis`: `derived`; `synthesised` for an LLS station below 0.1; `none` where the station has no
  pattern (no vessel).

TODO 3's check was "both adapters write it". It is met on the merged table instead, which is one implementation for
all three schemas.

Run without its writes (2026-10-13): rows and every other column unchanged.

| station_type | basis | stations |
|---|---|---|
| operation | derived | 5,879,425 |
| operation | synthesised (LLS) | 517,713 |
| event | derived | 842,619 |
| NA | none | 21 |

Stations that are `event`, by gear:
- LHM 477,413 of 503,698;
- GNS 308,782 of 395,850;
- DRB 41,910 of 83,950;
- FPO 3,846 of 6,158;
- OTB, OTM, SDN and PS under 2 %.

## Not done

- `monthly_aggregate` and `annual_aggregate` are not station rows here. afli's monthly aggregates stay in
  `staging/afli/aggregate`.
- `reconstructed` stations from the track are plan 004 / TODO 18.
