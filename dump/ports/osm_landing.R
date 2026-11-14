# OpenStreetMap's small landings: anything that may serve a small-scale fishing vessel as a landing place (plan 075 §2.1,
# step 5; the maintainer, 2026-11-14: "include record from osm on anything that may look like a potential landing site").
# Output: raw/ports/landings_osm_<YYYYMMDD>/<cell>.osm.gz   each Overpass answer as delivered (XML, gzipped)
#         raw/ports/landings_osm_<YYYYMMDD>.gpkg            the tagged features of every cell, one row per OSM object
#
# The port fetch's way (dump/ports/osm.R, 288 tiles answered on 2026-11-14), kept plain (the maintainer, 2026-11-14: "drop
# any clever stuff, use what (has) worked, even though it takes time"): the countries' boxes cut into 5-degree cells, one
# Overpass query per cell for every tag below at once, one cell at a time with a random pause (median 15 s, never under
# 10 s); each answer saved, and checked whole, before it is read. When Overpass does not answer, the fetch waits and tries
# again, at most every 30 minutes, for up to a day, rather than stop. Rerun with the same LANDING_DATE to resume: a cell
# whose answer is saved is not fetched again, and a box added to REGION fetches only its new cells. LANDING_CELLS
# (comma-separated cell names) fetches only those, and writes no gpkg. OVERPASS_URL names the server: overpass-api.de by
# default; VK's public mirror, https://maps.mail.ru/osm/tools/overpass/api/interpreter, answered the fetch of 2026-11-14
# while overpass-api.de refused connections from this machine (the maintainer: "Use the mirror"). Each answer's
# osm_base says how fresh the server's data were.
#
# The tags: slipways (leisure=slipway, the boat-ramp symbol); piers and quays, and breakwaters and groynes as context
# (man_made); seamark small-craft facilities and moorings. Measured on a pilot (study archive/2026-11-14-port-layer, plan
# 075 §4.2): 4,805 features over Portugal, the Azores and Madeira, 28,204 over Denmark. The places: those of the EM4SSF
# hackathon's case studies and partners (Italy, CS1 and the host; Greece; Spain; Portugal with the Azores and Madeira;
# Denmark), France, which the project's text names, and Iceland (the maintainer, 2026-11-14; Italy added on a check of the
# case studies).
# Data © OpenStreetMap contributors, ODbL.

source("R/osm_fetch.R")   # run from the repository's root; targets would source R/ itself

DATE <- Sys.getenv("LANDING_DATE", format(Sys.time(), "%Y%m%d", tz = "UTC"))
URL <- Sys.getenv("OVERPASS_URL", "https://overpass-api.de/api/interpreter")
# xmin, ymin, xmax, ymax
REGION <- list(denmark = c(7.9, 54.5, 15.3, 57.8), france = c(-5.3, 41.3, 9.6, 51.2), portugal = c(-9.6, 36.9, -6.1, 42.2),
               azores = c(-31.5, 36.8, -24.8, 39.8), madeira = c(-17.4, 32.3, -16.2, 33.2), spain = c(-9.4, 35.9, 4.4, 43.8),
               canaries = c(-18.2, 27.6, -13.4, 29.5), greece = c(19.3, 34.7, 29.7, 41.8), italy = c(6.6, 35.4, 18.6, 47.1),
               iceland = c(-24.6, 63.2, -13.4, 66.6))
cells <- osm_cells(REGION)
only <- strsplit(Sys.getenv("LANDING_CELLS", ""), ",")[[1]]
if (length(only)) cells <- cells[names(cells) %in% only]

dir <- fd_raw("ports", paste0("landings_osm_", DATE))
dir.create(dir, showWarnings = FALSE, recursive = TRUE)
osm <- list()
for (t in names(cells)) {
  gz <- file.path(dir, paste0(t, ".osm.gz"))
  q <- osmdata::opq(bbox = cells[[t]], timeout = 600) |> osmdata::add_osm_features(features = osm_landing_tags())
  if (!file.exists(gz)) {
    message(sprintf("fetching %s (%d of %d)", t, match(t, names(cells)), length(cells)))
    xml <- file.path(dir, paste0(t, ".osm"))
    osm_fetch(osmdata::opq_string(q), xml, url = URL, patience_h = 24, wait_max_s = 1800)
    R.utils::gzip(xml, destname = gz)
    osm_pause()
  }
  xml <- tempfile(fileext = ".osm")
  R.utils::gunzip(gz, destname = xml, remove = FALSE)
  osm[[t]] <- osm_read(xml, cells[[t]], osm_landing_keys(), osm_landing_keep)
  unlink(xml)
  message(sprintf("%s (%d of %d): %d tagged features", t, match(t, names(cells)), length(cells), NROW(osm[[t]])))
}
osm <- dplyr::bind_rows(osm)
osm <- osm[!duplicated(paste(sf::st_geometry_type(osm), osm$osm_id)), ]   # an object in two cells once
if (!length(only)) sf::write_sf(osm, fd_raw("ports", paste0("landings_osm_", DATE, ".gpkg")), delete_dsn = TRUE)
message(sprintf("%d features%s", nrow(osm), if (length(only)) " (a test of some cells: no gpkg written)" else ""))
