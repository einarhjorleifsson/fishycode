# 131 — The register's evidence table and its checks (plan 028 steps 3-4)

*2026-10-18. Coded and checked by Claude (AI-assisted) on the maintainer's go ("start plan 028 steps 3-4 (evidence table
and checks)"; "accuracy over speed"). Code only. The three scripts ran against a scratch store, which read the real
`raw/`, landings and logbook and wrote nothing under the real `$FISHYDATA`. They are not yet targets, which waits on
plan 028 ask a. The checking scripts were in the session's scratch and were not kept, so the numbers below are the
record.*

## What was built

- **`reference/vessels/skipaskra_evidence.R`** writes `curated/vessel/skipaskra/evidence.parquet`.
  - It holds every value every witness gives for an Icelandic hull, in the `vessel` schema's tables and columns
    (plan 028 §4.2): 7,203,454 rows, 7,709 vids, 28 witnesses (65 sources counting each edition), 11 tables.
  - Each row carries its window (`t1`, `t2`), `source`, `lineage` (§6.1), `kind` (snapshot, interval, event, change,
    undated) and `record` (the witness's own row).
  - Nothing is chosen. Kennitala is not carried.
- **`curate/checks/skipaskra_discrepancy.R`** writes `curated/check/skipaskra_discrepancy.parquet`, one row per finding,
  and `curated/check/skipaskra_agreement.parquet`, each witness against the PDFs by edition and column.
  - 38 checks, in plan 028 §5's four groups.
  - Every finding is `status` "unsettled" until step 5's decision model runs.
- **`docs/skipaskra.qmd`** says what each check found. It shows counts only, since the findings carry owners' names.
  It rendered cleanly against the scratch store; that render was removed, so the first render after the build runs
  afresh.

## Checked

1. **Step 3.**
   - Every staged register value is in the evidence once (1,148,534 of 1,148,534).
   - No row has an empty source or value, and no value repeats within one witness's record.
   - Ten repeats remained in `ufs.skipasaga_jn`: two users changed one row in the same second. The journal's session
     now tells them apart.
2. **Step 4.** All 38 checks run, and each one's findings are counted: 61,300 in all, from 34 checks; four found
   nothing. By kind:

   | kind | findings |
   |---|---|
   | witness | 55,643 |
   | edition | 2,970 |
   | activity | 1,574 |
   | between editions | 977 |
   | parse | 136 |

3. **Each check's findings were sampled before they were kept.** The first run's samples showed artefacts in the
   check or the witness, not in the register. Each was fixed at its cause:
   - **The list reader** (`sk_parse_lists()`, a D0 reading fault) dropped a name's trailing number ("BOBBY 9" read as
     "BOBBY"), and ran two blocks together on 2007 p. 310, whose second block is too short to set the page's split.
     - Number-list name mismatches fell from 296 to 90.
     - The number list holds 22,969 rows, not 22,964 (decision 130 amended).
   - **"TF"** stands for no call sign in `kvoti.skipaskra_siglo` and the `vessel` schema, on 164 hulls each. Read as a
     sign, it put 26,732 false pairs among the call signs on two hulls (28,159, now 1,427). The evidence table now drops
     it, as it already dropped "0".
   - **Precision.** Some editions print GRT and NT to one decimal or none (2004: 23 % of GRTs to one decimal), so a PDF
     value is not taken to have two. Numbers compare at the coarser apparent precision, rounded or truncated.
     Unexplained changes between editions fell from 1,178 to 481.
   - **The MMSI archive's default window** (from 2007-06-01, to 2028-12-24, `window_basis` "default") is no date. It
     put 1,162 windows "opening" in 2007. Now 22 open in a year the hull is off the register.
   - **The inspection table** ("Skoðunaraðili") counts every ship by the body that inspects it, not the decked ships
     by class society. Only the societies and its total are compared.
   - **The ship-type vocabulary** gained "-TOGARI", and a district printed with a stop ("EA.") is no defect.
4. **The docs page's claims were measured before they were written**, and the page reads each from the findings. One
   was wrong as first drafted. 2013's number list is newer than its register, not older: of its 93 names that differ
   from the register, 83 are the hull's name in a later edition.

## Found

None of these is repaired; step 5 settles them.

- **The PDFs against the witnesses.**
  - 97.6 % of 1,799,403 comparisons agree, and 99.5 % on measures (lengths, breadths, depths, tonnages, kW, build
    years).
  - Names and districts agree 92 % with the Directorate of Fisheries' ship history (`kvoti.skipasaga`,
    `ufs.skipasaga`). The two lineages diverge in time. There are 52,851 disagreements (a value and one witness):
    in 11,629 the witness gives the hull's value of an earlier edition, in 1,137 of a later one, and 2,354 agree within
    half a year.
- **The `vessel` schema before 2023-12-19.**
  - None of its 19,825 back-filled identification rows carries a call sign. For 2004-2022 the call signs come only
    from the PDFs, kvoti's register copies and the ufs journal. This measures what plan 028 §3 suspected.
  - 6,217 of its 7,602 back-filled engine rows (deletions left out) hold the engine type "D" where the make belongs.
    This is one systematic defect, for a declared correction in step 5, not 42,000 disagreements. The check leaves the
    schema's one-letter makes (6,223) out of the comparison.
- **One call sign on two hulls at once:** 1,427 times in one witness. In 1,423 of them one hull had left the register
  before 2022. The `vessel` schema (from 2023-12-19) and kvoti's register copy keep a gone hull's sign while another
  holds it, as TFBR on 1473 and 2815.
- **Inside the editions.**
  - Entries differ from the edition's own count in 2004, 2008-2011, 2013, 2016 and 2020.
  - The key's rules: 996 GTs off the formula below 15 m, 481 call signs below 15 m length overall, 412 ships above
    24 m without an IMO number, 108 IMO numbers that fail their check digit.
  - 38 district numbers sit on two hulls in one edition.
- **Between the editions.**
  - The 2020 edition repeats 2019's register: 96.4 % of its entries exactly.
  - 2013's lists name 14 hulls as deregistered that its register still prints, and 23 as registered that it does not.
  - 267 fixed fields change between editions, 130 of them a value cut short in print. 13 are IMO numbers.
  - 49 trend-table figures differ from most editions'; most are 2020's.
- **Against activity** (landings and logbook, 2004-2021):
  - 445 vessel-years with fishing while the hull is in neither edition around them;
  - 14 after a listed deregistration, 4 before a listed registration;
  - 536 vessel-years with landings on days no licence was valid, and 575 landing from Danish seine or lumpfish nets
    without that licence (to 2020-07-22, where kvoti's licences end).

## Personal data

The evidence table carries owners' and operators' names and addresses, as public sources print them, and no kennitala.
The discrepancy table carries owners' names where they disagree. Both stay under `$FISHYDATA`; the docs page shows
counts only (decision 130, plan 028 §7).

## Not done

- **Not targets.** The scripts carried `# Side: preprocessing` and waited on plan 028 ask a. They are `once` targets
  since decision 132, built there the same day.
- **The real store.** It has none of these outputs until the build.
- **AIS** (plan 028 §5.4) and changes the editions do not show come with step 5, which needs asks a and f.
