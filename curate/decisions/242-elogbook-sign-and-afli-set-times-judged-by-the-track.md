# 242 — Two e-logbook values judged by the track: the longitude's sign kept, and afli's 2021 set times kept over the Directorate's midnight

*2026-10-29. TODO 159, from the comparison of fishycode's merged logbook with the new mar's (plan 050 step 1,
`$FISHYDATA/archive/2026-10-29-mar-logbook/merge-vs-merge.md` §4.3 and §4.7). Measured by Claude (AI) in a read-only
side session, `$FISHYDATA/archive/2026-10-29-track-checks/` (`findings.md`, its scripts and counts); no person has
checked the numbers. Nothing in the code changes. **Amended the same day:** the merge still reads the afli route's
midnight as a set time on 231 stations (below).*

The track is a witness only: each logbook position is measured against the vessel's own fixes, and no logbook position
is joined to the AIS product (decision 211).

## The longitude's sign: step 3 of the e-logbook adapter kept

On 2,995 e-logbook stations the two merges give opposite signs: ours lies east on every one, as step 3 of
`sources/fs_afladagbok/convert.R` and `curate/corrections/adb_vs_fs_afladagbok.R` turn it, and the new mar keeps the
app's minus sign, which puts the station in the west. They are fs_afladagbok 2,279 (2022-2025), adb 274 (2026) and 442
of afli's e-logbook route of 2021-2022, where ours is afli's own reading.

Each reading was measured to the vessel's nearest fix within ± 1 h of the station's times (2,983 stations), else its
day (12). Near is 5 km, and one reading wins only when the other is at least twice as far and 5 km farther.

| outcome | fs_afladagbok | adb | afli route | all |
|---|---:|---:|---:|---:|
| ours nearer | 2,207 | 248 | 413 | 2,868 |
| theirs nearer | 2 | 0 | 19 | 21 |
| both far | 47 | 23 | 10 | 80 |
| cannot be judged (within 0.55° of the meridian) | 23 | 3 | 0 | 26 |
| no fix | 0 | 0 | 0 | 0 |

On the e-logbook's own records ours wins 2,455 to 2, and both of those 2 lie within 0.2° of the meridian. So the apps
write an east longitude negative, as the rule assumes. The check judges the rule only where the two merges differ: a
station whose west sign the rule restores reads the same on both sides. The 19 against us on the afli route are afli's
own sign (16 within 1° of the meridian, 3 at 22-23° E south of 67.66° N, on land), not our rule: TODO 162.

## afli's set time on its 2021-2023 e-logbook route: kept over the Directorate's

On 3,007 nets and lines of 2021-2023 (1,386 gillnet, 1,621 longline) afli's `t1` and the Directorate's differ. All are
afli's electronic logbook (`visir` < 0), not the paper record that §4.3 of the comparison named.

- **The Directorate's value is a date, not a time**: 00:00 of the station's date on all 3,007. So is every afli-route
  net and line of 2021-2023 in the live copy (6,265), and adb's raw copy holds the same midnight on the 2,991 it has,
  with no haul start or end.
- **afli's `t1` is a recorded time**: seconds on 93 %, never 00:00, never the haul start less 270 min (decision 157),
  and no single whole-hour shift brings its far times onto the set position.
- **The track, out of port, within 5 km of the set position:** afli's time on 1,698 (56.5 %), the midnight on 334
  (11.1 %). afli's own nets and lines of 2019-2020 (18,953), with a midnight made the same way, give 54.7 % and
  13.5 %: these 3,007 are ordinary afli set times. At midnight the gillnet boats are in port four times in five.

The merge's tier 1 (afli first per vessel and date) stands. A 00:00 start in the Directorate's 2021-2023 records of the
afli route is a date and is never read as a set time. ~~Nothing reads it as one now.~~ One reader does: see the
amendment below.

## Amended 2026-10-29: the midnight is still read on 231 stations

From the study of the e-logbook's static set times by app (Claude, read-only, not checked by a person;
`$FISHYDATA/archive/2026-10-29-static-set-time/findings.md` §6). The merge keeps 231 afli-route (`TRACKWELL`) stations
of 2022-05-25 to 06-15 from the e-logbook, whose `t1` is that midnight. `curate/station_window.R` draws a set window
from it and no day window, since `ramb::rb_create_record_windows()` gives a day window only to a station with no usable
time. For 194 of them that false set window is the only window, so their catch has no fishing window to sit on. The
same holds for 413 STOKKUR stations (`t1` the landing) and 24 FRA TAKTIKAL ones. The rule above stands; reading it is
TODO 164's choice (c): a station whose only time is a date or a landing gets a day window, not a set window.
*Decided 2026-10-30:* the maintainer's review of plan 053's rows T5, T8 and W1 chose (c), basis `synthesised`; TODO 164
is folded into TODO 165 (plan 053 §5.6), and the windows wait for its build.

## Leads

- **afli's east longitudes**, TODO 162: afli has no sign rule, and 436 of its stations lie east of 10.75° E south of
  67.66° N (35 before 2000, 66 in 2000-2009, 322 in 2010-2020, 13 from 2021). Not judged.
- **afli's electronic set times in general**, added to TODO 103: on its own nets and lines of 2019-2020 the set time
  misses the set position on 45 % (far or in port), leaning to a set logged 1-3 h before the vessel reaches the gear
  (2,692 later against 1,244 earlier, with hour shifts). This bears on decision 157's departure copies.
- **For the new mar's author**: it keeps the e-logbook sign as given, so of the 2,553 e-logbook stations it puts
  west, the track has 2,455 east. This was not in the email of plan 050 ask g; it is fault 21 of the full list,
  `$FISHYDATA/archive/2026-10-29-mar-logbook/mar-package.md` §8, not yet sent.

Closes TODO 159.
