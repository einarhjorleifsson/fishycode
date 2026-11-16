# LMÍ's lighthouses: the points of IS 50V's structures (IS_50V:mannvirki_punktar) whose class is a lighthouse (mannvirki 6510,
# "viti"; 78 of its 108 points are named -viti, the rest by their place: Stokksnes, Papey, Seley), on Náttúrufræðistofnun's
# GeoServer (gis.natt.is, the national map service). A witness for plan 074 step 9's curated list of aids to navigation (the
# maintainer, 2026-11-16: "curated list of lights, beacons"); its positions carry IS 50V's own accuracy (nakvaemnixy, m).
# Input: https://gis.natt.is/geoserver/ows (WFS 2.0.0 GetFeature, GeoJSON in EPSG:4326, filtered by the server to mannvirki=6510).
# Output: $FISHYDATA/raw/external/natt_lighthouses/IS_50V__mannvirki_punktar_6510.geojson, as delivered, and README-provenance.txt
# (the request, the date, bytes, sha256, the features against the server's own count, the attributes).
# Run once, from the repo root: Rscript dump/natt/lighthouses.R
# Open data of Náttúrufræðistofnun Íslands (IS 50V); cite "IS 50V, Náttúrufræðistofnun Íslands" where it is shown. Written by Claude (AI).
source("R/paths.R")
out_dir <- fd_raw("external", "natt_lighthouses"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
UA <- "fishycode data fetch"
OWS <- paste0("https://gis.natt.is/geoserver/ows?service=WFS&version=2.0.0&request=GetFeature&typeNames=IS_50V:mannvirki_punktar",
              "&CQL_FILTER=", utils::URLencode("mannvirki=6510", reserved = TRUE))
hits <- httr2::request(paste0(OWS, "&resultType=hits")) |> httr2::req_user_agent(UA) |> httr2::req_perform() |> httr2::resp_body_string()
matched <- as.integer(sub('.*numberMatched="([0-9]+)".*', "\\1", hits))
url <- paste0(OWS, "&outputFormat=application/json&srsName=EPSG:4326")
f <- file.path(out_dir, "IS_50V__mannvirki_punktar_6510.geojson")
httr2::request(url) |> httr2::req_user_agent(UA) |> httr2::req_timeout(600) |> httr2::req_perform(path = f)
x <- sf::read_sf(f)
stopifnot(nrow(x) == matched, all(x$mannvirki == 6510))
note <- c("# LMÍ's lighthouses (IS 50V structures of class 6510, viti), fetched by dump/natt/lighthouses.R (plan 074 step 9, the aids).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                 ". Open data of Náttúrufræðistofnun Íslands (IS 50V); not for navigation."), "",
          paste0("## ", basename(f)), paste0("request: ", url), paste0("bytes: ", file.size(f)),
          paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)),
          paste0("features: ", nrow(x), " (the server's own count ", matched, ")"),
          paste0("coordinate system: ", sf::st_crs(x)$input),
          paste0("attributes: ", paste(names(sf::st_drop_geometry(x)), collapse = ", ")),
          paste0("edition (gagnasafn): ", paste(unique(x$gagnasafn), collapse = "; ")),
          paste0("accuracy (nakvaemnixy, m): ", paste(names(table(x$nakvaemnixy)), table(x$nakvaemnixy), sep = " ", collapse = ", ")))
writeLines(note, file.path(out_dir, "README-provenance.txt")); cat(note, sep = "\n")
