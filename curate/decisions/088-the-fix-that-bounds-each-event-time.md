# 088 — The fix nearest each recorded event time

*2026-10-14. Built by Claude (AI-assisted) on the maintainer's request (TODO 54, raised 2026-10-13). The choices
on derived and placeholder-like times are the maintainer's (2026-10-14). ramb 2026.10.14: `rb_link_record_events()`.
Closes TODO 54.*

## What was built

- **ramb `rb_link_record_events(pings, records, key, events = c("t1", "t2", "t3", "t4"), max_dt_s = Inf)`** is a
  generic step-2 function.
  - For every record and every event time it carries, it returns the vessel's ping nearest in time.
  - `dt_s` is that ping's time minus the event's, signed. `gap_s` is the time between the last ping at or before
    the event and the first at or after it: how precisely the track can place the event. It is 0 when a ping falls
    on the event, and NA when the track does not reach both sides.
  - A missing event time gives no row. On a tie the ping before the event wins.
  - Two DuckDB ASOF joins, the same path for lazy tables and data frames; a test checks the rules and that both
    give the same result.
  - No cast between zoned and plain timestamps (decision 086, finding B).
- **`curate/link_station_event.R` → `curated/link/station_event.parquet`** (target `station_event`), year by year.
  - The event times are `station_window.parquet`'s t1–t4, as the windows read them: adb's towed start and end are
    already moved to t2/t3.
  - The fixes are `curated/ais/ping`.
  - `MAX_DT_S` is 1 hour: farther than that, a fix says nothing about the event, and `time` and `dt_s` are NA.
- **`curated/ais/trail` carries `nearest_event`**: the event times a fix is the nearest fix to (`t3`, or `t3+t4`),
  whichever station they belong to.

## What counts as an event time (maintainer, 2026-10-14)

- **Missing:** no row and no label. Filling a missing time from the track is phase 4's fallback, not this step.
- **Derived:** afli's tow end, t2 plus the towing time (4.04 M tows), is matched and labelled like a recorded time.
  `event_basis` (`recorded` / `derived`) tells them apart.
- **Day assumptions:** the windows' start and end of day, a synthesised haul start and a set's end are window
  bounds, not t1–t4. This step never reads them.
- **Placeholder-like clock values** are flagged (`event_flag = "suspect_clock"`) and still matched:
  - afli set starts (t1) at 23:59: 7,356, 3.6 %;
  - fs_afladagbok tow starts (t2) at 00:00: 1,530, 0.7 %, about 6 times a typical whole hour.

  A third of afli's tow starts are rounded to the hour, and 12:00 holds the same share as any other whole hour,
  so it is not flagged.

Found on the way: afli dropped every tow start between 00:00 and 00:59 (decision 087).

## Measured (2023, run without writing)

- **Rows:** 209,005 event times, one row each, for the stations whose first event is in 2023.
- **Within the hour:** 98.6 % have a fix.
- **Distance to the nearest fix:** the median |dt| is 72–120 s by source and event, and 92.9 % lie within 5
  minutes.
- **Gap between the fixes either side:** the median is about 6 minutes (STK's interval). The 90th percentile is
  10–12 minutes for t2, t3 and afli's t4, but longer at the set start and at fs_afladagbok's haul end: afli t1
  6.3 h, fs_afladagbok t1 2.8 h and t4 1.1 h.

The whole table, after the rebuild, is in decision 089.
