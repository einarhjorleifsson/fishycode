# place_names.R — the place-name explorer from an R session: place_names() starts its service in the background and
# opens the page in RStudio's Viewer (or a browser), on a name if one is given.
# Plan 045 step 1 (its first, read-only part); plan 044.
#
# Input:  api.R and what it reads (curated/place_name/); the page in www/
# Output: place_names(), place_names_stop(); a server on 127.0.0.1:<port> in this R session, in the background
#
# Use, from the fishycode root (an RStudio project opens there):
#   source("products/place_names/place_names.R")
#   place_names()                      # every name, the list ordered by positions
#   place_names("Litli banki")         # opens on a name (a spelling or a key)
#   place_names_stop()
#
# The server answers while the console is idle. Internal use only: it listens on 127.0.0.1.

source("R/paths.R")
source("R/write_curated.R")    # read_curated_sf(), for the footprints

.place_names <- new.env()
.place_names$dir <- "products/place_names"
sys.source(file.path(.place_names$dir, "api.R"), envir = .place_names)

place_names_start <- function(port = 8797) {
  e <- .place_names
  if (identical(e$port, port)) return(invisible(port))
  place_names_stop()
  e$con <- DBI::dbConnect(duckdb::duckdb())
  invisible(DBI::dbExecute(e$con, "SET threads = 4"))
  invisible(DBI::dbExecute(e$con, "SET memory_limit = '5GB'"))
  e$server <- httpuv::startServer("127.0.0.1", port, e$place_names_app(e$con, file.path(e$dir, "www")))
  e$port <- port
  message("place names on http://127.0.0.1:", port, ", answering while the console is idle; place_names_stop() ends it")
  invisible(port)
}

place_names_stop <- function() {
  e <- .place_names
  if (!is.null(e$server)) httpuv::stopServer(e$server)
  if (!is.null(e$con)) DBI::dbDisconnect(e$con, shutdown = TRUE)
  e$con <- e$server <- e$port <- NULL
  invisible()
}

# name: a spelling or a key, matched as the gazetteer's key is made (curate/place_name_evidence.R, name_key())
place_names <- function(name = NULL, port = 8797, viewer = TRUE) {
  place_names_start(port)
  key <- if (length(name)) {
    x <- tolower(name); x <- gsub("ð", "d", x); x <- gsub("þ", "th", x); x <- gsub("æ", "ae", x)
    x <- chartr("áéíóúýöäåøü", "aeiouyoaaou", x); x <- gsub("[^a-z0-9?]", "", x); gsub("([a-z])\\1+", "\\1", x)
  }
  url <- sprintf("http://127.0.0.1:%d/%s", port, if (length(key)) paste0("#key=", utils::URLencode(key, reserved = TRUE)) else "")
  if (viewer && requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) rstudioapi::viewer(url, height = "maximize")
  else if (viewer) utils::browseURL(url)
  invisible(url)
}
