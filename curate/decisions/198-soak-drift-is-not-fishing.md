# 198 — Slow drift during a soak is not fishing on the vessel's fixes, unless it looks like hauling: the freed fixes and every static voyage

*Drafted 2026-10-21 by Claude (AI) and measured read-only on the build of 2026-10-21 (stamp de25239, 452f83e in the
published history; ramb 2026.10.19.2), following decision 158, "Open". Decided by the maintainer on 2026-10-23, in a
status review run by Claude (the section "Chosen" at the end). The draft is kept as it stood above that section.
Nothing is built.*

- **Who asked.** The maintainer, through the session that ran the rebuild of 2026-10-21: what the 643,298 fixes are
  that `fishing_flow` began to call fishing when the placeholder set windows went, and whether that is right. The
  side effect is to be understood before anything is decided.
- **Who did the work.** Claude (Anthropic): the measurements and this draft. **Every number below was measured by
  Claude (AI); a person has not yet checked them.** Scripts, results, figures and a README in
  `$FISHYDATA/archive/2026-10-freed-fixes/`. The windows before the rebuild were rebuilt with the placeholder `t1`
  as recorded in `staging/` and ramb's own window builder: identical to the summary taken before the rebuild in all
  13 cells. No logbook position was read: hauls meet fixes by time, and the "where" below is the AIS track.

## Found

### Which fixes (every one in one outcome)

