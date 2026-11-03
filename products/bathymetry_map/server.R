# server.R — the bathymetry map from a terminal: ramb's map viewer serving bathymetry_map.R's map, until the process
# is stopped. From an R session, bathymetry_map() does the same in the background and opens the view.
# TODO 185, plan 046.
#
# Input:  bathymetry_map.R and what it reads
# Output: none; http://127.0.0.1:<port> answers until the process is stopped
#
# Run from the fishycode root:  Rscript products/bathymetry_map/server.R
# The port is 8798, or BATHYMETRY_MAP_PORT. It listens on 127.0.0.1 only.

source("products/bathymetry_map/bathymetry_map.R")

PORT <- as.integer(Sys.getenv("BATHYMETRY_MAP_PORT", "8798"))
e <- .bathymetry_map
con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, "LOAD spatial"))

ramb::rb_map_serve(e$bathymetry_map_build(con, e$dir), port = PORT, open = FALSE)
cat(sprintf("bathymetry map on http://127.0.0.1:%d, reading %s\n", PORT, e$dir))
repeat httpuv::service(100)
