# LMÍ's lighthouses, the IS 50V structures of class 6510 (viti), one row per point as delivered (plan 082, the aids).
# Side: preprocessing (aids). Standalone, run by hand outside the targets flow (plan 082 ask p); reference/aids/aid.R reads it.
#
# Input:  raw/external/natt_lighthouses/IS_50V__mannvirki_punktar_6510.geojson (dump/natt/lighthouses.R; WGS 84)
# Output: staging/is50v/lighthouse.parquet - one row per point: every attribute as delivered (objectid, uuid, mannvirki, virkni,
#         nafnfitju the name, ath the remark (the Admiralty number for most: "Viti, L4466"), nakvaemnixy the stated accuracy
#         in metres, heimild the source (SPOT-5, air photos), the dates, gagnasafn the edition), lon, lat
#
# Source-shaped. Open data of Náttúrufræðistofnun Íslands (IS 50V).
# Run from the repo root: Rscript sources/is50v/lighthouse.R. Written by Claude (AI).
library(sf)
g <- read_sf(fd_raw("external", "natt_lighthouses", "IS_50V__mannvirki_punktar_6510.geojson"))
stopifnot(sf::st_crs(g)$epsg == 4326, all(g$mannvirki == 6510))
ll <- st_coordinates(g); d <- as.data.frame(st_drop_geometry(g)); d$lon <- ll[, 1]; d$lat <- ll[, 2]
dir.create(fd_staging("is50v"), recursive = TRUE, showWarnings = FALSE)
nanoparquet::write_parquet(d, fd_staging("is50v", "lighthouse.parquet"))
message(sprintf("is50v: %d lighthouses", nrow(d)))
