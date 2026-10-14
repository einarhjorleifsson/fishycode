# 103 — Plan 013's remaining items: what was built, measured, and left for the maintainer

*2026-10-14. Built and measured by Claude (AI-assisted) on the maintainer's go ("go for the whole thing"). ramb
2026.10.14.10-.14 and fishymodel 2026.10.14 are committed, not pushed. Items 1-3 and 5 are in decisions 099-102.*

## Item 0: the step registry covers the flow

- 18 step functions check their input against the registry before any work. The other rows are tools and readers.
- A shared misuse test runs 17 of them on a table without its columns (`rb_link_trip_landings()` first checks its two
  key arguments).
- A missing column stops with a message that names it under the user's name and, where a step adds it, that step.

## Item 4: records checked against the operations the track shows (first step: measured)

June 2023, bottom trawl and the other towed gears, read-only. The track's towing stretches were cut on the voyage
gear's speed range with no prior (`rb_cut_record_stretches()`), and set against the declared tows.

- **Per vessel-day,** 1,183 vessel-days hold 4,237 declared tows and 5,965 stretches.
  - Bottom trawl: 57 % of vessel-days show more stretches than tows, 30 % as many, 11 % fewer.
  - A count alone is no evidence: one tow often breaks into several stretches at speed dips (decision 090).
- **Within a timed tow's own window:** 420 of the 4,237 records (9.9 %) hold two or more separate stretches of 30 min
  or more. Their median length is 6.8-13.6 h, against 2.2 h for the rest.
  - These are the records most likely to stand for several tows.
  - The day-level records need no such test: a day unit already shares its catch over all the day's fishing fixes.
- **Not built:** the ramb step that gives each record its case (as many, summary, unseen). When a stretch with no
  declared tow is an unlogged tow, rather than searching or a slow steam, needs ground truth (TODO 60).

## Item 6: which vessels fish (a check, built)

`curated/check/vessel_activity.parquet` (target `check_vessel_activity`) holds one row per vessel-year: whether it
lands or keeps a logbook, its home port, its share of day trips, and a suggested class. The port lists are the
maintainer's of 2026-10-14. It reports; it does not correct.

| period | fishing (voyages) | whale watching | aquaculture service | other, no fish |
|---|---|---|---|---|
| 2008-2012 | 317,651 | 13,974 | 4,141 | 20,812 |
| 2013-2020 | 501,625 | 50,779 | 22,832 | 52,426 |
| 2021-2025 | 236,949 | 38,576 | 30,622 | 39,307 |

In 2021-2025, whale watching and aquaculture service explain 69,198 of the 108,505 voyages by vessels with no
landing and no logbook. "Other" (1,768 vessel-years) is for a person to look through. Confirmed classes would
re-enter as an override.

## Item 7: records without pings (built in ramb)

- **`rb_build_record_pings()`** gives a record with no pings positions every `interval_s` over its window. They run
  along its line, or sit at its start where it has no end position, with `pos_basis = "synthesised"`. They run
  through effort and catch like any pings.
- **Not wired in fishycode:** the 1990-2006 logbook (3.5 M records, start positions only) waits for the maintainer's
  scope (are the records before 1990 in?) and a target of its own.

## Item 8: static gear (pairing built in ramb)

- **`rb_link_record_sets()`** finds each haul's set: the vessel's latest earlier pass along the haul's line, within
  240 h and a 330-550 m buffer. It is recoded from iapesca (decision 078) and tested on a synthetic gillnetter.
- **Not built:** the run on the Icelandic static hauls, and pressure as quantity × soak. The gear quantity (nets,
  hooks) is not yet read from the logbook.

## Item 9: track models (fishymodel; first bench)

- **fishymodel fixed:** `fm_gaussian()` read each step's speed as length / 60 s, as if pings were a minute apart. It
  now uses each step's own time. The HMM functions say they need equally spaced pings.
- **Bench:** June 2023, 20 bottom trawlers, 79 voyages, tracks interpolated to one minute (`rb_interpolate_track()`).
  Each method is scored against the recorded tow windows.

  | interval | method | sensitivity | specificity | balanced accuracy |
  |---|---|---|---|---|
  | 1 min | Gaussian mixture per voyage (`fm_gaussian`) | 0.77 | 0.67 | 0.72 |
  | 1 min | the gear's declared speed range | 0.94 | 0.83 | 0.88 |
  | 30 min (every 30th fix) | Gaussian mixture | 0.77 | 0.68 | 0.73 |
  | 30 min | declared speed range | 0.83 | 0.79 | 0.81 |

  Where the gear is known, the declared range beats the unsupervised mixture at both intervals. Thinning to 30
  minutes costs the range 8 points and the mixture almost nothing. The models matter where the gear or its range is
  unknown, not for Icelandic trawlers with a logbook.
- **Not run:** the HMMs, and the other gears. A model's output would enter the flow as one more approach column.

## Item 10: declared times against the track

Blocked on ground truth (TODO 60): unchanged.

## Answered by the maintainer (2026-10-14)

- **Push** ramb and fishymodel: no, not now.
- **Foreign logbooks:** yes, acquire them (TODO 62; where they are is asked).
- **The years before 1990:** not in scope.
- **Raise factors above 10:** the maintainer pointed at the pelagic species (30-36), the only fisheries where
  transhipment is expected. Measured per trip and species: pelagic logged and landed weights agree within 0.5-2 for
  23,682 trip-species (9.8 Mt landed). Only 8 sit near the ×1,000 of a tonnes/kilograms mix. The outliers come in
  pairs that look like transfers: 2,548 landed 2-300 times what they logged (1.0 Mt landed, 0.19 Mt logged) and
  1,032 logged more than twice what they landed. The demersal factors above 10 are small logged weights, not units.

## Asked of the maintainer (as first put)

- **Push** ramb (2026.10.14.6-.14, 9 commits) and fishymodel (1 commit) to GitHub?
- **Foreign logbooks** from Fiskistofa: acquire them, as a `dump/` script and a source adapter? They would move most
  landing-only catch onto the record path.
- **The years before 1990** for item 7: in scope?
- **The suggested vessel classes** in `vessel_activity`: review, and confirm through an override?
- **Raise factors above 10** (688,292 rows): a condition or unit difference by species? Correct, or leave as data?
