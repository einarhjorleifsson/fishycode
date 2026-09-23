# `lid_map` stops overwriting `logbook`'s `trip.parquet`

*Decided and implemented 2026-09-23.*

## What was wrong

`curated/logbook/trip.parquet` was written by two different `targets`
targets: `logbook` wrote it first (`curate/logbook.R`), then `lid_map`
(`curate/link_lid_map.R`) read it back, left-joined its own
`.tid_land`/`match_type` crosswalk onto it, and overwrote the same path.
Both `tar_target()`s declared it in their own `produces()`.

`targets` assumes a declared output file is owned exclusively by the one
target that produces it. Here, every `lid_map` run silently invalidated
`logbook`'s recorded hash for that file (it no longer matched what `logbook`
itself had written), so `logbook` looked stale and reran - which rewrote the
plain, pre-enrichment version, which then made `lid_map` look stale and
rerun again. A perpetual ping-pong between the two, independent of whether
any real input (afli/adb/fs_afladagbok, or the landings register) had
actually changed.

Found while rebuilding the AIS chain (item 13, see
[026](026-item13-ais-chain-rebuilt.md)): two consecutive, otherwise-identical
`tar_make()` runs each rebuilt `logbook`, `lid_map`, `logbook_sensor_gps` and
`trip_voyage` again - ~13 minutes of real compute for nothing, twice.

## The fix

`link_lid_map.R` no longer writes `trip.parquet` at all. Its only output is
`curated/logbook/lid_map.parquet` (columns `.tid`, `schema`, `.tid_land`,
`match_type`), which already carried the crosswalk independently - the
write-back was pure denormalisation for convenience, never the source of
truth. `tar_target(lid_map, ...)`'s `produces()` now declares only
`lid_map.parquet`.

This is also just applying a rule this project already states in
`AGENTS.md`: *"Never destroy the original. A correction adds columns; it
never overwrites."* Overwriting `trip.parquet` in place violated that same
principle `lid_map` itself is supposed to follow, not only the `targets`
dependency model.

## Checked before changing it

No consumer relies on `trip.parquet` already carrying `.tid_land`/
`match_type`:
- `curate/link_trip_voyage.R` reads `trip.parquet` but never references
  either column.
- `docs/landings-match.qmd` reads `trip.parquet` and `lid_map.parquet`
  **separately** and joins them itself - it was never depending on the
  write-back either, despite describing it in prose (updated).

A consumer that wants both together now does
`trip |> left_join(lid_map, by = c(".tid", "schema"))` itself - one line,
and it makes the join an explicit, visible step rather than a hidden side
effect of running `lid_map`.

## What this doesn't fix

Nothing about the *matching logic* changed - same eight-step cascade, same
crosswalk. This is purely the ownership/overwrite bug.
