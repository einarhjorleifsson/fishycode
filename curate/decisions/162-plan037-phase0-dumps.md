# 162 — Plan 037's phase 0: kvotix, vor, dwstg, fiskist and fiskifelagid dumped on the server, simalinu from the Mac

*2026-10-21 and 22. The maintainer ran the dumps; Claude (AI) wrote the scripts, copied, checked and adopted the
files, and wrote this record. The counts are Claude's and have not been checked by a person. Copy and checks:
`$FISHYDATA/archive/2026-10-phase0-dumps/` (README, `inventory.md`); simalinu: `$FISHYDATA/archive/2026-10-ivln/`.*

- **The run.** `nohup Rscript dump/oracle/all.R kvotix vor dwstg fiskist fiskifelagid` on the server at c27886a
  (ROracle, a clean tree), 2026-10-21 19:14-19:57: 150 objects, 203,129,642 rows, 3.79 GB, none failed or skipped.
  `dwstg.stg_port_notification_hst` had NUL characters in `site_name` (10 values), dropped by the dumper's refetch.
- **Copied, checked, adopted** the same evening: rsync from the share (a second dry run moved nothing); every object
  of Oracle's catalogue has an overview row and a file, rows and columns agree; moved into `raw/oracle/`;
  `tar_outdated()` the same before and after, since nothing reads them yet.

  | schema | objects | rows | what it holds |
  |---|---:|---:|---|
  | `kvotix` | 29 | 22,101,309 | the quota system's history and logs: landings' before-images, the line-incentive history, catch checks, the register's change log; ends 2020-07 |
  | `vor` | 97 | 176,889,601 | weighings, disposition, market reports, files received, auction XML; 1982 to 2020-07, but `samantekt_a_lods` to 2026-10-19 |
  | `dwstg` | 20 | 69,922 | ERS messages as staged, 2014-01 to 2018-06, with deletes and rejected rows |
  | `fiskist` | 1 | 1,803,610 | `ttrail`: 731 mobile ids over 22 hours of 2008-09-22/23, a one-off extract |
  | `fiskifelagid` | 3 | 2,265,200 | history: registers 1966-1981, landed catch 1982-1993 |

- **simalinu**, the line-fishing phone notifications, found by decision 163's study: 7 tables, 275,378 rows, none
  failed. It was dumped on 2026-10-21 at 21:14 through RJDBC from Claude's shell at the maintainer's request, before
  `dump/oracle/simalinu.R` was committed, so its stamp says `dirty = true`; a server run replaces it.
  `R/run_dump.R` takes it after `fiskist`.
- **28 of Oracle's 112 schemas are now dumped.** None of the six is read by fishycode yet; plan 037 §3.3 says which
  may serve.
- **Not ours:** `kvotix.kv_stada_saga_error_log` shows a quota job failing daily since 2020-08.
