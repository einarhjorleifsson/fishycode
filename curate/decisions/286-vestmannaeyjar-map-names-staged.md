# 286 — The Vestmannaeyjar map's names staged: a map read by eye and georeferenced, a source of the gazetteer

*2026-11-06. The maintainer: "Yes, read them", then "Yes, stage them". Read, georeferenced, staged and checked by
Claude (AI); the reading is not checked by a person.*

## The source

`raw/external/ornefni/documents/Vestmannaeyjar-Fiskimið_og_örnefni.pdf` (decision 221) is a chart, "Vestmannaeyjar,
fiskimið og örnefni", with its names only in two scanned images. `sources/ornefni/document_name.R` had left it out ("no
text: not staged").

The study `$FISHYDATA/archive/2026-11-06-vestmannaeyjar-map/` read it and placed it. Its README holds the method and
the checks.

- **The reading:** by eye from enlarged tiles of the two halves. 155 names: 113 sea names (mið, klakkar, hraun,
  flúðir, leirur, holur, rif, sund) and 27 islands and skerries. Each is at its "+" where one is drawn (97), else its
  label (40), or an island's centre (18).
- **The georeference:** the halves are tied by 7 marks drawn in both (2-3 px). One fit, affine with a north-south
  stretch, is made on 15 of LMÍ's islands. Their error when left out is a median of 87 m and at most 244 m.
- **The frame's bands are not the graticule.** The maintainer's guide, measured: the bands are equal distances of
  about 760 m. The label 63°24' agrees with the islands within about 80 m.
- **Against LMÍ's own sea areas,** 11 names: 5 inside the polygon, 5 within two of its radii, and 2 far, both placed
  by their label (Flatahraun 2.1 km, Austasta-Svið 1.5 km).
- **On land today:** five sea names lie east of Heimaey, where the island grew in the Eldfell eruption of 1973.
  That fits a chart drawn before it; the chart's age is not given.

## What was built

- **The raw input:** `raw/external/ornefni/readings/vestmannaeyjar_map_names.csv` is the reading with its positions,
  frozen from the study (md5 in `_manifest.csv`, a paragraph in `README-provenance.txt`).
  - **Why frozen:** the georeference fits one source on another (LMÍ), so it is no work for a source adapter. Made
    once, reviewed, and read as an input.
- **The reader:** `sources/ornefni/map_name.R` (target `ornefni_map_name`) writes `staging/ornefni/map_name.parquet`,
  one row per name read, source `vestmannaeyjar`, `position_basis` "reconstructed" (the map records the place; its
  lon/lat is fitted on another source), `position_kind` "point". Every row is in one outcome:
  - **staged:** 129;
  - **a control island** (16 rows, 15 islands, Álsey in both halves): left out. Its position agrees with LMÍ's by
    construction, so it is no witness for it;
  - **the same place in the map's other half** (10): a name drawn in both halves within 500 m, kept once, in the half
    with a "+". The four drawn twice farther apart (Einarsklakkur, Gvendarmið, Ólafshola, Syðri-Leira) are two
    places each.
- **The gazetteer:** `curate/place_name_evidence.R` reads it, with the two kinds of row left out counted in
  `outcome.parquet`. The source's count is `n_vestmannaeyjar`, and it is a family of its own in the cross-check.
- **The views:** the effort map's popup and the place-name explorer (`products/place_names/`) list the source. It
  has its own colour in the explorer, Dark2's yellow, as on the timarit study's map.

## The rebuild

Results follow this record's first commit.
