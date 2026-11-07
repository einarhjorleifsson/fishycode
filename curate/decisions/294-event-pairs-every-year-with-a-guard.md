# 294 — STK's event pairs in every year, with a guard: a pair over a ping 10 km from its port makes no port call

*2026-11-07. Plan 048 §7.4 step 6, its last, at the maintainer's word ("Yes, start step 6", then "Lift with the
guard"). Measured, built, run and counted by Claude (AI); no person has checked the code or the counts. The study, its
scripts and every table: `$FISHYDATA/archive/2026-11-07-plan048-step6/` (its README). **Amended 2026-11-07**: the cause
of the overlapping port calls given under "What it leaves" was wrong. The TODO 195 study measured it
(`$FISHYDATA/archive/2026-11-07-port-shapes/`, its README; paused by the maintainer, not finished); the first account is
kept under its own heading at the end.*

## Why

An STK arrival and departure at one port, 2 h or more apart and both judged good by `rb_flag_port_event()` (decision
289), make a port call by the rule `event_pair`. Decision 059 used such pairs only from 2017. Decision 196 lifted that
cut for the events, and plan 048 kept it for the pairs until step 6 (§7.5 c) measured the pairs before 2017 against
the logbook's own dates. Decision 293 also left 147 pairs of port calls of one vessel that overlap, with a tie
deciding the next voyage's departure port.

**The witness is by day.** Before 2019 the logbook is afli's, which has dates only. Each call is in one outcome:

- *Contradicted*: a logbook station dated on a day the call covers whole, or a landing at another port on such a day.
- *Confirmed*: a landing at the call's own port on a day it covers.
- *No witness*: neither.

The yardstick is production's own calls under the same witness: 1.30 % contradicted for the pings' calls of
2007-2016, and 0.78 % for those of 2017 with an event pair.

