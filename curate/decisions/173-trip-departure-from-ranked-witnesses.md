# 173 — Every logbook trip's departure, time and port, from ranked witnesses: AIS, the logbook, STK, the quota system, the phones

*2026-10-22. The maintainer's choices: "rank AIS first, then own, then STK; build TODO 121"; the logic as a ramb step
with a thin fishycode caller; the quota system's records and the phone calls below STK; scratch-tested and committed,
the real build left to the pending rebuild. Extended the same day by decision 174: the return (T2, pid2) from the same
witnesses, a date-only value giving way to a time on its day; the step and its table are renamed `trip_reconciled`
(`curate/trip_reconciled.R`, `curated/link/trip_reconciled.parquet`). The names below are those of this record's day.
He added that the quota system's records matter beyond the departure:
"the line incentive has then a special longline gear code in the landings". Written by Claude (AI); the code and
the scratch run are Claude's and have not been checked by a person. Not built. The witnesses are measured in
decision 172.*

*Amended 2026-10-23, from Claude's audit of the decision records (not yet checked by a person). Built 2026-10-22 in
decision 180. The `ais` witness is the one voyage `trip_voyage` links, the one the trip overlaps most: for a trip that
spans several voyages, its AIS `T1` (and `T2`, decision 174) are that voyage's bounds, not the trip's. Decision 155
counted 13,084 trips with timed stations in two or more voyages. The many-to-many link is TODO 90 (plan 031 ask f)
and the first item of TODO 101. Fixed in code by decision 193, not yet built: the witness spans the voyages the trip's
stations lie in.*

## Built in code

- **ramb 2026.10.22.1, `rb_add_trip_time()`** (step 1, a builder). It is the step `docs/one_flow.qmd` planned as
  `rb_reconcile_time`, named by its output shape (plan 032). Each trip takes its time from the best-ranked witness
  that holds one, and its place from the best-ranked witness that holds a place, each on its own: STK holds a time
  without a port from 2014. Each value carries the witness it came from and its basis. Every trip falls in one outcome
  per field: `none`, `one`, `agree` (every witness within `tolerance`, 1 hour, of the chosen time; the same port),
  `differ`. `_spread_s` gives the largest distance to another witness's time. 142 tests pass, 2 of them new.
- **Three preprocessing adapters, the witnesses beside the track and the logbook:**
  - `sources/stk/voyage.R` → `staging/stk/voyage.parquet`: STK's 3,186,904 recorded voyages. Ports come from the
    events' STK codes through `stk_hid_pid`, else the numeric port: 1,420,908 departures have one.
  - `sources/quota_trip/convert.R` → `staging/quota_trip/trip.parquet`: the quota system's trip records, kept as trips
    in their own right. That is 172,450 line-incentive (2004-2020) and 231,015 coastal-fishing (2009-2023) landings,
    each with its regime, the landing's gear code (`gid_landing`) and the hand-baited longline flag (`linu_ivilnun`,
    on 172,449 line-incentive records), and its departure and return from STK, else the phone line.
  - `sources/phone_call/convert.R` → `staging/phone_call/call.parquet`: 566,257 calls in or out of port, from the
    Coast Guard, the line-incentive phone line and the days-at-sea boats.
- **The flow step `curate/trip_departure.R`** → `curated/link/trip_departure.parquet`: one row per logbook trip,
  twins left out. The rank is `ais`, `own`, `stk`, `quota`, `phone`; each witness's own time and port are kept beside
  the chosen ones (`T1_ais`, `pid1_ais`, ...). The witnesses:
  - `ais` is the voyage `trip_voyage` links;
  - `own` is the logbook's T1 and port for fs_afladagbok and adb only. afli's T1 is the first fishing day and
    aflaskeyti's is synthesised, so neither is a departure; adb's port 0 is the placeholder of decision 172;
  - `stk` is the latest STK voyage containing the trip, its time and port together;
  - `quota` is the record of the trip's landing through `lid_map`, where no other trip claims that landing;
  - `phone` is the latest valid out-call on T1's day or up to 3 days before.
- Targets `stk_voyage`, `quota_trip`, `phone_call`, `trip_departure` and their raw file targets.

## Scratch run

On a scratch `$FISHYDATA` against the store as built (`raw/`, `curated/reference`, `curated/logbook`,
`trip_voyage` linked); the real store was not written. The result has 1,853,260 rows, one per trip. Witnesses and
agreement are as decision 172 measured them:
- AIS against the logbook's own: a median of 13-14 minutes, 76-77 % within 1 hour, the ports equal on 94.6 % (adb)
  and 94.7 % (fs_afladagbok);
- STK times on 730,493 afli trips and AIS times on 644,600, as in `09_times.R`.

STK ports reach 446,696 afli trips against decision 172's 454,827: the step takes time and port from the same voyage,
the latest that contains the trip, where the measurement took the latest voyage with a port.

| logbook | T1 from ais / own / stk / quota / phone | no T1 | pid1 from ais / own / stk / quota / phone | no pid1 |
|---|---|---:|---|---:|
| afli | 644,600 / - / 177,296 / 2,539 / 13,311 | 823,277 | 643,482 / - / 177,232 / 1,579 / 7,430 | 831,300 |
| fs_afladagbok | 147,752 / 6,043 / - / - / - | 0 | 147,722 / 2,182 / - / - / - | 3,891 |
| adb | 37,342 / 505 / - / - / - | 0 | 37,334 / 483 / - / - / - | 30 |
| aflaskeyti | 481 / - / - / - / - | 114 | 264 / - / - / - / - | 331 |

Every trip falls in one outcome per field, and both fields sum to the 1,853,260 trips:
- the time: 823,391 none, 238,867 one, 573,154 agree, 217,848 differ;
- the port: 835,552 none (823,391 with no time either, 12,161 with a time and no port), 550,221 one, 444,181 agree,
  23,306 differ.

The differing times are afli trips (173,557), where another witness lies more than an hour from the chosen one, and
fs_afladagbok (35,886) and adb (8,403) trips, where the logbook's own does.

## Not built

`tar_outdated()` lists 36 targets: the 29 of decisions 165, 169 and 170, and the 7 new ones (`stk_voyage_raw`,
`stk_voyage`, `quota_trip_raw`, `quota_trip`, `phone_call_raw`, `phone_call`, `trip_departure`). The build is the
maintainer's, with the pending rebuild (`tar_make_isolated()`).

## Left open

- The return (`T2`) the same way, with the landing as a witness.
- Using the departure downstream (the trail, the trip ↔ landing link) and the quota system's regime and gear on the
  trips: what reads `trip_departure` is not decided.
- adb's ports carry no `pid` in `curated/logbook/trip.parquet`; the step maps them itself.
