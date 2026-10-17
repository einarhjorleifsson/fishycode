# 116 — The Oracle tables the adapters read and the MMSI lists are declared inputs

*2026-10-17. Written by Claude (AI-assisted), on a brief from another session, as decision 113's next step. Verified
read-only: `tar_validate()`, `tar_outdated()` (the store's meta file has the same md5 before and after) and two
scratch targets projects. No target of this project was built.*

## What was wrong

`gear`, `port`, `port_code`, `afli`, `fs_afladagbok`, `adb`, `aflagrunnur` and `lods` read 28 files in `raw/oracle/`
that `_targets.R` did not name. A new dump left `tar_outdated()` empty, and decision 111 had to invalidate them by
hand. `mmsi_raw` listed `raw/mmsi/*.xlsx` inside its own command. A command is not rerun until its code changes, so
that listing would never see a new list (decision 113's table).

## What was chosen

Each reader gets one input target, `<reader>_raw`, with `format = "file"` and each file named by its path, as
`vessel_raw` does:

| input | files in `raw/oracle/` | read by |
|---|---|---|
| `gear_raw` | `asfis/asfis` | `gear` |
| `port_raw` | `agf/aflagrunnur_v`, `agf/aflagrunnur`, `kvoti/stadur` | `port` |
| `port_code_raw` | `agf/aflagrunnur_v` | `port_code` |
| `afli_raw` | `afli/{stofn,rafr_stofn,toga,lineha,gildra,hringn,afli}` | `afli` |
| `fs_afladagbok_raw` | `fs_afladagbok/{ws_veidiferd,ws_veidi,ws_dragnot_varpa,ws_plogur,ws_linanethandf,ws_gildra,ws_hringn,ws_afli}` | `fs_afladagbok` |
| `adb_raw` | `adb/{trip_v,station_v,trawl_and_seine_net_v,dredge_v,line_and_net_v,trap_v,surrounding_net_v,catch}` | `adb` |
| `aflagrunnur_raw` | `agf/aflagrunnur` | `aflagrunnur` |
| `lods_raw` | `kvoti/lods_oslaegt` | `lods` |

Two files sit in more than one input. `tar_validate()` accepts that, and a change marks every reader. Each file is
its own `fd_raw()` call, not a vectorised `paste0()`. `check_paths()` finds `fd_raw(` calls by a regex that stops at
the first `)`, and it would report a vectorised call as a missing file.

**Read, but not declared.** Some files are read only for a printed check, after the output is written. These are not
inputs, which agrees with what each script names in its own `write_curated(inputs =)`:

- `mapping.R` reads `afli/stofn` and `fs_afladagbok/ws_veidi` to list the gear codes it does not map.
- `registry.R` (`vessel`) reads `agf/aflagrunnur` to list landing vessels with no MMSI.
- `afli/convert.R` reads `kvoti/lods_londun` only inside `if (FALSE)`.

Declaring them would rerun `gear` on a logbook dump, and `vessel` on a landings dump, just to reprint a table.
`vessel` would also take the whole AIS chain below it with it (about two hours, decision 113). Comments at `gear`
and `vessel` say so.

**`mmsi_raw`.** The lists now come from `input_files("raw", "mmsi", pattern = "[.]xlsx$")` at the top of
`_targets.R`. `input_files()` gained a `pattern` argument. It defaults to parquet, so decision 113's three calls
are unchanged. The listing is recursive, while `mmsi.R`'s own is not. `raw/mmsi/` has no subfolder.

## Checked

A scratch project ran on copies, with the forms above (targets 1.12.0, `FISHYDATA` set to the scratchpad):

| change | marked outdated |
|---|---|
| nothing | none |
| a dump file rewritten, same bytes, new mtime | none |
| a dump file rewritten, new bytes | its input and its reader |
| a new MMSI list | `mmsi_raw`, `mmsi` |
| a list removed | `mmsi_raw`, `mmsi` |
| a `.DS_Store` in `raw/mmsi/` | none |
| an Excel lock file `~$x.xlsx` in `raw/mmsi/` | `mmsi_raw`, `mmsi` |

A real re-dump always has new bytes, because `dump_oracle_schema()` stamps `fd.dumped` into each file. So a dump of a
schema reruns every reader of it, which is what decision 111 had to do by hand.

## Cost

| | |
|---|---|
| no-op `tar_outdated()` here, before and after the edit, alternating runs against the same store (5 runs each, twice) | before 1.13-1.16 s, after 1.11-1.15 s; the first run of each set 1.28-1.31 s |
| the nine inputs' share of a no-op check (scratch project over the real files, built once, 5 runs, twice) | 0.42-0.45 s with them, 0.41-0.46 s without: no difference to measure |
| full hash of the 28 dump files (0.74 GB) | 0.17 s with a warm cache, about 4.3 GB/s |

No single input costs much to rehash. `port_raw` and `afli_raw` are the largest, at 0.26 GB and 0.06 s each, and
`mmsi_raw` is 13 files and 2 MB. One run right after the edit took 1.38-1.50 s, but the alternating runs show that
this was load on the machine, not the edit.

## What the edit marks outdated once

`tar_outdated()` now lists 63 of 92 targets, 32 more than before the edit. The 31 already listed were decision 113's 23
and plan 021's 8 new targets. The 32 new ones are:

- the nine inputs: eight new, plus `mmsi_raw`, whose command changed;
- the eight readers, whose commands changed;
- `mmsi`, `vessel`, `vessel_identity` and `vessel_identity_all`. `input_files()` sorts by radix, which puts the two
  `Númer - Skip - MMSI …` lists first, where the locale's sort had put them last. targets hashes a file target's files
  in order (`file_hash()`), so `mmsi_raw`'s hash changes from `dff3b896e6500ddb` to `15b6d67300dfe363`, and `mmsi`
  reruns once. The radix order stays, because with a locale order the hash would depend on the session's locale
  (decision 113);
- the targets below the readers: `gear_window`, `afli_depth_units`, `adb_lon_sign`, `landing`, `logbook`, `lid_map`,
  `logbook_gear`, `station_window`, `catch_by_species_station`, `catch_by_species_trip` and `check_landed_logged`.

Their last build took 9.9 min together, by `tar_meta()` seconds. The largest are `lid_map` 2.1 min, `landing`
2.0, `afli` 1.7, `logbook` 1.4 and `lods` 0.8. Everything below them (`trip_voyage`, `station_event`, `voyage_gear`,
`ais_trail`, `ais_catch` and the checks) was already outdated by decision 113. So the next build takes about 10 min
more than decision 113 said. Its advice still holds: build with the next dump, since a dump reruns all of this anyway.

## Left

- Other raw inputs are still undeclared, outside the Oracle dumps:
  - `ports_iceland`: `raw/ports/ports_iceland_faroe.gpkg`;
  - `ports_all`: ten files in `raw/ports/`;
  - `shapes_raw`: three files in `raw/aux/`;
  - `shapes`: `raw/aux/ICES_Areas_20160601_cut_dense_3857.gpkg`;
  - `area_h3`: the GEBCO GeoTIFF;
  - `check_survey_tow_times`: `raw/survey/is_smb_stations.csv`.

  They rarely change. Declaring them would mark `shapes` and everything below it outdated: the 10+ min EUSM step,
  then `stk_hid_pid`'s chain. That needs a decision of its own.
- The Excel lock file in the table above was a hazard before this edit too. `mmsi.R` lists the folder the same way, so
  a build run while a list is open in Excel reads the lock file.
- `fro_files` and `vid_ledger_files` at the top of `_targets.R` call `list.files()` themselves. They could use
  `input_files(pattern =)`. The only difference is an empty folder.
