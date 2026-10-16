# 111 — Every reader reads the Oracle dumps as they are; the old copies are in the Trash

*2026-10-16. Written by Claude (AI-assisted) as plan 018 phase 3, from the session that did phases 1 and 2. The choices
are plan 018's (the maintainer's, 2026-10-15) except where marked Claude's. TODO 66. The comparison scripts and their
logs are in `$FISHYDATA/archive/2026-10-oracle-rebuild/phase3/`.*

## What was done

**The readers.** Every script that read an old copy of an Oracle table now reads `raw/oracle/<schema>/` through
`fd_raw("oracle", <schema>, <table>.parquet)`: 8 in `sources/`, 11 in `reference/`, 11 in `curate/` (8 of them in the
`once` project), 4 pages in `docs/`, and `_targets.R`'s file targets (`mmsi_raw`, `vessel_raw`, `vessel_hist_raw`,
`vessel_class_raw`, `vessel_sign_raw`). Plan 018 counted about 25 and the trail's 7; the trail has 12.

| old copy | now |
|---|---|
| `raw/logbooks/{adb,afli,fs_afladagbok}/` | `raw/oracle/{adb,afli,fs_afladagbok}/`; `sjalfvirkir_maelar` is now a directory by year |
| `raw/landings/agf/`, `raw/landings/kvoti/lods_*` | `raw/oracle/agf/`, `raw/oracle/kvoti/` |
| `raw/vessels/<vessel table>`, `raw/vessels/kvoti_skipasaga.parquet` | `raw/oracle/vessel/`, `raw/oracle/kvoti/skipasaga.parquet` |
| `raw/mmsi/oracle_<table>.parquet`, `raw/ais/stk/einarhj_mobile-vid.parquet` | `raw/oracle/ops_einarhj/<table>.parquet`, `mobile_vid.parquet` |
| `raw/species/asfis.parquet` | `raw/oracle/asfis/asfis.parquet` |
| `raw/ais/stk/trail/`, `raw/ais/stk/mobile.parquet` | `stk_trail()`, `stk_mobile()` over `raw/oracle/stk/` |
| `raw/ports/ports_kvoti.parquet` (in `harbour_codes.R`) | `raw/oracle/kvoti/stadur.parquet`, with the old dump's renames |

- **`R/stk_trail.R`**: `stk_trail()` gives the trail in its preferred form (`.id`, `mid`, `time`, `lon`/`lat` and
  `heading` in degrees, `speed` in knots, `hid`, `io`, `recdate`, `year`) as a lazy table over the dump, with no copy.
  `stk_trail_sql()` is the same `SELECT` for the checks that write their own SQL (`from (%s)`); `audit_w1_month()`,
  `audit_w2_month()` and `split_end_positions()` take it in place of a glob. `stk_mobile()` gives the old three
  columns of `stk.mobile` (`mid`, `loid`, `glid`).
