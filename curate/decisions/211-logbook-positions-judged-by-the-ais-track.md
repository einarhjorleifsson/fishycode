# 211 — The logbook positions' ambiguous kinds judged by the AIS track: STOKKUR rounds to the degree, 60 is a carry, afli's three-digit ends are the loader's, its 61-99 start values are none; the forms by app in the overlays

*2026-10-23. TODO 126's AIS check, on the maintainer's go (decision 207). Done by Claude (AI), read-only, on the dumps
of 2026-10-16 and the trail rebuilt the same day (decision 205); not yet checked by a person. Scripts, logs and every
count: `$FISHYDATA/archive/2026-10-todo126-ais-check/README.md`. Nothing in the flow, the adapters or `curated/`
changed: logbook positions never join the track.*

## How

The witness is the vessel's own recorded fixes (the trail's stk, astd, astdB and emodnet rows; its `gps` rows are AIS
interpolated onto the logger and were left out), from 2007. Each reading of a position is measured to the track's path
in the narrowest window whose times the record holds for its position: the station's times ± 1 h (afli, Trackwell
raun, Fontos, Fishtech, Reiknistofa), the trip (Marína, Taktikal, Jóhann Gíslason, STOKKUR, whose station times are the
trip's, below), else the day. On the track: within 2 km for a whole-minute point (its rounding alone moves it up to
~1.0 km; afli's electronic minutes lie within 1 km on 85 %, 2 km on 94 %), 100 m for seconds (Trackwell raun's: 80 %,
median 16 m); one coordinate at a time, the track's range in the window ± 2 km (ordinary values pass on 90-97 %). Every
position of each kind is in one outcome.

## Decided

| Kind | Reading the track decides | Counts |
|---|---|---|
| STOKKUR's whole degrees (fs_afladagbok, 2020-22, 23,362) | **rounded to the nearest degree**: a 1 x 1 degree cell centred on the value, not a corner | rounded 14,491; truncated only 1,344; floored only 1,061; none 2,200; no AIS 4,266 |
| afli's exactly 60 (start) | **a carry** (the next degree), as the adapter reads it | latitudes 1,711: the carry alone 1,656, among others 21, another only 10, none 22, no AIS 2; four-digit longitudes 1,948: 1,696, 227, 12, 10, 3 |
| afli's 60-99 end values | **not minutes**: three digits, a haul end at minute 9-10 of its degree stored as degrees and minute run together and rounded (64 & 9.7 to 650; Oracle's loader most likely). Ending in 9: the degree and 9.0-9.5'; ending in 0: 9.5-10' of the degree below | all 2,319 three-digit end latitudes and 1,837 end longitudes (not copies). Where the haul's start is on the track: 978 of 998 and 984 of 1,006; longitudes 740 of 756 and 669 of 689. Correction `afli_end_three_digits` (declared); 2,176 zero end latitudes are none |
| afli's 61-99 start values (paper, 2015-22, 429 of four digits) | **none**: no reading explains most | hundredths of a degree alone 116, unpadded minutes 22, 60 too many 16, swapped 8, carry 7, several 146, none 97 (24 %, against 10 % of ordinary paper values), no AIS 17 |
| afli's rectangle-centre positions (8,802) | from 2007, **about a quarter of paper ones are fills**, the rest real; electronic ones real | before 2007 7,653, no AIS. Paper 651: on the track 345 (53 %, 71 % elsewhere), off with the vessel in the declared rectangle 158 (24 %, 15 % elsewhere), outside 65, unplaced 7, no AIS 76. Electronic 498: 91 % on the track (90.5 % elsewhere) |
| Marína's six digits (13,319) | **the track cannot tell; the digits decide seconds** (decision 165): 90.3 % end in 00, 15, 30 or 45. Precision about 0.5 km | seconds nearer on 50.8 % (95 % interval 49.1-52.5) of 3,411 judged; the test sees either reading (Trackwell raun 92.4 % seconds, Taktikal's 61-99 trips 16.7 %); its window is the whole handline day. Trips with 61-99: hundredths (22 of 29) |
| fs_afladagbok trips its adapter reads as hundredths for a 60 | **seconds** | 83.8 % (77.1-89.1) of 160 |
| The long longitudes (77 beyond 30 degrees beside a six-digit latitude) | mostly none | 13 latitude and longitude exchanged (12 Taktikal's), 5 the leading zeros dropped, 59 under no reading |
| The e-logbooks' other forms | `decode_logbook_position()` confirmed for TRACKWELL (whole minutes, 98-100 % a year), Trackwell raun's six digits (seconds, 92-96 %), Fontos, Fishtech, Reiknistofa (56-79 %); **wrong** for Trackwell raun's and Jóhann Gíslason's four- and five-digit latitudes of 2022-23 (degrees + decimal minutes, the leading zero dropped: 35-81 %) and for Taktikal's exchanged records and its four-digit longitudes beside six-digit latitudes (ddmm) | a sample of up to 600 start positions per app, digit count and year |

## So, each kind (decision 207's representation)

- **Cells:** afli's rectangle-only records (to 1984 87-89 % of stations; the quarter from 1985), STOKKUR's and Marína's
  whole degrees (1 degree, centred on the value).
- **Points:** afli's whole minutes (electronic ~1.8 km; paper nominal, part to 10'; a paper position at a rectangle's
  centre a point flagged as possibly the centre, since one row cannot be told); the three-digit ends, reconstructed,
  ± a quarter minute; the e-logbooks' seconds (~30 m: Trackwell raun, Fontos, Fishtech), Reiknistofa's and Marína's
  digits read as seconds with ~0.5 km; Taktikal's hundredths on its 61-99 trips; the unpadded minutes once the adapter
  reads them.
