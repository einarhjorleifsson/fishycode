# 052 — The logbook's gear, rigging and sensors: four tables designed on afli's `rafr_` layer

**status:** proposal — written 2026-10-29 at the maintainer's request; nothing built · **measured** (§1-§3), by Claude
the same day, read-only on the dumps of 2026-10-16/17 and the store, not checked by a person: six grammars mined into
one union of terms; afli's `rafr_` gear tables, their edited copies, and fs_afladagbok's and adb's gear tables, column
by column; the per-haul sensor values and the logger · **assumed** (§4): the meaning of seven undocumented columns, two
units, and what a zero or a 1 stands for · **see:** plan 020 (superseded for the gear tables' design), plan 037 (the
layers), decision 210, TODOs 73, 98, 100, 131 and 140, `docs/grammar.qmd`,
`$FISHYDATA/archive/2026-10-29-gear-rigging-sensor/`, `$FISHYDATA/archive/2026-10-xml-oracle-map/`

Drafted with AI assistance (Claude) on 2026-10-29; a person has not yet checked it. Every number is Claude's, from a
script or count file in `$FISHYDATA/archive/2026-10-29-gear-rigging-sensor/` (`scripts/`, `counts/`, `grammar/`), named
by its number below (`03` is `scripts/03_rafr_fill.R` and its `counts/03_*.tsv`).

The maintainer, 2026-10-29:
- "we want to take into account when we structure the logbook product the thinking of gear, the rigging part and then
  the sensor part. the latter are normally some summary records, but occasionally we have continuous recording of the
  sensor, e.g. the gps (do not forget the valuable depth data in that set)."
- "things like mesh size belong to the gear, things like warp to the rigging".
- On the logger's depth, joinable to the AIS fixes by vessel and time in the analysis: "including them in the ais is
  not the way".
- On the prototype: "absolutely not, use afli.rafr_ as the prototype. the fs_afladagbok thinned everything."
- "dig deep … remember the deepest grammar version we may have, that includes what we may have in repo imbus and
  datrasdoodle2. think they may potentially be richer than what we have in fishycode."

## 1. The deepest grammar

**What was mined** (`00`; `grammar/grammar_terms.tsv`, 614 rows, one per term and source, in 118 concepts;
`grammar/grammar_union.md`, the write-up with a line reference for every statement). The sources:

- fishycode's `docs/grammar.qmd`;
- the old grammar, `~/stasi/logbooks/grammar.qmd`;
- IMBUS's D2.2 and D2.3, its DATRAS yaml and technical reference;
- the ICES manuals in `imbus/DATRAS/external/`: SISP 10 (NS-IBTS) with its Annex 7 rigging tables, SISP 15, WKFDNG,
  WKDATR13 and its field ranges, the units and swept-area documents;
- datrasdoodle2 and obus.

The reading is by a Claude subagent, checked here on three claims against the files.

**Richer elsewhere:**

- **Rigging parts.** SISP 10's Annex 7, SISP 15 and WKFDNG name bridles, backstrops, kite, floats, groundgear,
  adjuster chain, restrictor rope and warp density, each with length, diameter, material and weight. fishycode's part
  list has none of them.
- **Code lists.** DATRAS has ICES vocabularies for door type, gear exceptions (`GearEx`: bobbins, double sweeps,
  rockhopper, single or double beam), rigging (`Rigging`: groundrope kinds, ticklers, chain mats), ticklers and
  thermocline. It also has archive ranges, per-survey ranges and dependency rules (`ThermoClineDepth` needs
  `ThermoCline`; the gear must agree with `GearEx` and `DoorType`). fishycode states none.
- **Sensors.** The manuals record a sensor's rate, statistic, averaging window, mounting and calibration.
- **Where a width came from.** datrasdoodle2 sorts gear widths into measured, nominal, modelled and borrowed.
- **The environment.** HH has thermocline, Secchi depth, turbidity, tide, currents at two levels and a link to a
  hydrographic station (`HydroStNo`). fishycode's environment table lacks them, though its own HH example lists them.

**Richer in fishycode:**

- many gears in one shape, by part and measure (HH is one wide row because it covers one class of gear);
- the count of units with its basis, the rig (twin, pair), the mishap and the lost gear;
- water depth kept apart from gear depth, with a rule for a depth whose kind is not stated;
- values at the start and end;
- `basis` and the layer per field group;
- the four events and the A-J phases;
- the streams.

**The old grammar against the current one.**

- **Warp.** The old one put warp length in pre-deployment configuration, with mesh and door type. The current one
  contradicts itself: its field-group table puts "warp out" under execution (line 75), its HH example puts
  `Warplngt` under configuration (line 112).
- **Streams.** The old one is closest to the maintainer's view that AIS is one vessel sensor. It makes GPS and AIS
  positions, VMS, underway temperature and salinity and echograms one class of trip-level stream on (`vid`,
  `timestamp`). It also names afli's logger as recording position, depth, temperature and heading on one tick. The
  current one splits the track from the underway sensors, with a key each.
- **Dropped since:** course (`cog`) and barometric pressure.

