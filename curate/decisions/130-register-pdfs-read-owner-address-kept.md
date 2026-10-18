# 130 — The annual register PDFs read whole (plan 028 step 1), and the owner and address kept

*2026-10-18. Coded and checked by Claude (AI-assisted), on the maintainer's go ("start implementing the plan"; "accuracy
over speed"). Code only: the three scripts ran against a scratch store, and nothing was written under the real
`$FISHYDATA`. They are not yet targets, which waits on plan 028 ask a. The checking scripts and the 150 page strips
were in the session's scratch and were not kept, so the numbers below are the record. Amended the same day: the
maintainer's rule, given in the step-2 session, keeps everything a public source prints, kennitala included, so the
name-prerogative list is now read too.*

## What was built

- **`R/skipaskra_pdf.R`:** the readers. They read the PDFs by word coordinates (`pdftools::pdf_data()`), not by
  `pdftotext -layout`, whose character columns jitter by up to four within one entry.
- **`sources/skipaskra/register.R`** writes `staging/skipaskra/register.parquet`: 43,430 entries, every entry of the 19
  editions, 2004-2022.
  - Text is kept as printed. Measures are parsed from the Icelandic print.
  - `note` says where the print needed reading: shifted cells, decimals cut, a place printed into the year, a district
    fused to the name, an unknown year printed "0" or "0000".
- **`sources/skipaskra/event.R`** writes `staging/skipaskra/event.parquet` and `event_total.parquet`: 1,637 rows of the
  previous year's registrations (743) and deregistrations (894, with date and fate), and the totals each list prints.
  2006 prints no lists.
