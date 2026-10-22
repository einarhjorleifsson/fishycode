# 175 — The port codes and the vessel register are read from their tables, not `agf.aflagrunnur_v` and `vessel.vessel_v`

*2026-10-22. The maintainer's rule "Oracle tables, not views" (AGENTS.md, Rules; TODO 120), applied to the five
main-project readers still on a view. Written by Claude (AI) in a session started from another Claude session; the
code, the scratch runs and the overlay entries are Claude's and have not been checked by a person. Decided and
committed, not built: the rebuild is the maintainer's (`$FISHYDATA/archive/2026-10-rebuild-prep/README.md`). The views
were rebuilt from their tables the same day, read-only (`$FISHYDATA/archive/2026-10-views-todo120/`). Dumps of
2026-10-16 (agf, ask, vessel). **Extended the same day:** adb's legacy reader deleted, at the maintainer's word.*

## Found

Both views equal their rebuild from their tables, row by row: `agf.aflagrunnur_v` 5,231,306 rows, none differing, and
`vessel.vessel_v` 7,047, of which 4 differ in the engines' power sum by 6e-14 kW. So neither hides a conversion. What
matters is what the joins drop and what the readers take.

- `aflagrunnur_v` inner-joins `aflagrunnur` to 13 code and party tables in `ask` and `ufs`. Its party and vessel joins
  drop landings (a seller missing from `ufs.adilar` alone drops 112,040 rows; the view lacks 24 % of 2026's), and
  with them code 168 (Bretland, one landing row). Its two readers take only the port code, its name and the landing system's own id,
  which come from `ask.londunarstadir`. `harbour_codes.R` patched 168 back in with a `full_join` on the table;
  `port_code.R` did not, so `port_code.parquet` lacked it.
- `vessel_v` is `vessel` LEFT JOIN `vessel_operational`, `vessel_identification`, `vessel_measurement` and
  `vessel_fishery`, each one row per vessel, with the engines counted and summed from `vessel_engines`. Oracle sums
  the stored NUMBERs exactly; `power` has no declared scale but at most two decimals, so a sum of doubles rounded to
  two decimals equals the view on all 7,047 vessels. `vessel_fishery` holds the owners' kennitala, names and
  addresses, which no reader uses.

## Chosen

- `reference/ports/harbour_codes.R` and `reference/ports/port_code.R` read the distinct `hafnarnumer` of
  `agf.aflagrunnur` and LEFT JOIN `ask.londunarstadir` for `id` (the old `hafnarnumer_id`) and `heiti`: 79 codes, every
  one named. The `full_join` patch is gone.
- `reference/vessels/mmsi.R` reads `vessel` (only `valid_from`, the register's last change).
- `reference/vessels/vessel_year.R` reads `vessel` and `vessel_measurement` (`max_length`).
- `reference/vessels/registry.R` reads `vessel`, `vessel_identification`, `vessel_measurement` and `vessel_engines`,
  counting the engines (0 where there is none, as the view's `count(*)`) and summing their power rounded to two
  decimals (NA where none has a value, as Oracle's `SUM`).
- None reads `vessel_operational` or `vessel_fishery`. In `_targets.R`, `port_raw` and `port_code_raw` list
  `aflagrunnur` and `londunarstadir`, and `vessel_raw` the four vessel tables.
- `docs/data-dict.yaml` says where `port_code.hid_new`, `port_code.port` and `port.hafnarnumer_id` come from; the last
  was marked "ungrounded".
- Plan 040's overlay (format of 53f4fbf): `dump/oracle/meta/agf.yml`, `ask.yml` and `vessel.yml` hold these readers'
  columns, with labels, units (kW, m, GRT, GT, NT), keys, the `status` codes as an enum, the joins, and two asserts
  (power and length overall at most two decimals). Laid over scratch copies of the three dumps' dictionaries with
  `rewrite_data_dict()` and checked with `check_data_dict()` (that session's `R/data_dict.R`, not yet committed):
  no spec error, every data check passing.

## Checked

HEAD's five scripts and the new ones, each run into its own scratch `$FISHYDATA` (`raw/`, `staging/ports`,
`staging/hreidar` and `curated/vessel/register` linked), in targets' order with its packages attached, every output
compared row by row (`EXCEPT ALL` both ways, every column) with the build in the real store:

| Output | Rows built | HEAD on scratch | New on scratch |
|---|---|---|---|
| `curated/reference/port_code.parquet` | 78 | identical | 79: code 168 added (Bretland, `hid_new` 136) |
| `curated/reference/port.parquet` | 113 | identical | 113: row 168 gains `hafnarnumer_id` 136; `port` (Bretland) and `pid` (none) unchanged |
| `curated/vessel/mmsi.parquet` | 4,228 | identical | identical, in the same order |
| `curated/vessel/vessel.parquet` | 7,249 | identical | identical, in the same order |
| `curated/vessel/vessel_year.parquet` | 140,940 | identical | identical, in the same order |

HEAD's run equal to the build shows that nothing else moved since it was built: the kvoti and ops$einarhj re-dump of
2026-10-22 left `kvoti.stadur` and every ops$einarhj table unchanged in content (decision 167's adoption).

What the new `hafnarnumer_id` moves downstream: only `sources/fs_afladagbok/convert.R` reads it, to map the e-logbook's
port ids to codes, and none of fs_afladagbok's 207,189 trips has port id 136. `port_code.parquet` has no reader in
the build. So the switch changes no other output; it outdates `port_code_raw`, `port_code` and `vessel_raw` beside
the 59 targets the re-dump had outdated (62 in all), whose rebuild is one build. `find -newer` on the real store after
the runs: nothing written outside `archive/2026-10-rebuild-prep/`.

## adb's legacy reader deleted

The scan of every script for the views it reads found one more outside the build: `sources/adb/convert_brute_force.R`,
an alternative adb reader migrated from `~/stasi/logbooks` (`01_adb_convert_brute-force.R`, decision 001's file
migration) and "kept for reference" (`docs/source-schemas.md`). It read seven of adb's views (`trip_v`, `station_v`
and five gear views) from `staging/data-dump/`, which no longer exists, so it could not run. No target, script or page
used it. The maintainer said to delete it (2026-10-22), and `docs/source-schemas.md` no longer names it; git history
keeps it. `sources/adb/convert.R` is adb's one reader, on tables since decisions 165 and 170.

## Left open

- The three readers in the `once` project (`curate/checks/ais_key_segments.R` on `vessel.vessel_hist_v`,
  `reference/vessels/skipaskra_evidence.R` and `curate/checks/skipaskra_discrepancy.R` on `kvoti.strandveidileyfi_v`):
  switched only at a redo, by decision (TODO 120).
- The rebuild (TODO 119), prepared in `$FISHYDATA/archive/2026-10-rebuild-prep/`.