**One lens no grammar has.** None treats AIS as one store of a vessel sensor among others, and none names ASTD, ASTD B
or EMODnet (`grammar_union.md` §3). The proposal: the grammar's track and underway sensors become one stream class,
the vessel's sensors, on (`vid`, `time`, `provider`). Position is one quantity, as depth, temperature or wind are, and
each store is a provider. A logger on the gear stays a sample, as the grammar has it now.

**Specification against measurement.** datrasdoodle2's point holds for the logbooks: every gear and rigging value in
`rafr_` is a specification the skipper types, often the same value every haul. Only the sensors measure. The design
keeps the two apart by table (gear and rigging against sensors), not by a new basis value.

**The line between gear and rigging** (ask a). The maintainer's rule: mesh to the gear, warp to the rigging. Drawn
generally:

- **gear** is one unit that catches, the netting and what is fixed to it. It is set when the unit is built or fitted,
  and it decides what the unit catches and how it meets the bottom.
- **rigging** is what connects the units to the vessel and to each other, and how many units are fished at once. The
  same unit can be fished with other rigging.

| term | where | why |
|---|---|---|
| mesh, codend, extension, liner, belly, panels | gear | the netting itself |
| headline, footrope, groundgear (rockhopper, bobbins), groundrope weight, adjuster chain | gear | the net's edges, built into it; they set its opening and its bottom contact |
| floats (buoyancy), kite | gear | fixed on the headline; they lift it, as the doors spread it from outside |
| grids, square-mesh windows, panels and other selection devices | gear | inside the net; they set what is kept |
| hooks (type, size, per tub), bait, hooks per jig | gear | the unit of a line or a jig |
| a gillnet's mesh, height, length; a seine, dredge, beam or trap | gear | the unit |
| warp (length, diameter, density) | rigging | the maintainer's rule; the per-haul depth it reaches is execution (the gear depth) |
| doors (type, weight, area) | rigging | between the warp and the sweeps; they spread the gear from outside, and one net is towed with other doors |
| sweeps, bridles, upper bridles, backstrops, the Danish seine's ropes and wires | rigging | they join the doors or the vessel to the wings |
| tickler chains, chain mats, clump weights, restrictor rope | rigging | strung ahead of the net or between the warps, not part of the netting; added or taken off by ground |
| the rig: single, twin, triple, pair | rigging | how many units one vessel tows, or how many vessels tow one; the same net is fished single or twin |
| the count of units: nets in a fleet, tubs, jigs, traps, trawls | rigging | the assembly; what one unit is made of is gear. `effort_count` reads it |
| sensors on the gear (headline, door, catch sensor) | neither | sensors (§5), marked `mount = gear` |

DATRAS's `Rigging` list splits under this line: its groundrope kinds (BC, BM, BN) go to the gear, its ticklers and chain
mats to the rigging. Step 6 puts warp in the rigging in `docs/grammar.qmd`, ending the contradiction between its
lines 75 and 112.

## 2. afli's `rafr_` tables, measured

**What they are.** `rafr_` is afli's electronic layer as loaded from the apps' XML messages (plan 037: the *loaded*
layer). `rafr_stofn` holds 1,149,278 stations, 16,912 deleted (`eytt`), so 1,132,366 counted here: under 8 thousand a
year in 2003-2007, 46-101 thousand in 2008-2019, 44 thousand in 2020 to July (`03`, `06`). Each station has at most one
row in one gear table, keyed on `visir`: `rafr_toga` (towed gear, 53 columns, 917,102 stations), `rafr_lineha` (lines,
nets and jigs, 28 columns, 206,721), `rafr_hringn` (purse seine, 12 columns, 8,487), and 56 stations in none (`03`,
`09`). The XML schema the apps sent documents each element; the study of 2026-10-21 (`2026-10-xml-oracle-map/`) traced
every element to its column and what the loader did to it. Its findings are used here and cited as "the XML map".

**The code tables** (`02`): footrope (`rafr_stofn_fotreipi`: Rockhopper, Fótreipi, Keðja, Plötur, Stálbobbingar,
Plastbobbingar, Annað), codend (`_gerd_poka`: capelin, herring, blue whiting, *speni*, *sekkur*, redfish, other), grid
(`_skiljugerd`: none, juvenile, small-shrimp/juvenile, fish, bycatch, Nephrops), hook (`_gerd_kroka`: J, EZ, EZ-W, O,
wide gap, jig hook, halibut hook, other), bait (`_beita_t`, 67 codes, species and artificial), sea state (`_sjolag`,
-1 not recorded, 0-8 with wave heights), bottom type (`_botngerd`, 15) and gear (`_veidarf`, 13; the purse seine's 12
and 13 are not in it). The hook-type list has no column: the apps sent `KROKAR@GERD` and `@STAERD` on 135,026 records
and the loader kept neither (the XML map).

