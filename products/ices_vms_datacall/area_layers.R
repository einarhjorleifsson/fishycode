# area_layers.R — the ICES areas with a 500 m coastal buffer, the EUSM habitats and the GEBCO depth bands, for the datacall.
# Side: the ICES datacall, not wired: moved out of the flow by plan 049 (2026-10-28), until plan 015 wires it.
#
# Input:  raw/aux/ICES_Areas_20160601_cut_dense_3857.gpkg, staging/aux_valid/{eusm,gebco}.gpkg (shapes_raw.R here)
# Output: staging/aux/ices_areas_500m-buffer.{gpkg,fgb}, eusm.fgb, gebco.{gpkg,fgb}   read by area_h3.R here and by
#         products/exports/astd_iseez.R
#
# Until plan 049 this was reference/geo/shapes.R, the `shapes` target, which also wrote the port polygons; those stay
# in the flow (reference/geo/shapes.R), cropped to this layer's box as it last built.
library(sf)
library(tidyverse)
library(mapview)

# Shoreline --------------------------------------------------------------------
# Shoreline is imperfect - here create a 500 meter buffer inland, so that
#  fisheries close to shore not allocated as points-on-land in downstream
#  analysis.

sf_use_s2(FALSE)
# The source is EPSG:3857, whose unit is a metre only at the equator (scale factor sec(lat)):
# a 500 buffer there was 215 m on the ground at 64.5N and 171 m at 70N. EPSG:3035 (LAEA
# Europe) gives 498-500 m across the ICES area and within 4 % at its corners (Greenland, 80N).
ices_raw <- read_sf(fd_raw("aux", "ICES_Areas_20160601_cut_dense_3857.gpkg")) |>
  st_transform(3035)

# 1. Buffer the union — only external (coastal) boundaries expand
original_union <- st_union(ices_raw)
# nQuadSegs set to 2 to reduce the number of vertices
union_buf      <- st_buffer(original_union, dist = 500, nQuadSegs = 2)

# 2. Coastal strip = new area only
coast_strip <- st_difference(union_buf, original_union)

# 3. Assign coastal strip pieces to each polygon via individual buffer
#    Use st_filter first to avoid all-pairs intersection
coast_assigned <- ices_raw |>
  st_buffer(500) |>
  st_filter(coast_strip) |>                        # only polygons touching the coast
  st_intersection(coast_strip)                     # clip to coast strip only

# 4. Union each polygon with its coastal strip piece
ices_extended <- bind_rows(
  select(ices_raw, Area_Full),
  select(coast_assigned, Area_Full)
) |>
  group_by(Area_Full) |>
  summarise(geom = st_union(geom), .groups = "drop")

ices_extended <- ices_extended |>
  st_transform(4326) |>
  st_cast("MULTIPOLYGON") |>
  rename(fao = Area_Full)
ices_extended |> write_sf(fd_staging("aux", "ices_areas_500m-buffer.gpkg"), delete_dsn = TRUE)
ices_extended |> write_sf(fd_staging("aux", "ices_areas_500m-buffer.fgb"), delete_dsn = TRUE)

# eusm -------------------------------------------------------------------------
# reference/geo/shapes_raw.R has already filtered and repaired it (staging/aux_valid/, EPSG:4326).
# This block used to repeat that from raw/aux/eusm.rds - the same three make_valid passes over
# 2.2 M polygons, most of this target's 15 minutes - and so never read its declared input.
eusm <-
  read_sf(fd_staging("aux_valid", "eusm.gpkg")) |>
  st_crop(st_bbox(ices_extended))
# .fgb only: both readers (area_h3.R here, products/exports/astd_iseez.R) take it; the 2 GB .gpkg copy is gone
eusm |> write_sf(fd_staging("aux", "eusm.fgb"), delete_dsn = TRUE)
# gebco ------------------------------------------------------------------------
read_sf(fd_staging("aux_valid", "gebco.gpkg")) |> write_sf(fd_staging("aux", "gebco.gpkg"), delete_dsn = TRUE)
read_sf(fd_staging("aux_valid", "gebco.gpkg")) |> write_sf(fd_staging("aux", "gebco.fgb"), delete_dsn = TRUE)
