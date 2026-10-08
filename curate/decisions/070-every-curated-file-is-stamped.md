# 070 — Every file under `curated/` carries provenance stamps; the rebuild exposed a loop in the key

*2026-10-08. Closes TODO item 12. Code by Claude (AI-assisted), commit 1d678ee; measured on `$FISHYDATA` the same day.*

## What was done

- Thirteen pipeline scripts and two hand-run ones (`reference/optiger.R`, `reference/vessels/mmsi.R`) write `curated/`
  through `write_curated()`, or `write_curated_sql()` for `curate/link_trip_voyage.R`. The Norway adapters wrote
  `curated/` from `sources/` and now write `staging/norway/`; neither has ever run here.
- `targets` cannot see script edits, so the 13 producing targets were invalidated by hand. 48 of 60 targets were then
  outdated and were rebuilt with `tar_make_isolated()` (2026-10-08 17:48–20:00, 48 of 48 completed).

## Measured

- `check_sync()`: 669 parquet files under `curated/`, **669 stamped**.
  - 654 were built at 1d678ee from a clean tree.
  - 15 older files keep stamps from earlier builds; 14 of them say `dirty = true`. They refresh at the next rebuild.
- The 19 outputs of the converted scripts against a snapshot taken before the change:
  - no column added, dropped or retyped;
  - 15 with the same row count.

  The 4 that differ:

  | output | rows before | rows after |
  |---|---|---|
  | `vessel/vessel_ais_key` | 19,321 | 19,319 |
  | `ais/ping` | 535,618,918 | 535,613,643 |
  | `ais/trip` | 1,372,738 | 1,372,656 |
  | `link/trip_voyage` | 797,420 | 797,391 |

## Why four outputs changed: a loop in the key, not the stamps

Stamping cannot change rows. Re-running `curate/checks/ais_key_segments.R` reproduces the built segment table
exactly, so the segment build is deterministic. What changed is an input.

- **The loop.**
  - The audit's other-feed witness (W1, `curate/checks/ais_key_audit.R:37`) reads `curated/ais/ping`.
  - Which other-feed pings survive into that table depends on the key itself: decision 069's cross-feed duplicate rule
    compares against STK pings of the same vessel, and the whack filter judges each vessel's whole track.
  - The key was last built on 2026-10-07; decision 069 rebuilt `ais/ping` on 2026-10-08. This rebuild ran the audit
    against those pings, and the segment table lost 2 segments (3,118 → 3,116).
- **Pings with a vessel did not change.** The total on key rows that carry a vessel is the same (181,792,889). The
  boundaries moved. The −5,275 kept pings downstream are consistent with stretches judged against another vessel's
  track; this was not traced ping by ping.
- **It does not settle.**
  - One more pass (audit → segments → key) was run in a scratch overlay against the rebuilt pings, writing nothing
    into `curated/`.
  - It moves mobile-id 103738's boundary between vids 9848 and 2914 from 2020-06-01 to 2021-06-01, which is 5,484
    STK pings.
  - That boundary is placed "mid-way between the two runs" of W1 evidence, so it shifts whenever the surviving
    pings do.

The audit's header claims witnesses "that never read" the key. For W1 that is not true. This breaks the `AGENTS.md`
rule that cycles are broken by a human, outside the DAG. TODO item 40 holds the fix: W1 reads the other-feed pings
before any key-dependent cleaning.
