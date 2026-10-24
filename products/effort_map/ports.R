# ports.R — the effort map's ports layer: every port of the reference as vector tiles, its area where it has one and a
# point on it for the zooms where an area is too small to see.
# Plan 046, step 4.
#
# Input:  $FISHYDATA/curated/reference/port_geometry.parquet (reference/ports/ports_all.R): one row per port, its pid,
#         name, hid, UN/LOCODE, source and geometry (a point, a line or an area)
# Output: ports_load(), the ports in a temporary DuckDB table, in web mercator with their bounds, and their number (0
#         without the file);
#         port_tile(), one Mapbox vector tile (raw) with two layers: `ports`, the lines and areas, and `port_points`, a
#         point on every port; each feature with pid, port, hid, unlocode, source and kind (point, line, area)

ports_load <- function(con, file = fd_curated("reference", "port_geometry.parquet")) {
  if (!file.exists(file)) return(0L)
  DBI::dbExecute(con, sprintf("
    CREATE OR REPLACE TEMP TABLE ports AS
    WITH p AS (SELECT pid, port, hid, unlocode, source, ST_GeomFromWKB(geom) AS g FROM read_parquet('%s')),
    m AS (
      SELECT pid, port, hid, unlocode, source,
             CASE WHEN ST_GeometryType(g) IN ('POINT', 'MULTIPOINT') THEN 'point'
                  WHEN ST_GeometryType(g) IN ('LINESTRING', 'MULTILINESTRING') THEN 'line' ELSE 'area' END AS kind,
             ST_Transform(g, 'EPSG:4326', 'EPSG:3857', always_xy := true) AS g3857,
             ST_Transform(ST_PointOnSurface(g), 'EPSG:4326', 'EPSG:3857', always_xy := true) AS p3857
      FROM p)
    SELECT *, ST_XMin(g3857) AS xmin, ST_XMax(g3857) AS xmax, ST_YMin(g3857) AS ymin, ST_YMax(g3857) AS ymax FROM m",
    file))
  DBI::dbGetQuery(con, "SELECT count(*)::INTEGER AS n FROM ports")$n
}

# The two layers are written apart and joined: a tile's layers are protobuf messages, so their bytes concatenate
port_tile <- function(con, z, x, y) {
  props <- "'pid': pid, 'port': port, 'hid': hid, 'unlocode': unlocode, 'source': source, 'kind': kind"
  sql <- sprintf("
    WITH e AS (SELECT ST_TileEnvelope(%1$d, %2$d, %3$d) AS env),
    f AS (SELECT p.* FROM ports p, e
          WHERE p.xmax >= ST_XMin(e.env) AND p.xmin <= ST_XMax(e.env) AND p.ymax >= ST_YMin(e.env) AND p.ymin <= ST_YMax(e.env))
    SELECT
      (SELECT ST_AsMVT({'geometry': ST_AsMVTGeom(g3857, ST_Extent(env), 4096, 64, true), %4$s}, 'ports', 4096)
       FROM f, e WHERE kind <> 'point') AS areas,
      (SELECT ST_AsMVT({'geometry': ST_AsMVTGeom(p3857, ST_Extent(env), 4096, 64, true), %4$s}, 'port_points', 4096)
       FROM f, e) AS points", z, x, y, props)
  r <- DBI::dbGetQuery(con, sql)
  c(r$areas[[1]], r$points[[1]])
}
