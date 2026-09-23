# Track interpolation moved from an inline `group_modify()` into `ramb`

*Decided and implemented 2026-09-23.*

## What was wrong

`curate/logbook_sensor_gps.R` interpolates lon/lat for the afli GPS logger
from the merged AIS track (`curated/ais/ping`), bounded per voyage. It did
this with `group_by(vid, trip) |> group_modify(...)`, and inside the
`group_modify` closure it re-filtered the *entire* year's track table —
`tk[tk$vid == key$vid & tk$trip == key$trip, ]` — from scratch, once per
`(vid, trip)` group. That is O(groups × track_rows), not O(track_rows).

It went unnoticed because early years are small. Measured live, rebuilding
this stage year by year: 2011→2012 took 69s, then 2012→2013 took **420s**,
tracking track/trip-count growth almost exactly as the O(groups × rows)
model predicts. Later years (2017 in particular) would have been far worse.

## What changed

The logic moved to `ramb::rb_interpolate_track()` — same rule as everywhere
else in this project's `AGENTS.md`: shared functions live in `ramb`, not
copied into a script here. It dispatches on input class, same shape as
`ramb::whack_fwdbwd()`:

- **data.frame**: the track is grouped/sorted **once**, duplicate
  `(group, time)` rows averaged (matches `approx(ties = mean)`), then a
  compiled core (`src/interpolate_track.cpp`, Rcpp) does a single pass —
  binary search per event within its group's slice, then linear
  interpolation. `rule = 1` (no extrapolation) preserved exactly.
- **tbl_lazy** (DuckDB): two `ASOF LEFT JOIN`s (one each direction) find the
  bracketing track point per event, interpolation formula in SQL. Not used
  here yet — `logbook_sensor_gps.R` already works entirely with collected
  data frames — but available for a future fully-lazy rewrite.

Verified against a direct transcription of the original `group_modify()`
logic on: the normal case, exact-timestamp matches at both ends,
single-point groups, an event group entirely absent from the track,
duplicate track timestamps, and empty input. On real 2013 data (318 trips,
20,654,036 track rows, 3,638,032 logger fixes): **420s → 45.8s** (~9.2×).

Lower than `whack_forward`'s ~1000× speedup (same session, same cause —
`curate/ais_ping_clean.R`'s pass 2 was a plain R sequential loop) because
real trips here are few and very large (≈65,000 track points per trip on
average that year), not many small ones — the binary search still does
real work per lookup, it just isn't redundant across groups anymore.

## What this doesn't fix

Nothing about the *data* changed — same interpolation, same `rule = 1`
semantics, same `dt_sec` bracketing-gap metric. This is purely the O(groups
× rows) → O(rows) fix `TODO.md`'s tracking of it called for. `ramb`'s
`TODO.md` still has the DuckDB ASOF path as unused-but-available, in case a
fully lazy rewrite of this stage is wanted later.
