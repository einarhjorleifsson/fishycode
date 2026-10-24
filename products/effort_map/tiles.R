# tiles.R — one vector tile of the effort map: the base grid summed to a cell size that suits the zoom, in the tile.
# Decision 220.
#
# Input:  $FISHYDATA/products/effort_map/grid.parquet (grid.R), and grid_005.parquet, its 0.005-degree copy, for cells
#         of 5, 10, 15 ...
#         thousandths: a coarse cell holds its 0.005-degree cells whole, so the sums are the same, from 14 % of the rows
# Output: effort_tile(), a Mapbox vector tile (raw) with one layer, `cells`: per cell h_km2 and kwh_km2, hours and
#         kW-hours per square kilometre, so a colour holds across zooms, and n, the fixes summed

# The cell side in thousandths of a degree: about `px` screen pixels (a tile is 512), from a few round sizes, never
# below the grid's 0.001. Measured 2026-10-24, the worst tile at zoom 5-8: px 1 (the page's default) 3.5-5 MB in
# 0.2-0.5 s; px 0.5 up to 25 MB in 1.3 s; px 2 about 1 MB.
CELL_K <- c(1, 2, 3, 4, 5, 7, 10, 15, 20, 30, 40, 50, 70, 100, 150, 200, 300, 500, 1000)
cell_k <- function(z, px = 1) {
  target <- 360 / 2^z / 512 * px * 1000
  max(CELL_K[CELL_K <= max(target, 1)])
}

tile_bounds <- function(z, x, y) {
  n <- 2^z
  lat <- function(t) atan(sinh(pi * (1 - 2 * t / n))) * 180 / pi
  c(lon0 = x / n * 360 - 180, lon1 = (x + 1) / n * 360 - 180, lat0 = lat(y + 1), lat1 = lat(y))
}

effort_tile <- function(con, grid, z, x, y, preset = "fishing", gid = NULL, y1 = NULL, y2 = NULL, px = 1) {
  k <- cell_k(z, px)
  coarse <- sub("[.]parquet$", "_005.parquet", grid)
  if (k %% 5 == 0 && file.exists(coarse)) grid <- coarse
  b <- tile_bounds(z, x, y)
  ix0 <- floor(b[["lon0"]] * 1000 / k) * k - k; ix1 <- ceiling(b[["lon1"]] * 1000 / k) * k + k
  iy0 <- floor(b[["lat0"]] * 1000 / k) * k - k; iy1 <- ceiling(b[["lat1"]] * 1000 / k) * k + k
  where <- c(sprintf("preset = '%s'", preset),
             # half-open: whole cells only, so the fine grid and its coarse copy give the same sums
             sprintf("ix >= %d AND ix < %d AND iy >= %d AND iy < %d", ix0, ix1, iy0, iy1),
             if (length(gid)) sprintf("gid IN (%s)", paste(gid, collapse = ", ")),
             if (!is.null(y1)) sprintf("year BETWEEN %d AND %d", y1, y2))
  sql <- sprintf("
    WITH c AS (
      SELECT floor(ix / %1$d) AS cx, floor(iy / %1$d) AS cy, sum(h) AS h, sum(kwh) AS kwh, CAST(sum(n) AS BIGINT) AS n
      FROM read_parquet('%2$s') WHERE %3$s GROUP BY ALL),
    g AS (
      SELECT *, cx * %1$d / 1000.0 AS lon0, (cx + 1) * %1$d / 1000.0 AS lon1,
                cy * %1$d / 1000.0 AS lat0, (cy + 1) * %1$d / 1000.0 AS lat1 FROM c),
    m AS (
      SELECT h, kwh, n,
             (%1$d / 1000.0 * 111.32 * cos(radians((lat0 + lat1) / 2))) * (%1$d / 1000.0 * 110.574) AS km2,
             ST_MakeEnvelope(radians(lon0) * 6378137, ln(tan(pi() / 4 + radians(lat0) / 2)) * 6378137,
                             radians(lon1) * 6378137, ln(tan(pi() / 4 + radians(lat1) / 2)) * 6378137) AS env
      FROM g)
    SELECT ST_AsMVT({'geometry': ST_AsMVTGeom(env, ST_Extent(ST_TileEnvelope(%4$d, %5$d, %6$d)), 4096, 64, true),
                     'h_km2': CAST(h / km2 AS FLOAT), 'kwh_km2': CAST(kwh / km2 AS FLOAT), 'n': n}, 'cells', 4096) AS tile
    FROM m", k, grid, paste(where, collapse = " AND "), z, x, y)
  r <- DBI::dbGetQuery(con, sql)$tile[[1]]
  if (is.null(r)) raw(0) else r
}
