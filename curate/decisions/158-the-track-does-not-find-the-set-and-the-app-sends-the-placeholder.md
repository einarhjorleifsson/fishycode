# 158 — The track's set finder does not recover the real set times, and Trackwell's app sends the 270-min placeholder

*2026-10-20. Plan 035's test, fixed before the run, failed for every gear: the set start of a static-gear station is
the logbook's or none. Measured read-only on the build of 2026-10-20 (data of 5cec0f4); the two corrections were built
on 2026-10-21 (below).*

- **Who asked.** The maintainer, on TODO 103: blank the placeholder set times (done in code, 4945290), then give a
  station the track's set where the logbook has none, if its error is acceptable, and rebuild unattended if so.
  The test and its threshold were written into plan 035 and committed before any number was seen.
- **Who did the work.** Claude (Anthropic): the measurements and this record. **Every number below was measured by
  Claude (AI); a person has not yet checked them.** Scripts and results in `$FISHYDATA/archive/2026-10-plan035/`.

## Found

### The set finder against real set times (plan 035 §3)

On 152,880 static hauls whose recorded set time passes every check of decision 157 (no placeholder of any kind,
outside a port call, a recorded ping within 15 min after it), `ramb::rb_link_record_sets()` given every static haul
with both haul times, pings only:

- **Longline:** the found set start is within 60 min of the real one on 53.7 % (2015-2025, no cap), below the
  vessel's own typical soak (57.9 %); misses are mostly late, 1-3 h on 19.9 %.
- **Gillnet:** 31.7 % (skip the run in, no cap), 8.6 points above the typical soak; 23.0 % are a day or more early,
  an earlier pass over the same spot.
- **Pots:** 3.6 %, against 88.7 % for the typical soak (415 hauls).
- The test asked 75 % and 5 points above the baseline. No variant, year or gear comes near; the finder does worse on
  the placeholder stations, where it would be used, than on the truth hauls.
- Decision 146's Icelandic score (2,030-3,752 of 7,721 longlines right) counted agreement with declared set times, 57
  % of them placeholders in 2023. Against real set times the defaults are right on 28.6 % of longlines and no cap on
  53.7 %: its finding that the cap hurts soaking gear stands, its levels do not.

### The 270-min set time is in the record the app sent

afli's electronic-logbook stations (negative `visir`) are linked to the XML each logbook sent
(`fs_afli.afladagb_xml_mottaka`) through `fs_afli.rafr_stofn` (`xml_sending_visir`, `xml_faerslu_visir`,
`xml_faerslu_version`). Of the 50,282 rows of `afli.lineha` with the 270-min set time, 50,282 have their sent record
and 50,281 carry it there (`LOGN_HEFST` 270 min before `DRATTUR_HEFST`): **the app writes it, not Fiskistofa's
loading.** The message names the software (`hugbunadur`): the pattern comes with Trackwell's Fishing Log 2.7 (from
2014). Of the twelve versions with most such rows, the nine 2.7.x carry it on 30-90 % of their rows with both times,
2.6.7, 2.6.32 and SeaData 2.0.1 on 0.6-1.4 %. That
places decision 157's rise of 2015, and answers its note that afli names no maker: the messages do, back to 2004.

## What follows

- `curate/corrections/logbook_set_placeholder.yml` stands as coded: a placeholder `t1` is NA, and nothing fills it.
  `station_window` draws no set window there; the soak stays unknown. Plan 035 is abandoned; its §4 is not built.
- No rebuild was run that night: the maintainer tied it to a passing test. The maintainer asked for it the next morning (below).
- The draft to Trackwell now says the app sends the value. It is kept out of git at the maintainer's word
  (2026-10-21), in `$FISHYDATA/archive/2026-10-plan035/trackwell.yml`.

## The rebuild of 2026-10-21

On the maintainer's go, at de25239 with ramb 2026.10.19.2: `afli_xml_raw`, `afli_end_longitude`, `logbook` and the 18
targets after it through `ais_catch` and the checks, 06:00-06:41 (`tar_make_isolated()`, names given, `mbl_photo` left
out). Fingerprints and summaries before and after, and the checks, in `$FISHYDATA/archive/2026-10-plan035/` (`before/`,
`after/`, `scripts/rebuild_*.R`, `rebuild.log`). Every rebuilt file is stamped de25239, `fd.dirty` false. Before the
push the unpushed commits were rewritten to take the draft out of git: de25239 is 452f83e in the published history,
979dd7f is 4655171, and the two differ only by that file (`git diff --name-status`), so the stamp names the same code.

- **The corrections, as declared:** 77,953 placeholder set times NA (adb 4,918, afli 54,623, fs_afladagbok 18,412), none
  left; afli's end longitude 136,798 recovered, 7,570 NA, no afli station with `lon2 = -lat2`.
- **Unchanged content:** trip, catch, gear, `lid_map`, `trip_voyage`, both `catch_by_species` tables and four checks.
  Changed: fishing_sample and station (the two corrections only), `station_window`, `station_event`, `voyage_gear`, 209 of
  the trail's 233 month files, the catch on the fixes and four checks.
- **Windows:** 76,654 static set windows fewer; jig, tow and day windows move by 1-4.
- **The trail:** 2,328,557 fixes leave the set phase (6,070,499 to 3,741,942) and now lie in no window. The fishing flag
  of the windows (`fishing`) is all but unchanged (jig -5,195, day +565). The flow's own flag (`fishing_flow`) rises by
  643,298 fixes (0.46 %), 2014-2026: fixes no window holds are judged by their voyage's gear and speed range, and 27.8 %
  of the fixes the false set windows held now pass it. Whether that is fishing (hauling a line the logbook does not
  record) or slow steaming between sets is not measured.
- **Catch on the fixes:** 27.9 Mt before and after; 12.2 t moved off the fixes (2019 and 2020) into the audit's "other
  difference" (each approach); the rows per year shift with the fishing fixes.
- **The audit:** stations whose first time of day lies in a port call 73,635 to 49,163 (decision 157 replayed 49,862
  with every placeholder pattern out); stations in their trip's voyage +24,324; trips whose last station is in no
  voyage 72,092 to 51,079. 333 voyages change gear, 688 their gear's basis.

## Open

- The 643,298 fixes the voyage rule now calls fishing where a false set window stood: hauling or steaming.
- A better set finder, if static effort as quantity × soak is built (TODO 72 item 8): the longline misses are late
  passes, the gillnet ones earlier visits to the same spot. The vessel's typical soak does as well on longlines and
  far better on pots, though it says nothing about where the set was.
- Pot set times lie in a port call on 657 of 1,073 candidates, an unchecked pattern of its own.
