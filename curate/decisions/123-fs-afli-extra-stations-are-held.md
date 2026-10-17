# 123 — The stations only fs_afli holds are in `curated/logbook` already, all but 248

*2026-10-17. Written by Claude (AI-assisted), read-only on `$FISHYDATA`. Measured: `raw/oracle/afli/` and
`raw/oracle/fs_afli/` (the dumps of decision 122) against `curated/logbook/` and `curated/landing/` as built on
2026-10-16 (decision 112). Station ids are `visir` in both schemas, and `.sid` with schema `afli` in curated. Nothing
was changed, and no adapter. Closes TODO 76; the choice it leaves is TODO 78.*

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

## What could change (the maintainer's choice, TODO 78)

1. **Nothing.** The 248 stations (492 t) stay outside the logbook part, and their trips stay known from the
   landings.
2. **Take `eytt` from `fs_afli.rafr_stofn`**, one path in `sources/afli/convert.R`. The 61 deleted stations are
   flagged, and 165,398 get FALSE instead of NA. No station is added or removed.
3. **Read fs_afli in place of afli** (`stofn`, `toga`, `lineha`, `afli`, ...). This adds group E's 189 stations (162
   of them new to curated) and group C's 1,898 as afli stations. Under `curate/logbook.R`'s (vid, date) tiers, afli
   comes first, so group C would take 1,857 vessel-days of the same hauls from fs_afladagbok: the source of those
   hauls would change. Group D would still be missing: it is in `rafr_stofn` only. The shared stations would also
   take fs_afli's edits (decision 122).

Claude's recommendation: option 2, which corrects a flag and adds nothing. Option 3 only if the spring-2022 jig and
gillnet logbooks are wanted, and after measuring the source swap on group C.
