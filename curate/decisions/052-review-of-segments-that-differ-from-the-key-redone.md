# 052 - The review of segments that differ from the key, redone on the current table

*2026-09-30. Supersedes 048 in part. Analysis by Claude (AI-assisted); reviewed rows are the maintainer's to confirm.*

The table now has 128 segments that differ from the key or fill a mobile-id the key left empty (048: 118; 2,515,239 pings, 1.4 %). Same set
logic as 048, but the evidence was **redone with W1's own definition** - the vid's other-provider ping within 5 minutes, within 2 km, scored
per opportunity (a moving STK ping that had any ping of the vid within 5 min) - instead of 048's nearest-ping-within-6-hours test, which
scores a sparse provider as a failed match.

## What changed the verdicts

- **048's "fits only partly" was mostly the 6-hour test.** Of its 12 + 16 partial or flagged physical segments, 20 confirm at 0.83-1.00
  (median 0.1-0.4 km): mids 100137 (1136), 101967 (2730), 101078 (2549), 103072 (2943), 101763 (2500), 100512 (1599), 100010 (2328), 103007 (2110),
  112543 (2730), 101779 (2593; the key's 2842 is 0.00 at 290 km), 100645 (2310), 121684/121685 (1932), 140620 (2500), 128996 (2499, 7386). Accepted.
  Mid 100137 and 101967 (the 2013 "device mismatch" pair of 046) are the same: 1.00 over their whole segments.
- **A vid that matches in every one of its (few) opportunities beats a denser vid that matches about half the time** (the pattern of mid 103750,
  decision 051): the denser vid is a companion. Applied to 101280 (key 1849: 100 % in 2014-2016; table 1985: 52-58 % of 5,000 opportunities),
  139705 (key 7850: 100 %, 92 %; table 3025: 19-49 %), 118744 (key 7787: 77-82 % of 379; table 7871: 49-69 % of 2,181).
- **A physical track outranks a logbook.** Four logbook-named segments contradict a key vid whose own AIS fits: 146259 (key 3037 100 % of 1,071
  opportunities; table 2340 0 % at 46 km), 100831 (key 6192 100 % of 123; table 6147 0 of 3), 100416 (key 6116 100 % of 97; table 6072 20 % of 10),
  124654 (table 7316 fails at 19-32 % of 199; key 7804 has only 6 opportunities, all hits - the table's vid rejected, the key's unverified).
- **The registry lifetime (Hreidar `yh1`/`yh2`) is not reliable as an "alive" test.** Mid 133558 -> vid 2173 (253,112 pings, 2019-) was marked "did not
  exist" because `yh2` is 1995, yet 2173 has been on the main register since 1992-12-28, landed on 2026-04-07, and the annual register lists its
  call sign TFUT in 2021-2022. Accepted. (Consistent with the maintainer's note that the registry is not 100 %.)
- **A measured track can precede registration.** Vid 3037 is with mid 146259 from 81 days before it was registered (sea trials, 100 % of 1,071
  opportunities); the registration-date guard in `ais_key_segments.R` now exempts reviewed rows.

Seven reviewed rows were added to `overrides/ais_key_segments_reviewed.csv` (146259, 100831, 100416, 139705, 101280, 118744, 124654). After the
rebuild the table has 121 differing segments (2,394,897 pings, 1.3 %); vessel-months AIS hears but the table does not assign fell from 362 to 232.

## Still for a person

- **Device mids carried by a vessel - decided 2026-09-30: not vessels, link kept.** The segment table gains `entity_class` (the key's) and `device`:
  a mobile-id is a device when its own identifier is an MMSI of class 941xxxxxx, 99xxxxxxx or 97xxxxxxx. Ten mids (117104, 117324, 119123, 119842,
  120323, 121684, 121685, 128996, 131663, 140620; 13 segments, 59,990 pings) are marked. Each **keeps its vid** - the vessel that carries it - and a
  consumer of vessel pings filters on `!device`. `ais_key_vessel_recall` does not count a device as its carrier reporting. Their partial W1 fit
  (0.55-0.84) is expected, since a gear tracker only rides its boat while deployed. Four more `unknown`-class mids with meaningless ids (100881,
  101763, 150520, 149853) are not flagged: no evidence they are devices.
- **No independent test:** 100112 (registry 2277 vs key 2502, 24,761 pings, no AIS for either), 101223 (table 2718 borrowed from a neighbour vs key 971,
  8,219 pings), 102182 (table 6712 by logbook for 2007-2023, 30,847 pings, vs the key's 6806 whose track fits 82 % of 335 opportunities - an unresolved
  conflict for 2007-2012, before any AIS), 143852 (table 1500 at 48 % vs the key's 1511, untestable), and a tail of registry or continuity
  segments of under 1,600 pings. The annual register agrees with the table for seven of the registry-sourced ones (100606, 100656, 100880, 101174,
  101334, 103284, 133558).
