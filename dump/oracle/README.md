# Dumping the Oracle schemas on the server

*Written with Claude (AI-assisted), 2026-10-16. The why is in
`curate/decisions/109-oracle-dumps-redone-on-the-server-with-roracle.md`; the plan is
`curate/plans/018-raw-oracle-dumps-as-is.md`.*

The dump writes every table and view of every schema in `dump/oracle/` to `$FISHYDATA/raw/oracle/<schema>/`, as
Oracle holds them, through ROracle. The logs sit in the same tree, so copying `raw/oracle/` copies the whole sweep.
A full run takes hours: start it with `nohup`, from the shell or from R, and leave it.

The schemas, in the order a full run takes them: asfis, taxon, fs_ufs, uv, rdbes, dw, dwstg, fiskist, simalinu, ufs, gear,
orri, vessel, channel, ops_einarhj, ops_sigfus, logbook, fiskifelagid, agf, ask, vor, kvoti, kvotix, adb, fs_afladagbok, afli,
fs_afli, biota, stk (dwstg, fiskist, fiskifelagid, vor and kvotix first run 2026-10-21 on the server for plan 037's phase 0; simalinu that
evening through RJDBC from the Mac; decision 162; ops_sigfus added 2026-10-23, not yet run). Each is one script,
`dump/oracle/<schema>.R`, which says what it leaves out and why. `catalogue.R` and `code.R` are not schemas: the first
lists what else Oracle holds (section 13), the second keeps the SQL behind each dumped schema (section 14).

## 1. Get the code

```bash
git clone https://github.com/einarhjorleifsson/fishycode.git
cd fishycode
```

Later changes: `git pull` in the same folder. Every command below runs from this folder, and R must start in it
too (in RStudio: open it as the project).

## 2. Settings for this machine

Make a file called `.Renviron` in the fishycode folder with these three lines (your own path in the first):

```
FISHYDATA=/path/to/fishydata
LANG=en_US.UTF-8
FD_DUMP_DRIVER=ROracle
```

`FISHYDATA` is where the data go; the folder is created if it does not exist. `FD_DUMP_DRIVER=ROracle` makes
every way of starting a dump below use ROracle, so it never needs saying again. `.Renviron` is not in git; it
stays on this machine. In RStudio, restart R after making it.

## 3. Check that the machine is ready

From the shell:

```bash
Rscript dump/oracle/all.R --check
```

or from R, see section 6. It dumps nothing. It checks the R packages, the locale, `$FISHYDATA` and its free space
(40 GB wanted), the git commit, then logs in to Oracle, tries a date before 1912 and the letters þ æ ö ð, and
counts each schema's tables. The last line says `ready to dump`, or `not ready` with `NOT OK` on what to fix. A
missing package: install it, and run the check again.

## 4. Dump everything, from the shell

```bash
nohup Rscript dump/oracle/all.R > /dev/null 2>&1 &
```

You get the prompt back at once and can log out: `nohup` keeps it running. It stops at a schema that fails as a
whole, such as a failed login; a single table that fails is recorded, and the dump goes on.

## 5. One schema, or a few, from the shell

The schema names go at the end, before `>`. One:

```bash
nohup Rscript dump/oracle/all.R asfis > /dev/null 2>&1 &
```

A few, one after the other:

```bash
nohup Rscript dump/oracle/all.R kvoti stk > /dev/null 2>&1 &
```

Each gets the same log and checks as in a full run. (`Rscript dump/oracle/asfis.R` runs a schema's script bare,
in the foreground, with no log of its own: use it only to watch one closely.)

## 6. The same from R

Start R in the fishycode folder (RStudio: the project), then load the dump functions once per session:

```r
for (f in list.files("R", full.names = TRUE)) source(f)
```

