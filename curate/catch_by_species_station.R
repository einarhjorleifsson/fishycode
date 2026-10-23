# catch_by_species_station.R — the catch as caught (whole fish), one row per (station, species).
# Side: preprocessing (logbook). See plan 014.
#
# Input:  curated/logbook/catch.parquet    (.sid, schema, sid, condition, catch, catch_whole)
#         curated/logbook/station.parquet  (.sid, schema, twin)
# Output: curated/logbook/catch_by_species_station.parquet
#         .sid schema sid  catch_recorded catch_released catch_round round_basis
#
# Joins the trail on (.sid, schema): `trail` carries both, filled when n_sid == 1. Species is `sid`
# (the species code; the trail's `.sid` is the station). One row per (station, species) however many
# conditions the logbook recorded.
#
# The whole weight is calc_whole_weight()'s (R/whole_weight.R), the one copy of the rule, which the logbook merge's
# fate table also uses (plan 024): GUTT / 0.8 where no whole weight is recorded, as recorded otherwise. Its columns
# keep their names here: `catch_round` is the whole weight, `round_basis` its basis. `catch_recorded` is the sum as
# recorded (mixed states), `catch_released` the part in condition RELE (already inside catch_round). The station's
# basis is the weakest of its rows: synthesised > reconstructed > recorded.
#
# A duplicate twin (curate/corrections/logbook_twin.yml) has no rows here: its catch is its kept record's, entered
# again, so a sum over this table counts it once. catch.parquet keeps every row.

library(DBI)
library(duckdb)

con <- dbConnect(duckdb())
spill <- file.path(tempdir(), "duckdb_spill"); dir.create(spill, showWarnings = FALSE)
dbExecute(con, sprintf("SET temp_directory = '%s'", spill))
src <- fd_curated("logbook", "catch.parquet")
stf <- fd_curated("logbook", "station.parquet")

duplicate <- dplyr::tbl(con, dplyr::sql(sprintf(
  "SELECT \".sid\", schema FROM read_parquet('%s') WHERE twin = 'duplicate'", stf)))
sql <- dplyr::tbl(con, dplyr::sql(sprintf("SELECT * FROM read_parquet('%s')", src))) |>
  dplyr::anti_join(duplicate, by = c(".sid", "schema")) |>
  calc_whole_weight(by = c(".sid", "schema", "sid"),
                    catch_recorded = sum(catch, na.rm = TRUE),
                    catch_released = sum(dplyr::if_else(condition == "RELE", whole_weight, NA), na.rm = TRUE)) |>
  dplyr::rename(catch_round = whole_weight, round_basis = whole_weight_basis) |>
  dbplyr::sql_render()

n <- write_curated_sql(con, sql, fd_curated("logbook", "catch_by_species_station.parquet"),
                       inputs = c(src, stf), order_by = "schema, \".sid\", sid")
message(sprintf("catch_by_species_station: %s rows", format(n, big.mark = ",")))
print(dbGetQuery(con, sprintf("SELECT round_basis, count(*) n, round(sum(catch_round) / 1e6) kt FROM read_parquet('%s') GROUP BY 1",
                              fd_curated("logbook", "catch_by_species_station.parquet"))))
