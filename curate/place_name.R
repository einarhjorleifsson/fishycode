# place_name.R — the place-name gazetteer: one row per key, with where the name is used, its spread, its footprint, the
# seabed under it, its terrain word, its gear and the broader name it lies in.
# Side: preprocessing (place names). See plan 044.
#
# Input:  curated/place_name/{evidence, variant}.parquet (curate/place_name_evidence.R);
#         raw/aux/gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif
# Output: curated/place_name/place_name.parquet - one row per key, with its footprint as WKB `geometry` (WGS 84)
#
# - `name`: the commonest spelling of the key among those that keep their letters (a repaired name counts as its
#   repair). `n_<source>`: occurrences by source; Trackwell's picklist summary is not counted.
# - Position, from the occurrences with one (the summary and flagged positions left out): `lon`, `lat` the median, `r80_km` the distance from
#   it within which 80 % lie. `geometry`: the footprint, the 0.05 x 0.02 degree cells (about 2.3 x 2.2 km) holding the
#   densest 80 % of the positions, for keys with 5 or more; else empty. A late name switch (plan 043 §3.1) puts a few
#   positions far off; the median and the densest cells leave most of them out.
# - Seabed (GEBCO 2026, 15"), the median over the key's positions in 61-69.5 N, 32-8 W, NA outside: `depth_m`,
#   `slope_deg`, `bpi_m` (the seabed against its mean within about +-10 km: positive = higher than around).
# - `terrain`: the class of the terrain word in the name (bank, deep, edge, ridge, hill, horn, bay, other). Plan 043
#   §3.4: bank, ridge, horn and edge names match the seabed's shape, deeps and hills less.
# - `gear`, `gear_share`: the commonest gear of Trackwell's hauls under the name (through the logbook) and its share.
# - `parent_key`, `parent_basis`: the broader name the key lies in. `footprint`: a key with 20 or more positions whose
#   positions lie 70 % in the footprint of a key with 50 or more, whose r80 is over twice its own; the smallest such key.
#   `isor_group`: ÍSOR's heading over the entry, where it is a key. `n_children` counts the keys under each.

library(dplyr)

ev <- nanoparquet::read_parquet(fd_curated("place_name", "evidence.parquet"))
variant <- nanoparquet::read_parquet(fd_curated("place_name", "variant.parquet"))
GEBCO <- fd_raw("aux", "gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif")
km <- function(lon1, lat1, lon2, lat2) 6371 * acos(pmin(1, sin(lat1 * pi / 180) * sin(lat2 * pi / 180) +
                                                          cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos((lon2 - lon1) * pi / 180)))
name_key <- function(x) {                                   # as in place_name_evidence.R
  x <- tolower(x); x <- gsub("ð", "d", x); x <- gsub("þ", "th", x); x <- gsub("æ", "ae", x)
  x <- chartr("áéíóúýöäåøü", "aeiouyoaaou", x); x <- gsub("[^a-z0-9?]", "", x); gsub("([a-z])\\1+", "\\1", x)
}
terrain <- function(x) { x <- tolower(x)
  case_when(grepl("kant|brún|brun|brekk|hlíð|hlid", x) ~ "edge", grepl("hrygg", x) ~ "ridge",
            grepl("hóll|hól|hæð|klakk|boði|bunga", x) ~ "hill",
            grepl("dýpi|dypi|djúp|áll|ál$|ál |all$|all |dalur|dal$|gljúf|renna|pytt|hola", x) ~ "deep",
            grepl("grunn|bank|flak|fláki", x) ~ "bank", grepl("horn", x) ~ "horn",
            grepl("vík|fjörður|fjord|flói|vogur", x) ~ "bay", TRUE ~ "other") }

pos <- ev |> filter(position_basis != "none", !summary, !is.na(lon), !is.na(lat), is.na(position_flag))

# Name and counts -----------------------------------------------------------------------------------------------------
pref <- ev |> filter(!summary) |> mutate(spelling = coalesce(name_repaired, name)) |>
  filter(!grepl("?", spelling, fixed = TRUE)) |> count(key, spelling) |>
  arrange(key, desc(n), spelling) |> group_by(key) |> slice(1) |> ungroup() |> select(key, name = spelling)
