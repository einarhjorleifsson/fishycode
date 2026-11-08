# 303 — Plan 062 step 5: the speed of astd and emodnet after the flags, the clean on ramb's lazy route

*2026-11-08. Plan 062 step 5 ("fishycode follows"), TODO 184, at the maintainer's word: "Yes, as proposed" (the
proposal, below) and, on the scratch run, "Delete, then rebuild". Coded, run and counted by Claude (AI); no person
has checked the code or the counts. The study, its scripts and every table:
`$FISHYDATA/archive/2026-11-08-plan062-step5/` (its README).*

## Why

Plan 062 moved step 0's last copies of ramb's work out of fishycode:

- the union's own speed for astd and emodnet, derived before any flag. On 2017, 28,758 kept speeds used a bad position
  as a neighbour (plan 062 step 1, test (i));
- the clean step's hand batching, which ramb's lazy route does since 2026.11.04 (step 4g).

## What was proposed and agreed

The plan's step 5, restated against the code of 2026-11-08:

- **The union** derives no speed for astd and emodnet: `speed`, `speed_raw` and `speed_span_s` NA, `speed_basis`
  `"none"`. Nothing between the union and the clean reads their speed.
- **The clean** runs on ramb's lazy route: `rb_flag_ping_invalid()`, `rb_flag_ping_duplicate()` and
  `rb_flag_ping_impossible("clean")` take the year as a lazy table and batch it themselves.
  - **Each year in its own R process.** ramb keeps the files of each lazy pass until the R session ends.
  - **Decision 299's ceiling stays.** `clean` takes one `kn_max` a call, so the vessels over 25 kn (about 1 M pings a
    year) are collected after the duplicate pass and judged in R, each at its own ceiling, as before. The other way,
    `clean` taking each vessel's limit from a table, would be a ramb change; it was not chosen.
  - **The tie stays in fishycode**, as SQL: ramb has no rule for two pings of one vessel in one second (plan 062,
    Decided f, not built).
- **ramb's speed after the flags.** `rb_add_ping_speed()` derives astd's and emodnet's speed, with plan 062's rules
  (Decided i, j): a flagged ping gets none; a copy (`duplicate`) stays a neighbour in its stream.
  - **On the delivered time, by provider and MMSI**, as the union did. On the harmonized time a feed's copies of STK's
    reports are moved onto STK's clock one by one and their neighbours are not: in 2017, 116,452 astd and 79,306
    emodnet pings.
  - **A year's first and last ping of a stream take one side.** The union read across New Year.
  - The 40 kn rule on `speed` is kept.

## What was run

- **The code:** fishycode 4e9c8dc, with ramb 2026.11.07.1 and DuckDB 1.5.6.
- **A trial on 2017** first: the new clean on the live `ping_tagged`, every row of its output the live store's, the
  derived speeds apart.
- **A scratch run from the union down** (2026-11-08, 14:48-17:08), on a `cp -c` clone:
  - every stage compared with the live store before the run deleted the scratch's copy of it (79 GB free; about
    108 GB written otherwise);
  - then the 16 targets below the clean, the comparison of every product, and the trail's speeds and labels.

## What it found

Every record from the union down is in one outcome, and every difference is explained.

- **The union, the tag pass, the clean, `curated/ais/ping`, the trail and `trail_match`**: every row of every year the
  live store's, apart from astd's and emodnet's speed columns and the fishing labels.
- **The labels**: every ping's label, basis and evidence the same, the 299 ceilings and `ping_limits` included, but two
  pairs of copies in 2019. Two astd reports of vid 1541, stationary, delivered minutes apart, were moved onto one STK
  time by their copy lags. In each pair one is `duplicate` and the other `tie` in both stores; which carries which
  swapped, since the union's speed ordered them and now the delivered time does. All four are flagged in both.
- **The speeds**: of astd's and emodnet's kept pings, 366,693,837 equal; 133,713 moved by 1 kn or more and 117,300
  under 1 kn:
  - 243,113 beside a ping flagged as a bad position;
  - 7,875 a stream's first or last ping of the year;
  - 25 raw speeds of 878 to 12,455 kn, `speed` NA by the 40 kn rule. They differ because the union's knot factor and
    ramb's differ in the ninth digit.
- **Port calls, voyages and the links**: every row the same. No trip end moved.
- **The trail**: `fishing` changed on 8,637 fixes and `fishing_flow` on 14,539:
  - 10,638 whose own speed changed;
  - 8,129 whose own speed did not, each within 600 s of a fix of its vessel whose speed did (the fishing rule's
    median over ±10 min).

  Fishing hours +431 (+0.005 %), `fishing_flow` +494 (+0.004 %), mostly in 2023 and 2024.
- **Float noise** in `trip_disposition`'s and `trip_landing`'s kg sums (at most 3e-16 relative).
- **One survey tow** in `survey_tow_times`: its AIS fishing stretch now ends 124 s from the survey's recorded end,
  against 333 s.
- **The clock check**: two descriptive columns, read by nothing, vary from run to run. `stk_receipt_gap_median_s` is
  DuckDB's `approx_quantile()`; `share_merged_under_60s` is a share over a window where pings of two feeds at one time
  and place tie. Every month that differs has such ties.
- **Time**: the clean took 46.9 min against 31.7 min live (1.48 times), at 9.1 GB at most.

## What was chosen

- **The switch is in the code** (4e9c8dc).
- **The live store is rebuilt**, at the maintainer's word ("Delete, then rebuild"). The scratch clone was deleted
  first.

## The live rebuild

- **When and with what:** 2026-11-08, 17:56-20:24, at 4e9c8dc, with ramb 2026.11.07.1 and DuckDB 1.5.6, under the
  heavy-job lock. The scratch clone was deleted first.
- **What it built:**
  - the 21 targets from `ais_ping_union` down: the union, the clock check, the tag pass, the VMS check, the clean and
    the 16 below it. `ais_ping_union` was invalidated by hand, since `targets` does not see a script's edit;
  - the effort map's two grids.
- **Its time:** 2 h 28 min. The clean took 49 min (31.7 min in decision 299's rebuild).
- **What it left outdated:**
  - `ais_catch` and `check_allocation_audit` (decision 261);
  - the place-name session's `name_group`, `place_name` and `place_name_evidence`.
- **The stamps:** all 425 curated files changed carry 4e9c8dc with a clean tree. The tree was clean after.
- **The same as the night's** (`rebuild/vs_night.R`, `vs_night_whacky.R`):
  - every `curated/ais`, link, v0 and `ping_whacky` file is the night's;
  - the clean's closing count is the night's, stage by stage;
  - `trip_disposition` and `trip_landing`'s check table hold the same rows with other float noise.
- **Against the store before** (`rebuild/after.R`, `after_staging.R`):
  - the union and the tagged pings change only in astd's and emodnet's four speed columns (14 and 17 files), and in
    where `speed_span_s` sits among the columns: the rows of all 44 files are the same;
  - `ping_limits`, `stk_receipt`, the copies table and the VMS check are unchanged;
  - `ping_clean` and `ping_whacky` are one file a year, where they were one a batch.
- **`user_tables` ran before the trail**, as in decision 299's rebuild: it does not depend on `ais_trail`. Its AIS
  tables are links into `curated/`, and its metadata holds nothing of the trail.

## What it leaves

- **Plan 062 step 6, the book** (`flow_pings.qmd`, plan 061), and with it TODO 184.
- **A per-vessel limit in ramb's `clean`**: would let the fast vessels ride the lazy route too. Not asked for.
- **The two descriptive columns of the clock check** that vary from run to run: an exact median and a full order
  would make them repeatable. Not pursued.
