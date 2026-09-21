# GISCO ports. PORT_ID is a UN/LOCODE, not a name — see reference/ports/ports_all.R.
# Output: raw/ports/ports_giscoR.gpkg
library(tidyverse)
library(giscoR)
library(sf)
gisco_get_ports() |> write_sf(fd_raw("ports", "ports_giscoR.gpkg"), delete_dsn = TRUE)
