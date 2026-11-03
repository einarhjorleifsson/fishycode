# grid.R — the depth grid on lon/lat cells for the bathymetry map: the Olex 50 m grid with GEBCO (TODO 185) averaged
# into 0.002-degree cells, and a 0.01-degree copy for the far zooms. A first view, before the topography tiles.
# TODO 185.
#
# Input:  $FISHYDATA/raw/external/bathymetry/Olex_50mBM_GEBCO_interp.tif (EPSG:5325, 50 m, metres, negative below sea)
# Output: $FISHYDATA/products/bathymetry_map/grid.parquet and grid_010.parquet: per cell ix, iy (its lower-left corner
#         in thousandths of a degree), depth (metres, positive down, the mean of the cell) and n (the 0.002-degree cells
#         in it, 1 in grid.parquet); cells at or above sea level are left out
#
# Run from the fishycode root: Rscript products/bathymetry_map/grid.R (gdalwarp on the PATH)

source("R/paths.R")

src <- fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif")
out <- fd_path("products", "bathymetry_map")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# Warp ------------------------------------------------------------------------------------------------------------

# -tap puts the cell edges on multiples of 0.002, so a cell's corner is a whole number of thousandths
warped <- tempfile(fileext = ".tif")
st <- system2("gdalwarp", c("-q", "-t_srs", "EPSG:4326", "-tr", "0.002", "0.002", "-tap", "-r", "average",
                            "-ot", "Float32", "-wm", "1024", "-co", "COMPRESS=DEFLATE", "-co", "TILED=YES",
                            shQuote(src), shQuote(warped)))
if (st != 0) stop("gdalwarp failed")

# Cells -----------------------------------------------------------------------------------------------------------

r <- terra::rast(warped)
d <- terra::as.data.frame(r, xy = TRUE, na.rm = TRUE)   # cell centres
names(d) <- c("x", "y", "z")
d <- d[d$z < 0, ]
d <- data.frame(ix = as.integer(round((d$x - 0.001) * 1000)), iy = as.integer(round((d$y - 0.001) * 1000)),
                depth = -d$z, n = 1L)

con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, "SET threads = 4"))
duckdb::duckdb_register(con, "d", d)
DBI::dbExecute(con, sprintf("COPY (SELECT * FROM d ORDER BY iy, ix) TO '%s' (FORMAT parquet)",
                            file.path(out, "grid.parquet")))
DBI::dbExecute(con, sprintf("
  COPY (SELECT CAST(floor(ix / 10) * 10 AS INTEGER) AS ix, CAST(floor(iy / 10) * 10 AS INTEGER) AS iy,
               avg(depth) AS depth, CAST(count(*) AS INTEGER) AS n
        FROM d GROUP BY ALL ORDER BY iy, ix) TO '%s' (FORMAT parquet)", file.path(out, "grid_010.parquet")))
DBI::dbDisconnect(con, shutdown = TRUE)
unlink(warped)
