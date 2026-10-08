# whack_review_examples.R — four anonymised AIS tracks for the whacky-filter review package.
#
# Input:  staging/ais/ping_tagged (read-only). Needs ramb >= 2026.10.08 (rb_whack_clean()).
# Output: tempdir()/whacky_examples.parquet  114 pings: example, vid, time, lon, lat
#         Copied by hand to ~/stasi/test/inst/extdata/ (the review package; no ramb mention there).
#
# THIS SCRIPT IS THE KEY TO THE ANONYMISATION (real vids and dates). It stays in fishycode and
# never goes into the review package.
#
#   spike        vid 5466, 2012-07-06: one ping reached at 26 kn and left at 113 kn
#   fast         vid 6684, 2016-07-13: steams at 24-25 kn, so kn_max = 25 flags real track
#   placeholder  vid 4896, 2014: a (0, 0) ping second to last; vmask keeps it, flags good track
#   noisy        vid 239, 2012-08-18: logger alternates true and one-axis-wrong positions
#
# Anonymised: vid -> 1..4; each track starts 2000-01-01 00:00 UTC; lon shifted by a constant per
# track, lat kept. Neither shift changes a time step, a distance or a bearing, so the labels must be
# identical - checked below. The (0, 0) placeholder is not a position and stays (0, 0).

source(here::here("R", "paths.R"))
suppressMessages({library(dplyr); library(duckdbfs); library(ramb)})
ais <- open_dataset(fd_staging("ais", "ping_tagged"))
get <- function(v, yr) ais |> filter(year == yr, vid == v) |> select(vid, time, lon, lat) |>
  collect() |> arrange(time, lon, lat)

s <- get(5466, 2012); w <- which(s$time == as.POSIXct("2012-07-06 06:55:18", tz = "UTC"))
x <- get(4896, 2014); z <- which(x$lon == 0 & x$lat == 0)
stopifnot(length(w) == 1, length(z) == 1)
raw <- list(
  spike       = s[(w - 10):(w + 10), ],
  fast        = get(6684, 2016) |> filter(as.Date(time) == as.Date("2016-07-13")),
  placeholder = x[(z - 20):(z + 1), ],
  noisy       = get(239, 2012) |> filter(as.Date(time) == as.Date("2012-08-18")) |> slice(1:24)
)

anon <- function(r, k, name) {
  ph <- r$lon == 0 & r$lat == 0
  shift <- round(median(r$lon[!ph]), 2)
  tibble(example = name, vid = k,
         time = as.POSIXct("2000-01-01", tz = "UTC") + as.numeric(r$time - r$time[1], units = "secs"),
         lon = ifelse(ph, 0, r$lon - shift), lat = r$lat)
}
ex <- bind_rows(purrr::imap(unname(raw), \(r, k) anon(r, k, names(raw)[k])))

# The labels survive the anonymisation ---------------------------------------------
same <- function(a, b, ...) identical(rb_whack_clean(a, ...)$whack_stage, rb_whack_clean(b, ...)$whack_stage)
for (k in seq_along(raw)) {
  a <- raw[[k]]; b <- filter(ex, vid == k)
  stopifnot(nrow(a) == nrow(b), same(a, b), same(a, b, kn_max = 26),
            same(filter(a, !(lon == 0 & lat == 0)), filter(b, !(lon == 0 & lat == 0))))
}

out <- file.path(tempdir(), "whacky_examples.parquet")
con <- cached_connection()
duckdb::duckdb_register(con, "ex", ex)
DBI::dbExecute(con, sprintf(
  "COPY (SELECT example, vid::INTEGER AS vid, time::TIMESTAMP AS time, lon, lat FROM ex ORDER BY vid, time)
   TO '%s' (FORMAT parquet)", out))
ex |> count(example, vid) |> print()
message("written to ", out)
