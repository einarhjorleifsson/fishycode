# Polygons round the tag recaptures read as one trawl ground (fiskislóð), and one polygon drawn by hand.
# Side: preprocessing (ornefni). See plan 043; decision 221.
#
# Input:  raw/external/ornefni/fiskmerki/fiskislod_polygons.gpkg (566 polygons, 2022-09-16);
#         raw/external/ornefni/qgis/ornefni_qgis-handdrawn.gpkg (1 polygon, 2022-11-01)
# Output: staging/ornefni/fiskislod.parquet - one row per fiskislóð (566), keyed on `name`; WKB `geometry`, WGS 84
#         staging/ornefni/drawn_area.parquet - one row per drawn polygon (1), keyed on `row`; WKB `geometry`, WGS 84
#
# - fiskislod: the convex hull of trial2's recaptures per `fiskislod` (recapture_reading), buffered 100 m in Web
#   Mercator (the ornefni repo's scripts/tmp.R); `n` the recaptures. Basis `derived`, kind `polygon`.
# - drawn_area: a polygon drawn by hand in QGIS, with its name, comment and source as written. Basis `recorded`, kind
#   `drawn`.

library(dplyr)

R <- fd_raw("external", "ornefni")

f <- sf::st_read(file.path(R, "fiskmerki", "fiskislod_polygons.gpkg"), quiet = TRUE)
stopifnot(setequal(setdiff(names(f), attr(f, "sf_column")), c("fiskislod", "n", "area")), sf::st_crs(f)$epsg == 4326)
fisk <- sf::st_sf(tibble(name = f$fiskislod, n = as.integer(f$n), area_m2 = f$area, source = "fiskmerki",
                         position_basis = "derived", position_kind = "polygon"), geometry = sf::st_geometry(f))

h <- sf::st_read(file.path(R, "qgis", "ornefni_qgis-handdrawn.gpkg"), quiet = TRUE)
stopifnot(setequal(setdiff(names(h), attr(h, "sf_column")), c("name", "comment", "source")), sf::st_crs(h)$epsg == 4326)
drawn <- sf::st_sf(tibble(row = seq_len(nrow(h)), name = h$name, comment = h$comment, source_note = h$source,
                          source = "qgis", position_basis = "recorded", position_kind = "drawn"), geometry = sf::st_geometry(h))

stopifnot(nrow(fisk) == 566L, !anyDuplicated(fisk$name), nrow(drawn) == 1L)
print(knitr::kable(tibble(fiskislod = nrow(fisk), recaptures = sum(fisk$n), drawn = nrow(drawn)), caption = "staging/ornefni: fiskislod, drawn_area"))

write_parquet_sf(fisk, fd_staging("ornefni", "fiskislod.parquet"))
write_parquet_sf(drawn, fd_staging("ornefni", "drawn_area.parquet"))
