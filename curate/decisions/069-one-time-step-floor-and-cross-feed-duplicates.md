# 069 — One time-step floor of 10 s in the whacky filters; a second feed's copy of a report is a duplicate, not a whacky point

*2026-10-08. Revises decision 067's filter (same recipe, new floor and names); adds two stages ahead of it in `ais_ping_clean.R`.*

## What changed

- **ramb** (`main`, `7a50541`, `d67a3fa`; pushed to GitHub 2026-10-08): the five filters are `rb_whack_clean()`, `rb_whack_sda()`, `rb_whack_forward()`,
  `rb_whack_fwdbwd()` and `rb_whack_sequential_fast()`, in line with the package's `rb_` names (the `dc_`, `mb_` and `read_is_` families are left
  as they are, by choice). The old names are `.Deprecated()` aliases. Output columns are unchanged. All five take `min_dt_s = 10`: a time step
  shorter than 10 s counts as 10 s in every speed. It replaces 1e-6 s in the forward scan, fwdbwd and sequential_fast, and argosfilter's "+1 s
  on every step" in sda. The lazy result no longer carries a `window_order()`. New `rb_distance()`: haversine metres on the filters' sphere,
  used by the two R filters that had their own copy.
- **`curate/ais_ping_clean.R`**: calls `rb_whack_clean(kn_max = 25, min_dt_s = 10)`. Ahead of it, in order: placeholder positions
  (`whack_stage = "invalid"`, `curate/corrections/ais_invalid_position.yml`), then a second feed's copy of a report (`"duplicate"`,
  `curate/corrections/ais_cross_feed_duplicates.yml`). The completion fingerprint carries every constant of the method; the ramb version is not
  in it, so a change to the filter itself must change `METHOD` (installing ramb alone re-cleans nothing).

## Why the floor

Over a step of a few seconds the position error and the whole-second timestamps dominate a speed. The old floors disagreed (1e-6 s in one
function, +1 s on every step in another), and the 1e-6 s one turned two reports of the same fix a second apart into an impossible speed.
Measured on June 2016 and June 2023 (`curate/checks/whack_floor_measure.R`): floors of 1-10 s keep no leg over 200 m at more than 25 kn; 20 s
keeps 575, 60 s 6,881. Steps under 10 s are about 1.3 % of legs, and same-second steps are almost all between two feeds. The maintainer's call:
one floor, consistent and realistic.

Against the production labels, whole record (`curate/checks/whack_floor_evaluate.R`, 543,638,789 pings, 16 min): flagged 2,873,631 (0.53 %) ->
1,448,373 (0.27 %). Given back 1,466,001: 96 % between two feeds, 92 % within 50 m of the ping before, 9 real jumps; 95 % had been flagged by
the forward scan. Newly flagged 40,743, mostly interleaved streams (decision 047); 14 were real jumps production kept. Kept legs over 1 km at
more than 25 kn 716 -> 706; kept track -0.003 %. One-feed years (2007-2012) barely change.

## Why a duplicate stage

The given-back pings are not whacky: they are the second copy of a report two networks both received. The old floor had been de-duplicating
them silently, and only where the two positions differed; where they were identical both copies stayed, in `ping_clean` and in the trail
(`ais_ping_trail.R` removes exact (vid, time) ties only). Measured over every year: 6,573,358 cross-feed copies (1.2 % of pings with a vid and a
position), 5,760,358 of them in `ping_clean` before this; median gap 1-4 s and median distance 0.1-0.4 m by feed pair. Removing them is a
declared correction, not the speed filter's job.

## Rebuilt

2026-10-08 13:17-14:20: `tar_invalidate(ais_ping_clean)`, then `tar_make_isolated()`, 14 targets, `tar_outdated()` empty afterwards and every
output file newer than the start; no deprecation warning in the log. Closing count of `ais_ping_clean.R`: 543,776,104 in = 535,618,918 kept +
8,029,391 flagged (1.48 %: 9,520 invalid, 6,573,358 duplicate, 1,015,137 vmask, 7,801 spike, 423,575 forward) + 127,795 with no vid; every year
reconciles. The duplicate count equals the DuckDB measurement exactly, and no pair the rule describes is left in `ping_clean`. The speed filter
flags 1,446,513, against 2,873,692 before (the forward scan 1,786,608 -> 423,575). Downstream: `curated/ais/ping` 535,618,918; `trip.parquet`
1,372,738 voyages (-676); `harbour_stay` 1,551,681 stays (-203); `trip_voyage` 797,420 (-10); `ping_trail` and `trail` 562,417,835 rows each
(-5,150,783), no duplicate (vid, time), no `lon == lat` row; `check_trail_agreement` 99.59 %; `check_voyage_sharing` unchanged to three decimals.
Fishing vessels faster than 25 kn (`whack_fast_vessels.R`): still 84; 8,433 real pings flagged on confirmed fast legs, now 1.9 % of their flagged
stk pings (was 0.9 % of twice as many).

## The duplicate rule moved to ramb

Same day: the rule became `ramb::rb_whack_duplicates()` (ramb `669c63a`, pushed), so it is not a function inside a script and the review
package can carry it. `ais_ping_clean.R` calls it with the same constants. Checked row for row against the `duplicate` rows on disk, every
year 2007-2026: identical (6,573,358), so nothing was rebuilt and `METHOD` is unchanged. It is not a filter for exact duplicates: `ping_clean`
holds 6,260 exact duplicate rows and 24,195 more rows sharing a (vid, time), which `ais_ping_trail.R` removes.

## Not changed

- The review copy `~/stasi/test` (anonymised examples, for colleagues) holds `rb_whack_clean()`, `rb_whack_sda()`, `rb_whack_forward()` as of
  `7a50541`; `rb_distance()` does not touch them.
- Check scripts whose heads state results from before 2026-10-08 were run with ramb `81cef38`; under the new floor they do not reproduce
  those numbers exactly, under either name. `~/stasi/wgsfd2026` pins `ramb@81cef38` and stays valid as written.
- `docs/project-review.qmd` (a dated review) and `docs/stk_data-inspection.qmd` keep the old names; the aliases run them.
- The forward scan's NA cascade (one NA position poisons the anchor until a gap of more than `max_gap_h`) is kept and documented in
  `whack_forward.cpp`; `ping_tagged` has no NA position, so it cannot fire in production.
