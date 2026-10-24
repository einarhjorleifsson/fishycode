# 044 — The place-name gazetteer: every source's names in one table, spellings grouped, with levels and footprints

**status:** partly built — written 2026-10-24 at the maintainer's request ("once you are done with staging can you go and
proceed to curation?", plan 043 ask h), on top of plan 043's staged tables (decision 222); version 1 (§1) built the same
day (decision 223), version 2 (§4) the same afternoon (decision 224), with the tagging databases and channel (§5,
decision 225) and uv (§6, decision 226); the seabed and effort footprints, the lanes and the review loop carried by
plan 045 (TODO 144) · **2026-10-24** · **see:** plan 043 §3.4, plan 045, decisions 221-226,
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

## 4. Version 2 (built 2026-10-24, decision 224): levels for zoom, classes, synonyms, cross-checks, from what is at hand

The maintainer, 2026-10-24: broader names at low zoom and finer ones as one zooms in; provenance and cross-checks in
the processing; spellings checked, entries that are not place names classed out, synonyms thought of; the ornefni
repo's own lists as placeholders; the effort map and GEBCO; and "proceed with what we got for now", so no new Oracle
dump. Measured the same day (Claude's, read-only):
- LMÍ's sea names carry a size class (Stórt 22, Mið 1,023, Lítið 730) and a display scale (10-2,000).
- `ops$sigfus.ornefni` has a recorded position on 238 of 2,881 names and a sub-square on 2,359, and comes with a coarse
  ladder: coast region (`landsvaedi`, 7 codes), sea area (`hafsvaedi`, 1-9), square, sub-square.
- `afli.afli_skikar` gives MFRI's coarse grounds (`heiti`, 1,470 squares), and `brei_nofn` with `ops$sigfus.fj_reitir`
  places 428 Breiðafjörður names.
- A rough class over Trackwell's and the plotter's spellings: 2,674 single names (470,359 uses), 197 composites, 108
  descriptions (a distance or bearing), 53 depths or numbers ("63-4fm"), 6 plotter defaults ("Event 0261").
- The tag app writes `NAFN-HEITI` from `ORRI.ORNEFNI` into a recapture (kb-hafro-kerfi), but the 2022 extract holds 1
  such pick: the cross-check through recaptures waits for a dump of `fiskmerki.endurheimtur` (plan 043 ask f).

**Assumed:**
- that a sub-square's parts and a mini-square's (`orreitur`) are numbered alike (from `geo::sr2d()`: 1 north-west,
  2 north-east, 3 south-west, 4 south-east), checked on the parts alone;
- that a name's extent sets the zoom at which it can first be read.

**Proposed.** The square tables give the coarse areas their footprints, a spelling gets a class, a key gets a level, a
minimum zoom and an outcome, and spellings close in letters and in place become candidate synonyms, never merged:
1. **Oracle's place tables as a source.**
   - What: `sources/ornefni/oracle_name.R` → `staging/ornefni/oracle_name.parquet`. It takes `ops$sigfus.ornefni` (orri's
     names and 307 more), `afli.afli_skikar` and `brei_nofn`, read where the dump put them.
   - Positions: recorded where given (degrees, minutes, seconds); else the sub-square's or mini-square's centre, basis
     `derived`, kind `square`.
2. **A class per spelling.**
   - The classes: `name`, `composite` (two names, or a name and a qualifier), `description` (a distance or a bearing), `depth`
     (a number, with or without a unit or range), `default` (a plotter's own label), `placeholder`.
   - Depths, defaults and placeholders are not occurrences.
   - The plotter's number rule is widened to depth ranges.
3. **Levels and a minimum zoom per key.**
   - The extent: the larger of the positions' r80 and half the footprint's diagonal.
   - LMÍ's size class and display scale, where the name is LMÍ's, take precedence.
   - The coarse grounds of `afli_skikar` and LMÍ's Stórt sit at the top.
   - A child shows no earlier than its parent.
4. **Lexical parents.** A composite whose key holds a well-used key (`Tungan Reykjafj.áll` holds `reykjafjardaral`) records
   it beside the footprint parent.
5. **Candidate synonyms.**
   - What qualifies: two keys within an edit distance of 2 (3 for long keys) whose positions overlap (a shared footprint
     cell, or medians within 10 km).
   - Explicit relations, beside them: LMÍ's `tvinefni`, the articles' synonyms, the dictionary readings.
   - Output: `curated/place_name/synonym.parquet`, every candidate with its evidence, for a person's read; nothing is
     merged.
6. **A cross-check per key.**
   - The independent source families that support it (Trackwell, plotter, LMÍ, Oracle, sjókort, recaptures, articles,
     documents).
   - Whether their medians agree (within the larger of 5 km and the key's r80).
   - The outcome: `confirmed` (two or more families agree), `single`, or `disagree`.
7. **The map.**
   - Names appear from their minimum zoom, sized by level.
   - The popup adds the class, the outcome and the candidate synonyms.

**Not in version 2:**
- footprints drawn from the seabed or the effort ridges, and the lanes (flow side);
- the review loop: drafts in the `data-md` template's fields, corrected by a person and read back from `overrides/`;
- any new dump.

## 5. The tagging databases and channel (built 2026-10-24, decision 225)

The maintainer had `merki` and `fiskmerki` dumped (plan 043 ask f) and pointed to `channel`'s fishing areas; then: a
noun has four endings in the singular, and the ornefni repo's files may now be repeated. **Measured** (decision 225):
the recaptures' positions are DDMM.mm points; `merki`'s place fields repeat `fiskmerki`'s; 1,794 recaptures carry an
orri name at orri's position; 1,330 channel samples are Trackwell hauls again. **Assumed:** that a name after "á" or
"í" lies where the fish was caught, and one after a word of relation (af, við, undan …) does not. **Built:**
1. `channel_name`, `tag_recapture`, `tag_release` staged, positions as their sources give them.
2. A finder's text matched to an attested name through its article and case endings, tested on the 2022 hand readings;
   a relative or two-name text counted, not used.
3. One occurrence per record: a recapture once, a copy (an orri pick, an inspector's sample of a logged haul, a tagging
   group at its own station) left to the original.

**Not in §5:** irregular inflection (BÍN declined by the maintainer, 2026-10-24).

## 6. uv's closures and regulated areas (built 2026-10-24, decision 226)

The maintainer: "think you have at least the schema uv to mine", then the whole process repeated with it. **Measured**
(decision 226): an area's code is no name, its explanation and a real-time closure's form name the ground beside the
area's outline; the forms hold persons. **Assumed:** that an area's first sentence names its ground, and that a name
after "á" or "í" there contains the area. **Built:**
1. `uv_area` staged, one row per area with its outline; the forms' place phrase only.
2. Every name after "á" or "í" in the first sentence an occurrence, at the outline's point on surface; nested names
   each; a relative name counted, not used; an area repeating an earlier one's names and point counted once.
3. The match mended for every source: endings off before a doubled letter is made single, and phrases out of the
   vocabulary.

**Not in §6:** uv's outlines as footprints (a closure's box is not its ground's edge).
