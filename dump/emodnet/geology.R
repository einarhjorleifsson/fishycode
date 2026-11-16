# EMODnet Geology's layers in a box round Iceland (32 W to 6 W, 59 N to 70 N), as its GeoServer serves them
# (drive.emodnet-geology.eu, WFS): BGR's general physiographic features (named) and geomorphology, the pre-Quaternary and
# Quaternary geology (lithology, age, faults), GTK's seabed substrate at 1:1 000 000, 1:250 000 and the multiscale 1:50 000
# and its seabed erosion, ISPRA's geological events (volcanic centres, submarine landslides, Quaternary tectonics, tsunami
# origins; much of it ÍSOR's contribution for Iceland), BGS's last glacial maximum landscape, palaeo-coastlines and channels,
# GEUS's borehole and geophysical data indexes, GSI's marine minerals (aggregates, hydrocarbons, polymetallic sulphides).
# The international sources for what NAGTEC's database holds (the maintainer, 2026-11-16: "NAGTEC's database isn't public -
# try dig into other source locations, possibly international ones that may actually contain whatever is likely to be in the
# NAGTEC database"; "no permission needed for downloading and mining"). Left out: TNO's coastal migration and type (Europe's
# coast in many scales; ÍSOR's own coastal type is in raw/external/isor), the layers with no feature in the box.
# Input: https://drive.emodnet-geology.eu/geoserver/wfs (WFS 2.0.0 GetFeature, GeoJSON, bbox in EPSG:4326, one request a layer).
# Output: $FISHYDATA/raw/external/emodnet_geology/<workspace>__<layer>.geojson, as delivered (the pages joined), and
# README-provenance.txt beside them. Terms: EMODnet's (CC BY 4.0 for most; each layer's record in its catalogue).
# Run once, from the repo root: Rscript dump/emodnet/geology.R
# Written by Claude (AI).
source("R/paths.R")
out_dir <- fd_raw("external", "emodnet_geology"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
W <- "https://drive.emodnet-geology.eu/geoserver/wfs?service=WFS&version=2.0.0&request=GetFeature&typeNames="
BBOX <- "&bbox=59,-32,70,-6,urn:ogc:def:crs:EPSG::4326"; UA <- "fishycode data fetch"
LAYERS <- c("bgr:general_physiographic_features_20261109", "bgr:geomorphology_poly_20261109", "bgr:geomorphology_line_20261109",
            "bgr:pre_quaternary_lithology_20261109", "bgr:pre_quaternary_age_20261109", "bgr:pre_quaternary_faults_20261109",
            "bgr:quaternary_lithology_20261109", "bgr:quaternary_age_20261109",
            "gtk:seabed_substrate_1m", "gtk:seabed_substrate_250k", "gtk:seabed_substrate_50k_multiscale", "gtk:seabed_erosion",
            "ispra:geological_event_distribution_250k", "ispra:tectonics_lin_250k", "ispra:tectonics_lin_100k",
            "ispra:volcanic_center_pt_250k", "ispra:volcanic_center_pol_250k", "ispra:volcanic_center_lin_250k", "ispra:volcanic_center_pt_100k",
            "ispra:volcanic_center_pol_100k", "ispra:landslide_pol_250k", "ispra:landslide_pt_250k", "ispra:landslide_lin_250k", "ispra:landslide_pol_100k",
            "ispra:tsunami_origin_pt", "bgs:PL_Lastglacialmaximum", "bgs:PL_Palaeocoastline", "bgs:PG_Palaeo_Channel",
            "geus:borehole_index", "geus:geophysics_index", "gsi:MarineAggregatesPoint", "gsi:MarineHydrocarbonsPoint", "gsi:PolymetallicSulphidesPoint")
get <- function(u) httr2::request(u) |> httr2::req_user_agent(UA) |> httr2::req_timeout(900) |> httr2::req_perform() |> httr2::resp_body_string()
note <- c("# EMODnet Geology's layers round Iceland, fetched by dump/emodnet/geology.R (plan 074).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), ". Box: 32 W to 6 W, 59 N to 70 N. Terms: EMODnet's; not for navigation."), "")
for (layer in LAYERS) {
  q <- utils::URLencode(layer, reserved = TRUE)
  n <- as.integer(sub('.*numberMatched="([0-9]+)".*', "\\1", get(paste0(W, q, "&resultType=hits", BBOX))))
  # one request a layer (every layer here under 10 000 in the box): the server pages only a layer with a primary key ("Cannot
  # do natural order without a primary key"), and the count below checks the answer is whole
  g <- jsonlite::fromJSON(get(paste0(W, q, "&outputFormat=application/json", BBOX)), simplifyVector = FALSE)
  feats <- g$features; crs <- g$crs; step <- "none"
  stopifnot(length(feats) == n)
  f <- file.path(out_dir, paste0(sub(":", "__", layer), ".geojson"))
  writeLines(jsonlite::toJSON(list(type = "FeatureCollection", crs = crs, features = feats), auto_unbox = TRUE, digits = NA, null = "null"), f, useBytes = TRUE)
  note <- c(note, paste0("## ", basename(f)), paste0("request: ", W, q, "&outputFormat=application/json", BBOX, " (one request)"),
            paste0("bytes: ", file.size(f)), paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)),
            paste0("features: ", length(feats), " (the server's own count in the box ", n, ")"),
            paste0("attributes: ", if (length(feats)) paste(names(feats[[1]]$properties), collapse = ", ") else ""), "")
  message(layer, ": ", length(feats))
}
writeLines(note, file.path(out_dir, "README-provenance.txt"))
