# server.R — the effort map from a terminal: ramb's map viewer serving map.R's map, until the process is stopped.
# Decision 220, plan 046. From an R session, effort_map.R does the same in the background and opens the view.
#
# Input:  tiles.R, map.R and what they read; ramb's rb_map_serve() (ramb >= 2026.10.24.1)
# Output: none; http://127.0.0.1:<port> answers until the process is stopped
#
# Run from the fishycode root:  Rscript products/effort_map/server.R
# The port is 8791, or EFFORT_MAP_PORT. It listens on 127.0.0.1 only: vessel data, for internal use.

source("R/paths.R")
source("R/write_curated.R")    # read_curated_sf(), for the place names
source("products/effort_map/tiles.R")
source("products/effort_map/map.R")

PORT <- as.integer(Sys.getenv("EFFORT_MAP_PORT", "8791"))
GRID <- fd_path("products", "effort_map", "grid.parquet")
con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, "LOAD spatial"))

ramb::rb_map_serve(effort_map_build(con, GRID), port = PORT, open = FALSE)
cat(sprintf("effort map on http://127.0.0.1:%d, reading %s\n", PORT, GRID))
repeat httpuv::service(100)
