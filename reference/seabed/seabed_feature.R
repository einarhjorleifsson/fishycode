# seabed_feature.R — the seabed's features, not names: ÍSOR's craters and guyots (points) and its volcanic areas (ridges,
# seamounts, volcanic systems), each with ÍSOR's label as a placeholder and every attribute kept (plan 080 §5.2a: version 3's
# table begun in version 2, the maintainer, 2026-11-19: "in my view it is has the best mound/volcano position there is").
# Side: preprocessing (sea-chart names). Standalone, run by hand outside the targets flow, before reference/names/marine_name.R.
#
# Input:  staging/isor/seabed_name.parquet (sources/isor/seabed_name.R: ÍSOR's seabed map as delivered), its kinds `point`
#         (740) and `area` (1,307); staging/isor/landform.parquet (sources/isor/landform.R: ÍSOR's landforms, decision 336
#         ask p: all Iceland now), its troughs, moraines, shelf break, canals, channels, meltwater channels and glacial and
#         gravity streamlines (3,215; its plough marks and the grounding line left out, not asked for);
#         raw/external/bathymetry/Olex_50mBM_GEBCO_interp.tif (the depth model, a seamount's top)
# Output: curated/reference/seabed_feature.parquet - one row a feature: `seabed_id` ("isor:point:<OBJECTID_1>",
#         "isor:area:<OBJECTID_1>", "isor:landform:<kind>:<its number>", ÍSOR's own numbers), `source`, `layer`, `rid`
#         (seabed_name's staging, none for a landform), `kind` (crater, guyot, point, ridge, seamount, volcanic system; trough,
#         moraine, shelf break, canal, channel, meltwater channel, glacial streamline, gravity streamline), `label` (ÍSOR's name, a
#         placeholder until the maintainer names it; a landform, which ÍSOR leaves unnamed, its kind and number), `isor_name`
#         (ÍSOR's Name field as delivered), `lon`, `lat`
#         (a point's own; a seamount's top on the depth model; a ridge's, system's or landform area's point inside it; a
#         landform line's point midway along it) with `place_basis`,
#         `top_depth_m` (the depth there), ÍSOR's attributes; WKB `geometry`, the feature's own (point or area), made valid
#         where GEOS found it invalid (`geometry_repaired`)
#
# Bookkeeping: every staged point and area once. Run from the repo root: Rscript reference/seabed/seabed_feature.R
# Written by Claude (AI), 2026-11-19.

suppressPackageStartupMessages({ library(dplyr); library(sf); library(terra) })
sf_use_s2(FALSE)
for (f in c("R/paths.R", "R/write_curated.R")) source(f)   # standalone: not targets'
SCRIPT <- "reference/seabed/seabed_feature.R"
STAGED <- fd_staging("isor", "seabed_name.parquet"); DEM <- fd_raw("external", "bathymetry", "Olex_50mBM_GEBCO_interp.tif")

s <- read_curated_sf(STAGED)
s <- s[s$kind %in% c("point", "area"), ]
stopifnot(sum(s$kind == "point") == 740L, sum(s$kind == "area") == 1307L, !anyDuplicated(paste(s$kind, s$OBJECTID_1)))
kind_of <- function(m, k) case_when(m == "Crater" ~ "crater", m == "Guyot" ~ "guyot", m == "Ridge" ~ "ridge",
                                    grepl("^Seamount", m) ~ "seamount", m == "Volcanic system" ~ "volcanic system",
                                    k == "point" ~ "point", TRUE ~ "area")
s <- s |> mutate(seabed_id = paste0("isor:", kind, ":", OBJECTID_1), source = "isor", feature_kind = kind_of(Morpho_T, kind),
                 label = name)

# Where: a point's own; a seamount's top on the depth model; a ridge's or system's point inside it -----------------------
xy <- matrix(NA_real_, nrow(s), 2); basis <- rep(NA_character_, nrow(s)); top <- rep(NA_real_, nrow(s))
pt <- s$kind == "point"
xy[pt, ] <- st_coordinates(st_geometry(s)[pt])[, 1:2]; basis[pt] <- "ÍSOR's point"
r <- rast(DEM)
top[pt] <- extract(r, vect(st_transform(s[pt, ], crs(r))))[, 2]
sm <- which(s$feature_kind == "seamount")
v <- vect(st_transform(s[sm, ], crs(r)))
e <- extract(r, v, cells = TRUE, xy = TRUE)                       # every cell inside each seamount
names(e)[2] <- "z"
best <- e |> filter(!is.na(z)) |> group_by(ID) |> slice_max(z, n = 1, with_ties = FALSE) |> ungroup()
tp <- st_transform(st_as_sf(as.data.frame(best), coords = c("x", "y"), crs = crs(r)), 4326)
xy[sm[best$ID], ] <- st_coordinates(tp)[, 1:2]; top[sm[best$ID]] <- best$z
basis[sm[best$ID]] <- "the shallowest cell of the depth model inside it"
rest <- which(is.na(xy[, 1]))
ip <- suppressWarnings(st_point_on_surface(st_transform(s[rest, ], 3057))) |> st_transform(4326)
xy[rest, ] <- st_coordinates(ip)[, 1:2]; basis[rest] <- "a point inside it"
top[rest] <- extract(r, vect(st_transform(ip, crs(r))))[, 2]

