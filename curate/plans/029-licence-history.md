# 029 — A fishing licence history: which licence each vessel held, of what type, where and when, from every witness

**status:** partly built — steps 1-3 coded and checked in a scratch store, not wired or built (decision 134); the
history to 2020-07-22 builds in the `once` project, the live tail after it in the main one (ask c, decision 133);
asks a, b and d-h open (TODO 84)
· **2026-10-18** · **see:** plan 028 (§3.4, §5.3-5.4, §6 and ask c, which this plan takes over), decisions 130-133, plans 014, 017, 021, 023 and 025, `reference/vessels/vessel_class.R`,
`reference/vessels/skipaskra_evidence.R`, `curate/checks/skipaskra_discrepancy.R`, `docs/one_flow.qmd` (step 3's
`gear_register`)

Drafted with AI assistance (Claude) on 2026-10-18, at the maintainer's request. In plan 028 licences are only
witnesses: the register's evidence table carries kvoti's licence rows as given, and its checks use them. Asked
whether licences belong inside plan 028 or apart, the maintainer chose a plan of their own. The numbers below were
measured by Claude (AI). A person has not yet checked them.

**Why** (maintainer, 2026-10-18). A licence is one of many pieces of evidence. It helps in two ways:
- to settle problems and conflicts while the AIS side is built, and gear ambiguities in the logbooks and landings
  (a lumpfish fishery requires a licence);
- to interpret the trail in downstream analyses.

Those uses are named here, not measured. Measuring them before the product exists is premature (maintainer).

**The approach** (maintainer, 2026-10-18) is the one plan 028 takes for the register:
- every source that says something about a licence is a witness;
- witnesses are counted by lineage, not by copy;
- where two records overlap in time, their agreement measures how far each can be trusted;
- the history is chosen from the witnesses by ordered rules, with the deciding rule and the witnesses on each row.

**Measured** (read-only, 2026-10-18):
- kvoti's licence tables in `raw/oracle/kvoti/` (the dump of 2026-10-16) with Oracle's comments, from the dump's
  `_overview_tables` and `_overview_fields`;
- every dumped table that names a hull and a date: 397 of 1,618 in the 20 dumped schemas. 213 have rows after
  2020-07-22, and 186 have rows before 1996-09-01. All were read by name and comment, and the candidates were
  profiled;
- the overlaps between records, row by row (§3.5);
- Oracle's catalogue (`raw/oracle/_catalogue/objects.parquet`) for licence tables in schemas not dumped;
- `curated/landing/`, only to test whether the sources are complete.

Scripts and output are in scratch only. No column naming a person was read beyond its name and count, and the
free-text notes only for a kennitala-like number.

**Assumed:**
- A licence row says the hull was allowed to fish, not that it fished.
- kvoti's tables are final for 1996-2020: nothing corrects them later, elsewhere.
- A record that implied a licence while both existed implies it after the licence tables end. This is measured
  only where they overlap (§3.5).

## 1. In short

- **Licence tables exist only in kvoti.** They run from 1994 (Danish seine) and 1996 (the rest) to 2020-07-22.
  The lumpfish rights' history runs to 2021.
- **Six other records witness licences, before and after those years:**
  - the class (útgerðarflokkur), 1991 to 2026;
  - the quota record, 1991 to 2026, with area quotas for sea cucumber, sea urchin and scallop from 2022/23, and
    lumpfish from 2024/25;
  - effort-day notices, 1996-2002;
  - coastal trips, 2009 to 2021-02;
  - the lumpfish logbook, 1980-2016;
  - activity in the landings and logbooks.
- **Where they overlap with the licence tables, they agree to a measured degree** (§3.5, decision 134). In the last
  five years of each overlap:
  - the class implies its licence for 98-100 % of hulls. That covers coastal, hook-and-line quota, catch quota (the
    classes that name a fishing vessel), cod cap, effort days, handline, line and handline, and recreational;
  - so do the coastal trips, the cod-cap and recreational allocations (97-100 %), and the lumpfish logbook (99.8 %);
  - the scallop (91 %), mackerel (54 %), catch-quota (49 %) and inshore-shrimp (20 %) allocations imply theirs less
    often;
  - in the landings, Danish seine, lumpfish nets and sea cucumber imply their licence on 99 % of vessel-days, and
    sea urchin on 97 %.
- **Four class tables are copies** of `kvoti.skipasaga`: `ufs.skipasaga`, `st_skipa`, the `vessel` schema's
  back-fill to 2023-12-18, and mbl's snapshot. Copies are not counted as witnesses.
- **Before 1991 the dumps hold only the lumpfish logbook** (from 1980) and activity.
- **After 2020-07-22 these licences have no witness but activity:**
  - Danish seine, whelk, crab, quahog and tuna;
  - the foreign vessels' licences;
  - revocations.
- **Proposed:** staged sources, an evidence table of every witness, and a licence history chosen from it by ordered
  rules (§5). It is built in the `once` project.

## 2. The licence tables

