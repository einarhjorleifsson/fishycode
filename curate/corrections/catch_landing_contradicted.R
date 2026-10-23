# catch_landing_contradicted.R — logged catch the landings contradict, flagged, never corrected.
# Side: preprocessing (logbook and landings). See plan 014.
#
# Input:  curated/logbook/{station,catch,lid_map,trip}.parquet, curated/landing/{landings,catch}.parquet
# Output: curated/logbook/catch_flag.parquet  one row per flagged (station, species): .sid, schema, .tid, sid, kg (the
#         station's), sid_landing (the code compared), trip_kg_logged (the trip's, of sid_landing), trip_kg_landed
#         (rule 1), species_kg_largest and vessel_kg_largest (rule 2), witness, flag
#
# Declaration and evidence: curate/corrections/catch_landing_contradicted.yml (plan 038 §8 step 1c).
#
# Per (logbook trip, species), with a margin of more than 10 times the witness and at least 1,000 kg more:
#   1. landing_contradicts: the trip has a linked landing that holds the species; the witness is what it holds. lid_map
#      is joined with the landing's own schema (the landings' .lid is shared between agf and lods, TODO 123).
#   2. largest_landing_exceeded: the trip has no linked landing; the witnesses are the largest landing of the species
#      by any vessel, and the vessel's own largest landing (all species) where 50 landing records or more stand behind
#      it. Either flags.
# The logbook's 830 (herring, Atlanto-Scandian stock) is compared as the landings' 30; catch let go (negative codes)
# is never landed and is left out. A linked landing that holds none of the species is not judged here.

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
  CREATE TEMP TABLE lk AS SELECT DISTINCT \".tid\" AS tid, schema, \".lid\" AS lid, schema_land FROM read_parquet(%s)
  WHERE \".lid\" IS NOT NULL", p(fd_curated("logbook", "lid_map.parquet"))))
dbExecute(con, sprintf("
  CREATE TEMP TABLE ld AS SELECT \".lid\" AS lid, schema, sid, sum(catch) AS kg FROM read_parquet(%s) GROUP BY ALL",
  p(fd_curated("landing", "catch.parquet"))))
dbExecute(con, "
  CREATE TEMP TABLE landed AS
  SELECT lk.tid, lk.schema, ld.sid AS sid_land, sum(ld.kg) AS kg
  FROM lk JOIN ld ON ld.lid = lk.lid AND ld.schema = lk.schema_land
  GROUP BY ALL")
# the witnesses of rule 2: the largest landing of each species, and of each vessel with the number of landing records
dbExecute(con, "CREATE TEMP TABLE smax AS SELECT sid AS sid_land, max(kg) AS kg FROM ld GROUP BY 1")
dbExecute(con, sprintf("
  CREATE TEMP TABLE vmax AS
  SELECT l.vid, max(t.kg) AS kg, count(*) AS n
  FROM read_parquet(%s) l JOIN (SELECT lid, schema, sum(kg) AS kg FROM ld GROUP BY ALL) t
    ON t.lid = l.\".lid\" AND t.schema = l.schema
  WHERE l.vid > 0 GROUP BY 1", p(fd_curated("landing", "landings.parquet"))))

flag <- dbGetQuery(con, sprintf("
  WITH tl AS (SELECT tid, schema, sid_land, sum(kg) AS trip_kg_logged FROM sc GROUP BY ALL),
       r1 AS (SELECT tl.*, l.kg AS trip_kg_landed, NULL::DOUBLE AS species_kg_largest, NULL::DOUBLE AS vessel_kg_largest,
                     'trip_landing' AS witness, 'landing_contradicts' AS flag
              FROM tl JOIN landed l USING (tid, schema, sid_land)
              WHERE l.kg > 0 AND tl.trip_kg_logged > 10 * l.kg AND tl.trip_kg_logged - l.kg >= 1000),
       w2 AS (SELECT tl.*, s.kg AS species_kg_largest, CASE WHEN v.n >= 50 AND v.kg > 0 THEN v.kg END AS vessel_kg_largest
              FROM tl JOIN (SELECT \".tid\" AS tid, schema, vid FROM read_parquet(%s)) t USING (tid, schema)
              LEFT JOIN smax s USING (sid_land) LEFT JOIN vmax v ON v.vid = t.vid
              WHERE NOT EXISTS (SELECT 1 FROM lk WHERE lk.tid = tl.tid AND lk.schema = tl.schema)),
       r2 AS (SELECT *, species_kg_largest > 0 AND trip_kg_logged > 10 * species_kg_largest
                          AND trip_kg_logged - species_kg_largest >= 1000 AS by_species,
                        trip_kg_logged > 10 * vessel_kg_largest AND trip_kg_logged - vessel_kg_largest >= 1000 AS by_vessel
              FROM w2),
       tf AS (SELECT * FROM r1
              UNION ALL
              SELECT tid, schema, sid_land, trip_kg_logged, NULL::DOUBLE, species_kg_largest, vessel_kg_largest,
                     CASE WHEN by_species AND by_vessel THEN 'species_largest+vessel_largest'
                          WHEN by_species THEN 'species_largest' ELSE 'vessel_largest' END, 'largest_landing_exceeded'
              FROM r2 WHERE coalesce(by_species, false) OR coalesce(by_vessel, false))
  SELECT sc.sid_st AS \".sid\", sc.schema, sc.tid AS \".tid\", sc.sid, sc.kg, sc.sid_land AS sid_landing,
         tf.trip_kg_logged, tf.trip_kg_landed, tf.species_kg_largest, tf.vessel_kg_largest, tf.witness, tf.flag
  FROM sc JOIN tf USING (tid, schema, sid_land)
  ORDER BY schema, \".tid\", \".sid\", sid", p(fd_curated("logbook", "trip.parquet"))))
dbDisconnect(con, shutdown = TRUE)

for (f in unique(flag$flag)) {
  g <- flag[flag$flag == f, ]
  message(sprintf("catch_flag %s: %s (station, species) rows on %s (trip, species) pairs, %.1f kt", f,
                  format(nrow(g), big.mark = ","), format(nrow(unique(g[, c(".tid", "schema", "sid_landing")])), big.mark = ","),
                  sum(g$kg) / 1e6))
}
write_curated(flag, fd_curated("logbook", "catch_flag.parquet"),
              inputs = c(station = fd_curated("logbook", "station.parquet"),
                         catch = fd_curated("logbook", "catch.parquet"),
                         lid_map = fd_curated("logbook", "lid_map.parquet"),
                         trip = fd_curated("logbook", "trip.parquet"),
                         landings = fd_curated("landing", "landings.parquet"),
                         landing_catch = fd_curated("landing", "catch.parquet")))
