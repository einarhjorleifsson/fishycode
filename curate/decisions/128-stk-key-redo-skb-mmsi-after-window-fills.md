# 128 — The STK key redo of 2026-10-17: SKB, MMSIs broadcast after their window, the coverage fills, and a boundary override

*2026-10-17. The scope and the rules are the maintainer's, asked one question at a time; the code, the scratch runs,
the investigation and the measurements are by Claude (AI-assisted). The frozen key of 2026-10-09 and its checks are
kept in `$FISHYDATA/archive/2026-10-17-key-redo/before/`, with the scripts and the build log. Redoes the one-time fix of decision 075 by decision, as it
requires. TODO 25's first redo; what it leaves is TODO 25 again.*

## What the maintainer chose

1. **Scope.** In this redo:
   - STK's SKB pleasure craft, vid 100000 + n (plan 016 §5, decision 119);
   - the units with no vid whose own MMSI belongs to an Icelandic or SKB vid. The cascade's MMSI step reaches them
     on the rebuilt `vessel_identity` with no new code;
   - the two `vid < 3700` filters, which become the `foreign` flag;
   - mid 108982;
   - `ais_key_coverage`'s fills.

   Not in it: plan 022 §3's 43 co-location units (21 of them carry a vid another unit holds at the same time). They
   stay a review list.
2. **Plan 022 §7 ask 3**, routes M1 and M2: not now. Their hulls are mostly Faroese and otherwise foreign. They wait
   for plan 021 step 6 to give foreign hulls vids.
3. **Plan 022 §7 ask 5**, the review lists: Claude drafts each list with its witnesses and a proposed verdict per row;
   the maintainer confirms. Confirmed rows enter `overrides/` for the next redo.
4. **Mid 108982**: a boundary override, not a general rule.
5. **An MMSI broadcast after its window closed** (asked after the first scratch run): the unit keeps the vid of the
   MMSI's last holder, "unless of course the mmsi were taken up by another vid", with a record of every such pair
   (the table below).

## The code

- **`reference/vessels/ais_key_cascade.R`**, two steps:
  - `skb`: a glid of the form `SKB<n>` (case and a suffix after the number dropped: `skb222`, `SKB009_MF`) is vid
    100000 + n, tier B as `NA_vid`. The 99xx range is a placeholder, as in the landings: `skb9998` (mid 106459) is a
    fixed unit in Reykjavík harbour, 604 pings at speed 0 in 2009-10, and gets no vid.
  - `mmsi_after_window`: a 9-digit glid whose last holder's window in `vessel_identity` ends before the unit starts
    takes that holder, when the archive gives the MMSI to no later one. It needs NA_mmsi's 30 pings. Tier D as
    `afmadur`, its twin.

  Both are exempt from the lifetime flag, as `afmadur` is. The SKB vid is a registration, and its identity windows
  are the lists' dates; the other match lies after its window by construction.
- **`curate/checks/ais_key_segments.R`**:
  - an SKB code is registry evidence for its vid over the unit's whole span;
  - **a reviewed row's edges are cuts.** Before, a reviewed row only replaced the vid of the segments lying mostly
    inside it, so it could not move a boundary;
  - the stretches with no evidence whose neighbour's registered lifetime does not cover them are filled with that
    neighbour, under the source `continuity: neighbour, outside its registered lifetime`, grade D. They stay
    segments of their own, so the source is not merged away;
  - `reg_cut_in_w1_run` flags a segment that starts on a vid's registration day while W1 still confirms the
    previous segment's vid inside it, for review;
  - `agrees_key` is FALSE, not NA, where the cascade has no vid for a stretch.
- **`overrides/ais_key_segments_reviewed.csv`**: mid 108982 is vid 2835 from 2018-04-13 to 2018-07-19. Checked first:
  every week from 2018-03 to the week of 2018-07-16, the mid's STK pings lie 0.00-0.65 km (weekly median) from 2835's
  astdB, and 175-196 km from 7830's. The mid falls silent after 2018-07-19.
- **`curate/checks/ais_key_reused_callsign.R`** and **`ais_key_landings.R`**: Icelandic is `!foreign`, not
  `vid < 3700`, which dropped every vid from 5000 up (decision 119).

## Measured on a scratch `$FISHYDATA` (2026-10-17)

The once key chain was run script by script in its own R sessions, on the real store's inputs linked read-only. It ran
three times: as first written, with struck hulls only, then with the rule as chosen. Nothing in the store was written
(`find -newer`). The figures are from the third run. The once build of the same code on the same inputs is
below.

**STK pings from 2007-06-01, the new key against the frozen one**, by mobile-id and day:

