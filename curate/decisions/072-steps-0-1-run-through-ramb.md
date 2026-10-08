# 072 — Steps 0 and 1 run through ramb; each port reproduces the built output (plan 013, phase 2)

*2026-10-08. Plan 013 phase 2. Code by Claude (AI-assisted): ramb d5602f1, 1ef5c51, 8be1fef, 1995e1a and 9789c0c;
fishycode 3365661, 20bcdb5, 0244d5a, 16b86e0, e552579 and the commit that adds this record.
Measured by Claude on `$FISHYDATA` in a scratch overlay; nothing was written to `curated/` or real `staging/`.
Closes TODO items 40 and 42.*

## What was done

Each fishycode step script now calls one ramb function per task. The SQL and R it held moved into ramb, written to run
on a data frame or a lazy DuckDB table alike.

| fishycode script | ramb function(s) |
|---|---|
| `curate/ais_ping_tag.R` | `rb_flag_ping_harbour()` |
| `curate/ais_ping_clean.R` | `rb_flag_ping_invalid()` → `rb_flag_ping_duplicate()` → `rb_flag_ping_impossible()` |
| `curate/harbour_stay.R` | `rb_find_trip_stays()` |
| `curate/ais_trip.R` | `rb_cut_trip_voyages()`, `rb_assign_trip()` |
| `curate/link_trip_voyage.R` | `rb_link_trip_voyages()` |

## Measured: each port against the built output

| Step | Compared | Result |
|---|---|---|
| harbour tag | `staging/ais/ping_tagged`, 543,776,104 pings, 2007–2026, every column but `geom` | 0 differ (2007–2014 row for row, 2015–2026 by fingerprint) |
| ping labels | 543,648,309 pings with a vessel, 2007–2026, in the script's own batches | 0 labels differ |
| harbour stays | 2007–2026 | 1,551,604 stays, row for row |
| voyages | `curated/ais/trip.parquet` | 1,372,656 rows, 0 differ either way |
| ping → stay, voyage | `curated/ais/ping`, per-year fingerprints | 535,613,643 rows, 0 years differ |
| voyage link | `curated/link/trip_voyage.parquet`, with the old key (`.tid` alone) | 797,391 rows, 0 differ |

An exact match proves the port faithful, not the logic right. The doubts found while reading the ported code are in
plan 013 ("Logic questions found while porting"), each with the measurement that would settle it.

## Changes beyond the port, each counted

- **The voyage link ranks per `(.tid, schema)`.** `.tid` is unique only within a schema (6,565 trip ids occur in
  two). The old SQL ranked colliding trips together, so two trips shared one link. 797,391 → 797,661 rows: 541 new
  rows, 540 of them for colliding ids, 271 merged rows gone; one tie is now settled by a fixed order.
- **The key settles (TODO 40).** W1 of the key audit read `curated/ais/ping`, which depends on the key; it now reads
  `staging/ais/ping_union` before any cleaning. The segment build kept the first row of ties in input order; it now
  sorts every input on all its columns (decision 070, amended). Two passes give identical `vessel_ais_key` rows.
  Against the built key, 6 mobile ids differ (100645, 103738, 103741, 103742, 143852, 149996). All are mids heard
  with more than one vessel; the difference comes from the tie order, not from new evidence.
- **The harbour tag cannot double a ping (TODO 42).** The left spatial join returned one row per polygon a ping lies
  in. `rb_flag_ping_harbour()` keeps the smallest. On the built table the old join doubled nothing:
  `ping_tagged` and `ping_union` have the same rows in all 20 years (543,776,104). The point geometry the join left
  in every row (`geom`) is not written any more; no reader used it.

## In ramb only

Not used by fishycode, so not measured on `$FISHYDATA`; tested on ramb's `dansk` data (ramb `NEWS.md`):

- `rb_cut_trip_voyages()` gains `method = "runs"` (was `rb_trip()`) and `"jepol"`, the ICES datacall rule (was
  `rb_trip_jepol()`), recoded from `data.table` to base R and equal to the old function's trips, with and without
  splits. Two defects of the ICES rule are kept for that equality (plan 013, logic questions).
- `traipse` is recoded (Vincenty on WGS84, within a micrometre of geodist's geodesic); `glue` and `data.table` are
  gone; `terra`, `mapdeck`, `scales` and `icesVocab` are in Suggests. `R CMD check`: 0 errors, 0 notes, one warning
  from R's own `Boolean.h` with this compiler.

## Not yet built

None of the ported scripts has been rebuilt in `$FISHYDATA`. `targets` cannot see script edits, so the next rebuild
invalidates them by hand. It is the combined rebuild of phases 2–3, with the TODO 37 branch merged, checked by
per-partition fingerprints against snapshots taken before it (plan 013).
