# 043 — An evidence tier for the ASTD/astdB fallback candidates

*2026-09-27. Plan `008-north-atlantic-vessel-registry.md` §7 Phase 5/8.*

## What was found

Decision 042's worked example (mid 114277, 813,524 pings, 99.97% one name,
12 years) and a one-ping ASTD snapshot were both landing in the same
`needs_review == TRUE` bucket with the same generic warning, even though one
is about as solid as evidence gets and the other is a single unverified
broadcast. Nothing distinguished them, and reviewing 4,862 flagged rows one
at a time isn't viable — but treating them as uniformly weak would bury the
well-corroborated ones.

## What was built

`ais_key_foreign.R`'s stage-4 ASTD query now aggregates each MMSI's **full**
observed history in the same restricted pass (still `WHERE mmsi IN (...)`,
no full-table scan): total ping count, distinct years, and the share of
named pings held by the single most common name. A new `evidence_tier`
column (A–E) is attached to every candidate:

- **A** — `mobileid_direct` / `sknr_direct` (marinetraffic, Icelandic pleasure craft)
- **B** — `cs`/`mmsi` registry match, not flagged
- **C** — `cs`/`mmsi` registry match, but its `external_id` sits inside a
  real conflict (`vessel_identity_foreign_conflicts.parquet`)
- **D** — `astd_mmsi`, and the broadcast history is well-corroborated
  (≥100 pings, ≥2 distinct years, dominant name ≥80% of named pings) —
  thresholds are a starting point, not tuned beyond that
- **E** — `astd_mmsi` below that bar, or `astdb_mmsi` (no name/IMO at all,
  so consistency can't be assessed)

Measured, not assumed: of 4,200 `astd_mmsi` candidates, **3,014 (72%)** clear
the tier-D bar. Combined with `astdb_mmsi`'s 659, the flagged pool of 4,862
splits **3,014 tier D / 1,845 tier E** (1,186 astd + 659 astdb) — most of the
previously undifferentiated "needs review" mass is in fact strongly
corroborated, and a reviewer working the queue can now start at tier E.

`needs_review`/`review_reason` are unchanged by this — `evidence_tier` is an
additional qualifier, not a replacement filter, per the "cycles are broken by
a human" rule: nothing here promotes a row out of review automatically.

Total candidate count (7,568) and the five `basis` counts are unchanged —
this adds a column, it does not refilter.
