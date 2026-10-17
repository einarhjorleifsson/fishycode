# 123 — The stations only fs_afli holds are in `curated/logbook` already, all but 248

*2026-10-17. Written by Claude (AI-assisted), read-only on `$FISHYDATA`. Measured: `raw/oracle/afli/` and
`raw/oracle/fs_afli/` (the dumps of decision 122) against `curated/logbook/` and `curated/landing/` as built on
2026-10-16 (decision 112). Station ids are `visir` in both schemas, and `.sid` with schema `afli` in curated. Nothing
was changed, and no adapter. Closes TODO 76; the choice it leaves is TODO 78. Extended the same day, at the
maintainer's request: where the data came in, option 3's move measured in part, option 4, and the 162 paper stations
checked against the landings and the track.*

## The answer

The stations only fs_afli holds are records fishycode already has, with 248 exceptions. Almost all are in
`curated/logbook` under the same id: `afli.stofn`, which the afli adapter reads, holds them. Only `afli.rafr_stofn`,
the table of electronic submissions, lacks them. Most of the rest are the same hauls through fs_afladagbok, or
deleted stations entered again. So fs_afli is not a missing source of logbook trips.

## The stations

169,691 station ids are in fs_afli and not in afli: 169,502 in `rafr_stofn` and 2,090 in `stofn`. 1,901 ids are in
both. Decision 122's "paper" stations with negative ids are electronic ones, held in `rafr_stofn` too.

| group | stations | vessels | dates | in `curated/logbook` |
|---|---|---|---|---|
| A. in `afli.stofn` | 165,459 | | 2019-2024 | all 165,459, by id, as afli stations |
| B. deleted (`eytt` = 1), not in `afli.stofn` | 2,039 | 144 | 2020-06-22 to 2023-04-14 | 2,020 on the same vessel, day and gear (1,983 afli, 37 fs_afladagbok), 2,001 of them within 5 km; 2,037 within a day |
| C. electronic, in `fs_afli.stofn` (`uppruni` `PAPPÍR`) | 1,898 | 93 | 2021-08-03 to 2022-06-15 | 1,857 on the same vessel, day and gear, 1,856 of them from fs_afladagbok at the same position (0 km to the 90th percentile); 1,879 within a day |
| D. electronic, in `rafr_stofn` only | 106 | 11 | 2002-07-03 to 2018-12-27 | 22 on the same vessel, day and gear (afli); 39 within a day |
| E. paper, positive ids | 189 | 30 | 2019-06-06 to 2022-06-14 | 17 on the same vessel, day and gear; 27 within a day |

Group A by year: 324 in 2019, 40,469 in 2020, 85,025 in 2021, 37,739 in 2022, 1,889 in 2023, 13 in 2024. Their
catch is the same in all three places: 2,362,745,786 kg in `afli.afli`, in `fs_afli.afli` and in
`curated/logbook/catch`.

A match is a curated station whose trip has the same `vid` as the station's `skipnr`, on the same date (or within
one day). The gear is `veidarf` mapped through `reference/gear` (`version` old), compared with `fishing_sample.gear`.
Every same-day match has the same gear. Positions are DDMM (`breidd` 6636 is 66.6° N).

**Not held: 248 stations, not deleted, with no curated station of the vessel within a day.** They hold 492 t.

