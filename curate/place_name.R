# place_name.R — the place-name gazetteer: one row per key, with where the name is used, its footprint, the seabed under
# it, its terrain word, its gear, the broader name it lies in, the zoom from which to show it and how far its sources
# agree; and the candidate synonyms.
# Side: preprocessing (place names). See plan 044 (§1 version 1, §4 version 2).
#
# Input:  curated/place_name/{evidence, variant}.parquet (curate/place_name_evidence.R); staging/ornefni/lmi_name.parquet
#         (LMÍ's display scale and alternative names); raw/aux/gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif;
#         raw/external/ornefni/lmi/iceland.gpkg (LMÍ's coast, to cut the land out of a footprint)
# Output: curated/place_name/place_name.parquet - one row per key, with its footprint as WKB `geometry` (WGS 84)
#         curated/place_name/place.parquet      - one row per place of a key (a name can mean several places)
#         curated/place_name/synonym.parquet    - one row per candidate pair of keys, with its evidence; nothing merged
#
# - `name`: the commonest spelling of the key among those that keep their letters. `class`: the commonest class of its
#   occurrences (name, composite, description). `n_<source>`: occurrences by source (Trackwell's summary not counted).
# - Position. An occurrence's precision is 1 (a point, a tow's midpoint, a line, a polygon, a drawn area), 2 (a square's
#   centre: Oracle's, channel's and the recaptures' unread positions) or 3 (an area's centre: uv's polygons over
#   2,500 km2); a key takes its positions of its best precision (`precision`), the summary and flagged
#   positions left out. Places: the positions are cut into clusters (single linkage, 30 km; 40 km for squares); a
#   place holds 10 % of them and two or more (any cluster, for a key of three positions or fewer); `n_places`. The main
#   place has the most, then the most support (occurrences of any precision and source within 30 km); a key with no such cluster (its positions all strays) takes its largest. `lon`, `lat`: the main place's median; `r80_km`: the distance from it within which 80 % of its
#   positions lie. Two bays called Hlöðuvík are two places, not one point between them.
#   `label_lon`, `label_lat`: where to write the name on a map, the median, or for a square-placed name a point on the
#   sea part of its squares (a square's centre may be ashore).
# - `geometry`, the footprint: for precision 1 and 5 positions or more, the 0.05 x 0.02 degree cells holding the
#   densest 80 % of them (a late name switch, plan 043 §3.1, puts a few far off); for precision 2 and 3 squares or
#   more (MFRI's coarse grounds), the union of the squares; else empty. The land is cut out of every footprint.
# - Seabed (GEBCO 2026, 15"), the median over the positions at sea in 61-69.5 N, 32-8 W (a square's centre ashore
#   says nothing of the seabed): `depth_m`, `slope_deg`, `bpi_m`.
# - `terrain`: the class of the terrain word: hazard (festa, a wreck: "flakið", "skipið"; plan 044 §4, the maintainer:
#   these show in the trawl effort), bank, deep, edge, ridge, hill, horn, bay, other. A "-flak" compound is a bank
#   (Digranesflak), "flakið" a wreck.
# - `gear`, `gear_share`: the commonest gear of Trackwell's hauls under the name, through the logbook.
# - `parent_key`, `parent_basis`: the broader name the key lies in, first by `footprint` (20 or more positions, 70 %
#   in the footprint of a key with 50 or more whose r80 is over twice its own; the smallest such key), else `lexical`
#   (the key holds a used key's, "tunganreykjafjal" holds "reykjafjardaral", lies within twice its r80 of it, and is the
#   narrower; not a generic terrain word such as "kantur", nor the same name with its article), else
#   ÍSOR's heading (`isor_group`). A cycle is broken at its weakest link (footprint over lexical over ÍSOR).
#   `n_children` counts the keys under each.
# - `min_zoom`, `level`: the zoom from which the name is shown. LMÍ's display scale where the name is LMÍ's (2,000 → 5
#   ... 10 → 10); else from the footprint's size (`size_km`, the side of a square of its area: a bounding box or r80
#   would let one stray position make a name broad), the zoom at which it spans about 60 pixels:
#   floor(log2(3969 / size in km)), within 4-12; else 11, a fine name shown late. A child shows no earlier than its
#   parent. `level` 1-4 bins it (≤ 5, 6-7, 8-9, ≥ 10).
# - Cross-check (plan 044 §4.6): `families` (the independent sources with a position: trackwell, plotter, lmi, oracle,
#   sjokort, fiskmerki, qgis, skjalfandi, channel, uv) and `n_text` (articles, ÍSOR). Two families agree when their medians lie
#   within the larger of 5 km and the key's r80, plus the mean of the two families' own r80, plus half a square for a
#   square-placed family (15 km) or an area's (40 km): a broad area's sources sit apart inside it. `outcome`: several
#   places (two places or more), confirmed (two or more families, all agreeing), disagree (two or more, some not: a
#   wrong position), single, or text (no position).
# - synonym.parquet: `relation` `spelling` (two positioned keys within an edit distance of 2, 1 for keys under 5
#   letters or a square-placed key, 3 for keys of 10 or more both with 5 positions or more, whose medians lie within
#   10 km, 20 km if square-placed;
#   not two names that differ in their digits or in a direction (a word, or a compass abbreviation: S, SV, NA ...); a key holding the other is left to the lexical
#   parent), `article` (the same with a definite article's ending: tunga, tungan), `lmi_alt` (LMÍ's
#   alternative name), `article_synonym` (an article's synonyms), `dictionary_reading` (the ornefni dictionary's reading,
#   often a broader name). `n_synonym` in place_name counts a key's candidates.

