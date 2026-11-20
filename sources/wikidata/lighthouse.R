# Wikidata's lighthouses round Iceland, the query's answer as delivered (plan 082, the aids).
# Side: preprocessing (aids). Standalone, run by hand outside the targets flow (plan 082 ask p); reference/aids/aid.R reads it.
#
# Input:  raw/external/wikidata_lighthouses/lighthouses_<YYYYMMDD>.csv, the latest (dump/wikidata/lighthouses.R)
# Output: staging/wikidata/lighthouse.parquet - one row per row of the answer (one per combination of an item's values: an
#         item with two characteristics is two rows): item (its Q-id), every column as delivered, lon and lat from its
#         coordinate (Point(lon lat)), the fetch's file
#
# Source-shaped: the rows are folded to one an item in reference/aids/aid.R, not here. Wikidata, CC0.
# Run from the repo root: Rscript sources/wikidata/lighthouse.R. Written by Claude (AI).
f <- tail(sort(list.files(fd_raw("external", "wikidata_lighthouses"), "\\.csv$", full.names = TRUE)), 1)
d <- read.csv(f, encoding = "UTF-8", colClasses = "character", check.names = FALSE)
stopifnot(identical(names(d)[1:2], c("item", "coord")))
m <- regmatches(d$coord, regexec("^Point\\(([-0-9.eE]+) ([-0-9.eE]+)\\)$", d$coord))
d$item <- sub(".*/", "", d$item); d$lon <- as.numeric(vapply(m, `[`, "", 2)); d$lat <- as.numeric(vapply(m, `[`, "", 3)); d$file <- basename(f)
stopifnot(!anyNA(d$lon), !anyNA(d$lat))
dir.create(fd_staging("wikidata"), recursive = TRUE, showWarnings = FALSE)
nanoparquet::write_parquet(d, fd_staging("wikidata", "lighthouse.parquet"))
message(sprintf("wikidata: %d rows, %d items, from %s", nrow(d), length(unique(d$item)), basename(f)))
