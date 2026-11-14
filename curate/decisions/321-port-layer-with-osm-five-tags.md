# 321 — The port layer rebuilt with OSM's five port tags: 14,925 ports, Numana a port, a second batch of numbers

*2026-11-14, evening. Built and measured by Claude (AI) on plan 075's ask j, which the maintainer answered the same day
("five tags, Greenland to the Mediterranean"); no person has checked the counts. The study behind it is
`$FISHYDATA/archive/2026-11-14-port-layer/` (`scripts/osm_tests.sh`, `scripts/osm_widened.R`, `scripts/osm_compare.R`;
the baselines `out/*_before_osm.*`). Nothing downstream of `ports_all` was rebuilt, and no table the flow reads changed.*

## What was done

- **The fetch.** `dump/ports/osm.R` asked Overpass for OSM's five port tags (`harbour=*`, `landuse=harbour`,
  `leisure=marina`, `industrial=port`, `seamark:type=harbour`) over Greenland, Iceland, the Faroes, Europe and the
  Mediterranean and Black Seas, in 288 tiles of 5 degrees, one at a time with a random pause: 23,550 features in
  `raw/ports/ports_osm_20261114.gpkg`, every answer kept under `raw/ports/osm_20261114/`. Two faults fixed on the way: a
  tile in two regions was fetched once under one name and dropped from the other (now a region-suffixed name), and
  `osmdata_sf()` fails on a tile whose nodes carry no tag (now GDAL's OSM driver reads it).
- **The build.** `port_feature.R` reads both OSM files, one row per OSM object, the newer fetch's where both hold it
  (`kind` says which). `port_lists_raw`, `port_feature`, `port_layer` and `check_port_accounting` rebuilt with
  `tar_make_isolated()`; the check gives ok on every row.
- **The numbers.** `allocate_ports()` wrote the ledger's second batch, `batch_20261114T193217.parquet`: 537 new numbers
  (15308-15844) and 186 inherited (a port re-anchored keeps its number), and `port_layer` was rebuilt on it. Every port has
  a number and no number is given twice. The ledger holds 15,121 keys.

## Measured

- **Features:** 238,505 (217,944 before). OSM's: 25,794, 23,550 from the new fetch and 2,244 from 2026-09's alone; 843
  anchor a port (172 before), 9,098 witness one, 257 are duplicates and 15,596 are flagged.
- **Ports:** 14,925 (14,398 before), 157 reviewed and 14,768 witnessed; 13,888 areas and 1,037 points. Anchors: GFW dock
  areas 12,355, jeppe 872, OSM 843, GISCO 459, vmstools 199, einar 157, EMODnet 22, marta 17, maksims 1. 14,202 ports
  keep their key; 723 are new keys (OSM 705, jeppe 15, vmstools 2, GISCO 1). 186 of them are old ports re-anchored, which
  inherit their number: 95 from another list's point to an OSM area, 66 to an OSM point, 25 from one OSM feature to
  another. The other 537 are new ports with new numbers; Estonia has 101 of them, Sweden 81, Denmark 60, France 42,
  Germany 36. A re-anchored port takes its anchor's name, so some now carry a marina's or a sailing club's name (GISCO's
  Demmin is "Demminer Segelclub Blau-Weiß").
- **Ten ports dissolved**: their anchor is flagged `unwitnessed`, or joined an OSM-anchored port that is unwitnessed
  (Porto Turistico Palau, Portsoy, Marina Zehdenick, Port de Compiègne, Port de Marseillan-Ville, Cala Mangiavolpe, Narva
  linnasadam, Port de Meyran, SAVELLETRI DI FASANO, and one OSM area with no name). Their numbers are retired, not lost:
  the ledger keeps their keys, so a site that comes back under the same anchor (plan 075 step 6) takes its old number.
- **Numana** (decision 320's case) is a port: OSM's `leisure=marina` node "Porto di Numana" anchors it, and UN/LOCODE's
  ITNUM and vmstools' NUMANA witness it by name within 5 km. **EM4SSF's CS1** is now covered in full: its three harbours
  and four HDBSCAN sites, Numana and site 4 within 1 km of the port.
- **marta's Portuguese sites** (129 placed): not covered 62 → 58. Six sites go from not covered, or covered only by a
  witness, to a port of marta and OSM (Cais do Bico, Ericeira, Olhão twice, Santa Cruz twice); Torreira now lies within 1 km
  of a port that stands without marta (Marina da Torreira, with UN/LOCODE).
- **Hold-outs** (the layer built without the list, against the list):
  - einar, Iceland: Miðsandur gains a port of its own and Litli sandur a port within 1 km; the Faroes unchanged.
  - jeppe, Denmark: not covered 12 → 7 (Ringkøbing, Snogebæk, Årsdale, Stige, Bregnør gain a port of their own). Five
    harbours now touch two ports where OSM draws two harbours in or beside one of jeppe's polygons (Åbenrå with Ensted
    Havn, Gråsten and Egernsund, Nykøbing Mors with Ørodde, Sletten with Humlebæk); not judged.

## Open

- The ten dissolved ports, and whether a port should lose its anchor to an unwitnessed neighbour of the same list, go
  into step 6, where every anchor becomes a site with its basis.
- The five Danish splits: one harbour or two, for the maintainer at the review map.
- OSM's small landings (plan 075 §2.1, step 5) are being fetched into `raw/ports/landings_osm_20261114/`, in the port
  fetch's plain way; they enter the build at step 6.
