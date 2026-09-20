library(sf)
library(tidyverse)
library(mapview)

# Shoreline --------------------------------------------------------------------
# Shoreline is imperfect - here create a 500 meter buffer inland, so that
#  fisheries close to shore not allocated as points-on-land in downstream
#  analysis.

sf_use_s2(FALSE)
ices_raw <- read_sf(fd_raw("aux", "ICES_Areas_20160601_cut_dense_3857.gpkg"))

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
eusm <-
  eusm |>
  st_transform(4326) |>
  st_crop(st_bbox(ices_extended))
eusm |> write_sf(fd_staging("aux", "eusm.gpkg"), delete_dsn = TRUE)
eusm |> write_sf(fd_staging("aux", "eusm.fgb"), delete_dsn = TRUE)
# gebco ------------------------------------------------------------------------
read_sf(fd_staging("aux_valid", "gebco.gpkg")) |> write_sf(fd_staging("aux", "gebco.gpkg"), delete_dsn = TRUE)
read_sf(fd_staging("aux_valid", "gebco.gpkg")) |> write_sf(fd_staging("aux", "gebco.fgb"), delete_dsn = TRUE)
# ports ------------------------------------------------------------------------
ports <-
  read_sf(fd_raw("ports", "ports_all.gpkg")) |>
  filter(source %in% c("einar", "gfw")) |>
  filter_out(source == "gfw" & (str_starts(pid, "FO") | str_starts(pid, "IS"))) |>
  st_crop(st_bbox(read_sf(fd_staging("aux", "ices_areas_500m-buffer.gpkg"))))
ports |> write_sf(fd_staging("aux", "ports.gpkg"), delete_dsn = TRUE)
ports |> write_sf(fd_staging("aux", "ports.fgb"), delete_dsn = TRUE)
