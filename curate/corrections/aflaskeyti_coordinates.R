# aflaskeyti_coordinates.R — put dw_aflaskeyti's swapped latitude and longitude right.
# Side: preprocessing (aflaskeyti). See plan 014 and plan 026 §3a.
#
# Input:  staging/aflaskeyti/station.parquet      (lon1, lat1, lon2, lat2 as Oracle names them)
# Output: staging/aflaskeyti/coordinates.parquet  (.sid, lon1, lat1, lon2, lat2, lon1_raw, lat1_raw, lon2_raw,
#         lat2_raw, lon1_basis, lon2_basis, coord_flag) — a side table, joined onto the station table by
#         curate/logbook.R; station.parquet is untouched.
#
# Declaration and evidence: curate/corrections/aflaskeyti_coordinates.yml (decision 126). Every row is swapped, so
# the rule has no condition.

library(dplyr)

station <- duckdbfs::open_dataset(fd_staging("aflaskeyti", "station.parquet")) |>
  select(.sid, lon1, lat1, lon2, lat2) |>
  collect()

# From the _raw columns only: within one transmute(), `lat1 = lon1` would read a lon1 already swapped.
coordinates <- station |>
  transmute(.sid, lon1_raw = lon1, lat1_raw = lat1, lon2_raw = lon2, lat2_raw = lat2) |>
  mutate(lon1 = lat1_raw, lat1 = lon1_raw, lon2 = lat2_raw, lat2 = lon2_raw,
         lon1_basis = "recorded", lon2_basis = "recorded",
         coord_flag = "lat_lon_swapped") |>
  relocate(.sid, lon1, lat1, lon2, lat2)

stopifnot(all(abs(coordinates$lat1) <= 90), all(abs(coordinates$lat2) <= 90, na.rm = TRUE))
in_box <- with(coordinates, lat1 >= 60 & lat1 <= 69 & lon1 >= -32 & lon1 <= -5)
cat(sprintf("aflaskeyti coordinates: %d stations swapped, %d of them around Iceland\n", nrow(coordinates), sum(in_box)))

coordinates |> duckdbfs::write_dataset(fd_staging("aflaskeyti", "coordinates.parquet"))
