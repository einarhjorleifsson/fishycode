# server.R — the landing sites' review map from a terminal, served until the process is stopped (plan 075 §2.5).
#
# Input:  products/port_map/port_map.R and what it reads
# Output: none; http://127.0.0.1:<port> answers until the process is stopped
#
# Run from the fishycode root:  Rscript products/port_map/server.R
# The port is 8818, or PORT_MAP_PORT. It listens on 127.0.0.1 only.

source("R/paths.R")
source("R/write_curated.R")    # read_curated_sf()
source("products/port_map/port_map.R")

PORT <- as.integer(Sys.getenv("PORT_MAP_PORT", "8818"))
ogis::og_serve(port_map_build(), port = PORT, open = FALSE)
cat(sprintf("port map on http://127.0.0.1:%d\n", PORT))
repeat httpuv::service(100)
