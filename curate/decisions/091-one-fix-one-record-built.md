# 091 — One fix, one record: the windows and the event links made exclusive

*2026-10-14. Built by Claude (AI-assisted) on the maintainer's request (TODO 57). The invariant is decision 090.
The rules for a set inside a haul, for twins and for windows with the same start are the maintainer's
(2026-10-14). ramb 2026.10.14.2, committed and installed, not pushed. The counts are dry runs against `curated/`
as built at fe31603, written to a scratch directory. The rebuild of `station_window`, `station_event` and the
trail waits for the maintainer's go, and TODO 57 stays open until its check passes on the rebuilt data.*

## The rules

**Windows** (`rb_build_record_windows()`). Apart from day windows, no two windows of a vessel overlap.
- The windows are half-open, `[w_start, w_end)`. Day windows end at midnight.
- They are put in one order per vessel: by start, then end, then station, with the lower `(.sid, schema)` last.
- A window ends where a later start that may cut it begins (`win_closed_by = "next_event"`):
  - the recorded start of a tow, haul or jig cuts any window. Jig windows are cut now; before, nothing cut them;
  - a set's start (t1) cuts only an earlier set. **A set never cuts a haul** (maintainer): a gillnetter may set
    net A, then set net B, and then haul A again;
  - a start that is not a logbook time cuts nothing: the typical haul before t4, or a jig's `duration_m` before t4.
- A window that starts inside one it may not cut starts at that window's end
  (`win_opened_by = "previous_event"`). If nothing is left, it is cut to nothing.
- Of two windows with the same start, the shorter is cut to nothing, and the row is kept with `w_end = w_start`
  (maintainer: the longer keeps it).
- Of twins (TODO 58), the station with the higher `(.sid, schema)` is cut to nothing. TODO 58 may later choose
  which twin keeps the link.

**Event links** (`rb_link_record_events()`). A fix bounds the events of at most one station, and of one phase of it.
- The phases are setting (t1-t2) and hauling (t3-t4), so a haul of one fix keeps both its events.
- When two events would share a fix, the nearer in time keeps it. A tie goes to the earlier event time, then to
  the lower `(.sid, schema)`.
- The others get `time` and `dt_s` NA and `ping_lost` TRUE. Their `gap_s` stays.

## Why the set yields to the haul

TODO 57 first said "cap a haul at a later set". The dry run of that rule on 2023:
- 25k gillnet and longline hauls are cut, all years. In 2023, 30,680 fixes of their tails are left in no window,
  and `fishing` falls by 31.7k fixes (−0.8 % of all fishing fixes, nearly all GNS);
- 63-66 % of the fixes in the overlap, and in the tail, are at hauling speed. Outside windows the share is 19 %,
  inside hauls 85 %. The vessels mostly kept hauling.

With the set yielding instead, 1,120 fixes of 2023 lose their window and `fishing` falls by 521 fixes.

## The dry runs

**Windows, all years** (7,494,007 windows, 5,058,471 not day):
- overlapping tier-1 windows: 47,515 before, 0 after;
- cut to nothing: 34,776, of which:
  - 11,720 twins;
  - 16,248 other sets inside a haul;
  - 6,722 same-start ties: 3,426 afli tows, 2,954 sets, 252 hauls, 90 jigs;
  - 86 moved starts with nothing left;
- jig windows cut at the next start: 2,107;
- starts moved (`win_opened_by`): 27,598, of them 26,745 sets.

The tows cut to nothing by a same-start tie are a median 100 min long, against 170 for the tow that keeps the window.
Their ends differ by a median of 40 min, and 84 % are on the same trip. They read as near-duplicates.

**Fixes, 2023.** The current `trail_match` was compared with the draft rules on the same fixes:
- tier-1 fixes with two or more stations: 98,955 before, 0 after;
- 1,120 of 5.17 M tier-1 fixes lose their window;
- `fishing`: 4,144,101 before, 4,143,580 after;
- day windows are untouched. 93,501 fixes still have several day-window stations; these are candidates, as
  decision 090 said.

**`station_event`, all years** (10,991,846 event times):
- 79,860 lose their fix (0.73 %). Of the 79,860, about 2,400 lose it to the other phase of their own station
  (221 a t4 to its own t1: a jig or a set and haul holding one fix);

  | schema | t1 | t2 | t3 | t4 |
  |---|---|---|---|---|
  | afli | 5,720 (2.8 %) | 25,003 (0.5 %) | 26,445 (0.6 %) | 2,679 (1.2 %) |
  | fs_afladagbok | 3,821 (2.5 %) | 6,607 (3.0 %) | 6,438 (2.4 %) | 1,870 (1.5 %) |
  | adb | 106 (2.1 %) | 533 (3.5 %) | 594 (3.1 %) | 44 (0.9 %) |

- No fix bounds events of two stations or phases. The script now stops if one does;
- every other row is the same as before, except 158 events. These lie more than a month after their station's
  first event, in another year. The old loop put a station in the year of its first event and read a month of
  fixes either side, so it found nothing for them; now 146 have a fix and all 158 a gap. Each event is now linked
  in its own year, beside the events within a day of that year, because the one-fix rule must see every event that
  wants a fix.

## What changed in fishycode

- `curate/station_window.R`:
  - carries `win_opened_by`;
  - allows a window cut to nothing only when something cut it;
  - stops if two windows overlap.
- `curate/link_station_event.R`:
  - links each event in its own year;
  - carries `ping_lost`;
  - stops if a fix bounds two stations or phases.
- `R/trail_sql.R`, `docs/data-dict.yaml` and `docs/ais_trail.qmd` describe half-open windows, and a
  `nearest_event` from one station.

## Still open (TODO 57)

- Rebuild `station_window`, `station_event` and the trail, then run TODO 57's check on the rebuilt data.
- The ramb push (2026.10.14 to 2026.10.14.2) is held by the maintainer.
