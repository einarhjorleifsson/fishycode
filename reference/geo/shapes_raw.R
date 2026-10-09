# shapes_raw.R — repair the raw spatial layers once: ICES areas, GEBCO depth bands and EUSM habitats.
# Side: preprocessing (geo). See plan 014.
#
# Input:  raw/aux/ICESareas.gpkg, raw/aux/ICES_GEBCO.rds, raw/aux/eusm.rds
# Output: staging/aux_valid/{ices_areas,gebco,eusm}.gpkg   valid geometry, EPSG:4326
#
# Each layer goes through st_make_valid(), lwgeom_make_valid() and st_make_valid() again. That is
# the slow part (about 10 minutes, mostly EUSM's 2.2 M polygons), so it is done here once and
# reference/geo/shapes.R only crops and buffers the result. EUSM keeps only polygons with an MSFD
# broad habitat type.

library(sf)
library(tidyverse)
sf::sf_use_s2(FALSE)
# ICES areas -------------------------------------------------------------------
ices_areas <-
  read_sf(fd_raw("aux", "ICESareas.gpkg")) |>
  select(fao = Area_Full) |>
  st_as_sf() |>
  st_make_valid() |>
  mutate(geom = lwgeom::lwgeom_make_valid(geom)) |>
  st_make_valid()
ices_areas$geom |> st_is_valid() |> table()
ices_areas |>
  write_sf(fd_staging("aux_valid", "ices_areas.gpkg"), delete_dsn = TRUE)
# gebco ------------------------------------------------------------------------
gebco <-
  readRDS(fd_raw("aux", "ICES_GEBCO.rds")) |>
  rename(depth_range = depth, geom = geometry) |>
  st_as_sf() |>
  st_make_valid() |>
  mutate(geom = lwgeom::lwgeom_make_valid(geom)) |>
  st_make_valid()
gebco$geom |> st_is_valid() |> table()
gebco |>
  write_sf(fd_staging("aux_valid", "gebco.gpkg"), delete_dsn = TRUE)
# eusm -------------------------------------------------------------------------
eusm <-
  readRDS(fd_raw("aux", "eusm.rds")) |>
  rename(bbht = MSFD_BBHT, geom = Shape) |>
  # drops 986652 features !!
  filter(bbht != "") |>
  st_as_sf() |>
  st_make_valid() |>
  mutate(geom = lwgeom::lwgeom_make_valid(geom)) |>
  st_make_valid()
eusm$geom |> st_is_valid() |> table()
eusm |>
  write_sf(fd_staging("aux_valid", "eusm.gpkg"), delete_dsn = TRUE)
