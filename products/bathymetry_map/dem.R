# dem.R — the depth grid (TODO 185) as elevation tiles: the Olex 50 m grid with GEBCO warped to web mercator at each
# zoom from 0 to 10, each zoom from the source's values (never from another zoom's tiles), encoded as Terrarium tiles
# of 512 pixels, lossless WebP, in one MBTiles file. The browser draws the shading and the colours from them (MapLibre's
# raster-dem source with hillshade and color-relief layers), so the colours stay in the page.
# TODO 185.
#
# Input:  $FISHYDATA/raw/external/bathymetry/Olex_50mBM_GEBCO_interp.tif (EPSG:5325, 50 m, metres, negative below sea)
# Output: $FISHYDATA/products/bathymetry_map/depth.mbtiles: `tiles` (zoom_level, tile_column, tile_row in the TMS
#         order, tile_data a lossless WebP) and `metadata` (format webp, encoding terrarium, bounds, minzoom, maxzoom,
#         ...). Elevation in metres, negative below sea, to 0.1 m; land and cells with no value are 0, sea level. Every tile
#         within the bounds is written, those with no depth flat at 0
#
# Run from the fishycode root: Rscript products/bathymetry_map/dem.R (gdalwarp on the PATH)
#
# Zoom 10 is the deepest: a pixel there is 32 m on the ground at 65 N, the source's cell 50 m; the page draws deeper
# zooms from it.

source("R/paths.R")

src <- fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif")
out <- fd_path("products", "bathymetry_map", "depth.mbtiles")
BOUNDS <- c(-30.87, 59.96, -5.55, 69.59)   # the cells with a value (grid.R), west, south, east, north
ZOOMS <- 0:10
SIZE <- 512
R_EARTH <- 6378137

# Tiles -----------------------------------------------------------------------------------------------------------

tile_x <- function(lon, z) floor((lon + 180) / 360 * 2^z)
tile_y <- function(lat, z) floor((1 - asinh(tan(lat * pi / 180)) / pi) / 2 * 2^z)
merc_edge <- function(i, z) (i / 2^z * 2 - 1) * pi * R_EARTH       # a tile index's west (or, flipped, north) edge

# Terrarium: elevation + 32768 = R * 256 + G + B / 256. Lossless, as an elevation in colours needs, and to 0.1 m, far
# below the data's own error: on 40 tiles of zoom 9 (2026-11-03) 0.48 of the size of full-precision PNG, which would
# have been about 1.4 GB; full-precision WebP was 0.77, and steps of 0.25 m or 1 m would show as terraces in the
# shading of gentle slopes
encode <- function(v) {
  v[is.na(v) | v > 0] <- 0
  u <- round(v * 10) / 10 + 32768
  webp::write_webp(array(c(floor(u / 256), floor(u) %% 256, floor((u - floor(u)) * 256)) / 255,
                         dim = c(SIZE, SIZE, 3)), quality = NA)
}

# MBTiles ---------------------------------------------------------------------------------------------------------

unlink(out)
con <- DBI::dbConnect(RSQLite::SQLite(), out)
DBI::dbExecute(con, "CREATE TABLE metadata (name TEXT, value TEXT)")
DBI::dbExecute(con, "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)")
DBI::dbWriteTable(con, "metadata", append = TRUE, data.frame(
  name = c("name", "format", "encoding", "type", "bounds", "minzoom", "maxzoom", "tile_size", "attribution",
           "description"),
  value = c("depth", "webp", "terrarium", "baselayer", paste(BOUNDS, collapse = ","), min(ZOOMS), max(ZOOMS), SIZE,
            "Olex and GEBCO; Julian Burgos (MFRI)",
            "Olex_50mBM_GEBCO_interp: metres, negative below sea level; land and no value at 0")))

for (z in ZOOMS) {
  x0 <- tile_x(BOUNDS[1], z); x1 <- tile_x(BOUNDS[3], z)
  y0 <- tile_y(BOUNDS[4], z); y1 <- tile_y(BOUNDS[2], z)
  nx <- x1 - x0 + 1; ny <- y1 - y0 + 1
  warped <- tempfile(fileext = ".tif")
  st <- system2("gdalwarp", c(
    "-q", "-t_srs", "EPSG:3857",
    "-te", merc_edge(x0, z), -merc_edge(y1 + 1, z), merc_edge(x1 + 1, z), -merc_edge(y0, z),
    "-ts", nx * SIZE, ny * SIZE,
    "-r", if (z == max(ZOOMS)) "bilinear" else "average",   # finer than the source at 10, coarser below
    "-ot", "Float32", "-wm", "1024", "-multi", "-wo", "NUM_THREADS=4",
    "-co", "COMPRESS=DEFLATE", "-co", "TILED=YES", "-co", "BLOCKXSIZE=512", "-co", "BLOCKYSIZE=512",
    "-co", "BIGTIFF=YES", shQuote(src), shQuote(warped)))
  if (st != 0) stop("gdalwarp failed at zoom ", z)
  r <- terra::rast(warped)
  terra::readStart(r)
  for (j in seq_len(ny)) {
    rows <- lapply(seq_len(nx), function(i) {
      v <- terra::readValues(r, row = (j - 1) * SIZE + 1, nrows = SIZE, col = (i - 1) * SIZE + 1, ncols = SIZE)
      list(x = x0 + i - 1, data = encode(matrix(v, SIZE, SIZE, byrow = TRUE)))
    })
    y <- y0 + j - 1
    DBI::dbWithTransaction(con, DBI::dbExecute(
      con, "INSERT INTO tiles VALUES (?, ?, ?, ?)",
      params = list(rep(z, nx), vapply(rows, `[[`, 0, "x"), rep(2^z - 1 - y, nx),
                    blob::as_blob(lapply(rows, `[[`, "data")))))
  }
  terra::readStop(r)
  unlink(warped)
  message(sprintf("zoom %d: %d tiles", z, nx * ny))
}
DBI::dbExecute(con, "CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row)")
DBI::dbDisconnect(con)
