# 044 — The place-name gazetteer: every source's names in one table, spellings grouped, with levels and footprints

**status:** partly built — written 2026-10-24 at the maintainer's request ("once you are done with staging can you go and
proceed to curation?", plan 043 ask h), on top of plan 043's staged tables (decision 222); version 1 (§1) built the same
day (decision 223); §2 open (TODO 144) · **2026-10-24** · **see:** plan 043 §3.4, decisions 221-223,
`$FISHYDATA/archive/2026-10-ornefni/` (scripts 01-05)

Drafted with AI assistance (Claude) on 2026-10-24. The design is Claude's, from plan 043 §3.4's preliminary check, and
a person has not yet checked it. **Measured:** plan 043 §2-§3 and the staged tables (decision 222). **Assumed:**
- that a deterministic key (case, accents, spaces, hyphens and doubled letters ignored) groups spellings of one place
  and rarely joins two places;
- that a footprint's 0.05 × 0.02° cells (about 2.3 × 2.2 km), holding the densest 80 % of a name's positions, stand
  for the area a name covers well enough to find one name inside another;
- that a "?" in a plotter name stands for one Icelandic letter.

## 1. Output

`curated/place_name/`, written with `write_curated()`. Side: preprocessing, since nothing reads the AIS track.

- **`evidence.parquet`:** one row per occurrence of a name in a staged table.
  - Columns: `source`, `source_table`, `source_key`, the name as written, `key`, a representative point (`lon`,
    `lat`: a tow's midpoint, a line's middle, a polygon's point on surface), `position_basis`, `position_kind`,
    time, vessel, and gear for Trackwell's hauls.
  - Not occurrences, with each counted in an outcome:
    - the plotter's numbers;
    - placeholders ("FROM SHIP", "Ekkert valið");
    - LMÍ's land and lake names;
    - the recapture texts (their hand readings are the occurrences);
    - the fiskislóð hulls (derived from those readings);
    - the plotter's tracks (no names).
- **`variant.parquet`:** one row per spelling.
  - Columns: its key, sources, count and vessels.
  - The rule that grouped it: `key`, or `repaired` where a "?" was matched to one name that keeps its letters.
  - The hand readings beside it, as relations, never merged: the dictionaries' `reading`, the articles' synonyms.
- **`place_name.parquet`:** one row per key.
  - Name: the preferred spelling (the commonest with its letters intact).
  - Counts: occurrences by source, vessels and years.
  - Position: the median of the recorded positions, their spread (r80, km) and a footprint (the core cells as a
    polygon).
  - Seabed: GEBCO's depth, slope and position against the surroundings (BPI, about 10 km).
  - Terrain word: the class from the name's word.
  - Gear: the main gear (Trackwell's hauls through the logbook match).
  - Levels: `parent_key`, a broader name whose footprint holds 70 % of this one's positions where its spread is
    under half the broader one's (bottom trawl and plotter names with 20+ positions); or ÍSOR's own group heading.

## 2. Not in version 1

- **The lanes** (plan 043 §3.4): effort since 2023 under the tows. They read the AIS trail through the effort map, so
  they belong on the flow side, after a decision on where the effort map's grid lives.
- **The Oracle gazetteers** (`ops$sigfus.ornefni`, `afli.skikar`, `brei_nofn`): sources of the same kind, read where
  they are dumped.
- **Footprints from the seabed or the effort ridges:** version 1 draws them from the positions alone.
- **A person's read of the keys:** where the key joins two places or splits one.

## 3. Checks

- Every staged row is in one outcome: an occurrence, or not with its reason.
- Every occurrence has a key, and every key a row in `place_name`.
- The counts are rerun against plan 043 §3.4 (nesting 21 %, the spellings of Litli banki and Tungan grouped).