# ÍSOR's landforms (decision 336 ask p), with the volcanic features ------------------------------------------------------
LANDFORM <- fd_staging("isor", "landform.parquet")
LF_KINDS <- c(trough = "trough", moraine = "moraine", shelf_break = "shelf break", canal = "canal", channel = "channel",
              meltwater_channel = "meltwater channel", glacial_streamline = "glacial streamline", gravity_streamline = "gravity streamline")
lf <- read_curated_sf(LANDFORM)
lf <- lf[lf$kind %in% names(LF_KINDS), ]
line <- st_geometry_type(lf) %in% c("LINESTRING", "MULTILINESTRING")
lp <- lapply(seq_len(nrow(lf)), function(i) { g <- st_transform(st_geometry(lf)[i], 3057)
  p <- if (line[i]) st_line_sample(st_cast(g, "LINESTRING")[which.max(st_length(st_cast(g, "LINESTRING")))], sample = 0.5)
       else suppressWarnings(st_point_on_surface(g))
  st_coordinates(st_transform(p, 4326))[1, 1:2] })
lxy <- do.call(rbind, lp)
lf_rows <- st_sf(tibble(kind = "landform", OBJECTID_1 = lf$isor_object, Morpho_T = NA_character_, name = NA_character_,
                        layer = lf$layer, rid = NA_integer_, references = NA_character_, Comment = lf$Comment,
                        seabed_id = paste0("isor:landform:", lf$kind, ":", lf$isor_object), source = "isor",
                        feature_kind = unname(LF_KINDS[lf$kind]), label = paste(unname(LF_KINDS[lf$kind]), lf$isor_object),
                        isor_name = lf$Name),
                 geometry = st_geometry(lf))
s$isor_name <- s$name
s <- dplyr::bind_rows(s, lf_rows)
xy <- rbind(xy, lxy); basis <- c(basis, ifelse(line, "a point midway along it", "a point inside it"))
top <- c(top, extract(r, vect(st_transform(st_as_sf(data.frame(x = lxy[, 1], y = lxy[, 2]), coords = c("x", "y"), crs = 4326), crs(r))))[, 2])
message(sprintf("landforms: %d of ÍSOR's (%s)", nrow(lf), paste(sprintf("%s %d", names(table(lf$kind)), table(lf$kind)), collapse = ", ")))

# a polygon GEOS calls invalid made valid in metres (ÍSOR's own stays in staging); DuckDB, which the maps read with, refuses
# the invalid ones (4 seamounts, 2026-11-19)
bad <- !st_is_valid(s)
if (any(bad)) st_geometry(s)[bad] <- st_geometry(st_transform(st_buffer(st_make_valid(st_transform(s[bad, ], 3057)), 0), 4326))
# and an area the maps' own path refuses though GEOS calls it valid (DuckDB's ST_ReducePrecision: rings touching
# themselves), tested one by one through ogis and repaired in metres: simplified by 1 m, a 1 m buffer out and back, then
# simplified by 10 m, else 50 m (the recipe of the trough study, 2026-11-16)
refused <- function(g) { line <- any(st_geometry_type(g) %in% c("LINESTRING", "MULTILINESTRING"))
  f <- if (line) ogis::og_line else ogis::og_polygon
  inherits(try(f(ogis::og_map(), st_sf(geometry = g), id = "t"), silent = TRUE), "try-error") }
if (requireNamespace("ogis", quietly = TRUE)) {
  ar <- which(st_geometry_type(s) %in% c("POLYGON", "MULTIPOLYGON", "LINESTRING", "MULTILINESTRING"))
  bad2 <- ar[vapply(ar, function(i) refused(st_geometry(s)[i]), logical(1))]
  for (i in bad2) for (tol in c(10, 50)) {
    g0 <- st_transform(st_geometry(s)[i], 3057) |> st_simplify(dTolerance = 1)
    # a line only simplified: the buffer out and back would leave a sliver polygon (no line was refused, 2026-11-19)
    if (!any(st_geometry_type(g0) %in% c("LINESTRING", "MULTILINESTRING"))) g0 <- st_buffer(st_buffer(g0, 1), -1)
    g <- st_simplify(g0, dTolerance = tol) |> st_transform(4326)
    if (!refused(g)) { st_geometry(s)[i] <- g; bad[i] <- TRUE; break }
  }
  still <- bad2[vapply(bad2, function(i) refused(st_geometry(s)[i]), logical(1))]
  if (length(still)) stop("areas the maps still refuse: ", paste(s$name[still], collapse = ", "))
  message(sprintf("areas the maps refused, repaired: %d", length(bad2)))
}
s$geometry_repaired <- bad
message(sprintf("geometries repaired in all: %d", sum(bad)))
out <- s |> mutate(lon = xy[, 1], lat = xy[, 2], place_basis = basis, top_depth_m = round(-top, 1)) |>
  select(seabed_id, source, layer, rid, kind = feature_kind, label, isor_name, lon, lat, place_basis, top_depth_m,
         height = Height, vei = VEI, activity = Activity, eruption = Eruption_F, district = V_district, chemistry = Chemical_c,
         age = VEI_age, references, isor_object = OBJECTID_1, comment = Comment, comment_area = Comment_, geometry_repaired)
stopifnot(!anyNA(out$lon), !anyNA(out$place_basis), !anyDuplicated(out$seabed_id))
write_curated(out, fd_curated("reference", "seabed_feature.parquet"), inputs = c(STAGED, LANDFORM, DEM), script = SCRIPT,
              stamps = c("fd.version" = "2"))
print(knitr::kable(st_drop_geometry(out) |> count(kind, place_basis), caption = "seabed_feature: ÍSOR's volcanic features"))
