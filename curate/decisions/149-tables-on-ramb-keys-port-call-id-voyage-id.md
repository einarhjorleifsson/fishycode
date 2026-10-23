# 149 — The tables take ramb's key names: `port_call.parquet`, `port_call_id` and `voyage_id` (TODO 91, plan 032 §7 d)

*2026-10-19. The choices are the maintainer's, answered in chat the same day. The code, the scratch checks, the
rebuild, the checks after it and this record are by Claude (AI-assisted). The code was committed at a015a18 on the
maintainer's word ("Yes, commit your 25 files"). It was built by name from a clean tree at 72183bd, on ramb 2026.10.19.2
(a312781) and on the maintainer's go ("Go for option 1"). Not pushed. Closes TODO 91 and plan 032. Follows decision
147, which renamed ramb's functions and left the tables to this rebuild.*

*Amended 2026-10-23, from Claude's audit of the decision records (not yet checked by a person): TODO 91 is not
closed. It stays open for ramb's `_pkgdown.yml` reference index, which still lists the old names. Closed by
decision 186 the same day.*

## Decided (the maintainer)

- **`voyage_id` wherever the key joins**: `curated/ais/voyage.parquet`, `curated/link/trip_voyage.parquet`,
  `curated/ais/voyage_gear.parquet`, the pings and the trail. One key has one name in every table.
- **`pid`, `pid1`/`pid2` and `T1_ais`/`T2_ais` are kept**, as decision 147 says. `docs/grammar.qmd` maps them to
  ramb's names.
- **The check and the app follow their subject**:
  - `curate/checks/port_stay_logbook.R` becomes `port_call_logbook.R`, with the target `check_port_call_logbook`, the
    file `curated/check/port_call_logbook.parquet` and the columns `n_port_call*`.
  - The vessel overview's `stays` endpoint becomes `port_calls`.
- **The build runs from a clean commit**, so that no new file is stamped dirty.

## Built

- **`curate/port_stay.R` becomes `curate/port_call.R`** (`git mv`). Its target is `port_call`, and it writes
  `curated/ais/port_call.parquet`.
  - The key `port_call_id` sits where `stay` was. It is numbered as before: per vessel by `T_in`, over all years.
  - A call over New Year therefore keeps one number (decision 147). ramb's own numbering of the calls is still
    replaced.
- **`curate/ais_voyage.R`** writes `port_call_id` and `voyage_id` on `curated/ais/ping`, and `voyage_id` in
  `voyage.parquet`, in the positions that `stay` and `voyage` had.
- **The readers**:
  - the trail SQL (`R/trail_sql.R`, with `rb_add_effort(by = "voyage_id")`) and `curate/ais_trail.R`'s header;
  - `link_trip_voyage.R`, `voyage_gear.R` and `ais_catch.R`;
  - the checks `port_call_logbook`, `voyage_sharing` (its archived "before" files keep their names), `vessel_activity`
    and `survey_tow_times`;
  - the vessel overview (`api.R`, `check.R` and `www/app.js`), with `API_VERSION` raised to 2026-10-19.1, so that
    `start.sh` restarts a server older than the code;
  - `docs/data-dict.yaml`, `ais_trail.qmd`, `grammar.qmd`, `one_flow.qmd` and `pipeline.qmd`;
  - `AGENTS.md`.
- **The `once` project's `curate/logbook_sensor_gps.R`** now reads `voyage_id`. Only its reader changed: the logger
  positions are a frozen fix and were not rebuilt.
- **Two stale facts on lines this touched.** `docs/data-dict.yaml` gave the port-call minimum as 4 h, and
  `docs/pipeline.qmd` described port classes with 2 h and 4 h. Both now say one 2 h minimum at every port (decision 074).
- **Nothing outside fishycode reads these tables.** The two old repos name no `curated/` path, and the ICES datacall
  reads neither key.
- **The old files** (`curated/ais/port_stay.parquet` and `curated/check/port_stay_logbook.parquet`) are in the macOS
  Trash, under `2026-10-19-todo91-port_stay/`, now that nothing reads them.

## Checked before the build (scratch `$FISHYDATA`)

The edited scripts ran against today's tables in a scratch store whose links to the real inputs were read-only.
Nothing in the real store changed (checked by modification time). The tables were compared by position, so the
renamed columns line up.

- `port_call.R`, every year: the same 1,631,285 rows as `port_stay.parquet`, with only `stay` renamed (6.1 min).
- `ais_voyage.R`, on 30 vessels drawn from 2015's, all years: the same 17,798 voyages and 7,634,544 pings.
- `link_trip_voyage.R`: the same 830,498 links. `voyage_gear.R`: 130 of 1,430,712 voyages chose another gear.
  125 of them kept the same speed range. That is decision 144's tie, not the rename.
