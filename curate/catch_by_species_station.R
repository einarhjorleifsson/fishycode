# catch_by_species_station.R — the catch as caught (whole fish), one row per (station, species).
# Side: preprocessing (logbook). See plan 014.
#
# Input:  curated/logbook/catch.parquet    (.sid, schema, sid, condition, catch, catch_whole)
#         curated/logbook/station.parquet  (.sid, schema, date, twin)
#         curated/logbook/nephrops_tails.parquet  (.sid, schema, sid, condition_corrected)
#         curated/reference/whole_weight_factor.parquet  (the factor table, reference/species/whole_weight_factor.R)
# Output: curated/logbook/catch_by_species_station.parquet
#         .sid schema sid  catch_recorded catch_released catch_round round_basis round_factor catch_round_logbook
#
# Joins the trail on (.sid, schema): `trail` carries both, filled when n_sid == 1. Species is `sid`
# (the species code; the trail's `.sid` is the station). One row per (station, species) however many
# conditions the logbook recorded.
#
# The whole weight is calc_whole_weight()'s (R/whole_weight.R), the one copy of the rule, at the landings' factor of
# the station's day for the species and its state (plan 051 ask a): GUTT x the species' gutted factor, a state a
# correction names x that state's (Nephrops tails, curate/corrections/logbook_nephrops_tails.yml), as recorded
# otherwise. Its columns keep their names here: `catch_round` is the whole weight, `round_basis` its basis,
# `round_factor` the factor read (NA where none was), and `catch_round_logbook` the logbook's own whole weight, the
# recorded `catch_whole` or GUTT / 0.8, as the merge's fate table keeps it (plan 024). `catch_recorded` is the sum as
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
tlf <- fd_curated("logbook", "nephrops_tails.parquet")
wwf <- fd_curated("reference", "whole_weight_factor.parquet")
factors <- duckdbfs::open_dataset(wwf) |> dplyr::collect()

# A station's day, as a date: station.parquet's `date` is a date-time.
station <- dplyr::tbl(con, dplyr::sql(sprintf(
  "SELECT \".sid\", schema, CAST(date AS DATE) AS date FROM read_parquet('%s') WHERE twin IS DISTINCT FROM 'duplicate'",
  stf)))
sql <- dplyr::tbl(con, dplyr::sql(sprintf("SELECT * FROM read_parquet('%s')", src))) |>
  dplyr::inner_join(station, by = c(".sid", "schema")) |>
  dplyr::left_join(dplyr::tbl(con, dplyr::sql(sprintf(
    "SELECT \".sid\", schema, sid, condition_corrected FROM read_parquet('%s') WHERE condition_corrected IS NOT NULL",
    tlf))), by = c(".sid", "schema", "sid")) |>
  calc_whole_weight(by = c(".sid", "schema", "sid"), factors = factors,
                    catch_recorded = sum(catch, na.rm = TRUE),
                    catch_released = sum(dplyr::if_else(condition == "RELE", whole_weight, NA), na.rm = TRUE)) |>
  dplyr::rename(catch_round = whole_weight, round_basis = whole_weight_basis, round_factor = whole_weight_factor,
                catch_round_logbook = whole_weight_logbook) |>
  dbplyr::sql_render()

n <- write_curated_sql(con, sql, fd_curated("logbook", "catch_by_species_station.parquet"),
                       inputs = c(src, stf, tlf, wwf), order_by = "schema, \".sid\", sid")
message(sprintf("catch_by_species_station: %s rows", format(n, big.mark = ",")))
print(dbGetQuery(con, sprintf("SELECT round_basis, count(*) n, round(sum(catch_round) / 1e6) kt FROM read_parquet('%s') GROUP BY 1",
                              fd_curated("logbook", "catch_by_species_station.parquet"))))
