# Three global seafloor datasets, for what NAGTEC's database would hold round Iceland (the maintainer, 2026-11-16: "NAGTEC's
# database isn't public - try dig into other source locations, possibly international ones"; "no permission needed for
# downloading and mining"), each into its own folder as delivered:
#   gsfml  the Global Seafloor Fabric and Magnetic Lineation project's seafloor fabric (Matthews et al. 2011, Wessel et al. 2015:
#          fracture zones, discordant zones, extinct ridges, propagating ridges and V-shaped structures, pseudofaults), the
#          snapshot as a zipped shapefile set (University of Hawaiʻi, SOEST);
#   usgs   the USGS's polygons of global undersea features for geographic searches (Open-File Report 2014-1040: named basins,
#          ridges, fracture zones, seamounts and more), zipped shapefile;
#   iodp   the drill holes of the Deep Sea Drilling Project, the Ocean Drilling Program and the International Ocean Discovery
#          Program (an ArcGIS feature service built from IODP's own KML of drilled holes), those in a box 45 W to 0, 50 N to 75 N.
# Output: $FISHYDATA/raw/external/{gsfml/GSFML_SF.zip, usgs_undersea/undersea_features.zip, iodp/drilled_holes.geojson}, and a
# README-provenance.txt in each (the request, the date, bytes, sha256). Run once, from the repo root:
#   Rscript dump/seafloor/global.R
# Written by Claude (AI).
source("R/paths.R")
UA <- "fishycode data fetch"; when <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
fetch <- function(url, dir, file, what, extra = character()) {
  d <- fd_raw("external", dir); dir.create(d, recursive = TRUE, showWarnings = FALSE); f <- file.path(d, file)
  httr2::request(url) |> httr2::req_user_agent(UA) |> httr2::req_timeout(900) |> httr2::req_perform(path = f)
  note <- c(paste0("# ", what, ", fetched by dump/seafloor/global.R (plan 074)."), paste0("# Fetched ", when, "."), "", paste0("## ", file),
            paste0("request: ", url), paste0("bytes: ", file.size(f)), paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)), extra)
  writeLines(note, file.path(d, "README-provenance.txt")); cat(note, sep = "\n"); f }
fetch("https://www.soest.hawaii.edu/PT/GSFML/SF/DATA/GSFML_SF.zip", "gsfml", "GSFML_SF.zip",
      "The GSFML seafloor fabric (fracture zones and other traces), global",
      c("cite: Matthews et al. (2011) doi:10.1029/2011JB008413; Wessel et al. (2015) doi:10.1002/2015GC005853; https://gsfml.earthbyte.org"))
fetch("https://pubs.usgs.gov/of/2014/1040/data/undersea_features.zip", "usgs_undersea", "undersea_features.zip",
      "The USGS's polygons of global undersea features (Open-File Report 2014-1040)",
      c("cite: USGS Open-File Report 2014-1040; https://cmgds.marine.usgs.gov/catalog/whcmsc/open_file_report/ofr2014-1040/undersea_features.html"))
B <- "https://services2.arcgis.com/qRqOFxxnwUHOSocZ/ArcGIS/rest/services/Integrated_Ocean_Drilling_Program_Sites/FeatureServer/6/query"
# by the holes' own latitude and longitude: the service stores its points in NAD83 / UTM 9N (EPSG:26909), and a box in WGS 84
# finds none of them
Q <- "?where=Latitude%3E50%20AND%20Latitude%3C75%20AND%20Longtitude%3E-45%20AND%20Longtitude%3C0&outFields=*&outSR=4326"
n <- jsonlite::fromJSON(httr2::request(paste0(B, Q, "&returnCountOnly=true&f=json")) |> httr2::req_user_agent(UA) |> httr2::req_perform() |> httr2::resp_body_string())$count
f <- fetch(paste0(B, Q, "&f=geojson"), "iodp", "drilled_holes.geojson", "DSDP, ODP and IODP drill holes in a box round Iceland",
           c(paste0("features: the server's own count ", n), "service: built from http://kml.iodp.org/IODP_Drilled_Holes.kml (2019-02-11)"))
stopifnot(nrow(sf::read_sf(f)) == n)