| what | command |
|---|---|
| is this machine ready? | `dump_check()` |
| one schema | `run_dump("asfis")` |
| a few, one after the other | `run_dump(c("kvoti", "stk"))` |
| every schema, with the run's own log | `run_dump_all()` |
| after a failure | `run_dump("afli", resume = TRUE)`, or `run_dump_all(resume = TRUE)` |
| where each stands | `dump_status()` |

`run_dump()` starts each run as a separate R process in the background, the same as `nohup` does, and gives the
prompt back at once: closing RStudio or logging out does not stop it. `run_dump_all()` instead waits until all
are done, so start it from the shell (section 4) when you mean to log out. The driver is ROracle from
`.Renviron`; `driver = "RJDBC"` would override it.

`dump_status()` prints, per schema: running, queued, finished (with counts and the tables that failed), finished
with an error, or stopped; and the last lines of the log of a run that is going or went wrong.

## 7. Follow it

A full run's own log, one line per schema started and finished:

```bash
tail -f $FISHYDATA/raw/oracle/_logs/*_all.log
```

One schema's full log:

```bash
tail -f $FISHYDATA/raw/oracle/asfis/_logs/*.log
```

Ctrl-C stops the watching, not the dump. Is anything still running?

```bash
ps -ef | grep [d]ump/oracle
```

## 8. If it stopped, or to stop it

Network, a reboot, a failed login: fix the cause, then the same command with `--resume` (or `resume = TRUE` in R):

```bash
nohup Rscript dump/oracle/all.R --resume > /dev/null 2>&1 &
```

A schema that finished with nothing failed is skipped. The others keep every table already written completely
and dump the rest; a file cut off mid-write is done again. Schema names work with `--resume` too.

To stop every dump yourself:

```bash
pkill -f dump/oracle/
```

(it ends anything whose command line names `dump/oracle/`, so close an editor with one of those files open), and
`--resume` later carries on. Do not start a second dump of a schema while one runs: two runs of a schema
write the same files. `all.R` and `run_dump()` refuse a schema that is still being dumped.

## 9. Done

A full run's `_all.log` ends with `done: 28 of 28 schemas exited 0`, and `dump_status()` says `finished` for each.
Each schema then has its `_overview_tables.parquet` (what was written, skipped and failed, and why) and a
`_data-dict.yaml`.

## 10. Copy it to the Mac

While the server dumps, a watcher on the Mac can copy each schema as soon as it is finished, from the share where
the Mac sees the server's folder (`/Volumes/einarhj` is hafdruna's `/heima/einarhj`). From the fishycode folder:

```bash
nohup caffeinate -i sh dump/oracle/sync.sh /Volumes/einarhj/stasi/fishydata/raw/oracle ~/stasi/fishydata/raw/oracle_server > /dev/null 2>&1 &
```

Its progress is in `~/stasi/fishydata/raw/oracle_server/_sync.log`; it stops when every schema is copied.
`caffeinate` keeps the Mac awake meanwhile. It watches for each schema's `.exit` file rather than the run's log,
because the share can show the log without its newest lines. After a `--resume`, run it again once the dump is done.

Or in one go once the dump is done, with the server's name and the path from section 2:

```bash
rsync -a SERVER:/path/to/fishydata/raw/oracle/ ~/stasi/fishydata/raw/oracle_server/
```

Either way the copy goes beside the Mac's own dumps, not over them, and running it again copies only what changed.

## 11. Compare it with the Mac's dumps

In R on the Mac, in the fishycode folder, one schema at a time:

```r
for (f in list.files("R", full.names = TRUE)) source(f)
d <- compare_dumps(fd_raw("oracle_server", "asfis"), fd_raw("oracle", "asfis"))
d[!d$same, ]
```

Each difference is explained before the server's files replace the Mac's: Oracle changed in between, or the
driver. Known: the Mac's dates before 1912 are 16 min 8 s late, and some decimals differ in the last binary
digit (decision 109). The swap itself is in decision 109, "How".

The light check compares rows, columns and types only, in seconds where a big schema takes minutes in full; add the
failures from the schema's overview:

