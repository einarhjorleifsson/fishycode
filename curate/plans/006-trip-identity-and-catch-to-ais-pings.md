# 006 — Trip identity across systems, and splitting catch onto AIS pings

**status:** proposal — nothing built · **2026-09-25** · **see:** `curate/decisions/
007-hid-maps-to-pid.md`, `010-time-variable-naming.md`, `015-identity-is-separate-
from-the-key.md`, `028-join-key-naming-aligned.md`; `curate/plans/
002-the-last-mile.md`, `004-behavioural-fishing-windows.md`; `docs/grammar.qmd`
("Landings", "The AIS location window"); `TODO.md` items 16, 18

**Measured** — 2026-09-25, against the real `curated/` parquet:

- `logbook/trip.parquet..tid`: 1,820,387 rows, 1,813,822 distinct (6,565 duplicated).
- `link/trip_voyage.parquet` link rate by schema, after the 028 rebuild: `afli`
  39.3%, `fs_afladagbok` 97.7%, `adb` 98.7% (`curate/link_trip_voyage.R`'s own
  report, `tar_make()` output, 2026-09-25).
- `curated/logbook/fishing_sample.parquet` carries `t1`, `t2`, `t3`, `t4` today;
  it does **not** carry `w1`/`w2` — the AIS-location-window columns `docs/
  grammar.qmd` §"The AIS location window" specifies. Checked by column list, not
  inferred.
- `reference/gear/mapping.R` does not carry `s1`/`s2` (gear speed window) —
  already measured by plan 002 §4, table row `00_DATASET_gear.R`, confirmed again
  here by grep.
- `sources/aflagrunnur/convert.R:15` derives landings' own `.tid` as `min(.lid)`
  within `(vid, date, hid)` — independent of and not derived from
  `logbook_trip..tid` in any way.

**Assumed** — everything about *how well* station-level linking would perform
relative to the trip-level `link_trip_voyage` overlap match (§4 proposes the
measurement, none has been run), and the actual catch-allocation formula once
pings are joined (§6 — deliberately left open).

## 1. The naming problem this plan starts from

`docs/grammar.qmd`'s Landings section already says this, and has since before this
plan existed:

> "A synthetic `.lid` can be assigned after de-duplication, but the link to a
> specific trip is made via those natural keys, not via `.tid`."

`sources/aflagrunnur/convert.R` does exactly what that sentence warns against: it
collapses multiple `.lid` records sharing one `(vid, date, hid)` into a
landing-trip group and names that group id `.tid` — squatting on a name that
`curate/decisions/028` established is reserved, system-wide, for the logbook's own
trip identifier. The code drifted from a rule that was already written down; the
grammar doesn't need to change on this point, the code does.

**Action 1 (small, do first): `.tid` → `.tid_land` in `sources/aflagrunnur/
convert.R`.** Drop the now-redundant `rename(.tid_land = .tid)` in `curate/
link_lid_map.R:63` and `curate/catch_by_species_trip.R:47`. Add the grammar's
missing description of the collapse step itself (§7).

## 2. Three identifier shapes, not two

The `.tid` fix generalizes. This pipeline has three systems that each have their
own notion of "a trip", and they are not interchangeable:

