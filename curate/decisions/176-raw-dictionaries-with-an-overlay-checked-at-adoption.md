# 176 — The raw dictionaries carry a hand-kept overlay of units, formats and codes, and are checked when a dump is adopted

*2026-10-22. Plan 040, phase 1. The maintainer chose the place of the overlay (`dump/oracle/meta/`, ask a) and the
phasing (the convention now; plans 038 and 039 fill it as they open each reader; the curated layer after them).
Written by Claude (AI) in a session started from another Claude session; the code, the overlays, the measurements and
this record are Claude's and have not been checked by a person. Committed locally, not pushed. Built and tested on
APFS clones of `raw/oracle/` in the session's scratch space; later the same day, on the maintainer's go ("go ahead and
rewrite the real raw dictionaries"), the 28 real dictionaries were rewritten (§ Rewritten).*

## What it settles

- **The overlay**, `dump/oracle/meta/<schema>.yml`, a data-dict document holding what Oracle does not say of the
  columns fishycode reads: the measure and unit, a unit that depends on another column as a definition, a position's
  form, sign and precision, code labels in English, the time zone, the evidence, and an assertion per claim the data
  can test. The format and its rules are in `dump/oracle/meta/README.md` (format committed early, 53f4fbf).
- **The dumper** (`.write_data_dict()`, `R/dump_oracle.R`) lays the overlay over the dictionary it writes: the overlay
  wins on what it sets, the dump fills ranges, examples and Oracle's comments. A faulty overlay is named in the
  dictionary's `todo` and the dictionary is written without it, so it never costs a dump its dictionary.
- **The writer's spec errors are fixed:** datetime ranges in ISO 8601 with `Z` (zoneless where the overlay gives a
  `time_zone`), text examples always quoted, NaN kept out of ranges, a column with no value in the file listed by name
  only with Oracle's declared type and a `todo`, examples from the whole file where the first 10,000 rows hold none,
  and an overview row whose file is gone left out and named in the `todo`.
- **Ask f** is implemented in its reversible form: an empty column is named, not typed, until a dump holds a value;
  where the overlay types it, an ordered type gets an open range (`[-.inf, .inf]`) and any other its type in the
  `todo`. The ask stays open for the maintainer.
- **`rewrite_data_dict(dir)`** (`R/data_dict.R`) rewrites a dump's dictionary from its files, its overviews and the
  overlay, without Oracle. **`check_data_dict(dir)`** runs data-dict's `validate-spec`, then `validate-data` on the
  tables the overlay gives an assertion or a code list, one year file at a time where a table is dumped by year (the
  tool reads no glob), and reports each check with its counts. An assertion that checks a known defect says
  `Expected false on N rows` in its description; a different count, an enum value outside its map, or a check that
  cannot run is marked NEWS. `dump/oracle/README.md` §11 calls both when a dump is adopted.
- Overlays are read as data-dict reads YAML 1.2: R's yaml reads `Y`, `N`, `on`, `off` as booleans (lods' fishing
  areas Y and N), and a one-element sequence read as a vector is written back as a scalar, which the spec refuses.

## Measured (plan 040 §5)

