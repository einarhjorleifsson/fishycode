# server.R — the depth and effort map from a terminal: ramb's map viewer serving depth_effort_map.R's map, until the
# process is stopped. From an R session, depth_effort_map() does the same in the background and opens the view.
# TODO 185, decision 220.
#
# Input:  depth_effort_map.R and what it reads
# Output: none; http://127.0.0.1:<port> answers until the process is stopped
#
# Run from the fishycode root:  Rscript products/depth_effort_map/server.R
# The port is 8797, or DEPTH_EFFORT_MAP_PORT. It listens on 127.0.0.1 only: vessel data, for internal use.

source("products/depth_effort_map/depth_effort_map.R")

PORT <- as.integer(Sys.getenv("DEPTH_EFFORT_MAP_PORT", "8797"))
con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, "LOAD spatial"))

ramb::rb_map_serve(depth_effort_map_build(con), port = PORT, open = FALSE)
cat(sprintf("depth and effort map on http://127.0.0.1:%d\n", PORT))
repeat httpuv::service(100)
