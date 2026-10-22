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

testthat::test_that("a shorter longitude beside a six-digit latitude has lost its leading zeros", {
  testthat::expect_equal(fd$decode_logbook_position(661858L, -4119L)$lon, dms(0, 41, 19))
  testthat::expect_equal(fd$decode_logbook_position(611207L, 40014L)$lon, -dms(4, 0, 14))
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

testthat::test_that("a trip is in hundredths for Taktikal's app or a last two digits of 61-99, not for 60", {
  h <- fd$logbook_position_hundredths(tid = c("a", "a", "b", "c", "c"),
                                      source = c("Trackwell raun", "Trackwell raun", "FRA TAKTIKAL", "x", "x"),
                                      lat1 = c(661858L, 661875L, 661858L, 661260L, 661259L),
                                      lon1 = c(214512L, 214512L, 214512L, 214512L, 214512L),
                                      lat2 = NA, lon2 = NA)
  testthat::expect_equal(h, c(TRUE, TRUE, TRUE, FALSE, FALSE))
})
