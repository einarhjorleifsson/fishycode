# 056 - The stretches that awaited a person

**Status:** done 2026-09-30. The last open list of plan 009: segments the evidence could not place (`vid` NA). Follows 055.

There were 94 such stretches on 85 mids, **88,744 pings** (0.05 % of STK). 73 were "no evidence, neighbour did not exist then" (the mid's first pings predate the vessel
the key names), 21 a continuity stretch with no vid. For each, the candidates were gathered - the cascade's vid, both neighbouring segments, every vid W1 confirmed in
the stretch's months, the registry holder of the mid's own MMSI or call sign, and the annual register - and each was tested on its own AIS track (the vid's other-provider
ping within 5 min and 2 km of the mid's moving pings, scored per opportunity). Only 19 of 96 candidate pairs have any AIS to test.

**Placed: 49 stretches, 49,638 pings** (49 mids), as reviewed rows in `overrides/ais_key_segments_reviewed.csv` (an input of the segment table; they are exempt from the
registration-date guard, which is what held them back):

| Basis | Stretches | Pings |
|---|---|---|
| E1 - the vid's own AIS within 2 km in >= 90 % of >= 10 opportunities (mids 101083 -> 2870 340/340, 101078 -> 2500 69/69, 141432 -> 3005 86/86 ...) | 8 | 15,752 |
| E2 - the mid's **own** identifier (MMSI or call sign) is that vid in the registry, the key agrees, and the stretch starts <= 365 days before its registration (mids 149520 -> 3059, 140664 -> 2983, 140480 -> 3003 ...) | 23 | 32,226 |
| E3 - the mid's first pings <= 365 days before the vid's registration, the same vid continuing from the registration day (key and next segment); no AIS to test | 18 | 1,660 |

Nearly all are a **new vessel's transponder running before the registration** (commissioning, sea trials): 64-365 days, median ~150. That is the same pattern as vid 3037
on mid 146259 (decision 052). Where a test exists it agrees in every case but one too thin to count (mid 129002, 4 opportunities, 0.50).

**Left: 45 stretches, 39,106 pings** - deliberately not placed:
- 28 stretches, 31,634 pings: the candidate was registered **more than a year after the stretch starts** - more than commissioning explains, so more likely an earlier hull or an
  unknown vessel. The big ones: mid 108582 (8,991 pings, 1,507 days before vid 7703's registration; a 5-opportunity test is all hits, too few), 100804 (8,243, 1,750 days),
  100066 (3,773, 2,743 days), 101032 (1,367). An identifier that matches a vessel registered 6-10 years later is not evidence for it (a call sign is reused).
- 8 stretches, 7,123 pings: no candidate vid at all (mids 139505, 146481, 142020, 142936, 146731 ... recent mids with no registry or key match).
- 9 stretches, 349 pings: a candidate with no test and no close registration; negligible.

Nothing here decides the bigger question of where an AIS transponder sat before its vessel existed; the placed stretches are the ones where the vessel itself is the only sensible
answer. The key changed (49,638 more pings on a vessel), so the targets downstream of it are outdated again; they were not rebuilt here.

## Rebuilt and verified, 2026-09-30

The targets downstream of the key were rebuilt on the new key (whole run 30 m 31 s: union 1 m 52 s, `stk` 57 s, `ais_ping_tag` 2 m 46 s, `ais_ping_clean` 6 m 12 s,
`ais_trip` 8 m 51 s, `trip_voyage` under 1 s, `logbook_sensor_gps` 9 m 32 s; nothing outdated afterwards). STK staging now has 181,792,892 rows against the segment
table's 181,792,889 pings on a vid (3 apart); no gear-device mid is in it; union -> tagged -> clean 543.78 M -> 543.78 M -> 540.58 M (0.59 % dropped); mids
103750 -> 2022, 146259 -> 3037, 149520 -> 3059 (49,528 pings), 140664 -> 2983 and 101083 -> 2870 (6,549 pings, from 2013-09-18) are in staging with the intended
vids; 720,330 trips for 2,763 vids. The 39,106 pings still awaiting a person are not in the vessel pings.
