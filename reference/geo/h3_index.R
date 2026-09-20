library(terra)
library(tidyverse)
library(duckdb)
library(nanoparquet)

# gebco ------------------------------------------------------------------------
r <- rast("~/Downloads/GEBCO_07_May_2026_8472de0f82f8/gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif")

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
#eusm_v <- vect("data-raw/aux/eusm.fgb")
eusm_v <- vect("data/aux/eusm.fgb")

# Rasterize onto GEBCO template — same grid, extent clips eusm automatically
eusm_r <- rasterize(eusm_v, r, field = "bbht")

# Extract bbht at H3 centroid points
pts <- vect(h3_centres, geom = c("lon", "lat"), crs = "EPSG:4326")
h3_centres$bbht <- terra::extract(eusm_r, pts)[["bbht"]]

# ices areas -------------------------------------------------------------------
ices_v <- vect("data/aux/ices_areas_500m-buffer.fgb")
# Rasterize onto GEBCO template — same grid, extent clips ices automatically
ices_r <- rasterize(ices_v, r, field = "fao")
# Extract ices area at H3 centroid points (reuse pts from eusm block)
h3_centres$fao <- terra::extract(ices_r, pts)[["fao"]]

# save -------------------------------------------------------------------------
h3_centres |> duckdbfs::write_dataset("data/aux/h3_indices.parquet")

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
