# voyage_map.R — one voyage of a vessel on ramb's map viewer: its track and its fixes, coloured by fishing. The
# viewer's second view (plan 046 step 7), made from ramb's functions with no edit to its engine.
# Plan 046.
#
# Input:  $FISHYDATA/curated/ais/trail (vid, year, voyage_id, time, lon, lat, speed, fishing, gear, phase, hours);
#         ramb's map viewer (rb_map_*(), ramb >= 2026.10.24.1)
# Output: voyage_map(), voyage_map_stop(); a server on 127.0.0.1:<port> in this R session, in the background
#
# Use, from the fishycode root (an RStudio project opens there):
#   source("products/voyage_map/voyage_map.R")
#   voyage_map(2173)                              # the vessel's last voyage with fishing in the trail
#   voyage_map(2173, year = 2025, voyage = 3)
#   voyage_map_stop()
#
# Vessel data, for use inside MFRI only: the server listens on 127.0.0.1. It answers while the console is idle.

source("R/paths.R")

.voyage_map <- new.env()

voyage_map <- function(vid, year = NULL, voyage = NULL, port = 8796, viewer = TRUE) {
  voyage_map_stop()
  con <- DBI::dbConnect(duckdb::duckdb())
  invisible(DBI::dbExecute(con, "LOAD spatial"))
  .voyage_map$con <- con
  src <- sprintf("read_parquet(%s, hive_partitioning = true)",
                 DBI::dbQuoteString(con, fd_curated("ais", "trail", "**", "*.parquet")))
  vid <- as.integer(vid)
  # where none is given, the vessel's last voyage with fishing in the trail (else its last voyage), in that year
  if (is.null(voyage)) {
    last <- DBI::dbGetQuery(con, sprintf(
      "SELECT year, voyage_id FROM %s WHERE vid = %d %s GROUP BY ALL
       ORDER BY bool_or(fishing) DESC NULLS LAST, year DESC, voyage_id DESC LIMIT 1",
      src, vid, if (is.null(year)) "" else sprintf("AND year = %d", as.integer(year))))
    if (!nrow(last)) stop("vessel ", vid, " has no fixes in the trail", if (!is.null(year)) paste(" in", year), call. = FALSE)
    year <- last$year; voyage <- last$voyage_id
  } else if (is.null(year)) {
    stop("give the year with the voyage: voyage ids count within a vessel's year", call. = FALSE)
  }
  year <- as.integer(year); voyage <- as.integer(voyage)
  where <- sprintf("year = %d AND vid = %d AND voyage_id = %d AND lon IS NOT NULL AND lat IS NOT NULL", year, vid, voyage)
  # a fix's values as text and rounded numbers, which a vector tile carries
  fixes <- sprintf(
    "SELECT strftime(time, '%%Y-%%m-%%d %%H:%%M:%%S') AS time, lon, lat, round(speed, 1) AS speed,
            CASE WHEN fishing THEN 'yes' WHEN NOT fishing THEN 'no' END AS fishing, gear, phase,
            round(hours * 60, 1) AS minutes
     FROM %s WHERE %s", src, where)
  n <- DBI::dbGetQuery(con, sprintf("SELECT count(*) AS n, min(lon) AS x0, max(lon) AS x1, min(lat) AS y0, max(lat) AS y1 FROM (%s)", fixes))
  if (n$n == 0) stop(sprintf("vessel %d has no voyage %d in %d", vid, voyage, year), call. = FALSE)
  track <- sprintf(
    "SELECT ST_MakeLine(list(ST_Point(lon, lat) ORDER BY time)) AS geometry FROM %s WHERE %s", src, where)
  track_layer <- ramb::rb_map_layer(
    "track", "vector", label = "Track", info = "The voyage's fixes joined in time order.",
    tiles = ramb::rb_map_tiles_table(dplyr::tbl(con, dplyr::sql(track))),
    style = list(list(id = "track-line", type = "line", "source-layer" = "features",
                      paint = list("line-color" = "#4d5b66", "line-width" = 1.2, "line-opacity" = 0.8))),
    legend = list(list(swatch = list(fill = "#4d5b66"), label = "track"))
  )
  fixes_layer <- ramb::rb_map_layer(
    "fixes", "vector", label = "Fixes",
    info = "Each fix of the voyage in the trail: red where the flow judges it fishing (in a haul window), grey where not.",
    tiles = ramb::rb_map_tiles_table(dplyr::tbl(con, dplyr::sql(fixes)), lon = "lon", lat = "lat",
                                     properties = c("time", "speed", "fishing", "gear", "phase", "minutes")),
    count = list(text = "{1} fixes"),
    style = list(list(id = "fixes-dot", type = "circle", "source-layer" = "features",
                      paint = list("circle-color" = list("match", list("get", "fishing"), "yes", "#c0392b", "#8a959e"),
                                   "circle-radius" = list("interpolate", list("linear"), list("zoom"), 5, 1.5, 10, 3, 14, 5),
                                   "circle-stroke-color" = "#fff", "circle-stroke-width" = 0.5))),
    legend = list(list(swatch = list(dot = "#c0392b"), label = "fishing"), list(swatch = list(dot = "#8a959e"), label = "not fishing")),
    popup = list(click = "fixes-dot", title = "time", fields = list(
      list(field = "speed", label = "speed (knots)"), list(field = "fishing", label = "fishing"),
      list(field = "gear", label = "gear"), list(field = "phase", label = "phase"),
      list(field = "minutes", label = "minutes it stands for")))
  )
  # the first view: the voyage's extent
  span <- max(n$x1 - n$x0, (n$y1 - n$y0) * 2, 0.01)
  zoom <- max(4, min(12, floor(log2(360 / span)) - 1))
  title <- sprintf("Vessel %d, voyage %d of %d", vid, voyage, year)
  m <- ramb::rb_map(
    ramb::rb_map_group("voyage", title, list(track_layer, fixes_layer)),
    title = title, view = list(center = c((n$x0 + n$x1) / 2, (n$y0 + n$y1) / 2), zoom = zoom),
    texts = list(about1 = "One voyage from the AIS trail (curated/ais/trail), on ramb's map viewer (fishycode plan 046 step 7). Built from vessel-level data: for use inside MFRI only."),
    about = "about1"
  )
  url <- ramb::rb_map_serve(m, port = port, open = viewer)
  .voyage_map$port <- port
  message(sprintf("%s: %s fixes on %s; voyage_map_stop() ends it", title, format(n$n, big.mark = ","), url))
  invisible(url)
}

voyage_map_stop <- function() {
  e <- .voyage_map
  if (!is.null(e$port)) ramb::rb_map_stop(e$port)
  if (!is.null(e$con)) DBI::dbDisconnect(e$con, shutdown = TRUE)
  e$con <- e$port <- NULL
  invisible()
}