**Fill by gear** (`06`, % of the gear's stations with a non-zero value; full table `counts/06_fill_by_gear_wide.tsv`):

| gear (stations) | filled on 85-100 % | filled on part |
|---|---|---|
| bottom trawl (566,861) | headline, codend mesh, door weight and area, sweeps, codend length, type and meshes around, belly mesh, footrope, wing-belly circumference, the catch-sensor flag | bottom temperature 64 % at the start and 46 % at the end, a grid named 20 % and bar spacing 16 %, a second codend mesh 17 %, two trawls 10 %, mesh orientation other than 0 on 15 %, square-mesh window 3 % |
| Danish seine (210,454) | headline, codend mesh, rope, body mesh (*voð*), panels, footrope | surface temperature 28 % |
| pelagic trawl (50,588) | headline, sweeps and upper bridles, doors, trawl name, largest and smallest mesh, headline depth (see §3) | headline temperature 80 % at the start, 72 % at the end; sounder type 11 %; codend mesh 10 % |
| Nephrops trawl (44,630) | headline, codend mesh, doors, sweeps, both sensor flags | codend details 78-79 %, two trawls 68 %, square-mesh window 76 % |
| shrimp trawl (44,390) | as bottom trawl, shrimp per kg 96 % | meshes around 73 %, grid 76 %, bar spacing 72 % |
| longline (135,766) | hooks per tub, tubs, hours in the sea | total hooks 33 %, air temperature 16 %, surface temperature 24 %, bait 11 %, sea state 77 % (−1 on 52 %) |
| gillnet (59,513) | nets hauled, mesh, height in meshes, nights | mean net length 18 % (0 on 81 % of those filled) |
| handline (11,377) | jigs, hours | |
| purse seine (8,487) | length, depth, mesh, set number and time | sea state 77-81 % (−1 on half) |
| dredge (170) | door columns as 1 | its own dimensions empty in `rafr_` |

**Units.** Oracle's comments are wrong on three columns. `rafr_toga.hoflina` (headline) is commented as feet and
`grandarar` (sweeps) as fathoms; the XML schema says metres for both, and the loader copied them as sent. On the 51
vessels that fished bottom trawl in afli's last e-logbook years (2019-20) and in fs_afladagbok's first (2021-22), fs's
headline over afli's is 3.28 (quartiles 3.27-3.29, feet per metre) and fs's sweeps over afli's 0.549 (0.544-0.556,
metres per fathom) (`08`). So afli holds metres and fs feet and fathoms, as fs's own comments say. `rafr_lineha.moskvi`
(gillnet mesh) is commented as inches and the schema says inches, but the values are mm (203.2 = 8 in, 228.6 = 9 in;
median 203). Converted by the loader from what was sent (the XML map): the Danish seine's rope and the purse seine's
length and depth (metres to fathoms), and the pelagic headline depth (metres to fathoms on 51 %, kept as sent on 49 %,
by app version). Codend length, door area, circumference and upper bridles are metres, by the schema.

**Every column in one class** (`09`, the map `counts/09_column_map.tsv`; a column is filled where some value is neither
null nor a placeholder held on every row):

| class | `rafr_toga` | `rafr_lineha` | `rafr_hringn` | all | filled |
|---|---|---|---|---|---|
| gear | 26 | 6 | 3 | 35 | 30 |
| rigging | 7 | 4 | 0 | 11 | 10 |
| sensor summary | 11 | 3 | 0 | 14 | 13 |
| environment | 1 | 1 | 1 | 3 | 2 |
| operation (times, durations, counts of sets) | 2 | 5 | 2 | 9 | 9 |
| other (keys, audit, catch observations, free text) | 6 | 9 | 6 | 21 | 18 |
| all | 53 | 28 | 12 | 93 | 82 |

Empty or a placeholder throughout: the dredge's width, length and height and the bottom type (sent on 177 records,
not loaded), the shrimp trawl's type (0, "obsolete" in the schema), the seine's wire length (0), the line's bottom
temperature, lumpfish count and long or short net. Seven columns have no documentation and are read from their values:
`fj_byrda` (2 or 4: panels, inferred), `moskvi_gerd` (0, 45, 90: the codend's mesh orientation T0/T45/T90, with 1, 3, 6,
50 and 80 on 11,438 tows), `moskvi2_staerd` and `moskvi2_fj_ummali` (a second codend, inferred: 17 % of bottom trawls,
34 % of Nephrops trawls), `moskvi_staersti` and `moskvi_minnsti` (the pelagic trawl's largest and smallest mesh,
medians 32,000 and 50 mm), and `beitufrakast` (longline, median 40, unknown).

