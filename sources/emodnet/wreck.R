# The UK Hydrographic Office's wrecks round Iceland as EMODnet Human Activities serves them (layer emodnet:wwshipwrecks), one
# row per wreck as delivered (plan 074 step 12, the wrecks; the named-features study's 91_wrecks.R).
# Side: preprocessing (wrecks). Standalone, run by hand outside the targets flow (plan 074 ask p); reference/wrecks/wreck.R
# reads its output.
#
# Input:  raw/external/emodnet_human_activities/wwshipwrecks.geojson (dump/emodnet/human_activities.R: the box 32 W to 6 W,
#         59 N to 70 N; WGS 84)
# Output: staging/emodnet/wreck.parquet - one row per wreck: every attribute as delivered (id, wreck_id, wreck_cate, status,
#         position as text, water_dept the seabed depth and depth the least depth over the wreck, metres both, name, type,
#         flag, date_sunk as yyyymmdd, circumstan, surveying_ and general_co the remarks ...: the layer's own names, English,
#         cut at 10 letters), WKB `geometry`, WGS 84
#
# Source-shaped: "n/a", the layer's own for a value not given, is kept. UK Hydrographic Office, Open Government Licence v3;
# not for navigation.
# Run from the repo root: Rscript sources/emodnet/wreck.R. Written by Claude (AI), 2026-11-19.
library(sf)
for (f in c("R/paths.R", "R/write_parquet.R")) source(f)   # standalone: not targets'
g <- read_sf(fd_raw("external", "emodnet_human_activities", "wwshipwrecks.geojson")); stopifnot(st_crs(g)$epsg == 4326)
write_parquet_sf(g, fd_staging("emodnet", "wreck.parquet"))
message(sprintf("emodnet: %d wrecks", nrow(g)))
