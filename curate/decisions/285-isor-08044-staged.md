# 285 — ÍSOR's fourth report of 2008 staged: the old names of the North Atlantic and the names proposed for its deeps

*2026-11-06. The maintainer: "Yes, download it", then "Yes, stage it", then "Commit and rebuild". Found, staged,
rebuilt and checked by Claude (AI); not checked by a person.*

## What was found

A web scan for grey literature on sea names (the maintainer, 2026-11-06: "most likely icelandic sources", "grey
litterature reports", "like from orkustofnun, fiskifelagid"). No published list of fishing grounds with positions
turned up. The one gap it found in the gazetteer's sources:

- **The report:** ÍSOR's GRG-ISOR-08044, "Örnefni fyrr og nú á norðanverðu Atlantshafi" (Haukur Jóhannesson, version
  1.0, 2008-04-02, for Orkustofnun; 6 pages, with a text layer).
- **Its companions:** the other three of the series (08041, 08045, 08125) were staged in decision 222. This one was
  not on disk.
- **Filed:** downloaded from Rafhlaðan, Landsbókasafn's repository, into `raw/external/ornefni/documents/`, with its
  md5 in that folder's `_manifest.csv` and a paragraph in its `README-provenance.txt`.

The scan's other leads (the German fisheries research reports, Close's 1909 British skippers' book, a GDR captains'
record, MFRI's card collection) are in `$FISHYDATA/archive/2026-11-05-timarit-ornefni/README.md`.

## What changed

- **The reader:** `sources/ornefni/document_name.R` reads it beside the other three (06f4f71). The report has two
  parts:
  - **"Nöfn á hafsbotni"**: 14 proposals in the series' layout, "Name. Description. Enska: English name.", 7 marked as
    coined (◊). A line ending in its figure ("(mynd 2)") is now a section heading.
  - **"Gömul örnefni"**: 8 old names with no English name (Íslandshaf, Dumbshaf, Grænlandssund, Grænlandshaf,
    Gunnbjarnarsker, Hvarf, Svalbarði, Hafsbotnar). There an entry starts at a line of one word and a full stop after
    a line that ends a sentence: a name inside the text that begins a line ("Íslandsála. Á seinni tímum …") follows no
    full stop, and a short sentence ("Gamalt og gott nafn.") is more than one word. Checks: one entry per "Enska" but
    the old names, and an old name is one word.
- **Tested in scratch:** a scratch `$FISHYDATA` held the documents only. The old reader gave the live staging file
  exactly; the new one gives the other four documents unchanged and 22 new rows.

## The rebuild

Filing the PDF changed `ornefni_raw`, so the 13 staging targets were outdated. The logbook chain above the gazetteer
(`afli`, `logbook`, `station_window` …) was outdated too, for reasons not of this change. So each target was built
alone with `targets::tar_make(names = , shortcut = TRUE)`, in its own R session under the heavy-job lock.

| Target | Result |
|---|---|
| the 13 staging targets | 18 of 19 files unchanged; `document_name` 394 → 416 rows |
| `place_name_evidence` (stamped 06f4f71) | 536,249 → 536,271 rows: exactly the 22 rows of 08044, every other row unchanged (the sum of row hashes after less before equals the new rows' sum) |
| `place_name`, `name_group` | 9,281 → 9,292 keys |

- **The 11 new keys, text only:** Íslandshaf, Dumbshaf, Grænlandshaf, Gunnbjarnarsker, Hvarf, Hafsbotnar,
  Svalbarði, Grænlandsdjúp, Grænlandsáll, Grænlandshryggur, Svalbarðadjúp.
- **10 keys gained a source:** six that ÍSOR's other reports held (Brimisdjúp, Jötnagrunn, Heljargjá, Íslandsdjúp,
  Íslandsslétta, Ægisdjúp), and four placed by other sources (Færeyjahryggur, Grænlandssund, Kolbeinseyjarhryggur,
  Reykjaneshryggur), whose positions come from those sources.
- **Not compared row by row:** the other gazetteer rows. The fingerprint (`R/fingerprint.R`) keeps only totals, and
  the old file was replaced. They are derived from the evidence, which changed only in the 22 rows.
- **Still outdated:** the three gazetteer targets stay outdated in `tar_outdated()` while the logbook chain above them
  is.

## Notes

- **Old names in a fishing-ground gazetteer.** Some of the old names are not grounds (Hvarf, Greenland's southern
  point; Svalbarði, which the report takes for Jan Mayen in the old texts). They enter as names with their text, like
  ÍSOR's other entries, and carry no position.
- **The same day, outside the repo:** the Vestmannaeyjar map in `raw/external/ornefni/documents/` was read and placed
  in `$FISHYDATA/archive/2026-11-06-vestmannaeyjar-map/`: 155 names, 88 sea names new to the gazetteer, and an error
  of about 90 m on 15 of LMÍ's islands. It is not staged; that is the maintainer's call.
