# 160 — adb is read only for the dates fs_afladagbok's dump no longer covers, from 2025-11-19

*2026-10-21. Supersedes decision 125's floor: `ADB_DATE_MIN` is the day fs_afladagbok's dump starts to thin, no longer
`FS_DATE_MIN`. From that day on decision 125's vessel-day rule stands. Tested on a scratch `$FISHYDATA`; not built.
Amended 2026-10-22: adb is loaded from the Directorate, not derived from fs_afladagbok (the last section); the rule
stands. Corrected the same day by decision 171: the sources the amendment called missing from fs_afladagbok's dump are
in dumps we hold (fs_afladagbok's tour app, afli's `stofn`).*

- **Who decided.** The maintainer, 2026-10-21, as a general rule: adb is not used downstream except for the dates
  fs_afladagbok no longer covers. fs_afladagbok is the dump of record; adb is derived from it and from other
  schemas, and has problems of its own.
- **Who did the work.** Claude (Anthropic) measured the handover day, changed the code, ran the test and wrote this
  record. The measurements are read-only and not yet checked by a person.

## What this supersedes

Decision 125 let adb fill every vessel-day afli and fs_afladagbok lack from 2020 on, since a date handover had
dropped the vessel-days the dump never received. Its floor (`ADB_DATE_MIN` = `FS_DATE_MIN`) goes; its reason holds
where the dump thins and ends, and so does its vessel-day rule there.

## Why

Before the dump thins, what adb holds and the dump lacks is not a gap in the dump but adb's own: adb re-serves fs_afladagbok (467,635 shared station ids,
times equal, adb's depth fs_afladagbok's times 1.8288 exactly; `$FISHYDATA/archive/2026-10-xml-oracle-map/README.md`),
and adds errors of its own: the dropped west sign (`curate/corrections/adb_vs_fs_afladagbok.yml`), dates outside
their own trip, an empty trawl duration (TODO 107).

## The handover day

The share of adb's vessel-days the dump holds, by day (`scripts/01_fs_share_by_day.R`, from 2025-10-20; afli holds
none of them): 99-100 % every day to 11-19 (135 of 137 that day), then 95, 96, 94, 93 and 92 % (11-20 to 11-24), 81,
69, 20 and 3 % (11-25 to 11-28), and after that nothing but four strays to 12-12.

What the dump lacks on 2025-11-19 is the first day of two trips (11-18 to 12-22) it holds nothing of, the pattern of
the thinning after it. What it lacks before that day is strays (`scripts/02_missing_days_trips.R`): 2025 has six
stations, three dated weeks outside their own trip, one on a trip a year long (2025-07-22 to 2026-07-22), and two on
one-day trips (10-27, 11-18) of a vessel the dump holds no day of after 10-25. So `ADB_DATE_MIN` is 2025-11-19, the
start of the thinning as decision 125's index row has it. A handover on 11-20, the first day below 99 %, would also
drop 11-19's 8 stations.

## What changes

- `curate/logbook.R`: `ADB_DATE_MIN` is 2025-11-19 (was `FS_DATE_MIN`, 2020-01-01), and the comments that called it
  a floor. The tier anti-join is unchanged: from 11-19 to 11-28 fs_afladagbok still wins every vessel-day it holds.
- `curate/aflaskeyti_trip.R` (and its target): the Icelandic logbook trips that keep an ERS haul from claiming a
  landing are afli's and fs_afladagbok's, no longer adb's too. adb's trips of those vessels start in 2019, after the
  ERS reports end, and of the 4,713 hauls inside a logbook trip all are inside an afli trip
  (`scripts/03_ers_inside_adb_trips.R`).
- `docs/merge.qmd`: adb's coverage, priority and date bound.

