# duckdbfs vs duckspatial

Notes based on hands-on use; not a complete survey of either package.

---

## What they share

Both packages wrap DuckDB and its spatial extension. Both return lazy
`tbl_duckdb_connection` objects (dbplyr-backed) that you can filter, mutate,
and summarise before calling `collect()`. Neither loads large datasets into R
memory until you ask.

---

## duckdbfs

**Purpose**: general-purpose lazy interface to DuckDB, primarily for
on-disk datasets (Hive-partitioned Parquet, CSV, JSON, remote S3/HTTP).

**Connection**: maintains one shared persistent connection via
`cached_connection()`. All `open_dataset()` / `as_dataset()` calls land in
the same connection and can therefore reference each other.

**Spatial support**: present but secondary. Call `load_spatial()` to activate
the DuckDB spatial extension, then use `spatial_join()` for point-in-polygon
and related predicates. Both inputs must already have a column named `"geom"`
of type `GEOMETRY`; create one inline with `mutate(geom = sql("ST_Point(lon, lat)"))`.

**`as_dataset()` and sf**: `as_dataset()` fails on `sf` objects — it cannot
register the `sfc` geometry column in DuckDB. Workaround: write to a
FlatGeobuf (`.fgb`) or GeoPackage and load with `open_dataset(path, format = "sf")`.
FlatGeobuf is preferred here because there are no timestamps, so the
TIMESTAMPTZ issue does not arise.

**Best fit**: data is already on disk as partitioned Parquet; you want to
filter/aggregate before pulling into R; spatial join is a secondary step on
an otherwise non-spatial pipeline.

---

## duckspatial

**Purpose**: spatial-first DuckDB interface. Richer spatial API (`ddbs_join`,
`ddbs_as_points`, `ddbs_buffer`, `ddbs_filter`, etc.).

**Connection**: creates its own connection by default (`ddbs_create_conn()`),
separate from the duckdbfs shared connection. Functions accept an explicit
`conn` argument if you want to share connections, but the behaviour is
stricter: when `conn` is not `NULL`, `x` must be a table *name* (character),
not a `tbl_lazy` — passing a duckdbfs `tbl_lazy` with an explicit `conn` will
error.

**Registering sf objects**: `as_duckspatial_df(sf_obj)` is a zero-copy
Arrow-backed registration of an in-memory sf object. `ddbs_register_table()`
does the same but is explicit about connection and table name.
`ddbs_open_dataset(path)` opens on-disk spatial files (GeoParquet, GeoJSON,
GeoPackage, FlatGeobuf, Shapefile, …) lazily.

**Geometry creation from coordinates**: `ddbs_as_points(tbl, coords = c("lon", "lat"))`
converts a data frame or `tbl_lazy` to a duckspatial geometry — but only when
`conn = NULL` (duckspatial resolves the connection from the object itself). The
equivalent in duckdbfs is the inline `sql("ST_Point(lon, lat)")` in a `mutate`.

**`ddbs_join` vs `spatial_join`**: `ddbs_join` is richer (more predicates,
`mode` argument, returns `duckspatial_df`) and handles CRS tags more
transparently. `duckdbfs::spatial_join` is simpler and requires both tables to
already have a `"geom"` column; it casts both to plain `GEOMETRY` before
joining, which sidesteps CRS-tag conflicts.

**Best fit**: working primarily with in-memory sf objects that you want to
push into DuckDB for joins or spatial operations; you want the richer spatial
API; you are not integrating with a pre-existing large duckdbfs pipeline.

---

## Mixing the two

Mixing is awkward because of the separate connections. The safest pattern:

- **Large on-disk data** (e.g. `data/trail`): stay entirely in duckdbfs.
  Bring small reference sf objects in via `write_sf → open_dataset(format = "sf")`.
- **In-memory sf objects only**: use duckspatial; let it manage its own
  connection.
- **Avoid** passing a duckdbfs `tbl_lazy` to a duckspatial function with
  `conn` set — it errors. Without `conn`, duckspatial may attempt to create a
  new connection that cannot see the duckdbfs-registered tables.

---

## Spatial join on lazy vs materialised data

**TL;DR**: `duckdbfs::spatial_join` is deterministic on materialised (on-disk)
Parquet, but produces apparently inconsistent results when the left-hand table
is a complex nested lazy query.

### Root cause

A `tbl_lazy` is not a result — it is a query that is re-executed every time it
is evaluated. When a spatial join is built on top of another lazy query and then
used as the basis for a second spatial join (e.g. in a sanity check), DuckDB
executes the full pipeline twice. The two executions can disagree on boundary
cases due to parallel thread scheduling and R-tree traversal order, making the
result appear non-deterministic.

### How to test correctly

Materialise the intermediate result before re-using it:

```r
# 1. run the join and write to disk
duckdbfs::write_dataset(x_joined, "path/to/output")

# 2. re-open the materialised result for any further checks
x_mat <- open_dataset("path/to/output")
x_mat |>
  filter(is.na(result_col)) |>
  mutate(geom = sql("ST_Point(lon, lat)")) |>
  duckdbfs::spatial_join(ref, by = "st_intersects", join = "left") |>
  filter(!is.na(result_col)) |>
  count()   # should be 0
```

### General advice

Avoid chaining a second `spatial_join` on top of a lazy query that already
contains a `spatial_join`. Write to Parquet between stages.

---

## Quick reference

| | duckdbfs | duckspatial |
|---|---|---|
| Primary use | on-disk parquet/CSV datasets | in-memory sf / rich spatial API |
| Connection | shared `cached_connection()` | own connection (or explicit `conn=`) |
| Register sf | ✗ `as_dataset()` fails on sfc | ✓ `as_duckspatial_df()` / `ddbs_register_table()` |
| Open spatial file | `open_dataset(path, format = "sf")` | `ddbs_open_dataset(path)` |
| Geometry from lon/lat | `mutate(geom = sql("ST_Point(lon, lat)"))` | `ddbs_as_points(tbl)` |
| Spatial join | `spatial_join(x, y, by = "st_intersects")` | `ddbs_join(x, y, join = "intersects")` |
| Result class | `tbl_duckdb_connection` | `duckspatial_df` + `tbl_duckdb_connection` |
| TIMESTAMPTZ caution | yes — use `write_dataset()` for POSIXct | not encountered |
