# bundle.R — the bathymetry map as a folder that opens with a double click on its index.html: no R, no server, no
# install (the maintainer, 2026-11-04), for colleagues inside MFRI. The depth, its relief and contours from the
# elevation tiles to zoom 9, and the gazetteer's place names. Internal: the names carry Trackwell's and the plotters'.
#
# Input:  $FISHYDATA/products/bathymetry_map/depth.mbtiles; $FISHYDATA/curated/place_name/ (as bathymetry_map.R reads
#         it); this repo's map code and products/bathymetry_map/bundle_README.md; ramb >= 2026.11.04.2 (rb_map_bundle())
# Output: $FISHYDATA/exports/bathymetry_map_bundle/ (index.html, tiles/, data/, README.md, VERSION) and
#         bathymetry_map_bundle.zip beside it
#
# Run from the fishycode root: Rscript products/bathymetry_map/bundle.R
#
# - Tiles to zoom 9 (MAXZOOM): a zoom-9 pixel at 65 N is about 65 m, against the grid's 50 m; zoom 10 alone is 372 MB
#   of the file's 547 (2026-11-04). Past zoom 9 the map draws zoom 9's tiles larger.
# - The depth by cell is left out: its tiles are made by a server from the depth grid.
# - The view's fits (the depth's floor and cap, the contour levels, the shading's intensity) are made in the browser
#   from the tiles in view, by rb_map_bundle()'s rules: depth_fit()'s and relief_fit()'s, on the tiles' pixels rather
#   than the grid's cells.

source("products/bathymetry_map/bathymetry_map.R")

MAXZOOM <- 9
NAME <- "bathymetry_map_bundle"
out <- fd_path("exports", NAME)
zipfile <- fd_path("exports", paste0(NAME, ".zip"))
if (!exists("rb_map_bundle", envir = asNamespace("ramb"))) stop("ramb has no rb_map_bundle(): ramb >= 2026.11.04.2")

e <- .bathymetry_map
con <- DBI::dbConnect(duckdb::duckdb())
invisible(DBI::dbExecute(con, "LOAD spatial"))
m <- e$bathymetry_map_build(con, e$dir)
unlink(c(out, zipfile), recursive = TRUE)
b <- ramb::rb_map_bundle(m, out, maxzoom = MAXZOOM)
DBI::dbDisconnect(con, shutdown = TRUE)

# What it was made from ---------------------------------------------------------------------------------------------

git <- function(dir, ...) system2("git", c("-C", shQuote(dir), ...), stdout = TRUE)
dirty <- function(dir) if (length(git(dir, "status", "--porcelain", "--untracked-files=no"))) " (with changes not committed)" else ""
ramb_dir <- Sys.getenv("RAMB_DIR", path.expand("~/R/Pakkar/ramb"))
writeLines(c(
  sprintf("made: %s", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
  sprintf("fishycode: %s%s", git(".", "rev-parse", "--short", "HEAD"), dirty(".")),
  sprintf("ramb: %s%s", utils::packageVersion("ramb"),
          if (dir.exists(ramb_dir)) sprintf(", its clone at %s%s", git(ramb_dir, "rev-parse", "--short", "HEAD"), dirty(ramb_dir)) else ""),
  sprintf("tiles: zoom 0-%d, %d of them", MAXZOOM, attr(b, "tiles"))
), file.path(out, "VERSION"))
invisible(file.copy("products/bathymetry_map/bundle_README.md", file.path(out, "README.md")))
invisible(processx::run("zip", c("-r9Xq", basename(zipfile), NAME), wd = dirname(out)))

cat(sprintf("%s: %d tiles, %.0f MB; zipped %.0f MB\n", out, attr(b, "tiles"),
            sum(file.size(list.files(out, recursive = TRUE, full.names = TRUE))) / 1e6, file.size(zipfile) / 1e6))
