# catch_landing_contradicted.R — logged catch the landings contradict, flagged, never corrected.
# Side: preprocessing (logbook and landings). See plan 014.
#
# Input:  curated/logbook/{station,catch,lid_map,trip}.parquet, curated/landing/{landings,catch}.parquet,
#         curated/reference/species.parquet (rule 4's small pelagics)
# Output: curated/logbook/catch_flag.parquet  one row per flagged (station, species): .sid, schema, .tid, sid, kg (the
#         station's), sid_landing (the code compared), trip_kg_logged (the trip's, of sid_landing), trip_kg_landed
#         (rules 1, 3 and 4), species_kg_largest and vessel_kg_largest (rule 2), witness, flag; rule 3 one row per
#         (trip, species landed), with no station (.sid, sid and kg NA)
#
# Declaration and evidence: curate/corrections/catch_landing_contradicted.yml (plan 038 §8 step 1c).
#
# Per (logbook trip, species), with a margin of more than 10 times the witness and at least 1,000 kg more:
#   1. landing_contradicts: the trip has a linked landing that holds the species; the witness is what it holds. lid_map
#      is joined with the landing's own schema (the landings' .lid is shared between agf and lods, TODO 123).
#   2. largest_landing_exceeded: the trip has no linked landing; the witnesses are the largest landing of the species
#      by any vessel, and the vessel's own largest landing (all species) where 50 landing records or more stand behind
#      it. Either flags.
#   3. landed_not_logged: the trip has a linked landing that holds catch, and no station of the trip holds any. The
#      catch records are lost (plan 050 §6: 564 afli trips, 19 kt); the witness is what the landing holds, species by
#      species. Flagged, never filled in (the maintainer, 2026-10-29, decision 241).
# Per station value, on any trip, where rules 1 and 2 leave its (station, species):
#   4. repeated_digits: a catch row of 100,000 kg or more whose digits repeat with a period of at most half their length
#      (333,333; 3,703,703; 550,550) or are one digit then nines (7,999,999); the value is its own witness. Small
#      pelagics (target assemblage SPF) are left out: their round hauls of that size agree with their landings (the
#      maintainer, 2026-10-30, TODO 166).
# The logbook's 830 (herring, Atlanto-Scandian stock) is compared as the landings' 30; catch let go (negative codes)
# is never landed and is left out. A linked landing that holds none of the species is not judged here.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
dbExecute(con, "SET threads = 4; SET memory_limit = '6GB'")
p <- function(...) DBI::dbQuoteString(con, ...)
# rule 4's test of a value's digits: its shortest period, at most half its length, or one digit then nines
dbExecute(con, "CREATE MACRO period(s) AS
  list_min(list_filter(range(1, length(s) // 2 + 1), lambda k: substr(s, 1, length(s) - k) = substr(s, k + 1)))")
dbExecute(con, "CREATE MACRO nines(s) AS length(s) >= 2 AND substr(s, 2) = repeat('9', length(s) - 1)")

dbExecute(con, sprintf("
  CREATE TEMP TABLE sc AS
  SELECT s.\".sid\" AS sid_st, s.schema, s.\".tid\" AS tid, c.sid, CASE WHEN c.sid = 830 THEN 30 ELSE c.sid END AS sid_land,
         sum(c.catch) AS kg,
         bool_or(CASE WHEN c.catch >= 100000 THEN period(c.catch::VARCHAR) IS NOT NULL OR nines(c.catch::VARCHAR)
                      ELSE false END) AS digits_repeat
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
# rule 4: a value whose digits repeat, where rules 1 and 2 leave its (station, species); they flag every station of a
# (trip, species), so leaving out their stations leaves out their pairs
digits <- dbGetQuery(con, sprintf("
  SELECT sc.sid_st AS \".sid\", sc.schema, sc.tid AS \".tid\", sc.sid, sc.kg, sc.sid_land AS sid_landing,
         t.kg AS trip_kg_logged, l.kg AS trip_kg_landed, NULL::DOUBLE AS species_kg_largest,
         NULL::DOUBLE AS vessel_kg_largest, 'value' AS witness, 'repeated_digits' AS flag
  FROM sc
  JOIN (SELECT tid, schema, sid_land, sum(kg) AS kg FROM sc GROUP BY ALL) t USING (tid, schema, sid_land)
  LEFT JOIN landed l USING (tid, schema, sid_land)
  LEFT JOIN read_parquet(%s) sp ON sp.sid = sc.sid
  WHERE sc.digits_repeat AND sp.target_assemblage IS DISTINCT FROM 'SPF'
  ORDER BY sc.schema, sc.tid, sc.sid_st, sc.sid", p(fd_curated("reference", "species.parquet"))))
digits <- digits[!paste(digits$.sid, digits$schema, digits$sid) %in% paste(flag$.sid, flag$schema, flag$sid), ]
# rule 3: trips with stations (duplicate twins left out), none of which holds catch, and a linked landing that does
lost <- dbGetQuery(con, sprintf("
  WITH st AS (SELECT DISTINCT \".tid\" AS tid, schema FROM read_parquet(%s) WHERE twin IS NULL OR twin <> 'duplicate')
  SELECT NULL::DOUBLE AS \".sid\", st.schema, st.tid AS \".tid\", NULL::INTEGER AS sid, NULL::DOUBLE AS kg,
         l.sid_land AS sid_landing, 0::DOUBLE AS trip_kg_logged, l.kg AS trip_kg_landed, NULL::DOUBLE AS species_kg_largest,
         NULL::DOUBLE AS vessel_kg_largest, 'trip_landing' AS witness, 'landed_not_logged' AS flag
  FROM st JOIN landed l USING (tid, schema)
  WHERE l.kg > 0 AND NOT EXISTS (SELECT 1 FROM sc WHERE sc.tid = st.tid AND sc.schema = st.schema)
  ORDER BY st.schema, st.tid, l.sid_land", p(fd_curated("logbook", "station.parquet"))))
dbDisconnect(con, shutdown = TRUE)
flag <- rbind(flag, digits[, names(flag)], lost[, names(flag)])

for (f in unique(flag$flag)) {
  g <- flag[flag$flag == f, ]
  message(sprintf("catch_flag %s: %s rows on %s (trip, species) pairs, %.1f kt logged, %.1f kt landed", f,
                  format(nrow(g), big.mark = ","), format(nrow(unique(g[, c(".tid", "schema", "sid_landing")])), big.mark = ","),
                  sum(g$kg, na.rm = TRUE) / 1e6,
                  sum(unique(g[, c(".tid", "schema", "sid_landing", "trip_kg_landed")])$trip_kg_landed, na.rm = TRUE) / 1e6))
}
write_curated(flag, fd_curated("logbook", "catch_flag.parquet"),
              inputs = c(station = fd_curated("logbook", "station.parquet"),
                         catch = fd_curated("logbook", "catch.parquet"),
                         lid_map = fd_curated("logbook", "lid_map.parquet"),
                         trip = fd_curated("logbook", "trip.parquet"),
                         landings = fd_curated("landing", "landings.parquet"),
                         landing_catch = fd_curated("landing", "catch.parquet"),
                         species = fd_curated("reference", "species.parquet")))
