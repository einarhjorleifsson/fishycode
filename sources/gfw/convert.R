# Global Fishing Watch's own vessel identity table.
#
# Input:  raw/external/gfw/fishing-vessels-v2.csv
# Output: staging/gfw/vessel.parquet — one row per mmsi
#
# Plan 008: an identity source for the north-Atlantic vessel registry, not a
# position source — GFW's daily effort grids (fleet-daily-csvs,
# mmsi-daily-csvs) are activity data, TODO item 21's concern, and are not
# read here. This adapter stays a literal translation of the source's own
# layout; external_id resolution and cross-source reasoning happen once, in
# curate/vessel_identity_foreign.R, not here.
#
# Every metric column comes three ways - _inferred (GFW's neural net),
# _registry (whatever registry GFW itself cross-referenced) and _gfw (GFW's
# own consolidated best guess) - and all three are kept. Collapsing to _gfw
# alone would discard exactly the recorded/reconstructed distinction AGENTS.md
# asks every inferred value to carry.
#
# fishing_hours_2012..2020 are dropped: per-vessel activity, not identity.
# registries_listed is kept - it names which registries corroborate the row.

library(readr)
library(dplyr)
library(nanoparquet)

gfw <-
  read_csv(fd_raw("external", "gfw", "fishing-vessels-v2.csv"),
           col_types = cols(
             mmsi = col_character(),
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
             .default = col_skip()
           ))

stopifnot(!anyDuplicated(gfw$mmsi))

cat("gfw fishing-vessels-v2: ", nrow(gfw), " vessels\n")
cat("with a registry cross-reference (registries_listed not NA): ",
    sum(!is.na(gfw$registries_listed)), "\n")

gfw |>
  nanoparquet::write_parquet(fd_staging("gfw", "vessel.parquet"))
