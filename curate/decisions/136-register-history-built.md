# 136 — The register's history to 2023-12-19, chosen by the decision model (plan 028 step 5)

*2026-10-18. Coded, checked and built by Claude (AI-assisted), on the maintainer's go ("proceed and ask"), with the
decision model the maintainer confirmed (decision 135). Built in the `once` project by name, at 314d8ee, and the history
and checks again at 43c513f. The maintainer then checked D2's 33 decisions against the page images, and the history was
rebuilt at 8527da7 with what that check found (below). The numbers here are the rebuild's; the first build's are under
"Superseded".*

## What was built

**`reference/vessels/skipaskra_history.R`**, the `once` target `skipaskra_history`, writes these to
`curated/vessel/skipaskra/`:

| table | rows | hulls |
|---|---|---|
| `vessel_hist` | 29,166 | 4,618 |
| `vessel_identification_hist` | 22,967 | 4,616 |
| `vessel_measurement_hist` | 15,397 | 4,615 |
| `vessel_engines_hist` | 13,393 | 3,462 |
| `vessel_operational_hist` | 36,333 | 3,144 |
| `vessel_fishery_hist` (operators, with `identity_no`) | 20,516 | 3,845 |
| `vessel_owners_hist` (with `national_identity_no`) | 27,089 | 3,795 |
| `vessel_mmsi_hist` | 3,584 | 2,609 |
| `vessel_event` | 20,720 | 5,313 |
| `registered`, the runs on the register | 6,157 | 4,702 |
| `annual_call_sign`, the call sign on each 1 January, 2004-2023 | 7,848 | |
| `usage_category_printed`, the printed types to the schema's codes | 122 | |
| `decision`, one row per column and stretch | 276,936 | |

How a value is chosen is in the script's head and plan 028 §4.3 and §6.2:
- each witness speaks for a window, and each stretch of time takes the first witness in its period's order;
- neighbouring stretches merge when printed alike;
- D1, D2 and D4 act on the PDFs' values, and D5 dates a change between annual witnesses;
- a value is kept only while the hull is on the register.

## Design choices the plan left open

- **A blank means none; a printed zero means unknown.** A field an edition prints (on 1 % of the entries of its
  section) and an entry leaves empty says the hull has none: no call sign, no previous name. 63,915 such blanks block
  the fall back to other sources. Before this, FJÖLVI (2196), which prints no call sign in 2006-2011, took kvoti's TFKC
  for those years. A printed zero ("0,00") is a placeholder, which other sources may fill (the maintainer's check,
  below).
- **kvoti's register copy is a snapshot of 2020-07-22.** Its `dagsfaerslu` is an entry date that dates no value:
  FJÖLVI's is 1993, with the call sign it was given in 2012. The evidence now dates the copy to that day, and the
  history reads it as a witness only. Its comparisons in the agreement table fell from 1,158 rows to 934.
- **Text and codes merge only when printed alike.** SI and SS are one body to the checks, but the change from
  Siglingastofnun to Samgöngustofa is the register's own. Numbers merge at their coarser precision.
- **A stretch must agree with the value its merged group carries.** A coarser print had bridged two that differ (GRT
  142.18 and 142.19 through 142.2, five hulls in 2005), so such a stretch now stands as a group of its own.
- **Registered life.** It is built from runs of the editions a hull is in and of Hreiðar's years in use (not his
  placeholder years).
  - Ends take a day from the lists, the first registration or the `vessel` schema where one falls in the bracket:
    1,835 starts and 810 ends are dated, and 2,327 runs reach 2023-12-19.
  - A hull printed in an edition was on the register that 1 January, so it left after it (GUÐRÚN, 243).
- **The operator's precedence.** No PDF prints the operator, so the general order applies: Hreiðar to 2021, then the
  `vessel` schema's dated rows.
- **Owners.** They are a set at a time: the PDFs' owner for 2004-2022, the `vessel` schema's before and after, and the
  2022-12-28 scrape where its owners differ from the 2022 edition's.
  - `national_identity_no` comes from the row's own source or, by name, from the `vessel` schema, kvoti's copy or the
    scrape: 26,680 of 27,089 rows carry one, 17,716 of them matched by name.
  - The `vessel` schema's nine-digit kennitala (429) lost a leading zero, and are padded to ten for matching.
- **The types of ship.** All 43,416 printed types map to a code. The bases, in order:
  - the maintainer's reading (`overrides/usage_category_printed_reviewed.csv`): OLÍUSKIP, an oil vessel, is 48,
    OLÍUFLUTNINGASKIP; BRUNNBÁTUR, a special cargo vessel or well-boat, possibly serving aquaculture, is 67,
    FLUTNINGA/BRUNNSKIP;
  - the code table's names;
  - the schema's own name-code pairs;
  - the code the schema gives the same hulls on the same date.

  `vessel_year.R`'s hand list was not copied.
- **`annual_call_sign` as a view** (plan 028 §4.4) is written beside the history. The STK key still reads
  `staging/skipaskra/annual_call_sign.parquet`, and the switch belongs to its redo (TODO 25).
