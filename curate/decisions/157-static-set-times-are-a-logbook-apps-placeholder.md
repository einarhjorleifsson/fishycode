# 157 — The static-gear set time 270 min before the haul is a logbook app's placeholder, and other times that are not the skipper's

*2026-10-20. Found, not decided: TODO 103 stays open for the correction and its design. Measured read-only on the
build of 2026-10-20 (b364249).*

- **Who asked.** The maintainer, in one session, on TODO 103 and plan 031's asks i-k: whether the 270-min offset is in
  the raw dumped data; whether it is a dummy that Trackwell's logbook fills so that what it sends to the Directorate of
  Fisheries is accepted, and whether the AIS time-speed pattern supports that; whether the 50,282 afli rows all carry
  a negative `visir`; an overview of `t1`, `t3` and `t4` by year and gear (longline, nets, jiggers) with which are
  likely real and which fictitious; and whether these times explain the trouble with the voyage definition (plan 031,
  decisions 144 and 155). Nothing was chosen.
- **Who did the work.** Claude (Anthropic): the measurements and this record. **Every number below was measured by
  Claude (AI); a person has not yet checked them.** Scripts, a README and the per-station table in
  `$FISHYDATA/archive/2026-10-todo103/`.

## Found

### The offset is in the raw dumps, from Trackwell's logbook

- **afli** (`raw/oracle/afli/lineha.parquet`): of 204,829 rows with both `logn_hefst` and `drattur_hefst`, 50,282 have
  `drattur_hefst` = `logn_hefst` + 270 min cut to the minute, every row 270 minute-boundaries apart fitting that rule,
  2008-2023. All 50,282 have a negative `visir`, as do the other 154,547 rows with both times; the 1,056,760 rows with a
  positive `visir` never have both. Every `visir` of `fs_afli.rafr_stofn` (the electronic logbook, 1,318,780 rows) is
  negative: a negative `visir` is the electronic logbook, a positive one the paper book. afli has no column naming the
  logbook's maker. afli stores haul times to the minute (no seconds on any of 202,779 static stations' `t3` or `t4`),
  so the seconds cannot tell which of the pair was computed from the other.
- **fs_afladagbok** (`ws_veidi`): 17,238 rows with `milli_timi` 270 min after `upphaf_timi`, all in trips whose
  `ws_veidiferd.uppruni` is Trackwell (`Trackwell raun` 16,758, `- GAFL AUTO` 479, `- Skrifstofa VES` 1), 2022-2025;
  none from Marína, Fontos, Jóhann Gíslason or Fiskistofa. 38 % of Trackwell's rows with two different times. 1,710 min
  (28.5 h, the same with a day added): 1,195, Trackwell only. The set is the computed one: on the 270-min stations it
  is the haul start less 270 min cut to the minute in 17,160 of 17,179, and carries seconds in 0.1 % (34 % of other set
  times), while the haul start carries them in 65 %. The record is saved a median 9 min after the haul end.
- **adb** (`fishing_station`): 21,769 with `tow_start` 270 min after `fishing_start`, all Trackwell (21,012, 755 and
  2), none from Marína (18,468 stations), Fontos (7,716), Reiknistofa fiskmarkaða (5,375), Jóhann Gíslason (2,431) or
  Fishtech (426). In the staged adb the set is the haul start less 270 min cut to the minute on 4,538 of 4,539.
- **Not the dump.** A time-zone or driver shift moves a whole column in every row; this is a fixed gap between two
  columns of one row, in one maker's rows, while the other makers' rows in the same tables have none, and 4.5 h is no
  offset of Iceland's. The dumper reads Oracle's DATE in UTC and checks a 1900 date's round trip
  (`R/dump_oracle.R`). Not compared with Oracle itself; this query would (not run):

  ```sql
  SELECT f.uppruni, COUNT(*) n,
         SUM(CASE WHEN FLOOR((CAST(v.milli_timi AS DATE) - CAST(v.upphaf_timi AS DATE)) * 1440) = 270 THEN 1 ELSE 0 END) n270
  FROM fs_afladagbok.ws_veidi v JOIN fs_afladagbok.ws_veidiferd f ON f.id = v.veidiferd_id
  WHERE v.milli_timi IS NOT NULL AND v.upphaf_timi IS NOT NULL
  GROUP BY f.uppruni ORDER BY n DESC;
  ```

