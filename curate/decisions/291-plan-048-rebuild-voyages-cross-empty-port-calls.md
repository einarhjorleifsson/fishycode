# 291 — Plan 048 steps 4 and 5: the store rebuilt with STK's events as events; fishing hours +0.09 %, port calls +4,829, but 58,207 fewer voyages, because a port call no ping falls in cuts no voyage

*2026-11-06. Plan 048 steps 4 and 5, TODO 148, at the maintainer's word ("proceed - i think we need no hand-check. use
your judgement on the rest"). Built, run and counted by Claude (AI); no person has checked the code or the counts.
The study, its scripts and every table: `$FISHYDATA/archive/2026-11-06-plan048-rebuild/` (its README).*

## What was done

- **Merged**: the branch `plan048-step3` into `main` (c3a5a97, decision 290's code), the hand check left out at the
  maintainer's word.
- **Rebuilt** at fc45a24 with ramb 2026.11.06.2 (852c86c, installed from ramb's local `main`: another session's map
  change on top of 2026.11.06.1, which nothing in the chain calls) and DuckDB 1.5.6: `stk`, `stk_event` and
  `ais_ping_union` invalidated by hand, then `tar_make_isolated()` over every target but `ais_catch` and
  `check_allocation_audit` (decision 261). 55 targets built from 15:26 to 17:46, `ports_all`'s descendants outdated
  since 2026-11-04 among them. After it only those two are outdated; `user_tables_check` passes 14 of 14.
- **Products and docs** (step 5): the effort map's grids rerun, each checked against the trail (730 preset-gear-years);
  the vessel overview shows `course` and `stream` beside `heading`, a missing heading empty rather than 0°, and its
  tooltip the course where the feed has no true heading (API 2026-11-06.1, checked in a browser); `docs/on_ais.qmd`,
  `docs/grammar.qmd`, `docs/data-dict.yaml` and `dump/oracle/meta/stk.yml` say what `heading`, `cog` and `stream` are
  and that STK's port events are judged as events.

## What changed

Every output file before and after (`after_files.csv`): 1,325 files, 812 changed, 512 unchanged, 1 gone (a part of
2021's `ping_clean`, which now fits in six).

| | before | after |
|---|---|---|
| fixes in the trail | 580,680,529 | 577,073,805 (−0.62 %) |
| fixes with a station | 156,677,636 | 156,028,834 |
| hours fishing (`fishing`) | 9,171,625 | 9,180,025 (+0.09 %) |
| hours fishing (`fishing_flow`) | 11,361,036 | 11,369,295 (+0.07 %) |
| speed filter: `vmask` / `forward` / `spike` | 972,571 / 317,489 / 7,204 | 275,913 / 178,508 / 2,065 |
| port calls | 1,623,775 | 1,628,604 (the scratch run of decision 290: 1,628,605) |
| port calls on events alone (no voyage cut) | 5,951 | 8,294 |
| voyages | 1,428,837 | 1,370,630 (−4.1 %) |
| trips with AIS times from a voyage | 846,672 | 846,001 |

- **The union**: STK's rows are 173,862,038 fixes and 3,904,823 arrivals kept as fixes. Its events, as `stk_event`
  places them: 8,147,800 by their code's port, 93,366 by position, 65,535 THH/THO departures by their arrival, 176,095
  with no port.
- **The hours**: a fix stands for the time to its vessel's next ping, at most 2 h (`ramb::rb_add_effort()`). Where an
  event row that left had been that next ping, the fix now runs to the next real position: at most +29,106 h of
  fishing (`hours.R`; an upper bound, since the speed filter had already removed many event rows), most of it on
  EMODnet's (11,229 h) and astd's (8,430 h) fixes. The rest, −20,704 h, is the event rows' own hours and the speed
  filter's changes. The largest group: EMODnet's fixes of afli's trips in 2017, +10,247 h (+9.8 %).
- **Port calls by rule**: `event_pair` 695,121 → 780,998, `tag_then_gap` 784,981 → 743,595, `tag_span` 125,784 → 88,082,
  `gap_near_port` 17,889 → 15,929. Calls on two rules now take the event pair's name more often, since the good events
  are presence.

## The voyages: a port call no ping falls in cuts no voyage

`ramb::rb_create_voyages(method = "dwell")` cuts the track into runs by the port call each ping falls in. A port call
that no ping falls in breaks no run, so the sea on either side of it becomes one voyage. Until this rebuild STK's event
rows were pings inside many port calls; now only an arrival kept as a fix is. `voyages2.R` counts each port call that
cuts voyages (not on events alone):

- 1,558,933 have pings in them;
- **57,389 have none and lie inside one voyage**, every one with STK event rows in its span (`tag_then_gap` 35,535,
  `event_pair` 18,967, `gap_near_port` 2,877, `tag_span` 10). Year by year they follow the voyages lost (2007: 1,689
  against 1,664; 2012: 5,780 against 5,643; 2025: 2,977 against 2,702);
- 3,988 have none and lie inside no voyage.

Another 12,678 runs at sea fell under the voyage's 10 pings without the event rows (`voyages.R`). Lost and new port
calls also merge and split voyages. These are not traced one by one, since the voyage table before was overwritten.

So 57,389 voyages run through a port. Their values may join two trips: the voyage's gear (`gid_voyage`, the speed range
`fishing_flow` takes outside a window) and the voyage's logbook trip (`.tid_voyage`, kept only when there is exactly
one). The trips' AIS times hardly moved (846,672 → 846,001).

The fix is generic and belongs in ramb: a port call cuts the track whether or not a ping falls in it. Then the chain
rebuilds from `ais_voyage` down. Both are the maintainer's to start (a ramb change and a live rebuild). Until then the
store and the user tables (v0) carry these voyages.

## What it leaves

- **The voyage cut** in ramb and the rebuild from `ais_voyage` down (TODO 148).
- **Step 6** of plan 048 §7.4: the event pairs before 2017, against the logbook's own dates (TODO 148).
- **Pushing** ramb (b7109d4..852c86c on its local `main`) and fishycode: the maintainer's.
- **TODO 192** (plan 069's speed rule) waited on this rebuild (decision 287); it can run again.
