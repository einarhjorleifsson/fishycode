# 080 — ramb's distance: one function, `method` argument; Haversine default; Karney engine; macros deferred (amends plan 013's "One distance function")

*2026-10-12. Code by Claude (AI-assisted): ramb 3afe1f2 (method argument, data-frame form), 96182b0 and
560c90e (AGENTS.md), cd51f29 and 7e4b2e2 (Karney engine), adde199 (jepol off-by-one). Amends the
"One distance function" section of plan 013 (maintainer's direction, 2026-10-09), which was written before
anything was built and which the 2026-10-12 session had not read when it started; the deviations below were
decided by the maintainer in that session, on the measurements quoted. Amended 2026-10-13 by Claude (AI-assisted),
on a review of the ramb changes: the Icelandic-latitude figure was understated and given as ±, the jepol line did
not apply to fishycode, and the speed default is reversed - `rb_calc_speed()` is geodesic again (ramb b225b37),
on a measurement against recorded speed over ground (second-last section).*

## What was done (ramb, 2026-10-12)

- `rb_calc_distance(lon1, lat1, lon2, lat2, method = c("haversine", "geodesic"))`; both vector forms
  (positional and named) unchanged. Haversine body moved verbatim to internal `.rb_haversine()` — the default
  path is bit-identical to before.
- Data-frame form: `rb_calc_distance(d, lon2 = port_lon, lat2 = port_lat)`, tidy-eval columns via `.rb_cols()`,
  `lon1`/`lat1` defaulting to `lon`/`lat`. `tbl_lazy` refused with a clear error.
- `"geodesic"` is **Karney**: GeographicLib-C v2.2's `geodesic.c/h` vendored unchanged in `src/` (MIT/X11;
  `inst/COPYRIGHTS`, Karney as `ctb` in DESCRIPTION — the plan's recorded exception to the recode rule),
  behind the Rcpp entry point `geod_karney()`. It replaced the Vincenty recode the same day that recode's
  antipode fallback was added; the fallback is gone, Karney has no convergence failure.
- `rb_calc_speed()` and `rb_calc_step_acceleration()` gained the same `method` argument, default flipped from
  geodesic to **haversine**: one sphere (R = 6,371,000 m) across distance, speed and the impossible-position
  filters. **Reversed 2026-10-13** (below): the speed default is geodesic again.
- ramb AGENTS.md records the one-sphere rule: `rb_calc_distance()` is the reference of record; the formula is
  hand-copied into `src/whack_forward.cpp`, `src/whack_sda.cpp` and the `.rb_whack_fwdbwd()` SQL on purpose
  (each backend's inner loop); tests pin them together. Also recorded: DuckDB's `LEAST()`/`GREATEST()` ignore
  NULLs, so no `LEAST(1, ...)` clamp in SQL (a NULL coordinate would become the antipodal distance).
- Tests: 215 pass; geodesic pinned to `traipse` (1e-9), C++ pinned to an R reference, SQL pinned to the
  data-frame branch. `R CMD check`: 0 errors, 0 notes, one known toolchain warning.

## Measured

- **Haversine error** (vs the ellipsoid): systematic, latitude/bearing-dependent, +0.56 % (N–S, equator) to
  −0.44 % (N–S, 80° N); independent of leg length. Consistent with the plan's 2026-10-09 table. At Icelandic
  latitudes it has one sign: haversine is shorter by 0.24 % (N–S, 63° N) to 0.40 % (E–W, 67° N), measured
  2026-10-13 with `rb_calc_distance()` both ways on 0.05° legs at 63/65/67° N and bearings 0/45/90°. (The
  first version of this record, and ramb's NEWS.md, said "about ±0.1–0.3 %".)
- **Speed**: haversine 0.015 s per million legs; Karney-in-C 0.74 s per million legs; Vincenty-in-R had been
  0.23 s per million (3.29M June-2023 legs, `staging/ais/ping_clean`). On random global pairs the ratio is
  ~40-50x; the docs say 40-50x.
- **Karney correctness**: nanometre agreement with traipse on ordinary legs; exact at the antipode
  (20,003,931 m, traipse identical); correct on the plan's near-antipodal pair (Iceland to 157.9° E, 63.95° S:
  19,997,715.092 m, where the Vincenty recode with fallback returned the haversine 20,007,690 m); max
  1.1 micrometres vs Vincenty on the 3.29M real legs.

## Where this deviates from the 2026-10-09 direction, and why

| Plan 013 direction | Built 2026-10-12 | Reason given in session |
|---|---|---|
| `method = c("geodesic", "andoyer", "haversine")`, geodesic default | Two methods, **haversine default** | One sphere across distance, speed and filters (a ping can no longer pass the filter yet compute over-threshold); ~40-50x faster; the Haversine error is a fixed latitude/bearing bias within ±0.6 %, below AIS position noise on track steps |
| Karney (vendored GeographicLib C via Rcpp), replacing Vincenty | **Done as directed** (cd51f29) | — |
| `rb_register_macros(con)` + `rb_calc_distance` DuckDB macro (4-arg default, 5th positional method; self-checking registration; `ST_Distance_Spheroid` for lazy geodesic) | Not built; lazy input errors | Judged unneeded for one SQL call site — advice given before plan 013 was re-read; the plan's tested mechanics stand as the design if lazy distance is ever wanted |
| Filters switch to exact after a counted-change study | Filters stay Haversine; `rb_calc_speed()` was moved *to* the filters' sphere instead | The opposite resolution of the same inconsistency; cheaper and keeps the tier-4 batch path as the only filter code |

## Settled alongside

- **jepol off-by-one** (plan 013's logic table: "fix in ramb as its own commit; count on dansk"): fixed in
  adde199 — a voyage over `max_dur_h` now splits at its longest gap, not one ping before it. Counted on
  `dansk` (by_year = FALSE): no cut moves at `max_dur_h = 72`, two voyages of 92 at 48, three of 93 at 24; no
  voyage gained or lost; at 24 the moved cut re-times two segments across the `min_dur_h` threshold, flipping
  two pings' at-sea status. Without splits the output is unchanged.

## Still open from the 2026-10-09 direction (deferred, not cancelled)

- **`"andoyer"`** method and **`rb_register_macros()`** (design and measured numbers in plan 013's section).
- **Counted filter switch** to exact distances (decision-069 style). With Karney in `src/`, the C++ filters
  *can* share the exact engine now; whether they should is the counted study.
- **Geodesic as default** for `rb_calc_distance()` stays decided against for now: filter consistency and speed won
  on 2026-10-12 (the speed default is geodesic again, above). The
  argument that re-opens it is the one the plan led with — the sphere's bias does not cancel in summed
  distances (track km, effort, swept area) — if those totals become a published product.
- **Stays' nearest harbour** still uses `ST_Distance` in degrees — already row 4 of plan 013's logic-question
  table ("re-choose in metres (EPSG:3575) and count").

## The speed default goes back to geodesic (2026-10-13)

The one-sphere argument holds for the filters, which only ask whether a leg is over 25 kn. It does not hold for a
speed that is kept as a value: in fishycode's `speed` column, derived speeds (astd, astdB, emodnet) sit beside
recorded speed over ground (stk, gps), and all of them are read against the gears' speed windows. The data were
asked which distance puts a derived speed on the recorded scale. Steady straight legs of STK VMS, June 2023 of
`staging/ais/ping_clean`, were used: 35,501 legs of 5-15 min at 6-15 kn, with speed within 0.3 kn and heading
within 2 degrees at both ends.

- The median ratio of derived speed to recorded SOG is 0.9978 on the sphere and 1.0011 on the ellipsoid.
- East-west legs minus north-south legs: haversine −0.085 % (95 % bootstrap −0.115 to −0.058), geodesic
  +0.019 % (−0.011 to 0.047). A speed over ground does not depend on heading, so this difference is the
  sphere's error, seen in real tracks. The geometry predicts about −0.11 % for these heading bands.
- On emodnet 2017 (19.2 M legs) the haversine default had moved 0.49 % of pings across at least one gear speed
  bound.

ramb b225b37 puts `rb_calc_speed()` and `rb_calc_step_acceleration()` back on `"geodesic"` by default (Karney,
0.74 s per million legs). The filters and the `rb_calc_distance()` default stay haversine. Moving them is the
counted filter study still open above.

## In fishycode (settled 2026-10-13)

- **`curate/ais_ping_union.R`: `rb_calc_speed(..., method = "geodesic")`, named** so that a later default
  cannot move it. A first pass of this review had named `"haversine"`, on the one-sphere argument; the
  measurement above reversed that the same day. The staged `ping_union` was built on the ellipsoid (Vincenty,
  ramb f6faf9b), within about a micrometre per leg of Karney, so code and data agree and nothing waits on a
  rebuild. This call computes the only speeds `rb_calc_speed()` makes here: emodnet 2017, 19,612,048 pings.
- **jepol:** the earlier line here ("voyage tables built with the pre-fix jepol keep their cuts") does not
  apply. `curate/ais_voyage.R` cuts with `method = "stays"`, and nothing in fishycode calls `"jepol"`, so the
  off-by-one fix reaches no fishycode output.
- `curate/checks/whack_floor_measure.R`: the local `hav()` copy can still be replaced by `rb_calc_distance()`.
  It is an evaluation script, so this is optional.
