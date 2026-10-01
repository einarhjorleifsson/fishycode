# 061 — Voyages are cut at stays; the AIS chain is rebuilt once

*2026-10-01. Plan 011 Phase 4. Written BEFORE the rebuild, as the plan requires; the measured result is added
below when it has run.*

## What changes

`curate/ais_trip.R` no longer finds harbour runs from the polygon tag and bridges those shorter than 4 h. A
voyage is the sea between two stays (`curated/ais/harbour_stay`, decisions 059–060), from every provider; the
departure and arrival harbour are the stays either side. Event-only stays are not used (decision 060).
`curated/ais/ping` gains `stay_pid`; `pid` (polygon tag) is unchanged. The 4 h stay minimum is kept.

## What is rebuilt, and why now

The whole outdated chain, once (AGENTS: not per polygon change): the 26 outdated targets, among them
`stk`, `ais_ping_union`, `ais_ping_tag` (current polygons, decision 058; the ping tag still carries the old
set), `ais_ping_clean`, then `check_stk_event`, `harbour_radius`, `harbour_stay`, `ais_trip`, `trip_voyage`,
`ais_ping_trail`, the logbook and landing targets, and the key checks. The events and stays are computed from
the rebuilt `ping_clean`, so their numbers may differ a little from decisions 059–060.

## Baseline kept

`$FISHYDATA/archive/pre-phase4_2026-10-01/{trip,trip_voyage}.parquet` (the old voyages and their links).
`curated/ais/ping` and `ping_trail` are not archived (derived, ~45 GB); the old logic is in git (`342f766` and earlier).
Rollback = restore the two files and `git revert` the `ais_trip.R` change; `ping` is rebuilt by `ais_trip`.

## What is measured

`curate/checks/voyage_sharing.R` → `curated/check/voyage_sharing.parquet`, same definitions before and after:
logbook trips linked, trips whose voyage is shared with another trip (plan §6: from ≈ 23 % afli, 19 % fs_afladagbok to
a small, explained residue), arrival-harbour agreement with the logbook landing harbour, voyages over 3 and 7 days,
vid 2481 in 2011 (≈ 185 voyages).
