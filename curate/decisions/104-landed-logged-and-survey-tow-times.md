# 104 — Landed against logged weight, and the survey's tows as ground truth for tow times

*2026-10-14. Measured by Claude (AI-assisted) on the maintainer's go. Closes TODO 60.*

## Landed against logged weight (`check_landed_logged`)

A difference between logbook and landing is not an error. The logbook is the skipper's estimate at sea, and the
landing is weighed. The difference is of interest where it is systematic (maintainer). The check reports, per year,
logbook system and species, the trips whose landing is linked and whose logged weight is at least 100 kg: the ratio
of the totals, and the trips' median and 10th and 90th percentiles. Read on 2008-2025:

- **Demersal species shift around 2020**, when the electronic logbook took over. Landed over logged was 0.92-0.98
  before, and 1.02-1.17 in 2020-2025. Cod went from 0.96-0.97 to 1.04, haddock from 0.92-0.94 to 1.09, and species 6
  reached 1.17.
- **Herring (30) rises:** 1.08, then 1.44, then 2.11, with a 90th percentile of 13.6 in 2020-2025.
- **The other pelagic species are near 1:** capelin 0.94-0.96, blue whiting about 1.0, mackerel about 0.99.
- **Pelagic transfers:**
  - Pelagic trips (30-36) whose landed weight is far from their logged come in pairs: 2,548 trip-species landed
    2-300 times what they logged, and 1,032 logged more than twice what they landed.
  - That is transhipment, expected only in the pelagic fisheries (maintainer).
  - A per-trip raise factor puts one vessel's catch on another's fixes there. The `raise_factor` is kept, as is.
  - A flag for these trips is proposed and not built.
- **No tonnes for kilograms:** only 8 pelagic trip-species sit near ×1,000.

## The survey's tows as ground truth (TODO 60; `check_survey_tow_times`)

- **The data:** MFRI's public spring-survey tows, `dump/survey/smb_stations.R`. They run 1990-2019; 7,601 overlap the
  AIS, on 9 vessels: the research vessels and the hired trawlers.
  - The csv that ramb's `rb_read_survey_stations_mfri()` reads is gone from the FTP site.
  - The DATRAS haul file there holds the other countries' surveys (`dump/survey/datras_hh.R`, kept as raw).
  - The autumn survey is not published.
- **The method:** each tow is paired with the vessel's towing stretch, as decision 092 pairs commercial tows.
- **Results:**

  | period | fix spacing | paired | start within 5 / 10 / 15 min | end within 5 / 10 / 15 min | median offset start / end |
  |---|---|---|---|---|---|
  | 2008-2012 | 10 min | 85.4 % | 37.7 / 77.9 / 87.8 % | 27.5 / 78.6 / 88.9 % | +3.9 / -2.5 min |
  | 2013-2019 | 4 min | 94.3 % | 50.4 / 80.7 / 90.0 % | 39.1 / 82.4 / 92.8 % | -2.7 / +3.7 min |

- **The track places a tow's boundaries to about ±10 minutes.** Since 2013 it is biased outward by about 3 minutes on
  each side: the ±10 min speed window smears the edges. That bias is systematic and could be corrected.
- **Against commercial logbooks the same method agrees far less** (start within 15 min for 55-60 % of bottom-trawl tows,
  decision 090). Most of those larger differences are therefore the commercial logbooks' times, not the track's.
- **What this unblocks:** plan 013 item 10 (`rb_reconcile_time()`). Where the fixes are dense and the tow pairs, the
  track's boundary can stand, with a tolerance of about 10-15 minutes.
- **Not independent for the logbook:** 373 of these tows are also in the hired trawlers' logbooks, with times equal
  to the survey's for 63 % of starts and 54 % of ends. They are the same bridge entry, so they do not check the
  logbook's own accuracy.
