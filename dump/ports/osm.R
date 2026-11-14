# OpenStreetMap's port features: five tags, over Greenland, Iceland, the Faroes, Europe and the Mediterranean and Black Seas.
# Output: raw/ports/osm_<YYYYMMDD>/<tile>.osm.gz  each Overpass response as delivered (XML, gzipped)
#         raw/ports/ports_osm_<YYYYMMDD>.gpkg     the tagged features of every tile, one row per OSM object
#
# The first fetch (raw/ports/ports_osm.gpkg, 2026-09, kept as it is) read one key, harbour=*, worldwide: 5,233 features.
# OSM draws most of its ports otherwise: worldwide (taginfo, 2026-11-14) 31,961 leisure=marina, 25,382
# seamark:type=harbour, 5,414 industrial=port and 2,570 landuse=harbour, against 5,429 harbour=*. Numana's harbour, for
# one, is a leisure=marina node and a landuse=harbour relation (decision 320). This fetch reads all five (plan 075, the
# maintainer, 2026-11-14), limited to the region the flow and its colleagues work in (his choice: "Greenland, Iceland,
# Faroes, Europe and then the Mediterranean seas"); reference/ports/port_feature.R reads both files, one row per OSM
# object, the newer where both hold it.
#
# Overpass answers a large box slowly and at times not at all (502, "runtime error"), so the region is cut into 5-degree
# cells fetched one at a time with a random pause between them (median 15 s, never under 10 s), each query is posted with retries, and the response is saved, and
# checked whole, before osmdata parses it. Rerun with the same DATE to resume:
# a tile whose response is saved is not fetched again. OSM_TILES (comma-separated tile names) fetches only those.
# Data © OpenStreetMap contributors, ODbL.

library(osmdata)
library(sf)
library(dplyr)

DATE <- Sys.getenv("OSM_DATE", format(Sys.Date(), "%Y%m%d"))
URL <- "https://overpass-api.de/api/interpreter"
TAGS <- c("\"harbour\"", "\"landuse\"=\"harbour\"", "\"leisure\"=\"marina\"", "\"industrial\"=\"port\"",
          "\"seamark:type\"=\"harbour\"")
# The region, xmin, ymin, xmax, ymax: Europe with Macaronesia and the Mediterranean and Black Seas, the Arctic, the Barents
# and White Seas' east, and Greenland; cut into 5-degree cells, each its own query (the maintainer: "take your time rather
# than mining too big stuff at any one time"), with a random pause between them ("a median around 15 seconds and a floor
# at 10 seconds")
REGION <- list(europe_med = c(-32, 27, 45, 72), arctic = c(-32, 72, 60, 82), barents = c(45, 60, 60, 72),
               greenland = c(-75, 58, -10, 84))
CELL <- 5
# the pause after each answer, random: a floor of 10 s and a median of 15 s (10 s plus an exponential draw with a 5 s median)
pause_s <- function() 10 + stats::rexp(1, rate = log(2) / 5)
tiles <- list()
for (rn in names(REGION)) {
  r <- REGION[[rn]]
  for (x in seq(floor(r[1] / CELL) * CELL, r[3] - 1e-9, CELL)) for (y in seq(floor(r[2] / CELL) * CELL, r[4] - 1e-9, CELL)) {
    b <- c(max(x, r[1]), max(y, r[2]), min(x + CELL, r[3]), min(y + CELL, r[4]))
    n <- sprintf("x%+04d_y%+03d", x, y)
    # a cell in two regions' boxes: the first region's clip keeps the name; the second's, unless the first holds it, is
    # fetched as well, named by its region (until 2026-11-14 it was dropped, and with it 72-75 N and a strip of Greenland)
    if (n %in% names(tiles)) {
      k <- tiles[[n]]
      if (b[1] >= k[1] && b[2] >= k[2] && b[3] <= k[3] && b[4] <= k[4]) next
      n <- paste0(n, "_", rn)
    }
    tiles[[n]] <- b
  }
}
only <- strsplit(Sys.getenv("OSM_TILES", ""), ",")[[1]]
if (length(only)) tiles <- tiles[names(tiles) %in% only]

dir <- fd_raw("ports", paste0("osm_", DATE))
dir.create(dir, showWarnings = FALSE, recursive = TRUE)
fetch <- function(q, file, tries = 8) {
  for (i in seq_len(tries)) {
    r <- tryCatch(httr2::request(URL) |> httr2::req_user_agent("fishycode port list (R osmdata)") |>
                    httr2::req_body_form(data = q) |> httr2::req_timeout(1200) |> httr2::req_perform(path = file),
                  error = function(e) e)
    txt <- if (!inherits(r, "error") && file.exists(file)) readLines(file, warn = FALSE) else character()
    # a complete answer opens as XML and closes the osm element; a timeout or a memory limit leaves a remark (at the end)
    ok <- length(txt) && grepl("^<\\?xml", txt[1]) && any(grepl("^</osm>", tail(txt, 3))) && !any(grepl("<remark>", txt))
    if (ok) return(invisible(TRUE))
    message(sprintf("  try %d failed: %s", i, if (inherits(r, "error")) conditionMessage(r) else "an error response"))
    unlink(file)
    Sys.sleep(min(300, 30 * i))
  }
  stop("Overpass gave no answer for ", basename(file))
}

