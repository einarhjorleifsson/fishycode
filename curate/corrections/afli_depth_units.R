# afli_depth_units.R — convert afli station depth to the product's declared
# unit (metres, curate/decisions/022-depth-unit-is-metres.md).
#
# Input:  staging/afli/{station,trip,fishing_sample}.parquet
#         curated/reference/{area_h3,gear}.parquet
# Output: staging/afli/depth.parquet  (.sid, z1, z2, z1_raw, z2_raw,
#         z1_basis, z2_basis) — a side table, joined onto station.parquet by
#         whoever merges afli into the logbook (curate/logbook.R). station.parquet
#         itself is untouched: this is a correction, not part of the adapter.
#
# Declaration and validation: curate/corrections/afli_depth_units.yml
#
# afli records depth in FATHOMS outside a 2010-01 to 2012-06 window, in which a
# growing share of vessels switch to METRES, one vessel at a time, before an
# abrupt system-wide reversion. See the .yml for the full evidence. This script:
#   1. Converts every station outside the drift window (fathoms -> metres, flat).
#   2. Inside the window, estimates ONE switch date per vessel from its own
#      non-pelagic, deep (z1 >= 50), Icelandic-box GEBCO ratio, and applies that
#      date to ALL of the vessel's stations in the window (any gear, any depth) -
#      the switch is equipment/software, not depth- or gear-dependent.
#   3. Vessels with too few classifiable stations in the window default to the
#      baseline assumption (fathoms throughout).
#
# Per the "never destroy the original" rule: z1/z2 become the corrected value,
# z1_raw/z2_raw keep exactly what afli recorded. z1_basis/z2_basis is
# "recorded" where the value was already metres (untouched) or "reconstructed"
# where it was converted. NA depth stays NA depth, basis NA.
#
# Pelagic gear (gid in the OTM/PS/HMS set) is EXCLUDED from the classification
# evidence only - a pelagic z1 can be fishing depth, not seabed depth, so its
# GEBCO ratio is not informative (curate/decisions/022, "Pelagic gear is out of
# scope"). Pelagic stations still get corrected depth, using their own vessel's
# switch date estimated from its non-pelagic stations.

suppressMessages({
  source("R/paths.R")
  library(duckdbfs)
  library(dplyr)
  library(purrr)
  library(tibble)
  library(lubridate)
})
duckdbfs::load_h3()

# Parameters -------------------------------------------------------------------
FATHOM_TO_M   <- 1.8288
DRIFT_START   <- as.POSIXct("2010-01-01")
DRIFT_END     <- as.POSIXct("2012-06-30")
METRES_THRESH <- 1.4    # GEBCO ratio below this reads as already-metres
MIN_CLASSIFY  <- 10     # minimum classification rows before trusting a changepoint
# Approximate Icelandic EEZ box for the GEBCO cross-check; loose on purpose -
# false positives here only add noise to the ratio, they don't misclassify a
# vessel, because MIN_CLASSIFY and the changepoint fit both average it out.
ICELAND_LON_MIN <- -30; ICELAND_LON_MAX <- -10
ICELAND_LAT_MIN <- 62;  ICELAND_LAT_MAX <- 68

# Load ---------------------------------------------------------------------
station <- open_dataset(fd_staging("afli", "station.parquet")) |>
  select(.sid, .tid, date, lon1, lat1, z1, z2)

trip <- open_dataset(fd_staging("afli", "trip.parquet")) |>
  select(.tid, vid)

gear_sid <- open_dataset(fd_staging("afli", "fishing_sample.parquet")) |>
  select(.sid, gid, gear)

gebco <- open_dataset(fd_curated("reference", "area_h3.parquet")) |>
  select(h3, gebco_depth = depth)

pelagic_gears <- c("OTM", "PS", "HMS")

base <- station |>
  left_join(trip, by = ".tid") |>
  left_join(gear_sid, by = ".sid") |>
  collect()