**Only kvoti holds fishing licences.** Oracle's catalogue lists 14,057 objects in 128 schemas. Searched by name and
comment, the other licence objects are weighing licences (`ask`'s `vleyfi_*`, the `vigtunarleyfi` schema),
aquaculture licences (`eldi`), Oracle's own, and `vessel.operational_category`.

**Every per-licence table stops on 2020-07-22**, by its last entry stamp. Licences valid that day run to 2020-08-31
(the fishing year) or 2020-12-31 (the calendar year); 1,324 do. So does `ufs.skipasaga`, the Directorate's later copy
of the vessel history. The shared last day suggests that the Directorate's systems changed on 2020-07-22 (assumed;
ask a).

| table | rows | span | holds | key | defects |
|---|---|---|---|---|---|
| `veidileyfi` | 61,847 | starts 1996-02-04 to 2020-07-22, ends to 2020-12-31 | every licence issued (from 1996-09-01, by its comment): vid, type, area, valid from and to, transfer flag, lumpfish licence number, unpaid flag | `id`, unique (set on old rows in 2011); the comment's key (vid, from, to, type, area) | 1 repeated comment key; 3 end before they start, 172 on the day they start; 231 overlap an earlier licence of the same vid and type; 18 unpaid (`er_ovirk`); 139 transfer rows; no open end |
| `veidileyfi_v` | 61,847 | as above | the same rows, with the type's and area's names in Icelandic and English | `id` | a view: every `id` is in the table |
| `veidileyfi_eydd` | 3,661 | deleted 1999-10-28 to 2020-07-22 (`sbt`) | deleted licences, copied at deletion | none (its comment) | 394 rows repeat another (3,322 distinct); 2,291 deleted before they started |
| `strandveidileyfi_v` | 7,904 | 2009-06-26 to 2020-08-31 | coastal-fishing licences | as `veidileyfi` | a view: all 7,904 are `veidileyfi` rows (7,902 of type 37, 2 of type 1) |
| `grasleppusaga` | 3,472 | 1996-03-11 to 2021-07-20 | the history of each lumpfish right, by licence number: hull, status, area, the retired volume rule (`m3`) | none; 8 repeated (number, from) | 516 numbers on 968 hulls (a right moves between hulls); status V 2,581, G (stored) 815, F 65, S 11; one ends 2099-12-31; every row stamped 2022-01-03 (a reload); 21 rows in 2021 |
| `grasleppurettindi` | 447 | stored 1999-03-20 to 2021-11-04 | each lumpfish right's state in 2021: active or stored | licence number | 436 of 447 numbers in `grasleppusaga` |
| `grasleppa`, `geymsla_grasleppu` | 533, 78 | undated; stored 1996-2000 | an older list of lumpfish rights by tonnage; rights put in storage | — | no dates in `grasleppa` |
| `grasleppa_veidarfaeri` | 1,743 | seasons 2014-2020 | each lumpfish application's number of nets and headline length (median 113 nets of 64 m) | — | carries the operator's kennitala |
| `dragnot_leyfi` + `dragnot_timabil` | 1,471 + 112 | 1994-2010 | Danish seine licences of 31 hulls by period: half-months 1994-2004, one period 1 Sep to 20 Dec 2005-2010 | (vid, year, period), unique | 84 surrendered (`dags_afsals`); `dragnot_timabil` has years `9394` and `94` |
| `veidileyfi_sviptingar` | 4,404 | 1996-05 to 2020-08-04 | revocations of all a hull's licences, from and to, by cause (`sv_flokkun`): logbook not returned D 1,344, development fund Þ 962, catch over quota U 685, unpaid fees V 541, unpaid levy O 503, article 15 of act 57/1996 S 369 | none; 8 repeated (vid, from) | 54 open ends; 57 end before they start, 91 on the day; 13 with a year of 1-3 digits (0012-12-02, 0201-09-02, 0219-03-25 …): the century lost |
| `veidileyfi_sviptingar_skip` | 1,323 | — | a list of vids | vid | no dates; 1,298 in the revocations |
| `veidileyfi_svipt_tilk` | 16,451 | 1991-11 (4 rows), 2002-2020 | notices of an impending revocation | — | 16,450 withdrawn; kennitala and message text; 32 dates before 1990 and one in 2055 |
| `veidileyfi_svipt_undanthaga` | 262 | 2004-2018 | exemptions, named by purpose (net and trawl surveys, aquaculture, capelin search) | — | one year 0004 |
| `veidileyfi_vanskil` | 378 | 2002-2003 | hulls sent no licence, or not collecting it, for debt | — | two years of one digit |
| `yfirlit_veidileyfa` | 1,045 | 1996-2020 | the catalogue of lawful licences: type, area, season start, number of days, end | `id` (= `vlyf_id`) | every licence's `vlyf_id` resolves; 28 licences differ from it in type, 3 in area |
| `tegund_veidileyfis`, `svaedi_veidileyfis` | 54, 44 | — | licence types (codes 1-54 and `L1`) and areas (Icelandic regions and bays, the coastal areas, foreign EEZs, NEAFC, NAFO), named in both languages | `kodi` | none |

