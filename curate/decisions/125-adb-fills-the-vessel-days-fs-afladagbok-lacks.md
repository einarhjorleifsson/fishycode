# 125 — adb fills every vessel-day afli and fs_afladagbok lack: its lower bound is a floor, not a handover

*2026-10-17. Chosen by the maintainer: TODO 80's option (b), with the floor at 2020 ("within vessel x day if fs
exists, use that"). Written by Claude (AI-assisted). Measured read-only on staging; tested by running the merge
against a scratch `$FISHYDATA`, and nothing under `$FISHYDATA` was written. Not built; that is TODO 77's build.*

## What was wrong

`curate/logbook.R` read adb only from `ADB_DATE_MIN` = `FS_DATE_MAX` + 1 = 2026-01-01, on the ground that
fs_afladagbok's dump covers 2025 (decision 023). It does not. The dump is a one-time copy of the Fisheries
Directorate's e-logbook, and it ends on 2025-11-28, thinning before that: of adb's vessel-days it holds at least
92 % up to 11-24, 81 % on 11-25, 69 % on 11-26, 20 % on 11-27, 3 % on 11-28, then 4 strays to 12-12. adb's stations
from 2025-11-27 to 12-31 were dropped with nothing else holding their vessel-days (plan 024 §3), and so were the
late-November vessel-days the dump never received.

fs_afladagbok and adb are copies of the same e-logbook: 467,635 of fs_afladagbok's 469,881 station ids are in adb,
467,560 of them on the same vessel and day.

## The choice

Two ways out were measured against the merge as it stands after decision 124 (stations as recorded, kt of catch):

| | admits | removes | leaves out |
|---|---|---|---|
| (a) handover at fs_afladagbok's last full day, read from the data: the last day it holds at least half of adb's vessel-days (2025-11-26) | 5,040 adb stations, 1,963 vessel-days, 196 vessels, 1,086 trips, 52.5 kt, all 2025-11-27 to 12-31 | 31 fs_afladagbok stations (0.09 kt), each replaced by its adb copy (same id, same vessel-day) | 238 adb stations (4.1 kt) on vessel-days the dump never received, 235 of them 2025-11-16 to 11-26 |
| (b) no handover: the tier anti-join decides, adb floored at `FS_DATE_MIN` (2020-01-01) | 5,664 adb stations: 5,009 from 2025-11-27 on (52.4 kt), the 238 of late 2025 (4.1 kt), 417 of 2020-2024 (0.06 kt) | none | adb before 2020 |

The maintainer chose (b). It is the rule the merge already states, afli > fs_afladagbok > adb by vessel-day: where
fs_afladagbok holds a vessel-day it is used, whatever the date, because adb is the poorer copy of the same trip (no
gear id of its own). A date handover would drop the vessel-days the dump lacks before it, and keep fs_afladagbok's
strays after it only by accident. On the vessel-days fs_afladagbok does hold in late November, adb holds more
stations on 3 (6 stations, 24.8 t), so the partly received days cost next to nothing.

**The floor.** adb before 2020 is misdated: 108 stations on vessel-days nothing holds, 47 in years 3 to 800 and 61
in 2001-2018, and 99 of the 108 lie more than a day outside their own trip's dates. `ADB_DATE_MIN` is now
`FS_DATE_MIN`, the floor fs_afladagbok has. adb's 2019 (1,198 stations) is all on vessel-days afli holds.

**What (b) lets in besides December.** The 417 stations of 2020-2024 are small: 360 in 2020 (18.6 t, 343 without
catch), 32 in 2021 (11.9 t, 18 without), 24 in 2022 (25.2 t), 1 in 2024 (3.3 t, the same kg as a kept station of
the vessel a day off). 66 of them are adb copies of fs_afladagbok stations that carry another vessel or day than
their fs_afladagbok copy, which yields to afli: probably afli hauls entered again. None is kept from
fs_afladagbok under its own id. They are left in, as the rule has them; a check of them belongs to TODO 79's
station fate table, not to the merge.

## What changed

`curate/logbook.R`: `ADB_DATE_MIN <- FS_DATE_MIN` (was `FS_DATE_MAX + 1`), and the comments that called it a
handover. `FS_DATE_MAX` stays at 2025-12-31; it now only bounds fs_afladagbok's own misdated strays (2027-2031,
which `DATE_MAX` drops too).

## Tested against the current code

The merge as committed (last changed in a8b285c) and the changed merge were run on the same scratch `$FISHYDATA`: afli's staging from
decision 124's scratch run (with `copy`), fs_afladagbok's and adb's linked from the real staging. The HEAD run equals
decision 124's scratch output in all four tables. Every table of the changed run was compared with it, row by row on
its key and column by column on shared rows:

| table | change | shared rows |
|---|---|---|
| `curated/logbook/station` | +5,664 adb, none removed | equal in every column, `twin` and `station_type` included |
| `curated/logbook/trip` | +1,448 adb, none removed | equal |
| `curated/logbook/fishing_sample` | +5,664 adb, none removed | equal |
| `curated/logbook/catch` | +15,475 rows (56.55 kt), none removed (whole rows compared) | equal |

The 5,664 are the stations measured above, by year. None is a twin. They carry no gear (adb's gear is not read,
decision 023), so their `station_type` is read in vessel-years of their own, 4,728 `operation` and 936 `event`,
and no kept station's changes.

TODO 80's check, on the scratch output: no adb station between the bounds is dropped on a vessel-day that
`curated/logbook` does not hold (655 from 2020 to 2025-11-26 and 5,009 after, before the change). 31 adb stations from
2025-11-27 on are still dropped, all on vessel-days fs_afladagbok holds with its own copy. Outside the bounds, 134
are dropped on vessel-days nothing holds: the 108 misdated ones before 2019, and 26 in 2027-2031.

Plan 024 §2.2 counted 191 such adb stations in 2022 against the build of 2026-10-16. 167 of them now yield to
decision 124's paper stations from fs_afli, which hold those vessel-days.

## Not done here

- The build (TODO 77) writes it to `$FISHYDATA`; TODO 80's check follows it.
- `docs/output-schema.md` still describes the merge before the restructuring (adb not a tier, `FS_DATE_MAX` as the
  bound).
