# 289 — Plan 048 step 2: ramb's `rb_flag_port_event()`, port events judged as events; on STK's events it trusts 108,339 more than today and sets aside 3,089, and the unit test leaves what the track has judged

*2026-11-06. Plan 048 step 2, TODO 148, at the maintainer's word ("Yes, start step 2"). Built, measured and recorded
by Claude (AI); no person has checked the counts or the code. ramb 2026.11.06 (b2a7264), committed to ramb's local
`main`, not installed or pushed. The study, its scripts and tables: `$FISHYDATA/archive/2026-11-06-plan048-step2/` (its
README).*

## What was built (ramb 2026.11.06)

- **`rb_flag_port_event(events, ports = NULL, pings = NULL, unit = NULL, ...)`**, a step-1 step beside
  `rb_create_port_calls()`: any system's recorded arrivals and departures (`vid`, `time`, `io` "I"/"U", optionally
  `port_id`, `lon`, `lat`) get `event_flag`, the first test each fails, `event_track_kn`, the track's implied speed, and
  `good`, which `rb_create_port_calls()` reads. The tests, each only where its input is given: `"other_port"` and, for
  an arrival, `"outside_port"` (with `ports` and a position; a marker's position given as NA); `"flicker"` and
  `"repeat"` (sequence); `"track"` (the pings either side farther from the port, less `radius_m`, than `kn_max` allows;
  no ping either side, no witness: `good` NA); `"unit"` (with `unit =`). Lazy or data frame, the same rows in the same
  order; a registry row (`port_event` added to step 1's object words); 7 tests of its own (41 expectations) and an
  etiquette case;
  `rb_create_port_calls()` now names the step when `events` lacks `good`. ramb's whole suite passes (3,042).

## What the data chose

On STK's events of 2008, 2016 and 2024 (1,575,674), given as plan 048 §2.3's adapter would (the pid STK's code names,
markers' positions NA, the sending mobile id as unit) against step 1's cleaned track without the event rows:

- **`radius_m` 2 km**: with 500, 100 or 0 m the track test flags 1.8-4.0 times as many events in 2016 and 3.0-10.6
  in 2024, a vessel just outside its polygon minutes after the departure report. It is also `rb_create_port_calls()`'s
  `radius_in` and fishycode's `R_M`.
- **`kn_max` 25**: of the events today's `io_ok` passes, the implied speed is 0 for 86.4 % and under 15 kn for 98.7 %.
- **The unit test at 70 % of 20 or more, and only where the track has not judged**: the passing events of units whose
  own failures reach 70 % the track contradicts 6.89 % of the time in 2008, against 0.38-2.05 % below; in 2016 and 2024
  a unit's record predicts nothing (0-0.78 % in every band). As §2.3 wrote it ("none of them is trusted"), the test set
  aside 13,546 events of the three years, 13,506 of them confirmed by the track. Now it flags 40. A departure from the
  plan's wording, Claude's choice on these numbers: the screen stands where there is no track.

## What it found

Every event of the three years in one outcome against today's tags (production's `good`: `io_ok` and the event's own
row kept by the speed filter):

- **The step trusts 108,339 events today does not**: 94,610 whose row the speed filter removed though the track is
  consistent with the port; 7,339 within 2 km of their own port, in a neighbouring polygon (4,066) or arrivals just
  outside it (3,273, a median 3.7 m out); 6,390 of today's flickers where a pid is missing or one STK code resolves to
  two pids by position.
- **It sets aside 3,089 events today trusts**: 1,997 the track contradicts, 1,092 with no ping either side.
- **The sequence tests are today's**: every `io_dup` a repeat or flagged by position first.
- **On CNR-IRBIM's tracker log** (66 geofence events, a ping a minute) every event is good under any allowance: the
  step is not fitted to STK.

## What it leaves

- **Step 3**: fishycode's `sources/stk/event.R` as STK's adapter, the union without the event rows, `curate/port_call.R`
  calling the step; port calls against today's, the 13,510 that rest on events alone first. One question for it: a
  repeat breaks the adjacent pair `rb_create_port_calls()` makes even when the earlier event is months old, so step 3
  may pass only the good events.
- **No hand check** of the events trusted afresh or set aside.
- **ramb installed and pushed**: at the maintainer's word.