**Not licences:**
- `skip_timabil` is every vid crossed with every fishing year, `0001` to `9900`.
- `uthl_makrill_veidileyfi` holds 3 rows.
- `veidileyfi_postlisti`, `veidileyfi_svipt_bodunars` and `veidileyfi_textar` hold mail settings, contact agreements
  and print texts.

**51 of the 54 types are used**, each with its own season:
- 34,062 licences start on 1 September and 37,697 end on 31 August: one fishing year.
- The coastal licence (37) runs May to August, by area (`SA`-`SD`).
- Lumpfish (11) runs from 20 March or later, by area (`A`-`G`).

**Foreign vessels hold 2,967 of the licences**, on vids 3700-4999. Types 16, 19, 20, 21, 22, 24 and 35 are
licences for foreign vessels (blue whiting, capelin, oceanic redfish, Faroese long line and hand line, herring, EU
redfish). These rows are the only Icelandic record that a foreign hull was allowed to fish in Icelandic waters
(plans 017, 021).

## 3. The other witnesses

### 3.1 The class: the fishing system of each hull

The class (útgerðarflokkur, 43 codes) puts each hull in a fishing system, such as catch quota, hook-and-line quota,
coastal, recreational, foreign, research, inactive, or rights surrendered.

**`kvoti.skipasaga`** is the Directorate of Fisheries' history of each hull, with one row per change. A row holds:
- district letters and number, name, home port;
- the class;
- tonnage and dimensions;
- owner and operator by kennitala.

It has 65,576 rows on 5,363 hulls, chained without gaps (each row starts where the one before ends). `saga_nr` 0 is
the current row, open to 2099-12-31.
- **It mostly records class changes.** Of the 60,213 rows after a hull's first, 54.5 % change the class and 29,796
  change nothing else. The coastal class is entered and left every season.
- **It opens on 1991-01-01** with every hull's state that day, after 2,973 placeholder rows dated 1901. The counts on
  15 January 1991 and 1992 are identical. In 1991 it holds:
  - 1,149 line-and-handline boats (99);
  - 777 small boats with catch quota (90);
  - 380 in the null class.
- **It ends 2023-12-07.** 5,733 class changes are dated after 2020-07-22.

`reference/vessels/vessel_class.R` already reads it for the trail's leisure flag. That script carries the last class
after 2023-12-07 unchanged.

**`vessel.vessel_operational_hist` continues it from 2023-12-19.** It is written from that day and back-filled to
1904. Before 1991 every row has no class.

### 3.2 The quota record

Kept by the Directorate apart from the licences, for catch control:

| table | span | holds |
|---|---|---|
| `afla_heimild` | fishing years 1991/92 to 2026-10-15 | each hull's rights and catch by quota type and fishing year: allocation `R` (2,472 hulls in 1991, 344-761 a year after 2020), transfers `A`-`D`, carry-over `M`, equalisation fund `J` (from 1993), cod-cap allocation `F` (1995-2000), recreational allocation `H` (35 hulls 2020-2024), catch to quota `X` |
| `afla_hlutdeild`, `upphafsuthlutun` | 1991 to 2021-08 | quota shares, and the first allocation of each share (the comment calls it "rather poor information") |
| `uthl_makrill`, `makrill_flokkur` | 2009/10-2017/18; 2018/19-2019/20 | mackerel allocations; the mackerel class (A, B) of 1,253 hull-years |
| `lods_slaegt` | 1992-09 to 2026-10-14 | every landing line's quota type (`kfteg`) and catch type (`gerd`: to quota, not to quota, VS catch, line concession, undersize, damaged) |

**Area quotas begin in 2022/23** (`kvotategundir_heiti`, entered 2022-12-21):
- sea cucumber in eight zones (101-108);
- sea urchin in three (116-118);
- scallop in Breiðasund and Hvammsfjörður (901, 902);
- lumpfish (951) is landed against quota from 2024-09-02: 259 hulls by 2026-08.

These quotas name the hull, the species and the area for licences that had no table after 2020: sea cucumber (40),
sea urchin (7) and scallop (6). The landings' catch type does not mark coastal fishing: `S`, the catch not counted to
quota, covers 1,000-1,260 hulls a year.

### 3.3 Notices, trips and logbooks

| table | span | holds |
|---|---|---|
| `kvoti.tilkynning_sokn` | 1996-2002 (and 7 rows dated 1980) | 133,507 departure and arrival notices of effort-day boats, with gear (line or handline) |
| `kvoti.fluttir_soknardagar`, `soknarheimild` | 1996-05; 2001-2005 | effort days moved between hulls; effort-day rights |
| `kvoti.strandveidar` | 2009-06 to 2021-02-08 | 231,015 coastal trips: each landing with its STK departure and arrival. A trip table for plan 023, and a witness of the coastal licence to the end of the 2020 season |
| `afli`/`fs_afli` `grasl_stofn`, `grasl_sokn`, `g_sokn` | 1980-2016 (one row 1977) | the lumpfish logbook: one form per hull and year (99-447 hulls a year), and its sets |

