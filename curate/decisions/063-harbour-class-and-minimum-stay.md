# 063 — A harbour class per year, and a minimum stay that depends on it

*2026-10-01. TODO 33 started; plan 011 §3.6. The class table is built; the minimum stay per class is built as a parameter and
tested; the default is unchanged (4 h for all), so `curated/ais/harbour_stay` and the voyages are as in decision 061.*

## What was built

`reference/ports/harbour_class.R` → `curated/reference/harbour_class.parquet` (target `harbour_class`): one row per `einar`
harbour and year 2007–2026 (159 × 20), class from the `I`→`U` pairs (STK, `io_ok` and kept by `ping_clean`): `landing` (≥ 25 % of
pairs reach 4 h), `marina`, `flicker`, `transient`, `sparse` (< 30 pairs), `no_events`; `overrides/harbour_class.csv` (empty, header
only) re-enters as an input and wins (`basis = recorded`); cargo, no-pier and mixed can only come from it. **Period design is provisional:**
each year pools the pairs of the year before, the year and the year after. Result: in 2024, 78 landing, 23 transient, 2 flicker, 1 marina, 26
no_events, 29 sparse; **3.4 % of judged year-to-year steps change class**. Anchors behave: Reykjavík, Akureyri, Ólafsvík, Dalvík and Hornafjörður
`landing`; Árskógssandur, Hrísey, Kristnes `transient`; Njarðvík changes with the data (landing 2010, flicker 2016, transient 2022, 93,000
pairs a year); Akureyri 2010 has only 30 pairs (its events carry another code that year). The class rule's thresholds are the plan's first cut,
not tuned further.
`harbour_stay.R` now takes the minimum stay per harbour and year: `STAY_G_LANDING` at a `landing` harbour, `STAY_G_H` (4 h) elsewhere;
`STAY_G_LANDING` defaults to `STAY_G_H`, and with that default 2019 reproduces the current stays exactly (82,448 of 82,448).

## The test: lower the minimum at landing harbours only (all years, proxy of decision 062)

| | stays | landings with a stay, same / any | landings with no stay | added stays: landing at that harbour | shared voyages, static gear |
|---|---|---|---|---|---|
| 4 h everywhere (current) | 1,457,657 | 92.8 / 95.5 % | 40,982 | – | 6.96 % |
| landing 3 h | 1,486,754 | 93.5 / 96.1 % | 35,057 | 38 % of 28,225 | 6.03 % |
| landing 2 h | 1,528,400 | 94.3 / 96.8 % | 28,520 | 35 % of 69,881 | 4.85 % |
| landing 1 h | 1,624,927 | 95.3 / 97.6 % | 21,792 | 28 % of 167,201 | 3.24 % |
| *global 2 h (062)* | 1,540,538 | 94.3 / 96.9 % | 28,219 | 31 % of 81,892 | 4.78 % |
| *global 1 h (062)* | 1,695,840 | 95.3 / 97.6 % | 21,374 | 20 % of 237,958 | – |

- The landing class holds nearly all of the gain: at 2 h the coverage is the same as the global 2 h with 12,138 fewer stays; at 1 h, 70,913 fewer
  stays for the same coverage and a better landing rate on the added ones (28 % against 20 %). Per landing recovered: 3 h 4.9 added stays,
  2 h 6.4 more, 1 h 14.3 more.
- **By gear class of the logbook trip** (shared voyages, 4 h → landing 2 h → landing 1 h): static 6.96 → 4.85 → 3.24 %, towed 4.65 → 3.31 → 2.99 %,
  jigged 3.06 → 2.88 → 2.78 %. Static gear gains most, as expected from small vessels that set and haul or are only logged at the haul.
- Static gear is the case where the logbook is a weak yardstick (memory `static-gear-logbook-recording`: often only the haul is logged,
  the set is a trip with no record), so the numbers for it are indicative. A check on the 331 vessels with both a set and a haul time
  (40,614 stations): 2.1 % of stays of 4 h or more already fall between a station's set and haul, and 2.4–2.5 % of the added short stays do,
  so the added stays are not concentrated in the set-and-return pattern; the sample is thin.
- Not pursued, by the maintainer's instruction: a minimum depending on gear or vessel size.

## Recommendation, not applied

`STAY_G_LANDING` = 2 h: recovers 12,462 landing days (30 %) and takes static-gear sharing from 7.0 to 4.9 % for 70,700 more stays (+4.9 %),
without the 1 h blanket cost. It needs `harbour_stay`, `ais_trip`, `trip_voyage` and the trail rebuilt, so it waits for the maintainer.

## Not decided

The value (2 h or 3 h); the period design of the class (the 3-year window is provisional); the reviewed overrides: `IS-HRN` Hornvík (`no_pier`),
Helguvík (`cargo`), `IS-KRI` (`A`, mostly transit); the 3 STK codes with no polygon (`VIS`, `MAN`, `TMY`) and `STO`.
