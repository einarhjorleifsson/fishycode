# whack_fast_vessels.R — how many fishing vessels go faster than KN_MAX (25 kn), and what the filter cuts from them.
#
# Input:  staging/ais/ping_clean, staging/ais/ping_whacky, curated/logbook/trip.parquet,
#         curated/landing/landings.parquet, curated/vessel/vessel.parquet (all read-only)
# Output: console tables; nothing written.
#
# A leg (two consecutive stk pings of a vid, 1-30 min apart) is CONFIRMED FAST when its implied speed is 25-50 kn
# and the vessel's own recorded speed agrees: mean of the two ends > 25 kn and within 5 kn of the implied. A jump,
# two transmitters on one mid, or a bad position gives an implied speed the recorded one does not back. stk only:
# astd and emodnet carry no recorded speed. Flagged pings are put back (except "invalid", which is no position),
# so a confirmed fast leg ending on a flagged ping is real track the 25 kn filter removed. A fishing vessel-year
# is a vid with a logbook trip or a landing that year. Result 2026-10-08 in decision 067.

source(here::here("R", "paths.R"))
suppressMessages({library(DBI); library(dplyr)})

con <- dbConnect(duckdb::duckdb())
spill <- file.path(Sys.getenv("TMPDIR", tempdir()), "duck_spill"); dir.create(spill, showWarnings = FALSE)
dbExecute(con, sprintf("SET temp_directory = '%s'", spill))

clean <- fd_staging("ais", "ping_clean"); whack <- fd_staging("ais", "ping_whacky")
years <- sort(as.integer(sub("year=", "", list.files(clean, pattern = "^year="))))

# Per vid x year ----------------------------------------------------------------
leg_sql <- function(y) sprintf("
  WITH p AS (
    SELECT vid, time, lon, lat, speed, false AS flagged FROM read_parquet('%s/year=%d/*.parquet') WHERE provider = 'stk'
    UNION ALL
    SELECT vid, time, lon, lat, speed, true FROM read_parquet('%s/year=%d/*.parquet') WHERE provider = 'stk' AND whack_stage <> 'invalid'
  ), l AS (
    SELECT vid, flagged, speed, lag(speed) OVER w AS speed0,
      epoch(time - lag(time) OVER w) / 3600.0 AS h,
      2 * 6371 * asin(least(1, sqrt(power(sin(radians(lat - lag(lat) OVER w) / 2), 2) +
        cos(radians(lag(lat) OVER w)) * cos(radians(lat)) * power(sin(radians(lon - lag(lon) OVER w) / 2), 2)))) AS km
    FROM p WINDOW w AS (PARTITION BY vid ORDER BY time, lon, lat)
  ), m AS (
    SELECT *, (speed + speed0) / 2 AS rec,
      (km / 1.852 / h BETWEEN 25 AND 50) AND ((speed + speed0) / 2 > 25) AND abs(km / 1.852 / h - (speed + speed0) / 2) < 5 AS fast
    FROM l WHERE h > 1 / 60.0 AND h <= 0.5
  )
  SELECT vid, %d AS year, count(*) AS legs, count(*) FILTER (WHERE fast) AS fast_legs,
    count(*) FILTER (WHERE fast AND flagged) AS fast_flagged, count(*) FILTER (WHERE flagged) AS flagged_legs,
    max(rec) FILTER (WHERE fast) AS max_fast_kn
  FROM m GROUP BY vid", clean, y, whack, y, y)
r <- bind_rows(lapply(years, \(y) dbGetQuery(con, leg_sql(y)))) |> mutate(year = as.integer(year))

fishing <- bind_rows(
  duckdbfs::open_dataset(fd_curated("logbook", "trip.parquet")) |> transmute(vid, year = as.integer(year(T1))) |> distinct() |> collect(),
  duckdbfs::open_dataset(fd_curated("landing", "landings.parquet")) |> transmute(vid, year = as.integer(year(date))) |> distinct() |> collect()) |>
  filter(!is.na(vid)) |> distinct() |> mutate(fishing = TRUE)
loa <- duckdbfs::open_dataset(fd_curated("vessel", "vessel.parquet")) |> select(vid, loa) |> collect() |> distinct(vid, .keep_all = TRUE)
r <- r |> left_join(fishing, by = c("vid", "year")) |> mutate(fishing = coalesce(fishing, FALSE)) |> left_join(loa, by = "vid")

# Summary -----------------------------------------------------------------------
f <- r |> filter(fishing)
cat("fishing vessel-years:", nrow(f), "; vessels:", n_distinct(f$vid), "\n")
for (k in c(1, 10, 100)) cat(sprintf("  >= %3d confirmed fast legs in a year: %5d vessel-years, %4d vessels\n",
                                     k, sum(f$fast_legs >= k), n_distinct(f$vid[f$fast_legs >= k])))
cat(sprintf("confirmed fast legs: %s of %s; flagged pings on them: %s of %s flagged stk pings (%.1f %%)\n",
            format(sum(f$fast_legs), big.mark = ","), format(sum(f$legs), big.mark = ","),
            format(sum(f$fast_flagged), big.mark = ","), format(sum(f$flagged_legs), big.mark = ","),
            100 * sum(f$fast_flagged) / sum(f$flagged_legs)))
print(f |> mutate(length = cut(loa, c(0, 8, 10, 12, 15, 100), right = FALSE)) |> group_by(length) |>
        summarise(vessels = n_distinct(vid), fast_10 = n_distinct(vid[fast_legs >= 10]),
                  fast_legs = sum(fast_legs), flagged_on_fast = sum(fast_flagged)) |> as.data.frame())
nf <- r |> filter(!fishing)
cat(sprintf("not fishing: %s confirmed fast legs, %s flagged on them, %d vessels with >= 10 in a year\n",
            format(sum(nf$fast_legs), big.mark = ","), format(sum(nf$fast_flagged), big.mark = ","),
            n_distinct(nf$vid[nf$fast_legs >= 10])))
