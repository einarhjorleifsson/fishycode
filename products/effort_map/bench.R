# bench.R — the effort map's tile times on a fixed set of tiles, so each step of plan 046 is measured against the same
# work.
# Plan 046, step 1.
#
# Input:  tiles.R and the grid it reads ($FISHYDATA/products/effort_map/grid.parquet, grid_005.parquet)
# Output: $FISHYDATA/products/effort_map/bench/<date>_<label>.csv, one row per tile and case: z, x, y, px, filter, ms
#         (effort_tile() alone, as the server spends it), bytes; and a summary by zoom, cells and filter on the console
#
# Run from the fishycode root (about 10 min):  Rscript products/effort_map/bench.R [label]
#
# The set: every tile at zoom 5-8 that touches the Icelandic grounds (lon -30 to -8, lat 62 to 68.5), at each of the
# page's cell sizes, with no filter (the heaviest) and with bottom trawl (gid 6) in 2015-2020. The zoom 5 tiles are
# read once before timing, so the first tiles do not carry the cold start.

source("R/paths.R")
source("products/effort_map/tiles.R")
source("products/effort_map/app.R")     # PX, the page's cell sizes

label <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(label)) label <- "run"
GRID <- fd_path("products", "effort_map", "grid.parquet")
BBOX <- c(lon0 = -30, lon1 = -8, lat0 = 62, lat1 = 68.5)
FILTERS <- list(all = list(gid = NULL, y1 = NULL, y2 = NULL),
                gid6_2015_2020 = list(gid = 6L, y1 = 2015L, y2 = 2020L))

tile_x <- function(lon, z) floor((lon + 180) / 360 * 2^z)
tile_y <- function(lat, z) floor((1 - log(tan(lat * pi / 180) + 1 / cos(lat * pi / 180)) / pi) / 2 * 2^z)
tiles <- do.call(rbind, lapply(5:8, function(z)
  expand.grid(z = z, x = tile_x(BBOX[["lon0"]], z):tile_x(BBOX[["lon1"]], z),
              y = tile_y(BBOX[["lat1"]], z):tile_y(BBOX[["lat0"]], z))))

con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, "LOAD spatial"))
for (i in which(tiles$z == 5)) invisible(effort_tile(con, GRID, tiles$z[i], tiles$x[i], tiles$y[i]))

# Time -------------------------------------------------------------------------
runs <- expand.grid(i = seq_len(nrow(tiles)), px = PX, filter = names(FILTERS),
                    stringsAsFactors = FALSE)
cat(sprintf("%d tiles x %d cell sizes x %d filters = %d tile reads\n", nrow(tiles), length(PX), length(FILTERS),
            nrow(runs)))
out <- do.call(rbind, lapply(seq_len(nrow(runs)), function(k) {
  t <- tiles[runs$i[k], ]; f <- FILTERS[[runs$filter[k]]]
  t0 <- proc.time()[["elapsed"]]
  b <- effort_tile(con, GRID, t$z, t$x, t$y, "fishing", f$gid, f$y1, f$y2, runs$px[k])
  data.frame(z = t$z, x = t$x, y = t$y, px = runs$px[k], filter = runs$filter[k],
             ms = round(1000 * (proc.time()[["elapsed"]] - t0)), bytes = length(b))
}))
out$duckdb <- as.character(packageVersion("duckdb"))
out$commit <- system("git rev-parse --short HEAD", intern = TRUE)
DBI::dbDisconnect(con, shutdown = TRUE)

dir <- fd_path("products", "effort_map", "bench")
dir.create(dir, showWarnings = FALSE)
file <- file.path(dir, sprintf("%s_%s.csv", format(Sys.Date()), label))
utils::write.csv(out, file, row.names = FALSE)

# Summary ----------------------------------------------------------------------
s <- do.call(rbind, lapply(split(out, list(out$filter, out$px, out$z), drop = TRUE), function(d)
  data.frame(filter = d$filter[1], px = d$px[1], z = d$z[1], tiles = nrow(d), ms_median = stats::median(d$ms),
             ms_p95 = unname(stats::quantile(d$ms, 0.95)), ms_max = max(d$ms), mb_max = round(max(d$bytes) / 1e6, 2))))
s <- s[order(s$filter, s$px, s$z), ]
print(s, row.names = FALSE)
cat("written:", file, "\n")
