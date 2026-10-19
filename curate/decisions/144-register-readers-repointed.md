# 144 — The register's readers repointed, with mbl last, kvoti first for the class, SKEMMTISKIP as 62 and Hreiðar's years read right (plan 028 step 7)

*2026-10-18. Coded, measured and built by Claude (AI-assisted), on the maintainer's go ("Start plan 028 step 7:
repoint vessel_sign, vessel_class, vessel_year and registry.R to curated/vessel/register/, one at a time, with
fingerprints before and after"). The three changes to the decision model are the maintainer's choices, asked on the
way. Built by name at 4b2fdf8: the history in the `once` project, the register and the four readers in the main
project. The AIS chain and trail downstream were rebuilt the same evening at 3aacc9f, on the maintainer's go ("Yes,
rebuild the 20 outdated targets ... and check the trail's kw_basis and leisure against the old trail afterwards").
The maintainer then had 6061's 2016 kW set by a reviewed row, and everything was rebuilt again at e2f741f.*

## What step 7 found in the register first

Comparing each reader's old table with the register showed four faults in the register itself. Each was fixed in the
history before the readers were built on it.

1. **mbl's pages carry stale values.** From 2022 the period order put mbl's 2023-01 pages before the 2022 edition and
   the `vessel` schema's rows, for 2022-12-28 to 2023-12-19.
   - mbl gives 1136 the call sign TFGR, which the hull held until 2014 and 2847 has held since. It gives 2593 TFAJ,
     held until 2016, and 2778 TDFU for TFDU.
   - About 860 mbl values sat between two neighbours that agree with each other. Among them: 278 horse powers
     (rounded or older: 1800 against 1802), 250 net tonnages, 147 maximum lengths (about 10 % short, though mapped as
     the page labels them) and 3 call signs.
   - In `vessel_sign`, the one-holder rule then ended 2847's TFGR at mbl's date, the live years included.
   - **Chosen** (maintainer, "mbl last"): mbl fills only where no other source speaks.
   - Alone, this moves 4,316 values on 2023-06-01 to the 2022 edition or the `vessel` rows. Engine makes account for
     1,758, horse powers 560, previous names 705 and call signs 4. Nothing before 2022-12-28 moves.
2. **The `vessel` schema's back-fill missed the change to Þróunarsjóður (−10).** kvoti dates it: 6300 from
   1994-12-09. The back-fill keeps class 3 until 2024-02-02, when the live system sets −10 itself.
   - The period order ranked that back-fill above kvoti for 2004-2021. So the register took the pre-1994 class on
     about 105 hulls a month, mostly 98, Þorskaflahámarksbátur, a class that ended around 2004.
   - mbl's "Þróunarsjóður" on 109 hulls, first read as stale, agrees with kvoti.
   - **Chosen** (maintainer, "kvoti first for class"): for `vessel_operational_hist`, kvoti and ufs come first in every
     period before 2023-12-19. This restores −10 on 131 hulls on 2005-06-01, 105 on 2015-06-01 and 103 on 2023-06-01,
     and changes no other class.
3. **SKEMMTISKIP mapped to 33, FISKISKIP.** The printed type means a pleasure ship: 6,723 entries on 1,289 hulls. It
   took 33 by the history's last mapping rule, because the `vessel` schema gives 87 % of the same hulls 33 on the same
   dates.
   - The live system calls the 349 hulls printed SKEMMTISKIP in 2022 33 (216), 62 (89) and 68 (12).
   - With 33, the trail's leisure vessel-years (usage 60, 62 or 68) in 2007-2021 would fall from 11,026 to 3,028.
   - **Chosen** (maintainer, "62, by its name"): a reviewed row in `overrides/usage_category_printed_reviewed.csv`. It
     covers every case of the spelling.
4. **Hreiðar's years were read shifted.** `skipaskra_history.R` read `year` and `year_out` from
   `staging/hreidar/vessel_year.parquet` with `nanoparquet::read_parquet(col_select = )`.
   - nanoparquet 0.5.1 drops the NULLs of an optional integer column in a file it wrote, and shifts its values up. The
     file's 1,214 placeholder years are NULL, so 157,501 of 164,164 years and 162,408 of the `year_out` values came
     back as another row's. A whole read is right.
   - The staged file is right too: by sheet row it equals the workbook on number, year, name and kW.
   - So the evidence, which reads the file whole, was never affected. The registered runs before 2004 and the fates
     were: they rested on shifted years (decisions 136 and 142).
   - Every other `col_select` in the repo was tested against a whole read on the real files, and all are exact. Both
     reads of this file now read it whole and select. AGENTS.md carries the rule.
   - What the fix changes:
     - registered runs: 6,157 on 4,702 hulls become 5,001 on 4,793;
     - registered hull-years: 2004-2023 unchanged; before 2004, 16,838 added and 7,570 dropped;
     - the share of registered life the rows cover: `vessel_hist` 97 → 100 %, `vessel_identification_hist`
       96.6 → 99.3 %, `vessel_measurement_hist` 97 → 100 %, `vessel_engines_hist` 90 → 94.3 %,
       `vessel_operational_hist` 97.7 → 98.5 %, `vessel_fishery_hist` 89.9 → 94.5 %.
   - Still true: all 880,054 PDF values are on the history on their 1 January, and the live part's open rows equal the
     current tables, 79,855 of 79,855.

