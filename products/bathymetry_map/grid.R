# grid.R — the depth grid on lon/lat cells for the bathymetry map: the Olex 50 m grid with GEBCO (TODO 185) averaged
# into cells of 0.001 degrees of longitude by 0.0005 of latitude, about 47 by 56 m at 65 N, so near the source's 50 m
# and near square; with coarser copies for the far zooms. A first view, before the topography tiles.
# TODO 185.
#
# Input:  $FISHYDATA/raw/external/bathymetry/Olex_50mBM_GEBCO_interp.tif (EPSG:5325, 50 m, metres, negative below sea)
# Output: $FISHYDATA/products/bathymetry_map/grid_0010/ (one file per band of rows), grid_0040.parquet and
#         grid_0200.parquet: per cell ix, iy (its lower-left corner in ten-thousandths of a degree), depth (metres,
#         positive down, the mean of the cell) and n (the base cells in it, 1 in grid_0010). A level's number is its
#         cell's longitude side in ten-thousandths; the latitude side is half that. Cells at or above sea level are left
#         out
#
# Run from the fishycode root: Rscript products/bathymetry_map/grid.R (gdalwarp on the PATH)

source("R/paths.R")

src <- fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif")
out <- fd_path("products", "bathymetry_map")
base <- file.path(out, "grid_0010")
unlink(c(base, file.path(out, c("grid.parquet", "grid_010.parquet", "grid_0040.parquet", "grid_0200.parquet"))),
       recursive = TRUE)
dir.create(base, recursive = TRUE, showWarnings = FALSE)

# Warp ------------------------------------------------------------------------------------------------------------

# -tap puts the cell edges on multiples of the cell sides, so a corner is a whole number of ten-thousandths
warped <- tempfile(fileext = ".tif")
st <- system2("gdalwarp", c("-q", "-t_srs", "EPSG:4326", "-tr", "0.001", "0.0005", "-tap", "-r", "average",
                            "-ot", "Float32", "-wm", "1024", "-co", "COMPRESS=DEFLATE", "-co", "TILED=YES",
                            "-co", "BIGTIFF=YES", shQuote(src), shQuote(warped)))
if (st != 0) stop("gdalwarp failed")

# Base cells, a band of rows at a time ----------------------------------------------------------------------------

r <- terra::rast(warped)
ix0 <- round(terra::xmin(r) * 1e4)
iy_top <- round(terra::ymax(r) * 1e4)
con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, "SET threads = 4"))
invisible(DBI::dbExecute(con, "SET memory_limit = '5GB'"))
terra::readStart(r)
step <- 2000
for (i in seq(1, nrow(r), by = step)) {
  n <- min(step, nrow(r) - i + 1)
  z <- terra::readValues(r, row = i, nrows = n)          # row by row, west to east
  keep <- which(!is.na(z) & z < 0)
  if (!length(keep)) next
  row <- (keep - 1) %/% ncol(r) + i                      # 1-based row of the raster
  col <- (keep - 1) %% ncol(r)
  d <- data.frame(ix = as.integer(ix0 + col * 10), iy = as.integer(iy_top - row * 5), depth = -z[keep], n = 1L)
  duckdb::duckdb_register(con, "d", d, overwrite = TRUE)
  DBI::dbExecute(con, sprintf("COPY (SELECT * FROM d ORDER BY iy, ix) TO '%s' (FORMAT parquet)",
                              file.path(base, sprintf("rows_%05d.parquet", i))))
  duckdb::duckdb_unregister(con, "d")
}
terra::readStop(r)
unlink(warped)

# Coarser copies --------------------------------------------------------------------------------------------------

level <- function(from, k, to) {
  DBI::dbExecute(con, sprintf("
    COPY (SELECT CAST(floor(ix / %1$d) * %1$d AS INTEGER) AS ix, CAST(floor(iy / %2$d) * %2$d AS INTEGER) AS iy,
                 sum(depth * n) / sum(n) AS depth, CAST(sum(n) AS INTEGER) AS n
          FROM read_parquet('%3$s') GROUP BY ALL ORDER BY iy, ix) TO '%4$s' (FORMAT parquet)",
    k, k / 2, from, to))
}
level(file.path(base, "*.parquet"), 40, file.path(out, "grid_0040.parquet"))
level(file.path(out, "grid_0040.parquet"), 200, file.path(out, "grid_0200.parquet"))
DBI::dbDisconnect(con, shutdown = TRUE)
