# 272 — The place-name explorer, read-only, and one name per place proposed by rule: plan 045 step 1's first part and §3.1; a hólf is no hill

*2026-11-01. The explorer was asked for by the maintainer through the plan 059 session ("an explorer for it, like the
vessel overview"), then steered by the maintainer in its own session: the names hard to read, too small, the map too
bland, "solely for looking at placenames - now just for qc purpose", a busy port, and the many versions of one name
("In the end we really want a single name (although the sources stay as is)"; "ok, proceed with the code, will build
afterwards"). Merged and built at the maintainer's word ("Merge and build") by the plan 059 session: 6a63fc3, and
`$FISHYDATA/archive/2026-11-01-place-name-build/` (its README, the build's logs, fingerprints and terrain counts). The
measures behind one name per place, and the read of the groups, are in `$FISHYDATA/archive/2026-11-01-place-name-groups/`
(its README and four scripts, rerun on the built store). Built, tested and written by Claude (AI); no person has checked
the numbers or the groups.*

## The explorer (plan 045 step 1, its read-only part)

`products/place_names/` (its README and `checklist.md`): `place_names()` from an R session, or `server.R` from a
terminal, on 127.0.0.1:8797.
- **The service** (`api.R`) answers fixed endpoints through a column allowlist.
  - It keeps back a finder's free text (it may name a person), Trackwell's own vessel name (the vid is served) and the
    source's row id; `check.R` tests that.
  - The names, places, synonyms, spellings, groups and footprints go to the page once (2.1, 0.5, 0.1, 0.8, 0.7 and
    10 MB as JSON). 1,783 of the 9,281 names have a footprint.
  - A name's occurrences are asked when it is chosen: up to 30,642 rows, 0.1 s.
- **The page** is its own, on MapLibre GL 4.7.1 pinned on jsdelivr, with ramb's base maps (`rb_map_basemaps()`) and
  the effort map's minimum-zoom labels. `rb_map()` was not used: it is a map of layers with filters, with no list to
  search, no panel for a chosen record and no tables linked to the map, and it is ramb's generic engine.
- **Read-only.** It writes nothing, to `overrides/` or anywhere. Plan 045's queues and answers wait on its ask c (who
  reviews, and whether a reviewer's name is kept).
- **The maintainer's steers**, each a click path in the checklist, all passed on 2026-11-01:
  - the names hard to read: they took the base map's thin italic with a broad white halo. Now upright semi-bold with a
    narrow soft halo, and the base map's own sea names hidden (M4);
  - "my eyes are getting old": the text a quarter larger, and the page stacked below 1200 px (W1);
  - "use colours more cleverly ... brewer": the 12 sources in ColorBrewer's Paired, a light and dark pair per family of
    witness, the rarer drawn on top. The footprints in Dark2, RdYlGn or YlGnBu, with a legend that filters (D3, D4, M5);
  - "solely for looking at placenames - now just for qc purpose": the names themselves carry the colour, by
    cross-check by default (M5);
  - "address already in use": the port was held by a test server. `place_names()` now uses an explorer of its version
    already on the port, and names any other holder.

## One name per place (plan 045 §3.1)

**The question.** `utanvidholf` is one ground, outside the Breiðafjörður box, written as 16 keys: "Utan við hólf", "Utan
við hólfið á Breiðafirði", "Utan við hólf Br." and more. Measured on the gazetteer before the build:
- candidate pairs within 30 km link 1,733 keys in 664 families, holding 68 % of the positioned occurrences (357,545 of
  524,973);
- a transitive merge would chain different places: Skálin, Skelin, Svaðan and Snaginn, one letter apart; and it would
  cut the composite "Barðið/Djúpkrókur" into its halves.

**The rules** (`curate/name_group.R`, target `name_group`; its header has them in full):
- each name is read to its core: article and case endings, compass letters, "fyrir utan" and "utan við" as "utan";
- a locator at the end ("Br.", "Breiðafj.", "á Breiðafirði") is dropped where it is marked as one and what is left is
  a name used near, or the words name a broad name;
- keys of one core gather as a star around the key with most positions, within reach;
- the 2022 hand readings join a key left alone;
- never a chain, never two names in one, a part (a compass word, a qualifier, brackets) or a bare terrain word.

The single name is LMÍ's, else the commonest plain spelling. Keys, spellings and occurrences are untouched; every row is
`proposed`.

**Built** (`curated/place_name/name_group.parquet`, 8 s):
- 9,281 keys in 8,751 groups;
- 953 keys share 423 groups: joined as the head 423, by core 348, by reading 125, by locator 57;
- "Utan við Hólf" holds 14 of the ground's 16 spellings: "…vestur af Breiðafirði" is left apart as relative, and "Utan
  við hólf Breiðafirði" (4 positions) is missed, its locator not marked as one.

The numbers equal the scratch run made before the build. `check.R` passes on the built store.

**How good, as far as read.** Claude read 25 keys per way of joining, drawn from the built groups (the study's
`scripts/02_samples.R`, `results/samples.csv`). This is a read, not a measured error rate; the review will be the
measure.
- **By core:** 24 of 25 plausibly right (article and case forms). Doubtful: "Gunnar" with "GUNNI".
- **By the hand reading:** 23 of 25, mostly spellings mended (Eyjarfjörður as Eyjafjörður, the -dýpi spellings as the
  reading's -djúp). Doubtful: "Út í myrkri" as Myrkri at 36 km; "Digraneskantur (kverk)", a part in brackets.
- **By a locator:** 20 of 25. Doubtful: "HLERI ST", "Austurbrúnin, Karginn", "Bulla í bjarg", "Arnarfjörður, Baulhús",
  and "Halamið - Barðið", two names. That one is a defect: the hyphen test's Perl pattern does not count ð, þ, æ, ö or
  an accented letter as a letter, so a hyphen after "Halamið" is not seen.

**Part of the rebuild?** The maintainer's question. Claude's recommendation, in plan 045 §3.1: the proposal yes, the
decision no.
- The rules are cheap and follow from the data, so the proposal is rebuilt with the gazetteer.
- A group's head and its commonest spelling can change as data are added, and a name in use must not change unseen.
- A reviewed name belongs in a ledger under `overrides/` that the rebuild reads and never writes, as the vid ledger is.
- That waits on plan 045 ask c.

## A hólf is no hill

`terrain()` in `curate/place_name.R` read "hól" inside hólf (a closed box) and hólm(i) (an islet) as a hill. With those
words read for no terrain, the hills went from 534 to 388. The 146 went to other (133), bank (4), horn (4), bay (3) and
deep (2); `place.parquet` and `synonym.parquet` are unchanged.

## Found, not fixed

- 25 of Trackwell's occurrences are dated 2095 (12) or 2099 (13): Halinn's years read 1998-2095. They are shown as
  recorded.
- A name's `level` measures its footprint, not whether it names a region: the large Trackwell grounds are levels 1-2.
  So the locator rule could not take level alone as "a region"; it asks whether what is left is used near.

## Commits

5c5b184 (the explorer), 01ae20a, 29fb3ae, 5ae1bbb, cea11cf (legible, larger, coloured, the names first), 11a1d0d (a
busy port), 0fcbb8f (`name_group`, the terrain fix). Merged into `main` as 6a63fc3, and built by name under the shared
lock (`place_name` 2 min 26 s, `name_group` 8 s). Afterwards only `ais_catch` and `check_allocation_audit` are outdated
(decision 261).

## Left

- The review: queues, answers and the ledger of reviewed names (plan 045 step 1, ask c).
- A reviewer's read of the locator joins, and any group to split.
- The hyphen test in `core_of()` to read Icelandic letters (`(*UCP)`, or the TRE pattern), and `name_group` rebuilt.
- Trackwell's 2095 and 2099 dates.
- The explorer's filters in its address.
