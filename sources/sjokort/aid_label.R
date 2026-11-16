# The sea charts' witnesses of the aids that are not names: the light characteristics printed on the nine frozen charts, and
# the letterings the twin rule makes an aid's name (plan 074 step 9, the aids).
# Side: preprocessing (aids). Standalone, run by hand outside the targets flow (plan 074 ask p); reference/aids/aid.R reads it.
#
# Input:  $FISHYDATA/archive/2026-11-11-named-features/out/frozen/aids/light_characteristics.gpkg (layer characteristic) and
#         aid_letterings.csv, frozen there by its 97_freeze_aid_labels.R: the charts' read is the study's, an input the build
#         reads and never makes (the read needs a Mac), as for curated/reference/chart_names.parquet
# Output: staging/sjokort/light_characteristic.parquet - one row per text the read took for a light's characteristic, as read
#         (not reviewed: a fragment or a misread is judged in reference/aids/aid.R): chart, scale, text_id, text, clean,
#         reads, outcome_read (how the read filed it), lon, lat (the text box's middle), box_wkt (the box, WGS 84), len_mm
#         (its longer side on its chart)
#         staging/sjokort/aid_lettering.parquet - one row per lettering the study's 84 makes an aid's name: chart, label_id
#         (chart_names' key), name, kind, cls, basis
#
# Internal: the charts are Landhelgisgæslan's (© Sjómælingar Íslands), not for navigation.
# Run from the repo root: Rscript sources/sjokort/aid_label.R. Written by Claude (AI).
library(sf)
sf_use_s2(FALSE)
FROZEN <- fd_path("archive", "2026-11-11-named-features", "out", "frozen", "aids")
g <- read_sf(file.path(FROZEN, "light_characteristics.gpkg"), "characteristic"); stopifnot(nrow(g) > 0)
bb <- st_transform(st_geometry(g), 3857)                                   # the read's own frame
c4 <- st_coordinates(st_transform(st_centroid(bb), 4326))
side_m <- vapply(bb, function(b) { e <- st_bbox(b); max(e[3] - e[1], e[4] - e[2]) }, numeric(1))
d <- as.data.frame(st_drop_geometry(g)); d$lon <- c4[, 1]; d$lat <- c4[, 2]; d$box_wkt <- st_as_text(st_geometry(g))
d$len_mm <- round(side_m * cos(c4[, 2] * pi / 180) / d$scale * 1000, 1)      # Web Mercator metres to the chart's mm
al <- read.csv(file.path(FROZEN, "aid_letterings.csv"), encoding = "UTF-8", colClasses = "character")
al$label_id <- as.integer(al$label_id)
dir.create(fd_staging("sjokort"), recursive = TRUE, showWarnings = FALSE)
nanoparquet::write_parquet(d, fd_staging("sjokort", "light_characteristic.parquet"))
nanoparquet::write_parquet(al, fd_staging("sjokort", "aid_lettering.parquet"))
message(sprintf("sjokort: %d printed characteristics, %d aid letterings", nrow(d), nrow(al)))
