# 139 — The vessel overview's R service: fixed endpoints, a column allowlist, parquet out (plan 030 step 3)

*2026-10-18. On the maintainer's go ("go on to step 3"); code, checks and this record by Claude (AI-assisted). A
person has not yet checked the answers. Nothing is written under `$FISHYDATA`, and nothing is a target.*

## Built

`products/vessel_overview/`:
- `api.R`: the endpoints, their SQL and the allowlist;
- `server.R`: starts the service on 127.0.0.1:8790 (decision 137, ask a);
- `check.R`: the checks below, run by hand from the repository root.

Each endpoint answers one vessel's rows as zstd parquet, which DuckDB-WASM reads in the page (ask h, both):

| endpoint | rows | from |
|---|---|---|
| `/api/vessels` | every vessel: vid, name, call sign, MMSI, IMO, status | `vessel.parquet` |
| `/api/register?vid=` | today's register row | `vessel.parquet` |
| `/api/hist?vid=&table=` | the register history to 2023-12-19: vessel, identification, measurement, owners, operators, events | `curated/vessel/skipaskra/` |
| `/api/landings?vid=&n=` | the last n landings, by species, with port and gear names | `curated/landing/` |
| `/api/trips`, `/api/stations`, `/api/station_catch` | the last n logbook trips, their stations with t1-t4 and gear, and their catch | `curated/logbook/` |
| `/api/trail_years?vid=`, `/api/trail?vid=&year=` | pings by year; one year of the trail, the latest by default | `curated/ais/trail` |
| `/api/photos?vid=`, `/photo?vid=&file=` | the vessel's images, and an image file the index lists | `staging/mbl/photo.parquet` |

- **The allowlist.** Each response is `SELECT` of the endpoint's listed columns only. Kennitala, addresses, postal
  codes, towns, phones, web pages and the EXIF copyright strings are never listed (ask e). Owners' and operators'
  names are.
- A landing's gear is named from the gear table's version that matches its schema: new codes for agf, old for lods
  (`curate/corrections/logbook_gear.R`).
- Twin trips and stations marked `duplicate` are left out (decision 094).
- The browser sends no SQL, only a whole-number vid, n, year and a history table's name.

## Checked

`check.R`, on vids 2757, 3739 and 2652:
- no allowlisted column is personal;
- 43 answers, each with exactly its allowlisted columns, empty answers included (3739 has no trip or register
  history);
- every answer under 0.4 s (0.003-0.351 s), with the files in the OS cache. The busiest, vid 2757's 2026 trail, is
  53,370 pings in 540 KB;
- a listed photo is served byte for byte (md5);
- eight requests refused: a non-numeric or missing vid, SQL in the vid, an unknown table or endpoint, a path out of
  the photo folder, a photo the index does not list.

Read by hand: landings carry their port and gear names (none missing for 2757 or 2652), and stations their t1-t4.

## Found on the way

Vid 2757 has the most pings of 2026-09, and pings to 2026-10-16, but its last landing and logbook trip are on
2024-12-27, and none of its 2026 pings is flagged fishing. The service shows the tables as they are. Whether the
vessel stopped fishing or the key puts another hull's pings on its vid was not looked into.
