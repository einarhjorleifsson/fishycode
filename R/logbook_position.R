# logbook_position.R — the e-logbook's position integers in decimal degrees.
#
# Input:  the integers as the e-logbook stores them: adb.fishing_station (latitude, longitude, latitude_end,
#         longitude_end), the same values as fs_afladagbok.ws_veidi on the stations both hold; for each station its
#         trip, vessel, app, feed and date, which the app profile's rows P3 and P4 read
#         (curate/corrections/logbook_app_profile.yml)
# Output: none; decode_logbook_position(), logbook_short_longitudes(), logbook_position_rules(),
#         logbook_position_hundredths()
#
# A latitude here has two-digit degrees, so its digit count gives the form of the record:
#   seven digits  ddmm.mmm, thousandths of a minute
#   six digits    ddmmss, or ddmm.hh (hundredths of a minute) on a trip logbook_position_hundredths() names
#   five digits   ddmm.m, tenths of a minute
#   four digits   ddmm
#   two digits    whole degrees (STOKKUR rounds to the degree: row P2, a 1-degree cell centred on the value)
# A longitude longer than its latitude is in the form of its own length, as a latitude would be. A shorter one beside a
# latitude of four or five digits has lost leading zeros (959 beside 6431 is 9°59'). Beside a six-digit latitude it is
# read value by value (the maintainer, 2026-10-30; $FISHYDATA/archive/2026-10-30-plan054-step2a/step7_findings.md):
#   right   trailing digits lost, the value in the form of its own length: five digits ddmm.m (22059 is 22°05.9'),
#           four ddmm, fewer right-padded to six; valid when its minutes (and seconds) are under 60 and it is under 46°
#   left    leading zeros lost (22312 is 2°23'12"), valid when its minutes and seconds are under 60
# The only valid reading is taken. Where both are, the record decides (logbook_short_longitudes()): the station's own
# other position where it is unambiguous, then the trip's unambiguous stations, then the vessel's within 3 days; the
# reading within 100 km (the station's own) or 200 km (trip, vessel) with the other three times as far. The AIS is never
# read. Where the record cannot decide, the gear does: a midwater trawl left (the Norwegian Sea's pelagic fisheries),
# every other gear right; and a gear other than the midwater trawl whose only valid reading is left is read right, its
# minutes of 60 or more carried. Both are marked uncertain in the form. Where neither reading is valid, none. Against
# the AIS track, which the rule never reads, the gear put the uncertain on the nearer reading on every midwater trawl and
# 850 of 852 other stations of fs_afladagbok (step7_findings.md). Until 2026-10-30 adb read every short longitude left
# (decision 211), and fs_afladagbok's adapter right-padded as seconds but for the midwater trawl (gid 9), which it read
# left.
# Any other latitude is NA, and so is a value beyond 85° or 178°. A latitude's sign is dropped. A positive longitude
# is west, so the sign is turned, as station_v turned it; the adapters' sign rule then restores the west entered as minus.
#
# Not every app keeps to the digit count (decision 211, against the AIS track); the profile's rows say which:
#   P3          Taktikal's six digits are ddmm.hh, and a latitude and longitude exchanged on a record are read back
#               (a latitude under 30° beside a longitude beyond 30°)
#   P3-value    a trip with a six-digit value ending 61-99, impossible as seconds, is ddmm.hh (any app)
#   P4          Trackwell raun's and Jóhann Gíslason's four- and five-digit latitudes of 2022-23 are degrees then
#               minutes with the leading zero dropped (6631 is 66°03.1', 64312 is 64°03.12'): beside a six-digit or a
#               five-digit longitude the latitude alone, beside a four-digit one both; five and five digits are kept as
#               read, and their form says uncertain
# The form each position was read in is returned with it, so the record keeps how it was read.
#
# Oracle's view adb.station_v reads every six-digit value as ddmm.hh, which the digits contradict for all but one app
# (curate/corrections/adb_station_v_positions.yml).

.pos_digits <- function(x) dplyr::if_else(is.na(x) | x == 0, NA_integer_, nchar(sprintf("%.0f", abs(x))))

# A six-digit value (ddmmss, or ddmm.hh) in degrees, and whether its minutes (and seconds) are under 60.
.pos_deg6 <- function(x, h) {
  x <- abs(x)
  dplyr::if_else(h, x %/% 1e4 + x %% 1e4 / 6000, x %/% 1e4 + (x %/% 100) %% 100 / 60 + x %% 100 / 3600)
}
.pos_ok6 <- function(x, h) {
  x <- abs(x)
  (x %/% 100) %% 100 < 60 & (h | x %% 100 < 60)
}