- **A field that must be filled.** In adb no maker sends a station with a haul start and no set time: 0 of 132,003
  from the six makers with over 100 such stations. Reiknistofa fiskmarkaða and Fishtech fill the set with the haul
  start in every row (411 of 411, 188 of 188; gear not checked), and Trackwell uses the 270-min offset on 21,769 of
  its 130,295. This is consistent with a field the Directorate's format requires, filled by each maker its own way, as
  the maintainer suspected. Its purpose is not confirmed: only Trackwell or Fiskistofa can say.
- In `curated/logbook/fishing_sample.parquet` (static gear, both times): 71,306 stations at 270 min (afli 49,588,
  fs_afladagbok 17,179, adb 4,539), 5,902 at 1,710, 5,188 at 210, 4,641 at 1,440.

### The AIS track says which times are the skipper's

Each recorded time against the vessel's recorded pings (`curated/ais/trail`): `t1` and `t3` the first ping at or
after the time, `t4` the last at or before, within 15 min; and whether the time lies in a port call
(`curated/ais/port_call.parquet`). LLS, GNS (with 406 GND) and LHM, duplicates out, 1,475,515 stations.

- **A first test was biased.** Taking the ping *before* each time made the 270-min haul starts look like steaming
  (gillnets a median 6.9-7.7 kn): the ping before a haul start catches the vessel on its way to the gear. With the
  first ping after it, below, the haul start is degraded, not fake.
- Per pattern (% of the times: in a port call, stopped < 0.5 kn, slow 0.5-3.5 kn, steaming > 5 kn):

  | gear | pattern | time | n | port | stopped | slow | steaming |
  |---|---|---|---|---|---|---|---|
  | GNS | none | set | 73,260 | 23.1 | 14.6 | 28.2 | 49.2 |
  | GNS | 270 min | set | 11,689 | 70.9 | 67.4 | 15.8 | 14.7 |
  | GNS | 1,710 min | set | 5,837 | 77.7 | 75.2 | 9.4 | 14.2 |
  | GNS | 1,440 min | set | 4,600 | 11.5 | 11.0 | 41.8 | 42.8 |
  | LLS | none | set | 109,884 | 5.1 | 4.4 | 10.8 | 76.2 |
  | LLS | 270 min | set | 59,064 | 20.3 | 16.9 | 22.6 | 54.4 |
  | GNS | none | haul start | 69,720 | 2.8 | 14.5 | 56.2 | 25.3 |
  | GNS | 270 min | haul start | 11,689 | 2.5 | 11.2 | 42.2 | 41.5 |
  | GNS | 1,440 min | haul start | 4,600 | 0.9 | 15.6 | 70.5 | 10.3 |
  | LLS | none | haul start | 107,747 | 1.2 | 12.9 | 65.9 | 16.3 |
  | LLS | 270 min | haul start | 59,064 | 1.0 | 11.8 | 50.1 | 30.6 |
  | GNS | none | haul end | 70,135 | 4.8 | 14.8 | 43.2 | 36.0 |
  | GNS | 270 min | haul end | 11,689 | 3.3 | 15.9 | 34.4 | 43.0 |
  | LLS | none | haul end | 108,618 | 1.9 | 9.7 | 50.5 | 35.4 |
  | LLS | 270 min | haul end | 59,056 | 1.3 | 9.7 | 49.9 | 35.3 |

- So: **the set time is the placeholder**, at 270 and at 1,710 min; **the haul start** on these stations is at hauling
  speed less often than on others (42-50 % against 56-66 %) but seldom in port: degraded, not fake; **the haul end**
  is like any other; **1,440-min soaks look real** (in port less often than other gillnet sets).
- **Other placeholders.** Set times copied from the trip's departure to the minute: jiggers 32,030 of 120,638 (27 %;
  40 % of them in a port call), gillnets 1,842 (49 % in port), longline 1,637 (18.5 %). A set equal to the haul start
  (gillnet 459, longline 967; at hauling speed, so the haul start copied), or to the haul end (jiggers 2,127, 81 %
  steaming). A set time at exactly 00:00 (jiggers 1,096, 78 % in port; gillnets 128, 88 %; longline 539, 15 %). A haul
  start within a minute of the haul end (longline 607, gillnet 413). 44 afli longline set times dated before 1990.
  End times equal to the trip's arrival (jiggers 13,182, 14.5 % in port) are not clearly placeholders.

