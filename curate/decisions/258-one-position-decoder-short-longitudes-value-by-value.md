# 258 — One position decoder for the e-logbook; short longitudes read value by value (plan 053 step 7; amends decision 211)

*2026-10-30. Plan 054 step 2a, plan 053 step 7 (TODOs 126, 165). Coded and traced by Claude (AI) in a side session, not
checked by a person. The choices are the maintainer's, put by the main session over three rounds the same day. The
second round corrected the first, which rested on a count that proved wrong. On main as 1f7f603. The evidence and
traces are in `$FISHYDATA/archive/2026-10-30-plan054-step2a/` (`step7_findings.md` with its corrections,
`draft-step7-the-decoders.md`, `trace_step7*.txt`). Nothing is built on the live store; the change rides rebuild A.*

## Why

The two copies of one e-logbook were decoded apart.
- adb used `decode_logbook_position()` (decision 211). It read a longitude shorter than its latitude as having lost
  its leading zeros.
- fs_afladagbok used a scaling of its own: right-padded as seconds, except for the midwater trawl. It named STOKKUR,
  and read seven- and eight-digit values as none.

Plan 053's review chose one decoder, with each app's forms read from the profile's rows.

## Chosen

- **One decoder in both adapters.** It reads the profile's rows by app, feed and date (`logbook_position_rules()`).
  The form each position was read in is staged as `pos1_form` and `pos2_form`, and the app names leave the code.
  - P3: Taktikal's hundredths and exchanged pairs, adb's copies included.
  - P3-value: a trip with 61-99 is in hundredths.
  - P4: the 2022-23 short latitudes of Trackwell raun and Jóhann Gíslason.
  - P2: whole degrees.
- **A longitude shorter than a six-digit latitude**, value by value. The maintainer asked what happens to longitudes
  between −10° and 10°, and those are why the rule is value by value:
  1. the only valid reading is taken: right (five digits ddmm.m, four ddmm, under 46°) or left (leading zeros lost);
  2. where both are valid, the record decides, never the AIS: the station's other position, then the trip's
     unambiguous stations, then the vessel's within ±3 days;
  3. where the record is silent, the gear decides: midwater trawl left, every other gear right, the form uncertain;
  4. for a gear other than midwater trawl whose only valid reading is left: right, minutes carried, the form uncertain;
  5. where none is valid, none.
- **Beside a four- or five-digit latitude,** a short longitude has lost its leading zeros, as decision 211 read it.

## What this amends

Decision 211's reading of a short longitude beside a six-digit latitude. The maintainer's first answer, "left by
default" for the uncertain, was given on a count of 5,117 misplaced fs stations. That count was wrong: fs's adapter
already read the midwater trawl left. The answer was replaced by the gear default before anything was committed.

## Checked on staging, against the live store

| feed | unchanged | start moved | position gained | position lost | end moved |
|---|---:|---:|---:|---:|---:|
| fs_afladagbok | 453,276 | 14,651 | 909 | 461 | 584 |
| adb | 681,555 | 8,698 | 0 | 240 | 518 |

In today's merge, 32 adb positions change. fs's changes reach the merge with rebuild A.

The moved starts against the AIS track, by area and gear. The new reading is nearer for:
- the right readings, whether the only valid one, decided by the vessel's days, or by the gear: 859 of 859, 799 of 799
  and 626 of 631;
- TRACKWELL's ddmm pairs: 2,133 of 2,133;
- the four-digit latitudes east of 10° W: 1,294 of 1,306;
- Taktikal's exchanged pairs: 238 of 238;
- the seven-digit longitudes: 53 of 53;
- P4's patterns: 5/4 201 of 203.

Not nearer:
- 54 midwater-trawl stations whose trips straddle 10° W, decided right by the record. The record comes before the
  gear, as decided.
- The carried minutes (447 adb, 396 fs): nearer than before, but about 45 km off.

37 decoder tests pass.

## Left

- A station-level `position_uncertain` flag. The form says it for now.
- 21 fs stations of pattern 5/4 outside P4, 19 against the track, for a person to judge.
- P8's 8 stations.
- `docs/data-dict.yaml`, with rebuild A.
