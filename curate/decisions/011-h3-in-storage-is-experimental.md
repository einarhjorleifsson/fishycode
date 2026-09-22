# 011 — H3 in storage is experimental, and res 8 is a quantisation, not a tag

*2026-09-22. Maintainer's call, in response to the open question in
`curate/plans/002-the-last-mile.md` §3. Nothing is changed yet; this record exists so
the provisional choice does not harden into a commitment by going unmentioned.*

## The decision

**H3 on a stored ping row is experimental.** It may be dropped. Nothing downstream
should be written that assumes a ping carries an `h3` column.

## What H3 is actually doing, which is two different jobs

Measured by reading the chain on 2026-09-22:

1. **A transient join key.** `curate/ais_ping_tag.R:46` computes
   `h3_latlng_to_cell_string(lat, lon, 8L)` for each ping and immediately
   `left_join`s `curated/reference/area_h3.parquet` to pick up `depth`, `bbht` and
   `fao`. This job is load-bearing — it is how a ping gets any spatial attribute at
   all.
2. **A retained column.** `curate/ais_ping_clean.R:58` then carries `h3` forward into
   the clean ping table, so it survives into storage.

Only the second is the experiment. Nothing in this repo reads a ping's `h3` after the
join, and no written analysis wants res 8: the posts derive their own cells in one
line, at res **5** for overview and **9** for detail. A stored res-8 string is a
resolution nobody asked for, on every row.

## The part that is not a storage question

`area_h3.parquet` is keyed on res-8 cells, and `reference/geo/h3_index.R:39` builds it
by averaging GEBCO depth **within** each res-8 hexagon. So depth on a ping is not the
depth at the ping — it is the mean depth of a hexagon of roughly 0.4–0.5 km². The same
holds for `bbht` and `fao`, both sampled at the cell centre.

That is an analytical commitment wearing the clothes of a storage choice, and it is the
real reason to hold res 8 loosely. Two consequences follow:

- **Dropping the column is cheap; changing the grain is not.** The stored `h3` can go
  tomorrow with nothing downstream affected. Changing *what resolution the spatial
  attributes are computed at* means rebuilding `area_h3.parquet`.
- **Which is now possible, as of 2026-09-22.** This record originally said the grain
  could not be revisited because the GEBCO raster was gone. It was not gone
  (`002-missing-gebco-raster.md`), and `area_h3.parquet` has since been rebuilt from it
  in 7m30s, reproducing the seeded table exactly. So changing the resolution is a
  7-minute rebuild, not an impossibility. The decision to hold res 8 loosely stands on
  its merits; it is no longer propped up by a missing file.

## What this means for the work in plan 002

- The enrichment tail must not add anything keyed on a ping's `h3`.
- Whether the published sweep keeps the column is deferred, not decided. If it is
  kept, it is kept as an internal artefact and documented as such, not as an
  analysis-facing column.
- Worth measuring when the machine is available, and not asserted here: what the
  column actually costs in the written parquet. Dictionary encoding may make it
  nearly free, in which case "drop it" is about clarity rather than size.
