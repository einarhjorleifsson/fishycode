# h3_index.R — build the H3 resolution-8 lookup used for all AIS spatial tagging.
#
# Input:  raw/aux/gebco_2026.tif   <-- MISSING, see below
#         staging/aux/eusm.fgb, staging/aux/ices_areas_500m-buffer.fgb
# Output: curated/reference/area_h3.parquet   (26,160,965 cells: h3, depth, bbht, fao)
#
# ############################################################################
# # THIS SCRIPT CANNOT RUN. The GEBCO GeoTIFF is not on this machine - it was
# # a manual download into ~/Downloads, used once on 2026-05-08, and cleared.
# # Re-download from https://download.gebco.net, bounding box n89.0 s35.0
# # w-45.0 e69.0, GeoTIFF, and place it at $FISHYDATA/raw/aux/gebco_2026.tif.
# # The existing curated/reference/area_h3.parquet is SEEDED, not built.
# # See curate/decisions/002-missing-gebco-raster.md
# ############################################################################

library(terra)
library(tidyverse)
library(duckdb)
library(nanoparquet)

# gebco ------------------------------------------------------------------------
r <- rast(fd_raw("aux", "gebco_2026.tif"))

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
h3_centres |> duckdbfs::write_dataset(fd_curated("reference", "area_h3.parquet"))

library(mapdeck)
token <- "pk.eyJ1IjoiZmlzaHZpY2UiLCJhIjoiY2p0MXQ5dThpMDZqeDQ5bHM0MGx4dHI5cyJ9.Fed_z7mv_TgTWDRjiavU3A"
mapdeck::set_token(token)
mapdeck(libraries = "h3", location = c(-20, 64)) |>
  add_h3(data = h3_centres |> filter(between(lon, -30, -10),
                                     between(lat, 63, 67)),
         hexagon = "h3",
         fill_colour = "depth",
         tooltip = "fao",
         palette = "inferno",
         legend = TRUE)
