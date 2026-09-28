# 045 — Track correlation resolves most of decision 044's 18 candidates

*2026-09-28. Extends decision 044 and `curate/corrections/ais_key_callsign_reuse.yml`.*

## Method

Decision 044 found 18 vids with real STK mobile-ids sharing their call sign,
overlapping their independent activity window, never assigned to them - but
only bucketed by whether the *current holder* has any evidence at all (ghost)
or genuinely overlapping evidence (ambiguous). This session tested a stronger
signal: for each disputed mid, match every STK ping against the nearest-in-time
(≤6h) position from each candidate vid's own other-provider (ASTD/GFW/EMODnet)
track, and compute the great-circle distance. Since STK and the other providers
are independent receivers hearing the same physical transponder, a true match
sits at metres-to-hundreds-of-metres; a wrong vid has no comparably-timed
position at all, or sits tens of kilometres off.

This REPORTS - it does not reassign. Per `AGENTS.md`'s cycle rule, a
conclusion here is a proposal for the maintainer, entering only through
`overrides/`, the same way vid 3047/2605/3045 were patched originally.

## Results

**Clean chronological handovers** (both sides tight, <1 km typically) that
`ais_key.R`'s flat, timeless cs-lookup currently sends entirely to one holder:

| cs | mid | era 1 (confirmed) | era 2 (confirmed) | currently keyed to |
|---|---|---|---|---|
| TFBR | 101759 | DÍSA/2815, 2013-22 | HILDUR/3047, 2024-26 | HÓLMBERG/1473 (zero evidence) |
| TFIU | 100111 | GRETTIR STERKI/2975, 2019-20 | SIGURVIN/3024, 2023-26 | ÁLFTAFELL/1195 (zero evidence) |
| TFSL | 100645 | HANNES Þ. HAFSTEIN/2593, 2014-23 | BJÖRG/3049, 2024-26 | vid 2188 (zero evidence) |
| TFBK | 103094 | BALDUR/2727, 2013-14 (9.3/6.6 km) | HERJÓLFUR/2941, 2019-26 (0.3-0.6 km) | all keyed to 2727 |
| TFNE | 101350 | ÖRVAR/2197, 2013-14 (4-5 km) | OCEAN SPIRIT/2916, 2016-18 (0.3-0.5 km) | all keyed to 2197 |
| TFFV | 100099 | PERLA/1402, 2013-15 (<0.1 km) | TEISTA/2980, 2019-25 (~0.5 km) | all keyed to 1402 |
| TFJG | 101334 | ENGEY/2889, 2017-19 | INGIBJÖRG/3055, 2025-26 | all keyed to 2889 |

**Pure ghost, confirmed** (target vid matches tightly; current holder has zero
other-provider evidence at any time): TFSY→THE LADY/2310, TFGY→ARCTIC
ROSE/3034, TFTH→SMYRILL/2798. TFHW→KEILIR/2946 is the same shape but the
holder (GRETTIR/2523) has 5 total pings of "evidence" (2 conflicting, n<4
each) - too thin to call a real handover; treat as ghost, not overlap.

**Confirms a case decision 044 flagged as absent from the key entirely**:
TFGA/mid 101444 (TÝR/1421) - 2014 pings match TÝR's own track at 0.36 km.
Supports adding it, not just noting the absence.

**Genuinely unresolved by this method - not guessed at**:
- TFCQ/GULLTOPPUR(2931): almost all pings predate 2013, before any
  other-provider coverage exists to test against either candidate.
- TFEL/SIF(2943): confirmed 2018-24, but 2025-26 (15,825 pings) match
  *neither* SIF nor the prior holder (SEIGUR/2219) - a third holder may exist
  in that period, untested here.

**An anomaly, flagged not explained**: TFRA (ÓÐINN's own call sign) is
currently keyed to vid 1511 - whose own registered call sign is `TFRK`, a
different sign entirely - with weak match quality (3-48 km) against `TFRA`,
while ÓÐINN (159) matches its own call sign tightly from 2022 on. Something in
`ais_key.R`'s cascade routed this through a non-cs path; that logic was not
traced here and nothing is asserted about why.

## Registry corroboration, checked separately - and the anomaly is a confirmed bug

`raw/vessels/vessel_v.parquet` (Fiskistofa's registry dump) is **one row per
`vessel_id`** (7,044 rows, 7,044 distinct ids) - a live snapshot with a
`status` field (`Á aðalskipaskrá` active / `Afmáð` deregistered) and
`valid_from` meaning "this record's last change," not a call-sign-history
table. It cannot date the handovers independently of the AIS track
correlation above. It does independently confirm every "era 2" vid in the
table (HERJÓLFUR, HILDUR, TEISTA, SIGURVIN, INGIBJÖRG, OCEAN SPIRIT, BJÖRG)
as the call sign's **currently active** registered holder, and every earlier-
era vid plus every wrongly-keyed current holder as **`Afmáð`**.

**The TFRA anomaly is now a confirmed bug, not just weak evidence**: the
registry's own row for vid 1511 gives its call sign as `TFRK` - not `TFRA` -
while vid 159 (ÓÐINN) is registry-confirmed active on `TFRA` itself.
`vessel_ais_key.parquet` keys mid 101892 to a vid whose registered call sign
is a completely different string; this is not a stale-registry judgement
call the way the ghost/handover cases are.

## What was not done

No vid was reassigned, no `overrides/` row written, `ais_key.R` untouched.
This is evidence for the maintainer to accept or reject case by case, same
shape as the original 3-case patch.