### 3.4 Activity

Landings (`lods` from 1992-09, `agf` from 2007-09, the weighing reports of `radst_vskyrslur` from 1982) and logbooks
show what was fished, and with what gear. Activity is a witness of another kind, as in plan 028's rule D6. It can bound
a licence and flag its absence. It cannot be used to check the same activity, which would be circular.

### 3.5 Overlaps: how far the records agree

Two records that cover the same years test each other. Agreement between copies proves only the copy.

**The overlap is the calibration** (maintainer, 2026-10-18). How far a secondary record agreed with the licence
tables while both existed is how far it can be trusted after they stop. It is measured both ways:
- **implies:** the share of the record's hulls that held the licence;
- **covers:** the share of licence holders that appear in the record.

A record can change over time. So the last years of the overlap weigh most: the line-and-handline class implied its
licence for 54 % of hull-years over 1996-2001, and 99 % in its last five.

The table below is the hand count that came first. `curated/vessel/licence/calibration.parquet` now gives both
measures for every witness, group and year (step 3, decision 134), summed after it.

| pair | years | measured on | agreement | reading |
|---|---|---|---|---|
| `veidileyfi_v`, `strandveidileyfi_v` against `veidileyfi` | 1996-2020 | rows | all | views, not witnesses |
| `veidileyfi_eydd` against `veidileyfi` | 1999-2020 | deleted rows that stand in the table | 961 of 3,322; 958 entered again after the deletion, 3 before it | consistent: licences re-issued |
| `grasleppusaga` against `veidileyfi` type 11 | 1996-2020 | (hull, licence number); dates | 88-91 % of rows each way; the start date 8-18 %; the end date 1 in 634 | two records: the right's history and the season's licence |
| `dragnot_leyfi` against licences 8-10 | 1996-2010 | hull-years | 188 of 188, mostly type 10 in area 17 (Faxaflói) | two records that agree |
| `ufs.skipasaga` against `kvoti.skipasaga` | 1992-2020 | class on 15 June; class runs | 99.8-100 %; 82.4 % of runs start on the same day | a copy |
| `kvoti.st_skipa` against `kvoti.skipasaga` | 1992-2023 | class on 15 June | 100 %, on 179-1,308 hulls | a partial copy |
| `vessel_operational_hist` against `kvoti.skipasaga` | 1992-2023 | class on 15 June; class runs | 88-100 %; 96.8 % of runs | a back-filled copy, which drops class −10 (rights surrendered to the development fund) and keeps the hull's last fishing class |
| mbl's class against `kvoti.skipasaga` | 2022-12-28 | class name | 3,730 of 3,756 hulls | a copy of the Directorate's |
| class −12 against licence 37 (coastal) | 2010-2020 | hulls on 15 June | all but 0-3 a year | two records that agree |
| class 96 against licence 32 (hook-and-line quota) | 2002-2020 | hulls on 15 January | all but 0-4 a year | two records that agree |
| cod-cap allocation `F` against licence 3 | 1996-2000 | hulls a fishing year | 97-100 % of `F` hulls hold the licence; 89-100 % of licence hulls have `F` | two records that agree |
| effort-day notices against licence 23 | 1999-2001 | hulls a year | 68-72 % of the notice hulls hold it; the notices of 1996-1998 come before licence 23 | partial |
| mackerel allocation against licences 26, 43-45, 53 | 2010-2017 | hulls a year | 35-73 % of licence hulls have an allocation in 2010-2013, 90-98 % in 2014-2017; allocations reach more hulls (2015: 313 against 173) | an allocation is not a licence |
| recreational allocation `H` against licences 38, 39, 42 | 2010-2019 | hulls a year | 72-100 % of `H` hulls hold one (all in 7 of 10 years); a fifth to a third of licence hulls have no `H` | `H` implies the licence |
| catch-quota allocation `R` against licence 1 | 2012-2019 | hulls a year | 57-68 % of licence hulls; allocations reach more hulls | no witness for licence 1 |
| lumpfish logbook against the lumpfish licence (11, 36, `grasleppusaga`) | 1997-2016 | hulls a year | 97-100 % of logbook hulls hold a licence; the logbook covers 12-80 % of licence hulls | the logbook implies the licence |

**Calibrated** (step 3, decision 134). Each statement is cut at year ends, and each measure is taken over the last
five years in which the register held the group:

