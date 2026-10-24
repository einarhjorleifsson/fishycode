# 219 — The user tables, version 0: curated's best state as plain tables, to be used before they are designed

*2026-10-24. The maintainer: "I want to start playing around with the products as-is", so that "experience gained from
that can provide a user-feedback loop to the whole process", and on the version: "it is very important that in the
next round we start thinking about the dataproduct version". Built, checked and written by Claude (AI), not checked by
a person.*

## What was built

`products/user_tables.R` writes `$FISHYDATA/products/v0/`, a folder per domain: `vessel/`, `landing/`, `logbook/`,
`ais/`, `reference/`. `$FISHYDATA/products/` is a new top-level folder: what a user opens, beside `published/`
(versioned releases, still empty) and `exports/` (one-off deliveries).

- **Linked:** ten tables taken as they are, as relative symlinks into `curated/`: `vessel`, `vessel_year`; the
  landings (`landing.parquet`) and their catch; the AIS `trail/`, `catch/` and `voyage`; `species`, `gear`, `port`.
  DuckDB reads the trail's year and month partitions through the link, and the 26 GB of AIS tables are not copied.
- **Written:** the three logbook tables, since none in `curated/` is right for a user as it stands. Each carries the
  stamps of `write_curated_sql()` (`.curated_kv()`), whose guard keeps that writer to `curated/`.
  - `trip` (1,853,260): `trip_reconciled`'s departure and return, times and ports, with `_basis`, `_from` and `_day`;
    `n_crew`; the trip's landing from `lid_map` (`.lid`, `schema_land`), one at most per trip.
  - `station` (7,301,169): the station with its fishing sample (one per station) and the trip's vid, less the `_raw`
    and internal columns.
  - `catch` (16,997,458): the kept stations' catch.
  Duplicate twins (decision 094) are out of all three: 9,773 stations, and the trips `trip_reconciled` leaves out.
- The keys are curated's, unchanged: a record by (id, schema), a landing by (`.lid`, schema).

## Checked

- The row counts against their sources (the script stops otherwise). A rerun replaces the links and files cleanly.
- As a user: all 1,533,984 trips with a landing find it in `landing`; the logbook's cod in 2023 sums to 209 kt; on
  one trawler in May 2023 (12,223 fixes), 7,031 are on a station by key and 11,788 in a trip by
  `join_by(vid, between(time, T1, T2))`, and the two agree on every fix both place.

## What v0 is not

- **Not frozen.** The links follow every rebuild of `curated/` and the written tables do not, so the script is rerun
  after a rebuild (6 s), or the two halves disagree. How a data product is versioned is the next round (TODO 140).
- **Not designed.** The names are curated's (`station`, `.tid` with `schema`), and no table was shaped beyond the
  above. What to change is to come from using it.

## Found the same day

Quick counts, read-only, from scripts not kept:

- `T2_basis` is `reconstructed` on 92-99 % of trips a year since 2008 because the AIS voyage ranks first (decisions
  173, 174). Up to 2020 the logbook's own return is a date only; since 2023 it is a time, a median 0.5 h from the
  track's.
- 529 fs_afladagbok trips have a negative vid, some of them minutes long (vid -422).
- Landings from 2007 with no logbook trip: 148,726. Foreign vessels (3700-4999) are 5,084 of them by count but 3,087
  of the 4,327 kt. The rest are mostly small boats' gears by count (grásleppunet, handfæri, sjóstöng) and trawlers by
  weight, the latter mostly within 3 days of a landing of the same vessel that has a trip (plan 027). Handline
  trips of September 2020 to March 2021 are in no logbook source held (TODO 141).
