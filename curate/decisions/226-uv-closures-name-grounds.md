# 226 — uv's closures and regulated areas name their grounds: a source of the gazetteer, and the whole run repeated with it

*2026-10-24. The maintainer asked whether schema `uv` holds place names ("think you have at least the schema uv to
mine"), declined BÍN, held the commit, and asked for the process to be repeated with the new sources included. Built,
checked and written by Claude (AI); not checked by a person.*

## What uv holds

`uv` is MFRI's fishing-area information system (Upplýsingakerfi veiðisvæða), already dumped:
- **`veidisvaedi`:** 5,948 areas, from 1990 to 2020. Most are real-time closures (Skyndilokun 3,932), then
  regulations (574), repealed regulations (225), protected areas (172) and Danish-seine areas (98).
- **The names.** `heiti` is a code: a regulation's article ("504-1-A") or a closure's number ("005"). The ground is
  named in the explanation (`skyring` on 2,985 areas, `fs_skyring` on 3,129), e.g. "Bann við veiðum með botnvörpu í
  Langaneskanti".
- **`hnit`:** each area's vertices (25,929; 4 per area at the median), degrees and minutes to two decimals as channel
  holds them. 273 vertices are unread.
- **`skyndilokanir_xml_input`:** the 1,694 forms a biologist sent from the web for a real-time closure. Their
  `stadur` (790) is the place phrase ("á Eyjagrunni í Húnaflóa") and `skyring` the explanation.
- **Persons.** The forms also hold the sender and a kennitala; `starfsm`, `veidisv_starfsm` and `hafro_notendur_v`
  are persons, and the free text `ath` names people. None of these is read.
- **`l_s`:** L or S. Its meaning is not documented, and it is not longline against the rest: 661 of 1,016 L
  explanations and 464 of 854 S name longlining.

## Built

- **Staging.** `sources/ornefni/uv_area.R` → `staging/ornefni/uv_area.parquet`: one row per area (5,948), with its
  outline as WKB (5,146 polygons, median 118 km²; 157 lines, 352 points, 293 none), its gears, and the form's two
  fields (target `ornefni_uv_area`).
- **Evidence** (`curate/place_name_evidence.R`):
  - **The text.** The explanation, else the form's, else the second explanation, else the form's place, cut at its
    first sentence. The rest of a regulation's text draws the boundary from landmarks.
  - **The rule.** Unlike a finder's text, every name after "á" or "í", or opening the text, is an occurrence: "á
    Eyjagrunni í Húnaflóa" lies on Eyjagrunn and in Húnaflói. A name after a word of relation only ("norður af
    Skaga") places the area relative to it.
  - **The position.** The outline's point on surface. A polygon over 2,500 km², larger than a statistical square, is
    kind `area` (precision 3).
  - **Repeats.** An area naming the same keys at the same point as an earlier one (a renewed closure, a repealed
    regulation's copy) repeats it.

## Two faults of the match, found here and mended for every source

uv's texts showed that "á Öræfagrunni", "á Kögurgrunni", "á Halanum" and "á Húnaflóa" were missed:
- **Doubled letters.** A doubled letter was made single before the endings came off, so "grunni" read as gr + unni.
  Endings now come off the folded word first, and a text's word is read every way an ending allows.
- **Phrases as names.** The vocabulary held phrases that open with a preposition or hold a word of relation
  (Trackwell's "A Húnaflói", "Innan við Fiskasker"), and the longest-run match took them whole. They are out.
- **Halinn.** It is no longer a bare word.

The recaptures' test and numbers in decision 225 are amended to this run: another name 469 → 115, with 82 % still
matched to the reading or its spelling.

## Outcomes (every area in one, `outcome.parquet`)

| uv area | Areas |
|---|---:|
| occurrence (one name) | 1,242 |
| occurrences, one per name (two names or more) | 39 |
| relative to a named place | 931 |
| no name matched | 1,282 |
| no text | 1,578 |
| a repeat of an earlier area (the same names at the same point) | 74 |
| a river's works, a salmon net at the shore (named by its farm), a fish farm's licence or a discarded entry: not a sea ground | 802 |

- **What uv adds.** 1,321 occurrences of 251 names (557 through inflection), on 250 keys. Every one of those keys has
  another family too.
- **Most named:** Húnaflói, Breiðafjörður, Eyjafjörður, Fljótagrunn, Strandagrunn, Þistilfjörður, Álar.
- **Agreement with the other families.** The median distance between uv's median and another family's, per key:
  Trackwell 10.9 km (125 keys), channel 11.5 (190), the recaptures 11.5 (198), sjókort 11.8 (63), LMÍ 12.9 (116), the
  plotter 14.2 (63), Oracle's squares 17.7 (162). The other families' pairs run 5.3-35.3 km.
- **Repeats against the other sources.** None found: the largest overlap is Trackwell's, 31 cells.

## The gazetteer, the whole run repeated (staging, evidence, gazetteer)

| Outcome | Start of the round (decision 224's build, with channel) | Now |
|---|---:|---:|
| confirmed | 758 | 802 |
| disagree | 368 | 472 |
| several places | 560 | 573 |
| single | 6,929 | 7,033 |
| text | 387 | 401 |
| keys | 9,002 | 9,281 |

- **Confirmations.** 113 single names became confirmed.
- **New disagreements.** 61 confirmed names now disagree, 35 of them with uv among their families. A key is confirmed
  only when every pair of its families agrees, so one more witness can turn it.
- **The new disagreements in all:** 129, 108 of them with the recaptures (homonyms and loose use, decision 225).
- **Checks.** `channel_name.R`, moved onto the shared decoder, writes an identical file. `check_bookkeeping()` holds.
- **The map.** The effort map's popup lists uv among a name's sources.

## Not done

- **Irregular forms** (Fætinum for Fótur): BÍN declined; a rule of their own if wanted.
- **uv's polygons as footprints.** They are used only as positions. A closure's outline could bound its ground, but a
  box drawn round small fish is not the ground's edge.
- **The 1,282 sea areas with text and no name.** Mostly "Svæðalokanir vegna hrygningar þorsks", a regulation's title,
  or a name no other source attests (Halamið, Vestfjarðamið); and Flákinn, which folds onto the bare "flak".
- **The targets build** after the commit, for clean `fd` stamps (scripts run by hand).