library(dplyr)

ev <- nanoparquet::read_parquet(fd_curated("place_name", "evidence.parquet"))
variant <- nanoparquet::read_parquet(fd_curated("place_name", "variant.parquet"))
lmi <- nanoparquet::read_parquet(fd_path("staging", "ornefni", "lmi_name.parquet"))
GEBCO <- fd_raw("aux", "gebco_2026_n89.0_s35.0_w-45.0_e69.0_geotiff.tif")
LAND <- fd_raw("external", "ornefni", "lmi", "iceland.gpkg")
km <- function(lon1, lat1, lon2, lat2) 6371 * acos(pmin(1, sin(lat1 * pi / 180) * sin(lat2 * pi / 180) +
                                                          cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos((lon2 - lon1) * pi / 180)))
name_key <- function(x) {                                   # as in place_name_evidence.R
  x <- tolower(x); x <- gsub("ð", "d", x); x <- gsub("þ", "th", x); x <- gsub("æ", "ae", x)
  x <- chartr("áéíóúýöäåøü", "aeiouyoaaou", x); x <- gsub("[^a-z0-9?]", "", x); gsub("([a-z])\\1+", "\\1", x)
}
terrain <- function(x) { x <- tolower(x)
  case_when(grepl("festa|festan|festu|flakið|flakinu|skipið|skipsflak|kirkjugarð|togarinn|bátsflak", x) ~ "hazard",
            grepl("kant|brún|brun|brekk|hlíð|hlid", x) ~ "edge", grepl("hrygg", x) ~ "ridge",
            grepl("hóll|hól|hæð|klakk|boði|bunga", x) ~ "hill",
            grepl("dýpi|dypi|djúp|áll|ál$|ál |all$|all |dalur|dal$|gljúf|renna|pytt|hola", x) ~ "deep",
            grepl("grunn|bank|flak|fláki", x) ~ "bank", grepl("horn", x) ~ "horn",
            grepl("vík|fjörður|fjord|flói|vogur", x) ~ "bay", TRUE ~ "other") }
rank_of <- function(kind) case_when(kind %in% c("point", "track", "line", "polygon", "drawn") ~ 1L, kind == "square" ~ 2L,
                                    kind == "area" ~ 3L, TRUE ~ NA_integer_)
mode1 <- function(x) { x <- x[!is.na(x)]; if (length(x)) names(sort(table(x), decreasing = TRUE))[1] else NA_character_ }

placed <- ev |> filter(position_basis != "none", !summary, !is.na(lon), !is.na(lat), is.na(position_flag)) |>
  mutate(rank = rank_of(position_kind))
pos <- placed |> group_by(key) |> filter(rank == min(rank)) |> ungroup()

