# Tests of the app profile's rules (R/logbook_app_profile.R), on hand-made stations: no data needed.
# Run from the repo root: Rscript -e 'testthat::test_file("tests/test_logbook_app_profile.R")'

Sys.setenv(TZ = "UTC")
root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
for (f in c("logbook_app_profile.R", "duration_limit.R", "logbook_effort.R")) source(file.path(root, "R", f))
library(testthat)

ts <- function(x) as.POSIXct(x, tz = "UTC")
na_t <- ts(NA_character_)
# one station; every argument a column
st <- function(app = "Trackwell raun", schema = "fs_afladagbok", date = "2023-03-01", gear = "GNS",
               gear_class = "static", t1 = na_t, t2 = na_t, t3 = na_t, t4 = na_t, departure = na_t, landing = na_t,
               record_entered = na_t, prev_t3 = na_t, prev_t4 = na_t, .tid = "1") {
  tibble::tibble(app = app, schema = schema, date = as.Date(date), gear = gear, gear_class = gear_class,
                 t1 = ts(t1), t2 = ts(t2), t3 = ts(t3), t4 = ts(t4), departure = ts(departure), landing = ts(landing),
                 record_entered = ts(record_entered), prev_t3 = ts(prev_t3), prev_t4 = ts(prev_t4), .tid = .tid,
                 lat1 = 65, lon1 = -22, lat2 = NA_real_, lon2 = NA_real_)
}
p <- app_profile(file.path(root, APP_PROFILE))
flags <- function(d) flag_app_times(d, p)

test_that("the profile names every row the code applies, and every flag or note row is applied or placed", {
  expect_true(all(c("T1", "T11", "T14", "W1", "K2") %in% names(p)))
  expect_true(all(vapply(p, \(r) !is.null(r$reviewed), TRUE)))
})

test_that("the placeholder: exact (T1), a minute off (T2), whole days added (T3), on the afli route (T2-afli, T20)", {
  f <- flags(rbind(st(t1 = "2023-03-01 06:00:00", t3 = "2023-03-01 10:30:00"),
                   st(t1 = "2023-03-01 06:00:00", t3 = "2023-03-01 10:31:00"),
                   st(t1 = "2023-03-01 06:00:00", t3 = "2023-03-03 10:30:30"),
                   st(app = "Fishing Log 2.7", schema = "afli", t1 = "2018-03-01 06:00:00", t3 = "2018-03-01 10:29:00"),
                   st(app = "Fishing Log 2.7", schema = "afli", t1 = "2018-03-01 06:00:00", t3 = "2018-03-02 09:30:00"),
                   st(app = "Fishing Log 2.7", schema = "afli", gear = "LLS", t1 = "2018-03-01 06:00:00",
                      t3 = "2018-03-01 09:30:00")))
  expect_equal(f$t1_rule, c("T1", "T2", "T3", "T2-afli", "T20", NA))
  expect_equal(f$t1_flag[1:5], rep("placeholder", 5))
  expect_equal(f$t1_action[1:5], rep("flag", 5))
})

test_that("the app's own rows come first: Marína's start and end are the trip's (T4, T10)", {
  f <- flags(st(app = "Marína raun", gear = "LHM", gear_class = "jig", date = "2024-05-01",
                t1 = "2024-05-01 00:00:00", t4 = "2024-05-01 18:00:00"))
  expect_equal(c(f$t1_rule, f$t1_flag, f$t4_rule, f$t4_flag), c("T4-marina", "trip_time", "T10", "trip_time"))
})

test_that("a set at the departure or landing (T16) and the entry time spared from the stamp (T12)", {
  f <- flags(rbind(st(t1 = "2023-03-01 05:00:20", departure = "2023-03-01 05:00:00", t3 = "2023-03-01 12:00:00"),
                   st(t1 = "2023-03-02 09:55:00", landing = "2023-03-02 10:00:00", t3 = "2023-03-02 12:00:00"),
                   st(t1 = "2023-03-01 06:00:13", record_entered = "2023-03-01 06:00:40", t3 = "2023-03-01 12:00:00"),
                   st(gear = "LLS", t1 = "2023-03-01 06:00:13", t3 = "2023-03-01 12:00:00"),
                   st(gear = "FPO", t1 = "2023-03-01 06:00:13", t3 = "2023-03-01 12:00:00")))
  expect_equal(f$t1_flag, c("copy_departure", "copy_landing", NA, "stamped", NA))
  expect_equal(f$t1_action, c("flag", "flag", NA, "note", NA))
})

test_that("a copy of the haul (T6-value), the previous haul (T7) and the half-hour grid (T13)", {
  f <- flags(rbind(st(t1 = "2023-03-01 12:00:00", t3 = "2023-03-01 12:00:30"),
                   st(app = "Fontos raun", t1 = "2023-03-01 06:00:00", prev_t4 = "2023-03-01 06:00:30",
                      t3 = "2023-03-01 12:00:00"),
                   st(t1 = "2023-03-01 06:30:07", t3 = "2023-03-01 12:00:07")))
  expect_equal(f$t1_rule, c("T6-value", "T7", "T13"))
  expect_equal(f$t1_action, c("flag", "flag", "note"))
})