# The two readings of a longitude shorter than a six-digit latitude, in degrees, unsigned, and their validity.
.short_lon_readings <- function(lon, n_lon, h) {
  x <- abs(lon)
  xr <- x * 10^(6L - n_lon)
  right <- dplyr::case_when(n_lon == 5 ~ x %/% 1e3 + x %% 1e3 / 600, n_lon == 4 ~ x %/% 100 + x %% 100 / 60,
                            .default = .pos_deg6(xr, h))
  right_ok <- dplyr::case_when(n_lon == 5 ~ (x %/% 10) %% 100 < 60, n_lon == 4 ~ x %% 100 < 60,
                               .default = .pos_ok6(xr, h)) & right < 46
  list(right = right, right_ok = right_ok, left = .pos_deg6(x, h), left_ok = .pos_ok6(x, h))
}

# `short_lon`: for a longitude shorter than a six-digit latitude, "right", "left", "uncertain right", "uncertain left",
# "uncertain" (read left) or "none"; NA where nothing decided it, which takes the only valid reading, left where both
# are, none where neither is.
# `short_why`: what decided it, for the form.
decode_logbook_position <- function(lat, lon, hundredths = FALSE, short_latitude = FALSE, exchanged = FALSE,
                                    short_lon = NA_character_, short_why = NA_character_) {
  dec <- function(x, n, h) {
    x <- abs(x)
    dplyr::case_when(
      n == 7 ~ x %/% 1e5 + x %% 1e5 / 60000,
      n == 6 & h ~ x %/% 1e4 + x %% 1e4 / 6000,
      n == 6 ~ x %/% 1e4 + (x %/% 100) %% 100 / 60 + x %% 100 / 3600,
      n == 5 ~ x %/% 1e3 + x %% 1e3 / 600,
      n == 4 ~ x %/% 100 + x %% 100 / 60,
      n == 2 ~ as.numeric(x))
  }
  # degrees, then minutes with their leading zero dropped (row P4): 6631 is 66°03.1', 64312 is 64°03.12'
  dec_zero <- function(x, n) {
    x <- abs(x)
    dplyr::case_when(n == 4 ~ x %/% 100 + x %% 100 / 600, n == 5 ~ x %/% 1e3 + x %% 1e3 / 6000)
  }
  n <- max(length(lat), length(lon))
  hundredths <- rep_len(hundredths, n); short_latitude <- rep_len(short_latitude, n)
  exchanged <- rep_len(exchanged, n); short_lon <- rep_len(short_lon, n); short_why <- rep_len(short_why, n)
  n_lat <- .pos_digits(lat)
  n_lon <- .pos_digits(lon)
  short <- !is.na(n_lon) & n_lat %in% 6L & n_lon < 6L
  sr <- .short_lon_readings(lon, n_lon, hundredths)
  choice <- dplyr::case_when(!short ~ NA_character_, !is.na(short_lon) ~ short_lon,
                             sr$right_ok & !sr$left_ok ~ "right", sr$left_ok & !sr$right_ok ~ "left",
                             sr$right_ok & sr$left_ok ~ "uncertain", .default = "none")
  # row P4 reads the digit counts as written, before a short longitude takes its latitude's
  p4_lat <- short_latitude & n_lat %in% 4:5 & n_lon %in% 4:6 & !(n_lat %in% 5L & n_lon %in% 5L)
  p4_lon <- short_latitude & n_lat %in% 4:5 & n_lon %in% 4L
  p4_uncertain <- short_latitude & n_lat %in% 5L & n_lon %in% 5L
  n_lon_read <- n_lon
  n_lon <- dplyr::case_when(!is.na(n_lon) & n_lon > n_lat ~ n_lon, .default = n_lat)
  y <- dplyr::if_else(p4_lat, dec_zero(lat, n_lat), dec(lat, n_lat, hundredths))
  x_abs <- dplyr::case_when(choice %in% c("right", "uncertain right") ~ sr$right,
                            choice %in% c("left", "uncertain", "uncertain left") ~ sr$left,
                            choice == "none" ~ NA_real_, p4_lon ~ dec_zero(lon, n_lon_read),
                            .default = dec(lon, n_lon, hundredths))
  x <- -sign(lon) * x_abs
  swap <- exchanged & !is.na(y) & !is.na(x) & y < 30 & abs(x) > 30
  form <- dplyr::case_when(
    swap ~ "exchanged (P3)",
    p4_uncertain ~ "uncertain (P4)",
    p4_lat ~ "degrees, minutes with the zero dropped (P4)",
    n_lat == 7 ~ "ddmm.mmm",
    n_lat == 6 & hundredths ~ "ddmm.hh",
    n_lat == 6 ~ "ddmmss",
    n_lat == 5 ~ "ddmm.m",
    n_lat == 4 ~ "ddmm",
    n_lat == 2 ~ "whole degrees")
  form <- dplyr::if_else(short, paste0(form, "; short longitude ", choice,
                                       dplyr::if_else(is.na(short_why), "", paste0(" by ", short_why))), form)
  lat_out <- dplyr::if_else(swap, abs(x), y)
  lon_out <- dplyr::if_else(swap, -y, x)
  tibble::tibble(lat = dplyr::if_else(lat_out <= 85, lat_out, NA_real_),
                 lon = dplyr::if_else(abs(lon_out) <= 178, lon_out, NA_real_),
                 form = dplyr::if_else(is.na(lat_out), NA_character_, form))
}