The history (`once`, 4b2fdf8) now holds:

| table | rows |
|---|---|
| `vessel_hist` | 30,078 |
| `vessel_identification_hist` | 24,430 |
| `vessel_measurement_hist` | 15,408 |
| `vessel_engines_hist` | 11,929 |
| `vessel_operational_hist` | 37,192 |
| `vessel_fishery_hist` | 21,441 |
| `vessel_owners_hist` | 28,434 |
| `vessel_event` | 18,365 |
| `registered` | 5,001 |
| `decision` | 275,202 |

The register for every year, before (decision 142) and after:

| table | before | after |
|---|---|---|
| `vessel_hist` | 33,323 | 34,235 |
| `vessel_identification_hist` | 25,711 | 27,174 |
| `vessel_measurement_hist` | 17,806 | 17,817 |
| `vessel_engines_hist` | 15,820 | 14,356 |
| `vessel_operational_hist` | 42,608 | 43,467 |
| `vessel_fishery_hist` | 23,757 | 24,682 |
| `vessel_owners_hist` | 31,084 | 32,429 |
| `vessel_event` | 20,841 | 18,486 |
| `registered` | 8,462 | 7,306 |
| `decision` | 364,198 | 362,464 |

## The four readers

Each was rewritten to read `curated/vessel/register/` and run in a scratch store against the built inputs. It was
compared with its old table value by value and built alone by name. Its built file equals the scratch run's, stamped
4b2fdf8, not dirty. The old files are kept in the session's scratchpad only. The fingerprints (`R/fingerprint.R`):

| file | rows before → after | schema | columns unchanged |
|---|---|---|---|
| `vessel_sign` | 29,664 → 29,983 | same | none |
| `vessel_class` | 37,926 → 39,309 | same | none |
| `vessel_year` | 140,940 → 140,940 | `mclass_source`, `kw_source`, `loa_source` added | `vid`, `year`, `segment` |
| `vessel` | 7,249 → 7,249 | `yh1`, `yh2` integer | all but `yh1`, `yh2` |

### `vessel_sign`

Call sign, local sign and name now come from the register's identification and name columns. Each value's `source` is
the witnesses of the register's decisions for that column; the register's own `source` names a row's, not a
column's. Hulls fall from 7,170 to 4,793. Compared on each 1 January:

- **Call signs.**
  - 2004-2006: 1,322 hull-years gained from the PDFs. The old table had none before 2007.
  - 2007-2021: 5,771 the same, none different. 27 are only in the old table: the PDF entry leaves the sign blank, and
    a blank means none. 13 are only in the new: the 2020-2021 matrices miss rows the PDFs print.
  - 2022-2023: 690 the same. 3 differ, where the 2022 PDF prints another sign than the old annual table (1977: TFKU,
    not TFHS).
  - 2024-2026: 1,045 the same.
- **Hulls the register does not carry.** The old table read an empty status in the `vessel` schema as on the register.
  So a struck hull's marks ran on to 2023: 132,687 of the old-only values. Foreign hulls account for 31,155 more.
- **Names and local signs on hulls both carry** follow the PDFs and Hreiðar over kvoti and the back-fill (D3). In
  2007-2021, 1,874 names and 952 local signs differ. 6559 is BOGI SIGURÐSSON in every edition 2006-2013 and in
  Hreiðar, and Dagga in kvoti.
- **The one-holder rule, refined for call signs.**
  - A call sign is the hull's for life, so another hull takes it over only by holding it to the first one's end or
    beyond.
  - A holding nested inside another's is two hulls on one mark: both are flagged `conflict`, for the overlap only. For
    example, mbl's sole 2023 value gives 2730, back on the register that year, the TFCR it held until 2013, while
    2892 holds it.
  - Local signs keep the old rule, a later holder's dated change ends the earlier: applying the nested rule to them
    too pushed conflicts since 2007 past the script's 1 % limit.
  - Conflicts since 2007: 6 of 5,810 mark periods, against 14 of 6,905 before.

### `vessel_class`

The class code comes from the register's `vessel_operational_hist` and is named from the `vessel` schema's code table,
not from `history.rda`.
- Where the table lacks a code, the name comes from the schema's own rows: 12, Hvalveiðiskip, on four hulls from
  2026-02-18.
