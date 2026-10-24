# 225 — The tagging databases dumped; tag recaptures, tagging places and channel's fishing areas in the gazetteer; names matched through their inflection; a record entered twice counted once

*2026-10-24. The maintainer asked for dump scripts for `merki` and `fiskmerki` (TODO 144) and ran them, pointed to the
place names in `channel` ("we have them already in the dump"), and then said that a noun takes four endings in the
singular ("Hestur, Hest, Hesti, Hests are all just Horse"), and that the ornefni repo's files may now be repeated.
Built, checked and written by Claude (AI); not checked by a person. Amended the same evening, before any commit: two
faults of the match, found while adding `uv` (decision 226), are mended below and the numbers are the final run's; the
first run's are kept at the end.*

## The dumps

- **`merki`**, the older tagging system: 45 tables, no views, 549,007 rows, in `raw/oracle/merki/`.
  - Its place fields hold the same records as `fiskmerki`'s, so nothing is read from it:
    - `endurheimt`: 26,370 of 26,470 place texts sit in `fiskmerki.endurheimtur` with the same position;
    - `grupmerk`: 456 of 457 names are in `fiskmerki.groupmerk`;
    - `merking`: 123 of 123 names are there too.
  - `finnandi`, `contact`, `tmp_contact` and `verkefnisstjorar` hold persons: counts only (decision 159).
- **`fiskmerki`**, the tagging system in use: 53 objects, 51 written, 22,048,283 rows, in `raw/oracle/fiskmerki/`.
  - The maintainer's run stopped at the views. Claude then added `skip`, ran `--resume` (which kept the 48 files
    written; log `_logs/20261024_165019_resume.log`) and ran `dump/oracle/code.R merki fiskmerki`.
  - The two views skipped (`dump/oracle/fiskmerki.R`):
    - `rafaudkenni_summur_v` fails inside Oracle (ORA-01722);
    - `rafgogn_v`, over 19.8 M readings, gave no row in ten minutes.
  - Five non-UTF-8 notes, read as Windows-1252 (decision 167).
  - The files carry `fd.commit` 7f3ad19 dirty: the scripts were committed after the run, in 48705a6.
  - `hafsvaedi` (12 regions: Ísland, A-Grænland …) and `landshlutir` (coast sectors 01-09) are coarse codes, not read.

## Three sources added (staging, Side: preprocessing)

| Script → `staging/ornefni/` | Rows | Positions |
|---|---|---|
| `channel_name.R` → `channel_name` | 22,503 stations with a fishing area, 2000-2026 | the tow's midpoint, the start, else the recorded square |
| `tag_recapture.R` → `tag_recapture` | 35,108 recaptures with a place text (`endurheimtur` 35,059, `endurheimtur_otengt` 49) | 21,205 points, 10,729 squares, 3,174 none |
| `tag_release.R` → `tag_release` | 1,536 links of 521 tagging groups (450 names) to channel samples | the station: 1,293 tows, 186 starts, 15 squares, 42 none |

- **Recapture positions.**
  - `NBREIDD`/`VLENGD` are degrees and minutes, DDMM.mm; a minus longitude is east (three Barents Sea recaptures).
  - They are points, not squares' centres: 63 of 24,332 sit on one.
  - The recorded square agrees on 23,970 of 24,168.
- **Shared helper.** channel's positions are read by `decode_channel_position()` (`R/channel_position.R`), now shared
  by `channel_name.R` and `tag_release.R`.

## Names matched through their inflection (`curate/place_name_evidence.R`)

A finder's text names a place inflected after a preposition: "út af Hellissandi", "í Faxaflóa", "á Halanum".
- **The rule.** A name's word, folded (case, accents), loses an article ending and then a case ending, with the stem
  changes of fjörður, höfn, strönd, sjór and ey, before a doubled letter is made single. A text's word is read every
  way an ending allows: "grunni" is grunn + i, not gr + unni.
