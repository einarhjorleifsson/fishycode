# test_whole_weight.R — calc_whole_weight(): the logbook's own rule, and the factor table's rule beside it.
#
# Input:  the functions in R/; no data, no $FISHYDATA, no Oracle
# Output: nothing kept
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_whole_weight.R")'
#
# A toy factor table in the shape reference/species/whole_weight_factor.R writes, and catch rows that each take one
# branch of the rule: gutted cod before and after 1997-09-01, a recorded whole weight, ungutted, released, afli's
# stateless weight, adb's row with no condition, lumpfish logged gutted (roe), Nephrops named tails by a correction,
# and a gutted species the table has no row for (the fallback). The same rows run in memory and in DuckDB.

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
for (f in list.files(file.path(root, "R"), full.names = TRUE)) sys.source(f, envir = fd)
library(testthat)

factors <- data.frame(
  scope     = c("logbook", "logbook", "logbook", "logbook", "logbook", "landings"),
  kind      = c("period", "period", "period", "period", "fallback", "period"),
  sid       = c(1L, 1L, 951L, 40L, NA, 1L),
  condition = c("GUTT", "GUTT", "GUTT", "tails", "GUTT", NA),
  from      = as.Date(c("1992-09-01", "1997-09-01", "2012-09-01", "1992-09-01", NA, "1997-09-01")),
  to        = as.Date(c("1997-08-31", NA, NA, NA, NA, NA)),
  factor    = c(1.25, 1.1905, 3.4014, 3.25, 1.25, 9))
catch <- data.frame(
  .sid      = 1:10,
  schema    = c("fs_afladagbok", "fs_afladagbok", "adb", "fs_afladagbok", "fs_afladagbok", "afli", "adb",
                "fs_afladagbok", "afli", "adb"),
  sid       = c(1L, 1L, 1L, 1L, 1L, 1L, 1L, 951L, 40L, 62L),
  condition = c("GUTT", "GUTT", "GUTT", "UNGU", "RELE", NA, NA, "GUTT", NA, "GUTT"),
  catch     = c(100L, 100L, 100L, 100L, 100L, 100L, 100L, 100L, 100L, 100L),
  catch_whole = c(NA, NA, 125, NA, NA, NA, NA, NA, NA, NA),
  date      = as.Date(c("1995-01-01", "2020-01-01", "2020-01-01", "2020-01-01", "2020-01-01", "2020-01-01",
                        "2020-01-01", "2021-05-01", "2020-01-01", "2020-01-01")),
  condition_corrected = c(NA, NA, NA, NA, NA, NA, NA, NA, "tails", NA))

check <- function(out) {
  out <- out[order(out$.sid), ]
  expect_equal(out$whole_weight, c(125, 119.05, 119.05, 100, 100, 100, 100, 340.14, 325, 125))
  expect_equal(out$whole_weight_logbook, c(125, 125, 125, 100, 100, 100, 100, 125, 100, 125))
  expect_equal(out$whole_weight_factor, c(1.25, 1.1905, 1.1905, NA, NA, NA, NA, 3.4014, 3.25, 1.25))
  expect_equal(out$whole_weight_basis, c("reconstructed", "reconstructed", "reconstructed", "recorded", "recorded",
                                         "recorded", "synthesised", "reconstructed", "reconstructed", "reconstructed"))
}

test_that("the factor table's rule, in memory", {
  check(fd$calc_whole_weight(catch, by = c(".sid"), factors = factors))
})

test_that("the factor table's rule, in DuckDB, is the same", {
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  lazy <- dplyr::copy_to(con, catch, "catch")
  check(fd$calc_whole_weight(lazy, by = c(".sid"), factors = factors) |> dplyr::collect() |> as.data.frame())
})

test_that("without the table, the logbook's own rule, as before", {
  out <- fd$calc_whole_weight(catch, by = c(".sid"))
  out <- out[order(out$.sid), ]
  expect_equal(out$whole_weight, c(125, 125, 125, 100, 100, 100, 100, 125, 100, 125))
  expect_equal(out$whole_weight_basis, c("reconstructed", "reconstructed", "recorded", "recorded", "recorded",
                                         "recorded", "synthesised", "reconstructed", "recorded", "reconstructed"))
  expect_false("whole_weight_factor" %in% names(out))
})

test_that("a group sums its rows and keeps its weakest basis", {
  two <- catch[c(2, 4), ]; two$.sid <- 1L
  out <- fd$calc_whole_weight(two, by = ".sid", factors = factors, logged = sum(catch))
  expect_equal(out$whole_weight, 219.05)
  expect_equal(out$logged, 200)
  expect_equal(out$whole_weight_basis, "reconstructed")
})
