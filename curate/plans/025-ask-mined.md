# 025 — ask mined whole: landing times, what agf changed, and what the rest holds

**status:** proposal — measured 2026-10-17; §4's design chosen by the maintainer the same day (agf's rows, ask's
columns, a weighing table), nothing built; §6 asks 1 and 2 open (TODO 74) · **2026-10-17** · **see:** plan 023 (the
landings by period: this measures its §3 and §4 for ask), plan 022 (stk mined, the form followed here), plan 018 (the
dump), plan 007 (fishycode's landings), decisions 031, 094 and 109

Drafted with AI assistance (Claude) on 2026-10-17, at the maintainer's request: mine the ask schema, dumped whole on
the server on 2026-10-16 (decision 109). Plan 023 had inventoried ask by column name, for a landing's trip, gear and
catch only. The numbers below were measured by Claude (AI); a person has not yet checked them.

**Measured** (read-only, 2026-10-17): `raw/oracle/ask/` against `raw/oracle/agf/aflagrunnur.parquet`,
`curated/landing/`, `curated/logbook/lid_map.parquet` and `curated/ais/port_stay.parquet` (the build of 2026-10-16,
decision 112). Scripts and output in scratch only. **Assumed:** that ask's Oracle comments (on 124 of its 235
objects) say what a column holds. §3 tests the ones that matter.

**Personal data:** no column naming a person was read. That covers the seller, buyer, receiver and weigher on the
records, the users and their logs, and the change stamps. Tables of persons and parties are named here by kind and
size only. This follows plan 023 §7 and MFRI's gagnastefna. Nothing personal enters this repository, which is public.

## 1. What ask is

ask is the Directorate of Fisheries' landing registration, which calls itself Gafl. It holds 723,129 landings, from
2006-05-15 to 2020-07-22. It is whole from September 2007; before that it holds only 5,037 landings of January to
August 2007, years that LODS holds.

Its record has three levels:

- **the landing**, `landanir`: vessel, port, the landing day, when it was registered and closed, and its type;
- **the weighing note**, `vigtarnotur_tab` (2.48 M rows): one or more per landing, with the gear and the weighing
  type;
- **the weighing line**, `vigtanir` (10.5 M rows): stock, fishing area, condition, storage, disposal, gross weight,
  deductions, net weight and the conversion factor.

Around them sit three more records:

- the deductions, `fradrattur` (3.66 M rows);
- the pairs of re-weighing notes, `vnotur_tenging` (588,349);
- the discrepancies between those pairs, `fravik` (60,543) with `fravik_vigtarlinur`.

The same catch is weighed more than once. There are 26 weighing types: harbour scale, to re-weighing, the licensed
plant's own note, the note made from the plant's report, products weighed at sea, transshipment, and others. Only
the *net* notes count, marked by `vigtunartegundir.lods2`, so summing `vigtanir` counts catch twice. fishycode never
does, since it reads agf.

A note is withdrawn by a credit note of negative weight (`er_kreditnota = 1`). The original keeps
`er_kreditnota = 0`, and only its link to the credit note (`bakfaerslunota_id`) marks it. There are 250,520 originals
and as many credit notes (+5,834 and -5,834 kt), against 1.98 M notes never reversed. Oracle's comment puts the link
on the credit note; the data put it on the original. Any use of a note must leave out both.

ask's own comments state the lineage that plan 023 §3 took as a hypothesis:

- `landanir.uppreiknad` says whether a closed landing "has been moved into `agf.aflagrunnur`";
- `vigtarnotur_netto_v` holds the net notes, "whose catch is registered onward into `agf.aflagrunnur` and
  `kvoti.lods_slaegt`";
- `aflagrunnur_upphaf_v` has `agf.aflagrunnur`'s columns.

## 2. Triage

