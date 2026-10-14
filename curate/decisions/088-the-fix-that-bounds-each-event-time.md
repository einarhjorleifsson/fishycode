# 088 — The fix that bounds each recorded event time

*2026-10-14. Built by Claude (AI-assisted) on the maintainer's request (TODO 54, raised 2026-10-13). The rule and
the choices on derived and placeholder-like times are the maintainer's (2026-10-14). ramb 2026.10.14.1:
`rb_link_record_events()`. Closes TODO 54.*

## The rule

The event times bound phases:
- t1 starts the setting and t2 ends it;
- t3 starts the hauling and t4 ends it;
- towed gear records only t2 and t3, and its tow lies between them.

A **start takes the vessel's next fix** (the first at or after it), and an **end the previous fix** (the last at or
before it). So:
- the fixes from the t1 fix to the t2 fix are the setting;
- the fixes from the t3 fix to the t4 fix are the hauling;
- a tow is the fixes strictly between its t2 fix and its t3 fix.

The same rule holds for every gear.

**It replaced "the nearest fix"**, which was built first and then measured on 2023:
- The nearest fix was the one before the event for 48–53 % of events, for every event.
- So it fell inside the station's own recorded tow or haul for only 49–50 % of them.
- The bounding fix of a start is inside for 97.3 % (static, hauls) to 98.7 % (towed, tows), and so is the bounding
  fix of an end.
- The rest are phases shorter than the gap between fixes. For those, the start's fix comes after the end's;
  `link_station_event.R` counts them.
- The fix before a tow's t2 and the fix after its t3 fall inside the tow window for 0.4 %. They sit just
  outside it, and the tow is what lies between.

## What was built

- **ramb `rb_link_record_events(pings, records, key, starts = c("t1", "t3"), ends = c("t2", "t4"), max_dt_s)`**
  is a generic step-2 function. It returns one row per record and event time present:
  - `time` is the bounding ping's time.
  - `dt_s` is `time - event_time`: at least 0 for a start, at most 0 for an end.
  - `gap_s` is the time between the last ping at or before the event and the first at or after it: how precisely
    the track places the event. It is 0 on a ping, and NA when the track does not reach both sides.

  Two DuckDB ASOF joins, one path for lazy tables and data frames, tested on a fixture. There is no cast between
  zoned and plain timestamps (decision 086, finding B).
- **`curate/link_station_event.R` → `curated/link/station_event.parquet`** (target `station_event`), year by year.
  - The event times are `station_window.parquet`'s t1–t4, as the windows read them: adb's towed start and end are
    already moved to t2/t3.
  - The fixes are `curated/ais/ping`.
  - `MAX_DT_S` is 1 hour: farther than that, `time` and `dt_s` are NA.
- **`curated/ais/trail` carries `nearest_event`**: the event times a fix bounds (`t3`, or `t3+t4` for a haul of
  one fix), whichever station they belong to. The column name stayed from the first build.

## What counts as an event time (maintainer, 2026-10-14)

- **Missing:** no row and no label. Filling a missing time from the track is phase 4's fallback.
- **Derived:** afli's tow end, t2 plus the towing time (4.04 M tows), is matched like a recorded time.
  `event_basis` (`recorded` / `derived`) tells them apart.
- **Day assumptions:** the windows' start and end of day, a synthesised haul start and a set's end are window
  bounds, not t1–t4. This step never reads them.
- **Placeholder-like clock values** are flagged (`event_flag = "suspect_clock"`) and still matched:
  - afli set starts (t1) at 23:59: 7,356, 3.6 %;
  - fs_afladagbok tow starts (t2) at 00:00: 1,530, 0.7 %, about 6 times a typical whole hour.

  A third of afli's tow starts are rounded to the hour, and 12:00 holds the same share as any other whole hour,
  so it is not flagged.

Found on the way: afli dropped every tow start between 00:00 and 00:59 (decision 087).

The full-data figures, after the rebuild, are in decision 089.