# Where both readings of a short longitude beside a six-digit latitude are valid, the record decides, one feed at a
# time: the station's own other position (start for end, end for start) where it is unambiguous (six-digit latitude,
# six-digit longitude), then the trip's unambiguous start positions (their median), then the vessel's within 3 days;
# then the gear (`midwater`, TRUE for a midwater trawl: left; else right), uncertain. A station not on a midwater trawl
# whose only valid reading is left takes the right one, minutes carried, uncertain, where it is under 46°. Distances are
# on the adapters' sign rule. Returns per station lon1, why1, lon2, why2 for decode_logbook_position()'s short_lon and
# short_why; NA where the value is not such a longitude or its only valid reading stands.
logbook_short_longitudes <- function(tid, vid, date, lat1, lon1, lat2, lon2, hundredths, midwater = FALSE) {
  sign_rule <- function(lat, lon) dplyr::if_else(lon > 10.75 & lat < 67.66, -lon, lon)
  km <- function(a1, o1, a2, o2) {
    r <- pi / 180
    2 * 6371 * asin(sqrt(sin((a2 - a1) * r / 2)^2 + cos(a1 * r) * cos(a2 * r) * sin((o2 - o1) * r / 2)^2))
  }
  d <- tibble::tibble(i = seq_along(tid), tid = tid, vid = vid, date = as.Date(date), y1 = lat1, x1 = lon1, y2 = lat2,
                      x2 = lon2, h = rep_len(hundredths, length(tid)), mw = rep_len(midwater %in% TRUE, length(tid)))
  ny1 <- .pos_digits(d$y1); nx1 <- .pos_digits(d$x1); ny2 <- .pos_digits(d$y2); nx2 <- .pos_digits(d$x2)
  # the unambiguous positions: a six-digit latitude with a six- (or for a start, seven-) digit longitude
  un1 <- ny1 %in% 6L & nx1 %in% 6:7
  un2 <- ny2 %in% 6L & nx2 %in% 6L
  ulat1 <- dplyr::if_else(un1, .pos_deg6(d$y1, d$h), NA_real_)
  ulon1 <- dplyr::if_else(un1, sign_rule(ulat1, -sign(d$x1) * dplyr::if_else(nx1 == 7, abs(d$x1) %/% 1e5 + abs(d$x1) %% 1e5 / 60000,
                                                                         .pos_deg6(d$x1, d$h))), NA_real_)
  ulat2 <- dplyr::if_else(un2, .pos_deg6(d$y2, d$h), NA_real_)
  ulon2 <- dplyr::if_else(un2, sign_rule(ulat2, -sign(d$x2) * .pos_deg6(d$x2, d$h)), NA_real_)
  un <- tibble::tibble(tid = d$tid, vid = d$vid, date = d$date, lat = ulat1, lon = ulon1)[un1, ]
  trip <- dplyr::summarise(un, tlat = stats::median(lat), tlon = stats::median(lon), .by = tid)
  side <- function(y, x, ny, nx, own_lat, own_lon) {
    short <- ny %in% 6L & !is.na(nx) & nx < 6L
    sr <- .short_lon_readings(x, nx, d$h)
    both <- short & sr$right_ok & sr$left_ok
    out <- tibble::tibble(lon = rep(NA_character_, nrow(d)), why = NA_character_)
    carry <- short & !d$mw & sr$left_ok & !sr$right_ok & !is.na(sr$right) & sr$right < 46
    out$lon[carry] <- "uncertain right"
    out$why[carry] <- "the gear, minutes carried"
    if (!any(both)) return(out)
    lat <- .pos_deg6(y, d$h)
    b <- tibble::tibble(i = d$i, tid = d$tid, vid = d$vid, date = d$date, lat = lat,
                        r = sign_rule(lat, -sign(x) * sr$right), l = sign_rule(lat, -sign(x) * sr$left),
                        olat = own_lat, olon = own_lon)[both, ]
    b <- dplyr::left_join(b, trip, by = "tid", relationship = "many-to-one")
    v <- dplyr::inner_join(b |> dplyr::select(i, vid, date), un |> dplyr::select(vid, ud = date, ulat = lat, ulon = lon),
                           by = dplyr::join_by(vid, date >= ud), relationship = "many-to-many") |>
      dplyr::filter(date - ud <= 3) |>
      dplyr::bind_rows(dplyr::inner_join(b |> dplyr::select(i, vid, date),
                                         un |> dplyr::select(vid, ud = date, ulat = lat, ulon = lon),
                                         by = dplyr::join_by(vid, date < ud), relationship = "many-to-many") |>
                         dplyr::filter(ud - date <= 3)) |>
      dplyr::summarise(vlat = stats::median(ulat), vlon = stats::median(ulon), .by = i)
    b <- dplyr::left_join(b, v, by = "i", relationship = "one-to-one")
    pick <- function(kr, kl, lim) dplyr::case_when(kr <= lim & kl >= 3 * kr ~ "right", kl <= lim & kr >= 3 * kl ~ "left")
    eo <- pick(km(b$lat, b$r, b$olat, b$olon), km(b$lat, b$l, b$olat, b$olon), 100)
    et <- pick(km(b$lat, b$r, b$tlat, b$tlon), km(b$lat, b$l, b$tlat, b$tlon), 200)
    ev <- pick(km(b$lat, b$r, b$vlat, b$vlon), km(b$lat, b$l, b$vlat, b$vlon), 200)
    gear <- dplyr::if_else(d$mw[b$i], "uncertain left", "uncertain right")
    out$lon[b$i] <- dplyr::coalesce(eo, et, ev, gear)
    out$why[b$i] <- dplyr::case_when(!is.na(eo) ~ "the station's other position", !is.na(et) ~ "the trip",
                                     !is.na(ev) ~ "the vessel's days", .default = "the gear")
    out
  }
  s1 <- side(d$y1, d$x1, ny1, nx1, ulat2, ulon2)
  s2 <- side(d$y2, d$x2, ny2, nx2, ulat1, ulon1)
  tibble::tibble(lon1 = s1$lon, why1 = s1$why, lon2 = s2$lon, why2 = s2$why)
}