- **`harbour_codes.R`** makes `ports_kvoti`'s list itself from `kvoti.stadur` (the same 100 rows as the old file). It
  also reads the base table `agf.aflagrunnur` beside the view `aflagrunnur_v` (Claude's choice, as the task asked):
  the view drops landings whose vessel the frozen UFS tables do not know (decision 110), and with them code 168
  (Bretland, one landing on 2022-02-08), which now has a row, named from `kvoti.stadur`, with no pid.
  `reference/ports/bootstrap_iceland_faroe.R`, frozen, keeps `raw/ports/ports_kvoti.parquet` (plan 018) and reads the
  trail through `stk_trail()`.
- **Integers and text.** The dump has NUMBER(p ≤ 9, 0) as integers, where the old RJDBC copies had doubles or text.
  `reference/vessels/mmsi.R` called `sprintf("%.0f", ...)` on two of them, which R refuses for an integer; it now casts.
  Every other reader already cast with `as.integer()`.
- **Time zone (Claude's choice).** The dump's date-times are plain TIMESTAMPs in UTC, where several old copies held
  TIMESTAMP WITH TIME ZONE. `nanoparquet::read_parquet()` returns a plain TIMESTAMP with no time zone, so `format()`,
  `as_date()` and `year()` read it in the session's zone. Here that is Atlantic/Reykjavik, −0:16:08 before 1912 in
  current time-zone data: `vessel_sign.R`'s 1,240 placeholder starts of 1901-01-01 became 1900-12-31, and on a
  machine outside UTC every date-time would move. DuckDB returns them in UTC either way. `_targets.R` and
  `_targets_once.R` now set `TZ=UTC`, as the dump does (decision 109). A script run outside targets (`products/`,
  `docs/`) still reads in the machine's zone; on this Mac that moves only dates before 1912.
- The headers' `Input:` lines and four corrections' `applies_to:` (`afli_coords`, `logger_runs_past_the_station`,
  `fs_veidiferd_year`, `stk_trail_time_outliers`) name the new paths. Dated measurements keep the old ones.

## How it was checked

Each script ran twice into scratch, never into `staging/` or `curated/`. **A** ran HEAD's code (5fcff6d) on the old
copies. **B** ran the edited code on `raw/oracle/`, in UTC, as `_targets.R` now runs. Each run had its own
`FISHYDATA`: `raw/` linked to the real one, and links to the script's other inputs. After every run nothing under
the real `staging/` or `curated/` had changed. B against A isolates the switch. B against the real tables is what
phase 4 will change, and the real ones are older than the old copies (A differs from them too).

| script | B against A | B against the real table |
|---|---|---|
| `sources/afli` | trip, station, catch, aggregate identical; `fishing_sample` effort and `sensor` temperatures differ in the last digits (≤ 1.2e-10) | the same |
| `sources/fs_afladagbok` | all four tables identical | identical |
| `sources/adb` | +28 trips, +99 stations, +310 catch rows (Oracle's day); positions differ in the last digits (≤ 3e-11); 39 dates, 47 t1, 30 t4, 11 T1, 7 T2 changed, every one a year typo before 1912 (0003 for 2003 and the like) | +36,047 trips: the real table was built from an older copy |
| `sources/aflagrunnur` (agf) | +55 landings, +350 catch rows (landed 2026-10-09 to 10-14); 66 catch values changed, on landings of 10-11 to 10-13 | +32,914 landings; 175,672 catch values changed, all older edits |
| `sources/lods` | +64 landings, +391 catch rows (10-09 to 10-14); 37 values changed, on landings of 09-15 to 10-13 | +32,909 landings |
| `sources/stk` | every year 2007-2025 the same rows, values within 1e-9; 2026 +20,494 positions; 2008 +1 (`.id` 14064953, received 2006-04-01) | 2026 +6.96 M: the real table predates the 2026-10-15 trail |
| `harbour_codes.R` (`port`) | +1 row, code 168 | the same |
| `port_code.R`, `gear/mapping.R` | identical | identical |
| `stk_hid_pid.R` | the same 245 codes; event counts up by ≤ 85 and shares by less than 0.0006: the trail's new positions | counts up by ≤ 15,700 (an older trail) |
| `mmsi.R`, `registry.R`, `vessel_class.R`, `vessel_sign.R`, `vessel_year.R` | identical | no real table for four of them (plan 016 is not rebuilt); `vessel.parquet` differs by plan 016's code, not by this |

**The trail.** `stk_trail()` against the old `raw/ais/stk/trail/` by `.id`, year by year: in 2007-2025 the same
283.1 M rows with the same `mid`, `time`, `recdate`, `hid` and `io`. Positions, speed and heading differ by a relative
6e-15 at most (1e-12 degrees): the old copy was computed in Oracle's decimal arithmetic with π as dbplyr wrote it,
`stk_trail()` computes in doubles with DuckDB's `pi()`. No `.id` changed partition. The new dump adds 63,596 positions
received after the old one (2026-10-15 08:45 to 10-16 17:15) and 11,515 in 2003-2006, which the old dump never
fetched. No key period reaches back that far, so `staging/ais/stk` gains none of them except the one above.

**The `once` project and `ais_ping_union.R`** were not rerun: the first is frozen (decision 075), the second writes
44 GB. Each new read was run once on the real dump (the trail joined to the mobile ids, the SQL form, `split_end_positions()`,
the logger by year), and every changed R file parses. Their inputs are the trail above and tables compared below:
`stk.mobile` +1 row (mobile 155870), `mobile_vid` identical. The four `docs/` pages render.

## The old copies, table by table, before the Trash

`compare_dumps()` on every table each old directory held, then each differing column through the known causes in
turn: a cast to one type, RJDBC's 16 min 8 s before 1912 (decision 109), rounding to 12 significant digits. What was
left was compared by key.

| old copy | written | result |
|---|---|---|
| `logbooks/afli` (92 tables; ROracle, April) | 2026-04-19 | same rows in every table; 50 identical, 24 differ only in type (TIMESTAMP WITH TIME ZONE, now plain), 14 also in the last digits of decimals (the April fetch, decision 109); `sjalfvirkir_maelar` the same 28,234,223 rows, decimals only; `afladagb_xml_mottaka` the same 483,738 documents serialised another way (pretty-printing, `<X/>` for `<X></X>`, spaces before `>`, `&apos;` and `&gt;`). Only `create$java$lob$table` and `ps_txn` (Oracle internals, 2 rows each) are not in the dump, which skips them. The April file's statistics also misled DuckDB: `id = 153` found no row, `id + 0 = 153` found it |
| `logbooks/adb` (31; RJDBC) | 2026-10-15 | 15 identical; the rest one day of new rows and, before 1582, Java's Julian calendar on top of the 16 min 8 s: adb's placeholder `registered`, 0001-01-01 in Oracle's calendar, is 0000-12-30 in the proleptic Gregorian one parquet and R use. After 1912 the only differences are the new rows; no old key is missing |
| `logbooks/fs_afladagbok` (27) | 2026-04-09 | 25 identical; `fishing_spot` decimals; `ws_rekjanleiki` +40,494 rows (neither is read) |
| `landings/agf` (15), `landings/kvoti` (2) | 2026-10-15 | new landings and revisions of recent ones (agf: 486 rows added, 633 changed; lods: 464 added, 50 changed), the year-0198 typo in `kvotategundir_vsv_vstofn`; no old landing key missing |
| `vessels/` (28 vessel tables, `kvoti_skipasaga`) | 2026-10-14 | same rows; types, the 16 min 8 s (1912-01-01 00:00 included), ids as text now numbers, decimals |
| `gear/`, `species/` | 2026-04-10 | identical; orri's `veidarfaeri` has four audit columns the old script dropped |
| `mmsi/oracle_*`, `ais/stk/` | 2026-10-14/15 | snapshot `vid`s text, now numbers, equal; the trail and mobile ids above |

Moved to the macOS Trash on 2026-10-16, under their names and dates: `raw-logbooks-adb_2026-10-15`,
`raw-logbooks-afli_2026-04-19`, `raw-logbooks-fs_afladagbok_2026-04-09`, `raw-landings_2026-10-15`,
`raw-ais-stk_2026-10-15` (9.0 GB), `raw-species_2026-04-10`, `raw-gear_2026-04-10`, `raw-vessels-oracle_2026-10-14`
(32 files) and `raw-mmsi-oracle_2026-10-14` (4). Before the move, `~/stasi/logbooks` and `~/stasi/fishydata_2024-2026` were searched for
these paths, and for links into `raw/`: neither reads them.

**Kept:** `raw/logbooks/logbook/` (plan 018: rows the rebuilt schema lacks); `raw/ports/ports_kvoti.parquet` (the frozen
bootstrap); `raw/vessels/mmsi_iceland_archieves.parquet` and `vessels_iceland.parquet`, which are built files, not
Oracle's (plan 018 §2.1); `raw/mmsi/`'s lists.

## Found on the way, not done here

- **`staging/ais/stk` keeps two partitions no build writes any more**, `year=1970` and `year=2006`, from the build of
  2026-09-23 (3 rows). `duckdbfs::write_dataset()` replaces the partitions it writes and leaves the others, so a
  partitioned output can carry rows from an older build into every reader (TODO 69).
- `raw/oracle_server_try1/` is the server's first run, set aside in decision 109; this record does not touch it.
- `tmp/` (git-ignored, 2026-10-01) has two scripts that read the old trail and a file that is gone.

## What is left

Phase 4: the rebuild, together with plan 016's, on the maintainer's go. `tar_outdated()` (read-only, 2026-10-16)
lists 28 targets: the vessel targets, whose declared raw files moved, and the AIS chain from `ais_ping_union` down.
The other targets whose scripts changed read raw files `_targets.R` does not declare, and targets cannot see a script
edit, so they are invalidated by hand before the build:

```r
targets::tar_invalidate(c(gear, port, port_code, stk_hid_pid, afli, fs_afladagbok, adb, aflagrunnur, lods, stk))
```

*Done 2026-10-16, at the maintainer's request:* the ten are invalidated, and `tar_outdated()` then lists 50 targets,
the ten and everything downstream. `staging/ais/stk` is not cleared (the maintainer: the rebuild needs it), so its two
stale partitions stay until TODO 69 is done. The `once` project
is not rebuilt (decision 075). `TZ=UTC` in `_targets.R` changes no target's hash; it acts on the targets that rebuild.
The April copy of `raw/logbooks/afli/` is in the Trash (`raw-logbooks-afli_2026-04-19`) and can be put back if a
second copy of `afladagb_xml_mottaka` in its old serialisation is wanted.
