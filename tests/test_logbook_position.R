# test_logbook_position.R — decode_logbook_position() and logbook_position_hundredths() on the e-logbook's forms.
#
# Input:  R/logbook_position.R; no data, no $FISHYDATA
# Output: nothing kept
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_logbook_position.R")'
#
# The values are forms found in adb.fishing_station (curate/corrections/adb_station_v_positions.yml).

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
sys.source(file.path(root, "R", "logbook_position.R"), envir = fd)

dms <- function(d, m, s) d + m / 60 + s / 3600

testthat::test_that("six digits are ddmmss, a positive longitude west", {
  p <- fd$decode_logbook_position(661858L, 214512L)
  testthat::expect_equal(p$lat, dms(66, 18, 58))
  testthat::expect_equal(p$lon, -dms(21, 45, 12))
})

testthat::test_that("six digits are ddmm.hh on a hundredths trip", {
  p <- fd$decode_logbook_position(661875L, 214599L, hundredths = TRUE)
  testthat::expect_equal(p$lat, 66 + 18.75 / 60)
  testthat::expect_equal(p$lon, -(21 + 45.99 / 60))
})

testthat::test_that("a short longitude beside a six-digit latitude: the only valid reading, else left and uncertain", {
  # 22059: right ddmm.m 22°05.9' valid, left 2°20'59" valid: both, uncertain, left
  # 22075: right 22°07.5', left 2°20'75" invalid: right
  # 67312: right 67° (over 46) invalid, left 6°73' invalid: none
  # 4119: right 41°19' valid, left 0°41'19" valid: both, uncertain, left
  p <- fd$decode_logbook_position(rep(661858L, 4), c(22059L, 22075L, 67312L, -4119L))
  testthat::expect_equal(p$lon, c(-dms(2, 20, 59), -(22 + 7.5 / 60), NA, dms(0, 41, 19)))
  testthat::expect_equal(p$form, paste0("ddmmss; short longitude ", c("uncertain", "right", "none", "uncertain")))
  q <- fd$decode_logbook_position(661858L, 22059L, short_lon = "right", short_why = "the trip")
  testthat::expect_equal(q$lon, -(22 + 5.9 / 60))
  testthat::expect_equal(q$form, "ddmmss; short longitude right by the trip")
})

testthat::test_that("the record decides a short longitude both readings allow: own end, trip, vessel's days", {
  # station 1: start 22059 beside 645030, its end unambiguous at 22°06' W; station 2 on the same trip, no end and no
  # unambiguous start on its trip; station 3 another trip, its vessel's start 2 days later unambiguous at 22°00'30" W
  # (station 4); station 5 nothing near. A longitude under 10° is never unambiguous in six digits, so the record can
  # only decide right
  s <- fd$logbook_short_longitudes(tid = c("a", "a", "b", "c", "c2"), vid = c(1, 1, 2, 2, 3),
                                   date = as.Date(c("2024-01-01", "2024-01-01", "2024-01-01", "2024-01-03", "2024-01-01")),
                                   lat1 = c(645030L, 645030L, 645030L, 645030L, 645030L),
                                   lon1 = c(22059L, 22059L, 22059L, 220030L, 22059L),
                                   lat2 = c(645100L, NA, NA, NA, NA), lon2 = c(220600L, NA, NA, NA, NA), hundredths = FALSE)
  testthat::expect_equal(s$lon1, c("right", "uncertain right", "right", NA, "uncertain right"))
  testthat::expect_equal(s$why1, c("the station's other position", "the gear", "the vessel's days", NA, "the gear"))
  # the same where the record is silent, on a midwater trawl: left
  m <- fd$logbook_short_longitudes(tid = "x", vid = 9, date = as.Date("2024-01-01"), lat1 = 645030L, lon1 = 22059L,
                                   lat2 = NA, lon2 = NA, hundredths = FALSE, midwater = TRUE)
  testthat::expect_equal(c(m$lon1, m$why1), c("uncertain left", "the gear"))
})

testthat::test_that("a left-only reading on a gear other than the midwater trawl is read right, minutes carried", {
  # 22659: right 22°65.9' (minutes 65, invalid; 23°05.9' carried), left 2°26'59" (valid)
  s <- fd$logbook_short_longitudes(tid = c("a", "b"), vid = c(1, 2), date = as.Date(c("2024-01-01", "2024-01-01")),
                                   lat1 = c(645030L, 645030L), lon1 = c(22659L, 22659L), lat2 = NA, lon2 = NA,
                                   hundredths = FALSE, midwater = c(FALSE, TRUE))
  testthat::expect_equal(s$lon1, c("uncertain right", NA))
  p <- fd$decode_logbook_position(c(645030L, 645030L), c(22659L, 22659L), short_lon = s$lon1, short_why = s$why1)
  testthat::expect_equal(p$lon, -c(22 + 65.9 / 60, dms(2, 26, 59)))
  testthat::expect_equal(p$form, c("ddmmss; short longitude uncertain right by the gear, minutes carried",
                                   "ddmmss; short longitude left"))
})

