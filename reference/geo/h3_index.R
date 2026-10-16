# h3_index.R — build the H3 resolution-8 lookup used for all AIS spatial tagging.
# Side: preprocessing (geo). See plan 014.
#
# Input:  raw/aux/gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif
#         staging/aux/eusm.fgb, staging/aux/ices_areas_500m-buffer.fgb
# Output: curated/reference/area_h3.parquet   (26,160,965 cells: h3, depth, bbht, fao)
#
# The raster was recorded as missing from 2026-09-20 to 2026-09-22 and this script
# carried a CANNOT RUN banner. It was never missing: it is in raw/aux/ under the
# name GEBCO's download service gave it, which is not the gebco_2026.tif the banner
# told people to create. Verified 2026-09-22 - 709 MB, extent -45/69/35/89, EPSG:4326,
# 12960 x 27360. See curate/decisions/002-missing-gebco-raster.md.
#
# The filename is left as downloaded, because the bounding box in it IS the
# provenance of the request; the script is pointed at it instead.

library(terra)
library(tidyverse)
library(duckdb)
library(nanoparquet)

# gebco ------------------------------------------------------------------------
r <- rast(fd_raw("aux", "gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif"))

# Dump raster to temp parquet — DuckDB reads this without loading into R memory
pts <- as.data.frame(r, xy = TRUE, na.rm = TRUE) |>
  rename(lon = x, lat = y, depth = 3) |>
  filter(depth < 5)
tmp <- tempfile(fileext = ".parquet")
nanoparquet::write_parquet(pts, tmp)
rm(pts)
gc()

# H3 res-8 (~460m) matches raster pixel size; aggregate min depth per cell
con <- dbConnect(duckdb())
dbExecute(con, "INSTALL h3 FROM community; LOAD h3;")

h3_depth <- dbGetQuery(con, glue::glue("
  SELECT
    h3_latlng_to_cell_string(lat, lon, 8) AS h3,
    min(depth)                      AS depth
  FROM read_parquet('{tmp}')
  GROUP BY h3
"))

# Recover cell centres — h3 column comes back as DOUBLE; cast to UBIGINT
duckdb::duckdb_register(con, "h3_depth", h3_depth)
h3_centres <- dbGetQuery(con, "
  SELECT
    h3,
    depth,
    h3_cell_to_lat(h3) AS lat,
    h3_cell_to_lng(h3) AS lon
  FROM h3_depth
")
dbDisconnect(con, shutdown = TRUE)
unlink(tmp)

# EUSM -> raster -> H3 bbht ----------------------------------------------------

# Read eusm directly from FlatGeoBuf (GDAL handles it, no R memory overhead)
#eusm_v <- vect(fd_staging("aux", "eusm.fgb"))
eusm_v <- vect(fd_staging("aux", "eusm.fgb"))

# Rasterize onto GEBCO template — same grid, extent clips eusm automatically
eusm_r <- rasterize(eusm_v, r, field = "bbht")

# Extract bbht at H3 centroid points
pts <- vect(h3_centres, geom = c("lon", "lat"), crs = "EPSG:4326")
h3_centres$bbht <- terra::extract(eusm_r, pts)[["bbht"]]

# ices areas -------------------------------------------------------------------
ices_v <- vect(fd_staging("aux", "ices_areas_500m-buffer.fgb"))
# Rasterize onto GEBCO template — same grid, extent clips ices automatically
ices_r <- rasterize(ices_v, r, field = "fao")
# Extract ices area at H3 centroid points (reuse pts from eusm block)
h3_centres$fao <- terra::extract(ices_r, pts)[["fao"]]

# save -------------------------------------------------------------------------
h3_centres |> write_curated(fd_curated("reference", "area_h3.parquet"),
                           inputs = c(fd_raw("aux", "gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif"),
                                      fd_staging("aux", "eusm.fgb"), fd_staging("aux", "ices_areas_500m-buffer.fgb")))

library(mapdeck)
# mapdeck reads the Mapbox token from MAPBOX_TOKEN in ~/.Renviron; it is never in the repo
mapdeck(libraries = "h3", location = c(-20, 64)) |>
  add_h3(data = h3_centres |> filter(between(lon, -30, -10),
                                     between(lat, 63, 67)),
         hexagon = "h3",
         fill_colour = "depth",
         tooltip = "fao",
         palette = "inferno",
         legend = TRUE)
