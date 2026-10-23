# 216 — Catch the trip's landing contradicts is flagged, never corrected, and carried onto the fixes as `kg_flagged`

*2026-10-23. The maintainer's margin ("follow the proposal") and rule that flagged catch stays on the fixes, marked;
the code and every number below by Claude (AI), not checked by a person. Coded and checked on a scratch store; not
built. Plan 038 §8 step 1c; decision 210 item 3; decision 214.*

## Chosen

- **The rule.** Per (logbook trip, species): the trip's logged kilograms of the species against what the landings
  `lid_map` links to it (with the landing's own schema) hold of it. Flagged where the landings hold some of the species,
  and the trip logged more than 10 times that and at least 1,000 kg more. Every station of the trip with the species
  is flagged. Duplicate twins (decision 094) and catch let go (negative codes) are left out. The logbook's 830
  (herring, Atlanto-Scandian stock) is compared as the landings' 30: the comparison is of the taxon, and the stock is
  checked on its own (plan 038 §8 step 1c).
- **A flag, never a correction.** `curated/logbook/catch_flag.parquet` holds one row per flagged (station, species),
  with the trip's logged and landed kilograms beside it. Nothing in `logbook_catch` changes.
- **The flag travels with its kilograms.** `curated/ais/catch` gains `kg_flagged`, the flagged part of each row's
  `kg`, shared over the same fixes with the same weights by `rb_share_catch(value = )`. An analyst leaves the flagged
  catch out with `sum(kg - kg_flagged)` (decision 215: the filter is the user's). Kg in equals kg out for both columns,
  and the script stops if not.
- **Not judged here:** a trip with no linked landing (4,861 kt, mostly before 2007), which needs the gear and
  species' own range, and a landing that holds none of the species (710 kt), which needs a crosswalk of the
  logbook's codes to the landings' first. Both are left in plan 038 §8 step 1c.

## Built

`curate/corrections/catch_landing_contradicted.{yml,R}` (target `catch_landing_contradicted`, preprocessing: it
reads no AIS), `curate/ais_catch.R` (reads the flag, writes `kg_flagged`), `_targets.R`, and the two entries in
`docs/data-dict.yaml` with their asserts.

## Checked on a scratch store

The scratch store (`R_ENVIRON_USER` with its own `FISHYDATA`, the real store's inputs linked into it) ran both
targets' scripts. Nothing under the real `$FISHYDATA` was written: no file there is newer than a marker set before.
The checks are in `$FISHYDATA/archive/2026-10-todo126-ais-check/15*.R` with their logs.

- **The flag:** 87,838 (station, species) rows on 8,703 (trip, species) pairs, 293.7 kt. By source: afli 236.3 kt,
  fs_afladagbok 44.0, adb 13.2, aflaskeyti 0.3. (station, species) is unique, and every row meets the margin, the code
  rule and kg > 0. By what the trip landed of the species: 5,807 pairs landed 100 kg or more (278.6 kt logged),
  2,436 landed 10-100 kg, 457 landed 1-10 kg, and 3 landed under 1 kg (10 t). Those three rest on positive landing
  rows of nearly no weight, so they are flagged as the rule says.
- **The catch, 2015, 2021 and 2023:**
  - Rows the same as the stored catch: 76,199,810, 44,433,100 and 39,145,149. Each row matches the stored one on
    every label column, with kg equal to 1e-6 and the raise factor to 1e-9. In 2021, the year traced closest, the
    kg differ by under 1.2e-10, the order of summing.
  - `kg_flagged` lies between 0 and `kg` on every one of the 159,778,059 rows, and is over 0 on 124,389.
  - Kg in equals kg out for both columns in every vessel group.
  - The flagged kilograms on the catch equal the flag's by year of the station: 5,242.1 t, 3,652.1 t and 11,286.3 t.
    Under `fishing` almost all are on fixes. 2023's sit at the trip (8,088.6 t), the jig (2,214.4) and the tow
    (799.8). Those that find no fix (basis `none`) are 1.2 t, 56.3 t and 1.8 t.
- **The first known cases (decision 214), STOKKUR's six net and line stations:** two are flagged, fs_afladagbok
  stations 6449 (328,000 kg of species 951 against 2,602 kg landed) and 91104 (9,999,999 kg of cod against 4,205
  landed, 999,999 of species 2 against 872). The other four (45559-45561, the 11,111 t trip, and 59912) are not:
  their trips have no linked landing, so they wait for the range rule.

## The build

The build is the maintainer's: `tar_make_isolated(names = c("catch_landing_contradicted", "ais_catch"))`.
`tar_outdated()` on those two names lists only those two (2026-10-23), so nothing upstream is rebuilt with them. Then
`check_sync()`, and `kg_flagged` summed against `catch_flag` per year, as above.
