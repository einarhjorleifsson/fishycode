# depth_h3.R — GEBCO's depth per H3 resolution-8 cell, for the logbook's depth-unit correction.
# Side: preprocessing (geo). See plan 014.
#
# Input:  raw/aux/gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif
# Output: curated/reference/depth_h3.parquet   (h3, depth, lat, lon: the cell, its deepest pixel, its centre)
#
# Read by curate/corrections/afli_depth_units.R alone. This is reference/geo/h3_index.R's GEBCO part unchanged; its
# habitat and ICES-area parts, which tagged every ping, went to the ICES datacall with plan 049
# (products/ices_vms_datacall/area_h3.R).
#
# The raster was recorded as missing from 2026-09-20 to 2026-09-22. It was never missing: it is in raw/aux/ under the
# name GEBCO's download service gave it, which is not the gebco_2026.tif the banner told people to create. Verified
# 2026-09-22 - 709 MB, extent -45/69/35/89, EPSG:4326, 12960 x 27360. See curate/decisions/002-missing-gebco-raster.md.
# The filename is left as downloaded, because the bounding box in it IS the provenance of the request.

library(terra)
library(tidyverse)
library(duckdb)
library(nanoparquet)

GEBCO <- fd_raw("aux", "gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif")

# gebco ------------------------------------------------------------------------
r <- rast(GEBCO)

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

# save -------------------------------------------------------------------------
h3_centres |> write_curated(fd_curated("reference", "depth_h3.parquet"), inputs = GEBCO)
