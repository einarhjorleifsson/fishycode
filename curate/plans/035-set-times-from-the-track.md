# 035 — Set times from the track where the logbook has none

**status:** abandoned — §3's test, fixed before the run, failed for every gear (2026-10-20, decision 158): the set
stays the logbook's or none, and §4 is not built · **2026-10-20** · **see:** TODO 103, decision 157, `curate/corrections/logbook_set_placeholder.yml`, decision 146 (the
set finder), TODO 72 item 8, `curate/station_window.R`, ramb `rb_link_record_sets()`

Drafted with AI assistance (Claude) on 2026-10-20: the cascade is the maintainer's ("use the logbook's set where it is
real, the track's where it is not"), the test, its threshold and the design of §4 are Claude's, written before any
number of §3 was seen. The maintainer asked Claude to build §4 and rebuild unattended if the test passes.

**Measured:** §3, by Claude (AI) on the build of 2026-10-20 (data of 5cec0f4), ramb 2026.10.19.2; a person has not yet
checked it. Scripts and results in `$FISHYDATA/archive/2026-10-plan035/`. **Assumed:** that a logbook set time which is no placeholder,
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

261,370 static hauls (t3 < t4, no duplicate twin, 2008-2026) were given to the finder, year by year. Their set times:
placeholder at 270 or 1,710 min 77,171; other placeholders 2,646; out of range 753; none 113; candidates 180,687, of
which 27,807 fail the track (21,690 in a port call, the rest no ping within 15 min). **Truth: 152,880 hauls** (LLS
98,814, GNS and GND 53,651, FPO 415).

The test, 2015-2025, in % of all truth hauls (`within 60` = the found set start within 60 min of the real `t1`; `none`
= no set found; the baseline is `t3` less the vessel's median real soak):

| gear | n | variant | within 60 | within 30 | off | none | baseline within 60 | pass |
|---|---|---|---|---|---|---|---|---|
| LLS | 50,855 | defaults | 28.6 | 20.7 | 70.2 | 1.2 | 57.9 | no |
| LLS | | no cap | **53.7** | 40.5 | 45.1 | 1.2 | 57.9 | no |
| LLS | | skip the run in, no cap | 53.5 | 40.0 | 43.4 | 3.1 | 57.9 | no |
| GNS | 32,530 | defaults | 20.9 | 15.8 | 76.5 | 2.5 | 23.1 | no |
| GNS | | no cap | 21.6 | 16.3 | 75.8 | 2.5 | 23.1 | no |
| GNS | | skip the run in, no cap | **31.7** | 25.1 | 63.4 | 4.9 | 23.1 | no |
| FPO | 415 | defaults | **3.6** | 2.2 | 94.5 | 1.9 | 88.7 | no |

- **No gear passes.** The best longline variant is right on about half the hauls and below the vessel's own typical
  soak (57.9 %); the gillnet one is above its baseline by 8.6 points but right on under a third; on pots the finder is
  almost never right, while the typical soak is (88.7 %). All years 2008-2026 give the same picture (LLS 54.6 %, GNS
  30.1 %).
- **Where it misses** (best variant, signed error of the found start, 2015-2025): longlines are late, 1-3 h on 19.9 %
  and 3-6 h on 8.1 % of hauls; gillnets are early, a day or more on 23.0 % (an earlier pass over the same spot, where
  nets are set again) and 6-24 h late on 7.0 %. The finder and the baseline are both right on 32.5 % of longline
  hauls, either on 79.1 %.
- **By year** the longline share is 47-60 % and the gillnet share 13-38 %, with no trend that would pass in a subset.
- **On the placeholder stations** (not tested) the longline finder's soak is within 60 min of the vessel's typical
  soak on 32.2 %, against 41.8 % on the truth hauls: it does worse where it would be used, as assumed possible above.
- **Decision 146's Icelandic score is superseded.** It scored against declared `t1`, a placeholder on 57 % of 2023
  longline sets; against real set times the defaults are right on 28.6 % of longlines, and no cap almost doubles it.

## 4. The build, if a gear passes

- `curate/station_set.R` (flow), target `station_set` after `ais_voyage`, `logbook` and `logbook_gear`: every static
  station with `t1` NA and `t3` < `t4` recorded, of a passing gear, run through the finder with the passing variant;
  writes `curated/logbook/station_set.parquet` (`.sid`, `schema`, `set_start`, `set_end`, `set_basis =
  "reconstructed"`).
- `curate/station_window.R` reads it: a static station's `t1` is the logbook's, else the track's set start, and a
  column `t1_basis` (`recorded`, `reconstructed`, `none`) is carried on the windows. The window rules are unchanged.
- A rebuild from `logbook` through `station_window`, `station_event`, `voyage_gear`, `ais_trail`, `ais_catch` and the
  checks, fingerprinted before and after; a decision records it.
