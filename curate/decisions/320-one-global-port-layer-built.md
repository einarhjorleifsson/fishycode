# 320 — One global port layer built beside `ports_all`: every list's feature in one outcome, 14,398 ports, a number for each

*2026-11-14. Built by Claude (AI) at the maintainer's word ("Review what has been done and propose a plan to do it
properly. Execute the plan.") and his answers to plan 075's asks a, b, c and d the same day; no person has checked the
counts. The plan is `curate/plans/075-one-global-port-layer.md`; the study behind it is
`$FISHYDATA/archive/2026-11-14-port-layer/` (its README lists the scripts). Nothing downstream of `ports_all` was rebuilt,
and no table the flow reads changed.*

## What was chosen (the maintainer, 2026-11-14)

- **One layer, the same way as all the data flow**: preprocessing targets, `write_curated()` stamps, a check that counts.
- **A port needs evidence beyond one list** (ask a): a second list, a UN/LOCODE location of its name or code, or, for a GFW
  dock area, GFW's named label beside its AIS stops. A feature that makes no port stays, flagged.
- **einar rules the shapes in Iceland and the Faroes.** Other people's local lists are named and weighed by measure,
  since they "may have been constructed from a very narrow viewpoint, build ad-hoc on the fly without any strategy".
- **`pid` becomes an integer** (ask b): "the current standard acronym we have been cooking up can not be changed at a
  later date". An Icelandic harbour's pid is its landing code as given; 1-999 is kept for those codes and every other port
  is numbered from 1000 up, einar's first (ask c). The acronym stays beside it as `pid_acronym`.
- The provenance of `maksims` and `marta` comes later from the maintainer (ask d); they are built as they are.

## What was built

| target | script | output |
|---|---|---|
| `port_lists_raw` | | the nine raw lists and UN/LOCODE, declared |
| `port_feature` | `reference/ports/port_feature.R` | `staging/ports/port_feature.gpkg`: 217,944 rows, every raw row of every list (197,905) and 20,039 GFW dock areas |
| `port_ledger` | `R/allocate_ports.R` (by hand) | `curated/reference/port_ledger/batch_20261114T120247.parquet`, the first batch |
| `port_layer` | `reference/ports/port_layer.R` | `curated/reference/port_layer.parquet` (14,398 ports) and `port_feature.parquet` (every feature, its outcome and reason) |
| `check_port_accounting` | `curate/checks/port_accounting.R` | `curated/check/port_accounting.parquet`, verdict ok |

The review map is `products/port_map/` (`port_map()`, or `Rscript products/port_map/server.R`, port 8818), on rebelrebel.

## Measured

- **The ports:** 14,398, of which 157 are `reviewed` (einar) and 14,241 `witnessed`; 13,438 are areas and 960 points. They
  are anchored by GFW dock areas 12,355, jeppe 857, GISCO 577, vmstools 237, OSM 172, einar 157, EMODnet's own points 23,
  marta 19 and maksims 1. The old build made 18,009, 15,176 of them from one list alone.
- **Every feature, one outcome** (`check_port_accounting`):

  | list | features | chosen | witness | duplicate | flagged |
  |---|---|---|---|---|---|
  | einar | 157 | 157 | 0 | 0 | 0 |
  | jeppe | 952 | 857 | 15 | 33 | 47 |
  | GFW dock areas (derived) | 20,039 | 12,355 | 1,200 | 6,481 | 3 |
  | GFW anchorages | 166,497 | 53,065 | 5,949 | 27,666 | 79,817 |
  | OSM | 5,233 | 172 | 2,241 | 23 | 2,797 |
  | GISCO | 2,440 | 577 | 1,785 | 2 | 76 |
  | EMODnet | 946 | 23 | 43 | 861 | 19 |
  | vmstools | 3,839 | 237 | 1,775 | 10 | 1,817 |
  | maksims | 67 | 1 | 62 | 0 | 4 |
  | marta | 178 | 19 | 40 | 0 | 119 |
  | UN/LOCODE | 17,596 | 0 | 4,014 | 0 | 13,582 |

  A GFW anchorage takes its dock area's outcome; 79,817 anchorages away from a dock lie within 1 km of no port. Of
  UN/LOCODE's flagged rows, 5,767 have no position. 170 vmstools points are `displaced`
  (`curate/corrections/ports_list_displaced.yml`); Falconara Marittima, GENOVA, CATTOLICA, POZZALLO, Castletown, Kallviken
  and Charlestown among them, all ports in the old build.
