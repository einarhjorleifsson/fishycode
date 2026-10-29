# 051 — Whole weight across species, states, periods and databases: one factor table for the logbooks and the landings

**status:** proposal — written 2026-10-29 at the maintainer's request; nothing built · **measured** (§1), by Claude the
same day, read-only and in aggregates only: `agf.aflagrunnur`'s three weights per landing row (2007-2026),
`kvoti.lods_slaegt`'s two (1992-2026), the merged logbook's `catch_whole` on its gutted rows, plan 050's Nephrops tails;
the study of 2026-10-21 (`$FISHYDATA/archive/2026-10-xml-oracle-map/`, TODO 114) · **assumed** (§2): where the factors
come from, what the other states are, and how lumpfish is logged · **see:** TODO 114, TODO 115 (plan 037 phase 1),
TODO 152, plan 036, plan 050 step 5 (branch `plan-050-step5-tails`), decision 066, `R/whole_weight.R`

Drafted with AI assistance (Claude) on 2026-10-29; a person has not yet checked it.

The maintainer, 2026-10-29, when plan 050's Nephrops tails were built: "the whole weight (un-gutted) vs gutted weight
is a big issue on its own … the convertion factors may have changed over time. this includes all species, the landings
databasis and the logbook databases. and then how lumpfish roe barrel weight is converted to ungutted weight! wander if
we need to take a broader review on that rather than doing some quickfix here, just on nephrops."

## 1. What is measured

**The landings carry their factor on every row.** `agf.aflagrunnur` (2007-2026) holds the state (`astand`), the weight
as landed (`magn`), and its gutted (`magn_slaegt`) and ungutted (`magn_oslaegt`) equivalents. Ungutted over landed is
the factor applied, row by row. The states by rows: 0 ungutted (3.45 M), 1 gutted (1.58 M), 4 (98 k), 27 (88 k, 13.9 Mt
at factor 1), 6 roe (79 k), 2 (35 k), and some 40 more product states. `kvoti.lods_slaegt` (1992-2026) holds `magn` and
`magn_oslaegt` by species and `gerd`.

**Gutted to ungutted, by species** (agf, the value on 80-91 % of a species' gutted rows; the rest are the same value
rounded):

| factor | species (agf code) |
|---|---|
| 1.1905 | cod 1, haddock 2, saithe 3 |
| 1.25 | whiting 4, ling 6, blue ling 7, Greenland shark 17, porbeagle 18 |
| 1.1111 | tusk 8, Atlantic wolffish 9, spotted wolffish 13, monkfish 14, rays 12 and 15 |
| 1.087 | halibut 21, Greenland halibut 22, plaice 23, lemon sole 24, witch 25, megrim 26, dab 27, long rough dab 28 |
| 1.0638 | redfish 5 (a few rows; nearly all redfish is landed ungutted) |

**The factor changed over time.** In `lods_slaegt`, cod, haddock and saithe take 1.25 from 1992 to 1997 and 1.1905
from 1997 on. Greenland halibut changes from 1.09 to 1.087 in 1997. Since 2007 agf's gutted factors hold, but for
rounding (halibut 1.0867 → 1.0870 in 2012).

**Roe** (agf state 6). Lumpfish roe (grásleppa, 951) becomes ungutted lumpfish at 3.030 in 2008-2009, 3.788 in
2010-2012 and 3.401 from 2013. That is three factors in six years, on 1.7-2.2 kt of roe a year before 2013. Cod,
haddock, saithe and ling roe take 0, so roe adds no fish. Species 31's roe takes 1.0.

**Other states have their own factors**, e.g. redfish state 2 1.8182, saithe state 13 2.6455 (with other values),
Greenland halibut state 17 1.5097 and 1.087, mackerel state 2 1.5152. Their names (heads off, fillets, …) are not read
yet.

**The logbook uses one factor for every species.** On its gutted rows with a whole weight, fs_afladagbok's
`catch_whole` is the gutted weight × 1.25 for cod, haddock, saithe, ling, tusk, wolffish, Greenland halibut and
plaice. afli stores round(gutted × 1.25) as its catch, for every species and without the state (TODO 114, from the sent
messages). `calc_whole_weight()` (`R/whole_weight.R`) takes ÷ 0.8, the same. So for the same gutted fish, the logbook's
whole weight is above the landings' by:

- 5 % for cod, haddock and saithe (1.25 / 1.1905), since 1997; before, the two agreed;
- 12.5 % for tusk, wolffish and monkfish (1.25 / 1.1111);
- 15 % for the flatfish and Greenland halibut (1.25 / 1.087);
- 0 for whiting, ling and blue ling.

**States the logbooks do not name.** Nephrops tails under the whole-animal code: afli's in-house edits converted
17,969 catch items × 3.3 in 2007-2018 (plan 037). Four vessels log tails since 2019, and vid 1645 also in 2004-2006
(plan 050 §6, held on its branch). adb's app names the tails `GUTT`.

**The curated landings keep one weight.** `curated/landing/catch.parquet` carries `catch`, the ungutted equivalent
(equal to `lods_oslaegt` year by year for Nephrops, plan 050 §1). Its `catch_gutted` is empty, and the state and the
weight as landed are not kept.

## 2. What is assumed

- That agf's and lods's ungutted weight is Fiskistofa's computation from the factor in force on the day, not a
  weighing. The official factor lists (the regulations on conversion factors) are not yet read.
- What states 2, 4, 13, 17, 27 and the rest are. agf's views name only 0 (óslægt), 1 (slægt) and 6 (hrogn).
- How the logbooks record lumpfish: roe in barrels, roe in kg, or fish, by period and source; and a barrel's
  weight. Not measured.
- That afli's sent messages hold the logged weight and its state on every electronic item (TODO 114). Paper records
  hold what the paper held.

## 3. The steps

1. **The landings' factors, all of them.** Per species, state and day, from agf (2007 on) and lods (1992 on), each a
   period with `from` and `to`. Each factor is matched to the regulation where one is found (ask b), basis
   `recorded`, and otherwise `derived` from the rows. The state codes are named from agf's code tables. Read-only, archived
   under `$FISHYDATA/archive/2026-10-whole-weight/`.
2. **The logbooks' side.** Per source and period: the factor each one stored (afli × 1.25, fs_afladagbok, adb), the
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
unaffected.

## 5. Asks

- a. Which factor the product's whole weight takes: the landings' factor of the day (proposed, so logged and landed
  whole weights of the same gutted fish agree and kilograms in equal kilograms out), or the logbook's own × 1.25 as
  stored. The other would be kept beside it.
- b. Where the official factor lists are: Fiskistofa's regulations, by date, for the witness column.
- c. Lumpfish: how the logbooks and the older landings record it (roe barrels, roe kg or fish), in which periods, and
  a barrel's weight.
- d. Scope: every product state (some 40), or the main ones (ungutted, gutted, roe, tails), with the rest listed.
