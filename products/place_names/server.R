# server.R — the place-name explorer from a terminal: its service on 127.0.0.1 until the process is stopped.
# Plan 045 step 1 (its first, read-only part). From an R session, place_names.R does the same in the background.
#
# Input:  api.R and what it reads (curated/place_name/); the page in www/
# Output: none; http://127.0.0.1:<port> answers until the process is stopped
#
# Run from the fishycode root:  Rscript products/place_names/server.R
# The port is 8797, or PLACE_NAMES_PORT. It listens on 127.0.0.1 only: Trackwell's and the plotters' names are internal.

source("R/paths.R")
source("R/write_curated.R")    # read_curated_sf(), for the footprints
source("products/place_names/api.R")

PORT <- as.integer(Sys.getenv("PLACE_NAMES_PORT", "8797"))
con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, "SET threads = 4"))
invisible(DBI::dbExecute(con, "SET memory_limit = '5GB'"))

app <- place_names_app(con, "products/place_names/www")
cat(sprintf("place names on http://127.0.0.1:%d, reading %s\n", PORT, fd_path("curated", "place_name")))
httpuv::runServer("127.0.0.1", PORT, app)