### By year and gear

`rec`: share of stations with the time. Of the recorded values: `plh` a placeholder (the set 270 or 1,710 min before
the haul start, or a copy of the haul start, the haul end or the trip's departure, or 00:00; a haul start equal to the
haul end or 00:00), `port` in a port call, `ok` a ping within 15 min and not in port (not contradicted, not proven);
the rest unchecked. All values in %. Schemas pooled (afli and fs_afladagbok overlap from 2022); afli has a set and a haul time together only on its electronic logbook's stations.

| Longline | n | set rec | plh | port | ok | haul start rec | plh | port | ok | haul end rec | plh | port | ok |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2008 | 22,175 | 4 | 1 | 8 | 83 | 4 | 0 | 3 | 89 | 4 | 0 | 5 | 87 |
| 2009 | 21,235 | 9 | 1 | 4 | 91 | 9 | 0 | 1 | 96 | 9 | 0 | 3 | 94 |
| 2010 | 19,390 | 22 | 2 | 4 | 90 | 22 | 0 | 1 | 95 | 22 | 0 | 2 | 94 |
| 2011 | 18,599 | 51 | 2 | 5 | 88 | 51 | 0 | 1 | 93 | 51 | 0 | 2 | 93 |
| 2012 | 17,793 | 63 | 2 | 4 | 89 | 63 | 0 | 1 | 94 | 63 | 0 | 1 | 94 |
| 2013 | 18,113 | 69 | 2 | 4 | 91 | 69 | 0 | 1 | 96 | 69 | 0 | 2 | 95 |
| 2014 | 16,693 | 69 | 6 | 4 | 87 | 69 | 0 | 1 | 97 | 69 | 0 | 2 | 96 |
| 2015 | 15,454 | 75 | 34 | 4 | 61 | 75 | 0 | 1 | 97 | 75 | 0 | 1 | 96 |
| 2016 | 15,373 | 78 | 40 | 3 | 57 | 77 | 0 | 1 | 99 | 78 | 0 | 1 | 98 |
| 2017 | 13,695 | 84 | 45 | 3 | 52 | 84 | 0 | 1 | 99 | 84 | 0 | 1 | 98 |
| 2018 | 14,037 | 88 | 50 | 3 | 46 | 84 | 0 | 1 | 98 | 88 | 0 | 2 | 97 |
| 2019 | 13,386 | 91 | 54 | 3 | 43 | 91 | 0 | 1 | 98 | 91 | 0 | 2 | 97 |
| 2020 | 11,413 | 97 | 54 | 3 | 43 | 97 | 0 | 1 | 98 | 97 | 0 | 2 | 97 |
| 2021 | 10,921 | 99 | 55 | 3 | 42 | 92 | 0 | 1 | 98 | 92 | 0 | 1 | 98 |
| 2022 | 9,039 | 100 | 61 | 2 | 37 | 93 | 1 | 1 | 97 | 96 | 0 | 3 | 97 |
| 2023 | 7,819 | 100 | 57 | 2 | 40 | 99 | 1 | 2 | 96 | 99 | 0 | 2 | 97 |
| 2024 | 7,143 | 100 | 59 | 2 | 39 | 100 | 2 | 2 | 96 | 99 | 0 | 1 | 98 |
| 2025 | 7,354 | 100 | 60 | 2 | 38 | 100 | 3 | 2 | 95 | 99 | 0 | 2 | 97 |
| 2026 | 5,420 | 100 | 62 | 1 | 36 | 100 | 2 | 1 | 96 | 100 | 0 | 1 | 98 |
| all | 265,052 | 64 | 36 | 3 | 59 | 63 | 0 | 1 | 97 | 64 | 0 | 2 | 96 |

