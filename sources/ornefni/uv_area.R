# The areas of MFRI's fishing-area information system (uv, "Upplýsingakerfi veiðisvæða"): closures, real-time closures,
# regulated areas, each with its polygon and the text that names its ground.
# Side: preprocessing (ornefni). See plan 044 §6.
#
# Input:  raw/oracle/uv/veidisvaedi.parquet (5,948 areas), hnit.parquet (25,929 vertices), veidisv_veidarf.parquet and
#         veidarfa.parquet (the gears an area concerns), skyndilokanir_xml_input.parquet (1,694 real-time closure forms)
# Output: staging/ornefni/uv_area.parquet - one row per area (5,948), keyed on `area_id`, its outline as WKB `geometry`
#         (WGS 84; read_curated_sf())
#
# Source-shaped, under English names. `heiti` is the area's code, mostly a regulation's article ("504-1-A") or a
# closure's number ("005"); the ground is named in `skyring` and `fs_skyring` (the explanation, and a second version
# whose source is not documented: "Bann við veiðum með botnvörpu í Langaneskanti") and, for a real-time closure, in the
# form a biologist sent from the web (`form_place`, the form's STADUR: "á Eyjagrunni í Húnaflóa"; `form_text`, its
# SKYRING). Only those two of the form's fields are read: it also holds the sender and a kennitala. The persons'
# tables (starfsm, veidisv_starfsm, hafro_notendur_v), the free text `ath` (it names people), the images and the
# species are not read. `l_s` is kept as
# given: L on 1,179 real-time closures and S on 2,753, its meaning not documented (L is not only longline).
# - The outline: the area's vertices in HNIT's order, degrees and minutes to two decimals as channel holds them
#   (decode_channel_position(), R/channel_position.R); three or more make a polygon, two a line, one a point
#   (`outline`). A vertex outside 55-80 N and 0-45 W, or with its minutes at 60 or over, is unread (`vertex_unread`) and
#   left out. A polygon that crosses itself is mended on the plane (sf::st_make_valid). `area_km2` in ISN93.

library(dplyr)

R <- function(t) nanoparquet::read_parquet(fd_raw("oracle", "uv", paste0(t, ".parquet")))
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(x)); x[x %in% ""] <- NA; x }
tag <- function(s, t) {                                       # one XML element's text, NA where absent
  m <- regmatches(s, regexec(sprintf("<%s[^>]*>(.*?)</%s>", t, t), s))
  vapply(m, function(z) if (length(z) > 1) z[2] else NA_character_, "")
}

v <- R("veidisvaedi"); h <- R("hnit")
need <- c("id", "heiti", "dags_fra", "dags_til", "fors", "vmork", "teg_veidisvaeda", "l_s", "skyring", "fs_skyring")
stopifnot("uv.veidisvaedi has the columns read" = all(need %in% names(v)))
gear <- R("veidisv_veidarf") |> left_join(R("veidarfa") |> select(veidarf = id, gear = heiti), by = "veidarf") |>
  group_by(area_id = veidisv_id) |> summarise(gears = paste(sort(unique(na.omit(gear))), collapse = "; "), .groups = "drop")
x <- R("skyndilokanir_xml_input")
form <- tibble(area_id = x$veidisvaedi_id, form_place = squeeze(tag(x$xml_input, "stadur")),
               form_text = squeeze(tag(x$xml_input, "skyring")))
stopifnot("one form per area" = !anyDuplicated(form$area_id))

vx <- h |> arrange(veidisv, id) |>
  mutate(lat = decode_channel_position(hnit_n, 55, 80), lon = -decode_channel_position(hnit_v, 0, 45),
         read = !is.na(lat) & !is.na(lon))
shape <- vx |> filter(read) |> group_by(area_id = veidisv) |>
  summarise(n_vertex = n(), geometry = list({
    m <- cbind(lon, lat)
    if (n() >= 3) sf::st_polygon(list(rbind(m, m[1, ]))) else if (n() == 2) sf::st_linestring(m) else sf::st_point(m[1, ])
  }), .groups = "drop")
unread <- vx |> group_by(area_id = veidisv) |> summarise(vertex_unread = sum(!read), .groups = "drop")

out <- v |> transmute(area_id = id, type = teg_veidisvaeda, heiti, date_from = dags_fra, date_to = dags_til,
                      reason = squeeze(fors), limit = squeeze(vmork), l_s, skyring = squeeze(skyring),
                      fs_skyring = squeeze(fs_skyring)) |>
  left_join(gear, by = "area_id") |> left_join(form, by = "area_id") |>
  left_join(unread, by = "area_id") |> left_join(shape, by = "area_id") |>
  mutate(vertex_unread = coalesce(vertex_unread, 0L), n_vertex = coalesce(n_vertex, 0L),
         outline = case_when(n_vertex >= 3 ~ "polygon", n_vertex == 2 ~ "line", n_vertex == 1 ~ "point", TRUE ~ "none"))
empty <- vapply(out$geometry, is.null, NA)
out$geometry[empty] <- list(sf::st_geometrycollection())
out <- sf::st_sf(out, sf_column_name = "geometry", crs = 4326)
s2 <- sf::sf_use_s2(); sf::sf_use_s2(FALSE)
poly <- out$outline == "polygon"
out$geometry[poly] <- sf::st_make_valid(out$geometry[poly])
sf::sf_use_s2(s2)
out$area_km2 <- NA_real_
out$area_km2[poly] <- as.numeric(sf::st_area(sf::st_transform(out$geometry[poly], 3057))) / 1e6

stopifnot(nrow(out) == nrow(v), !anyDuplicated(out$area_id), sum(out$n_vertex) + sum(out$vertex_unread) == nrow(h))
print(knitr::kable(sf::st_drop_geometry(out) |> count(outline) |>
  left_join(sf::st_drop_geometry(out) |> group_by(outline) |>
    summarise(with_text = sum(!is.na(coalesce(form_place, skyring, fs_skyring))), median_km2 = median(area_km2)), by = "outline"),
  caption = "staging/ornefni/uv_area"))
cat("vertices", nrow(h), " unread", sum(out$vertex_unread), " forms", nrow(form), " with a place", sum(!is.na(form$form_place)), "\n")

write_parquet_sf(out, fd_staging("ornefni", "uv_area.parquet"))