- **No two ports' areas overlap**, every einar harbour is a port of its own, and its pinned acronym is its `pid_acronym`.
- **The numbers:** 90 Icelandic harbours keep their landing code (1-293), einar's 67 harbours without one get 1000-1066
  (Iceland first, then the Faroes), and the other 14,241 ports 1067-15307. 12,124 ports carry the old build's acronym as
  an alias. Of the 292 old non-einar pids on 691,341 pings of `curated/ais/ping`, 261 (629,609 pings) are an alias of a
  new port.
- **Iceland's codes across eight Oracle lists** (plan 075 §2.3): one number names two places in a few cases. 76 is Ögurvík
  in `kvoti.stadur`, `channel` and `dw`, and Veiðileysa in `afli.stadur` and `fs_afli.stadur` (125 `afli` logbook trips;
  the 10 linked to a landing landed at Suðureyri). The `afli` logbook's 102 and 103 both land at Árskógssandur (103 in
  the landings), and `adb.port` gives Helguvík 21 and Skarðsstöð 0. The codes einar carries were kept as they are.
- **EMODnet against the local lists**, each scored against GFW's dock anchorages: 867 of EMODnet's 946 points are GISCO's.
  In Denmark, where it has a point, it is as well placed as DTU Aqua's polygons (86 and 88 % within 1 km of an AIS dock),
  but it covers a third: 27 % of jeppe's 182 Danish landing places have an EMODnet point within 1 km. In Portugal all 22 of
  its points lie at an AIS dock and 31 % of marta's 123 sites do. marta's file marks small-scale landing sites, which AIS
  does not see, so the rule flags 65 of them.

## Found on the way

- `write_curated()` writes under `curated/` only, so the staged feature table is a GeoPackage, whose `fid` is reserved:
  the list's own key is `feature_key`.
- In the cascade, two areas of one list that touch must join, or both anchor and overlap (GFW labels whose dock areas
  touch). Only two einar harbours never merge.
- rebelrebel 2026.11.12.2 passes an sf layer to DuckDB as WKT written at R's `digits` (7 significant digits). Close
  vertices of GFW's 500 m circles collapse, the ring turns invalid, and the tiler stops with a TopologyException (Cannes,
  7.058 E 43.518 N). `port_map_build()` sets `digits` to 15 while it builds; the fix belongs in rebelrebel. Its
  `rr_map(data)` also keeps only the title, `choose` and `sections` until the first layer, and drops `basemaps` and
  `view` without a word; `port_map_build()` sets them on the built map. The map opens on OpenStreetMap's tiles, with no
  EMODnet base map, and a port's hover shows its name alone (the maintainer, 2026-11-14).
- `dump/ports/osm.R` fetched only the `harbour=*` key. OSM's port areas are mostly `landuse=harbour`, `industrial=port`,
  `seamark:type=harbour` and `leisure=marina`, none of them read. It costs a port the maintainer pointed to: Numana, CS1's
  third harbour and its HDBSCAN site 4 (13.626 E 43.509 N), is no port in the layer. Within 4 km lie only UN/LOCODE's
  ITNUM and vmstools' NUMANA, 1.05 km off, on one coordinate (vmstools copied UN/LOCODE's), so one witness: both flagged.
  GFW has no anchorage there, GISCO no point. OSM has the harbour (Overpass, 2026-11-14): a `leisure=marina` node "Porto
  di Numana" (also `seamark:type=harbour`) and a `landuse=harbour` relation "Porto Turistico di Numana", neither with a
  `harbour=*` key. Worldwide (taginfo, 2026-11-14) OSM holds 5,429 `harbour=*` features, and 31,961 `leisure=marina`,
  25,382 `seamark:type=harbour`, 5,414 `industrial=port` and 2,570 `landuse=harbour`, overlapping.
- One GFW anchorage (POINTE NOIRE, s2id 8efe7543) lies at longitude 1001. `port_feature.R` now keeps such a position as
  given with `has_pos` FALSE and `pos_out_of_range` TRUE, and the layer flags it "position out of range"; the ports did not
  change (rebuilt and fingerprinted, 2026-11-14).

## Open

- The switch (plan 075 step 5, ask g): `shapes.R`, `harbour_codes.R`, `port_call.R`, `sources/stk/event.R`, `stk_hid_pid.R`,
  `products/exports/wgsfd_harbours.R`, the maps and the frozen `port_radius` read the layer and the integer pid;
  `ports_all` retires; the descendants are rebuilt. At the maintainer's word only.
- Asks d (the local lists' provenance), e (the ranks), f (point ports in the ping tag), h (Iceland's disputed codes), and
  whether a local small-scale list (marta) may make a port alone, and a wider OSM fetch.
