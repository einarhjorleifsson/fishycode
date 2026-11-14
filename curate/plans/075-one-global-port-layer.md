# 075 — One global port layer: every list's features weighed as evidence, each port anchored once, a number that never moves

**status:** partly built — steps 1-4 built 2026-11-14 (decision 320): `port_feature`, `port_layer`, the ledger's first batch, `check_port_accounting` and the review map; step 5, the switch, waits for the maintainer. Written 2026-11-14 at the maintainer's word ("Review what has been done and propose a plan to do it
properly. Execute the plan."), with his notes of the same day: a numeric id because an acronym cannot be changed later,
einar rules the shapes in Iceland and the Faroes, and other people's local lists are known by name but weighed by measure,
since they "may have been constructed from a very narrow viewpoint" · **2026-11-14** · **see:** decisions 005, 006, 007,
068, 082, 273; plan 031 (§3.7-3.9, learned ports); `curate/corrections/ports_osm_invalid_geometry.yml`,
`ports_iceland.yml`; `docs/ports.md` (the WGSFD exchange format); TODO 92 (ports abroad as a second tier)

Drafted with AI assistance (Claude) on 2026-11-14; a person has not yet checked it. The measurements below were run by
Claude from scratch scripts on the files named; no person has checked the counts.

## 1. What exists, and where it fails

`reference/ports/ports_all.R` (target `ports_all`, preprocessing side) reads nine lists at a fixed priority (einar 1,
gisco 2, jeppe 3, maksims 4, emodnet 5, osm 6, vmstools 7, gfw 8, marta 9), mints a `pid` per feature from a UN/LOCODE
name match or an acronym, groups features whose centroids lie within 300 m or whose geometries touch (single linkage),
splits a group holding several einar harbours, and lets the best priority be the group's canonical member. It writes
`staging/ports/ports_all.gpkg` (24,653 features) and `curated/reference/port_geometry.parquet` (18,009 ports).

**Measured** (2026-11-14, on the live files of 2026-11-04 and the raw lists):

- **Not every feature is counted.** The build reads 24,653 features. The raw lists hold 192,089 with a position (GFW's
  166,497 anchorages, OSM's 5,233 features, UN/LOCODE's 11,829 coordinates, marta's 129 of 178 rows), and UN/LOCODE has
  5,767 rows with no coordinate. The 1,939 unnamed OSM features, the 87,967 GFW anchorages not at a dock and the 51 marta
  rows that the build merges by name are dropped. They are not labelled.
- **Most ports rest on one list.** 15,176 of the 18,009 groups span less than 1 m, almost all of them a single feature:
  GFW 9,857, vmstools 2,484, OSM 1,549, GISCO 698. A single list far from all others makes a port.
- **300 m is too tight for points, single linkage too loose for areas.** Across lists, the same port lies 0.3-2 km apart:
  the nearest feature of another list has the same name in 68 % of pairs within 300 m, 64 % at 0.3-1 km, 54 % at 1-2 km,
  28 % at 2-5 km, 10 % at 5-10 km and 3 % at 10-20 km. 14 groups span over 50 km and 81 over 10-50 km, chained through
  touching areas.
- **The shape is often thrown away.** 1,900 of the 18,009 ports have a point as their geometry although an area of
  another list lies in the group (GISCO 1,307, OSM points 337, vmstools 246). ramb's port flag tests `ST_Intersects`, so
  the 6,606 point ports tag no ping.
- **Lists copy each other.** All 867 EMODnet points "from GISCO" lie within 10 m of a GISCO point. 16 % of vmstools'
  points lie within 10 m of a UN/LOCODE coordinate. A copy is not a witness.
- **Lists differ in how well they place a port**, scored against the reviewed polygons:
  - Against einar (Iceland and the Faroes, 157 polygons), features within 5 km of one: GFW dock anchorages lie inside
    91 % and within 1 km 98 %; GISCO 69 / 93 %; OSM points 91 / 100 % (11 points); GFW anchorages not at a dock 0 / 36 %;
    jeppe's 15 polygons there share a median 13 % of their area with einar's, at 7.4 km² each.
  - Against jeppe (Denmark and its neighbours, 952 polygons): EMODnet 80 % inside, GISCO 68 %, GFW dock 66 %, OSM areas
    83 % (and their median area, 0.03 km², lies wholly inside jeppe's), OSM points 64 %, vmstools 35 % (61 % within
    1 km, median 427 m away).
  - Shape: a GFW dock area (500 m around each dock anchorage, unioned by label and split into connected pieces: 78,530
    anchorages, 12,831 labels, 20,039 pieces) overlaps the einar polygon it touches most with a median IoU of 0.21, jeppe
    0.13. GFW against jeppe 0.28.
  - maksims' 67 "polygons" are circles of 1-12 km radius by a size class, 51-83 km² in the median. They are not drawn.
- **Displaced points exist in more than one list.** A feature with no feature of another list within 5 km: vmstools 844
  of 3,839, OSM 1,638 of 5,233, GISCO 71 of 2,440, marta 26 of 129, jeppe 5 of 952, einar 49 of 157 (small harbours no
  other list holds). Falconara Marittima (vmstools, 13.40 E 38.62 N, at sea north of Sicily) is one: it made the port
  `IT-FAC`. Name matching alone gives false witnesses across countries (a Sarti in Greece and one 10,000 km away), so a
  name witness must be in the same country and near.
- **The coastline cannot judge a port.** Against Natural Earth's 10 m land, 3 einar harbours lie over 5 km "at sea"
  (islands it lacks). GISCO holds 240 points and OSM 1,147 features over 30 km inland: river and lake ports. The
  coastline is a column, not a test.
- **What reads the pids.** The 157 einar pids are in the landings, the logbook trips, `port_call` (152), `stk_hid_pid`,
  `port_radius` (frozen), the WGSFD export of 2026-10-06 and the release 2026.10.31.1 (`reference/port.parquet`, the
  trips' `pid1`/`pid2`). 292 other pids are on 691,341 pings of `curated/ais/ping` (Norway, Turkey, the Faroes' non-einar
  places), 0.24 % of the pings with a pid. The effort and bathymetry maps read `port_geometry.parquet` whole.

## 2. The proposal

### 2.1 Every feature, one row (target `port_feature`)

`reference/ports/port_feature.R` reads every list and writes `staging/ports/port_feature.parquet`: one row per raw
feature, with nothing dropped. Its columns are `source`, `fid` (the list's own key: einar's `pid_bootstrap`, OSM's type and
id, GFW's `s2id`, GISCO's code, and so on), `name`, `name_key`, `iso_src` (the list's own country), `iso_geo` (where it
lies), `locode`, `kind` (the list's own type: OSM's `harbour`, GFW's dock flag and label source, UN/LOCODE's status),
`gtype` (area, line or point), `geom` (as drawn, repaired only where GEOS finds it invalid, flagged `repaired`), a
representative point, its area, and the distance to Natural Earth's coast. GFW's dock anchorages are also bound into
areas (500 m true ground, unioned by label, split into connected pieces), each a feature of its own (`gfw_dock`). Its key
is the smallest `s2id` among its anchorages, so a GFW refresh keeps it.

### 2.2 The cascade (target `port_layer`)

`reference/ports/port_layer.R` places every feature in one outcome, in rank order:

1. **Ranks.** Each list's rank comes from §1's measurements, areas before points. The proposed ranks are einar (reviewed,
   and it rules Iceland and the Faroes: the maintainer), jeppe, GFW dock areas, OSM areas, GISCO, OSM points and lines,
   maksims (the circle's centre), vmstools, EMODnet (its own points only), and marta. UN/LOCODE and GFW's anchorages not
   at a dock are witnesses only.
2. **Join or anchor.** In rank order, a feature joins the nearest port anchor if it touches the anchor, lies within
   `R_near` = 1 km with no name disagreeing, or lies within `R_name` = 5 km with the same name. Otherwise it anchors a
   new port. It joins anchors only, never a witness, so nothing chains. A feature joins an anchor of its own list only by
   the same name (OSM's parts excepted): two einar harbours never merge. In Iceland and the Faroes a feature that joins
   no einar harbour is flagged `home list has no port here`.
3. **A port needs a witness.** A port whose members come from one list is dissolved and its features flagged
   `unwitnessed`, unless its anchor is reviewed (einar). What else counts as a witness is ask a.
4. **One geometry per port.** The anchor's, as drawn (area or point), with `geom_basis` naming its list and key. Anchors'
   areas never overlap, because a touching feature joins. The port's name follows the same cascade: einar's, else the
   first named member by rank.
5. **Outcomes.** Every feature ends `chosen` (the anchor), `witness` (another list), `duplicate` (the anchor's own list,
   or a copy within 10 m, or EMODnet from GISCO) or `flagged` with its reason (`unwitnessed`, `displaced` (unwitnessed,
   and a feature of another list with its name lies over 20 km off in the same country), `home list has no port here`,
   `no position`, `not a dock`). A disagreeing feature keeps its position; it is never moved.

It writes `curated/reference/port_layer.parquet` (one row per port: its number, its acronym where it has one, name,
country, geometry, `geom_basis`, `basis` (`reviewed` or `witnessed`), the lists that agree and how many features) and
`curated/reference/port_feature.parquet` (every feature with its outcome, reason and port), both by `write_curated()`.

### 2.3 A number that never moves (asks b and c, answered)

`pid` becomes an integer (the maintainer, 2026-11-14). An Icelandic harbour's pid is its landing code as given (`hid`,
Fiskistofa's `stad_nr`): the 90 einar harbours with a code keep it (codes in use reach 293). 1-999 is reserved for
Iceland's codes, so a code Fiskistofa adds later never collides. Every other port is numbered from 1000 up, in this order:
the 39 Icelandic einar harbours with no code and the 28 Faroese (1000-1066), then the rest by country and name. A number
carries no meaning beyond that.

A number is allocated once in a ledger, as the vid ledger does (`R/allocate_vids.R`):
`curated/reference/port_ledger/batch_*.parquet`, append-only, extended by hand by `allocate_ports()`. A port is known to the
ledger by its anchor's key (`einar:IS-REY`, `gfw_dock:<s2id>`, `gisco:NLRTM`). When a later build anchors the same port
on another feature (a list refreshed, a better list added), the port inherits the number if exactly one of its members'
keys holds a number no current port holds. A number is never reused, and a port that dissolves keeps its row, marked
retired. The acronym stays beside it as `pid_acronym`: einar's pinned one (decision 082), and for other ports the one the
current build gave their anchor's group, as an alias only, where the group maps to one port.

**Iceland's codes across the schemas** (measured 2026-11-14, at the maintainer's word "check though first for
inconsistencies across different schemas"). Eight lists hold them: `kvoti.stadur` (161), `afli.stadur` and
`fs_afli.stadur` (96 each), `afli.rafr_stofn_hofn` (91), `ask.londunarstadir` (140), `adb.port` (72), `channel.port`
(129, with positions) and `dw.dw_hafnir` (158). They disagree on a few codes:
- **76**: Ögurvík in `kvoti`, `channel` and `dw`; Veiðileysa in `afli.stadur` and `fs_afli.stadur`. Einar gives 76 to
  Ögurvík. The `afli` logbook uses it in 125 trips; the 10 linked to a landing landed at Suðureyri (67). Unresolved.
- **102 and 103**: `afli.stadur` reads 102 Árskógssandur and 103 Árskógsströnd; `channel` 103 "Árskógaströnd / Hauganes";
  the landings (`ask`) 103 Árskógssandur and no 102. Linked to their landings, the `afli` logbook's 103 trips land at
  Árskógssandur (6,274 of 6,712 with five or more) and so do its 102 trips (482 of 611). So 103 is Árskógssandur in both
  systems and 102 is `afli`'s other code for it. Hauganes is 104 everywhere.
- **20 and 21**: Helguvík and Keflavík in every list, but `adb.port` gives Helguvík port_no 21 too. No landing uses 20.
- **0**: "port missing" everywhere, Skarðsstöð (291 elsewhere) in `adb.port` (handled in `sources/adb/convert.R`).
- **34 and 140**: Miðsandur and Grundartangi in einar. `ask` reads 34 as Hvalfjörður, and `adb` 140 as Hvalfjörður.
- **36/153** (Hvalseyjar) and **82/200** (Gjögur) are one place under two codes.
- `kvoti.ivln_hafnir_jafngilding` declares 11 ≡ 13, 79 ≡ 81 and 137 ≡ 139 (neighbouring ports counted as one), a
  grouping, not a conflict.

The codes einar carries are kept as they are; 102, 153 and 200 stay codes without a pid, as `port_code_class.yml` has
them. Which harbour 76 is, and whether 102 and 200 take their place's pid, are the maintainer's.

### 2.4 The check (target `check_port_accounting`)

`curate/checks/port_accounting.R` writes `curated/check/port_accounting.parquet`, one row per list and outcome with
counts, and stops unless:
- every raw row is in exactly one outcome;
- every port has exactly one `chosen` feature;
- no two ports' areas overlap;
- every einar pin is a port, with its own polygon.

### 2.5 The review map

`products/port_map/`, `port_map()`, on rebelrebel (`rr_` functions, served on 127.0.0.1, not bundled). It shows the ports
by basis, the witnesses, and the flagged features with their reasons, each feature's popup naming its list, key, outcome
and port. It is internal, as the other served maps are.

### 2.6 What the layer does not do

- No AIS. GFW's anchorages are a list built by GFW from AIS, read as delivered. Our own track stays out of preprocessing
  (plan 014), and learned ports (plan 031 §4.3) are the flow's.
- No radius. A point port stays a point; a reader that tags pings chooses its own buffer (ask f).
- No correction of a list. A displaced point is flagged in place, and the clear vmstools cases are written up for its
  maintainers in `curate/issues/vmstools.yml`, not sent.

## 3. Steps

1. `port_feature`: every feature, one row (§2.1).
2. `port_layer` with the witness rule of ask a (§2.2), and `port_accounting` (§2.4).
3. The ledger's first batch, at the maintainer's answers to asks b and c (§2.3).
4. The review map (§2.5) and `curate/issues/vmstools.yml`.
5. The switch, at the maintainer's word (ask g): `shapes.R`, `harbour_codes.R`, `port_call.R`, `sources/stk/event.R`,
   `stk_hid_pid.R`, `products/exports/wgsfd_harbours.R`, the maps and the frozen `port_radius` read the layer and its
   number, `ports_all` retires, and the descendants are rebuilt.

## 4. Measured on a prototype (2026-11-14, scratch)

The cascade of §2.2, run on the 33,802 port-making features (GFW dock pieces in place of anchorages):

| witnesses beyond a second list | ports | unwitnessed anchors |
|---|---|---|
| none | 3,574 | GFW 10,072, OSM 2,654, vmstools 1,995, GISCO 552, marta 86, jeppe 49, EMODnet 35, maksims 5 |
| UN/LOCODE by name within 5 km | 5,258 | GFW 9,291, OSM 2,601, vmstools 1,503, GISCO 232, marta 67, jeppe 47 |
| that, and GFW's label beside its own AIS stops | 14,549 | OSM 2,601, vmstools 1,503, GISCO 232, marta 67, jeppe 47 |

Held out as truth, with every other list run through the cascade (R_near 1 km, a disagreeing name blocks a join):
- einar: of 69 harbours that other lists' features fall in, 2 are split and 17 are merged into 7 ports. GFW's dock areas
  span close neighbours (Reykjavík and Kópavogur, Njarðvík and Keflavík).
- jeppe: of 151, 8 split and 30 merged into 13.

`R_near` between 300 m and 1 km changes these by at most 5. At 2 km merges rise to 42 of 160 unless a disagreeing name
blocks the join. Falconara Marittima's vmstools point ends `unwitnessed`; GISCO's Falconara joins Ancona's port.

The build (decision 320) differs from the prototype in three ways: GFW's anchorages away from a dock witness a port within
1 km, two touching areas of one list join, and a copy follows its original. It makes 14,398 ports.

**Assumed:**
- that a list's agreement with the reviewed polygons in Iceland, the Faroes and Denmark holds for its features elsewhere;
- that a GFW dock anchorage marks a berth (GFW's own definition, not checked here);
- that the name rule (Jaro-Winkler ≥ 0.9 or one name the start of the other, after common harbour words are stripped)
  separates ports well enough, and the 1 km rule where names are absent.

## 5. Asks (the maintainer's)

a. **What makes a port.** A second list, as today's measure says (3,574 ports); also a UN/LOCODE name match (5,258); also
   GFW's dock area on its own, its AIS stops and its named label being two lines of evidence (14,549). **Answered
   2026-11-14: the third.** Unwitnessed features stay in `port_feature`, flagged and visible.
b. **The number's name.** **Answered: `pid` becomes the integer**, the acronym kept as `pid_acronym`; Iceland's harbours
   take their landing code as given, after a check across the schemas (§2.3).
c. **Numbering.** **Answered: plain integers, einar first; Iceland's codes as given within 1-999, every other port from
   1000 up** (§2.3).
d. **The local lists' provenance.** `jeppe` is DTU Aqua's harbour polygons from WKSSFGEO 2021 (`havnepolygoner3`;
   WKSSFGEO's `data/harbours.rds` is the same 942 polygons without names). `maksims` (67 circles with a size class) and
   `marta` (178 Portuguese landing sites, `landings_portos_Einer.xlsx`) have no record of who made them, when, or on what
   terms. **Answered: the maintainer supplies it later**; they are built as they are, ranked by measure. Local lists are
   of different quality, "constructed from a very narrow viewpoint, built ad hoc" (the maintainer), so only einar is
   granted its rank.
h. **Iceland's disputed codes** (§2.3): which harbour 76 is, and whether 102 (Árskógssandur in `afli`) and 200 (Gjögur)
   take their place's pid.
i. **Local small-scale lists alone.** Whether a local list of small-scale landing sites (marta: 65 of its 123 placed sites
   flagged, AIS cannot see beach landings) may make a port without a second list, as einar does.
j. **A wider OSM fetch.** `dump/ports/osm.R` reads only `harbour=*`; `landuse=harbour`, `industrial=port`,
   `seamark:type=harbour` and `leisure=marina` hold most of OSM's port areas.
e. **The ranks.** As in §2.2.1, from the measurements: einar rules Iceland and the Faroes, every other list by its
   measured agreement, maksims' circles read as points.
f. **Point ports in the flow.** At the switch, should `shapes.R` buffer point ports for the ping tag? Plan 031 found
   1-2 km best for a point list. Today they tag nothing.
g. **The switch and its rebuild** (step 5): when, and whether the 292 foreign pids on the pings may change with it.
