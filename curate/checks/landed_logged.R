# landed_logged.R — how the landed weight compares with the logged weight, per species, by year and logbook system.
# Side: preprocessing (logbook and landings). See decision 104.
#
# Input:  curated/logbook/{station,catch,trip,lid_map}.parquet, curated/landing/catch.parquet
# Output: curated/check/landed_logged.parquet   one row per (year, logbook system, species)
#
# A REPORT, not a correction (maintainer, 2026-10-14): the logbook is the skipper's estimate at sea and the landing is
# weighed, so the two differ by design. A difference is not an error; it is of interest, above all where it is
# systematic (a species, a period, a system). Per trip and species, over the trips whose landing is linked
# (lid_map) and whose logged weight is at least 100 kg (smaller ones give ratios that say little): trips, kg logged,
# kg landed, the ratio of the totals, and the median and 10th / 90th percentiles of the trips' ratios.
# For the pelagic species (30-36) a trip may land what another vessel caught, or pass its catch on (transhipment);
# their wide percentiles are that, not the scale.
library(DBI)
con <- dbConnect(duckdb::duckdb())
f <- function(...) shQuote(fd_curated(...), type = "sh")
sql <- sprintf("
  WITH st AS (SELECT \".sid\", schema, \".tid\" FROM read_parquet(%s) WHERE twin IS DISTINCT FROM 'duplicate'),
  lb AS (SELECT st.\".tid\", st.schema, c.sid AS species, sum(c.catch) AS kg_lb
         FROM read_parquet(%s) c JOIN st USING (\".sid\", schema) GROUP BY ALL),
  ld AS (SELECT m.\".tid\", m.schema, c.sid AS species, sum(c.catch) AS kg_ld
         FROM read_parquet(%s) m JOIN read_parquet(%s) c ON c.\".lid\" = m.\".lid\" AND c.schema = m.schema_land GROUP BY ALL),
  x AS (SELECT lb.*, ld.kg_ld, ld.kg_ld / lb.kg_lb AS r, year(t.T1) AS year
        FROM lb JOIN ld USING (\".tid\", schema, species) JOIN read_parquet(%s) t USING (\".tid\", schema)
        WHERE lb.kg_lb >= 100 AND t.twin IS DISTINCT FROM 'duplicate')
  SELECT year, schema, species, count(*) AS trips, sum(kg_lb) AS kg_logged, sum(kg_ld) AS kg_landed,
         sum(kg_ld) / sum(kg_lb) AS landed_over_logged, median(r) AS median_trip,
         quantile_cont(r, 0.1) AS p10_trip, quantile_cont(r, 0.9) AS p90_trip
  FROM x GROUP BY year, schema, species",
  f("logbook", "station.parquet"), f("logbook", "catch.parquet"), f("logbook", "lid_map.parquet"),
  f("landing", "catch.parquet"), f("logbook", "trip.parquet"))
write_curated_sql(con, sql, fd_curated("check", "landed_logged.parquet"),
                  inputs = c(fd_curated("logbook", "station.parquet"), fd_curated("logbook", "catch.parquet"),
                             fd_curated("logbook", "lid_map.parquet"), fd_curated("landing", "catch.parquet"),
                             fd_curated("logbook", "trip.parquet")),
                  order_by = "year, schema, species")
dbDisconnect(con, shutdown = TRUE)
