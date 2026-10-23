# 190 — The crosswalk ready for the first vid allocation: a dominant IMO, a reviewed link's IMO, the STK open end

*2026-10-23. Plan 021 step 4, TODO 65. The maintainer approved the four changes on 2026-10-23 (decision 115's note of
that day). The code, the checks and this record are Claude's (AI), written in a session started from another Claude
session, and have not been checked by a person. Checked on a scratch `$FISHYDATA` only. Nothing was built in the store,
and no vid was allocated: the rebuild and the first allocation are the maintainer's (commands below).*

## Chosen

1. **A dominant IMO takes a segment by rule** (`curate/vessel_ais_link.R`). Before this change a segment was held as
   `two_imos` when its feed claimed two or more IMOs whose pings overlap. Now, if one IMO has 99 % or more of the
   segment's IMO pings (`DOMINANT`), that IMO takes the segment. Every other rule still applies to it:
   - a register's IMO comes first. Six of the 176 have one, and in all six it is the dominant IMO;
   - the dominant IMO on another MMSI at the same time still holds the segment (`imo_two_mmsis`, reading 3);
   - a foreign vid's call sign with no vid reached by the IMO still holds it (`foreign_vid_candidate`, reading 5).

   **A modifier, not a basis.** The link's IMO is still the feed's own claim (basis `broadcast`), or the register's
   (`recorded`). The rule only chose among the claims, so the grammar puts it in a column of its own: `imo_flag`
   `dominant`, beside `imo`, as `interval_flag` carries `capped`. A segment with no evidence of its own carries the hull
   of its neighbour with basis `reconstructed`, and it takes that neighbour's flag too, as it takes its `link`. The
   flag is part of what cuts a period, so a dominant year never merges with a clean one. The review table lists each
   such segment as `dominant_imo` (not held), and a new column, `imo_other`, names the IMOs it lost to.
2. **A reviewed link's IMO is its vid's** (reading 4 extended to the reviewed links). A confirmed link in
   `overrides/vessel_ais_link.csv` to a registry vid gives that vid the one IMO its MMSI carries in the link's period:
   from the feed claims that overlap the period, or from an EU or Faroese register period that overlaps it. A reviewed
   MMSI with two IMOs in its period gives none. The pairs join the registry's in `imo_vid`, under the same conflict rule
   (`imo_registry_conflict`). They are not counted as "an IMO in a register" (`imo_in_register`, route 4), since a review
   is not a register. Before this change, an MMSI with a reviewed hull's IMO (the vessel sold abroad, mostly) got an IMO
   hull, and the first allocation would have given it a second vid. The reviewed links' periods are not added to the
   twin test as the Icelandic archive's dates are (reading 3). They are whole years set by the review, not holding
   dates, and they would hold, for instance, 257688000's 2024, the year the hull of 231036000 was sold to Norway. Every
   reviewed MMSI with an IMO broadcasts it, so the twin test by pings covers them.
3. **The STK rows' open end is NA** (TODO 129, decisions 183 and 184). A mid's last stretch, if `d2_is_open`, gets `t2`
   NA instead of `day_after(d2)`. Every other stretch keeps its end, including the two open ones of mids 102543 and
   103872 that a one-day stretch follows. `T_OPEN2`, the script's stand-in for an open end, is now infinity, not
   2101-01-01. The key has stretches that start on 2106-02-06, and with their end NA the check `t1 < t2` would fail on
   them.
4. **The SKB leisure bound** (`R/trail_sql.R`). Leisure basis `skb` is now `vid BETWEEN 100000 AND 199999`, not
   `vid >= 100000`, so the ledger's 200000 + n will not read as SKB boats once the union reads the crosswalk (plan 021
   step 6). Plan 021 §4 defines the ranges. The register would need one more join in the trail's SQL for the same
   answer.

## The 27 MMSIs

