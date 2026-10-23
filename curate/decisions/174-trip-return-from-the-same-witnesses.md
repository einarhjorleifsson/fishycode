# 174 — The return (T2, pid2) from the same ranked witnesses as the departure; a date-only value gives way to a time on its day

*2026-10-22. The maintainer: "do the return T2 the same way", and, asked whether the logbook's return should rank
below STK's, "why have different approach for T1, pid1 and T2, pid2?". Written by Claude (AI); the code and the
scratch run are Claude's and have not been checked by a person. Not built. Extends decision 173; its table is renamed
`trip_reconciled`.*

*Amended 2026-10-23, from Claude's audit of the decision records (not yet checked by a person). Built 2026-10-22 in
decision 180. As at the departure (decision 173), the `ais` witness is the one voyage `trip_voyage` links: for a trip
that spans several voyages, its AIS `T2` is that voyage's end, not the trip's. Decision 155 counted 13,084 trips with
timed stations in two or more voyages (TODO 90, TODO 101). Fixed in code by decision 193, not yet built: the witness
spans the voyages the trip's stations lie in.*

## Why one approach

The only argument for a different ranking was that a logbook's return may be written before the trip ends
(`docs/one_flow.qmd`). Against the AIS voyage, the logbook's T2 is less precise than its T1, but not of another kind:

| logbook against AIS | median | within 1 h | logbook > 1 h earlier |
|---|---:|---:|---:|
| T1, fs_afladagbok / adb | 14 / 13 min | 76 / 77 % | 5 / 4 % |
| T2, fs_afladagbok / adb | 31 / 29 min | 65 / 65 % | 15 / 15 % |

AIS ranks first anyway. The logbook's own and STK never compete for fs_afladagbok and adb trips, since STK ends in
2021-02. Where they do compete (afli), the logbook's T2 is the landing day only, a date. So the ranking is the same
for both ends: AIS, own, STK, quota, phone. The landing register witnesses the return only, and comes last. The one
rule both ends needed is about precision, not rank.

## Built in code

- **ramb 2026.10.22.2:** `rb_add_trip_time()` takes an optional `day` flag per witness: `TRUE` where its time is a
  date only. A first-ranked witness that knows only the day gives way to the best lower-ranked witness with a time on
  that day. A date-only value agrees with any time on its day. `_day` marks results known only to the day. Without
  `day` the results are as before. 143 tests pass, one of them new.
- **`curate/trip_reconciled.R`** (was `trip_departure.R`) → `curated/link/trip_reconciled.parquet`: T1, pid1 and T2,
  pid2 for every logbook trip (twins left out), each with its witness, basis and outcome, and each witness's own
  values. For the return:
  - `own` is the logbook's T2 and port for afli (its landing day), fs_afladagbok and adb. adb's port is mapped
    through `port.parquet`, 0 read as missing;
  - `stk` and `quota` take the in-event of the same voyage or record as the departure;
  - `phone` is the latest valid in-call on T2's day or up to 3 days before, no earlier than T1;
  - `landing` is the trip's landing in `lid_map`, its day and port.

  A logbook time at midnight counts as a date only, at both ends. Target `trip_reconciled` (was `trip_departure`).

## Scratch run

Same scratch store as decision 173, the real store not written. The result has 1,853,260 rows, one per trip. The
departure is unchanged in value, witness and port on every trip. 622 departure outcomes moved, because date-only
logbook times are now compared by date: 568 from differ to agree, 54 from agree to differ.

| return | none | one | agree | differ |
|---|---:|---:|---:|---:|
| T2 | 122 | 822,385 | 818,010 | 212,743 |
| pid2 | 47,667 | 779,847 | 956,296 | 69,450 |

T2 comes from AIS on 830,175 trips and from the logbook's own on 843,392. Of the latter, 836,844 are afli trips
known only to the day: no other witness gives a time on their landing day. STK gives T2 on 168,479 afli trips, phone
calls on 10,658 and the quota system on 364. Each of these is a time on the logbook's landing day, the day refined. The
landing gives aflaskeyti's 70. 837,307 returns are dates only. The differing times are mostly AIS against the
logbook's own: on fs_afladagbok 54,010 of 147,752 trips and on adb 14,080 of 37,342, as the medians above lead one to
expect, and on afli 123,472 of 644,600.

## Not built

`tar_outdated()` lists the 36 targets of decision 173, `trip_reconciled` in place of `trip_departure`.

## Left open

- What reads the reconciled times and ports downstream, and the quota system's regime and gear on the trips.
