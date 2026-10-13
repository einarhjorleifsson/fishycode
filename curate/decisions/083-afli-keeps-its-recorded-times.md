# 083 — afli keeps its recorded times; the overlap check is a flag

*2026-10-13. Code and measurements by Claude (AI-assisted), on the maintainer's answers of 2026-10-13: keep the
overlapping tows' times; and, for static gear, the fishing is the haul from t3 to t4 with t1 the setting, so a
recorded time is used and never replaced by a dummy. Closes TODO 29, and the "Not done" line of decision 057.
The windows after the 2026-10 rebuild are in that rebuild's record.*

## What was wrong

`sources/afli/convert.R` ("Overlap QC") labels each operation against its neighbours on the same vessel with
`osfd::fd_flag_time_overlaps(t2, t3, by = vid)`, and then set t2 and t3 to NA for **every** label but `ok`.
TODO 29 named only the overlaps. The label is computed on t2/t3, so static gear (which has no t2) is always "start
time missing". The comment said such rows "pass through with no change", but their recorded t3 was dropped.

On the build of 2026-10-09 (`staging/afli/fishing_sample`):

| `.checks` | stations | dropped | what it was |
|---|---|---|---|
| start time missing | 1,715,187 | t3 for 217,816 | static gear's recorded haul start (`drattur_hefst`): LLS 137,567, GNS 67,106, LHM 13,143 |
| end time missing | 1,087,355 | t2 for all | a tow's recorded start (`ibotni`) with no towing time |
| end time overlaps next | 101,269 | t2, t3 | the tow overlaps the next one of the vessel |
| start time overlaps previous | 86,896 | t2, t3 | the tow overlaps the previous one |
| start after end, start equals end | 0 | | |

All 188,152 of the overlapping tows that reach `station_window` had a whole-day window (`day`, `synthesised`).

## What was chosen

- The label stays in `.checks` as a flag. Only an impossible interval (start after or equal to end; none
  today) loses its times. "Never destroy the original" (AGENTS.md).
- Nothing changes downstream. `ramb::rb_build_record_windows()` already cuts a tow or haul back at the vessel's next
  recorded start (`win_basis` "capped", raw times kept), and builds a haul from a recorded t3 and t4.

## Measured before the rebuild

`convert.R` was run without its writes and compared row by row with `staging/afli/fishing_sample`:
- Only t2 and t3 differ: t2 on 1,275,520 rows (1,087,355 + 101,269 + 86,896), t3 on 405,981
  (217,816 + 188,165).
- Every difference restores a value that was NA. No other column and no other value changes.

The restored static t3 are recorded times, not dummies:
- 0.1 % fall exactly at midnight.
- The haul (t4 − t3) has a median of 7.9 h for longline and 4.0 h for gillnet.
- The soak (t3 − t1) has a median of 4.5 h for longline and 22 h for gillnet.
- Almost all date from the electronic logbook, 2008–2022.
- A few are out of order: t3 before t1 on 36 stations, after t4 on 44, equal to t4 on 52 and equal to t1 on 59.
  ramb does not use a t3 after t4 for a recorded haul. The 36 that start before their own setting are left as
  recorded.

## What it changes

- **(a)** The static hauls get a recorded window [t3, t4] instead of a synthesised one. Afli's hauls also enter the
  typical haul length per gear (median t4 − t3).
- **(b)** A tow with a start but no end still gets a day window: ramb needs an end or a duration. Its t2 is kept
  beside it.
- **(c)** The overlapping tows get tow windows, the earlier one capped at the later one's start.
