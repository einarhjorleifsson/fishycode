# 144 — The register's readers repointed, with mbl last, kvoti first for the class, SKEMMTISKIP as 62 and Hreiðar's years read right (plan 028 step 7)

*2026-10-18. Coded, measured and built by Claude (AI-assisted), on the maintainer's go ("Start plan 028 step 7:
repoint vessel_sign, vessel_class, vessel_year and registry.R to curated/vessel/register/, one at a time, with
fingerprints before and after"). The three changes to the decision model are the maintainer's choices, asked on the
way. Built by name at 4b2fdf8: the history in the `once` project, the register and the four readers in the main
project.*

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

### Targets

- `vessel_sign`, `vessel_class`, `vessel_year` and `vessel` now depend on `vessel_register`.
- `hreidar_vessel_year` is a frozen input for `vessel_year`.
- `annual_call_sign`, `vessel_sign_raw`, `vessel_hist_raw` and `vessel_class_raw` left the main project.
- `vessel_raw` still lists Hreiðar's workbook, which no main script reads now. Dropping it would cascade through
  `mmsi` into the AIS chain for nothing.

## Not done

- **The downstream rebuild waits for the maintainer.**
  - 20 targets are outdated: the AIS chain from `vessel_identity` through `ais_trail` and `ais_catch`, and their checks.
  - The trail's `kw_basis` and `leisure` and the catch will change.
  - The chain above the trail reads none of the changed columns. It would rebuild to the same content with new
    stamps.
- **The STK key** reads `yh1`/`yh2` and `staging/skipaskra/annual_call_sign.parquet`, frozen in the `once` project. Its
  redo (TODO 25) should read the register's values, with `yh2` NA meaning on the register at the dump.
- **Left in the register:**
  - the class name column (622 rows off their code);
  - mbl's sole values, such as 2730's TFCR in 2023;
  - 12 kvoti stretches starting on its 1901 placeholder, on old hulls before 1920;
  - 111 local signs with Hreiðar's or a page's typing ("RE.", "ís", "TH" for ÞH), which `vessel_sign` folds in its key.
- **Asks d and e** of plan 028.
