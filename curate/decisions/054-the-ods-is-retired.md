# 054 - The manual ODS is retired

**Status:** done 2026-09-30 (plan 009 phase 5). Follows 053.

`reference/vessels/ais_key_cascade.R` no longer reads `stk_mobile_match-and-duals.ods`: no `manuals` step (499 rows of it before), no ODS-made
period splits, no ODS-supplied vids. Its columns stay, empty, so the later cascade steps fill from their own evidence. The file was **moved, not
deleted**, to `$FISHYDATA/archive/retired_2026-09-30/stk_mobile_match-and-duals.ods` (22,398 bytes); the maintainer deletes it when satisfied.

What replaced it: the segment table places every stretch on evidence; the foreign matches live in `overrides/stk_foreign_mid_vid.csv` (352 rows,
extracted once, unchanged), and the segment table takes those mids into scope itself (they used to enter through the ODS rows in the key).

**What moved** (audit chain and segment table rebuilt without the ODS, compared with the table before): the cascade has 19,163 rows (19,234) and
no `manuals`; the segment table 3,154 segments (3,175), 15 more mids in scope. **0.104 % of mid-days change vid (20,828 of 19,946,100; 27 mids)**,
almost all of them a stretch that was "a person decides" or borrowed from a neighbour and is now filled by the cascade's own vid or by W1 evidence that
an ODS `drop` row had hidden (mids 108963 -> 2835 and 129801 -> 7830, both physical). Stretches awaiting a person: 92,683 -> 88,744 pings. Foreign
vessels: the cascade reaches the override's vid on its own in 318 of 344 segments (25 by landings or the override itself; one differs, mid 112543, where
the physical track decided 2730 before, decision 048). A foreign match that agrees with the override keeps the label `foreign: kept override`.
Mid 143852 now reads 1511 (physical), the vid the key named; decision 052 had left it for a person.

**Not rebuilt:** the key changed slightly (19,357 rows), so the targets downstream of `vessel_ais_key` are outdated again (`stk`, `ais_ping_union`, ...).
The union costs about 1.5 hours; the difference is 0.1 % of mid-days, so running it is the maintainer's call, not a dependency of anything else.
