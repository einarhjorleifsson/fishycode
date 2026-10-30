# 253 — The app that wrote each e-logbook station, carried on the merged station (plan 053 step 2)

*2026-10-30. Plan 054 step 2a, plan 053 step 2 (TODO 165). Coded by Claude (AI) and checked on a scratch store, not by a
person. The trace and its script are in `$FISHYDATA/archive/2026-10-30-plan054-step2a/` (`trace.R`, `trace_app.txt`).
Nothing is built on the live store; the change rides plan 054's rebuild A.*

## Why

Plan 053's profile (`curate/corrections/logbook_app_profile.yml`) says, per app, what each field holds. A rule can only
apply where the station knows its app. Until now, the app was on fs_afladagbok's trips alone (`source`, the trip's
`uppruni`). adb's adapter read `fishing_trip.source` for its position decoder and dropped it, and the afli route's app
was in `staging/afli_sent` only.

## Chosen

- **adb's staged trip carries `source`**, as fs_afladagbok's does (`sources/adb/convert.R`).
- **`curated/logbook/station.parquet` carries the app**, under the profile's own vocabulary:
  - `app_raw`: the string as written;
  - `app`: for fs_afladagbok and adb, the trip's string with the suffixes " - GAFL AUTO" and " - Skrifstofa VES" taken
    off; for the afli route, the sent message's software and its major.minor version, for example "Fishing Log 2.6";
  - `app_suffix`: the suffixes taken off;
  - `app_version`: the sent message's whole version (the afli route only).

  It is made in `curate/logbook.R`, after the station type, from the merged trip and from
  `staging/afli_sent/station.parquet` by `.sid`. A paper record and aflaskeyti's ERS reports have none. `logbook` now
  depends on the `afli_sent` target.
- **The app stays on the station**, not on the fishing sample: the sample joins it by `.sid`.

## Checked on a scratch store

The adb adapter and the merge were run on a scratch `$FISHYDATA`, with the inputs linked file by file. No file of the
real store is newer than a marker set before the run. The run also carries decision 249's `coord_flag`, which was coded
the same day.

| file | rows, live = scratch | new columns | rows differing on shared columns |
|---|---:|---|---|
| `staging/adb/trip.parquet` | 306,537 | `source` | 0 |
| `staging/adb/{station,fishing_sample,catch}.parquet` | 691,011 / 691,011 / 2,074,565 | – | 0 |
| `curated/logbook/trip.parquet` | 1,854,063 | – | 37,878: adb's merged trips, `source` filled, nothing else |
| `curated/logbook/station.parquet` | 7,310,942 | `app_raw`, `app`, `app_suffix`, `app_version` | 251: afli's `coord_flag` (75 `lon_sign_switched`, 176 `lon_sign_unjudged`), nothing else |
| `curated/logbook/{fishing_sample,catch,station_fate,trip_fate}.parquet` | 7,310,942 / 17,026,059 / 8,013,418 / 2,175,609 | – | 0 |

The apps on the merged stations:
- **fs_afladagbok:** all 374,681 stations. Trackwell raun 317,807, STOKKUR 23,136, Marína raun 14,007, FRA TAKTIKAL
  6,992, Fontos raun 5,382, Reiknistofa fiskmarkaða raun 2,527, Jóhann Gíslason raun 2,395, TRACKWELL 1,856, Fishtech raun
  540, and four others under 25.
- **adb:** all 88,464 stations. Trackwell raun 77,546, Marína raun 5,090, Reiknistofa 3,209, Fontos raun 2,611,
  Skráningar.com 8.
- **afli:** 1,264,047 of 6,844,739 stations, its electronic route. Fishing Log 2.7 644,244, 2.6 372,406, 2.0 155,153,
  1.1 75,501, 1.3 11,686, and Fishing Logbook 1.1 5,057.
- **aflaskeyti:** none.

## Left

- "FRA GAFLI - AUTO" (22 stations) keeps its " - AUTO". The profile names only the two suffixes above.
- `docs/data-dict.yaml` gets the four columns, and adb's filled `source`, with rebuild A, once the files hold them.
- Plan 053's next steps: the check, the flags read by the windows, the decoders, and depth by app.