- The trail and trail_match of 2015-03: the same 2,865,090 fixes and 1,372,003 matches.
- The catch of 2015 kept kg in = kg out.
- `vessel_activity`, `voyage_sharing` and `port_call_logbook` were the same. `survey_tow_times` was the same for every
  tow that the scratch month covers.

## The rebuild

- **The 13 targets**, built by name from 16:40 to 17:54 UTC:
  - the chain: `port_call`, `ais_voyage`, `trip_voyage`, `station_event`, `voyage_gear`, `ais_trail`, `ais_catch`;
  - the checks: `port_call_logbook`, `voyage_sharing`, `vessel_activity`, `trail_agreement`, `survey_tow_times`,
    `trail_sid_coverage`.
- **The run** ended "ALL DONE" with exit 0. The longest steps were `ais_trail` (31.5 min), `ais_catch` (19.8 min),
  `ais_voyage` (14.7 min) and `port_call` (5.7 min).
- **Afterwards**, `tar_outdated()` lists only `mbl_photo` and `mbl_photo_raw`, which were outdated before and are not
  part of this build.
- **All 684 output files are new**, stamped 72183bd and not dirty.
- **The one warning** is decision 129's SQL notice on missing values, in `ais_catch`.

## Measured after the build

The comparison used fingerprints of the 684 files, taken before and after (`R/fingerprint.R`; order-free hashes of
each row and each column). It also used the old trail and catch aggregated by vessel-year, and copies of the old
voyage, voyage-gear and link tables.

- **The keys map one to one: old to new is the identity.** Every file of `curated/ais/ping` holds the same rows as
  before, column for column: 127 files and 585,490,807 pings, with only `stay` and `voyage` renamed. So does every
  file of these tables:
  - `port_call` (1,631,285 rows);
  - `voyage` (1,430,712);
  - `trip_voyage` (830,498);
  - `station_event` (11,117,895);
  - `trail_match` (190,886,823 in 233 files);
  - the six checks.
- **The trail**: 585,490,807 fixes, as before.
  - 142 of its 233 files are unchanged.
  - The other 91 differ only in the voyage's gear: `gid_voyage` in 91 files, `s1_voyage`/`s2_voyage` in 4 and
    `fishing_flow` in 3.
  - By vessel-year (37,553), every count agrees: fixes, port-call and voyage keys, the distinct keys, `fishing`,
    `.sid`, `.tid_voyage`, `gid_voyage`, hours and kW-hours.
  - `fishing_flow` agrees too, except 13 fixes in 2 vessel-years: 2018 in 2023 (+11) and 2650 in 2011 (+2).
- **`voyage_gear`'s tie** (decision 144) did all of that, not the rename.
  - 161 voyages chose another gear. In 157 of them (93 `ambiguous`, 64 `logbook`) the speed range stayed the same.
  - In 4 `landing` voyages it moved: 2650's 2011 voyage 80, 2018's 2023 voyages 39-40, and 1808's 2008 voyage 33.
  - The 13 fixes lie on the first three of those voyages.
- **The catch**:
  - The total is 28,085,616,635 kg under both approaches, as before, and every vessel-year agrees within
    6 × 10⁻⁷ kg.
  - `fishing_flow` has 92 more rows: the same kilograms spread over the moved fixes of 2018 (+88) and 2650 (+4).
  - Every file's `kg` hash differs: the order of floating-point sums, as in decision 144.
- **The vessel overview**:
  - `products/vessel_overview/check.R` passes: 79 answers, 10 refusals, one photo.
  - The page loaded vessel 2757 in quality-control mode with no console error, showing the `voyage_id` and
    `port_call_id` columns and the port-call and voyage lanes.
- **The docs**:
  - `validate-spec` gives the same 417 findings before and after, all of them TODO 51's.
  - The dictionary's columns match the parquet for the seven renamed tables, except `ais_trail`, which lacks
    `kw_basis`, `leisure` and `leisure_basis`. That gap predates this work.
  - The four changed pages render.

## Not done

- **`voyage_gear`'s tie** (decision 144) is still there: `arg_max()` over gears with equal counts or weights picks
  differently on each run. This time it moved 161 voyages and 13 fishing flags.
- **The `once` project was not built.** Its 19 outdated targets were already outdated before this build.
  `main_ais_ping` watches `curated/ais/ping` and `voyage.parquet`, so it stays outdated until the next fix built there
  by name.
- **Plan 031** still names `port_stay.R` and `port_stay.parquet`, as they were when it was measured. It is the voyage
  session's to update (TODO 90). Older plans and decisions keep the names of their day.
- **The old target names** `port_stay` and `check_port_stay_logbook` keep their rows in `_targets/meta` until a
  `tar_prune()`. They are not in the pipeline, so `tar_outdated()` does not list them.
- **The trail's dictionary entry** lacks `kw_basis`, `leisure` and `leisure_basis` (above).
