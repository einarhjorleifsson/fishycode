# 264 — The tour app staged as the record of its trips: its STOKKUR copies out, its never-imported trips classed and admitted (plan 054 step 2e)

*2026-10-30. Plan 054 step 2e, plan 019 §4, TODOs 73 and 141, plan 054 ask j; decisions 210, 214 and 252. Coded and
traced by Claude (AI) in a side session, not checked by a person. Merged into main as 2ab1acb (3872e5f). The two
choices left open, the unlanded class and the hooks threshold, are the maintainer's, put by the main session the same
day: both as built. The draft with every table, the traces and the scripts are in
`$FISHYDATA/archive/2026-10-30-plan054-tour-app/`. Nothing is built on the live store.*

## Why

The Directorate's small-boat web logbook, fs_afladagbok's `tour`, `fishing_spot` and `catch` of 2020-01 to 2022-03,
was unread. From 2021-04-06 its trips were imported into `ws_*` as STOKKUR, with the latitude rounded to a whole
degree, one time at the landing, and no hours or gear count. Before that day nothing was imported, which made most of
TODO 141's handline gap.

## Chosen

- **The tour app is the record of its trips** (decision 210). `sources/fs_afladagbok/convert.R` reads it:
  - **trips:** the landing port is read as `hid` through `port.parquet` (decision 252);
  - **spots:** the position decimal as recorded;
  - **times:** the spot time is `t4`, the end of fishing, and `t1` is `t4` less the hours or nights where those are
    plausible, basis `synthesised` (decision 214);
  - **the count** comes from the jigs, nets or hooks;
  - **the catch** is the estimated weight in kg, with the undersized part beside it.
- **The 25,971 STOKKUR copies leave `ws_*`'s output.** Each matches its tour to the second, one to one. The adapter
  stops if one does not.
- **Every never-imported trip is admitted, with its class on the trip** (`tour_class`): `imported`, `landed` (8,339,
  the vessel landed within a day) or `unlanded` (1,482). The maintainer kept `unlanded` in with its class visible, so
  an analyst can leave it out. The merge's own rules still drop a spot on a vessel-day afli holds.
- **A longline's hooks are read per line where a record gives fewer than 100 a line.** That is the session's reading,
  accepted by the maintainer and noted here to revisit if a person finds otherwise. 33 spots lie between 60 and 200 a
  line.
- **A tour's recorded `t4` stands when its duration is doubted.** `judged_time_sql()` and `calc_effort()` now doubt
  the e-logbook's static `t4` only where `t1` is recorded. Nothing else changes, and a test covers it.
- **`station_window` labels the tour's jig window `derived`**, since its `t1` is made from the hours.

## Checked on scratch stores

- **Staging:** 217,010 trips and 478,304 stations. Every other row is identical, and kg in = kg out to the kilogram
  (the tour's 408,390,412 kg equal the raw catch).
- **The merge:**
  - all 31,785 tour spots have one outcome;
  - the imported tours meet exactly their copies' fate, spot for spot and kilogram for kilogram;
  - no other station's fate changes;
  - 7,839 never-imported spots are kept, with 9.4 kt in rows under 100 t.
- **Large rows:** 15 kept rows of 100 t or more; `catch_flag` flags 13 of them (376 kt). Two, 210 t on unlanded trips,
  fall under its margin.
- **The windows:** the copies' 23,132 day windows become mostly jig, set and haul windows. Elsewhere 4 windows move,
  cut by a tour neighbour.
- **The handline gap of 2020-09 to 2021-03:** landings with no logbook trip fall from 2,091 (87 %) to 419 (17 %). The
  remainder is declared in `docs/merge.qmd` and in the landings' dictionary entry (ask j). The question to the
  Directorate stays TODO 169's.

## Left

- **11,197 tour jig spots get a day window**, because their hours are none or above the limit. Decision 214's
  trip-long window is parked (TODO 137).
- **`protected_bycatch`** is parked (TODO 73).
- **The live build** in the rebuild, with the 2i and 2d changes merged after this branch was cut. The combined
  scratch build traces them together.
