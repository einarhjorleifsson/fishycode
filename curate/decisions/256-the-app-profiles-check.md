# 256 — The app profile's check: each e-logbook app's classes on every build (plan 053 step 4)

*2026-10-30. Plan 054 step 2a, plan 053 step 4 (TODO 165). Coded and tested by Claude (AI) in a side session, not
checked by a person. On main as 57417c9. The draft and the test are in `$FISHYDATA/archive/2026-10-30-plan054-step2a/`
(`draft-step4-the-check.md`, `test_check.R`, `test_check.txt`). Nothing is built on the live store.*

## Why

Plan 053 §5.4: the profile is a set of reviewed rows, and the apps move. Trackwell raun's tow starts stamped with
seconds, for example, fell from 95 % in 2022 to 35 % in 2026. The classes the rows came from must be remade on every
build, so that a new app, a new version or a moved share shows.

## Chosen

- **`curate/checks/logbook_app_profile.R`** (target `check_logbook_app_profile`) remakes the archive's classes from the
  record alone into `curated/check/logbook_app_profile.parquet`, per feed, app, year, gear class and field, with the
  merged stations beside.
  - The population is each station once: fs_afladagbok whole, adb's stations that fs_afladagbok lacks, and the afli
    route as sent.
  - The classes cover the times, the latitude's digit form, the longitude's sign, the end position, and the depth.
- **`app_named`** is FALSE for an app no row names. On 2026-10-30 these are the afli route's versions other than
  Fishing Log 2.6, the tour app, paper, TRACKWELL BAEKUR and FRA GAFLI - AUTO.
- **Row I4's unlanded clusters are listed here, not flagged in the merge**, because they need `lid_map`, which is made
  after it.
- **A check, never an input.** Nothing reads the file back. Neither the margin for "moved" nor the witnesses are
  built: they run on demand (§5.4).

## Checked

On a scratch store over today's live files, in 6 s, against the archive:
- p01, the times: 575 rows, every count, the merged count and the year;
- p03, the positions: 145 cells;
- p05, the depth: 179 cells;
- r18, the unlanded clusters: trips by app.

None differs. The real store was untouched.

## Left

- The witnesses on demand, and scoring the afli route's rows against the expert's edits to 2018 (plan 053 §5.4).
- I4 reads adb's trips by app once rebuild A carries adb's `source` (decision 253).
- The file enters the data dictionary with rebuild A.
