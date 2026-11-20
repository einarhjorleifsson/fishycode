# place_name_region.R — the regions the place names go forward by (plan 080 §3, decision 336: "As proposed"), each a polygon
# drawn by a rule from the seabed's features, for the maintainer to redraw where he will.
# Side: preprocessing (sea-chart names). Standalone, run by hand outside the targets flow, before reference/names/marine_name.R.
#
# Input:  curated/reference/seabed_feature.parquet (reference/seabed/seabed_feature.R: ÍSOR's features)
#         overrides/place_name_region_open.csv (the regions opened, by the maintainer's word: region, opened, by, why)
# Output: curated/reference/place_name_region.parquet - one row a region drawn so far: `region` (its key), `name`, `basis`,
#         `open` (opened by the maintainer), WKB `geometry` (WGS 84)
#
# Drawn so far (Claude's rules, the maintainer's to redraw):
# - reykjaneshryggur: the hull of ÍSOR's features of its Reykjanes Ridge districts (the ridge and its flanks) and its eleven
#   volcanic systems from Reykjanes to Njörður, widened by 10 km, north of 63.95° N cut off (the Reykjanes peninsula's tip is
#   at 63.8° N).
# Run from the repo root: Rscript reference/names/place_name_region.R. Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)   # standalone: not targets'
SF <- fd_curated("reference", "seabed_feature.parquet"); OPEN <- "overrides/place_name_region_open.csv"
sfx <- read_curated_sf(SF)

RIDGE_SYSTEMS <- c("Reykjanes", "Eldey", "Geirfuglasker", "Langagrunn", "Eldeyjarboði", "Stóri-Brandur", "Grjóthryggur", "Gullhóll",
                   "Steinahóll", "Fagurhóll", "Njörður")
draw <- function(parts, buffer_m, north) {
  h <- st_convex_hull(st_union(st_transform(parts, 3057))) |> st_buffer(buffer_m) |> st_transform(4326)
  cut <- st_as_sfc(st_bbox(c(xmin = -60, ymin = 40, xmax = 0, ymax = north), crs = st_crs(4326)))
  st_intersection(h, cut)
}
rk <- sfx[grepl("^Reykjanes Ridge", coalesce(sfx$district, "")) | (sfx$kind == "volcanic system" & sfx$label %in% RIDGE_SYSTEMS), ]
stopifnot(sum(sfx$kind == "volcanic system" & sfx$label %in% RIDGE_SYSTEMS) == length(RIDGE_SYSTEMS))
regions <- st_sf(region = "reykjaneshryggur", name = "Reykjaneshryggur",
                 basis = "the hull of ÍSOR's Reykjanes Ridge features and its eleven ridge systems, widened by 10 km, cut at 63.95° N",
                 geometry = draw(rk, 10000, 63.95))
op <- if (file.exists(OPEN)) read.csv(OPEN, encoding = "UTF-8") else data.frame(region = character())
stopifnot(all(op$region %in% regions$region))
regions$open <- regions$region %in% op$region
write_curated(regions, fd_curated("reference", "place_name_region.parquet"), inputs = c(SF, OPEN),
              script = "reference/names/place_name_region.R")
a <- round(as.numeric(st_area(st_transform(regions, 3057))) / 1e6)
print(data.frame(region = regions$region, open = regions$open, km2 = a))
