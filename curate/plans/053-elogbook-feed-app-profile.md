# 053 — The e-logbook feed: every app's quirks found by rule, in one app profile, and the feed's seams

**status:** proposal — written 2026-10-29 at the maintainer's request; measured read-only the same day; step 3's rows
drafted the same day (`curate/corrections/logbook_app_profile.yml`, 45 rows, none reviewed, none applied); nothing built ·
**measured** (§1-§3), by Claude in a read-only side session, not checked by a person, in counts only, every number in a
file of `$FISHYDATA/archive/2026-10-29-elogbook-feed/` (`findings.md`; `counts/tables.md` renders the tables below from
the count files; `counts/q00_inventory.tsv` is §1): every station of fs_afladagbok, of adb where fs_afladagbok lacks it,
and of the afli route as sent, field by field, by app, against the AIS track and port calls, GEBCO, the landing and
Trackwell's own copy of its app's hauls · **assumed** (§4): the app string identifies the app; the witnesses'
tolerances; Trackwell's file is the app's own; the month-end mechanism · **see:** TODOs 73, 103, 107, 126, 156,
157, 162, 164, decisions 157, 158, 160, 165, 171, 206, 210, 211, 213, 240, 242, 243, plans 050 (§6, ask f), 051, 052,
`curate/corrections/logbook_set_placeholder.yml`, `R/logbook_position.R`, `sources/fs_afladagbok/convert.R`

Drafted with AI assistance (Claude) on 2026-10-29; a person has not yet checked it, nor any number in it.

The maintainer, 2026-10-29, asked for a plan "on how to deal with the fed bullshit": the e-logbook feed, what the apps and
the Directorate send, and the feed itself. The day's studies kept finding one kind of fault. Each app fills the fields
its own way, and the code catches them one special case at a time: an adapter branch for STOKKUR, the name of
Taktikal's app in the position decoder, a placeholder rule in the merge, and the rest in TODOs. This plan measures every
app's profile, field by field, and proposes one place where the quirks are caught by rule.

## 1. The quirks known, and how each is caught today

From the record (TODOs 103, 107, 126, 162, 164; decisions 157, 158, 160, 165, 171, 206, 210, 211, 240, 242, 243; plans
050 §6 and 051) and the day's archive folders, each counted again on the dumps and the merge as built on 2026-10-29
(`counts/q00_inventory.tsv`, its `from` column naming the count file). "Merged" counts the stations the merge holds,
duplicate twins out. Feeds: fs = fs_afladagbok, adb from 2025-11-19, the afli route as sent (`staging/afli_sent`).