# Name, class and counts --------------------------------------------------------------------------------------------
pref <- ev |> filter(!summary) |> mutate(spelling = coalesce(name_repaired, name)) |>
  filter(!grepl("?", spelling, fixed = TRUE)) |> count(key, spelling) |>
  arrange(key, desc(n), spelling) |> group_by(key) |> slice(1) |> ungroup() |> select(key, name = spelling)
lost_only <- setdiff(unique(ev$key), pref$key)
pref <- bind_rows(pref, ev |> filter(key %in% lost_only) |> count(key, name) |> arrange(key, desc(n)) |>
                    group_by(key) |> slice(1) |> ungroup() |> select(key, name))
cnt <- ev |> filter(!summary) |> count(key, source) |>
  tidyr::pivot_wider(names_from = source, values_from = n, names_prefix = "n_", values_fill = 0L)
base <- ev |> group_by(key) |>
  summarise(class = mode1(class), n_spelling = n_distinct(name), n_vessel = n_distinct(vessel, na.rm = TRUE),
            year_first = suppressWarnings(as.integer(min(format(time, "%Y"), na.rm = TRUE))),
            year_last = suppressWarnings(as.integer(max(format(time, "%Y"), na.rm = TRUE))),
            in_lmi = any(source == "lmi"), lmi_class = first(na.omit(lmi_class)), region = mode1(region),
            .groups = "drop")

# Places: one name can mean several places (two bays are called Hlöðuvík) -------------------------------------------
# A key's positions are cut into clusters by single linkage at 30 km (40 km for squares). A place is a cluster with 10 %
# of the positions and two or more, or any cluster of a key with three positions or fewer; the rest are strays (a late
# name switch). The main place is the one with the most positions; the key's position and spread are its.
set.seed(44)
cluster_of <- function(lon, lat, h) {
  n <- length(lon)
  if (n == 1) return(1L)
  i <- if (n > 2500) sample.int(n, 2500) else seq_len(n)
  d <- outer(i, i, function(a, b) km(lon[a], lat[a], lon[b], lat[b]))
  cl <- cutree(stats::hclust(stats::as.dist(d), "single"), h = h)
  if (n <= 2500) return(as.integer(cl))
  cx <- tapply(lon[i], cl, median); cy <- tapply(lat[i], cl, median)
  as.integer(names(cx))[apply(outer(seq_len(n), seq_along(cx), function(a, b) km(lon[a], lat[a], cx[b], cy[b])), 1, which.min)]
}
pos <- pos |> group_by(key) |> mutate(cluster = cluster_of(lon, lat, ifelse(first(rank) == 1, 30, 40))) |> ungroup()
place <- pos |> group_by(key, cluster) |>
  summarise(n = n(), plon = median(lon), plat = median(lat), families = paste(sort(unique(source)), collapse = ", "),
            .groups = "drop_last") |>
  mutate(share = n / sum(n), is_place = (share >= 0.1 & n >= 2) | sum(n) <= 3) |>
  mutate(is_place = is_place | (!any(is_place) & row_number() == which.max(n))) |>       # else its largest cluster
  filter(is_place) |> ungroup()
# A tie is broken by support: every positioned occurrence of the key, of any precision and source, within 30 km
support <- place |> select(key, cluster, plon, plat) |>
  inner_join(placed |> select(key, lon, lat), by = "key", relationship = "many-to-many") |>
  filter(km(plon, plat, lon, lat) <= 30) |> count(key, cluster, name = "support")
place <- place |> left_join(support, by = c("key", "cluster")) |> mutate(support = coalesce(support, 0L)) |>
  group_by(key) |> arrange(desc(n), desc(support), .by_group = TRUE) |> mutate(place = row_number(), main = place == 1) |> ungroup()
main_of <- place |> filter(main) |> select(key, cluster)
pos <- pos |> left_join(main_of |> mutate(in_main = TRUE), by = c("key", "cluster")) |> mutate(in_main = coalesce(in_main, FALSE))

# Position, spread and footprint ------------------------------------------------------------------------------------
mp <- pos |> filter(in_main) |> group_by(key) |> mutate(clon = median(lon), clat = median(lat), d = km(lon, lat, clon, clat)) |>
  summarise(lon = first(clon), lat = first(clat), r80_km = unname(quantile(d, 0.8)), .groups = "drop")
