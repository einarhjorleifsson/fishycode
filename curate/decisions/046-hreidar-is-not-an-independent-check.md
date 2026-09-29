# 046 — Hreidar's annual table is not an independent check on the mid→vid match, but it exposes a gap in the lifetime check

*2026-09-29. Review of `vessel_ais_key` against `HREIDAR_Islensk_skip.xlsx`. Analysis
by Claude (AI-assisted), run against `$FISHYDATA` as it stands; nothing was written under
it. Scratch scripts were not kept — the numbers below are the record.*

## Finding 1 — the workbook is already in the pipeline

`raw/external/hreidar/data-raw/HREIDAR_Islensk_skip.xlsx` is byte-identical (md5
`485ad2cf…`) to `~/stasi/hreidar/data-raw/`, and `reference/vessels/registry.R:139`
already reads it: `yh1`/`yh2` in `vessel.parquet` **are** min/max of its `Ár` column.
Measured: of 2,858 Icelandic vids in both, `h2 == yh2` for 99.97 %. So lifetime evidence
from Hreidar cannot corroborate lifetime evidence from the registry — it is the same
column. Nothing needs importing from `~/stasi/hreidar`.

The workbook ends in 2021 and carries a `9999` placeholder row per unused number
(1,214), which `registry.R` already maps to `NA`.

## Finding 2 — `registry.R` keys on the wrong column for pre-2007 rows

