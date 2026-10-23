# 183 — The STK joins read an open stretch of the key as open: `d2_is_open`, not its date

*2026-10-23. Closes TODO 128, found by decision 181. Written by Claude (AI) in a session started from another Claude
session; the code and the checks are Claude's and have not been checked by a person. Committed, not built: no output
differs (below), so no target needs invalidating.*

## Found

An open stretch of `curated/vessel/vessel_ais_key.parquet` has `d2_is_open` true and, as `d2`, 2028-12-24: an
arbitrary open-end date (`SENTINEL` in the key's scripts). `sources/stk/convert.R` and `curate/ais_ping_union.R` joined
the STK trail on `time < d2 + 1`, so from 2028-12-25 every ping on an open stretch would have lost its vid and been
dropped, with no error.

The key as frozen (decision 128; read-only, 2026-10-23):

- Every one of its 20,710 rows carries `d2_is_open`, none NULL: the 3,352 rows from the segment table and the 17,358 of
  mobile-ids it does not cover (the cascade's `rest`). Every open row has `d2` on or after 2028-12-24, and every row
  with such a `d2` is open (`ais_key.R` sets `d2_is_open = d2 >= SENTINEL`).
- 3,144 segment rows are open: 3,133 end on the date and 11 after it (2032-04-01 to 2106-02-06), where the segment
  table ends a stretch at its last ping if that is later. One `rest` row has a vid (mid 101061, open). The joins keep the
  3,344 rows with a vid, 3,137 of them open.
- Two open rows are not their mid's last. Mids 102543 and 103872 each have a stretch to 2106-02-05, then a stretch of one
  day, 2106-02-06, a bad timestamp's day. The flag is true on the first only because its `d2` lies after the date. Read
  as open, it would take that day's pings a second time.

## Chosen

- **A mid's last stretch, if open, has no end.** Both joins still end a stretch at `d2 + 1`. The exception is the
  stretch with the latest `d1` of its mid: if that one is open, its end is DuckDB's `'infinity'::DATE`. The two stretches
  above stay closed by the one that follows them. The latest `d1` is taken over all of a mid's rows, with or without a
  vid, before the joins drop the rows without one. An open stretch therefore never runs into a later stretch the key has
  no vessel for.
- **Infinity, not a later date.** A later date would bring the same defect back, further off, and stretches already run
  to 2106.
- **`staging/ais/stk` keeps `d2e`.** The key's `d1`, `d2` and `d2e` (`d2 + 1`) are columns of the output, so `d2e`
  keeps its value. The join uses an end column of its own, which is dropped after it.
- **The frozen key is not redone.** Its next redo (TODO 25) may write an open end itself, but the joins no longer depend
  on it.

## Checked

Read-only, against the store as built on 2026-10-22, with the old and the new key side of the joins:

- **No ping is added.** No STK trail ping lies at or after `d2 + 1` on a mid's last open stretch, in any year. The bad
  timestamps of 2032-2106 lie within their stretches, since the segment table ended those at their last ping.
- **Same rows.** `convert.R`'s join gives 189,201,390 rows under the old code and the new, with the same 18 columns in
  the same order. The union's STK join over 2007-2026 gives 189,201,143 under both. With the new ends, no two stretches
  of a mid overlap, so no ping is joined twice.
- **The 2 rows on disk.** `staging/ais/stk` holds 189,201,392 rows. The 2 more are the `year=2006` partition left by the
  build of 2026-09-23 (TODO 95), the same under the old code and the new.
- **No target to invalidate.** `tar_outdated()` (main) lists only `species` and `species_raw`, the new targets of
  decision 182. `targets` cannot see a script edit, and since no output differs, no target needs invalidating.

On a scratch `$FISHYDATA` (the key and `vessel_identity` copied; a trail of 7 real 2026 pings of three mids and 10
made-up ones; one foreign astd and astdB row; emodnet's first two rows), both scripts ran in full, the old (HEAD) and
the new. The real store was unchanged (`find -newer`).

- **Mid 101666** (vid 1252, open at the date): the pings of 2028-12-25 00:00, 2029-06-01 and 2106-03-01 keep vid 1252 in
  `staging/ais/stk`; the old code dropped all three. In `ping_union`, 2028-12-25 and 2029-06-01 keep it. 2106 is outside
  the union's years, as before. The ping of 2028-12-24 12:00 has the vid under both.
- **Mid 142936** (vid 2741, closed 2026-06-15): 2026-06-15 12:00 is kept; 2026-06-16 00:00 and 2029-06-01 are dropped
  under both.
- **Mid 102543** (vid 2706): the pings of 2106-02-05 and 2106-02-06 are joined once each. The ping of 2106-02-07, after
  the last stretch, is kept by the new code only.
- **The rest** is unchanged: every other ping and its vid, `d2e`, and the columns.

## Left as they are

- **The key's `SENTINEL`**, in the frozen `once` scripts: the key is not redone.
- **`curate/vessel_ais_link.R`** writes an STK stretch's end as `day_after(d2)`, so an open stretch ends 2028-12-25 in the
  crosswalk, whose own convention is NA for open. No ping join reads it. Changing it changes the crosswalk today, so it
  waits for that target's next rebuild (TODO 129).
- **The key's own checks** in the `once` project (`ais_key_coverage`, `ais_key_audit`, `ais_key_split_candidates`) also
  compare ping days with `d2`. They run only with a key redo (TODO 25).
