# 266 — Records and factors in one long table: tested on Nephrops and shrimp, set aside

*2026-10-30. Proposed by the maintainer the same day, in a discussion of where aggregated data belong; tested by Claude
(AI) in a side session, read-only, not checked by a person; set aside at the maintainer's word ("ok - so this one can
consider a failure"). The scripts, logs, the long table and the account are in
`$FISHYDATA/archive/2026-10-30-nephrops-shrimp-factors/` (README first); the reading of `ops$sigfus`, afli's fjord
squares and the ICES table that led to it in `$FISHYDATA/archive/2026-10-30-records-and-statistics/`. Plan 055 takes
the lessons into the grammar.*

## Why

The aim, as the maintainer put it on 2026-10-30, is tables an analyst can use without knowing the pipeline: a biologist
interested only in his species wants a quick answer, and the product should be robust enough to keep him from going
wrong. The ICES datacall is a side product.

The proposal: one long table, one row per record × variable, the value as recorded, and factor columns tying each row
to a named total (`factor_landed`, `factor_statistic`), each with its stratum and basis. Rows are leaves (a record is a
row only where no finer record of the same quantity lies inside it); a move between levels is a factor (a total over
the records in its stratum, or a census of effort over a sampled one); one quantity per ladder; lineage and coverage
tested as bookkeeping. It was tested end to end on MFRI species 40 (Nephrops) and 41 (shrimp), the two fisheries with
the oldest coarse records, from the first record (shrimp 1936, Nephrops 1959) to 2026-10.

## What it did

As bookkeeping it held exactly. With one cascade of strata (the landing a trip is linked to, then vessel × month, then
vessel × year), Σ value × factor reproduced all 91,973 landed strata to the kilogram and ICES in all 124 species-years
it has. Every source record ended in one outcome, kg in = kg out per source, and the coverage history fell out of the
factors.

## Why it is set aside

As the analyst's table it failed, for reasons that do not depend on the species:
- **Rows of several quantities in one table add up wrong by default.** `sum(value)` returned 2.7-3.0 × the landed
  total in every year tested (Nephrops all years; shrimp to 1995).
- **Records that partition one quantity in crossing ways have no leaf.** `landed_catch_pre94`'s month × port × gear
  against vor's vessel × month (1982-90); the fleet's Nephrops month × square against the weighing register's vessel ×
  month (1966-72). One can only be a key, and a factor cannot carry a key: Nephrops by square in 1966-68 and 1971-72
  has no answer in the table, though the store holds the totals.
- **NA, 0 and 1 in a factor mean different things** (outside the total, no landing found, carries itself). A reader
  who takes NA as "unknown" gets it wrong.
- **An implausible total travels through its factor.** ICES's Nephrops 2018 (62.6 kt against 0.73 kt landed) gives
  every haul of 2018 a factor of 86; a statistic-raised square map of the 2010s is then 85 % that one year.

More testing would not change this. The table with factors is a builders' account, not an analyst's product. The
maintainer asked whether it should stay in the grammar as alternative thinking; the answer was no: recorded here as
tested and set aside, its lessons kept as rules (plan 055 §3).

## Found on the way

Measured by Claude, not checked by a person; the logs are in the two archives named above.
- **`ops$sigfus` holds what afli holds.** `gamall_humar` matches afli's Nephrops summaries cell for cell (20,822
  cells); afli split a source row where its tow minutes passed 9,999 (the source holds hours). No vessel, raising factor
  or tails mark for the fleet's records. **The seine's 937 rows of 1967-1970 (7.2 kt) in `gomul_dragnot` were never
  loaded into afli** (TODO 136).
- **`staging/afli/aggregate.parquet` keeps no place for the 12,708 shrimp summaries**: no area, no square (TODO 136).
- **228,259 afli hauls (113.9 kt, mostly the inshore shrimp of 1972-2003) have no position or square in curated.**
  `afli.stofn` holds their fjord square (`fj_reitur`), which nothing reads; `ops$sigfus.fj_reitir` places 216,425 of
  them (TODO 172).
- **The fleet's Nephrops of 1960-72** (no vessel, 789 source rows, 36.5 kt) equal the weighing register by year (within
  2.2 %), not by month, and are not afli's hauls raised: allocated at the year, key unknown, quantity unknown.
- **ICES for Iceland is compiled from the landings from 1966** (within 1-3 % every year 1966-2015), so a witness, never
  a check. Its errors from 2010 are its own: Nephrops 2010 and 2016 absent, 2018 86 ×; shrimp 2016 under both PRA and
  PAN (1.82 ×), 2018 1.9 ×.
- **vor's `afli_einstakra_skipa` holds 1984 as one date per vessel** (a vessel-year), and crosses `landed_catch_pre94`
  in 1982-90 (TODO 123).
- **Catch raised by effort from logging to non-logging vessels is above the landed total** in 118 of 151
  species-years, by up to 37 %; before 1993 in 46 of 48. Logbook keepers fished harder.
- **The e-logbooks' tow time is in the times, not in `duration_m`**: by design (`.duration_source` `times`), but v0's
  logbook table leaves `duration_m` empty on every adb station and 347,852 of 378,818 fs_afladagbok stations (TODO 140).
- **Unexplained, listed:** Ísafjarðardjúp shrimp tows of median 0.5-0.9 h at 650-900 kg in 2011 and 2019-20; shrimp
  landings with no AIS voyage ending within a day, 1.4-2.2 kt a year in 2009-11, by vessels on AIS that year.
