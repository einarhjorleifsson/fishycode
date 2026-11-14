# port_feature.R — every feature of every port list, one row each, in one standard table (plan 075 §2.1).
# Side: preprocessing (ports). See plan 014.
#
# Input:  staging/ports/ports_iceland_faroe.gpkg       einar: the Iceland/Faroe harbours, reviewed (curate/corrections/ports_iceland.R)
#         raw/ports/havnepolygoner3.gpkg               jeppe: DTU Aqua's harbour polygons (WKSSFGEO 2021)
#         raw/ports/maksims/harbours.shp               maksims: circles with a size class and a UN/LOCODE
#         raw/ports/ports_emodnet.gpkg                 EMODnet's port locations (dump/ports/emodnet.R)
#         raw/ports/ports_osm.gpkg                     OSM's harbour=* features (dump/ports/osm.R)
#         raw/ports/ports_vmstools.gpkg                vmstools 0.77's harbours (dump/ports/vmstools.R)
#         raw/ports/ports_gfw_named_anchorages_v2_pipe_v3_202601.gpkg  GFW's named anchorages (dump/ports/gfw.R)
#         raw/ports/ports_giscoR.gpkg                  GISCO's ports (dump/ports/gisco.R)
#         raw/ports/marta/landings_portos_Einer.xlsx   marta: Portuguese landing sites
#         raw/ports/unlocode.parquet                   UN/LOCODE's port-function locations (dump/ports/unlocode.R)
# Output: staging/ports/port_feature.gpkg              one row per raw feature, and one per GFW dock area
#
# Nothing is dropped: an unnamed OSM feature, a GFW anchorage away from a dock, a UN/LOCODE row or a marta row with no
# position each keep a row, and port_layer.R places every row in one outcome. A geometry is kept as drawn; one that GEOS
# finds invalid is repaired with st_make_valid() and flagged `repaired` (curate/corrections/ports_osm_invalid_geometry.yml).
#
# GFW's dock anchorages are also bound into areas, rows of their own with source `gfw_dock` and `derived` TRUE: 500 m of
# true ground around each, unioned by label and country and split into connected pieces. A piece's key is the smallest
# s2id among its anchorages, so a GFW refresh keeps it while that anchorage exists; each dock anchorage names its piece in
# `part_of`. The countries and the coast are Natural Earth's 10 m (rnaturalearthhires): `iso_geo` is the nearest
# country, `on_land` and `d_coast_km` describe a feature and judge nothing (plan 075 §1: islands are missing at 10 m,
# and river and lake ports lie far inland).

library(sf)
library(dplyr)
library(stringr)
library(stringi)

sf_use_s2(FALSE)

norm <- function(x) str_remove_all(str_to_upper(stri_trans_general(x, "Latin-ASCII")), "[^A-Z0-9]")

std <- function(x, source, feature_key, name, iso_src = NA_character_, locode = NA_character_, kind = NA_character_) {
  x <- st_zm(x)
  tibble(source = source, feature_key = as.character(feature_key), name = as.character(name), iso_src = as.character(iso_src),
         locode = as.character(locode), kind = as.character(kind), geom = st_geometry(st_transform(x, 4326))) |>
    st_as_sf()
}
# a 1-based number within a key, so a list that repeats a key still gives each row its own
dedup <- function(k) ifelse(duplicated(k) | duplicated(k, fromLast = TRUE), paste0(k, "_", ave(seq_along(k), k, FUN = seq_along)), k)

unlocode <- nanoparquet::read_parquet(fd_raw("ports", "unlocode.parquet"))
iso3 <- countrycode::codelist |> filter(!is.na(iso3c), !is.na(iso2c)) |> select(iso3c, iso2c)

# Each list as it is ------------------------------------------------------------------------------------------------
L <- list()

e <- read_sf(fd_staging("ports", "ports_iceland_faroe.gpkg"))
L$einar <- std(e, "einar", e$pid_bootstrap, e$port, substr(e$pid_bootstrap, 1, 2), kind = "reviewed")
L$einar$hid <- as.integer(e$hid)

j <- read_sf(fd_raw("ports", "havnepolygoner3.gpkg"))
L$jeppe <- std(j, "jeppe", dedup(as.character(j$Kode)), j$Landingsplads, kind = paste0("landing place ", j$Kode))

m <- read_sf(fd_raw("ports", "maksims", "harbours.shp"))
L$maksims <- std(m, "maksims", m$locode, m$harbour, substr(m$locode, 1, 2), substr(m$locode, 3, 5),
                 kind = paste0("circle of ", m$radius, " m, ", m$size))

