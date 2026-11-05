# 067 — Place-name records: a source registry, one reading per document, one file per place, and the links between them

**status:** proposal — written 2026-11-05 at the maintainer's request, with the timarit.is study
(`$FISHYDATA/archive/2026-11-05-timarit-ornefni/`, its README) · **2026-11-05** · **see:** plans 043, 044, 045 (§3
step 1's ledger, ask c), decisions 221-226 and 272, TODOs 144 and 186, the data-dict overlays of plan 040
(`dump/oracle/meta/`, `R/data_dict.R`), the vid ledger (`R/allocate_vids.R`)

Drafted with AI assistance (Claude) on 2026-11-05; a person has not yet checked it. **Measured** (by Claude,
2026-11-05): the counts in §1. **Assumed:**
- that a document read once into a structured file is worth more than its names alone. One article read for the plan
  (§1) says so; no reading has been made or checked yet;
- that SKOS and the Linked Places Format (§5) fit. They are leads from Claude's knowledge and have not been read
  against their specifications;
- that a person will fetch the issue text of the pages the search finds (§8, ask c).

The maintainer, 2026-11-05: "think about how best to store / file Örnefni - a yaml construct is one posibility. We may
need to think about if each ornefni should have a yaml (or whatever construct) and then also how to refer to the
original source, how to refer to synonyms, how to do crossreferencing. possibly something from the data-dict construct
could be borrowed, although that deals with metadata. you also should contemplate how we incorporate other sources like
those we have already scraped when it comes to örnefni."

## 1. What is at hand (measured 2026-11-05)

- **Staged sources:** 17 adapters in `sources/ornefni/`, each source-shaped (`staging/ornefni/`).
- **The gazetteer** (`curated/place_name/`, decisions 223-226): 536,249 occurrences and 9,281 keys.
  - By class: 8,146 `name`, 575 `description`, 560 `composite`.
  - Decision 272 adds a proposed group per place (`name_group`), never merging a key.
  - Plan 045 measured 1,617 candidate synonyms and 573 names with several places.
- **The maintainer's records** (`raw/external/ornefni/data-md/`): 151 Markdown files, one per name. The maintainer
  wrote them in 2023 (file dates 2023-11-16 and 2023-12-07) from published articles. The people they name are the
  skippers those articles quote, a public record.
  - Sections: name, synonyms, description, comment, class, quotations, person, url, reference.
  - Sources: 114 cite two Fiskifréttir pages on timarit.is (2002-05-31 p. 14, 80 records; 2002-06-21 p. 8, 34
    records); 35 cite one Fiskifréttir web article.
  - What is filled in: a description on 18, quotations on 62, a person on 68, synonyms on 27. Of the 114 timarit
    records, 110 have no description.
  - Baujuhóll's record holds the name, "Fjöllin" and the link. The article says much more: a long hill, 60 fathoms at
    its shoalest, saithe and redfish, towed along both sides and around it. It also says who named it, and why: a buoy
    marked the shoal to tow around. And it gives relations the files cannot hold. *Bjargvætturinn* is also called
    *Vætturinn*; *Mamman* lies in the middle of *Töfragarðurinn*; *Syndabælið* was first *Sindrabælið*, after Sindri
    VE.
- **The charts' names** (TODO 186): 5,211 names read off the chart images, in a study, not yet in the gazetteer.
- **timarit.is:**
  - Its search (`/search`) is open to scripts.
  - Its issue text, page images and PDFs sit under `/files` and `/pdf`, which robots.txt disallows for every crawler
    (read 2026-11-05).
  - The study's `01_search.R` searches by the gazetteer's own names, through `/search` only.
  - Two pilots, 50 requests 10 s apart: pages that two or more names hit are the known articles, and two articles not
    read before. These are *Sjómannablaðið Víkingur* 1980 p. 30 (foreign names and their origins) and *Bændablaðið*
    7.11.2019 p. 16 (the names of the stern-trawler years). Both were judged from their snippets.
- **A first trial of the reading format** (§5) was run in the study on 2026-11-05. Ten documents were read by
  Claude subagents into 149 entries: 70 with a name's origin, 103 placed, 35 names new to the gazetteer.
  - The 2002-06-21 article's reading holds 28 of the maintainer's 33 named records of it, with an origin for 27,
    where the records hold none.
  - The issue texts were fetched slowly at the maintainer's decision, past robots.txt (the study's README).
  - No person has checked the readings.
