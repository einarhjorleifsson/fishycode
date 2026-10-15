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
   in between, or the driver.
4. ROracle's fetch size (`bulk_read`) is left at its default; tune it only on a measured need.

## How (plan 018 phase 2, on the server)

- A copy of fishycode with its `.git` (no remote yet: `git bundle` or `rsync`), so the stamps name the commit.
- R with ROracle and the Oracle client, `mar`, `duckdb`, `nanoparquet`, `dplyr`, `dbplyr`, `tibble`, `yaml`;
  `$FISHYDATA` set.
- The login: `mar::connect_mar(rjdbc = FALSE)` passes only `dbname = "sjor"`, so it comes from the server's own Oracle
  setup, presumably as for the April dumps (`ops$` is Oracle's prefix for an operating-system login).
- From the repo root: `nohup Rscript dump/oracle/all.R --driver=ROracle > /dev/null 2>&1 &`, followed with
  `tail -f $FISHYDATA/raw/oracle/_logs/*_all.log`. asfis comes first, so a wrong setup stops it within minutes.
  After a failure, the same command with `--resume`.
- The whole sweep is under `raw/oracle/`, data and logs, so one copy brings it to the Mac (`rsync -a`), into
  `raw/oracle_server/`. Each schema is compared, then moved into `raw/oracle/<schema>/`. Today's RJDBC set goes to
  `archive/raw-oracle-rjdbc_2026-10-15/` until the comparison is recorded.
- The two runs still going on the Mac (ask, and kvoti in RStudio) are left to finish: they are the baseline.
