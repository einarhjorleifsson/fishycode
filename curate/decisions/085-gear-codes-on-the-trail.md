# 085 — The station's gear codes are on the trail

*2026-10-13. Code and check by Claude (AI-assisted), on the maintainer's choice of 2026-10-13 to take TODO 34's
question (3) before the 2026-10 rebuild. TODO 34's questions (1) and (2) stay open.*

## What was chosen

`curated/ais/trail` carries `gid`, `gid_landing`, `gid_used` and `gid_basis` beside `metier`, `gear` and `target`.
They are joined on (.sid, schema) from `curated/logbook/gear.parquet` in the wide row of `R/trail_sql.R`, and keep
the names they have there, one name per concept:
- `gid` is the logbook's;
- `gid_landing` is the landing's, where the landing names one;
- `gid_used` is what the windows were built with, and `gid_basis` says how it was obtained.

Like every station column on the trail, they are filled only when exactly one station claims the fix (`n_sid` = 1).
`trail_match` is unchanged.

`station_window.parquet` calls `gid_used` just `gid`. It stays as it is: renaming it would touch the window
builder's input and every reader of that file.

`ais_trail` now depends on `logbook_gear` in `_targets.R`, and the file is among the trail's stamped inputs.

## Checked (June 2023, built in memory from the current trail_match)

- 3,288,291 fixes, as in the current trail. Every existing column is identical (`EXCEPT ALL` both ways: 0 rows).
- The four columns are filled on exactly the 640,327 fixes with one station, and on none of the others.
- `gid_used` equals `station_window.gid` on all 640,327.
- `gid_landing` is filled on 631,857 of them.
