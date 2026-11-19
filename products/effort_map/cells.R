# cells.R — the fishing effort as one file for ogis's og_cells(): the effort map's 0.005-degree grid under the
# `fishing` preset (the haul windows) alone, every gear and year, sorted by cell, with a data dictionary naming its
# columns and gears for the page's sidebar, and fishycode's fd.* stamps. Carried by ogisdata, MFRI's internal package
# (plan 078, TODO 205), and named on one computer by OGIS_CELLS. Internal: a cell may hold one vessel's fishing.
#
# Input:  $FISHYDATA/products/effort_map/grid_005.parquet (products/effort_map/grid.R)
#         $FISHYDATA/curated/reference/gear.parquet (the gear names, version 'new')
# Output: $FISHYDATA/products/effort_map/cells.parquet
#         gid, year, ix, iy (the cell's south-west corner in thousandths of a degree, a multiple of 5), h (hours),
#         kwh (kW-hours), n (fixes); KV metadata `data_dict` (ogis's dictionary: each column's label, the gears'
#         names) and the fd.* stamps of write_curated()
#
# Run from the fishycode root, after grid.R (about a minute):
#   Rscript products/effort_map/cells.R
# then ogisdata's data-raw/files.R copies it into the package.

source("R/paths.R")
source("R/write_curated.R")   # the fd.* stamps (.curated_kv); the file is not curated, so not write_curated_sql()

grid <- fd_path("products", "effort_map", "grid_005.parquet")
gear <- fd_path("curated", "reference", "gear.parquet")
out  <- fd_path("products", "effort_map", "cells.parquet")
stopifnot(file.exists(grid), file.exists(gear))

con <- DBI::dbConnect(duckdb::duckdb())
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
q <- function(x) DBI::dbQuoteString(con, x)

# The dictionary ---------------------------------------------------------------
g <- DBI::dbGetQuery(con, sprintf(
  "SELECT gid, \"veiðarfæri\" AS name, gear FROM read_parquet(%s) WHERE version = 'new' ORDER BY gid", q(gear)))
dict <- jsonlite::toJSON(list(columns = list(
  list(name = "gid", label = "Gear", values = stats::setNames(as.list(sprintf("%s (%s)", g$name, g$gear)), g$gid)),
  list(name = "year", label = "Years"),
  list(name = "h", label = "Hours"),
  list(name = "kwh", label = "kW-hours"),
  list(name = "n", label = "Fixes")
)), auto_unbox = TRUE)

# The cells --------------------------------------------------------------------
sql <- sprintf("SELECT gid, year, ix, iy, h, kwh, n FROM read_parquet(%s) WHERE preset = 'fishing'", q(grid))
gids <- DBI::dbGetQuery(con, sprintf("SELECT DISTINCT gid FROM (%s) WHERE gid IS NOT NULL", sql))$gid
miss <- setdiff(gids, g$gid)
if (length(miss)) stop("cells.R: gears with no name in gear.parquet: ", paste(miss, collapse = ", "), call. = FALSE)

ds <- DBI::dbGetQuery(con, sprintf("DESCRIBE %s", sql))
n  <- DBI::dbGetQuery(con, sprintf("SELECT count(*) AS n FROM (%s)", sql))$n
kv <- c(.curated_kv("products/effort_map/cells.R", n,
                    substr(digest_string(paste(ds$column_name, ds$column_type, collapse = "|")), 1, 16),
                    inputs = c(grid, gear)),
        data_dict = as.character(dict))
meta <- paste(sprintf("%s: %s", q(names(kv)), q(unname(kv))), collapse = ", ")

tmp <- paste0(out, ".partial")
unlink(tmp)
invisible(DBI::dbExecute(con, sprintf(
  "COPY (%s ORDER BY ix, iy, gid, year) TO %s (FORMAT parquet, COMPRESSION zstd, ROW_GROUP_SIZE 122880, KV_METADATA {%s})",
  sql, q(tmp), meta)))

# The hours are the grid's, or nothing is replaced
chk <- DBI::dbGetQuery(con, sprintf(
  "SELECT (SELECT count(*) FROM read_parquet(%1$s)) AS rows,
          (SELECT sum(h) FROM read_parquet(%1$s)) AS h_out, (SELECT sum(h) FROM (%2$s)) AS h_in,
          (SELECT coalesce(sum(h), 0) FROM read_parquet(%1$s) WHERE gid IS NULL) AS h_na", q(tmp), sql))
if (chk$rows != n || abs(chk$h_out - chk$h_in) > 1e-6 * chk$h_in) {
  unlink(tmp)
  stop("cells.R: the file written is not the grid's fishing cells", call. = FALSE)
}
invisible(file.rename(tmp, out))
# the hours with no gear: fixes whose stations have different gears (decision 331), about 840 h
cat(sprintf("%s: %s rows, %.0f MB, %s hours, %s of them with no gear\n", out, format(n, big.mark = ","),
            file.size(out) / 1e6, format(round(chk$h_out), big.mark = ","), format(round(chk$h_na), big.mark = ",")))