| group | record | overlap | implies | covers |
|---|---|---|---|---|
| coastal | class −12; coastal trips | 2009-2020 | 0.998; 0.999 | 0.997; 0.957 |
| hook-and-line quota | class 96 | 2000-2020 | 0.998 | 0.999 |
| catch quota | class (10-91, the fishing-vessel classes) | 1996-2020 | 0.995 | 0.995 |
| catch quota | allocation `R` | 1996-2020 | 0.494 | 0.606 |
| cod cap | class 98; allocation `F` | 1996-2001 | 0.996; 0.971 | 1.000; 0.935 |
| effort days | class 101; notices | 1999-2006; 1999-2002 | 0.998; 0.699 | 1.000; 0.379 |
| handline; line and handline | class 100; class 99 | 1996-2001 | 1.000; 0.993 | 1.000; 1.000 |
| recreational | class 89, 95, −11; allocation `H` | 2009-2020; 2010-2020 | 0.980; 1.000 | 1.000; 0.422 |
| lumpfish | lumpfish logbook; class 93; landings | 1996-2016; 1996-2020; 1996-2020 | 0.998; 0.314; 0.992 | 0.247; 0.005; 0.710 |
| mackerel | allocations (`uthl_makrill`); mackerel class | 2010-2018; 2018 | 0.543; 0.116 | 0.792; 0.973 |
| scallop | allocation; landings | 1996-2003 | 0.906; 0.932 | 0.770; 0.424 |
| inshore shrimp | allocation by area | 1996-2017 | 0.203 | 0.754 |
| Danish seine; sea cucumber; sea urchin | landings | 1994-2020; 2010-2020; 1996-2020 | 0.992; 0.998; 0.965 | 0.921; 0.777; 0.617 |

The mackerel allocations of quota type 36 (from 2019) have no overlap: uncalibrated.

### 3.6 Are the licence tables complete?

Tested on the landings, as a check of the sources, not a use:
- **To 2020-07-22:** 99.76 % of 1,488,695 Icelandic landing vessel-days fall on a day with a valid licence (99.1 %
  in 2019, 99.4-99.9 % in the other years). The rest are 3,503 vessel-days and 60.6 kt.
- **The class:** a fishing class covers 99.6-99.9 % of them a year to 2022 and 98.6-98.9 % in 2023-2025. Most of
  the rest is seaweed harvest (class −14: 6 hulls, 126 kt from 2020-07-23) and the null class (0: 195 hulls,
  7.9 kt).
- **Foreign hulls:** 33 % of their landing vessel-days fall on a licence. They need none to land in Iceland what they
  caught elsewhere.

## 4. Coverage: which witness speaks, by licence and period

| licences (types) | before 1991 | 1991 to 1996-08 | 1996-09 to 2020-07-22 | after 2020-07-22 |
|---|---|---|---|---|
| coastal (37) | — | — | licences (from 2009); class −12; coastal trips | class −12 (to 2026-06); coastal trips (to 2021-02) |
| hook boats: handline, line, cod cap, effort days, hook-and-line quota (2, 3, 14, 23, 32) | — | class (99, 98, 100, 101, 96); cod-cap allocation `F` (1995) | licences; class; `F` (to 2000); effort-day notices (1996-2002) | class 96 |
| catch quota (1) | — | class (the fishing-vessel classes); quota record (weak) | licences | class; quota record (weak) |
| recreational (38, 39, 42) | — | — | licences (from 2009); class 89, 95, −11; `H` | class; `H` (to 2024) |
| lumpfish (11, 36) | lumpfish logbook (from 1980) | lumpfish logbook; rights from 1996-03 | licences; rights; logbook (to 2016) | rights (to 2021-07); quota 951 (from 2024-09); activity between |
| Danish seine (8, 9, 10) | — | `dragnot_leyfi` (from 1994) | licences; `dragnot_leyfi` (to 2010) | activity only |
| mackerel (26, 43-45, 53) | — | — | licences (from 2002); allocations (from 2009/10) | allocations (quota type 36) |
| sea cucumber (40), sea urchin (7), scallop (6) | — | — | licences | activity only to 2022-08; area quotas from 2022/23 |
| inshore shrimp (4) | — | quota record by area (51-58) | licences (to 2017); quota record | quota record by area |
| distant waters (12, 13, 15, 25, 28-31, 33, 41, 46-48) | — | quota record by stock | licences; quota record | quota record by stock |
| whelk, crab, quahog, tuna, deep sea, experimental (34, 49-52, 54, `L1`) | — | — | licences | activity only |
| foreign vessels (16, 19-22, 24, 27, 35) | — | — | licences | none |
| revocations | — | — | revocations (from 1996-05); notices (2002-2020) | none |

## 5. Proposed

### 5.1 Staging: the sources as they are

`sources/kvoti/licence.R` writes `staging/kvoti/` from the dump, one table per source. Columns are renamed to the
house style; nothing else changes.
- **The licence register:**
  - `licence`: `veidileyfi`;
  - `licence_deleted`: `veidileyfi_eydd`, with its repeats kept;
  - `licence_lumpfish`: `grasleppusaga`, with `grasleppurettindi`'s 2021 state beside it;
  - `licence_lumpfish_gear`: `grasleppa_veidarfaeri`'s nets and headline lengths, staged for the flow's gear
    quantity and not used here;
  - `licence_seine`: `dragnot_leyfi`, with its period's dates from `dragnot_timabil`;
  - `licence_revocation`: `veidileyfi_sviptingar`, with its cause;
  - `licence_exemption` and `licence_arrears`: `veidileyfi_svipt_undanthaga` and `veidileyfi_vanskil`;
  - `licence_code`: the types, the areas and the catalogue (`yfirlit_veidileyfa`).