| Gillnet | n | set rec | plh | port | ok | haul start rec | plh | port | ok | haul end rec | plh | port | ok |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2008 | 8,632 | 19 | 0 | 9 | 85 | 19 | 0 | 1 | 93 | 19 | 0 | 2 | 91 |
| 2009 | 10,741 | 42 | 0 | 12 | 68 | 42 | 1 | 1 | 77 | 42 | 0 | 2 | 78 |
| 2010 | 8,343 | 54 | 0 | 20 | 77 | 54 | 0 | 2 | 96 | 54 | 0 | 3 | 95 |
| 2011 | 7,309 | 70 | 0 | 38 | 58 | 70 | 0 | 2 | 95 | 70 | 0 | 4 | 93 |
| 2012 | 6,904 | 65 | 0 | 40 | 57 | 65 | 0 | 2 | 95 | 65 | 0 | 5 | 92 |
| 2013 | 6,151 | 64 | 0 | 36 | 61 | 64 | 0 | 2 | 94 | 64 | 0 | 3 | 93 |
| 2014 | 5,937 | 67 | 8 | 31 | 61 | 67 | 0 | 3 | 96 | 67 | 0 | 4 | 95 |
| 2015 | 6,339 | 74 | 37 | 14 | 48 | 74 | 0 | 2 | 97 | 74 | 0 | 3 | 96 |
| 2016 | 9,062 | 53 | 40 | 12 | 46 | 54 | 0 | 2 | 95 | 53 | 0 | 2 | 95 |
| 2017 | 8,290 | 44 | 40 | 10 | 48 | 44 | 0 | 4 | 94 | 44 | 0 | 4 | 94 |
| 2018 | 9,715 | 57 | 32 | 10 | 53 | 57 | 0 | 4 | 91 | 57 | 0 | 3 | 92 |
| 2019 | 10,208 | 57 | 23 | 12 | 61 | 57 | 0 | 4 | 93 | 57 | 0 | 4 | 92 |
| 2020 | 5,872 | 83 | 27 | 13 | 58 | 83 | 0 | 3 | 94 | 83 | 0 | 4 | 93 |
| 2021 | 8,130 | 95 | 24 | 13 | 58 | 62 | 0 | 2 | 93 | 61 | 0 | 3 | 91 |
| 2022 | 6,665 | 98 | 29 | 13 | 55 | 85 | 1 | 3 | 92 | 94 | 0 | 9 | 87 |
| 2023 | 6,462 | 100 | 23 | 15 | 61 | 99 | 2 | 3 | 92 | 100 | 0 | 6 | 90 |
| 2024 | 6,423 | 100 | 24 | 15 | 57 | 100 | 1 | 2 | 93 | 99 | 0 | 8 | 88 |
| 2025 | 6,165 | 100 | 27 | 13 | 57 | 100 | 1 | 3 | 92 | 99 | 0 | 5 | 91 |
| 2026 | 5,275 | 100 | 27 | 13 | 57 | 99 | 1 | 2 | 94 | 100 | 0 | 4 | 92 |
| all | 142,623 | 67 | 21 | 17 | 58 | 65 | 1 | 3 | 93 | 65 | 0 | 4 | 91 |

| Jigger | n | start rec | plh | port | ok | end rec | plh | port | ok |
|---|---|---|---|---|---|---|---|---|---|
| 2020 | 17,803 | 2 | 18 | 9 | 71 | 6 | 0 | 10 | 87 |
| 2021 | 21,883 | 87 | 14 | 16 | 68 | 5 | 0 | 9 | 89 |
| 2022 | 20,337 | 95 | 32 | 6 | 61 | 95 | 1 | 23 | 74 |
| 2023 | 17,935 | 100 | 29 | 3 | 67 | 100 | 0 | 19 | 80 |
| 2024 | 19,668 | 100 | 30 | 2 | 67 | 100 | 0 | 18 | 81 |
| 2025 | 19,989 | 100 | 30 | 4 | 65 | 100 | 0 | 18 | 81 |
| 2026 | 24,204 | 100 | 31 | 2 | 66 | 100 | 0 | 15 | 84 |

Jiggers before 2020: a set time on almost no station, haul times on 0-7 %, 5-22 % of those in port. The jiggers' haul
start is almost never recorded from 2022 (3 % of stations in 2022, none from 2024).

- **Longline:** the set time is a placeholder on 34-62 % of recorded sets from 2015, 1-6 % before; haul times 93-99 %
  ok from 2009.
- **Gillnet:** placeholders on 23-40 % of set times from 2015, and 9-40 % of recorded set times lie in a port call with
  no pattern, most in 2011-2013, before the 270-min offset appears. Their median soak is 22 h. Unexplained: every gillnet station's
  target is DEF, so lumpfish nets set near a harbour cannot be told apart. Haul times 87-97 % ok from 2010; haul ends
  in port rise to 5-9 % in 2022-2025.
