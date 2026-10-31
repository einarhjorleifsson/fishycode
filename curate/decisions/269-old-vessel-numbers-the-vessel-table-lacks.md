# 269 — The old vessel numbers the vessel table lacks: the lumpfish logbook numbered its own boats until 1991, and the register covers every hull the logbooks name

*2026-10-31. The maintainer's question, through a side session. Why do 22,588 stations of release 2026.10.31.1 carry a
vid not in `vessel/vessel`? And should the register's history (Hreiðar's data, decisions 132 and 144) already cover
them? The maintainer believed the register's history is good all the way back. Mid-way the maintainer narrowed the
question: "i am mostly interested old vessel vid missingness. not the quircks in the more recent decades". Then it
widened again: "i thought that hreidar's data had the boat list. care to check his raw data, you may have
misinterpreted things", and "don't only check the lumpfish data, but all the pre 1990 data". Analysed
read-only by Claude (AI) on the release, `curated/`, the register's history and the Oracle dumps. Nothing was rebuilt,
and nothing was written outside the archive. No person has checked the numbers. The scripts, their logs and the
per-vid table are in `$FISHYDATA/archive/2026-10-31-vid-gap/` (`classify.R`; `vid_gap.csv` has no name column).*

## The answer

**The register covers every hull the logbooks name by a register number.** The belief holds:

- **The vessel table drops none of the history's hulls.** `registry.R` takes the live Oracle `vessel` table (7,047 rows,
  deregistered hulls included) and the SKB craft. The history adds only `yh1`/`yh2`. Every number in
  `registered.parquet` is in `vessel.parquet` except 7776, which is on the history for 2023 alone and has no logbook
  station.
- **None of the 517 vids is a number the register ever held.** None is in `registered.parquet`, Hreiðar's `nr` or the
  PDF editions. The live table holds one of them, 0, "Enginn bátur", which `registry.R` drops.
- **afli's main logbook sits on the register.** The share of its stations on a hull on Hreiðar's register that year:

  | decade | share |
  |---|---|
  | 1960s | 99.4 % |
  | 1970s | 99.2 % |
  | 1980s | 99.8 % |
  | 1990s | 99.7 % |

  The 1950s hold only 712 stations, 73 % of them on the register.

**What Hreiðar's keys mean.** His sheet "Info" defines them:

- **`NR` is a boat's last register number.** "Örfáir bátar hafa haft tvö skipaskrárnúmer, bara notað það síðasta": a
  few boats had two register numbers, and only the last is used. Boats without a register number get 90000 and up.
- **`Skskr.nr.` is the number in use at the time**, or a TF or LB call sign where there was none.

So his rows are also the crosswalk from a number a logbook used then to the hull's last number. Decision 046 found the
column dragged down in some older blocks, so it is a lead, not proof.

**Every pre-1990 row with a vid, against Hreiðar year by year.** There are 1,478,332 stations and 25,057 rows of the
monthly summaries (`aggregate/logged_monthly`). Landings, `vessel_year` and the trips' times start later.

| outcome | afli | afli_grasl | summaries |
|---|---:|---:|---:|
| the vid is a boat's `NR`, in use that year | 1,385,893 | 22,981 | 21,864 |
| an `NR`, before the boat's first year | 2,932 | 1,164 | 28 |
| an `NR`, after the boat's last year | 1,410 | 46,513 | 326 |
| in the live register, not in Hreiðar | 426 | 1,086 | 2 |
| in neither | 162 | 15,229 | 10 |
| no vessel (NA or 0) | 536 | 0 | 2,827 |
| another boat's `Skskr.nr.` that year: an old number | 0 | 0 | 0 |
| **all** | **1,391,359** | **86,973** | **25,057** |

- **No pre-1990 row is on an old number.** The renumbered open boats are all of the 1990s.
- **afli's hulls fit their gear.** Where the vid is in use that year, bottom trawl sits on hulls of a median 451 GRT,
  none of them open and 88 % of 50 GRT or more. Danish seine sits on 35 GRT, dredge on 62, longline on 10, and handline
  on 6, 42 % of them open boats. The early-year rows (2,647 in the 1970s) are a median of one year before the boat's
  first year in Hreiðar.
- **The lumpfish logbook's do not.** Its gillnets sit on a median 49 GRT hull, 49 % of them 50 GRT or more. Most of
  its rows are outside the boat's years or in no register (below).
- **The summaries' 2,827 rows with no vessel** are 2,594 of the 1960s, 218 of the 1970s and 15 of the 1980s.

**The lumpfish logbook did not use the register's numbers before 1992.** Its `skipnr` was its own list of boats:

| years | the number |
|---|---|
| 1980-81 | 20000 + x, x from 3 to 1116, on 507 vessel-years |
| 1982-1990 | x alone: every vessel-year is numbered 1-999 |
| 1991 | both: 250 of 404 vessel-years are numbered 1-999 |
| from 1992 | register numbers: 81-91 % of vessel-years are on the register that year in 1992-95 |

