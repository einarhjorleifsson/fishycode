# The fishing-area names on MFRI's sampling stations: channel.station.fishing_area, with the station's position.
# Side: preprocessing (ornefni). See plan 044 §4.1.
#
# Input:  raw/oracle/channel/station.parquet (344,656 stations), sample.parquet, sample_category.parquet
# Output: staging/ornefni/channel_name.parquet - one row per station with a fishing area (22,503, 2000-2026), keyed on
#         `station_id`
#
# Read where the dump put it, under English names. `fishing_area` is "Nafn veiðisvæðis" (Oracle's comment): mostly
# the gillnet survey's stations (SMN, sample category 34), then inspectors', fishermen's, gear trials', the discard
# project's and other samples (`categories`, the station's samples' categories). The station's `employees` (people) is
# not read.
# - Positions are degrees and minutes to two decimals (653000 = 65°30.00'; 5,492 latitudes end above 59, so not
#   seconds), read by decode_channel_position() (R/channel_position.R): the square from them is the recorded `square` on
#   98.8 %. A value of three or four digits is degrees and minutes (6611 = 66°11'). One whose minutes reach 60, or
#   outside 55-80 N and 0-45 W, is unread: noted in `position_note`, and the station is placed at its recorded square's
#   or sub-square's centre (basis `derived`, kind `square`).
# - With both ends read, the position is the tow's midpoint (basis `derived`, kind `track`); else the start (`recorded`,
#   `point`).

library(dplyr)

R <- function(table) nanoparquet::read_parquet(fd_raw("oracle", "channel", paste0(table, ".parquet")))
squeeze <- function(x) { x <- gsub("\\s+", " ", trimws(x)); x[x %in% ""] <- NA; x }

st <- R("station")
need <- c("station_id", "cruise_id", "station_date", "latitude", "longitude", "latitude_end", "longitude_end", "square",
          "square_part", "region", "region_part", "fishing_area")
stopifnot("channel.station has the columns read" = all(need %in% names(st)))
st <- st[!is.na(squeeze(st$fishing_area)), need]
sm <- R("sample"); cat_ <- R("sample_category")
cats <- sm |> filter(station_id %in% st$station_id) |> distinct(station_id, sample_category_no) |>
  left_join(cat_ |> select(sample_category_no, eng_descr), by = "sample_category_no") |>
  group_by(station_id) |> summarise(categories = paste(sort(unique(eng_descr)), collapse = "; "), .groups = "drop")

lat1 <- decode_channel_position(st$latitude, 55, 80); lon1 <- -decode_channel_position(st$longitude, 0, 45)
lat2 <- decode_channel_position(st$latitude_end, 55, 80); lon2 <- -decode_channel_position(st$longitude_end, 0, 45)
start <- !is.na(lat1) & !is.na(lon1); both <- start & !is.na(lat2) & !is.na(lon2)
part <- st$square_part
sqc <- matrix(NA_real_, nrow(st), 2); has_sq <- !is.na(st$square)
if (any(has_sq)) { d <- geo::r2d(st$square[has_sq]); sqc[has_sq, ] <- cbind(d$lat, d$lon) }
off_lat <- ifelse(part %in% c(1, 2), 0.125, ifelse(part %in% c(3, 4), -0.125, 0))
off_lon <- ifelse(part %in% c(1, 3), -0.25, ifelse(part %in% c(2, 4), 0.25, 0))

out <- tibble(station_id = st$station_id, cruise_id = st$cruise_id, station_date = st$station_date,
              name_raw = st$fishing_area, name = squeeze(st$fishing_area), region = st$region, region_part = st$region_part,
              square = st$square, square_part = as.integer(part),
              latitude_raw = st$latitude, longitude_raw = st$longitude, latitude_end_raw = st$latitude_end,
              longitude_end_raw = st$longitude_end, lat1 = lat1, lon1 = lon1, lat2 = lat2, lon2 = lon2) |>
  left_join(cats, by = "station_id") |>
  mutate(lat = case_when(both ~ (lat1 + lat2) / 2, start ~ lat1, has_sq ~ sqc[, 1] + off_lat, TRUE ~ NA_real_),
         lon = case_when(both ~ (lon1 + lon2) / 2, start ~ lon1, has_sq ~ sqc[, 2] + off_lon, TRUE ~ NA_real_),
         position_basis = case_when(both | (!start & has_sq) ~ "derived", start ~ "recorded", TRUE ~ "none"),
         position_kind = case_when(both ~ "track", start ~ "point", has_sq ~ "square", TRUE ~ NA_character_),
         square_w = ifelse(position_kind %in% "square", ifelse(is.na(square_part), 1, 0.5), NA_real_),
         square_h = square_w / 2,
         position_note = ifelse(!is.na(latitude_raw) & !start, paste("position unread:", latitude_raw, longitude_raw), NA_character_),
         source = "channel")

stopifnot(nrow(out) == nrow(st), !anyDuplicated(out$station_id), !anyNA(out$name))
print(knitr::kable(tibble(stations = nrow(out), names = n_distinct(out$name),
  years = paste(range(format(out$station_date, "%Y"), na.rm = TRUE), collapse = "-"),
  track = sum(out$position_kind %in% "track"), point = sum(out$position_kind %in% "point"),
  square = sum(out$position_kind %in% "square"), none = sum(out$position_basis == "none"),
  unread = sum(!is.na(out$position_note))), caption = "staging/ornefni/channel_name"))

write_parquet_group(out, fd_staging("ornefni", "channel_name.parquet"))
