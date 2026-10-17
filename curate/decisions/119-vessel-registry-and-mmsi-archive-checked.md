# 119 — Plan 016 built and checked: the MMSI archive, the vessel registry, and SKB as vid 100000 + n

*2026-10-17. Written by Claude (AI-assisted), on a brief from another session. Plan 016's §8 checks were run
read-only on `$FISHYDATA` as the rebuild of 2026-10-16 left it (decision 112). Nothing was built. `_targets/meta/meta`
has the same md5 before and after.*

## What was built

The rebuild of 2026-10-16 (decision 112, fishycode c166aef) built plan 016's steps 1–6b. The three vessel tables
below carry `fd.commit` c166aef and `fd.dirty` false.

- **`mmsi`** (`reference/vessels/mmsi.R`, a new target): `curated/vessel/mmsi.parquet`, 4,228 rows. 2,846 are vessels,
  1,258 navigational aids, and the rest coast stations, child vessels, test units and SAR aircraft. The sources are the
  four Fjarskiptastofa lists, the three `ops$einarhj` snapshots, `mmsi_icelandic_registry`, Oracle's `vessel_mmsi`, and
  the old archive's hand-set windows. Every row keeps its `sources`, `window_basis` and `basis` (4,223 `recorded`,
  5 `reconstructed`).
- **Two declared corrections:**
  - `overrides/mmsi_broadcast.csv` (`curate/corrections/mmsi_broadcast_unregistered.yml`) holds the broadcast
    numbers of 1357, 2411 and 2935, 251396098's 2015 pings as another boat's, and vid 84's 251066110;
  - `overrides/mmsi_list_errors.csv` (`mmsi_list_errors.yml`) rejects the March list's 251237000 on 1612, moves
    251777340 from 3068 to 3048, and rejects the 2022 snapshot's 251354640 on 7236. In the table, 1612 holds
    251237110 to 2011-01-25 and 3048 holds 251777340.
- **`vessel`:** 7,249 rows, +206 vids (decision 112). `vid` is an integer. 7,046 rows come from Oracle's register
  (`register` "skipaskra") and 203 are SKB (`register` "skb"). New columns: `status`, `foreign` and `register`.
- **`vessel_identity`:** 5,409 rows, +240. It is one row per vid and MMSI period, taken from `mmsi.parquet`, not from
  `vessel.parquet`'s single `mmsi`.
- **Built for the first time:** `vessel_year` (140,940 rows), `vessel_class` (37,926) and `vessel_sign` (29,664).
- **Wiring:** `mmsi_raw` and `vessel_raw` are file targets (decisions 113 and 116).

## SKB: what became of `registry.R`'s exclusion

Before plan 016, `registry.R` dropped every archive row whose number began with "SKB"
(`filter(!str_starts(sknr, "SKB"))`) before it made `vid` an integer. SKB pleasure craft had no vid, so their fixes
never reached the union.

The maintainer chose option B on 2026-10-14 (plan 016 §5). `mmsi.R` encodes each SKB code as vid 100000 + n, and
`registry.R` adds one row per code: `register` "skb", flag ISL, the list's name, and no length or kW. There are 203
rows, vids 100002–102772, on 208 MMSIs. Like 3700–4999, the range is an exception to "a vid is a hull". It names a
registration, which has been reused (SKB905) and can cover a tender (SKB225). The trail marks every SKB fix outside a
logbook record as leisure with `leisure_basis` "skb" (`R/trail_sql.R`).

## §8, check by check

### 1. `vessel.parquet`: `vid` integer and unique, one current MMSI per vid — **pass**

- `vid` is an integer: 7,249 rows, 7,249 distinct vids, none missing.
- Each vid has one `mmsi` (2,771 rows have one).
- 21 MMSIs sit on two vids. Each is a reissued number whose windows do not overlap, such as 251146240: 2450 to
  2010-12-31, then 7839 from 2011-01-01.