where <- pos |> group_by(key) |> summarise(precision = first(rank), n_positioned = n(), .groups = "drop") |>
  left_join(mp, by = "key") |> left_join(place |> count(key, name = "n_places"), by = "key")
sf::sf_use_s2(FALSE)
box <- function(x0, y0, x1, y1) sf::st_polygon(list(rbind(c(x0, y0), c(x1, y0), c(x1, y1), c(x0, y1), c(x0, y0))))
cells <- pos |> filter(rank == 1) |> mutate(cx = floor(lon / 0.05), cy = floor(lat / 0.02)) |> count(key, cx, cy) |>
  group_by(key) |> arrange(desc(n), .by_group = TRUE) |> mutate(core = lag(cumsum(n) / sum(n), default = 0) < 0.8) |>
  ungroup() |> filter(core)
fc <- cells |> semi_join(where |> filter(precision == 1, n_positioned >= 5), by = "key")
fs <- pos |> filter(rank == 2, !is.na(square_w)) |> semi_join(where |> filter(precision == 2, n_positioned >= 3), by = "key")
parts <- bind_rows(
  tibble(key = fc$key, x0 = fc$cx * 0.05, y0 = fc$cy * 0.02, x1 = (fc$cx + 1) * 0.05, y1 = (fc$cy + 1) * 0.02),
  tibble(key = fs$key, x0 = fs$lon - fs$square_w / 2, y0 = fs$lat - fs$square_h / 2, x1 = fs$lon + fs$square_w / 2,
         y1 = fs$lat + fs$square_h / 2))
foot <- sf::st_sf(key = parts$key, geometry = sf::st_sfc(mapply(box, parts$x0, parts$y0, parts$x1, parts$y1, SIMPLIFY = FALSE),
                                                         crs = 4326)) |>
  group_by(key) |> summarise(.groups = "drop")
# A footprint is sea: the land (LMÍ's coast, mainland, islands and skerries) is cut out of it, so a coarse ground drawn
# from squares does not cover the shore
land <- sf::st_geometry(sf::st_make_valid(sf::st_read(LAND, quiet = TRUE)))
land <- sf::st_union(land[sf::st_geometry_type(land) %in% c("POLYGON", "MULTIPOLYGON")])
foot <- sf::st_make_valid(suppressWarnings(sf::st_difference(foot, land)))
foot <- foot[!sf::st_is_empty(foot), ]
foot$size_km <- sqrt(as.numeric(sf::st_area(sf::st_transform(foot, 3057))) / 1e6)   # the side of a square of its area, in ISN93
# Where to write a square-placed name on a map: a point on the sea part of its squares (a square's centre may be ashore)
sq <- pos |> filter(rank == 2, !is.na(square_w))
sq_poly <- sf::st_sf(key = sq$key, geometry = sf::st_sfc(mapply(box, sq$lon - sq$square_w / 2, sq$lat - sq$square_h / 2,
                                                                sq$lon + sq$square_w / 2, sq$lat + sq$square_h / 2, SIMPLIFY = FALSE),
                                                         crs = 4326)) |>
  group_by(key) |> summarise(.groups = "drop")
sea_part <- sf::st_make_valid(suppressWarnings(sf::st_difference(sq_poly, land)))
sea_part <- sea_part[!sf::st_is_empty(sea_part), ]
lp <- sf::st_coordinates(suppressWarnings(sf::st_point_on_surface(sea_part)))
label_at <- tibble(key = sea_part$key, label_lon = lp[, 1], label_lat = lp[, 2])
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
  filter(elev < 0) |>                                        # a square's centre ashore says nothing of the seabed
  group_by(key) |> summarise(depth_m = -median(elev, na.rm = TRUE), slope_deg = median(slope, na.rm = TRUE),
                             bpi_m = median(bpi, na.rm = TRUE), .groups = "drop")

# Gear ----------------------------------------------------------------------------------------------------------------
gear <- ev |> filter(!is.na(gear)) |> count(key, gear) |> group_by(key) |>
  mutate(gear_share = n / sum(n)) |> slice_max(n, n = 1, with_ties = FALSE) |> ungroup() |> select(key, gear, gear_share)

