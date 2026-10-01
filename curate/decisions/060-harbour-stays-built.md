# 060 — Harbour stays are built from the general rules; events add little

*2026-10-01. Plan 011 Phase 3, built in the voyage session. Nothing reads the table yet (Phase 4).*

## What was built

`curate/harbour_stay.R` → `curated/ais/harbour_stay.parquet` (target `harbour_stay`): 1,465,635 stays,
2007–2026, every provider, about 20 s per year. A stay is elapsed time at one `einar` harbour (inside the
polygon or within 2 km of it, retagged here against the current polygons, since `ping_clean$pid` still
comes from the old set), from: two consecutive pings at the harbour ≥ 4 h apart (`tag_then_gap`,
`gap_near_harbour`), consecutive polygon pings spanning ≥ 4 h (`tag_span`), and from 2017 an `I`→`U`
pair that is `io_ok` and kept by `ping_clean` (`event_pair`, decision 059). Seeds are extended over the
contiguous polygon pings and merged per harbour. Events before 2017 are not used; the table still covers
every year because the general rules need no event.
`curate/checks/harbour_stay_logbook.R` → `curated/check/harbour_stay_logbook.parquet` is the yardstick.

## What was measured (logbook and landings as yardstick only)

- **The anchor:** vid 2481 in 2011 has 190 stays against ≈ 185 landings (one voyage today).
- **Stays per logbook trip**, vessel-years with ≥ 20 trips: median 1.14–1.25 in every year 2008–2025;
  48–65 % of vessel-years within ±25 %. This is the same as the bare gap split of Phase 0 (≈ 1.2, 59 %);
  the rules around it (extension, merging, 2 km) did not change the count, and the events do not either.
- **Why above 1:** 76 % of stays have a landing at that harbour on a date inside the stay; the rest are real
  port time without a landing (calls, lay-ups, nights), 8–16 h and > 3 d alike. AIS stays that a logbook trip
  spans are expected; the §6 target (voyages shared by several trips) is measured in Phase 4, not by this ratio.
- **Landings covered:** 92.5 % of landing (vid, date, pid) have a stay at the same pid, 95.3 % have a stay at any
  harbour. The 2.8 pp are neighbouring harbours: landings at `IS-NJA` (Njarðvík) sit in stays at `IS-KEL`
  (Keflavík) (9,526 uncovered `IS-NJA` landings, 53 % of its landings), landings at `IS-REY` in stays at `IS-SNA`/`IS-KOV`
  (Kópavogur, Viðey, Gufunes became their own harbours in decision 058). **The link to the logbook must allow
  neighbouring harbours; a landing's `pid` is not the stay's `pid`.** `IS-HOR` (Hornafjörður) had
  3,165 landing dates, 14 % of its landings, with no stay: **not a polygon problem, a radius problem** (follow-up
  below).
- **Events:** in 2019 they add 1.7 % more stays, and the ping and event boundaries agree (median 0 s at the start,
  72 s at the end). 2017+ precision (share of stays with a landing): `both` 79 %, `ping only` 71 %, `event only`
  45 % (11,128 stays, 2 % of the total). Events corroborate; as a source of new stays they are weak.

## Follow-up: Hornafjörður, event-only stays, and the radius

- **Hornafjörður:** the polygon holds 100 % of its `I` events (code `HFN`). Vessels leave through a long channel
  and the first ping after the silence is farther out: `U` distance from the polygon median 181 m, p90 3.4 km.
  The 2 km radius misses those gap ends. Rerun with `STAY_R_M=5000` (all years, 2008–2025): `IS-HOR` landings
  covered 86.0 → 94.1 %, all landings 92.5 → 93.1 % (same pid), 14,790 more stays, only 15 % of them at
  `IS-HOR` (then Mjóifjörður 1,238, Ólafsvík 1,216, Siglufjörður 556): one global radius is wrong both ways,
  hence the per-harbour `r_m` of plan §3.6, not yet built. The default stays 2 km.
