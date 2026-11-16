# ÍSOR's (Iceland GeoSurvey) data on the seabed and the coast, as its map server serves them (kort.isor.is, ArcGIS REST): the
# seabed's landforms (named troughs with outlines, the last glacial maximum's grounding line, the shelf break, moraines, glacial
# and gravity streamlines, canals along the shelf edge, turbidity and meltwater channels, plough marks), volcanism and hazards
# (volcanic features as points, lines and areas, submarine landslides and scarps, dykes, faults), offshore geothermal sites, the
# seabed's substrate and sedimentation rate, boreholes, cores and grab samples on the shelf, the coast's type and behaviour,
# the survey lists, wrecks (ÍSOR's, the list SKFI's, Landhelgisgæslan's) and diving sites, and the submerged lavas of
# Veðurstofan's volcanic systems (served from the same server). Much of it ÍSOR compiled for EMODnet Geology.
# The maintainer, 2026-11-16: "anything that has coordinates out at sea or in coastal areas if of interest here"; "ISOR (ÍSOR)
# is another institute to potentially mine for things"; "no permission needed for downloading and mining".
# Input: https://kort.isor.is/server/rest/services (each layer's query, f=geojson, paged by resultOffset; WGS 84).
# Output: $FISHYDATA/raw/external/isor/<service>__<layer id>_<layer name>.geojson, as delivered (the pages joined), and
# README-provenance.txt beside them (each request, the date, bytes, sha256, the features against the server's own count, the
# attributes). Terms: ÍSOR's ("Hafðu samband við ÍSOR vegna aðgengis að gögnum og vefþjónustu", its portal); internal use.
# The geometry: a MapServer layer may withhold it from `query` (hafsbotn/Botngerd, both layers, 2026-11-16: every feature's
# geometry null, in any outSR, with returnGeometry=true), while its `identify` returns it whole (the same vertices at any map
# scale: 201,636 for the largest substrate polygon both ways). There the geometry is taken from `identify` over the layer's
# extent and joined to the query's features by the object id; the attributes stay the query's (`identify` gives display
# strings). The provenance says which layers.
# Run once, from the repo root: Rscript dump/isor/hafsbotn.R. ISOR_ONLY (a regular expression on the service) fetches only
# the services it matches and replaces only their sections in README-provenance.txt, the others kept as they were.
# Written by Claude (AI).
source("R/paths.R"); `%||%` <- function(a, b) if (is.null(a)) b else a
out_dir <- fd_raw("external", "isor"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
B <- "https://kort.isor.is/server/rest/services"; UA <- "fishycode data fetch"
SERVICES <- c("hafsbotn/Landmótun/FeatureServer", "hafsbotn/Eldvirkni_og_jarðvá/FeatureServer", "hafsbotn/Jardhiti_i_sjo/MapServer",
              "hafsbotn/Botngerd/MapServer", "hafsbotn/Borholur__kjarna_og_gripsýni/FeatureServer", "hafsbotn/Strandgerð_Coastal_type/FeatureServer",
              "hafsbotn/Survey_List/MapServer", "hafsbotn/Efnahagslögsaga_Íslands_200NM/FeatureServer", "vindorka_a_hafi/Infrastructure/MapServer",
              "vedurstofa/Layers/MapServer")
js <- function(u) jsonlite::fromJSON(httr2::request(u) |> httr2::req_user_agent(UA) |> httr2::req_timeout(300) |> httr2::req_perform() |> httr2::resp_body_string(), simplifyVector = FALSE)
enc <- function(s) paste(vapply(strsplit(s, "/")[[1]], utils::URLencode, "", reserved = TRUE), collapse = "/")
ONLY <- Sys.getenv("ISOR_ONLY"); if (nzchar(ONLY)) SERVICES <- grep(ONLY, SERVICES, value = TRUE)
stopifnot(length(SERVICES) > 0)
when <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
note <- c("# ÍSOR's data on the seabed and the coast, fetched by dump/isor/hafsbotn.R (plan 074).",
          paste0("# Fetched ", when, ". Terms: ÍSOR's; internal use; not for navigation."), "")
# the geometry a query withheld, from identify over the layer's extent (in WGS 84), as GeoJSON geometries by object id
identify_geometry <- function(su, l, lm, oid) {
  e <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(c(xmin = lm$extent$xmin, ymin = lm$extent$ymin, xmax = lm$extent$xmax,
          ymax = lm$extent$ymax), crs = sf::st_crs(lm$extent$spatialReference$latestWkid %||% lm$extent$spatialReference$wkid))), 4326))
  e <- paste(floor(e[["xmin"]]) , floor(e[["ymin"]]), ceiling(e[["xmax"]]), ceiling(e[["ymax"]]), sep = ",")
  u <- paste0(su, "/identify?geometry=", e, "&geometryType=esriGeometryEnvelope&sr=4326&layers=all:", l$id, "&tolerance=0&mapExtent=", e,
              "&imageDisplay=1000,1000,96&returnGeometry=true&returnFieldName=true&f=json")
  r <- js(u)$results
  fs <- list(geometryType = lm$geometryType, spatialReference = list(wkid = 4326),
             fields = list(list(name = "oid_", type = "esriFieldTypeString")),
             features = lapply(r, function(x) list(attributes = list(oid_ = as.character(x$attributes[[oid]])), geometry = x$geometry)))
  tf <- tempfile(fileext = ".json"); tg <- tempfile(fileext = ".geojson")
  writeLines(jsonlite::toJSON(fs, auto_unbox = TRUE, digits = NA, null = "null"), tf, useBytes = TRUE)
  sf::write_sf(sf::read_sf(tf, quiet = TRUE), tg, quiet = TRUE)
  g <- jsonlite::fromJSON(tg, simplifyVector = FALSE)$features; unlink(c(tf, tg))
  list(geometry = stats::setNames(lapply(g, `[[`, "geometry"), vapply(g, function(x) x$properties$oid_, "")), url = u, n = length(r)) }
