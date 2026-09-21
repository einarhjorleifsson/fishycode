# vmstools harbour points, from the installed package's bundled data.
# Output: raw/ports/ports_vmstools.gpkg
#
# Install once:
#   url <- "https://github.com/nielshintzen/vmstools/releases/download/0.77/vmstools_0.77.tar.gz"
#   download.file(url, destfile = "vmstools_0.77.tar.gz", mode = "wb")
#   install.packages("vmstools_0.77.tar.gz", repos = NULL, type = "source")
library(vmstools)
library(tidyverse)
library(sf)
data("harbours")
harbours |>
  as_tibble() |>
  mutate(harbour = iconv(harbours$harbour, from = "latin1", to = "UTF-8")) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |>
  write_sf(fd_raw("ports", "ports_vmstools.gpkg"), delete_dsn = TRUE)
