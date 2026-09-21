# Global Fishing Watch named anchorages.
# Input:  raw/ports/named_anchorages_v2_pipe_v3_202601.csv (manual download)
# Output: raw/ports/ports_gfw_named_anchorages_v2_pipe_v3_202601.gpkg
#
# Download: https://globalfishingwatch.org/data-download/datasets/public-anchorages
library(tidyverse)
library(sf)
read_csv(fd_raw("ports", "named_anchorages_v2_pipe_v3_202601.csv")) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
  write_sf(fd_raw("ports", "ports_gfw_named_anchorages_v2_pipe_v3_202601.gpkg"),
           delete_dsn = TRUE)
