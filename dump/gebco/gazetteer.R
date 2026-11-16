# The IHO-IOC GEBCO Gazetteer of Undersea Feature Names (SCUFN's approved names, kept by the IHO Data Centre for Digital
# Bathymetry at NOAA NCEI), the features in a box round Iceland and its ridges (45 W to 0, 50 N to 75 N): points, lines and
# areas with their name, generic term and id (plan 074: the undersea features' official names beside the charts').
# The maintainer, 2026-11-16: "they may have placenames an positions related to underwater geological feature"; "no
# permission needed for downloading and mining".
# Input: https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/Undersea_Features/FeatureServer (layers 0, 1, 2;
# query by envelope, f=geojson; the service named on gebco.net). Output: $FISHYDATA/raw/external/gebco/
# undersea_feature_names_{points,lines,polygons}.geojson, as delivered, and gazetteer-provenance.txt beside them (the grid's own
# README-provenance.txt kept). Cite as "IHO-IOC GEBCO Gazetteer of Undersea Feature Names, www.gebco.net".
# Run once, from the repo root: Rscript dump/gebco/gazetteer.R
# Written by Claude (AI).
source("R/paths.R")
out_dir <- fd_raw("external", "gebco"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
B <- "https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/Undersea_Features/FeatureServer"
Q <- "/query?where=1%3D1&geometry=-45,50,0,75&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=*&outSR=4326"
req <- function(u) httr2::request(u) |> httr2::req_user_agent("fishycode data fetch") |> httr2::req_timeout(300)
note <- c("# The GEBCO Gazetteer of Undersea Feature Names round Iceland, fetched by dump/gebco/gazetteer.R (plan 074).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), ". Cite as \"IHO-IOC GEBCO Gazetteer of Undersea Feature Names, www.gebco.net\"."), "")
for (l in list(c(0, "points"), c(1, "lines"), c(2, "polygons"))) {
  n <- jsonlite::fromJSON(req(paste0(B, "/", l[1], Q, "&returnCountOnly=true&f=json")) |> httr2::req_perform() |> httr2::resp_body_string())$count
  f <- file.path(out_dir, paste0("undersea_feature_names_", l[2], ".geojson")); url <- paste0(B, "/", l[1], Q, "&f=geojson")
  req(url) |> httr2::req_perform(path = f)
  x <- sf::read_sf(f); stopifnot(nrow(x) == n)
  note <- c(note, paste0("## ", basename(f)), paste0("request: ", url), paste0("bytes: ", file.size(f)),
            paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)), paste0("features: ", nrow(x), " (the server's own count ", n, ")"),
            paste0("attributes: ", paste(names(sf::st_drop_geometry(x)), collapse = ", ")), "")
}
writeLines(note, file.path(out_dir, "gazetteer-provenance.txt")); cat(note, sep = "\n")