It uses `Skskr.nr.` (`skskr_nr`); Hreidar's own key is `NR`. They agree from 2007 on
(1 row differs) but not before: 11,162 rows differ, `skskr_nr` is blank on 20,200, and in
older blocks it **auto-increments per year on one hull** (Gullfinnur, `NR` 953:
`skskr_nr` 954, 955, 956, 957 across 1959–62). Effect: 164 vids have `yh1`/`yh2`
disagreeing with the `NR`-keyed range by more than a year (e.g. vid 1023 FAXABORG
`yh1` 1933, `NR` says 1967 — 1933 belongs to another hull's block). All 164 predate the
STK era, so **no mid→vid assignment is affected today**; it is a `vessel.parquet` defect
to repair separately. **Open, not fixed here.**

## Finding 3 — the existing lifetime check only catches mids *wholly* outside a hull's life

`ais_key.R`'s `lifetime_conflict` fires when the mobile-id is active wholly outside
`[yh1, yh2]`. A mid that *starts before the hull was born* or *runs on after it left the
register* is not flagged. Measured per mid-vid row, ping-years 2007–2021, ±1 year
tolerance, threshold ≥1,000 pings or ≥5 %: **29 of 1,207** Icelandic-vid rows
(869,081 of 115.2 M pings, 0.75 %); the other 1,178 rows sit entirely inside the hull's
life. Of the 29: 7 already `lifetime_conflict`, 9 already in
`overrides/ais_key_callsign_reuse_reviewed.csv`, 5 in the reused-call-sign check, 9 named
in decisions 020/044/045. **10 are known nowhere** (304,357 pings):

| mid | glid | assigned vid | out-of-life pings | direction | other holder of the call sign (registry) |
|---|---|---|---|---|---|
| 100137 | TFGR | 2847 | 100,042 | before hull's 2013 birth | — none in `vessel.parquet` |
| 101967 | TFCR | 2892 | 102,015 | before hull's 2017 birth | 2429 ÍSAFOLD (2000–03) |
| 103072 | TFEL | 2219 | 39,973 | after hull left 2013 | 2943 SIF (2018–21) |
| 101760 | TFKG | 2626 | 26,509 | after hull left 2019 | — (939 MAGNÚS ended 1990) |
| 100290 | TFFS | 1359 | 19,093 | after hull left 2007 | 2914 KARLSEY (2015–21) |
| 101126 | 2329 | 2329 | 6,866 | after hull left 2007 | — |
| 101779 | TFAJ | 2842 | 3,632 | before 2017 | 1567 HÓLMATINDUR (ended 2001) |
| 101146 | 168 | 168 | 3,508 | after hull left 2013 | — |
| 101115 | TMP_TFOP | 1807 | 1,528 | after hull left 2009 | — |
| 100161 | 250 | 250 | 1,191 | after hull left 2008 | — |

The call-sign holders in the last column are candidates, **not** conclusions: a
call-sign match with a plausible date is exactly the guess `AGENTS.md` says not to
promote. They belong in the decision-045 track-correlation queue, not in `overrides/`.
`TFAJ` is decision 021's case (correctly resolved to 2842 for the modern era; the
pre-2017 pings are the residue). The 19 rows whose *whole* window falls outside Hreidar
(12 negative-vid `manuals` rows absent from Hreidar entirely, 7 after the hull's end) are
the existing `negative_vid` / `outside_vessel_lifetime` checks, unchanged.

## Finding 4 — Hreidar's per-year `Staður`+`Númer` (uid) is not a usable check

The one unused Hreidar signal that is per-year is the local identifier. Tested two
ways, both **negative**:

- 24 assigned rows carry a uid-shaped STK `loid`/`glid`. 8 agree with Hreidar's uid for
  that vid in the ping years; 16 do not. For the 12 with a call sign in the registry, the
  registry call sign **equals** the STK `glid` every time — so the uid field is stale
  free text (a vessel's uid changes when it changes harbour), not evidence against the
  vid. A uid mismatch must not be read as a wrong match.
- The reverse direction (unmatched mids → which hull held that uid that year): 217
  unmatched-or-non-vessel rows have a uid-shaped field; **0** hit a Hreidar
  (uid, year) pair. They are not Icelandic hulls.

## Finding 5 — completeness: Hreidar corroborates the registry's "not in AIS" list, and is consistent with 044/045

187 Icelandic vids alive in Hreidar at ≥2007 have no row in the key (80 ≥ 15 m, 48
≥ 24 m). The largest are not vessels that should transmit (floating docks 2247/2260,
museum/training ships 159/229) or are gone before STK (HAUKUR 1265, BEITIR 226 ended
2007). The ones that matter are consistent with 045's finding, not new: **DÍSA (2815) and
PÁLL PÁLSSON (2904)** appear here as large, live, key-less hulls — exactly the ones whose
call signs (TFBR, TFPH) 045 shows are mis-keyed to an older holder. Hreidar cannot
add MMSI or call sign, so it cannot pick the mid for the others.

## What this changes

Nothing is reassigned. Hreidar's lasting value here is small: it is a **second read of the
registry's year range**, useful only for the whole-window `outside_vessel_lifetime`
question and for the STK-era existence of hulls; it cannot arbitrate a call-sign reuse
because it carries no call sign and no MMSI.

## Next steps (recommended, not done)

1. **Done 2026-09-29.** `curate/checks/ais_key_registry.R` check 3b,
   `partly_outside_vessel_lifetime`: mid ping-years (from `raw/ais/stk/trail`, 2007-2021)
   against the hull's `[yh1, yh2]`, ±1 y, `yh2` trusted only below the 2021 horizon,
   ≥1,000 pings or ≥5 % with a 100-ping floor, rows already `lifetime_conflict` and
   foreign vids excluded. Dry-run (write redirected to scratch, `curated/check/` not
   touched): **26 rows, 2,081,354 pings**, including all 10 unrecorded rows above; the
   rest are the known 044/045 cases plus a few new small ones on vids 6330, 6473, 7519,
   7551. Runs in ~3 s. `curated/check/ais_key_registry.parquet` is **stale until the
   `check_ais_key_registry` target is next built**; the target does not track the trail,
   so it will not rebuild on new pings alone.
2. Send the 10 to the decision-045 track-correlation procedure before any override.
3. Repair `registry.R` to key on `NR` (or ignore `skskr_nr` where it increments),
   with the 164 vids as the regression set. Independent of the STK work.

## Amended 2026-09-29 — what decision 047 found about Finding 3

Kept as written above; the reasoning that was wrong is named here, per this directory's
revision convention.

- **"Before the hull's birth" is not "reused call sign".** Finding 3 read the two rows for
  mids 100137 (`glid` TFGR, key vid 2847) and 101967 (`glid` TFCR, key vid 2892) as a call
  sign reused by a later hull. Decision 047's other-provider check (W1) shows that in 2013,
  the only year it can see, the transponder on those mids was co-located with a *different*
  hull whose call sign differs from the mid's `glid` (vids 1136 and 2730). That is a
  device/identity mismatch, not reuse. Their 2007–2012 pings are untested: no independent
  witness reaches them.
- **The candidate holders in the table's last column** were call-sign matches with a plausible
  date — exactly the guess this decision itself warned against — and should not be read as
  findings. For mids 100137, 101967 and the other rows the reviewed route is decision 047 §3
  and the split candidates it lists, not this table.
- **The partial-overlap check itself stands** (`partly_outside_vessel_lifetime`,
  `curate/checks/ais_key_registry.R`): it finds the right rows; only the explanation offered
  for two of them was wrong.

