# 109 — The Oracle dumps are redone on the server, through ROracle

*2026-10-15. Written by Claude (AI-assisted); the choice is the maintainer's ("running the whole thing from scratch
over the server, and potentially using ROracle", then "prepare the dumper for a full rerun on the server with
ROracle"). Supersedes 106 for the server. Plan 018, TODO 66.*

## Why

**Speed, measured 2026-10-15 at about 21:50.** The dumps run from the Mac over Wi-Fi (802.11n on 2.4 GHz, signal
−70 dBm, transmit rate 57 Mbit/s) and the VPN (`utun4`; round trip to the database server 6-249 ms, mean 92). They
were bound by the network, not the CPU or the driver:

| | received | on disk as parquet | rate |
|---|---|---|---|
| ask (`run_dump()`, 2 h) | 11.0 GB | 2.6 GB | 1.7 MB/s, R at 42 % of a core |
| kvoti (RStudio, since 18:40) | about 5 GB | 1.8 GB | 0.8 MB/s |

RJDBC already fetches 2,048 rows per round trip (its `block`, passed to JDBC's fetch size). On the server the round
trips stay on the institute's network, and only the parquet travels to the Mac, a quarter to a third of the bytes,
in one stream.

**The driver.** Most of what decision 105 had to fix belongs to RJDBC's Java layer: the 8 GB heap, the JVM's time
zone, NUMBER returned as text, the parse failure behind the text retry, LOBs fetched one row at a time. ROracle uses
Oracle's own client library. The April dump made with it on the server holds `afli.afladagb_xml_mottaka`, one of the
LOB tables RJDBC could not fetch in time.

**Timing.** Plan 018 phase 3 has not started: no reader uses `raw/oracle/` yet, so nothing downstream depends on
which driver wrote it.

## What this supersedes

Decision 106 chose RJDBC among the drivers that run on the Mac (python-oracledb, DuckDB's `oracle_scanner`, Instant
Client's ODBC driver). ROracle on the server was not among them. Its findings stand: on the Mac RJDBC is still the
only driver that logs in (ROracle is installed there but finds no Oracle client library), and it stays the default.

## What was built (code only; nothing has run against Oracle)

- `dump_connect(driver = )`, from `FD_DUMP_DRIVER`, RJDBC by default. ROracle: `TZ` and `ORA_SDTZ` set to UTC before
  connecting, and the connection's driver checked, since `mar::connect_mar()` falls back to RJDBC without a word
  when ROracle is missing.
- `.oracle_check_time()`, for both drivers: a DATE of 1900-01-01 12:00:00 goes through the driver and DuckDB as a dump
  writes it, and the dump stops if it comes out otherwise. Tested on its three possible inputs: a date-time in UTC
  passes, one read through Atlantic/Reykjavik fails (12:16:08), text passes.
- `skip_rjdbc` in `dump_oracle_schema()`: left out through RJDBC only. afli's three LOB tables, fs_afladagbok's
  `takt_json_form` and agf's `aflagrunnur_th_igildi_v` (a Java exception). Oracle's own BLOB tables and agf's secured
  view stay in `skip`.
- `run_dump(schema, driver = "ROracle")` sets `FD_DUMP_DRIVER`, `TZ` and `ORA_SDTZ` for the background run. With
  `wait = TRUE` it now records its own process id, so `dump_status()` and the guard against a second run see it.
- `dump/oracle/all.R` and `run_dump_all()`, for the server (the maintainer's design: "checks if a directory exists and
  if not creates it, has the full log and can be run as a nohup"): every schema in turn, asfis first and stk last,
  each through `run_dump(wait = TRUE)` with its full log in `raw/oracle/<schema>/_logs/`, and the run's own log in
  `raw/oracle/_logs/<time>_all.log`. It creates `$FISHYDATA`, `raw/oracle/` and each schema's directory when missing,
  and stops at the first schema whose script fails as a whole (no login, the date check); a failed table is only
  recorded. Tested end to end under `nohup` on a scratch repo with stand-in schema scripts: directories created,
  driver and time zones passed, a failing schema stops the run, named schemas work.
- Resume after a failure (the maintainer: "in case of failure, the nohup call can resume"): the same command with
  `--resume`. A schema whose last run exited 0 with nothing failed, through the same driver, is skipped. Any other
  keeps each table an earlier run of the same driver completed and dumps the rest (`.dump_kept()`). Completed now
  means the file's own footer stamps (`fd.rows`, `fd.driver`), not only the overview, which a run writes at its end:
  the kvoti run killed or stopped before its end would otherwise be redone whole. A file cut off mid-write has no
  readable footer and is redone; a year of a partitioned table likewise. Tested: eight cases of `.dump_kept()` on
  files written by `.write_raw()` (complete, cut off, the other driver, in an overview or not, partitioned), and a
  failed `all.R` run resumed end to end (the clean schema skipped, the one with a failed table and the failed one
  rerun with `--resume`, the rest run).
- `compare_dumps(a, b)` (`R/compare_dumps.R`): two dumps of a schema, table by table (per year when partitioned):
  rows, driver, columns, types, the rows each lacks (EXCEPT ALL) and the columns that differ. Two date-times are
  compared as UTC instants, two numbers as doubles. Tested on mock dumps. On real data, the April ROracle copy of five
  afli tables (`raw/logbooks/afli/`, 1,470 to 3,625,502 rows) against today's RJDBC dump: the same rows and values in
  all five. The only difference is the April copy's `TIMESTAMP WITH TIME ZONE` where the dumper writes plain
  `TIMESTAMP`. The April copy was written by another script, so this compares the drivers' values, not the file
  types.

## Before the server dumps replace these

1. The `afli.afli` query (plan 018 §3). ROracle read the table that RJDBC could not, and the April copy has 48 empty
   `afli` values: ROracle may write NULL for a malformed stored NUMBER where RJDBC fails.
2. asfis first (3 tables, minutes), then `compare_dumps()` against `raw/oracle/asfis/`: expected the same.
3. Every schema compared with today's RJDBC dump before it replaces it, and each difference explained: Oracle changed
   in between, or the driver. *Revised 2026-10-16 (maintainer): in full for the first seven (asfis, gear, orri,
   vessel, ops_einarhj, logbook, ask), which found the decimal and column-name faults and nothing else; for kvoti,
   adb, fs_afladagbok, afli and stk the light check, `compare_dumps(values = FALSE)` (rows, columns and types per
   table) and the overview's failures, with a full comparison only where those look wrong. The same code reads them
   all, and stk has no Mac copy to compare with.*
4. ROracle's fetch size (`bulk_read`) is left at its default; tune it only on a measured need.

## How (plan 018 phase 2, on the server)

- A copy of fishycode with its `.git` (no remote yet: `git bundle` or `rsync`), so the stamps name the commit.
- R with ROracle and the Oracle client, `mar`, `duckdb`, `nanoparquet`, `dplyr`, `dbplyr`, `tibble`, `yaml`; a
  `.Renviron` at the repo root with `FISHYDATA=` and `LANG=en_US.UTF-8`.
- The code reaches the server through GitHub: `git clone` (maintainer, 2026-10-16), the repo pushed first.
- The login: `mar::connect_mar(rjdbc = FALSE)` passes only `dbname = "sjor"`, so it comes from the server's own Oracle
  setup, presumably as for the April dumps (`ops$` is Oracle's prefix for an operating-system login).
- First `Rscript dump/oracle/all.R --check`: packages, `$FISHYDATA` and its free space, R's locale, the commit, then
  a login with the date and text checks and each schema's objects; it dumps nothing.
- Then, from the repo root: `nohup Rscript dump/oracle/all.R > /dev/null 2>&1 &` (ROracle is `all.R`'s default since
  2026-10-16, the maintainer's "run via rjdbc set to FALSE"), followed with
  `tail -f $FISHYDATA/raw/oracle/_logs/*_all.log`. asfis comes first, so a wrong setup stops it within minutes.
  After a failure, the same command with `--resume`.
- The whole sweep is under `raw/oracle/`, data and logs, so one copy brings it to the Mac (`rsync -a`), into
  `raw/oracle_server/`. Each schema is compared, then moved into `raw/oracle/<schema>/`. Today's RJDBC set goes to
  `archive/raw-oracle-rjdbc_2026-10-15/` until the comparison is recorded.
- The two runs still going on the Mac (ask, and kvoti in RStudio) are left to finish: they are the baseline.

## Found 2026-10-16: dates before 1912 in the RJDBC dumps are 16 min 8 s late

The date check stopped the resumed ask and kvoti runs at their start: a DATE of 1900-01-01 12:00:00 would be
written as 12:16:08, with the JVM in UTC. The decision-105 fix (the JVM in UTC) was therefore not enough. Current
time-zone data give Atlantic/Reykjavik an offset of −0:16:08 before 1912 and none after, so only earlier dates move.

Measured on the dumps of 2026-10-15: 84 files (adb 10, afli 11, agf 1, ask 5, fs_afladagbok 4, kvoti 29, logbook 2,
vessel 22), 132 date columns and 2,797,887 values before 1912, every one ending in 16:08. Most are placeholder dates:
`1900-01-01 00:16:08` and `1860-01-01 00:16:08` in the vessel tables, `0001-01-01 00:16:08` in adb's `registered`,
`1899-12-30 00:16:08` in afli's logger times. An equality on such a placeholder fails silently. No reader uses
`raw/oracle/` yet (plan 018 phase 3).

RJDBC hands dates to R as text, so the shift is in the JDBC layer or in R's reading of that text; which one is not
established without a connection. The dump process now runs in UTC from its start, R included, for both drivers
(`dump_connect()`, `run_dump()`), and the check says what the driver returned, so its next run either passes or
names the layer. The 84 files are to be redone: on the server through ROracle, which replaces them all, and the
comparison will show these columns as differences.

## Added 2026-10-16 for the server run

- **Icelandic letters.** ROracle's text passes through Oracle's client, which converts it to the character set of
  `NLS_LANG`, commonly plain ASCII when it is unset: þ, æ, ö and ð would come out as `?`. `dump_connect()` and
  `run_dump()` set `NLS_LANG=AMERICAN_AMERICA.AL32UTF8` (UTF-8, and a decimal point in the text retry's `TO_CHAR`),
  and `.oracle_check_text()` stops a ROracle dump whose letters made in Oracle (`UNISTR`) do not come back as UTF-8.
  Tested with stubbed answers: UTF-8 and latin1 pass, `????` stops. The RJDBC dumps carry the letters (1,604 of
  vessel's 7,047 names), so `compare_dumps()` will show any loss.
- **`dump_check()`**, `all.R --check`: run on the Mac through ROracle it reported the packages, locale,
  `$FISHYDATA`, 170 GB free and the commit as ok, and the connection as not ok (no Oracle client library here),
  before any login.
- **One default driver per machine.** `FD_DUMP_DRIVER=ROracle` in the server's `.Renviron` makes ROracle the
  default of `dump_connect()`, `run_dump()`, `run_dump_all()`, `dump_check()` and `all.R` (which falls back to
  ROracle itself); the Mac sets nothing and keeps RJDBC. Tested on stand-in scripts: `all.R` alone, with
  `FD_DUMP_DRIVER=RJDBC`, and `run_dump()` from R under such a `.Renviron` each reached the schema script with the
  driver meant.
- **`dump/oracle/README.md`**: the steps on the server, from the clone to the copy back and the comparison, from
  the shell and from R, a whole run or one schema (the maintainer asked for a readme with the `nohup` command).
- **First run on hafdruna, 2026-10-16.** `all.R --check` passed: ROracle 1.5.1, the 1900 DATE exact in UTC, þæöÐ
  intact, all 13 schemas visible with the Mac's object counts. The run then stopped at asfis within a second:
  `oracle_fields()` read `SYS.ALL_TAB_COLUMNS` through dbplyr with `SELECT *`, and its `DATA_DEFAULT` is a `LONG`,
  which ROracle refuses ("unsupported column type"; RJDBC had read it as text). It now names its columns, and
  `--check` reads each schema's columns too. Tested on a stand-in catalogue in DuckDB built from kvoti's column
  list: the same 7,740 rows and values. The data tables hold no `LONG` (the twelve schemas the Mac dumped have
  NUMBER, VARCHAR2, DATE, CHAR, CLOB, BLOB, TIMESTAMP, XMLTYPE, SDO_GEOMETRY; stk is not known), and a BLOB in
  ROracle's form (a list of raw vectors) writes as a parquet BLOB.
- **First comparison, 2026-10-16:** the six schemas the server had finished (asfis, gear, orri, vessel, ops_einarhj,
  logbook) against the Mac's RJDBC dumps of the day before. 46 of 70 tables identical; every table the same rows and
  column types. The rest differ in two ways. Dates before 1912 (the Mac's 16 min 8 s, as known). And decimal
  numbers one step apart (1 ulp, relative 2e-16): `power_kw` 60.3 came through ROracle as 60.3000000000000043, where
  RJDBC gave 60.2999999999999972, the nearest double; 198 of vessel's 7,047 rows, and logbook station's positions.
  RJDBC is right. Through ROracle a NUMBER whose scale is not 0 is now fetched as `TO_CHAR`, the exact decimal, and
  turned into the nearest double in R (`.oracle_query()`, `.oracle_numbers()`); a whole NUMBER is exact either way.
  Tested with DuckDB standing in for Oracle: 60.3 comes out equal to 60.3, whole numbers stay integers. The server's
  first run, made before this, is to be set aside and redone from the start.
- **Second comparison, the run on 8e3778f** (the same six schemas): the decimal fix holds; `power_kw`, `length` and
  logbook's positions now equal the Mac's. Left: dates before 1912 (the Mac's 16 min 8 s; in logbook exactly its 47
  such values), and a few values of two NUMBER columns without a declared precision (`auxiliary_engine_powerkw`,
  `brutto_weight_tons`), where the server now holds the double nearest Oracle's decimal (`53.09999847412109`) and the
  Mac's RJDBC is a step off (exactly float32's 53.1). One table failed: ops$einarhj's `mmsi_icelandic_registry`,
  ORA-00904 `"STADUR"`: a column made with quotes keeps its lower case (`stadur`), and the explicit column list the
  decimal fix needs had upper-cased every name. `oracle_fields()` now keeps Oracle's own spelling
  (`oracle_column`) and the query quotes it as it is; ask has two column names with Icelandic letters
  (`er_línuívilnun_heiti`, `er_lokuð_heiti`) that need the same. Tested with DuckDB: `"stadur"` and
  `"ER_LOKUÐ_HEITI"` quoted as they are, the files' names in lower case. A failed table is recorded and the run goes
  on, so after it, `--resume` with this fix redoes only the failed tables.
- **`dump/oracle/sync.sh`**: on the Mac, it copies each schema from the share to `raw/oracle_server/` as soon as its
  run has ended (its `.exit` file appears). It watches for new files, not the run's log, because the macOS SMB client
  showed `_all.log` without the lines the server had appended since. Tested on local stand-ins (copies as schemas
  finish, stops at the end or at a schema that failed as a whole); on the real run it had the six small schemas on
  the Mac within two minutes of their end.
- **ask, server against Mac (2026-10-16):** of the 220 tables both runs reach, 165 are identical, 47 the Mac never
  got, none only on the Mac. The 8 others differ in one column each: `gildir_fra`/`gildir_til` placeholder dates
  (`1901-01-01` against the Mac's `00:16:08`; two year-13 typos also differ by 2 days, Java counting dates before
  1582 in the Julian calendar), and `magn_oslaegt`, decimals one step apart, as in vessel. Of the server's 15 failed
  objects, 13 are views guarded by `ask.valin_hofn` (ORA-20290, no chosen ports for this login), now in ask.R's
  `skip`; the other 2 are column names Oracle keeps as quoted (one begins with an apostrophe, `'STADA_HEITI`), for
  `--resume` with the name fix.
- **Views are counted before they are fetched (2026-10-16).** stk's run went silent for hours on its views: a view has
  no row estimate, so the `max_rows` rule for tables did not apply, and views of the whole trail were fetched whole
  into memory (`stk_vms_v`, 303,784,194 rows, was written; `trail_all`, `view_trail` and seven others were left).
  `dump_oracle_schema()` now counts a view first and lists one over `max_rows` (50 M) as `too_big`, its count kept.
  The trail itself is dumped by year. Tested on a stand-in schema in DuckDB.
- **A test reached the real database once (2026-10-16).** The stand-in lacked Oracle's `DUAL`, so the dumper took the
  test for a lost connection and reconnected through `dump_connect()`, which the keychain now answers without a
  prompt; it ran read-only queries on tables that do not exist. The reconnect is now an argument (`connect =`), and
  a dumper test replaces `dump_connect()` with one that refuses.
- **The view count never fired (found 2026-10-16).** Oracle names an unquoted alias in capitals: `COUNT(*) AS n` came
  back as `N`, `$n` was NULL, and no view was ever too big. The DuckDB stand-in keeps the alias as written, so the
  test passed. stk's resume (commit c9f596a) fetched `trail_all` (303,790,717 rows) and `view_trail` (303,791,859,
  8.4 GB) whole. Both stay on the server, as `stk_vms_v` does, left out of the Mac's copy (`SYNC_EXCLUDE`). The count
  is now read by position.
- **afli.afli and v_afli through ROracle (2026-10-16).** Both still failed on the server with ORA-01722, now in the
  `TO_CHAR` that reads decimals exactly. `dump_oracle_table()` finds the columns whose `TO_CHAR` fails, one scan
  each (`MAX(LENGTH(TO_CHAR(col)))`), and reads only those as ROracle returns them, as the April dump did. Which
  columns, and how many of their values Oracle counts but the fetch left empty, goes in the file's `fd.note`, the
  overview's new `note` column and the table's `details` in `_data-dict.yaml`. Tested on a DuckDB stand-in whose
  `TO_CHAR` fails on one value. A resumed run keeps the note, from the overview or from the footer.
  *Run on hafdruna (d1520dc, 2026-10-16):*
  - **The column was `visir`,** in both, as expected: it is the only decimal in v_afli. No `visir` value came through
    empty, and its values are exactly the April copy's: the same multiset of 15,674,405, none infinite, NaN or
    fractional. So a value `TO_CHAR` rejects reaches R through ROracle as a number.
  - **Which values those are is still open.** 302 are above 10^9 (largest 10,630,176,826) and 4,064,218 are negative.
    The query in plan 018 names the rows.
  - **The 48 empty `afli` values are the same 48 as in April**, on 46 stations. `afli` is a whole NUMBER, read natively
    by both dumps, so they are not this fault.
- **Light check of kvoti, adb, fs_afladagbok and afli (2026-10-16)**, server against Mac, rows, columns and types:
  - **No column or type differs.** Where both have a table and the rows differ, the server has more rows, never
    fewer: kvoti 59 tables, adb 16. That is a day of Oracle's new records.
  - **kvoti:** 488 of 742 identical. 193 objects are only on the server: the Mac's RStudio run was stopped before its
    end, with no overview written. Two are only on the Mac: `adili_jn` (156,364 rows) and `eftirlits_gjald_utan_ees`
    (5,472). ROracle fails on them with "embedded nul in string": a text value holds a NUL character, which an R
    string cannot. The Mac's RJDBC copies hold them. Oracle fails three views itself, the same on both: ORA-01843 in
    their own code, and ORA-04063 "has errors" for `vinnsluadili_v` and `vinnsluadili_vadili_fteg_v`. `della_post` is
    ORA-00942, a table this login may not read.
  - **fs_afladagbok:** 32 identical. `takt_json_form` fails through ROracle with an embedded NUL (PDF bytes in it); RJDBC
    skipped it.
  - **afli:** 287 identical. `afladagb_xml_mottaka` and `ra_email_skeyti` are on the server only: the LOB tables RJDBC
    skipped. Failed: `afli` and `v_afli` (ORA-01722, the fallback above), and `rafr_mottaka_view` and `urv_raekja`
    (ORA-01843 in Oracle's own view code).
- **stk's silences were one view (2026-10-16).** Both stk runs went quiet on `tilk_stk_por_v`, departures paired with
  arrivals. The first run's last line was at 12:49 and nothing followed until it was stopped after 15:00; the resume
  was quiet from 16:03 with every other object written. Oracle does not finish evaluating that view in hours, so
  `dump/oracle/stk.R` skips it, as it does `toti2_mobile_skip_v` (ORA-00942, an object it reads is not there for this
  login). `tilk_stk_allt` holds voyages, each a departure and its arrival (TODO 68). The big trail views were
  slow too, but they finished.
- **The sweep is on the Mac (2026-10-16).** The server's last resume (d1520dc) ended with 13 of 13 schemas exited 0.
  `raw/oracle_server/` matches the server's `raw/oracle/` file for file (an rsync dry run lists nothing). The
  exceptions are stk's three copies of the whole trail (`stk_vms_v`, `trail_all`, `view_trail`, 26.2 GB), left on
  the server. stk has no Mac copy to compare with, so its light check is the dump against itself:
  - 61 objects written and 2 skipped; every file reads back with the rows the overview records.
  - The trail holds 303,795,653 positions, 2003-09-26 to 2026-10-16 17:15.
  - 40 of 42 tables are within 5 % of Oracle's row estimate. `error_log` and `mobile` are 8 % and 10 % above theirs,
    estimates older than the rows.
