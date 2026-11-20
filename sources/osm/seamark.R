# OpenStreetMap's seamarks round Iceland, as fetched: one row per object and one per tag (plan 082, the aids).
# Side: preprocessing (aids). Standalone, run by hand outside the targets flow (plan 082 ask p); reference/aids/aid.R reads it.
#
# Input:  raw/external/osm_seamarks/seamarks_<YYYYMMDD>.osm.gz, the latest (dump/osm/seamarks.R: every object tagged
#         seamark:type, man_made=lighthouse or man_made=beacon in the box 32 W to 6 W, 59 N to 70 N)
# Output: staging/osm/seamark.parquet - one row per object: osm_id ("node/123", "way/45"), lon, lat (a node's own, a way's or
#         relation's centre as Overpass gives it), version, timestamp, the fetch's file
#         staging/osm/seamark_tag.parquet - one row per tag of an object: osm_id, key, value, as delivered
#
# Source-shaped: no tag read or judged here (which objects are aids is reference/aids/aid.R's). The contributors' names in
# the fetch's metadata are not carried. Data © OpenStreetMap contributors, ODbL.
# Run from the repo root: Rscript sources/osm/seamark.R. Written by Claude (AI).
f <- tail(sort(list.files(fd_raw("external", "osm_seamarks"), "\\.osm\\.gz$", full.names = TRUE)), 1)
x <- xml2::read_xml(gzfile(f)); obj <- xml2::xml_find_all(x, "/osm/node|/osm/way|/osm/relation")
nd <- xml2::xml_name(obj) == "node"; cen <- xml2::xml_find_first(obj, "center")
id <- paste0(xml2::xml_name(obj), "/", xml2::xml_attr(obj, "id"))
o <- data.frame(osm_id = id, lon = as.numeric(ifelse(nd, xml2::xml_attr(obj, "lon"), xml2::xml_attr(cen, "lon"))),
                lat = as.numeric(ifelse(nd, xml2::xml_attr(obj, "lat"), xml2::xml_attr(cen, "lat"))),
                version = as.integer(xml2::xml_attr(obj, "version")), timestamp = xml2::xml_attr(obj, "timestamp"), file = basename(f))
tags <- do.call(rbind, lapply(seq_along(obj), function(k) { t <- xml2::xml_find_all(obj[[k]], "tag")
  if (length(t)) data.frame(osm_id = id[k], key = xml2::xml_attr(t, "k"), value = xml2::xml_attr(t, "v")) else NULL }))
stopifnot(!anyDuplicated(o$osm_id), !anyNA(o$lon), !anyNA(o$lat))
dir.create(fd_staging("osm"), recursive = TRUE, showWarnings = FALSE)
nanoparquet::write_parquet(o, fd_staging("osm", "seamark.parquet"))
nanoparquet::write_parquet(tags, fd_staging("osm", "seamark_tag.parquet"))
message(sprintf("osm: %d seamark objects, %d tags, from %s", nrow(o), nrow(tags), basename(f)))