# Levels: the footprint parent, the lexical parent, ÍSOR's heading --------------------------------------------------
cand <- pos |> filter(rank == 1) |> mutate(cx = floor(lon / 0.05), cy = floor(lat / 0.02)) |>
  semi_join(where |> filter(n_positioned >= 20), by = "key") |>
  inner_join(cells |> semi_join(where |> filter(n_positioned >= 50), by = "key") |> select(parent_key = key, cx, cy),
             by = c("cx", "cy"), relationship = "many-to-many") |>
  filter(parent_key != key) |> count(key, parent_key, name = "n_in") |>
  left_join(where |> select(key, n_positioned, r80_km), by = "key") |>
  left_join(where |> select(parent_key = key, r80_parent = r80_km), by = "parent_key") |>
  filter(n_in / n_positioned >= 0.7, r80_km < 0.5 * r80_parent) |>
  group_by(key) |> slice_min(r80_parent, n = 1, with_ties = FALSE) |> ungroup() |>
  transmute(key, parent_key, parent_basis = "footprint")
# Generic terrain words are not parents ("Norðurkantur" does not lie in "Kantur"), nor is a name without its article
GENERIC <- c("kantur", "kanturin", "horn", "hornid", "grun", "grunin", "hrygur", "hrygurin", "dypi", "dypid", "djup",
             "djupid", "al", "alin", "hol", "holin", "banki", "bankin", "brun", "brunin", "hraun", "hraunid", "flak", "flakid",
             "bletur", "bleturin", "slod", "slodin", "holf", "holfid", "svaedi", "svaedid", "flaki", "flakin", "kverk", "kverkin")
ARTICLE <- c("n", "in", "inn", "id", "d", "num", "nar", "nir", "nn", "s", "ns", "r", "ur")   # "d": Háaleiti, Háaleitið
is_article <- function(a, b) { l <- if (nchar(a) < nchar(b)) c(a, b) else c(b, a)
                               startsWith(l[2], l[1]) && substring(l[2], nchar(l[1]) + 1) %in% ARTICLE }
used <- where |> filter(n_positioned >= 50, nchar(key) >= 5, !key %in% GENERIC)
lex <- where |> select(key, lon, lat) |>
  mutate(parent_key = vapply(key, function(k) { h <- used$key[used$key != k & vapply(used$key, grepl, TRUE, x = k, fixed = TRUE)]
                                                 if (length(h)) h[which.max(nchar(h))] else NA_character_ }, "")) |>
  filter(!is.na(parent_key)) |>
  left_join(used |> select(parent_key = key, plon = lon, plat = lat, pr80 = r80_km), by = "parent_key") |>
  left_join(where |> select(key, r80_km), by = "key") |>
  filter(km(lon, lat, plon, plat) <= 2 * pmax(pr80, 5), pr80 > coalesce(r80_km, 0),
         !mapply(is_article, key, parent_key)) |>
  transmute(key, parent_key, parent_basis = "lexical")
isor <- ev |> filter(!is.na(isor_group)) |> distinct(key, parent_key = name_key(isor_group)) |>
  filter(parent_key %in% ev$key, parent_key != key) |> mutate(parent_basis = "isor_group")
parent <- bind_rows(cand, lex, isor) |> distinct(key, .keep_all = TRUE)
# A cycle (Grunnkantur lies in Grunnkantur-Kópanesgr's footprint, and the composite holds its name) is broken at its
# weakest link: a footprint relation outranks a lexical one, and both ÍSOR's heading
PRIORITY <- c(footprint = 1, lexical = 2, isor_group = 3)
repeat {
  up <- setNames(parent$parent_key, parent$key)
  cyc <- vapply(parent$key, function(k) { x <- k; for (i in 1:50) { x <- unname(up[x]); if (is.na(x)) return(FALSE)
                                                                     if (x == k) return(TRUE) }; FALSE }, TRUE)
  if (!any(cyc)) break
  drop <- parent[cyc, ] |> mutate(p = PRIORITY[parent_basis]) |> slice_max(p, n = 1, with_ties = FALSE)
  parent <- parent |> filter(!(key == drop$key & parent_key == drop$parent_key))
}

