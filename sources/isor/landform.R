# ÍSOR's seabed map: the ten landform layers (Landmótun: the last glacial maximum's grounding line, terminal moraines,
# glacial streamlines, canals along the shelf edge, turbidity or bottom-current channels, gravity streamlines, meltwater
# channels, plough marks, the shelf break, troughs), one row per record as delivered (plan 080 ask p, decision 336).
# Side: preprocessing (sea-chart names). Standalone, run by hand outside the targets flow; reference/seabed/seabed_feature.R
# reads it.
#
# Input:  raw/external/isor/hafsbotn_Landm_otun__<0-9>_*.geojson (dump/isor/hafsbotn.R: kort.isor.is's hafsbotn layers)
# Output: staging/isor/landform.parquet - one row per record with a geometry (11,481): `kind` (grounding_line, moraine,
#         glacial_streamline, canal, channel, gravity_streamline, meltwater_channel, plough_mark, shelf_break, trough), `layer`
#         (the file), `isor_object` (its OBJECTID, or OBJECTID_1 where OBJECTID repeats), and every attribute of its layer as delivered (one whose name clashes with
#         these, case aside, prefixed `isor_`); WKB `geometry`, WGS 84
#
# Source-shaped. The layers carry no names: `Name` holds a type word ("djúp", "Terminal_moraines") or a code ("IS004").
# Run from the repo root: Rscript sources/isor/landform.R. Written by Claude (AI), 2026-11-19.

library(dplyr)
for (f in c("R/paths.R", "R/write_parquet.R")) source(f)   # standalone: not targets'

KINDS <- c("0" = "grounding_line", "1" = "moraine", "2" = "glacial_streamline", "3" = "canal", "4" = "channel",
           "5" = "gravity_streamline", "6" = "meltwater_channel", "7" = "plough_mark", "8" = "shelf_break", "9" = "trough")
files <- list.files(fd_raw("external", "isor"), pattern = "^hafsbotn_Landm_otun__[0-9]_.*[.]geojson$")
stopifnot(length(files) == 10)
parts <- lapply(files, function(f) {
  k <- KINDS[[sub("^hafsbotn_Landm_otun__([0-9])_.*", "\\1", f)]]
  g <- sf::st_transform(sf::st_read(fd_raw("external", "isor", f), quiet = TRUE), 4326)
  g <- g[!sf::st_is_empty(g), ]
  a <- as.data.frame(sf::st_drop_geometry(g)); a[] <- lapply(a, as.character)
  clash <- tolower(names(a)) %in% c("kind", "layer", "isor_object", "geometry")
  names(a)[clash] <- paste0("isor_", names(a)[clash])
  # the layer's own unique number: OBJECTID, or OBJECTID_1 where OBJECTID repeats (the moraines: 728 records, 130 OBJECTIDs)
  oid <- if (!anyDuplicated(a$OBJECTID)) a$OBJECTID else a$OBJECTID_1
  stopifnot(!anyDuplicated(oid))
  sf::st_sf(dplyr::bind_cols(tibble(kind = k, layer = f, isor_object = as.character(oid)), a), geometry = sf::st_geometry(g))
})
d <- do.call(dplyr::bind_rows, parts)
d <- sf::st_sf(d, sf_column_name = "geometry")
stopifnot(!anyDuplicated(paste(d$kind, d$isor_object)), sf::st_crs(d)$epsg == 4326)
print(knitr::kable(sf::st_drop_geometry(d) |> count(kind, name = "records"), caption = "staging/isor/landform"))
write_parquet_sf(d, fd_staging("isor", "landform.parquet"))
