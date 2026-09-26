# 040 — Plan 008 Phase 6: the ASTD/astdB residual pass, and a real bug it surfaced

*2026-09-27. Plan `008-north-atlantic-vessel-registry.md` §7 Phase 6.*

## What was built

Two more stages appended to `reference/vessels/ais_key_foreign.R`'s cascade,
each restricted to exactly the MMSIs the previous stages left unmatched —
never a scan of ASTD's 2.77 billion pings:

- **Stage 4, ASTD**: `WHERE mmsi IN (...)` plus `QUALIFY row_number() OVER
  (PARTITION BY mmsi ORDER BY date_time_utc DESC) = 1`, collecting one (the
  latest) row per MMSI. `external_id` is IMO where ASTD's own `imonumber`
  passes the checksum, `astd_<mmsi>` otherwise; `astd_cat` rides along as
  reference only, never a filter (per the maintainer's earlier finding that
  it is unreliable for a fishing/non-fishing split).
- **Stage 5, astdB** — added after the maintainer asked "you are not
  forgetting astdB" (this session had dismissed it earlier for lacking a
  name/IMO column, which is true but was the wrong reason to skip it
  entirely). It still carries dimensions, flag (`cc_iso3`) and AIS class, and
  resolves MMSIs ASTD itself has nothing for. `external_id` can only ever be
  `astdb_<mmsi>` here — there is no IMO to check.

**A found-and-fixed bug along the way**, more consequential than either
stage: the first version of stage 4 used `duckdbfs::open_dataset()` (the
shared, cached connection also used by `identity_foreign.R`/`identity_all.R`
earlier in the session) and failed with `IO Error: Failed to create directory
.../duckdb/temp` — the exact failure mode `R/write_parquet.R`'s own header
describes. Fixed with a fresh `DBI::dbConnect(duckdb::duckdb())` per query,
disconnected immediately after.

## A real bug in `R/vid_match.R`, found by asking why FRO and GFW never matched

Checking the results by `source` after stages 2/3 first ran showed something
wrong: **zero** matches ever resolved to `source == "fro"` or `"gfw"`, despite
both contributing rows to `vessel_identity_foreign.parquet`. Cause: `.overlaps()`
(`a1 <= b2 & b1 <= a2`) returns `NA` — silently dropped by `filter()` — whenever
either identity bound is `NA`, and that is exactly how those two sources were
built (plan 008 §7 Phase 2/3): FRO's single open snapshot leaves `t2` `NA`,
GFW's leaves both `t1` and `t2` `NA`. An unbounded period is supposed to mean
"matches any query window," not "never matches."

Fixed in `R/vid_match.R`'s `.overlaps()` — `NA` bounds coalesce to
`1900-01-01`/`2100-12-31` before comparing. Icelandic `vessel_identity.parquet`
never carries an `NA` bound (`identity.R` always coalesces to a sentinel
date), so this is a no-op there — **verified by reproducing decision 037's
`ais_key.R` baseline exactly unchanged** (19,234 rows, 2,820 assigned vid,
identical tier counts) before trusting the fix.

## Effect, measured before and after the fix

| | before the `.overlaps()` fix | after |
|---|---|---|
| stage 2 (`cs`) | 193 | 780 |
| stage 3 (`mmsi`) | 106 | 736 |
| stage 4 (`astd`) | 4,563 | 4,295 (fewer mobile-ids reach this stage at all — more were already resolved by 2/3) |
| stage 5 (`astdb`) | — | 722 |
| **total candidates** | 5,772 | **7,443** |
| still unmatched | 6,815 | **5,144** |

By source: `fro` now contributes 982 matches (584 `cs` + 398 `mmsi`), `gfw`
319 (`mmsi` only, as expected — it has no call sign column). Both were
silently zero before the fix.

`needs_review` (decision 039's split): every `astd`/`astdb` candidate is
flagged unconditionally (a single broadcast snapshot, no registry
corroboration, no time-aware window — closer to `ais_key.R`'s own
`older`/hail-mary tier than to a registry match) — 2,423 `FALSE`, 5,020
`TRUE`.

## What's still open

Wiring `overrides/stk_foreign_identity_reviewed.csv` back into the cascade.
`_targets.R` wiring for all of plan 008. Reviewing the ASTD/astdB candidates
at whatever pace is practical — each is genuinely single-source and
uncorroborated, unlike the registry-sourced cases decision 039 resolved.
