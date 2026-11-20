# OpenStreetMap's wrecks round Iceland, as fetched: one row per object and one per tag (plan 074 step 12, the wrecks; the
# named-features study's 91_wrecks.R).
# Side: preprocessing (wrecks). Standalone, run by hand outside the targets flow (plan 082 ask p); reference/wrecks/wreck.R
# reads its output.
#
# Input:  raw/external/osm_wrecks/wrecks_<YYYYMMDD>.osm.gz, the latest (dump/osm/wrecks.R: every object tagged
#         seamark:type=wreck or historic=wreck in the box 32 W to 6 W, 59 N to 70 N)
# Output: staging/osm/wreck.parquet - one row per object: osm_id ("node/123", "way/45"), version, timestamp, the fetch's file,
#         WKB `geometry` (a node's own position, a way's or relation's centre as Overpass gives it), WGS 84
#         staging/osm/wreck_tag.parquet - one row per tag of an object: osm_id, key, value, as delivered
#
# Source-shaped: no tag read or judged here (names, depths and dates are reference/wrecks/wreck.R's). The contributors' names
# in the fetch's metadata are not carried. Data © OpenStreetMap contributors, ODbL.
# Run from the repo root: Rscript sources/osm/wreck.R. Written by Claude (AI), 2026-11-19.
library(sf)
for (f in c("R/paths.R", "R/write_parquet.R")) source(f)   # standalone: not targets'
f <- tail(sort(list.files(fd_raw("external", "osm_wrecks"), "\\.osm\\.gz$", full.names = TRUE)), 1)
x <- xml2::read_xml(gzfile(f)); obj <- xml2::xml_find_all(x, "/osm/node|/osm/way|/osm/relation")
nd <- xml2::xml_name(obj) == "node"; cen <- xml2::xml_find_first(obj, "center")
id <- paste0(xml2::xml_name(obj), "/", xml2::xml_attr(obj, "id"))
o <- data.frame(osm_id = id, lon = as.numeric(ifelse(nd, xml2::xml_attr(obj, "lon"), xml2::xml_attr(cen, "lon"))),
                lat = as.numeric(ifelse(nd, xml2::xml_attr(obj, "lat"), xml2::xml_attr(cen, "lat"))),
                version = as.integer(xml2::xml_attr(obj, "version")), timestamp = xml2::xml_attr(obj, "timestamp"), file = basename(f))
tags <- do.call(rbind, lapply(seq_along(obj), function(k) { t <- xml2::xml_find_all(obj[[k]], "tag")
  if (length(t)) data.frame(osm_id = id[k], key = xml2::xml_attr(t, "k"), value = xml2::xml_attr(t, "v")) else NULL }))
stopifnot(!anyDuplicated(o$osm_id), !anyNA(o$lon), !anyNA(o$lat))
write_parquet_sf(st_as_sf(o, coords = c("lon", "lat"), crs = 4326), fd_staging("osm", "wreck.parquet"))
nanoparquet::write_parquet(tags, fd_staging("osm", "wreck_tag.parquet"))
message(sprintf("osm: %d wreck objects, %d tags, from %s", nrow(o), nrow(tags), basename(f)))