- `mmsi.parquet` itself flags 5 vids with two `current` vessel MMSIs:
  - 1357, 2411 and 2935: the official number and the broadcast one. The official windows stay open to 2028-12-24, as
    the lists give them. So 251454110 is not closed at 2017-12-09, as §7 d's wording has it. No ping moves because of
    this: neither 251454110 nor 251439000 is heard after its swap, and 251216110 is never heard.
  - 100122 (two "Þytur") and 100225 (a boat and its dinghy): the SKB codes with two MMSIs in §5.

  `mmsi.R` reports these rather than stopping, and `registry.R` takes the recorded number before the reconstructed one.
  So `vessel.parquet` gives 1357, 2411 and 2935 their official MMSI.

### 2. `vessel_identity`: no MMSI on two vids at once — **pass**

- 2,780 rows have an MMSI: 18 reissued MMSIs, and 25 rows with no vid.
- No two rows of one MMSI overlap. This holds in the table and in the windows as `curate/ais_ping_union.R` opens them
  (first period open at the start, last at the end).

**ASTD pings on 1357, 2411 and 2935** (`staging/ais/ping_union`, provider `astd`). Before is what the old archive could
resolve: it held only the broadcast number of each boat, open 2007-06-01 to 2028-12-24.

| vid | MMSI | which | in the union now | before |
|---|---|---|---|---|
| 2411 | 251439000 | official, 2013-01-03 → 2021-02-27 | 527,096 | 0 |
| 2411 | 251139000 | broadcast, 2021-03-02 → 2026-06-30 | 413,479 (349,724 to 2026-01-31) | the same |
| 1357 | 251454110 | official, 2013-01-03 → 2017-12-09 | 277,339 | 0 |
| 1357 | 251396098 | broadcast, from 2017-12-09 13:49 | 822,729 | the same, plus 45,997 of 2015 |
| 2935 | 251216110 | official, never heard | 0 | 0 |
| 2935 | 251216100 | broadcast, 2017-09-30 → 2026-01-31 | 694,110 | the same |

- 2411 and 1357 gain 804,435 ASTD pings.
- The 45,997 ASTD pings of 2015 on 251396098 (counted in `staging/ais/astd`, deduplicated as the union does) are
  another boat's (§2 b). They now have no vid.
- 2411 also has 1 astdB ping on 251439000.
- **EMODnet:** all 51,735 EMODnet pings of 2017 on 251439000 carry vid 2411.

The gains measured here, at the union stage, add up to 826,836 pings: 804,435 ASTD on 2411 and 1357, 51,735 EMODnet
and 16,663 SKB, less the 45,997. Decision 112 traced +870,664 pings in 2013–2025 in `ping_clean` to
`vessel_identity` by elimination. These gains are of that size. Plan 016 §2 g's smaller vids (3068, 3066, 7900, 9839)
were not counted here.

### 3. `tar_outdated()` shows `vessel` after a change to `vessel_v` or a list — **pass, from the graph**

- `vessel` depends on `mmsi` and `vessel_raw`.
- `mmsi` depends on `mmsi_raw` and `vessel_raw`.
- `vessel_raw` is a file target on `raw/oracle/vessel/vessel_v.parquet` and Hreiðar's sheet. Plan 016 named
  `raw/vessels/vessel_v.parquet`, but the readers have used the dump since decision 111.
- `mmsi_raw` is a file target on the 5 `.xlsx` files in `raw/mmsi/`, the four `ops_einarhj` files, Oracle's
  `vessel_mmsi`, the old archive and the two override files (13 paths). The lists are taken by `input_files()` at the
  top of `_targets.R`.
- A changed list or a changed `vessel_v.parquet` therefore marks `vessel` and the 20 targets below it outdated.
  Decision 116's scratch project tested that a new or rewritten list marks `mmsi_raw` and `mmsi`.
- `tar_outdated()` now lists 63 targets, `vessel` among them (1.0 s). That is decision 116's reason, not a raw
  change: its radix sort changed `mmsi_raw`'s hash. `vessel_raw` is not outdated, so `vessel_v.parquet` has not changed
  since the build.