| # | quirk | app(s) | field, period | caught today | count |
|---|---|---|---|---|---:|
| T1 | haul start less 270 or 1,710 min (the placeholder) | Trackwell raun; Fishing Log 2.7 | t1, 2008-2026 | `t1` NA, `t1_placeholder` (`logbook_set_placeholder.yml`) | 77,953 flagged |
| T2 | the same, a minute off (269, 271, 1,709, 1,711) | Trackwell raun | t1, 2022-2026 | nothing (decision 206 chose it) | 823 merged |
| T3 | the same plus 2-40 whole days | Trackwell raun | t1, 2022-2026 | nothing (TODO 164 a) | 1,626 merged |
| T4 | `t1` is the trip's departure | Marína, FRA TAKTIKAL | t1, 2021-2026 | nothing: a set window, or a jig window from the port | 24,271 merged |
| T5 | `t1` is the trip's landing | STOKKUR mostly | t1, 2020-2022 | nothing | 15,282 merged |
| T6 | `t1` is the haul start or end | Reiknistofa, Fishtech, Jóhann Gíslason | t1, 2022-2026 | nothing: a set window cut to nothing | 1,963 merged |
| T7 | `t1` is the vessel's previous haul end | Fontos | t1, 2023-2026 | nothing | 495 merged |
| T8 | `t1` or `t2` a date (00:00) | TRACKWELL; Marína, Taktikal on some | t1, t2, 2019-2026 | twins ignore it; a set window at midnight | 1,520 + 1,530 merged |
| T9 | the only times a date, landing or departure: no window but a false set window | STOKKUR, TRACKWELL, Taktikal | window, 2020-2023 | nothing (TODO 164 c) | 3,632 merged |
| T10 | `t4` is the trip's return | Marína, FRA TAKTIKAL | t4, 2022-2026 | nothing: the jig window is the whole trip | 20,741 within 1 h of port |
| T11 | the trip's departure copies the first haul or tow start | Trackwell raun | departure, 2022-2026 | `trip_reconciled` takes the AIS first; decision 206 would blank the tow start | 8,665 times near |
| T12 | a set time stamped with seconds: in port on a quarter | Trackwell raun | t1, 2022-2026 | nothing | 11,291 merged |
| T13 | a set derived from the haul start in half hours | Trackwell raun; Fishing Log 2.6 | t1, 2022-2026 | nothing (decision 206: `derived`, not built) | 2,893 merged |
| T14 | a tow or haul of 0-4 min | Trackwell raun | t2, t3, 2022-2026 | nothing (decision 206, not built) | 4,810 merged |
| T15 | the afli route's `t1` is the departure | Fishing Log 2.6 | t1, 2003-2022 | nothing (decision 157: as recorded) | 4,787 as sent |
| P1 | the sign convention differs by app | every app | lon, 2020-2026 | the sign rule (fs adapter step 3, `adb_vs_fs_afladagbok.R`) | 1 wrong, 337,996 right |
| P2 | whole degrees, a 1-degree cell | STOKKUR | lat, lon, 2020-2022 | fs adapter `source == "STOKKUR"`, read as a point | 23,362 |
| P3 | hundredths of a minute, and four digit forms | FRA TAKTIKAL | lat, lon, 2021-2023 | `R/logbook_position.R` names the app | 7,014 |
| P4 | 4-5 digit latitudes: degrees and decimal minutes, the leading zero dropped | Trackwell raun, Jóhann Gíslason | lat, 2022-2023 | nothing (TODO 126) | 6,988 judged |
| P5 | seconds only at 00, 15, 30, 45 (about 0.5 km) | Marína | lat, lon, 2023-2026 | nothing | 16,973 |
| P6 | the end position a copy of the start | Reiknistofa (all), Jóhann Gíslason | lat2, lon2 | nothing | 13,713 |
| P7 | the position saved later than its times (stamped gillnets, jigs) | Trackwell raun | lat, lon, 2022-2026 | nothing | 61,866 jig stations |
| P8 | east sent for west (ddmm, six vessels) | Fishing Log 2.6 | lon, 2010-10 to 2015-04 | afli's edited layer, all but 4 | 987 as sent |
| D1 | integer fathoms sent where the app holds metres | Trackwell raun, TRACKWELL | z, 2020-2026 | `fathoms_to_metres()` for every fs and adb station | 14,629 of 14,978 matched |
| D2 | metres, read as fathoms | Marína, Taktikal (most vessels), some of every app | z, 2022-2026 | nothing: x 1.8288 (decision 210's `fs_depth_units`, not built) | 22,568 |
| D3 | a depth of 0 for none | STOKKUR | z, 2020-2022 | nothing: 0 m | 23,362 |
| D4 | the end depth a copy of the start | Reiknistofa (all), others | z2 | nothing | 31,553 |
| D5 | the afli route's unit by version | SeaData's Fishing Log 1.x, 2.0 | z, 2000-2016 | `afli_depth_units.R`, edited layer | 55,506 |
| C1 | no count sent (midwater trawl, seines, the Directorate's afli route) | Trackwell raun, TRACKWELL | count, 2020-2026 | 1, basis `synthesised` (decision 240) | 186,432 |
| C2 | the jig count one value all year | the jig apps | count, 2022-2026 | nothing (likely the reels) | 79,778 |
| K1 | UNGU on nearly every row | Marína, Fontos, STOKKUR, Taktikal | state, 2020-2026 | x 1 (plan 051) | 109,816 rows |
| K2 | a stored whole weight, GUTT x 1.25 | TRACKWELL | `afli`, 2019-2023 | kept beside (plan 051) | 169,893 rows |
| K3 | lumpfish 950 and 951 written 48 | adb | species, 2025-11-19 on | nothing (plan 051 ask c) | 3,159 rows |
| I1 | a trip sent again: exact copies under another trip id | six apps | station, 2022-2026 | `logbook_twin` duplicate | 3,865 merged |
| I2 | the same on vessel-days afli holds | Trackwell raun | station, 2022 | the tiers | 208 |
| I3 | the landing system's own trips, no station | FRA GAFLI (- AUTO) | trip, 2021-2026 | trips without stations are not merged | 26,668 trips |
| I4 | a vendor's trial: trips never landed, most on one vessel | Fishtech, Reiknistofa, Fontos | trip, 2023-2025 | nothing, kept | 405 trips |
| I5 | a year lost (0005, 2030) | Taktikal, Fontos, Jóhann Gíslason, STOKKUR | dates | the date bounds (`fs_veidiferd_year.yml` not built) | 194 |
| I6 | the tour app's ids are e-logbook ids | the tour app | ids, 2020-2022 | not read (decision 210) | 33,369 trips |
| F1 | fs_afladagbok registers nothing after 2025-12-12 | all | 2025-11-19 on | adb (decision 160) | 2,038 adb vessel-days to 12-31 |
| F2 | adb writes bottom trawl for shrimp and Nephrops trawls | all | gear, 2019-2024 | adb not read then; read back since plan 050 | 5,200 |
| F3 | trips registered on a month's last day lost in the new mar's live build | all | trip, 2022-2026 | the dump and adb hold them | 4,531 trips |

**What the build catches:** 12 of these 42 by a rule that names no app (T1, P1, D1, D5, C1, I1-I3, I5, F1-F3); 2 by
an app's name in code (P2, P3); 6 in part or elsewhere (T8, T11, P8, K1, K2, I6). The other 22 are caught by nothing.

## 2. Each app's profile

Measured as §1, one class per station and field (`02_profile.py`), then against the witnesses (`03_witness.py`,
`06_deep.py`, `07_trackwell_copy.py`). "Near" is the vessel's interpolated position within 5 km of the logged one at
that time; "in port" lies in a port call; "within 1 h of leaving or reaching port" is against the port calls' ends. The
track is a witness only: no logbook position joins the AIS product (decision 211).

**Trackwell raun** (fs 318,184 stations, 2021-11 to 2025-12; adb 77,552): the only app that writes a set time, and most
of the fleet.
- Tows and seine sets: start and end recorded, near on 92-99 % in every class. The share stamped with seconds falls
  each year: 95 % of tow starts in 2022, 77, 57, 45, then 35 % in 2026. So a profile holds by period, not for an app
  once.
- Static `t1`: the placeholder 44 % (fs) and 48 % (adb), typed 29 % and 24 %, stamped 20 % and 17 %, half-hour grid 4 %
  and 11 %. Typed sets are near on 63-73 % and in port on 4-8 %; stamped ones near on 30-35 % and in port on 25-26 %;
  the placeholder near on 32-33 %, in port on 26-30 %.
- Static `t4` equals the trip's landing on 16-18 % and the entry time on 7 %, and those ends are near on 66-86 %: the
  haul ends when the record is closed. Jig `t4` equals the landing on 29-30 % and the entry time on 18-25 % (near on
  45-81 %).
- Static `t3` equals the departure on 11 %, and is near on 87-91 %: the departure copies the haul start (T11).
- Jigs: `t1` stamped on 90 %, far on 67-70 %. The logged position fits the vessel at the entry time (49 % and 68 %
  within 5 km) better than at `t1` (29 % and 34 %): the position is taken when the record is saved (P7).
- Positions: six digits, ddmmss, on 98 %; Trackwell's own copy puts 14,872 of 14,978 matched hauls within 100 m. The 2 %
  with five digits (and 723 with four) are far on the track on 74-80 % (P4). West positive, east negative.
- Depth: integer fathoms. Trackwell's own copy holds metres, 1.829 times the sent value (10-90 %: 1.821-1.837) on 14,629
  of 14,978 hauls. By GEBCO 643 vessels read fathoms, 47 metres and 177 mixed.
- Count: tows 1 on 75 %, 2 or more on 19-22 %, none sent on 4-6 %; by vessel-year of bottom trawl (fs), 167 always 1,
  22 always 2 or more, 57 varying. Midwater trawl, Danish seine and purse seine send none.
- Catch: GUTT 54-56 %, UNGU 42-45 %, RELE 1 % of rows; a stored whole weight on 1 % of rows.
- Ids: 3,240 exact copies under another trip id in the merge, every one flagged duplicate, and 208 more on vessel-days
  afli holds (decision 243).

**Marína raun** (fs 14,007, 2023-02 to 2025-12; adb 5,090): handline mostly; its times are the trip's.
- `t1` equals the departure on 96-100 % and lies within 1 h of the vessel leaving port on 91-94 %. `t4` lies within
  1 h of it reaching port on 84 %. The landing field is mid-port-call on 90-93 %: a weighing time (decision 211).
- Static `t3` is recorded (98 %), near on 48 %.
- Positions: six digits, seconds only 00, 15, 30 or 45 on 16,973 (P5); no end position. West positive.
- Depth: metres. By GEBCO 221 vessels read metres, 18 fathoms, 43 mixed (D2).
- Catch: UNGU on 99 % of rows. 310 exact copies.

**FRA TAKTIKAL** (fs 7,014, 2021-2023): its times are the trip's too.
- `t1` the departure on 85-90 % (within 1 h of leaving port on 77 %); `t4` within 1 h of reaching port on 73 %; the
  landing field a date on every trip of 2022.
- Positions in four forms: four digits 73 %, seven 11 %, six 9 %, five 3 %, six with 61-99 2 % (P3).
- Depth: metres (119 vessels against 35). Catch: UNGU 97 %. Years lost on 15 stations (I5).

**STOKKUR** (fs 23,362, 2020-04 to 2022-03): one time, a cell.
- Its one time is the landing (52-58 %) or a departure equal to it (23-34 %). On its 776 stations of 2022 that time
  lies within 1 h of the vessel reaching port on 56 %.
- Positions whole degrees (P2), signed true (west negative). Depth 0 on all. No count. UNGU on 95 % of rows.
- 3,907 merged static stations have a set window from that one time as their only window: 3,363 of T9's 3,632, and
  544 whose time carries seconds and lies far from the cell on 87 %.

**Fontos raun** (fs 5,449, 2022-05 to 2025-11; adb 2,611):
- Jig `t1` equals the departure on 49-54 %, but those times are near the logged position on 65-78 %, and 58 % of all
  its `t1` lie at sea: here the departure copies the start, the opposite of Marína.
- Jig `t4` equals the landing on 79-83 %, within 1 h of reaching port on 50 %. Static `t1` is the previous haul's end
  on 71 % (far on 70 %).
- Signed true (west negative) on 97-99 %. Depth mostly fathoms (90 vessels; 16 metres). UNGU 98-99 %.

**Reiknistofa fiskmarkaða raun** (fs 2,527, 2024-08 to 2025-11; adb 3,209): static `t1` the haul start or end on
50-66 %; the end position and end depth copies of the start on every station; a stored whole weight on every row; 76
exact copies; 95 trips of fs never landed, 48 of them one vessel's.

**Jóhann Gíslason raun** (fs 2,436, 2022-03 to 2023-12): static `t1` the haul start on 49 %; four- and five-digit
latitudes on 37 % (P4); 53 exact copies; 907 trips with no station.

**Fishtech raun** (fs 540, 2023-05 to 2025-03): static `t1` the haul start or the departure; jig `t1` the entry time
(57 %); 150 of its 540 stations are duplicate twins; 110 of its 347 trips never landed, 93 of them on one vessel.

**TRACKWELL** (fs 96,323, 2019-11 to 2024-06; 1,856 merged): the afli route as the Directorate holds it.
`xml_trackwell_vorpun` maps its 20,842 trips to afli's XML messages. Dates only (00:00, no ends), four-digit positions,
fathoms, no count, and GUTT x 1.25 stored on 169,893 rows. The merge reads afli instead (tier 1, decision 243).

**The afli route as sent** (1,317,165 stations, 2000-2024; versions from the message):
- Fishing Log 2.7: the placeholder on 48 % of static sets (decision 158), decimal degrees, metres (Trackwell's own
  copy x 1.000 on 231,214 hauls).
- Fishing Log 2.6: `t1` the departure on 6 % (in port on 96 % of those judged), the half-hour grid on 9 %. 987
  longitudes sent east where Trackwell's copy has them west (P8): 2010-10 to 2015-04, six vessels; afli's edited
  layer has 957 of the 961 merged ones right.
- SeaData's versions: no static times at all in 1.1 and 1.3; Fishing Log 2.0 sends 1.8288 times what Trackwell's own
  copy holds (55,506 hauls).

**Others:** Fiskistofa raun (15 stations), the landing system's own trips (`FRA GAFLI`, I3), and one new app,
`Skráningar.com - Jón Arnar Gestsson - Afladagbók`, 8 stations from 2026-09-30, which no rule yet names.

**What the witnesses add.**
- **The same equality means opposite things by app.** A start equal to the departure is the departure for Marína
  (within 1 h of leaving port on 91-94 %) and Taktikal (77 %). For Fontos's jigs (near 65-78 %) and Trackwell raun's
  tows and seine sets (near 92-97 %, at sea on 72-77 %, 3,064 stations) it is a real start, and the trip's departure
  is the copy. Decision 206 chose to blank the towed starts; the track says to flag the departure instead.
- **Trackwell's own copy** confirms the six-digit decoding, the fathoms sent, the afli route's metres, and the towed
  times of both feeds to the minute (405,997 afli-route and 14,292 e-logbook tows with start and end). It holds few
  static hauls (88 matched), so it cannot judge the set.
- **The sign rule holds for every app**, though the apps differ: Trackwell raun, Marína, Reiknistofa, Taktikal and
  TRACKWELL write west positive and east negative, while Fontos, STOKKUR, Jóhann Gíslason, Fishtech and the tour app
  write the true sign. The rule reads both. Against the track, the mirror is nearer on 1 station and the reading as
  made on 337,996.
- **The landing finds no app-level weight fault.** Per trip, logged over landed lies in 0.8-1.25 on 86-92 % for every
  app the merge reads from the e-logbook but STOKKUR (76 %) and Fishtech (52 %, the trial vessel); each trip's outcome
  is in `w05_weight_landing.tsv`.
- **Cross-checks.** On its own population, the classes reproduce the static set-time study's. The placeholder flag
  equals `logbook_set_placeholder.yml`'s counts per schema, and every flagged station falls in the placeholder class.
  adb equals fs on 467,567 of 467,635 shared stations (decisions 022, 171).

## 3. The feed: each period's source, and what is lost at each seam

| period | the merge reads | carries |
|---|---|---|
| to 2022 (thinning: 87,962 stations in 2021, 38,243 in 2022, 1,889 in 2023) | afli's edited layer (`stofn` to 2024-06-27) | paper, and the afli route (Trackwell's and SeaData's apps; XML to 2024-07-12) |
| 2020-04 to 2022-03 | fs_afladagbok's STOKKUR | the tour app's copies (whole degrees, the landing time); the tour app itself not read (decision 210) |
| 2019-11 to 2024-06 | fs_afladagbok's TRACKWELL where afli lacks the vessel-day | the afli route as the Directorate holds it: dates only |
| 2021-11 to 2025-11-18 | fs_afladagbok (`ws_veidi` registered to 2025-12-12, `ws_veidiferd` to 2025-11-28) | every e-logbook app |
| 2025-11-19 to 2026-10-15 | adb (dumped 2026-10-16; a batch every day but 2025-12-24 and 25) | every e-logbook app, in MFRI's codes |
| live | nothing: the Directorate's `ws_*` tables are reached by no account (plan 050 ask f) | |

**The seams:**
- **afli to the e-logbook (2021-2023).** Two copies of the same Trackwell submissions; afli first per vessel-day, on
  witnesses neither copy produced (decision 243).
- **fs_afladagbok to adb (2025-11-19).** fs_afladagbok holds 98.5 % of adb's vessel-days on 11-19, 92-96 % to 11-24,
  then 81, 69, 20 and 3 %, and none from 11-29: 2,038 adb vessel-days it lacks to 12-31. adb's copy is fs_afladagbok's
  on 467,567 of 467,635 shared stations (times, raw positions, depth). What adb loses: shrimp and Nephrops trawls
  written as bottom trawl to 2024 (5,200; read back since plan 050), Grásleppa (951) and Rauðmagi (950) both written 48
  (3,159 rows from 11-19; fs_afladagbok holds 951 on 8,895 rows and 950 on 1,992), and, from decision 171, zeros for
  NULLs, the dredge's weight and the trap's type.
- **fs_afladagbok's end is our copy's, not the source's** (inferred). Its trip and station rows stop, but the schema at
  MFRI was created on 2025-12-19, its tables altered on 2026-09-29 and five views added in April 2026, and
  `ws_rekjanleiki` holds 40,494 trip ids with no trip row, changed to 2026-09-09.
- **The live: the new mar's build** (its build of the morning of 2026-10-29, before fishycode's email). Of fs_afladagbok's
  trips of 2022-2025 registered on a month's last day, 3,829 of 3,875 are missing from it, against 317 of 139,957
  others; of adb's from 2025-11-19, 702 of 714 against 20 of 37,560; every app alike. It also files afli's and the
  tour app's records under e-logbook ids (`$FISHYDATA/archive/2026-10-29-mar-logbook/live-vs-dump.md`); 33,369 of the
  tour app's 35,792 trip ids are `ws_veidiferd` ids.

**The options** (no one is contacted while the hold of 2026-10-29 stands):
1. **The dump of record and adb, as now**, with the profile of §5 over both. It loses nothing known but adb's own
   conversions, which §5 flags.
2. **The fs_afladagbok copy at MFRI resumed** (IT): the schema is maintained, so the cheapest way back to the dump of
   record, and adb could go.
3. **The Directorate's live tables, dumped source-shaped** (plan 050 ask f): an account and the tables named.
4. **The new mar's parquet**: interpreted, losing the month-end trips, and partly fishycode's since the email. Not a
   source; a reading to compare with, by date.

Under any of them the apps' quirks are the same: the profile is written once, for every feed.

## 4. What is assumed

- That the trip's `uppruni` (fs) and `source` (adb) name the app, "from the Auth0 login" (Oracle's comment), with
  nothing for its version; the afli route's version is the message's `hugbunadur`.
