# 262 — A trip's further landings joined to it (`trip_landing`), and the catch's disposition on the landings and the trip

*2026-10-30. Plan 054 step 2i (TODOs 81, 112), plan 027 §5 and plan 036 §3, as decision 208 and plan 054 ask b chose
them. Coded by Claude (AI) in side sessions and checked on scratch stores, not by a person. Merged into main with
12900a4: adb6020 (`trip_landing`), 1322792 (the disposition), and 12900a4, which puts `ais_catch` and the audit back
to main's, unbuilt (decision 261). The draft with every table, the scripts and the traces are in
`$FISHYDATA/archive/2026-10-30-plan054-link-lumpfish/`. Nothing is built on the live store.*

## Chosen

- **`curate/trip_landing.R`**, a flow table: a trip's further landings are joined to it. That means any port, within 7
  days, until the vessel next fishes. In-port landings the logbook lacks are joined too (decision 247 b). `lid_map`'s
  rows are all kept. Every landing gets one outcome:
  - `lid_map`: 1,529,082;
  - export joined: 11,942 (265.8 kt);
  - by the track: 5,094;
  - by weight: 9,526;
  - fished between: 37,072;
  - weight not nearer: 21,779;
  - no claimed landing: 585,142.
- **A class for every landing code that is not a harbour** (208 e), in `reference/ports/port_code_class.yml`, read by
  `reference/ports/port_code.R`. Every code the landings use is listed (104), and a code with neither a pid nor a class
  stops the build. Four were looked up by name:
  - 41 Hellissandur, harbour;
  - 71 Hnífsdalur, harbour;
  - 197 Leiðréttingar (corrections, 7,520 t in 1993-1997), placeholder;
  - 200 Gjögur ("not used, 82"), harbour. It could take code 82's pid.
- **The disposition on every `catch_detail` row** (208 a): home, export, abroad, export_or_abroad, transfer or unknown,
  with its basis. agf's `afdrif` is kept raw beside it. `landings.parquet` and `catch.parquet` are unchanged.
- **The disposition stops at the trip** (208 f), in a new `curated/logbook/trip_disposition.parquet`, one row per
  kept trip. It is a table beside `trip_landing`, not on `trip.parquet`: that one is preprocessing, and this is flow.
- **Checked at the trip, never on the fixes** (decision 261).

## Checked on scratch stores

- **The landings:** the staged and curated landings and catch are identical to live, row for row. `catch_detail`
  summed back equals 2c's on every row, and every row has a disposition and a basis.
- **Exports carry on across the 2013-09 handover:** LODS's 159 up to 2012/13, then agf's U.
- **kg in = kg out** in every one of the 52,623 vessel-years: the landed kg equals the kg of its landings' outcomes.
- **Logged over landed, per vessel-year:**

  | vessel-years | before | after | kt added |
  |---|---:|---:|---:|
  | a 159 export joined (1,047) | 1.149 | 1.015 | 295.9 |
  | a further landing by the track (3,495) | 0.984 | 0.976 | 54.5 |
  | a further landing by weight (3,666) | 1.004 | 0.984 | 213.9 |
  | none joined, the control (29,121) | 0.976 | 0.976 | 0 |

  The vessel-years with a further landing move to the control's ratio, as TODO 81's check asks, now at the trip.

## Left

- **TODO 160's trace-id witness:** waits for the maintainer's Oracle session (`ops$rafn.rekjanleikanumer`).
- **Plan 039's `withdrawn` and key:** not ready (TODO 123).
- **For the maintainer:** a look at the four codes classed by name, and whether 200 takes 82's pid.
- **The rest:** `docs/data-dict.yaml`, and the live build in the rebuild: `port_code`, `aflagrunnur`, `landing`,
  `trip_landing`.
