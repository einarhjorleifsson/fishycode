# 091 — One fix, one record: the windows and the event links made exclusive

*2026-10-14. Built by Claude (AI-assisted) on the maintainer's request (TODO 57). The invariant is decision 090.
The rules for a set inside a haul, for twins and for windows with the same start are the maintainer's
(2026-10-14). ramb 2026.10.14.2 and 2026.10.14.3, committed and installed, not pushed. The rules were first tested
on dry runs against `curated/` as built at fe31603. `station_window`, `station_event` and the trail were then
rebuilt on the maintainer's go, the same day (below), and TODO 57's check passed. Closes TODO 57.*

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
  the earlier phase, then to the lower `(.sid, schema)`. The phase was added in 2026.10.14.3, after the first
  rebuild (below).
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

**`station_event`, all years** (10,991,846 event times; the table is the final rebuild):
- 79,864 lose their fix (0.73 %). About 2,400 of them lose it to the other phase of their own station (221 a t4 to
  its own t1: a jig, or a set and haul, holding one fix);

  | schema | t1 | t2 | t3 | t4 |
  |---|---|---|---|---|
  | afli | 5,683 (2.8 %) | 24,993 (0.5 %) | 26,492 (0.6 %) | 2,680 (1.2 %) |
  | fs_afladagbok | 3,279 (2.2 %) | 6,603 (3.0 %) | 6,983 (2.6 %) | 1,874 (1.5 %) |
  | adb | 82 (1.7 %) | 532 (3.5 %) | 619 (3.2 %) | 44 (0.9 %) |

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

## The rebuild (maintainer's go, 2026-10-14)

`station_window`, `station_event` and `ais_trail` were invalidated by hand and rebuilt with `tar_make_isolated()`,
with the two trail checks after them. The logs, fingerprints and check script are in
`$FISHYDATA/archive/2026-10-todo57/`.

- **Build 1** (ramb 2026.10.14.2) passed TODO 57's check. Against the dry run, though, 1,069 event rows of 532
  stations came out differently. 531 of those stations have `t1 = t3`: the setting and the hauling start at one
  moment, so both want the same fix at the same distance and from the same time, and nothing broke the tie.
- **ramb 2026.10.14.3** breaks it by the phase: the setting keeps the fix. `station_event` and the trail were
  rebuilt with it (build 2). `station_event` took 28 s, the trail 20 min 23 s.
- **Reproducible:** a second, independent run of `link_station_event.R` gives the same 10,991,846 rows, with 0
  differences.

**TODO 57's check, on the rebuilt data:**
- fixes that bound events of two stations or phases in `station_event`: 0;
- `trail_match` fixes with two or more stations from tier-1 windows: 0. No fix has a tier-1 and a day window
  together. 6,497,408 fixes have several day-window stations; these are candidates, as decision 090 said;
- overlapping non-day windows in `station_window`: 0;
- every trail fix with `n_sid > 1` is a day-window fix;
- 2023 on the trail: 4,143,580 fishing fixes, as in the dry run.

**Fingerprints before and after** (847 files): six datasets changed, as expected, and nothing else.
- `station_window`: the same 7,494,007 rows. Only `w_start`, `w_end`, `win_basis` and `win_closed_by` changed,
  and `win_opened_by` is new (34,776 windows cut to nothing, 27,598 starts moved).
- `station_event`: the same rows. `time`, `dt_s` and `gap_s` changed, and `ping_lost` is new.
- The trail: the same 566,714,976 fixes. Only the station columns changed (`.sid` to `win_basis`, `n_sid`,
  `fishing`, `nearest_event`); position, speed, stay and voyage are identical.
- `trail_match`: 186,935,616 candidate rows before, 186,003,233 after (−932,383).
- The two trail checks.

The ramb push (2026.10.14 to 2026.10.14.3) is held by the maintainer.
