# A skipper's TimeZero plotter (internal): the three exports the wreck list reads, every object and waypoint as delivered
# (plan 074 step 12, the wrecks; the named-features study's 91_wrecks.R).
# Side: preprocessing (wrecks). Standalone, run by hand outside the targets flow (plan 082 ask p); reference/wrecks/wreck.R
# reads its output.
#
# Input:  raw/external/ornefni/fra_gudmundi-a-bjarna/GS_nofn-og-flok_2022-10-18/{Nöfn, Nöfn og flök}/UserObjects.json (the
#         TimeZero export of 30.7.2021, unzipped) and nofn og flok.gpx (the GPX export of 2022-10-18);
#         raw/external/vernd_i_hafi/kortlagning/grunnthekjur/nofn-flok/nöfn og flök.tzx (the TimeZero export of 20.6.2025,
#         read inside its zip); TimeZero's point geometry decoded by tz_point() of sources/ornefni/plotter_mark.R (parsed out
#         of that script, not copied), the GPX read by read_gpx_marks() of R/gpx.R
# Output: staging/ornefni/plotter_wreck_tz.parquet - one row per TimeZero object of the 2021 and 2025 exports (marks, depth
#         marks, ground names, lines, areas): export (tz2021, tz2025), file (under raw/external/), every field as delivered
#         (Guid, ObjectType, Geometry in base64, CreationDate and LastModificationDate in seconds since 2000-01-01 UTC, Icon,
#         Color, Name, Comment, UserLayerGuid, Deleted, Value1-6 ...: TimeZero's own names), decoded (its point read),
#         WKB `position` (WGS 84; an empty point where TimeZero's geometry is a line or an area, not decoded; not named
#         geometry, which DuckDB would take for TimeZero's own Geometry)
#         staging/ornefni/plotter_wreck_gpx.parquet - one row per waypoint of the 2022 GPX export as read_gpx_marks() gives
#         it: mark (its order in the file), time_txt, name, cmt, symbol, colour, WKB `geometry`, WGS 84
#
# Source-shaped: which marks are wrecks, and which copy another list's or an earlier state, are reference/wrecks/wreck.R's.
# The 2025 export's abcd.gpx, Flök.kml (= ccc.kml) and cc_wpt.csv hold its marks again in other formats and are not staged
# (curate/checks/wreck_accounting.R checks that they do). sources/ornefni/plotter_mark.R stages the 2021 export and every
# GPX for the place names, with fewer fields; the 2025 export is staged only here. Internal, as Háskóli Íslands' list: its
# owner is named under $FISHYDATA only.
# Run from the repo root: Rscript sources/ornefni/plotter_wreck.R. Written by Claude (AI), 2026-11-19.
library(sf)
for (f in c("R/paths.R", "R/gpx.R", "R/write_parquet.R")) source(f)   # standalone: not targets'
# TimeZero's point geometry, decoded by fishycode's own adapter: its tz_point() is parsed out of that script, not copied
local({ ex <- parse("sources/ornefni/plotter_mark.R", encoding = "UTF-8")
  i <- which(vapply(ex, function(e) is.call(e) && identical(e[[1]], as.name("<-")) && identical(e[[2]], as.name("tz_point")), logical(1)))
  stopifnot("tz_point() found once in sources/ornefni/plotter_mark.R" = length(i) == 1); eval(ex[[i]], globalenv()) })
GS <- file.path("ornefni", "fra_gudmundi-a-bjarna", "GS_nofn-og-flok_2022-10-18")
TZ25 <- file.path("vernd_i_hafi", "kortlagning", "grunnthekjur", "nofn-flok", "nöfn og flök.tzx")
tz_objects <- function(con, export, file) {   # every TimeZero object with every field as given, its point decoded beside
  txt <- sub("^﻿", "", paste(readLines(con, warn = FALSE, encoding = "UTF-8"), collapse = ""))
  o <- jsonlite::stream_in(textConnection(gsub('}{"Object"', '}\n{"Object"', txt, fixed = TRUE)), verbose = FALSE)$Object
  p <- tz_point(o$Geometry)
  cbind(data.frame(export = rep(export, nrow(o)), file = rep(file, nrow(o))), o, decoded = p$decoded, lon = p$lon, lat = p$lat) }
tz <- dplyr::bind_rows(
  tz_objects(fd_raw("external", GS, "Nöfn", "UserObjects.json"), "tz2021", file.path(GS, "Nöfn", "UserObjects.json")),
  tz_objects(fd_raw("external", GS, "Nöfn og flök", "UserObjects.json"), "tz2021", file.path(GS, "Nöfn og flök", "UserObjects.json")),
  tz_objects(unz(fd_raw("external", TZ25), "UserObjects.json"), "tz2025", file.path(TZ25, "UserObjects.json")))
pts <- st_sfc(lapply(seq_len(nrow(tz)), function(i) if (tz$decoded[i]) st_point(c(tz$lon[i], tz$lat[i])) else st_point()), crs = 4326)
tz <- st_sf(tz[, setdiff(names(tz), c("lon", "lat"))], position = pts)
g22 <- read_gpx_marks(fd_raw("external", GS, "nofn og flok.gpx")); stopifnot(!anyNA(g22$lon), !anyNA(g22$lat))
g22 <- st_as_sf(g22, coords = c("lon", "lat"), crs = 4326)
write_parquet_sf(tz, fd_staging("ornefni", "plotter_wreck_tz.parquet"))
write_parquet_sf(g22, fd_staging("ornefni", "plotter_wreck_gpx.parquet"))
message(sprintf("plotter: %d TimeZero objects (%s), %d decoded; %d waypoints of 2022", nrow(tz),
                paste(names(table(tz$export)), table(tz$export), sep = ": ", collapse = ", "), sum(tz$decoded), nrow(g22)))
