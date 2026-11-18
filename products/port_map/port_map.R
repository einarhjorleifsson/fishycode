# port_map.R — the landing sites' review map, on ogis (formerly rebelrebel; plan 075 §2.5).
# Side: product. Internal: served on 127.0.0.1, not bundled.
#
# Input:  curated/reference/landing_site.parquet and landing_site_feature.parquet (reference/ports/landing_site.R);
#         ogis
# Output: port_map_build() an ogis map; port_map() serves it in the background and opens it
#
# The sites by basis (reviewed, witnessed, one list, structure, context): areas as drawn, the others at their point,
# small landings' lines as drawn from zoom 12; the small landings that joined a port list's site, the features that
# witness one or duplicate its anchor (by list), and the flagged features with their reasons, each popup naming the
# list, key, outcome, reason and site. GFW's anchorages are left out but for those flagged near nothing (hidden at
# first): their dock areas stand for them. Layers of many rows reach the page as tiles (ogis's default).
# Run from the fishycode root: source("products/port_map/port_map.R"); port_map(), or Rscript products/port_map/server.R.

BASIS_COLOURS <- c(reviewed = "#1b9e77", witnessed = "#2166ac", `one list` = "#e6ab02", structure = "#d95f02",
                   context = "#7f7f7f")

port_map_build <- function() {
  s2 <- sf::sf_use_s2(FALSE); on.exit(sf::sf_use_s2(s2), add = TRUE)
  # rebelrebel 2026.11.12.2 passes an sf layer to DuckDB as WKT, written to R's `digits` significant digits: at the
  # default 7, close vertices of GFW's 500 m circles collapse and the ring turns invalid (a TopologyException at Cannes)
  dg <- options(digits = 15); on.exit(options(dg), add = TRUE)
  ly <- read_curated_sf(fd_curated("reference", "landing_site.parquet"))
  ly$basis <- factor(ly$basis, levels = names(BASIS_COLOURS))
  f <- as.data.frame(nanoparquet::read_parquet(fd_curated("reference", "landing_site_feature.parquet")))
  f$geom <- NULL
  f <- f[!is.na(f$lon), ]
  f$reason_group <- sub(":.*| [0-9,]+ km off$", "", f$reason)
  f$key <- paste0(f$source, ":", f$feature_key)
  keep <- c("key", "name", "source", "kind", "outcome", "reason", "reason_group", "pid", "site_key", "dist_m",
            "iso_geo", "lon", "lat")
  joined <- f[f$outcome %in% c("witness", "duplicate") & !f$source %in% c("gfw", "osm_landing"), keep]
  landed <- f[f$outcome == "joined", keep]
  flagged <- f[f$outcome == "flagged" & f$source != "gfw", keep]
  gfw_far <- f[f$outcome == "flagged" & f$source == "gfw", keep]
  pop <- quote(c(pid, pid_acronym, name, iso, basis, lists, n_lists, n_features, n_joined, anchor_source, anchor_kind, anchor_key))
  pts <- ly[ly$geom_type != "area", ]
  lines <- pts[pts$geom_type == "line", ]
  at <- f[match(pts$site_key, paste0(f$source, ":", f$feature_key)), c("lon", "lat")]
  pts <- cbind(sf::st_drop_geometry(pts), at)

  m <- ogis::og_map(ly[ly$geom_type == "area", ], title = "Landing sites (plan 075)") |>
    ogis::og_polygon(colour = "#333333", fill = basis, palette = BASIS_COLOURS, opacity = 0.4, popup = !!pop,
                           hover = name, choose = c(basis, anchor_source), name = "Sites: areas") |>
    ogis::og_point(data = pts, colour = basis, palette = BASIS_COLOURS, size = c(3, 8), popup = !!pop,
                         hover = name, choose = c(basis, anchor_source), name = "Sites: points") |>
    ogis::og_line(data = lines, colour = basis, palette = BASIS_COLOURS, linewidth = 2, popup = !!pop,
                        hover = name, choose = basis, name = "Sites: lines as drawn", minzoom = 12) |>
    ogis::og_point(data = landed, colour = "#d95f02", size = 4, popup = c(key, name, kind, reason, pid, site_key, dist_m),
                         hover = name, name = "Small landings at a port list's site", visible = FALSE, minzoom = 10) |>
    ogis::og_point(data = joined, colour = source, size = 4, popup = c(key, name, kind, outcome, reason, pid, site_key, dist_m),
                         hover = name, choose = c(source, outcome), name = "Witnesses and duplicates", minzoom = 6) |>
    ogis::og_point(data = flagged, colour = reason_group, size = 5, popup = c(key, name, kind, reason, iso_geo),
                         hover = name, choose = c(source, reason_group), name = "Flagged") |>
    ogis::og_point(data = gfw_far, colour = "#999999", size = 2, popup = c(key, name, kind, reason),
                         name = "GFW anchorages away from any site", visible = FALSE, minzoom = 6)
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
  c(list(osm), Filter(\(b) !startsWith(b$id, "emodnet"), ogis::og_basemaps()))
}

port_map <- function(port = as.integer(Sys.getenv("PORT_MAP_PORT", "8818")), open = interactive()) {
  ogis::og_serve(port_map_build(), port = port, open = open)
}
