# 062 — A lower stay minimum recovers landings, at a falling price per stay

*2026-10-01. Plan 011, after Phase 4 (decision 061). A test; nothing was rebuilt, `curated/` still holds the 4 h stays.*

## Method

`harbour_stay.R` was run for the whole period with the minimum stay `G_H` at 4, 3, 2 and 1 h (`STAY_G_H`, test hook; no write).
Event-only stays left out, as in the voyages. Stay-level proxy of the shared-voyage residue: a voyage is the sea between two
consecutive stays, each afli / fs_afladagbok trip (2008–2025) is linked to the voyage it overlaps most, as `link_trip_voyage.R`
does. At 4 h the proxy gives 4.94 % / 4.27 % against the real 5.0 % / 4.2 % (decision 061), so the proxy is good enough to
rank the options; it ignores the 10-ping rule and the year split. Landing coverage is as in decision 060.

## Result

| minimum stay | stays | shared voyages afli / fs | landings with a stay, same / any harbour | landings with no stay | added stays: landing at that harbour |
|---|---|---|---|---|---|
| 4 h (current) | 1,457,657 | 4.94 % / 4.27 % | 92.8 % / 95.5 % | 40,982 | – |
| 3 h | 1,490,527 | 4.39 % / 3.78 % | 93.5 % / 96.1 % | 34,903 | 34 % of the 31,886 added |
| 2 h | 1,540,538 | 3.80 % / 3.21 % | 94.3 % / 96.9 % | 28,219 | 31 % of 81,892 (29 % of the 50,006 between 2 and 3 h) |
| 1 h | 1,695,840 | 3.11 % / 2.29 % | 95.3 % / 97.6 % | 21,374 | 20 % of 237,958 (14 % of the 156,066 between 1 and 2 h) |

Stays of 4 h and over keep a 62 % landing rate in every run, so the old stays are unchanged; only stays are added.

## Reading

Each step recovers about 6,000–6,800 landing days (a stay now exists) and takes about 0.6–0.7 points off the shared voyages,
but costs more stays: 3 h adds 32,870 stays (5 added per landing recovered), 2 h another 50,000 (7 per landing), 1 h another
155,000 (23 per landing). The added stays are mostly stops without a landing (14–34 %), which also cut voyages, so
fragmentation grows (the proxy cannot say how much). 2–3 h is the reasonable range for one global value; 1 h is poor value as
a blanket. The better lever is the per-harbour minimum of TODO 33: a landing harbour can take a lower minimum, a transit or
flicker harbour keeps 4 h. That is not built; the harbour class comes from the `I`→`U` pairs, not from the landings.

## Not decided

Whether to lower the global minimum (2 or 3 h) now, or wait for the per-harbour minimum. Lowering it means rebuilding
`harbour_stay`, `ais_trip` and what depends on it.
