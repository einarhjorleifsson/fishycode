# 060 — STK's VMS clocks: a lag from the shift that puts each ping on its vessel's AIS track, by week where it can be judged, the rest flagged

**status:** proposal — written 2026-11-01 at the maintainer's request ("Lag from the scan": a lag per vessel and period
from the per-ping shift where it can be judged, and a flag where it cannot; plan it first) · **2026-11-01** · **see:**
TODO 180, `curate/corrections/stk_vms_clock.yml`, decision 271, plan 059 (the feeds' clocks, ramb's step 0),
`curate/checks/ais_feed_clock.R`, `curate/ais_ping_tag.R`, the study `$FISHYDATA/archive/2026-11-01-vms-clock-scan/`

Drafted with AI assistance (Claude) on 2026-11-01, from the study run the same evening. No person has checked it. The
choice of repair is the maintainer's; the design and every number are Claude's.

**Measured** (the study, scripts 01-03, and the store of 2026-11-01 at 7216654):
- **The scan.** Each VMS ping of a vessel with an AIS stream that year (3.48 M of 4.05 M) was projected onto the
  vessel's moving AIS track within 2 h, giving the shift that puts it there. A ping is judged where the AIS track moves
  at its own stamp and the fit is within 300 m.
  - 6,947 vessel-months are on time: judged shifts −1.0 to +3.0 min (5-95 %).
  - 43 are an hour off (14 vessels): 33-118 min, mostly 2007-2009.
  - 251 are off by minutes (40 vessels): −9.8 to +16.5 min, mostly 2007-2013.
  - 38,203 vessel-months (2.45 M pings) have fewer than 10 judged pings.
  - The clocks drift: vid 975 and vid 1809 lost 8-9 min a month over September-December 2007. Checked against a per-
    minute scan on vids 975, 1809 and 2677 (the control: 82 m at +1 min, 87 % within 200 m).
- **Why plan 059's check misses them.** Its method (`rb_create_ping_lags(method = "interpolate")`) needs 30 pairs. In
  `curated/check/ais_feed_clock` the VMS stream's 48,298 vessel-months are:
  - 44,135 `not measurable`,
  - 2,508 `one stream`,
  - 1,628 `no reference`,
  - 19 `aligned`,
  - 8 `offset`.

  Speed is not the cause: 74.5 % of VMS pings report 2 kn or more, and 11.3 % report 0. STK's own units (`stk_unit`,
  10.2 M pings) are the same: 29,174 `not measurable`, 2 `aligned`, none measured.
- **The store.** 3,744 hour-off and 63,257 minute-off VMS pings are in it unmoved. The whack removed 3,589 of the
  hour-off months' 9,319 VMS pings as impossible jumps.
- **The period** (script 03). The residual |shift − the period's median| in the vessel-months found off:

  | months | lag per month | lag per week | lag per day |
  |---|---|---|---|
  | an hour off | 1.5 min median, 5.4 at 90 % | 0.6 / 2.1 min | 0.3 min |
  | off by minutes | 0.9 / 3.7 min | 0.6 / 1.7 min | 0.4 min |

  Weeks with 5 or more judged pings hold 94-96 % of these months' judged pings, and days 85-89 %. Over every year,
  7,305 vessel-months, 4,106 vessel-weeks and 3,748 vessel-days hold 10 or more judged pings.
- **The tag pass** applies a lag table through `rb_add_ping_time(lags, period = )`, one period for the whole table. A
  ping takes the unit of its delivered time.

**Assumed:**
- that a VMS unit's clock error is one value over a week (the drift is about 2 min a week);
- that STK's AIS stream stays the reference. It is stamped at receipt (plan 059 §1), so an on-time VMS unit sits about
  0.8 min ahead of it, and plan 059 harmonizes to the reference, not to true UTC;
- that a vessel's VMS and AIS streams are one hull. They are one STK mobile id for vids 975 and 1809, and this is not
  checked for every vessel; the key's own audits stand behind it (plan 009);
- that 300 m and 2 kn judge as well in every year as on the three vessels checked.

## 1. The method, in ramb: the shift onto the reference's track

A third method for `rb_create_ping_lags()`, `method = "track"`, generic for any stream held against a reference that
moves. Each ping of the stream:
- is placed on the reference's track (segments between consecutive pings of at most `max_gap_s`, moving over `kn[1]`)
  by the shift within ±`max_lag_s` (default 2 h) that brings it nearest, projected onto each segment, so the shift is
  to the second;
- is judged where the reference moves at the ping's own time and the fit is within `max_dist_m` (300 m).

