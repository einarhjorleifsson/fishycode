# Helpers for fetching OSM features from Overpass in 5-degree cells, one query at a time (dump/ports/osm_landing.R;
# dump/ports/osm.R holds the same steps inline, as they ran on 2026-11-14).
#
# osm_cells(boxes, cell)   the full `cell`-degree grid cells that meet any of `boxes` (named lists of xmin, ymin, xmax,
#                          ymax), named x+010_y+55 by their south-west corner; a cell is fetched whole, so two boxes in
#                          one cell fetch it once
# osm_pause()              a random pause after each fetch: 10 s plus an exponential draw with a 5 s median (the
#                          maintainer, 2026-11-14: "a median around 15 seconds and a floor at 10 seconds")
# osm_fetch(query, file, patience_h, wait_max_s)   posts an Overpass query and keeps the answer only if it is whole: XML,
#                          closed, no remark (a timeout or a memory limit leaves one). A failed try waits 30 s more than
#                          the last, at most `wait_max_s`, and the fetch stops only when `patience_h` hours have passed
# osm_read(xml, bbox, keys, keep)   the tagged features of a saved answer as sf, one row per OSM object, with osm_id and
#                          the `keys` as columns; `keep(v)` says which rows to keep (v(key) gives a key's values).
#                          osmdata_sf() first; where it fails (a cell whose nodes carry no tag at all), GDAL's OSM driver
# osm_landing_tags()       the small-landing tags (plan 075 §2.1), as osmdata::add_osm_features() takes them
# osm_landing_keep(v)      the rows that carry one of them
# osm_landing_keys()       the keys kept as columns
osm_cells <- function(boxes, cell = 5) {
  out <- list()
  for (b in boxes) for (x in seq(floor(b[1] / cell) * cell, b[3] - 1e-9, cell)) for (y in seq(floor(b[2] / cell) * cell, b[4] - 1e-9, cell))
    out[[sprintf("x%+04d_y%+03d", x, y)]] <- c(x, y, x + cell, y + cell)
  out[!duplicated(names(out))]
}

osm_pause <- function() Sys.sleep(10 + stats::rexp(1, rate = log(2) / 5))

osm_fetch <- function(query, file, url = "https://overpass-api.de/api/interpreter", patience_h = 0.3, wait_max_s = 300) {
  start <- Sys.time(); i <- 0
  repeat {
    i <- i + 1
    r <- tryCatch(httr2::request(url) |> httr2::req_user_agent("fishycode port list (R osmdata)") |>
                    httr2::req_body_form(data = query) |> httr2::req_timeout(1200) |> httr2::req_perform(path = file),
                  error = function(e) e)
    txt <- if (!inherits(r, "error") && file.exists(file)) readLines(file, warn = FALSE) else character()
    ok <- length(txt) && grepl("^<\\?xml", txt[1]) && any(grepl("^</osm>", utils::tail(txt, 3))) && !any(grepl("<remark>", txt))
    if (ok) return(invisible(TRUE))
    message(sprintf("  %s try %d failed: %s", format(Sys.time(), "%H:%M", tz = "UTC"), i,
                    if (inherits(r, "error")) gsub("\\s+", " ", conditionMessage(r)) else "an incomplete answer"))
    unlink(file)
    wait <- min(wait_max_s, 30 * i)
    if (difftime(Sys.time() + wait, start, units = "hours") > patience_h) break
    Sys.sleep(wait)
  }
  stop(sprintf("Overpass gave no whole answer for %s in %d tries over %.1f hours", basename(file), i,
               as.numeric(difftime(Sys.time(), start, units = "hours"))))
}

osm_read <- function(xml, bbox, keys, keep) {
  one <- function(d) {
    if (is.null(d) || !nrow(d)) return(NULL)
    if (!"osm_id" %in% names(d)) d$osm_id <- rownames(d)          # osmdata 0.4.0 leaves it out of some layers
    d$osm_id <- ifelse(is.na(d$osm_id), rownames(d), as.character(d$osm_id))
    v <- function(k) if (k %in% names(d)) as.character(d[[k]]) else rep(NA_character_, nrow(d))
    i <- which(keep(v))
    if (!length(i)) return(NULL)
    out <- sf::st_sf(osm_id = d$osm_id[i], name = v("name")[i], geometry = sf::st_geometry(d)[i])
    for (k in keys) out[[k]] <- v(k)[i]
    out
  }
  x <- tryCatch(osmdata::osmdata_sf(osmdata::opq(bbox = bbox), doc = xml), error = function(e) NULL)
  if (!is.null(x)) return(dplyr::bind_rows(lapply(c("osm_points", "osm_lines", "osm_polygons", "osm_multilines", "osm_multipolygons"),
                                                  \(n) one(x[[n]]))))
  message("  osmdata_sf failed: read by GDAL")
  tag <- function(other, k) { m <- regmatches(other, regexec(paste0('"', k, '"=>"([^"]*)"'), other)); vapply(m, \(z) if (length(z) == 2) z[2] else NA_character_, "") }
  layer <- function(l) {
    g <- tryCatch(suppressWarnings(sf::st_read(xml, layer = l, quiet = TRUE)), error = function(e) NULL)
    if (is.null(g) || !nrow(g)) return(NULL)
    id <- if ("osm_way_id" %in% names(g)) dplyr::coalesce(g$osm_way_id, g$osm_id) else g$osm_id
    d <- sf::st_sf(osm_id = as.character(id), name = if ("name" %in% names(g)) g$name else NA_character_, geometry = sf::st_geometry(g))
    for (k in keys) d[[k]] <- if (k %in% names(g)) g[[k]] else tag(dplyr::coalesce(g$other_tags, ""), k)
    d
  }
  g <- dplyr::bind_rows(lapply(c("points", "lines", "multilinestrings", "multipolygons", "other_relations"), layer))
  if (!nrow(g)) return(NULL)
  v <- function(k) g[[k]]
  g <- g[which(keep(v)), ]
  single <- sf::st_geometry_type(g) == "MULTIPOLYGON" & lengths(sf::st_geometry(g)) == 1
  sf::st_geometry(g)[single] <- sf::st_cast(sf::st_geometry(g)[single], "POLYGON")
  g
}

osm_landing_tags <- function() c('"leisure"="slipway"', '"man_made"="pier"', '"man_made"="quay"', '"man_made"="breakwater"',
                                 '"man_made"="groyne"', '"seamark:type"="small_craft_facility"', '"seamark:type"="mooring"')

osm_landing_keep <- function(v) v("leisure") %in% "slipway" | v("man_made") %in% c("pier", "quay", "breakwater", "groyne") |
  v("seamark:type") %in% c("small_craft_facility", "mooring")

osm_landing_keys <- function() c("leisure", "man_made", "pier", "seamark:type", "seamark:small_craft_facility:category",
                                 "access", "operator")