lost_only <- setdiff(unique(ev$key), pref$key)
pref <- bind_rows(pref, ev |> filter(key %in% lost_only) |> count(key, name) |> arrange(key, desc(n)) |>
                    group_by(key) |> slice(1) |> ungroup() |> select(key, name))
cnt <- ev |> filter(!summary) |> count(key, source) |> tidyr::pivot_wider(names_from = source, values_from = n,
                                                                           names_prefix = "n_", values_fill = 0L)
base <- ev |> group_by(key) |>
  summarise(n_spelling = n_distinct(name), n_vessel = n_distinct(vessel, na.rm = TRUE),
            year_first = suppressWarnings(as.integer(min(format(time, "%Y"), na.rm = TRUE))),
            year_last = suppressWarnings(as.integer(max(format(time, "%Y"), na.rm = TRUE))),
            in_lmi = any(source == "lmi"), lmi_class = first(na.omit(lmi_class)),
            region = names(sort(table(region), decreasing = TRUE))[1] %||% NA_character_, .groups = "drop")

# Position, spread and footprint ------------------------------------------------------------------------------------
pos <- pos |> group_by(key) |> mutate(clon = median(lon), clat = median(lat), d = km(lon, lat, clon, clat)) |> ungroup()
where <- pos |> group_by(key) |> summarise(n_positioned = n(), lon = first(clon), lat = first(clat),
                                           r80_km = unname(quantile(d, 0.8)), .groups = "drop")
cells <- pos |> mutate(cx = floor(lon / 0.05), cy = floor(lat / 0.02)) |> count(key, cx, cy) |>
  group_by(key) |> arrange(desc(n), .by_group = TRUE) |> mutate(core = lag(cumsum(n) / sum(n), default = 0) < 0.8) |>
  ungroup() |> filter(core)
keys5 <- where$key[where$n_positioned >= 5]
sf::sf_use_s2(FALSE)
cell_poly <- function(cx, cy) sf::st_polygon(list(rbind(c(cx, cy), c(cx + 1, cy), c(cx + 1, cy + 1), c(cx, cy + 1), c(cx, cy)) *
                                                   rep(c(0.05, 0.02), each = 5)))
fc <- cells |> filter(key %in% keys5)
foot <- sf::st_sf(key = fc$key, geometry = sf::st_sfc(mapply(cell_poly, fc$cx, fc$cy, SIMPLIFY = FALSE), crs = 4326)) |>
  group_by(key) |> summarise(.groups = "drop")
sf::sf_use_s2(TRUE)

# Seabed ------------------------------------------------------------------------------------------------------------
r <- terra::crop(terra::rast(GEBCO), terra::ext(-32, -8, 61, 69.5))
m <- terra::as.matrix(r, wide = TRUE); storage.mode(m) <- "double"
box_mean <- function(m, hr, hc) {
  I <- matrix(0, nrow(m) + 1, ncol(m) + 1); I[-1, -1] <- t(apply(apply(m, 2, cumsum), 1, cumsum))
  r1 <- pmax(seq_len(nrow(m)) - hr, 1); r2 <- pmin(seq_len(nrow(m)) + hr, nrow(m))
  c1 <- pmax(seq_len(ncol(m)) - hc, 1); c2 <- pmin(seq_len(ncol(m)) + hc, ncol(m))
  (I[r2 + 1, c2 + 1] - I[r1, c2 + 1] - I[r2 + 1, c1] + I[r1, c1]) / outer(r2 - r1 + 1, c2 - c1 + 1)
}
bpi <- r; terra::values(bpi) <- as.vector(t(m - box_mean(m, 21, 50)))
slope <- terra::terrain(r, "slope")
inbox <- pos$lon > -32 & pos$lon < -8 & pos$lat > 61 & pos$lat < 69.5
xy <- cbind(pos$lon[inbox], pos$lat[inbox])
sea <- tibble(key = pos$key[inbox], elev = terra::extract(r, xy)[, 1], bpi = terra::extract(bpi, xy)[, 1],
              slope = terra::extract(slope, xy)[, 1]) |>
  group_by(key) |> summarise(depth_m = -median(elev, na.rm = TRUE), slope_deg = median(slope, na.rm = TRUE),
                             bpi_m = median(bpi, na.rm = TRUE), .groups = "drop")