# The zoom from which to show a name --------------------------------------------------------------------------------
SCALE_ZOOM <- c(`2000` = 5, `1000` = 6, `500` = 7, `250` = 7, `100` = 8, `50` = 9, `25` = 9, `10` = 10)
lmi_zoom <- ev |> filter(source == "lmi") |>
  left_join(lmi |> transmute(source_key = as.character(row), scale), by = "source_key") |>
  group_by(key) |> summarise(z_lmi = min(SCALE_ZOOM[as.character(scale)], na.rm = TRUE), .groups = "drop") |>
  mutate(z_lmi = ifelse(is.finite(z_lmi), z_lmi, NA))
zoom <- where |> left_join(sf::st_drop_geometry(foot) |> select(key, size_km), by = "key") |>
  mutate(z_ext = ifelse(is.na(size_km), NA, pmin(12, pmax(4, floor(log2(3969 / pmax(size_km, 0.5))))))) |>
  left_join(lmi_zoom, by = "key") |>
  transmute(key, size_km, min_zoom = coalesce(z_lmi, z_ext, 11))
pz <- setNames(zoom$min_zoom, zoom$key)
repeat {                                                     # a child no earlier than its parent, down the chain
  k <- parent$key[parent$key %in% names(pz) & parent$parent_key %in% names(pz)]
  p <- parent$parent_key[match(k, parent$key)]
  new <- pmax(pz[k], pz[p] + 1)
  if (all(new == pz[k])) break
  pz[k] <- new
}
zoom$min_zoom <- as.integer(pz[zoom$key])
zoom$level <- as.integer(cut(zoom$min_zoom, c(-Inf, 5, 7, 9, Inf), labels = 1:4))

# Cross-check: do the independent sources agree on where the name is? ------------------------------------------------
TOL <- c(`1` = 0, `2` = 15, `3` = 40)
fam <- placed |> group_by(key, source) |>
  mutate(fd = km(lon, lat, median(lon), median(lat))) |>
  summarise(flon = median(lon), flat = median(lat), frank = min(rank), fr80 = unname(quantile(fd, 0.8)), .groups = "drop") |>
  left_join(where |> select(key, r80_km), by = "key")
pairs <- fam |> inner_join(fam |> select(key, source2 = source, flon2 = flon, flat2 = flat, frank2 = frank, fr802 = fr80),
                           by = "key", relationship = "many-to-many") |>
  filter(source < source2) |>
  mutate(d = km(flon, flat, flon2, flat2),
         agree = d <= pmax(5, r80_km) + (fr80 + fr802) / 2 + TOL[as.character(frank)] + TOL[as.character(frank2)])
stopifnot("every placed position has a precision" = !anyNA(placed$rank))
check <- fam |> group_by(key) |> summarise(families = paste(sort(source), collapse = ", "), n_families = n(), .groups = "drop") |>
  left_join(pairs |> group_by(key) |> summarise(all_agree = all(agree), max_family_km = max(d), .groups = "drop"), by = "key")
text_n <- ev |> filter(source %in% c("article", "isor")) |> count(key, name = "n_text")
outcome <- tibble(key = unique(ev$key)) |> left_join(check, by = "key") |> left_join(text_n, by = "key") |>
  mutate(n_families = coalesce(n_families, 0L), n_text = coalesce(n_text, 0L),
         outcome = case_when(n_families == 0 ~ "text", n_families == 1 ~ "single", all_agree ~ "confirmed", TRUE ~ "disagree")) |>
  left_join(where |> select(key, n_places), by = "key") |>
  mutate(outcome = ifelse(coalesce(n_places, 0L) >= 2, "several places", outcome)) |>
  select(key, families, n_families, n_text, max_family_km, outcome)