| kind | objects | what |
|---|---|---|
| record | 11 | the three levels above; deductions, re-weighing pairs, discrepancies; containers and vehicles at the ports; 237 comments per port; `vigtanir_upd_afurdir` (15,169 rows, no comment) |
| code list or setting | 40 | gear (25), fishing area (15, with FAO codes), stock (214), condition, storage, disposal, landing and weighing types, ports (140); conversion factors with validity dates; maps to LODS 1 and LODS 2; quota rules; access rights |
| derived (view) | 66 | joins of the records and code lists: the net view that agf copies, LODS's feeds (`landanir_vigtarnotur_lods1_v`, `_lods2_v`), reports (`rep_*`), control views |
| persons or parties | 17 | users, the ports' weighers, sellers, buyers, receivers, licence holders, fish markets, postcodes: not read |
| journal | 47 with rows, 10 empty | Oracle Designer change journals (`_jn`) |
| leftover | 21 | `tmp*` and `*_afr_tmp*` tables of 11 to 574 rows; one test view, `test_fradrattur_afr_urt_v`, with the same 3.61 M rows as `fradrattur_afurdar_urtak_v` |
| empty | 9 | including `vigtarnotur` (the records are in `vigtarnotur_tab`) |
| not dumped | 14 | 13 views guarded per user (ORA-20290, decision 109) and one that fails in Oracle |

**None of the core records has a journal with rows.** `landanir_jn`, `vigtarnotur_tab_jn`, `vigtanir_jn` and
`fradrattur_jn` are empty. A change shows only through ask's copy-and-reverse mechanism (§3.3). The journals with
rows record:

- the code lists, including every change to a conversion factor (`studlar_jn`, 1,511 rows);
- the re-weighing pairs (`vnotur_tenging_jn`, 1.18 M rows);
- a user log (`valin_hofn_jn`, 774,313 rows), which is not read.

## 3. Findings

### 3.1 The first weighing bounds the arrival to within the hour, 2007-2020

The landing day, `londun_hefst`, is a date in every row of ask, as it is in agf and LODS. But ask stamps two times:

- each weighing line is stamped when it is entered (`timi_vigtunar`, set by the database);
- each landing is stamped when it is registered (`skraningartimi`).

The test compares the first weighing of each landing with the AIS port stays. A landing's first weighing is the
earliest line on a note that is neither a credit note nor a reversed original (§1); 7,395 landings have no such
note. The landings are those of the general type that were not replaced
by a copy. Each is matched to the vessel's stay at the landing port whose arrival `T_in` falls on the landing day or
the day before. Ports go from `hid` to `pid` as in `curated/landing`. Times are UTC throughout (decision 111), and so
is Iceland.

| year | landings | with a stay | first weighing before arrival | median after arrival | 75th percentile |
|---|---|---|---|---|---|
| 2007 | 17,322 | 14,129 | 3.4 % | 1.6 h | 18.8 h |
| 2008 | 47,908 | 43,633 | 4.8 % | 1.1 h | 14.9 h |
| 2009 | 56,820 | 50,991 | 4.6 % | 1.1 h | 15.6 h |
| 2010 | 57,835 | 51,669 | 4.0 % | 1.0 h | 15.6 h |
| 2011 | 59,795 | 55,313 | 3.5 % | 0.9 h | 13.8 h |
| 2012 | 60,858 | 56,649 | 3.5 % | 0.8 h | 11.8 h |
| 2013 | 63,017 | 59,756 | 3.8 % | 0.8 h | 11.8 h |
| 2014 | 59,097 | 56,026 | 3.8 % | 0.8 h | 8.8 h |
| 2015 | 53,628 | 50,766 | 3.5 % | 0.8 h | 9.3 h |
| 2016 | 54,475 | 51,713 | 5.2 % | 0.7 h | 4.1 h |
| 2017 | 51,138 | 48,725 | 5.0 % | 0.7 h | 3.8 h |
| 2018 | 50,930 | 48,287 | 4.2 % | 0.7 h | 4.2 h |
| 2019 | 49,536 | 46,652 | 4.8 % | 0.6 h | 3.3 h |
| 2020 | 30,186 | 28,699 | 3.2 % | 0.6 h | 2.7 h |

A first draft counted reversed originals as live notes. Leaving them out gives 31,406 landings (4.3 %) a later first
weighing, by a median of 0.8 h; per year the share before arrival moves by at most 0.2 points, and the median by
under three minutes.