| System | Trip identity | Shape |
|---|---|---|
| Logbook | `.tid` | single synthetic column (string) — reserved, per §1 |
| Landings | `.tid_land` (after §1's fix) | single synthetic column (numeric) |
| AIS | `(vid, year, trip)` | composite natural key — no single column exists |

The rule that keeps this safe: **no two of these are ever the same value space,
even where they overlap in real-world meaning, so they are never joined directly
and never share a column name.** Every correspondence between two of them is an
inferred *match*, computed once and stored as its own crosswalk table carrying
both sides' native key shape — not a rename that makes them look identical.
`link_lid_map.parquet` (`.tid` ↔ `.tid_land`, fuzzy vid×date×hid cascade) and
`link_trip_voyage.parquet` (`.tid` ↔ `(vid, year, trip)`, fuzzy temporal overlap)
are both already exactly this shape. Nothing here proposes changing that pattern —
only naming it, so the next system added follows it instead of re-deriving it
one collision at a time.

**A smaller naming note, not a collision:** `reference/gear/mapping.R` is
expected to eventually carry `s1`/`s2` — a gear's speed threshold in knots, per
plan 002 §4's port list. `docs/grammar.qmd`'s own column vocabulary already uses
`s1`/`s2` for a *station's* outer time bounds. The maintainer's read (2026-09-25):
gear speed thresholds are a small support/lookup table, not something that has to
sit in `fishing_sample` or any other main curated table alongside the station-level
`s1`/`s2` — so the two names likely never end up in the same table at all, and
this is worth a note, not a fix. Named here only so it isn't rediscovered as
alarming later.

## 3. What splitting catch onto pings needs, by source

The maintainer's stated goal: split the catch reported in either the logbook or
the landings register across the AIS pings that were actually fishing, at
whichever granularity each source actually supports.

- **Landings has no finer structure than a trip.** `landing_catch` is one row per
  species per landing-trip; there is no station/event breakdown, so the *only*
  granularity available is trip-level: split a trip's landed catch across every
  AIS ping belonging to the AIS voyage that trip matched to. That match is two
  hops today — `landing_landings..tid_land` → `logbook_lid_map` → `.tid` →
  `link_trip_voyage` → `(vid, year, trip)` → `ais_trip`/`ais_ping` — compounding
  both cascades' non-match rate. There is no direct landings↔AIS crosswalk.
- **Logbook supports station-level splitting**, because `fishing_sample` carries
  gear-event times (`t1`..`t4`) per station, not just a trip window. This is
  where `docs/grammar.qmd`'s "AIS location window" and plan 002's "enrichment
  tail" both already point, and where they say two different things (§5).

## 4. The trip-level link's weak point is measured, not assumed

`link_trip_voyage.parquet` links only 39.3% of `afli` trips, against >97% for the
other two schemas. `curate/logbook.R` derives `afli` trip `T1` as "the earliest
fishing **date**" — a calendar date, no time of day — which is why `curate/
link_trip_voyage.R`'s own comment calls ~80% of `afli` trips "`T1 = T2`
(date-midnight)" and has to repair `T2` to end-of-day just to make the overlap
test non-degenerate. The time-of-day granularity that would fix this is not
missing from the data — it survives one level down, in `fishing_sample.t1`..`t4`.

**What is not yet known:** whether a station-level, gear-windowed match (§3, logbook
side) rolled up to trip level actually recovers more of that 60.7% than the
trip-level overlap heuristic does, or whether `afli`'s degenerate dates are a
symptom of a deeper gap (missing pings, not missing precision) that station-level
matching cannot fix either. This needs measuring before `link_trip_voyage.R`'s
algorithm is touched — not assumed from the mechanism being more precise on paper.

## 5. A design disagreement between two existing documents

`docs/grammar.qmd` ("The AIS location window") proposes precomputing two derived
columns on `fishing_sample`, `w1`/`w2`, collapsing the gear-class asymmetry
(mobile `[t2,t3]`, static `[t3,t4]`) into one uniform join:

```r
fishing_sample |> left_join(ais_ping, by = join_by(vid, between(time, w1, w2)))
```

`curate/plans/002-the-last-mile.md` §3 instead says the enrichment tail should
carry `t1`..`t4` raw onto the ping row, because the `fishyweb` consumer it is
modelled on filters with `between(speed, s1, s2)` (a gear-appropriate *speed*
window) **alongside** `between(time, t1, t2)` — i.e. it uses behaviour (speed) as
part of what decides a ping is "fishing", not just a fixed time window. Plan 004
goes further still: it proposes *replacing* the logbook's recorded window with one
reconstructed from the logger's own speed/heading, because the recorded window is,
in the maintainer's words, "only vaguely right" for a large share of stations.

These are not the same design, and neither doc says so. `w1`/`w2` is the simpler,
cheaper mechanism; the speed-filtered / behavioural approach is more work but
answers a real, measured problem (`logger_runs_past_the_station.yml`: the logger
over- or under-runs the recorded window on a large share of stations) that a fixed
`w1`/`w2` pair inherits unchanged. **Not resolved here** — flagging it is the
contribution; picking one is a decision for whoever builds plan 002's enrichment
tail, informed by plan 004's five measurements (none done yet).

There is direct precedent for the speed+time approach winning: the pre-restructuring
site (`heima.hafro.is/~einarhj/fishydata`) already ran this comparison for trawl
detection — speed alone (`2.625`–`5.500` kn) produces false positives near shore and
in fjords; `t1`/`t2` alone is undermined by known haul-end misreporting; the two
combined removes most of the false positives either produces on its own. That is
`fishyweb`'s actual filter (§ quoted in plan 002 §1), not a hypothetical — one more
reason to treat it as the working baseline, not `w1`/`w2`.

## 6. The catch-allocation formula itself is not designed anywhere

Every document reviewed (`grammar.qmd`, plans 002 and 004) stops at "the columns
needed to join catch onto a ping." None specifies how a station's (or a landing
trip's) total catch should be divided across the N pings that matched it — evenly,
weighted by the time-gap between consecutive pings (so a longer unobserved stretch
doesn't get proportionally more catch), weighted by speed (favouring pings inside
an inferred fishing state), or something else. This is a real design gap, not a
detail — the choice changes the spatial pattern the allocation produces. **Not
proposed here.** It belongs in whichever plan actually builds the enrichment tail
(plan 002), once §5's window question is settled, since the allocation weight and
the window mechanism are coupled (a wider window with even weighting smears catch
across more sea than a narrow one with speed weighting).

## 7. What this plan proposes doing now

1. `.tid` → `.tid_land` in `sources/aflagrunnur/convert.R` (§1); drop the two
   redundant downstream renames; rebuild `aflagrunnur`, `lid_map`,
   `catch_by_species_trip` and dependents; update `docs/data-dict.yaml` and the
   `fishyweb` data dictionary page the same way decision 028 did for `.sid`.
2. Add a short paragraph to `docs/grammar.qmd`'s Landings section describing the
   `.lid` → landing-trip collapse step and naming the result `.tid_land`
   explicitly — the model doesn't currently describe this step at all.
3. Write up the three-identifier-shapes rule (§2) in `docs/grammar.qmd` or
   `docs/data-dict.yaml`'s glossary, including the `s1`/`s2` note for whoever
   ports plan 002's gear speed windows.
4. Leave §4's measurement (does station-level matching actually beat 39.3% for
   `afli`?), §5's window-design choice, and §6's allocation formula as explicitly
   open — each is its own decision, and none should be made inside this plan.

## 8. Not proposed

- Rebuilding `link_trip_voyage.R`'s matching algorithm. §4 says what would need
  measuring first.
- A direct landings↔AIS crosswalk table. Today's two-hop path
  (`lid_map` → `trip_voyage`) works and compounds two already-measured non-match
  rates; whether that compounding is bad enough to justify a new table is a
  question for once §4 is answered, since a better trip-level logbook↔AIS match
  would shrink it for free.
- Building any part of plan 002's enrichment tail or plan 004's behavioural
  classifier. Both are already proposed elsewhere, un-started, and blocked on
  their own measurements — this plan adds the naming layer and the landings side
  they don't cover, not a competing implementation.
