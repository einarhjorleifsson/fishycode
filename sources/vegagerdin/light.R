# Vegagerðin's national lights and its wave buoys, one row per feature as the layers deliver them (plan 082, the aids).
# Side: preprocessing (aids). Standalone, run by hand outside the targets flow (plan 082 ask p); reference/aids/aid.R reads it.
#
# Input:  raw/external/vegagerdin/vitar_2024_1.geojson, dufl_2024_1.geojson (dump/vegagerdin/fetch.R; ISN93, EPSG:3057)
# Output: staging/vegagerdin/light.parquet - one row per light: every attribute as delivered (NR, ADMR the Admiralty number,
#         HEITI, LJOSEINKENNI the characteristic, LJOSHAED, SJONARLENGD, BREIDD_N and LENGD_V the position as text ...),
#         x, y (the geometry, ISN93 metres) and lon, lat (WGS 84)
#         staging/vegagerdin/wave_buoy.parquet - the same for the wave-measuring buoys (dufl_2024_1; LON given positive west)
#
# Source-shaped. Measured 2026-11-16: the lights are the List of Lights' own (every Admiralty number shared, BREIDD_N and
# LENGD_V the List's position to the digit), the geometry within the List's rounding of it (median 4 m, at most 10 m).
# Run from the repo root: Rscript sources/vegagerdin/light.R. Written by Claude (AI).
library(sf)
stage <- function(f) {
  g <- read_sf(fd_raw("external", "vegagerdin", f)); stopifnot(sf::st_crs(g)$epsg == 3057)
  xy <- st_coordinates(g); ll <- st_coordinates(st_transform(g, 4326))
  d <- st_drop_geometry(g); d$x <- xy[, 1]; d$y <- xy[, 2]; d$lon <- ll[, 1]; d$lat <- ll[, 2]; as.data.frame(d) }
dir.create(fd_staging("vegagerdin"), recursive = TRUE, showWarnings = FALSE)
li <- stage("vitar_2024_1.geojson"); wb <- stage("dufl_2024_1.geojson")
nanoparquet::write_parquet(li, fd_staging("vegagerdin", "light.parquet"))
nanoparquet::write_parquet(wb, fd_staging("vegagerdin", "wave_buoy.parquet"))
message(sprintf("vegagerdin: %d lights, %d wave buoys", nrow(li), nrow(wb)))