# Candidate synonyms --------------------------------------------------------------------------------------------------
# Not one place: names that differ only in their digits (numbered marks: "Gamall 31", "Gamall 34") or in a direction
# ("6 sml austari", "6 sml vestari")
DIRECTION <- "austan|vestan|norðan|sunnan|austar|vestar|nyrðr|syðr|ytr|innr|eystr|vestr|norðar|sunnar|efr|neðr|austur|vestur|norður|suður"
dir_of <- function(x) { m <- regmatches(tolower(x), regexpr(DIRECTION, tolower(x))); if (length(m)) m else "" }
COMPASS <- "\\b(NNA|NNV|SSA|SSV|ANA|ASA|VNV|VSV|NA|NV|SA|SV|N|S|A|V)\\b"           # "S af Malarrifi", "SV af Malarrifi"
compass_of <- function(x) { m <- regmatches(x, regexpr(COMPASS, x)); if (length(m)) m else "" }
w <- where |> filter(precision <= 2) |> mutate(bx = floor(lon / 0.3), by = floor(lat / 0.15))
near <- w |> select(key, lon, lat, precision, bx, by) |>
  cross_join(tidyr::expand_grid(dx = -1:1, dy = -1:1)) |> mutate(bx = bx + dx, by = by + dy) |>
  inner_join(w |> select(key2 = key, lon2 = lon, lat2 = lat, precision2 = precision, bx, by), by = c("bx", "by"),
             relationship = "many-to-many") |>
  filter(key < key2) |> mutate(km = km(lon, lat, lon2, lat2)) |>
  filter(km <= ifelse(pmax(precision, precision2) == 2, 20, 10))
near$letters <- mapply(function(a, b) drop(utils::adist(a, b)), near$key, near$key2)
short <- pmin(nchar(near$key), nchar(near$key2))
held <- mapply(function(a, b) grepl(a, b, fixed = TRUE) || grepl(b, a, fixed = TRUE), near$key, near$key2)
art <- mapply(function(a, b) { l <- if (nchar(a) < nchar(b)) c(a, b) else c(b, a)
                               startsWith(l[2], l[1]) && substring(l[2], nchar(l[1]) + 1) %in% ARTICLE }, near$key, near$key2)
nm0 <- setNames(pref$name, pref$key)
same_letters <- gsub("[0-9]", "", near$key) == gsub("[0-9]", "", near$key2)
other_dir <- mapply(function(a, b) dir_of(nm0[[a]]) != dir_of(nm0[[b]]) || compass_of(nm0[[a]]) != compass_of(nm0[[b]]) ||
                      (grepl("[0-9]", nm0[[a]]) && grepl("[0-9]", nm0[[b]]) && gsub("[^0-9]", "", nm0[[a]]) != gsub("[^0-9]", "", nm0[[b]])),
                    near$key, near$key2)
spell <- near |> mutate(held = held, art = art, short = short, digits_only = same_letters, other_dir = other_dir) |>
  left_join(where |> select(key, n1 = n_positioned), by = "key") |> left_join(where |> select(key2 = key, n2 = n_positioned), by = "key2") |>
  filter(!digits_only, !other_dir,
         art | (!held & letters <= ifelse(short < 5 | pmax(precision, precision2) == 2, 1,
                                          ifelse(short >= 10 & pmin(n1, n2) >= 5, 3, 2)))) |>
  transmute(key_a = key, key_b = key2, relation = ifelse(art, "article", "spelling"), letters, km)
pair_of <- function(a, b, relation) tibble(key_a = pmin(a, b), key_b = pmax(a, b), relation) |> filter(key_a != key_b)
alt <- lmi |> filter(grepl("^Sjávar", class), !is.na(name_alt)) |> select(name, name_alt) |>
  mutate(alt = strsplit(name_alt, "\\s*,\\s*")) |> tidyr::unnest(alt)
explicit <- bind_rows(
  pair_of(name_key(alt$name), name_key(alt$alt), "lmi_alt"),
  variant |> filter(!is.na(synonym_of)) |> mutate(o = strsplit(synonym_of, "; ")) |> tidyr::unnest(o) |>
    with(pair_of(key, name_key(o), "article_synonym")),
  variant |> filter(!is.na(reading)) |> mutate(o = strsplit(reading, "; ")) |> tidyr::unnest(o) |>
    with(pair_of(key, name_key(o), "dictionary_reading")))
