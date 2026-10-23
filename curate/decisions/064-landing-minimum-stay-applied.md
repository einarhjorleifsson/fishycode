# 064 — The landing-class minimum stay of 2 h is applied; stays and voyages rebuilt

*2026-10-01. Maintainer's decision on the recommendation of decision 063. Written before the rebuild.*

*Superseded, noted 2026-10-23 from Claude's audit of the decision records (not yet checked by a person): decision 074
drops the harbour class, and decision 077 (step 3b) built one 2 h minimum stay for every harbour. The 2 h of the
landing class became the minimum for all.*

`harbour_stay.R`: `G_LANDING` defaults to 2 h (was 4 h); every harbour whose class that year (`harbour_class`) is `landing` has a 2 h
minimum stay, all others 4 h. Gear and vessel size are not used (decision 063 discussion: landings are the yardstick, not an input;
a size or day-boat rule would trim about 10,000 of the 70,000 added stays, not built). Rebuilt: `harbour_class`, `harbour_stay`,
`ais_trip`, `trip_voyage`, `ais_ping_trail` and the checks that read them.

**Baseline kept:** `$FISHYDATA/archive/pre-landing2h_2026-10-01/{trip,trip_voyage,harbour_stay,voyage_sharing}.parquet` (the 4 h state of
decision 061). Rollback: set `G_LANDING` back to 4 and rebuild.

**Expected from the proxy (063):** about 70,000 more stays, static-gear shared voyages 7.0 → 4.9 %, landings with no stay 41,000 → 28,500.
The measured result is added below.

## Result (rebuilt in 27 min; 9 targets, 0 outdated afterwards)

Checked on the outputs: `ping` has the `ping_clean` row count in all 20 years; `harbour_class` 3,180 rows; vid 2481 in 2011 still 186 voyages.

| | 4 h everywhere (061) | landing 2 h |
|---|---|---|
| stays | 1,468,284 | 1,540,204 (+71,920, +4.9 %) |
| voyages | 1,319,244 | 1,362,624 (+43,380) |
| shared voyages, afli / fs_afladagbok | 4.99 % / 4.23 % | **3.89 % / 3.18 %** |
| shared voyages by gear of the logbook trip: static / towed / jigged | 6.93 / 4.81 / 3.05 % | **4.85 / 3.48 / 2.87 %** |
| logbook trips with a voyage, afli / fs | 97.58 / 95.93 % | 97.56 / 95.92 % |
| arrival harbour = logbook landing harbour, afli / fs | 92.73 / 94.05 % | 93.11 / 94.57 % |
| voyages over 7 days (2008-2025) | 2.39 % | 2.23 % |

The proxy of decision 063 was right: static-gear sharing 6.9 → 4.85 %, as predicted, and the linked share did not fall (the cost of
decision 061 was not repeated). Against the original 23.2 % / 19.3 % (before Phase 4) the shared voyages are now 3.9 % / 3.2 %.
Shared voyages are no longer the biggest remaining defect; the landings with no stay are (about 28,000, of which the 15 m+ static gear
and the towed gear under 15 m remain at 15–17 %, a gap a lower minimum does not close and that has not been diagnosed).