| what the redo does | mids | pings |
|---|---|---|
| same vid | 2,929 | 188,668,283 |
| gains a vid | 275 | 452,325 |
| another vid | 12 | 80,768 |
| loses its vid | 3 | 50 |
| no vid either | 30,223 | 114,567,231 |

- **The gains:**
  - SKB: 217 mids, 185 vids, 388,276 pings. 190 units have the code in glid; the rest broadcast an SKB MMSI.
    369,456 pings are registry (grade B) and 18,820 physical (A): W1 confirms them through the SKB MMSIs.
  - Icelandic vids: 57 mids, 61,988 pings. Plan 016's archive and the rebuilt logbook reach units the old key did
    not. 7 are `mmsi_after_window` (7,262 pings).
  - One foreign unit (2,061 pings).
- **67 of the 185 SKB vids have no row in `vessel.parquet`.** Their codes are in no MMSI list. Every reader joins the
  vessel tables on the left, and the trail marks every vid ≥ 100000 leisure (decision 119).
- **Another vid** (12 mids):
  - mid 108982, 5,029 pings, as reviewed;
  - mostly 2024-2026 handovers the newer trail dump shows. A new hull takes a call sign from its registration day or
    by registry evidence: 3048, 3049, 3058 and 3066 (registered 2025-26), 9850, 7897, 1734 and 7070;
  - TFBR (mid 101759) is 3047 from 2024-12-21 (85 pings), against decision 045's 2025-01-10.
- **Loses its vid:** 3 units with fewer than 30 pings (50 pings in all), listed below.

**MMSIs broadcast after their window: the record.** None has a later holder:
- the archive (`curated/vessel/mmsi.parquet`) holds one row per MMSI;
- the foreign registries hold none of them but GFW, which lists them as ISL;
- where ASTD or EMODnet broadcasts an IMO, it is the hull's own (1743, 1902, 2923, 2926).

Pings are the unit's.

| vid | MMSI | mid | the window ends | unit's pings | where they are | in the key |
|---|---|---|---|---|---|---|
| 2631 | 251582540 | 138795 | 2020-07-20, sold to Norway | 9,234, 2020-08 to 2021-01 | southern Norway, in port | yes |
| 2542 | 251285110 | 138825 | 2020-07-17, sold to the Netherlands | 1,142, 2020-08 to 2021-02 | the Netherlands | yes |
| 2923 | 251609000 | 139364 | 2020-09-11, sold to the Seychelles | 11,860, 2020-09 to 2021-08 | the Netherlands, in port | yes |
| 2507 | 251154340 | 139505 | 2019-06-14, sold to the Faroes | 2,622, 2020-09 to 2022-02 | the Faroes | yes |
| 7543 | 251825240 | 141687 | 2021-04-28, sold to Norway | 2,125, 2021-05 to 06 | southern Norway | yes |
| 7570 | 251477540 | 142020 | 2018-10-03, MMSI cancelled, hull struck, not sold | 1,201, 2021-06 to 2022-07 | west Iceland; astdB hears the MMSI there 2021-24 | yes, **for review** |
| 2998 | 251856840 | 142147 | 2021-02-02, MMSI cancelled, still registered | 437, 2021-06 to 2022-03 | east Iceland | yes |
| 2741 | 251791440 | 142936 | 2019-06-12, registered in Gibraltar | 1,205, 2021-07 to 2026-06 | the North Sea and the Baltic | yes |
| 1743 | 251283110 | 143787 | 2021-06-14, leased to the Norwegian flag, still registered | 6,559, 2021-09 to 2022-01 | the Faroes to Norway; ASTD has IMO 8500886 on the MMSI to 2026 | yes |
| 1902 | 251047110 | 143788 | 2021-08-13, sold to Russia | 3,980, 2021-09 to 10 | Kirkenes, in port | yes |
| 1779 | 251548240 | 144567 | 2021-01-08, sold to Norway | 1,904, 2022-04 to 06 | northern Norway | yes |
| 7695 | 251837870 | 144622 | 2022-03-24, sold to England | 517, 2022-04 to 08 | south-east England | yes |
| 2655 | 251184740 | 146376 | 2022-10-21, sold to Norway | 158, 2023-02 | northern Norway | yes |
| 7884 | 251485470 | 146972 | 2023-03-20, MMSI cancelled, still registered | 53, 2023-06 | north-east Iceland | yes |
| 2926 | 251743000 | 147212 | 2023-06-19, sold to Norway | 126, 2023-06 | Norway; ASTD has IMO 9818632 on the MMSI to 2023-08 | yes |
| 2806 | 251837640 | 148617 | 2021-10-26, sold to Norway | 622, 2023-12 | northern Norway, in port | yes |
| 6473 | 251218840 | 132228 | 2017-12-31, the hull's registry lifetime (still registered) | 103, 2019-01 to 04 | east Iceland | yes |
| 2225 | 251858940 | 146481 | 2008-12-31, the same | 1,669, 2023-03 | Reykjavík | yes |
| 5882 | 251859340 | 146731 | 2009-12-31, the same | 336, 2023-04 to 05 | Reykjavík | yes |
| 2298 | 251232340 | 143928 | 2021-06-01, sold to Norway | 14 | Iceland to northern Norway | no: under 30 pings |
| 7893 | 251861840 | 151532 | 2024-01-08, MMSI cancelled, still registered | 24, 2025-04 | Reykjavík | no: under 30 pings |
| 7898 | 251861740 | 152733 | 2024-10-03, the same | 12, 2025-09 | Reykjavík | no: under 30 pings |

