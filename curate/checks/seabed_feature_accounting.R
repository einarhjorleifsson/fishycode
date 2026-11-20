# seabed_feature_accounting.R — the seabed feature table's bookkeeping: every ÍSOR point and volcanic area once, and every
# staged landform in one outcome (in the table, or left out as not asked for: the plough marks and the grounding line), each
# feature placed with a basis, an area's point inside it (plan 080 §5.2a, decision 336 ask p).
# Side: preprocessing (sea-chart names). Standalone, run by hand after reference/seabed/seabed_feature.R, outside the targets flow.
#
# Input:  staging/isor/seabed_name.parquet (its kinds point and area), staging/isor/landform.parquet,
#         curated/reference/seabed_feature.parquet
# Output: curated/check/seabed_feature_accounting.parquet - one row per check: the check, its verdict ("ok" or what failed), n
#
# Bookkeeping (decision 155): the script stops, after writing, unless every check holds.
# Run from the repo root: Rscript curate/checks/seabed_feature_accounting.R. Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages({ library(dplyr); library(sf) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)                     # standalone: not targets'
st <- read_curated_sf(fd_staging("isor", "seabed_name.parquet")); st <- st[st$kind %in% c("point", "area"), ]
sf <- read_curated_sf(fd_curated("reference", "seabed_feature.parquet"))
lf <- read_curated_sf(fd_staging("isor", "landform.parquet")); LEFT_OUT <- c("plough_mark", "grounding_line")

acc <- data.frame(check = character(), verdict = character(), n = integer())
ok <- function(what, cond, n = NA_integer_) { cond <- isTRUE(all(cond))
  acc[nrow(acc) + 1, ] <<- list(what, if (cond) "ok" else "FAILED", as.integer(n)) }

want <- c(paste0("isor:", st$kind, ":", st$OBJECTID_1), paste0("isor:landform:", lf$kind, ":", lf$isor_object)[!lf$kind %in% LEFT_OUT])
ok(sprintf("every staged ÍSOR point (%d) and volcanic area (%d) once, and every landform asked for (%d) once", sum(st$kind == "point"),
           sum(st$kind == "area"), sum(!lf$kind %in% LEFT_OUT)), setequal(sf$seabed_id, want) && !anyDuplicated(sf$seabed_id), nrow(sf))
ok(sprintf("every staged landform in one outcome: in the table %d, left out as not asked for %d (%s)", sum(!lf$kind %in% LEFT_OUT),
           sum(lf$kind %in% LEFT_OUT), paste(LEFT_OUT, collapse = ", ")),
   sum(grepl("^isor:landform:", sf$seabed_id)) + sum(lf$kind %in% LEFT_OUT) == nrow(lf), nrow(lf))
ok("kinds from their set", sf$kind %in% c("crater", "guyot", "point", "ridge", "seamount", "volcanic system", "trough", "moraine",
   "shelf break", "canal", "channel", "meltwater channel", "glacial streamline", "gravity streamline"), nrow(sf))
ok("every feature placed, with a basis", !is.na(sf$lon) & !is.na(sf$lat) & !is.na(sf$place_basis), nrow(sf))
a <- sf[st_geometry_type(sf) %in% c("POLYGON", "MULTIPOLYGON"), ]
p <- st_as_sf(st_drop_geometry(a), coords = c("lon", "lat"), crs = 4326)
inside <- vapply(seq_len(nrow(a)), function(i) st_intersects(st_geometry(p)[i], st_buffer(st_make_valid(st_geometry(a)[i]), 1e-4), sparse = FALSE)[1, 1], logical(1))
ok("an area's point inside it (a seamount's top, or a point on it)", inside, nrow(a))
ln <- sf[st_geometry_type(sf) %in% c("LINESTRING", "MULTILINESTRING"), ]
pl <- st_as_sf(st_drop_geometry(ln), coords = c("lon", "lat"), crs = 4326)
ok("a line's point on it (within 1 m)", as.numeric(st_distance(st_transform(pl, 3057), st_transform(ln, 3057), by_element = TRUE)) < 1, nrow(ln))
ok("every text valid UTF-8", all(validUTF8(na.omit(c(sf$label, sf$references, sf$comment)))), nrow(sf))

write_curated(acc, fd_curated("check", "seabed_feature_accounting.parquet"), script = "curate/checks/seabed_feature_accounting.R",
              inputs = c(fd_staging("isor", "seabed_name.parquet"), fd_staging("isor", "landform.parquet"), fd_curated("reference", "seabed_feature.parquet")))
print(knitr::kable(acc))
fails <- acc$check[acc$verdict != "ok"]
message(sprintf("seabed_feature_accounting: %d checks, %d failed", nrow(acc), length(fails)))
if (length(fails)) stop("seabed_feature_accounting: ", paste(fails, collapse = "; "))
