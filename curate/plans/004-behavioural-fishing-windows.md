# 004 — Fishing windows from what the vessel did, not what the skipper wrote

**status:** parked (maintainer, 2026-10-14, after §8: jigging stopped, static gear's ceiling about +5 %) — nothing built · **2026-09-23** · **see:** `TODO.md` item 18,
`curate/logbook_sensor_gps.R`, `curate/corrections/logger_runs_past_the_station.yml`,
`curate/decisions/010-time-variable-naming.md`

**Measured** — on 2026-09-23, against the 2013 partition of
`curated/logbook/sensor_gps` (58,085 stations, 3,653,458 fixes) and
`curated/logbook/fishing_sample.parquet`:

- which of `t1`..`t4` each gear fills, and how many stations fill none;
- the logger's own span per station against the gear-appropriate window;
- that the over-run is one-sided.

**Measured since** (2026-10-14, §8): what a day window costs in the trail, by gear class, with a holdout on
vessel-days whose hauls or tows are recorded. Status of §5's five: (1) speed separates towed gear (decision 090)
and longline hauls (93 %), less so gillnets (67 %), pots (57 %) and Danish seine (63 %); (2) heading: not measured;
(3) and (4): towed gear by the stretch pairing (decision 092), jigging by a holdout (§8: no rule does better than
about 0.63 balanced accuracy against the logged sessions; stopped), static gear not yet, the holdout in §8 is the bench;
(5) the seines: 205,284 untimed SDN stations, five a vessel-day.

**Assumed** — everything about the classifier: that speed and heading separate
fishing from steaming well enough to place a window, that the transitions are sharp
enough to time, and that the result is worth more than the recorded times. None of
it has been tried. §5 lists the measurements that would decide it, and they come
before any building.

**The principle this plan is written under**, in the maintainer's words, 2026-09-23:
*keep model separate from measurements as far upstream as possible.* Nothing here
proposes to alter a measured table.

## 1. The opening the measurements leave

The logbook's event times are gear-shaped and sparse. On the 2013 logger stations:

| gear | slots filled | stations |
|---|---|---|
| OTB bottom trawl | `.23.` | 38,419 |
| OTM midwater trawl | `.23.` | 5,215 |
| LLS longline | `1..4` | 4,073 |
| GNS gillnet | `1..4` | 1,022 |
| **SDN Danish seine** | **none** | **6,058** |
| **PS purse seine** | **none** | **1,278** |
| LHM handline | `...4` | 93 |

Towed gear fills the inner pair, passive gear the outer pair — one schema, filled by
gear, exactly as `decisions/010` says. But **7,336 stations in one year record no
fishing time at all**, and the maintainer's assessment of the ones that do is that
they are "only vaguely right". `curate/corrections/station_time_whole_day.yml`
already documents stations handed a synthesised 00:00–23:59 window in place of the
missing times.

So for a seventh of the logger's stations there is nothing to improve on — there is
simply nothing there.

## 2. What the logger independently knows

`curated/logbook/sensor_gps` carries, per fix: `time`, `speed`, `heading`, and the
station `.sid`. The DDMMmm fault is confined to `lon`/`lat`
(`curate/corrections/afli_coords.yml`); **time, speed and heading are sound**.

Three independences make this usable, and they are the whole argument:

1. **Speed and heading are measured aboard.** They are not derived from the AIS
   track, from the vid match, or from anything this pipeline computes.
2. **`vid` reaches a logger fix through the logbook** — `.sid → .tid → vid` at
   `logbook_sensor_gps.R:43` — not through `vessel_ais_key`. So it does not inherit
   the misassignment class of `curate/corrections/ais_key_callsign_reuse.yml`.
3. **A classifier on speed and heading needs no position.** It therefore never
   touches the interpolated `lon`/`lat`, which *are* derived from the AIS track —
   and that is what removes the circularity the union's own note at
   `ais_ping_union.R:126` objects to.

Consequence worth stating plainly: such a classifier would run on **100 %** of logger
fixes, not the ~99.7 % that could be positioned — including the 0.3–4.7 % falling
outside any voyage, and 2007, where 97.9 % of fixes could not be positioned at all.

## 3. What is proposed

A **station-level** table: for each `.sid`, a fishing window inferred from the
logger's own speed and heading series, carrying `basis = "reconstructed"` beside the
logbook's `"recorded"`, and a confidence.

Not a position table. Not a merge. The output is a *time window per station*, so it
belongs beside the station, not among the pings.

**`curated/ais/ping` is not touched.** The union's contract is measured positions
with `provider` naming the instrument that saw the vessel; a reconstructed window is
neither a position nor a provider. Keeping it out is the upstream separation the
maintainer asked for, applied at the only place it can be applied.

## 4. What this replaces in the earlier argument

Two objections raised on 2026-09-23 against merging the logger into the union, both
**withdrawn**, recorded so they are not raised again:

- *"Merging inflates density statistics."* Wrong. Effort downstream is estimated from
  the **step** between pings, not from ping counts, so inserting a point splits a
  10-minute step into 5 + 5 and the total is preserved. Spatial allocation is
  unchanged too, since interpolated points lie on the same chord.
- *"The resolution gain is illusory."* True of the *positions* — they are
  `approx()` output along the AIS track and carry no positional information — but
  beside the point. The gain was never positional. It is that speed and heading are
  independent measurements, which is a different asset entirely.

What survives from that discussion is only the third objection: a reconstructed
quantity does not belong in a table whose contract is measurement.

## 5. What to measure before building anything

In this order, each cheap, and any of them can kill it:

1. **Does speed separate?** Distribution of logger speed inside the recorded window
   (`t2..t3`) against outside it, on the 43,634 towed stations. Heavy overlap means
   no classifier.
2. **Does heading separate?** Cog variance during a tow against during steaming.
3. **How sharp are the transitions?** A window needs edges, not just a state.
4. **Where both exist, how far apart are they?** The behavioural window against the
   recorded one. This is the validation, and it also puts a number on "vaguely right".
5. **The seines.** 7,336 stations with no recorded time. If the classifier works
   there it is supplying something that does not exist rather than second-guessing
   something that does — the easiest case to justify and probably the most valuable.

## 6. Two things to get right from the first day

**Carry basis and confidence from the start.** `vessel_ais_key` is this repo's
standing lesson: a fitted model that reads like a registry, whose `AGENTS.md`
description claimed a confidence column it has never had. Whatever this produces
should declare what it is before anyone depends on it.

**It interacts with an open correction.** `logger_runs_past_the_station.yml` measures
that the logger over-runs the recorded window on 39.8 % of stations and *under*-covers
it for passive gear (7.5 h of logger inside a 16.5 h set-to-haul window, because the
vessel leaves the gear soaking and returns). A behavioural window would settle which
of the two is wrong in each case, which is the repair that correction currently lacks.

## 7. Not proposed

Dead reckoning from speed and heading to reconstruct the path between AIS fixes. It
was raised on 2026-09-23 as a way to recover turns that linear interpolation erases,
and it may be worth doing for swept-area work — but it produces *positions*, which is
a heavier claim needing its own validation (the closing-error test against the next
known AIS fix). It is a separate plan if anyone wants it, not part of this one.

## 8. Measured, 2026-10-14: what a day window costs (Claude, AI-assisted, on the maintainer's request)

A station with no usable time gets a day window, midnight to midnight, and a fix in it is fishing when its ±10 min
median speed is in the gear's range (decision 093). Scripts and logs: `$FISHYDATA/archive/2026-10-todo18/`.

**Weight in the trail** (fishing fixes, 2007-2025): towed 0.6 % in day windows, static 22.8 %, **jigged 80.7 %**.

**Holdout:** take vessel-days whose stations of one gear all have a recorded haul (static, 213k days) or a
recorded tow (towed, 345k days). Count the fixes called fishing inside the real windows, then over the whole day as
if the times were missing, under the same rule (it agrees 100 % with the trail's `fishing`).

| gear | extra fishing fixes at sea from a day window | haul or tow fixes called fishing |
|---|---|---|
| LLS | 18.4 % | 93.0 % |
| GNS | 26.7 % | 66.6 % |
| FPO | 30.3 % | 56.6 % |
| OTB / OTM | 21.7 / 35.0 % | 94.6 / 94.2 % |
| SDN | 50.1 % | 62.6 % |
| DRB | 24.0 % | 87.3 % |

- **The "extra" is an upper bound.** Static gear often logs only the haul, so part of it is unlogged setting.
- The false fishing at sea lies before the first window and between windows about equally, and less after the last.
- **Port time is not the trail's problem:** 3.7 % of static day-window fishing fixes are in port (gillnet's range
  starts at 0, so a day-long window would take port time; the trail's windows evidently mostly do not).
- **A midnight-to-midnight day cuts real hauls:** 23 % of static hauls (15 % of tows) cross midnight, and 17 %
  (13 %) of their time falls on another date.
- **Static day windows are one per vessel-day** (98 %); GNS ones are 89 % `event` (one record a day). Towed ones
  are mostly Danish seine, five untimed records a vessel-day, so for SDN the question is which tow a fix belongs
  to, not when.
- **Dredgers** (2015-2025):
  - On days logged without times they write 1.5 records and tow a median 104 min at dredge speed.
  - On days logged with times, 8 records and 382 min.
  - That is 70 min of towing per untimed record against 48 per timed one: perhaps an extra haul in two records,
    not records skipped at scale.
  - Counting runs merges a dredge's short back-to-back tows (0.41 runs per timed record), so minutes are the
    fairer measure.

**Jigging, tested the same day (maintainer: the gear moves with the boat, and the drift varies in space and time
with the tidal currents).** The bench used 83,727 vessel-days whose jig stations all have a recorded or derived
session, with 4.2 M fixes at sea that also have a local drift baseline. The baseline is the median speed of other
jiggers' slow fixes in the same ~5 km cell within ±1 h. Scored against "inside a session or not":

| rule | sensitivity | specificity | balanced |
|---|---|---|---|
| today's range (0.025-1.7 kn) | 0.647 | 0.593 | 0.620 |
| best fixed threshold (≤ 3.0 kn) | 0.767 | 0.504 | 0.635 |
| best local-drift rule (≤ 2.75 × local drift) | 0.738 | 0.508 | 0.623 |

- **The local drift does vary:** 0.25 to 1.6 kn (10th to 90th percentile across cells and hours). But it adds
  nothing over a fixed speed.
- **Every rule stops near 0.62-0.635,** because the truth is coarse: a session (about 8 h) includes the runs back
  up-current, and fixes outside the logged sessions include slow drifting.
- **The reported heading is the course,** within 7° of the track (median), so it carries no drift signal.
- Fixes are about 10 min apart, so a drift cycle mostly falls between them.
- **Stopped, by a rule set before the result** (more than 3 points over the best fixed speed, or stop). The speed
  rule in day windows is as good as these data allow for jigging. Script: `jig_bench.R`.

**Where this points:**
- ~~**Jigging first.**~~ Tested and stopped, above. It carries most of its effort in day windows. The gear moves with the boat, so the question
  is which fixes are drifting (maintainer, 2026-10-14), not where a gear lies.
- **Static gear second:** the over-claim is about +5 % of static fishing fixes. The idea is to place each station
  on a hauling bout by its recorded position, with this holdout as the test bench.
- **Towed gear** needs no window work for effort. Danish seine's which-tow question matters only for catch per
  fix.