The frozen key had 12 of the 19 by `NA_mmsi`, on the archive's open windows before plan 016 rebuilt it. Each key row
carries its MMSI and the cascade's step names the route. In this table "the window ends" is `vessel_identity`'s `t2`.
The archive's note, and for the last three registered boats the stale `yh2`, say why.

**The coverage fills.** `ais_key_coverage` reports 0 unassigned pings: 3,160 mids with a vessel and 189,158,117
pings. The frozen key left 31,512 in 344 stretches. Now 32 stretches on 32 mids (34,514 pings) carry a neighbour
outside its registered lifetime, 12 of them in STK's start-up years before 2009. By year:
- 2007: 14,310 pings;
- 2012: 13,805;
- 2010: 3,104;
- 2025: 1,707;
- the rest under 1,000 a year.

**Registration-date boundaries inside a witnessed run.** The flag's logic, run on the frozen tables, finds 2:
- 108982;
- 149996: 7076 registered 2024-07-26 while W1 confirms 7897 for two more months.

On the new tables it finds none. 108982 moves by the override. In 149996 the cascade now names 7897, so 7076's
registration day is no longer a cut.

**The segment table, by source** (frozen → new, segments):
- physical 1,653 → 1,657;
- registry 241 → 446 (SKB);
- logbook 172 → 201 and landings 57 → 61, from decision 127's logbook;
- continuity 556 → 580;
- reviewed 58 → 59;
- foreign: kept override 344 → 321, the same vids under stronger sources;
- "a person decides" 33 → 0;
- the fills 0 → 32.

It tiles 3,196 mids and 189,262,200 pings. The 834 pings on no vid are on mids with no vessel at all.

**The checks.**
- The audit: 426 discrepancy rows on 254 mids (402 on 239 before); 1,051 rows no witness reaches (840), mostly
  the SKB units. None is reviewed.
- `ais_key_resolution`: 322 rows on 254 mids (303 on 239).
- `ais_key_landings`:
  - `ais_precedes_landings` goes from 27 to 93 rows, since vids from 5000 up count now;
  - `ais_but_never_landed` goes from 452 to 640, the SKB vids among them, as expected of boats that never land.
- `ais_key_reused_callsign`: 92 rows (71 before).
- `ais_key_twins`: 33 rows, unchanged.

## Built in the once project

- **The run:** `TAR_PROJECT=once`, `tar_make_isolated(names = )` with the 13 key targets
  (`archive/2026-10-17-key-redo/once_build.R`). 19 targets were built: the 13 and their six watchers of main-project
  files. It ran 18:13:56 to 18:19:34 UTC with exit 0; the audit took 180 s and the segment table 48 s. The frozen
  files were copied to `before/` first.
- **Left outdated, by design:** `port_radius`, `sensor_gps` and their two watchers.
- **Stamps:** every file carries fishycode 9cb2f45 and `fd.dirty` false.
- **Against the scratch run:** the key, the cascade, the segment table and the device file are identical (rows and
  order-free hashes). Four checks differ only in columns that pick among ties, which they do in no fixed order:
  - the split candidates' first-ping position and shift;
  - the audit's alternative vid;
  - the twins' own-track distances;
  - and so `ais_key_resolution`, with 323 rows against 322.

  The key reads none of these columns.
- **`ais_key_coverage`:** 0 rows. Its one warning is `min()` over the empty table.
- **The main project:** `tar_outdated()` lists decision 127's 20 targets and the key's own file target.

## Left

TODO 25 carries the next redo:
- the review lists, drafted by Claude and confirmed by the maintainer: the audit's discrepancies, the 43 co-location
  units, the 41 key rows, the 37 `mobile_vid` claims, plan 016's 14 handed-over MMSIs, the 32 fills, LILLÝ (7570);
- the foreign hulls and routes M1/M2 after plan 021 step 6.

TODO 77 builds the AIS chain on this key.
