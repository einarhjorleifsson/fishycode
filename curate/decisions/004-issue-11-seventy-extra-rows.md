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

---

## Addendum 2026-09-21 (2) — the source line found, a second defect beside it, and the scale measured

The previous addendum said "one bad record" and pointed upstream. The record has now been
located in kaenugardr's source, and the lead recorded in TODO item 4 — that a name-based
join to `ports_kvoti.parquet` produced one geometry under three identities — **was wrong**.
Recorded because the wrong lead is cheap to re-follow.

### It is a copy-paste, not a join

`kaenugardr/ports-iceland-and-faroe.R:209-215`, the `ports_add` tribble. This is a
hand-written literal listing "some ports in kvoti.stadur that is not in the stk data":

```r
ports_add <-
  tribble(~pid,    ~port, ~lat, ~lon,
          'IS-VIK', 'Vík',          63.413191, -19.005441,
          'IS-HLL', 'Hellnar',      64.751359, -23.643993,   # Hellnar
          'IS-HLS', 'Hellisandur',  64.751359, -23.643993,   # Hellisandur
          'IS-ALV', 'Aviðruvör',    65.926529, -23.610718,
          'IS-HDL', 'Hnífsdalur',   64.751359, -23.643993,   # Hnífsdalur
          'IS-OGV', 'Ögurvík',      66.043098, -22.732611)
```

Hellnar's coordinate pair is repeated verbatim on the Hellissandur and Hnífsdalur rows.
The `ports_kvoti` join is by name and is innocent: it attaches `hid` only, and correctly —
39, 41 and 71 are the right `hid` for those three names. The geometry was already wrong
before the join ran. `ports_all.R` later renames the pids globally, so these surface in
`ports_all.gpkg` as `IS-HEN`, `IS-HEA`, `IS-HNI`.

Two spelling slips sit in the same block and are harmless only because `ports_add` drops
`port` before joining on `pid`: `Hellisandur` vs `Hellissandur`, `Aviðruvör` vs `Alviðruvör`.

### Second defect, same block: the 500 m buffer is not 500 m

`ports_add` buffers in EPSG:3857 (Web Mercator), whose unit is a metre only at the equator:

```r
st_as_sf(coords = c("lon","lat"), crs = 4326) |>
  st_transform(crs = 3857) |> st_buffer(dist = 500) |> st_transform(crs = 4326)
```

At Iceland's latitudes the ground radius is `500 * cos(lat)`. Measured against the
geometries actually in `ports_all.gpkg` (areas via EPSG:3057), the fit is exact:

| pid | port | lat | area km2 | actual radius m | `500*cos(lat)` |
|---|---|---|---|---|---|
| IS-VIK | Vík | 63.413 | 0.158 | 224.2 | 223.8 |
| IS-HEN | Hellnar | 64.751 | 0.143 | 213.7 | 213.3 |
| IS-HEA | Hellissandur | 64.751 | 0.143 | 213.7 | 213.3 |
| IS-HNI | Hnífsdalur | 64.751 | 0.143 | 213.7 | 213.3 |
| IS-ALV | Alviðruvör | 65.927 | 0.131 | 204.4 | 204.0 |
| IS-OGU | Ögurvík | 66.043 | 0.130 | 203.5 | 203.0 |

All six `ports_add` harbours are **~57% too small**. This is independent of the duplicate
coordinate and survives fixing it. The 159 STK-derived (`einar`) polygons are unaffected —
their median area is 0.143 km2, so an undersized circle is not conspicuous by size alone.

### Scale: 21 trips, not 10,000

The measurement TODO item 4 asked for, against `curated/logbook/trip.parquet`
(1,815,425 trips; `hid2` = arrival harbour, populated on 1,778,986 of them):

| hid | harbour | pre-2007 | 2007+ (AIS era) |
|---|---|---|---|
| 39 | Hellnar | 156 | 17 |
| 41 | Hellissandur | 232 | 17 |
| 71 | Hnífsdalur | 4,982 | 4 |

5,408 trips in total (0.298%), but they are overwhelmingly **1975–1993** — Hnífsdalur alone
carries 4,982 arrivals in that window and 4 since. Against the 836,080 trips in the AIS era,
the two harbours with no polygon at all (41, 71) account for **21 trips, 0.0025%**.

Departure harbour `hid1` is populated on only 110,959 trips (6.1%), so arrival is effectively
the only harbour signal in this table. Noted separately; not part of this issue.

### Consequence for ordering

**Item 4 no longer blocks the trail rebuild.** The unquantified fear in the first addendum
was that two undetectable harbours would distort trip segmentation. In the era where AIS
exists at all, they are named by 21 trips. The +70 tagging rows remain cosmetic, and the
`max(pid)` attribution rule still deserves a deliberate answer — but neither is worth
holding the L1→L4 run for.

### What cannot be fixed from inside these repos

Neither harbour has an independent geometry anywhere in `ports_all.gpkg`. Searched by name
across all nine sources, and by location:

- **Hellissandur** — nothing on the north Snæfellsnes coast but Rif (`IS-RIF`, hid 42,
  -23.812/64.922, from `einar`) and Ólafsvík. UNLOCODE has a single `IS RIF`
  *"Rif-Hellisandur"* with **no coordinates**, which suggests Rif and Hellissandur may be
  one port rather than two — a domain question, not a data one.
- **Hnífsdalur** — nothing between Bolungarvík (`IS-BOL`, -23.245/66.157) and Ísafjörður
  (`IS-ISA`, -23.123/66.068), which is where it belongs.

`ports_kvoti.parquet` is `stad_nr` + `port` only, with no coordinates, so it cannot supply
them either. The correct geometries must come from outside: OSM queried directly, or the
maintainer's own knowledge. **No coordinate has been guessed here.**

---

## Closed 2026-09-21

Root cause fixed upstream and propagated. `curate/corrections/ports_iceland.R`
removes the two non-harbours and rebuffers the four hand-added ports to a true
500 m; `staging/aux/ports.fgb` now has **zero** features sharing a geometry,
where it had two.

The +70 rows **cannot recur**, but the existing `staging/ais/ping_tagged` still
carries them (527,960,388 vs `ping_union`'s 527,960,318) because
`curate/ais_ping_tag.R` has not been re-run. That re-run is TODO item 13, not a
defect. TODO item 4 is deleted as done.