The 45 MMSIs that reviewed links put on a foreign vid (3699-4999) are the 50 reviewed MMSIs less the five on an IMO or
Faroese hull. 40 of them carry exactly one IMO in their link's period, with all of their IMO pings. Where a register
gives one, it is the same IMO. The other 5 carry none. No foreign vid has an IMO in `vessel.parquet`, and none of the
40 IMOs is a registry vid's.

28 other MMSIs claim one of the 40 IMOs:
- 26 sat on an IMO hull, unallocated: 30 rows on 23 IMO hulls, since three IMOs are each on two MMSIs (9214484,
  9278258, 8816077);
- 1, 232283576, is held as `imo_two_mmsis` in 2020, its only year: the 166 pings of 9099212 the review of 231235000
  noted;
- 1, 997211593, is not a valid MMSI.

That makes 27 valid MMSIs, the count of 2026-10-17, and 26 of them were headed for a second vid. A first count that
took a reviewed MMSI's register IMOs at any time found three more, which claim 9202455 (ANGO). The register gives that
IMO to 231110000 only from 2017-08, after its reviewed period, so they are rightly left out. Now 27 MMSIs reach a
foreign vid by IMO: the 26, on 23 vids, and 231110000's own 2014, a dominant segment of IMO 8615265, vid 4606's.

## Checked (scratch)

The scratch store held symlinks to the script's inputs as built on 2026-10-22, with `curated/vessel/` and
`curated/check/` real directories. `R_ENVIRON_USER` named it, with the project's UTF-8 locale. Afterwards no file
under the store's `curated/` or `staging/` was newer than the first scratch run.

- **Baseline.** HEAD's script on scratch reproduces the store's crosswalk (655,183 rows) and review (3,030 rows)
  exactly, row for row.
- **The new crosswalk: 655,202 rows.** By all of the old columns, 20,699 old rows are not in the new and 20,718 new
  rows are not in the old. Every one belongs to one of the fixes:
  - **STK: 20,500 rows**, `t2` only, all of them a mid's last open stretch, now NA. Before, 20,491 ended 2028-12-25,
    7 ended 2106-02-07, 1 2032-04-02 and 1 2049-09-09. No other STK column or row differs. No STK row now ends on
    the open-end date.
  - **MMSI: 199 old rows and 218 new, on 187 MMSIs.** Each is a dominant-segment MMSI (161) or an extension MMSI
    (27), with 231110000 in both. No other MMSI changed. The Icelandic rows (2,213) are identical.
    - The extension: the 26 MMSIs' 30 rows keep their periods and change hull from `imo_<n>` to `vid_<n>`, getting the
      vid; 231110000 2014 goes from held to vid 4606.
    - The dominant segments: 169 old rows (164 `two_imos`, 2 `foreign_vid_candidate`, 2 `continued_conflict`, 1
      `imo_two_mmsis`) become 188 new ones. 163 of these are linked with `imo_flag` `dominant` (157 unallocated, 6 on
      a registry vid). The other 25 are held: the held runs split where a dominant year left them, and
      231078000's 2013-2019 rows merge into one held run.
