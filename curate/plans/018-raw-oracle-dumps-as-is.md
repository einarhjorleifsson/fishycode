# 018 — Oracle dumps as they are: one directory per schema, every table and view, a data dictionary beside them

**status:** executed 2026-10-16 (phases 1-4: the server dump in `raw/oracle/`, every reader on it, decision 111; the rebuild, decision 112) · **2026-10-15** · **see:** decisions 105, 106, 109, 111, 112, 113 and 116 (the inputs declared); open: TODO 70; TODO 51; plan 016 §4 step 6

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

**Phase 2, the dumps:** done 2026-10-16. Every schema was dumped on hafdruna through ROracle and copied into `raw/oracle/`; the Mac's RJDBC dumps described below were checked against it and moved to the Trash (decision 109). As planned: every script once. The trail's 20 years take roughly 2-3 h (2026's
20.6 M rows took about 10 min). Disk: 188 GB free; the as-is trail is about 9 GB beside the old one.
Where it stands, 2026-10-15 evening:
- **Dumped:** adb, logbook, fs_afladagbok, gear, asfis, ops_einarhj, orri, vessel, agf.
- **afli, resumed:** finished, 88 written, 5 skipped (the LOB tables), 3 failed: `afli`, `v_afli` (below) and
  `urv_raekja` (ORA-01843, not a valid month: a date in the view itself).
- **ask:** added (7c96ad7) because fs_afladagbok's gear codes refer to `ASK.VEIDARFAERI`. Its `_jn` tables look like
  change journals and may name staff. Stopped 2026-10-16 at 06:29 with 173 of 235 written: the Mac's network dropped
  after 23:00, and the reconnect waited on a keychain prompt nobody answered.
- **Dates before 1912 are 16 min 8 s late** in 84 files of these RJDBC dumps (decision 109); the process now runs in
  UTC, and the date check stops a dump that would shift them.
- **kvoti:** an RStudio run started 18:40 with the dumper before `run_dump()`; stuck after 22:59 (the same network
  drop) with 549 of 748 written, and stopped. A resume keeps every complete file (`.dump_kept()`).
- **Not run:** stk.
- **Driver:** RJDBC on the Mac (decision 106). Dumps run through `run_dump()`, one process per schema. Two runs of
  one schema write the same files: `run_dump()` refuses a schema whose run is still alive (since 2026-10-15, after two
  ask runs went into one directory). A dump started by hand is not seen.
- **Redone on the server, through ROracle (decision 109):** the Mac's dumps were bound by Wi-Fi and the VPN. The code
  is ready, not yet run against Oracle: on the server, `Rscript dump/oracle/all.R --check`, then
  `nohup Rscript dump/oracle/all.R &` runs every schema through ROracle with its logs under `raw/oracle/` (after a
  failure, the same with `--resume`), and `compare_dumps()` checks each against today's RJDBC dump before it replaces it.
  The runs on the Mac (ask; kvoti in RStudio) finish as the baseline.

**`afli.afli` holds numbers neither fetch can read (2026-10-15).** It is the logbook's catch table (15,674,405 rows,
the same count as the April copy). The first fetch failed in the driver (`ArrayIndexOutOfBoundsException: Index -1
out of bounds for length 21`, converting a NUMBER); the retry, with every NUMBER as `TO_CHAR`, failed in Oracle
itself (ORA-01722, invalid number). `TO_CHAR` of a valid NUMBER cannot raise ORA-01722, so most likely some stored
NUMBERs are malformed bytes. `v_afli` (four of its columns, the same rows) fails the same way. The April copy in
`raw/logbooks/afli/` (ROracle on the server) read every row and holds nothing odd, except 48 rows (46 `visir`) with
an empty `afli`: where ROracle turned malformed numbers into NULL? Not shown. It stays the copy `sources/afli` reads
until the rows are found.

Asked of the maintainer: run this in R (`con <- dump_connect()`). It fetches no raw NUMBER, only `DUMP()`, which shows
the stored bytes and never fails, and returns the rows where `TO_CHAR` fails on any column (one full scan, a few
minutes):

```r
DBI::dbGetQuery(con, "
WITH FUNCTION bad(x NUMBER) RETURN NUMBER IS s VARCHAR2(200);
  BEGIN s := TO_CHAR(x); RETURN 0; EXCEPTION WHEN OTHERS THEN RETURN 1; END;
SELECT ROWIDTOCHAR(ROWID) AS rid,
       CASE WHEN bad(visir) = 0 THEN TO_CHAR(visir) END AS visir,
       DUMP(visir) AS d_visir, DUMP(sokntegund) AS d_sokntegund, DUMP(tegund) AS d_tegund,
       DUMP(afli) AS d_afli, DUMP(medalthyngd_gr) AS d_medalthyngd_gr, DUMP(magn) AS d_magn
FROM afli.afli
WHERE bad(visir) + bad(sokntegund) + bad(tegund) + bad(afli) + bad(medalthyngd_gr) + bad(magn) > 0")
```

Then: are they the 48 empty rows of the April copy, and can the dump read them as text (`DUMP`) and the rest as
numbers?

*The dump reads it now (2026-10-16, hafdruna).* Through ROracle the dump's own `TO_CHAR` of the decimals failed
too (ORA-01722, afli and v_afli). `dump_oracle_table()` now finds the columns whose `TO_CHAR` fails and reads only
those natively, as the April dump did, with a note in the file, the overview and `_data-dict.yaml` (decision 109).
The column is `visir`, none of its values came through empty, and they match the April copy's exactly. The query
above still shows which rows and bytes `TO_CHAR` rejects. The 48 empty `afli` values (46 stations) are in both copies.

**Phase 3, the readers (Claude):** *done 2026-10-16, decision 111.* 34 scripts and pages and `_targets.R` read
`raw/oracle/`; the trail's 12 readers (not 7) read it through `stk_trail()` (`R/stk_trail.R`). `harbour_codes.R` also
reads the base table `agf.aflagrunnur`, which adds code 168. Both targets projects run in UTC, as nanoparquet reads a
plain TIMESTAMP in the session's zone. Each adapter ran into scratch on the old copies and on the dump; their
differences are Oracle's latest day, the old copies' known faults (RJDBC's 16 min 8 s and Julian dates, last-digit
decimals) and code 168. The trail matched by `.id` in every year. The old directories are in the Trash, except
`raw/logbooks/logbook/` (below) and the frozen bootstrap's `ports_kvoti.parquet`.
As planned:
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

**Phase 4:** *done 2026-10-16, decision 112: all 50 targets in one pass, every change traced.* The rebuild, together with plan 016's (maintainer's go). The raw inputs are not declared in
`_targets.R`, so the targets that read them are invalidated by hand, or the raw-dump-targets session declares them.
