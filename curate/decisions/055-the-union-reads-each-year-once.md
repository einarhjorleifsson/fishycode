# 055 - The union reads each year's partitions, not everything, once per year

**Status:** done 2026-09-30 (was TODO 27). `curate/ais_ping_union.R`; equivalence test `curate/checks/ping_union_equivalence.R`.

The write loop re-evaluated the whole lazy union for each of 20 years (`d |> filter(year == YR)` after the union does not prune), so each year re-read ~145 GB
of ASTD and ASTDB: 1 h 35 m 34 s for a full build (37 minutes in an earlier run, on a machine under less pressure). Now `d_for(YR)` builds each year from that year's
partitions only:

- **ASTD and ASTDB** are hive-partitioned by `year`, and the partition is the year of `date_time_utc` (0 mismatches over all rows), so `filter(year == YR)` comes
  first. The duplicate-ping window groups on identical timestamps, so it never reaches across a year; pruning first does not change it.
- **STK** is not safe to prune blindly: 33,373 of ~290 M raw rows sit in a partition that is not their own year (timestamps of 1984, 1997, 2106 ...). A year is
  its own partition **plus** the rows of every other partition whose time falls in it (`union_all` of two filters).

**Verified** (same key, old full-scan code against the new code): identical for 2007, 2014 and 2017 (counts by provider, distinct vids, coordinate, time and vid
sums), 199 / 192 / 230 s against 3.0 / 4.9 / 13.5 s for the query. The test needed DuckDB's spill directory set explicitly (`SET temp_directory`); it failed
twice on R's own temp folder before any comparison ran.

**Measured on the full build:** `ais_ping_union` **1 m 54.7 s** (12.78 GB) against 1 h 35 m 34 s. All 46 provider-and-year cells of the new union match the old
on rows (543,727,495 in total) and on distinct vids; coordinate sums are identical in 45 of 46 cells and differ by 0.001 out of 1.6 billion in the last
(floating-point summation order), epoch sums by at most 8 seconds in 4e16. The bytes differ (ties in `arrange(vid, time)` can land in a different order), so the
downstream targets rebuilt: `ais_ping_tag` 2 m 54 s, `ais_ping_clean` 6 m 04 s, `ais_trip` 8 m 59 s, `trip_voyage` under 1 s, `logbook_sensor_gps` 9 m 06 s -
the whole run 29 m 18 s, nothing outdated afterwards. The rest of the chain is now the slow part.