- No raw file was touched and nothing was built.

### 4. SKB through the flow (option B) — **pass for the MMSI feeds; STK waits for the key redo**

SKB fixes, vid 100000 + n:

| stage | ASTD | astdB |
|---|---|---|
| in the feed, on an SKB MMSI (ASTD's placeholder duplicates removed, as the union does) | 5,333 (5 MMSIs) | 11,338 (74 MMSIs) |
| `staging/ais/ping_union` | 5,325 | 11,338 |
| `ping_tagged` | 5,325 | 11,338 |
| `ping_clean` = `curated/ais/ping` = `curated/ais/trail` | 5,313 | 11,281 |

- The union's set union removes 8 duplicates, and the clean step's generic filters drop 69 fixes, as for any vessel.
  EMODnet's 2017 file has no SKB MMSI.
- The trail holds 16,594 fixes of 75 SKB vids, 2014–2025. Every one is in the trail that is in `curated/ais/ping`.
- None has gear (no landings, no logbook): `fishing_flow_basis` is `none`, `fishing` FALSE and `fishing_flow` NA on all
  16,594.
- `leisure` is TRUE with basis `skb`.
- 15,351 fixes carry `hours` (11,211 h, `effort_basis` derived), and `kw_hours` is NA, since SKB has no kW.
- **The STK half is not done.** The frozen key gives none of STK's 179 SKB mobile-ids (357,642 pings) a vid, so their
  fixes are not in the union. They get vid 100000 + n at the key redo, TODO 25. The key was not redone here.

**No code filters out vids ≥ 100000 by accident.** A grep of `R/`, `curate/`, `reference/`, `products/`, `sources/`,
`docs/` and both `_targets` scripts finds:

- `R/trail_sql.R`'s `vid >= 100000`, which is the deliberate SKB leisure rule;
- range filters that never meet an SKB vid:
  - `vid < 9900` (`reference/vessels/ais_key_cascade.R:542`) and `vid >= 7555 ~ "tourist_angling"`
    (`docs/landings-match.qmd:381`) both read landings, and SKB boats land nothing;
  - `vid < 3700` (`curate/checks/ais_key_reused_callsign.R:70`) is on TF call signs, and no SKB row has a call sign;
  - `vid < 3700` (`curate/checks/ais_key_landings.R:87`) is on the key, which holds no SKB vid.

The last two filters are meant to leave out the foreign range, but they also drop every Icelandic vid from 5000 up.
For call signs, that is 21 of the 1,099 Icelandic vids with a TF call sign. The `TF` test already keeps out the foreign
vids, since none has a TF call sign. For the long-before-landing test, it drops all 1,278 key vids from 5000 up. Both
scripts are `once` key checks, so they are to be fixed when the key redo reruns them. The fix is the `foreign` flag
(§7 c), not a range: the register marks all 1,289 vids in 3700–4999 "Erlent", and 3699 KONGSFJORD too.

### 5. TODO 17's rerun — **done** (decision 117)

## Also found

- **STK fixes carry the frozen key's MMSI.** On 1357, 2411 and 2935 that is the old archive's broadcast number over the
  whole span: 2411's STK fixes from 2007-06-09 carry 251139000. It is a label only, since STK resolves by mobile-id.
  It is §4 step 7's "the key's `mmsi` is attached from the register, not observed", and it changes with the key redo.
- **`check_vessel_activity` does not read `register`.** It lists 41 SKB vids in 93 vid-years, with `suggested`
  "other" in 91 and "aquaculture_service" in 2. §5's table said it should filter on `register`. "Other" is right for a
  boat that never lands, and the check's own header says its port lists are evidence, not a register. Left as is.

## Left

- TODO 63 is deleted. Its SKB key half is in TODO 25's SKB bullet, and the two `vid < 3700` filters are a note
  under TODO 25's bullets.
- Plan 016 §4 step 7, the key against the archive, is TODO 25's "archive" bullet.
