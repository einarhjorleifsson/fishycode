# adopt_windows.R — the sea-chart windows of the chart-name studies, moved into raw/external/sjokort/ (plan 074 step 1b)
#
# Input:  $FISHYDATA/archive/2026-11-04-chart-names-coast/img/<id>.png (the chart on white; not <id>_grid.png, which carries
#         a drawn grid) with its results/windows.csv; archive/2026-11-11-named-features/out/scale/<folder>/windows/<id>.png
#         with each folder's windows.csv (the windows that study fetched beyond the first, 22_fetch_windows.R)
# Output: raw/external/sjokort/<series>/<id>.png; raw/external/sjokort/_manifest.csv (one row a window: series, id, file,
#         md5, bytes, when fetched, the study it came from, its extent in web Mercator and its chart share);
#         raw/external/sjokort/README-provenance.txt; at each old path a relative symbolic link to the file's new place, so the
#         studies' scripts and READMEs still read it
# One-time, run by hand (decision 295's way, dump/timarit/adopt_studies.R). A file is moved (rename within $FISHYDATA), its
# md5 checked before and after; a path that is already a link is skipped, so a second run moves nothing; a second copy of a
# window with the same bytes becomes a link to the first; a second copy with other bytes stops it. Makes no request. The
# pilot study's windows (archive/2026-11-02-chart-names-pilot/img, another grid) and the old charts' scans
# (archive/2026-11-08-old-chart-names) are not these and stay where they are.
# The maintainer, 2026-11-12: "is this table in the end not something that will have a home in fishydata, aka like staged ->
# curated approach we have been using?"; 2026-11-15: "Yes, start" (plan 074 step 1b, the windows given one home).
# Run from fishycode's root:
#   Rscript dump/sjokort/adopt_windows.R
# Drafted by Claude (AI), 2026-11-15. Not checked by a person.

Sys.setenv(TZ = "UTC")
source("R/paths.R")
FD <- normalizePath(fishydata_root())
A <- file.path(FD, "archive")
DEST <- fd_raw("external", "sjokort")
md5 <- function(f) unname(tools::md5sum(f))
when <- function(f) format(file.mtime(f), "%Y-%m-%d %H:%M:%S", tz = "UTC")
rel_link <- function(dest, src) {     # a relative link from the old path to the new, both under $FISHYDATA
  up <- length(strsplit(sub(paste0("^", FD, "/"), "", dirname(src)), "/")[[1]])
  paste(c(rep("..", up), sub(paste0("^", FD, "/"), "", dest)), collapse = "/")
}
series_of <- function(f) paste0("sjokort_", sub("_r-?[0-9]+c-?[0-9]+[.]png$", "", basename(f)))

# the sources, the coast study first (it fetched most), then the named-features study's folders
cc <- file.path(A, "2026-11-04-chart-names-coast")
nf <- list.dirs(file.path(A, "2026-11-11-named-features/out/scale"), recursive = FALSE)
nf <- nf[file.exists(file.path(nf, "windows", "windows.csv"))]
src <- c(list(list(dir = file.path(cc, "img"), listing = file.path(cc, "results/windows.csv"))),
         lapply(nf, function(d) list(dir = file.path(d, "windows"), listing = file.path(d, "windows", "windows.csv"))))
ext <- do.call(rbind, lapply(src, function(s) { w <- utils::read.csv(s$listing)
  data.frame(id = w$id, x0 = w$x0, y0 = w$y0, x1 = w$x1, y1 = w$y1, chart = w$chart) }))
ext <- ext[!duplicated(ext$id), ]

man_f <- file.path(DEST, "_manifest.csv")
man <- if (file.exists(man_f)) utils::read.csv(man_f, colClasses = "character") else NULL
rows <- list(); n_moved <- n_linked <- n_skipped <- 0
for (s in src) {
  fs <- list.files(s$dir, "[.]png$", full.names = TRUE)
  fs <- fs[!grepl("_grid[.]png$", fs) & grepl("_r-?[0-9]+c-?[0-9]+[.]png$", basename(fs))]
  for (f in fs) {
    if (nzchar(Sys.readlink(f))) { n_skipped <- n_skipped + 1; next }     # moved already
    ser <- series_of(f); id <- sub("[.]png$", "", basename(f)); dest <- file.path(DEST, ser, basename(f)); m <- md5(f)
    if (file.exists(dest)) {                                             # a second copy: the same bytes, or stop
      if (md5(dest) != m) stop("a second copy with other bytes: ", f, " (", dest, ")")
      stopifnot(file.remove(f), file.symlink(rel_link(dest, f), f)); n_linked <- n_linked + 1; next }
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    t0 <- when(f); b <- file.size(f)
    stopifnot(file.rename(f, dest), md5(dest) == m, file.symlink(rel_link(dest, f), f)); n_moved <- n_moved + 1
    e <- ext[match(id, ext$id), ]
    rows[[length(rows) + 1]] <- data.frame(series = ser, id = id, file = file.path(ser, basename(f)), md5 = m, bytes = b, fetched = t0,
                                           from = sub(paste0("^", FD, "/"), "", s$dir), x0 = e$x0, y0 = e$y0, x1 = e$x1, y1 = e$y1, chart = e$chart)
  }
}
new <- if (length(rows)) do.call(rbind, rows) else NULL
if (!is.null(new)) { out <- if (is.null(man)) new else rbind(man, new); out <- out[order(out$series, out$id), ]
  utils::write.csv(out, man_f, row.names = FALSE) }
writeLines(c(
  "raw/external/sjokort: windows of the Icelandic sea charts (Sjómælingar Íslands, Landhelgisgæslan), one PNG a window.",
  "Source: the charts' map cache on gis.natt.is, a WMS in web Mercator (EPSG:3857), layer Sjomaelingar:<series>, requested",
  "1024 x 1024 px at twice the chart's print scale at 65 N, a tenth overlapping, on a grid from 30 W, 68 N; transparent",
  "pixels flattened onto white. Fetched by the studies archive/2026-11-04-chart-names-coast (scripts/01_images.R) and",
  "archive/2026-11-11-named-features (scripts/22_fetch_windows.R), 2026-11-04 to -14; moved here by",
  "dump/sjokort/adopt_windows.R (fishycode), links left at the old paths. _manifest.csv: each window's md5, size, when it",
  "was fetched (the file's time), where it came from, its extent (x0, y0, x1, y1, metres) and the chart's share of it.",
  "The same windows again, or new ones: dump/sjokort/fetch.R.",
  "Internal: the charts are Landhelgisgæslan's (© Sjómælingar Íslands); not for navigation."), file.path(DEST, "README-provenance.txt"))
cat("moved", n_moved, "; linked as second copies", n_linked, "; already links", n_skipped, "; in the manifest", if (is.null(new)) nrow(man) else nrow(out), "\n")
