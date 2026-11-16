# Iceland's aids to navigation and Vegagerðin's other data at sea and on the coast, from their official sources: Vegagerðin's
# lights (the national lights: name, position, characteristic, height, range, structure, radar beacon), its harbours, its wave
# buoys, its nearshore wave forecasts' areas (with their weather stations and buoys) and its sea-state webcams, as served by its GeoServer
# (gagnaveita.vegagerdin.is, WFS, open data, the source to be named), and the List of Lights in force (Vitaskrá, published by
# Landhelgisgæslan and Vegagerðin: lights, harbour lights, buoys, beacons and leading marks, radar beacons, with positions).
# The maintainer, 2026-11-16: "I am wandering if there is an official list of these beacon, .... with their specified
# coordinates. care to dig for data that may contain the icelandic features"; "no permission needed for downloading and
# mining"; "we want the "wave buoys" table as well - anything that has coordinates out at sea or in coastal areas if of interest
# here". Wanted for plan 074: the aids' own positions, apart from where a chart letters their names.
# Input: https://gagnaveita.vegagerdin.is/geoserver/wfs (WFS 2.0.0 GetFeature, GeoJSON, each layer's own coordinate system,
# EPSG:3057); https://www.lhg.is/wp-content/uploads/2026/06/Vitaskra_i_gildi.pdf.
# Output: $FISHYDATA/raw/external/vegagerdin/{vitar_2024_1,hafnir_2024_1,dufl_2024_1,vs_afmorkungrunnslod,test_afmorkun,
# TEST_VEFMYNDAVEL}.geojson and Vitaskra_i_gildi.pdf, as
# delivered, and README-provenance.txt beside them (each request, the date, bytes, sha256, the features against the server's
# own count). Run once, from the repo root: Rscript dump/vegagerdin/fetch.R
# Written by Claude (AI).
source("R/paths.R")
out_dir <- fd_raw("external", "vegagerdin"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
UA <- "fishycode data fetch"
WFS <- "https://gagnaveita.vegagerdin.is/geoserver/wfs?service=WFS&version=2.0.0&request=GetFeature&typeNames=gis:"
get <- function(url, path) httr2::request(url) |> httr2::req_user_agent(UA) |> httr2::req_timeout(600) |> httr2::req_perform(path = path)
note <- c("# Iceland's aids to navigation and Vegagerðin's data at sea and on the coast, fetched by dump/vegagerdin/fetch.R (plan 074).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "."), "")
# the wave buoys (dufl: their wave height, period, direction, sea temperature), the forecasts' areas (vs_afmorkungrunnslod; its test
# copy test_afmorkun names each area's weather station and buoy), and the sea-state webcams (a test layer, the only one)
for (layer in c("vitar_2024_1", "hafnir_2024_1", "dufl_2024_1", "vs_afmorkungrunnslod", "test_afmorkun", "TEST_VEFMYNDAVEL")) {
  hits <- httr2::request(paste0(WFS, layer, "&resultType=hits")) |> httr2::req_user_agent(UA) |> httr2::req_perform() |> httr2::resp_body_string()
  matched <- as.integer(sub('.*numberMatched="([0-9]+)".*', "\\1", hits))
  url <- paste0(WFS, layer, "&outputFormat=application/json"); f <- file.path(out_dir, paste0(layer, ".geojson"))
  get(url, f)
  x <- sf::read_sf(f)
  stopifnot(nrow(x) == matched)                                   # the answer whole, not capped by the server
  note <- c(note, paste0("## ", basename(f)), paste0("request: ", url), paste0("bytes: ", file.size(f)),
            paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)),
            paste0("features: ", nrow(x), " (the server's own count ", matched, ")"),
            paste0("coordinate system: ", sf::st_crs(x)$input),
            paste0("attributes: ", paste(names(sf::st_drop_geometry(x)), collapse = ", ")), "")
}
pdf <- file.path(out_dir, "Vitaskra_i_gildi.pdf"); url <- "https://www.lhg.is/wp-content/uploads/2026/06/Vitaskra_i_gildi.pdf"
get(url, pdf)
note <- c(note, "## Vitaskra_i_gildi.pdf", paste0("request: ", url), paste0("bytes: ", file.size(pdf)),
          paste0("sha256: ", digest::digest(pdf, algo = "sha256", file = TRUE)),
          "the List of Lights in force (Vitaskrá), Landhelgisgæslan and Vegagerðin; read as delivered, never edited", "",
          "Terms: Vegagerðin's layers are open data with the source to be named (\"Geta þarf heimilda\", its catalogue record on",
          "gatt.natt.is); the Vitaskrá is a public publication of Landhelgisgæslan and Vegagerðin. Not for navigation.")
writeLines(note, file.path(out_dir, "README-provenance.txt"))
cat(note, sep = "\n")
