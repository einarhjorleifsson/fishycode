# 181 — Every current-year bound follows the data: the logbook caps at each source's dump, the AIS years at the feeds' partitions

*2026-10-23. Found by a read-only audit on 2026-10-23; the same defect class as decision 027 (a stale date literal in
`lid_map` that dropped every 2026 match). Written by Claude (AI) in a session started from another Claude session; the
code and the checks are Claude's and have not been checked by a person. Committed, not built: every output is
unchanged today (below), so no target needs invalidating.*

## Found

Three literals would have dropped all of 2027 on the first rebuild after New Year, with no error:

- `curate/logbook.R`: `DATE_MAX <- as.Date("2026-12-31")` capped the afli, adb and aflaskeyti stations. adb is the only
  one still fed (afli ends 2024-06-27, aflaskeyti 2018-06-08), so every haul after 2026 would have gone.
- `curate/ais_ping_union.R` and `curate/ais_ping_tag.R`: `years <- 2007:2026`, the loops that write
  `staging/ais/ping_union` and `ping_tagged`, so every 2027 ping, and with it every port call, voyage, fix, effort and
  catch built on them. The flow's later scripts (`ais_ping_clean.R`, `ais_voyage.R`, `ais_trail.R`, `ais_catch.R`,
  `logbook_sensor_gps.R`) already take their years from the data.

The sweep of `sources/`, `curate/`, `reference/`, `R/`, `products/`, `dump/`, `_targets.R` and `_targets_once.R` found
four more of the same kind, of lesser reach:

- `curate/corrections/ping_union_duplicate_keys.R`: the default `years = 2007:2026` of a measurement run by hand.
- `curate/corrections/licence_lost_century.R` (`once` side, not wired, plan 029): an assertion that every resolved date
  lies in 1991-2026, which would stop a run in 2027 (loudly, not silently).
- `sources/norway/vessel_registry.R`: the sheets `2001:2022` of the delivered workbook; a new workbook's later years
  would have been read past without a word.
- `reference/vessels/ais_key.R` (the frozen `once` key): `n_years` counted an open stretch's years to 2026-12-31 at
  most. Nothing reads `n_years`.

## Chosen

- **The logbook:** each source is capped at the day after its dump began, read from the `fd.dumped` stamp of the raw
  file its adapter reads (`afli.stofn` and `fs_afli.stofn`, the later of the two; `adb.fishing_station`;
  `dw.dw_aflaskeyti`). The intent of the old cap is kept: no haul is later than the copy it was read from, so the 26
  adb stations dated 2027-2031 (decision 125) are still left out. A dump's stamp, not `Sys.Date()`, so that the same
  inputs give the same output whenever they are built. A day of margin, since `fd.dumped` is the dump's start and a
  dump can run past midnight. A raw file without the stamp stops the script. The script reads only the stamps of
  these files, never their rows; the target does not list them, but a new dump reaches it through the adapters'
  targets, so cap and rows move together.
- **The AIS union:** from 2007 to the newest year partition of any feed: the STK trail (by receipt year), astd,
  astdB and the logger. The floor stays 2007 (STK's partitions of 2003-2006 stay out, as before), and a ping whose
  time lies past the newest partition (2106 ...) is left out, as before.
- **The tagging:** the years the union wrote, as `ais_ping_clean.R` does.
- **The duplicate-key measurement:** by default every year the union holds.
- **The licence assertion:** the current year at run time. It checks a one-time fix, built once; the clock is what
  the literal stood for.
- **The Norwegian register:** every four-digit sheet of the workbook, oldest first.
- **The key's `n_years`:** counted to the newest year partition of the STK dump at most. Edited in the frozen project
  because no output differs (below); the key is not redone.

## Checked, against the store as built on 2026-10-22

- The logbook: the edited `curate/logbook.R` run on a scratch `$FISHYDATA` (raw and staging linked, `curated/` empty;
  1.6 min) wrote `trip`, `station`, `fishing_sample` and `catch` with the real files' columns and types and the same
  rows: 1,854,063, 7,310,942, 7,310,942 and 17,026,059, none in either `EXCEPT ALL`. The caps are 2026-10-18 (afli),
  2026-10-17 (adb) and 2026-10-18 (aflaskeyti): no station of these sources lies between them and 2026-12-31 (adb's
  last before 2027-06-22 is on or before 2026-10-15).
- The AIS years: the new expressions give exactly `2007:2026` for the union (newest partition 2026 in all four feeds),
  the tagging (the union's 20 partitions; integer, so the loop's SQL is the same) and the duplicate-key default. The
  loop bodies are unchanged, so the outputs are.
- The licence assertion: the current year is 2026. The Norwegian sheets: `2001`…`2022`, the same vector.
- The key: `n_years` by the new formula equals the old on all 3,365 segment rows, and the frozen
  `vessel_ais_key.parquet`'s `n_years` on all 3,352 of its segment rows.
- `tar_outdated()`: the main project empty; the `once` project lists 27, all `main_*` inputs it watches and the fixes
  downstream of them, from the rebuild of 2026-10-22 (decision 180), not from these edits: none touches `R/` or a
  targets file, and `targets` cannot see a script edit. No target needs invalidating.

## Left as they are

- Fixed bounds that are decisions, not the date of writing: `FS_DATE_MIN`/`FS_DATE_MAX` and `ADB_DATE_MIN` (decisions
  023, 125, 160), and the 2007 floors (the start of the AIS track).
- Open-end markers: `OPEN_T2` 2099-12-31 (`ais_ping_union.R`) and `OPEN` 2099-12-31 (`vessel_sign.R`,
  `vessel_year.R`, `vessel_class.R`), far enough off. `SENTINEL` 2028-12-24 is not: see below.
- Windows of complete years in checks and diagnostics, which print, plot or measure and bound no written table:
  `curate/checks/` (`gear_speed_range`, `gear_speed_by_vessel`, `gear_logbook_vs_landing`, `vessel_shifted_range`,
  `vessel_speed_range_stability`, `trail_sid_coverage`'s figure, `trail_agreement`, `port_call_logbook`'s and
  `voyage_sharing`'s printouts, `ais_residual_whacks`, `whack_floor_evaluate`'s default, `afli_rafr_stofn_loss`'s
  2003-2030 plausibility window), and `reference/vessels/registry.R`'s printed landings table (2007-2025).
- `reference/ports/port_radius.R`'s 2008-2025: the measurement window of a frozen one-time fix.
- `products/`: the ICES datacall (left out by rule), the dated ad-hoc exports, `vessel_overview/check.R`'s test
  queries and its `API_VERSION` string.

## Open

The key's open-end marker `SENTINEL` (2028-12-24, from the MMSI archive) is joined as a real end date: an open stretch
has `d2` = 2028-12-24, and `sources/stk/convert.R` and `curate/ais_ping_union.R` join `time < d2 + 1`. From
2028-12-25 every STK ping on an open stretch (3,143 of the segment table's 3,365 rows end on the marker) would lose its
vid and be dropped, the same silent loss two years later. The MMSI feeds are safe: `ais_ping_union.R` and
`curate/vessel_ais_link.R` open the last identity window themselves. TODO 128.
