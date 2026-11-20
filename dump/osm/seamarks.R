# OpenStreetMap's seamarks round Iceland (32 W to 6 W, 59 N to 70 N): every node, way or relation tagged seamark:type (any
# value: OpenSeaMap's lights, buoys, beacons, radar transponders and marks, and the harbours, rocks and moorings beside them)
# or man_made=lighthouse or man_made=beacon, one Overpass query, as delivered. A witness for plan 082's curated list of
# aids to navigation (the maintainer, 2026-11-16: "similar as we will have a curated harbour list, curated list of lights,
# beacons"); the staging decides which records are aids, so nothing is filtered here.
# Output: $FISHYDATA/raw/external/osm_seamarks/seamarks_<YYYYMMDD>.osm.gz (XML, ways and relations with their centre) and
# README-provenance.txt. OVERPASS_URL names the server, overpass-api.de by default; VK's mirror,
# https://maps.mail.ru/osm/tools/overpass/api/interpreter, answered plan 075's fetch when overpass-api.de did not.
# Run once, from the repo root: Rscript dump/osm/seamarks.R
# Data © OpenStreetMap contributors, ODbL. Written by Claude (AI).
source("R/osm_fetch.R")
URL <- Sys.getenv("OVERPASS_URL", "https://overpass-api.de/api/interpreter")
DATE <- format(Sys.time(), "%Y%m%d", tz = "UTC")
B <- "(59,-32,70,-6)"
q <- paste0('[out:xml][timeout:900];(nwr["seamark:type"]', B, ';nwr["man_made"="lighthouse"]', B, ';nwr["man_made"="beacon"]', B,
            ';);out meta center;')
dir <- fd_raw("external", "osm_seamarks"); dir.create(dir, recursive = TRUE, showWarnings = FALSE)
xml <- file.path(dir, paste0("seamarks_", DATE, ".osm")); gz <- paste0(xml, ".gz")
osm_fetch(q, xml, url = URL, patience_h = 2, wait_max_s = 600)
x <- xml2::read_xml(xml)
obj <- xml2::xml_find_all(x, "/osm/node|/osm/way|/osm/relation")
typ <- xml2::xml_attr(xml2::xml_find_first(obj, "tag[@k='seamark:type']"), "v")
base <- xml2::xml_attr(xml2::xml_find_first(x, "/osm/meta"), "osm_base")
R.utils::gzip(xml, destname = gz)
tab <- sort(table(dplyr::coalesce(typ, "(no seamark:type)")), decreasing = TRUE)
note <- c("# OpenStreetMap's seamarks round Iceland, fetched by dump/osm/seamarks.R (plan 082, the aids).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), ". Box: 32 W to 6 W, 59 N to 70 N. Data © OpenStreetMap contributors, ODbL."),
          "", paste0("## ", basename(gz)), paste0("server: ", URL), paste0("query: ", q), paste0("osm_base: ", base),
          paste0("objects: ", length(obj)), paste0("bytes: ", file.size(gz)), paste0("sha256: ", digest::digest(gz, algo = "sha256", file = TRUE)),
          "seamark:type (objects):", paste0("  ", names(tab), " ", tab))
writeLines(note, file.path(dir, "README-provenance.txt")); cat(note, sep = "\n")