**The cut lifted alone** (calls begun 2007-2017, against production's run of the same years):
- 40,790 new calls, 2.4 % contradicted.
- 83,652 changed. Most barely move, but 2,029 that a landing confirmed became contradicted, their start a median of
  48 h earlier.
- 3,041 merged several calls into one, 45 % contradicted. A pair whose trips' events are missing spans those trips
  and swallows the port calls between.

**The guard.** A pair makes no port call where a recorded ping between its two events, not at the pair's port, lies
more than 10 km from that port's polygon. Measured before it was built:
- It catches 65 % of the changed calls' contradictions and 81 % of the merged calls'.
- It touches 2.4 % of the changed calls a landing confirms.
- Of the 2017 pairs production used, it would drop 294 of 85,852, 155 of them contradicted.

The maintainer chose the cut lifted with the guard, in ramb, for every year.

## What was done

- **ramb 2026.11.07** (3a7c295): `rb_create_port_calls(pair_away_m = 10000)` drops a pair over such a ping; `NULL`
  turns the guard off. It has 20 expectations of its own, and the whole suite passes (3,174). It is committed to
  ramb's local `main` and installed from it (`git archive` with the LFS files, `--preclean`), not pushed.
- **`curate/port_call.R`** (63912ac):
  - The pairs count from every year: `EVENT_FROM` 2017 → 0 (`STAY_EVENT_FROM`, a test hook).
  - The guard is passed at 10 km (`STAY_PAIR_AWAY_M`).
  - The script stops under a ramb older than 2026.11.07.
- **Run read-only on every year first**, in `port_call.R`'s subset mode (`calls.R guard`): 1,667,466 calls.
- **Rebuilt** at 63912ac, with ramb 2026.11.07 and DuckDB 1.5.6, from 15:26 to 16:28:
  - `port_call` was invalidated by hand, then the 16 targets from it down were built.
  - All 370 curated files that changed are stamped 63912ac with a clean tree.
  - Only `ais_catch` and `check_allocation_audit` are outdated (decision 261).
  - The effort map's grids were rerun.
- **The build's port calls against the read-only run's**: 24 and 24 differ, all ties in time order (below).

## What changed

| | before | now |
|---|---|---|
| port calls | 1,628,604 | 1,667,466 |
| — begun 2007-2016 | 816,601 | 852,956 |
| — of those, rule `event_pair` | 185 | 804,362 |
| port calls the logbook contradicts; the fishing days inside them | 19,627; 21,286 | 18,459; 18,483 |
| — 2007-2016 | 10,636 (1.30 %) | 11,859 (1.39 %) |
| — 2017-2026 | 8,991 | 6,600 |
| port calls a landing at their port confirms | 983,556 | 1,001,209 |
| port calls that cut voyages; inside a voyage | 1,620,310; 0 | 1,621,990; 0 |
| voyages | 1,601,182 | 1,602,818 |
| fixes in a voyage | 292,529,578 | 293,162,194 |
| fixes with the voyage's logbook trip (`.tid_voyage`) | 216,689,163 | 217,120,902 |
| fishing fixes; their hours | 113,780,857; 9,178,233 | the same fixes; 9,178,041 (−0.002 %) |
| `fishing_flow` fixes; their hours | 138,882,222; 11,360,483 | 138,944,390; 11,367,674 (+0.06 %) |

**Port calls, 2007-2016**, each in one outcome against the store before:

| outcome | calls | contradicted | confirmed |
|---|---|---|---|
| the same | 734,208 | | |
| changed (one call before) | 79,904 | 1,110 (1.4 %) | 46,445 |
| new | 37,675 | 667 (1.8 %) | 14,049 |
| merged (several calls before in one) | 1,169 | 331 (28 %) | 308 |
| lost | 1 | | |

Most of the calls before 2017 now carry the rule `event_pair`. The rule names the strongest evidence, and an event
pair now stands behind calls the pings also make, as it has since 2017.

**Port calls, 2017-2026.** The guard acts on the pairs production used:

| outcome | calls | contradicted | confirmed |
|---|---|---|---|
| the same | 807,873 | | |
| changed | 6,636 | 77 | 5,062 |
| merged | 1 | | |
| lost | 490 | 48 | 160 |
| split into several | 1,998 | 1,474 | 239 |

The 1,998 split calls held 2,785 fishing days: long pairs over trips whose events are missing, which the track shows
were left.

**Voyages**, matched by vessel and times rather than by `voyage_id`. A `voyage_id` is a sequence within a vessel's
year, so a call new before 2017 renumbers every voyage after it that year.

| | the same | a port changed | times changed or gone | new |
|---|---|---|---|---|
| 2007-2016 | 801,506 | 87 | 4,442 | 2,853 |
| 2017-2026 | 793,344 | 24 | 1,779 | 5,004 |

**Trips.**
- `trip_voyage`, matched by the voyages' times:
  - 2007-2016: 472,248 trips the same, 1,485 with other voyages, and 612 lost their voyage.
  - 2017-2026: 386,855 the same, 1,229 other, and 3,568 gained one, from the split calls.
- `trip_reconciled`:
  - 3,549 trips gained AIS times and 610 lost them.
  - A departure moved for 5,473 trips (1,369 by more than 6 h), a return for 5,725 (4,205).
  - The witness of the return changed from the trip's own record to the AIS for 3,269.
- `trip_landing` lost 47 of 1,625,485 links and gained 65.
- `station_event` is unchanged.

**The effort.** Before 2017, 72,852 fixes left a voyage for a port call, and fishing hours fell by 267 (−0.005 %). In
2017-2026, 705,468 fixes joined a voyage, and `fishing_flow` hours rose by 8,022 (+0.15 %).

## What it leaves

- **Overlapping port calls**: 152 pairs on 75 vessels, 115 of them begun before 2017 (147 before this decision).
  Measured by the TODO 195 study:
  - No good STK event pair begins inside another pair of the same vessel (0 of 58,979). The guard's ASOF join shields
    nothing.
  - 123 of the 152 outer calls cross a New Year.
  - In 101 pairs, the outer call is held open by pings at its own port alone, either side of a silence in the track.
    Every such silence with a ping on both sides crosses at least one New Year. In all 101, the inner call's span holds
    good events with a position.
  - In 51 pairs, an outer event pair spans the inner call. In 41 the inner port is under 10 km away, below the guard's
    distance. In the other 10 a ping lies more than 10 km away between the pair's events, and every one of those pairs
    crosses a New Year.
  - The likely cause is `curate/port_call.R` running one year at a time. A year's pings are padded with a ping from the
    years either side, but only that year's events count as presence, and only the neighbouring years' events make
    pairs. So one year's run can see a long gap at a port that the next year's events would break. Batches of vessels
    over every year, as `ais_voyage.R` runs, should remove it. Not tested.
  - Carried to TODO 195.
- **Ties in time order.** Port calls, and the ports of the voyages after them, vary between runs where pings tie in
  time: 24 calls between the read-only run and the build, and 14-15 voyages' departure ports in decision 293. Each of
  the 24 keeps its port; only an end moves. Of the 69 differing ends:
  - 32 have a good event at a ping's time, in another place;
  - 12 have an STK arrival and departure in the same second, at two positions;
  - 25 have no such candidate within 6 h.

  In both named causes, two rows enter `rb_create_port_calls()` as presence at one time, and its order is by vessel
  and time alone. Carried to TODO 195.
- **TODO 192's condition is met**: STK's event rows are out of the track (plan 048), and plan 069's night run can run
  again. TODO 192 stays parked until the maintainer says otherwise.
- **The contradicted calls the guard leaves before 2017** have no ping away, because the track is silent during them.
  No rule that sees only the track can catch them.

## The first account of the overlaps was wrong

Kept for the reasoning. It read the calls' evidence, not the pairs' spans: an outer call can be longer than the event
pair in it, merged with the pings' calls at its port.

- **Overlapping port calls**: 152 pairs on 75 vessels, 115 of them begun before 2017 (147 before this decision).
  - In 69 pairs, both calls rest on an event pair. ramb's guard tests a ping only against the latest pair begun
    before it (an ASOF join), so a pair inside another shields the outer one.
  - In 53, the outer call rests on an event pair and the inner one on pings alone.
  - In 30, the outer call rests on pings alone.
  - 78 pairs lie at ports 10 km or more apart. The outer calls are long, a median of 4,200-10,200 h.
  - Carried to TODO 195.