```r
compare_dumps(fd_raw("oracle_server", "kvoti"), fd_raw("oracle", "kvoti"), values = FALSE) |> subset(!same)
o <- nanoparquet::read_parquet(fd_raw("oracle_server", "kvoti", "_overview_tables.parquet"))
o[o$status == "failed", c("name", "error")]
```

Then the dump's dictionary (plan 040). The dump wrote `_data-dict.yaml` with the overlay
`dump/oracle/meta/<schema>.yml` of the commit the server ran; rewrite it with the overlay as it is here, from the
dump's own files, and check it:

```r
rewrite_data_dict(fd_raw("oracle_server", "kvoti"))
check_data_dict(fd_raw("oracle_server", "kvoti"))
```

`check_data_dict()` runs data-dict's `validate-spec`, then `validate-data` on the tables the overlay gives an
assertion or a code list, and prints each check with its counts. `NEWS` marks one that fails otherwise than its
description expects (`Expected false on N rows`, `dump/oracle/meta/README.md`): a source that changed a unit, a
format or a code shows there. Each is explained before the dump replaces the Mac's, as a difference in
`compare_dumps()` is; whether one blocks the swap is plan 040's ask d. The tool is the binary
`datadict::dd_install()` puts in R's cache.

## 12. Schemas added or widened since the last full run

On 2026-10-17 orri and ops_einarhj were widened to the whole schema, and taxon, fs_ufs, uv, rdbes, dw, ufs and
fs_afli were added (decision 121). After `git pull` (section 1), dump only those, resuming:

```bash
nohup Rscript dump/oracle/all.R --resume taxon fs_ufs uv rdbes dw ufs orri ops_einarhj fs_afli > /dev/null 2>&1 &
```

or from R:

```r
run_dump(c("taxon", "fs_ufs", "uv", "rdbes", "dw", "ufs", "orri", "ops_einarhj", "fs_afli"), resume = TRUE)
```

`--resume` keeps what the run of 2026-10-16 wrote: orri's two gear tables, and ops_einarhj's five tables that
`_targets.R` reads, so those files and the targets on them stay as they are. fs_afli takes longest, about as long
as afli. Then copy the nine directories as in section 10, and check orri and ops_einarhj as in section 11: the files
kept are the same, and the rest are new. The Mac has no copy of the seven new schemas to compare with.

Done 2026-10-17 (decision 122), with two reruns after fixes to the dumper: uv and kvoti at 12:48, ops_einarhj at
13:01, each `all.R --resume <schemas>`. kvoti's five views that fail in Oracle itself are expected to fail.

## 13. What else is in Oracle

```bash
Rscript dump/oracle/catalogue.R
```

lists every table and view the account can see, in every schema, with Oracle's comment, row estimate and number of
columns, to `raw/oracle/_catalogue/objects.parquet`. It reads the data dictionary only, in about a minute, and prints
each schema's size and whether it has a dump script. `all.R` and `sync.sh` leave it out.

## 14. The SQL behind the schemas

```bash
Rscript dump/oracle/code.R
```

keeps, for every dumped schema, what Oracle's data dictionary holds of its definitions, in
`raw/oracle/<schema>/_code/`: the text of its views and materialized views, the stored PL/SQL the account may see
(line by line), its triggers, synonyms and dependencies, its objects with their status and last change, and its
columns with their defaults and comments (the fields table). One parquet file per dictionary view
(`all_views.parquet`, `all_source.parquet`, ...), and `_overview.parquet` with what each returned, or Oracle's
refusal. Schema names after the script take only those (`Rscript dump/oracle/code.R adb`). It reads the dictionary
only, in under 3 minutes, and its log is `raw/oracle/_logs/<time>_code.log`. Run it on the Mac: the text is LONG,
which RJDBC reads and ROracle cannot. `all.R` and `sync.sh` leave it out. Why it is so: decision 166.
