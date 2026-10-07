# catch_by_species_station.R — the catch as caught (whole fish), one row per (station, species).
#
# Input:  curated/logbook/catch.parquet  (.sid, schema, sid, condition, catch, catch_whole)
# Output: curated/logbook/catch_by_species_station.parquet
#         .sid schema sid  catch_recorded catch_released catch_round round_basis
#
# Joins the trail on (.sid, schema): `trail` carries both, filled when n_sid == 1. Species is `sid`
# (the species code; the trail's `.sid` is the station). One row per (station, species) however many
# conditions the logbook recorded.
#
# The logbook records a weight in the STATE the fish were landed in (`condition`: GUTT, UNGU, RELE), and
# the whole-fish weight (`catch_whole`) only until 2022: fs_afladagbok fills `afli` for ~98 % of rows
# thereafter NOT at all. Measured on the 1.39 M (station, species) rows adb shares with fs_afladagbok:
# GUTT weight is 0.80 of the whole weight (5-95 % range 0.789-0.80), UNGU and RELE are 1.00.
#   catch_round = catch_whole           where recorded                          basis "recorded"
#               = catch / 0.8           GUTT, no whole weight                   basis "reconstructed"
#               = catch                 UNGU, RELE, or the old afli schema      basis "recorded"
#               = catch                 no condition at all (adb bycatch rows)  basis "synthesised"
# The afli schema records whole weight: on the 167,320 (vessel, date, species) the afli and fs_afladagbok
# logbooks share, afli equals fs's whole weight (`afli`) in 99.6 % of 166,713 comparable cases, and equals
# the GUTT weight / 0.8 (median ratio 1.250) and the UNGU weight (1.000) otherwise (measured 2026-10-03).
# `catch_recorded` is the sum as recorded (mixed states), `catch_released` the part in condition RELE
# (already inside catch_round). The station's basis is the weakest of its rows: synthesised >
# reconstructed > recorded.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
dbExecute(con, sprintf("SET temp_directory = '%s'", spill))
src <- fd_curated("logbook", "catch.parquet")

sql <- sprintf("
  WITH r AS (
    SELECT \".sid\", schema, sid, condition, catch,
           CASE WHEN catch_whole IS NOT NULL THEN catch_whole
                WHEN condition = 'GUTT' THEN catch / 0.8
                ELSE catch END AS cr,
           CASE WHEN catch_whole IS NOT NULL THEN 1
                WHEN condition = 'GUTT' THEN 2
                WHEN condition IS NULL AND schema <> 'afli' THEN 3
                ELSE 1 END AS b
    FROM read_parquet('%s'))
  SELECT \".sid\", schema, sid,
         sum(catch) AS catch_recorded,
         sum(cr) FILTER (WHERE condition = 'RELE') AS catch_released,
         sum(cr) AS catch_round,
         CASE max(b) WHEN 1 THEN 'recorded' WHEN 2 THEN 'reconstructed' ELSE 'synthesised' END AS round_basis
  FROM r GROUP BY \".sid\", schema, sid", src)

n <- write_curated_sql(con, sql, fd_curated("logbook", "catch_by_species_station.parquet"),
                       inputs = src, order_by = "schema, \".sid\", sid")
message(sprintf("catch_by_species_station: %s rows", format(n, big.mark = ",")))
print(dbGetQuery(con, sprintf("SELECT round_basis, count(*) n, round(sum(catch_round) / 1e6) kt FROM read_parquet('%s') GROUP BY 1",
                              fd_curated("logbook", "catch_by_species_station.parquet"))))
