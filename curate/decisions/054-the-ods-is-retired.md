# 054 - The manual ODS is retired

**Status:** done 2026-09-30 (plan 009 phase 5). Follows 053.

`reference/vessels/ais_key_cascade.R` no longer reads `stk_mobile_match-and-duals.ods`: no `manuals` step (499 rows of it before), no ODS-made
period splits, no ODS-supplied vids. Its columns stay, empty, so the later cascade steps fill from their own evidence. The file was **moved, not
deleted**, to `$FISHYDATA/archive/retired_2026-09-30/stk_mobile_match-and-duals.ods` (22,398 bytes); the maintainer has decided to leave it there.

What replaced it: the segment table places every stretch on evidence; the foreign matches live in `overrides/stk_foreign_mid_vid.csv` (352 rows,
extracted once, unchanged), and the segment table takes those mids into scope itself (they used to enter through the ODS rows in the key).

**What moved** (audit chain and segment table rebuilt without the ODS, compared with the table before): the cascade has 19,163 rows (19,234) and
no `manuals`; the segment table 3,154 segments (3,175), 15 more mids in scope. **0.104 % of mid-days change vid (20,828 of 19,946,100; 27 mids)**,
almost all of them a stretch that was "a person decides" or borrowed from a neighbour and is now filled by the cascade's own vid or by W1 evidence that
an ODS `drop` row had hidden (mids 108963 -> 2835 and 129801 -> 7830, both physical). Stretches awaiting a person: 92,683 -> 88,744 pings. Foreign
vessels: the cascade reaches the override's vid on its own in 318 of 344 segments (25 by landings or the override itself; one differs, mid 112543, where
the physical track decided 2730 before, decision 048). A foreign match that agrees with the override keeps the label `foreign: kept override`.
Mid 143852 now reads 1511 (physical), the vid the key named; decision 052 had left it for a person.

**Rebuilt (same day):** the targets downstream of the key were then rebuilt end to end on the key built WITHOUT the ODS (nothing in the chain reads the ODS any more) (union 12:0x-12:2x at ~2 min a year - the
slow 5-min years that morning were machine pressure, not the code; `stk` 1 m, `ais_ping_tag` 2 m 42 s, `ais_ping_clean` 6 m 10 s with no year skipped, `ais_trip`
8 m 43 s, `trip_voyage` under 1 s, `logbook_sensor_gps` 9 m 04 s). A battery warning stopped the run once between targets (a controlled kill, `ais_trip` rerun from
scratch); nothing outdated afterwards. Verified: STK staging 181,743,254 rows against the segment table's 181,743,251 pings on a vid (3 apart); no gear-device
mid in it; union -> tagged -> clean 543.73 M -> 543.73 M -> 540.53 M (0.59 % dropped); mids 103750 -> 2022, 101280 -> 1849, 146259 -> 3037, 143852 -> 1511 and
108963 -> 2835 are in staging with the intended vids; 720,247 trips for 2,763 vids. The archived ODS is kept where it is, by the maintainer's decision (2026-09-30): nothing reads it, and it is not to be deleted.