em <- read_sf(fd_raw("ports", "ports_emodnet.gpkg"))
L$emodnet <- std(em, "emodnet", em$gml_id, coalesce(em$portname, em$port), em$country,
                 ifelse(grepl("^[A-Z]{2}[A-Z0-9]{3}$", em$port_id), substr(em$port_id, 3, 5), NA),
                 kind = paste0("from ", em$source))

o <- read_sf(fd_raw("ports", "ports_osm.gpkg"))
L$osm <- std(o, "osm", paste0(as.character(st_geometry_type(o)), "/", o$osm_id), o$name, kind = o$harbour)

v <- read_sf(fd_raw("ports", "ports_vmstools.gpkg"))
L$vmstools <- std(v, "vmstools", seq_len(nrow(v)), v$harbour, kind = "point")

g <- read_sf(fd_raw("ports", "ports_gfw_named_anchorages_v2_pipe_v3_202601.gpkg"))
L$gfw <- std(g, "gfw", g$s2id, g$label, iso3$iso2c[match(g$iso3, iso3$iso3c)],
             kind = paste0(ifelse(is.na(g$dock), "dock unknown", ifelse(g$dock, "dock", "not a dock")), "; ", g$label_source))

gi <- read_sf(fd_raw("ports", "ports_giscoR.gpkg"))
ok <- grepl("^[A-Z]{2}[A-Z0-9]{3}$", gi$PORT_ID)
# PORT_ID is a UN/LOCODE and the file carries no name: the name is UN/LOCODE's for the code
L$gisco <- std(gi, "gisco", gi$PORT_ID, unlocode$name[match(gi$PORT_ID, paste0(unlocode$country, unlocode$location))],
               ifelse(ok, substr(gi$PORT_ID, 1, 2), gi$CNTR_ISO2), ifelse(ok, substr(gi$PORT_ID, 3, 5), NA), kind = "point")

mt <- readxl::read_excel(fd_raw("ports", "marta", "landings_portos_Einer.xlsx"))
mt_geom <- st_sfc(lapply(seq_len(nrow(mt)), \(i) if (is.na(mt$longdec[i]) || is.na(mt$latdec[i])) st_point() else
  st_point(c(mt$longdec[i], mt$latdec[i]))), crs = 4326)
L$marta <- std(st_sf(geom = mt_geom), "marta", seq_len(nrow(mt)), mt$nome.pt, "PT", kind = paste0("landing site, ", mt$zona))

u_geom <- st_sfc(lapply(seq_len(nrow(unlocode)), \(i) if (is.na(unlocode$lon[i])) st_point() else
  st_point(c(unlocode$lon[i], unlocode$lat[i]))), crs = 4326)
L$unlocode <- std(st_sf(geom = u_geom), "unlocode", dedup(paste0(unlocode$country, unlocode$location)), unlocode$name,
                  unlocode$country, unlocode$location, kind = paste0("status ", unlocode$status, "; ", unlocode$function_desc))

n_raw <- vapply(L, nrow, 1L)
feat <- bind_rows(lapply(L, \(x) { if (!"hid" %in% names(x)) x$hid <- NA_integer_; x }))
feat$derived <- FALSE
feat$part_of <- NA_character_

# GFW's dock anchorages as areas --------------------------------------------------------------------------------------
# Ground metres, not degrees: EPSG:3857's scale is sec(latitude), so the distance is divided by cos(latitude)
buffer_m <- function(x, dist) {
  lat <- st_coordinates(x)[, 2]
  x |> st_transform(3857) |> st_buffer(dist / cos(lat * pi / 180), nQuadSegs = 8) |> st_transform(4326)
}
dock <- which(feat$source == "gfw" & startsWith(feat$kind, "dock;"))
gd <- feat[dock, c("feature_key", "name", "iso_src")]
gd$grp <- paste(gd$name, coalesce(gd$iso_src, "NA"), sep = "\r")
pieces <- buffer_m(gd, 500) |>
  group_by(grp) |> summarise(geom = st_union(geom), .groups = "drop") |>
  st_make_valid() |> st_cast("MULTIPOLYGON") |> st_cast("POLYGON", warn = FALSE)