- **The data-dict construct** (plan 040): one YAML per schema, merged from two parts:
  - a part generated from the dump;
  - a hand overlay, `dump/oracle/meta/<schema>.yml`, which adds labels, details, definitions and asserts with their
    expected counts.

  `rewrite_data_dict()` merges them and `check_data_dict()` checks the result.

## 2. The design in short

**Sources speak in names; the gazetteer speaks in places.** Three kinds of record keep the two apart:

1. **A source registry:** one entry per source, cited by every reading and occurrence (§4).
2. **Readings:** what a source says, source-shaped, never resolved to a place.
   - A structured source's reading is its staged table, as now.
   - A text source (an article, a report, an interview) is read into one YAML **per document**, listing each name it
     describes, what it says of it and the relations it states (§5).
3. **Places:** one id per place, given once in a ledger and never moved, as a vid is (§6).
   - Each place has a file in two parts, the data-dict's split:
     - generated from the gazetteer: its names, counts, positions and attestations;
     - a hand overlay holding only decisions: the preferred name, same place or not, its parent, links to other
       gazetteers.
   - A rewrite merges the two and a check holds them to the rules.

## 3. Why not one file per name

- **A name is a string; a place is a thing.**
  - One name can be several places: Sandvík, Digranes, and the 573 names with several places.
  - One place can have several names: the 1,617 candidate synonyms.
  - A file per name must say which place it means, and a homonym needs two. A file per place lists its names, and a
    name's homonyms are found by its key.
- **A document belongs together.**
  - An article describes many names and the links among them.
  - Its citation, date, the skippers it quotes and its terms belong to it once.
  - The 151 files repeat the link on each record and have nowhere to put a relation between two names.

## 4. The source registry

- **Where:** one YAML, `sources.yml`, one entry per source; where it lives is §7.
- **Bibliographic fields:** CSL's (`id`, `type`, `title`, `container-title`, `issued`, `page`, `URL`, `author`,
  `publisher`), so the book can cite a source directly; Quarto reads CSL YAML.
- **fishycode's fields:**
  - `kind`: `text` or `structured`;
  - `staged`: the staged table and its adapter;
  - `terms`: `public` (published texts) or `internal` (Trackwell, plotters, the charts);
  - `access`: how it was had, for example "issue text saved by a person with timarit.is's button".
- **Check:** every `source` in `evidence.parquet` and every document reading names a registered source; every entry
  is used.
- **Seeded** from the adapters' headers, which already say this for the 17 staged sources.

## 5. Readings of text sources: one YAML per document

Baujuhóll as a reading of the 2002-06-21 article would look like this:

```yaml
$version: 0.1.0
source: fiskifrettir-2002-06-21-p8          # in the registry: Fiskifréttir, 21.6.2002, pp. 8-9, timarit.is/page/7540154
text: text/2002-06-21i1p8.txt               # the issue text as saved, with its md5
read_by: Claude Sonnet 5.5 (AI), 2026-11-..  # who made this reading
checked_by: ~                               # a person, when one has
entries:
  - name: Baujuhóll
    written: [Baujuhóllinn]                 # other forms in the text
    page: 8
    within: Fjöllin
    says: >-
      Mikil fiskislóð sem gefur ufsa og karfa. Hóllinn er aflangur, 60 faðma þar sem grynnst er; dregið utan í
      honum báðum megin og togað í kringum hann.
    depth: {value: 60, unit: fathom, at: shoalest}
    species: [ufsi, karfi]
    named_by: Sverrir, skipstjóri á Úranusi
    origin: Bauja sett út þar sem grynnst var, til að marka hvar toga skyldi í kringum.
    quoted: [Sigurður Steindórsson]         # the skipper the article quotes
  - name: Bjargvætturinn
    also: [Vætturinn]                       # a synonym the text states ("eða")
    near: {name: Ágústa, bearing: NW}
  - name: Syndabælið
    formerly: [Sindrabælið]
    named_after: Sindri VE
```