Three findings show it:

- **The matches are ships.** In 1982-91, only 1,030 of the 3,280 vessel-years numbered 1-999 are on the register
  under that number that year. Those hulls have a median of 99 GRT and 21 m, and 507 of them are 50 GRT or more. The
  lumpfish boats of 1992-2016 have a median of 5-8 GRT.
- **The 20000s and the plain numbers are one list.** 202 of the 390 x's of 1980-81 recur as x in 1982-84 at the same
  place (`stadur`). Shifted by 7, only 11 do.
- **Nothing else in the lumpfish tables names a boat.** `kennil` and `bokst_regl` are empty on every row. `ahofn` and
  `stadur` give a port and a place, not a boat.
- **x is not a boat's district number.** A boat's mark is its district and a number (Hreiðar's `Staður` and
  `Númer`). Read as that number, with `stadur` as the district, x finds a boat in `stadur`'s commonest district on 791
  vessel-years. Shifted by 7 it finds 747, and by −3, 807.

**So the gap is only the visible part.** The release holds 100,381 lumpfish stations up to 1991:

| where the number lands | stations |
|---|---:|
| not in the vessel table: the gap | 15,669 |
| a hull of the vessel table, not on the register that year | 56,164 |
| a ship of 50 GRT or more on the register that year | 10,597 |
| a hull of 30-50 GRT, or with no GRT, on the register that year | 10,946 |
| a boat under 30 GRT on the register that year | 7,005 |

Only the last row can be the right hull. In 1982-90 most of those match by chance, 4-17 vessel-years a year.

**The merge's one-source rule (decision 263) compares different boats in these years.** It leaves a lumpfish
vessel-day out when another source holds that vid and day. Of the 2,097 vessel-days it left out, 1,895 fall in
1980-1991, with 243 t of roe. The other 202 are from 1992 on, with 39.6 t.

## Where a key to the lumpfish list was looked for

- **Oracle's catalogue** of all 128 owners, every dictionary's comments, and the views' and stored code's text: no
  table names a lumpfish boat list, and nothing joins the lumpfish tables to another.
- **Hreiðar's workbooks.** "Data main" is the only data sheet. His second workbook holds samples of other data.
- **Fiskifélag** (`fiskifelagid`). Its weighing register of 1966-81 numbers decked vessels by register number and open
  boats by a code of its own (42502-114901). Neither matches 20000 + x beyond chance. Its landings carry a vessel number
  only from 1991.
- **A scan of every number and text column** for the list's fingerprint (`scan/scan.R`, counts only): the 390
  numbers of 1980-81 against the 724 it does not use, and the plain numbers of 1982-90 with the 27 the register never
  issued. Only the lumpfish tables hold it: `grasl_stofn`, `grasl_sokn`, and `g_stofn`/`g_sokn`, a copy for 1982-89
  with the plain numbers and no other key. The scan covered `adb`, `afli`, `agf`, `asfis` and part of `ask` (files
  1-439). It then covered only the schemas where a vessel list would be kept: `channel`, `orri`, `ops_einarhj`,
  `ops_sigfus`, `vessel`, `ufs`, `fs_ufs`, `kvotix`, `logbook`, `uv` and `fiskifelagid` (the maintainer, "Narrow it").
  Not scanned: `stk`'s pings, the logbook GPS logger, the e-logbook's messages, and the quota, landings, weighing,
  survey and tag schemas. In the narrowed schemas no column has the list's shape. The lumpfish tables hold 773-810 of
  its numbers and only 12-25 of the others. The next closest columns hold 48-125 of the others: district numbers
  (`einknr`, `region_no`), depths and ids, which are general numbers, not this list. So no dumped table holds a key
  from the lumpfish list to a hull. One may still exist outside the dumps, on paper or with the people who kept the
  lumpfish logbook.

## Every station in one outcome

Each of the 517 vids takes one outcome, by the first rule in `classify.R` that holds:

| outcome | vids | stations | before 2000 |
|---|---:|---:|---:|
| the lumpfish logbook's own number, used only up to 1991 | 423 | 15,365 | 15,365 |
| an unregistered boat under kvoti's number (9901-9965) | 39 | 4,418 | 3,352 |
| a renumbered open boat: the hull is in the vessel table under a later number | 9 | 872 | 866 |
| 0, "Enginn bátur" | 1 | 583 | 534 |
| a number found nowhere else: unexplained | 12 | 235 | 226 |
| a diver's licence, not a hull | 2 | 96 | 12 |
| a software-test vessel of the Directorate (ufs class 71, "Hugbúnaðarprófun") | 27 | 906 | 0 |
| a quota-accounting entry (−1, −6, −9, −999) | 4 | 113 | 0 |
| **all** | **517** | **22,588** | **20,355** |

By decade and schema:

