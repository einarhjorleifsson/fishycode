# adb_vs_fs_afladagbok.R — fix adb's dropped west longitude sign.
#
# Input:  staging/adb/station.parquet
# Output: staging/adb/lon_sign.parquet  (.sid, lon1, lon2, lon1_raw, lon2_raw,
#         lon_basis) — a side table, joined onto adb_station by curate/logbook.R
#         (curate/decisions/023-adb-wired-into-logbook.md). station.parquet
#         itself is untouched: this is a correction, not part of the adapter.
#
# Declaration and validation: curate/corrections/adb_vs_fs_afladagbok.yml,
# defect_2_longitude_sign. Only that defect is handled here — defect_1 (depth
# units) is closed via curate/decisions/022-depth-unit-is-metres.md, and
# defect_3 (gear coding) was not a defect at all.
#
# Rule, derived and validated against the 466,508 stations adb shares with
# fs_afladagbok (same underlying records, so fs's own value is ground truth):
#   negate lon when lon > 10.75 AND lat < 67.66
# This is exactly fs_afladagbok's own restore-threshold (sources/fs_afladagbok/
# convert.R, Step 3) - not a coincidence, since both are renderings of the same
# reporting system's positive-magnitude convention. Against the shared
# population this rule: fixes 37,205 of the 50,269 >10km mismatches, and
# breaks ZERO previously-correct rows (checked exhaustively, not sampled).
# The remaining 13,064 mismatches are NOT sign-related (confirmed: negating
# does not bring them within 10 km either) and are left alone - a separate,
# uncharacterised defect, out of scope here.
#
# The 10.75/67.66 boundary is what protects the ~4,630 genuine eastern-waters
# (Barents/Norwegian Sea) stations, which sit at lon up to 51.5 and lat mostly
# > 67.66 - and it does NOT depend on fs at all, so it generalises to adb rows
# fs_afladagbok never covered (2026+, the entire reason to wire adb in).

suppressMessages({
  source("R/paths.R")
  library(dplyr)
})

LON_THRESH <- 10.75
LAT_THRESH <- 67.66

station <- duckdbfs::open_dataset(fd_staging("adb", "station.parquet")) |>
  select(.sid, lon1, lat1, lon2, lat2) |>
  collect()

fix_lon <- function(lon, lat) {
  wrong <- !is.na(lon) & !is.na(lat) & lon > LON_THRESH & lat < LAT_THRESH
  if_else(wrong, -lon, lon)
}

lon_sign <- station |>
  mutate(
    lon1_raw = lon1, lon2_raw = lon2,
    lon1 = fix_lon(lon1, lat1),
    lon2 = fix_lon(lon2, lat2),
    lon1_basis = case_when(is.na(lon1_raw) ~ NA_character_,
                           lon1 != lon1_raw ~ "reconstructed",
                           .default = "recorded"),
    lon2_basis = case_when(is.na(lon2_raw) ~ NA_character_,
                           lon2 != lon2_raw ~ "reconstructed",
                           .default = "recorded")
  ) |>
  select(.sid, lon1, lon2, lon1_raw, lon2_raw, lon1_basis, lon2_basis)

out <- fd_staging("adb", "lon_sign.parquet")
lon_sign |> duckdbfs::write_dataset(out)

# Report -------------------------------------------------------------------
cat("== adb longitude sign fix ==\n")
cat("total adb stations:", nrow(lon_sign), "\n")
print(lon_sign |> count(lon1_basis))
cat(sprintf("\nreconstructed (sign-flipped): %s of %s (%.2f%%)\n",
            sum(lon_sign$lon1_basis == "reconstructed", na.rm = TRUE),
            sum(!is.na(lon_sign$lon1_basis)),
            100 * mean(lon_sign$lon1_basis == "reconstructed", na.rm = TRUE)))
