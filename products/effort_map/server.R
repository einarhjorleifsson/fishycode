# server.R — the effort map from a terminal: app.R's page and tiles, until the process is stopped.
# Decision 220. From an R session, effort_map.R does the same in the background and opens the view.
#
# Input:  app.R and what it reads
# Output: none; http://127.0.0.1:<port> answers until the process is stopped
#
# Run from the fishycode root:  Rscript products/effort_map/server.R
# The port is 8791, or EFFORT_MAP_PORT. It listens on 127.0.0.1 only: vessel data, for internal use.

source("R/paths.R")
source("R/write_curated.R")    # read_curated_sf(), for the place names
source("products/effort_map/tiles.R")
source("products/effort_map/ports.R")
source("products/effort_map/app.R")

PORT <- as.integer(Sys.getenv("EFFORT_MAP_PORT", "8791"))
GRID <- fd_path("products", "effort_map", "grid.parquet")
con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, "LOAD spatial"))

cat(sprintf("effort map on http://127.0.0.1:%d, reading %s\n", PORT, GRID))
httpuv::runServer("127.0.0.1", PORT, effort_map_app(con, GRID, "products/effort_map/www"))
