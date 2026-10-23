# 188 — `docs/data-dict.yaml` on the data-dict 0.0.3 spec, with plan 016's tables (TODO 51 closed)

*2026-10-23. Claude's status review of the day picked this as a quick win, and the maintainer asked for it to be
started. The edits, the checks and this record are by Claude (AI-assisted) and have not been checked by a person. The
maintainer chose how the DATE columns are handled ("A, keep them as date and write up the issue"). Read-only on
`$FISHYDATA`. No code changed, and nothing needs rebuilding. Closes TODO 51 (decisions 029, 030).*

## Counts (data-dict 0.0.3, the binary `datadict::dd_install()` puts in R's user cache)

| | before | after |
|---|---|---|
| tables, columns | 52, 799 | 56, 856 |
| `validate-spec` errors | 223: 212 S07 (no `examples`/`range`), 11 S28 (`timestamp`, `double`) | 0 |
| `validate-meta` | not run: it stops at any spec error | 17 errors (M01), all one cause, below; 895 checks pass |
| S31 warnings (an unresolved `todo`) | 276 | 266 |

## The 17 `validate-meta` errors are the tool's reading of DuckDB's DATE

Every DATE column in these files is written by DuckDB 1.5.6 (`write_curated()`'s `COPY`) as INT32 with the
ConvertedType DATE and no LogicalType. data-dict 0.0.3 reads such a column as `number`. A DATE written by nanoparquet,
which carries the LogicalType, reads as `date`; this was tested on two one-row scratch files. The 17 columns are
`logbook_lid_map.date_land`, `vessel` `mmsi_t1`, `mmsi_t2`, `note_date`, `vessel_ais_key` `d1`, `d2`, `vessel_mmsi`
`note_date`, `mmsi_t1`, `mmsi_t2`, `first_seen`, `last_seen`, `vessel_class` `t1`, `t2`, `observed_to`, `vessel_sign`
`t1`, `t2` and `staging_quota_trip.date`.

They stay typed `date` (the maintainer's choice). Typing them `number` would pass the check, but it would misstate the
columns for every other reader: DuckDB, R and arrow all read them as dates. The defect is written up for the tool's
authors in `curate/issues/data-dict.yml` (drafted, not sent), and the file's own `details` says the same. The landing
tables' `date` columns were typed `number`, with ranges in days since 1970-01-01, by decision 029's draft, for this
same reason. They are left as they were.

## Done

- **Plan 016's tables.** `vessel_mmsi` (`curated/vessel/mmsi.parquet`), `vessel_year`, `vessel_class` and `vessel_sign`,
  described from `reference/vessels/{mmsi,vessel_year,vessel_class,vessel_sign}.R`. Each column has a specific type
  and no `todo`. The keys declared are the ones the scripts assert, and the files hold them: `(mmsi, zombie_no)`
  4,228 of 4,228 distinct, `(vid, year)` 140,940 of 140,940, `(vid, t1)` 39,309 of 39,309.
- **Columns the files had gained:**
  - `vessel`: `status`, `foreign` and `register`;
  - the trail: `kw_basis`, `leisure` and `leisure_basis` (`R/trail_sql.R`);
  - `ais_voyage_gear.landing_gap_d`;
  - `logbook_catch_by_species_trip.schema`. It is NA on 5,494,406 of 8,393,841 rows, the landings-only rows of the
    script's full join, and is described that way;
  - `vessel_ais_key`: `d2_is_open` and `tier`;
  - `check_afli_rafr_stofn_loss.share_absent`. It replaces `severity` and `usable`, which the commit of decision 098
    dropped from the file.
- **Columns whose types were wrong.** `link_station_event` `event_time` and `time` were `string` and are `datetime`
  in the file. The 10 `timestamp` columns are now `datetime` in UTC, as their descriptions say.
  `fishing_sample.duration_m_raw` is now `number(quantity)` in minutes, and its misplaced "enum?" todo is gone.
  `landing_catch.schema` and `landing_landings.schema` are now `enum` (agf, lods, the only values in the files).
- **Representative values.** 250 `examples` and `range` were taken from each table's own file by a read-only script
  (in the session's scratchpad, not the repo). A partitioned table's come from its one representative file, as in
  decision 029. Three GPS-logger columns (`dt_sec`, `sid_gps`, `n_sid_gps`, on `ais_ping` and `ais_trail`) are empty in
  2023 and 2024: no logger fix is left after 2020 (decision 154). Their examples come from every partition, and a
  `details` line says so.
- **No person's data in examples.** The MMSI list's `nafn` and `note` can name an owner, a buyer or an address. They
  are `display: restricted`, with made-up examples. `vessel_sign`'s `key` and `value` show call signs and local signs
  only, no vessel names. Every other value filled is a code, an id, a count, a port, a date or a category.
- **S31 resolved where grounded (10).**
  - 11 "Needs a `time_zone`?" items are set to UTC. Those columns are AIS-clock times (decision 111), plus the
    logbook's `t1`-`t4` and trip `T1`/`T2`: Iceland keeps UTC all year, and the foreign hauls' local times are moved
    to UTC (`aflaskeyti_local_time.yml`). Five todos emptied, and the warning went with them.
  - `vessel.yh1` and `yh2` are `number(ordinal)`, and their text now says the ship register's first and last year
    (`registry.R`, 2026-10-18), not Hreiðar's.
  - `duration_m_raw`'s todo was not about it.
  - `severity` and `usable` left with their columns.
  - The station's calendar `date` and the logger's clock keep their time-zone question.
- **Stale text in the same tables, brought up to date.** `vessel`'s description and `source` now cover the SKB craft
  (enum ISL, SKB), and its `vid` range runs to 102,772. The stofn-loss check is described as a report only (098).

## Left

- 266 S31 warnings: one per `todo` field, and their 374 items are mostly the draft's own notes:
  - "pick a more specific numeric type" (157);
  - "specify constraints" (141);
  - "record a primary key" (25);
  - "is this an enum?" (44);
  - "needs a time zone?" (2);
  - five notes of earlier passes: two on partitioning, `vessel`'s population, a tail of old rows and a non-UTF-8
    column.

  Each needs a check on the whole table, or a person's word, before it can be resolved.
- `vessel_ais_key.step`'s description and examples are from the cascade, and the file's steps are now the segment
  table's ("segment: physical", ...). They are left as they were, outside this item.
- The landing tables' `date` columns as `number`, until the tool reads DuckDB's DATE.
- `docs/output-schema.md` is untouched (TODO 111), and so are the raw overlays of plan 040.
- `curated/` holds tables the file does not describe (for example `vessel_ais_link`, `vessel_identity_all` and most
  of `check/`). They were not counted here: TODO 51 asked for plan 016's.
