# depth_effort_map.R — the bathymetry map with the fishing effort as one more layer (the maintainer, 2026-11-04): the
# depth, its contours and relief and the place names of products/bathymetry_map/, with the effort and the ports of
# products/effort_map/, on one page of ramb's map viewer. Both maps stay as they are; this one composes their
# builders. TODO 185, decision 220.
#
# Input:  what bathymetry_map.R and the effort map's map.R read (the depth's elevation tiles, the effort's base grid
#         and its grid of fixes, the ports, the gazetteer); ramb >= 2026.11.04.1
# Output: depth_effort_map(), depth_effort_map_stop(); depth_effort_map_build(), for server.R; a server on
#         127.0.0.1:<port> in this R session, in the background
#
# Use, from the fishycode root (an RStudio project opens there):
#   source("products/depth_effort_map/depth_effort_map.R")
#   depth_effort_map()
#   depth_effort_map(center = c(-22.5, 64.3), zoom = 8, lang = "is")
#   depth_effort_map_stop()
#
# - The depth by cell is left out: ramb draws one grid a map, here the effort. The depth is the elevation tiles'
#   (its colours, contours and relief), drawn under the effort.
# - The effort as the effort map draws it (map.json: its filters, colours, opacity and popup), its palette magma.
# Internal: vessel-level data, and the gazetteer's names from Trackwell and the plotters.

source("products/bathymetry_map/bathymetry_map.R")

.depth_effort_map <- new.env()
.depth_effort_map$grid <- fd_path("products", "effort_map", "grid.parquet")

# The map: the bathymetry map without its depth by cell, the effort in a group of its own between the relief and the
# reference layers, the ports beside the place names
depth_effort_map_build <- function(con, center = c(-19, 65), zoom = 6, lang = "en") {
  e <- .bathymetry_map
  effort <- e$effort_map_layers(con, .depth_effort_map$grid)$layers
  e$bathymetry_map_build(
    con, e$dir, center = center, zoom = zoom, lang = lang, cells = FALSE, palette = "magma",
    groups = list(ramb::rb_map_group("effort", "gEffort", list(effort$effort))),
    extra = list(effort$ports),
    about = c("aboutDepthEffort", "about2"),
    extra_texts = list(
      title = list(en = "Depth and fishing effort", is = "Dýpi og veiðisókn"),
      aboutDepthEffort = list(
        en = paste("The seabed from Olex's 50 m depth grid with GEBCO (TODO 185) under where Icelandic vessels fished,",
                   "from their AIS tracks linked to the logbooks and landings (decision 220): the bathymetry map and the",
                   "effort map in one."),
        is = paste("Hafsbotninn úr 50 m dýptargrunni Olex með GEBCO (TODO 185) undir því hvar íslensk skip voru að",
                   "veiðum, samkvæmt AIS-ferlum þeirra tengdum afladagbókum og löndunum (ákvörðun 220):",
                   "dýptarkortið og sóknarkortið í einu.")
      )
    )
  )
}

depth_effort_map <- function(center = c(-19, 65), zoom = 6, base = "light", lang = c("en", "is"), port = 8797,
                             viewer = TRUE) {
  lang <- match.arg(lang)
  bases <- vapply(ramb::rb_map_basemaps(), `[[`, "", "id")
  if (!base %in% bases) stop("base is one of ", paste(bases, collapse = ", "), call. = FALSE)
  depth_effort_map_stop()
  e <- .depth_effort_map
  e$con <- DBI::dbConnect(duckdb::duckdb())
  invisible(DBI::dbExecute(e$con, "LOAD spatial"))
  m <- depth_effort_map_build(e$con, center = center, zoom = zoom, lang = lang)
  url <- ramb::rb_map_serve(m, port = port, open = viewer, query = if (base != "light") list(base = base))
  e$port <- port
  invisible(url)
}

depth_effort_map_stop <- function() {
  e <- .depth_effort_map
  if (!is.null(e$port)) ramb::rb_map_stop(e$port)
  if (!is.null(e$con)) DBI::dbDisconnect(e$con, shutdown = TRUE)
  e$con <- e$port <- NULL
  invisible()
}
