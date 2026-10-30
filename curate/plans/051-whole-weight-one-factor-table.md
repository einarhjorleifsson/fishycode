# 051 — Whole weight across species, states, periods and databases: one factor table for the logbooks and the landings

**status:** partly built — written 2026-10-29 at the maintainer's request; steps 1-2 measured the same day; asks a, d and
e answered by the maintainer on 2026-10-30, as was c's question on afli's lumpfish logbook (TODO 167); b partly
answered from the regulations the same day, and c's confirmations are with HV 2020-33's authors; the factor table built with plan 054's live rebuild on
2026-10-30 (decisions 257, 265), the lumpfish rows provisional; left: ask e's paper era and the authors' answers
(TODO 157) · **measured** (§1), by Claude in two read-only side sessions the same day, in aggregates only and not checked by
a person: the landings' factors (agf, lods and the ask tables) and every logged kilogram's state
(`$FISHYDATA/archive/2026-10-whole-weight/findings.md`); lumpfish roe and barrels against MFRI's reports and afli's
lumpfish logbook (`lumpfish.md` there) · **assumed** (§2): the landings' factors are computed, not weighed; the states
not yet named; one GSI for every year · **see:** TODO 114, TODO 115 (plan 037 phase 1),
TODO 152, plan 036, plan 050 step 5 (branch `plan-050-step5-tails`), decision 066, `R/whole_weight.R`

Drafted with AI assistance (Claude) on 2026-10-29; a person has not yet checked it.

The maintainer, 2026-10-29, when plan 050's Nephrops tails were built: "the whole weight (un-gutted) vs gutted weight
is a big issue on its own … the convertion factors may have changed over time. this includes all species, the landings
databasis and the logbook databases. and then how lumpfish roe barrel weight is converted to ungutted weight! wander if
we need to take a broader review on that rather than doing some quickfix here, just on nephrops."

## 1. What is measured

**Measured** by Claude on 2026-10-29, read-only and in aggregates only, not yet checked by a person
(`$FISHYDATA/archive/2026-10-whole-weight/findings.md`; the draft table `draft_factor_table.parquet`).

**The landings carry their factor, and the system that made them holds it.** agf's ungutted weight is the weight as
landed × a state → gutted factor (`ask.studlar` through `ask.afurdir`, per stock × state × area × period) × a gutted
→ ungutted factor (`ask.veidistofnar_i_oslaegt`, per stock × area × period). The product reproduces 4.59 M of agf's
5.39 M rows. lods' `magn_oslaegt` is its gutted `magn` × `kvoti.lods_i_oslaegt(_vsv)`, on every period. Derived from
the rows, the factors agree with those tables on 71.1 of the 75.5 Mt landed. The ask tables end in 2019, so later
changes are in the rows only, such as Greenland halibut heads and tails from 0 to 1.087 in 2022.