testthat::test_that("a shorter longitude beside a four-digit latitude has lost its leading zeros", {
  testthat::expect_equal(fd$decode_logbook_position(6431L, 959L)$lon, -(9 + 59 / 60))
  testthat::expect_equal(fd$decode_logbook_position(6431L, 959L)$form, "ddmm")
})

testthat::test_that("row P4's short latitudes: the zero dropped, the longitude by its pattern, 5 / 5 uncertain", {
  p <- fd$decode_logbook_position(c(6631L, 64312L, 6631L, 6631L, 64312L), c(221530L, 221530L, 2231L, 22312L, 22312L),
                                  short_latitude = TRUE)
  testthat::expect_equal(p$lat[1:4], c(66 + 3.1 / 60, 64 + 3.12 / 60, 66 + 3.1 / 60, 66 + 3.1 / 60))
  testthat::expect_equal(p$lon[1:4], -c(dms(22, 15, 30), dms(22, 15, 30), 22 + 3.1 / 60, 22 + 31.2 / 60))
  testthat::expect_equal(p$lat[5], 64 + 31.2 / 60)
  testthat::expect_equal(p$form, c(rep("degrees, minutes with the zero dropped (P4)", 4), "uncertain (P4)"))
  testthat::expect_equal(fd$decode_logbook_position(6631L, 221530L)$lat, 66 + 31 / 60)
  q <- fd$decode_logbook_position(64312L, 2231L, short_latitude = TRUE)
  testthat::expect_equal(c(q$lat, q$lon), c(64 + 3.12 / 60, -(22 + 3.1 / 60)))
  testthat::expect_equal(q$form, "degrees, minutes with the zero dropped (P4)")
})

testthat::test_that("row P3: a latitude and longitude exchanged are read back", {
  p <- fd$decode_logbook_position(223000L, 643000L, exchanged = c(TRUE, FALSE)[1])
  testthat::expect_equal(c(p$lat, p$lon), c(64.5, -22.5))
  testthat::expect_equal(p$form, "exchanged (P3)")
  testthat::expect_equal(fd$decode_logbook_position(223000L, 643000L)$lat, 22.5)
})

testthat::test_that("a longer longitude is in the form of its own length", {
  p <- fd$decode_logbook_position(66242L, -172041L)
  testthat::expect_equal(p$lat, 66 + 24.2 / 60)
  testthat::expect_equal(p$lon, dms(17, 20, 41))
  testthat::expect_equal(fd$decode_logbook_position(650502L, 1325620L)$lon, -(13 + 25.620 / 60))
})

testthat::test_that("seven, five, four and two digits", {
  testthat::expect_equal(fd$decode_logbook_position(6606143L, 2412609L)$lat, 66 + 6.143 / 60)
  testthat::expect_equal(fd$decode_logbook_position(66123L, 22345L)$lat, 66 + 12.3 / 60)
  testthat::expect_equal(fd$decode_logbook_position(6530L, 2130L)$lon, -(21 + 30 / 60))
  testthat::expect_equal(fd$decode_logbook_position(66L, 22L)$lat, 66)
})

testthat::test_that("60 seconds carry, a negative latitude is north, and the rest is NA", {
  testthat::expect_equal(fd$decode_logbook_position(661260L, 0L)$lat, dms(66, 13, 0))
  testthat::expect_equal(fd$decode_logbook_position(-655208L, 181355L)$lat, dms(65, 52, 8))
  p <- fd$decode_logbook_position(c(616L, 0L, NA, 880927L), c(155632L, 0L, 1L, 183002L))
  testthat::expect_true(all(is.na(p$lat)))
})

testthat::test_that("a trip is in hundredths where row P3 holds or a last two digits of 61-99, not for 60", {
  h <- fd$logbook_position_hundredths(tid = c("a", "a", "b", "c", "c"),
                                      by_app = c(FALSE, FALSE, TRUE, FALSE, FALSE),
                                      lat1 = c(661858L, 661875L, 661858L, 661260L, 661259L),
                                      lon1 = c(214512L, 214512L, 214512L, 214512L, 214512L),
                                      lat2 = NA, lon2 = NA)
  testthat::expect_equal(h, c(TRUE, TRUE, TRUE, FALSE, FALSE))
})
