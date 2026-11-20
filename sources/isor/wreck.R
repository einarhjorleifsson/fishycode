# ÍSOR's offshore wind map, its Infrastructure service (vindorka_a_hafi/Infrastructure): the four point layers of wrecks and
# diving sites, one row per point as the layers deliver them (plan 074 step 12, the wrecks; the named-features study's
# 91_wrecks.R).
# Side: preprocessing (wrecks). Standalone, run by hand outside the targets flow (plan 082 ask p); reference/wrecks/wreck.R
# reads its output.
#
# Input:  raw/external/isor/vindorka_a_hafi_Infrastructure__{0,1,2,3}_*.geojson (dump/isor/hafsbotn.R; WGS 84)
# Output: staging/isor/wreck.parquet - one row per point: layer (the server's layer number, 0-3), file, point (its order
#         within its feature: layer 0's two features are multipoints, every other feature a point), every attribute of its
#         layer as delivered (OBJECTID; Type, Domain, Droid, Name, Comment, Project; OID_, FolderPath, SymbolID, AltMode,
#         Base, Snippet, PopupInfo, HasLabel, LabelID; Longitude, Latitude, ID, Symbol: the layers' own names, English),
#         WKB `geometry`, WGS 84
#
# The layers: 0 "Skipsflok (ISOR)", ÍSOR's own wreck points (16 in two multipoints, no names; made for EMODnet Geology);
# 1 "Skipsflök (SKFI)", 18 named wrecks; 2 "Skipsflok (LHG)", Landhelgisgæslan's list (279: an ID, the plotter's symbol it
# was drawn with, a comment, the coordinates in their own columns as well); 3 "Köfunarstaðir á Íslandi", the diving sites
# (57, each in a folder). Source-shaped: which layers and records are wrecks, which records copy another list's, and
# Landhelgisgæslan's text stored in Mac Icelandic and read as Windows-1252 ("ARINBJ…R", kept as given) are
# reference/wrecks/wreck.R's. Terms: ÍSOR's, internal use (dump/isor/hafsbotn.R).
# Run from the repo root: Rscript sources/isor/wreck.R. Written by Claude (AI), 2026-11-19.
library(sf)
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_parquet.R")) source(f)   # standalone: not targets'
fs <- sort(list.files(fd_raw("external", "isor"), "^vindorka_a_hafi_Infrastructure__[0-9]+_.*[.]geojson$", full.names = TRUE))
stopifnot(length(fs) == 4)
d <- do.call(dplyr::bind_rows, lapply(fs, function(f) {
  g <- read_sf(f); stopifnot(st_crs(g)$epsg == 4326)
  cc <- st_coordinates(g); fid <- if ("L1" %in% colnames(cc)) cc[, "L1"] else seq_len(nrow(g))
  stopifnot(length(fid) == nrow(cc), all(fid %in% seq_len(nrow(g))))
  data.frame(layer = as.integer(sub("^vindorka_a_hafi_Infrastructure__([0-9]+)_.*", "\\1", basename(f))), file = basename(f),
             point = as.integer(ave(fid, fid, FUN = seq_along)), as.data.frame(st_drop_geometry(g))[fid, , drop = FALSE],
             lon = cc[, "X"], lat = cc[, "Y"], row.names = NULL, check.names = FALSE) }))
d <- st_as_sf(d, coords = c("lon", "lat"), crs = 4326)
write_parquet_sf(d, fd_staging("isor", "wreck.parquet"))
message(sprintf("isor: %d points (%s, by layer)", nrow(d), paste(names(table(d$layer)), table(d$layer), sep = ": ", collapse = ", ")))
