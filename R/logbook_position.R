# logbook_position.R — the e-logbook's position integers in decimal degrees.
#
# Input:  the integers as the e-logbook stores them: adb.fishing_station (latitude, longitude, latitude_end,
#         longitude_end), the same values as fs_afladagbok.ws_veidi on the stations both hold
# Output: none; decode_logbook_position(), logbook_position_hundredths()
#
# A latitude here has two-digit degrees, so its digit count gives the form of the record:
#   seven digits  ddmm.mmm, thousandths of a minute
#   six digits    ddmmss, or ddmm.hh (hundredths of a minute) on a trip logbook_position_hundredths() names
#   five digits   ddmm.m, tenths of a minute
#   four digits   ddmm
#   two digits    whole degrees
# A longitude no longer than its latitude is in the same form with its leading zeros dropped (4119 beside a six-digit
# latitude is 0°41'19"); a longer one is in the form of its own length, as a latitude would be. Any other latitude is
# NA, and so is a value beyond 85° or 178°. A latitude's sign is dropped. A positive longitude is west, so the sign is
# turned, as station_v turned it; curate/corrections/adb_vs_fs_afladagbok.R then restores the west entered as minus.
#
# Not every app keeps to the digit count (decision 211, against the AIS track): Trackwell raun's and Jóhann Gíslason's
# four- and five-digit latitudes of 2022-23 are degrees then minutes with the leading zero dropped (6631 is 66°03.1'),
# Taktikal exchanges latitude and longitude on some records and writes a four-digit longitude beside a six-digit
# latitude as ddmm, and two digits are a cell (STOKKUR rounds to the nearest degree). Reading them is TODO 126's.
#
# Oracle's view adb.station_v reads every six-digit value as ddmm.hh, which the digits contradict for all but one app
# (curate/corrections/adb_station_v_positions.yml).

decode_logbook_position <- function(lat, lon, hundredths = FALSE) {
  digits <- function(x) dplyr::if_else(is.na(x) | x == 0, NA_integer_, nchar(sprintf("%.0f", abs(x))))
  dec <- function(x, n) {
    x <- abs(x)
    dplyr::case_when(
      n == 7 ~ x %/% 1e5 + x %% 1e5 / 60000,
      n == 6 & hundredths ~ x %/% 1e4 + x %% 1e4 / 6000,
      n == 6 ~ x %/% 1e4 + (x %/% 100) %% 100 / 60 + x %% 100 / 3600,
      n == 5 ~ x %/% 1e3 + x %% 1e3 / 600,
      n == 4 ~ x %/% 100 + x %% 100 / 60,
      n == 2 ~ as.numeric(x))
  }
  n_lat <- digits(lat)
  n_lon <- digits(lon)
  n_lon <- dplyr::if_else(!is.na(n_lon) & n_lon > n_lat, n_lon, n_lat)
  lat <- dec(lat, n_lat)
  lon <- -sign(lon) * dec(lon, n_lon)
  tibble::tibble(lat = dplyr::if_else(lat <= 85, lat, NA_real_),
                 lon = dplyr::if_else(abs(lon) <= 178, lon, NA_real_))
}

# TRUE for a trip whose six-digit positions are ddmm.hh: one from Taktikal's app (33 % of its last two digits are
# 60-99), or one holding a last two digits of 61-99, impossible as seconds. 60 is not a sign: Reiknistofa's app writes
# 60 seconds where it rounds up (210 times), which the arithmetic of ddmmss reads right.
logbook_position_hundredths <- function(tid, source, lat1, lon1, lat2, lon2) {
  over60 <- function(x) !is.na(x) & abs(x) >= 1e5 & abs(x) < 1e6 & abs(x) %% 100 > 60
  hit <- grepl("TAKTIKAL", toupper(source)) | over60(lat1) | over60(lon1) | over60(lat2) | over60(lon2)
  tid %in% tid[hit]
}