| group | year | gear | stations | vessels | t | a landing by the vessel within 3 days |
|---|---|---|---|---|---|---|
| E | 2022 (04-11 to 06-14) | LHM | 123 | 19 | 81 | all |
| E | 2022 | GNS | 38 | 5 | 65 | all |
| E | 2020 | LHM | 1 | 1 | 1 | yes |
| D | 2014-2016 | LLS | 45 | 2 (44 are vid 2652's) | 141 | 49 of D's 67 |
| D | 2002, 2003, 2012, 2015 | SDN 11, GNS 6, LHM 3, OTB 1, OTM 1 | 22 | 6 | 191, 160 of it on one OTM haul | |
| C | 2021-2022 | LHM 10, OTB 9 | 19 | 3 | 13 | 15 of 19 |

Group E's 161 stations of spring 2022 stand beside 15,127 jig and gillnet stations (22,918 t) in `curated/logbook`
for April to June 2022: about 1 % of the stations and 0.6 % of the catch. Their landings are in `curated/landing`.
The trips are known, and the logbook part lacks their positions. Two deleted stations of 2020 also have no match.

## The other tables with more rows

Decision 122 counted 25 tables with more rows in fs_afli. Two are the station tables above. Of the other 23:

- **The tables the afli adapter reads.** `toga` has 1,504 more rows, `lineha` 586 and `afli` 6,501; `gildra` and
  `hringn` are the same. Every extra row is on one of the 4,232 stations not in `afli.stofn` (groups B to E). No
  station both schemas hold has a different number of rows. The same holds for `soknartegund` (+3,582), `beita`
  (+169), `medafli` (+16) and `spendyr` (+28).
- **The `rafr_` detail tables** (read by no adapter). Their extra rows are on the extra electronic stations:
  `rafr_afli` has 536,865 more rows, 536,804 of them on those stations and 523,396 on group A; `rafr_toga` has 134,276
  more and `rafr_lineha` 34,290. On group A, `rafr_afli` agrees with `afli.afli` on 522,895 of 522,902 station-species
  pairs. Two of the seven that differ are placeholders of 9,999,999 kg in `rafr_afli`, which `afli.afli` holds as 334
  and 159 kg; together they make up the whole 20,005,505 kg gap between the two sums. Four are other edits, and one
  species is only in `rafr_afli`.
- **The logger.** `afli.sjalfvirkir_maelar`'s overview says 2,714 rows. That is the count left by a by-year resume
  (decision 121); the files hold 28,234,223 rows and fs_afli's 28,294,442. The 60,219 extra rows are on 1,500
  group C stations (2022). `fs_afli.rafr_sjalfvirkir_maelar` has 5,058,454 more rows than afli's, 4,916,645 of them on
  135,436 group A stations. `afli.sjalfvirkir_maelar` already holds those fixes: for 2021-2023,
  `curated/logbook/sensor_gps`'s `gps1` counts (2,602,793, 1,070,987 and 39,477) equal fs_afli's extra fixes exactly.
  So `curate/logbook_sensor_gps.R` is not short of them.
- **Not followed further.** These tables hold no stations: the load logs (`rafr_hledsla_log` +1,388,580,
  `rafr_hledsla_log_runs`), the receipts of submissions (`afladagb_xml_mottaka` +81,454, `afladagb_skil`,
  `afladagb_skil_linur`, `rafr_afladagb_skip_t`), `rafr_soknartegund`, `rafr_beita`, `rafr_hringn`, `rafr_medafli`,
  and the code list `rafr_stofn_spendyr_fuglar` (+10).

## Two things the afli adapter misses

- **The deletion flag.** `sources/afli/convert.R` reads `eytt_deleted` from `afli.rafr_stofn`, so every group A
  station carries NA (the script's comment calls them the "2020–2022 direct-load"). `fs_afli.rafr_stofn` says 61 of
  them are deleted and 165,398 are not. Of the 61 in `curated/logbook`, 23 are already twin duplicates (decision 094).
  The other 38 count as live stations.
- **The 248 stations** above, and group C's 1,898, which are in `fs_afli.stofn` only.

## Where the data came in

| | afli | fs_afli |
|---|---|---|
| receipts of submissions (`afladagb_xml_mottaka`) | 483,738, 2002-12-05 to **2020-07-23** | 565,192, 2002-12-05 to **2024-07-12** |
| load log (`rafr_hledsla_log`) | 6,595,396, 2011-08-25 to **2020-07-20** | 7,983,976, 2011-08-25 to **2025-11-28** |
| last row written to `rafr_stofn` (`snt`) | 2020-07-23 | 2024-07-12 |
| written by (`rafr_stofn.sng`) | `OPS$AFLI`, every row | `OPS$AFLI`, every row |
| Oracle's statistics on `stofn` last gathered | 2026-10-08 | 2023-04-19 |

The receipts name the vessels' software, Trackwell's Fishing Log in most. What follows is read from these columns. It
is not proven: no job, database link or code shows a move, since the catalogue's lists of them are empty for our
account (decision 121). A database administrator at MFRI or the Directorate can confirm it.

- **Until July 2020** one process, Oracle user `OPS$AFLI`, received and loaded the electronic logbooks, and both
  schemas hold the same history. Either it wrote both, or fs_afli was cloned from afli then. The data cannot tell.
- **From 2020-07-23** receiving went on in fs_afli only. The new electronic stations still reached `afli.stofn`
  (group A, to 2024), but not `afli.rafr_stofn`. `fs_afli.rafr_stofn.er_lesid` ("has been read") is 1 on 95,634 of
  them, from 2021-03-18: they were read from fs_afli into `afli.stofn`, the adapter's "2020–2022 direct-load". The
  flag is also 1 on 1,876 stations that never reached afli (2021-05 to 2022-06), so it does not prove the move.
- **Edits followed the stations.** Of the 3,098 shared electronic stations whose last change differs, fs_afli's
  copy is the later in 2,981, all changed between 2020-07-27 and 2023-01-29. Where the two `rafr_stofn` copies
  differ (about 170 stations, in nearly every column), `afli.stofn` holds fs_afli's edited value (163 of 171 for the
  vessel, 162 of 170 for the date). On these 2,981 the catch is 74,055,833 kg in both `afli.afli` and
  `fs_afli.afli`, against 70,863,326 kg in `afli.rafr_afli`. Only afli's `rafr_` tables are frozen at 2020-07-23.
- **afli is the copy MFRI still works on.** Its statistics were gathered this month; fs_afli's stopped in 2023-2024.
  afli also holds edits fs_afli lacks: 32 stations (4 in 2018, 6 in 2019, 19 in 2020, 3 in 2021) have a date in
  afli and none in fs_afli.
- **Groups C and E were never read across.** They stayed in fs_afli, and group C's hauls reached curated through
  fs_afladagbok instead.

So for the electronic logbooks of 2020-2024, the data came in through fs_afli and were moved to afli, with most of
fs_afli's later edits. afli adds edits of its own. For the stations afli holds, its copy is the one to keep.

## Option 3's move, measured in part

Simulated read-only in scratch. The adapter's `stofn` filters and trip key, applied to `afli.stofn`, reproduce
`staging/afli` exactly (6,844,567 stations, every `.tid`). The (vid, date) tiers of `curate/logbook.R` then keep the
same 374,681 fs_afladagbok stations as `curated/logbook`. With `fs_afli.stofn` in place of `afli.stofn`:

- 979 vessel-days become afli's. 750 of them hold fs_afladagbok stations: 749 through new stations, 1 through a
  shared station that changes day.
- 1,863 fs_afladagbok stations leave `curated/logbook` and none come back: 1,862 in 2022, 94 vessels, 405 trips (403
  whole; 2 split, leaving 2 stations behind), 13,649 t. By gear: OTB 1,139 (7,623 t), SDN 332, LHM 148, LLS 146
  (1,058 t), GNS 85, OTM 13 (4,020 t).
- The 32 stations with no date in fs_afli drop out, and 36 shared stations move to another vessel or day.
- Not measured: the fields of the hauls that come in against those that leave (times, effort, catch by species).
  Option 4 makes it unnecessary.

## The 162 paper stations against the landings and the track

Group E's 162 stations with no curated station make 156 trips by the adapter's trip key (vessel, landing date
`ldags`, landing port `lhofn`); 155 of them hold no other station. They were measured read-only against
`curated/landing` and `curated/ais/trail` (2022-04 to 2022-06, and 2020-05 for the one station of 2020).

- **Landings.** Every trip has a landing by the vessel: 149 on the logbook's landing date, 7 one or two days from it.
  The port code agrees on 71. In the rest, the paper logbook mostly gives port 0 (blank), and 13 give Flatey (49)
  where the landing is in Stykkishólmur (47).
- **Kg by species**, logged (`fs_afli.afli`) against landed, per trip, where both sides have the species. The baseline
  is the curated jig and gillnet trips with stations in April-June 2022 (`catch_by_species_trip`):

| gear | species | paper trips, median ratio | curated trips, median ratio (interquartile) |
|---|---|---|---|
| LHM | cod (1) | 116, 0.98 | 10,527, 0.98 (0.94-1.02) |
| LHM | saithe (3) | 59, 0.95 | 5,435, 0.95 (0.77-1.11) |
| LHM | golden redfish (5) | 30, 1.00 | 2,456, 1.00 (0.71-1.33) |
| GNS | lumpfish, female (951) | 33, 0.98 | 1,137, 0.95 (0.82-1.00) |
| GNS | cod (1) | 14, 0.98 | 1,569, 0.93 (0.76-1.06) |

The 156 trips log 146,882 kg in all and land 160,379 kg.
- **The track.** For each station: the vessel's pings on the station's date (UTC), and the distance from the
  station's position to the nearest. Curated jig and gillnet stations of the same months get the same measure. The
  paper positions are in whole minutes (DDMM), so to about 1.9 km in latitude. 70 % of these vessel-days' pings are STK's.

| stations | n | vessel's track that day | at sea | pings the flow marks fishing | median km to nearest ping | ≤ 2 km | > 20 km |
|---|---|---|---|---|---|---|---|
| paper GNS | 38 | 38 | 38 | 38 | 1.0 | 29 | 3 |
| curated afli GNS | 1,227 | 1,219 | 1,224 | 1,217 | 0.4 | 1,140 | 26 |
| curated fs_afladagbok GNS | 1,770 | 1,694 | 1,719 | 1,550 | 1.2 | 945 | 566 |
| paper LHM | 124 | 122 | 122 | 118 | 1.7 | 60 | 19 |
| curated afli LHM | 476 | 474 | 474 | 472 | 0.7 | 382 | 36 |
| curated fs_afladagbok LHM | 11,183 | 10,813 | 11,036 | 10,627 | 2.3 | 5,219 | 3,403 |

So the paper stations record fishing trips that took place and were landed as logged. They lie as close to the
vessel's track as the curated stations do: closer than fs_afladagbok's, farther than afli's. Agreement shows
consistency, not accuracy. It is a fair test, though: these stations never entered curated, so they shaped neither
the landing links nor the trail's fishing flags on these days.

The 22 stations more than 20 km from the track (19 jig, 3 gillnet) are all on days the vessel was at sea. Their
positions are wrong in the ways logbook positions often are, so they say nothing against the stations (maintainer,
2026-10-17). 6 come within 1 km of the track with one digit changed: the latitude degree one too high in 4, a minutes
tens digit in 2. 11 repeat nearly the same position on several days (vessels 1695, 2084 and 7720), a standing
position rather than the haul's. 2 give latitude 46° where 66° fits the track. The other 3 hold other errors
(minutes of 64, a longitude of 44°, a latitude of 67° north of the track). They are kept as recorded.

## What could change (the maintainer's choice, TODO 78)

1. **Nothing.** The 248 stations (492 t) stay outside the logbook part, and their trips stay known from the
   landings.
2. **Take `eytt` from `fs_afli.rafr_stofn`**, one path in `sources/afli/convert.R`. The 61 deleted stations are
   flagged, and 165,398 get FALSE instead of NA. No station is added or removed.
3. **Read fs_afli in place of afli** (`stofn`, `toga`, `lineha`, `afli`, ...). This adds group E's 189 stations (162
   of them new to curated) and group C's 1,898 as afli stations. The cost is the move above, and afli's own edits.
   Group D would still be missing: it is in `rafr_stofn` only.
4. **Keep afli, and add from fs_afli only what afli lacks**: option 2's flag, and group E's 189 stations with their
   `toga`, `lineha` and `afli` rows. Group C stays with fs_afladagbok. Under the tiers, 6 group E stations share a
   vessel-day with an fs_afladagbok station and would push 6 stations (6 trips) out, unless group E enters below
   fs_afladagbok.

Claude's recommendation: option 2 now, and option 4 for group E, which the check above supports. Not option 3:
it gives up afli's own edits, and the move buys nothing that option 4 does not.