nm <- setNames(pref$name, pref$key); np <- setNames(where$n_positioned, where$key)
cen <- where |> select(key, lon, lat)
synonym <- bind_rows(spell, explicit) |> distinct(key_a, key_b, relation, .keep_all = TRUE) |>
  left_join(cen |> rename(key_a = key, la = lon, ta = lat), by = "key_a") |>
  left_join(cen |> rename(key_b = key, lb = lon, tb = lat), by = "key_b") |>
  mutate(km = coalesce(km, km(la, ta, lb, tb)), name_a = unname(nm[key_a]), name_b = unname(nm[key_b]),
         n_a = unname(np[key_a]), n_b = unname(np[key_b]), letters = coalesce(letters, mapply(function(a, b) drop(utils::adist(a, b)), key_a, key_b))) |>
  select(key_a, name_a, key_b, name_b, relation, letters, km, n_a, n_b) |> arrange(relation, key_a)
n_syn <- bind_rows(synonym |> select(key = key_a), synonym |> select(key = key_b)) |> count(key, name = "n_synonym")

# Together ----------------------------------------------------------------------------------------------------------
out <- pref |> left_join(base, by = "key") |> left_join(cnt, by = "key") |> left_join(where, by = "key") |>
  left_join(sea, by = "key") |> left_join(gear, by = "key") |> left_join(parent, by = "key") |>
  left_join(zoom, by = "key") |> left_join(outcome, by = "key") |> left_join(n_syn, by = "key") |>
  left_join(label_at, by = "key") |>
  mutate(label_lon = coalesce(label_lon, lon), label_lat = coalesce(label_lat, lat)) |>
  mutate(terrain = terrain(name), n_positioned = coalesce(n_positioned, 0L), n_synonym = coalesce(n_synonym, 0L)) |>
  left_join(parent |> count(parent_key, name = "n_children"), by = c("key" = "parent_key")) |>
  mutate(n_children = coalesce(n_children, 0L))
geom <- sf::st_geometry(foot)[match(out$key, foot$key)]
geom[is.na(match(out$key, foot$key))] <- sf::st_polygon()
out <- sf::st_sf(out, geometry = geom)

# Check and write -----------------------------------------------------------------------------------------------------
d <- sf::st_drop_geometry(out)
stopifnot("one row per key" = !anyDuplicated(d$key), setequal(d$key, ev$key), !anyNA(d$name), !anyNA(d$outcome),
          "every key of variant.parquet" = all(variant$key %in% d$key),
          "a positioned key has a zoom" = !anyNA(d$min_zoom[d$n_positioned > 0]),
          "a child no earlier than its parent" = with(d[!is.na(d$parent_key), ], all(min_zoom > d$min_zoom[match(parent_key, d$key)],
                                                                                   na.rm = TRUE)))
print(knitr::kable(tibble(keys = nrow(d), positioned = sum(d$n_positioned > 0), by_precision = paste(table(d$precision), collapse = "/"),
  with_footprint = sum(!sf::st_is_empty(out)), with_parent = sum(!is.na(d$parent_key)),
  parent_basis = paste(names(table(d$parent_basis)), table(d$parent_basis), collapse = ", "), in_lmi = sum(d$in_lmi),
  hazard = sum(d$terrain == "hazard"), synonyms = nrow(synonym)), caption = "curated/place_name/place_name"))
print(knitr::kable(d |> filter(n_positioned > 0) |> count(level, min_zoom), caption = "level and minimum zoom"))
print(knitr::kable(d |> count(outcome, n_families > 1), caption = "cross-check"))
print(knitr::kable(d |> filter(n_positioned > 0) |> count(n_places), caption = "places per key"))
print(knitr::kable(synonym |> count(relation), caption = "curated/place_name/synonym"))

inputs <- c(fd_curated("place_name", "evidence.parquet"), fd_curated("place_name", "variant.parquet"),
            fd_path("staging", "ornefni", "lmi_name.parquet"), GEBCO, LAND)
write_curated(out, fd_curated("place_name", "place_name.parquet"), inputs = inputs)
write_curated(synonym, fd_curated("place_name", "synonym.parquet"), inputs = inputs)
write_curated(place |> transmute(key, place, main, lon = plon, lat = plat, n, share, support, families),
              fd_curated("place_name", "place.parquet"), inputs = inputs)
