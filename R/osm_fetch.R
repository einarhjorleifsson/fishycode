# Helpers for fetching OSM features from Overpass in cells, with care, into a store that grows (dump/ports/osm_landing.R;
# dump/ports/osm.R holds the same steps inline until its run of 2026-11-14 ends), and for reading the store.
#
# osm_landing_groups()     the small-landing tag groups (plan 075 §2.1): each an Overpass filter and the rows it keeps
# osm_landing_keys()       the keys kept as columns
# osm_store_held(dir)      the answers a store holds, <cell>__<group>__<YYYYMMDD>.osm.gz: the newest of each cell and group
# read_landings_osm(dir)   the store's small landings as sf: the newest answer of every cell and group, one row per OSM
#                          object (the newest answer's where two hold it), with osm_group, fetched and cell
#
# osm_cells(boxes, cell)   the full `cell`-degree grid cells that meet any of `boxes` (named lists of xmin, ymin, xmax,
#                          ymax), named x+010_y+55 by their south-west corner; a cell is fetched whole, so two boxes in
#                          one cell fetch it once
# osm_pause()              a random pause after each fetch: 10 s plus an exponential draw with a 5 s median (the
#                          maintainer, 2026-11-14: "a median around 15 seconds and a floor at 10 seconds")
# osm_fetch(query, file)   posts an Overpass query, with retries, and keeps the answer only if it is whole: XML, closed,
#                          no remark (a timeout or a memory limit leaves one)
# osm_read(xml, bbox, keys, keep)   the tagged features of a saved answer as sf, one row per OSM object, with osm_id and
#                          the `keys` as columns; `keep(v)` says which rows to keep (v(key) gives a key's values).
#                          osmdata_sf() first; where it fails (a cell whose nodes carry no tag at all), GDAL's OSM driver
osm_cells <- function(boxes, cell = 5) {
  out <- list()
  for (b in boxes) for (x in seq(floor(b[1] / cell) * cell, b[3] - 1e-9, cell)) for (y in seq(floor(b[2] / cell) * cell, b[4] - 1e-9, cell))
    out[[sprintf("x%+04d_y%+03d", x, y)]] <- c(x, y, x + cell, y + cell)
  out[!duplicated(names(out))]
}

osm_pause <- function() Sys.sleep(10 + stats::rexp(1, rate = log(2) / 5))

osm_fetch <- function(query, file, url = "https://overpass-api.de/api/interpreter", tries = 8) {
  for (i in seq_len(tries)) {
    r <- tryCatch(httr2::request(url) |> httr2::req_user_agent("fishycode port list (R osmdata)") |>
                    httr2::req_body_form(data = query) |> httr2::req_timeout(1200) |> httr2::req_perform(path = file),
                  error = function(e) e)
    txt <- if (!inherits(r, "error") && file.exists(file)) readLines(file, warn = FALSE) else character()
    ok <- length(txt) && grepl("^<\\?xml", txt[1]) && any(grepl("^</osm>", utils::tail(txt, 3))) && !any(grepl("<remark>", txt))
    if (ok) return(invisible(TRUE))
    message(sprintf("  try %d failed: %s", i, if (inherits(r, "error")) conditionMessage(r) else "an incomplete answer"))
    unlink(file)
    Sys.sleep(min(300, 30 * i))
  }
  stop("Overpass gave no whole answer for ", basename(file))
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

osm_landing_groups <- function() list(
  slipway  = list(filter = '["leisure"="slipway"]', keep = \(v) v("leisure") %in% "slipway"),
  man_made = list(filter = '["man_made"~"^(pier|quay|breakwater|groyne)$"]',
                  keep = \(v) v("man_made") %in% c("pier", "quay", "breakwater", "groyne")),
  seamark  = list(filter = '["seamark:type"~"^(small_craft_facility|mooring)$"]',
                  keep = \(v) v("seamark:type") %in% c("small_craft_facility", "mooring")))

osm_landing_keys <- function() c("leisure", "man_made", "pier", "seamark:type", "seamark:small_craft_facility:category",
                                 "access", "operator")

osm_store_held <- function(dir) {
  f <- list.files(dir, "\\.osm\\.gz$")
  if (!length(f)) return(data.frame(cell = character(), group = character(), date = character(), file = character()))
  p <- do.call(rbind, strsplit(sub("\\.osm\\.gz$", "", f), "__"))
  h <- data.frame(cell = p[, 1], group = p[, 2], date = p[, 3], file = f)
  h <- h[order(h$cell, h$group, h$date, decreasing = TRUE), ]
  h[!duplicated(h[, c("cell", "group")]), ]
}

read_landings_osm <- function(dir = fd_raw("ports", "landings_osm"), groups = osm_landing_groups(), keys = osm_landing_keys(),
                              cell = 5) {
  h <- osm_store_held(dir)
  h <- h[h$group %in% names(groups), ]
  out <- dplyr::bind_rows(lapply(seq_len(nrow(h)), \(i) {
    b <- as.numeric(regmatches(h$cell[i], gregexpr("[-+][0-9]+", h$cell[i]))[[1]])
    xml <- tempfile(fileext = ".osm"); R.utils::gunzip(file.path(dir, h$file[i]), destname = xml, remove = FALSE)
    x <- osm_read(xml, c(b[1], b[2], b[1] + cell, b[2] + cell), keys, groups[[h$group[i]]]$keep); unlink(xml)
    if (is.null(x) || !nrow(x)) return(NULL)
    x$osm_group <- h$group[i]; x$fetched <- h$date[i]; x$cell <- h$cell[i]
    x
  }))
  if (!nrow(out)) return(out)
  out$type <- as.character(sf::st_geometry_type(out))
  out <- out[order(out$fetched, decreasing = TRUE), ]
  out[!duplicated(paste(out$type, out$osm_id)), ]          # an object in two cells, or two groups, once
}
