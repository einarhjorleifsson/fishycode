# 051 - The three segments that still disagreed with the annual register

**Status:** done 2026-09-30. Follows 050. The maintainer's rule: the annual register is evidence, not a judge - where other data say
otherwise it is overwritten (and so is the registry, which is not 100 % either).

Two mids, three segments, all physically confirmed. Read on the vid's own AIS against the mid's moving pings (within 5 min, within 2 km;
score = hits / opportunities, by year), plus landings and the mids' own activity:

- **Mid 103750 (two segments, 2011-2019, 54,498 pings; later merged into one 2011-2028 stretch): vid 2022.** Vid 2022's own AIS (sparse: 4-262
  opportunities a year, 2014-2024) is within 2 km of the mid in **100 %** of its opportunities every year, median 0.0-0.3 km. The vids the
  table had (7487, 2487) match only part of the time - 7487 0.18-0.92 a year, 2487 0.00-0.87 (0 in 2020-2023) - companions that
  travel with it, not the vessel. The month threshold (>= 3 months at score >= .8) let a denser companion win; the key, the register
  (TFJQ, 2007-2022, one holder) and the registry agree with 2022. A vid that matches in *every* opportunity outranks ones that match
  in some; this is now the reading, recorded as a reviewed row rather than a rule (one case; a rule wants more).
- **Mid 101079 (from 2021-05-27, 12,024 pings): vid 7126.** 7126's AIS is within 2 km in 91-95 % of opportunities each year 2021-2024
  (median 0.3-0.7 km), its landings match the mid's harbour calls at 1.00 each year 2021-2025, and the registry gives TFAH to 7126. Vid 1988
  (the register's 2022 row for TFAH) is heard only in 2021, median 179 km from the mid. Both hulls' old mids (103593 for 7126, 100799
  for 1988) stop transmitting in 2021, and 101079 - formerly 1270's - takes over 7126. The register's single 2022 row is overwritten; it is
  one of the ~1 % of rows whose vid or call sign disagrees with the registry.

Mechanism: `overrides/ais_key_segments_reviewed.csv` (mid, d1, d2, vid, reviewed_date, reason), read by `ais_key_segments.R` as an
**input**: a segment lying >= 50 % inside a row takes its vid, `source = "reviewed"`, grade A; `annual_disagrees` ignores reviewed
segments. After the rebuild the register reaches 519 segments and none disagrees (two rest on a reviewed row: 101079 overwrites the register, 103750 agrees with it).
