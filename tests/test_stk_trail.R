# test_stk_trail.R — stk_trail_sql()'s decoding (plan 048 §2.1) and the stream rule of the tag pass, on rows made up in
# DuckDB: every stream, both sides of the heading switch, the codes; ping_stream_sql() on the union's own columns.
#
# Input:  the functions in R/stk_trail.R; no data, no $FISHYDATA
# Output: nothing kept: the parquet goes to a temporary directory
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_stk_trail.R")'

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
sys.source(file.path(root, "R", "stk_trail.R"), envir = fd)

tmp <- tempfile("stk_trail_test_")
dir.create(file.path(tmp, "year=2010"), recursive = TRUE)
withr::defer(unlink(tmp, recursive = TRUE))
con <- DBI::dbConnect(duckdb::duckdb())
withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))

# positions in radians, as the dump holds them: on the AIS grid (a ten-thousandth of a minute), on the centiminute
# grid (a hundredth), and on neither
rad <- function(deg) deg * pi / 180
ais <- c(lon = -21 - 12345 / 600000, lat = 64 + 23456 / 600000)
cm <- c(lon = -21 - 1234 / 6000, lat = 64 + 2345 / 6000)
ung <- c(lon = -21.123456789, lat = 64.987654321)
rows <- data.frame(
  trailid = 1:9,
  mobileid = 100,
  posdate = as.POSIXct(c("2010-06-09 17:40:12", "2010-06-09 17:40:13", "2010-06-09 17:00:00", "2010-06-10 00:00:00",
                         "2010-06-09 12:00:00", "2010-06-10 12:00:00", "2010-06-01 00:00:00", "2010-07-01 00:00:00",
                         "2010-06-09 17:00:00"), tz = "UTC"),
  poslon = rad(c(ais[["lon"]], ais[["lon"]], ais[["lon"]], ais[["lon"]], cm[["lon"]], cm[["lon"]], ung[["lon"]],
                 ung[["lon"]], ais[["lon"]])),
  poslat = rad(c(ais[["lat"]], ais[["lat"]], ais[["lat"]], ais[["lat"]], cm[["lat"]], cm[["lat"]], ung[["lat"]],
                 ung[["lat"]], ais[["lat"]])),
  speed = 2,
  # degrees: a heading before the switch; a course after it; 511 before; 360.0 after; whole degrees and a 511 on the
  # centiminute stream; a course in tenths and a 0 on no grid; and 0 on the AIS stream before the switch
  heading = rad(c(123, 123.4, 511, 360, 45, 511, 12.3, 0, 0)),
  harborid = NA_character_,
  in_out_of_harbor = c(rep(NA, 8), "I"),
  recdate = as.POSIXct("2010-06-09 17:40:20", tz = "UTC")
)
duckdb::duckdb_register(con, "rows", rows)
DBI::dbExecute(con, sprintf("COPY rows TO '%s' (FORMAT parquet)", file.path(tmp, "year=2010", "part.parquet")))
out <- DBI::dbGetQuery(con, paste(fd$stk_trail_sql(file.path(tmp, "year=*", "*.parquet")), "ORDER BY \".id\""))

test_that("the stream is the position's grid, the centiminute grid first", {
  expect_equal(out$stream, c(rep("ais", 4), rep("centiminute", 2), rep("ungridded", 2), "ais"))
})

test_that("heading is true heading on the AIS stream before the switch, cog the course after and elsewhere", {
  expect_equal(out$heading, c(123, NA, NA, NA, NA, NA, NA, NA, 0), tolerance = 1e-9)
  expect_equal(out$cog, c(NA, 123.4, NA, NA, 45, NA, 12.3, 0, NA), tolerance = 1e-9)
})

test_that("an event row keeps its io, and the columns are the readers'", {
  expect_equal(out$io, c(rep(NA, 8), "I"))
  expect_equal(names(out), c(".id", "mid", "time", "lon", "lat", "speed", "stream", "heading", "cog", "hid", "io",
                             "recdate", "year"))
  expect_equal(out$lon[1], ais[["lon"]], tolerance = 1e-12)
})

test_that("the tag pass's stream: the provider, STK's by the union's stream, an arrival kept as a fix", {
  u <- data.frame(provider = c("astd", "stk", "stk", "stk", "stk"), stream = c(NA, "ais", "centiminute", "ungridded", "ais"),
                  io = c(NA, NA, NA, NA, "I"))
  duckdb::duckdb_register(con, "u", u)
  s <- DBI::dbGetQuery(con, sprintf("SELECT %s AS s FROM u", fd$ping_stream_sql("u")))$s
  expect_equal(s, c("astd", "stk_ais", "stk_vms", "stk_unit", "stk_event"))
})
