# OpenStreetMap harbour features, global.
# Output: raw/ports/ports_osm.gpkg
library(osmdata)
library(sf)
library(dplyr)
bb <- c(-170.9, -89.0, 179.9, 89.0)   # global
osm_fetch <- opq(bbox = bb, timeout = 120) |>
  add_osm_feature(key = "harbour") |>
  osmdata_sf()
osm <-
  bind_rows(osm_fetch$osm_points, osm_fetch$osm_polygons,
            osm_fetch$osm_multipolygons, osm_fetch$osm_lines,
            osm_fetch$osm_multilines) |>
  as_tibble() |>
  filter(!is.na(harbour)) |>
  janitor::clean_names() |>
  janitor::remove_empty(which = "cols") |>
  janitor::remove_constant() |>
  select(osm_id, name, harbour, geometry, everything())
osm |> write_sf(fd_raw("ports", "ports_osm.gpkg"), delete_dsn = TRUE)
