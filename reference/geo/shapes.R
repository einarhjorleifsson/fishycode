# shapes.R — the port polygons the flow tags pings with, cropped to the ICES areas' box.
# Side: preprocessing (geo). See plan 014.
#
# Input:  curated/reference/port_geometry.parquet   from reference/ports/ports_all.R
# Output: staging/aux/ports.{gpkg,fgb}               read by curate/ais_ping_tag.R and reference/ports/stk_hid_pid.R
#
# Until plan 049 this script also wrote the ICES areas with a 500 m coastal buffer, the EUSM habitats and the GEBCO depth
# bands. Those are the ICES datacall's (products/ices_vms_datacall/area_layers.R), so only the box is kept here: the
# buffered ICES areas' bounding box as they last built it (2026-10-28), so the ports come out the same.

library(sf)
library(tidyverse)

ices_box <- st_bbox(c(xmin = -44.009436955761288, ymin = 35.995461513687637,
                      xmax = 68.764211089664045, ymax = 89.004724200724098), crs = st_crs(4326))

# ports ------------------------------------------------------------------------
# One row per physical port, already deduplicated across the nine sources by
# reference/ports/ports_all.R, which resolves overlaps by source priority
# inside a spatial cluster. The hardcoded source filter this replaced -
#   filter(source %in% c("einar","gfw")) then drop gfw where pid starts IS/FO
# - was a crude hand version of that same rule, applied in the wrong place.
sf_use_s2(FALSE)
ports <-
  read_curated_sf(fd_curated("reference", "port_geometry.parquet")) |>
  st_crop(ices_box)
ports |> write_sf(fd_staging("aux", "ports.gpkg"), delete_dsn = TRUE)
ports |> write_sf(fd_staging("aux", "ports.fgb"), delete_dsn = TRUE)