- The register's own name column follows its own witnesses: 622 of its 41,185 named rows name another class than their
  code (595 history, 27 live). `vessel_class` therefore does not read it.
- Compared month by month:
  - 2000-2023: every hull-month both tables carry has the same class, bar 4.
  - Old-only months are classes on hulls off the register: Núllflokkur (0), foreign (−4), and −10 after
    deregistration.
  - From 2024 the live system's changes appear, which the old table missed by carrying kvoti's class of 2023-12-07.
    The 2024 and 2025 Strandveiðar seasons account for 5,848 vessel-months moving from 96 to −12.
  - Leisure months are the same through 2023, and differ by about 100 in 2024-2026.
- `observed_to` is the `vessel` schema's last entry, 2026-06-16. Every one of its history tables ends that day,
  although the dump is of 2026-10-16.
- `leisure` adds 89 (Frístundaveiðar - aflamark), which no row carries yet.

### `vessel_year`

The usage code, kW and length overall now come from the register, as the value in force on 1 July.
- **kW** is `power_kw`, the vessel's power. The main engine's power stands in where `power_kw` is missing: 13 hull-years
  on the register. It is not the first choice because in 2022-2026 it differs from `power_kw` by more than 20 % on 454
  hull-years.
- **The basis is the path**:
  - `register`: the value on 1 July;
  - `register_later` and `register_earlier`: a hull registered later or struck before;
  - `current`: the `vessel` schema's value, for hulls the register never carries;
  - `none`.

  The register's witnesses are in `*_source`.
- **Hreiðar's segment** comes from his staged workbook. It equals the old values wherever both have one.
- Compared vessel-year by vessel-year, 2007-2021 and 2022-2026:

  | | 2007-2021 | 2022-2026 |
  |---|---|---|
  | kW the same | 67,968 | 22,691 |
  | kW within 5 % | 966 | 219 |
  | kW more than 20 % off | 11 | 41 |
  | length overall the same | 80,412 | 26,717 |
  | usage code different | 644 | 710 |
  | leisure vessel-years, old / new / both | 11,026 / 11,173 / 10,987 | 3,721 / 3,703 / 3,645 |

### `registry.R` → `vessel.parquet`

Only `yh1` and `yh2` change. They are now the first and last year on the register, `yh2` NA while the hull is on it
(2,244 hulls).
- They were Hreiðar's first and last year keyed on `Skskr.nr.`. Decision 046 found that key auto-incrementing in old
  blocks, which made 164 hulls' ranges wrong.
