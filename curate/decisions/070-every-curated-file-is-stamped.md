# 070 — Every file under `curated/` carries provenance stamps; the rebuild exposed a loop in the key

*2026-10-08. Closes TODO item 12. Code by Claude (AI-assisted), commit 1d678ee; measured on `$FISHYDATA` the same day. Amended later the same day: the key's movement was at least partly row-order flicker in the segment build, not only the loop (last section).*

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

## The loop reading was partly wrong (amended 2026-10-08, plan 013 phase 2)

*Measured by Claude (AI-assisted) in a scratch overlay of `$FISHYDATA`; nothing written to `curated/`.*

- **What happened next.** After W1 was moved to the merged pings before cleaning (TODO 40), two passes on identical
  inputs still differed. The moving mobile-ids changed from run to run: 100645, 103741, 103742.
- **The audit is deterministic as a set of rows.** Three runs gave identical W1, `lb_hits` and `lb_n`. It does not
  fix their row order.
- **The segment build is not order-independent.** The same audit evidence, sorted and then shuffled, gives segments
  differing in 4 and 3 rows. Several steps keep the first row of a tie (`distinct(.keep_all = TRUE)`, `slice(1)`,
  `x[1]`).
- **So the 3,118 → 3,116 change and mobile-id 103738's shift above cannot be told apart from this flicker** without
  rebuilding `curated/ais/ping`. The loop through W1 is still a real dependency and is removed anyway.
- **Fix.** `curate/checks/ais_key_segments.R` sorts every input on all its columns as it reads it. Two different
  shuffles then give identical segments, equal to the old code run on sorted input. Which row should win each tie is
  open (plan 013, logic questions).