- **Jiggers:** about 30 % of start times are placeholders, mostly the trip's departure; the end time lies in a port
  call on 15-23 % of stations from 2022, logged after arrival. These are mostly the 22,889 jigging stations plan 031
  §3.11 found within an hour of a call's end.

### What the placeholders do to the flow's evidence

`voyage_gear.R`'s placement (a station on every voyage one of its times of day lies in, else its trip's voyage)
replayed as built and with the placeholder times left out (static gear: 81,972 set times, 1,063 haul starts; jiggers:
33,581 and 30):

| | as built | without placeholders |
|---|---|---|
| stations whose first time of day lies in a port call (the audit's outcome, 73,635 as built) | 73,794 | 49,862 |
| stations on a voyage other than their trip's | 121,103 | 119,362 |
| stations on two or more voyages | 47,134 | 45,279 |
| voyages with logbook stations of several gears | 1,049 | 1,044 |
| of which tied | 520 | 516 |

- A third of decision 155's "timed station in a port call" is placeholder times; 49,862 are left.
- The multi-gear and tied voyages (decisions 144, 155) barely move: they are not caused by the placeholders. On 775
  pairs of voyage and gear class, a static or jigging gear is on the voyage only through a placeholder time.
- Port calls and voyages are cut from the track alone (`curate/port_call.R`, `curate/ais_voyage.R`): no logbook time
  enters them. The trip-to-voyage link uses the trips' own times, which come from the source, not from the stations:
  afli's trip start equals the trip's first set time on 273 of 142,446 trips. In fs_afladagbok it does on 21,665 of
  132,855, and adb 5,520 of 38,245, which is the set copied from the departure above, not the reverse.
- So the voyage definition's faults stay where plan 031 put them (calls missed over silences, the departure radius,
  logbook trips split by day, a trip matched to an earlier landing, real two-gear or overlapping trips). The
  placeholders inflated a measure of them.

### Measured beside it, for plan 031 ask i (not an answer)

Of §3.11's 1,708 R2 cuts backed by a landing dated inside the call, 1,405 have the cut trip's own landing (`lid_map`)
strictly inside it, and 798 have it on or after the station's day and two days or more after the call began (a
landing weighed the day after arrival belongs to the arriving voyage). 34 of the 798 lie 1-3 h from a call's end,
against 192 of the 1,708.

### Who reads the set time, and what happens without it

Measured the same evening in a second session, read-only, on the parent session's go (scripts `window_today.R`,
`afli_soak.R`, `window_t1_na.R` in the archive):
- `station_window.R` (`ramb::rb_create_record_windows()`): on static gear `t1` makes only the set window
  (`set_max_min`, 60 min gillnet, 150 min longline, synthesised; set fixes are never fishing); the haul window comes
  from `t3` and `t4`, and reads `t1` only when `t3` is missing. On jigging gear the jig window starts at `t1`; without
  it at `t4` less the duration, else the whole day. Rerun on the vessels concerned with the placeholder `t1` set to NA
  (as built it gives the build's 1,813,933 windows, 1,813,193 identical): 81,532 set windows go, 174 haul windows and
  313 other stations' set windows change, 1,059 static stations keep only a day window; about 21,900 jig windows start
  from the duration instead, and 6,494 jigging stations fall to a day window.
- `link_station_event.R` links `t1` to a fix as the start of setting; `voyage_gear.R` and `allocation_audit.R` place a
  station by its times (above).
- The soak and effort columns are made before `curate/`: fs_afladagbok's static `duration_m` is `t4 - t1`, and with it
  `effort_duration` and `effort`; afli's own soak field `lineha.klst` is 4.5 h on 18.7 % of the 270-min stations (0.7 %
  of the rest). The flow reads neither; an analyst does.
- Not from `t1`: the trail's effort and `ais_catch` (the pings), ramb's `soak_h` (the track).

## Open

TODO 103: the correction (which patterns; remove or flag, static gear and jiggers apart; the soak and effort columns
made before `curate/`), the gillnet set times in port with no pattern, and whether to ask Trackwell or Fiskistofa. Plan 031's asks i-k
stay the maintainer's.

Followed by decision 158 (the same night): the correction was chosen and coded
(`curate/corrections/logbook_set_placeholder.yml`), the track's set finder failed plan 035's test, and the XML each
logbook sent shows that Trackwell's app writes the 270-min set time (Fishing Log 2.7, from 2014).
