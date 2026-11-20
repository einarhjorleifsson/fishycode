# EMODnet Human Activities' worldwide wrecks round Iceland (32 W to 6 W, 59 N to 70 N): the UK Hydrographic Office's wrecks
# and obstructions, a subset served by EMODnet (layer emodnet:wwshipwrecks, Open Government Licence v3). A witness for plan
# plan 082's curated wreck list (the maintainer, 2026-11-16: "these wreck list can by matched against any of the other wreck
# list we have in already gathered datasource. This way we have more than one witness"). Its other wreck layer,
# emodnet:heritageshipwrecks (France, Ireland, England, the Mediterranean), has none in the box (counted 2026-11-16).
# Input: https://ows.emodnet-humanactivities.eu/wfs (WFS 2.0.0 GetFeature, GeoJSON, bbox in EPSG:4326, one request).
# Output: $FISHYDATA/raw/external/emodnet_human_activities/wwshipwrecks.geojson as delivered, and README-provenance.txt.
# Run once, from the repo root: Rscript dump/emodnet/human_activities.R
# Written by Claude (AI).
source("R/paths.R")
out_dir <- fd_raw("external", "emodnet_human_activities"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
W <- "https://ows.emodnet-humanactivities.eu/wfs?service=WFS&version=2.0.0&request=GetFeature&typeNames=emodnet:wwshipwrecks"
BBOX <- "&bbox=59,-32,70,-6,urn:ogc:def:crs:EPSG::4326"; UA <- "fishycode data fetch"
get <- function(u) httr2::request(u) |> httr2::req_user_agent(UA) |> httr2::req_timeout(900) |> httr2::req_perform() |> httr2::resp_body_string()
n <- as.integer(sub('.*numberMatched="([0-9]+)".*', "\\1", get(paste0(W, "&resultType=hits", BBOX))))
f <- file.path(out_dir, "wwshipwrecks.geojson")
writeLines(get(paste0(W, "&outputFormat=application/json", BBOX)), f, useBytes = TRUE)
g <- sf::read_sf(f)
stopifnot(nrow(g) == n)
note <- c("# EMODnet Human Activities' worldwide wrecks (UKHO) round Iceland, fetched by dump/emodnet/human_activities.R (plan 082).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), ". Box: 32 W to 6 W, 59 N to 70 N."),
          "# Terms: UK Hydrographic Office, Open Government Licence v3 (https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/); not for navigation.",
          "", "## wwshipwrecks.geojson", paste0("request: ", W, "&outputFormat=application/json", BBOX, " (one request)"),
          paste0("bytes: ", file.size(f)), paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)),
          paste0("features: ", nrow(g), " (the server's own count in the box ", n, ")"),
          paste0("attributes: ", paste(setdiff(names(g), attr(g, "sf_column")), collapse = ", ")),
          "", "## emodnet:heritageshipwrecks", "features in the box: 0 (counted, not fetched)")
writeLines(note, file.path(out_dir, "README-provenance.txt")); cat(note, sep = "\n")
