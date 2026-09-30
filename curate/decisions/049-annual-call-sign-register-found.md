# 049 - The annual ship register holds the call sign per vessel per year

*2026-09-30. Found in `~/stasi/skipaskra` (the maintainer copied it in) while hunting for annual call-sign records; the STK
mid -> vid work needs to know who held a call sign WHEN (decisions 044, 045, 047, 048). Analysis by Claude (AI-assisted).
Nothing is written under `$FISHYDATA` yet: the source still lives in `~/stasi/skipaskra`, outside the pipeline.*

## What it is

The Icelandic ship register as published every year (Skipaskra, the `data-raw/skipaskra_tabulized_matrix_*.rds` matrices are its
PDF pages) - a vessel-by-year listing with, among much else, the **call sign as held that year**. Two forms exist:

| years | form | call signs |
|---|---|---|
| 2009-2017 | tidied in `data/skipaskra_2009-2017_almost-tidy.rds` (year, vid, name, uid, `cs`, ...) | 3,463 vessel-year call signs |
| 2018-2022 | raw matrices only; the vid sits on the call sign's row, so `(year, vid, cs)` is read straight off each page | 1,820 |
| 2004-2008 | raw matrices; the tidy script fails (see below) - **2007-2008, the start of STK, are still missing** | - |

Assembled 2009-2022: **5,283 vessel-year call signs, 491 call signs, 571 vessels**. Call signs are listed for only ~16-18 % of
the register's rows (the larger vessels; small boats mostly have none), so this covers the vessels that matter for reuse, not all.

## Checked

- **One holder at a time, as it must be:** 4 of 5,279 call-sign-years have two holders (an extraction slip or a hand-over within a year).
- **Two extraction routes agree:** 2017 (tidy table) and 2018 (extracted from the raw page) share 347 call signs; 346 have the same vid.
- **It confirms the reuse cases independently of AIS:** of the 32 mobile-ids where W1 saw two vids on one call sign, **31 are consistent**
  with the register (it lists the call sign under the first vessel until about the switch W1 saw and under the second from about it); one has no record.
  E.g. TFBR is held by vid 2815 in every register year 2012-2022 - the key had given it to vid 1473.
- **Against the segment table:** of 554 segments whose call sign the register lists (2009-2022; 75.3 M pings), the table's vid equals the
  register's holder **every year for 511 (96.6 % of the pings)**, in part for 22 (3.1 %), and the register names another vid every year for 21 (0.3 %).
  The 21 are informative: it supports the key's vid 2022 on mid 103750 (the case decision 048 rejected), names vid 2549 where the table's
  neighbour-fill wrongly borrowed 2500 for mid 103173, and agrees with the key's vid 2724 on mid 103934 where the table left the stretch for a person.
  Several of the one-year mismatches are a switch inside a register year (mids 101119, 111702).

## Why the tidy script does not run here (recorded so it need not be rediscovered)

`R/02_tidy_20*.R` in `skipaskra` reads its region letters from the Oracle database (`omar`), which is not reachable here, and uses a
`str_detect()` idiom (a two-element pattern recycled against a vector) that current `stringr` rejects. `raw/vessels/region.parquet`
(`acronym`) is a substitute for the region list; the 2004-2008 layout then fails further down at a page with fewer columns. The 2018-2022
route above avoids all of it.

## What is open

1. Adapter in `sources/skipaskra/` writing `staging/skipaskra/annual_call_sign.parquet` (year, vid, cs, form). The raw copy landed
   2026-09-30 under `$FISHYDATA/raw/external/skipaskra/` (136 MB: matrices, `data/`, `R/`, 14+ annual report PDFs incl. 2006/2007 for
   the 2007-08 call signs, and `data-raw/mbl`; the ~1,000 vessel photos were deliberately not copied).
2. Use it in the segment table as a registry evidence family that dates a call sign's holder by year (it would replace Hreidar's annual
   years and the placeholder MMSI windows as the time source for call-sign reuse), and feed the 21 segments above to the review.
3. Tidy 2004-2008 so 2007-2008 are covered.
4. The registry's current call sign (2023 onward) continues the series; its dated history only starts on 2023-12-19 (decision 047).

## Rest of the `skipaskra` directory (surveyed 2026-09-30)

- `data/history.rda`: dated name and usage-class history, 24,056 rows, 5,100 vids, dates to 2021-12; 3,458 vessels change class over
  time. A candidate time source for the class-change caveat in the time-speed reading. Not yet used.
- `data/vessels.rda` (7,111 vessels) and the siglo scrape (owner, status, built, harbour): undated snapshots; MMSI for 2,461 vessels.
- `data-raw/mbl`: one 2026-era snapshot per vid (5,803 files, 5,823 vids); only 405 carry a call sign, 1,738 an MMSI, none dated.
  Low value for dating; kept for completeness.
- `reports/`: the annual PDFs, the route to 2007-08.