**What the edit changed** (`04`, afli's edited `toga`, `lineha`, `hringn` against `rafr_` on the shared `visir`):

- **Rows:** 898,473 tows, 202,329 line sets and 8,291 seine sets shared. 32,787, 6,928 and 382 `rafr_` rows never
  reached the edited layer (TODO 118).
- **Columns:** none dropped by name. The edited `lineha` adds `grasleppuhrogn` (roe, kg).
- **Values emptied:** the surface temperature on every Danish seine haul (201,622 at the start, 28,217 at the end); the
  tow time on 106,603 Danish seine hauls (the XML map: 2005-2013 and 2015); bait on 5,694 and nets on 3,377 line sets.
- **Values changed:** soak hours 20,092 and nights 8,198 (rounded again); rope 6,701; headline 4,086; door weight 3,271;
  codend mesh 3,123; twin flag 3,347 (2,161 added); sweeps 1,973.

So the edit keeps every gear column and empties the surface temperature (two columns). What `staging/afli` reads
today is the edited layer.

**What fs_afladagbok and adb keep** (`05`, `09`). Of the 55 filled gear, rigging, sensor and environment columns of
`rafr_`, fs_afladagbok has a column for 21, and one more only in its tour app (tubs). adb has the same 21. Lost:

- **gear, 16:** codend length, type and belly mesh; a square-mesh codend; footrope type; the wing-belly circumference;
  the pelagic trawl's name and largest and smallest mesh; grid bar spacing; the second codend's mesh and meshes around;
  the Danish seine's body mesh and panels; hooks per tub; bait. The codend's meshes around is kept for shrimp trawls
  only.
- **rigging, 2:** door area; upper bridles.
- **sensor summaries, all 13:** the bottom, headline, surface and air temperatures, the headline depth, and the
  headline-sensor, catch-sensor and sounder flags.
- **environment, 2:** sea state on lines and on seines. (Wind is on `rafr_stofn` and not on fs either.)

fs keeps the codend mesh, headline, doors' weight, sweeps, rope, shrimp meshes around, grid type (as text), square-mesh
window, mesh orientation (in a column named `leggpoki`), twin flag, the net counts, mesh and height, mean net length,
hooks in all and jigs. It adds what `rafr_` lacks or leaves empty: the gear's material (343,288 of 469,881 operations,
151 values as typed), the seine's type, the dredge's dimensions, weight and type, traps and their type, and divers.
Its 469,881 operations: 349,868 in a gear table, 120,013 in none (`09`; 51,107 of them bottom trawl, 17,584 Danish
seine, 20,939 handline, 11,417 longline). That is the maintainer's "thinned": 33 of 55 columns, every sensor value, and
a quarter of the operations.

**Every station in one outcome** (`09`): of 1,149,278 `rafr_stofn` stations, 16,912 deleted; 56 with no gear row; 17 a
gear row with no measure; 8,487 gear only (seines); 11,356 rigging only (handlines: the jig count, with the hooks per
jig lost on loading); 521 gear only and 162,358 gear and rigging without a sensor value (lines and nets); 147,660 tows
with gear and rigging and 3 with gear only, without a sensor value; 801,908 with a sensor value or flag (769,439 tows,
32,469 line sets), of which 537,584 hold a reading (§3, `10`).

