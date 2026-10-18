# The vessel overview: starts its R service on the laptop (decision 137, ask a). Plan 030 step 3.
#
# Input:  what products/vessel_overview/api.R reads
# Output: none; http://127.0.0.1:<port> answers until the process is stopped
#
# Run from the repository root:
#   Rscript products/vessel_overview/server.R
# The port is 8790, or VESSEL_OVERVIEW_PORT. It listens on 127.0.0.1 only: the photos and the register's names are
# for internal use (plan 030 §4.5). The page (step 4) is products/vessel_overview/www/index.html.

source("R/paths.R")
source("products/vessel_overview/api.R")

PORT <- as.integer(Sys.getenv("VESSEL_OVERVIEW_PORT", "8790"))
con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbExecute(con, sprintf("SET temp_directory = '%s'", file.path(tempdir(), "duckdb_temp")))

cat(sprintf("vessel overview on http://127.0.0.1:%d, reading %s\n", PORT, fishydata_root()))
httpuv::runServer("127.0.0.1", PORT, vessel_overview_app(con, "products/vessel_overview/www"))