Unchanged, since they act only on the adb stations the merge keeps: `curate/corrections/adb_vs_fs_afladagbok.R`
(adb's longitude sign), `curate/corrections/logbook_gear.R` (adb's own gear crosswalk) and `curate/station_window.R`
(adb's times).

## Tested against the built tables

Both scripts were run on a scratch `$FISHYDATA` (staging and `curated/landing` linked from the real store, the outputs
written to scratch; nothing in the real store changed). Each output was compared with the real store's as built at
de25239 (decision 158), whole rows and keys (`scripts/04_compare_scratch.R`, `scratch/run.log`):

| table | change | shared rows |
|---|---|---|
| `staging/aflaskeyti/trip_landing`, `station_trip` | none | equal |
| `curated/logbook/station` | -423 adb (2020: 360, 2021: 32, 2022: 24, 2024: 1, 2025: 6; 2020-02-03 to 2025-11-18) | equal in every column |
| `curated/logbook/fishing_sample` | -423 adb | equal |
| `curated/logbook/trip` | -367 adb | equal |
| `curated/logbook/catch` | -117 rows on 62 stations, 81.2 t (2020: 18.6, 2021: 11.9, 2022: 25.2, 2024: 3.3, 2025: 22.2) | equal |

361 of the 423 stations have no catch, none is a twin, and no kept station's `twin`, `station_type` or
`t1_placeholder` changes. adb now keeps 88,464 stations, 495 of them from 2025-11-19 to 11-28 and 87,969 after.
Decision 125 found 66 of its 417 adb stations of 2020-2024 to be copies of fs_afladagbok stations carrying another
vessel or day than their fs_afladagbok copy, probably afli hauls entered again; those go too.

## Built 2026-10-21

On the maintainer's go, at f05de18 with ramb 2026.10.19.2: the 20 targets from `aflaskeyti_trip` and `logbook` through
`ais_catch` and the checks, 17:15-18:00 (`tar_make_isolated()`, names given; `mbl_photo` left out). Fingerprints,
summaries and checks before and after in `$FISHYDATA/archive/2026-10-decision160/`; the before fingerprints of
`logbook`'s own files, which `tar_meta` dropped when it was invalidated, are in `../2026-10-adb-handover/before/`.
Every rebuilt file is stamped f05de18, `fd.dirty` false; nothing is outdated after it but `mbl_photo`.

- **As the scratch test said:** no adb station before 2025-11-19; adb stations -423 (2020 -360, 2021 -32, 2022 -24,
  2024 -1, 2025 -6), trips -367, catch -117 rows and -81.2 t; afli, fs_afladagbok and aflaskeyti unchanged, as are
  `aflaskeyti`'s staging, the placeholder set times and afli's end longitudes.
- **Downstream:** 429 windows fewer; 34,992 trail fixes lose their window and 316 their `fishing_flow` (2020-2025);
  30 of the trail's 233 month files change. The allocation audit's stations in a port call 49,163 to 49,121.
- **Traced afterwards** (a side session, stopped before it finished writing up; `$FISHYDATA/archive/2026-10-catch-253t/`,
  measured by Claude, not yet checked by a person): the catch on the fixes rose by 253 t (268.7 t on the fixes)
  because the landings `lid_map` had matched to the removed adb trips are now unclaimed and shared onto fixes by the
  voyage route. And the decision's assumption holds only in part: of the 368 adb trips removed or with stations
  removed, 26 are copies of a kept afli or fs_afladagbok trip and 1 names a kept afli trip, but 321 are adb's own app
  trips found in neither (320 with no catch logged) and 19 adb's own records with catch (Trackwell books, vendor
  trials, one paper logbook). So before 2025-11-19 adb is not only derived: it holds records of its own, from an
  entry route not dumped. Whether those 340 trips and their landings should come back is plan 037's (§3.1).

## Not done here

- `products/exports/bjarki_table.R`, a legacy export carried over from the old trees, reads Oracle's adb directly
  through `mar`; it is not part of the build and is left as it is.

## adb's origin above was wrong (amended 2026-10-22)

This record called adb derived from fs_afladagbok and other schemas, re-serving it ("Who decided", "Why"). It is not
derived from the fs_afladagbok schema dumped here: adb is a second copy of the Directorate's e-logbook, loaded from
the Directorate beside it, and it holds sources fs_afladagbok's dump has none of (corrected by decision 171: the
third bullet). Checked on the dumps by Claude (Anthropic), 2026-10-22, after a colleague's
comparison of the layers; not checked by a person. The text above is kept as it was.

