# EMODnet human-activities port locations (WFS).
# Output: raw/ports/ports_emodnet.gpkg
library(emodnet.wfs)
library(sf)
library(dplyr)
wfs_ha <- emodnet_init_wfs_client(service = "human_activities")
emodnet_get_layers(wfs = wfs_ha, layers = "portlocations", simplify = TRUE) |>
  write_sf(fd_raw("ports", "ports_emodnet.gpkg"), delete_dsn = TRUE)