- **Event-only stays** (13,381 in 2017–2025: an `I`→`U` pair ≥ 4 h with no ping-rule stay at that harbour).
  By what the pings do between the two events: silent, the two pings 2–5 km apart, 3,398 stays, **81 % with a
  landing**, 2,701 of them `IS-HOR` (the radius case above, so these are real stays); silent within 2 km, 2,211,
  7 % with a landing (the pings sit under another harbour's tag: `IS-REY` next to `IS-SNA`, `IS-NJA`/`IS-KEL`);
  the vessel left beyond 5 km, 2,350, 39 % with a landing, median 48 h (a missing `U`, the pair spans a trip);
  pings stay within 5 km, 5,422, 22 % with a landing, `IS-NJA` 2,186 (the flicker harbour). So event-only
  is a mixture: real where the radius is too small, false where an event is missing or the harbour flickers.
  Filtering on `evidence` alone cannot separate them; fixing the radius first removes the best part.

- **Is the `U` ping generally far from the harbour? No (checked 2026-10-01).** 1,282,867 real pairs (adjacent `I`→`U`
  at one harbour, ≥ 4 h, both `io_ok` and kept, 2008–2025): the `I` ping is inside the polygon (by construction) and
  the `U` ping is outside it in 82 % of pairs but close: median 94 m, p90 821 m, p95 1.2 km, 2.3 % beyond 2 km
  (pre-2017 3.3 %, 2017+ 1.4 %). Of 100 harbours with ≥ 100 pairs, 91 have ≤ 10 % of their `U` beyond 2 km and 18 have
  a p95 above 2 km (9 above 5 km), together 3.8 % of the pairs. The exceptions are specific harbours: Hornafjörður
  (28 % beyond 2 km, 24,664 pairs, p95 3.4 km), Mjóifjörður (14.5 %), `IS-BRA` (12 %),
  `IS-RHA`, `IS-FAS`, `IS-KLA`, `IS-HVR`; a few p95 values of 20–59 km (`IS-DRN`, `IS-BLO`) are event errors. So the
  pattern is asymmetric (arrival near, departure sometimes far) but it is a property of a harbour, not a rule:
  a per-harbour departure radius `r_out` (p95 of this distance, floor 2 km, cap about 6 km) with the arrival
  end kept at 2 km would cover Hornafjörður without the 14 k extra stays a global 5 km adds. **Built the same day**,
  see the last section.

## Asymmetric radius built (2026-10-01)

`reference/ports/harbour_radius.R` → `curated/reference/harbour_radius.parquet` (target `harbour_radius`): `r_in_m` 2 km
for all, `r_out_m` the p95 of the `U` distance clamped to 2–6 km, **after dropping `U` distances beyond 6 km as bad events**
(with them in, `IS-DRN` and `IS-BLO` would have got 6 km from errors alone). 100 harbours are measured, 8 get more
than 2 km: Borgarnes 4.1, Miðsandur 3.7, Hornafjörður 3.4, Mjóifjörður 3.3, Skálmarnes 3.2, Stafnes 2.9, Brjánslækur 2.7,
Djúpavík 2.6 km. `harbour_stay.R` takes a gap only when its first ping is within 2 km of the harbour and its second within
that harbour's `r_out_m`. `STAY_RADIUS_OUT=same` reproduces the old symmetric rule. Stays rebuilt: 1,468,243 (+2,608 over
the 2 km rule; the global 5 km added 14,790).
- Landing coverage, same pid: 92.5 → 92.7 %, any pid 95.3 → 95.5 %; `IS-HOR` 86.0 → 94.0 %. Stays per logbook trip
  unchanged (1.14–1.25, 50–65 % within ±25 %).
- **Event-only stays 13,381 → 10,385.** The "silent, pings 2–5 km apart" class fell from 3,398 (81 % with a landing)
  to 633 (31 %): the real ones are now found by the ping rules. What remains is 21 % with a landing overall: 2,209 silent
  within 2 km (7 %), 2,349 where the vessel left beyond 5 km (38 %, a missing `U`), 5,194 where the pings stay within 5 km
  (19 %). **Event-only stays are now mostly false; Phase 4 should not use them** (filter `evidence` containing only
  `event_pair`). Events still corroborate: stays with ping and event evidence have the best precision.

## All providers, not only STK (checked 2026-10-01)

The stays are built from `ping_clean`, every provider merged; only the event pairs and the `r_out` profile are STK-only.
By what the pings inside a stay are: 2012 (before ASTD) 100 % STK, median 2 pings per stay (the two ends: the signal is
off in harbour). 2016: 53 % of stays have other-provider pings (median 95), 61 % of those carry `tag_span`; 2019: 70 % (median 62),
2023: 70 % (median 47); STK-only stays remain 22 k a year (vessels with no ASTD). A stay seen only by other providers is rare
(1,294 in 2016, 594 in 2023) and has a low landing precision (21–34 %). A vessel with its transponder on in harbour has no gap,
so its stay comes from the polygon run (`tag_span`), which counts pings inside the polygon only.
Do the continuous-signal vessels slip through? Landings 2016–2025 with no stay: 29,451 of 450,503 (6.5 %). On the landing
date and harbour: 9,517 have no ping in the harbour at all (never heard), 9,520 a run under 1 h, 10,297 a run of 1–4 h
(99.7 % with other-provider pings: short visits, below the 4 h minimum), and only 117 a run of ≥ 4 h. So the polygon-run rule
is not missing continuous-signal stays; the loss is short landing visits (the per-harbour `min_stay_h`, TODO 33) and
harbours where no signal is heard.

## Not decided

Event-only stays: recommended not to use them in voyages (see above); the maintainer decides. The 2 km
radius and 4 h are one value for all harbours, the profile is TODO 33. A pass-through guard is not needed for the
general rules (a transit has no ≥ 4 h gap) and is moot for event pairs (≥ 4 h by construction). Foreign
harbours have no `einar` polygon and no stays. `rule` here is the plan's `basis` column; the name `basis`
stays what AGENTS says it is (`reconstructed`).
