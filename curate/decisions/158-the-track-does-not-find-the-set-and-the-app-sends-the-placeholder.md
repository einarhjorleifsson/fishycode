# 158 — The track's set finder does not recover the real set times, and Trackwell's app sends the 270-min placeholder

*2026-10-20. Plan 035's test, fixed before the run, failed for every gear: the set start of a static-gear station is
the logbook's or none, and nothing was rebuilt. Measured read-only on the build of 2026-10-20 (data of 5cec0f4).*

- **Who asked.** The maintainer, on TODO 103: blank the placeholder set times (done in code, 4945290), then give a
  station the track's set where the logbook has none, if its error is acceptable, and rebuild without him if so.
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
- No rebuild was run: the maintainer tied it to a passing test. The correction (and TODO 106's, coded the same night)
  enter the data with the next rebuild from `logbook`.
- The draft to Trackwell (`curate/issues/trackwell.yml`) now says the app sends the value.

## Open

- A better set finder, if static effort as quantity × soak is built (TODO 72 item 8): the longline misses are late
  passes, the gillnet ones earlier visits to the same spot. The vessel's typical soak does as well on longlines and
  far better on pots, though it says nothing about where the set was.
- Pot set times lie in a port call on 657 of 1,073 candidates, an unchecked pattern of its own.
