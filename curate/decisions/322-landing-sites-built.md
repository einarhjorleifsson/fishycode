# 322 — One table of potential landing sites: 168,351 sites by basis, the 14,929 ports a subset, OSM's small landings in

*2026-11-15. Built and measured by Claude (AI) on plan 075's step 6, at the maintainer's word ("Yes, build it", with ask l
labelled rather than ruled); no person has checked the counts. Nothing downstream of `ports_all` was rebuilt, and no table
the flow reads changed.*

## What was done

- **The names** (ask o): `reference/ports/landing_site_feature.R`, `landing_site.R` and
  `curate/checks/landing_site_accounting.R`, the targets `landing_site_feature`, `landing_site` and
  `check_landing_site_accounting`, and `curated/reference/landing_site.parquet` and `landing_site_feature.parquet`, in place
  of the port layer's (`port_feature`, `port_layer`, `check_port_accounting`). The ledger keeps its name (`port_ledger`,
  `allocate_ports()`, its key column `port_key`), since its files are never rewritten. The port layer's four files of
  decision 321 are left where they were, built no longer: the study `archive/2026-11-14-port-layer` reads them.
- **OSM's small landings** (plan 075 step 5's fetch, `raw/ports/landings_osm_20261114.gpkg`) are a list of their own,
  `osm_landing`, keyed as OSM's port tags are, `kind` holding their tags. An object that also carries a port tag is the port
  feature's duplicate.
- **Every anchor is a site, with its basis**: `reviewed` (einar), `witnessed` (evidence beyond the anchor's list, as
  built), `one list`, `structure` (a small landing alone: a slipway, pier, quay, small-craft facility or mooring) and
  `context` (a breakwater or groyne alone; ask l, answered: labelled, not ruled). A port is a site reviewed or witnessed.
  A small landing comes last and is no witness: piers stand on every shore. At a port list's site it is `joined`, a new
  outcome; otherwise it anchors a site of its own, and small landings are not grouped among themselves (ask m).
- **Displaced anchors**: a single list's anchor with a feature of another list of its name over 20 km off in its country
  is flagged `displaced`, and the cascade is run again without it, so the features that had joined it find their own
  place. Three passes: 654 displaced, then 10, then none.
- **einar's rule in Iceland and the Faroes**, set aside on 2026-11-14 (ask n) and built without on the first run of the
  day, was reinstated by the maintainer ("I think we have to reinstall the einar-one rule for Iceland and the Faroes",
  "Unless you have something new to show me"). Without it the two countries gained 123 sites: GISCO's Höfn, 148 m from
  einar's Hornafjörður (the name rule reads "Höfn, Hornafjørdur" and "Hornafjörður" as two names), three GFW dock areas of
  one anchorage each in the Faroes (Strendur 0.9 km from Tóftir, Nordskála 3.7 km from Streymnes, FRO-15 5.3 km from
  Tórshavn), 44 OSM port features (in the Faroes mostly unnamed `industrial=port` areas 1-9 km from einar's harbours), and
  75 small landings in Iceland (52 structures, 23 context; eight slipways over 2 km from an einar harbour, Selvík near
  Eyrarbakki one). Each is now flagged `home list has no site here`, kept with its row. Strendur and Norðskáli are the
  only ones that may be harbours einar lacks.
- **The numbers**: `allocate_ports()` wrote the ledger's third batch, `batch_20261115T073915.parquet`, before the rule was
  reinstated: 153,539 new numbers (15845-169383) and 7 inherited. Marina Wolin takes vmstools' Wolin's 11881, and six of
  the ten ports decision 321 dissolved come back as one-list sites with their numbers (Portsoy, Marina Zehdenick, Port de
  Compiègne, Port de Marseillan-Ville, Narva linnasadam, Port de Meyran, now under an OSM area of La Hume). The 123 sites of
  Iceland and the Faroes numbered in that batch were retired at once by the rule's return; a number is never reused, so
  they are gaps. The ledger holds 168,667 keys, 316 retired.
- **The check** tests, beyond decision 320's: each site's basis against its members' families of evidence, that a
  structure or context site is a small landing with no witness, that no small landing witnesses, that no two sites'
  areas overlap but small landings' among themselves, and that no list but einar anchors a site in Iceland or the Faroes.
  It gives ok on every row.
- **The review map** (`products/port_map/`, port 8818) shows the sites by basis: areas as drawn, the others at their
  point, small landings' lines as drawn from zoom 12, and the small landings that joined a site as a hidden layer.
- **Two faults on the way**: the distance to the coast copied a coastline line once per point and reached R's 24 GB
  (now computed once per line), and s2 rejected one small landing's ring with a repeated vertex (s2 now rebuilds such a
  geometry for the distances alone; the table keeps it as drawn).

## Measured

- **Features**: 629,081, of which 390,576 small landings: 139,880 anchor a site, 250,378 joined a port list's site (140,742
  touching its anchor, 109,533 within 1 km, 103 of its name within 5 km), 242 are OSM port features' duplicates and 76 are
  flagged (75 in Iceland, one the copy of a flagged OSM feature).
- **Sites**: 168,351: reviewed 157, witnessed 14,772, one list 13,542, structure 109,098, context 30,782. Every site has a
  number and no number is given twice.
- **Ports**: 14,929. 14,924 of decision 321's 14,925 are ports still, under the same key and number; Wolin's vmstools
  point joined OSM's Marina Wolin, which anchors the port with its number. Four more, from the cascade without the
  displaced: Red Trailer Park (GB, an OSM `harbour=boat_trailers_park` with a UN/LOCODE of its name), Berga Strand (SE),
  Port de Cassy and Port de Taussat (FR), each OSM's with vmstools' or UN/LOCODE's.
- **The small landings' sites by country** follow the fetch's whole 5-degree cells, not the ten countries asked for:
  Germany 30,318, Sweden 16,267, the Netherlands 14,137, France 12,887, Poland 10,325, Italy 9,886, Britain 8,532,
  Denmark 6,708, Norway 5,167, Austria 4,756, Hungary 2,503, Switzerland 2,348. Many lie on lakes and rivers;
  `d_coast_km` says how far, and no rule cuts them.
- **Build**: the feature table 3 min, the sites 6 min (three passes), the check 17 s, under `tar_make_isolated()`.

## Open

- The name rule's blind spot: a name with its alternative after a comma ("Höfn, Hornafjørdur") disagrees with either part
  alone. Hidden in Iceland by einar's rule; elsewhere not measured.
- Strendur and Norðskáli: harbours einar's list lacks, or not; einar's list is where one would be added.
- The port layer's four old files, left for the study's scripts: removed when the maintainer says so.
- Plan 075 step 7, the track's evidence, and step 8, the switch.