**afli before `rafr_`** (`04`, `11`: the edited layer's rows with no `rafr_` row; paper to the late 2000s and some
after, and the Directorate's afli route of 2020-2023). In the paper years the towed gear holds the tow time, the time
on the bottom, the headline (77-92 % from the 1990s), the codend mesh (84-96 %), the doors and sweeps (66-69 % in the
1990s and 2000s), the bottom temperature (30-34 %), the headline-sensor and catch-sensor flags, and the seine's rope
(9-36 % from the 1980s). Lines and nets hold hooks per tub and tubs (all in the 1960s-70s, 30-44 % later), nets
(30-48 %), mesh (27-36 %) and height (21-25 % from the 1990s), nights and hours. The purse seine holds its length,
depth and set (97-100 % from the 1990s). Everything else `rafr_` has is empty before 2003.

## 3. Sensors

**Per-haul readings** (`07`, `10`; a temperature counts in -2.5 to 20 °C other than 0, a headline depth above 1):

- **Bottom temperature** (`rafr_toga.botnhiti`, `_lok`): 361 thousand bottom-trawl tows at the start (median 6.3 °C) and
  260 thousand at the end; 20,703 shrimp tows (3.6 °C) and 12,819 Nephrops tows (7.6 °C). 0.0 on 159,131 of 559,771
  values, against 19,048 on the commonest real value (7.0): a placeholder, though a true 0 °C occurs. 1,027 Nephrops
  and 770 bottom-trawl values out of range (up to 9,999).
- **Headline depth** (`hoflinu_dypi`, `_lok`; pelagic trawl): 48,799 values, of which 26,235 are 1 and 3,477 are 0;
  19,087 real (median 120). Its unit is fathoms or metres by app version (the XML map); the share of 1s was 60 % in
  2010-2014 and 50 % later (`counts/07_headline_depth.tsv`).
- **Headline temperature** (pelagic): 40,379 at the start (median 9.2 °C), 36,251 at the end.
- **Surface temperature:** Danish seine 58,559 real of 206,026 (147,032 zeros); longline 31,805 of 67,585.
- **Air temperature:** longline 21,890 real of 62,810 (40,901 zeros).
- **Sea state:** longline 119,731 values (−1 on 70,254); purse seine 8,487 (−1 on 4,203).
- **Wind** (`rafr_stofn`): direction on 99.7 % of stations, speed in m/s on 95 % (−1 on 56,223 more), Beaufort on
  23 % (to 2016).
- **Water depth** (`rafr_stofn.dypi`, `dypi_lok`): on 99 % and 90 %, the start in fathoms or metres by app, the end in
  metres (the XML map; TODO 113, `afli_depth_units`).
- **fs_afladagbok:** water depth at the start and end only (`upphaf_dypi`, `lok_dypi`), its unit by app (decision 210
  item 6). No temperature, wind or sea state.

Of 1,132,366 stations, 537,584 (47 %) hold a temperature or headline-depth reading, 263,827 only a flag that a sensor
was fitted (the catch sensor `nemi` on 707,076 tows), and 330,955 nothing; 1,130,210 hold wind.

**The continuous recording: the vessel's sensors.** AIS is one kind of vessel sensor (the maintainer, 2026-10-29). It
differs from the afli logger only in where it is stored: STK, ASTD, ASTD B or EMODnet for AIS, afli for the logger.
Each store keeps readings on (`vid`, `time`), and they differ in which quantities they carry:

- position, speed, heading and course: every store (the logger's position is faulty, `afli_coords.yml`);
- water depth under the vessel (the echosounder), a sea temperature and wind: the logger alone.

`curate/ais_ping_union.R` already treats the logger as a store: `provider = gps` beside `stk`, `astd`, `astdB` and
`emodnet`. What it takes from the logger is the quantities the AIS stores share: time, speed and heading, with a
position interpolated from the AIS track.

The logger (`07`). `rafr_sjalfvirkir_maelar` holds 23,610,639 readings, 2008-2020, of 58-270 vessels a year, each with
the `visir` of the record it was sent with. Its edited copy `sjalfvirkir_maelar` holds 28,234,223 to 2023 (the afli
route adds 2.6 M in 2021). By column, in `rafr_`:

- `botndypi`, the echosounder's depth under the vessel: 13,716,506 (58 %), median 187 m. TODO 100 found it follows GEBCO
  (median ratio 0.95-0.98) at every speed, steaming too: water depth along the whole trip.
- `skip_hradi` and `skip_stefna`, speed (m/s, median 1.8) and heading: 19.5 M.
- `vindhradi`, `vindstefna`, wind: 6.7 M.
- `botnhiti`: 1.13 M. It does not step when the gear reaches the bottom (TODO 100), so it is most likely the hull's
  sea temperature, unchecked.
- `hofudlinudypi`: 22,529, of 1-2 vessels in 2010-2013 and 2017.
- `hofudlinuhiti`: never sent.
- The position: faulty in the app (`afli_coords.yml`).
- **Dates lost:** 848,306 readings carry 1899-12-30, Oracle's zero date, with a time of day; 3,547 carry 2092-2099.

`curated/logbook/sensor_gps` (a frozen `once` fix, decision 075) holds 49,324,452 of them from both layers. It has the
logger's time, speed, heading, the depth on 29.3 M, and lon/lat interpolated from the AIS track. `ais_ping_union.R`
joins it into the track as `provider = gps` (TODO 98). The depth is in no product.

**The link to the fixes is by vessel and time, in the analysis** (the maintainer). A logger reading is keyed as an AIS
ping is, on (`vid`, `time`) and its store, not on a station. Its depth, temperature and wind belong in no AIS product.
An analyst joins them to the fixes with `join_by(vid, closest(time >= time))` within a tolerance, or the reverse: the
same kind of join that lines up the AIS stores with each other. Its `visir` says which record carried it, not which
haul it belongs to.

**TODO 98, asked, not decided here** (ask d). Seen as one store among five, the question narrows to the logger's
positions. They are faulty in the app, so today the union re-interpolates them from the AIS track on each build, with a
gap limit still to be measured (decision 196). The options:

1. keep the logger in the union as decision 196 has it, judged like any other store, and keep its other quantities in
   its own stream beside it;
2. take the logger out of the union, since it adds no measured position, so the positions are the AIS stores' (and
   VMS) alone; keep every quantity it measured, speed and heading included, in its own stream, joined by vessel and
   time.

## 4. What is assumed

- The meanings read from values (§2): panels, the second codend, the stray orientation codes, the pelagic trawl's
  largest and smallest mesh, `beitufrakast`.
- The gillnet's mean net length: no unit in afli or fs. adb says metres. The median is 54 in afli and 57 in fs.
  Decision 210 item 2 asks for a measurement first.
- The dredge's dimensions: fs says feet. The values (3 × 3 × 3) look like metres for a scallop dredge.
- That a 0.0 temperature and a headline depth of 1 or 0 are placeholders. They stand far above the neighbouring
  values, but a true 0 °C occurs.
- That the logger's `botnhiti` is the hull's temperature.
- That the edited layer's paper rows hold what the paper held, in the units of the comments. Paper-era units are not
  tested here.

## 5. The design

Four tables. Three sit beside `fishing_sample` in `curated/logbook/`, keyed on (`.sid`, `schema`) as the other logbook
tables are. They are built in staging per source and bound in `curate/logbook.R` for the stations it keeps (one schema
per station, duplicates out, decision 094). The fourth is a stream of the vessel's sensors on (`vid`, `time`,
`provider`), the AIS pings' key.