- **Every field is what the text states.** A value the reader infers carries `basis: inferred`, as everywhere else.
- **OCR errors:** the reader corrects them, and keeps the OCR form in `ocr:` where it differs.
- **Relation vocabulary:** taken from established gazetteer work rather than invented (ask d). Leads, not yet read:
  - SKOS for names: `prefLabel`, `altLabel`, and `hiddenLabel` for misspellings and OCR forms;
  - the Linked Places Format of the World Historical Gazetteer for places: names with their citations and dates,
    relations such as `gvp:broaderPartitive` for "within", and links (`closeMatch`, `exactMatch`) to other gazetteers.

  The YAML keeps short names (`within`, `also`, `formerly`) and maps them to those terms on export.
- **Staging:** a new adapter, `sources/ornefni/document_record.R`, writes two tables:
  - `staging/ornefni/document_record.parquet`, one row per entry;
  - `document_relation.parquet`, one row per stated relation.

  The gazetteer reads the entries as occurrences (kind `text`) and the relations as candidate synonyms and parents, as
  it reads the articles' synonyms now.
- **The 151 Markdown records** stay in raw, as the record of the ornefni repo.
  - When a document reading covers their article, every name of theirs must be an entry in it (a check), and staging
    takes the reading in their place.
  - The registry says which reading replaces which files.

## 6. Places: an id, a ledger, a file

- **The id** (`place_id`, ask b): an integer given once, never reused or moved, as the vid ledger's are (AGENTS.md,
  the cycle rule).
  - A merge retires one id with `replaced_by`; a split gives new ids and the old one `split_into`.
  - A retired id stays in the ledger.
- **Seeding:** once, from decision 272's groups, an id for each group and each lone key of class `name`, status
  `proposed`. A review sets `reviewed`.
- **Each place's file:**

  ```yaml
  $version: 0.1.0
  place_id: 4711
  name: Baujuhóll                     # overlay: the preferred name (else the rule's, basis: rule)
  status: reviewed                    # proposed | reviewed | retired
  within: [4702]                      # Fjöllin; overlay or the gazetteer's parent (basis shown)
  near: [{place_id: 4733, bearing: NW, basis: stated, source: fiskifrettir-2002-06-21-p8}]
  links: {lmi: ~, marineregions: ~}   # other gazetteers' ids
  different_from: [5120]              # a review's "not the same place": no rule may join them
  names:                              # generated: every key of this place, with its sources
    - {name: Baujuhóll, key: baujuhol, sources: {article: 1, trackwell: 37}, years: [2008, 2024]}
  position: {lon: ..., lat: ..., r80_km: ..., footprint: place_name.parquet}
  attestations: [fiskifrettir-2002-06-21-p8, trackwell_haul, plotter_mark]
  note: ~
  reviewed_by: ~                      # who and when (plan 045 ask c)
  ```

- **Generated and overlay:** the generated part is rewritten with the gazetteer and never edited. The overlay holds
  only the decision fields. A rewrite merges them, as `rewrite_data_dict()` does, and a hand value always wins and
  says so (`basis: reviewed`).
- **`check_place_records()`,** enforced like `check_data_dict()`:
  - every id is in the ledger and unique;
  - every relation points at a place that exists and is not retired;
  - `within` has no cycle;
  - `also` is symmetric;
  - no chain of same-place decisions joins two places marked `different_from`;
  - every gazetteer key of class `name` is in exactly one place or listed as unresolved (decision 155's accounting:
    every name in one outcome);
  - every attestation's source is in the registry.

## 7. Where the files live

What each kind of file holds decides where it goes:

- **Readings of published texts** hold only what was published: the names, what the text says of them, and the
  skippers it quotes. A reading made by Claude is written by a script into a study under `$FISHYDATA`, as the charts'
  names were, so no rule stands in its way.
- **The registry** is generated from the adapters' headers, with an entry added for each new document.
- **The places' files** carry Trackwell's and the plotters' names and counts, which are internal (plan 045 §5). They
  are never in the public repo.
