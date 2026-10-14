# 094 — Twin records: a duplicate is flagged and left out of every sum and link

*2026-10-14. Measured and built by Claude (AI-assisted) on the maintainer's request (TODO 58). The choices are the
maintainer's, the same day: leave out the catch of duplicates only, let the first record keep the link, put
accuracy first whatever the rebuild costs, and report the duplication where analysts read. The declaration is
`curate/corrections/logbook_twin.yml`.*

## What a twin is: three things, not one

Decision 090 counted 24,768 stations sharing all of t1-t4 with another station of their vessel. Counted again on
the merged logbook (24,823 stations; read-only, 2026-10-14), they are three things:

| kind | groups | stations | catch | what they are |
|---|---|---|---|---|
| duplicate | 7,529 kept records | 9,744 more | identical | the same record entered again |
| same time | 6,035 stations | | differs | records of their own whose times equal another's |
| date only | 386 | | | every time at 00:00: several untimed stations of one day, not twins |

- **fs_afladagbok:** 739 trips were submitted again, by the same vendor with the same dates, mostly in 2022-2023.
  Each repeats exactly one trip (479 trips, some sent three times or more).
- **afli:** single stations were entered twice within one trip, 1969-2023 (5,286 of 5,813 duplicates). The
  same-time records are towed and seine gear (OTB, SDN, PS) for the most part.
- **adb:** 235 duplicates on 2 resubmitted trips, 2026.

## The landings decided what is a copy

The landings are the witness that never reads the logbook's times.

- **afli, duplicates on one trip** (897 trips with one landing): logbook catch / landed catch has a median of
  **2.12 with every copy and 1.01 with one**. 96.1 % of the trips are nearer the landing with one. Trips with no
  twin have 0.99.
- **fs_afladagbok, resubmitted trips** (1,837 pairs that took the same landing): **0.96 for either trip, 1.93 for
  both.**
- **Same-time records are not copies** (198 afli trips): 1.09 with both, 0.90 with one, and dropping one brings a
  trip nearer in only 45.5 % of trips. Where the two catches share no species, dropping one leaves 0.08 of the
  landing. Where the species are the same and the weights differ (108 trips), dropping one is nearer in 56.5 %:
  some may be re-entries with an edited weight, but the landings cannot say which. All are kept.

## The rule (maintainer's choices)

- A duplicate is a station of the same vessel and schema with identical t1-t4 (at least one a time of day) and
  identical catch: every species, condition and weight. No catch matches only no catch.
- **The first record keeps the link and the catch**: not deleted (`eytt_deleted`), then the lowest `.sid`. The
  maintainer chose "the landing-linked record, then the lowest `.sid`". The landing link cannot be read before
  `lid_map`, and `lid_map` needs the duplicates out first, because it sums a trip's catch (steps 6-7). The two
  rules differ in 17 of 7,529 duplicate sets, all on two trips where only the later is linked. With the
  duplicate out, `lid_map` matches the kept trip on its own keys.
- A trip all of whose stations are duplicates of one other trip is a duplicate trip. The other is the kept trip.
- Nothing is deleted. `station.parquet` and `trip.parquet` carry `twin` (`kept`, `duplicate`, `same_time`) and
  `twin_of` (the kept `.sid` or `.tid`). `catch.parquet` keeps every row.

## What changed

- **`curate/logbook.R`** computes `twin` and `twin_of` on the merged tables. `station_type` (decision 084) counts
  a vessel's records per day without duplicates: a copy made a one-record day look like two.
- **Left out wherever a duplicate distorted a result:**
  - `catch_by_species_station`: no rows for a duplicate.
  - `catch_by_species_trip`: no catch from a duplicate.
  - `lid_map`: no duplicate trip; a trip's catch and main gear without duplicates. A resubmitted trip used to
    take its original's landing, so `n_trips` said 2 for one trip.
  - `station_window`: no window for a duplicate, so the kept record's window stands. Since decision 091 the
    higher-keyed twin already got an empty window, so the trail did not give one fix to two records.
  - `trip_voyage`: no duplicate trip. On its original's voyage it emptied the trail's `.tid_voyage`.
- **Same-time records stay everywhere.** Their windows follow decision 091: the higher key is emptied.
- **Reported:** the correction entry; "Twin records" in `docs/merge.qmd`, whose annual totals now leave
  duplicates out; `twin` and `twin_of` in `docs/data-dict.yaml`; this record.

## Open

- Same-time records cannot be placed apart by the track, because their times are equal. Where their positions
  differ, the track could say which record the times belong to.
- The 382 date-only groups are the whole-day problem (`station_time_whole_day.yml`), not twins.
- The `once` project reads `trip.parquet` and `fishing_sample.parquet`. It is frozen (decision 075) and was not
  rebuilt. The logbook gained two columns and kept every row.

The counting scripts are in `$FISHYDATA/archive/2026-10-todo58/`.
