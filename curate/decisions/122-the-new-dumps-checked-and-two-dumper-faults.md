# 122 — Decision 121's dumps checked; the dumper reads lower-case names and drops NUL characters; fs_afli holds all of afli and more

*2026-10-17. Written by Claude (AI-assisted) after the maintainer ran `dump/oracle/README.md` §12 on the server.
Measured: the run's logs and overviews, read over the share; the copies on the Mac (rsync, md5, `compare_dumps()`);
Oracle's data dictionary (the catalogue rerun), read from Claude's shell with the maintainer's leave of the same day.
The dumper fix was tested on a DuckDB stand-in only. Nothing was dumped from the Mac.*

## The run

hafdruna, commit 9ef7596, 11:53 to 12:14: 9 of 9 schemas exited 0. fs_afli took 18.9 min (2.9 GB), the rest under a
minute each.

| schema | written | failed | skipped | kept |
|---|---|---|---|---|
| taxon | 16 | | | |
| fs_ufs | 4 | | | |
| uv | 8 | `veidisvaedi` | 3 | |
| rdbes | 41 | `effort_v`, `landing_v` | | |
| dw | 24 | | 7 | |
| ufs | 44 | `afli_til_kvota_veidarf_v` | 18 | |
| orri | 22 | | 8 | 2 |
| ops_einarhj | 49 | `heildarafli`, `raw_index_calc`, `test` | | 5 |
| fs_afli | 74 | | 6 | |

**On the Mac.** The seven new schemas are moved into `raw/oracle/`. orri and ops_einarhj took their new files: the
seven kept files are byte-identical to the Mac's (md5), and `compare_dumps()` finds them the same, so `mmsi_raw` and
the gear and key readers see no change. rsync checks each file as it copies. Afterwards, a size and time pass finds no
fs_afli file differing from the server's, and a checksum pass finds orri and ops_einarhj equal to their copies. The
staging folder `raw/oracle_server/` is removed.

## Why each failed

- **Ours: names.** ops$einarhj's three tables were made from R with quoted lower-case names. The dumper wrote every
  table name in capitals, so Oracle found no `"OPS$EINARHJ"."HEILDARAFLI"` (ORA-00942). The rerun catalogue
  (`oracle_name`, Oracle's own spelling) finds five such objects in the dumped schemas: these three, kvoti's
  `della_post` (failed the same way on 2026-10-16) and stk's `toti2_MOBILE_SKIP_V`. stk.R skipped that view, and
  decision 109 explained its ORA-00942 as an object it reads being missing. That was wrong; both are corrected.
- **Ours, partly: NUL characters.** `uv.veidisvaedi`, the closure and regulation areas themselves, holds NUL
  characters (CHR(0)) in its text, and R's strings cannot hold them ("embedded nul in string"). kvoti's `adili_jn` and
  `eftirlits_gjald_utan_ees` failed the same way.
- **Oracle's.** rdbes's `effort_v` and `landing_v` do not compile (ORA-04063). ufs's `afli_til_kvota_veidarf_v` raises
  ORA-20011 in the Directorate's own PL/SQL (`ASK.VEIDARFAERI_PKG`: a landing "does not exist or has no weighing
  slip"); its base table `afli_til_kvota` is dumped. The older schemas' remaining failures are of the same kind: kvoti
  three views ORA-01843, two ORA-04063; agf one ORA-20006; ask one ORA-04063; afli two ORA-01843.
- **Left failing.** fs_afladagbok's `takt_json_form` holds signed PDF files in a CLOB. Its NULs are the files'
  content, and removing them would corrupt them.

## The fix (`R/dump_oracle.R`)

- `oracle_objects()` and `oracle_catalogue()` keep Oracle's spelling in `oracle_name`. `dump_oracle_schema()` passes a
  name that is not all capitals on in quotes (`.oracle_spelled()`), and every query names a table through
  `.oracle_ref()`, which keeps a quoted part as it is: the convention of `mar::tbl_mar()`. An ordinary table's name,
  query and `fd.source` are as before.
- A fetch that fails on NUL characters is redone with them removed from the text columns that hold them
  (`.oracle_nul()`, one scan). The file, the overview and `_data-dict.yaml` carry a note naming the columns and the
  values that held one. In Oracle '' is NULL, so a value of NULs only becomes empty. CLOBs are not touched.

**Tested on a DuckDB stand-in** (`dump_connect()` stubbed to refuse; 14 checks, all pass). It had a quoted lower-case
table with a decimal column, a table with NULs in two columns, an ordinary table and a view. On the committed code the
NUL table fails. DuckDB matches names regardless of case, so it cannot reproduce ORA-00942. That part is checked by
the SQL it renders (`FROM "S"."heildarafli"`) and by the catalogue's spelling of the five names.

**To run on the server** (README §12): `all.R --resume uv ops_einarhj kvoti` redumps only the objects that failed and
keeps the rest. kvoti's files that `_targets.R` reads are kept as they are. Expected: uv's `veidisvaedi`, the three
ops$einarhj tables, and kvoti's `della_post`, `adili_jn` and `eftirlits_gjald_utan_ees` written; kvoti's five
failing views fail again.

## fs_afli against afli: a first measurement

By rows, fs_afli holds more in 25 tables and the same in 48. By key, in the two station tables:

| table | afli | fs_afli | only in afli | only in fs_afli |
|---|---|---|---|---|
| `stofn` (paper) | 6,885,574 | 6,887,664 | 0 | 2,090: 2,066 from 2022-04-11 to 06-15 (118 vessels), origin `PAPPÍR` |
| `rafr_stofn` (electronic) | 1,149,278 | 1,318,780 | 0 | 169,502: 40,910 in 2020, 86,088 in 2021, 40,165 in 2022 (240-277 vessels a year), 1,896 in 2023; 2,100 marked deleted (`eytt`) |

So afli is a subset of fs_afli. None of the extra stations has a vessel number in the foreign range (3700-4999).
fs_afli also has two columns afli lacks: `stofn.uppruni` (`PAPPÍR` 5.78 M, `TRACKWELL` 1.11 M) and `rafr_stofn.er_lesid`.
On shared stations the copies differ mostly in one flag, `breytt_eftir_lokun` (166,538 paper stations), with tens to
about 130 real edits per column. About 190 electronic stations differ in nearly every column, and 3,098 in their last
change time.

The electronic stations only fs_afli holds fall in fs_afladagbok's years (2020 onward). Whether they are records that
fishycode lacks, or the same trips that fs_afladagbok already holds, is the open question (TODO 76).

## Not from this

`tar_outdated()` lists 63 of 92 targets, as decision 116 counted. Twenty were never built: decision 113's four
inputs, decision 116's eight and decision 115's eight (plan 021). The other 43 sit on them or had their command
changed (`mmsi_raw`). No declared input changed here. No TODO item held decisions 113 and 116's build; TODO 77 does now.
