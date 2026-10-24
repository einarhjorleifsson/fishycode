# 223 — The place-name gazetteer, version 1: every source's names under one key, with footprints, seabed and levels

*2026-10-24. The maintainer: "once you are done with staging can you go and proceed to curation?" (plan 043 ask h,
plan 044). Built, checked and written by Claude (AI), not checked by a person.*

## What was built

`curate/place_name_evidence.R` and `curate/place_name.R`, preprocessing side, write `curated/place_name/` with
`write_curated()`. They are wired into `_targets.R` (`place_name_evidence`, `place_name_gebco`, `place_name`) and were
built by name, so `tar_outdated()` is empty.

- **`evidence.parquet`** (503,638 occurrences): one row per name in a staged row.
  - Each carries a representative point (a tow's midpoint, a line's middle, a polygon's point on surface), its basis
    and kind, time and vessel.
  - Trackwell's hauls carry gear, through the logbook match on vid and start minute: 440,781 of 478,326.
  - `position_flag` marks 89 positions kept as given but used for nothing: 22 of Trackwell's with an impossible
    latitude or longitude, and 67 at zero.
- **`variant.parquet`** (5,168 spellings): each spelling with its key and its rule (`key`, or `repaired` where a lost
  letter's "?" fits exactly one name with letters: 35 of 563). The hand readings (1,342) and the articles' synonyms
  (17) sit beside the spellings as relations, never merged.
- **`outcome.parquet`:** every staged row in one outcome. The occurrences come from Trackwell's hauls 478,326 and its
  summary 1,095, the plotter 3,870, LMÍ's sea names 1,775 and the recapture readings 17,755. Not occurrences:
  - the plotter's numbers (446,969), symbols (778) and unnamed marks (67,972);
  - "FROM SHIP" (6,408) and "Ekkert valið" (1);
  - LMÍ's land and lake names (4,046);
  - the recapture texts (read in their readings);
  - the fiskislóð hulls (derived from those readings);
  - the plotter's tracks.
- **`place_name.parquet`** (4,629 keys):
  - name: the preferred spelling;
  - counts: by source, vessels and years;
  - position: the median, r80, and a footprint (the cells holding 80 % of the positions) for 1,281 keys;
  - seabed: GEBCO's depth, slope and BPI;
  - terrain word, and gear: bottom trawl first on 836 keys;
  - parent: 186 keys, 158 by footprint and 28 by ÍSOR's heading, under 72 parents.

## Checked

- **Accounts:** every staged row is in one outcome, every occurrence has a key, and every key has a row.
- **Plan 043 §3.4 on the merged data:**
  - Litli banki's six spellings are one key (976 occurrences), and Tungan's four are one;
  - Reykjafjarðaráll holds Tungan, Kolkugrunn and two abbreviated forms;
  - of the keys with 30 or more positions, 91 % of the banks and 94 % of the horns lie higher than the seabed around
    them, edges are the steepest (1.11°), and deeps and hills are near the middle (54 %, 43 %).

## Not done, and why

- **The key's limits:** it does not join spellings beyond case, accents, spaces and doubled letters. Grovens, Gróves,
  Groves, Gróens and Grovers stay apart, as do abbreviations such as "Tungan Reykjafj.áll". That is a person's read
  (plan 044 §2).
- **Still to come** (plan 044 §2, TODO 144):
  - the lanes from the effort map, which are flow-side;
  - the Oracle gazetteers;
  - footprints drawn from the seabed or the effort ridges.
- **fd.dirty is true** in the stamps: the tree held uncommitted work (this session's and another's) when they were
  written.
