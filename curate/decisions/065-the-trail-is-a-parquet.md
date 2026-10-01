# 065 — The trail is a month-partitioned parquet, not a function

*2026-10-01. Plan 011 Phase 5 (which closes plan 011), plan 010 §3.3/§4.*

## What was built

`curated/ais/trail` (`curate/ais_trail.R`, SQL in `R/trail_sql.R`, target `ais_trail`): one row per fix, 567,376,085 rows for 2007–2026, partitioned
`year=Y/month=M`, sorted `vid, time`, unique on `(vid, time)`, 32 columns, 17 GB; `curated/ais/trail_match` (186,966,809 rows, 1.9 GB) with every
(fix, station) match. Columns: the fix; `stay_pid`, `trip` (the voyage, decision 061); `.tid_voyage`, `schema_voyage`, `n_tid_voyage` (the logbook trip of the voyage,
only when exactly one is on it); the station columns `n_sid .sid schema .tid gear gear_class phase phase_frac win_basis events fishing`; `sid_gps n_sid_gps`.
`pid` (the polygon tag of the ping tables) is not carried; `stay_pid` is the harbour. `ping_trail` gained `stay_pid`. Year and month are partition keys only
(`write_curated_sql()` used to copy them into the files too, because it read its temp file from a `year=…/month=…` path; fixed with
`hive_partitioning = false`). A month builds in about 7 s, the full history in 16 min; one month rewrites only its own files.

## Why a table and not `ais_trail()`

The function was a live join. It was meant to take 6 s (plan 010 §4, a range join on one year), but the whole wide result with the ambiguity step ran out of
memory on a year (a plain `count()` on 2019 failed at 19 GiB), and it made the analyst call a function instead of reading data. The deliverable is a parquet
opened with `open_dataset()` and worked in dplyr (AGENTS: a sweep of parquet files). `R/ais_trail.R` is removed; `docs/ais_trail.qmd` now shows the dplyr route.
Year-month partitioning so that a new month, or a late logbook correction, rewrites that month and nothing else; the wider rethink of making the whole chain
incremental (frozen profiles, content hashing, carry-over state, dirty vessels) was thought through in the session and not recorded or built.

## Checked

- Fixes per year equal `ping_trail`'s (the script stops otherwise); unique on `(vid, time)`.
- `.tid` (the station window) and `.tid_voyage` (the voyage link) agree for 99.59 % of the 137,094,608 fixes that have both (`check/trail_agreement`):
  independent evidence, so the link and the windows support each other. Share of fixes by `n_tid_voyage`: 22–73 % have no logbook trip on the voyage (cargo, ferries,
  service vessels, unrecorded static-gear set trips, fixes in harbour), 1.2–7.9 % are on a voyage shared by trips.
- Logbook stations with a fix (`check/trail_sid_coverage`): 94–99 % by any match, but that counts a whole-day window; given that the logbook recorded times for
  the station (47 % of stations in 2008, 99 % in 2024, a logbook property), 98–99.7 % of them find fixes in every year but 2008 (91 %). The 2022–2025 dip to
  97.5–98 % is not examined.

## Not done

The per-voyage table (one row per voyage with its trips, harbours and times) was offered and not asked for. The vessel-key and logbook-revision paths for incremental
updates are not built.
