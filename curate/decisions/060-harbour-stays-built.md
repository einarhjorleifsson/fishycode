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
  neighbouring harbours; a landing's `pid` is not the stay's `pid`.** `IS-HOR` (Hornafjörður): 3,165 landing
  dates, 14 % of its landings, have no stay at all (probably under 4 h); not examined.
- **Events:** in 2019 they add 1.7 % more stays, and the ping and event boundaries agree (median 0 s at the start,
  72 s at the end). 2017+ precision (share of stays with a landing): `both` 79 %, `ping only` 71 %, `event only`
  45 % (11,128 stays, 2 % of the total). Events corroborate; as a source of new stays they are weak.

## Not decided

Whether `event only` stays enter the voyages (Phase 4 can filter on `evidence`; recommended not to). The 2 km
radius and 4 h are one value for all harbours, the profile is TODO 33. A pass-through guard is not needed for the
general rules (a transit has no ≥ 4 h gap) and is moot for event pairs (≥ 4 h by construction). Foreign
harbours have no `einar` polygon and no stays. `rule` here is the plan's `basis` column; the name `basis`
stays what AGENTS says it is (`reconstructed`).
