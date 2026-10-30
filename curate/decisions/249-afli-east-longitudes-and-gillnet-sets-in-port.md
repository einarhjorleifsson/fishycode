# 249 — afli's east longitudes judged by the track and flagged, and the gillnet set times in port that plan 053 does not flag

*2026-10-30. Plan 054 step 1, TODOs 162 and 103. Measured by Claude (AI) in a side session, read-only, on the store of
2026-10-29, and not checked by a person. The scripts and counts are in
`$FISHYDATA/archive/2026-10-30-plan054-stations-vs-track/`, with the station lists in `counts/t162_station.parquet` and
`counts/t103_station.parquet`; a rerun from a fresh scratch folder gave the same counts. The choices are the
maintainer's, put by Claude with AskUserQuestion the same day: both as proposed. Nothing is built: the flag rides plan
054's rebuild A (step 2f), and the profile's changes ride step 2a.*

## TODO 162: afli's east longitudes

Each afli station east of 10.75° E and south of 67.66° N was judged by its vessel's nearest AIS fix. Both readings were
measured, the recorded east one and its mirror to the west, within 5 km. The fix was sought in the narrowest window that
had one: the station's own times ± 1 h, then its day, then its trip. The GPS logger was left out as a witness, because
its positions come from the same afli message.

| outcome | stations |
|---|---:|
| west: the sign is switched (the vessel within 5 km of the mirror) | 62 |
| west side, beyond 5 km | 13 |
| east: the position is real | 181 |
| east side, beyond 5 km | 4 |
| cannot be judged (the vessel near neither reading) | 3 |
| no fix | 86 |
| **from 2007** | **349** |
| before 2007, no track | 87 |

- **The 75 on the west side** are all at 63-66.9° N and 12.6-33.8° E, which is Iceland's waters read as east. All are
  on afli's electronic logbook, 2011-2022.
- **The 185 on the east side** are trawlers on the Norwegian shelf, at 66.5-67.65° N and 10.8-12.4° E, 2009-2016,
  except one in the Baltic.
- **The 86 with no fix** are one vessel's two trips in March-April 2011, inside the same Norwegian box.
- **The 3 that cannot be judged** have a wrong latitude, or wrong digits in the longitude, as well as or instead of the
  sign.
- No afli station east of the line is later than 2022.

**Chosen:** the stations are flagged, not corrected. The merge reads no AIS, so the judgment enters as a reviewed,
frozen list, `overrides/afli_east_longitude_reviewed.csv` (`.sid`, outcome), made from `counts/t162_station.parquet`.
The merge turns it into `coord_flag`:
- `lon_sign_switched` on the 75;
- `lon_sign_unjudged` on the 176 (no fix 86, cannot be judged 3, before 2007 87);
- nothing on the 185 the track puts east.

`lon1` stays as recorded. Moving the 75 to the west would be a correction, which would need a decision of its own.

## TODO 103: gillnet set times in a port call

Of 401,891 kept gillnet stations, 98,259 have a set time, and 31,666 of those lie in a port call. Plan 053's rules, as
written (none is built yet), flag 21,159 and note 203 (T13). **10,304 are not flagged:**
- Fishing Log 2.7: 4,285;
- Fishing Log 2.6: 3,632;
- Fishing Log 2.0: 1,450;
- Trackwell raun: 923;
- other apps: 14.

The three Fishing Logs are all on the afli route.

| pattern (the first that matches) | sets |
|---|---:|
| a copy of another time (the landing, a haul, the previous haul's end, 00:00, the departure day) | 190 |
| a fixed offset from the haul start: 270 min a minute off or plus whole days, or 210 min (plus whole days) | 1,585 |
| the port call holds the vessel's own logged hauls: a trip the AIS track missed | 1,028 |
| no fix within 30 min: the port call spans a gap in the AIS | 4,175 |
| seen in port within 1 h of leaving | 1,108 |
| seen in port within 1 h of arriving | 503 |
| lumpfish nets, seen in port mid-call | 213 |
| stamped with seconds, seen in port mid-call | 886 |
| on the half-hour grid back from the haul, seen in port mid-call | 26 |
| **unexplained:** a typed set, seen in port mid-call | **590** |

- **By year.** In 2008-2013 the gaps in the AIS dominate (Fishing Log 2.0 and 2.6). In 2015-2021 Fishing Log 2.7's
  offsets and stamps dominate. From 2023 it is mostly Trackwell raun's unexplained typed sets.
- **210 min is a second placeholder on the afli route.** A 210-min soak lies in port on 61 % of 900 sets, and on 53 %
  with whole days added. T2's form is in port on 70 % and T3's on 38 %, against 6-15 % for other half-hour soaks.
- **Lumpfish nets** lie in port on 44 % of their unflagged sets, against 15 % for other nets.
- **A stamp means nothing on the afli route.** It is Fishing Log 2.7's normal form (20,401 of 20,865 sets) and lies in
  port on 13 %, about as often as a typed set (14 %).
- **Trackwell raun's stamped sets** lie in a port call on 32 %, but a fix sees the vessel in port on only 8.8 %, the
  same as its typed sets (9.0 %).
- **The unexplained** Trackwell raun sets are on 26 vessels, and two vessels hold 296 of them. Each types a set about
  4 h before the haul starts, while in port, about 3 h before leaving.
- **Plan 053's T15 compares with a date.** afli's trip departure is 00:00 on every trip, so T15 in fact takes the set
  times at 23:59:00 on the evening before the departure date (3,480 of its 3,504).

**Chosen (for plan 053's profile, step 2a):**
- T2 and T3 also apply on the afli route.
- A new row for the 210-min offset (± 1 min, plus whole days). These forms hold 3,399 gillnet sets on the afli route,
  1,603 of them in port.
- T15 is relabelled as 23:59 on the evening before the departure date.
- T12 stays on Trackwell raun only.
- Left as recorded, with the reason stated:
  - the AIS gaps and the calls that hold logged hauls (5,203), a matter of the track (TODO 98, the voyage
    definition), not of the set time;
  - the sets near a call's start or end (1,611);
  - the lumpfish nets, stamps and grid sets seen mid-call (1,125).
- The 590 unexplained are listed (`p10` in `counts/t103_station.parquet`).

## Open

- Do lumpfish nets lie inside the port radii, or are their boats' tracks just sparse?
- What are the two vessels' typed sets, 4 hours before the haul?

TODO 162 closes when the flag is built in rebuild A. TODO 103 closes when decision 198's rule is built and traced there.
