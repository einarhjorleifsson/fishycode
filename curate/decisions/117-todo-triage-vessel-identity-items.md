# 117 — TODO 17, 21 and 23 leave TODO.md; 24 and 25 are re-measured

*2026-10-17. Written by Claude (AI-assisted) at the maintainer's request, who asked of each item whether later work
already covers it and dropped 21 as out of scope. Measured read-only on `$FISHYDATA` as it stands: the vessel tables
of the rebuild of 2026-10-16 (decision 112) and the `once` project's check files of 2026-10-09. Nothing was built.*

## TODO 17 — the full review of the STK vessel match: carried by later plans

The review the item asked for is done or planned elsewhere: the independent audit (plan 009, TODO 25), the key against
the refreshed archive (plan 016 §4 step 7), the foreign candidates on the same vids (plan 021 step 7) and STK mined
whole (plan 022 §3). What the item still held:

- **`TFUT` and `TFPH` resolve.** `TFUT` is vid 2173 on MMSI 251017000, as plan 016 §2 i found. `TFPH` is vid 2904
  on 251277000 in `curated/vessel/mmsi.parquet`, and the key gives mid 101439 (`glid` TFPH) to 2904 with that MMSI
  from 2018-03-15 (`segment: physical`).
- **The 88-vid gap survives the refresh.** Of the key's 1,217 vids below 3700, 88 have no MMSI anywhere in the
  rebuilt `mmsi.parquet` (649,361 pings), the same count plan 003 §4.7 gave. Plan 003 counted below 3700 only: the
  Icelandic vids above 4999 add 42 of 1,278 (22,626 pings). So 130 Icelandic vids, 671,987 pings. The data refresh
  the item asked of the maintainer happened and did not close it. The route left is co-location (plan 022 §3, point
  8), and it is noted there.

## TODO 21 — GFW effort against STK: out of scope

Dropped by the maintainer on 2026-10-17. GFW's effort grids are activity data, and judging another provider's effort
is not this project's aim. The two zips (`mmsi-daily-csvs-10-v1-5-2018.zip`, `fleet-daily-csvs-100-v2-2020.zip`) stay
where they are, in `~/garbage/vessels_from_home-haf-einarhj-stasi-fishydata-dataraw/`, and are not moved into
`$FISHYDATA`. GFW stays an identity source (`sources/gfw/`, plan 021).

## TODO 23 — SKB pleasure craft: half built, the rest is TODO 63's

- **The registry half is built.** `vessel.parquet` has 203 rows with `register` "skb", vids 100002–102772 (plan 016
  §5, option B; `reference/vessels/registry.R`), since the rebuild of 2026-10-16. The exclusion the item asked about
  is now this encoding. Decision 112 does not mention it, so plan 016's own decision record (its step 8, TODO 63)
  states it.
- **The key half is not.** The frozen key holds 179 SKB mobile-ids (357,642 pings), 178 of class "vessel" and 1
  "unknown", none with a vid. They get vid 100000 + n and the class pleasure craft at the key redo of plan 016 §4
  step 7, and plan 016 §8 checks that every SKB fix reaches the trail. Both are TODO 63's, which now says so.

## TODO 24 — landed but no AIS: stays, on new numbers

`ais_key_landings` reads the cascade, not the key, by design (decision 053: it audits the cascade's own claims, and the
key's segment table uses landings as evidence). Its `landed_but_no_ais` now lists 308 vids, not 83:

| | vids |
|---|---|
| foreign (3700–4999), no key row | 148 |
| in the key, heard in the union (44 Icelandic, 9 foreign) | 53 |
| Icelandic, no key row, no ping from any provider in `staging/ais/ping_union` | 107 |

The 107 are 96 registered vessels and 11 landings placeholders. Of the 96, 9 have an MMSI in the archive, 67 last
landed in 2013 or later, 31 are under 8 m and 24 are 15 m or more. The ASTD scan by vessel name the item proposed is
withdrawn: names are never used to match (maintainer, 2026-09-29). The MMSI route is already taken, because the union
takes ASTD, astdB and EMODnet pings by MMSI and none of the 107 is there.

## TODO 25 — the key audit: stays, re-counted

On the `once` project's files of 2026-10-09, `ais_key_audit_discrepancy` has 402 rows on 239 mids, none reviewed:
125 `w1_other_vid_on_mid`, 81 `split_candidate_review`, 64 `mid_outside_hull_life`, 63 `two_vids_in_sequence`, 42
`split_candidate_strong` and 27 `contradicted_by_two_witnesses`. The ledger has 840 vid-claiming rows that no witness
reaches (6.84 M pings), against 884 when first built. `ais_key_coverage` holds 31,512 pings in 344 stretches, largest
4,962. The review belongs with the key redo that plans 016, 021 and 022 also name.