for (sv in SERVICES) {
  su <- paste0(B, "/", enc(sv)); meta <- js(paste0(su, "?f=json"))
  for (l in meta$layers) {
    if (grepl("^vedurstofa", sv) && !grepl("submerged", l$name, ignore.case = TRUE)) next   # Veðurstofan's: the submerged lavas alone
    lu <- paste0(su, "/", l$id); lm <- js(paste0(lu, "?f=json")); if (!identical(lm$type, "Feature Layer")) next
    n <- js(paste0(lu, "/query?where=1%3D1&returnCountOnly=true&f=json"))$count
    step <- min(as.integer(lm$maxRecordCount %||% 1000), 1000); feats <- list(); off <- 0
    # the order by the layer's own id field (OBJECTID_1 on some: a missing one makes the server refuse the query)
    oid <- lm$objectIdField %||% { k <- vapply(lm$fields, function(x) identical(x$type, "esriFieldTypeOID"), TRUE); if (any(k)) lm$fields[[which(k)[1]]]$name else NULL }
    while (off < n) {
      q <- paste0(lu, "/query?where=1%3D1&outFields=*&outSR=4326&f=geojson&resultOffset=", off, "&resultRecordCount=", step,
                  if (!is.null(oid)) paste0("&orderByFields=", utils::URLencode(oid)) else "")
      g <- js(q); feats <- c(feats, g$features); off <- off + step
      if (!length(g$features)) break
    }
    stopifnot(length(feats) == n)                                 # every feature, the pages joined
    from_identify <- NULL
    if (n && all(vapply(feats, function(x) is.null(x$geometry), TRUE))) {
      ig <- identify_geometry(su, l, lm, oid)
      key <- vapply(feats, function(x) as.character(x$properties[[oid]]), "")
      stopifnot(ig$n == n, !anyDuplicated(names(ig$geometry)), all(key %in% names(ig$geometry)))
      for (k in seq_along(feats)) feats[[k]]$geometry <- ig$geometry[[key[k]]]
      from_identify <- ig$url
    }
    nm <- gsub("[^A-Za-z0-9_]+", "_", iconv(paste0(sub("/(FeatureServer|MapServer)$", "", sv), "__", l$id, "_", l$name), "UTF-8", "ASCII//TRANSLIT"))
    f <- file.path(out_dir, paste0(nm, ".geojson"))
    writeLines(jsonlite::toJSON(list(type = "FeatureCollection", features = feats), auto_unbox = TRUE, digits = NA, null = "null"), f, useBytes = TRUE)
    note <- c(note, paste0("## ", basename(f)), paste0("layer: ", sv, " ", l$id, " \"", l$name, "\" (", lm$geometryType, ")"),
              paste0("request: ", lu, "/query?where=1=1&outFields=*&outSR=4326&f=geojson (paged by ", step, ")"), paste0("bytes: ", file.size(f)),
              paste0("sha256: ", digest::digest(f, algo = "sha256", file = TRUE)), paste0("features: ", length(feats), " (the server's own count ", n, ")"),
              paste0("attributes: ", paste(vapply(lm$fields, function(x) x$name, ""), collapse = ", ")),
              if (!is.null(from_identify)) c(paste0("geometry: withheld by the query; from identify, joined by ", oid, " (", when, ")"),
                                             paste0("identify: ", from_identify)), "")
    message(sv, " ", l$id, " ", l$name, ": ", length(feats), if (!is.null(from_identify)) " (geometry from identify)" else "")
  }
}
pf <- file.path(out_dir, "README-provenance.txt")
if (nzchar(ONLY) && file.exists(pf)) {
  # replace only the refetched layers' sections; keep the rest, and say so in the header
  blocks <- function(x) { h <- grep("^## ", x); if (!length(h)) return(list(head = x, b = list()))
    list(head = x[seq_len(h[1] - 1)], b = stats::setNames(lapply(seq_along(h), function(i) x[h[i]:(c(h[-1] - 1, length(x))[i])]), sub("^## ", "", x[h]))) }
  old <- blocks(readLines(pf, encoding = "UTF-8")); new <- blocks(note)
  b <- old$b; for (k in names(new$b)) b[[k]] <- new$b[[k]]
  head <- c(sub("\\s+$", "", old$head[nzchar(old$head)]), paste0("# Refetched ", when, " (ISOR_ONLY=", ONLY, "): ", paste(names(new$b), collapse = ", "), "."), "")
  note <- c(head, unlist(b, use.names = FALSE))
}
writeLines(note, pf)
