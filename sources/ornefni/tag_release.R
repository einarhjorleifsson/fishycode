# The place names MFRI gave its tagging groups, at the channel stations where the fish were tagged, from the dump of
# fiskmerki.
# Side: preprocessing (ornefni). See plan 044 §4.1.
#
# Input:  raw/oracle/fiskmerki/groupmerk.parquet (543 groups), groupmerk_stodvar.parquet (1,536 group-sample links);
#         raw/oracle/channel/sample.parquet, station.parquet
# Output: staging/ornefni/tag_release.parquet - one row per group-sample link (1,536), keyed on `link_id`
#
# Source-shaped, under English names. `name` is GROUPMERK.ORNEFNI, given by MFRI's staff: mostly a name ("Faxaflói",
# "Presthúsaklakkur"), sometimes two ("Eyrarbakki - Knarrarós") or a qualified one ("Innan við Mánáreyjar"). The link
# names a channel sample (SYNIS_ID, channel.sample's `sample_id`), whose station gives the position, as fiskmerki's
# view stodvar_v does: the tow's midpoint with both ends read (basis `derived`, kind `track`), else the start
# (`recorded`, `point`), else the recorded square's centre (`derived`, `square`), read by decode_channel_position()
# (R/channel_position.R). A sample not in the dump gives no position (`none`). merki.grupmerk and merki.merking, the
# older system's, are not read: 456 of their 457 and 123 of 123 names are here.

library(dplyr)

R <- function(s, t) nanoparquet::read_parquet(fd_raw("oracle", s, paste0(t, ".parquet")))
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(x)); x[x %in% ""] <- NA; x }

g <- R("fiskmerki", "groupmerk"); gs <- R("fiskmerki", "groupmerk_stodvar")
sm <- R("channel", "sample")[c("sample_id", "station_id")]
st <- R("channel", "station")[c("station_id", "station_date", "latitude", "longitude", "latitude_end", "longitude_end",
                                "square", "square_part")]

d <- gs |> select(link_id = id, group_id = groupmerk_id, sample_id = synis_id) |>
  left_join(g |> select(group_id = id, group_no = groupmerknr, name_raw = ornefni), by = "group_id") |>
  left_join(sm, by = "sample_id") |> left_join(st, by = "station_id")

lat1 <- decode_channel_position(d$latitude, 55, 80); lon1 <- -decode_channel_position(d$longitude, 0, 45)
lat2 <- decode_channel_position(d$latitude_end, 55, 80); lon2 <- -decode_channel_position(d$longitude_end, 0, 45)
start <- !is.na(lat1) & !is.na(lon1); both <- start & !is.na(lat2) & !is.na(lon2)
part <- d$square_part
has_sq <- !is.na(d$square) & d$square > 0
sqc <- matrix(NA_real_, nrow(d), 2)
if (any(has_sq)) { s <- geo::r2d(d$square[has_sq]); sqc[has_sq, ] <- cbind(s$lat, s$lon) }
off_lat <- ifelse(part %in% c(1, 2), 0.125, ifelse(part %in% c(3, 4), -0.125, 0))
off_lon <- ifelse(part %in% c(1, 3), -0.25, ifelse(part %in% c(2, 4), 0.25, 0))

out <- d |>
  transmute(link_id, group_id, group_no, sample_id, station_id, time = station_date, name_raw, name = squeeze(name_raw),
            latitude_raw = latitude, longitude_raw = longitude, square, square_part = as.integer(part)) |>
  mutate(lat = case_when(both ~ (lat1 + lat2) / 2, start ~ lat1, has_sq ~ sqc[, 1] + off_lat),
         lon = case_when(both ~ (lon1 + lon2) / 2, start ~ lon1, has_sq ~ sqc[, 2] + off_lon),
         position_basis = case_when(both | (!start & has_sq) ~ "derived", start ~ "recorded", TRUE ~ "none"),
         position_kind = case_when(both ~ "track", start ~ "point", has_sq ~ "square", TRUE ~ NA_character_),
         square_w = ifelse(position_kind %in% "square", ifelse(is.na(square_part), 1, 0.5), NA_real_),
         square_h = square_w / 2, source = "fiskmerki")

stopifnot(nrow(out) == nrow(gs), !anyDuplicated(out$link_id), !anyNA(out$name))
print(knitr::kable(tibble(links = nrow(out), groups = n_distinct(out$group_id), names = n_distinct(out$name),
  stations = n_distinct(out$station_id, na.rm = TRUE), track = sum(out$position_kind %in% "track"),
  point = sum(out$position_kind %in% "point"), square = sum(out$position_kind %in% "square"),
  none = sum(out$position_basis == "none")), caption = "staging/ornefni/tag_release"))

write_parquet_group(out, fd_staging("ornefni", "tag_release.parquet"))
