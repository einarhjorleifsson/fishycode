# Join-key names aligned across tables; the dot-prefix rule made explicit

*Decided and implemented 2026-09-25. Reasoning corrected the same day — see
"The reasoning was wrong" below; the fix itself (the renames in "The fix")
stands unchanged and is confirmed correct.*

## What was wrong

Three tables used different names for concepts other tables already named,
forcing every join between them to carry a cosmetic `by = c("x" = "y")`
rename — the `fishyweb/tutorials/ais_trip_tutorial` example that prompted
this is exactly that shape:

```r
one_trip |> inner_join(link |> filter(...),
  by = c("vid", "year" = "voyage_year", "trip" = "voyage"))
```

- `curated/link/trip_voyage.parquet` called the AIS voyage's own `year`/`trip`
  `voyage_year`/`voyage`, although `curated/ais/trip.parquet` already names
  them plainly (`curate/link_trip_voyage.R:76`).
- `curate/catch_by_species_trip.R` stripped the dot off `.tid`/`.tid_land`
  before writing its output, although every other logbook-derived table
  (`trip.parquet`, `station.parquet`, `lid_map.parquet`) keeps it dotted.
- `sources/aflagrunnur/convert.R` renamed two raw columns, `fisktegund`
  (species code) and `veidistofn` (fishing-stock code), to `.sid`/`.stid`.
  Both are meaningful codes, not synthetic keys — this directly contradicted
  `docs/grammar.qmd`'s own vocabulary table, which reserves `.sid` for the
  logbook's synthetic station key and bare `sid` for the species code.

## The reasoning was wrong

The first pass framed this as a generic style rule — "any dot-prefixed
column is a surrogate key, any bare column is an enum, audit every dotted
name in the repo against that axis" — and treated `sources/aflagrunnur/convert.R`
using `.sid`/`.stid` as one instance of that generic pattern to fix.

That's not what `.sid` is. `.sid` is not a category of names; it is **one
specific, reserved name** — the logbook station id, used that way in every
`curated/logbook/*` table and nowhere else — the same way `.tid` specifically
means trip id. `aflagrunnur/convert.R` using `.sid` for a species code wasn't
"on the wrong side of a surrogate/enum style axis"; it was squatting on an
already-taken name for an unrelated concept, in a table that never even joins
to the logbook tables on `.sid`. The generic framing would have licensed
renaming *any* dotted column found to violate the surrogate/enum test,
without checking whether the specific token was already spoken for elsewhere
— the real check that matters.

`docs/grammar.qmd:803-806` states the general principle correctly (dot
prefix = synthetic/derived key with no value-level meaning; bare = a code
whose value is meaningful), and it still holds as a description of what
`.tid`/`.sid`/`.lid` already are. But it's not a rule to sweep the codebase
with column-by-column — it's a description of specific, already-meaningful
names. The one-file audit this decision was based on happened to reach the
same two renames a narrower check would have, but for the wrong reason.

## Confirmed, not assumed

- **`veidistofn` (`.stid`) is an ecological population/stock within a
  species** (maintainer, 2026-09-25) — a meaningful classification, not a
  sequential key. Bare `stid` is correct on that basis alone, independent of
  the generic-rule framing above.
- **Logbook `sid` and landings' species code are the same vocabulary** — one
  official Directorate of Fisheries `tegundnúmer` list (maintainer,
  2026-09-25). `catch_by_species_trip.R`'s hypothesis test (does logbook code
  445 show up in landings as code 40?) is checking a data-quality anomaly in
  *specific* codes, not evidence of two incompatible numbering systems.
  Unifying both tables' species column under bare `sid` is therefore not just
  harmless but correct — it's one vocabulary, so one name is exactly right.

## The fix

- `curate/link_trip_voyage.R`: write `year`, `trip` — no rename.
- `curate/catch_by_species_trip.R`: keep `.tid`/`.tid_land` dotted in the
  output; the landings-side `rename(sid = .sid)` is no longer needed once
  `aflagrunnur` writes bare `sid` itself.
- `sources/aflagrunnur/convert.R`: `.sid` → `sid` (species code),
  `.stid` → `stid` (fishing-stock code).

Pure renames, no logic change. `aflagrunnur`, `trip_voyage`,
`catch_by_species_trip` and their dependents (`lid_map`,
`check_ais_key_landings`, `check_ais_key_reused_callsign`) were
`tar_invalidate()`d so the next `tar_make()` picks them up; not rebuilt here.

## Not touched, and why

- `hid1`/`hid2`/`pid1`/`pid2` and the `T1`/`T2` (trip-level, decision 010)
  convention already do the right thing — a genuine same-name collision
  between two sources gets a `_ais`-style suffix, not a different name.
- `fishyweb/tutorials/ais_trip_tutorial` lives in a separate repo
  (`curate/plans/001`, the three-repo boundary) and needs its own update
  once this lands in `fishydata` — out of scope here.