- **Nothing:** afli's 61-99 start values, its three-digit start latitudes (109: none 80), zero end positions; the long
  longitudes under no reading.

## Written

- `dump/oracle/meta/fs_afladagbok.yml` (new): the forms by app under `ws_veidi.upphaf_breidd`, the times' meaning under
  `upphaf_timi`, four assertions on the latitude and one on the longitude.
- `afli.yml`: the start assertions split (60 a carry: `<= 60`, expected false on 153 and 288), the end positions'
  three-digit form, zeros and four-digit minutes asserted (2,319, 2,176, 0, 1,837), decoded in `breidd_lok_dd` and
  `lengd_lok_dd`; the centre fills and the rectangle-only period in the table's details.
- `adb.yml`: the latitude's open `todo` answered (the 3,183 overflows), the rule's fit per app in adb's period
  (Trackwell raun 96 %, Fontos 87 %, Marína 81 %, Reiknistofa 72 %), Marína's start time the departure.
- Tested on clones of the three dumps: `validate-spec` 0 errors (only the dumps' S31 todos), every assertion fails on
  exactly the rows its description says. The real dictionaries are not rewritten: that is `rewrite_data_dict()` on
  `raw/oracle/{afli,adb,fs_afladagbok}`, the maintainer's go, as in decision 176.

## The per-app checks (proposed, not built)

`curate/checks/logbook_position_forms.R`, since one table's assertions cannot see the app: per source, app and year,
(1) the digit-count shares and the overlays' assertion counts against their declared values, news on a new app or a
moved share; (2) the artefacts counted (three-digit ends, zeros, 61-99, whole degrees, exchanged latitude and
longitude); (3) for paper before 2015, the decoded position against the declared rectangle, where it is still an
independent witness; (4) on demand, this AIS diagnostic. A check, never an input of the flow.

## Found in passing

- **Station times that are not the position's:** Marína's (13,543 of 13,543) and Taktikal's (6,632 of 7,005) start
  time is the trip's departure and the end the return (the vessel reaches the start position a median 5-5.5 h later);
  STOKKUR's one time is the landing (18,565 of 23,362 within 10 min); the old TRACKWELL route records midnight. The flow
  meets hauls with pings by time; decision 206 covers Trackwell's towed dummies, not these.
- Decision 210 replaces STOKKUR's copies with the tour app's decimal positions; the rounding holds for the STOKKUR rows
  until then, and the tour app's positions could confirm it without AIS.

## Left (TODO 126)

The representation built in the adapters and the merge (decision 207), with `R/logbook_position.R`: the three-digit
ends decoded (`afli_end_three_digits`), afli's 61-99 starts and zeros none, STOKKUR's cell, fs_afladagbok's adapter
reading Marína and the 60-trips as seconds, the unpadded minutes and Taktikal's exchanged and ddmm longitudes; the
per-app check; the real dictionaries rewritten.