keep_tagged <- function(d) {
  if (is.null(d) || !nrow(d)) return(NULL)
  # osmdata 0.4.0 leaves osm_id out of some layers (two unnamed relations in the Faroes' cell): the id is the row name
  if (!"osm_id" %in% names(d)) d$osm_id <- rownames(d)
  d$osm_id <- ifelse(is.na(d$osm_id), rownames(d), as.character(d$osm_id))
  v <- function(k) if (k %in% names(d)) d[[k]] else rep(NA_character_, nrow(d))
  d[!is.na(v("harbour")) | v("landuse") %in% "harbour" | v("leisure") %in% "marina" | v("industrial") %in% "port" |
      v("seamark:type") %in% "harbour", ]
}

# osmdata_sf() stops on a response whose nodes carry no tag at all (x+040_y+35: two tagged ways, 53 bare nodes). Then the
# cell is read by GDAL's OSM driver: its ways and relations, each with the five keys and its name, a one-part
# multipolygon as a polygon, as osmdata gives it.
read_gdal <- function(xml) {
  keys <- c("harbour", "landuse", "leisure", "industrial", "seamark:type")
  tag <- function(other, k) { m <- regmatches(other, regexec(paste0('"', k, '"=>"([^"]*)"'), other)); vapply(m, \(x) if (length(x) == 2) x[2] else NA_character_, "") }
  one <- function(layer) {
    x <- tryCatch(suppressWarnings(st_read(xml, layer = layer, quiet = TRUE)), error = function(e) NULL)
    if (is.null(x) || !nrow(x)) return(NULL)
    id <- if ("osm_way_id" %in% names(x)) coalesce(x$osm_way_id, x$osm_id) else x$osm_id
    out <- st_sf(osm_id = as.character(id), name = if ("name" %in% names(x)) x$name else NA_character_, geometry = st_geometry(x))
    for (k in keys) out[[k]] <- if (k %in% names(x)) x[[k]] else tag(coalesce(x$other_tags, ""), k)
    out
  }
  x <- bind_rows(lapply(c("lines", "multilinestrings", "multipolygons", "other_relations"), one))
  if (!nrow(x)) return(NULL)
  single <- st_geometry_type(x) == "MULTIPOLYGON" & lengths(st_geometry(x)) == 1
  st_geometry(x)[single] <- st_cast(st_geometry(x)[single], "POLYGON")
  x
}

osm <- list()
for (t in names(tiles)) {
  gz <- file.path(dir, paste0(t, ".osm.gz"))
  q <- opq(bbox = tiles[[t]], timeout = 300) |> add_osm_features(features = TAGS)
  if (!file.exists(gz)) {
    message("fetching ", t)
    xml <- file.path(dir, paste0(t, ".osm"))
    fetch(opq_string(q), xml)
    R.utils::gzip(xml, destname = gz)
    Sys.sleep(pause_s())
  }
  xml <- tempfile(fileext = ".osm")
  R.utils::gunzip(gz, destname = xml, remove = FALSE)
  x <- tryCatch(osmdata_sf(q, doc = xml), error = function(e) { message("  osmdata_sf failed (", conditionMessage(e), "): read by GDAL"); NULL })
  osm[[t]] <- if (is.null(x)) keep_tagged(read_gdal(xml)) else
    bind_rows(lapply(c("osm_points", "osm_lines", "osm_polygons", "osm_multilines", "osm_multipolygons"), \(n) keep_tagged(x[[n]])))
  unlink(xml)
  if (is.null(osm[[t]])) osm[[t]] <- tibble()
  message(sprintf("%s (%d of %d): %d tagged features", t, match(t, names(tiles)), length(tiles), nrow(osm[[t]])))
}
osm <- bind_rows(osm) |>
  mutate(.type = as.character(st_geometry_type(geometry))) |>
  distinct(.type, osm_id, .keep_all = TRUE) |>        # an object in two tiles once
  select(-.type) |>
  as_tibble() |>
  janitor::clean_names() |>
  janitor::remove_empty(which = "cols") |>
  select(osm_id, name, any_of(c("harbour", "landuse", "leisure", "industrial", "seamark_type")), geometry, everything())
if (!length(only)) osm |> st_as_sf() |> write_sf(fd_raw("ports", paste0("ports_osm_", DATE, ".gpkg")), delete_dsn = TRUE)
message(sprintf("%d features%s", nrow(osm), if (length(only)) " (a test of some tiles: no gpkg written)" else ""))