- `yh1` is the same on 4,420 hulls and differs on 289. `yh2` is the same on 2,411 and differs on 136.
- `vessel_identity` (`reference/vessels/identity.R`) reads them to bound a hull's lifetime, so the change reaches the
  ping union. Its old horizon rule (a `yh2` of 2021, Hreiðar's last year, read as still open) now meets a `yh2` that is
  NA while the hull is registered.

### Targets

- `vessel_sign`, `vessel_class`, `vessel_year` and `vessel` now depend on `vessel_register`.
- `hreidar_vessel_year` is a frozen input for `vessel_year`.
- `annual_call_sign`, `vessel_sign_raw`, `vessel_hist_raw` and `vessel_class_raw` left the main project.
- `vessel_raw` still lists Hreiðar's workbook, which no main script reads now. Dropping it would cascade through
  `mmsi` into the AIS chain for nothing.

## The downstream rebuild

All 20 targets downstream of `vessel.parquet` were rebuilt by name in the main project, from 20:54 to 22:48 UTC:
- the run ended "ALL DONE", exit 0, and `tar_outdated()` is empty;
- all 856 files the targets record are new, the 689 curated ones stamped 3aacc9f, not dirty (the 167 staging ping
  partitions carry no stamp);
- the longest steps were `ais_trail` (32 min), `ais_ping_clean` (21 min), `ais_catch` (20 min) and `ais_voyage`
  (15 min);
- the warnings are decision 129's: the SQL notice on missing values, and the `vid` coercion in `vessel_ais_link`.

Before the build, the old trail and catch were aggregated by vessel and year, and the 856 files fingerprinted.
- **The chain above the trail changed, though this record first said it would not.** `vessel_identity` reads
  `yh1`/`yh2`, which the first draft of this record missed: a search for their readers was cut short.
  - Identity rows go from 5,409 to 5,421; 5,181 windows are unchanged.
  - 12 of 20 ping-union partitions change, and the trail's fixes from 2019 rise by 74,000 to 101,000 a year: 671,363
    gained and 7,884 lost, on 26 vessel-years of 10 hulls.
  - Nine of the ten had an old `yh2` before 2021 from the misread key, and are on the register. Most of the gain is
    one hull: 2173, TÓMAS ÞORVALDSSON (TFUT), whose MMSI-keyed pings 2019-2026 an old `yh2` of 1995 had shut out
    (+662,066 fixes). It lands every year 2019-2026.
  - 7,860 fixes in 2023-2024 move from 1773, struck in 2016, to 7107, which holds the MMSI since 2018.
- **kW-hours.** Total kW-hours change by at most 0.32 % in any year (2022), mostly through the gained fixes. On
  fishing fixes (`fishing_flow`), by vessel-year:

  | change | vessel-years | kW-hours before → after (GWh) |
  |---|---|---|
  | the same | 23,530 | 11,834 → 11,841 |
  | within 5 % | 364 | 1.90 → 1.89 |
  | more than 20 % | 1 | 0.01 → 0.15 |
  | a kW where there was none | 1 | 0 → 0.01 |

  The one vessel-year over 20 % is 6061 in 2016. The `vessel` schema's history gives it 728 kW that year alone,
  against 58 in the years either side, in the 2016 PDF and in Hreiðar: a typo in the back-fill. `power_kw` has no
  other witness, so no rule caught it.
- **`kw_basis`** on the trail's fixes: `register` 564.8 M, `register_later` 10.5 M, `register_earlier` 1.9 M,
  `current` 0.2 M (was 72.7 M), `none` 7.6 M (was 7.6 M). The old `hreidar`, `oracle_hist` and `oracle_later` are
  gone.
- **Leisure** stays at 1.04 % of all fixes.
  - By the class: 2,709,204 fixes in 2007-2021 (2,709,231 before), and 621,512 in 2022-2026 (613,681).
  - By the usage type: 1,626,172 in 2007-2021 (1,721,673) and 748,070 in 2022-2026 (629,259).
  - The usage changes sit on 71 hulls whose usage code differs between the register and Hreiðar or Oracle: −152,210
    fixes in 2017, about +60,000 a year in 2021-2023.
- **The catch** is unchanged in total: every year's kilograms and every approach and basis equal the old to the
  kilogram. Its rows move with the fixes.

## The reviewed row for 6061, and the second rebuild

On the maintainer's go ("add a reviewed row (D1) setting 6061's power_kw in 2016 to 58, then rebuild the history, the
register, vessel_year and the trail by name"):
- **The row.** `overrides/skipaskra_reviewed.csv` gained its first row: 6061, `vessel_hist.power_kw`, 2016-01-01 to
  2017-01-01, 58. That stretch is now `reviewed`, rule D1, with 728 kept in `alternatives`. `vessel_year` gives 58 kW
  for 2016, with `kw_source` `review`.
  - In a scratch store first, it changed one row each in the history, the register and `vessel_year`, and nothing
    else.
- **The build.** The history was rebuilt in the `once` project by name. Then all 27 targets that were outdated in the
  main project were rebuilt by name, from 23:36 to 01:28 UTC: the register, the four readers and the whole AIS chain.
  - The chain reran because the register's rewritten files carry new stamps, which make `vessel` and everything
    after it outdated.
  - The run ended "ALL DONE", exit 0, and `tar_outdated()` is empty in both projects. All 856 files are new, the 689
    curated ones stamped e2f741f, not dirty.
- **The trail.** 6061's 2016 kW-hours fall from 280,870 to 22,377 on its fixes (58/728 of the old).
- **What else moved, from identical inputs.** Against the first rebuild, a little more changed than the row explains:
  - `voyage_gear` chose another gear (`gid_voyage`, `s1_voyage`, `s2_voyage`) for some voyages. This reaches
    `gid_voyage` in 60 trail partitions. It also changes the fishing flag on about 25 fixes of hulls 1808 (2008), 2404
    (2022) and 2018 (2019, 2023).
  - So `curate/voyage_gear.R`'s choice is not deterministic: a tie, probably, broken differently on each run. It
    predates this work.
  - The catch is equal in every vessel-year to 0.0000002 kg, and in total. Two vessel-years of 2018 spread the same
    kilograms over slightly different fixes.
  - The rest is the order of floating-point sums (`kg`, the link checks' `hours`), and rows moving between two 2025
    `ping_clean` part files, which together hold the same 9,890,591 rows.

## Not done

- **The STK key** reads `yh1`/`yh2` and `staging/skipaskra/annual_call_sign.parquet`, frozen in the `once` project. Its
  redo (TODO 25) should read the register's values, with `yh2` NA meaning on the register at the dump.
- **Left in the register:**
  - the class name column (622 rows off their code);
  - mbl's sole values, such as 2730's TFCR in 2023;
  - 12 kvoti stretches starting on its 1901 placeholder, on old hulls before 1920;
  - 111 local signs with Hreiðar's or a page's typing ("RE.", "ís", "TH" for ÞH), which `vessel_sign` folds in its key.
- **`voyage_gear`'s non-deterministic gear choice** (above), which makes a rebuild move a few fishing flags.
- **Asks d and e** of plan 028.
