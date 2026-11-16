# OpenStreetMap's wrecks round Iceland (32 W to 6 W, 59 N to 70 N): every node, way or relation tagged seamark:type=wreck
# (OpenSeaMap's charted wrecks) or historic=wreck, one Overpass query, as delivered. A witness for plan 074 step 9's curated
# wreck list (the maintainer, 2026-11-16: "these wreck list can by matched against any of the other wreck list we have in
# already gathered datasource. This way we have more than one witness").
# Output: $FISHYDATA/raw/external/osm_wrecks/wrecks_<YYYYMMDD>.osm.gz (XML, ways and relations with their centre) and
# README-provenance.txt. OVERPASS_URL names the server, overpass-api.de by default; VK's mirror,
# https://maps.mail.ru/osm/tools/overpass/api/interpreter, answered plan 075's fetch when overpass-api.de did not.
# Run once, from the repo root: Rscript dump/osm/wrecks.R
# Data © OpenStreetMap contributors, ODbL. Written by Claude (AI).
source("R/osm_fetch.R")
URL <- Sys.getenv("OVERPASS_URL", "https://overpass-api.de/api/interpreter")
DATE <- format(Sys.time(), "%Y%m%d", tz = "UTC")
B <- "(59,-32,70,-6)"
q <- paste0('[out:xml][timeout:600];(nwr["seamark:type"="wreck"]', B, ';nwr["historic"="wreck"]', B, ';);out meta center;')
dir <- fd_raw("external", "osm_wrecks"); dir.create(dir, recursive = TRUE, showWarnings = FALSE)
xml <- file.path(dir, paste0("wrecks_", DATE, ".osm")); gz <- paste0(xml, ".gz")
osm_fetch(q, xml, url = URL, patience_h = 2, wait_max_s = 600)
x <- xml2::read_xml(xml)
n <- length(xml2::xml_find_all(x, "/osm/node|/osm/way|/osm/relation"))
base <- xml2::xml_attr(xml2::xml_find_first(x, "/osm/meta"), "osm_base")
R.utils::gzip(xml, destname = gz)
note <- c("# OpenStreetMap's wrecks round Iceland, fetched by dump/osm/wrecks.R (plan 074 step 9).",
          paste0("# Fetched ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), ". Box: 32 W to 6 W, 59 N to 70 N. Data © OpenStreetMap contributors, ODbL."),
          "", paste0("## ", basename(gz)), paste0("server: ", URL), paste0("query: ", q), paste0("osm_base: ", base),
          paste0("objects: ", n), paste0("bytes: ", file.size(gz)), paste0("sha256: ", digest::digest(gz, algo = "sha256", file = TRUE)))
writeLines(note, file.path(dir, "README-provenance.txt")); cat(note, sep = "\n")
