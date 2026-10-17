# 118 — TODO 18 and 48 dropped; 8, 22, 39 and 67 folded into other items; 15, 34 and 68 trimmed

*2026-10-17. Written by Claude (AI-assisted). The maintainer approved the whole list after a review of every
remaining item against the code, the data and the records. Measured read-only; nothing was built.*

## Dropped

- **TODO 48, the voyage step's speed.** The rebuild of 2026-10-16 ran `ais_voyage` in 914 s (15.2 min; `tar_meta()`),
  so the item's check (10 min at most) is not met. It is dropped anyway, because compute is free and tokens are not
  (the maintainer's working rule). It was 51 min after the ramb port and 13.8–14.1 min in the rebuilds of decisions 086
  and 089. It was not profiled further.
- **TODO 18, behavioural fishing windows.** The maintainer parked it on 2026-10-14 (plan 004 §8: the ceiling is about
  +5 % of static fishing fixes). Plan 004 keeps it, and its row in `curate/plans/README.md` now says parked instead of
  "proposal". It reopens when a delivery needs static-gear effort that precise.

## Folded into another item

| from | into | why |
|---|---|---|
| 8, the old trail kept for the datacall | 27b | 8 only held the 2025 trail until 27b's comparison. 27b's check now also asks that no directory under `~/stasi/fishydata_2024-2026` exceed 1 GB |
| 22, foreign pings never reach the voyages | 65 | plan 017 replaced 22's `external_id` with a vid (200000 + n) and moved its steps to plan 021. Its §7 restates 22's check on vid. The joins that drop a ping with no vid are still there (`sources/stk/convert.R:31`, `curate/ais_ping_union.R:62` and `:78`) |
| 39, mid 108982's boundary | 25 | a boundary in the STK key, fixed only at the key redo |
| 67, the divers 8008 and 8009 | 24 | they are 2 of 24's 107 vessels with no track, and 24's check now names them |

**TODO 25 is now the key redo** (`once` project). Seven reviews waited on the same redo, spread over five items and
four plans: the audit (plan 009), coverage, mid 108982, SKB (TODO 63, plan 016 §5), the archive (plan 016 §4 step 7),
the foreign hulls and reused call signs (plan 021 step 7, TODO 65) and STK mined (plan 022 §3, point 10). One item
lists them and carries one check. TODOs 63 and 65 point to it.

Lines that were dropped from 25 because decision 047 already holds them: mid 101444 = vid 1421 (TFGA),
`ais_key_vessel_recall`'s 0.3 % and `ais_key_twins`. One line that no other record holds, kept here as it stood
(not validated, not pursued): on the uncleaned 2019 union, implied-speed jumps over 50 kn are 0.09 % of consecutive
pairs for stk, 0.04 % for astdB and 0.02 % for astd.

## Trimmed

- **34:** ask (2) was answered by decision 093 (the declared ranges stay; `fishing` tests the ±10 min median speed).
  Ask (1) is left (small trawlers near the coast, and a coastline polygon), and the check now names the last-haul
  question that the item had left outside it.
- **68:** the stk catalogue it restated is in plan 022's appendix (`SYNC_EXCLUDE` is in decision 109 and
  `dump/oracle/sync.sh`). What is left is `tilk_stk_allt` against the voyages, plan 022 §4.
- **15:** a paragraph that repeated the first is gone. The maintainer's rule that the 3-vessel minimum per cell applies
  only to ICES deliveries (recorded 2026-10-02) is now in plan 001 §3, as a partial answer. The minimum cell and the
  allowlist of tables are still asked.
- **27b:** its status named the build of 2026-09-30. The trail was rebuilt on 2026-10-16 (decision 112).