test_that("every set of Reiknistofa and Fishtech flagged by the equality found (T6-app); jigs at the departure (T17)", {
  f <- flags(rbind(st(app = "Reiknistofa fiskmarkaða raun", date = "2024-08-01", t1 = "2024-08-01 07:00:00",
                      t3 = "2024-08-01 07:00:00"),
                   st(app = "Fishtech raun", date = "2024-08-01", t1 = "2024-08-01 04:00:00",
                      departure = "2024-08-01 04:00:00"),
                   st(app = "Fishtech raun", date = "2024-08-01", gear = "LHM", gear_class = "jig",
                      t1 = "2024-08-01 04:00:00", departure = "2024-08-01 04:00:30"),
                   st(app = "Jóhann Gíslason raun", date = "2023-08-01", gear = "LHM", gear_class = "jig",
                      t1 = "2023-08-01 04:00:00", departure = "2023-08-01 04:00:30")))
  expect_equal(f$t1_flag, c("copy_haul", "copy_departure", "equals_departure", "copy_departure"))
  expect_equal(f$t1_action, c("flag", "flag", "note", "flag"))
})

test_that("a date (T8), a pressed tow and haul (T14) and an end at the landing (T18)", {
  f <- flags(rbind(st(gear = "OTB", gear_class = "towed", t2 = "2023-03-01 00:00:00", t3 = "2023-03-01 05:00:00"),
                   st(gear = "OTB", gear_class = "towed", t2 = "2023-03-01 03:00:00", t3 = "2023-03-01 03:03:00"),
                   st(t3 = "2023-03-01 10:00:00", t4 = "2023-03-01 10:02:00"),
                   st(app = "Reiknistofa fiskmarkaða raun", gear = "LHM", gear_class = "jig", date = "2024-08-01",
                      t1 = "2024-08-01 06:00:00", t4 = "2024-08-01 17:55:00", landing = "2024-08-01 18:00:00")))
  expect_equal(f$t2_rule, c("T8", NA, NA, NA))
  expect_equal(f$t3_rule, c(NA, "T14", NA, NA))
  expect_equal(f$t4_rule, c(NA, NA, "T14", "T18"))
})

test_that("the trip's departure and landing that copy a station's time (T11, T11-afli)", {
  d <- rbind(st(gear = "OTB", gear_class = "towed", t2 = "2023-03-01 03:00:10", t3 = "2023-03-01 08:00:00",
                departure = "2023-03-01 03:00:00", landing = "2023-03-02 10:00:00", .tid = "a"),
             st(gear = "OTB", gear_class = "towed", t2 = "2023-03-01 09:00:00", t3 = "2023-03-02 09:55:00",
                departure = "2023-03-01 03:00:00", landing = "2023-03-02 10:00:00", .tid = "a"),
             st(app = "Fishing Log 2.7", schema = "afli", date = "2018-03-01", t1 = "2018-02-28 23:59:41",
                departure = "2018-03-01 00:00:00", .tid = "b"),
             st(app = "Fontos raun", gear = "OTB", gear_class = "towed", t2 = "2023-03-01 03:00:00",
                departure = "2023-03-01 03:00:00", .tid = "c"))
  tr <- flag_app_trips(d, p)
  expect_equal(tr$.tid, c("a", "b"))
  expect_equal(tr$T1_rule, c("T11", "T11-afli"))
  expect_equal(tr$T2_rule, c("T11", NA))
})

test_that("the positions: Marína's quarter minutes (P5), a copied end (P6), a jig's position saved late (P7)", {
  d <- rbind(st(app = "Marína raun", date = "2024-01-01"), st(app = "Reiknistofa fiskmarkaða raun", date = "2024-08-01"),
             st(gear = "LHM", gear_class = "jig"))
  d$lat2 <- c(65.1, 65, 65); d$lon2 <- c(-22.1, -22, -22); d$t1_rule <- NA_character_
  ps <- flag_app_positions(d, p)
  expect_equal(ps$pos1_rule, c("P5", NA, "P7"))
  expect_equal(ps$pos2_rule, c("P5", "P6-app", "P6-value"))
  expect_equal(ps$pos2_action, c("note", "flag", "note"))
})

test_that("judged_time_sql() leaves out a flagged time, calc_effort() too unless asked", {
  expect_match(judged_time_sql("t1"), "fs.t1_action = 'flag'", fixed = TRUE)
  expect_match(judged_time_sql("t3"), "OR fs.t3_action = 'flag'", fixed = TRUE)
  s <- tibble::tibble(schema = "fs_afladagbok", gear = "GNS", .duration_source = "times", duration_m = NA_real_,
                      t1 = ts("2023-03-01 06:00:00"), t2 = na_t, t3 = ts("2023-03-01 10:30:00"),
                      t4 = ts("2023-03-01 12:00:00"), t1_action = "flag", t2_action = NA, t3_action = NA, t4_action = NA,
                      effort_count = 10, effort_count_unit = "nets")
  expect_true(is.na(calc_effort(s)$effort_duration))
  expect_equal(calc_effort(s, flagged = TRUE)$effort_duration, 6)
})