**`gear_part`**: one row per station and part of the gear (§1's line), one column per measure. Plan 020's shape, kept:

- **Parts:** `gear` (the whole: its name or make, material, panels), `net` (the body: largest and smallest mesh, the
  Danish seine's body mesh, a shrimp trawl's meshes around, the wing-belly circumference, a gillnet's mesh, height and
  length), `headline`, `footrope` (with its groundgear), `float`, `kite`, `belly`, `extension`, `liner`, `codend`,
  `codend_2`, `grid`, `square_window`, `panel`, `hook`, `hook_per_jig`, `bait`, `beam`, `dredge`, `seine`, `trap`.
- **Measures:** `n` (of the part per unit: hooks per tub, hooks per jig, panels), `length_m`, `width_m`, `height_m`,
  `height_meshes`, `circumference_m`, `weight_kg`, `area_m2`, `mesh_size_mm`, `mesh_size_min_mm`, `mesh_size_max_mm`,
  `meshes_around`, `mesh_orientation` (T0, T45, T90), `bar_spacing_mm`, `type` (the code list's code), `type_raw` (as
  the source holds it), `material`, `present`.
- **Kept with each row:** `basis`, `layer` (which table answered, plan 037), and a `flag` (`placeholder`,
  `implausible`, as `.duration_source` does) where the value is kept but not used.

**`rigging_part`**: the same columns, one row per station and part of the rigging:

- **Parts:** `rig` (`type` single, twin, triple or pair; `n` the units fished at once: trawls, dredges), `unit` (`type`
  net, tub, jig, trap, seine; `n` the units set or hauled), `hook_total` (`n`, recorded or derived), `door` (weight,
  area, type), `sweep`, `bridle`, `upper_bridle`, `backstrop`, `rope` (Danish seine), `wire`, `warp` (length, diameter,
  density), `tickler`, `chain_mat`, `clump`, `restrictor_rope`, and `partner` (the other vessel of a pair, its `vid`
  in `type`, from the notes, plan 020 §6).
- **Effort:** `fishing_sample.effort_count` becomes a read of this table: nets, tubs' hooks, jigs, traps from `unit`
  and `hook_total`, trawls and dredges from `rig` (decision 241's twin rule is the `rig` row's basis). The count is the
  same as today's, so effort does not move; step 5 checks it does not.

**`sensor_summary`**: one row per station, quantity, place, moment and instrument, long:

- **Columns:** `quantity` (`temperature`, `depth`, `wind_speed`, `wind_direction`, `wind_force`, `sea_state`,
  `bottom_type`, `fitted`), `place` (`bottom`, `headline`, `surface`, `air`, `water` for the sea's depth, `gear` for
  the gear's depth), `moment` (`1` start, `2` end, `min`, `max`, `mean`), `mount` (`vessel` or `gear`), `instrument`
  (on the vessel `sounder`, `thermometer`, `anemometer`, `observed`; on the gear `headline_sensor`, `catch_sensor`;
  `unknown`; `type_raw` the sounder type as sent), `value` (SI), `unit`, `value_raw`, `unit_raw`, `basis`, `layer`,
  `flag`.
- **A vessel sensor's summary and its stream are one sensor:** the start and end water depth of a haul are two
  readings of the sounder whose stream the logger holds. Where both exist, the stream is the summary's witness.
- **The grammar's rule holds:** water depth (`place = water`) and gear depth (`place = gear`) are different rows. A
  pelagic headline depth is gear depth. A depth whose kind the source does not say is kept as recorded with
  `place = unknown`.
- **The flags of a fitted sensor** (`hoflinum`, `nemi`) are rows with `quantity = fitted`, value 1 or 0. They say what
  was fitted, not what it read.
- **The grammar's wide `environment`** (plan 020, decision 210 item 5) is a pivot of the rows that describe the sea,
  made for the user tables, not stored twice (ask c). `station.z1`/`z2` stay where they are, the `water` depth rows
  their witnesses.

**`vessel_sensor`**: the vessel's sensor streams, one row per reading, `curated/vessel_sensor/` by provider and year
(the name and home are ask h):

- **The AIS stores and the logger as peers.** The key is the AIS pings' (`vid`, `time`, `provider`), with
  `provider = gps` for the logger as the union names it. The quantities every store shares use the pings' names:
  `lon`, `lat`, `speed`, `heading`, `cog`, with `pos_basis` and `speed_basis`. The rest are columns of their own:
  `depth_m` (`botndypi`, water depth under the vessel), `headline_depth_m`, `temperature` (`botnhiti`, place `unknown`
  until checked), `wind_speed_ms`, `wind_direction`.
- **What fills it today:** the logger, 2008-2023, both layers. An AIS store adds a column only when it records a
  quantity the pings do not carry. The AIS products stay the positions' home and are unchanged by this plan.
- **The logger's other columns:** `time_basis` (`recorded`, or `reconstructed` for the 848,306 readings whose date
  Oracle lost, if ask e dates them), `lon_raw` and `lat_raw` (its own faulty position, kept and never used as a
  position), `.sid_carrier` (the record that carried it), `layer`, `app`.
- **Built on the preprocessing side:** it reads no AIS. It supersedes `sensor_gps` as the home of the logger's
  readings, whatever TODO 98 decides for its positions (ask d).
- **The join is the analyst's:** by vessel and time (§3), as the stores are joined to each other, shown in the user
  tables' documentation and the book. A ramb helper is not proposed: dplyr's `join_by(vid, closest())` does it.

**Units.** SI as the grammar has it: metres, kilograms, square metres, mm for mesh and bar spacing, °C, m/s, degrees.

- **A conversion is recorded once,** in the data dictionary's overlay (plan 040: `dump/oracle/meta/afli.yml`,
  `fs_afladagbok.yml`, `adb.yml`), per source, column and period or app where it changes. Each carries its evidence: the
  XML schema, the same-vessel ratios of `08`, the loader's conversion found in the XML map, GEBCO for water depth.