# Classification evidence: non-pelagic, in-box, deep, inside the drift window --
# h3_latlng_to_cell_string is a DuckDB macro (duckdbfs::load_h3()), so this join
# has to run lazily against the DuckDB source, not against the collected `base`.
classif <- station |>
  left_join(trip, by = ".tid") |>
  left_join(gear_sid, by = ".sid") |>
  filter(!is.na(lon1), !is.na(lat1), !is.na(z1), z1 >= 50,
         !is.na(gear), !gear %in% pelagic_gears,
         lon1 >= ICELAND_LON_MIN, lon1 <= ICELAND_LON_MAX,
         lat1 >= ICELAND_LAT_MIN, lat1 <= ICELAND_LAT_MAX,
         date >= DRIFT_START, date <= DRIFT_END, !is.na(vid)) |>
  mutate(h3 = h3_latlng_to_cell_string(lat1, lon1, 8L)) |>
  left_join(gebco, by = "h3") |>
  filter(!is.na(gebco_depth), gebco_depth < 0) |>
  mutate(gebco_ratio = abs(gebco_depth) / z1,
         is_metres = gebco_ratio < METRES_THRESH) |>
  select(vid, date, is_metres) |>
  collect()

# Per-vessel changepoint --------------------------------------------------------
# Single step function fathoms(0) -> metres(1). Fit on the vessel's OWN ordered
# classification rows only - never on an individual row's own ratio at
# application time (curate/corrections/afli_depth_units.yml, "do_not").
fit_switch_date <- function(date_sorted, is_metres_sorted) {
  n <- length(is_metres_sorted)
  label <- as.integer(is_metres_sorted)
  cum1 <- c(0, cumsum(label))
  total1 <- cum1[n + 1]
  # score(k) = correct fathoms in [1,k] + correct metres in [k+1,n], k = 0..n
  k <- 0:n
  score <- (k - cum1) + (total1 - cum1)
  k_star <- k[which.max(score)]
  if (k_star == n) DRIFT_END + 1
  else if (k_star == 0) DRIFT_START - 1
  else date_sorted[k_star + 1]
}

vessel_groups <- classif |>
  arrange(vid, date) |>
  group_by(vid) |>
  filter(n() >= MIN_CLASSIFY) |>
  ungroup() |>
  split(~vid)

switch_tbl <- purrr::map_dfr(vessel_groups, function(g) {
  tibble(vid = g$vid[1], n_classified = nrow(g),
         switch_date = fit_switch_date(g$date, g$is_metres))
})

cat("== vessels classified in the drift window ==\n")
cat("vessels with >=", MIN_CLASSIFY, "classification rows:", nrow(switch_tbl), "\n")
cat("  always-fathoms (no switch found):   ", sum(switch_tbl$switch_date > DRIFT_END), "\n")
cat("  already-metres from window start:   ", sum(switch_tbl$switch_date < DRIFT_START), "\n")
cat("  genuine mid-window switch:          ",
    sum(switch_tbl$switch_date >= DRIFT_START & switch_tbl$switch_date <= DRIFT_END), "\n\n")

# Apply --------------------------------------------------------------------
depth <- base |>
  left_join(switch_tbl, by = "vid") |>
  mutate(
    switch_date = if_else(is.na(switch_date), DRIFT_END + 1, switch_date),  # default: fathoms throughout
    in_window = date >= DRIFT_START & date <= DRIFT_END,
    was_fathoms = !in_window | date < switch_date,
    z1_raw = z1,
    z2_raw = z2,
    z1 = if_else(!is.na(z1_raw) & was_fathoms, z1_raw * FATHOM_TO_M, z1_raw),
    z2 = if_else(!is.na(z2_raw) & was_fathoms, z2_raw * FATHOM_TO_M, z2_raw),
    z1_basis = case_when(is.na(z1_raw) ~ NA_character_,
                         was_fathoms   ~ "reconstructed",
                         .default      = "recorded"),
    z2_basis = case_when(is.na(z2_raw) ~ NA_character_,
                         was_fathoms   ~ "reconstructed",
                         .default      = "recorded")
  ) |>
  select(.sid, z1, z2, z1_raw, z2_raw, z1_basis, z2_basis)

out <- fd_staging("afli", "depth.parquet")
depth |> duckdbfs::write_dataset(out)

# Report -------------------------------------------------------------------
cat("== station-level basis, all", nrow(depth), "afli stations ==\n")
print(depth |> count(z1_basis))
cat("\nmedian z1 (m) by year, before vs after (sample):\n")
depth |>
  left_join(base |> select(.sid, date), by = ".sid") |>
  mutate(year = lubridate::year(date)) |>
  filter(year %in% c(1995, 2005, 2010, 2011, 2012, 2015, 2020)) |>
  group_by(year) |>
  summarise(median_z1_raw_before = median(z1_raw, na.rm = TRUE),
            median_z1_m_after = median(z1, na.rm = TRUE),
            pct_reconstructed = mean(z1_basis == "reconstructed", na.rm = TRUE) * 100,
            .groups = "drop") |>
  print()
