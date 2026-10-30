# 254 — The logbook merge in DuckDB: the same six files, R only for the rules written in R

*2026-10-30. Plan 054 step 2, the merge's mechanics, not its rules. The maintainer asked why step 2 took so long
("this should not really take such a long time"), and then for code that is efficient, with lazy DuckDB where needed
and "something that does not take ages" as the bar. Coded by Claude (AI) in a side session and checked on a scratch
store, not by a person. Merged into main as ef06b5b on the maintainer's standing word for proven branches. The scripts,
logs and comparisons are in `$FISHYDATA/archive/2026-10-30-plan054-lean-merge/` (`draft-lean-merge.md` has every
table). Nothing is built on the live store.*

## Why

`curate/logbook.R` loaded every staged table whole into R, with 29 `collect()` calls: 6.8 M afli stations, as many
fishing samples, and 15.6 M catch rows. It then merged in dplyr. A scratch merge took 6 to 13 min and held up to 19.5 GB
of a 24 GB Mac. Every traced change paid for that, and two scratch merges could not run at once. Measured section by
section, the time was spread over the plumbing (the fate, the twins, the station type, the tiers), not over the rules.

## Chosen

- **DuckDB reads the staged files where they lie.** The tiers, the joins and the fate run as SQL over narrow key
  tables, and each output is written by one query (`write_curated_sql()`), in the row order the old merge wrote.
- **R keeps the rules written in R**, each on the rows and columns it reads: the twins' catch signature, the apps'
  names (on the distinct strings), and the app profile's flags (`R/logbook_app_profile.R`, unchanged).
- **R's semantics are kept where SQL differs.**
  - A missing key matches a missing key, as dplyr's joins did.
  - `.tid` is written as `as.character()` writes it.
  - Constants are doubles.
  - The fate's sums run in the stations' order.
- **The `relationship` checks became key checks.** The merge stops before a join if a key appears twice. That is
  slightly stricter than before: a duplicate key that no row joined used to pass.

## Checked

- **The six files equal the in-memory merge's**, at the same commit's inputs, for `trip`, `station`,
  `fishing_sample`, `catch`, `station_fate` and `trip_fate` (1.85 M to 17.0 M rows). That means the same schema,
  nothing in either side's EXCEPT ALL, and every row in the same place. Every repeat of both merges equals the first
  run.
- **Time:** the median repeat takes 60 s against 371 s; the first runs took 67 s against 795 s.
- **Memory:** the peak footprint is 9.2 GB against 19.5 GB.
- **The real store:** no file was written.

## Found

- **R's scientific form for 5 trip keys.** afli's and fs_afladagbok's double `.tid` goes through `as.character()`, so a
  round number is written as, for example, "1e+05": 3 afli trips (36 stations), and 2 fs_afladagbok trips that are only
  in `trip_fate`. They are kept as they were. Writing them as integers would change keys, which needs a decision of its
  own.
- **The old merge compared afli's POSIXct dates with Date bounds.** That works only while lubridate is attached. The
  SQL compares them by DuckDB's own rules.
- **`fd.schema_hash` changes once.** `write_curated_sql()` hashes DuckDB's types, where `write_curated()` hashed R's
  classes. Nothing reads the stamp.

## Left

The writes are now most of the time and hold the memory peak (39 of the 67 s). That meets the maintainer's bar, so it
is left as it is.