- **A value whose unit is unknown** keeps `value_raw` and gets no SI value, basis `none`, until measured (the gillnet's
  length, the dredge's dimensions).
- **Afli's comments that the evidence contradicts** (headline, sweeps, gillnet mesh) are corrected in the overlay,
  with the evidence, not in Oracle.

**Basis and witness.** `recorded` for a value as the source holds it, a unit conversion included. `derived` for one
computed from the same record (total hooks from tubs × hooks per tub; the start-end mean). `reconstructed` for a unit
inferred per vessel. `none` where a part is known to exist but nothing measured it. A second source holding the same
value is named in `witness`: the skipper's remark for the twin rig (decision 241), the sent message for a `rafr_`
value, GEBCO for water depth. A copy is not a witness, so `rafr_` and the edited layer do not witness each other.

**Code lists** in `reference/gear/`, one per coded measure, each mapping every source's code to one list with the label
as recorded: footrope (afli's 7), codend type (7), grid (afli's 6 codes; fs's free text mapped, decision 210 item 4;
adb's `grid_no`), hook type (8, from the sent layer), bait (67), sea state (10, with wave heights), bottom type (15),
mesh orientation (T0/T45/T90, afli's 0/45/90, fs's and adb's text), sounder type (as sent, 8 spellings), rig (single,
twin, triple, pair), unit, and the seine, dredge and trap types of fs and adb. Where a source's list matches an ICES
vocabulary (§1), the vocabulary's code is a column of the list, never the key.

**How each source fills them:**

| source and years | `gear_part` | `rigging_part` | `sensor_summary` | `vessel_sensor` |
|---|---|---|---|---|
| afli e-logbook, 2003-2020 (`rafr_`; the sent layer first where the loader lost or changed a value, plan 037) | all of §2's gear columns; hook type and size and hand-baited from the sent layer | all of §2's | temperatures, headline depth, sensor flags, sea state, wind, water depth | `rafr_sjalfvirkir_maelar` |
| afli paper, 1950-2000s, and the afli route 2020-2023 (edited layer only) | headline, codend mesh; hooks per tub; gillnet mesh and height; seine length, depth, mesh | twin flag (rare), doors, sweeps, rope, tubs, nets, jigs | bottom temperature (30 %), wind, water depth, sensor flags | the edited `sjalfvirkir_maelar`, 2021-2023 |
| fs_afladagbok, 2020-2025 (`ws_*`, the tour app) | codend mesh and orientation, headline, grid (text), square window, net mesh, height and length, seine, dredge, trap type, material | twin flag, doors' weight, sweeps, rope, nets, hooks, jigs, traps, divers | water depth only, its unit by app | none |
| adb, from 2025-11-19 | as fs (adb re-serves fs) | as fs | water depth | none |

Empty in every Icelandic source, and in the tables only as parts the grammar names: warp length, diameter and density,
backstrops and bridles apart from sweeps, tickler chains, chain mats, kite, floats, clump weights, restrictor rope,
door spread, wing spread, net opening, the gear's material before 2020.

**The `g_*` columns** (`g_mesh`, `g_width`, `g_height`, `g_length`, `length_headline`, `length_fotreipi`,
`length_togle`, `length_virle`, `mesh_vod`, `n_per_unit`, `n_lost`, `rig`, `bottom_type`, `catch_nperkg`) stay on
`fishing_sample` one release beside the new tables and then go (decision 210 item 3). Two of them are wrong today and
are named in that release's notes:

- `length_fotreipi` holds afli's footrope type code (1 Rockhopper … 999 other; `reference/dictionary.R` maps
  `fotreipi` to it as a length). It becomes `gear_part` part `footrope`, `type`.
- fs's `g_width` is the sweep length in fathoms (decision 170). It becomes `rigging_part` part `sweep`, metres.

`catch_nperkg` (shrimp per kg) and `fj_fiska` (fish counted) are observations of the catch, not gear. They move to the
catch's side with plan 036's or 038's next change, not to these tables.

**What this supersedes and folds in:**

- **Plan 020:** superseded for the gear tables' design. Its `gear_part` is kept as the shape and split into gear and
  rigging; its `environment` becomes a pivot of `sensor_summary`; its fs prototype (§3) stays as a measurement of fs.
  Its §6, the notes, is unaffected. Its header points here.
- **Plan 037:** the layer order (sent, loaded, edited) is its own. This plan asks its phase 2 to parse the gear
  sections' elements the sent adapter does not read yet (doors, sweeps, codend, grid, sensors).
- **TODO 73:** plan 020's half of it moves to this plan; plan 019's half and the notes stay there.
- **TODO 98:** its question is ask d. `vessel_sensor` gives the logger's readings a home beside the AIS stores, outside
  the AIS products, whatever is decided for its positions.
- **TODO 100:** answered by this design if it is accepted: the per-haul readings are a product (`sensor_summary`), the
  logger a stream of the vessel's sensors (`vessel_sensor`). It closes with step 6's decision record.
- **TODO 131** (parked): the metier reads the rig and the selection devices from these tables when it resumes.
- **TODO 140:** the user tables' next version takes the four tables. This plan is the gear, rigging and sensor part of
  the plan that item asks for.

## 6. Steps

1. **The overlay and the code lists.** Units, codes and evidence for every column of `rafr_toga`, `rafr_lineha`,
   `rafr_hringn`, the edited copies, `ws_*` and adb's gear tables, in `dump/oracle/meta/` (plan 040). The code lists
   in `reference/gear/`. Measured first: the gillnet's length unit (decision 210 item 2), the dredge's dimensions, the
   headline depth's unit per app version (from the sent layer, which names the element).
2. **afli.** `sources/afli/convert.R` writes `staging/afli/{gear_part,rigging_part,sensor_summary}.parquet`: `rafr_` for
   the e-logbook records, the edited layer for the rest. `rafr_` keeps what the edit emptied (the Danish seine's
   surface temperature and tow time). `sources/afli_sent/convert.R` adds the sent elements the loader lost or rounded
   (the XML map): hook type and size, hand-baited, hooks per jig, the headline depth in metres as sent, the soak in
   hours and nights unrounded. Account: every column of each source table in one outcome (a part and measure, or left
   out with the reason); every station in one outcome, as `09` does.
3. **fs_afladagbok and adb.** Their adapters write the same three tables from `ws_*`, the tour app and adb's tables,
   with fs's depth unit by app (decision 210 item 6).
4. **The vessel's sensors.** `vessel_sensor` from both layers of the logger, on the preprocessing side, partitioned by
   provider and year, with the AIS pings' names for the quantities they share; the 1899 rows as ask e decides.
5. **Curated and checked.** `curate/logbook.R` binds the staged tables for the kept stations. Checks: `effort_count`
   read from `rigging_part` equals today's on every station; every placeholder and implausible value flagged and
   counted; afli's units against fs on the same vessels (`08`'s test, kept as a check).
