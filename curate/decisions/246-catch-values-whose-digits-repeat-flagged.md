# 246 — Catch values whose digits repeat are flagged: `catch_flag` rule 4, `repeated_digits`

*2026-10-30. The maintainer's choice ("proceed", read as TODO 166's choice a, the proposed rule); the measurement, the
code and every number below by Claude (AI), not checked by a person. Coded and checked on a scratch store, then built
the same day on the maintainer's go ("Yes, build it"). Plan 053 row I4; closes TODO 166; decisions 216, 217 and 241.*

## Why

Plan 053's row I4 found STOKKUR's 276 trial trips of 2021 carry 12,119 t of logged catch, 11,667 t of it flagged by
rules 1 and 2. Of the 452 t left, 333.3 t is one row: 333,333 kg of basking shark (288) on station 59912, which decision
217 named as out of reach, since no landing has held 288. The other 118.6 t are values of ordinary size (9,800 kg of
lumpfish, 8,000 kg of cod) that no rule on the value tells from real catch. They stay I4's: the trips noted
`unlanded_cluster`, the catch kept (the maintainer, 2026-10-30, plan 053 ask h).

## Measured

`$FISHYDATA/archive/2026-10-30-catch-flag-test-values/` (`README.md`, `scripts/01_account.R`, `counts/c01`-`c08`).
Every logbook catch row is in one outcome: 17,026,059 rows and 51,031.2 kt, the same out as in, in all 75
source-years. Rule 2 is reproduced row for row.

- **A value's digits, judged where the landing is a witness** (trips with a linked landing). Values of 6 digits or
  more whose digits repeat, or are one digit then nines: the landing contradicts all 11 that are not small pelagics,
  10 beyond rule 1's margin and 111,111 kg of cod at 9.8 times. The 5 small-pelagic ones (120,120, 142,142 and
  230,230 kg of herring; 299,999 and 999,999 kg of mackerel) are each within 0.5-2 times their landing: round hauls.
  At 5 digits, 97 of the 100 that are not small pelagics are within 0.5-2 times. Read as gutted (kg / 1.25), the digits
  add no value of 6 digits or more.
- **Further landing witnesses, not chosen.** The species' largest landing by vessels of the same length class flags
  23.9 kt before 1993, when the landings begin, by later fisheries (Norway pout of 1973-83, 19.7 kt, against 5.5 t);
  from 1993 it adds 1.9 t. The vessel's own largest landing with fewer than 50 records flags at most 72.9 t, all of
  it in 1987-1991. Rule 2 takes what the landings can judge.

## Chosen

Rule 4, `repeated_digits`, in `curate/corrections/catch_landing_contradicted.{yml,R}`: a catch row of 100,000 kg or
more whose digits repeat with a period of at most half their length (333,333; 3,703,703; 550,550) or are one digit then
nines (7,999,999). Small pelagics (the species reference's target assemblage SPF) are left out. It applies on any
trip, linked or not, where rules 1 and 2 leave the (station, species).

`catch_flag` gets one row per (station, species), with witness `value` and the trip's logged kilograms of the species.
Where a linked landing holds the species, its kilograms are shown, not compared. Nothing is corrected. The target now
reads the species reference (`species`). The asserts and enums of `docs/data-dict.yaml` take the rule. The `flag` enum
gains `landed_not_logged` as well, which decision 241 left out of it.

## Checked on a scratch store

The inputs were linked file by file into a scratch `$FISHYDATA`, and the script wrote only there: no file of the real
store is newer than a marker set before the run. Against the real `catch_flag` (90,924 rows), the scratch one holds
90,926.

- **The rows already there:** every column is the same, but `vessel_kg_largest` on three rule 2 rows, which moves by
  at most 1.6e-16 relative. That is the order of float sums, as decision 241 found.
- **The two added rows:**
  - fs_afladagbok station 59912 (STOKKUR, 2021): 333,333 kg of species 288, with no landing linked;
  - afli station -1006748 (2018): 111,111 kg of cod, whose linked landing holds 11,346 kg.
- (station, species) stays unique on the 88,109 station rows, and every assert of `docs/data-dict.yaml`, rule 4's
  among them, holds on every row.

## Built 2026-10-30

At dbece0c with a clean tree, under DuckDB 1.5.6 and ramb 2026.10.28.3. `tar_make_isolated(names =
"catch_landing_contradicted")` built the one target in 7 s (09:06 UTC). Before the build, `tar_outdated()` listed it with
`ais_catch` and `check_allocation_audit`. After, it lists those two, which stay out of a build unless asked (decision
241). The run, its logs, both fingerprints and the table as it was before are in
`$FISHYDATA/archive/2026-10-30-catch-flag-test-values/build/` (`build.sh`, `run.log`).

The fingerprint taken after was compared with the one taken before (decision 241's method). Each of the 8,045 files
falls in one outcome:

- **The same: 8,044.** 8,041 by rows, schema and row hash. 3 are empty both times, with the same schema:
  `raw/oracle/adb/diving.parquet` and the two staged `sensor_summary` files of adb and fs_afladagbok. The comparison
  leaves no row hash for an empty file, so these were checked by hand.
- **Rows changed: 1**, `curated/logbook/catch_flag.parquet`, from 90,924 rows to 90,926. It is stamped at dbece0c,
  with `fd.dirty` false.

Each of its rows falls in one outcome:

- **The same: 90,899.**
- **A value moved: 25** rule 2 rows, in `vessel_kg_largest` only, by at most 1.4e-16 relative. This is the order of
  float sums: the scratch run moved 3, this one 25.
- **Only after: 2**, the two rows of rule 4 as on the scratch store, 444,444 kg.
- **Only before:** none.

The AIS catch is out of the store (decision 241). When it is next built, `kg_flagged` takes rule 4's rows as it takes
the others: `ais_catch.R` reads every flagged (station, species).

## Left, outside this decision

- **The trial clusters' 249 t that look like real catch** (STOKKUR 118.6 t, four other apps 130.4 t) are plan 053's
  row I4: the trips noted `unlanded_cluster`, the catch kept.
- **The 4,653 kt logged before 2007 on trips with no landing** has no landing witness. It waits for plan 038 §8 step
  1c's range by gear and species, taken from the logbook itself.
