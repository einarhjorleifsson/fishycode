# 243 — afli first per vessel-day kept, tested against witnesses neither copy produced

*2026-10-29. From the reading of the new mar's author's reply to plan 050 ask g, in a side session at the maintainer's
request (`$FISHYDATA/archive/2026-10-29-rafn-mail/rafn-mail.md`, its scripts and counts). Measured and written by
Claude (AI), read-only; no person has checked the numbers. Nothing in the code changes.*

## Why it needed a witness of its own

The new mar's rebuild of 2026-10-29 now reads afli after 2021 and takes afli first, as fishycode's merge does
(`curate/logbook.R`, tier 1 per vessel and date). Its author took that choice from the findings emailed the same
morning (plan 050 ask g): one source per year, and 2021's tows without times, which afli holds. So his agreeing is
fishycode's choice copied, not a second finding. His builds are read by date: the one of that morning
(`$FISHYDATA/archive/2026-10-29-mar-logbook/live/`) is the independent reading, and where the rebuild agrees with
fishycode on a choice, it is not a witness. The maintainer, the same day: no push of fishycode and no email to him for a
while, to avoid a feedback loop between the two merges.

## What the records hold

On the 94,083 hauls of 2021-2023 that afli and the e-logbook both hold (the second round's pairs), afli has the tow
times and duration, mesh, gear dimensions, unit counts and the twin count. The e-logbook copy has a date and a gear
code. In 2021-2022 the two are copies of the same Trackwell submissions: the e-logbook's are the Directorate's
`ws_*` tables, "API" in his mail. The catch does not tell the copies apart.

## The witnesses

- **The AIS track, for the times.** The method is decision 242's: the vessel's position at a time, against the copy's
  own position. The yardstick is the e-logbook's own recorded times of 2023 for the same vessels, entered through the
  apps' own feeds.

  | event | afli's time on the pairs, near | the e-logbook's own 2023 time, near |
  |---|---:|---:|
  | tow start (within 5 km of the logged start) | 96.3 % (71,070 of 73,810) | 96.8 % |
  | tow at the gear's speed | 82.7 % | 86.5 % |
  | static haul | 85.3 % | 87.2 % |
  | static set | 43.3 % | 45.4 % |

  The e-logbook copy's midnight lands near on 11-14 %. So afli's extra times are as right as an e-logbook's own. The
  set time is weak in both; that is TODO 103's matter, not a reason to prefer either.
- **The count of trawls.** The e-logbook copy holds no count on these tows: its 1 is the staged fill (`synthesised`)
  on 73,858 of 73,980. All 9,877 tows where afli says two are afli's flag against that fill. afli's flag fits the same
  vessels' recorded practice in 2023-2025. The 116 vessel-gears afli never calls twin include 42 with recorded tows
  later, all single. The landing cannot tell twin from single within a vessel (a median ratio of 0.95 over 11
  vessel-years). This is a check of consistency, not proof per tow, and nothing contradicts it.
- **The hauls the tiers drop.** The second round counted 289 e-logbook hauls (2.3 kt) on 75 vessel-days afli holds.
  - 216 of them (2,153 t) are the e-logbook's own copies: 208 are exact copies under another `Trackwell raun` trip of
    the same vessel, sent again in 2022.
  - 36 hold no catch.
  - On 21 (100 t) the landing says afli's trip is whole without them.
  - What the tiers may really lose is 8 hauls, 43.7 t, and the track never puts the vessel at their logged positions.

  A haul-level tie to keep the 289 would add back 2.15 kt of copies, so none is made.

## His whole-trip rule, for the record

He takes a whole trip from afli or from the e-logbook. His build pairs afli's trip with the e-logbook trip of the same
vessel landing the same day: all 19,651 of his traced afli trips carry that trip's id, a join of his own, not a source
value. Where afli's landing date and the Directorate's differ, it keeps both copies. That happens on 547 real trips,
with 4,675 hauls of 2021-2023 held twice (54.3 kt); on those trips it holds 105.4 kt against 48.4 kt landed, and
fishycode 53.0 kt. Their fishing days overlap on 499 of the 547. It is fault 23 of the list kept for him
(`$FISHYDATA/archive/2026-10-29-mar-logbook/mar-package.md` §8), on hold with the reply drafted in `rafn-mail.md` §7.

## Decided

afli first per vessel-day stays, now on witnesses neither copy produced, and not on the agreement of the other merge.
Plan 050 §6 carries the corrected count of the dropped hauls, and its asks f and g are on hold.
