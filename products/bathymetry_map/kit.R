# kit.R — the bathymetry map as a kit for colleagues inside MFRI: one folder to copy to a share, with its data, a
# snapshot of the map's code and ramb as package files, run from R with no fishycode checkout and no $FISHYDATA of
# their own (TODO 185). Internal: it carries the gazetteer's names from Trackwell and the plotters.
#
# Input:  $FISHYDATA/products/bathymetry_map/ (depth.mbtiles, grid_0010/, grid_0040.parquet, grid_0200.parquet);
#         $FISHYDATA/curated/place_name/{place_name, place, synonym, name_group}.parquet; this repo's map code; the ramb
#         checkout at RAMB_DIR (default ~/R/Pakkar/ramb), built with R CMD build
# Output: $FISHYDATA/exports/bathymetry_map_kit/: data/ (laid out as a $FISHYDATA), code/ (the map's code as in this
#         repo, with start.R and an RStudio project), ramb/ (the source package, and a binary for this Mac's R),
#         README.md (the instructions) and VERSION (the commits it was made from)
#
# Run from the fishycode root: Rscript products/bathymetry_map/kit.R. The data are cloned (cp -c on APFS), so the kit
# takes no space here until a file changes.

source("R/paths.R")

kit <- fd_path("exports", "bathymetry_map_kit")
ramb_dir <- Sys.getenv("RAMB_DIR", path.expand("~/R/Pakkar/ramb"))
unlink(kit, recursive = TRUE)
dir.create(kit, recursive = TRUE)

copy <- function(from, to) {
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  # a clone where the file system has them (APFS), else a copy
  ok <- system2("cp", c("-c", "-R", shQuote(from), shQuote(to)), stdout = FALSE, stderr = FALSE) == 0
  if (!ok) ok <- file.copy(from, dirname(to), recursive = TRUE)
  if (!ok) stop("could not copy ", from)
}

# Data -------------------------------------------------------------------------------------------------------------

for (f in c("depth.mbtiles", "grid_0010", "grid_0040.parquet", "grid_0200.parquet")) {
  copy(fd_path("products", "bathymetry_map", f), file.path(kit, "data", "products", "bathymetry_map", f))
}
for (f in c("place_name", "place", "synonym", "name_group")) {
  copy(fd_path("curated", "place_name", paste0(f, ".parquet")),
       file.path(kit, "data", "curated", "place_name", paste0(f, ".parquet")))
}

# Code: as in this repo, so the kit runs what the repo runs -------------------------------------------------------

for (f in c("R/paths.R", "R/write_curated.R", "products/effort_map/tiles.R", "products/effort_map/map.R",
            "products/effort_map/map.json", "products/bathymetry_map/bathymetry_map.R",
            "products/bathymetry_map/server.R")) {
  copy(f, file.path(kit, "code", f))
}
writeLines(c(
  "# start.R — the bathymetry map from the kit: run from this folder (open bathymetry_map.Rproj in RStudio).",
  "# The kit's data are its own $FISHYDATA; the map opens in RStudio's Viewer, or a browser.",
  "Sys.setenv(FISHYDATA = normalizePath(file.path('..', 'data'), mustWork = TRUE))",
  "source('products/bathymetry_map/bathymetry_map.R')",
  "bathymetry_map()",
  "message('bathymetry_map_stop() stops it; bathymetry_map(center = c(-22.5, 64.3), zoom = 9) opens Faxafloi')"
), file.path(kit, "code", "start.R"))
writeLines(c("Version: 1.0", "", "RestoreWorkspace: No", "SaveWorkspace: No", "AlwaysSaveHistory: No", "",
             "Encoding: UTF-8"), file.path(kit, "code", "bathymetry_map.Rproj"))

# ramb: its source package, and a binary for this Mac's R ----------------------------------------------------------

# R CMD build and INSTALL --build write into the folder they run in: a temporary one, never this repo
dir.create(file.path(kit, "ramb"))
build <- tempfile("ramb_build_")
dir.create(file.path(build, "lib"), recursive = TRUE)
in_build <- function(cmd) system(sprintf("cd %s && %s > out.log 2>&1", shQuote(build), cmd))
st <- in_build(sprintf("R CMD build --no-build-vignettes --no-manual %s", shQuote(ramb_dir)))
tarball <- list.files(build, pattern = "^ramb_.*[.]tar[.]gz$")
if (st != 0 || length(tarball) != 1) stop("R CMD build failed: see ", file.path(build, "out.log"))
st <- in_build(sprintf("R CMD INSTALL --build --preclean -l lib %s", shQuote(tarball)))
binary <- list.files(build, pattern = "^ramb_.*[.]tgz$")
if (st != 0 || length(binary) != 1) stop("the binary build failed: see ", file.path(build, "out.log"))
invisible(file.copy(file.path(build, c(tarball, binary)), file.path(kit, "ramb")))
unlink(build, recursive = TRUE)

# What it was made from ---------------------------------------------------------------------------------------------

git <- function(dir, ...) system2("git", c("-C", shQuote(dir), ...), stdout = TRUE)
writeLines(c(
  sprintf("made: %s", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
  sprintf("fishycode: %s%s", git(".", "rev-parse", "--short", "HEAD"),
          if (length(git(".", "status", "--porcelain", "--untracked-files=no"))) " (with changes not committed)" else ""),
  sprintf("ramb: %s %s%s", read.dcf(file.path(ramb_dir, "DESCRIPTION"), "Version"), git(ramb_dir, "rev-parse", "--short", "HEAD"),
          if (length(git(ramb_dir, "status", "--porcelain", "--untracked-files=no"))) " (with changes not committed)" else ""),
  sprintf("R that built the binary: %s, %s", R.version$version.string, R.version$platform)
), file.path(kit, "VERSION"))

invisible(file.copy("products/bathymetry_map/kit_README.md", file.path(kit, "README.md"), overwrite = TRUE))
message("kit in ", kit, ": ", paste(list.files(kit), collapse = ", "))
