# 146 — Co-location becomes rb_link_vessel_tracks(), the set finder is measured, and ramb's data are parquet (ramb 2026.10.16-.16.1; plan 013 item 8)

*2026-10-16, recorded 2026-10-19 when the session closed. A side session of plan 022, on the maintainer's brief and
an agreed design; built, measured and recorded by Claude (AI-assisted), in ramb only. ramb a68d1f6, 14 commits ahead
of its origin: not pushed, not installed. The data on disk are still built with 2026.10.15.1 (AGENTS.md). Working
files: `$FISHYDATA/archive/2026-10-16-ramb-proximity/` (README).*

## Built in ramb

Two tasks, two functions, one private engine (`.rb_near_pairs()`, `R/near.R`): every pair of points within a
distance, and a time, on ramb's sphere. Its blocks are derived from the tolerance at each latitude and wrap at ±180;
it equals a full cross join from the equator to 89.95° N. The fixed box and the cos(65°) block width of the two
hand-written versions are gone.

- **`rb_link_vessel_tracks(x, y)`**, new. Two feeds' ids are linked where their moving pings meet. Per (id_x, id_y,
  month): `hits`, `opportunity`, `score = hits / opportunity`, a rank, the best other id with its score, and
  `strong`. It generalises W1 (`audit_w1_month()`, decision 047) and plan 022 §3's run by MMSI, with their
  defaults.
- **`rb_link_record_sets()`**, extended. The haul's line can come from its pings, a line through them or its
  declared positions (`method`, a cascade). `skip_approach` drops the pass that leads straight into the haul;
  `max_pass_pings` caps a pass's length in the score. iapesca's defaults are kept. With them the output equals
  2026.10.15.1's on 129 labelled hauls at five ping rates.
- **ramb's data**, all parquet in `inst/extdata` under Git LFS (the maintainer's choice), read with
  `rb_read_example()`; `data/` is gone (breaking: `ramb::dansk` is `rb_read_example("dansk")`). One data dictionary
  (`inst/extdata/data-dict.yaml`, the data-dict spec) gives each dataset's columns, licence and sources. The sources
  are BibTeX in `inst/REFERENCES.bib`, checked against the publishers. From it come a help page per dataset, each
  file's own parquet metadata and a catalogue. Three labelled tracks were added: WKSSFGEO2 pots, WKSSFGEO pots and
  dredges, and IRD drive-in gillnets. `benthis_parameters` gained the standard errors and n of Eigaard et al.
  (2016), Table 4.

## W1 reproduced, March 2014

Same inputs: the raw STK dump, `staging/ais/ping_union`, W1's box. Only two choices of W1's differ.
1. W1 counts distinct times; the function counts rows. 52,670 of the month's 1,127,451 STK rows (4.7 %) repeat
   another exactly. With them dropped first, as the flow does: the same 681 pairs, the same opportunity in all 681,
   the same 221 strong pairs.
2. W1 also counts STK pings in the 10 minutes either side of the month. Given the same margin, all 1,596 pairs with
   a hit have the same hits. The haversine and the per-latitude blocks changed no hit.

## The set finder measured

Right = the found pass overlaps the labelled set run, or (Iceland) lies within an hour of the declared set time
`t1`. That is agreement with the labels and the logbook, not accuracy.

| hauls | defaults | no cap | skip the run in, no cap | declared positions |
|---|---|---|---|---|
| labelled pots, 56 (≤ 60 s) | 13 | 33 | 40 | 12 |
| labelled drive-in gillnets, 72 | 70 | 67 | 2 | 69 |
| Iceland 2023 longlines, 7,721 (~6 min) | 2,030 | 3,674 | 3,752 | 899 |
| Iceland 2023 gillnets, 6,352 | 1,069 | 1,040 | 1,413 | 682 |
| Iceland 2023 pots, 496 | 5 | 5 | 5 | 2 |

The Icelandic hauls are those of 2023 whose logbook declares the set time, on stations, windows and trail as built
on 2026-10-14. The findings:
- **With iapesca's score, most wrong sets are the run in to the gear.** A pass stops gaining at four pings, so the
  latest wins (longlines: 4,456 of 5,299 wrong picks end a median 0.3 h before the haul).
- **Skipping the run in helps gear that soaks and breaks gear that does not.** It is wrong for drive-in gillnets,
  where set, drive and haul are one pass.
- **Declared positions are a fallback, not a better line.** `method = c("pings", "record")` never lost on the
  labelled tracks; at 30 min it lifts the gillnets from 26 to 42.
- **The rule cannot find a set made while hauling.** 22 % of Icelandic gillnet sets and 18 % of pot sets are declared
  inside another haul window of the vessel, and a haul window is never a candidate.
- **A source defect:** the WKSSFGEO2 file holds its trip 40 twice (trip 41 = trip 40 an hour later). ramb leaves
  trip 41 out.

## Left open (TODO 72)

The defaults (skip the run in, no cap, for soaking gear); a set inside another haul's window (a rule change, design
first); fishycode on these functions (W1 and plan 022 §3, by a decision when switched). ramb's push and install
also wait. GitHub must first include LFS objects in its archives, since `rb_predict_gear_width()` now reads parquet
lookups. On install, `curate/checks/whack_demo.R` needs `whacks1 <- dplyr::collect(rb_read_example("whacks1"))`.
Two ramb articles, `sets.qmd` and `vessels.qmd`, are drafts in ramb's working tree, uncommitted for review. The
dictionary's licence `todo` for MFRI's survey data and Eigaard's Table 5 standard deviations are not settled.
