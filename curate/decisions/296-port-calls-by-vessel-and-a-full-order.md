# 296 — Port calls by vessel over every year, and a full order for rows that tie in time: 152 overlaps to 39, and a rerun gives the same store

*2026-11-07. TODO 195, at the maintainer's word ("Can we try to complete the TODO's here, one at a time", then "Yes,
apply and rebuild"). Measured, built, run and counted by Claude (AI); no person has checked the code or the counts. The
study, its scripts and every table: `$FISHYDATA/archive/2026-11-07-port-call-by-vessel/` (its README). It follows the
TODO 195 study the maintainer paused (`$FISHYDATA/archive/2026-11-07-port-shapes/`).*

## Why

Decision 294 left two defects in the port calls (TODO 195).

- **152 pairs of one vessel's port calls overlapped** (75 vessels). The paused study found the cause in
  `curate/port_call.R`, which made the calls a year at a time:
  - each year's pings were padded with each vessel's last ping before the year and first ping after it;
  - only that year's own good events counted as presence;
  - a silence over New Year therefore became one call at the port either side of it, even when the next year's events
    put the vessel at another port. 101 of the pairs were made that way.
- **A rerun gave a slightly different store.** Rows that share a time were ordered arbitrarily in three of ramb's
  functions:
  - `rb_create_port_calls()` ordered a vessel's pings and presence events by time alone. A good event at a ping's time
    in another place, or an STK arrival and departure in one second, fell either side.
  - `rb_flag_port_event()` numbered the events in no order and broke ties by that number.
  - `rb_create_voyages()` gave every port call's boundary rows the same rank, so two calls that end in one second
    tied.

## What was done

- **Tested read-only first.** A copy of `port_call.R` ran by vessel (`run.R`), twice under ramb as installed and twice
  under a patched copy of ramb.
  - Two runs under the old ramb differed in 85 port calls.
  - Two runs under the patched copy were identical.
  - Over 2009 and 2017, the old voyages differed in 11 of 169,548 between two runs, each a departure or arrival port;
    the patched voyages did not differ.
- **ramb 2026.11.07.1** (6fbb540): the full order.
  - `rb_create_port_calls()` orders by time, lon and lat.
  - `rb_flag_port_event()` numbers the events by vessel, time, io, port, position and unit.
  - `rb_create_voyages()` orders the boundary rows by port after time, and the runs by their number after their start.
  - `test-ties.R` has 10 expectations: 7 fail on 2026.11.07 and all pass now. The whole suite passes (3,187).
  - Committed to ramb's local `main` and installed from it (`git archive` with the LFS files, `--preclean`); not
    pushed.
- **`curate/port_call.R`** (c32ac1b): the calls are made by batches of vessels over every year.
  - A batch is a range of vids of about 40 M recorded pings. The pings are sorted by vid within each file, so a batch
    reads only its own row groups.
  - Every good event is presence and every pair counts, whatever its year. No call is cut at New Year.
  - The port calls took about 5 minutes in 14 batches.
  - The subset mode (`STAY_YEARS`) gives the calls that overlap the years asked for, made on the whole series of the
    vessels heard in them.
  - The script stops under a ramb older than 2026.11.07.1.
- **Rebuilt** at 6c89c14, with ramb 2026.11.07.1 and DuckDB 1.5.6, 19:30-20:31.
  - `port_call` was invalidated by hand, then the 16 targets from it down were built.
  - All 370 curated files that changed are stamped 6c89c14 with a clean tree.
  - Outdated: `ais_catch` and `check_allocation_audit` (decision 261), and the three timarit targets that another
    session rebuilds itself.
  - The effort map's grids were rerun.
- **The build reproduces the patched read-only run exactly**: no port call differs in key, port, times, rule or
  evidence.

## What changed

| | before | now |
|---|---|---|
| port calls | 1,667,466 | 1,668,404 |
| — the same | | 1,660,233 |
| overlapping pairs of one vessel's calls | 152 (75 vessels) | 39 (34 vessels) |
| port calls the logbook contradicts; the fishing days inside them | 18,459; 18,483 | 18,364; 18,266 |
| port calls a landing at their port confirms | 1,001,211 | 1,001,429 |
| port calls that cut voyages; inside a voyage | 1,621,990; 0 | 1,622,527; 0 |
| voyages | 1,602,818 | 1,604,035 |
| fixes in a voyage | 293,162,194 | 293,182,537 |
| fishing fixes; their hours | 113,780,857; 9,178,041 | the same fixes; 9,177,976 (−0.0007 %) |
| `fishing_flow` fixes; their hours | 138,944,390; 11,367,674 | 138,945,905; 11,367,766 (+0.0008 %) |

**Port calls**, each in one outcome against the store before:
- 7,928 changed, mostly long calls at a silence over New Year (median 2,847 h before 2017 and 4,390 h after).
- 155 merged several calls before into one, and 88 are new.
- 900 calls before were split into several, and 74 were lost.

**Voyages**, matched by vessel and times:
- 1,596,354 are the same.
- 628 have the same times and another port.
- 5,836 have other times or are gone.
- 7,053 are new.

**Trips.**
- `trip_voyage`: 863,702 trips keep the same voyages, 1,683 take other voyages, and 130 gain one.
- `trip_reconciled`: 130 trips gain AIS times. A departure moved for 1,413 trips (51 by more than 6 h), a return for 559
  (126).
- `trip_landing`: 2 of 1,625,503 links changed.

## What it leaves

- **39 overlapping pairs.** Each is an STK event pair at one port over a call made by pings at another port 0.4-10 km
  away, below the guard's 10 km (decision 294). Their outer calls run a median 482 h. IS-AMG with IS-OLV is the
  commonest pair, 10 times. The records side with the pair:
  - 15 outer calls have a landing at their own port on their days, and 1 has fishing days inside;
  - no inner call has a landing at its own port, and the landing on 4 inner calls' days is at the outer port.

  A rule that dropped the pair over another port's call would drop the better-witnessed call. They are left as they
  are. `ais_voyage.R` cuts at both calls, and with the full order the voyage after them takes one port on every run.
- **The port codes the paused study found** (TODO 196):
  - two pairs of neighbouring ports that the track and the records name for each other, IS-NJA/IS-KEL and
    IS-SNA/IS-REY, which may be one port under two pids;
  - adb's logbook trips with no pid (37,847);
  - fs_afladagbok's trip ends whose port code has no row in `port.parquet` (439, 14 codes).
- **Other orders in ramb** were not traced, only the three that made the port calls and voyages differ.
