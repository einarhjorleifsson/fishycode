# 026 — The ERS catch reports of `dw_aflaskeyti` as a logbook source: foreign vessels 2014-2018

**status:** proposal — measured 2026-10-17; §2-§7 written: coded, run on a scratch `$FISHYDATA` against the committed merge, targets added (§11), `docs/merge.qmd` section rendered; nothing built (TODO 62, 77) · **2026-10-17**
· **see:** decision 126, TODO 62 and 77, plans 014, 017 and 024; `curate/logbook.R`, `curate/link_lid_map.R`,
`curate/corrections/logbook_gear.R`, `curate/station_window.R`, `curate/ais_catch.R`

Drafted with AI assistance (Claude) on 2026-10-17. The maintainer chose to take the Norwegian and Faroese rows of
`dw.dw_aflaskeyti` in as a logbook source, as decision 126 recommends, and asked for the plan first, with an
answer on the 282 Icelandic hauls (§7).

**Measured** (read-only, 2026-10-17, on `raw/oracle/dw/dw_aflaskeyti.parquet` against `curated/`):
- everything in decision 126;
- here: the gear codes (§2), the times by flag and season (§3b), longline events from the AIS speed profile (§2),
  the gaps between hauls and to the next landing (§4), the Icelandic rows' weight by vessel and the 282 hauls with
  their fixes (§7).

**Assumed:**
- that `afli_kg` of the foreign rows is round weight: every row says "live weight in kg.", and the weight landed in
  Iceland is 0.98-1.13 of it, never near 1.25;
- that Faroese times follow Faroese summer time on 2017-10-14..28 too (6 hauls with fixes, too few to tell);
- that the 48-hour and 7-day thresholds of §4 hold for the rows not measured;
- that the start and duration of a Faroese `LLS` or Norwegian `LLS` haul are setting start and hauling end, as
  measured for Norwegian `LL` (§2).

## 1. What enters

The Norwegian and Faroese rows: 6,310 rows, 2,778 hauls of 111 vessels, 280.4 kt, from 2014-01-20 to 2018-06-08
(the Faroese from 2017-10-14). The Icelandic rows are staged too, and tier 4 keeps the 280 Icelandic hauls on
vessel-days the logbook lacks (§7, the maintainer's choice of 2026-10-17). A haul is one station with one fishing
sample (the collapsed case of `docs/grammar.qmd`).

- **Schema:** `"aflaskeyti"`. Ids are unique only within a schema, so everything joins on (id, schema).
- **Haul:** (`id_skip`, `dagsetning_hols_dt`): no vessel starts two hauls at one minute. A haul sent in more than one
  message (1,131 Icelandic hauls, one Norwegian) is the latest message's, whole. Where the Icelandic logbook has the
  haul, the latest message agrees with it in 2,892 of 2,979 species rows, the earliest in 2,211 of 2,772.
- **`.sid`:** the haul's lowest `aflaskeyti_id`. It is the source's own id, so it is stable from dump to dump.
- **vid:** `id_skip`. All 144 resolve in `vessel.parquet` (decision 126).

## 2. The adapter: `sources/aflaskeyti/convert.R`

Side: preprocessing (aflaskeyti). Input: `raw/oracle/dw/dw_aflaskeyti.parquet`. Output:
`staging/aflaskeyti/{trip,station,fishing_sample,catch}.parquet`, the four tables of the other logbook adapters.
It reads no other source and corrects nothing (AGENTS.md).

- **station:** `.sid`, `.tid`, `date` = `dagsetning_hols` (as recorded), and the positions as Oracle names them
  (`lon1` = `lengd_byrjun`, `lat1` = `breidd_byrjun`, `lon2` = `lengd_endir`, `lat2` = `breidd_endir`); §3a swaps
  them. There is no depth and no `sq`/`ssq`, as fs_afladagbok and adb have none.
- **fishing_sample:**
  - `gid_old` = `id_veidarfaeri`, the Directorate's code as recorded; `gear`, `target` and `target2` from the
    `gid`'s row in `gear.parquet`, as for the other sources.
  - `gid` through `gear.parquet`, version `new`, column `map`: 1 → 12 (LLS), 6 → 6 (OTB), 7 → 9 (OTM), 14 → 8 (OTB,
    shrimp). Four codes have no row there. MFRI's gear register, `raw/oracle/gear/veidarfaeri_v`, uses the same
    numbers and gives their ISSCFG class, as does the source's FAO column: two-boat purse seine (57, ISSCFG 0110
    `PS`) and one-boat (56, `PS_1`; not in the register) go to 10 (`Nót`); bottom pair trawl (75, 0315 `PTB`) and twin
    bottom otter trawl (76, 0313 `OTT`), on Icelandic rows only, go to 6 (`Botnvarpa`). The foreign gears are `PS_2`
    869 hauls, `PS_1` 687, `PS` 369, `LLS` 689, `LL` 136, `OTM` 22 and `OTB` 6.
  - Times by gear class. Mobile gear and purse seine: `t2` = `dagsetning_hols_dt`, `t3` = `t2` + `lengd_hols`, and
    `duration_m` = `lengd_hols`. On the Icelandic trawl rows `t2` matches the logbook within a minute in 4,716 of
    5,050 hauls, and `lengd_hols` = `t3` − `t2` in 4,693 of 4,716. Purse seine sets slow from 5-6 kn to 0.6-1.0 kn
    at the start and speed up after the end.
  - Longlines: `t1` = start and `t4` = start + `lengd_hols`, with `t2`, `t3` and `duration_m` empty. For Norwegian
    `LL` the AIS speed is 7.7 kn in the first hour of the reported haul and 7.2 kn in the second, which is setting.
    In the middle it is 2.1 kn and in the last hour 1.9 kn, which is hauling. The Faroese and Norwegian `LLS` show it
    less clearly: 2.3 and 5.5 kn in the first two hours, and 3.1 and 3.2 kn.
  - The 63 hauls with duration 0 get no end: 50 purse seine sets (41 of them Faroese) lose `t3` and `duration_m`,
    with `.duration_source` `implausible` as afli has it; 13 Norwegian `LL` hauls lose `t4`.
  - Effort columns are empty: the flow takes effort from the fixes.