- **The witnesses:**
  - `class`: `kvoti.skipasaga`'s class runs, and `vessel_operational_hist`'s from 2023-12-19;
  - `quota_right`: `afla_heimild`'s rights (not its catch), `uthl_makrill` and `makrill_flokkur`, with the quota
    types' names;
  - `effort_day_notice`: `tilkynning_sokn`;
  - `coastal_trip`: `strandveidar`'s hull and dates;
  - `lumpfish_logbook`: `grasl_stofn`, one row per hull and year.

The copies (`veidileyfi_v`, `strandveidileyfi_v`, `ufs.skipasaga`, `st_skipa`) are not read. The check (§5.6)
proves them copies. Activity is read from `curated/` when the evidence table is built, not staged again.

**Personal data.** Kennitala is kept: the lumpfish right's owner and the net application's operator. The
maintainer's general rule (2026-10-18) is that kennitala may be carried up to and including `curated/`, under
`$FISHYDATA` only, never in the repo, docs or anything published. Staging also:
- keeps the free-text notes as given, which give the reason for a storage, deletion or revocation;
- drops the staff's user names in the stamps (`snn`, `sbn`, `sng`, `sbg`, `gerandi`), which nothing uses;
- keeps the stamps' times, which date the entry and the deletion.

The notices of `veidileyfi_svipt_tilk`, the contact agreements, the mail settings and `strandveidar_logskradur`
(coastal boats' owners) are not read: the history needs none of them.

### 5.2 Corrections

Declared in `curate/corrections/`, each a `.yml` beside its `.R`. The original is kept beside every corrected value:
- **`licence_lost_century`:** the 1-3 digit years in the revocations, exemptions and arrears (16 rows).
  - A year *y* below 100 becomes 2000 + *y* when that falls within a year of the row's entry stamp: 0012-12-02,
    entered 2012-12-04, becomes 2012-12-02.
  - The rest are flagged, not guessed: 0201-09-02 ends a revocation that started 2015-08-31.
- **Interval order:** a licence or revocation that ends before it starts is flagged and left as given.

### 5.3 Lineages and the evidence table

**Lineages.** Agreement between copies proves only the copy, so witnesses are counted by lineage:

| lineage | its records |
|---|---|
| the licence register | `veidileyfi`, `veidileyfi_eydd`, `grasleppusaga`, `grasleppurettindi`, `dragnot_leyfi`, the revocations, exemptions and arrears |
| the class record | `kvoti.skipasaga`; its copies `ufs.skipasaga`, `st_skipa`, mbl's class and `vessel_operational_hist` to 2023-12-18; `vessel_operational_hist` itself after |
| the quota record | `afla_heimild`, `afla_hlutdeild`, `uthl_makrill`, `makrill_flokkur`, the landings' quota type |
| notices and trips | `tilkynning_sokn`, `strandveidar` |
| the lumpfish logbook | `grasl_stofn`, `grasl_sokn` |
| activity | landings by gear and species; logbook stations |

The first four lineages are the Directorate of Fisheries'. Plan 028 counts them as one lineage. Here they are
separate records, kept for different purposes, and §3.5 shows they disagree in ways a copy would not. Whether to count
them apart is ask f.

**`curated/vessel/licence/evidence.parquet`** holds one row per witness statement:
- vid, licence group and type where the witness names one, area, `t1`, `t2`;
- the witness: source table and row;
- its lineage;
- what it says: `held`, `implied`, `absent` or `revoked`.

It is the only place where the witnesses meet. The history (§5.5) is chosen from it.

### 5.4 The rules, in order

The first rule that applies decides. Each writes its id into `rule`.

- **L0 Recorded.** A row of the licence register is taken as given, after the corrections of §5.2. Other lineages
  flag it and never change it.
- **L1 Review.** A person's decision in `overrides/licence_reviewed.csv` (vid, type, window, decision, reviewer,
  date, reason) outranks every rule below.
- **L2 Implied by a separate record.** Where the register is silent, a record of another lineage gives a licence row
  with basis `reconstructed`. It must have implied the licence at least 95 % of the time in the last years of the
  overlap (§3.5; the threshold is proposed, ask b). By that measure (decision 134):
  - the class: coastal (−12), hook-and-line quota (96), catch quota (10-91), cod cap (98), effort days (101),
    handline (100), line and handline (99), recreational (89, 95, −11);
  - the coastal trips;
  - the cod-cap (`F`) and recreational (`H`) allocations;
  - the lumpfish logbook.

  Below the bar, so these flag only:
  - the effort-day notices (0.70);
  - class 93, only a lumpfish licence (0.31);
  - the scallop (0.91), mackerel (0.54), catch-quota (0.49) and inshore-shrimp (0.20) allocations.

  Activity reaches the bar (0.97-1.00), but it stays under L4 (ask g).

  Each row carries its witness, and the record's `implies` and `covers` from the overlap.