- That an app's behaviour holds within a period. Measured by year for the times only: it moves (the stamped tow starts,
  the half-hour grid from 2025).
- The witnesses' tolerances: 5 km, 30 min to a fix, 1 h to a port call's end, GEBCO's 1.45-2.4 and 0.75-1.3 bands.
  Near is necessary for a right time, not sufficient (the static set-time study). A position saved later or a drifting
  gear can be far at a right time.
- That Trackwell's file of November 2022 is its app's own data; it was delivered for the place names and is not
  verified with Trackwell.
- The month-end loss's mechanism, a read that drops a month's last day (inferred; the build code is not reachable),
  and adb's nightly load from the Directorate (the knowledge base, not the dump).

## 5. The design: one app profile, read by rule

### 5.1 Two kinds of quirk

- **The feed's own encoding**, the same for every app it carries: adb's codes and its zeros for NULL, the integer
  positions, fathoms, the trip and station tables' shape. Read by that feed's adapter, source-shaped, as now (decision
  165: reading the stored form is the adapter's work).
- **The app's habits**, the same whichever feed carries the record (fs, adb, the live, the afli route's copies): which
  time it copies where, its placeholder, its position form, its sign, its depth unit, its count, its state. Caught
  once, in `curate/`, by rule.

### 5.2 The profile

