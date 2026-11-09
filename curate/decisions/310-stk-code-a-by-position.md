# 310 — STK's code `A` resolved by position: one stay at Akureyri was two port calls

*2026-11-09. At the maintainer's word: "Yes, check it" (the check of STK's placeholder positions, which found the
overlaps), "Do this task here" (the trace) and "Yes, A by position". Measured and written by Claude (AI); no person has
checked the counts. Studies: `$FISHYDATA/archive/2026-11-09-port-call-overlaps/` (its README holds every number) and
`$FISHYDATA/archive/2026-11-09-event-placeholder-positions/`.*

## Why

The live store's port calls (built 2026-11-08) hold 4,940 pairs of one vessel's calls that overlap in time at two
different ports, on 313 vessels, all but 7 in 2007-2013, every pair under 10 km apart. Decision 296 counted 39. Its
query took only a second call starting later, and only pairs in which neither call rests on an STK event pair alone,
so it missed the rest.

One stay is made twice:
- STK's arrival and departure form a pair, which makes a call at the port their code names;
- the same two events, as presence (`rb_create_port_calls(presence = TRUE)`, plan 048 §7.3), are pings inside a
  neighbouring port's polygon, and the dwell rules make a second call there over the same span.

Calls at two ports are never merged. The event judge passes the events, since its `other_port` test fires only beyond
2 km of the code's port. In 3,834 pairs the two calls have the same span ("twins"). No ping is duplicated, and the
voyages either side follow the call by pings 98 % of the time. The pair's call is a second row for a stay the track
already has, and it doubles the port time in any sum over the calls.

4,562 of the pairs (210 vessels) are an event pair at IS-KRI over a call at IS-AKU, polygons 0.5 km apart: STK's code
`A`, set to IS-KRI by `overrides/stk_hid_pid.csv` on 2026-10-01 with the caveat that "most events look like vessels
passing toward Akureyri". Four witnesses place these stays at Akureyri:
- **the events' positions**: of `A`'s 59,925 arrivals (all to 2013), 44,561 lie inside IS-KRI and 15,211 inside IS-AKU;
- **the track**: with the events' presence withheld (the study's run C), the vessels' own pings near IS-AKU still make
  2,318 calls there, under IS-KRI's pairs;
- **STK's own numeric port**: every one of `A`'s 94,251 events in STK's voyage table (`tilk_stk`, 2003-2013) names a
  port that `port.parquet` maps to IS-AKU;
- **the landings**: they name no IS-KRI at all, so they cannot choose between the two ports.

## What was chosen

`A,BY_POSITION` in `overrides/stk_hid_pid.csv`, as THH and THO already are: an event of code `A` takes the polygon it
lies in, and a departure in none takes the port of the arrival before it (decision 290).

The study's run E measured it through production's `sources/stk/event.R` and `curate/port_call.R` on a scratch store:

| | port calls | overlapping pairs | IS-KRI calls | IS-AKU calls |
|---|---|---|---|---|
| live | 1,668,927 | 4,940 | 5,811 | 31,875 |
| `A` by position | 1,664,545 | 379 | 1,016 | 32,288 |

It replaces 10,242 of the live store's calls with 5,860. The records on the replaced and the new calls:

| calls | landing at their own port | fishing day inside |
|---|---|---|
| the new ones | 24 % | 1.2 % |
| the live ones they replace | 13.5 % | 1.3 % |
| every event-pair call of the live store | | 0.89 % |

Further effects:
- 498 of `A`'s events lie in no polygon and have no arrival to inherit from, so they lose their port.
- The union keeps an arrival inside its own port, at no marker, as a fix: 14,803 more of 2007-2013.
- STK's voyages (`sources/stk/voyage.R`) and the quota trips (`sources/quota_trip/convert.R`) read the same table.
  Where a code gives no port they take STK's numeric port, which for `A` is IS-AKU.

The change is in the repo only. The store is built from `stk_hid_pid` down, through the union, with TODO 182's rebuild
and the maintainer's go.

## What it leaves

- **379 overlapping pairs.** IS-REY over IS-VID 200 (20 vessels: Reykjavík's code `R`, whose 9,695 arrivals of
  2007-2013 lie inside the 0.002 km² Viðey polygon, itself an override; there the code looks right, and the polygon is the
  question), IS-SNA and IS-REY 88, IS-AMG and IS-OLV 41 (decision 296's residual, where the records side with the pair),
  IS-FLA over IS-SUU 8.
- **No guard in ramb** keeps one stay from becoming two calls at neighbouring ports over its own events. Withholding
  presence alone (run C) does not do it: the track's own pings then make the second call.
- **The placeholder rule** for `curate/port_call.R` (no presence from a position beyond ±180°, ±90° or at 0,0; 786 calls
  on 141 vessels, measured in the other study) waits on the maintainer.
- **Decision 296's "39 overlapping pairs"** is that subset, not every overlap.
