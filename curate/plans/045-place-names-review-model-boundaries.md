# 045 — Place names, the next round: a review interface with a feedback loop, a model for placing names, and boundaries from depth, habitat and effort

**status:** proposal — written 2026-10-24 at the maintainer's request, on top of the gazetteer of plan 044 (decisions
223-226) · **2026-10-24** · **see:** plan 044 §2, §4-§6, plan 043 §3.4, decisions 220, 224-226, TODO 144

Drafted with AI assistance (Claude) on 2026-10-24; a person has not yet checked it. The methods named in §2 are leads
from Claude's knowledge, not yet read against their sources.

The maintainer, 2026-10-24, beyond plan 044:
- an interface for the ambiguities in names, interactive, with a feedback loop on what the user thinks is correct;
- a better "model" for the analysis: "there must be some well known method to deal with this type of name-placing";
- a better depth model than GEBCO: MFRI has one in house;
- the EUSM habitat map, or something better, as an auxiliary to mark boundaries;
- the effort image to infer place names: the effort intensity by gear indicates names and boundaries at a broad and a
  fine scale.

## 1. What is at hand (measured 2026-10-24)

- **The gazetteer** (`curated/place_name/`, decision 226):
  - 9,281 keys from 536,249 occurrences in 11 source families; levels 1-4 hold 26, 426, 1,596 and 6,832 keys;
    923 keys have a parent.
  - The cross-check: 802 confirmed, 472 disagree, 573 several places, 7,033 single, 401 text only.
  - 1,617 candidate synonyms: spelling 677, dictionary reading 610, article 184, LMÍ's alternative 146.
- **Ambiguities waiting for a person:**
  - the 472 disagreements: homonyms (Sandvík, Digranes) or loose use (a finder's "Bakkaflói");
  - the 573 names with several places;
  - the synonyms;
  - the recapture texts set aside: 4,308 relative ("Innan við Fiskasker"), 1,923 with two names, 4,354 with none
    matched;
  - uv's areas: 931 relative, 1,282 with no name matched.
- **A labelled set already exists:** the 2022 hand readings, a person's name for 9,749 recapture texts (decision 225).
- **The effort grid** (decision 220): `$FISHYDATA/products/effort_map/grid.parquet` and `grid_005.parquet`, hours,
  kWh and fixes per cell by preset, gear (`gid`) and year, from v0's trail.
- **EUSM:** `raw/aux/eusm.rds`, 3,169,489 polygons with the MSFD broad habitat type (`MSFD_BBHT`); `staging/aux/eusm.fgb`
  is built by the `shapes` target.
- **Depth:** GEBCO 2026 (15") is what `curate/place_name.R` reads. Where MFRI's own depth model lives, and in what
  form, is not recorded anywhere in this repo.

## 2. Methods to start from (leads, unread)

Naming places from many noisy witnesses is studied under several heads:
- **Vague places.** A name's extent is modelled as a density surface over its occurrences, not a hull. Examples:
  Montello et al. 2003, "Where's downtown?"; Jones, Purves et al. 2008, on modelling vague places from web content.
  This fits broad names holding fine ones, and boundaries that fade.
- **Gazetteer conflation and record linkage.** Name similarity, distance and feature type are combined into a match
  probability (Fellegi-Sunter; Hastings 2008, on conflating digital gazetteers). This fits spellings, synonyms and
  homonyms across sources.
- **Source reliability.** A latent-class model estimates each source's error rate together with the truth (Dawid &
  Skene 1979; "truth discovery"). Trackwell's "use last value" noise, a square's size and a closure's box become each
  source's error. A reviewer's answers are labels for it, and active learning chooses the next question by the
  information it would give.
- **Toponym resolution** (geoparsing) for the free-text sources: recapture texts, uv's explanations, the logbook
  notes. Today's inflection match (decision 225) is a hand-made instance.
- **Regionalisation.** A surface is cut into contiguous regions by image segmentation (watershed, mean shift,
  scale-space) or spatially constrained clustering (SKATER, REDCAP), on effort by gear, depth and substrate. Names are
  then assigned to regions by the occurrences inside them.

**Proposed model:** a probabilistic gazetteer.
- **Places.** Each place is a latent object with a footprint (a density surface over regions), its names and a
  parent.
- **Occurrences.** Each occurrence comes from one place, through its source's own error.
- **Fitting.** Every reviewed answer is fixed in the fit, and the fit is redone.
- **Adoption.** The deterministic version 2 is the baseline. The model replaces it only where it does better on the
  reviewed cases ("better than the status quo").

## 3. Proposed steps

1. **The review interface** (first, since its answers are the labels for everything else).
   - A page and an R service on 127.0.0.1 under `products/`, like the vessel overview: the browser holds the data,
     and the views are linked.
   - Queues: disagreements, several places, synonyms, set-aside texts. Each case shows its occurrences by source on
     the map, over effort, depth and habitat.
   - Answers: same place or not, a spelling of, not a name, its parent, its place. They are written with who and when
     to `overrides/place_name_review.*`, which the evidence and the gazetteer read as an input, never compute (the
     cycle rule, AGENTS.md).
   - The feedback loop: a rebuild shows the case resolved, or what it now conflicts with.
   - Built one step at a time, each click path tested before the next.
2. **Effort as an image** (flow side: the effort comes from the track).
   - Per gear, the grid's surface is cut at two scales: the grounds (broad) and the tow lanes and ridges (fine).
   - Measured against the names: the share of a name's positions in its best region, and whether parents and
     children nest as the regions do.
   - Written as its own table beside the gazetteer, which stays preprocessing. Whether the lanes go flow-side is
     TODO 144's ask.
3. **MFRI's depth model** in place of GEBCO for the seabed columns (depth, slope, BPI), with plan 043 §3.4's terrain
   test measured again.
4. **EUSM's habitat** (or MFRI's own substrate map, if one exists) as a boundary auxiliary: a footprint's edge where
   the substrate changes together with the effort or the depth.
5. **The model** of §2, fitted and compared with version 2 on the reviewed cases and the 2022 readings.

## 4. Asks

- a. **Where MFRI's depth model lives:** its name, path or schema, format, resolution, coverage and terms of use.
  `needs: maintainer`.
- b. **Whether MFRI has a substrate or habitat map** better than EUSM for Icelandic waters.
- c. **Who reviews,** and whether a reviewer's name is kept with each answer (`overrides/` lives in the repo).

## 5. Not in this plan

- Publishing the gazetteer or the review page outside MFRI: plan 001's boundary, and the names' sources (Trackwell,
  plotters) are internal.
- The originals still in `~/stasi/ornefni` (plan 043 ask a).