- **A person's decisions** are the only files edited by hand: same place or not, the preferred name, a corrected
  reading. Two rules meet there:
  - fishycode is public;
  - nothing under `$FISHYDATA` is ever hand-edited (AGENTS.md).

  One rule has to give (ask a). Nothing waits on it until a person starts reviewing, which is plan 045's ask c. The
  options:

- **a. A private repo** for a person's decisions and corrections. One candidate is the ornefni repo
  (`~/stasi/ornefni`, plan 043 ask a) revived as a private MFRI repo. fishycode reads it as an input at a pinned
  commit, as it reads ramb. Git gives the history, the diffs and a review by pull request. *Recommended.*
- **b. Under `$FISHYDATA`, written only by functions:**
  - the review page and functions like `place_overlay_set()` write append-only batch files, as `allocate_vids()`
    does;
  - no file is hand-edited, and the history is in the batches;
  - but a person cannot simply open a file and correct a line.
- **c. Under `$FISHYDATA`, with a declared exception** to "never hand-edited" for one folder, kept in a local git with
  no remote.

This widens plan 045's ask c, which is still open.

## 8. How the other sources come in

| Source | Its reading | Into places |
|---|---|---|
| plotter marks and tracks, Trackwell's hauls and areas, the Oracle gazetteers, LMÍ, uv, the channel, recaptures and tags, fiskislóð | the staged tables, as now | occurrences, by key and group |
| the Skjálfandi report, ÍSOR's names | `document_name.parquet` from the PDFs, as now | occurrences; ÍSOR's groups as `within` |
| the 2022 hand readings (`name_dictionary`) | as now | candidate synonyms |
| the 151 Markdown records | replaced by readings of their articles (step 2) | as readings |
| the charts' names (TODO 186) | a staged table from the study's output, as TODO 186 plans | occurrences, flagged by scale |
| timarit.is | search hits (snippets) list candidate pages; the pages a person saved are read into document YAMLs | as readings |

- A news report that only mentions a ground ("togararnir voru á Rósagarðinum") is a dated occurrence: evidence of a
  name's use in a year, though not a description.
- Such mentions are kept only from pages that were read, never from snippets alone.

## 9. Proposed steps

1. **The registry** and its check, seeded for every source staged now.
2. **The reading format** (schema 0.1), its adapter and a pilot on the two 2002 articles, their text saved by a
   person. Measured against the 151 records:
   - their names found as entries;
   - descriptions gained;
   - relations stated.
3. **timarit.is:**
   - the study's search widened from its pilot;
   - candidate pages ranked by distinct names;
   - the pages saved by a person (ask c);
   - read by subagents as the charts were.
4. **Place ids and the ledger,** after asks a and b.
5. **The places' files:**
   - generated part, overlay, rewrite and check;
   - the explorer (`products/place_names/`) reads them;
   - plan 045's review page writes the overlay.
6. **An export** in the Linked Places Format, internal, if ask d says so.

## 10. Asks

- a. **Where a person's decisions are kept** (§7): a private repo, functions only, or a declared folder. Needed once
  a person reviews (plan 045 ask c). `needs: maintainer`.
- b. **The place id:** its name (`place_id`, or a short one in the manner of `vid` and `pid`), and whether every
  `name` key gets one at seeding or only reviewed groups.
- c. **timarit.is's text:** a person saves the issues the search finds, with the site's button, or Landsbókasafn is
  asked for the maritime titles' text (Fiskifréttir, Ægir, Sjómannablaðið Víkingur, Morgunblaðið's *Úr verinu*).
  `needs: maintainer`.
  - No published service for bulk text was found (Claude's search, 2026-11-05). timarit.is's about page gives the
    images for personal use under the copyright act (nr. 73/1972) and a contact, timarit@landsbokasafn.is. So asking
    is a request, not a known service.
  - The Icelandic Gigaword Corpus (Risamálheild, Árni Magnússon Institute; malfong.is) holds printed papers and
    journals, but its records name no titles. Whether it holds these ones is not known.
- d. **The vocabularies:** follow SKOS and the Linked Places Format's terms, or keep fishycode's own.

## 11. Not in this plan

- The review page (plan 045 step 1) and the placing model (plan 045 §2).
- Publishing outside MFRI (plan 001's boundary; the sources' terms).
