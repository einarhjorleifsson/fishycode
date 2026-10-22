# 165 — adb's stations are read from the table `fishing_station`, not the view `station_v`, whose positions are misread

*2026-10-22. Decided and committed, not built: the rebuild is the maintainer's to run. Tested on a scratch
`$FISHYDATA`. The defect and its evidence: `curate/corrections/adb_station_v_positions.yml`.*

- **Who decided.** The maintainer, 2026-10-22: read the table as the source rather than correct the view ("should we
  not switch from station_v to station as the source"), then "record + commit, no build".
- **Who did the work.** Claude (Anthropic) verified the lead on the dump, wrote the decoder, changed the adapter and
  the merge, ran the scratch test and wrote this record. The numbers are Claude's and not yet checked by a person. The
  lead came from Claude's reading of the kb-hafro-kerfi knowledge base against the dumps.

## What it settles

`sources/adb/convert.R` reads `raw/oracle/adb/fishing_station.parquet` (and `fishing_trip.parquet` for the app, the
trip's `source`) instead of `station_v.parquet`. The position integers are read by `decode_logbook_position()` in
`R/logbook_position.R`; `logbook_position_hundredths()` names the trips whose six digits are hundredths of a minute.
Reading the stored form is the adapter's work, as `sources/fs_afladagbok/convert.R` does for the same integers, so
there is no side table. Depth comes in the table's fathoms, and `curate/logbook.R` converts adb's as it converts
fs_afladagbok's: the same metres, `z1_raw` now the fathoms recorded, `z1_basis` "reconstructed" (was "recorded").
The adapter turns the longitude's sign as the view did, so `curate/corrections/adb_vs_fs_afladagbok.R`'s restore of a
west entered as minus applies unchanged.

## Why

`station_v` is `fishing_station` row for row (691,011 rows). It reads every six-digit position as ddmm.hh, while the
digits are ddmmss for every app but Taktikal's (2021-2023) and 51 Marína trips: Trackwell's last two digits are never
above 59 (0 of 673,010 latitudes), Reiknistofa fiskmarkaða's are 60 only as a rounded-up carry, Marína's peak at 15,
30 and 45. It reads a shorter longitude beside a six-digit latitude (leading zeros dropped) the same wrong way, and a
longer one in the latitude's form. A correction over the view would have kept a wrong decoding as the source and
added a table to undo it; the table holds what the logbook sent.

## Effect, on a scratch run against the store as built

Scratch `$FISHYDATA` run of `sources/adb/convert.R`, `curate/corrections/adb_vs_fs_afladagbok.R` and
`curate/logbook.R`, compared with `curated/logbook/`; the real store was checked untouched afterwards.

- Only adb's 88,464 stations (2025-11-19 on, decision 160) change. `trip`, `fishing_sample` and `catch` are
  identical, and so are afli's, fs_afladagbok's and aflaskeyti's stations, keys, twins and station types.
- Start positions: 85,901 of 88,444 move; half less than 400 m, 90 % less than 684 m, 99 % less than 765 m; 64 more
  than 5 km, from longitudes of 112-180° or a latitude of -7° into Icelandic waters. End positions: 64,889 of 65,732
  move, half less than 412 m, 53 more than 5 km. 6 start and 3 end latitudes become NA (three-digit values the view
  read as whole degrees, and two beyond 85°). No longitude beyond 90° is left (52 and 54 before).
- Depth: the same values (to 2e-12 m); `z1_raw` fathoms, `z1_basis` "reconstructed". `lon1_basis` changes on 1
  station.
- The flow never reads a logbook position (hauls meet pings by time), so effort and catch on the fixes should not
  change; positions and maps do.

## Not built

`tar_outdated()` lists 25 targets. 22 are `adb_raw` and everything downstream of it: `adb`, `adb_lon_sign`, `logbook`,
`lid_map`, `logbook_gear`, `station_window`, `station_event`, `trip_voyage`, `voyage_gear`, `ais_trail`,
`catch_by_species_station`, `catch_by_species_trip`, `ais_catch` and the checks `check_allocation_audit`,
`check_landed_logged`, `check_port_call_logbook`, `check_survey_tow_times`, `check_trail_agreement`,
`check_trail_sid_coverage`, `check_vessel_activity`, `check_voyage_sharing`. Three are outdated for other reasons
(`afli_sent`, `mbl_photo_raw`, `mbl_photo`). `targets` cannot see the edit to `curate/logbook.R`, but `logbook` is
downstream of `adb_raw` anyway. The rebuild is the maintainer's to run (`tar_make_isolated()`).

## Left open

- fs_afladagbok's adapter decodes the same integers its own way and reads all 7,710 kept Marína stations as
  hundredths, puts a trip holding a carried 60 in hundredths (23 kept), and leaves 59 of its 9,184 kept stations with
  a four- or five-digit longitude beyond 30°. Proposed as its own session, not done.
- Eleven other Oracle views the flow reads (adb's `trip_v` and five gear views, `kvoti.lods_oslaegt`,
  `agf.aflagrunnur_v`, `vessel.vessel_v`, `vessel.vessel_hist_v`, `kvoti.strandveidileyfi_v`) have not been compared
  with their tables; the dump holds no view definitions.
- `reference/dictionary.R` still says "already decimal degrees — wrong convertion" beside adb's positions, which now
  arrive decoded from the table.