The ping's own speed is not used, so a stream with no speed, or an unreliable one, is judged as well. A unit's lag is
the median of its judged pings' shifts, with its quantiles. `pairs` counts its judged pings, and the outcomes are as
today (`min_pairs`: 10 for this method, measured above). `dist_zero_m` and `dist_lag_m` are the medians at no shift and
at the lag. It stays lazy at the flow's scale: the study's `01_scan.R` is the prototype (a join on vessel and hour
bucket, 1-3 s a year on the store). It is checked against the study's per-ping shifts on 2007 and 2017, to the second.

## 2. The check, in fishycode: STK's own streams by week, then by month

`curate/checks/ais_feed_clock.R` keeps plan 059's method for the commercial feeds. For STK's own streams it adds the
track method:
- by vessel-week where the week holds `min_pairs` judged pings;
- else by vessel-month;
- else the unit's outcome as today.

The output gains `method` and the period's unit (`week` or `month`), so every unit still lands in one outcome. The
whole cascade is in the check, and the tag pass reads its result.

## 3. The tag pass and the flag

- **The lag.** A ping of a unit with the outcome `offset` is moved by its unit's lag, as plan 059 moves astd's. Its
  `lag_basis` is `track` (ask e), so the audit can tell the two methods apart.
- **The periods.** The lags now come in two periods, so the tag pass must take a lag table whose rows carry their own
  period (ask f).
- **The flag.** A VMS ping whose unit cannot be judged keeps `lag_basis` `unmeasured`: the flag the maintainer asked
  for, already documented in `docs/data-dict.yaml`. Today a vessel-month with the VMS stream alone is `one stream`, so
  `none`, which reads as "nothing to correct". The scan shows these clocks can be an hour off, so ask c proposes
  `unmeasured` for them.

## 4. The rebuild

From `check_ais_feed_clock` down, as plan 059's: the tag pass, the clean, the port calls, the voyages, the links, the
trail and the user tables, about 1.5 h; `ais_catch` and the audit left (decision 261). It is prepared as
`before.R` / `build.sh` / `after.R`. Expected:
- the VMS pings in judged weeks on the AIS track within ±3 min, checked by rerunning the study's scan on the store;
- fewer VMS pings whacked in those weeks (up to the 3,589 above, and part of the minute-off months');
- `lag_basis` `track` on about 70 thousand pings, and `unmeasured` on the lone VMS months if ask c is yes.

## 5. Steps

1. **ramb:** `rb_create_ping_lags(method = "track")` with its tests, checked against the study's per-ping shifts;
   timed on one year; a ramb release, installed from GitHub.
2. **ramb:** `rb_add_ping_time()` takes lags whose rows carry their own period (ask f), with tests.
3. **The check in scratch**, on 2007, 2017 and 2019: STK's VMS stream and its own units (ask d) by week then month.
   Every unit in one outcome, the study's scan rerun on the scratch tag pass.
4. **The rebuild** (§4), prepared and run on the maintainer's go.
5. **A decision record.** TODO 180 closed, `stk_vms_clock.yml` repaired, the data dictionary's `lag_basis` with
   `track`.

## 6. What it does not do

- It repairs no VMS ping without a moving AIS track to judge it by: 2.45 M pings, flagged.
- It leaves plan 059's method for the commercial feeds as built.
- It does not touch STK's AIS stream's own receipt delay (TODO 117, `stk_receipt`), which would change the reference
  itself.

## 7. Asks

- a. **The period:** a week, falling back to the month (recommended: a third of the month's residual, nearly all the
  coverage); the month alone, as for astd; or a day (finer, with 85-89 % of the judged pings).
- b. **Which units move:** every unit `offset` by plan 059's rule (`lag_min_s` 10 s, recommended: one rule for every
  stream). This also moves the on-time VMS units onto the AIS stream's receipt clock, about 0.8 min, an estimated
  0.9 M pings. The alternative is only units beyond 3 min (the defect alone, about 70 thousand pings).
- c. **The lone VMS months** (2,508 vessel-months `one stream`, 443,604 pings): `unmeasured` (recommended: the scan
  shows these clocks can be an hour off), or `none` as today.
- d. **STK's own units** (`stk_unit`, 10.2 M pings, no unit ever measured): judged by the same method in step 3
  (recommended), or VMS alone.
- e. **The basis value:** `track` (recommended), or `measured` with the method only on the check's table.
- f. **Mixed periods in the tag pass:** `rb_add_ping_time()` takes a per-row period (recommended, generic and small),
  or the check also writes a lag table by day for the tag pass to read with `period = "day"`.
