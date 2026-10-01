# 059 — STK harbour events get a tag table, one row per ping

*2026-10-01. Plan 011 Phase 2, built in the voyage session. Nothing reads the table yet.*

## What was built

`curate/checks/stk_event.R` → `curated/check/stk_event.parquet` (target `check_stk_event`):
8,197,409 events (4,264,553 `I`, 3,932,856 `U`) with a `vid`, 2007–2026, one row per `(vid, time, io)`.
Tags: `io_pos` (own / other_harbour / outside / no_hid / no_pid, plus `pos_dist_m`), `io_dup`,
`io_short`, `io_jump` (against the nearest retained non-event pings on both sides, 25 kn, neighbours
must agree with each other), `in_clean`, `io_ok`. The tags live in a check table, not in staging
(plan §5 a). The position test uses the current polygons (`ports.fgb`), so it does not depend on
the outdated chain; the jump test uses `ping_clean`.

## The duplicates found on the way

STK ships most `U` events twice, one row with `hid` and one without (3.03 M of 4.39 M `U` pings), so
the plan's §2 figures (6.77 M `U`, 40 % without a code, `U→U` 26 %) counted source rows. Per ping,
`U` and `I` are about equal in number and 1 % of `U` lack a code. Recorded in
`corrections/stk_event_duplicate_rows.yml`; the pings are not affected (the union dedups them).

## What the shares say (by year in the run output; 2017–2025 summary)

- `I` position: 99.2–99.8 % `own` from 2017; 85–98.5 % in 2007–2016. `other_harbour` is 1.3–2.6 % to
  2012, ~0 after 2013. `U` is 29–49 % `own`, the rest `outside`, as expected: the test does not apply.
- `io_dup` (`I` after `I`) is 23–35 % in 2007–2010 and 2013, 1–3 % otherwise. `io_short`
  (flicker) is 8–36 % in 2007–2016, 1–3 % from 2017: the old receiver era is different data.
- `io_jump`: 0.1–1 % of `I`, 0.3–1.6 % of `U` from 2017; 2013–2016 `U` 3.6–17 %. The jump test
  judges 99 % of events. 2016 `U` is the outlier.
- `in_clean`: 71–92 % in 2007–2016, 92–97 % after. `ping_clean` drops 3–8 % of events in the good
  years and up to 29 % in 2016; only 1–12 % of dropped `I` (up to 62 % of dropped `U` in 2016) fail
  the jump test, so most dropped events are not provably wrong by this test.
- `io_ok`: 94–98 % from 2017, 50–83 % before. 2009 `I` is 49.8 %, below plan §6's "majority every year".

## Not decided

`U` position test (plan §5 c): `pos_dist_m` is reported for `U`, no distance to the `I` cluster yet.
Whether the stay rule trusts the pre-2017 years is Phase 3's question.