| decade | afli | afli_grasl | fs_afladagbok | the outcomes |
|---|---:|---:|---:|---|
| 1950s | 60 | 0 | 0 | vid 0 |
| 1960s | 91 | 0 | 0 | vid 0 |
| 1970s | 286 | 0 | 0 | vid 0 |
| 1980s | 259 | 15,229 | 0 | own number 15,189; unexplained 202 (932); vid 0 97 |
| 1990s | 708 | 3,722 | 0 | kvoti's number 3,352; renumbered 866; own number 176; unexplained 24; diver 12 |
| 2000s | 0 | 855 | 0 | kvoti's number |
| 2010s | 82 | 154 | 0 | kvoti's number 197; diver 39 |
| 2020s | 51 | 0 | 1,091 | test vessels 906; quota entries 113; vid 0 49; diver 45; kvoti's number 14; unexplained 9; renumbered 6 |

### The old outcomes

**The lumpfish logbook's own numbers.** These are the 20000s, plus the numbers its list used and the register never
issued: 26 numbers in 1-999, 3026-3082, 8700, 10018 and 10019. They hold 15,365 stations of 1980-1991.

**The renumbered open boats.** An open boat that was decked, or re-registered, took a new number. The logbook kept the
old one. Two witnesses name the hull:

- kvoti's name field (`kvoti.skip.heiti`, for example "… er nú 2125");
- Hreiðar's `skskr_nr`, the number in use, under another `nr` of his, the hull's last number.

Decision 046 found `skskr_nr` dragged down in some older blocks, so a row with one witness needs review.

| number | the hull | witness | stations |
|---|---|---|---:|
| 1699 | 7339 | Hreiðar's `skskr_nr`; kvoti's mark VE 23 is Hreiðar's | 39 |
| 7003 | 2091 | Hreiðar's `skskr_nr` | 5 |
| 7117 | 2125 | kvoti's name | 152 |
| 7128 | 2178 | Hreiðar's `skskr_nr`; kvoti's mark EA 96 is Hreiðar's | 208 |
| 7174 | 2129 | kvoti's name and Hreiðar's `skskr_nr` | 21 |
| 7198 | 2226 | kvoti's name | 267 |
| 7285 | 2209 | kvoti's name | 35 |
| 7365 | 1560 | kvoti's name ("er nú aftur 1560") | 38 |
| 9929 | 9050 | kvoti's name ("ER SKRÁÐ SKRNR 9050") | 107 |

**The unregistered boats.** From 1991, kvoti numbered boats that were not on the register 9901-9965:

- kvoti calls them "Óskráður" or "… óskr.", most of them in district ZZ;
- ufs puts them in class 0 or 93 ("Eingöngu grásleppuleyfi");
- 24 hold lumpfish licences and 25 lumpfish rights, and 7 land.

They are real boats that were never on the register. Eight carry a district mark, which may lead to a registered hull,
as 9929's did.

**vid 0, "Enginn bátur".** It is 534 afli stations of 1950-1985:

- longline in 1950;
- trawl events in 1962-63;
- trawl operations in 1972-85;
- dredge events in 1978-81.

The record names no vessel.

**Unexplained.** 932 is a number the register never issued. It holds 162 afli trawl stations in 1985 and 40 lumpfish
stations in 1989. 9947 and 9956 hold 24 lumpfish stations of 1992; they are in kvoti's range of numbers, but kvoti
does not hold them.

### The recent outcomes, in brief

- **Software-test entries.** The Directorate's test vessels and the quota-accounting entries are fs_afladagbok
  records of 2020-2025. They are not fishing.
- **Two single entries hold the big tonnages.** The test vessels carry an entry of 50,000 t, and vid 0 in
  fs_afladagbok one of 300,000 t. Both are flagged `largest_landing_exceeded`.
- **Persons' names.** ufs's and kvoti's name fields hold persons' names for the test vessels and the divers. No file
  here carries them.
- **One-station numbers.** Nine numbers with one handline station each, May-August 2022, are in no register and not in
  kvoti.

## What a fix would be (TODO 177, for the next release)

The fixes go in the merge, never in the adapter, and keep the logged number. Release 2026.10.31.1 is not rewritten.

- **The lumpfish logbook up to 1991.** Its number is not a vid:
  - move the number into a column of its own and set `vid` to NA, with its basis;
  - keep the number as the vessel-day's key;
  - take those years out of the one-source rule;
  - decide 1991 per vessel-year.

  Linking the numbers to hulls needs a witness this data lacks. That would be the boat list behind the numbers, if
  anyone at MFRI holds it, or the landings of roe by day and port, where the landings reach back.
- **The renumbered open boats.** A reviewed table in `overrides/`, the old number to the hull.
- **The unregistered boats.** Into the vessel table as a register of their own, as SKB is, from kvoti's mark and name,
  without owner columns.
- **vid 0.** Kept, and explained in the README.
- **The recent outcomes.** The test vessels and the quota entries are left out, as duplicates are, and the divers are
  flagged.
- **The release's README.** This breakdown replaces "most of them lumpfish-logbook boats of 1980-2015".
