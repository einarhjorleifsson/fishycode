# 170 — adb's trips and gear are read from their tables, not Oracle's views; the dredge's feet are 0.3048 m

*2026-10-22. The maintainer's rule "Oracle tables, not views" (AGENTS.md, Rules; TODO 120), applied to
`sources/adb/convert.R`. Written by Claude (AI) in a session started from another Claude session; the comparison, the
code and the scratch run are Claude's and have not been checked by a person. Decided and committed, not built: the
rebuild is the maintainer's to run. Study, script and log: `$FISHYDATA/archive/2026-10-adb-views/` (README,
`01_views_from_tables.R`). Dump of 2026-10-16.*

## Found

Each of the six views the adapter read was rebuilt in DuckDB from its table and the view's text
(`raw/oracle/adb/_code/all_views.parquet`, decision 166) and compared row by row, `EXCEPT ALL` both ways, converted
values at 9 decimals. All six are equal to their rebuild: `trip_v` 306,537 rows, `trawl_and_seine_net_v` 267,040,
`dredge_v` 96,650, `line_and_net_v` 205,536, `trap_v` 446, `surrounding_net_v` 1,997, none differing.

- `trip_v` is 13 of `fishing_trip`'s 15 columns, unchanged. Its `trip_id` is the table's VARCHAR `id` (306,537
  distinct), not its DOUBLE `fishing_trip_id` (297,105 distinct); the view drops `fishing_trip_id` and `batch_day`.
- `trawl_and_seine_net_v` converts headline from feet (x 0.3048), bridle and rope from fathoms (x 1.8288).
- `dredge_v` joins `dredge_type` for the name and takes width, length and height x **0.3042**. The unit is feet
  (fs_afladagbok's `ws_plogur` comments say "fet"), so the factor is 0.2 % low; 0.3042 is a garbled 0.3048.
- `line_and_net_v` is its table; `trap_v` and `surrounding_net_v` join their type tables for the name, and
  `surrounding_net_v` converts length and height from fathoms.

## Chosen

`sources/adb/convert.R` reads `fishing_trip`, `trawl_and_seine_net`, `dredge`, `line_and_net`, `trap` and
`surrounding_net` (and, since decision 165, `fishing_station`), and `adb_raw` in `_targets.R` lists those files. Each
is renamed to its view's names, which `curated/reference/dictionary.parquet` maps (`trip_id`, `station_id`,
`bridle_length`, ...), as decision 165 did for `fishing_station`. Only the columns the adapter uses are read: the
type tables' names are not needed, and `fishing_trip` holds persons' data (`vessel_gsm`, `company_ssn`). The
conversions done in R are the bridle x 1.8288 (it becomes `sweeps` and the trawl's `gear_width`) and the dredge width
x **0.3048** (the dredge's `gear_width`). No adb view is read any more.

## Checked

The HEAD adapter and the new one, each run into its own scratch `$FISHYDATA` (`raw/` and `curated/reference` linked),
their four `staging/adb` tables compared row by row:

- `trip` (306,537 rows), `station` (691,011) and `catch` (2,074,565) are identical.
- `fishing_sample` (691,011 rows, `.sid` unique on both sides) is identical in every column but `g_width`, where
  every row is in one outcome:

  | station's gear table | `g_width` | rows |
  |---|---|---|
  | dredge | x 0.3048/0.3042 | 7,631 |
  | dredge | NA in both | 89,019 |
  | trawl and seine net | equal | 254,088 |
  | trawl and seine net | float noise, at most 2.8e-14 m | 12,952 |
  | neither | NA in both | 327,321 |

  The float noise is Oracle multiplying exact NUMBERs where R multiplies a double. The dredge widths take five
  values: 0.9126 m becomes 0.9144 (5,776 rows, the app's default of 3 feet), 0.7605 becomes 0.7620 (1,266), 0.6084
  0.6096 (308), 7.605 7.620 (278), 0.1521 0.1524 (3).
- 2,835 of the 7,631 are from 2025-11-19 on (decision 160); 2,682 of them are in `curated/logbook/fishing_sample`
  as built, with the old width. Nothing in `curate/`, `R/` or `products/` reads `g_width`, so effort, catch and the
  fixes do not change.
- Nothing under the real `$FISHYDATA` was written: `find -newer` after the runs listed only another session's files
  (`archive/2026-10-lods-upstream/`).

## Not built

`tar_outdated()` after the change lists 29 targets, all already outdated by earlier decisions: decision 165's 25
(`adb_raw` and the 21 downstream of it, and `afli_sent`, `mbl_photo_raw`, `mbl_photo`) and decision 169's
`lods_raw`, `lods`, `landing` and `aflaskeyti_trip` (TODO 119). `adb_raw` was outdated since decision 165, so this
switch adds no target. The rebuild is the
maintainer's to run (`tar_make_isolated()`).

## Left open

- TODO 120's other readers still on views (`agf.aflagrunnur_v`, `vessel.vessel_v`, `vessel.vessel_hist_v`,
  `kvoti.strandveidileyfi_v`).
- Two book pages still name adb's views: `docs/convert-bugs.qmd` reads `station_v` and `trawl_and_seine_net_v` in
  its code, and `docs/grammar_logbooks.qmd` gives adb's keys as `trip_v.trip_id` and `station_v.station_id`.
- The trawl's `gear_width` is the bridle (sweep) length, not a width (noticed in the archive's README; unchanged here).
