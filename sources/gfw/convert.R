# Global Fishing Watch's own vessel identity table.
# Side: preprocessing (gfw). See plan 014.
#
# Input:  raw/external/gfw/fishing-vessels-v3/fishing-vessels-v3.csv (release 3.0, March 2025, 2012-2024;
#         provenance in raw/external/gfw/README-provenance.txt)
# Output: staging/gfw/vessel.parquet — one row per (mmsi, year)
#
# Plan 008: an identity source for the north-Atlantic vessel registry, not a
# position source — GFW's daily effort grids (fleet-daily-csvs,
# mmsi-daily-csvs) are activity data, out of scope (decision 117), and are not
# read here. This adapter stays a literal translation of the source's own
# layout; external_id resolution, periods and cross-source reasoning happen once, in
# reference/vessels/identity_foreign.R, not here.
#
# Every metric column comes three ways - _inferred (GFW's neural net),
# _registry (whatever registry GFW itself cross-referenced) and _gfw (GFW's
# own consolidated best guess) - and all three are kept. Collapsing to _gfw
# alone would discard exactly the recorded/reconstructed distinction AGENTS.md
# asks every inferred value to carry.
#
# v3 is long where v2 was wide: a row for each year an MMSI was active, with that year's active_hours and
# fishing_hours, where v2 had one row per MMSI and a fishing_hours_YYYY column per year (plan 021 §6 e). The class and
# flag can differ between an MMSI's years (1,277 and 1,054 MMSIs), so the rows are kept as they come. v3 writes an
# empty field for a missing value, v2 wrote "NA"; both read as NA.

library(readr)
library(dplyr)
library(nanoparquet)

gfw <-
  read_csv(fd_raw("external", "gfw", "fishing-vessels-v3", "fishing-vessels-v3.csv"),
           na = c("", "NA"),
           col_types = cols(
             mmsi = col_character(),
             year = col_integer(),
             flag_ais = col_character(),
             flag_registry = col_character(),
             flag_gfw = col_character(),
             vessel_class_inferred = col_character(),
             vessel_class_inferred_score = col_double(),
             vessel_class_registry = col_character(),
             vessel_class_gfw = col_character(),
             self_reported_fishing_vessel = col_logical(),
             length_m_inferred = col_double(),
             length_m_registry = col_double(),
             length_m_gfw = col_double(),
             engine_power_kw_inferred = col_double(),
             engine_power_kw_registry = col_double(),
             engine_power_kw_gfw = col_double(),
             tonnage_gt_inferred = col_double(),
             tonnage_gt_registry = col_double(),
             tonnage_gt_gfw = col_double(),
             registries_listed = col_character(),
             active_hours = col_double(),
             fishing_hours = col_double()
           ))

stopifnot(nrow(problems(gfw)) == 0,
          !anyNA(gfw$mmsi), !anyNA(gfw$year),
          !anyDuplicated(gfw[c("mmsi", "year")]))

cat("gfw fishing-vessels-v3: ", nrow(gfw), " rows, ", n_distinct(gfw$mmsi), " mmsi, years ",
    min(gfw$year), "-", max(gfw$year), "\n", sep = "")
cat("mmsi with a registry cross-reference (registries_listed not NA): ",
    n_distinct(gfw$mmsi[!is.na(gfw$registries_listed)]), "\n")

gfw |>
  nanoparquet::write_parquet(fd_staging("gfw", "vessel.parquet"))