- **Matching.** The readings are matched to the names the other sources attest, longest run first. A vocabulary name
  has class `name`, four letters or more and no digit. It is not a bare terrain word (kantur, blettur, Norðurkantur
  …; Halinn is no bare word, alone it is the ground off the Westfjords). Nor is it a phrase that opens with "á" or
  "í" or holds a word of relation ("A Húnaflói", "Innan við Fiskasker", "Út af Ólafsvík").
- **An occurrence** is a text holding exactly one name, alone or after "á" or "í". After a word of relation (af, við,
  undan, fyrir sunnan …) the text places the catch *relative to* the name. Those texts, and texts naming two places,
  are counted but not used.
- **Tested against the 2022 hand readings** (`ornefni_endurheimtur.xlsx`, 9,749 read texts):

  | Outcome | Texts |
  |---|---:|
  | the reading | 5,294 |
  | the reading, spelt otherwise | 971 |
  | another name | 115 |
  | two names or more | 739 |
  | relative to a named place | 366 |
  | no name matched | 147 |
  | the reading is a bare terrain word (Vík, Brún, Kantur), which the rule never matches | 2,117 |

  - Of the 7,632 readings that name a place, 6,265 (82 %) are matched to that name or its spelling. Of the 6,380 texts
    matched to a name, 98 % agree with the reading.
  - "Relative" is mostly "Innan við Fiskasker" and the like, which the reader read as the landmark and the rule does
    not.
  - Irregular forms are missed: Fætinum (Fótur) and the like. BÍN, which would supply them, is not to be downloaded
    (maintainer, 2026-10-24).

## A record entered twice is one occurrence

| Repeat | Rows | Kept |
|---|---:|---|
| Both hand workbooks read the same recaptures | 7,725 | `ornefni_endurheimtur.xlsx`'s reading first, else trial2's fiskislóð |
| The ornefni repo's 2022 extract (`recapture_place`) of recaptures now dumped | 20,317 | the dump, which gives the position as it stands now |
| A recapture name picked in the app from orri.ornefni, at orri's exact position | 1,799 | `oracle_name` (a copy would confirm orri by itself) |
| A channel sample of a Trackwell haul (same key, same day, within 0.02 × 0.01°): inspectors 991, discard project 270, fishermen 60, other 9 | 1,330 | `trackwell_haul` (the skipper's name, copied) |
| A tagging group at a channel station that names it the same | 9 | `channel_name` |

- **Other pairs.** A check of the same key at the same spot (within about 100 m) across every pair of staged tables
  found no other copy, `uv` included (decision 226). The largest overlap, channel with Trackwell, was 10.5 % of
  channel's cells before the 1,330 were removed and 4.2 % after.
- **Bookkeeping.** Every staged row is in one outcome in `outcome.parquet`. Recaptures:
  - 12,622 occurrences (2,895 through inflection) and 10,030 read by hand;
  - 1,799 orri picks, 4,308 relative, 1,923 with two names, 4,354 with none matched, and 72 numbers.

## The gazetteer

Built with these sources and `uv`: decision 226. Its cross-check's new disagreements are mostly the recaptures':
- homonyms: Sandvík, Digranes, Fagranes and Eiðisvík recur round the coast, so a finder and another source each name
  a different place (Flatey, whose two places each have their positions, is `several places`);
- loose use: a finder's "Bakkaflói" or "Miðnessjór" for a catch some way off.

The tolerance was not widened to hide them: they are for the review loop (TODO 144).

## Not done

- **Irregular inflection.** BÍN declined by the maintainer, so a form such as Fætinum needs a rule of its own.
- **The targets build.** The scripts were run by hand. A `tar_make_isolated(names = )` after the commit gives clean
  `fd` stamps.

## Superseded — the first run, kept for the record

The first match keyed each word, making a doubled letter single, before the endings came off. So "Öræfagrunni" read as
gr + unni and missed Öræfagrunn. It also kept phrases as names, so "á Húnaflóa" was taken whole as Trackwell's
"A Húnaflói" and lost its "á". That run gave:
- **The test:** the reading 5,296, spelt otherwise 935, another name 469;
- **The recaptures:** 14,482 occurrences;
- **The gazetteer:** 909 confirmed and 492 disagreeing.
