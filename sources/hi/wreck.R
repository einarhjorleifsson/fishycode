# The known shipwrecks off Iceland as a researcher at Háskóli Íslands shared them (80; internal), one row per point as
# delivered (plan 074 step 12, the wrecks; the named-features study's 91_wrecks.R).
# Side: preprocessing (wrecks). Standalone, run by hand outside the targets flow (plan 082 ask p); reference/wrecks/wreck.R
# reads its output.
#
# Input:  raw/external/wreck_hi/unzipped/thekkt_skipsflok.shp (the shapefile "Þekkt skipsflök" as received: UTF-8, ISN93,
#         EPSG:3057; its README-provenance.txt)
# Output: staging/hi/wreck.parquet - one row per point: every attribute as delivered (ID; X and Y, the position in degrees
#         as typed; Z, a depth; TYPE, SHIP_TYPE, SITE, SHIP_NAME, REGISTRATI, NATIONALIT, LOSS_DATE, NET_TONNAG, LOSS_LIFE,
#         POINT_ORIG, POINT_DEST, REASON_LOS, Locatio_co, WRITTEN_SO, NOTES, Date, Cluster_ID: the shapefile's own names,
#         English, cut at 10 letters), WKB `geometry` in ISN93 as delivered
#
# Internal: to be asked before anything from it is published (plan 082). Source-shaped. Its positions come from
# fishermen (snags, inexact) and from Landhelgisgæslan (exact); no field says which. The geometry and X/Y differ in 17
# (three X with the sign lost); the geometry, as placed in QGIS, is the position (README-provenance.txt). Z states its unit
# nowhere: reference/wrecks/wreck.R reads it in metres, measured.
# Run from the repo root: Rscript sources/hi/wreck.R. Written by Claude (AI), 2026-11-19.
library(sf)
for (f in c("R/paths.R", "R/write_parquet.R")) source(f)   # standalone: not targets'
g <- read_sf(fd_raw("external", "wreck_hi", "unzipped", "thekkt_skipsflok.shp")); stopifnot(st_crs(g)$epsg == 3057)
write_parquet_sf(g, fd_staging("hi", "wreck.parquet"))
message(sprintf("hi: %d points", nrow(g)))