**Gutted → ungutted, by species and period** (Iceland's waters):
- cod, haddock and saithe: 1.25 to 1997-08-31, then 1.1905 (Barents Sea cod 1.18; haddock and saithe off Norway
  1.14 and 1.2 from 2012);
- whiting, ling and blue ling: 1.25;
- tusk, the wolffishes, monkfish and the rays: 1.1111;
- the flatfish, Greenland halibut and halibut included: 1.09 to 1997-08-31, then 1.087;
- redfish: 1.0638 (it is landed ungutted).

**Other states** (agf holds 49 of `ask.astand`'s 65 codes):
- ungutted, whole (27) and capelin residue (95) take 1.0;
- liver (4), heads (7), trimmings (10) and the gadoids' roe (6) take 0;
- Nephrops tails (3, *slitinn*) take **3.25**, 1992-2026;
- lumpfish roe: see below; gutted lumpfish takes 0;
- the products processed at sea, headed and fillets, take a factor per landing: 45 species-state-area keys, 1.27 Mt,
  4-8 values per vessel and year. For example redfish headed 1.74-1.77, saithe skinless bone-in 2.28-2.33, cod
  skinless boneless 2.92-2.97 and Greenland halibut headed and tailed 1.09-1.41 (yearly means).

**The logbooks store 1.25 for every gutted species.** afli stores round(GUTT × 1.25) + UNGU. This holds on 2.59 M and
1.43 M items checked against the sent messages, 2003-2024. fs_afladagbok and adb store `catch_whole` = GUTT × 1.25
to 2022, and almost never after. `calc_whole_weight()` takes ÷ 0.8. They name only GUTT, UNGU and RELE.

Against the landings the logged whole weight of the same gutted fish is:
- 5 % higher for cod, haddock and saithe (since 1997-09-01);
- 12.5 % higher for tusk, the wolffishes and monkfish;
- 15 % higher for the flatfish;
- **63 % lower for lumpfish logged GUTT, which is roe** (logged over landed per trip 0.28-0.30; afli stored it as
  roe × 1.25).

Nephrops tails are logged UNGU or GUTT, or without a state. afli's in-house edit multiplied about half the sent
Nephrops items of 2007-2018 × 3.3, and those sent GUTT × 4.125.

**Every logged kilogram has one outcome.** 50.95 Mt, duplicate twins out: state known 38.6 % (recorded in the source
9.8 %, in afli's sent messages but not carried 28.8 %), reconstructed 0.02 %, and unknown 61.4 %, all of it afli
without a sent message. Of the unknown, 45.0 % of all kilograms are species landed ungutted, for which the state
does not matter; **15.7 % are species landed gutted in part**.

**Lumpfish roe and barrels** (measured by Claude on 2026-10-29, read-only, not yet checked by a person;
`$FISHYDATA/archive/2026-10-whole-weight/lumpfish.md`).
- **The landings take roe → fish at a GSI:** 3.0303 (100/33) to 2010-03-23, 3.7879 (1.25 × 100/33) to 2012-08-31,
  then 3.4014 (100/29.4).
- **MFRI takes roe × 3.4014, × 1.25 for the Directorate's 20 % deduction** on roe landed from 2010-03-24 to 2016.
  This reproduces its published 2008-2019 landings within 8 t a year; its report says from 2008. agf's own ungutted
  lumpfish is 6 % below MFRI's over 2008-2016.
- **The main logbook holds no barrels.** Barrels are in afli's own lumpfish logbook:
  - `grasl_sokn`: roe kg and fish counted per vessel-day, 1977-2016;
  - `grasl_stofn`: barrels per vessel-year, 1990-2010, and the salting stage `teg_verkunar`;
  - `g_sokn` and `g_stofn` are copies of 1982-1991.

  It is the logbook MFRI's reports use: HV 2020-33's Table 1 reproduces from it. `teg_verkunar` 1-4 are the report's
  stages (with all fluid, drained, ready for salting, salted), with factors 1.00, 0.92, 0.77 and 0.81. It shares 7
  vessel-days with the main logbook in 2005-2016, and holds 31-80 % of MFRI's landings a year in 1980-2011.
- **A barrel is 105 kg of salted roe.** MFRI takes it as 0.472 t of ungutted fish (139 kg of fresh roe at a GSI of
  29.4 %; HV 2020-33), in every technical report since June 2020. Earlier figures were 487 kg (2012-2014), 445 kg
  (2015-2016) and 427 kg (2017 to April 2020). The industry's 2020 trial measured 553 kg. Since 2021 the barrel
  years do not enter the advice (KV 2021-1).
- **`afli.grasl_verkun.lysing` is not those factors.** It is 0.92, 0.85, 0.67 and 0.67. mar's former `afli_grasl()`
  took fish = 3.40 × roe / `lysing`, which is 540 kg per logbook barrel against the report's 473. No source documents
  it.

**The curated landings keep one weight.** `curated/landing/catch.parquet` carries `catch`, the ungutted equivalent;
its `catch_gutted` is empty, and the state and the weight as landed are not kept.

## 2. What is assumed

- That agf's and lods's ungutted weight is Fiskistofa's computation from the factor in force on the day, not a
  weighing. The official factor lists (the regulations on conversion factors) are not yet read.
- What states 2, 4, 13, 17, 27 and the rest are. agf's views name only 0 (óslægt), 1 (slægt) and 6 (hrogn).
- That the stage factors of HV 2020-33, means over 1977-2016, hold in every year; and that one GSI of 29.4 % holds for
  every year, month and area.
- That the Directorate's 20 % roe deduction ran from 2010-03-24 to 2016. This is inferred from MFRI's series, not
  stated by the Directorate.
- That afli's sent messages hold the logged weight and its state on every electronic item (TODO 114). Paper records
  hold what the paper held.

## 3. The steps

1. **The landings' factors, all of them** (measured 2026-10-29, §1). Per species, state and day, from agf (2007 on) and lods (1992 on), each a
   period with `from` and `to`. Each factor is matched to the regulation where one is found (ask b), basis
   `recorded`, and otherwise `derived` from the rows. The state codes are named from agf's code tables. Read-only, archived
   under `$FISHYDATA/archive/2026-10-whole-weight/`.
2. **The logbooks' side** (measured 2026-10-29, §1). Per source and period: the factor each one stored (afli × 1.25, fs_afladagbok, adb), the
   states it names (GUTT, UNGU, RELE; tails; roe), and how lumpfish is logged (ask c). Every kilogram of logged catch
   falls in one outcome: state known, state reconstructed (tails), or state unknown.
3. **One factor table** in `reference/`, e.g. `curated/reference/whole_weight_factor.parquet`: species, state,
   `from`, `to`, factor, source (landings or logbook), basis and witness. `reference/` builds it from step 1's
   periods and the regulations, with checks: no overlapping periods, and every species-state the data hold has a
   factor or is listed.
4. **`calc_whole_weight()` reads it** for the state and date of each row, in place of the one ÷ 0.8 (ask a decides
   which factor). A correction that finds the state, like the Nephrops tails, names the state; the factor comes from
   the table. Plan 050 step 5 then joins here: its detection stands, and its 3.3 becomes a row of the table.
5. **The landings keep the state and the weight as landed** beside the ungutted equivalent (the landing adapters and
   `curate/landing.R`), so a factor can be read back and re-applied.
6. **Account** before the rebuild: per species and year, the logbook's whole weight against the landed whole weight,
   before and after, and the kilograms the change moves. Then the rebuild (with plan 050 step 7) and a decision record.

## 4. What it changes

`R/whole_weight.R`, a new reference table and its script in `reference/`, the landing adapters and `curate/landing.R`,
`curate/catch_by_species_station.R`, `products/user_tables.R`, and plan 050 step 5 (folded in). It touches plan 037's
phase 1 ("consumers reading the whole weight by name") and TODO 114 (afli's × 1.25 labelled `recorded`). Those decide
where the logged weight and its state come from, and this plan decides the factor. `curate/ais_catch.R` shares the
logged `catch` and raises it by the landing per trip and species. It is left as it is, and the raised value is
unaffected. Its product is not in the store since 2026-10-29 (decision 241).

## 5. Asks

- a. *Answered (maintainer, 2026-10-30):* the landings' factor of the day, from the step 1 table, so logged and landed
  whole weights of the same gutted fish agree. The logbook's own × 1.25, as stored, is kept beside it. The difference
  is 5-15 % on gutted demersal fish since 1997 and a factor of 2.7 on lumpfish roe.
- b. *Partly answered:* the landings system's factor tables are in the dump (`ask.studlar`,
  `ask.veidistofnar_i_oslaegt`, `kvoti.lods_i_oslaegt(_vsv)`), but they end in 2019. *Read from public sources on
  2026-10-30 by Claude, not checked by a person* (`$FISHYDATA/archive/2026-10-whole-weight/regulations/README.md`):
  - The factors are in each fishing year's regulation on the total allowable catch, in its article on
    slægingarstuðlar. For 2025/2026 that is B nr. 860/2025, article 9.
  - Every factor in that article agrees with the landings' factor: 0.84 for cod, haddock and saithe; 0.92 for the
    flatfish; 0.90 for the wolffishes, tusk and monkfish; 0.80 for ling and blue ling; × 3.25 for Nephrops tails.
  - Lumpfish roe is the exception: × 3.4 in the regulation, against the landings' 3.4014 (100/29.4).
  - Greenland halibut's heads and tails: regulation nr. 1464/2021 amended nr. 468/2013 from 2022-01-01. The tails
    must be kept, and the sum of tails, heads and bodies is the catch recorded. The landings show the change on
    2022-01-16, which is not explained.
  - Left to step 3: each year's regulation from 1997/98 on, to date the periods and make it the `witness`, basis
    `recorded`.
- c. *Answered from the reports and the dump; to be confirmed by MFRI's lumpfish assessors (questions in
  `lumpfish.md` §6).*
  - How lumpfish is logged: kg of fish (UNGU), kg of roe (GUTT), and barrels only in afli's lumpfish logbook.
  - A barrel's weight: 105 kg of salted roe = 0.472 t of ungutted fish by MFRI (553 kg by the 2020 trial).
  - The roe factor by period: as in §1.

  Proposed rows for the table:
  - roe → ungutted as the landings hold it, 3.0303, 3.7879 and 3.4014 (witness `ask.studlar`);
  - beside it MFRI's 4.2517 (1.25 × 100/29.4) for roe landed from 2010-03-24 to 2016 (witness the June 2020 advice
    sheet, basis `derived`);
  - the lumpfish logbook's stage → fresh roe 1.00, 0.92, 0.77 and 0.81, and fresh roe → fish 100/29.4 (witness HV
    2020-33);
  - barrels → fish 0.472 t, held but not applied.

  *Answered (maintainer, 2026-10-30):* afli's lumpfish logbook enters the product as catch, as a logbook source of its
  own at the vessel-day, not raised to the barrels (`lumpfish.md` §7, option B). It is TODO 167, after the table holds
  its rows and HV 2020-33's authors have answered.
- d. *Answered (maintainer, 2026-10-30):* as proposed, out of agf's 49 states and 346 species-state pairs:
  - the table holds periods for ungutted, gutted, whole, roe, liver, heads, tails (Nephrops and Greenland halibut)
    and the lumpfish states;
  - the 45 products processed at sea are held as yearly means with their range, since only the landings use them;
  - the rest are listed.
- e. *Answered (maintainer, 2026-10-30):* yes. afli's weights without a sent message (to 2002, and 85 % of 2003-2010)
  carry no state, and step 6 tests them against the landings per trip and species: were they converted at 1.25, as
  the sent ones were? Each trip goes in one outcome: converted, not converted, or cannot tell.