# each anchorage to the piece of its own label that holds it
hit <- st_intersects(gd, pieces)
own <- vapply(seq_along(hit), \(i) { h <- hit[[i]]; h <- h[pieces$grp[h] == gd$grp[i]]; if (length(h)) h[1] else NA_integer_ }, 1L)
stopifnot("every dock anchorage lies in a piece of its own label" = !anyNA(own))
key <- tapply(gd$feature_key, own, \(s) sort(s)[1])
pieces$feature_key <- unname(key[as.character(seq_len(nrow(pieces)))])
stopifnot(!anyNA(pieces$feature_key), !anyDuplicated(pieces$feature_key))
feat$part_of[dock] <- pieces$feature_key[own]
n_anch <- tabulate(own, nrow(pieces))
gfw_dock <- st_sf(source = "gfw_dock", feature_key = pieces$feature_key, name = sub("\r.*", "", pieces$grp),
                  iso_src = na_if(sub(".*\r", "", pieces$grp), "NA"), locode = NA_character_,
                  kind = paste0(n_anch, " dock anchorage", ifelse(n_anch > 1, "s", "")), hid = NA_integer_,
                  derived = TRUE, part_of = NA_character_, geom = st_geometry(pieces))
feat <- bind_rows(feat, gfw_dock)

# Standard columns ----------------------------------------------------------------------------------------------------
feat$name <- str_squish(feat$name)
feat$name_key <- norm(feat$name)
feat$has_pos <- !st_is_empty(feat)
feat$gtype <- ifelse(!feat$has_pos, NA, c("point", "line", "area")[st_dimension(feat) + 1])
bad <- which(feat$has_pos & !st_is_valid(feat))
feat$repaired <- FALSE
feat$repaired[bad] <- TRUE
st_geometry(feat)[bad] <- st_make_valid(st_geometry(feat)[bad])
stopifnot(all(st_is_valid(feat[feat$has_pos, ])))
pt <- matrix(NA_real_, nrow(feat), 2)
pt[feat$has_pos, ] <- suppressWarnings(st_coordinates(st_point_on_surface(st_geometry(feat)[feat$has_pos])))[, 1:2]
feat$lon <- pt[, 1]
feat$lat <- pt[, 2]
feat$area_m2 <- NA_real_
ar <- which(feat$gtype %in% "area")
feat$area_m2[ar] <- as.numeric(st_area(st_transform(st_geometry(feat)[ar], "+proj=cea")))

# Country and coast: Natural Earth 10 m; GFW's anchorages and UN/LOCODE keep their own country only
countries <- rnaturalearth::ne_countries(scale = "large", returnclass = "sf") |> select(iso_a2, name) |> st_make_valid()
countries$iso_a2[countries$name == "Norway"] <- "NO"
countries$iso_a2[countries$name == "France"] <- "FR"
need <- which(feat$has_pos & !feat$source %in% c("gfw", "unlocode"))
rp <- st_as_sf(st_drop_geometry(feat)[need, c("lon", "lat")], coords = c("lon", "lat"), crs = 4326)
feat$iso_geo <- feat$iso_src
feat$iso_geo[need] <- countries$iso_a2[st_nearest_feature(rp, countries)]
feat$on_land <- NA
feat$on_land[need] <- lengths(st_intersects(rp, countries)) > 0
coast <- st_transform(rnaturalearthhires::coastline10, "+proj=eqearth")
rp3 <- st_transform(rp, "+proj=eqearth")
feat$d_coast_km <- NA_real_
feat$d_coast_km[need] <- round(as.numeric(st_distance(rp3, coast[st_nearest_feature(rp3, coast), ], by_element = TRUE)) / 1000, 2)

feat <- feat |>
  select(source, feature_key, derived, part_of, name, name_key, iso_src, iso_geo, locode, kind, hid, has_pos, gtype, repaired,
         lon, lat, area_m2, on_land, d_coast_km, geom) |>
  arrange(source, feature_key)

# Every raw row, and no key twice -------------------------------------------------------------------------------------
n_out <- table(feat$source[!feat$derived])
stopifnot("every raw row has a feature" = all(n_out[names(n_raw)] == n_raw),
          "one row per list and key" = !anyDuplicated(paste(feat$source, feat$feature_key)))
cat("features\n"); print(table(feat$source, feat$gtype, useNA = "ifany"))
cat("repaired", length(bad), "\n")

# staging is not stamped (write_curated() writes curated/ only); the stamped table is port_layer.R's port_feature.parquet
write_sf(feat, fd_staging("ports", "port_feature.gpkg"), delete_dsn = TRUE)