6. **Docs, rebuild and record.** `docs/grammar.qmd` gets the gear and rigging split (§1, warp in the rigging), the
   track and underway sensors as one class of vessel sensors, and the sensor tables. ICES's codes (§1) become columns
   of the code lists where they match. `docs/data-dict.yaml` gets the tables' entries, and the user tables take them
   (TODO 140). Rebuild with fingerprints, a decision record, and TODO 100 closed. The `g_*` columns go one release
   later.

## 7. Asks

- a. **The line between gear and rigging** as §1 draws it: the net and what is fixed to it (mesh, codend, headline,
  footrope, floats, kite, grids, windows, hooks, bait) is gear; what connects the units to the vessel and to each
  other, and how many are fished at once (warp, doors, sweeps, bridles, ropes, ticklers, clumps, the rig, the count of
  nets, tubs, jigs and traps) is rigging.
- b. **Two tables of one shape** (`gear_part`, `rigging_part`), or one table with a `component` column? Proposed: two,
  so the split is visible to the user; a union is one line.
- c. **`sensor_summary` long, with `environment` a pivot made for the user tables**, in place of plan 020's stored
  `environment` (decision 210 item 5)?
- d. **TODO 98:** the logger's positions in the AIS union. Keep them as decision 196 has it, or take the logger out of
  the union, so the positions are the AIS stores' and VMS alone and the logger's readings live in `vessel_sensor`?
  Not decided here.
- e. **The logger's 848,306 readings dated 1899-12-30** (time of day kept, date lost): dated from the record that
  carried them, basis `reconstructed`, or left out with a flag?
- f. **Placeholders.** Zeros in the temperatures and 0 or 1 in the headline depth: kept raw with `flag =
  placeholder` and no SI value. This applies the rule that an extreme value is flagged, not corrected. Confirm?
- g. **The undocumented columns** (§4): who can confirm them (Trackwell, or MFRI's logbook staff), or are they used
  as read, with basis `reconstructed` for the meaning?
- h. **The vessel's sensor streams: name and home.** Proposed: `curated/vessel_sensor/`, by provider and year, the AIS
  stores and the logger as peers on the pings' key, the AIS products the positions' home. Or under
  `curated/logbook/`, as the logger's source suggests, or beside the AIS stores in `curated/ais/`?