The 75,273 old placeholder set windows that held fixes held 2,330,799. 2,328,557 left the set phase (the
summaries' number exactly), and 2,242 now fall in another station's set window, which the placeholder start no
longer cuts.

| Outcome now | Fixes | % | Hours |
|---|---|---|---|
| in another window (set 2,242, day 3,031, several stations 41) | 5,314 | 0.2 | 422 |
| in a port call: no voyage, the voyage rule does not judge it | 261,892 | 11.2 | 38,293 |
| at sea, not judged (no speed 2,385; the voyage's gear ambiguous 927 or none 525; no voyage 128) | 3,965 | 0.2 | 242 |
| fails the voyage rule, within 500 m of the track where its own line is hauled later: **setting** | 958,270 | 41.1 | 55,583 |
| fails the voyage rule, otherwise (steaming, median 8.3 kn) | 457,409 | 19.6 | 28,944 |
| passes, in a hauling-like stretch (60 min or more at the vessel's own hauling speeds) | 210,589 | 9.0 | 13,746 |
| passes, within 1 km of its own line's haul track | 197,765 | 8.5 | 11,946 |
| passes, within 1 km of another station's haul track or an earlier haul | 29,734 | 1.3 | 1,842 |
| passes, away from any recorded haul | 205,861 | 8.8 | 13,633 |
| **all** | **2,330,799** | 100 | |

The four "passes" rows are 643,949 fixes and 41,167 h (longline 626,976, gillnet 16,973). The +643,298 of decision
158 is +643,949 from them, +542 from freed fixes now in day windows, −621 from voyages whose gear changed (a
placeholder time no longer places a station on a voyage) and −572 from jig windows that start later. Recomputed
fix by fix, the "after" equals the trail's `fishing_flow` on all 2.4 M fixes touched.

### What the vessel was doing (longline; the same 217 vessels, the ±10 min median speed the voyage rule tests)

| | Fixes | Median kn (IQR) | > 5 kn | 00-06 UTC |
|---|---|---|---|---|
| freed, passes | 626,976 | 1.06 (0.71-1.50) | 0 % | 52 % |
| freed, fails | 1,380,719 | 6.73 (5.52-7.69) | 87 % | |
| recorded hauls | 25,498,899 | 1.61 (1.43-1.79) | 4 % | 14 % |
| real set windows | 3,051,680 | 5.94 (4.30-7.19) | 70 % | 56 % |
| real soaks, at sea in no window | 2,762,676 | 1.70 (0.90-6.74) | 37 % | |

| Against the hauls' track | Own line, later, ≤ 500 m | ≤ 1 km | Another haul ≤ 1 km | No haul ≤ 1 km | A haul ended ≤ 30 min before | Next haul is its own |
|---|---|---|---|---|---|---|
| freed, passes | 22 % | 38 % | 16 % | 55 % | 0.4 % | 99.7 % |
| freed, fails | 69 % | 76 % | 15 % | 22 % | 1.3 % | 99.9 % |
| real set windows | 72 % | 82 % | 20 % | 15 % | 1.0 % | 98.9 % |
| real soaks | 40 % | 55 % | 16 % | 39 % | 0.4 % | 98.4 % |

- **The failing freed fixes are mostly the setting.** At setting speed, over the line that is hauled hours later,
  as real set windows are. The placeholder 270 min before the haul often falls on the real set.
- **The passing ones are the soak.** They are slower than the same vessels' hauls. 52.5 % lie below the vessel's own
  hauling band (p10-p90 of its recorded hauls), 44 % inside it, 3.5 % above, the same split as passing fixes in real
  soaks (52.8 / 43.5 / 3.7). They lie between setting and hauling the same line, 3.0 h before the haul (median),
  36 km from the voyage's first fix. They are not the tail of an earlier haul, and seldom on another station's
  ground. Example: vid 2842 on 2019-08-01 sets at 5 kn, then drifts from 1.2 to 0.5 kn at the end of the line it
  hauls from 08:30 (figure 3, example 1).
- **Some are hauls.** 40 % of the hauling-like passing fixes (83 k) sit on stations whose own haul window is poor
  (under half its fixes fishing; 50,876) or not recorded (32,486). On placeholder stations in general the haul
  window is as sound as elsewhere (good on 92.3 %, real-set stations 93.8 %). There the logbook's haul times are off
  and the voyage rule finds the real haul. Example: vid 2817 on 2019-06-05 runs at 1.7 kn from 07:00 to 14:00 while
  its recorded haul is 14:25-14:27, at steaming speed (figure 3, example 4, drawn at random). The other
  60 % (127 k) may be hauls the logbook does not record, or slow transit at hauling speed: the track cannot tell.
- **Gillnet** (16,973 passing): the range starts at 0 kn, so a stopped boat passes. 27.5 % of them are below
  0.5 kn.

### The same on stations with a real set time

At sea and in no window, the voyage rule calls the fixes of a real soak (set window end to haul start) fishing on
**52.1 % on longline** (2.81 M fixes, 101 k h) and **22.0 % on gillnet** (6.79 M, 115 k h), every vessel. By hours
before the haul, real soaks pass 49-63 % on longline. In placeholder soaks the share is 23-49 %, lower far from the
haul because the real setting lies there (figure 2). Real set windows, judged as if no window held them, would pass
20 % (longline) and 12 % (gillnet). **The pattern belongs to the voyage rule on static voyages, not to the
placeholder.** The false windows hid 644 k of these fixes; without them, placeholder stations behave like the rest.

On every voyage whose gear is static from the logbook, all years, the voyage rule calls fishing:

| | Longline fixes | Hours | Gillnet fixes | Hours |
|---|---|---|---|---|
| before a static haul on the same voyage (soak, between hauls) | 2,862,286 | 200,882 | 618,428 | 47,401 |
| in a hauling-like stretch | 1,463,155 | 101,790 | 253,063 | 21,123 |
| after the voyage's last haul | 176,708 | 15,503 | 78,955 | 5,787 |
| on a voyage with no static haul window | 217,433 | 25,776 | 333,856 | 35,729 |
| all | 4,719,582 | 343,952 | 1,284,302 | 110,041 |

In 2014-2026 that is 276,573 h of longline fishing beside 1,246,557 h from the windows on these voyages. The freed
fixes are 40,024 h of it (2.6 % of the total).

## Rules measured (for the maintainer's choice; nothing built)

- **Keep (the status quo).** No code. +41 k h, about two-thirds soak and one-third hauling-like; catch hardly moves
  (12.2 t, decision 158).
- **A rule for the freed fixes alone** (e.g. no voyage-rule fishing within 4.5 h before a placeholder station's haul).
  This brings the placeholder back in another form, and two stations with the same track would be judged
  differently by what the logbook app wrote. Not measured further.
- **The voyage rule off on static voyages with logbook stations** (only windows decide; about three lines in
  `curate/voyage_gear.R`). Removes 344 k h of longline and 110 k h of gillnet fishing, all years, the hauling-like
  stretches with them (102 k h longline), and with them the mis-timed real hauls. Of the freed fixes it removes
  625,227 + 16,633.
- **No voyage-rule fishing before a static haul on the same voyage, unless hauling-like.** An estimated 30-40 lines in
  `R/trail_sql.R`, plus each vessel's hauling band as an input. Removes 201 k h of longline and 47 k h of gillnet;
  keeps the hauling-like stretches. Of the freed fixes it removes 417,982 + 11,599 and keeps 206,701 + 4,877.
- **Pass only stretches of N min inside the range** (generic, could live in ramb). Measured not to work: drifting
  through a soak lasts as long as a haul. At 60 min longline soaks still pass 47.6 % (52.0 % without), hauls 88.1 %
  (92.4 %), and gillnet hauls fall from 65.9 % to 36.3 %.

No rule could be scored for accuracy: nothing labels a soak fix as drift or haul. Agreement with the logbook is not
the test. The gain of the last two candidate rules is consistency with the grammar, not a measured error.

## Recommendation (Claude's, for the maintainer to accept or reject)

1. **Keep the rebuild's state for now; add no rule for the placeholder stations alone.** The freed fixes now behave
   like every other static soak. The +41 k h (0.46 % of flow-fishing fixes) is the visible part of a general
   property, not a fault of the correction.
2. **Decide once, for all static voyages, whether slow movement during a soak is fishing.** fishycode's grammar
   (hauling is fishing, setting never, the soak no window) says no. A WGSFD-style speed filter says yes. On
   longline voyages with logbook stations it is about 200 k h either way.
3. **If not:** the rule "no voyage-rule fishing before a static haul on the same voyage, unless hauling-like" is the
   better of the two measured. It keeps the hauling-like stretches, where 40 % of the freed fixes are probably
   mis-timed real hauls. Switching the voyage rule off on these voyages is cheaper but loses them.

## Open

- Hauling-like stretches on stations whose own haul window is poor or not recorded (83 k freed fixes; on every static
  voyage not counted) point at mis-timed logbook hauls. A check could list them per station.
- The gillnet range starts at 0 kn (`gear_window`, declared fleet ranges): any stopped gillnetter on a gillnet voyage
  passes the voyage rule.
- 261,892 freed fixes are in a port call: the placeholder set window in port (decision 157). They are not judged
  before or after.

## Chosen (the maintainer, 2026-10-23)

- **Slow drift during a soak is not fishing on the vessel's fixes, unless the stretch looks like hauling.** On every
  static voyage, not only the placeholder stations: no voyage-rule fishing before a static haul on the same voyage,
  except a hauling-like stretch (60 min or more at the vessel's own hauling speeds, its p10-p90 band from its recorded
  hauls). About 30-40 lines in `R/trail_sql.R`, with each vessel's hauling band as an input. On the measure above it
  removes about 201 k h of longline and 47 k h of gillnet fishing (all years), and keeps the hauling-like stretches
  where the logbook's haul times are likely off. The case put to the maintainer: during the soak the gear fishes where
  it was set, not where the boat drifts, so a static gear's effort belongs on its set line as soak × gear (the pressure
  product, TODO 72 item 8), not on the vessel's fixes.
- **The draft to Trackwell** (and the Directorate) is sent by the maintainer, who records it in `trackwell.yml`
  (`sent`, `sent_how`).

Built as a flow change, a scratch build first with the catch traced kilogram by kilogram (plan 037 §6), then the trail
and catch rebuilt by name on the maintainer's go; it fits the AIS batch's rebuild. The gillnet speed range starting at
0 kn, which lets any stopped gillnetter pass the voyage rule, goes to TODO 34.
