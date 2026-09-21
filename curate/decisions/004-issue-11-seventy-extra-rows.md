# 004 — Known issue 11 (+70 rows) solved: overlapping harbour polygons

*2026-09-21. Reproduced in a controlled rebuild, so this supersedes the earlier guess.*

## The observation

`staging/ais/ping_tagged` has exactly **70 rows more** than `staging/ais/ping_union`:

| | rows |
|---|---|
| `ping_union` | 527,960,318 |
| `ping_tagged` | 527,960,388 |

Spread over nine years: 2008 (+16), 2009 (+2), 2011 (+6), 2013 (+6), 2014 (+2),
2015 (+2), 2017 (+1), 2019 (+4), 2020 (+31).

This is the long-standing "+70 rows on trail2" of known issue 11.

## The earlier theory was wrong

It was attributed to `write_sf()` appending to FlatGeobuf, because GDAL cannot `DeleteLayer`
and a re-run doubled every `.fgb`. That is a real bug and was fixed with `delete_dsn = TRUE`,
but it is **not** this. The 70 rows appear in a clean rebuild into an empty directory, in a
parquet step that involves no `write_sf` at all.

## The actual mechanism

`curate/ais_ping_tag.R` left-joins each ping to harbour polygons:

```r
duckdbfs::spatial_join(ports, by = "st_intersect", join = "left")
```

**The harbour polygons in `staging/aux/ports.fgb` overlap.** A ping inside more than one
polygon matches each of them, and a left join emits one row per match. Example, vid 7566:

| vid | time | lon | lat | pid | hid |
|---|---|---|---|---|---|
| 7566 | 2020-07-13 22:27:59 | -23.6 | 64.8 | IS-HEN | 39 |
| 7566 | 2020-07-13 22:27:59 | -23.6 | 64.8 | IS-HEA | 41 |
| 7566 | 2020-07-13 22:27:59 | -23.6 | 64.8 | IS-HNI | 71 |

One ping, three harbours, three rows. Both `h3` and `depth` are identical across the copies,
confirming the port join is the sole source: `curated/reference/area_h3.parquet` was checked
and has 26,160,965 rows with 26,160,965 distinct `h3`, so that join cannot duplicate.

In 2020: 41 duplicated ping keys in `ping_tagged` against 25 in `ping_union`, of which 16
keys are duplicated *only* by tagging, contributing the +31.

## A second, separate defect found alongside

`ping_union` **already contains 25 exactly-duplicated rows in 2020 alone**, before any
tagging. Same vid, time, lon and lat. That is a distinct problem - most likely the same fix
arriving from two providers, or one provider delivering a ping twice - and it is NOT issue 11.
Recorded here so it is not conflated with it again. Not yet quantified across all years.

## Impact

Negligible for aggregates: 70 rows in 528 million is 1.3e-7.

Not obviously harmful for trip building either. `ais_trip.R` derives harbour runs from
`in_harbour = !is.na(pid)` and collapses each run with `summarise(pid = max(pid))`, so three
consecutive rows at one timestamp behave as one harbour ping. But the choice of *which*
harbour a visit is attributed to becomes arbitrary - `max(pid)` picks the alphabetically
largest code, which is not a decision anyone made.

## Not fixed yet — this needs a decision

Two options, and they are not equivalent:

1. **Deduplicate after the join.** One row per ping, choosing a harbour deterministically -
   smallest containing polygon is the defensible rule, since a ping inside a small berth
   polygon and a large bay polygon is really in the berth. Cheap, local, and makes `hid1`/`hid2`
   on voyages meaningful.
2. **Fix `ports.fgb`.** Resolve the overlaps in the source geometry. Correct at the root, but
   it is reference data with its own provenance, and the overlaps may be deliberate
   (a harbour inside a fjord inside a bay).

Option 1 does not preclude option 2. Neither is done; the rebuild was allowed to proceed with
the 70 rows present, because they cannot move any number that matters and the harbour-choice
rule deserves a deliberate answer rather than a passing one.


---

## Addendum 2026-09-21 — root cause found, and it is one record

The diagnosis above said "overlapping harbour polygons". That was right about the
*join* behaviour and wrong about the *cause*. The three harbours are not three
polygons that happen to overlap. They are **the same polygon, duplicated under three
different harbour identities**:

| pid | port | hid | source | priority | centroid | area km2 |
|---|---|---|---|---|---|---|
| IS-HEN | Hellnar | 39 | einar | 1 | -23.644, 64.751 | 0.143 |
| IS-HEA | Hellissandur | 41 | einar | 1 | -23.644, 64.751 | 0.143 |
| IS-HNI | Hnífsdalur | 71 | einar | 1 | -23.644, 64.751 | 0.143 |

Identical centroid, identical area. Hnífsdalur is in the Westfjords, roughly 150 km
from the other two, so this is not adjacency - Hellissandur and Hnífsdalur have been
assigned Hellnar's geometry.

Scope, measured over the whole source: of kaenugardr's 159 Iceland/Faroe ports,
**156 have a unique geometry**. This is the only duplicate, and it covers exactly
these 3. The entire +70-row defect is one bad record.

**This is worse than the row count suggests, in one direction and better in another.**
Better: it is not a systemic overlap problem and needs no selection rule for Iceland.
Worse: Hellissandur and Hnífsdalur have **no correct polygon at all**, so vessels
genuinely at those two harbours are never detected as being in harbour, which affects
trip segmentation rather than just row counts. That impact has not been quantified.

The fix belongs upstream in kaenugardr, not in this pipeline. Recorded in TODO item 3b.