# Where the profile's rows P3 (Taktikal's hundredths and exchanged pairs) and P4 (the short latitudes) hold, for
# stations of one feed: the app as the profile names it (app_base_name()), the station's date. One logical vector each.
# Row P2's whole degrees need no row: two digits are read as degrees for any app, and the form says so.
logbook_position_rules <- function(app, schema, date, profile = app_profile()) {
  d <- tibble::tibble(app = app, schema = schema, date = as.Date(date), gear = NA_character_, gear_class = NA_character_)
  list(hundredths = .app_scope(profile$P3, d), exchanged = .app_scope(profile$P3, d),
       short_latitude = .app_scope(profile$P4, d))
}

# TRUE for a trip whose six-digit positions are ddmm.hh: one row P3 names (`by_app`, Taktikal's: 33 % of its last two
# digits are 60-99), or one holding a last two digits of 61-99, impossible as seconds (row P3-value). 60 is not a sign:
# Reiknistofa's app writes 60 seconds where it rounds up (210 times), which the arithmetic of ddmmss reads right.
logbook_position_hundredths <- function(tid, by_app, lat1, lon1, lat2, lon2) {
  over60 <- function(x) !is.na(x) & abs(x) >= 1e5 & abs(x) < 1e6 & abs(x) %% 100 > 60
  hit <- by_app | over60(lat1) | over60(lon1) | over60(lat2) | over60(lon2)
  tid %in% tid[hit]
}
