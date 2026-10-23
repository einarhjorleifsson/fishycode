# catch_landing_contradicted.R — logged catch the trip's landing contradicts, flagged, never corrected.
# Side: preprocessing (logbook and landings). See plan 014.
#
# Input:  curated/logbook/{station,catch,lid_map}.parquet, curated/landing/catch.parquet
# Output: curated/logbook/catch_flag.parquet  one row per flagged (station, species): .sid, schema, .tid, sid, kg (the
#         station's), sid_landing (the code compared), trip_kg_logged and trip_kg_landed (the trip's, of sid_landing),
#         flag
#
# Declaration and evidence: curate/corrections/catch_landing_contradicted.yml (plan 038 §8 step 1c).
#
# Per (logbook trip, species): logged more than 10 times what the trip's linked landings hold of it, and at least
# 1,000 kg more. lid_map is joined with the landing's own schema (the landings' .lid is shared between agf and lods,
# TODO 123). The logbook's 830 (herring, Atlanto-Scandian stock) is compared as the landings' 30; catch let go
# (negative codes) is never landed and is left out. A trip with no linked landing, or whose landing holds none of the
# species, is not judged here.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
dbExecute(con, "SET threads = 4; SET memory_limit = '6GB'")
p <- function(...) DBI::dbQuoteString(con, ...)

dbExecute(con, sprintf("
  CREATE TEMP TABLE sc AS
  SELECT s.\".sid\" AS sid_st, s.schema, s.\".tid\" AS tid, c.sid, CASE WHEN c.sid = 830 THEN 30 ELSE c.sid END AS sid_land,
         sum(c.catch) AS kg
  FROM read_parquet(%s) c
  JOIN read_parquet(%s) s ON s.\".sid\" = c.\".sid\" AND s.schema = c.schema
  WHERE (s.twin IS NULL OR s.twin <> 'duplicate') AND c.catch > 0 AND c.sid >= 0
  GROUP BY ALL", p(fd_curated("logbook", "catch.parquet")), p(fd_curated("logbook", "station.parquet"))))
dbExecute(con, sprintf("
  CREATE TEMP TABLE landed AS
  SELECT lk.tid, lk.schema, ld.sid AS sid_land, sum(ld.catch) AS kg
  FROM (SELECT DISTINCT \".tid\" AS tid, schema, \".lid\" AS lid, schema_land FROM read_parquet(%s) WHERE \".lid\" IS NOT NULL) lk
  JOIN read_parquet(%s) ld ON ld.\".lid\" = lk.lid AND ld.schema = lk.schema_land
  GROUP BY ALL", p(fd_curated("logbook", "lid_map.parquet")), p(fd_curated("landing", "catch.parquet"))))

flag <- dbGetQuery(con, "
  WITH tl AS (SELECT tid, schema, sid_land, sum(kg) AS trip_kg_logged FROM sc GROUP BY ALL),
       tf AS (SELECT tl.*, l.kg AS trip_kg_landed FROM tl JOIN landed l USING (tid, schema, sid_land)
              WHERE l.kg > 0 AND tl.trip_kg_logged > 10 * l.kg AND tl.trip_kg_logged - l.kg >= 1000)
  SELECT sc.sid_st AS \".sid\", sc.schema, sc.tid AS \".tid\", sc.sid, sc.kg, sc.sid_land AS sid_landing,
         tf.trip_kg_logged, tf.trip_kg_landed,
         'landing_contradicts' AS flag
  FROM sc JOIN tf USING (tid, schema, sid_land)
  ORDER BY schema, \".tid\", \".sid\", sid")
dbDisconnect(con, shutdown = TRUE)

message(sprintf("catch_flag: %s (station, species) rows on %s (trip, species) pairs, %.1f kt",
                format(nrow(flag), big.mark = ","), format(nrow(unique(flag[, c(".tid", "schema", "sid_landing")])), big.mark = ","),
                sum(flag$kg) / 1e6))
write_curated(flag, fd_curated("logbook", "catch_flag.parquet"),
              inputs = c(station = fd_curated("logbook", "station.parquet"),
                         catch = fd_curated("logbook", "catch.parquet"),
                         lid_map = fd_curated("logbook", "lid_map.parquet"),
                         landing_catch = fd_curated("landing", "catch.parquet")))