# Gear ----------------------------------------------------------------------------------------------------------------
gear <- ev |> filter(!is.na(gear)) |> count(key, gear) |> group_by(key) |>
  mutate(gear_share = n / sum(n)) |> slice_max(n, n = 1, with_ties = FALSE) |> ungroup() |> select(key, gear, gear_share)

# Levels ------------------------------------------------------------------------------------------------------------
cand <- pos |> mutate(cx = floor(lon / 0.05), cy = floor(lat / 0.02)) |> semi_join(where |> filter(n_positioned >= 20), by = "key") |>
  inner_join(cells |> semi_join(where |> filter(n_positioned >= 50), by = "key") |> select(parent_key = key, cx, cy),
             by = c("cx", "cy"), relationship = "many-to-many") |>
  filter(parent_key != key) |> count(key, parent_key, name = "n_in") |>
  left_join(where |> select(key, n_positioned, r80_km), by = "key") |>
  left_join(where |> select(parent_key = key, r80_parent = r80_km), by = "parent_key") |>
  filter(n_in / n_positioned >= 0.7, r80_km < 0.5 * r80_parent) |>
  group_by(key) |> slice_min(r80_parent, n = 1, with_ties = FALSE) |> ungroup() |>
  transmute(key, parent_key, parent_basis = "footprint")
isor <- ev |> filter(!is.na(isor_group)) |> distinct(key, parent_key = name_key(isor_group)) |>
  filter(parent_key %in% ev$key, parent_key != key) |> mutate(parent_basis = "isor_group")
parent <- bind_rows(cand, isor |> anti_join(cand, by = "key")) |> distinct(key, .keep_all = TRUE)

# Together ----------------------------------------------------------------------------------------------------------
out <- pref |> left_join(base, by = "key") |> left_join(cnt, by = "key") |> left_join(where, by = "key") |>
  left_join(sea, by = "key") |> left_join(gear, by = "key") |> left_join(parent, by = "key") |>
  mutate(terrain = terrain(name), n_positioned = coalesce(n_positioned, 0L)) |>
  left_join(parent |> count(parent_key, name = "n_children"), by = c("key" = "parent_key")) |>
  mutate(n_children = coalesce(n_children, 0L))
geom <- sf::st_geometry(foot)[match(out$key, foot$key)]
geom[is.na(match(out$key, foot$key))] <- sf::st_polygon()
out <- sf::st_sf(out, geometry = geom)

# Check and write -----------------------------------------------------------------------------------------------------
stopifnot("one row per key" = !anyDuplicated(out$key), setequal(out$key, ev$key), !anyNA(out$name),
          "every key of variant.parquet" = all(variant$key %in% out$key))
d <- sf::st_drop_geometry(out)
print(knitr::kable(tibble(keys = nrow(d), positioned = sum(d$n_positioned > 0), with_footprint = sum(!sf::st_is_empty(out)),
  with_parent = sum(!is.na(d$parent_key)), by_footprint = sum(d$parent_basis %in% "footprint"),
  by_isor = sum(d$parent_basis %in% "isor_group"), parents = sum(d$n_children > 0), in_lmi = sum(d$in_lmi),
  with_depth = sum(!is.na(d$depth_m)), bottom_trawl = sum(d$gear %in% "OTB")), caption = "curated/place_name/place_name"))
print(knitr::kable(d |> filter(n_positioned >= 30, !is.na(bpi_m)) |> group_by(terrain) |>
  summarise(keys = n(), depth_m = round(median(depth_m)), higher_than_around = round(mean(bpi_m > 0), 2),
            slope_deg = round(median(slope_deg), 2)), caption = "keys with 30+ positions, by terrain word"))

write_curated(out, fd_curated("place_name", "place_name.parquet"),
              inputs = c(fd_curated("place_name", "evidence.parquet"), fd_curated("place_name", "variant.parquet"), GEBCO))