- **`sources/skipaskra/lists.R`** writes three tables:
  - `draught.parquet`: 3,160 rows, 2004-2006, the only source of weight and light draught;
  - `index_list.parquet`: 22,969 rows by registration number and 6,754 by call sign, 2004-2013. The call-sign list
    holds every sign of the TF block, held or free. (22,964 at first: decision 131's checks found the reader dropping
    a name's trailing number and joining two blocks on 2007 p. 310. Both are fixed.);
  - `summary.parquet`: 1,309 cells from 41 of the prefaces' tables by year;
  - `name_prerogative.parquet`: the names reserved for a holder, 173-239 a year in all 19 editions, with the
    holder's name, and kennitala in 2013-2015. 2004-2006 print it in two blocks with no header, so their columns
    are read from the data.

## The owner and the address are kept, and what else a public source prints

Asked whether the readers should keep the owner's name and address, the maintainer chose "Keep both, $FISHYDATA only"
(2026-10-18), noting that they are public in the register. In the step-2 session the same day, they widened it: owner
and operator names and addresses are kept as printed, "and so is anything else from a public source", and all of
Hreiðar's columns are kept, at least in staging (commits bb8fe9a and 662b99e, merged in c56278d). Asked directly in the
main session whether that is the rule (kennitala, phone numbers and Hreiðar's counts of people lost included), the
maintainer answered "Yes, that's my rule". Everything stays
under `$FISHYDATA`, never in the repository, docs or anything published. This replaces decision 121's default for
the register and its kin. Plan 028 §7 is amended to match, and ask b (Hreiðar's counts of people lost and rescued) is
answered: kept in staging.

## Superseded — kept for the reasoning

The first answer covered names and addresses only, so this record said at first that kennitala (printed in the
2013-2015 name-prerogative list) and phone numbers stayed unread, and the name-prerogative list was not read. The
maintainer's public-source rule overturned that the same day.

## How the PDFs read

- **Layout A, 2004-2017 (five-line blocks).** Tokens are typed by content before position. A 4-digit integer is a
  year, 7 digits an IMO number, a district comes from the key's letters, and a material from the key's list. A line's
  measures are taken in order when it has as many as it has measure columns.

  The quirks met, each handled and noted on the entry:
  - 2007 sets cells at tab stops and leaves an empty one out, so the rest stand a stop to the left;
  - 2005 and 2007 sometimes print line 1's GRT and length on a line of their own below it;
  - 2012-2013 print "IMO-nr." 3 pt above its header line;
  - a long place is printed into the year ("HAFNARFJÖRÐU1987");
  - a district is fused to the name ("GUÐBRANDSDÓTTIRAK");
  - 2004-2006 cut the decimals of GT over 999 ("1310,"), and 2005 prints zero decimals as integers;
  - an unknown build year is "0" or "0000", and an unknown engine year "árg. 0";
  - a boat owned by "Siglingastofnun Íslands" prints the running head's words inside its entry.
- **Layout B, 2018 (two-line rows).** A wrapped cell is centred on its row, so a fragment goes to the row where its
  words fall in columns of their kind. An IMO wrapped over two lines is joined.
- **Layout C, 2019-2022.** A wrapped cell runs up to two lines above its row.
- **The lists** take their columns from each header and their kind (registration or deregistration, first or
  re-registration, decked or open) from the title above. Dates and measures are typed by content where they stand
  outside their label.

## Checked

1. **Counts.** For 2004-2017, every entry head in the layout text is read: entries equal heads in all 14 editions.
   Against each edition's stated totals:
   - equal in 2005, 2006, 2007, 2010, 2012, 2015, 2017, 2018, 2019 and 2021, and in 2022 against its trend table;
   - short in 2004 (10), 2008 (11), 2009 (12), 2011 (1) and 2013 (10), where the PDFs print fewer entries;
   - 2014 and 2016 differ by one between the sections.
2. **The second route.** Against the almost-tidy table of 2009-2017 (tabulizer):
   - the measures agree 100 % wherever both have a value, and the parse fills 2,125-2,664 more of each;
   - the text fields agree 96.2-100 %. Every difference inspected is the old route's (truncated home ports, expanded
     types, districts fused into names) or a different Unicode accent.
3. **Rules over every entry.** 166 of the 43,430 entries break a type, vocabulary or formula rule. Four break two or
   more, all one vessel (1483) whose type the print truncates. Ten IMO numbers fail their check digit as printed.
4. **Page images.** 150 entries, 50 per layout at random, were compared field by field with their page. The check
   found five faults:
   - A: the measures on a line of their own (2007, 1929);
   - A: the bare "0" year (2005, 1766);
   - A: "árg. 0" (2017, 2071);
   - B: a fragment given to the wrong row (2018, 1629);
   - C: a three-line wrap (2020, 2310-2311).

   Each fix reached beyond its case: 4 entries' line 1, 161 years, 485 engine years and 45 GRTs in 2019-2022. After
   the fixes, all 150 match the page as printed. Three second rows that fall on the next page, and 2007's line 5,
   were checked only as far as the crop showed them.
5. **Lists against their printed totals.** They are equal everywhere except where the list prints fewer rows than its
   own total:
   - 2004: decked 46 against 47, open 55 against 59;
   - 2016: 36 against "Fjöldi: 44";
   - 2018: 39 against 44.

## Found in the PDFs

These go to plan 028 §5's checks. None is repaired.

- **The 2020 edition reprints the 2019 register.** It has the same 2,278 numbers, and its own preface says 2,278,
  with 9 owners, 4 home ports and 1 GT changed. The 2021 and 2022 trend tables give 2020 as 2,267.
- **Number lists and registers disagree.** 2008's number list holds 15 numbers with no register entry, among them
  1716, which its preface says was on the waiting list. 2013's list has 2,297 numbers against 2,288 entries.
- **Lists shorter than their totals** (2004, 2016, 2018; above).
- **Clipped home ports.** 31 home ports in 2019-2022 begin mid-word ("eyjar", "fjörður"), because the PDF clips the
  first line of a wrapped cell, in the image and the text alike.
- **Totals that differ between editions:** 2010 is 2,237 in some editions and 2,238 in others. The 2019 trend table's
  last column, labelled 2018, holds 2019's figures (plan 028 §2.6).
- **IMO numbers:** 10 fail their check digit. For example, 1906199 for vid 1695 in 19 editions. Vid 975 prints
  9972912 in 12 editions and 6617946 in the others.

## Not done

- **Not targets.** The scripts carried `# Side: preprocessing` and waited on plan 028 ask a for their project. They
  are `once` targets since decision 132, built there the same day.
- **Step 2.** The other readers were on the other session's branch; merged in c56278d.
- **Steps 3-5**, the evidence table, the checks and the decision model, were still to come. Steps 3-4 are decision
  131; step 5 waits on plan 028's asks a and f (TODO 83).