- **L3 Implied, not calibrated.** A record with no overlap to measure on gives a row with basis `reconstructed` and
  flag `uncalibrated`. These are:
  - the area quotas for sea cucumber, sea urchin and scallop (from 2022/23);
  - lumpfish quota 951 (from 2024/25);
  - mackerel allocations after 2020 (quota type 36). They have no overlap of their own, and the allocations
    before them implied the licence for only 54 % of hulls.
- **L4 Activity.** Activity never makes a licence row by default. It bounds and flags: a gear that requires a
  licence, landed with no licence row covering the day, goes `open`. Ask g is whether activity may imply a licence
  where no other lineage speaks (lumpfish 2021-2024, Danish seine after 2020).
- **L5 Open.** Anything left, and every disagreement between lineages, goes `open`, is listed on the docs page, and
  waits for L1.

A systematic difference is not settled row by row. Examples are the vessel schema dropping class −10, and an
allocation reaching hulls with no licence. It is described once, on the docs page and in `curate/corrections/` when it
is a defect.

### 5.5 The licence history: `curated/vessel/licence.parquet`

The frozen history to 2020-07-22 (`curated/vessel/licence/history.parquet`, §5.7) with the live tail after it.

One row per licence held, implied, deleted, stored, surrendered or revoked:

| column | holds |
|---|---|
| `vid` | the hull, foreign vids included |
| `licence_type`, `licence_name`, `licence_name_en` | `tegund_veidileyfis`; NA for a revocation, which stops every licence |
| `area`, `area_name`, `area_name_en` | `svaedi_veidileyfis`, or the area quota's zone |
| `t1`, `t2` | plain TIMESTAMP, UTC, `[t1, t2)`: a licence from 00:00 of its first day to 00:00 of the day after its last; a revocation at its own time; NA `t2` for an open end |
| `status` | `held`, `unpaid` (`er_ovirk`), `deleted` (with `t_deleted`), `stored` (lumpfish G), `surrendered` (Danish seine), `revoked`; the source's own status kept in `status_source` |
| `revocation_cause` | the cause of a revocation |
| `licence_no` | the lumpfish licence number, which moves between hulls |
| `source`, `lineage` | the table and row it came from, and its lineage |
| `rule`, `basis` | the deciding rule (L0-L5); `recorded` for L0, `reconstructed` for L2-L3 |
| `witnesses` | the other lineages that agree |
| `implies`, `covers` | for a reconstructed row, its record's agreement in the overlap (§3.5): the share of its hulls that held the licence, and the share of licence holders it named |
| `flag` | the checks' findings on the row, e.g. `lost_century`, `overlap_same_type`, `uncalibrated` |

- **Nothing is cut.** A revocation sits beside the licences it stopped. A licence was in force at time *t* when a
  `held` row covers *t* and no `revoked` row of the hull does.
- **The class itself stays in `vessel_class`.** This table holds only the licences implied by it.
- **It is plan 028's `vessel_licence_hist`** (§3.5 there). Once it is built, the register's evidence table and its
  checks read it instead of kvoti, so kvoti's licence tables are read once (ask e).

### 5.6 Checks: `curate/checks/licence.R` → `curated/check/licence_discrepancy.parquet`

**Within the licence register:**
- repeated keys:
  - `veidileyfi`: 1;
  - deleted rows: 394;
  - revocations: 8;
  - lumpfish: 8;
- interval order, open ends, the lost century;
- overlapping licences of one vid and type (231);
- deleted licences entered again (958) or still standing (3);
- a licence against its catalogue entry (28 types, 3 areas);
- one lumpfish licence number on two hulls at once;
- a licence held while the hull is revoked, by cause.

**Between lineages** (§3.5, rebuilt by the check so a new dump shows a change):
- each overlap's agreement, a year at a time;
- the copies equal to their source: `veidileyfi_v`, `strandveidileyfi_v`, `ufs.skipasaga`, `st_skipa`, and
  `vessel_operational_hist` to 2023-12-18, with class −10 counted apart;
- a licence with no class or right that should go with it, and the reverse;
- the register (plan 028): a licence on a deregistered hull, or on a hull whose type is not a fishing one. These
  checks exist in `skipaskra_discrepancy.R` and move here once this table exists;
- completeness: the share of landing vessel-days with a licence (§3.6), a year at a time.

**Found in passing in plan 028's check** (`skipaskra_discrepancy.R`), to fix there:
- It reads `dragnot_leyfi` as whole calendar years and ignores surrender, where the periods give the dates.
- Its lumpfish licence is type 11 alone (not 36, lumpfish male).
- Its lumpfish gear is the lumpfish net alone, not the lumpfish-male net (`agf` 4, `lods` 29).

Each finding gets a row: what, which rows, the value and its witness. A docs page, `docs/licence.qmd`, shows:
- the coverage of §4 as each lineage gives it;
- the agreement of §3.5;
- the counts by check and year.

It shows no rows.

### 5.7 Where it builds

Split at 2020-07-22, the day the licence tables end (maintainer, 2026-10-18, decision 133), as the register is split
at 2023-12-19 (decision 132):

