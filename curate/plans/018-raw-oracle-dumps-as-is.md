# 018 — Oracle dumps as they are: one directory per schema, every table and view, a data dictionary beside them

**status:** approved 2026-10-15; phase 1 being built · **2026-10-15** · **see:** decision 105; TODO 51; plan 016 §4 step 6

Drafted with AI assistance (Claude) on 2026-10-15, at the maintainer's request. The four choices in §2 are the
maintainer's, made the same day.

**Measured** (read-only, 2026-10-15): the dump scripts in `dump/` (§1), the readers of each raw path, the size of
kvoti (from `raw/vessels/kvoti_overview.parquet`), the disk. **Assumed:** that stk, gear, orri, asfis and
`ops$einarhj` dump as the others do through RJDBC; nothing has queried their size.

## 1. Where the dumps stand

The aim (maintainer): dump the raw data as it is, with no renames and no changes, then make the preferred format from it. Dump every table in a
schema, and keep Oracle's descriptions of the tables and fields, so that each dataset's format and meaning can be
written as a data-dict yaml.

| script | as it is? | whole schema? | |
|---|---|---|---|
| `adb`, `afli`, `fs_afladagbok`, `logbook`, `agf`, `vessels` | yes | yes | afli skips 2 tables, agf 2 views |
| `ais/stk.R` | no: renames, radians to degrees, m/s to knots | no: trail and mobile | 7 readers use the converted form |
| `lods.R`, `vessel_history.R`, `ports_kvoti.R` | lods and history yes; ports_kvoti renames, fixes names, filters | no: 3 of kvoti's 748 objects (435 tables, 60.7 M rows; 313 views) | kvoti in three places |
| `gear.R` | no: drops columns, prefixes names | no: orri and gear mixed | nothing reads `raw/gear` |
| `species.R` | yes | no | |
| `landings.R` | not a dump | | dead: it writes `staging/landings/`, which nothing reads |

## 2. Choices (maintainer, 2026-10-15)

1. **`raw/oracle/<schema>/`**, one directory per Oracle schema, named after it. Topic grouping belongs to staging and
   curated. Files from outside Oracle (Fjarskiptastofa lists, the MMSI archive, skipaskra, scrapes) stay where they are.
2. **The STK trail is dumped as it is** (`trailid`, `poslon` in radians, ...). One lazy reader in `R/`, `stk_trail()`,
   gives every reader the preferred form (`.id`, `mid`, `lon`/`lat` in degrees, knots) as a DuckDB view over raw,
   with no copy. The same goes for `stk.mobile`.
3. **Tables and views.** The adapters read views (adb `trip_v`, `vessel_v`, `aflagrunnur_v`).
4. **The data-dict yaml goes beside the data**: `_data-dict.yaml`, written by the dumper at each dump from Oracle's
   table and column comments, with types, ranges and examples from the data. The examples come from the data, so the
   yaml is handled as the data is (`company_ssn`, phone numbers).
5. **Dead scripts are removed** (maintainer).
6. **Every file carries its dump time** in its parquet metadata (`fd.dumped`, with `fd.source`, `fd.rows`,
   `fd.driver`, `fd.commit`), read by `curated_provenance()` as for curated files. The same time is in the overview
   and the yaml. It is the version marker of a dump.

## 3. Phases

**Phase 1, code (Claude):**
- extend `R/dump_oracle.R` with table comments, `tables =` (dump some objects, list all of them), `partition =`
  (a big table by calendar year of a date column, refetching a year that does not reach 31 December), the KV
  stamps, and the yaml;
- write one script per schema, `dump/oracle/<schema>.R` writing `raw/oracle/<schema>/`: adb, afli, agf,
  fs_afladagbok, logbook, vessel, kvoti, stk, gear, orri (the two `veidarfaeri` tables), asfis, ops_einarhj (the
  tables named, not the whole personal schema);
- remove `landings.R`, `astd_class_b.R` and the dead copies under `raw/`, and fold `lods.R`, `vessel_history.R`,
  `ports_kvoti.R`, `species.R`, `mmsi_snapshots.R`, `vessels.R` and `ais/stk.R` into the scripts above;
- check it on a DuckDB mock.

**Phase 2, the dumps (maintainer's terminal):** every script once. The trail's 20 years take roughly 2-3 h (2026's
20.6 M rows took about 10 min). Disk: 188 GB free; the as-is trail is about 9 GB beside the old one.

**Phase 3, the readers (Claude):**
- about 25 reader files move to `fd_raw("oracle", ...)`, and the trail's 7 readers to `stk_trail()`;
- `ports_kvoti.R`'s renames and fixes move into `reference/ports/harbour_codes.R`. The frozen bootstrap keeps its
  file until the once project is redone;
- checks: `stk_trail()` over the new dump against the old trail by `.id` (time, position, speed, heading, port, in
  and out), every year. Each adapter run into scratch against its current staging;
- then the old directories go to the Trash, and a decision record is written. **Except** an old dump that holds rows
  the new one lacks: compare table by table first. Oracle's `logbook` schema was rebuilt, with new ids, after the copy
  in `raw/logbooks/logbook/` (files of 2026-04-09, rows entered to 2025-11-18; the rebuild's to 2025-12-05).
  - **The old copy:** 1.85 M trips, 1950-2025, from `afli.stofn` and `afladagbok.veidiferd`.
  - **Now:** 1.10 M trips, 1950-2020, from `afli.stofn` only. `catch` has 3,581,193 rows against 17,062,085, and
    `station` 1,262,920 against 7,092,122, all from `afli.lineha` and 85 % without a time. `trawl`, `seine_net`,
    `dredge`, `trap` and `diving` are empty, and columns were renamed (`headline` to `headline_length`).
  - **Ids are renumbered:** trip 607697 was a 2002 trip and is now a 2015 one. So the two copies cannot be compared
    row by row.

  The old copy is kept. Nothing reads it.

**Phase 4:** the rebuild, together with plan 016's (maintainer's go). The raw inputs are not declared in
`_targets.R`, so the targets that read them are invalidated by hand, or the raw-dump-targets session declares them.