- **The outputs are deterministic.** A rebuild had changed the order inside `alternatives` and among tied findings
  (DuckDB aggregates distinct values in no fixed order). Both are now sorted, and a rebuild reproduces the files.

## Reading faults found on the way (D0, fixed in the reader)

- **Three class codes were missing from the reader's list:** SR (2005-2013), DG (2015) and NG (2016-2017, DNV GL).
  With the code unknown, it and the call sign after it went into the home port on 22 entries, among them BJARTUR
  (1278, TFNV) and VÖTTUR (2734, TFMV), which lost their call signs for 2015-2017.
- **GRT and length swapped for 1764 and 1929 in 2007** (decision 135).
- A rerun of `register.R` against the built register changes exactly these 24 entries.

## Checked

Plan 028 step 5's checks, one by one:

1. **Tiling.** No table's rows overlap for a hull, and all lie within its registered life. They cover 90-98 % of it;
   the rest is where no column has a value.
2. **Every column filled where its source prints it.** All 880,054 PDF values equal the history on their edition's
   1 January.
3. **Every disputed value has a status, and a rule when resolved or open.** The script stops otherwise. Of the 276,936
   stretches:

   | status | stretches | share |
   |---|---|---|
   | single (one lineage) | 147,465 | 53.2 % |
   | agreed | 104,595 | 37.8 % |
   | resolved | 24,795 | 9.0 % |
   | open | 81 | 0.0 % |

   - D3 settled all the resolved; D2, D4 and D1 settled none.
   - 81 stay open under D2: 71 call signs below 15 m and 10 IMO numbers that fail their check digit.
   - 143 stretches carry the flag `gt_formula`.
   - D5 dated 29,123 of 67,062 changes between annual witnesses.
4. **The docs page counts each rule's decisions.** `docs/skipaskra.qmd` gained a section on the history; it renders
   against the built store.
5. **D2's and D4's samples, checked by a person.** D4 made no decision. The maintainer checked all 33 of D2's decisions
   in the first build against the page crops: the PDF was right on 32, a 97 % error (plan 028 §6.3).
   - The 32 were all GTs off the formula below 15 m, replaced by the fisheries' history. In 28 of them the value
     came only from the ufs journal's superseded versions, which the history uses as a witness nowhere else.
   - The one right was 6996 in 2018, where the PDF prints GT 0,00, a placeholder. The rebuild fills it from
     Hreiðar's 2018 value, 12.01, which every edition from 2019 prints too. The first build had the journal's 11.9.
   - What changed, by the maintainer's choice of "flag only": the GT formula flags a value and replaces none. D2 takes
     no value from the ufs journal. A printed zero is unknown, not none.
6. **The call signs against `annual_call_sign`.**
   - For 2007-2017 the history's call sign on each 1 January equals the built table on all 4,311.
   - For 2018-2022, against 88823e5's fixed parse built in a scratch store, 1,802 agree and none differs.
   - 47 are only in the history: the 2020-2022 matrices miss rows the PDFs print (2020 has 348 rows against 2019's
     373). DRÍFA (795) is printed in 2020 and ERNA (1175) in 2021, yet both are missing from those years' matrices.
   - 13 are only in the fixed table: in 2020, hulls deregistered in 2019 that the reprint still carries (TJALDANES,
     239).

**The build.**
- All six targets built at 314d8ee, exit 0, by name: the register by hand-invalidation, since `targets` cannot see an
  edit in `R/`.
- The `once` project's 12 outdated key, logger and radius targets stayed outdated, and their 26 files are
  byte-identical.
- Every output equals its scratch copy, apart from the order of tied values, since fixed.

**The checks, rebuilt.** Their findings are 61,049 (were 61,300):
- `witness_value` lost 271, kvoti's copy no longer being compared at the editions;
- the lumpfish fixes added 27 to `gear_without_licence`;
- the reader fixes moved a few others (`callsign_list` −2, `change_unexplained` −4, `rule_callsign_short` +1,
  `rule_gt_formula` −2).

## The rebuild of 8527da7

- `skipaskra_history` was rebuilt in the `once` project by name, exit 0, its 13 files identical to the scratch run.
- The `once` project's 12 outdated key, logger and radius targets stayed as they were.

## Superseded — kept for the reasoning

The first build (314d8ee, 43c513f) had:
- 30,587 rows in `vessel_hist`, 15,331 in `vessel_measurement_hist`, 14,572 in `vessel_engines_hist`, and 282,842
  stretches;
- 98,274 blanks, because a printed zero counted as none;
- 880,035 of 880,054 PDF values on the history, the 19 others replaced by D2;
- D2 replacing 33 values in 12 stretches, with 200 stretches open;
- 43,390 of 43,416 printed types mapped.

D2 then sought, for a GT off the formula, another lineage's value that keeps it. The maintainer's check showed that
the formula is no rule these GTs keep.

## Not done

- **Step 6, the live part** from 2023-12-19 in the main project, and **step 7**, repointing `vessel_sign`,
  `vessel_class`, `vessel_year` and `registry.R`.
- **Asks d and e** (the MMSI lists `mmsi.R` does not read; editions outside 2004-2022).
