# 268 — The user tables' first release: plan 056 built, its versioning chosen, the inshore hauls placed by their fjord square

*2026-10-31. Plan 056, executed on the maintainer's word: "we should stick with the original plan, even though this is
a trial. we may discover something along the way, and we may be able to tick off TODO's". Built, checked and written by
Claude (AI); the numbers come from its runs, and no person has checked them. The live build's scripts and logs are in
`$FISHYDATA/archive/2026-10-31-plan056-build/` (`before.R`, `build.sh`, `after.R`, `publish.R`, their logs,
`files.csv`). The scratch run was on a clone of the store, `/Users/einarhj/stasi/scratch-p056/`.*

## Decided (the maintainer, 2026-10-31)

- **The form.** The user tables are a conventional data repository, a directory tree of frozen releases, read as
  parquet files with nothing installed. They are not an R package: one with the parquet files in `inst/` was weighed
  and set aside. A reader package over the repository may come later.
- **The versioning** (TODO 140's first half; plan 056 §2):
  - **Kept, not rebuilt.** A release is kept, never rebuilt, since the same code does not give the same bytes back.
  - **The id.** It is `YYYY.MM.DD.n`, with a schema version `MAJOR.MINOR` beside it.
  - **One id for the whole release.** A release is never rewritten.
  - **`CHANGES.md`** classes each change by its cause: new data, method or correction.
  - **The manifest** records fishycode's and ramb's commits: for each file at its build, and for the release when it
    is published.
- **Plan 056's asks a-h**, each as recommended after a check of the data:
  - a folder on an MFRI share, with no links;
  - no AIS in the release;
  - `gear` and `rigging` without `_part`;
  - the e-logbook's tow time filled from its times;
  - the logged summaries, the fleet's Nephrops and ICES in `aggregate/`;
  - a `flag` column on the catch, and `landed_not_logged` as its own table;
  - the candidate rebuilt by targets, and published by hand.

## Built

Code at c85f500, a fix at 4627437, the README's count at 08321a4.

- **`write_curated()` stamps `fd.ramb`** (ramb's version and the commit `remotes::install_git()` recorded) and
  **`fd.duckdb`** on every curated file.
- **The fjord squares** (TODO 172):
  - the afli adapter stages `skiki`, `fj_reitur` and `fj_skiki`;
  - `sources/ops_sigfus/convert.R` stages `fj_reitir`;
  - the merge gives an afli haul with neither position nor square its fjord square's square and sub-square, with
    `sq_basis` "derived". `sq_basis` is "recorded" where afli gives the square.
- **The aggregates.** `sources/ops_sigfus/convert.R` stages the three monthly summary tables, and
  `curate/aggregate.R` writes `curated/aggregate/`:
  - `logged_monthly`, with `repeats_hauls`: plan 041 §3.3's rule as a flag;
  - `nephrops_fleet`;
  - `ices`, Iceland's rows, read where the dump put it, and flagged where a species-year is above ten times the
    landings that hold it.
- **The candidate.** `products/user_tables.R` became the target `user_tables`:
  - the names, the tow time, the flags, `sq_basis` and `area`, and links to the aggregates;
  - a stop on any person's column.

  It does not depend on the AIS tables it only links: a build of it by name would otherwise rebuild the trail.
  `products/user_tables_check.R` is its check, the target `user_tables_check`.
- **The release.** `R/release.R` holds `publish_release()`, `compare_release()` and `release_meta()`.
  `products/repository/` holds the metadata's text, the two READMEs and the index. `tests/test_release.R` has 15 tests,
  all passing.

## The build

20 targets were built by name (`names.txt`), all on the logbook side, none of AIS. The first run stopped at the eighth,
`ops_sigfus`: my target definitions passed a vector of file names to `fd_staging()` and `fd_curated()`, which take one
path. It resumed after the fix. Each of the 46 files in the build's account is in one outcome (`files.csv`):

| outcome | files | which |
|---|---:|---|
| data unchanged | 25 | only their stamps differ |
| columns changed | 2 | `staging/afli/station` and `curated/logbook/station`, below |
| rows changed | 1 | `catch_flag`: `vessel_kg_largest` alone, the order of a floating-point sum, as decision 265 found |
| new | 18 | the aggregates, the staged summaries, the candidate's written tables and check, and the two new raw targets' files |

- **The station table**, column by column:
  - `sq` and `ssq` changed;
  - `skiki`, `fj_reitur`, `fj_skiki` and `sq_basis` are new;
  - every other column is identical.
- **The placing.** 216,425 afli hauls are placed by their fjord square (91 of the 1960s, 45,774 of the 1970s,
  72,888 of the 1980s, 93,745 of the 1990s, 3,927 of the 2000s), as TODO 172 expected. The merge's rule changes no
  row whose square or position is recorded. 24,183 afli hauls still have neither position nor square.
- **The candidate's check.** All 14 checks pass:
  - every row and every kg of the written tables against curated/;
  - the summaries' 34,272 rows and 206.6 kt;
  - all 19 tables there;
  - every column described;
  - no person's column;
  - `meta.yml` clean under `validate-spec` and `validate-data`.

## Published

Release **2026.10.31.1**, in `$FISHYDATA/published/releases/2026.10.31.1/`, with every check of `publish_release()`
on. It holds 36 files, 1.95 GB, made read-only. Its index, `LATEST` and the repository's README are beside it.

- **Published from** fishycode 08321a4, with ramb 2026.10.28.3 at 5a01d76.
- **Built from** fishycode 09a18fc, 4627437, 93dfbdb, ba1d53d and f76e73c.
- **ramb at each file's build:** 11 stamped, 3 derived, 4 not used, 18 frozen (the logger's year files, decision 075).

It is not yet on the share: the path is not decided (TODO 175).

## Found on the way

- **The local folder is `$FISHYDATA/published/`** (`fd_published()`), there since the restructuring. Plan 056 had
  said `products/published/`.
- **`landed_not_logged` carries its species,** `sid_landing`. The plan had said it has none.
- **Re-stamping the reference tables (port, gear, species) would cascade into the AIS foundation.** Port tags the pings,
  so hours of rebuild would follow, for identical data. So ramb at a file's build is known one of four ways:
  - **stamped:** the file carries `fd.ramb`;
  - **derived:** the file was built after the installed ramb was;
  - **not used:** the file's script, as it stood at the file's own commit, calls no ramb function, directly or through
    an `R/` function that does;
  - **frozen:** a once fix, named by its record.

  `publish_release()` refuses any other.
- **Four tables were built before ramb 2026.10.28.3 was installed.** They are `reference/port`, `reference/species`,
  `vessel/vessel` and `vessel/vessel_year`. They were built on 2026-10-28 between 13:52 and 14:49 UTC, and the ramb was
  installed at 19:56. So decision 239's "every target ... rebuilt with ramb 2026.10.28.3" does not hold for them. Their
  scripts call no ramb function.
- **R's YAML reader turns an integer past 2^31 into NA,** with a warning. A `.lid`'s range then fails the spec, so the
  tool's draft is read with integers as doubles.
- **The ICES flag holds 30 species-years, for different causes:**
  - ICES's own errors: Nephrops 2018 at 86 times the landings, several other species that year, and Pollack 2010;
  - a state the landings record otherwise: lumpfish, landed as roe;
  - odd bycatch totals.

  The flag fires only where the landings hold the species that year: at first it fired on every 0.
- **The e-logbook's tow time is afli's quantity.** afli's recorded tow time is the span `t2` → `t3` on 765,100 of its
  765,154 bottom-trawl stations from 2008, and shrimp tows' medians run on across the change of source.
- **Listed in the release's known gaps, not explained:**
  - 22,588 stations whose vid is not in the vessel table, most of them lumpfish-logbook boats of 1980-2015;
  - the e-logbook's Nephrops tows, a median of 91 minutes against afli's 5-6 hours.

## Closed and left

- **TODO 172 is closed**, and deleted from `TODO.md`: its check is met.
- **TODO 140:** how a product is versioned is recorded here. The plan for the user tables after the colleague's
  feedback is left.
- **TODO 175:** the share's path and the copy are left, with the copy checked against the manifest, then the
  colleague's use.
- **Plan 056 is partly built.** The scratch clone may be removed on the maintainer's word.
