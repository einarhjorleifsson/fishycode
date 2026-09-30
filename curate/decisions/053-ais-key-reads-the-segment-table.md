# 053 - `ais_key.R` reads the segment table

**Status:** done 2026-09-30 (plan 009 phase 5, step 2). Built end to end and verified 2026-09-30 (see the end).

The key the pipeline consumes (`curated/vessel/vessel_ais_key.parquet`) is now built from `curated/check/ais_key_segments.parquet`, not from
the cascade and the manual ODS. One mechanical consequence forced a split: the segment table reads the old key (identifiers, entity class,
the cascade's own vid as continuity), so the two cannot be one target.

- `reference/vessels/ais_key_cascade.R` (git mv of the old `ais_key.R`) -> `vessel_ais_key_cascade.parquet`. Unchanged content, still reads the
  ODS. Read by the audit, registry, split-candidate, segment, landings, reused-callsign and resolution checks - everything that audits the
  *cascade's* own claims.
- `reference/vessels/ais_key.R` (new, ~80 lines) -> `vessel_ais_key.parquet`: one row per segment, same columns as before (`step` =
  "segment: <source>", `tier` from the grade: A physical or reviewed, B registry or logbook, C landings, D continuity, E foreign override;
  `basis` reconstructed, foreign recorded), plus the cascade rows of the mobile-ids the table does not cover (navaids, buoys, net relays ...),
  with ODS `drop` vids set to NA. A stretch nobody can place is a row with vid NA, not a hole. Asserts that each mid's stretches tile it.
- `check_ais_key_coverage` now reads the final key: its invariant is checked on the product. It finds 70,901 pings (0.04 %) on stretches with no
  vid for mids that have a vessel - the list awaiting a person - and its own proposed fill closes all of them.
- **Gear devices are not in the key.** `vessel_ais_device.parquet` (mid, d1, d2, `carrier_vid`, pings; 13 rows, 10 mids) keeps the link to the
  vid that carries each.
- **The interval join was half-closed.** `sources/stk/convert.R` and `curate/ais_ping_union.R` joined on `between(time, d1, d2)` with `d2` a
  Date, so a ping after 00:00 on the last day of a period fell outside it. Both now join `time >= d1, time < d2 + 1`. Measured: the loss is
  small (57 pings with the old key, 510 with the new one - most periods end on the sentinel or in a silence), and the coverage check could
  not see it because it counted whole days. With the half-open join the new key assigns 181,714,828 STK pings against the old key's
  181,126,291 (+588,537).
- Backups: the previous key is `vessel_ais_key_cascade.parquet` (byte-identical copy at the time of the switch).

**Not done - needs a decision to run:** the targets downstream of the key are outdated (`stk`, `ais_ping_union`, `ais_ping_clean`, `ais_ping_tag`,
`ais_trip`, `trip_voyage`, `logbook_sensor_gps`, and the checks). Running them re-labels about 1.3 % of STK pings and fills the stretches the old
key left unassigned; it rebuilds the 44 GB union. The ODS stays until the cascade's `manuals` step is dropped and the audit chain rebuilt on the result.

## Build record, 2026-09-30

`tar_make()` built the cascade (identical to the old key: 19,234 rows, same mid/d1/d2/vid/step), the audit chain (audit 4 m 32 s), the segment table, the new key,
twins and recall without trouble. `ais_ping_union` first failed on `d2 + 1` (DuckDB has no DATE + DECIMAL; the literal must be `1L` - fixed in both
`sources/stk/convert.R` and `curate/ais_ping_union.R`), then ran **1 h 35 m 34 s**, 12.79 GB - the same size as the previous union, rows within 0.1 % per
year (2019: 50.17 M against 50.15 M in the earlier run's derived table). It was stopped on purpose after the union (the maintainer had to leave), so the
downstream targets remain outdated. The last full union took about 37 minutes (2 min a year); the loop at the end of `ais_ping_union.R` re-evaluates the
whole lazy query once per year (20 rescans of ~145 GB of ASTD/ASTDB), so each year costs a fixed ~5 minutes whatever its size. Not caused by the join
(timed in plain DuckDB: 0.3 s for old and new forms, identical rows). A pruned or single-pass write is a possible change, not made.

## The rest of the build, and a silent failure found on the way, 2026-09-30

The union was stopped on purpose, then `tar_make()` was resumed. **It reported success in 3 m 57 s, and `ais_ping_clean` had done nothing**: it keeps an
empty completion marker per year and skips any year with one, so against the 23 Sep markers every year printed "already done, skipping", `ping_clean`
stayed the old output (newest file 23 Sep 19:33), and because its files were unchanged targets skipped `ais_trip`, `trip_voyage` and `logbook_sensor_gps`.
The pipeline said "up to date" while the tail was built from the old key. Fixed in `curate/ais_ping_clean.R`: a marker now holds a fingerprint of that
year's input files (name, size, mtime) and a year is skipped only when it still matches; old empty markers never match. No other script has this pattern.
Rerun: `ais_ping_clean` 6 m 08 s (13.71 GB, all years), `ais_trip` 8 m 55 s (12.67 GB), `trip_voyage` under 1 s, `logbook_sensor_gps` 9 m 03 s (1.19 GB);
the whole resume 24 m 16 s, nothing outdated afterwards.

Verified on the rebuilt tables: STK staging has 181,714,831 rows against the segment table's 181,714,828 pings on a vid (3 apart); the six vid swaps
(mids 103750, 101280, 146259, 139705, 101079, 101892's 2007-13 stretch) are in staging with the intended vids; no gear-device mid is in it; union ->
tagged -> clean is 543.7 M -> 543.7 M -> 540.5 M rows (0.59 % dropped: STK 1.18 %, ASTD 0.24 %, ASTDB 0.67 %, EmodNet 1.41 %); the swapped vids have trips
(720,097 trips, 2,761 vids). STK staging repeats 6.6 M (mid, time) pairs (3.6 %) - inherited from the raw trail (9.9 M of 290 M rows since 2007-06), not
made by the join (the segments do not overlap); the union removes exact duplicates (175,113,292 STK rows).