- **The 176 dominant segments:**
  - 172 are linked: 163 to a hull the crosswalk already had (the MMSI's other years or another MMSI), 6 to a registry
    vid (2654, 4606, 1360, 1610, 2750, 2550) and 3 to a new hull;
  - 3 are held as `imo_two_mmsis`: their dominant IMO is on another MMSI at the same time (258052000 2013, 273133100
    2019, 273313560 2015);
  - 1 is held as `foreign_vid_candidate`: 231078000 2015, call sign of vid 3878.
- **The review: 3,030 rows become 2,611.**
  - 419 segments leave it:
    - 407 `foreign_vid_candidate` segments of 40 reviewed MMSIs, all inside their own reviewed period. Their IMO,
      from the feed or the register, is now their reviewed vid's, so the rule computes the vid the review gave, and
      the override replaces those rows as before;
    - 12 `continued_conflict` segments of 257067400, which now carry its dominant 2023 hull.
  - Of the 176 `two_imos` segments, 172 become `dominant_imo`, 3 `imo_two_mmsis` and 1 `foreign_vid_candidate`.
  - Two `imo_handover` segments (235674000 from 2016-08-27, 367157110 from 2023-09-26) take their foreign vid.
  - Noise: ping hours differ by under 1e-12 h on 28 rows (the order of a float sum), and one carried name set is in
    another order (257110000).
- **Plan 021 §7 on a scratch allocation.** The ledger was written to scratch only (379,912 hulls), and the crosswalk
  rebuilt on it. The script's checks held: no feed id overlaps itself, one vid per IMO and one IMO per vid. Also, read
  after:
  - every row with a hull has a vid, and no vid has two hulls;
  - the 293 rows whose IMO a registry vid holds all carry that vid;
  - the rebuild differs from the unallocated build in `vid` and `vid_reason` only.

  `check_vessel_ais_link_routes` runs on the new crosswalk. Its shifts are MMSI-years leaving route 8 (held out) for
  6 (own IMO) and 4 (IMO in a register), and route 4 rows gaining vids. Check 5 (a rebuild with one more ASTD month) was
  not rerun.
- **`allocate_vids(dry_run = TRUE)`: 379,912 hulls (200001-579912), 0 inherited, against 379,932.** The 20 fewer are:
  - 23 IMO hulls gone: the 26 MMSIs, now on foreign vids;
  - 3 IMO hulls new, from dominant segments: 231160000 2013 (`imo_9137466`; its review called 2013 "another hull
    (GULLBERG)"), 257067400 2023 (`imo_8331405`) and 273359480 2025 (`imo_9658288`).

  The other 169 dominant segments go to hulls that are numbered anyway or that are registry vids. Since no ledger has
  been written, the change in which hull gets which number moves no vid.
- **The leisure bound.** No fix carries a vid ≥ 200000:
  - the union: 589,267,384 fixes, the largest vid 100999;
  - `curated/ais/ping`: 580,639,236 fixes;
  - the trail: its 381,320 `skb` fixes are exactly the ping table's fixes in 100000-199999.

  The new condition differs from the old only above 199999, so no output changes.

## Left

- **For the maintainer, in order.** `targets` cannot see a script edit, so the crosswalk is invalidated by hand, after
  the fingerprints:

  ```r
  for (f in list.files("R", full.names = TRUE)) source(f)
  fp <- c(fd_curated("vessel", "vessel_ais_link.parquet"), fd_curated("check", "vessel_ais_link_review.parquet"),
          fd_curated("check", "vessel_ais_link_routes.parquet"))
  fp0 <- fingerprint_outputs(fp); saveRDS(fp0, fd_path("archive", "fp_vessel_ais_link_190_before.rds"))
  targets::tar_invalidate(c(vessel_ais_link, check_vessel_ais_link_routes))
  tar_make_isolated(names = c("vessel_ais_link", "check_vessel_ais_link_routes"))
  allocate_vids()                   # the dry run on the store's crosswalk: 379,912 hulls, 200001-579912, 0 inherited
  allocate_vids(dry_run = FALSE)    # the first ledger batch, never rewritten
  tar_make_isolated(names = c("vessel_ais_link", "check_vessel_ais_link_routes"))   # the ledger is an input
  ```

  Nothing above the two targets is outdated (`tar_outdated()` is empty, 2026-10-23), so these three files and the
  ledger batch are the only files written. If the dry run's count differs from the scratch one, stop before the
  allocation.
- **Minority claims as twins.** 13 segments on 12 MMSIs are held as `imo_two_mmsis` only because a dominant segment's
  minority claim (under 1 % of its IMO pings) names their IMO. The rule of 2026-10-23 does not reach them.
- **A new month can withdraw a dominant link.** Decision 115 found that one new month can make a new twin. In the same
  way, a share can fall under 99 %: the segment goes back to the review table, and its vid stays in the ledger unused.
- **Not changed:** the reviewed rows' `imo` stays NA, as the Icelandic rows' does. The vid carries the IMO only through
  the rows that reach it by IMO.