| part | project | writes | why |
|---|---|---|---|
| the history to 2020-07-22: staging, corrections, the evidence of every lineage, each witness's calibration (§3.5), the rules, reviewed overrides | `once` | `curated/vessel/licence/{evidence,calibration,history}.parquet` | closed sources; reviewed and frozen; read by the register's history and the STK key, which build in `once` |
| the live tail from 2020-07-23: the class and quota witnesses run through the same rules with the frozen calibration, on top of the frozen history | main, preprocessing side | `curated/vessel/licence.parquet` | the witnesses change with every dump; a `once` fix would need a decision for each |

- **The calibration is frozen with the history.** The tail uses the agreement measured in the overlap. It does not
  measure it again, because after 2020 there is nothing to measure against.
- **No AIS and no trail** in either part. The `once` part watches the landings and logbook stations as
  main-project files, for activity and completeness, as the key's targets do.
- **The scripts:**
  - in `once`, each with `# Side: once (licence history)`:
    - `sources/kvoti/licence.R` (target `kvoti_licence`);
    - `curate/corrections/licence_lost_century.{yml,R}`;
    - `reference/vessels/licence_evidence.R` (target `licence_evidence`, with the calibration);
    - `reference/vessels/licence_history.R` (target `licence_history`);
    - `curate/checks/licence.R` (target `check_licence`);
  - in the main project, with `# Side: preprocessing`: `reference/vessels/licence.R` (target `licence`). It reads
    the frozen history and calibration with `frozen_input()`.
- **Built by name, never as a whole project:** `tar_make_isolated(names = "check_licence")` in `once`, after the
  maintainer's go.
- **A licence system after 2020 that can be dumped (ask a)** goes into the live tail, not into a `once` redo.

## 6. Uses, named and not measured

Each is measured when it is built, in its own plan or TODO item:
- **The register** (plan 028): licences as witnesses in the evidence table and checks.
- **Settling conflicts in building the AIS side**, in the `once` key: which of two hulls on one mobile-id or MMSI held
  a licence that day (`ais_key_twins`, `ais_key_split_candidates`, the MMSI windows of TODO 82), and foreign hulls
  allowed to fish in Icelandic waters.
- **Gear ambiguities in the logbooks and landings:** a gear that requires a licence (lumpfish nets, Danish seine,
  dredges for scallop or sea cucumber) set against the licences held, beside `logbook_gear.yml`'s rule.
- **Interpreting the trail:** the licences a fix's vessel held. This is the one-flow's `gear_register` (step 3), and
  a second witness for the leisure flag.

## 7. Steps

1. Staging (§5.1), checked in a scratch store against the counts of §2 and §3.
2. The corrections (§5.2).
3. The evidence table (§5.3), with the overlaps of §3.5 rebuilt from it.
4. The rules and the licence history (§5.4-5.5).
5. The checks and the docs page (§5.6).
6. Wiring into `once`; the build by name after the maintainer's go.
7. The live tail in the main project (§5.7).
8. Plan 028's evidence table and checks read this table (ask e).

Steps 1-3 need no answer. Asks b, f and g settle step 4.

## 8. Asks

a. **Licences after 2020-07-22** (plan 028's ask c, moved here). The licence tables and `ufs.skipasaga` all stop that
   day. Which system holds licences now, at the Directorate of Fisheries? Can it be dumped, and by whom?
b. **The rules (§5.4).**
   - Is 95 % agreement the right bar for a record to imply a licence (L2)?
   - Should uncalibrated records (L3) imply licences at all, or only flag?
c. **The live witnesses.** Answered (maintainer, 2026-10-18, decision 133): the history to 2020-07-22 builds in
   `once`, and the live tail from 2020-07-23 in the main project, with the frozen calibration (§5.7).
d. **Lumpfish statuses F and S** (65 and 11 rows). What do they mean? Until then they are kept as given, with status
   `held`.
e. **Plan 028 reads this table.** Its `vessel_licence_hist` becomes this table, and its evidence and checks read it
   instead of kvoti. Proposed: yes, after step 5.
f. **Lineages.** Count the Directorate's licence register, class record, quota record and notices apart, as
   proposed? Plan 028 counts them as one.
g. **Activity as a witness.** May landings and logbooks imply a licence where no other lineage speaks? Examples are
   lumpfish 2021-2024 and Danish seine after 2020. Proposed: no, they only flag; the gap stays visible.
h. **Before 1991.** The dumps hold no licence or class before 1991 beyond the lumpfish logbook. Does a paper or
   archived record exist (the Directorate's or the ministry's), and is the period worth it?

## 9. Not in this plan

- Measuring the uses of §6 (maintainer, 2026-10-18).
- Weighing licences (`ask`, `vigtunarleyfi`) and aquaculture licences (`eldi`).
- Quota amounts: how much a hull may catch. The quota record is read here only for whether a hull held a right.
- Polygons for the licence areas and quota zones.
- The coastal trips of `strandveidar` as trips, which belong to plan 023.
