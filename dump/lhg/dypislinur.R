# The Icelandic Coast Guard's depth contours (Landhelgisgæslan, "Dýpislínur frá Landhelgisgæslunni"), as served by
# Náttúrufræðistofnun's GeoServer, WFS layer LHG:dypislinur. The maintainer, 2026-11-12: "yes, fetch LHG:dypislinur -
# think you should put them in fishydata raw". Wanted as the charts' own contours, beside the Olex grid's, for drawing
# named features' outlines at the charts' standard isobaths (plan 074).
# Input: https://gis.natt.is/geoserver/ows (WFS 2.0.0 GetFeature, GeoJSON, the layer's own coordinate system).
# Output: $FISHYDATA/raw/external/lhg/dypislinur.geojson (as delivered), and README-provenance.txt beside it (the request,
# the date, bytes, sha256, features, the coordinate system, the attributes). Run once, from the repo root:
#   Rscript dump/lhg/dypislinur.R
# Written by Claude (AI).
source("R/paths.R")
out_dir <- fd_raw("external", "lhg"); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out <- file.path(out_dir, "dypislinur.geojson")
url <- paste0("https://gis.natt.is/geoserver/ows?service=WFS&version=2.0.0&request=GetFeature",
              "&typeNames=LHG:dypislinur&outputFormat=application/json")
# the number of features the server holds, to check that the answer is whole (a server may cap a GetFeature)
hits <- httr2::request(paste0("https://gis.natt.is/geoserver/ows?service=WFS&version=2.0.0&request=GetFeature",
                              "&typeNames=LHG:dypislinur&resultType=hits")) |>
  httr2::req_user_agent("fishycode data fetch") |> httr2::req_perform() |> httr2::resp_body_string()
matched <- as.integer(sub('.*numberMatched="([0-9]+)".*', "\\1", hits))
httr2::request(url) |> httr2::req_user_agent("fishycode data fetch") |> httr2::req_timeout(600) |> httr2::req_perform(path = out)

x <- sf::read_sf(out)
crs <- sf::st_crs(x)
bb <- sf::st_bbox(sf::st_transform(x, 4326))
sha <- digest::digest(out, algo = "sha256", file = TRUE)
attrs <- vapply(sf::st_drop_geometry(x), function(v) class(v)[1], "")
num <- names(attrs)[attrs %in% c("numeric", "integer")]
ranges <- vapply(num, function(n) paste(range(x[[n]], na.rm = TRUE), collapse = " to "), "")
note <- c(
  "# The Icelandic Coast Guard's depth contours: \"Dýpislínur frá Landhelgisgæslunni\" (the layer's own abstract), WFS layer",
  "# LHG:dypislinur on Náttúrufræðistofnun's GeoServer. Fetched by dump/lhg/dypislinur.R at the maintainer's word",
  "# (2026-11-12: \"yes, fetch LHG:dypislinur - think you should put them in fishydata raw\").",
  "# This note was written by a Claude session (AI) from the file itself; no person has checked it yet.",
  "",
  "# dypislinur.geojson",
  sprintf("#  fetched %s UTC from %s", format(Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC"), url),
  sprintf("#  %s bytes, sha256 %s", format(file.size(out), big.mark = ""), sha),
  sprintf("#  %d features (the server reported %s matched), geometry %s", nrow(x), matched, paste(unique(as.character(sf::st_geometry_type(x))), collapse = ", ")),
  sprintf("#  CRS: %s (EPSG %s)", crs$Name %||% crs$input, crs$epsg %||% "?"),
  sprintf("#  Extent: %.2f to %.2f E, %.2f to %.2f N", bb["xmin"], bb["xmax"], bb["ymin"], bb["ymax"]),
  sprintf("#  Attributes: %s", paste(sprintf("%s (%s)", names(attrs), attrs), collapse = ", ")),
  if (length(num)) sprintf("#  Ranges: %s", paste(sprintf("%s %s", names(ranges), ranges), collapse = "; ")),
  "",
  "# Terms of use: not stated with the layer; to ask Landhelgisgæslan before anything made from it is published.",
  "# Not known yet: the source scale and survey of the contours, and their datum (chart datum, by the charts' convention)."
)
writeLines(note, file.path(out_dir, "README-provenance.txt"))
cat(note, sep = "\n")
if (!is.na(matched) && nrow(x) < matched) warning("Fewer features than the server holds: the answer was capped; fetch in pages.")
