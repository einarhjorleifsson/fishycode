# adb is wired into the logbook merge

*Decided and implemented 2026-09-23. Closes TODO.md item 1.*

*Amended 2026-10-23, from Claude's audit of the decision records (not yet checked by a person). The tiers and the
vessel-day anti-join stand; adb's window does not. `ADB_DATE_MIN = FS_DATE_MAX + 1` was replaced by decision 125's
floor (`FS_DATE_MIN`), then by decision 160's 2025-11-19, the day fs_afladagbok's dump starts to thin. Decision 171
found adb to be the Directorate's records in MFRI's codes, not a view of fs_afladagbok, and kept 160's rule. The
premise that adb needs no depth conversion was also replaced (decision 165).*

## The merge is now three-tier

`curate/logbook.R` merges `afli`, `fs_afladagbok` and `adb` by the priority the
maintainer gave: **afli > fs_afladagbok > adb**. Each tier keeps only the
`(vid, date)` pairs no higher tier already covers (an anti-join, not a date
cutoff, so the priority holds even where windows overlap).

`adb`'s own date range is corrupted at the edges (rows found in year 3, year
202, year 2031 — a handful each) and, in practice, only matters from
2026-01-01: `fs_afladagbok`'s static dump covers everything up to
`FS_DATE_MAX` (2025-12-31), so `adb` is bounded to
`ADB_DATE_MIN = FS_DATE_MAX + 1` .. `DATE_MAX`. The anti-join against tiers
1–2 still runs inside that window — cheap, and it is what actually enforces
the priority rather than a date boundary standing in for it.

## What this depended on

Both prerequisites closed earlier the same day:
- [022 - depth unit is metres](022-depth-unit-is-metres.md): `adb` needed no
  conversion (already metres); `z1_basis`/`z2_basis` = `"recorded"` added for
  consistency with `afli`/`fs_afladagbok`.
- `curate/corrections/adb_vs_fs_afladagbok.yml` (longitude sign):
  `curate/corrections/adb_vs_fs_afladagbok.R` writes
  `staging/adb/lon_sign.parquet`, joined onto `adb_station` the same way
  `afli_depth_units.R`'s output is joined onto `afli_station` (never
  overwrite the original - `lon1_raw`/`lon2_raw`/`lon1_basis`/`lon2_basis`).

## A declaration gap this surfaced

`sources/adb/convert.R` already writes `staging/adb/fishing_sample.parquet` -
someone had already split adb's station table into the narrow
station + fishing_sample grammar afli/fs_afladagbok use, with a comment
explaining exactly why (adb's own gear coding doesn't resolve against
`reference/gear.parquet` - `gid` is left `NA`, filled from landings
downstream, not yet done). But `_targets.R`'s `adb` target's `produces()`
never declared that file as an output - a partly-declared graph, the exact
failure mode `_targets.R`'s own header warns about. Fixed alongside this: the
target now lists all four files `convert.R` actually writes.

## Result

`targets::tar_make(names = c("adb_lon_sign", "logbook"))` rebuilt
`curated/logbook/*.parquet`. `merged_station` grew from 6,844,567 + 374,681 to
7,239,778 rows; 20,530 of those are the full `adb` 2026 population (zero
excluded by the tier anti-join, confirming afli/fs_afladagbok have no 2026
coverage to protect). Validated: zero positive longitudes anywhere in the
2026 rows (53 of 20,530 were sign-flipped, 8 NA, the rest already correct);
every row has `z1_basis` resolved; `git`-free sanity check via
`check_bookkeeping()` passes.

## What this does not fix

`TODO.md` item 2 (`FS_DATE_MAX` hardcoded and expired nine months ago) is
unrelated and still open. `adb`'s own `gid` is still `NA` throughout - the
crosswalk `adb_vs_fs_afladagbok.yml`'s `defect_3_gear_coding` describes is
derived but not yet implemented. `adb`'s ~13,064-station longitude residual
(not sign-related) is still uncharacterised.