On the 28 dictionaries as they are (27 of the plan, and kvoti's of the re-dump of 2026-10-22):

| | dictionaries passing `validate-spec` | errors |
|---|---|---|
| as written by the dumps | 3 (asfis, fiskifelagid, fs_ufs) | S12 4,514 (4,242 datetime ranges, 272 text examples that YAML 1.2 reads as numbers, `62E5`), S07 3,510 |
| with the datetime fix alone | 5 (and agf, fiskist) | S12 272, S07 3,510 |
| rewritten by `rewrite_data_dict()` | 28 | none; warnings only: S31 for each `todo`, S16 once (fiskist) |

The plan counted 21 of 27 failing on 2026-10-22, with ask, kvotix and ufs passing; on the files as they are now, those
three fail as well (S07 and S12).

The S07 errors are columns with no examples or range. Of 21,128 columns, **2,859 hold no value in the whole file**,
that is in Oracle when it was dumped, the file being the table whole; 1,616 of them are in tables with no rows. **744
hold values only past the first 10,000 rows**: 650 numbers and texts, which were S07, and 94 datetimes, whose range
came from the whole file. 2,859 + 650 = 3,509 of the 3,510; the other was in stk's old dictionary, which still listed
three views whose files are gone (TODO 110).

## The seeded overlays, on the current dumps

Each claim is from a decision or correction already recorded; the counts are the assertions' on clones of the dumps.
Every check came out as its description says.

| Schema (dump) | Claim | Result |
|---|---|---|
| kvoti (2026-10-22) | `lods_slaegt`: herring, capelin and blue whiting (fteg 30, 31, 34) in tonnes, cod equivalents ≥ 10 × magn (decision 169) | true on all 9,980,418 rows |
| | every other species in kg, cod equivalents ≤ 12 × magn | true on all rows |
| | `gerd` K, S, U, L, H, A, V, B with labels; K + A is the sold weight at port 159 (decision 169, amended) | no other code |
| | `veidisvaedi`, 24 areas from `veidisv`; `g_skip.for_fra` S, V and F | no other code; F is not in Oracle's comment (todo) |
| adb (2026-10-16) | six-digit latitudes are ddmmss (decision 165) | false on 157, as expected: the hundredths trips, Taktikal 134, Marína 23 |
| | six-digit longitudes likewise | false on 175, as expected: Taktikal 144, Marína 31 |
| | minutes below 60 in four to six digits | false on 3,183 rows from every app (new; todo) |
| | depth in fathoms (scale check); trawl headline in feet (scale check); bridle, rope fathoms; dredge width feet (decision 170) | the checks hold |
| afli (2026-10-16) | `stofn.lengd_lok` is not a copy of `breidd_lok` (correction afli_end_longitude) | false on 144,368, as expected |
| | positions in whole minutes, ddmm and dddmm | false on 1,864 and 2,276 rows |
| | start depth fathoms, end depth metres on electronic records (correction afli_depth_units, TODO 113; scale checks) | hold |
| | `afli.afli` = round(gutted × 1.25) where `astand` is S (TODO 114) | true on all 434; `astand` is empty on 15,501,866 of 15,674,405 |
| dw (2026-10-17) | `dw_aflaskeyti`'s longitude columns hold the latitude (correction aflaskeyti_coordinates) | true at the start; false on 1 end, as expected |
| | every row says live weight (correction aflaskeyti_weight is the exception it does not see) | true |
| stk (2026-10-16) | the trail's `poslat` is radians | true on all 303,795,653 rows |
| | longitude equals latitude only on placeholders (correction ais_invalid_position) | false on 22,733, as expected |
| | `in_out_of_harbor` is I or U (decision 164) | no other code |

The sibling session's overlays for agf, ask and vessel (decision 175) pass the same checks.

## Found in passing, not acted on

- adb: on the trips whose source is `TRACKWELL` (2019-2024), 56,507 of 94,793 stations with both depths have
  `depth_end` 1.6-2.1 times `depth`, as afli's end depth is metres beside a start in fathoms (TODO 113). These trips
  are before 2025-11-19, outside adb's period in the flow (decision 160). Recorded as a `todo` in `adb.yml`.
- stk: 991,201 headings exceed a full turn (up to 12.04 rad), and 2,401 longitudes half a turn. A `todo` in `stk.yml`.

## Checked

`tests/test_data_dict.R` (40 expectations; no Oracle, no data but its own) and the existing dumper tests
(`test_dump_oracle.R` 42, `test_dump_oracle_code.R` 47, `test_dump_oracle_text.R` 29, `test_logbook_position.R` 17)
pass. No target calls a changed function (`_targets.R`, `_targets_once.R`).

## Rewritten

On the maintainer's go, 2026-10-22, `rewrite_data_dict()` then `check_data_dict()` on every schema in `raw/oracle/`
(`$FISHYDATA/archive/raw-oracle-data-dict_2026-10-22/`: `rewrite.R`, its log and results, and `before/`, the 28
dictionaries as the dumps wrote them, for undoing one). About 2 minutes in all. Only the 28 `_data-dict.yaml` files
changed under `raw/oracle/`. All 28 validate with no error (2,866 warnings: a `todo` per empty column and per open
question, and fiskist's S16); the 26 checks of the eight overlays (these five, and agf, ask and vessel of decision 175)
come out as their descriptions say, none NEWS. The column counts are those measured on the clones: 2,859 of 21,128
empty, 744 with values only past the first 10,000 rows.

## Not done

- Asks b-f of plan 040 stay open (c: the labels here are Claude's translations; d: whether NEWS blocks a swap).
- The overlays cover the seeded columns only. fs_afli's copies of afli's tables, fs_afladagbok, agf's other readers
  and the rest come with plans 038 and 039 (phase 2).
