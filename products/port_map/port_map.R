# port_map.R — the global port layer's review map, on rebelrebel (plan 075 §2.5).
# Side: product. Internal: served on 127.0.0.1, not bundled.
#
# Input:  curated/reference/port_layer.parquet and port_feature.parquet (reference/ports/port_layer.R); rebelrebel
# Output: port_map_build() a rebelrebel map; port_map() serves it in the background and opens it
#
# The ports by basis (areas and points), the features that joined them (witnesses and duplicates, by list), and the
# flagged features with their reasons, each feature's popup naming its list, key, outcome, reason and port. GFW's
# anchorages are left out but for those flagged near nothing (hidden at first): their dock areas stand for them.
# Run from the fishycode root: source("products/port_map/port_map.R"); port_map(), or Rscript products/port_map/server.R.

port_map_build <- function() {
  s2 <- sf::sf_use_s2(FALSE); on.exit(sf::sf_use_s2(s2), add = TRUE)
  # rebelrebel 2026.11.12.2 passes an sf layer to DuckDB as WKT, written to R's `digits` significant digits: at the
  # default 7, close vertices of GFW's 500 m circles collapse and the ring turns invalid (a TopologyException at Cannes)
  dg <- options(digits = 15); on.exit(options(dg), add = TRUE)
  ly <- read_curated_sf(fd_curated("reference", "port_layer.parquet"))
  f <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "port_feature.parquet")))
  f$geom <- NULL
  f <- f[!is.na(f$lon), ]
  f$reason_group <- sub(":.*| [0-9,]+ km off$", "", f$reason)
  f$key <- paste0(f$source, ":", f$feature_key)
  keep <- c("key", "name", "source", "kind", "outcome", "reason", "reason_group", "pid", "port_key", "dist_m",
            "iso_geo", "lon", "lat")
  joined <- f[f$outcome %in% c("witness", "duplicate") & f$source != "gfw", keep]
  flagged <- f[f$outcome == "flagged" & f$source != "gfw", keep]
  gfw_far <- f[f$outcome == "flagged" & f$source == "gfw", keep]
  pts <- ly[ly$geom_type != "area", ]
  pts <- cbind(sf::st_drop_geometry(pts), sf::st_coordinates(pts)[, 1:2])
  names(pts)[names(pts) == "X"] <- "lon"
  names(pts)[names(pts) == "Y"] <- "lat"

  m <- rebelrebel::rr_map(ly[ly$geom_type == "area", ], title = "Global port layer (plan 075)") |>
    rebelrebel::rr_polygon(colour = "#333333", fill = anchor_source, opacity = 0.4,
                           popup = c(pid, pid_acronym, name, iso, basis, lists, n_lists, n_features, anchor_source, anchor_key),
                           hover = name, choose = c(basis, anchor_source), name = "Ports: areas") |>
    rebelrebel::rr_point(data = pts, colour = anchor_source, size = 6,
                         popup = c(pid, pid_acronym, name, iso, basis, lists, n_lists, n_features, anchor_source, anchor_key),
                         hover = name, choose = c(basis, anchor_source), name = "Ports: points") |>
    rebelrebel::rr_point(data = joined, colour = source, size = 4, popup = c(key, name, kind, outcome, reason, pid, port_key, dist_m),
                         hover = name, choose = c(source, outcome), name = "Witnesses and duplicates", minzoom = 6) |>
    rebelrebel::rr_point(data = flagged, colour = reason_group, size = 5, popup = c(key, name, kind, reason, iso_geo),
                         hover = name, choose = c(source, reason_group), name = "Flagged") |>
    rebelrebel::rr_point(data = gfw_far, colour = "#999999", size = 2, popup = c(key, name, kind, reason),
                         name = "GFW anchorages away from any port", visible = FALSE, minzoom = 6)
  # rebelrebel 2026.11.12.2's rr_map(data) keeps only the title, `choose` and `sections` until the first layer, and drops
  # `basemaps` and `view`, and each layer added sets the base maps again: they are set on the built map, after its last
  # layer (a caller that adds layers sets them again)
  m$config$basemaps <- port_map_bases()
  m$config$view <- list(center = list(5, 55), zoom = 4)
  m
}

# OpenStreetMap's standard tiles as the background, and no EMODnet base map (the maintainer, 2026-11-14)
port_map_bases <- function() {
  osm <- list(id = "osm", label = "OpenStreetMap", maxzoom = 19, attribution = "© OpenStreetMap contributors",
              tiles = "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
  c(list(osm), Filter(\(b) !startsWith(b$id, "emodnet"), rebelrebel::rr_basemaps()))
}

port_map <- function(port = as.integer(Sys.getenv("PORT_MAP_PORT", "8818")), open = interactive()) {
  rebelrebel::rr_serve(port_map_build(), port = port, open = open)
}
