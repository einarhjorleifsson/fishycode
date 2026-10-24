# 224 — The place-name gazetteer, version 2: Oracle's place tables, a class per spelling, places, levels by zoom, cross-checks and synonyms

*2026-10-24. The maintainer asked for broader names at low zoom and finer ones as one zooms in, provenance and
cross-checks, spellings checked and non-names classed out, synonyms, the ornefni repo's lists, the effort map and
GEBCO; then "proceed with what we got for now", so no new Oracle dump; then: names of a festa or a sunken ship may
show in the trawl effort. Built, checked and written by Claude (AI) while the maintainer was out; not checked by a
person.*

## What was built (plan 044 §4)

- **Oracle's place tables as a source.**
  - `sources/ornefni/oracle_name.R` → `staging/ornefni/oracle_name.parquet` (4,779 rows; target `ornefni_oracle_name`). It reads
    `ops$sigfus.ornefni` (orri's names and more), `afli.afli_skikar` (MFRI's coarse grounds, mini-square by mini-square) and
    `brei_nofn`, from the dump.
  - Positions:
    - ornefni's recorded position on 236 names: degrees, minutes and seconds, or degrees and minutes for 4 digits (Grænahlíð);
      Kóparif's longitude (22410) fits neither form, so it is noted and its square used;
    - else the sub-square's centre: `geo::sr2d()`'s numbering, 1 north-west to 4 south-east, checked;
    - Breiðafjörður's names by three routes (`fj_reitir` 157, `afli_skikar`'s fjord rows 32, the area's own squares 238,
      mostly area 32, "Snæfellsnes"), the route recorded.
- **The plotter's number rule** now takes ranges ("350-450", "63-4fm"): 564 more marks are depths, not names.
- **`curate/place_name_evidence.R`:**
  - Oracle's 4,775 named rows join the evidence (507,773 occurrences, 7,013 spellings, 6,427 keys).
  - Each spelling has a class: `name` 6,146 keys, `composite` 182, `description` 99. A hyphen after Litli-, Austur- and the like is
    part of one name (84 names first classed composite).
  - Not place names, so counted in `outcome.parquet` and left out: depths (Trackwell 302 hauls, the plotter 27, others 14),
    the plotter's default labels ("Event 0261", 257), a placeholder (1).
- **`curate/place_name.R`, per key:**
  - **Precision and position.**
    - Precision: 1 for a point, line or polygon (4,333 keys), 2 for a square (1,593), 3 for an area (114); positions of the
      key's best precision only.
    - **Places** (`place.parquet`): positions cut by single linkage at 30 km; a place holds 10 % and two or more. 482 keys
      have two places or more (406 two). Two bays called Hlöðuvík had put that name inland, between them.
    - The main place has the most positions, then the most support (occurrences of any source within 30 km).
  - **Footprints** (1,314): the densest cells, or the union of a coarse ground's squares; the land (LMÍ's coast) cut out.
    Square-placed names are written on the sea part of their squares.
  - **`min_zoom` and `level`.**
    - LMÍ's display scale where the name is LMÍ's; else the footprint's size (the side of a square of its area); else 11.
      A bounding box or r80 had let one stray position make a name broad (Jökuldýpi: 2,002 km).
    - A child shows no earlier than its parent. By zoom: 27 at 5, 94 at 6, 326 at 7, 484 at 8, 893 at 9, 618 at 10,
      3,597 at 11.
  - **Parents** (355):
    - footprint 151;
    - lexical 176 (Þverálshorn in Þveráll, Péturseyjarbleyðan in Pétursey). Generic words ("Kantur") and the same name
      with its article are not parents;
    - ÍSOR's headings 28.
    - One cycle (Grunnkantur, Grunnkantur-Kópanesgr) is broken at its weakest link.
  - **Cross-check** (`outcome`): confirmed 527, disagree 270, several places 482, single 4,761, text 387. Each family's own
    spread widens the tolerance, so a broad area's sources may sit apart inside it.
  - **Synonym candidates** (`synonym.parquet`, 1,206; nothing merged):
    - spelling 332 (letters and place close; not digits-only or direction-word differences, e.g. "Gamall 31/34",
      "6 sml austari/vestari");
    - article 124 (Gígur, Gígurinn);
    - LMÍ's alternative names 146;
    - the dictionary's readings 604.
  - **Terrain word** adds `hazard` (festa, a wreck: "flakið", "skipið"; a "-flak" compound stays a bank): 27 keys.
  - Depth is taken from sea positions only.
- **The effort map** (`products/effort_map/`, app version 4):
  - names show from their minimum zoom, sized by level, with a label at each of a name's places;
  - the popup adds class, cross-check, places, minimum zoom and candidate synonyms;
  - a footprint under a clicked label keeps quiet.

Built by name (`ornefni_oracle_raw`, `ornefni_oracle_name`, `ornefni_plotter_mark`, `place_name_evidence`, `place_name`);
`tar_outdated()` is empty. The stamps say `fd.dirty` true: the work is not committed.

## Checked

- Every staged row is in one outcome, and every occurrence has a key with a row.
- In the browser at zooms 5, 7 and 9:
  - zoom 5 shows the broad bays, deeps and banks and MFRI's coarse grounds;
  - zoom 7 adds the next tier (Strandagrunn, Reykjafjarðaráll, Tungan);
  - zoom 9 shows Tungan's variants along its lane;
  - no footprint lies over land;
  - popups as described, and no console errors.
- **The festa test** (`$FISHYDATA/archive/2026-10-ornefni/scripts/06_hazards.R`, `06b`): at hazard-named marks the
  bottom-trawl effort within 450 m of the mark, against a ring 1.5-3 km out, has a median ratio of 0.60, against 0.75 at
  other named marks (45 and 445 marks in fished water; one-sided Wilcoxon p = 0.10). At 300 m and 1-2 km, 0.68 against
  0.71 (p = 0.37). The tendency is the expected one, but weak, and the marks are nearly all one plotter's. The class is
  kept, but the effort does not confirm it.

## Not done

- **Footprints from the seabed's features or the effort ridges**, and the lanes (flow side).
- **The review loop:** drafts in the data-md template's fields, corrected by a person, read back from `overrides/`.
- **The recapture cross-check through `ORRI.ORNEFNI` picks**, which waits for a dump of `fiskmerki.endurheimtur`
  (plan 043 ask f).
- **Footprint validity:** 23 footprints are valid on the plane but not on the sphere (s2), which is enough for the map.
