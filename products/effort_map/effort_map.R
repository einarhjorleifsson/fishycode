# effort_map.R — the effort map from an R session: effort_map() opens a view in RStudio's Viewer (or a browser), set
# by its arguments, with the page's controls to go on from there.
# Decision 220, plan 046.
#
# Input:  tiles.R, map.R and what they read; ramb's map viewer (rb_map_serve(), rb_map_palettes(), rb_map_basemaps();
#         ramb >= 2026.10.24.1)
# Output: effort_map(), effort_map_stop(); a server on 127.0.0.1:<port> in this R session, in the background
#
# Use, from the fishycode root (an RStudio project opens there):
#   source("products/effort_map/effort_map.R")
#   effort_map()                                                     # all gears and years
#   effort_map(gear = "OTB", years = 2015:2020, palette = "deep", stretch = "equal")
#   effort_map(gear = 6, center = c(-24.5, 66.3), zoom = 8, floor = 1, cap = 300)
#   effort_map(lang = "is", base = "ocean", opacity = 60, names = FALSE, ports = TRUE)
#   effort_map(gear = "OTB", interpolate = FALSE)                   # each fix's hours where the fix is
#   effort_map_stop()
#
# The server answers while the console is idle: a map waits while R runs something else. A server already on the port
# from server.R (a terminal) is used as it is, if it is ramb's viewer serving the effort map.

source("R/paths.R")
source("R/write_curated.R")    # read_curated_sf(), for the place names

.effort_map <- new.env()
.effort_map$dir <- "products/effort_map"
.effort_map$grid <- fd_path("products", "effort_map", "grid.parquet")
sys.source(file.path(.effort_map$dir, "tiles.R"), envir = .effort_map)
sys.source(file.path(.effort_map$dir, "map.R"), envir = .effort_map)

effort_map_start <- function(port = 8791) {
  e <- .effort_map
  if (identical(e$port, port)) return(invisible(port))
  effort_map_stop()
  found <- suppressWarnings(tryCatch(jsonlite::fromJSON(sprintf("http://127.0.0.1:%d/meta", port)),
                                     error = function(err) NULL))
  if (!is.null(found) && !is.null(found$engine) && !is.null(found$layers$effort)) {
    message("using the effort map already running on port ", port)
    return(invisible(port))
  }
  if (!is.null(found)) stop("port ", port, " has an older effort map (a terminal's server.R?): stop it, or give another port",
                            call. = FALSE)
  e$con <- DBI::dbConnect(duckdb::duckdb())
  invisible(DBI::dbExecute(e$con, "LOAD spatial"))
  ramb::rb_map_serve(e$effort_map_build(e$con, e$grid), port = port, open = FALSE)
  e$port <- port
  message("effort map on http://localhost:", port, ", answering while the console is idle; effort_map_stop() ends it")
  invisible(port)
}

effort_map_stop <- function() {
  e <- .effort_map
  if (!is.null(e$port)) ramb::rb_map_stop(e$port)
  if (!is.null(e$con)) DBI::dbDisconnect(e$con, shutdown = TRUE)
  e$con <- e$port <- NULL
  invisible()
}

# gear: gear ids, FAO codes ("OTB" is every bottom trawl) or Icelandic names, as in curated/reference/gear (new codes)
effort_map <- function(gear = NULL, years = NULL, preset = c("fishing", "fishing_flow"), metric = c("hours", "kw_hours"),
                       cells = c("fine", "finer", "coarser"), interpolate = TRUE, palette = "magma",
                       stretch = c("even", "equal"),
                       floor = NULL, cap = NULL, opacity = NULL, names = TRUE, ports = FALSE, base = "light",
                       lang = c("en", "is"),
                       center = c(-19, 65), zoom = 5, port = 8791, viewer = TRUE) {
  preset <- match.arg(preset); metric <- match.arg(metric); cells <- match.arg(cells); stretch <- match.arg(stretch)
  lang <- match.arg(lang)
  palettes <- vapply(ramb::rb_map_palettes(), `[[`, "", "id")   # the viewer's palettes and base maps
  bases <- vapply(ramb::rb_map_basemaps(), `[[`, "", "id")
  if (!palette %in% palettes) stop("palette is one of ", paste(palettes, collapse = ", "), call. = FALSE)
  if (!base %in% bases) stop("base is one of ", paste(bases, collapse = ", "), call. = FALSE)
  if (!is.null(opacity) && !(is.numeric(opacity) && opacity >= 0 && opacity <= 100))
    stop("opacity is a percentage, 0 to 100", call. = FALSE)
  gid <- NULL
  if (length(gear)) {
    ref <- duckdbfs::open_dataset(fd_curated("reference", "gear.parquet")) |> dplyr::collect()
    ref <- ref[ref$version == "new", ]
    gid <- if (is.numeric(gear)) as.integer(gear)
           else ref$gid[toupper(ref$gear) %in% toupper(gear) | tolower(ref[["veiðarfæri"]]) %in% tolower(gear)]
    if (!length(gid) || anyNA(gid)) stop("no gear matches ", paste(gear, collapse = ", "), call. = FALSE)
    gid <- sort(unique(gid))
  }
  if (!is.null(floor) && (is.null(cap) || floor <= 0 || cap <= floor)) stop("floor and cap: 0 < floor < cap", call. = FALSE)
  effort_map_start(port)
  q <- c(preset = preset, gid = if (length(gid)) paste(gid, collapse = ","),
         y1 = if (length(years)) min(years), y2 = if (length(years)) max(years),
         metric = c(hours = "h_km2", kw_hours = "kwh_km2")[[metric]], px = c(fine = "1", finer = "0.5", coarser = "2")[[cells]],
         interp = if (!isTRUE(interpolate)) "off",
         palette = palette, stretch = stretch, floor = floor, cap = cap, opacity = opacity,
         names = if (!names) "0", ports = if (ports) "1", base = if (base != "light") base, lang = if (lang != "en") lang)
  url <- sprintf("http://localhost:%d/?%s#%s/%s/%s", port,
                 paste(names(q), vapply(q, utils::URLencode, "", reserved = TRUE), sep = "=", collapse = "&"),
                 zoom, center[2], center[1])
  if (viewer && requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) rstudioapi::viewer(url, height = "maximize")
  else if (viewer) utils::browseURL(url)
  invisible(url)
}