- **The bound holds for 95-97 % of landings every year**, so the first weighing is an upper bound of the arrival.
  In 2010-2019 it falls inside the stay for about 83 % of them (measured with the first draft's definition).
- **It is tight for most landings and loose for many.** The median is under an hour from 2010. The tail is long in
  2007-2013, when a quarter of the landings were first weighed more than 10 h after arrival: weighed the next
  morning, or on a later note. Since 2016 the 75th percentile is under 4.5 h.
- **The registration time is not a bound.** 22 % of landings are registered before the AIS arrival (pre-registered),
  with a median of 0.5 h after it.
- **The day alone** gives the arrival on the landing day for 93 % of landings and the day before for 7 %.

So for 2007 to July 2020 the landings can give `T2` an upper bound to the hour, where today they give the day. That
serves the flow twice: as `T2`'s bound where AIS has no arrival, and as a witness where it has one. No landing source
holds a time after July 2020.

**Measured since** (2026-10-17, read-only, proposal 1's first measure). Measured by Claude (AI); a person has not yet
checked these numbers. `t_weighed` is taken per fishycode landing, the earliest over the agf ids that `.lid`
collapses, from 2007-09-01 to 2020-07-22. It was taken over every note with `er_kreditnota = 0`, as in the first
draft, so reversed originals were included. Its counts were not rerun. It reproduced the first draft's table (2010:
4.0 % before arrival, median 1.0 h). The trips are logbook trips matched to an agf landing in `lid_map.parquet`, twins left out. Their AIS
arrival is the stay that ends the trip's voyage in `trip_voyage.parquet`. In these years afli's `T2` is a date in
every row, so *disagree* means that `T_in` falls more than an hour outside the logbook's day. Gear is the landing's
main gear by catch.

- **Trips with no AIS arrival:** 32,772 of 595,233 (5.5 %).
  - 11,484 have no voyage, and 21,288 have a voyage that ends at another port.
  - All but 90 have `t_weighed`, and 19,554 have no stay at the landing port on that day or the day before.
  - The share falls from 7-10 % in 2007-2010 to about 4.5 % from 2013. By gear it is 10.7 % for gillnet and 3.4 %
    for bottom trawl.
  - For those 19,554, `t_weighed` is the only time. The rest have a stay at the landing port that the link did not
    use.
- **Logbook day against AIS arrival:** 54,407 of the 561,952 trips that have both (9.7 %) disagree.
  - *AIS earlier* (32,081 trips): the vessel arrived the evening before. The first weighing comes after that arrival
    in 99.8 % of these trips, a median of 21 h later, and falls on the logbook's day in 81 %. The logbook has the
    landing day, and `t_weighed` confirms the AIS arrival.
  - *AIS later* (22,326 trips): the catch was weighed before that arrival in 18,138 of them (81 %), a median of 25 h
    before. That voyage cannot end the trip, so `t_weighed` moves `T2` back by about a day.
    - 7,288 of the 18,138 have an earlier stay at the landing port, which the link passed over.
    - 10,850 have no such stay: AIS missed the arrival.
    - Most are handline and longline trips, and most are from 2008-2012.
  - *Logbook `T2` impossible* (the catch was weighed before the logbook's day): 2,924 matched trips (0.5 %).
    2,883 of them come from `lid_map`'s ±1 and ±2 day steps, which is 14 % of the ±1 day matches and 25 % of the
    ±2 day matches.
- **Landings with no logbook trip:** 107,198. Of these, 90,297 have both `t_weighed` and a stay, mostly gillnet
  (39,238) and handline (35,331). For 98.6 % of them, a stay that begins on the landing day or the day before begins
  before the first weighing.
- **No other time in ask tightens the bound:**
  - The registration stamps of the note and of the landing come before the arrival for 21-22 % of landings, because
    those landings were pre-registered.
  - The closing times come after the first weighing.
  - The container gross weighing (`bruttovigtun_gama`) covers 4,673 landings, a median of 10 h after arrival.
  - Where AIS has an arrival, the gap between the last ping at sea and `T_in` has a median of 4.5 min, and
    `t_weighed` falls inside that gap for 0.5 % of landings.
  - agf's row time (`snt`; its user column was not read) is when the row was written. Until 2024 that is about one
    to six years after the landing, and in 2025-2026 it is still a median of 56 h after arrival, so agf gives no
    landing time after July 2020 either.

### 3.2 agf is ask's net view, except the live weight of factory-vessel products

agf has been compared with `aflagrunnur_upphaf_v`, landing by landing, 2008 to 2020-07-22:

- **Landings:** every landing in ask's net view is in agf, with the same id, vessel, day and port, except 1,053.
  Those are the ranching landings (`Úr áframeldi`), which agf leaves out whole. ask holds 1,101 of them (6.0 kt);
  its research catch (`Rannsóknarafli`, 392) is in agf.
- **Landings only agf holds:** 912 landings (53.7 kt) dated 2014 to July 2020 are not in ask. Their ids come after
  ask's last, and agf wrote them in 2021-2022: late registrations, made after ask closed.
- **Weights:** the net weight agrees. The live weight, `magn_oslaegt`, which fishycode reads, does not agree for
  factory-vessel products with floating yield (weighing type `AF`, `fullvinnsla = 1`):
  - it differs on 18,078 of 46,588 rows, and agf's is lower on 17,367 of them;
  - the difference is 133 kt over 2007-2020, from 4 % of the `AF` live weight in 2008 to 10 % in 2017-2018.
  - agf rewrote these rows after the landing: in 2014 for 2007-2012, then about two years after each year.
  - ask's view converts with the initial factor (`upphafsstudull`). agf holds a lower weight, most likely after the
    yield measured on board (kvoti's `nyting_*` tables, plan 023 §5; `afurdir_voruteg_vorpun` names that system).
    **Assumed, not measured:** that agf's weight is the measured yield.
  - Another 70 rows without floating yield differ by 24 kt, most of it on 41 rows of condition 27, where agf's net
    weight is zero or empty.

So agf is not a plain copy of ask. It is ask with the yield correction applied, without the ranching landings, and
with later registrations added. fishycode's live weight for factory vessels is the corrected one; ask's would be
4-10 % higher. Reading ask in agf's place, for 2007-2020, would undo that correction.

### 3.3 Changed and reversed landings stay in the landings as zero-kg landings

ask changes a landing by copying it, then closing and reversing every note on the original with credit notes of
negative weight (the Oracle comment on `breytt_londun_id`).

- **The changes:** 4,257 landings were changed. The copy moved the vessel in 1,001 and the day in 2,801.
- **In agf,** the original stays. Its weight sums to zero, so totals are right, but the landing is still there.
  12,001 agf landing ids sum to zero kg:
  - 4,171 replaced by a copy;
  - 1,024 reversed with no copy;
  - 4,123 whose every row is 0 kg (not explained);
  - 2,683 not in ask: after it, or late.
- **In `curated/landing`,** a landing is one vessel, day and port. 6,743 agf landings (2007-2026, 170 to 585 a year)
  and 983 LODS ones (2007-2008; earlier years not counted) have zero catch.
- **In the trip-landing link,** `lid_map.parquet` matched 631 logbook trips to one of them: 451 exact, the rest by
  the looser steps. Such a landing says that the vessel landed at that port on that day, which the Directorate
  withdrew.

### 3.4 The fishing area of each weighing line

`veidisvaedi` has 15 areas, with FAO codes: Iceland, Norway, Russia, Greenland, Jan Mayen, Svalbard, the Faroes,
NEAFC and NAFO international waters, Canada, the Flemish Cap (3L, 3M), the EU, Ireland, and "foreign ship".

Weighing lines by area, 2006-2020 (all notes, so some catch is counted twice):

| area | lines |
|---|---|
| Iceland | 10.42 M |
| NEAFC | 24,299 |
| Greenland | 13,101 |
| Norway | 11,457 |
| Faroes | 6,626 |
| Russia | 5,366 |
| NAFO | 1,348 |
| Svalbard | 819 |
| Canada | 442 |
| Jan Mayen | 109 |

agf carries the area to the present day as `veidisvaedi`, but `sources/aflagrunnur/convert.R` drops it. It is a
witness of where a trip's catch was taken. That marks the catch whose fishing fixes should lie outside Icelandic
waters, and checks the track where they do.

### 3.5 Gear

- **Gears per landing:** 99.4-99.7 % of landings carry one gear across their notes that were not reversed
  (2008-2020); 0.30-0.60 % carry two or more. These are mostly longline with hand-baited line (12 and 13, 515
  landings), hand-baited line with handline (13 and 14, 323), and bottom with pelagic trawl (6 and 9, 206). agf
  carries the gear per row, and the adapter keeps it.
- **The LODS map:** ask's map of its gears to LODS 2's (`veidarf_lods2_vorpun`) agrees with fishycode's map of old
  codes to new (`curated/reference/gear.parquet`) on all 19 old codes the two share. fishycode lacks LODS code 71
  (hand-baited line, ask 13), which carries 29 LODS rows (0.24 kt, 1993-1995).
- **English labels:** ask's English gear labels are wrong for two codes. The Nephrops trawl (7) is labelled
  "PTB - Bottom pair trawls" and the shrimp trawl (8) "TPB". Nothing in fishycode reads them.
- **A ready check:** `veidarf_fteg_rong_vensl` holds the Directorate's 27 gear-species pairs, graded as error
  (`VILLA`) or warning (`ADVORUN`). agf's catch holds 2 errors and 142 warnings. It is a ready check for the
  logbook, not yet measured.

### 3.6 How far the weighings disagreed, from the discrepancy log

Catch re-weighed at a licensed plant has two notes, paired in `vnotur_tenging`:

- the plant's own note (type 2), which counts;
- the note made from the plant's report (type 22).

- **In the final record, the pairs agree.** Of the 412,380 pairs where neither note was reversed (2009-2020),
  0.0-0.1 % a year differ by more than 1 kg. A first draft counted reversed originals as live notes and reported the
  pairs differing on 9-16 %, by 0.4-1.5 % a year in total. That was wrong.
- **The disagreement is in `fravik`.** It logs 2,810 to 6,925 discrepancies a year (60,543 in 2009-2020), 92-99 %
  of them approved. Each names two notes, and both were later reversed and re-issued.
  - Where logged, the two notes differed by a median of 6-11 % (97-207 kg).
  - Summed, the logged differences are 1.8-6.6 kt a year: 0.6-2.1 % of the year's re-weighed catch (2009: 5.5 of
    264 kt; 2020: 1.8 of 295 kt).
- **Which value was kept:** of the 56,683 landings with an approved discrepancy, the re-issued plant notes total the
  reported weight in 21,655 (38 %), the plant's logged weight in 29, and neither in 34,478, which is not resolved
  here.

**Assumed:** what each note records, from the Oracle comments. The logged differences measure how far two records of
one weighing disagreed before the Directorate settled them. They are not the error of the settled weight (done
criterion 3 in `AGENTS.md`), but they bound how wrong a weighing could be before it was checked.

### 3.7 Conversion factors

ask holds the factors that convert between weights:

- `studlar`: product to gutted weight, set by regulation, with validity dates (1,101 rows);
- `veidistofnar_i_oslaegt` and `i_oslaegt_vsv`: gutted to whole weight;
- `afurdir_isprosenta`: the share of ice;
- `grasleppa_hrogn_studlar`: lumpfish roe to whole fish.

Their journals hold every change. agf's live weight is already converted, so fishycode needs none of them today.
They are needed only to recompute a live weight, for instance to test §3.2's correction.

## 4. The design: agf's rows, ask's columns, and a weighing table (chosen 2026-10-17; nothing built)

The maintainer's choice (2026-10-17): one landings table from the source already used, agf from September 2007 and
LODS before. What ask adds is joined on as columns by the landing id, each with its basis. No value is chosen between
ask and agf row by row: where both hold a value, agf's is ask's later state, the same or corrected on purpose (§3.2).
How the weight was reached goes in a table of its own.

1. **`sources/ask/`**, a preprocessing adapter that reads no AIS, stages from `raw/oracle/ask/`:
   - per landing: `londun_id`, `t_weighed` (§3.1), and `replaced_by` (`breytt_londun_id`, §3.3);
   - the weighing lines (item 3).

   It reads no column that names a person.
2. **`curated/landing/landings.parquet`** keeps its rows and gains two columns:
   - **`t_weighed`**, the first weighing.
     - Its basis is `recorded` from 2007-09-01 to 2020-07-22, and `none` outside that period.
     - It is taken per fishycode landing, the earliest over the agf ids its `.lid` collapses.
     - The flow uses it as `T2`'s upper bound where AIS has no arrival, and as a witness where it has one.
   - **`withdrawn`**, for a landing whose catch sums to zero (§3.3).
     - `withdrawn_by` names the copy's id where ask names it.
     - The landing is kept, through a declared correction in `curate/corrections/`.
     - `link_lid_map.R` leaves withdrawn landings out of its candidates. Before that, measure what the 631 trips match
       instead.
3. **`curated/landing/weighing.parquet`**, new: one row per weighing line, with every note kept, 2007-2020, from ask.
   agf holds only net weights, so the table has no rows after July 2020.
   - **Keys:** `.lid`, `londun_id`, the note and the line.
   - **The note:** its weighing type; whether it counts (a net note, as agf takes it); `reversed` (a credit note or
     a reversed original, §1).
   - **What was weighed:** species, stock, fishing area, condition, storage, disposal and undersize.
   - **How the weight was reached:**
     - the gross weight (`vigt`);
     - the vehicle tare;
     - the ice, in kg and per cent;
     - the deductions (the sum of `fradrattur`, with their kinds);
     - the net weight (`magn`);
     - the factor (`upphafsstudull`) and the gutted weight;
     - the sample weighings: boxes counted, mean weight and sample gross weight.
   - **The re-weighing:** the paired note (`vnotur_tenging`) and the logged discrepancy (`fravik`: status, major or
     not).
   - From this table come §3.6's disagreement per year and `t_weighed`. It has 10.5 M lines.
4. **The fishing area (§3.4):** the agf adapter keeps `veidisvaedi` in its catch, and `ais_catch.R` reads it as a
   witness.
5. **A check (§3.5):** in `curate/checks/`, the Directorate's gear-species pairs against the logbook and the landings.
6. **The docs:** §3.6's disagreement goes where the docs describe the error on each path.

**Not added:**

- **The ranching landings** (§3.2; this answers the former ask 3).
  - All 1,101 (2007-2018) have no vessel id. They are landed from a pen, with gear `Eldiskví`.
  - Their fish is already in agf as it was caught: 1,388 vessel landings weighed "to ranching" (weighing type `IF`,
    3.2 kt, 2007-2017).
  - Adding them would count the same cod twice.
- **Seaweed and kelp:** there is nothing to add.
  - ask holds them only for 2019-2020: 506 landings by 4 vessels, each with a vessel id, harvested by plough (gear
    15). All of them are in agf.
  - `curated/landing` already holds 2,115 seaweed landings (species 1125-1128: knotted wrack and three kelps),
    2019-2026, by 12 vessels, 142 kt.
- **ask's uncorrected live weight,** unless ask 1 finds agf's correction wrong. The weighing table holds the net
  weight and the factor to recompute it.
- **Reading ask in agf's place** for 2007-2020 (§3.2).

## 5. How it ran

Read-only, by DuckDB over `raw/oracle/` and `curated/`, with scripts and output in scratch. No build was running,
and no tracked file was edited while it ran.

## 6. Asks

1. **Factory-vessel live weight (§3.2):** is agf's lower weight the yield measured on board, and the one to keep?
   Who at the Directorate knows? This joins plan 023's first ask.
2. **The build:** when? §4 touches the agf adapter, `curate/landing.R` and `link_lid_map.R` and adds
   `sources/ask/`, so it rebuilds the landings and everything after them. TODO 77's build is waiting for the
   maintainer's go.