- **Oracle's comments.** `adb.fishing_trip.batch_day`: "The query day from Fiskistofa that returns the information
  about the trip"; `adb.catch.source_id`: "Id of the source record from Directorate of Fisheries";
  `fishing_trip.source`: "Origin of catch log, ID is retrieved from Auth0 login" (fs_afladagbok's `ws_veidiferd.uppruni`
  carries the same comment).
- **One record, two copies.** adb's trip number is the Directorate's: before 2025-11-19, 205,787 of the 206,252 adb
  trips from sources fs_afladagbok also holds carry an fs_afladagbok trip id (`ws_veidiferd.id`) with the same source
  and vessel. The shared station ids, times and depths of "Why" are that, not a derivation; the depth 1.8288 times
  fs_afladagbok's is the view fishycode reads (`station_v`), while the table `fishing_station` keeps fs_afladagbok's
  fathoms (equal on all 96,687 shared stations of 2023).
- **Sources fs_afladagbok lacks.** 56,623 adb trips, 2020-2023 (and 10 in 2026), are from sources `ws_veidiferd` has
  no trip of: `TRACKWELL BAEKUR` 26,210, `PAPPÍR` 20,993, `APP TÖFLUR` 9,374 and a few small ones. Every adb trip of
  2020 is one of them. *Wrong, decision 171:* `ws_veidiferd` lacks them, the dumps do not. All 9,374 `APP TÖFLUR`
  trips are trips of fs_afladagbok's tour app (`tour`, `fishing_spot`), and 112,729 of the 112,757 `TRACKWELL BAEKUR`
  and 21,574 of the 21,781 `PAPPÍR` stations are afli's `stofn` records (same id, vessel and day).
- **The load.** That a service on MFRI's side loads adb nightly at 03:00, for the day before and from every source, is
  the word of Hafró's systems knowledge base (`kb-hafro-kerfi`: adb.md, fiskistofa-mirror-service.md; word of mouth and
  its read of a run log that is not dumped), not verified. The dump agrees as far as it can: each trip has one
  `batch_day`, a calendar day, and every day from 2025-11-19 to 2026-10-15 has one but 2025-12-24 and 25; it keeps no
  load time (`registered` is the trip's own registration time, never after its `batch_day`).
- **The maintainer's account** (2026-10-22), not verified on the dump: adb gets its recent data from Fiskistofa, most
  likely with Fiskistofa's fs_afladagbok system as the source, built by Java no one at hand understands; it fed the new
  data into `afli`'s format, mapping the new gear codes into the old ones, with mapping problems of its own. That fits
  the shared trip ids, and adb running on after the dump thins from 2025-11-19 points to Fiskistofa's live system
  feeding it, not the copy dumped here.

**The 340 trips "from an entry route not dumped"** (traced afterwards, above;
`$FISHYDATA/archive/2026-10-catch-253t/results/removed_trips_by_kind.csv`). This explains 335 of them: the 321 app
trips are `APP TÖFLUR`, and of the 19 with catch 13 are `TRACKWELL BAEKUR` and 1 `PAPPÍR`, all sources the
Directorate delivered to adb and fs_afladagbok's dump never held. The records are dumped, in adb; the route is the
Directorate's delivery to adb, which no dump shows. *Wrong, decision 171:* the 321 app trips are in fs_afladagbok's
tour app, and the other two sources are afli's `stofn` records; the 14 trips were not checked one by one. The other 5 (`Trackwell raun` 2, `Fontos raun` 2, `Marína raun` 1)
are from sources fs_afladagbok holds, but not these trips; why is open.

**What stands.** The rule, adb only from 2025-11-19, is the maintainer's and is not reopened here. Of the 368 adb trips
it removed before that day, 335 are records of sources the dump never received, not adb's own errors; whether they
should come back is plan 037's (§3.1), as above.
