# bundle.R — the depth and effort map as a folder that opens with a double click on its index.html: no R, no server
# (the maintainer, 2026-11-04), for colleagues inside MFRI. The depth, its relief and contours from the elevation
# tiles to zoom 9, the place names, and the effort with all its filters (gear, years, fishing definition, hours or
# kW-hours), summed in the browser from its rows. Internal: vessel-level data, and Trackwell's and the plotters' names.
#
# Input:  what depth_effort_map.R reads; $FISHYDATA/products/effort_map/grid_005.parquet (grid.R, the interpolated
#         grid on 0.005-degree cells); products/depth_effort_map/bundle_README.md; ramb >= 2026.11.04.3
#         (rb_map_bundle(grids = ))
# Output: $FISHYDATA/exports/depth_effort_map_bundle/ (index.html, tiles/, data/, grids/, README.md, VERSION) and
#         depth_effort_map_bundle.zip beside it
#
# Run from the fishycode root, as a heavy job (DuckDB sums 71 M rows; under the heavy jobs' shared lock when other
# sessions run): Rscript products/depth_effort_map/bundle.R, about 3 minutes
#
# - The depth to zoom 9, as products/bathymetry_map/bundle.R (decision 277).
# - The effort's rows summed to cells of 0.01, 0.02, 0.04, 0.1, 0.2 and 0.5 degrees (LEVELS), by gear, year and
#   fishing definition, everywhere the grid has them. The page takes the size that makes a cell one to two screen
#   pixels, so at zoom 7 and in the cells are 0.01 degrees, where the server goes to 0.001.
# - The interpolated effort only: the interpolation switch is left out (its grid of fixes would double the effort's
#   share of the folder).

source("products/depth_effort_map/depth_effort_map.R")

MAXZOOM <- 9
LEVELS <- c(10, 20, 40, 100, 200, 500)   # thousandths of a degree
NAME <- "depth_effort_map_bundle"
out <- fd_path("exports", NAME)
zipfile <- fd_path("exports", paste0(NAME, ".zip"))
grid <- fd_path("products", "effort_map", "grid_005.parquet")
if (!"grids" %in% names(formals(ramb::rb_map_bundle))) stop("ramb's rb_map_bundle() has no `grids`: ramb >= 2026.11.04.3")

con <- DBI::dbConnect(duckdb::duckdb())
spill <- file.path(tempdir(), "duckdb_spill")
invisible(lapply(c("LOAD spatial", "SET threads = 4", "SET memory_limit = '5GB'",
                   sprintf("SET temp_directory = '%s'", spill)), function(s) DBI::dbExecute(con, s)))
m <- depth_effort_map_build(con)
rows <- dplyr::tbl(con, dplyr::sql(sprintf(
  "SELECT preset, gid, year, ix, iy, h, kwh, n FROM read_parquet('%s')", grid)))
unlink(c(out, zipfile), recursive = TRUE)
b <- ramb::rb_map_bundle(m, out, maxzoom = MAXZOOM, grids = list(effort = list(
  rows = rows, unit = 0.001, levels = LEVELS, x = "ix", y = "iy",
  columns = c(preset = "preset", gid = "gid", years = "year"),
  sums = c("h", "kwh", "n"),
  fields = list(h_km2 = c("h", "km2"), kwh_km2 = c("kwh", "km2"), n = "n"),
  px = "px"
)))
DBI::dbDisconnect(con, shutdown = TRUE)
unlink(spill, recursive = TRUE)

# What it was made from ---------------------------------------------------------------------------------------------

git <- function(dir, ...) system2("git", c("-C", shQuote(dir), ...), stdout = TRUE)
dirty <- function(dir) if (length(git(dir, "status", "--porcelain", "--untracked-files=no"))) " (with changes not committed)" else ""
ramb_dir <- Sys.getenv("RAMB_DIR", path.expand("~/R/Pakkar/ramb"))
size <- function(d) sum(file.size(list.files(file.path(out, d), recursive = TRUE, full.names = TRUE))) / 1e6
writeLines(c(
  sprintf("made: %s", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
  sprintf("fishycode: %s%s", git(".", "rev-parse", "--short", "HEAD"), dirty(".")),
  sprintf("ramb: %s%s", utils::packageVersion("ramb"),
          if (dir.exists(ramb_dir)) sprintf(", its clone at %s%s", git(ramb_dir, "rev-parse", "--short", "HEAD"), dirty(ramb_dir)) else ""),
  sprintf("tiles, the depth's and the ports': zoom 0-%d, %d of them, %.0f MB", MAXZOOM, attr(b, "tiles"), size("tiles")),
  sprintf("effort: %s, cells of %s degrees, %.0f MB", basename(grid), paste(LEVELS / 1000, collapse = ", "), size("grids"))
), file.path(out, "VERSION"))
invisible(file.copy("products/depth_effort_map/bundle_README.md", file.path(out, "README.md")))
invisible(processx::run("zip", c("-r9Xq", basename(zipfile), NAME), wd = dirname(out)))

cat(sprintf("%s: %.0f MB (the effort %.0f MB); zipped %.0f MB\n", out,
            sum(file.size(list.files(out, recursive = TRUE, full.names = TRUE))) / 1e6, size("grids"),
            file.size(zipfile) / 1e6))