- **catch:** `.sid`, `sid` = `id_fisktegund` (the Icelandic species code, the same as the logbook's), `catch` and
  `catch_whole` = `afli_kg`, and `condition` `UNGU` (round).
- **trip:** one row for each run of a vessel's hauls, cut where the gap from one haul's end to the next haul's start
  is 48 hours or more (§4). `vid` = `id_skip`, `T1` = the run's first time, and `T2`, `hid1`, `hid2` empty. `source`
  is `ERS DCA (dw_aflaskeyti)`. §4 then cuts the runs at landings in Iceland and dates them.

## 3. Two corrections (the third is §7's)

Each is a declaration (`.yml`) paired with its implementation (`.R`), and writes a side table into
`staging/aflaskeyti/` that `curate/logbook.R` joins by (`.sid`, schema), as `adb_vs_fs_afladagbok` does for adb.
Nothing staged is overwritten.

### 3a. `curate/corrections/aflaskeyti_coordinates`: latitude and longitude swapped

- **Detection:** every row of the source. `lengd_*` holds 59.8 to 90.0 and `breidd_*` −179.5 to 37.2.
- **Evidence:** decision 126. On 4,716 Icelandic hauls the swapped start position agrees with the logbook to a median
  of 0.005°; as named it is 53° off. On the foreign hauls it lies 0.12-0.61 nm from AIS (purse seine).
- **Repair:** `lon1`, `lat1`, `lon2` and `lat2` swapped. `lon1_raw` and `lon2_raw` (existing columns) and
  `lat1_raw` and `lat2_raw` (new, empty for the other schemas) keep the staged values, and `coord_flag` reads
  `lat_lon_swapped`. The basis is `recorded`: the value is the recorded one, only its label was wrong.
- **Test:** every swapped latitude lies within ±90°, and 2,772 of the 2,778 foreign hauls lie in the box around
  Iceland, as measured.

### 3b. `curate/corrections/aflaskeyti_local_time`: Faroese summer times are local

- **Detection:** Faroese hauls during Faroese summer time, which follows the EU rule: from 01:00 UTC on the last
  Sunday of March to 01:00 UTC on the last Sunday of October. That is 316 hauls.
- **Evidence:** on the 264 of them with fixes, a shift of −60 min puts the start 2.0 nm from AIS, against 5.8 nm
  unshifted. Faroese winter hauls fit best unshifted (1.5 nm), and so do Norwegian hauls in summer (1.0 nm; −60
  min gives 2.7) and in winter (0.18 nm).
- **Repair:** `t1` to `t4` moved by −60 min. A new `time_basis` column reads `reconstructed`, and `t_shift_min`
  holds −60, so the recorded time is `t` − `t_shift_min`. Both are empty for the other schemas. `date` stays as
  recorded.

## 4. The trip: `curate/aflaskeyti_trip.R`

Side: preprocessing (logbook and landings). It reconciles the logbook with the landings, which preprocessing may do
(plan 014), and reads no AIS. Input: the staged tables, §3b's times, and `curated/landing/landings.parquet`. Output:
`staging/aflaskeyti/trip_landing.parquet` (the trips, replacing the adapter's runs) and
`staging/aflaskeyti/station_trip.parquet` (each station's `.tid`).

**Why it cannot be left to the gap rule.** `ais_catch.R` takes one source per trip. A landing that no logbook trip
claims in `lid_map` is a unit of its own and carries its own catch. A foreign trip that does not reach its landing
in Iceland would have its catch counted twice: on the hauls, and on the landing.

**Measured** on the 2,778 hauls and the 918 landings of the 111 vessels in Iceland:

| gap between consecutive hauls | Faroese | Norwegian |
|---|---|---|
| no landing between: 95 % below | 23.4 h | 32.5 h |
| no landing between, 48 h or more | 7 of 581 | 43 of 1,610 |
| a landing between: median | 207 h | 161 h |
| a landing between, under 48 h | 2 of 41 | 73 of 435 |

Norwegian capelin vessels land close to the grounds, so a landing must cut a trip before a gap does. From a vessel's
last haul to the next landing is 7 days or less for 454 of 460 Norwegian landings and 55 of 58 Faroese ones.

**Rule.**
1. **Cut at a landing.** A trip ends at a landing in Iceland that falls between the end date of one haul and the
   start date of the next, and no more than 7 days after the haul. `T2` = the landing's date and `hid2`/`pid2` its
   port, with basis `reconstructed`. Where several landings qualify, the first one ends the trip.
2. **Cut at a gap.** Otherwise a trip ends where the gap to the next haul is 48 hours or more. `T2` is empty (basis
   `none`): the catch was landed abroad, or later than 7 days after.
3. **T1.** The trip's first haul time, basis `synthesised`. It is a bound on departure, never a departure, and it
   is enough for `link_trip_voyage.R`, which matches by overlap.

`link_lid_map.R` then matches the dated trips to their landings at step 1 (vid, date, port), unchanged.

## 5. The tier in `curate/logbook.R`

- **Tier 4, aflaskeyti:** vessel-days that tiers 1 to 3 do not hold (an anti-join on vid and date, as for adb). No
  foreign station overlaps a curated one in 2014-2018 (decision 126), so for the foreign rows the tier keeps
  everything.
- **The joins:** §3a's, §3b's and §7's side tables and §4's trips.
- **The new columns**, empty for the other schemas: `lat1_raw`, `lat2_raw` and `coord_flag` values on `station`;
  `time_basis` and `t_shift_min` on `fishing_sample`; `condition_basis` on `catch`; `T1_basis` and `T2_basis` on `trip`.
- **The inputs:** the staging files go into `logbook_inputs`.
- **`_targets.R`:** `aflaskeyti_raw`, `aflaskeyti`, `aflaskeyti_coordinates`, `aflaskeyti_local_time`,
  `aflaskeyti_trip` and `aflaskeyti_weight`, with the logbook target depending on the staged tables and all four
  side tables.
- **Plan 024:** if built, `station_fate` counts the new schema too.

**Unchanged code downstream:**
- `link_lid_map.R`: §4.
- `logbook_gear.R`: the landing's gear where it names one; capelin landings name purse seine or pelagic trawl.
- `station_window.R`: windows by `gid`'s gear class; PS is class `other`.
- `ais_trail.R`: 88 of the 111 vids have fixes in 2014-2018, and 2,191 hauls hold at least one.
- `ais_catch.R`: stations with timed windows are level-1 units.

## 6. The span, on the table and on the docs page

- **On the table:** every row carries `schema` `aflaskeyti`, and the trips carry `source` `ERS DCA
  (dw_aflaskeyti)`.
- **`docs/merge.qmd`:** written 2026-10-17, "Foreign vessels: the ERS catch reports, 2014–2018" (`#sec-ers`), with a
  table read from `curated/logbook` that says the rows arrive at the next build until they do. It is a section on
  foreign vessels and their ERS catch reports, 2014-2018. It gives the span; the
  coverage by flag and year from decision 126 (Norway whole by vessel, 72-77 % of AIS fishing days from 2015; the
  Faroes about 700 vessel-days a year by AIS, none before 2017-10); the three corrections; and the trip rule. Foreign
  fishing outside that span takes the pings path, and the basis on each fix says which path it took.

## 7. The Icelandic hauls on vessel-days the logbook lacks: in (maintainer, 2026-10-17)

Counted below by vessel, time and position as 282; by vessel and start time they are 280 hauls, two of them sent
again with a corrected position (§11).

**Measured:** of the 5,050 Icelandic hauls, 4,716 are in the curated logbook. Of the other 294, 282 lie on vessel-days
the Icelandic logbook lacks entirely:

- 75 vessel-days of 6 vessels, 2,640 t, mostly 2014-2015;
- cod 2,009 t, haddock 389 t, shrimp 158 t, saithe 76 t;
- bottom trawl, with one vessel's shrimp trawl and purse seine and one pelagic trawl haul.

All 75 vessel-days have fixes in the trail, 12,829 in all and 7,912 of them `fishing_flow`. Only 262 of those fixes
lie on a logbook station today.

**Why yes:**
- They come from the same feed that agrees with the logbook to a minute and 0.005° on the 4,716 matched hauls.
- They fill days that nothing holds, and put about 7,900 fishing fixes on the record path.
- The tier's anti-join picks them out with no code of its own. Staged with the foreign rows, any Icelandic haul on a
  vessel-day the logbook holds is dropped by the rule that already drops adb's.

**What they add:**
- **Resends.** 1,131 Icelandic hauls were sent in two or more messages. The adapter keeps the latest message's
  version of each haul, whole (§1).
- **The weight of demersal species.** It is a trait of the vessel. Of the 13 vessels with matched demersal catch,
  six report it in ERS at the logbook's weight and six at 1/1.25 of it, gutted against round; one does both. A
  correction, `curate/corrections/aflaskeyti_weight`, sets `condition` per vessel and species from the vessel's own
  hauls matched to the staged afli logbook (upstream of the merge, so no cycle):
  - the majority of its matched station-species pairs: 1.25 times → `GUTT`, which `catch_by_species_station.R`
    raises by 1.25; equal → `UNGU`; basis `derived`;
  - a species round wherever matched (at least 20 pairs, 95 % equal: blue whiting, redfish, shrimp) → `UNGU`;
  - anything else `NA`, basis `none`; foreign rows `UNGU`, basis `recorded`;
  - `catch` is never changed (the weight in the state `condition` names, as in fs_afladagbok and adb), and
    `catch_whole` is the catch where `UNGU`.
  On scratch: 4,700 Icelandic hauls matched, 11,270 pairs; of the Icelandic catch rows 7,648 `GUTT`, 4,300 `UNGU`
  and 168 `NA`. Vessels 1351, 1395 and 1937 come out round, 1579 gutted, and the two vessels with no matched hauls
  (2770 and 2903, 33 hauls, mostly shrimp and purse seine) round where the species is, else `NA`.

## 8. Checks (done when)

1. `staging/aflaskeyti`: 7,770 stations, 2,778 of them foreign, their kg equal to the raw rows' less resent rows
   (280.4 kt foreign less one 80 t row), no catch row without a station.
2. §3a moves every position. 2,772 of the 2,778 foreign hauls lie in the box around Iceland. §3b moves the 316
   Faroese summer hauls by −60 min.
3. Every station is on a trip. Every trip with a `T2` has a `lid_map` row. No landing in Iceland that follows foreign
   hauls within 7 days is left without a `lid_map` row, so `ais_catch.R` counts no catch twice.
4. `curated/logbook`: the other schemas' row counts and catch by schema are unchanged.
5. `curated/ais/trail`: foreign hauls with fixes are on their station windows (2,191 hold a fix between `t2` and
   `t3` today).
6. `curated/ais/catch`: the foreign catch is on the record path, and kg in equals kg out per vessel and year.
7. `docs/merge.qmd` renders with the section, and `check_bookkeeping()` passes.

## 9. Order and build

1. The adapter.
2. The three corrections.
3. The trip script.
4. The tier and the targets.
5. The docs section.

Each step is tested on a scratch `$FISHYDATA` against the current build, as decisions 124 and 125 were, and nothing
is written to `$FISHYDATA` before the build. The build rides on TODO 77's single `tar_make_isolated()`, since
everything from `logbook` down is outdated there already.

## 10. Asks

a. **The 282 Icelandic hauls (§7):** answered — in, with the weight correction (maintainer, 2026-10-17).

## 11. The scratch run (2026-10-17)

§2-§5 and §7 were run on a scratch `$FISHYDATA`:
- **Linked read-only:** `raw/`, the curated reference, landing and vessel tables, and fs_afladagbok's and adb's staging.
- **afli's staging** has a column `copy` = `afli` added, since the real one predates decision 124.
- **The baseline:** the merge as committed (HEAD's `curate/logbook.R`) ran on the same inputs.
- **The targets:** all six are in `_targets.R`, and `logbook` reads them.

- **Adapter.** 7,770 stations (2,778 foreign, 4,992 Icelandic).
  - Foreign catch is 280,273 t: the raw 280,353 t less one capelin row of 80 t sent in two messages.
  - Every gear resolves.
  - 63 hauls with duration 0 have no end.
- **Corrections.**
  - All positions are swapped back.
  - 316 Faroese hauls are moved by −60 min.
  - Weight: 4,700 Icelandic hauls are matched to the staged afli logbook.
- **Trips.** 812 before the tier. 4,713 hauls lie inside an Icelandic logbook trip and claim no landing (§4). The first
  run, without that rule, let Icelandic vessel 2903's one haul of 2018-05-08 take the landing of its afli trip of
  2018-05-05..10.
- **Tier 4** keeps 3,058 of the 7,770 stations, in 595 trips:

  | flag | stations | trips | catch | around Iceland |
  |---|---|---|---|---|
  | Norway | 2,138 | 514 | 264.5 kt | 2,132 |
  | Faroes | 640 | 65 | 15.8 kt | 640 |
  | Iceland | 280 | 16 | 2.7 kt | 1 |

  The 280 Icelandic hauls are exactly the hauls of §7. Its "282" counted two hauls twice, sent again with a corrected
  position. Their weights: 604 t `GUTT`, 2,080 t `UNGU`, 0.2 t `NA`. No twin, and no catch row without a station.
  Station type: 2,215 `operation` and 18 `event` (derived), and 825 longline `operation` (synthesised).
- **Unchanged.** afli, fs_afladagbok and adb are identical to the baseline in all four tables: 0 rows differ, and only
  the new columns are added, empty. `lid_map` for those schemas is identical to the baseline's: 822,787 links, 0
  differing.
- **`lid_map` for aflaskeyti.** All 521 trips dated by a landing are claimed at the first, exact step; the 74 ended
  at a gap are not. `rb_link_trip_voyages()` pads a missing `T2` to the end of `T1`'s day (DuckDB's `greatest()`
  skips NULL), so a gap-ended trip links to the voyage of its first day.
- **A residual: second landings.** Of the 531 landings in Iceland within 7 days after an aflaskeyti haul, 522 are
  claimed, 521 by aflaskeyti trips and 1 by vessel 2903's afli trip. The other 9 (3.5 kt) are one catch unloaded
  across midnight, mostly the next day at the same port. `link_lid_map.R` links one landing to each trip, and by
  `ais_catch.R`'s rule a landing it leaves unclaimed carries its own catch, so these 3.5 kt would be counted twice.
  Icelandic trips have such landings too: TODO 81 measured 9,955 next-day landings at the same port, most of them
  after the vessel fished again, and 490 (23.0 kt) counted twice. Joining a trip's further landings to it is a
  matter for every schema (TODO 81), and covers these 9 too.
