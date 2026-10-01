# 064 — The landing-class minimum stay of 2 h is applied; stays and voyages rebuilt

*2026-10-01. Maintainer's decision on the recommendation of decision 063. Written before the rebuild.*

`harbour_stay.R`: `G_LANDING` defaults to 2 h (was 4 h); every harbour whose class that year (`harbour_class`) is `landing` has a 2 h
minimum stay, all others 4 h. Gear and vessel size are not used (decision 063 discussion: landings are the yardstick, not an input;
a size or day-boat rule would trim about 10,000 of the 70,000 added stays, not built). Rebuilt: `harbour_class`, `harbour_stay`,
`ais_trip`, `trip_voyage`, `ais_ping_trail` and the checks that read them.

**Baseline kept:** `$FISHYDATA/archive/pre-landing2h_2026-10-01/{trip,trip_voyage,harbour_stay,voyage_sharing}.parquet` (the 4 h state of
decision 061). Rollback: set `G_LANDING` back to 4 and rebuild.

**Expected from the proxy (063):** about 70,000 more stays, static-gear shared voyages 7.0 → 4.9 %, landings with no stay 41,000 → 28,500.
The measured result is added below.
