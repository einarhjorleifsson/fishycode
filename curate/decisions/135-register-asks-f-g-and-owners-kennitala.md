# 135 — Plan 028's decision model confirmed, Hreiðar's own numbers left in staging, owners and operators with kennitala

*2026-10-18. The maintainer's answers to plan 028 asks f and g and to the kennitala question, asked one at a time;
the counts and the parser fix by Claude (AI-assisted).*

## Decided

- **Ask f, the lineages.** Hreiðar's workbook does not count apart from the register for 2004-2021: his notes say he
  took values from it, and he agrees with the PDFs on 99.5 % of names and 99.8 % of build years. Before 2004 he is
  the period's source (§4.3). mbl counts as its own lineage, as §6.1 proposes.
- **Ask f, the rules.** They stand as §6.2 orders them. D4, the typo rule, may overrule the PDF. The consensus value
  takes basis `reconstructed`, the printed value is kept beside it, and the rule's error is measured on a sample of 50
  against the page images.
- **Ask g, Hreiðar's own numbers.** His 1,764 boats without a register number (90000 and above; 30,913 rows, nearly
  all before 1992) stay in `staging/hreidar/`, outside the history. They have no vid, and none is given.
- **Kennitala** (the maintainer's general rule of 2026-10-18, AGENTS.md):
  - `vessel_owners_hist` carries `national_identity_no` where a source has it;
  - `vessel_fishery_hist`, the operator, is built.

  Both stay under `$FISHYDATA`. §4.1 and §7 of plan 028 said otherwise and are amended.

## What the choice costs D4, measured before building

D4 needs two lineages besides the register agreeing with each other. With Hreiðar inside the register lineage, that
leaves the fisheries history and, for call signs, the radio lists.

Of 2,233 PDF values that stand alone in their series (the editions before and after agree with each other), D4 would
fire on 7 even with Hreiðar counted apart. Only Hreiðar gives the neighbours' value in 187 more, and only the
fisheries history in 9. So the choice moves at most 7 values. Most lone values have no second witness at all: a
one-year change, or a print variant such as 359.9 against 360.

## A reading fault found by the count (D0)

Two of the seven were the parser's, not the print's. In 2007, vids 1764 and 1929 print the GRT at the end of the head
line and wrap the length to the next line's left margin. `sk_parse_A()` ordered line 1's words by position alone, so
the wrapped length came first and GRT and length swapped. The head line now reads before what wrapped below it.

A rerun of `register.R` against the real store's `register.parquet` changes exactly these two entries. The 2005 cases
with the same note wrap both measures and were right. The `once` target `skipaskra_register` is rebuilt by hand with
step 5: `targets` does not see an edit in `R/` that its commands do not name.

## Licences go to plan 029

Plan 029 builds the licence history, and its §5.5 says the product is plan 028's `vessel_licence_hist`. Step 5
therefore does not build its own: two licence histories would be the fork AGENTS.md forbids. Until plan 029's table
exists, the register's evidence and checks read kvoti's licence tables, as now; plan 029 ask e decides the switch.

Plan 029 lists three faults in `skipaskra_discrepancy.R`'s licence checks:
- Danish seine licences read as whole calendar years, where the periods give dates;
- the lumpfish licence taken as type 11 alone, without 36 (lumpfish male);
- lumpfish-male nets (`agf` 4, `lods` 29) left out of the gear.

The two lumpfish faults are fixed with step 5. The Danish seine periods wait for plan 029's staged period table.