`curate/corrections/logbook_app_profile.yml`, the declaration, beside `logbook_app_profile.R`, the implementation
(AGENTS.md naming rule 6). One row per finding, reviewed by a person before it applies, as an override is: the profile
re-enters the flow as an input, never as a computed output.

```yaml
- id: T4
  apps: [Marína raun, FRA TAKTIKAL]      # the base name; suffixes " - GAFL AUTO", " - Skrifstofa VES" ignored
  feeds: [fs_afladagbok, adb]
  period: [2021-01-01, null]              # an open end is NA (AGENTS.md)
  gear_class: [jig, static]
  field: t1
  holds: "copy: departure"                # recorded | copy:<field> | placeholder:<rule> | date | default:<value>
                                          # | unit:<unit> | form:<form> | sign:<convention> | precision:<value>
  action: flag                            # flag | read_as | convert | none
  evidence: counts/x02_times_port_calls.tsv (within 1 h of leaving port 77-94 %)
  reviewed: null
```

A row may name an app, a version, a period, a gear class and a vessel list (for an app that mixes units, as
`afli_depth_units` does per vessel-period). A row with `holds: recorded` says the field was checked and found sound.

### 5.3 Flags, and what the flow does with them

- **Every value stays as recorded** (AGENTS.md: an extreme value is flagged, not corrected; the maintainer,
  2026-10-29: "same should apply in general"). Per field a flag column: `t1_flag` to `t4_flag` (`placeholder`,
  `copy_departure`, `copy_landing`, `copy_haul`, `copy_previous`, `date`, `trip_time`, `pressed`, `stamped`),
  `pos_flag` (`cell_1deg`, `quarter_minute`, `saved_late`, `end_copy`), `z_unit` with `z1_basis`, `z2_flag`, and the
  rule's id. `t1_placeholder` stays one release, as `t1_flag == "placeholder"`.
