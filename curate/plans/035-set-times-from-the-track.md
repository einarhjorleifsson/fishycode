# 035 — Set times from the track where the logbook has none

**status:** proposal — written 2026-10-20 before the measure of §3 was run; §4 is built only if §3's test passes ·
**2026-10-20** · **see:** TODO 103, decision 157, `curate/corrections/logbook_set_placeholder.yml`, decision 146 (the
set finder), TODO 72 item 8, `curate/station_window.R`, ramb `rb_link_record_sets()`

Drafted with AI assistance (Claude) on 2026-10-20: the cascade is the maintainer's ("use the logbook's set where it is
real, the track's where it is not"), the test, its threshold and the design of §4 are Claude's, written before any
number of §3 was seen. The maintainer asked Claude to build §4 and rebuild without him if the test passes.

**Measured:** nothing yet; §3 is filled in after the run. **Assumed:** that a logbook set time which is no placeholder,
lies outside a port call and has a ping within 15 min after it is the skipper's (decision 157's "ok", which is not
contradicted by the track, not proven by it); that the finder does as well on the placeholder stations, whose haul
start is degraded (decision 157), as on the well-recorded ones (checked only indirectly, §3).

## 1. The cascade

The set start of a static-gear station (`t1`), best source first:

1. the logbook's `t1`, where it is recorded and no placeholder (`curate/corrections/logbook_set_placeholder.yml`);
2. the set the track shows: `ramb::rb_link_record_sets()`, which looks back from the haul for the vessel's earlier pass
   over the haul's line (pings only, never the logbook's positions: they never meet the track);
3. none: no set window, no soak.

What the set is used for: the set window (whose fixes are never fishing), the set start in `station_event`, a station's
placement on voyages (`voyage_gear.R`) and in the audit, and later the soak (static effort as quantity × soak, TODO 72
item 8). The fishing fixes, their effort and their catch come from the haul windows and do not depend on it.

## 2. The test, fixed before the run

- **Truth.** Static hauls (LLS, GNS and GND, FPO) with both haul times, no duplicate twin, whose recorded `t1` is no
  placeholder of any kind (270 or 1,710 min, the trip's departure, the haul start or end, 00:00), lies before `t3` by
  at most 240 h (the finder's look-back), outside a port call, with a recorded ping within 15 min after it. 2008-2026.
- **Hauls given to the finder.** Start `t3`, end `t4`, pings from `curated/ais/ping` (recorded positions), exactly as
  §4 would run it. Every truth haul is counted in one outcome: within 60 min (|found set start − t1| ≤ 60 min), off,
  or no set found.
- **Variants.** ramb's defaults (iapesca's); no cap on the pass length; skip the run in with no cap (decision 146's
  best for soaking gear). Pings only.
- **Baseline.** The set at `t3` less the vessel's median real soak for that gear and year (its other truth hauls; the
  gear-year median where it has fewer than 5).
- **Pass, per gear class.** A variant passes for a gear if, over the truth hauls of 2015-2025 (the years the
  placeholders fill), it is within 60 min on at least 75 % of all of them (no set found counts as a failure), and at
  least 5 points above the baseline. The best passing variant is used for that gear; a gear with none keeps rung 3.
- **Reported beside it, not tested:** within 30 min, the soak's median relative error, the result by year, and on the
  placeholder stations the soaks the finder gives against the same vessels' real soaks.

## 3. Results

(Filled in after the run.)

## 4. The build, if a gear passes

- `curate/station_set.R` (flow), target `station_set` after `ais_voyage`, `logbook` and `logbook_gear`: every static
  station with `t1` NA and `t3` < `t4` recorded, of a passing gear, run through the finder with the passing variant;
  writes `curated/logbook/station_set.parquet` (`.sid`, `schema`, `set_start`, `set_end`, `set_basis =
  "reconstructed"`).
- `curate/station_window.R` reads it: a static station's `t1` is the logbook's, else the track's set start, and a
  column `t1_basis` (`recorded`, `reconstructed`, `none`) is carried on the windows. The window rules are unchanged.
- A rebuild from `logbook` through `station_window`, `station_event`, `voyage_gear`, `ais_trail`, `ais_catch` and the
  checks, fingerprinted before and after; a decision records it.
