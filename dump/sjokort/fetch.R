# fetch.R — windows of the Icelandic sea charts into raw/external/sjokort/<series>/ (plan 074 step 1b)
#
# Input:  the charts' map cache on gis.natt.is (a WMS in web Mercator, layer Sjomaelingar:<series>); raw/external/sjokort/
#         _manifest.csv (the windows held)
# Output: raw/external/sjokort/<series>/<id>.png, each window kept where the chart covers 2 % of it, the chart on white;
#         rows added to _manifest.csv (never rewritten); a window held already is not fetched again
# The windows of the chart-name studies (2026-11-04 to -14), on their grid: 1024 x 1024 px at twice the chart's print scale at
# 65 N, a tenth overlapping, rows and columns from 30 W, 68 N, the id <series less "sjokort_">_r<row>c<col> (three digits
# each, a minus sign kept: 2milljon_r-01c-01). The requests and the flattening are 22_fetch_windows.R's of the named-features
# study (archive/2026-11-11-named-features), whose windows dump/sjokort/adopt_windows.R moved here.
# Run from fishycode's root, by hand (it makes requests to gis.natt.is, three tries each, 0.2 s apart):
#   Rscript dump/sjokort/fetch.R <series> <row from> <row to> <col from> <col to>
#   e.g. Rscript dump/sjokort/fetch.R sjokort_2milljon 0 6 -1 9
# Internal: the charts are Landhelgisgæslan's (© Sjómælingar Íslands); not for navigation.
# Drafted by Claude (AI), 2026-11-15. Not checked by a person; not yet run (the windows held were fetched by the studies).

Sys.setenv(TZ = "UTC")
source("R/paths.R")
ar <- commandArgs(TRUE); if (length(ar) != 5) stop("Give the series and the rows and columns: sjokort_2milljon 0 6 -1 9", call. = FALSE)
SER <- ar[1]; rr <- as.integer(ar[2]):as.integer(ar[3]); cc <- as.integer(ar[4]):as.integer(ar[5])
SCALE <- c(sjokort_2milljon = 2e6, sjokort_1milljon = 1e6, sjokort_300thusund = 3e5, sjokort_K42 = 1.6e5, sjokort_100thusund = 1e5,
           sjokort_K44 = 7e4, sjokort_35_40_50thusund = 4e4, sjokort_15thusund = 1.5e4, sjokort_10thusund = 1e4)
if (!SER %in% names(SCALE)) stop("Not a series of the grid: ", SER, call. = FALSE)
DEST <- fd_raw("external", "sjokort"); dir.create(file.path(DEST, SER), recursive = TRUE, showWarnings = FALSE)
man_f <- file.path(DEST, "_manifest.csv"); man <- if (file.exists(man_f)) utils::read.csv(man_f, colClasses = "character") else NULL
R <- 6378137; mx <- function(lon) lon * pi / 180 * R; my <- function(lat) log(tan(pi / 4 + lat * pi / 360)) * R
PX <- 1024; X0 <- mx(-30); Y1 <- my(68); side <- SCALE[[SER]] * 0.00028 / 2 / cos(65 * pi / 180) * PX; step <- side * 0.9
WMS <- paste0("https://gis.natt.is/mapcache/sjokort/web-mercador/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap",
              "&FORMAT=image%2Fpng&TRANSPARENT=TRUE&STYLES=&CRS=EPSG%3A3857")
id_of <- function(r, c) sprintf("%s_r%s%sc%s", sub("sjokort_", "", SER), ifelse(r < 0, "-", ""), sprintf(ifelse(r < 0, "%02d", "%03d"), abs(r)),
                                paste0(ifelse(c < 0, "-", ""), sprintf(ifelse(c < 0, "%02d", "%03d"), abs(c))))
fetch <- function(url, tmp) { for (k in 1:3) { ok <- tryCatch({ utils::download.file(url, tmp, mode = "wb", quiet = TRUE); TRUE }, error = function(e) FALSE)
  if (ok) return(TRUE); Sys.sleep(2 * k) }; FALSE }
tmp <- tempfile(fileext = ".png"); on.exit(unlink(tmp), add = TRUE); rows <- list()
for (r in rr) for (c in cc) {
  id <- id_of(r, c); f <- file.path(DEST, SER, paste0(id, ".png")); if (file.exists(f) || id %in% man$id) next
  x <- X0 + side / 2 + (c - 1) * step; y <- Y1 - side / 2 - (r - 1) * step; bb <- c(x - side / 2, y - side / 2, x + side / 2, y + side / 2)
  url <- sprintf("%s&WIDTH=%d&HEIGHT=%d&BBOX=%s&LAYERS=Sjomaelingar%%3A%s", WMS, PX, PX, paste(bb, collapse = ","), SER)
  a <- if (fetch(url, tmp)) tryCatch(png::readPNG(tmp), error = function(e) NULL) else NULL
  chart <- if (is.null(a)) NA else if (dim(a)[3] == 4) mean(a[, , 4] > 0) else 1
  if (isTRUE(chart >= 0.02)) {
    rgb <- if (dim(a)[3] == 4) a[, , 1:3] * as.vector(a[, , 4]) + (1 - as.vector(a[, , 4])) else a[, , 1:3]; png::writePNG(rgb, f)
    rows[[length(rows) + 1]] <- data.frame(series = SER, id = id, file = file.path(SER, basename(f)), md5 = unname(tools::md5sum(f)), bytes = file.size(f),
      fetched = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"), from = "dump/sjokort/fetch.R", x0 = bb[1], y0 = bb[2], x1 = bb[3], y1 = bb[4], chart = round(chart, 3)) }
  Sys.sleep(0.2) }
if (length(rows)) { new <- do.call(rbind, rows); out <- if (is.null(man)) new else rbind(man, new); utils::write.csv(out[order(out$series, out$id), ], man_f, row.names = FALSE) }
cat(SER, ": rows", min(rr), "-", max(rr), ", columns", min(cc), "-", max(cc), ";", length(rows), "windows fetched and kept\n")