- **The windows read the flags as `judged_time_sql()` reads the duration limit:** a flagged time opens and closes no
  window and makes no duration. A station left with no usable time gets the day window, basis `synthesised`, as a
  date-only record does (TODO 164 c), or a trip window (ask c).
- **The app is carried** on the staged and merged station: today it is on the trip alone (`ws_veidiferd.uppruni`,
  `fishing_trip.source`), and the afli route's version only in `staging/afli_sent`.

### 5.4 The check

`curate/checks/logbook_app_profile.R` makes `02_profile.py`'s classes on every build, per feed, app, version, year,
gear class and field, into `curated/check/logbook_app_profile.parquet`, and compares them with the profile. It lists
as news: an app or version no row names (today `Skráningar.com`), a class no row names, and a share that moves by more
than a set margin. The witnesses (track, port calls, GEBCO, landing, Trackwell's copy) run on demand, as decision 211
proposed for the positions (`logbook_position_forms.R`, folded in here). A check, never an input.

### 5.5 What moves

- **Out of `curate/logbook.R`:** the "Placeholder set times" section, to rows T1-T3; `fathoms_to_metres()` for every
  fs and adb station, to rows D1-D3 by app (decision 210's `fs_depth_units`).
- **Out of `sources/fs_afladagbok/convert.R` and `R/logbook_position.R`:** the names STOKKUR and TAKTIKAL. The decoder
  takes the app's form from rows P2-P4, so a new app's form is a row, not code. The forms stay read at the adapter: it
  reads its stored form, with the profile as a reference input, as it reads the gear table.
- **From decision 206 and TODO 164:** T2, T3, T13, T14 become rows; T11 flags the trip's departure, not the tow start.
- **Stay as they are:** the sign rule (it reads every app's convention right), `logbook_twin` (it takes every
  resubmission in the merge), the tiers, the date bounds, adb's gear read back, the merge's trips with stations only.

### 5.6 TODO 164's choices under the design

- **a.** Rows T2 and T3: Trackwell raun's `t1` at 270 + k x 1,440 min (k >= 0, +-1 min), flagged. 2,449 merged
  stations more than today's 23,330 fs and adb.
- **b.** Per-app rows where the app writes no set time (Marína and Taktikal: the trip's times; STOKKUR: the landing;
  TRACKWELL: a date; Reiknistofa, Fishtech, Jóhann Gíslason: the haul start; Fontos: the previous haul), and per-value
  flags on Trackwell raun's own copies. The maintainer's earlier "left as recorded" holds for the value: it is kept and
  flagged, not opened as a set window.
- **c.** The fallback of §5.3: the 3,632 merged stations whose only window is a false set window get the day window.

### 5.7 Alternatives weighed

- **The status quo:** a case in code per quirk as it is found. Each new app or version is new code, and no check
  notices a new app. 22 of the 42 quirks are caught by nothing today.
- **Rules on the value alone, no app:** "a start equal to the departure is a copy". The same equality means opposite
  things by app (§2): flagging it would take 3,064 real tow starts with Marína's departures, and leaving it would keep
  both. Kept inside the check, as its detector.
- **The track as judge of each value:** the set finder does not recover set times (decision 158), and a value made from
  the track would make the AIS a source of logbook values, a cycle (AGENTS.md). Kept as a witness.
- **Upstream:** the vendors stop their fills, or the Directorate rejects them. Trackwell's own copy shows its app holds
  metres and sound positions, and the placeholder is in the record the app sends (decision 158), so only the vendor can
  stop it (TODO 103's draft). On hold with every contact.
- **Another feed:** §3's options. None removes an app's habits.

The profile is proposed; the value rules serve it as detectors, the witnesses as its evidence, and upstream as its exit.

## 6. Steps

1. **Measure** (done 2026-10-29, §1-§3).
2. **Carry the app** on every staged station and fishing sample (fs, adb, the afli route with its version; afli's edited
   layer through `rafr_stofn`'s message key), base name and suffix apart.
3. **Draft the rows** from §1-§2, one per finding, each with its count file; a person reviews them (ask a). *Drafted
   2026-10-29:* `curate/corrections/logbook_app_profile.yml`, 45 rows (20 flag, 10 note, 8 none, 4 read as, 3
   convert), each with its scope (the app's every value, or the values showing the pattern), its evidence and the ask
   that governs it; `reviewed` is null on all. Nothing reads the file yet.
4. **The check**, tested to give this archive's counts on the store of 2026-10-29.
5. **The flags** in `curate/logbook.R` after the twins, from `R/logbook_app_profile.R`; the placeholder section goes.
6. **The windows** (`curate/station_window.R`, `judged_time_sql()`) read the flags; the fallback window.
7. **The adapters' decoders** read the position forms from the rows; the app names leave the code (TODO 126's forms).
8. **Depth by app**, per vessel-period where an app mixes; STOKKUR's 0 read as none.
9. **A scratch build**, traced before and after: windows, `station_event`, the fishing fixes, effort, catch on the
   fixes, the allocation audit, every station in one outcome. Then the rebuild on the maintainer's go, and a decision.

## 7. What it changes, folds in, supersedes

- **Folds in:** TODO 164 (its choices are §5.6); TODO 103's "other placeholder patterns" and the gillnet sets in port
  (T12); TODO 107's chosen and unbuilt items (decision 206; its towed departure copies reversed by T11, ask d);
  TODO 126's per-app forms and decision 211's proposed per-app check; decision 210's `fs_depth_units`.
- **Informs:** TODO 162 (Trackwell's copy witnesses 987 afli-route longitudes, P8); plan 051 (the state by app, K1-K3;
  the factor stays its own); plan 050 ask f (§3); plan 037 (the afli route as sent has its own faults: P8, D5, T15);
  plan 052 (the gear detail is not profiled here).
- **Supersedes:** `logbook_set_placeholder.yml` as the place of the rule (kept as its history).
- **Stand:** decisions 157, 158, 160, 206 (as evidence), 211, 242, 243.
- **Code:** `curate/logbook.R`, `curate/station_window.R`, `R/duration_limit.R` (`judged_time_sql()`),
  `R/logbook_position.R`, `sources/fs_afladagbok/convert.R`, `sources/adb/convert.R`, the afli adapters (the app
  carried), a new `curate/corrections/logbook_app_profile.{yml,R}`, `R/logbook_app_profile.R`,
  `curate/checks/logbook_app_profile.R`, `docs/data-dict.yaml`.

## 8. Asks

- a. **Review the rows** (needs a person): each finding's reading, in the order T1-T3, T4 and T10, T5, T9, D2, P2-P4.
- b. **Flag and keep, or NA:** decision 158 set the placeholder `t1` to NA; AGENTS.md's rule of 2026-10-29 keeps a value
  as recorded with a flag. Proposed: kept and flagged for every time, the placeholder included.
- c. **Times that are the trip's** (Marína, Taktikal): the day window, or a window bounded by the trip's departure and
  return, which the track confirms on 77-94 %? Proposed: the trip's, basis `derived`.
- d. **Decision 206's towed departure copies:** blank the tow start (206), or flag the trip's departure (T11, the track
  near on 92-97 %)? Proposed: flag the departure.
- e. **Trackwell raun's stamped set times** (T12; in port on 25-26 %, near on 30-35 %): flagged as weak, or as recorded?
- f. **The feed, once the hold lifts:** which of §3's options; proposed 2, then 3.
- g. **Trackwell's own file as a standing witness:** ask for a copy to date when contact resumes?
- h. **Vendors' trials** (I4): a trip flag by rule (an app's unlanded trips concentrated on one vessel), or kept as now?
